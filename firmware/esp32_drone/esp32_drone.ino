// =====================================================================
//  Firmware do drone ESP32 — Cockpit Drone (protocolo CDP v1)
//
//  Placa:   ESP32 / ESP32-S2 / ESP32-S3 (núcleo Arduino-ESP32 2.x ou 3.x)
//  Sensor:  MPU6050 (I2C)
//  Motores: 4 motores escovados (coreless) acionados por MOSFET + PWM
//  Ligação: Wi-Fi em modo ponto de acesso, UDP 4210 (veja PROTOCOLO.md)
//
//  Modo de voo: ângulo (auto-nivelamento) na rolagem/arfagem e velocidade
//  angular na guinada. Sem barômetro: a altura é controlada pelo piloto.
//
//  SEGURANÇA: faça o primeiro teste SEM HÉLICES. Confira os sentidos dos
//  eixos e dos motores conforme o README.md antes de voar.
// =====================================================================
#include <WiFi.h>
#include <WiFiUdp.h>
#include <Wire.h>
#include <Preferences.h>
#include <esp_wifi.h>
#include "config.h"

// ---------------- Protocolo ----------------
static const uint8_t CDP_MAGIA0 = 0x43;
static const uint8_t CDP_MAGIA1 = 0x44;
static const uint8_t CDP_VERSAO = 1;
static const uint8_t CDP_CONTROLE = 0x01;
static const uint8_t CDP_CALIBRAR = 0x02;
static const uint8_t CDP_TELEMETRIA = 0x81;
static const size_t  CDP_CABECALHO = 6;
static const size_t  CDP_CRC = 2;

static const uint8_t SINAL_ARMAR = 0x01;
static const uint8_t SINAL_CORTE = 0x02;

enum Estado : uint8_t {
  DESARMADO = 0, ARMADO = 1, PERDA_SINAL = 2, CORTE = 3, CALIBRANDO = 4, ERRO_SENSOR = 5
};

static const uint8_t ALERTA_BATERIA_BAIXA = 0x01;
static const uint8_t ALERTA_SENSOR_OK     = 0x02;
static const uint8_t ALERTA_ACEL_TRAVADO  = 0x04;
static const uint8_t ALERTA_INCLINADO     = 0x08;

// ---------------- Estado global ----------------
WiFiUDP udp;
Preferences prefs;

Estado estado = DESARMADO;
bool sensorOk = false;
bool travaCorte = false;          // corte ativo até soltar corte e armar

// Comando recebido
int16_t cmdRolagem = 0, cmdArfagem = 0, cmdGuinada = 0;
uint16_t cmdAcel = 0;
uint8_t cmdSinais = 0;
uint32_t ultimoControleMs = 0;
uint16_t seqTx = 0;
IPAddress ipCockpit;
uint16_t portaCockpit = 0;
bool temCockpit = false;
uint32_t contControle = 0, taxaControle = 0;

// Sensor e atitude
float biasGx = 0, biasGy = 0, biasGz = 0;
float trimRolagem = 0, trimArfagem = 0;
float angRolagem = 0, angArfagem = 0, angGuinada = 0;
float taxaRolagem = 0, taxaArfagem = 0, taxaGuinada = 0;

// PID
struct Pid {
  float kp, ki, kd;
  float integral = 0, erroAnterior = 0;
  void zera() { integral = 0; erroAnterior = 0; }
  float calcula(float erro, float dt) {
    integral += erro * dt * ki;
    integral = constrain(integral, -LIMITE_I, LIMITE_I);
    float d = (dt > 0) ? (erro - erroAnterior) / dt : 0;
    erroAnterior = erro;
    return constrain(kp * erro + integral + kd * d, -LIMITE_SAIDA_PID, LIMITE_SAIDA_PID);
  }
};
Pid pidRolagem{KP_TAXA_RP, KI_TAXA_RP, KD_TAXA_RP};
Pid pidArfagem{KP_TAXA_RP, KI_TAXA_RP, KD_TAXA_RP};
Pid pidGuinada{KP_TAXA_Y, KI_TAXA_Y, 0};

