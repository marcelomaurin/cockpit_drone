# Arquitetura do simulador

O simulador tem quatro linhas de execução que só se falam por cópias de estado protegidas por travas: a janela, a física, o emulador do protocolo e o cliente do mundo. Os downloads de mapa rodam em mais quatro linhas.

```
            UDP/TCP (protocolo real)                HTTPS (blocos)
 Cockpit  <------------------------>  Emulador      Google / OpenStreetMap
 Drone                                 (1 linha)          ^
                                         |  comando        | 4 linhas de download
                                         v                 |
                                      Física 50 Hz  ->  Visão (janela, 25 qps)
                                      (1 linha)            ^
                                         |  posição         | vizinhos
                                         v                 |
                                      Cliente do mundo  <-> Servidor PHP (JSON)
                                      (1 linha, 500 ms)
```

## Unidades

| Pasta / unidade | Classe | Responsabilidade |
|---|---|---|
| `nucleo/simgeo` | — | Web Mercator, metros locais, haversine, zoom por tamanho de pixel |
| `nucleo/simtipos` | `TComandoVoo`, `TEstadoVoo`, `TParametrosModelo`, `TFalhas` | Tipos comuns; leitura de `equipamentos.json` |
| `nucleo/simfisica` | `TSimFisica` | Física de multirrotor de passo fixo |
| `nucleo/simsimulacao` | `TSimulacao`, `TLinhaFisica` | Liga física + emulador, aplica falhas, guarda o rastro |
| `nucleo/simhttp` | — | Cliente HTTP(S) com prazos padronizados |
| `protocolos/simrede` | `TSimUDP`, `TSimTCPServidor` | UDP/TCP sobre a unidade `sockets` (Windows e Linux) |
| `protocolos/simemulador` | `TEmulador` (abstrata) | Laço de rede, atraso, sinal perdido, fases de voo comuns |
| `protocolos/simprotocolos` | `TEmuladorTello`, `TEmuladorARDrone`, `TEmuladorFQ777`, `TEmuladorCDP`, `TEmuladorESPDrone` | Um emulador por protocolo |
| `protocolos/simmavlink` | `TEmuladorMavlink` | ArduCopter emulado: modos, armar, missão, RTL |
| `mapa/simmapa` | `TGerenciadorBlocos`, `TFonteGoogle`, `TFonteOSM` | Blocos, cache em disco, troca automática de fonte, crédito |
| `mundo/simmundo` | `TClienteMundo` | Entrar, atualizar, eventos e sair no servidor PHP |
| `visao/simvisao` | `TVisao`, `TAmostrador` | Câmera, terceira pessoa e mapa de cima, em software |
| `forms/simprincipal` | `TFrmPrincipal` | Janela montada em código, preferências |

## Fluxo de um passo da física (20 ms)

1. `TLinhaFisica` copia o estado atual (trava da simulação) e solta a trava.
2. Pede o comando ao emulador: `MontaComando(estado)`. O emulador usa a própria trava, aplica as regras do equipamento (fases, vigias, falhas) e devolve um `TComandoVoo`.
3. Trava a simulação de novo, avança `TSimFisica.Passo` e guarda o novo estado e o rastro.

A linha da física **nunca** chama o emulador segurando a trava da simulação. O emulador lê o estado (trava da simulação) segurando a própria trava, então a ordem é sempre emulador → simulação, e não há impasse.

## Física

- O comando vira ângulo-alvo (modo ângulo), velocidade-alvo (modo velocidade, como o Tello e o LOITER) ou ponto-alvo (modo "ir para", nos modos autônomos do MAVLink).
- A atitude segue o alvo com resposta de primeira ordem (`constante_resposta_s`).
- Empuxo 0,5 sustenta o drone parado. No modo subida ou altura, um controlador ajusta o empuxo; no modo empuxo, o cockpit manda direto, como nos brinquedos (CX-10W, FQ777, ESP32, ESP-Drone).
- O arrasto é calculado para que, no ângulo máximo, a velocidade final seja `vel_max_ms`. O vento entra no arrasto.
- O chão é plano (altura 0). Um toque acima de 2 m/s é queda: os motores param e só voltam com *Reiniciar*.
- A bateria cai com o tempo e com o esforço (`autonomia_min` é o tempo pairando). Abaixo de 5% o empuxo diminui.
- Sinal perdido: falha injetada ou distância maior que `alcance_radio_m`.

## Mapa e vistas

- `TGerenciadorBlocos` mantém até 320 blocos na memória. A fila de pedidos atende primeiro os blocos com cópia em disco, depois os da vista principal e, por fim, o pedido mais recente.
- Os blocos usados na tela nos últimos 5 s nunca são descartados, porque a janela pode estar lendo um deles. A troca de fonte é só marcada nas linhas de download e é aplicada na linha principal, entre um quadro e outro.
- A câmera lança um raio por pixel e procura onde ele toca o chão. O zoom do bloco é escolhido por linha, conforme a distância. Ao longe entra a névoa; acima do horizonte, o céu. A imagem é feita em meia resolução e esticada na tela.
- A consulta de direitos autorais do Google (viewport) roda numa linha de download, nunca na janela.
