# Protocolos e veículos da versão 0.46

A versão mantém os adaptadores Cheerson CX-10W, MAVLink, Tello, ESP-Drone/CRTP, FQ777-954, AR.Drone e ESP32/CDP. Acrescenta dois candidatos WIFI_8K e cinco formatos de canais RC. As novas entradas genéricas não afirmam compatibilidade de uma marca/modelo sem validação de hardware.

| Formato novo | Saída para equipamento | Simulação local |
| --- | --- | --- |
| WIFI_8K Legacy9 | UDP7099; descoberta/conexão Wi-Fi | Mesmo quadro, UDP7099 |
| WIFI_8K E58_8 | UDP8090, inicialização auxiliar8080 | Mesmo quadro, UDP8090+8080 |
| MSPv1 SET_RAW_RC200 | Serial, 115200baud padrão, 8 canais | Mesmo quadro, UDP14600 |
| MSPv2 SET_RAW_RC200 | Serial, 115200baud padrão, 16 canais | Mesmo quadro, UDP14601 |
| CRSF RC_CHANNELS_PACKED16 | Serial4200008N1 padrão, 16 canais | Mesmo quadro, UDP14602 |
| SBUS | Serial1000008E2 e inversão elétrica apropriada, 16 canais | Mesmo quadro, UDP14603 |
| FlySky iBUS canais | Serial1152008N1, 14 canais | Mesmo quadro, UDP14604 |

São saídas de canais, não implementação integral de todos os serviços desses protocolos. CRSF não implementa negociação de módulos, envio de configuração, Lua ou telemetria completa. MSP exige firmware que aceite SET_RAW_RC na porta e habilitação de entrada MSP compatível. iBUS aqui é o fluxo de canais do receptor, não o barramento de sensores. SBUS exige adaptador com baud/framing e níveis/inversão adequados: USB-serial comum sem essa adaptação não é suficiente. O endereço CRSF padrão C8 representa a controladora; conexões com módulo transmissor podem exigir endereço EE, temporização e negociação próprias que este adaptador não implementa.

Cada formato RC tem **seis perfis independentes**, totalizando 30: drone, helicóptero, avião, carro, barco e submarino. Selecione RC genérico e o formato/modelo na aba Tipo de equipamento, ou troque a categoria na aba RC serial/veículos. Configure COM, baud, frequência, canais dos quatro eixos, inversões, canal de armamento, endereço CRSF e URL de vídeo opcional. A saída real começa desabilitada; Modo simulador ignora COM e usa somente loopback.

O padrão RC aéreo é AETR: rolagem1, arfagem2, acelerador3, guinada4, armamento5. No submarino são lateral6, avanço5, guinada4, vertical3 e armamento7. A arma, B desarma e Espaço corta. Para armar aeronaves RC, baixe o acelerador; em carro/barco/submarino, centralize-o. No carro/barco, o eixo de rolagem dirige e a aceleração centrada permite marcha à ré. No submarino, arfagem avança/recua, rolagem desloca lateralmente e aceleração centrada controla subida/descida. Os canais reais precisam corresponder à configuração da controladora/receptor do veículo.

No simulador, escolha WIFI_8K ou a categoria RC correspondente. Os cinco formatos RC servem ao mesmo modelo da categoria, com validação de confirmação e canais. O avião precisa acelerar na pista e obter sustentação; carro permanece no chão; barco na superfície; submarino opera entre a superfície e 30 m de profundidade. Helicóptero usa a aproximação de rotor já existente. São modelos de treinamento simplificados, sem promessa de dinâmica específica de fabricante, hidrodinâmica detalhada ou voo acrobático de helicóptero.

Protocolos seriais não substituem o enlace de rádio. Em veículos físicos é necessário receptor/controladora/interface compatível; um computador não transmite CRSF/SBUS/iBUS pelo ar sozinho. Para submarino, a interface deve estar em cabo, boia ou outra arquitetura de comunicação apropriada; Wi-Fi submerso não é uma funcionalidade deste projeto.

## Validação e referências

Passaram vetores de canais, tamanhos, empacotamento, checksum/CRC, rejeição de quadros inválidos e failsafe SBUS; 30 combinações de perfil; integração de todos os formatos pelo adaptador do cockpit e física do simulador; voo/corte, categorias, avião com pista e limites de profundidade. Saída serial foi compilada para Windows, mas não foi ensaiada com controladora/receptor físico. Nenhum desses resultados homologa uma marca comercial.

Fontes: [CRSF TBS](https://github.com/tbs-fpv/tbs-crsf-spec/blob/main/crsf.md), [MSP Betaflight](https://github.com/betaflight/betaflight/blob/master/src/main/msp/msp_protocol.h), [iBUS Betaflight](https://github.com/betaflight/betaflight/blob/master/src/main/rx/ibus.c), [SBUS Betaflight](https://github.com/betaflight/betaflight/blob/master/src/main/rx/sbus.c). [WIFI_8K e suas fontes](WIFI_8K_EXPERIMENTAL.md).
