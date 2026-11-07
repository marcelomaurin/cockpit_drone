<?php
declare(strict_types=1);

/**
 * Ponto de entrada compatível com o mundo compartilhado do Simulador Cockpit Drone.
 * Protocolo: GET/POST status, entrar, atualizar, evento, sair.
 * Reutiliza a infraestrutura de storage e sessões do Cockpit Drone (storage.php).
 */

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');

function api_reply(int $code, array $data): never {
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}

function api_body(): array {
    $raw = file_get_contents('php://input', false, null, 0, 65536);
    if ($raw === false || strlen($raw) === 0) {
        return [];
    }
    $v = json_decode($raw, true);
    if (!is_array($v)) {
        api_reply(400, ['ok' => false, 'erro' => 'json', 'mensagem' => 'JSON inválido.']);
    }
    return $v;
}

try {
    $configFile = __DIR__ . '/config.php';
    if (!is_file($configFile)) {
        $configFile = __DIR__ . '/config_sample.php';
    }
    if (!is_file($configFile)) {
        api_reply(503, ['ok' => false, 'erro' => 'config', 'mensagem' => 'Configuração não encontrada.']);
    }

    $config = require $configFile;
    if (!is_array($config)) {
        api_reply(500, ['ok' => false, 'erro' => 'config', 'mensagem' => 'Configuração inválida.']);
    }

    require_once __DIR__ . '/storage.php';
    $store = createStore($config);

    $metodo = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    $dados = ($metodo === 'POST') ? api_body() : [];
    $acao = is_string($dados['acao'] ?? null) ? $dados['acao'] : ($_GET['acao'] ?? 'status');

    $raio = (int)($config['radius_m'] ?? 2000);
    $intervalo = 500;
    $ttl = (int)($config['session_ttl'] ?? 120);

    // 1. Ação STATUS
    if ($acao === 'status' || ($metodo === 'GET' && empty($dados))) {
        api_reply(200, [
            'ok' => true,
            'versao' => 1,
            'raio_m' => $raio,
            'intervalo_ms' => $intervalo
        ]);
    }

    if ($metodo !== 'POST') {
        api_reply(405, ['ok' => false, 'erro' => 'metodo', 'mensagem' => 'Use POST com corpo JSON.']);
    }

    // 2. Ação ENTRAR
    if ($acao === 'entrar') {
        $ip = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
        $maxSessions = (int)($config['max_active_sessions'] ?? 100);
        $rateLimit = (int)($config['rate_limit_per_minute'] ?? 15);

        $activeSessions = count($store->sessions());
        if ($activeSessions >= $maxSessions) {
            api_reply(503, [
                'ok' => false,
                'erro' => 'max_sessions',
                'mensagem' => 'Capacidade máxima de sessões ativas atingida.'
            ]);
        }

        $ipHash = hash('sha256', 'ip_' . $ip);
        $rateKey = 'ratelimit_' . $ipHash;
        $rateData = $store->get($rateKey) ?? ['count' => 0, 'window' => time()];
        if (time() - ($rateData['window'] ?? 0) < 60) {
            if (($rateData['count'] ?? 0) >= $rateLimit) {
                api_reply(429, [
                    'ok' => false,
                    'erro' => 'rate_limit',
                    'mensagem' => 'Muitas tentativas de conexão. Aguarde 1 minuto.'
                ]);
            }
            $rateData['count'] = ($rateData['count'] ?? 0) + 1;
        } else {
            $rateData = ['count' => 1, 'window' => time()];
        }
        $store->put($rateKey, $rateData, 60);

        $apelido = trim((string)($dados['apelido'] ?? 'Piloto'));
        if ($apelido === '') $apelido = 'Piloto';
        $apelido = mb_substr($apelido, 0, 40);

        $modelo = trim((string)($dados['modelo'] ?? 'drone'));
        if ($modelo === '') $modelo = 'drone';
        $modelo = mb_substr($modelo, 0, 40);

        $pos = $dados['posicao'] ?? [];
        $lat = isset($pos['lat']) && is_numeric($pos['lat']) ? (float)$pos['lat'] : null;
        $lon = isset($pos['lon']) && is_numeric($pos['lon']) ? (float)$pos['lon'] : null;
        $alt = isset($pos['alt']) && is_numeric($pos['alt']) ? (float)$pos['alt'] : 0.0;

        $token = bin2hex(random_bytes(32));
        $key = hash('sha256', $token);
        $id = substr($key, 0, 16);

        $sessao = [
            'id' => $id,
            'key' => $key,
            'apelido' => $apelido,
            'modelo' => $modelo,
            'lat' => $lat,
            'lon' => $lon,
            'alt' => $alt,
            'rumo' => 0.0,
            'velocidade' => 0.0,
            'estado' => 'parado',
            'bateria' => null,
            'telemetry' => [
                'apelido' => $apelido,
                'modelo' => $modelo,
                'lat' => $lat,
                'lon' => $lon,
                'alt' => $alt,
                'rumo' => 0.0,
                'velocidade' => 0.0,
                'estado' => 'parado',
            ],
            'updated_at' => time()
        ];
        $store->put($key, $sessao, $ttl);

        api_reply(200, [
            'ok' => true,
            'token' => $token,
            'id' => $id,
            'raio_m' => $raio,
            'intervalo_ms' => $intervalo,
            'ultimo_evento' => 0
        ]);
    }

    // Ações autenticadas (requerem Bearer token)
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/^Bearer\s+([a-f0-9]{64})$/i', $auth, $m)) {
        api_reply(401, ['ok' => false, 'erro' => 'token', 'mensagem' => 'Cabeçalho Authorization com token Bearer obrigatório.']);
    }

    $key = hash('sha256', strtolower($m[1]));
    $self = $store->get($key);
    if ($self === null) {
        api_reply(401, ['ok' => false, 'erro' => 'token_invalido', 'mensagem' => 'Token expirado ou inválido.']);
    }

    // 3. Ação SAIR
    if ($acao === 'sair') {
        $store->remove($key);
        api_reply(200, ['ok' => true]);
    }

    // 4. Ação EVENTO
    if ($acao === 'evento') {
        $tipo = trim((string)($dados['tipo'] ?? 'mensagem'));
        if (!in_array($tipo, ['mensagem', 'sinal', 'marcador'], true)) {
            $tipo = 'mensagem';
        }
        $conteudo = $dados['conteudo'] ?? '';

        $eventoData = [
            'type' => $tipo,
            'tipo' => $tipo,
            'apelido' => $self['apelido'] ?? 'Piloto',
            'sender_id' => $self['id'],
            'conteudo' => $conteudo,
            'lat' => $self['lat'],
            'lon' => $self['lon']
        ];
        $eventId = $store->appendEvent($key, $eventoData);
        api_reply(200, ['ok' => true, 'id' => $eventId]);
    }

    // 5. Ação ATUALIZAR
    if ($acao === 'atualizar') {
        $pos = $dados['posicao'] ?? [];
        if (isset($pos['lat'], $pos['lon']) && is_numeric($pos['lat']) && is_numeric($pos['lon'])) {
            $self['lat'] = (float)$pos['lat'];
            $self['lon'] = (float)$pos['lon'];
        }
        if (isset($pos['alt']) && is_numeric($pos['alt'])) {
            $self['alt'] = (float)$pos['alt'];
        }
        if (isset($dados['rumo']) && is_numeric($dados['rumo'])) {
            $self['rumo'] = (float)$dados['rumo'];
        }
        if (isset($dados['velocidade']) && is_numeric($dados['velocidade'])) {
            $self['velocidade'] = (float)$dados['velocidade'];
        }
        if (isset($dados['estado']) && is_string($dados['estado'])) {
            $self['estado'] = mb_substr($dados['estado'], 0, 20);
        }
        if (isset($dados['bateria']) && is_numeric($dados['bateria'])) {
            $self['bateria'] = (float)$dados['bateria'];
        }

        $self['telemetry']['lat'] = $self['lat'];
        $self['telemetry']['lon'] = $self['lon'];
        $self['telemetry']['alt'] = $self['alt'] ?? 0.0;
        $self['telemetry']['rumo'] = $self['rumo'] ?? 0.0;
        $self['telemetry']['velocidade'] = $self['velocidade'] ?? 0.0;
        $self['telemetry']['estado'] = $self['estado'] ?? 'voando';
        $self['telemetry']['bateria'] = $self['bateria'] ?? null;
        $self['telemetry']['apelido'] = $self['apelido'] ?? 'Piloto';
        $self['telemetry']['modelo'] = $self['modelo'] ?? 'drone';
        $self['updated_at'] = time();

        $store->put($key, $self, $ttl);

        // Vizinhos dentro do raio
        $vizinhos = [];
        if ($self['lat'] !== null && $self['lon'] !== null) {
            foreach ($store->sessions() as $other) {
                if (($other['key'] ?? '') === $key || !isset($other['lat'], $other['lon'])) {
                    continue;
                }
                $d = distance($self['lat'], $self['lon'], (float)$other['lat'], (float)$other['lon']);
                if ($d <= (float)$raio) {
                    $otherApelido = $other['apelido'] ?? ($other['telemetry']['apelido'] ?? substr($other['id'], 0, 8));
                    $otherModelo = $other['modelo'] ?? ($other['telemetry']['modelo'] ?? 'drone');
                    $otherAlt = (float)($other['alt'] ?? ($other['telemetry']['alt'] ?? 0.0));
                    $otherRumo = (float)($other['rumo'] ?? ($other['telemetry']['rumo'] ?? 0.0));
                    $otherVel = (float)($other['velocidade'] ?? ($other['telemetry']['velocidade'] ?? 0.0));
                    $otherEstado = (string)($other['estado'] ?? ($other['telemetry']['estado'] ?? 'voando'));

                    $vizinhos[] = [
                        'id' => $other['id'],
                        'apelido' => $otherApelido,
                        'modelo' => $otherModelo,
                        'posicao' => [
                            'lat' => (float)$other['lat'],
                            'lon' => (float)$other['lon'],
                            'alt' => round($otherAlt, 1)
                        ],
                        'rumo' => round($otherRumo, 1),
                        'velocidade' => round($otherVel, 1),
                        'estado' => $otherEstado,
                        'distancia_m' => round($d, 1)
                    ];
                }
            }
        }

        // Eventos novos
        $ultimoEvento = (int)($dados['ultimo_evento'] ?? 0);
        $eventos = [];
        if ($self['lat'] !== null && $self['lon'] !== null) {
            foreach ($store->events($ultimoEvento) as $ev) {
                if (($ev['sender'] ?? '') === $key) {
                    continue;
                }
                $evData = $ev['data'] ?? [];
                if (isset($evData['lat'], $evData['lon'])) {
                    $dEv = distance($self['lat'], $self['lon'], (float)$evData['lat'], (float)$evData['lon']);
                    if ($dEv > (float)$raio) {
                        continue;
                    }
                }
                $eventos[] = [
                    'seq' => (int)$ev['id'],
                    'tipo' => $evData['tipo'] ?? ($evData['type'] ?? 'mensagem'),
                    'apelido' => $evData['apelido'] ?? 'Outro',
                    'conteudo' => $evData['conteudo'] ?? ($evData['content'] ?? '')
                ];
            }
        }

        api_reply(200, [
            'ok' => true,
            'vizinhos' => $vizinhos,
            'eventos' => $eventos
        ]);
    }

    api_reply(400, ['ok' => false, 'erro' => 'acao', 'mensagem' => 'Ação desconhecida: ' . $acao]);

} catch (Throwable $e) {
    error_log('api.php error: ' . $e->getMessage());
    api_reply(500, ['ok' => false, 'erro' => 'interno', 'mensagem' => 'Erro interno do servidor.']);
}
