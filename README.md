> **Versão 0.46:** casas/prédios na câmera com fallback a partir do mapa real, sinal infinito opcional, recuperação após queda e Xbox 360 configurável. Inclui WIFI_8K Legacy9/E58_8 experimentais e MSPv1/MSPv2/CRSF/SBUS/iBUS com 30 perfis de drone, helicóptero, avião, carro, barco e submarino. [Pilotagem](docs/CONTROLES_0.46.md) · [Protocolos e limites](docs/PROTOCOLOS_0.46.md) · [Simulador](simulador/docs/SIMULADOR_0.46.md) · [Dependências do instalador](docs/DEPENDENCIAS_0.46.md).

[Português](README.md) · [English](README.en.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [日本語](README.ja.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

# Cockpit Drone - Sistema de Controle, Telemetria e Simulação

Aplicação completa desenvolvida em Object Pascal (Lazarus / Free Pascal) para controle remoto, monitoramento de telemetria e simulação física 3D de drones e aeronaves não tripuladas. Integra joystick analógico, sensores GPS, feed de vídeo ao vivo (H.264 e câmera sintética), mapas táticos (OpenStreetMap) e suporte a múltiplos protocolos de voo.

---

## Índice

1. [Visão Geral](#visão-geral)
2. [Estrutura do Projeto](#estrutura-do-projeto)
3. [Protocolos Suportados](#protocolos-suportados)
4. [Simulador 3D Oficial e Multiplayer](#simulador-3d-oficial-e-multiplayer)
5. [Controles: Joystick vs Teclado](#controles-joystick-vs-teclado)
6. [Instalação e Requisitos](#instalação-e-requisitos)
7. [Planejamento de Rota de Voo](#planejamento-de-rota-de-voo)
8. [Download dos Binários Compilados](#download-dos-binários-compilados)
9. [Contato e Licença](#contato-e-licença)

---

## Visão Geral

O **Cockpit Drone** foi projetado com arquitetura de thread dedicada desacoplada da interface do usuário (UI), garantindo que os laços críticos de envio de comandos de voo (50 ms) e recepção de telemetria nunca sejam interrompidos por travamentos ou caixas de diálogo na interface.

Principais recursos:
- **Laço de Voo Seguro:** Thread independente de comunicação com corte de pânico na barra de espaço e retorno suave ao ponto de sustentação (*hover*).
- **Interface Tática Multijanela:** Instrumentos de voo, painel de status por LEDs, HUD militar tático, mapa geoespacial interativo e feed de vídeo em tempo real.
- **Ecossistema Completo:** Inclui o **Simulador 3D** (`simulador/simulador.exe`) com física 6DOF e o servidor web multiplayer em PHP/WebSocket (`PHP/`).

---

## Estrutura do Projeto

- **`src/main.pas`:** Interface gráfica principal do sistema. Gerencia os controles visuais, status por LEDs, processamento de atalhos e acionamento dos módulos.
- **`src/config.pas`:** Painel de configuração com seleção de protocolos, ajuste de joystick com calibração visual em tempo real, mapeamento de teclas e seletor de idiomas.
- **`src/joystick.pas`:** Módulo de gerenciamento de controles analógicos físicos (DirectInput / SDL), com suporte a manches de voo, gamepads e filtros de zona morta.
- **`src/gps.pas`:** Leitura contínua de portas seriais e decodificação de sentenças NMEA, com exibição de satélites e qualidade de sinal.
- **`src/camera.pas`:** Decodificação de vídeo H.264 via FFmpeg e captura em memória compartilhada da câmera sintética do simulador 3D (`cockpit_sim_camera.bmp`).
- **`src/map.pas`:** Mapeamento geoespacial interativo baseado em OpenStreetMap (MapViewer), com rastro de trajetória em tempo real, waypoints e geocerca.
- **`simulador/`:** Projeto autônomo do simulador de voo 3D (`simulador.lpi`), emulando dinâmica de voo, sensores e câmera para testes locais ou mundo compartilhado.
- **`PHP/`:** Servidor HTTP/WebSocket de simulação compartilhada para sincronização de drones no mapa em um raio de até 2 km.

---

## Protocolos Suportados

Os protocolos de comunicação integram a [Lazarus AI Suite (CHATGPT)](https://github.com/marcelomaurin/CHATGPT) no pacote `openai_drone`, compartilhando a arquitetura base de `conexaodrone.pas`:

| Drone / Protocolo | Componente | Descrição / Canal |
|---|---|---|
| **Cheerson CX-10W** | `TAIDroneCX10W` | Wi-Fi UDP 8895 / TCP 8888, comandos a 50 ms e vídeo H.264 |
| **MAVLink (ArduPilot/PX4)** | `TAIDroneMavlink` | UDP 14550, telemetria completa, missões e waypoints |
| **DJI / Ryze Tello** | `TAIDroneTello` | Wi-Fi UDP comandos/telemetria e vídeo H.264 |
| **ESP-Drone / OpenDrone** | `TAIDroneESPDrone` | Protocolo CRTP via UDP 2390 para firmware Espressif |
| **FQ777-954** | `TAIDroneFQ777` | Conexão Wi-Fi automática, controle proporcional e vídeo |
| **Parrot AR.Drone 2.0** | `TAIDroneARDrone` | Comandos AT (UDP 5556), telemetria (UDP 5554) e vídeo TCP 5555 |
| **Drone ESP32 (Cockpit)** | `TAIDroneCDP` | Firmware aberto dedicado CDP com ESP32 + MPU6050 |

---

## Simulador 3D Oficial e Multiplayer

O projeto conta com o **Simulador Cockpit Drone** (`simulador/simulador.exe`), um executável independente que emula os drones reais sobre imagens de satélite ou OpenStreetMap.

> **IMPORTANTE — ENTRADA MULTIPLAYER:**  
> A entrada no **Multiplayer (Mundo Compartilhado)** é feita através do **Simulador** (`simulador.exe`):  
> 
> 1. Abra o `simulador.exe`.  
> 2. No painel **Mundo compartilhado**, informe o endereço do servidor (oficial: `https://maurinsoft.com.br/cockpit/`) e seu **Apelido**, e clique em **Entrar**.  
> 3. Drones voando em um raio de até **2 km** aparecem no mapa e na câmera 3D.  
> 4. O **Cockpit Drone** (`drone.exe`) conecta-se localmente em `127.0.0.1`, permitindo pilotar, monitorar telemetria e ver os instrumentos.

---

## Controles: Joystick vs Teclado

- **Joystick Analógico (Recomendado):** Proporciona modulação contínua e suave dos 4 eixos (arfagem, rolagem, guinada e aceleração). Compatível com manches de voo, gamepads (Xbox, PlayStation) e rádios RC via USB.
- **Teclado:** Permite pilotagem completa com atalhos direcionais, retorno suave ao pairar e **corte imediato de emergência** na barra de espaço.

### Mapa Principal de Teclas

| Comando | Tecla Principal | Tecla Alternativa | Ação |
|---|---|---|---|
| **Frente (Pitch +)** | `W` | `Seta Acima` | Inclina para frente |
| **Trás (Pitch -)** | `S` | `Seta Abaixo` | Inclina para trás |
| **Esquerda (Roll -)** | `A` | `Seta Esquerda` | Inclina para a esquerda |
| **Direita (Roll +)** | `D` | `Seta Direita` | Inclina para a direita |
| **Subir (Throttle +)** | `E` | `Page Up` | Aumenta altitude/potência |
| **Descer (Throttle -)** | `Q` | `Page Down` | Reduz altitude/potência |
| **Girar Esquerda (Yaw -)** | `1` ou `Z` | Botão 1 | Giro no próprio eixo anti-horário |
| **Girar Direita (Yaw +)** | `2` ou `X` | Botão 2 | Giro no próprio eixo horário |
| **Decolar / Armar** | `3` ou `Insert` | Botão 3 | Arma motores ou decola |
| **Pousar / Desarmar** | `4` ou `Delete` | Botão 4 | Pouso automático ou desarma |
| **Pairar / Centralizar** | `5` ou `R` / `Home` | Botão 5 | Estabiliza e centraliza |
| **PÂNICO / CORTE** | `Espaço` | Botão Emergência | Zera motores imediatamente |
| **HUD Tático** | `T` | — | Alterna visualização do HUD |
| **Janela Câmera** | `C` | — | Alterna feed de vídeo |
| **Janela Mapa** | `M` | — | Alterna mapa de navegação |
| **Janela GPS** | `G` | — | Alterna telemetria GPS |

---

## Instalação e Requisitos

1. Instale o **Lazarus IDE** e o **Free Pascal**.
2. Instale os componentes da [Lazarus AI Suite (CHATGPT)](https://github.com/marcelomaurin/CHATGPT).
3. Abra `src/drone.lpi` no Lazarus e compile o projeto.
4. Para a decodificação de vídeo da câmera, copie o executável `ffmpeg.exe` para a mesma pasta do `drone.exe` ou garanta sua presença no PATH do sistema.

---

## Planejamento de Rota de Voo

Para drones com piloto automático e GPS (como MAVLink / ArduPilot / PX4):
1. Acesse o botão **Rota de voo** no menu principal.
2. Adicione pontos clicando diretamente sobre o mapa OpenStreetMap (ou importe arquivos `.waypoints` compatíveis com Mission Planner / QGroundControl).
3. Configure altitude, velocidade, raio de geocerca e ação ao final da missão (retornar ao início, pousar ou pairar).
4. Clique em **Enviar ao drone** e confirme para iniciar a missão autônoma.

---

## Download dos Binários Compilados

Os executáveis pré-compilados e o instalador oficial completo para Windows estão disponíveis diretamente na pasta [`bin/`](bin/):
- **`bin/setup_cockpit_drone_0.41.exe`:** Instalador completo para Windows com Cockpit, Simulador e bibliotecas.
- **`bin/drone.exe`:** Executável do Cockpit Drone.
- **`bin/simulador.exe`:** Executável do Simulador 3D.

---

## Contato e Licença

- **Autor:** Marcelo Maurin Martins
- **E-mail:** marcelomaurinmartins@gmail.com
- **WhatsApp:** +55 16 98143-4112
- **Site Oficial:** [Maurinsoft - Cockpit Drone](https://maurinsoft.com.br/wp/projetos-open-source/projeto-cockpit-drone/)
- **Licença:** Código aberto sob licença livre permissiva.
