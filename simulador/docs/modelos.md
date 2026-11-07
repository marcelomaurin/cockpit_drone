# Modelos e protocolos emulados

Cada emulador responde no formato que o componente correspondente da suíte CHATGPT (pacote `openai_drone`) usa com o equipamento real. A fonte da verdade são esses componentes: qualquer correção de protocolo é feita lá, e o emulador é ajustado para continuar igual ao equipamento.

| Modelo | Componente do cockpit | Portas do simulador | Para onde responde |
|---|---|---|---|
| DJI/Ryze Tello | `TAIDroneTello` | UDP 8889 | Respostas para quem enviou; estado para a UDP 8890 de quem enviou |
| Parrot AR.Drone 2.0 | `TAIDroneARDrone` | UDP 5556 | Navdata para a UDP 5554 de quem enviou |
| MAVLink (ArduCopter) | `TAIDroneMavlink` | UDP 14551 (configurável) | Envia para `IP do cockpit:14550` |
| Cheerson CX-10W / FQ777-954 | `TAIDroneCX10W` / `TAIDroneFQ777` | TCP 8888 e UDP 8895 | Não responde (como o real; o vídeo não é emulado) |
| Drone ESP32 (CDP v1) | `TAIDroneCDP` | UDP 4210 | Telemetria para quem enviou |
| ESP-Drone / OpenDrone | `TAIDroneESPDrone` | UDP 2390 | Pacote de enlace para quem enviou (porta 2399) |

## Tello

- `command` → `ok` e modo SDK; `takeoff`, `land`, `emergency`, `streamon`, `streamoff` → `ok`; `battery?`, `height?` e `time?` respondem o valor.
- `rc a b c d` (-100..100) não tem resposta; é velocidade no corpo, com altura mantida no centro.
- Estado a 10 Hz: `pitch;roll;yaw;vgx;vgy;vgz;templ;temph;tof;h;bat;baro;time;agx;agy;agz`.
- Pousa sozinho após 15 s sem comandos e com bateria abaixo de 10%. Recusa decolar com bateria abaixo de 10%.

## AR.Drone 2.0

- `AT*REF`: bit 9 decola e pousa; o bit 8 alterna a emergência (motores param).
- `AT*PCMD=seq,flag,rolagem,arfagem,subida,guinada`: valores -1..1 no padrão de bits do float. Arfagem positiva é para trás. Com `flag=0`, paira.
- A sequência 1 reinicia a numeração; comandos com sequência antiga são ignorados.
- Navdata a cerca de 15 Hz: cabeçalho `0x55667788`, estado (voando, confirmação de configuração, bateria baixa, vigia, emergência), opção "demo" de 148 bytes e soma de verificação.
- Sem comando AT por 2 s, paira e liga o bit de vigia. Com bateria abaixo de 5%, pousa.

## MAVLink (ArduCopter)

- HEARTBEAT 1 Hz (quadricóptero, ArduPilot). SYS_STATUS, GPS_RAW_INT e GLOBAL_POSITION_INT a 4 Hz. HOME_POSITION a 1 Hz e quando pedido.
- COMMAND_LONG: armar e desarmar (400), decolar (22, só em GUIDED), pousar (21), RTL (20), mudar modo (176), iniciar missão (300), pedir home (410 e 512). Cada comando recebe COMMAND_ACK.
- Missão: MISSION_COUNT → MISSION_REQUEST_INT item a item → MISSION_ACK. O item 0 é o ponto de partida, como no ArduPilot. Itens executados: decolagem, ponto (com espera e raio), mudança de velocidade, pairar, pouso e RTL, com MISSION_CURRENT e MISSION_ITEM_REACHED.
- MANUAL_CONTROL: em STABILIZE o acelerador é o empuxo; em ALT_HOLD e LOITER, o centro (500) mantém a altura.
- Proteções: 5 s sem a estação no ar → RTL; bateria < 15% → RTL; < 8% → LAND; perda de GPS → LAND. Armado no chão por 15 s sem decolar desarma sozinho. Recusas chegam como STATUSTEXT ("PreArm: ...").
- RTL: sobe a pelo menos 15 m, volta à partida, desce e desarma.

## CX-10W e FQ777-954

- O simulador aceita as conexões TCP 8888 (pacotes mágicos de inicialização e vídeo) e descarta o conteúdo.
- O comando UDP de 8 bytes: `$CC rolagem arfagem aceleração guinada sinais XOR $33`. Pacote com XOR errado é descartado.
- Brinquedo sem altura automática: a aceleração é o empuxo. Aceleração zero no ar faz o drone cair, como o real.
- Sem pacotes por 1 s, o enlace cai e o drone perde força e desce.

## Drone ESP32 (CDP v1)

As seis regras de segurança do firmware (`firmware/esp32_drone/PROTOCOLO.md`) estão emuladas: condições para armar, desarmar ao soltar o pedido, corte travado, perda de sinal em 500 ms com descida de 2 s, corte acima de 70° de inclinação e limite com bateria crítica. A telemetria `0x81` sai a 10 Hz, com CRC-16/CCITT-FALSE. A bateria é de uma célula: 4,2 V cheia e 3,3 V vazia.

## ESP-Drone / OpenDrone

- Pacote do commander (`0x3C`): rolagem, arfagem (com o sinal invertido, como o cflib) e guinada em `f32`, mais o empuxo em `u16` (0..60000) e a soma de verificação.
- O empuxo só é aceito depois de receber empuxo zero, como na trava do firmware.
- Sem comando por 0,5 s, nivela; sem comando por 2 s, para os motores. O pairar fica perto de 62% do empuxo máximo.

## Parâmetros (`config/equipamentos.json`)

| Campo | Uso |
|---|---|
| `protocolo` | Qual emulador usar: `tello`, `ardrone`, `mavlink`, `fq777`, `cdp`, `espdrone` |
| `massa_kg` | Informativo nesta versão |
| `vel_max_ms`, `subida_max_ms` | Velocidades máximas horizontal e vertical |
| `angulo_max_graus`, `guinada_max_graus_s` | Inclinação e giro máximos |
| `constante_resposta_s` | Rapidez da atitude em seguir o comando |
| `autonomia_min` | Tempo de bateria pairando |
| `alcance_radio_m` | Além disso, sinal perdido |
| `altura_decolagem_m` | Altura da decolagem automática (Tello, AR.Drone) |
| `gps` | Se o modelo informa posição |
| `camera` | Resolução, campo de visão e inclinação para baixo |

Um modelo novo com um protocolo já existente entra só por esse arquivo. Um protocolo novo precisa de uma classe derivada de `TEmulador`, registrada em `ClasseDoProtocolo` (`simsimulacao.pas`).

## Pendências

- Vídeo H.264 para o cockpit (Tello, AR.Drone, FQ777/CX-10W).
- Valores de `equipamentos.json` medidos em voo real lado a lado.
