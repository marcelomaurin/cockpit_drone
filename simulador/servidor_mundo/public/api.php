<?php
/**
 * Ponto de entrada único do servidor de mundo compartilhado.
 * Somente esta pasta (public/) deve ficar exposta no servidor web.
 */
declare(strict_types=1);

require __DIR__ . '/../src/autoload.php';

use MundoDrone\Api;

$arquivoConfig = __DIR__ . '/../config.php';
if (!is_file($arquivoConfig)) {
    $arquivoConfig = __DIR__ . '/../config.exemplo.php';
}
$config = require $arquivoConfig;

(new Api($config))->atende();