// Saída
uint16_t acelAplicada = 0;
float fatorDescida = 1.0f;        // 1 -> 0 durante a perda de sinal
uint32_t inicioPerdaMs = 0;
uint16_t bateriaMv = 0;
uint32_t contLaco = 0, taxaLaco = 0;

// ---------------- CRC-16/CCITT-FALSE ----------------
uint16_t crc16(const uint8_t *d, size_t n) {
  uint16_t crc = 0xFFFF;
  while (n--) {
    crc ^= (uint16_t)(*d++) << 8;
    for (int i = 0; i < 8; i++)
      crc = (crc & 0x8000) ? (crc << 1) ^ 0x1021 : (crc << 1);
  }
  return crc;
}

static inline int16_t le16s(const uint8_t *p) { return (int16_t)(p[0] | (p[1] << 8)); }
static inline uint16_t le16u(const uint8_t *p) { return (uint16_t)(p[0] | (p[1] << 8)); }
static inline void pe16(uint8_t *p, uint16_t v) { p[0] = v & 0xFF; p[1] = v >> 8; }

// ---------------- Motores ----------------
const uint8_t pinosMotor[4] = {PINO_M1, PINO_M2, PINO_M3, PINO_M4};

void motoresInicia() {
  for (int i = 0; i < 4; i++) {
#if ESP_ARDUINO_VERSION_MAJOR >= 3
    ledcAttach(pinosMotor[i], PWM_FREQ_HZ, PWM_RESOLUCAO);
#else
    ledcSetup(i, PWM_FREQ_HZ, PWM_RESOLUCAO);
    ledcAttachPin(pinosMotor[i], i);
#endif
  }
}

void motorEscreve(int i, uint16_t valor0a1000) {
  const uint32_t maximo = (1u << PWM_RESOLUCAO) - 1;
  uint32_t duty = (uint32_t)valor0a1000 * maximo / 1000;
#if ESP_ARDUINO_VERSION_MAJOR >= 3
  ledcWrite(pinosMotor[i], duty);
#else
  ledcWrite(i, duty);
#endif
}

void motoresParados() {
  for (int i = 0; i < 4; i++) motorEscreve(i, 0);
}

// ---------------- MPU6050 ----------------
bool mpuEscreve(uint8_t reg, uint8_t val) {
  Wire.beginTransmission(MPU_ENDERECO);
  Wire.write(reg);
  Wire.write(val);
  return Wire.endTransmission() == 0;
}

bool mpuInicia() {
  Wire.begin(PINO_SDA, PINO_SCL);
  Wire.setClock(400000);
  if (!mpuEscreve(0x6B, 0x00)) return false;   // acorda
  delay(50);
  mpuEscreve(0x1A, 0x03);                       // filtro passa-baixa ~44 Hz
  mpuEscreve(0x1B, 0x08);                       // giroscópio ±500 °/s
  mpuEscreve(0x1C, 0x10);                       // acelerômetro ±8 g
  return true;
}

// Lê aceleração (g) e giroscópio (°/s, já com sinal e sem desvio).
bool mpuLe(float &ax, float &ay, float &az, float &gx, float &gy, float &gz) {
  Wire.beginTransmission(MPU_ENDERECO);
  Wire.write(0x3B);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom((int)MPU_ENDERECO, 14) != 14) return false;
  uint8_t b[14];
  for (int i = 0; i < 14; i++) b[i] = Wire.read();
  auto v = [&](int i) { return (int16_t)((b[i] << 8) | b[i + 1]); };
  ax = SINAL_ACEL_X * v(0) / 4096.0f;
  ay = SINAL_ACEL_Y * v(2) / 4096.0f;
  az = v(4) / 4096.0f;
  gx = SINAL_GIRO_ROLAGEM * v(8) / 65.5f - biasGx;
  gy = SINAL_GIRO_ARFAGEM * v(10) / 65.5f - biasGy;
  gz = SINAL_GIRO_GUINADA * v(12) / 65.5f - biasGz;
  return true;
}

