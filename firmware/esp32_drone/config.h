// =====================================================================
//  Configuração do firmware do drone ESP32 (Cockpit Drone)
//  Ajuste pinos, sentidos dos eixos e ganhos para o SEU quadro.
//  Leia o README.md antes do primeiro voo (teste SEM hélices).
// =====================================================================
#pragma once

// ---------------- Rede ----------------
#define WIFI_PREFIXO_SSID   "CockpitDrone-"   // + 4 dígitos do MAC
#define WIFI_SENHA          "cockpit123"      // mínimo 8 caracteres
#define WIFI_CANAL          6
#define UDP_PORTA           4210

// ---------------- Motores (escovados, via MOSFET) ----------------
// Disposição em X, vista de cima, frente para cima:
//
//      M4 (FE, horário)      M1 (FD, anti-horário)
//                  \        /
//                   [ ESP32 ]
//                  /        \
//      M3 (TE, anti-horário) M2 (TD, horário)
//
// Pinos padrão do ESP-Drone (ESP32-S2/S3). Ajuste para a sua placa.
#define PINO_M1   5
#define PINO_M2   6
#define PINO_M3   3
#define PINO_M4   4

#define PWM_FREQ_HZ       20000   // 20 kHz: fora da faixa audível
#define PWM_RESOLUCAO     10      // 0..1023

// Aceleração mínima com o drone armado (mantém as hélices girando).
#define MOTOR_MARCHA_LENTA  60    // em 0..1000

// ---------------- Sensor MPU6050 (I2C) ----------------
#define PINO_SDA   11
#define PINO_SCL   10
#define MPU_ENDERECO 0x68

// Sentido dos eixos: troque para -1 o eixo que estiver invertido
// (veja "Teste de sinais" no README).
#define SINAL_GIRO_ROLAGEM    1
#define SINAL_GIRO_ARFAGEM    1
#define SINAL_GIRO_GUINADA    1
#define SINAL_ACEL_X          1
#define SINAL_ACEL_Y          1

// ---------------- Bateria ----------------
#define PINO_BATERIA          2      // ADC com divisor resistivo
#define DIVISOR_BATERIA       2.0f   // (R1+R2)/R2 — 100k/100k = 2.0
#define BATERIA_BAIXA_MV      3500   // alerta
#define BATERIA_MINIMA_MV     3300   // não arma abaixo disto
#define BATERIA_CRITICA_MV    3200   // em voo: limita a aceleração

// ---------------- LED de estado ----------------
#define PINO_LED              8
#define LED_ATIVO_ALTO        1

// ---------------- Controle ----------------
#define FREQ_LACO_HZ          500
#define ANGULO_MAXIMO_GRAUS   25.0f   // inclinação máxima pedida pelo manche
#define GUINADA_MAX_GRAUS_S   180.0f
#define ANGULO_CORTE_GRAUS    70.0f   // capotou: corta os motores
#define ANGULO_ARMAR_GRAUS    25.0f   // inclinado demais: não arma
#define ACELERADOR_ARMAR_MAX  50      // aceleração máxima para armar (0..1000)

#define FILTRO_COMPLEMENTAR   0.996f  // peso do giroscópio

// PID do ângulo (graus -> graus/s)
#define KP_ANGULO             4.5f

// PID da velocidade angular (graus/s -> saída do misturador, 0..1000)
#define KP_TAXA_RP            0.9f
#define KI_TAXA_RP            1.5f
#define KD_TAXA_RP            0.025f
#define KP_TAXA_Y             2.0f
#define KI_TAXA_Y             1.0f
#define LIMITE_I              150.0f
#define LIMITE_SAIDA_PID      400.0f

// ---------------- Segurança da ligação ----------------
#define TEMPO_PERDA_SINAL_MS  500
#define TEMPO_DESCIDA_MS      2000
#define TELEMETRIA_HZ         10
