<?php
declare(strict_types=1);

namespace MundoDrone;

/**
 * Servidor de mundo compartilhado do Simulador Cockpit Drone.
 *
 * Regras:
 *  - entrada livre, sem usuário e senha;
 *  - cada entrada recebe um token que identifica UM drone; o servidor
 *    identifica o drone sempre pelo token, nunca por um id enviado no corpo;
 *  - cada resposta traz só drones e eventos a até 2 km (raio_m) de quem
 *    pergunta; fora do círculo nada é repassado, nem a contagem.
 *
 * Ações (POST JSON em api.php, campo "acao"): entrar, atualizar, evento,
 * sair, status. Protocolo completo em docs/protocolo_mundo.md.
 */
final class Api
{
    public const VERSAO_PROTOCOLO = 1;
    private const TAMANHO_MAX_CORPO = 4096;
    private const ESTADOS = ['parado', 'voando', 'pousando', 'caiu'];
    private const TIPOS_EVENTO = ['mensagem', 'sinal', 'marcador'];

    private ?Repositorio $repo = null;
    private int $agora;

    /** @param array<string, mixed> $config */
    public function __construct(private array $config)
    {
        $this->agora = (int) round(microtime(true) * 1000);
    }

    public function atende(): void
    {
        try {
            $metodo = $_SERVER['REQUEST_METHOD'] ?? 'GET';
            if ($metodo === 'GET' && (($_GET['acao'] ?? 'status') === 'status')) {
                $this->responde(200, $this->status());
                return;
            }
            if ($metodo !== 'POST') {
                throw new ErroApi(405, 'metodo', 'Use POST com corpo JSON.');
            }
            $corpo = file_get_contents('php://input', false, null, 0, self::TAMANHO_MAX_CORPO + 1);
            if ($corpo === false || strlen($corpo) > self::TAMANHO_MAX_CORPO) {
                throw new ErroApi(400, 'tamanho', 'Corpo acima de 4 KB.');
            }
            $dados = json_decode($corpo, true);
            if (!is_array($dados)) {
                throw new ErroApi(400, 'json', 'JSON inválido.');
            }
            $this->responde(200, $this->executa($dados, $this->tokenDoCabecalho()));
        } catch (ErroApi $e) {
            $this->responde($e->status, ['ok' => false, 'erro' => $e->codigo, 'mensagem' => $e->getMessage()]);
        } catch (\Throwable $e) {
            error_log('servidor_mundo: ' . $e->getMessage());
            $this->responde(500, ['ok' => false, 'erro' => 'interno', 'mensagem' => 'Erro interno do servidor.']);
        }
    }

    /**
     * Executa uma ação. Separado de atende() para os testes chamarem direto.
     * @param array<string, mixed> $dados
     * @return array<string, mixed>
     */
    public function executa(array $dados, ?string $token, ?string $ip = null): array
    {
        $ip ??= $this->ipCliente();
        $acao = is_string($dados['acao'] ?? null) ? $dados['acao'] : '';
        if ($acao === 'status') {
            return $this->status();
        }
        $this->limpezaOcasional();
        return match ($acao) {
            'entrar' => $this->entrar($dados, $ip),
            'atualizar' => $this->atualizar($dados, $this->droneAutenticado($token)),
            'evento' => $this->evento($dados, $this->droneAutenticado($token)),
            'sair' => $this->sair($this->droneAutenticado($token)),
            default => throw new ErroApi(400, 'acao', 'Ação desconhecida.'),
        };
    }

    public function defineAgora(int $ms): void
    {
        $this->agora = $ms;
    }

    // ------------------------------------------------------------------ ações

    /** @return array<string, mixed> */
    private function status(): array
    {
        // Nada sobre drones: nem posições, nem contagem.
        return [
            'ok' => true,
            'versao' => self::VERSAO_PROTOCOLO,
            'raio_m' => $this->raio(),
            'intervalo_ms' => (int) $this->config['intervalo_ms'],
        ];
    }

    /**
     * @param array<string, mixed> $d
     * @return array<string, mixed>
     */
    private function entrar(array $d, string $ip): array
    {
        $repo = $this->repo();
        if ($repo->contaLimite('entrar:' . $ip, 60000, $this->agora) > (int) $this->config['limite_entradas_por_min_ip']) {
            throw new ErroApi(429, 'limite', 'Muitas entradas deste endereço; espere um minuto.');
        }
        $ativosDesde = $this->agora - $this->validadeMs();
        if ($repo->dronesDoIp($ip, $ativosDesde) >= (int) $this->config['limite_drones_por_ip']) {
            throw new ErroApi(429, 'limite', 'Limite de drones ativos por endereço atingido.');
        }
        $apelido = Validacao::apelido($d['apelido'] ?? null);
        $modelo = Validacao::modelo($d['modelo'] ?? null);
        [$lat, $lon, $alt] = Validacao::posicao($d['posicao'] ?? null);

        do {
            $id = 'd_' . bin2hex(random_bytes(3));
        } while ($repo->idExiste($id));
        $token = bin2hex(random_bytes(32));
        $repo->insereDrone([
            'id' => $id,
            'token_hash' => hash('sha256', $token),
            'ip' => $ip,
            'apelido' => $apelido,
            'modelo' => $modelo,
            'lat' => $lat,
            'lon' => $lon,
            'alt' => $alt,
            'agora' => $this->agora,
        ]);
        return [
            'ok' => true,
            'id' => $id,
            'token' => $token,
            'validade_s' => (int) $this->config['validade_token_s'],
            'raio_m' => $this->raio(),
            'intervalo_ms' => (int) $this->config['intervalo_ms'],
            // Novos eventos a partir daqui (não recebe o que aconteceu antes de entrar).
            'ultimo_evento' => $repo->ultimoSeqEvento(),
        ];
    }

