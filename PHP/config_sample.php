<?php
declare(strict_types=1);
/* Copy this file and configure storage. Keep it outside public access if possible. */
return [
    'storage' => getenv('DRONE_STORAGE') ?: 'files', // files | mysql | apcu
    'ws_listen' => getenv('DRONE_WS_LISTEN') ?: '127.0.0.1:8081',
    'ws_origins' => array_values(array_filter(explode(',', getenv('DRONE_WS_ORIGINS') ?: ''))),
    'radius_m' => 2000,
    'max_active_sessions' => 100,
    'rate_limit_per_minute' => 15,
    'session_ttl' => 120,
    'data_dir' => getenv('DRONE_DATA_DIR') ?: dirname(__DIR__, 2) . '/drone-private-data',
    'mysql' => [
        'dsn' => getenv('DRONE_MYSQL_DSN') ?: 'mysql:host=localhost;dbname=drone;charset=utf8mb4',
        'user' => getenv('DRONE_MYSQL_USER') ?: '',
        'password' => getenv('DRONE_MYSQL_PASSWORD') ?: '',
    ],
];
