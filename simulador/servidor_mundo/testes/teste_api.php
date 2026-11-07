<?php
/**
 * Testes do servidor de mundo compartilhado (sem PHPUnit).
 * Uso: php testes/teste_api.php     -> código de saída 0 = tudo certo
 */
declare(strict_types=1);

require __DIR__ . '/../src/autoload.php';

use MundoDrone\Api;
use MundoDrone\ErroApi;
use MundoDrone\Geo;

$config = (require __DIR__ . '/../config.exemplo.php');
$config['dsn'] = 'sqlite::memory:';

$falhas = 0;
$total = 0;
function confere(bool $condicao, string $descricao): void
{
    global $falhas, $total;
    $total++;
    if ($condicao) {
        echo "  ok    $descricao\n";
    } else {
        $falhas++;
        echo "  FALHA $descricao\n";
    }
}

/** Chama a API; devolve [status, resposta]. */
function chama(Api $api, array $dados, ?string $token = null, string $ip = '10.0.0.1'): array
{
    try {
        return [200, $api->executa($dados, $token, $ip)];
    } catch (ErroApi $e) {
        return [$e->status, ['ok' => false, 'erro' => $e->codigo, 'mensagem' => $e->getMessage()]];
    }
}

/** Ponto a $metros ao norte de (lat, lon). */
function aoNorte(float $lat, float $lon, float $metros): array
{
    return [$lat + $metros / Geo::METROS_POR_GRAU_LAT, $lon];
}

$api = new Api($config);
$t = 1_800_000_000_000;
$api->defineAgora($t);
$lat0 = -21.1767;
$lon0 = -47.8208;

echo "Entrada e token\n";
[$st, $a] = chama($api, ['versao' => 1, 'acao' => 'entrar', 'apelido' => 'Ana', 'modelo' => 'tello',
    'posicao' => ['lat' => $lat0, 'lon' => $lon0, 'alt' => 0]], null, '10.0.0.1');
confere($st === 200 && $a['ok'] === true, 'entrar sem usuário e senha');
confere(preg_match('/^[0-9a-f]{64}$/', $a['token'] ?? '') === 1, 'token de 64 caracteres hexadecimais');
confere($a['raio_m'] === 2000, 'raio informado é 2000 m');
$tokA = $a['token'];
$idA = $a['id'];

// O banco guarda só o hash.
$ref = new ReflectionClass($api);
$prop = $ref->getProperty('repo');
$prop->setAccessible(true);
$pdo = $prop->getValue($api)->pdo();
$linha = $pdo->query("SELECT token_hash FROM drones WHERE id = '$idA'")->fetch();
confere($linha['token_hash'] === hash('sha256', $tokA) && $linha['token_hash'] !== $tokA, 'banco guarda só o hash do token');
confere((int) $pdo->query("SELECT COUNT(*) FROM drones WHERE token_hash = '$tokA'")->fetchColumn() === 0, 'token em claro não está no banco');

[$latB, $lonB] = aoNorte($lat0, $lon0, 1990);
[$st, $b] = chama($api, ['acao' => 'entrar', 'apelido' => 'Bruno', 'modelo' => 'ardrone',
    'posicao' => ['lat' => $latB, 'lon' => $lonB, 'alt' => 0]], null, '10.0.0.2');
$tokB = $b['token'];
$idB = $b['id'];
[$latC, $lonC] = aoNorte($lat0, $lon0, 2010);
[$st, $c] = chama($api, ['acao' => 'entrar', 'apelido' => 'Carla', 'modelo' => 'mavlink',
    'posicao' => ['lat' => $latC, 'lon' => $lonC, 'alt' => 0]], null, '10.0.0.3');
$tokC = $c['token'];
$idC = $c['id'];

echo "Filtro de 2 km\n";
$t += 600;
$api->defineAgora($t);
$upd = fn(float $la, float $lo, int $ult = 0) => ['acao' => 'atualizar',
    'posicao' => ['lat' => $la, 'lon' => $lo, 'alt' => 20.0], 'rumo' => 90, 'velocidade' => 3.5,
    'estado' => 'voando', 'bateria' => 80, 'ultimo_evento' => $ult];
chama($api, $upd($latB, $lonB), $tokB, '10.0.0.2');
chama($api, $upd($latC, $lonC), $tokC, '10.0.0.3');
[$st, $r] = chama($api, $upd($lat0, $lon0), $tokA);
$ids = array_column($r['vizinhos'], 'id');
confere($st === 200, 'atualizar com token válido');
confere(in_array($idB, $ids, true), 'drone a 1.990 m aparece');
confere(!in_array($idC, $ids, true), 'drone a 2.010 m não aparece');
confere(!in_array($idA, $ids, true), 'o próprio drone não aparece na lista');
$json = json_encode($r);
confere(!str_contains($json, $idC) && !str_contains($json, 'Carla'), 'nenhum campo revela o drone fora do círculo');
confere(!isset($r['total']) && !isset($r['contagem']), 'resposta não informa contagem de usuários');
confere(($r['vizinhos'][0]['bateria'] ?? '') === 'alta', 'bateria repassada só como faixa');
confere(abs($r['vizinhos'][0]['distancia_m'] - 1990) <= 2, 'distância informada (1.990 m)');

