<?php
/**
 * Configuração do servidor de mundo compartilhado.
 * Copie para config.php (mesma pasta) e ajuste. O config.php não vai para o git.
 */
return [
    // MySQL/MariaDB:
    //   'dsn' => 'mysql:host=localhost;dbname=mundo_drone;charset=utf8mb4',
    // SQLite (testes locais; a pasta precisa ser gravável pelo PHP):
    'dsn' => 'sqlite:' . __DIR__ . '/dados/mundo.sqlite',
    'usuario' => '',
    'senha' => '',

    // Regras do mundo (o cliente não pode mudar).
    'raio_m' => 2000,
    'validade_token_s' => 30,
    'intervalo_ms' => 500,
    'eventos_validade_s' => 60,

    // Limites (veja docs/protocolo_mundo.md).
    'limite_atualizar_por_s' => 4,
    'limite_entradas_por_min_ip' => 10,
    'limite_drones_por_ip' => 5,
    'limite_eventos_por_s' => 1,
    'velocidade_max_ms' => 60,

    // true somente atrás de um proxy reverso confiável que envia X-Forwarded-For.
    'confiar_proxy' => false,
];
