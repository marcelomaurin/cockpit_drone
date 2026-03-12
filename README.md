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
  Arquivo atualmente vazio, reservado para implementações futuras relacionadas ao joystick.

- **gps.pas**  
  Formulário responsável pela leitura de dados GPS via porta serial, decodificação das sentenças NMEA e apresentação das informações de localização, satélites e qualidade do sinal.

- **camera.pas**  
  Formulário visual com grade customizada, imagem e etiquetas para apresentação de dados da câmera. Não possui lógica implementada atualmente.

- **map.pas**  
  Formulário com componente de grade para exibição de mapa ou área visual, sem lógica funcional implementada.

- **conectioncx10w.pas**  
  Gerencia a comunicação TCP/UDP com o drone CX10W. Envia pacotes mágicos para handshake e ativação de vídeo, transmite comandos do joystick em tempo real e trata erros e logs da conexão.

- **funcs.pas**  
  Contém funções utilitárias, como `MAPA`, que realiza mapeamento linear de valores analógicos para o intervalo byte (0-255), fundamental para a normalização dos sinais.

### Instalação

1. Instale Lazarus e Free Pascal no seu ambiente de desenvolvimento.  
2. Clone ou obtenha o código-fonte do projeto.  
3. Abra o arquivo `main.pas` no Lazarus.  
4. Compile e execute o projeto.

### Funcionalidades Atuais

- Interface gráfica principal para controle e monitoramento do drone e dispositivos periféricos.  
- Visualização e configuração em tempo real dos estados do joystick.  
- Leitura e decodificação de dados GPS via porta serial.  
- Comunicação TCP/UDP para envio de comandos ao drone e monitoramento da conexão.  
- Interfaces visuais básicas para câmera e mapa (sem lógica implementada).  
- Utilitário para mapeamento linear de sinais analógicos.

### Avaliação do Momento Atual do Desenvolvimento

O projeto está em estágio intermediário, com base do sistema e integração dos dispositivos principais funcionando. Interfaces principais e módulo de configuração operam adequadamente para joystick e comunicação de drone. GPS está parcialmente implementado com decodificação e apresentação básica. Módulos como joystick.pas e formulários de câmera e mapa carecem de código funcional. A função de mapeamento existe, porém sem tratamento robusto de erros. Recomenda-se progresso em robustez, tratamento de exceções e complementação funcional.

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
  Currently empty file, reserved for future joystick-related implementations.

- **gps.pas**  
  Form responsible for reading GPS data from serial port, decoding NMEA sentences, and displaying location, satellite, and signal quality information.

- **camera.pas**  
  Visual form with custom grid, image and labels for camera data display. Currently has no implemented logic.

- **map.pas**  
  Form with grid component for map or visual area display, without functional logic implemented yet.

- **conectioncx10w.pas**  
  Manages TCP/UDP communication with CX10W drone. Sends magic packets for handshake and video activation, streams joystick commands in real-time, and handles connection errors and logging.

- **funcs.pas**  
  Contains utility functions like `MAPA` for linear mapping of analog values to byte range (0-255), essential for signal normalization.

### Installation

1. Install Lazarus and Free Pascal in your development environment.  
2. Clone or download the project source.  
3. Open `main.pas` in Lazarus.  
4. Compile and run the project.

### Current Features

- Main GUI for drone and peripheral control and monitoring.  
- Real-time visualization and configuration of joystick states.  
- GPS data reading and NMEA decoding from serial port.  
- TCP/UDP communication for sending commands and monitoring the drone.  
- Basic camera and map visual interfaces (without implemented logic).  
- Utility for linear mapping of analog signals.

### Current Development Status

The project is in an intermediate phase, with basic system infrastructure and main device integrations operational. The main UI and configuration module function for joystick and drone communication. GPS functionality includes basic decoding and display. Modules like joystick.pas and camera/map forms lack functional code. The mapping function exists but lacks robust error handling. Development should focus on robustness, exception handling, and feature completion.

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

- **conectioncx10w.pas**  
  Gestiona la comunicación TCP/UDP con el dron CX10W. Envía paquetes mágicos para handshake y activación de vídeo, transmite comandos del joystick en tiempo real y maneja errores y registro de conexión.

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
