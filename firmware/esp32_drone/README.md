# Firmware do drone ESP32 — Cockpit Drone

Firmware para um mini quadricóptero com ESP32, controlado pelo Cockpit Drone
pelo protocolo **CDP** (veja [PROTOCOLO.md](PROTOCOLO.md)). No cockpit, escolha
**Configuração > Protocolo > Drone ESP32 (firmware Cockpit)**.

## Hardware previsto

| Peça | Observação |
|---|---|
| ESP32, ESP32-S2 ou ESP32-S3 | núcleo Arduino-ESP32 2.x ou 3.x |
| MPU6050 | I2C (SDA/SCL em `config.h`) |
| 4 motores escovados (coreless 7×16 / 8×20) | um MOSFET N por motor (ex.: SI2302), diodo em antiparalelo |
| Bateria LiPo 1S | divisor resistivo para o ADC (padrão 100k/100k) |
| LED de estado | opcional |

Os pinos padrão de `config.h` seguem o **ESP-Drone (ESP32-S2/S3)**. No ESP32
"clássico", troque os pinos dos motores: os GPIO 1 e 3 são a serial de gravação
e os GPIO 6 a 11 são da memória flash. Uma escolha segura é M1=25, M2=26,
M3=27, M4=14, SDA=21, SCL=22, bateria=34, LED=2.

## Gravação

1. Instale a IDE Arduino e o suporte a placas **esp32** (Espressif).
2. Abra `esp32_drone/esp32_drone.ino`, escolha a placa e a porta.
3. Ajuste `config.h` (pinos, sentido dos eixos, senha do Wi-Fi).
4. Grave. No monitor serial (115200) aparecem o nome da rede e o IP.

Na primeira execução o firmware calibra o sensor: deixe o drone **parado e
nivelado** por uns 3 segundos. Para recalibrar depois, use o botão
**Calibrar** do cockpit (só com o drone desarmado).

## Primeiro teste — SEM HÉLICES

1. Conecte o PC na rede `CockpitDrone-XXXX` (senha `cockpit123`) e ligue o
   cockpit com o protocolo **Drone ESP32 (firmware Cockpit)**.
2. **Teste de sinais do sensor** (na janela de conexão do cockpit):
   - incline o drone para a **direita**: a rolagem deve ficar **positiva**;
   - abaixe o **nariz**: a arfagem deve ficar **positiva**;
   - gire para a **direita** (horário, visto de cima): o rumo deve **aumentar**.

   Se algum sinal sair invertido, troque o `SINAL_...` correspondente em
   `config.h` e grave de novo.
3. **Teste dos motores**: leve a aceleração ao mínimo, clique **Armar** e suba
   a aceleração devagar. Todos os motores devem girar. Incline o drone para a
   direita com a mão: os motores da **esquerda** devem acelerar (ele tenta
   voltar ao nível). Se acontecer o contrário, os sinais do item 2 estão errados.
4. Confira o sentido de giro: M1 e M3 anti-horário, M2 e M4 horário (vistos de
   cima), com as hélices correspondentes.
5. Teste o **CORTE** (botão vermelho ou Espaço) e a **perda de sinal**
   (desligue o Wi-Fi do PC: os motores devem parar em até 2,5 s).

Só depois disso coloque as hélices.

## Estados do LED

| LED | Estado |
|---|---|
| pisca lento | desarmado, pronto |
| aceso | armado |
| pisca rápido | corte ou perda de sinal |
| pisca muito rápido | calibrando |
| piscadas curtas | erro no sensor |

## Ajuste fino

Os ganhos do PID estão em `config.h`. Se o drone oscilar rápido, reduza
`KP_TAXA_RP` e `KD_TAXA_RP`; se responder mole ou derivar, aumente `KP_ANGULO`
ou `KI_TAXA_RP` aos poucos. Sem barômetro, a altura é controlada pelo piloto
com a aceleração.
