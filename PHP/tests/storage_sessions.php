<?php
declare(strict_types=1);
/**
 * Teste local do armazenamento em arquivos (não precisa de servidor):
 *   php PHP/tests/storage_sessions.php
 * Os registros do limitador de conexões ficam no mesmo armazenamento das
 * sessões; sessions() deve devolver só sessões de pilotos.
 */
require __DIR__ . '/../storage.php';

$falhas = 0;
function confere(bool $ok, string $nome): void {
    global $falhas;
    echo ($ok ? 'OK    ' : 'FALHA ') . $nome . "\n";
    if (!$ok) $falhas++;
}

$dir = sys_get_temp_dir() . '/drone_teste_' . bin2hex(random_bytes(4));
$store = createStore(['storage' => 'files', 'data_dir' => $dir]);

$store->put('ratelimit_' . hash('sha256', 'ip_127.0.0.1'), ['count' => 3, 'window' => time()], 60);
$k = hash('sha256', 'ficha');
$store->put($k, ['id' => substr($k, 0, 16), 'key' => $k, 'lat' => null, 'lon' => null, 'telemetry' => []], 60);

$s = $store->sessions();
confere(count($s) === 1, 'registro do limitador não conta como sessão');
confere(($s[0]['key'] ?? '') === $k, 'a sessão do piloto é listada');
confere(($store->get('ratelimit_' . hash('sha256', 'ip_127.0.0.1'))['count'] ?? 0) === 3,
    'registro do limitador continua legível pelo get()');

foreach (glob($dir . '/*') ?: [] as $p) @unlink($p);
@rmdir($dir);
exit($falhas > 0 ? 1 : 0);