    /**
     * @param array<string, mixed> $d
     * @param array<string, mixed> $drone
     * @return array<string, mixed>
     */
    private function atualizar(array $d, array $drone): array
    {
        $repo = $this->repo();
        if ($repo->contaLimite('atualizar:' . $drone['id'], 1000, $this->agora) > (int) $this->config['limite_atualizar_por_s']) {
            throw new ErroApi(429, 'limite', 'Atualizações rápidas demais.');
        }
        [$lat, $lon, $alt] = Validacao::posicao($d['posicao'] ?? null);

        // Sem teletransporte: só chega a outra área voando até ela.
        $dt = max(0.05, ($this->agora - (int) $drone['atualizado']) / 1000);
        $salto = Geo::distanciaM((float) $drone['lat'], (float) $drone['lon'], $lat, $lon);
        if ($salto / $dt > (float) $this->config['velocidade_max_ms'] && $salto > 30) {
            throw new ErroApi(400, 'salto', sprintf('Posição recusada: salto de %.0f m em %.1f s.', $salto, $dt));
        }

        $repo->atualizaDrone((string) $drone['id'], [
            'lat' => $lat,
            'lon' => $lon,
            'alt' => $alt,
            'rumo' => Validacao::inteiro($d['rumo'] ?? 0, 0, 359, 'rumo'),
            'velocidade' => Validacao::numero($d['velocidade'] ?? 0, 0, 100, 'velocidade'),
            'estado' => Validacao::opcao($d['estado'] ?? 'voando', self::ESTADOS, 'estado'),
            'bateria' => isset($d['bateria']) ? Validacao::inteiro($d['bateria'], 0, 100, 'bateria') : null,
            'agora' => $this->agora,
        ]);

        $raio = $this->raio();
        $ret = Geo::retangulo($lat, $lon, $raio);
        $vizinhos = [];
        foreach ($repo->dronesNoRetangulo($ret, (string) $drone['id'], $this->agora - $this->validadeMs()) as $v) {
            $dist = Geo::distanciaM($lat, $lon, (float) $v['lat'], (float) $v['lon']);
            if ($dist > $raio) {
                continue; // fora do círculo: nada é repassado
            }
            $vizinhos[] = [
                'id' => $v['id'],
                'apelido' => $v['apelido'],
                'modelo' => $v['modelo'],
                'posicao' => ['lat' => (float) $v['lat'], 'lon' => (float) $v['lon'], 'alt' => round((float) $v['alt'], 1)],
                'rumo' => (int) $v['rumo'],
                'velocidade' => round((float) $v['velocidade'], 1),
                'estado' => $v['estado'],
                'bateria' => self::faixaBateria($v['bateria']),
                'distancia_m' => (int) round($dist),
                'atualizado' => (int) $v['atualizado'],
            ];
        }
        usort($vizinhos, static fn(array $a, array $b): int => $a['distancia_m'] <=> $b['distancia_m']);

        $ultimo = Validacao::inteiro($d['ultimo_evento'] ?? 0, 0, PHP_INT_MAX, 'ultimo_evento');
        $eventos = [];
        $desde = $this->agora - (int) $this->config['eventos_validade_s'] * 1000;
        foreach ($repo->eventosNoRetangulo($ret, $ultimo, $desde, (string) $drone['id']) as $e) {
            if (Geo::distanciaM($lat, $lon, (float) $e['lat'], (float) $e['lon']) > $raio) {
                continue;
            }
            $conteudo = json_decode((string) $e['conteudo'], true);
            $eventos[] = [
                'seq' => (int) $e['seq'],
                'de' => $e['drone_id'],
                'apelido' => $e['apelido'],
                'tipo' => $e['tipo'],
                'conteudo' => $conteudo,
                'quando' => (int) $e['quando'],
            ];
        }
        return ['ok' => true, 'agora' => $this->agora, 'vizinhos' => $vizinhos, 'eventos' => $eventos];
    }