void anguloAcel(float ax, float ay, float az, float &rol, float &arf) {
  rol = atan2f(ay, az) * RAD_TO_DEG;
  arf = atan2f(-ax, sqrtf(ay * ay + az * az)) * RAD_TO_DEG;
}

// Calibra com o drone parado e nivelado (desarmado).
void calibra() {
  Estado anterior = estado;
  estado = CALIBRANDO;
  motoresParados();
  float sgx = 0, sgy = 0, sgz = 0, sr = 0, sp = 0;
  biasGx = biasGy = biasGz = 0;
  const int N = 1000;
  int ok = 0;
  for (int i = 0; i < N; i++) {
    float ax, ay, az, gx, gy, gz, r, p;
    if (mpuLe(ax, ay, az, gx, gy, gz)) {
      sgx += gx; sgy += gy; sgz += gz;
      anguloAcel(ax, ay, az, r, p);
      sr += r; sp += p;
      ok++;
    }
    delay(2);
  }
  if (ok > N / 2) {
    biasGx = sgx / ok; biasGy = sgy / ok; biasGz = sgz / ok;
    trimRolagem = sr / ok; trimArfagem = sp / ok;
    prefs.putFloat("bgx", biasGx); prefs.putFloat("bgy", biasGy); prefs.putFloat("bgz", biasGz);
    prefs.putFloat("trr", trimRolagem); prefs.putFloat("trp", trimArfagem);
    angRolagem = angArfagem = angGuinada = 0;
    sensorOk = true;
  }
  (void)anterior;
  estado = sensorOk ? DESARMADO : ERRO_SENSOR;
}

// ---------------- Bateria e LED ----------------
void leBateria() {
  uint32_t mv = analogReadMilliVolts(PINO_BATERIA);
  uint16_t novo = (uint16_t)(mv * DIVISOR_BATERIA);
  bateriaMv = bateriaMv ? (uint16_t)((bateriaMv * 7u + novo) / 8u) : novo; // média móvel
}

void led(bool aceso) {
  digitalWrite(PINO_LED, (aceso == (bool)LED_ATIVO_ALTO) ? HIGH : LOW);
}

void atualizaLed(uint32_t agora) {
  switch (estado) {
    case ARMADO:      led(true); break;                              // aceso
    case DESARMADO:   led((agora / 1000) % 2); break;                // pisca lento
    case PERDA_SINAL:
    case CORTE:       led((agora / 100) % 2); break;                 // pisca rápido
    case CALIBRANDO:  led((agora / 50) % 2); break;
    case ERRO_SENSOR: led((agora / 250) % 4 == 0); break;
  }
}

// ---------------- Rede ----------------
void recebe(uint32_t agora) {
  uint8_t buf[64];
  int n;
  while ((n = udp.parsePacket()) > 0) {
    int lidos = udp.read(buf, sizeof(buf));
    if (lidos != n || n < (int)(CDP_CABECALHO + CDP_CRC)) continue;
    if (buf[0] != CDP_MAGIA0 || buf[1] != CDP_MAGIA1 || buf[2] != CDP_VERSAO) continue;
    if (crc16(buf, n - 2) != le16u(&buf[n - 2])) continue;

    const uint8_t *d = &buf[CDP_CABECALHO];
    size_t tam = n - CDP_CABECALHO - CDP_CRC;
    ipCockpit = udp.remoteIP();
    portaCockpit = udp.remotePort();
    temCockpit = true;

    if (buf[3] == CDP_CONTROLE && tam == 9) {
      cmdRolagem = constrain(le16s(d + 0), -1000, 1000);
      cmdArfagem = constrain(le16s(d + 2), -1000, 1000);
      cmdGuinada = constrain(le16s(d + 4), -1000, 1000);
      cmdAcel = min<uint16_t>(le16u(d + 6), 1000);
      cmdSinais = d[8];
      ultimoControleMs = agora;
      contControle++;
    } else if (buf[3] == CDP_CALIBRAR && tam == 0) {
      if (estado == DESARMADO || estado == ERRO_SENSOR) calibra();
    }
  }
}

