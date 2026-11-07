## Plano de evolução / Change plan

[Plano de alterações, prioridades, critérios de aceite e homologação](docs/PLANO_ALTERACOES_COCKPIT.md).

## Idiomas / Languages

O seletor de idioma em Configurações salva a preferência para português, inglês, espanhol, chinês simplificado, árabe, alemão, russo e hindi. **A tradução completa da interface ainda está em desenvolvimento.** Guia introdutório multilíngue: [docs/LANGUAGES.md](docs/LANGUAGES.md).

# Sistema de Controle e Monitoramento de Drones

---

## Seção 1: Português

### Visão Geral do Projeto

Este projeto, desenvolvido em Object Pascal (Lazarus/Free Pascal), constitui uma aplicação para controle remoto e monitoramento de drones. Ele integra múltiplos dispositivos e funcionalidades, tais como joystick, GPS, câmera e mapas, oferecendo uma interface gráfica central para o usuário gerenciar e visualizar o status do drone e dos periféricos conectados.

### Estrutura do Projeto

- **main.pas**  
  Implementa a interface gráfica principal do sistema. Gerencia a ativação e monitoramento dos controles, incluindo joystick, drone, GPS, câmera e mapa, usando LEDs e controles visuais. Processa comandos do joystick e controla a conexão com o drone via formulário específico.

- **config.pas**  
  Interface para configuração dos parâmetros de comunicação e seleção do joystick. Permite a visualização e teste em tempo real dos eixos e botões do controlador, integrando-se com a interface principal.

- **joystick.pas**  
  Gerenciamento de joysticks e controles físicos (DirectInput / SDL), com leitura de eixos analógicos, mapeamento de botões, calibração e tratamento de zonas mortas em tempo real.

- **gps.pas**  
  Formulário responsável pela leitura de dados GPS via porta serial, decodificação das sentenças NMEA e apresentação das informações de localização, satélites e qualidade do sinal.

- **camera.pas**  
  Exibição e captura de vídeo ao vivo do drone (decodificação H.264 / streaming via FFmpeg) e recepção de imagens sintéticas do simulador 3D local (`cockpit_sim_camera.bmp`). Inclui retículo de mira, medição de FPS e gravação de vídeo.

- **map.pas**  
  Mapeamento geoespacial interativo baseado em OpenStreetMap (MapViewer), com rastreamento da trajetória do drone em tempo real, plotagem de waypoints de rotas de voo e geocercas (geofence).

- **Simulador 3D Oficial (`simulador/`)**  
  O executável autônomo na pasta `simulador/` (`simulador.lpi`) é o simulador de voo 3D oficial do Cockpit Drone, com física 6DOF, geração de câmera sintética compartilhada e integração multiplayer. As unidades `src/simulator_*.pas` no cockpit atuam como pontes internas de telemetria e testes de protocolo.