    /**
     * @param array<string, mixed> $d
     * @param array<string, mixed> $drone
     * @return array<string, mixed>
     */
    private function evento(array $d, array $drone): array
    {
        $repo = $this->repo();
        if ($repo->contaLimite('evento:' . $drone['id'], 1000, $this->agora) > (int) $this->config['limite_eventos_por_s']) {
            throw new ErroApi(429, 'limite', 'Eventos rápidos demais.');
        }
        $tipo = Validacao::opcao($d['tipo'] ?? null, self::TIPOS_EVENTO, 'tipo');
        $lat = (float) $drone['lat'];
        $lon = (float) $drone['lon'];
        $raio = $this->raio();
        switch ($tipo) {
            case 'mensagem':
                $conteudo = Validacao::texto($d['conteudo'] ?? null, 1, 200, 'conteudo');
                break;
            case 'sinal':
                $conteudo = Validacao::texto($d['conteudo'] ?? 'luzes', 1, 20, 'conteudo');
                break;
            default: // marcador
                $c = $d['conteudo'] ?? null;
                if (!is_array($c)) {
                    throw new ErroApi(400, 'conteudo', 'Marcador precisa de lat, lon e rotulo.');
                }
                [$mLat, $mLon] = Validacao::posicao(['lat' => $c['lat'] ?? null, 'lon' => $c['lon'] ?? null, 'alt' => 0]);
                if (Geo::distanciaM($lat, $lon, $mLat, $mLon) > $raio) {
                    throw new ErroApi(400, 'conteudo', 'O marcador precisa estar a até ' . $raio . ' m de você.');
                }
                $conteudo = ['lat' => $mLat, 'lon' => $mLon,
                    'rotulo' => Validacao::texto($c['rotulo'] ?? '', 0, 40, 'rotulo')];
        }
        // A origem do evento é a posição do drone do token no momento do envio.
        $seq = $repo->insereEvento((string) $drone['id'], (string) $drone['apelido'], $tipo,
            json_encode($conteudo, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR), $lat, $lon, $this->agora);

        $entregue = 0;
        $ret = Geo::retangulo($lat, $lon, $raio);
        foreach ($repo->dronesNoRetangulo($ret, (string) $drone['id'], $this->agora - $this->validadeMs()) as $v) {
            if (Geo::distanciaM($lat, $lon, (float) $v['lat'], (float) $v['lon']) <= $raio) {
                $entregue++;
            }
        }
        return ['ok' => true, 'seq' => $seq, 'entregue_a' => $entregue];
    }

    /**
     * @param array<string, mixed> $drone
     * @return array<string, mixed>
     */
    private function sair(array $drone): array
    {
        $this->repo()->removeDrone((string) $drone['id']);
        return ['ok' => true];
    }

    // ---------------------------------------------------------------- apoio

    /** @return array<string, mixed> */
    private function droneAutenticado(?string $token): array
    {
        if ($token === null || !preg_match('/^[0-9a-f]{64}$/', $token)) {
            throw new ErroApi(401, 'token', 'Token ausente ou inválido.');
        }
        $hash = hash('sha256', $token);
        $drone = $this->repo()->droneDoToken($hash);
        if ($drone === null || !hash_equals((string) $drone['token_hash'], $hash)) {
            throw new ErroApi(401, 'token', 'Token inválido ou vencido: entre de novo.');
        }
        if ((int) $drone['atualizado'] < $this->agora - $this->validadeMs()) {
            $this->repo()->removeDrone((string) $drone['id']);
            throw new ErroApi(401, 'token', 'Token vencido (30 s sem atualizar): entre de novo.');
        }
        return $drone;
    }

    private function tokenDoCabecalho(): ?string
    {
        $cab = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? null;
        if ($cab === null && function_exists('getallheaders')) {
            foreach (getallheaders() as $nome => $valor) {
                if (strcasecmp($nome, 'Authorization') === 0) {
                    $cab = $valor;
                }
            }
        }
        if (!is_string($cab) || !preg_match('/^\s*Bearer\s+(\S+)\s*$/i', $cab, $m)) {
            return null;
        }
        return strtolower($m[1]);
    }

    private function ipCliente(): string
    {
        if (!empty($this->config['confiar_proxy']) && !empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
            $partes = explode(',', (string) $_SERVER['HTTP_X_FORWARDED_FOR']);
            return substr(trim($partes[0]), 0, 45);
        }
        return substr((string) ($_SERVER['REMOTE_ADDR'] ?? '0.0.0.0'), 0, 45);
    }

    private function limpezaOcasional(): void
    {
        if (random_int(1, 20) !== 1) {
            return;
        }
        $this->repo()->limpa(
            $this->agora - $this->validadeMs(),
            $this->agora - (int) $this->config['eventos_validade_s'] * 1000,
            $this->agora - 120000
        );
    }

    private static function faixaBateria(mixed $valor): ?string
    {
        if ($valor === null) {
            return null;
        }
        $v = (int) $valor;
        return $v >= 50 ? 'alta' : ($v >= 20 ? 'media' : 'baixa');
    }

    private function raio(): int
    {
        return (int) $this->config['raio_m'];
    }

    private function validadeMs(): int
    {
        return (int) $this->config['validade_token_s'] * 1000;
    }

    private function repo(): Repositorio
    {
        return $this->repo ??= new Repositorio(
            (string) $this->config['dsn'],
            (string) ($this->config['usuario'] ?? ''),
            (string) ($this->config['senha'] ?? '')
        );
    }

    /** @param array<string, mixed> $dados */
    private function responde(int $status, array $dados): void
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        header('Cache-Control: no-store');
        echo json_encode($dados, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }
}
