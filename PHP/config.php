<?php
declare(strict_types=1);
/* Copy this file and configure storage. Keep it outside public access if possible. */
return [
    'storage' => getenv('DRONE_STORAGE') ?: 'files', // files | mysql | apcu
    'radius_m' => 2000,
    'session_ttl' => 120,
    'data_dir' => getenv('DRONE_DATA_DIR') ?: dirname(__DIR__) . '/drone-private-data',
    'mysql' => [
        'dsn' => getenv('DRONE_MYSQL_DSN') ?: 'mysql:host=localhost;dbname=drone;charset=utf8mb4',
        'user' => getenv('DRONE_MYSQL_USER') ?: '',
        'password' => getenv('DRONE_MYSQL_PASSWORD') ?: '',
    ],
];