echo "Token é a única prova de identidade\n";
$t += 600;
$api->defineAgora($t);
$antes = $pdo->query("SELECT lat FROM drones WHERE id = '$idB'")->fetchColumn();
$corpo = $upd($lat0 + 0.0001, $lon0);
$corpo['id'] = $idB;   // tentativa de falar pelo drone B
[$st, $r] = chama($api, $corpo, $tokA);
$depois = $pdo->query("SELECT lat FROM drones WHERE id = '$idB'")->fetchColumn();
confere($antes == $depois, 'id alheio no corpo é ignorado: B não se move');
[$st, $r] = chama($api, $upd($lat0, $lon0), str_repeat('a', 64));
confere($st === 401, 'token desconhecido responde 401');
[$st, $r] = chama($api, $upd($lat0, $lon0), null);
confere($st === 401, 'sem token responde 401');

echo "Eventos só dentro de 2 km\n";
$t += 1100;
$api->defineAgora($t);
chama($api, $upd($lat0, $lon0), $tokA);   // A volta ao ponto inicial (C fica a 2.010 m)
[$st, $e] = chama($api, ['acao' => 'evento', 'tipo' => 'mensagem', 'conteudo' => 'Bom voo!'], $tokA);
confere($st === 200 && $e['entregue_a'] === 1, 'mensagem entregue a 1 vizinho');
$t += 600;
$api->defineAgora($t);
[$st, $rb] = chama($api, $upd($latB, $lonB), $tokB, '10.0.0.2');
[$st, $rc] = chama($api, $upd($latC, $lonC), $tokC, '10.0.0.3');
confere(count($rb['eventos']) === 1 && $rb['eventos'][0]['conteudo'] === 'Bom voo!', 'B (1.990 m) recebe a mensagem');
confere(count($rc['eventos']) === 0, 'C (2.010 m) não recebe a mensagem');
$seq = $rb['eventos'][0]['seq'];
$t += 600;
$api->defineAgora($t);
[$st, $rb2] = chama($api, $upd($latB, $lonB, $seq), $tokB, '10.0.0.2');
confere(count($rb2['eventos']) === 0, 'evento já lido não volta (ultimo_evento)');
[$st, $m] = chama($api, ['acao' => 'evento', 'tipo' => 'marcador',
    'conteudo' => ['lat' => $latC, 'lon' => $lonC, 'rotulo' => 'longe']], $tokA);
confere($st === 400, 'marcador fora de 2 km é recusado');

echo "Limites\n";
[$st] = chama($api, ['acao' => 'evento', 'tipo' => 'sinal', 'conteudo' => 'luzes'], $tokA);
confere($st === 429, 'segundo evento no mesmo segundo responde 429');
$t += 1000 - ($t % 1000);
$api->defineAgora($t);
$codigos = [];
for ($i = 0; $i < 6; $i++) {
    [$codigos[]] = chama($api, $upd($lat0, $lon0), $tokA);
}
confere(in_array(429, $codigos, true) && $codigos[0] === 200, 'mais de 4 atualizações por segundo responde 429');
$t += 2000;
$api->defineAgora($t);
[$st, $r] = chama($api, $upd($lat0 + 0.05, $lon0), $tokA);  // ~5,5 km em 2 s
confere($st === 400 && $r['erro'] === 'salto', 'salto de posição (teletransporte) é recusado');
[$st, $r] = chama($api, ['acao' => 'entrar', 'apelido' => 'x', 'modelo' => 'tello',
    'posicao' => ['lat' => $lat0, 'lon' => $lon0]], null, '10.0.0.9');
confere($st === 400 && $r['erro'] === 'apelido', 'apelido curto é recusado');
[$st, $r] = chama($api, ['acao' => 'entrar', 'apelido' => 'Zeca', 'modelo' => 'tello',
    'posicao' => ['lat' => 95, 'lon' => $lon0]], null, '10.0.0.9');
confere($st === 400 && $r['erro'] === 'lat', 'latitude fora do limite é recusada');
$cods = [];
for ($i = 0; $i < 7; $i++) {
    [$cods[]] = chama($api, ['acao' => 'entrar', 'apelido' => 'Ip' . $i, 'modelo' => 'tello',
        'posicao' => ['lat' => $lat0, 'lon' => $lon0]], null, '10.0.0.50');
}
confere($cods[4] === 200 && $cods[5] === 429, 'no máximo 5 drones ativos por endereço');

echo "Validade e saída\n";
$t += 31000;
$api->defineAgora($t);
[$st, $r] = chama($api, $upd($latB, $lonB), $tokB, '10.0.0.2');
confere($st === 401, 'token vence após 30 s sem atualizar');
[$st, $r] = chama($api, ['acao' => 'sair'], $tokC, '10.0.0.3');
confere($st === 401, 'token vencido também não sai (já foi removido)');
$api->defineAgora($t);
[$st, $n] = chama($api, ['acao' => 'entrar', 'apelido' => 'Davi', 'modelo' => 'tello',
    'posicao' => ['lat' => $lat0, 'lon' => $lon0]], null, '10.0.0.4');
[$st, $r] = chama($api, ['acao' => 'sair'], $n['token'], '10.0.0.4');
confere($st === 200, 'sair com token válido');
[$st, $r] = chama($api, $upd($lat0, $lon0), $n['token'], '10.0.0.4');
confere($st === 401, 'depois de sair o token não vale mais');
[$st, $s] = chama($api, ['acao' => 'status'], null);
confere($st === 200 && array_keys($s) === ['ok', 'versao', 'raio_m', 'intervalo_ms'], 'status não revela drones');

echo "\n$total verificações, $falhas falhas\n";
exit($falhas === 0 ? 0 : 1);