- **Protocolos dos drones**  
  Os protocolos não ficam mais no cockpit: são componentes da [Lazarus AI Suite (CHATGPT)](https://github.com/marcelomaurin/CHATGPT), pacote `openai_drone`, reaproveitáveis em outras aplicações:

  | Drone | Componente | Janela do cockpit |
  |---|---|---|
  | Cheerson CX-10W | `TAIDroneCX10W` | `conectioncx10w.pas` |
  | MAVLink (ArduPilot/PX4) | `TAIDroneMavlink` | `conectionmavlink.pas` |
  | DJI/Ryze Tello | `TAIDroneTello` | `conectiontello.pas` |
  | ESP-Drone / OpenDrone | `TAIDroneESPDrone` | `conectionopendrone.pas` |
  | FQ777-954 | `TAIDroneFQ777` | `conectionfq777.pas` |
  | Parrot AR.Drone 2.0 | `TAIDroneARDrone` | `conectionardrone.pas` |
  | Drone ESP32 (firmware Cockpit) | `TAIDroneCDP` | `conectionesp32drone.pas` |

- **conexaodrone.pas**  
  Base comum das janelas de conexão: monta a janela, converte o manche do cockpit (X/Y, Q/E, botões 1 a 6), entrega o vídeo H.264 ao `TAIH264Decoder` e mostra as mensagens do componente. Cada janela de drone só configura o seu componente e repassa os comandos.

- **conectionfq777.pas**  
  Conexão exclusiva do quadricóptero FQ777-954 (veja a seção abaixo).

- **rotavoo.pas / rotamavlink.pas / flightplan.pas**  
  Planejamento de rota de voo (somente drones com GPS), validação, arquivos `.waypoints` e envio da missão pelo `TAIDroneMavlink`.

- **funcs.pas**  
  Contém funções utilitárias, como `MAPA`, que realiza mapeamento linear de valores analógicos para o intervalo byte (0-255), fundamental para a normalização dos sinais.

### Instalação

1. Instale Lazarus e Free Pascal no seu ambiente de desenvolvimento.  
2. Instale os pacotes da [Lazarus AI Suite (CHATGPT)](https://github.com/marcelomaurin/CHATGPT): `openai_core`, `openai_input`, `openai_hardware`, `openai_video` e `openai_drone`.  
3. Clone ou obtenha o código-fonte do projeto.  
4. Abra o arquivo `src/drone.lpi` no Lazarus.  
5. Compile e execute o projeto.  
6. Para a câmera (FQ777-954, CX-10W, Tello e AR.Drone) é preciso o `ffmpeg.exe` na pasta do `drone.exe` (ou no PATH). O instalador já traz o ffmpeg; para gerar o instalador, baixe o pacote win64-gpl de [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds/releases) e copie `ffmpeg.exe` e `LICENSE.txt` (como `ffmpeg-LICENSE.txt`) para `install/redist` (pasta fora do git).

### Drone FQ777-954

Selecione **FQ777-954 (Wi-Fi)** em Configuração > Protocolo. Ao clicar em Start:

1. O cockpit procura a rede Wi-Fi do drone (padrão: nome contendo `FQ777`) e conecta sozinho. **Se a rede não for encontrada, o equipamento não é ligado** e a mensagem lista as redes visíveis, para ajustar o nome se necessário.  
2. Conecta ao drone (`172.16.10.1`, TCP 8888, UDP 8895) e envia comandos a cada 50 ms.  
3. O vídeo (H.264, 720×576) aparece na janela da câmera.  
4. Ao desligar, envia aceleração zero e devolve o PC à rede Wi-Fi anterior.

| Comando | Joystick (padrão) | Teclado |
|---|---|---|
| Rolagem | manche esquerdo X | A / D |
| Arfagem | manche esquerdo Y | W / S |
| Guinada | manche direito X | Q / E |
| Aceleração | gatilho direito (RT/R2) | seta cima / baixo |
| Corte dos motores | botão B | Espaço |

Após um corte, a aceleração só volta depois que o gatilho e o teclado retornarem ao mínimo. Eixos, zona morta, modo do acelerador (gatilho ou manche), nome e senha da rede e gravação do vídeo ficam na aba **FQ777-954** da configuração (seção `[FQ777]` do `drone.cfg`, separada dos outros drones).

O protocolo, o vídeo, o joystick e o Wi-Fi vêm dos componentes `TAIDroneFQ777`, `TAIH264Decoder`, `TAIJoystick` e `TAIWifi` da Lazarus AI Suite.

### Cheerson CX-10W

Selecione **Cheerson CX-10W** em Configuração > Protocolo e conecte o PC na rede Wi-Fi do drone (`Cheerson-CX-10W-…`). Ao clicar em Start o cockpit abre o canal de controle e os dois canais de vídeo (TCP 8888), envia os pacotes de inicialização e passa a mandar o comando por UDP 8895 a cada 50 ms. IP e portas ficam na seção `[CX10W]` do `drone.cfg` (padrão `172.16.10.1`, 8888, 8895), separada dos outros drones.

Por segurança, **a aceleração fica travada até ser levada ao mínimo** (tecla Q ou manche) depois da conexão. O vídeo é H.264 e usa o `ffmpeg.exe` (na pasta do programa ou no PATH).

### Parrot AR.Drone 2.0

Selecione **Parrot AR.Drone 2.0** e conecte o PC na rede `ardrone2_…`. O cockpit usa o protocolo oficial da Parrot: comandos AT por UDP 5556, telemetria (bateria, altura, atitude) por UDP 5554 e vídeo H.264 por TCP 5555.

| Comando | Joystick / teclado |
|---|---|
| Decolar | botão 3 (tecla 3) ou botão **Decolar** |
| Pousar | botão 4 (tecla 4) ou botão **Pousar** |
| Rolagem / arfagem | manche ou setas / W A S D |
| Subir / descer | eixo Z ou E / Q (centro = mantém a altura) |
| Girar | botões 1 / 2 |
| Emergência | botão **EMERGÊNCIA** na janela do drone |

Com os comandos no centro o drone paira no lugar. Ao desligar, o cockpit manda o drone pousar. Altura máxima, voo ao ar livre e sensibilidade ficam na aba **AR.Drone 2.0** (seção `[ARDRONE]`).

### Drone ESP32 (firmware Cockpit)

A pasta [`firmware/esp32_drone`](firmware/esp32_drone) traz o firmware de um mini quadricóptero com ESP32 + MPU6050 + motores escovados, e o protocolo **CDP** ([PROTOCOLO.md](firmware/esp32_drone/PROTOCOLO.md)). Grave o firmware, conecte o PC na rede `CockpitDrone-XXXX` (senha derivada do MAC `cpXXXXXXXX` impressa na serial, ou configurável em `config.h`) e selecione **Drone ESP32 (firmware Cockpit)**.

Botão 3 arma (só com a aceleração no mínimo), botão 4 desarma; a janela do drone tem **CORTE DOS MOTORES** e **Calibrar**. O firmware corta os motores se perder o sinal por 500 ms (descida de 2 s) ou se o drone capotar. Leia o [README do firmware](firmware/esp32_drone/README.md) e faça o primeiro teste **sem hélices**.

O protocolo **ESP-Drone / OpenDrone (CRTP)** continua disponível para placas com o firmware ESP-Drone da Espressif (rede do drone `192.168.43.42`, UDP 2390).

### Rota de voo (somente drones com GPS)

O botão **Rota de voo** do cockpit abre o planejamento de rota. Ele só fica disponível para drones com GPS e navegação autônoma: hoje, **MAVLink (ArduPilot ou PX4)**, em multirrotores. Com outro drone selecionado (CX-10W, Tello, FQ777-954, OpenDrone, drone ESP32, AR.Drone 2.0 sem o acessório Flight Recorder), a janela não abre e explica o motivo.

1. Em Configuração > Protocolo, escolha **MAVLink**. Na aba MAVLink, informe o IP do drone ou da ponte Wi-Fi e a porta UDP (padrão 14550, a mesma do Mission Planner). Clique em **Start**.
2. Em **Rota de voo**, clique em **Adicionar pelo mapa** e clique nos pontos (ou use Ctrl+clique). Arraste para mover o mapa e use a roda do mouse para o zoom. Também é possível usar a **posição do drone** ou **abrir** um arquivo `.waypoints` do Mission Planner/QGroundControl.
3. Ajuste na tabela a latitude, a longitude, a altitude e a velocidade de cada ponto. Nas opções, defina a altitude de decolagem, a velocidade padrão, a distância máxima do ponto de partida e o que fazer ao terminar: voltar ao ponto de partida, pousar ou pairar no último ponto.
4. **Enviar ao drone**: a rota é validada e enviada; o drone confirma.
5. **Iniciar rota**: depois da confirmação, o drone arma, decola e percorre os pontos. Durante o voo: **Pausar** (pairar), **Continuar**, **Voltar ao ponto de partida** e **Pousar agora**.

Proteções:
- A rota só é enviada com GPS 3D e pelo menos 6 satélites, com a posição e o ponto de partida conhecidos, bateria de pelo menos 30% (quando informada) e o drone desarmado.
- Cada ponto precisa estar entre 2 e 120 m de altitude e entre 0,5 e 15 m/s de velocidade, dentro da geocerca (Alt+clique no mapa) e dentro da distância máxima do ponto de partida.
- Se a rota for alterada depois de enviada, é preciso enviá-la de novo.
- Durante a rota, o manche e o teclado não interferem.

As opções ficam na seção `[ROTA]` do `drone.cfg` e a conexão MAVLink na seção `[MAVLINK]`.

### Funcionalidades Atuais

- Interface gráfica principal com laço de controle em thread dedicada desacoplada da interface de usuário.
- Proteção contra perda de sinal, retorno suave ao pairar e tecla de corte/pânico imediato (Espaço).
- Visualização e calibração de joystick em tempo real com mapeamento de eixos e botões.
- Leitura e decodificação contínua de dados GPS (NMEA).
- Comunicação TCP/UDP resiliente com tratamento de exceções para múltiplos protocolos (CX-10W, FQ777, Tello, MAVLink, AR.Drone, ESP32 CDP).
- Câmera em tempo real com decodificação de vídeo H.264 e modo câmera sintética do simulador.
- Mapa OpenStreetMap integrado com rastreamento de trajeto, waypoints e geocerca.
- Simulador 3D autônomo com aerodinâmica, câmera em tempo real e multiplayer online/local.

### Avaliação do Momento Atual do Desenvolvimento

O projeto possui arquitetura consolidada e foco em segurança de voo: o laço de envio de comandos roda de forma independente da UI (evitando travamentos em modais), as janelas de câmera e mapa operam com renderização contínua e telemetria sincronizada, e o ecossistema inclui simulador 3D completo e servidor multiplayer dedicado.

### Contato

Para dúvidas, colaborações ou sugestões, entre em contato:

- Email: marcelomaurinmartins@gmail.com  
- WhatsApp: +55 16 98143-4112

### Licença

Este projeto está sob uma licença livre, permitindo o uso, modificação e distribuição conforme condições específicas definidas pela equipe de desenvolvimento. Informações detalhadas devem ser obtidas diretamente com os mantenedores.

### Site Oficial

[https://maurinsoft.com.br/wp/projetos-open-source/projeto-cockpit-drone/](https://maurinsoft.com.br/wp/projetos-open-source/projeto-cockpit-drone/)

---

## Seção 2: English

### Project Overview

This project, developed in Object Pascal (Lazarus/Free Pascal), is an application for remote control and monitoring of drones. It integrates multiple devices and features such as joystick, GPS, camera, and maps, providing a central graphical user interface to manage and view the status of the drone and connected peripherals.

### Project Structure

- **main.pas**  
  Implements the main graphical interface. Manages activation and monitoring of controls including joystick, drone, GPS, camera, and map using LEDs and visual controls. Processes joystick commands and controls the drone connection via a dedicated form.

- **config.pas**  
  Provides configuration interface for communication parameters and joystick selection. Allows real-time viewing and testing of joystick axes and buttons, integrated with the main interface.

- **joystick.pas**  
  Physical joystick and gamepad management (DirectInput / SDL), providing real-time axis polling, button mapping, calibration, and deadzone adjustment.

- **gps.pas**  
  Form responsible for reading GPS data from serial port, decoding NMEA sentences, and displaying location, satellite, and signal quality information.

- **camera.pas**  
  Real-time video display and capture (H.264 decoding / FFmpeg streaming) and synthetic camera frames from the 3D simulator (`cockpit_sim_camera.bmp`). Features crosshair overlay, FPS tracking, and video recording.

- **map.pas**  
  Interactive geospatial mapping using OpenStreetMap (MapViewer), featuring real-time flight path tracking, waypoint navigation, and geofencing.

- **Official 3D Simulator (`simulador/`)**  
  Standalone 3D flight simulator project located in `simulador/` (`simulador.lpi`), providing 6DOF flight dynamics, shared synthetic video frames, and multiplayer support. Units `src/simulator_*.pas` serve as internal telemetry bridges.

- **Drone protocols**  
  The protocols live in the [Lazarus AI Suite (CHATGPT)](https://github.com/marcelomaurin/CHATGPT) `openai_drone` package, so other applications can reuse them: `TAIDroneCX10W`, `TAIDroneMavlink`, `TAIDroneTello`, `TAIDroneESPDrone`, `TAIDroneFQ777`, `TAIDroneARDrone` and `TAIDroneCDP`. The cockpit windows (`conection*.pas`) share the base `conexaodrone.pas` and only configure their component and forward the sticks.

- **conectionfq777.pas**  
  Dedicated connection for the FQ777-954 quadcopter: finds and joins the drone's Wi-Fi automatically (the drone is not started if the network is not found), proportional flight control and H.264 camera, built on the Lazarus AI Suite components `TAIDroneFQ777`, `TAIH264Decoder`, `TAIJoystick` and `TAIWifi`.

- **funcs.pas**  
  Contains utility functions like `MAPA` for linear mapping of analog values to byte range (0-255), essential for signal normalization.

### Installation

1. Install Lazarus and Free Pascal in your development environment.  
2. Install the [Lazarus AI Suite (CHATGPT)](https://github.com/marcelomaurin/CHATGPT) packages: `openai_core`, `openai_input`, `openai_hardware`, `openai_video` and `openai_drone`.  
3. Clone or download the project source.  
4. Open `src/drone.lpi` in Lazarus.  
5. Compile and run the project.  
6. For the camera (FQ777-954, CX-10W, Tello and AR.Drone), `ffmpeg.exe` must be next to `drone.exe` (or on the PATH). The installer already ships it; to build the installer, copy `ffmpeg.exe` from the BtbN/FFmpeg-Builds win64-gpl package into `install/redist`.

### Current Features

- Main GUI with decoupled dedicated control thread isolated from UI freezes.
- Failsafe signal protection, auto-hover recentering, and panic/kill switch (Space bar).
- Real-time joystick visualization, calibration, axis mapping, and deadzone configuration.
- Serial GPS data streaming and NMEA decoding.
- Resilient TCP/UDP communication and robust exception handling across multiple drone protocols.
- Live camera with H.264 video decoding and shared memory synthetic simulator feed.
- Integrated OpenStreetMap with real-time breadcrumbs, flight plan waypoints, and geofence.
- Standalone 3D flight simulator with aerodynamic simulation and local/remote multiplayer.

### Current Development Status

The project features a mature and flight-safe architecture: control commands run on a dedicated worker thread, camera and map modules are fully operational with live data, and the platform includes a complete 3D simulator and multiplayer infrastructure.

### Contact

For questions, collaboration, or suggestions, contact:

- Email: marcelomaurinmartins@gmail.com  
- WhatsApp: +55 16 98143-4112

### License

This project is under a free license that allows usage, modification, and distribution under specific terms defined by the development team. Detailed info should be obtained directly from maintainers.

### Official Website

[https://maurinsoft.com.br/wp/projetos-open-source/projeto-cockpit-drone/](https://maurinsoft.com.br/wp/projetos-open-source/projeto-cockpit-drone/)

---

## Sección 3: Español

### Visión General del Proyecto

Este proyecto, desarrollado en Object Pascal (Lazarus/Free Pascal), es una aplicación para control remoto y monitoreo de drones. Integra múltiples dispositivos y funcionalidades como joystick, GPS, cámara y mapas, ofreciendo una interfaz gráfica central para gestionar y visualizar el estado del dron y los periféricos conectados.

### Estructura del Proyecto

- **main.pas**  
  Implementa la interfaz gráfica principal del sistema. Gestiona activación y monitoreo de controles, incluyendo joystick, dron, GPS, cámara y mapa mediante LEDs y controles visuales. Procesa comandos del joystick y controla la conexión con el dron a través de un formulario específico.

- **config.pas**  
  Interfaz para configurar parámetros de comunicación y selección del joystick. Permite visualización y prueba en tiempo real de ejes y botones del controlador, integrada con la interfaz principal.

- **joystick.pas**  
  Archivo actualmente vacío, reservado para futuras implementaciones relacionadas con joystick.

- **gps.pas**  
  Formulario encargado de la lectura de datos GPS vía puerto serial, decodificación de sentencias NMEA y presentación de información de ubicación, satélites y calidad de señal.

- **camera.pas**  
  Formulario visual con cuadrícula personalizada, imagen y etiquetas para presentación de datos de cámara. No posee lógica implementada actualmente.

- **map.pas**  
  Formulario con componente de cuadrícula para mostrar mapas o área visual, sin lógica funcional implementada.

- **Protocolos de los drones**  
  Los protocolos están en el paquete `openai_drone` de la [Lazarus AI Suite (CHATGPT)](https://github.com/marcelomaurin/CHATGPT): `TAIDroneCX10W`, `TAIDroneMavlink`, `TAIDroneTello`, `TAIDroneESPDrone`, `TAIDroneFQ777`, `TAIDroneARDrone` y `TAIDroneCDP`. Las ventanas de conexión (`conection*.pas`) comparten la base `conexaodrone.pas`.

- **funcs.pas**  
  Contiene funciones utilitarias como `MAPA`, que realiza mapeo lineal de valores analógicos al rango byte (0-255), fundamental para la normalización de señales.

### Instalación

1. Instale Lazarus y Free Pascal en su entorno de desarrollo.  
2. Clone u obtenga el código fuente del proyecto.  
3. Abra el archivo `main.pas` en Lazarus.  
4. Compile y ejecute el proyecto.

### Funcionalidades Actuales

- Interfaz gráfica principal para control y monitoreo del dron y dispositivos periféricos.  
- Visualización y configuración en tiempo real del estado del joystick.  
- Lectura y decodificación de datos GPS vía puerto serial.  
- Comunicación TCP/UDP para envío de comandos y monitoreo del dron.  
- Interfaces visuales básicas para cámara y mapa (sin lógica implementada).  
- Utilitario para mapeo lineal de señales analógicas.

### Estado Actual del Desarrollo

El proyecto está en una fase intermedia con infraestructura básica y principales integraciones operativas. La interfaz principal y módulo de configuración funcionan para joystick y comunicación con el dron. La funcionalidad GPS está parcialmente implementada con decodificación y visualización básica. Módulos como joystick.pas y formularios de cámara/mapa carecen de código funcional. La función de mapeo existe pero sin manejo robusto de errores. Se recomienda avanzar en robustez, manejo de excepciones y complementación funcional.

### Contacto

Para dudas, colaboraciones o sugerencias, contacte a:

- Email: marcelomaurinmartins@gmail.com  
- WhatsApp: +55 16 98143-4112

### Licencia

Este proyecto está bajo una licencia libre, permitiendo uso, modificación y distribución conforme condiciones específicas definidas por el equipo de desarrollo. Información detallada debe ser solicitada directamente a los mantenedores.

### Sitio Oficial

[https://maurinsoft.com.br/wp/projetos-open-source/projeto-cockpit-drone/](https://maurinsoft.com.br/wp/projetos-open-source/projeto-cockpit-drone/)

---


## Simulador e Multiplayer (Mundo Compartilhado)

O projeto conta com o **Simulador Cockpit Drone** (`simulador/simulador.exe`), um executável independente que emula os drones reais (Tello, AR.Drone 2.0, MAVLink, CX-10W, FQ777-954, drone ESP32 e ESP-Drone) utilizando os mesmos protocolos de comunicação sobre imagem de satélite do Google ou ruas do OpenStreetMap.

> **IMPORTANTE — ENTRADA MULTIPLAYER:**  
> A entrada no **Multiplayer (Mundo Compartilhado)** é feita exclusivamente através do **Simulador** (`simulador.exe`), e **NÃO no Cockpit Drone** (`drone.exe`).  
> 
> - **Servidor oficial de produção:** `https://maurinsoft.com.br/cockpit/`  
> - **Como funciona:**  
>   1. Abra o `simulador.exe`.  
>   2. No painel **Mundo compartilhado**, aponte para o servidor oficial `https://maurinsoft.com.br/cockpit/`, informe seu **Apelido** e clique em **Entrar**.  
>   3. O simulador sincroniza com o servidor mundial e exibe no mapa e na câmera 3D outros drones voando em um raio de até 2.000 metros (2 km).  
>   4. O **Cockpit Drone** se conecta localmente ao simulador (`127.0.0.1`), permitindo pilotar, monitorar telemetria e visualizar os quadros da câmera.

Documentação detalhada: [simulador/docs/LEIAME.md](simulador/docs/LEIAME.md).