int8_t rssiCockpit() {
  wifi_sta_list_t lista;
  if (esp_wifi_ap_get_sta_list(&lista) == ESP_OK && lista.num > 0)
    return lista.sta[0].rssi;
  return 0;
}

void enviaTelemetria() {
  if (!temCockpit) return;
  uint8_t p[CDP_CABECALHO + 17 + CDP_CRC];
  p[0] = CDP_MAGIA0; p[1] = CDP_MAGIA1; p[2] = CDP_VERSAO; p[3] = CDP_TELEMETRIA;
  pe16(&p[4], seqTx++);
  uint8_t *d = &p[CDP_CABECALHO];
  uint8_t alertas = 0;
  if (bateriaMv && bateriaMv < BATERIA_BAIXA_MV) alertas |= ALERTA_BATERIA_BAIXA;
  if (sensorOk) alertas |= ALERTA_SENSOR_OK;
  if (estado == DESARMADO && cmdAcel > ACELERADOR_ARMAR_MAX) alertas |= ALERTA_ACEL_TRAVADO;
  if (fabsf(angRolagem) > ANGULO_ARMAR_GRAUS || fabsf(angArfagem) > ANGULO_ARMAR_GRAUS)
    alertas |= ALERTA_INCLINADO;
  d[0] = estado;
  pe16(&d[1], bateriaMv);
  pe16(&d[3], (uint16_t)(int16_t)(angRolagem * 100));
  pe16(&d[5], (uint16_t)(int16_t)(angArfagem * 100));
  float g = fmodf(angGuinada, 360.0f);
  if (g > 180.0f) g -= 360.0f;
  if (g < -180.0f) g += 360.0f;
  pe16(&d[7], (uint16_t)(int16_t)(g * 100));
  pe16(&d[9], acelAplicada);
  d[11] = (uint8_t)rssiCockpit();
  pe16(&d[12], (uint16_t)taxaLaco);
  d[14] = alertas;
  pe16(&d[15], (uint16_t)taxaControle);
  pe16(&p[sizeof(p) - 2], crc16(p, sizeof(p) - 2));
  udp.beginPacket(ipCockpit, portaCockpit);
  udp.write(p, sizeof(p));
  udp.endPacket();
}

// ---------------- Máquina de estados de segurança ----------------
void desarma(Estado novo) {
  estado = novo;
  motoresParados();
  acelAplicada = 0;
  pidRolagem.zera(); pidArfagem.zera(); pidGuinada.zera();
}

void atualizaEstado(uint32_t agora) {
  bool ligado = (agora - ultimoControleMs) < TEMPO_PERDA_SINAL_MS && ultimoControleMs != 0;
  bool pedeArmar = cmdSinais & SINAL_ARMAR;
  bool pedeCorte = cmdSinais & SINAL_CORTE;

  if (estado == CALIBRANDO) return;

  // Corte: imediato, de qualquer estado; trava até soltar corte e armar.
  if (ligado && pedeCorte) {
    if (estado != CORTE) desarma(CORTE);
    travaCorte = true;
    return;
  }
  if (estado == CORTE) {
    if (!pedeCorte && !pedeArmar) { travaCorte = false; estado = DESARMADO; }
    return;
  }

  // Capotou: corta os motores.
  if (estado == ARMADO &&
      (fabsf(angRolagem) > ANGULO_CORTE_GRAUS || fabsf(angArfagem) > ANGULO_CORTE_GRAUS)) {
    desarma(CORTE);
    return;
  }

  // Perda de sinal com o drone armado: desce em TEMPO_DESCIDA_MS e desarma.
  if (estado == ARMADO && !ligado) {
    estado = PERDA_SINAL;
    inicioPerdaMs = agora;
  }
  if (estado == PERDA_SINAL) {
    if (ligado && !pedeArmar) { desarma(DESARMADO); return; }
    uint32_t t = agora - inicioPerdaMs;
    fatorDescida = (t >= TEMPO_DESCIDA_MS) ? 0.0f : 1.0f - (float)t / TEMPO_DESCIDA_MS;
    if (fatorDescida <= 0.0f) desarma(DESARMADO);
    return;
  }

  if (estado == ARMADO) {
    if (!pedeArmar) desarma(DESARMADO);
    return;
  }

  // Desarmado (ou erro de sensor): verifica as condições para armar.
  if (estado == DESARMADO && ligado && pedeArmar && !travaCorte &&
      sensorOk && cmdAcel <= ACELERADOR_ARMAR_MAX &&
      (bateriaMv == 0 || bateriaMv >= BATERIA_MINIMA_MV) &&
      fabsf(angRolagem) < ANGULO_ARMAR_GRAUS && fabsf(angArfagem) < ANGULO_ARMAR_GRAUS) {
    pidRolagem.zera(); pidArfagem.zera(); pidGuinada.zera();
    angGuinada = 0;
    fatorDescida = 1.0f;
    estado = ARMADO;
  }
}

