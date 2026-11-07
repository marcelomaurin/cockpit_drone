# Protocolo CDP — Cockpit Drone Protocol (versão 1)

Protocolo entre o cockpit (Lazarus) e o firmware do drone ESP32 desta pasta.

## Rede

| Item | Valor |
|---|---|
| Wi-Fi do drone | ponto de acesso `CockpitDrone-XXXX` (XXXX = final do endereço MAC) |
| Senha | aleatória por drone, gerada no primeiro uso e mostrada no monitor serial (ou fixa com `WIFI_SENHA_FIXA` em `config.h`) |
| IP do drone | `192.168.4.1` |
| Porta | UDP `4210` (o drone responde para o IP e a porta de quem enviou) |

## Formato de todo pacote

Todos os números são *little-endian*.

| Byte | Campo | Conteúdo |
|---|---|---|
| 0 | `MAGIA0` | `0x43` (`'C'`) |
| 1 | `MAGIA1` | `0x44` (`'D'`) |
| 2 | `VERSAO` | `1` |
| 3 | `TIPO` | tipo do pacote (tabela abaixo) |
| 4–5 | `SEQ` | contador do remetente (u16) |
| 6… | dados | conforme o tipo |
| últimos 2 | `CRC` | CRC-16/CCITT-FALSE (polinômio `0x1021`, início `0xFFFF`) de todos os bytes anteriores |

Pacotes com magia, versão, tamanho ou CRC errados são descartados em silêncio.

## Cockpit → drone

### `0x01` CONTROLE — 9 bytes de dados, enviado a cada 20–50 ms

| Deslocamento | Tipo | Campo | Faixa |
|---|---|---|---|
| 0 | i16 | rolagem | −1000..1000 (+ = direita) |
| 2 | i16 | arfagem | −1000..1000 (+ = frente) |
| 4 | i16 | guinada | −1000..1000 (+ = gira à direita) |
| 6 | u16 | aceleração | 0..1000 |
| 8 | u8 | sinalizadores | bit 0 = **pedido de armar**; bit 1 = **CORTE** (mata os motores) |

O pacote de controle também é o sinal de vida: o drone considera a ligação perdida após **500 ms** sem recebê-lo.

### `0x02` CALIBRAR — sem dados

Calibra o giroscópio e o nível do acelerômetro. Aceito somente **desarmado** e com o drone parado numa superfície plana.

## Drone → cockpit

### `0x81` TELEMETRIA — 17 bytes de dados, 10 vezes por segundo

| Deslocamento | Tipo | Campo |
|---|---|---|
| 0 | u8 | estado: 0 desarmado, 1 armado, 2 perda de sinal (pousando), 3 corte, 4 calibrando, 5 erro de sensor |
| 1 | u16 | bateria em mV |
| 3 | i16 | rolagem em centésimos de grau |
| 5 | i16 | arfagem em centésimos de grau |
| 7 | i16 | guinada (rumo integrado) em centésimos de grau |
| 9 | u16 | aceleração aplicada (0..1000) |
| 11 | i8 | sinal Wi-Fi do cockpit em dBm (0 = desconhecido) |
| 12 | u16 | frequência do laço de controle em Hz |
| 14 | u8 | alertas: bit 0 bateria baixa, bit 1 sensor OK, bit 2 acelerador travado, bit 3 inclinado demais para armar |
| 15 | u16 | pacotes de controle recebidos por segundo |

## Regras de segurança do firmware

1. **Armar** exige: pedido de armar ligado, aceleração ≤ 50, sensor OK, bateria acima do mínimo, inclinação < 25° e o bit de corte desligado.
2. Depois de armado, desligar o pedido de armar desarma na hora.
3. **CORTE** desliga os motores imediatamente e trava: só volta a armar depois que o cockpit soltar o corte **e** o pedido de armar.
4. **Perda de sinal** (500 ms sem CONTROLE) com o drone armado: a aceleração desce até zero em 2 s e o drone desarma.
5. Inclinação acima de 70° com o drone armado (queda/capotagem): corta os motores.
6. Bateria abaixo do mínimo crítico: impede armar; em voo, limita a aceleração e sinaliza.