// ---------------- Controle ----------------
void controla(float dt) {
  float ax, ay, az, gx, gy, gz;
  if (!mpuLe(ax, ay, az, gx, gy, gz)) {
    sensorOk = false;
    if (estado == ARMADO || estado == PERDA_SINAL) desarma(ERRO_SENSOR);
    else if (estado == DESARMADO) estado = ERRO_SENSOR;
    return;
  }
  if (estado == ERRO_SENSOR) {      // leitura voltou: libera para armar de novo
    sensorOk = true;
    estado = DESARMADO;
  }

  // Atitude por filtro complementar.
  float rAcel, pAcel;
  anguloAcel(ax, ay, az, rAcel, pAcel);
  rAcel -= trimRolagem;
  pAcel -= trimArfagem;
  angRolagem = FILTRO_COMPLEMENTAR * (angRolagem + gx * dt) + (1 - FILTRO_COMPLEMENTAR) * rAcel;
  angArfagem = FILTRO_COMPLEMENTAR * (angArfagem + gy * dt) + (1 - FILTRO_COMPLEMENTAR) * pAcel;
  angGuinada += gz * dt;
  taxaRolagem = gx; taxaArfagem = gy; taxaGuinada = gz;

  if (estado != ARMADO && estado != PERDA_SINAL) {
    motoresParados();
    acelAplicada = 0;
    return;
  }

  // Na perda de sinal: nivela (manche no centro) e desce aos poucos.
  float rDesej = 0, pDesej = 0, yDesej = 0;
  float acel = cmdAcel;
  if (estado == ARMADO) {
    rDesej = cmdRolagem / 1000.0f * ANGULO_MAXIMO_GRAUS;
    pDesej = cmdArfagem / 1000.0f * ANGULO_MAXIMO_GRAUS;
    yDesej = cmdGuinada / 1000.0f * GUINADA_MAX_GRAUS_S;
  } else {
    acel = cmdAcel * fatorDescida;
  }
  if (bateriaMv && bateriaMv < BATERIA_CRITICA_MV) acel = min(acel, 600.0f);

  // Laço externo (ângulo -> taxa) e interno (taxa -> correção).
  // Arfagem + = frente = nariz para baixo.
  float rTaxa = KP_ANGULO * (rDesej - angRolagem);
  float pTaxa = KP_ANGULO * (pDesej - angArfagem);
  float r = pidRolagem.calcula(rTaxa - taxaRolagem, dt);
  float p = pidArfagem.calcula(pTaxa - taxaArfagem, dt);
  float y = pidGuinada.calcula(yDesej - taxaGuinada, dt);

  // Sem aceleração: não acumula o integral (drone no chão).
  if (acel < MOTOR_MARCHA_LENTA) {
    pidRolagem.integral = pidArfagem.integral = pidGuinada.integral = 0;
  }

  // Misturador em X. Rolagem + inclina para a direita (motores da direita
  // diminuem); arfagem + abaixa o nariz (motores da frente diminuem);
  // guinada + gira à direita (motores anti-horários aumentam).
  float m[4];
  m[0] = acel - r - p + y;   // M1 frente-direita, anti-horário
  m[1] = acel - r + p - y;   // M2 trás-direita, horário
  m[2] = acel + r + p + y;   // M3 trás-esquerda, anti-horário
  m[3] = acel + r - p - y;   // M4 frente-esquerda, horário

  for (int i = 0; i < 4; i++) {
    float v = constrain(m[i], (float)MOTOR_MARCHA_LENTA, 1000.0f);
    motorEscreve(i, (uint16_t)v);
  }
  acelAplicada = (uint16_t)acel;
}

// ---------------- Arduino ----------------
void setup() {
  Serial.begin(115200);
  pinMode(PINO_LED, OUTPUT);
  led(false);

  motoresInicia();
  motoresParados();                 // primeiro de tudo: motores desligados

  analogReadResolution(12);
  prefs.begin("drone", false);
  biasGx = prefs.getFloat("bgx", 0); biasGy = prefs.getFloat("bgy", 0); biasGz = prefs.getFloat("bgz", 0);
  trimRolagem = prefs.getFloat("trr", 0); trimArfagem = prefs.getFloat("trp", 0);

  sensorOk = mpuInicia();
  if (!sensorOk) {
    estado = ERRO_SENSOR;
    Serial.println("MPU6050 nao encontrado: verifique SDA/SCL em config.h");
  } else if (!prefs.isKey("bgx")) {
    Serial.println("Primeira execucao: calibrando (deixe o drone parado e nivelado)...");
    calibra();
  }

  uint8_t mac[6];
  WiFi.macAddress(mac);
  char ssid[40];
  snprintf(ssid, sizeof(ssid), "%s%02X%02X", WIFI_PREFIXO_SSID, mac[4], mac[5]);
  WiFi.mode(WIFI_AP);
  WiFi.softAP(ssid, WIFI_SENHA, WIFI_CANAL, 0, 1);  // 1 cliente: só o cockpit
  WiFi.setSleep(false);
  esp_wifi_set_ps(WIFI_PS_NONE);
  udp.begin(UDP_PORTA);

  Serial.printf("Rede: %s  IP: %s  UDP: %d\n", ssid,
                WiFi.softAPIP().toString().c_str(), UDP_PORTA);
}

void loop() {
  static uint32_t proxLaco = micros();
  static uint32_t ultimoMicros = micros();
  static uint32_t proxTelemetria = 0, proxSegundo = 0, proxBateria = 0;
  const uint32_t periodo = 1000000UL / FREQ_LACO_HZ;

  uint32_t agoraUs = micros();
  if ((int32_t)(agoraUs - proxLaco) < 0) {
    // Tempo livre do laço: rede.
    recebe(millis());
    return;
  }
  proxLaco += periodo;
  if ((int32_t)(agoraUs - proxLaco) > (int32_t)(4 * periodo)) proxLaco = agoraUs + periodo;

  float dt = (agoraUs - ultimoMicros) / 1e6f;
  ultimoMicros = agoraUs;
  if (dt <= 0 || dt > 0.02f) dt = 1.0f / FREQ_LACO_HZ;

  uint32_t agora = millis();
  atualizaEstado(agora);
  controla(dt);
  contLaco++;

  if ((int32_t)(agora - proxBateria) >= 0) { proxBateria = agora + 50; leBateria(); }
  if ((int32_t)(agora - proxTelemetria) >= 0) {
    proxTelemetria = agora + 1000 / TELEMETRIA_HZ;
    enviaTelemetria();
  }
  if ((int32_t)(agora - proxSegundo) >= 0) {
    proxSegundo = agora + 1000;
    taxaLaco = contLaco; contLaco = 0;
    taxaControle = contControle; contControle = 0;
  }
  atualizaLed(agora);
}
