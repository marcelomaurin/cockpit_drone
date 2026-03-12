# Sistema de Controle e Monitoramento de Drones

## Visão Geral do Projeto / Project Overview / Visión General del Proyecto

Este projeto, desenvolvido em Object Pascal (Lazarus/Free Pascal), constitui uma aplicação para controle remoto e monitoramento de drones. Ele integra múltiplos dispositivos e funcionalidades, tais como joystick, GPS, câmera e mapas, oferecendo uma interface gráfica central para o usuário gerenciar e visualizar o status do drone e dos periféricos conectados.

This project, developed in Object Pascal (Lazarus/Free Pascal), is an application for remote control and monitoring of drones. It integrates multiple devices and features such as joystick, GPS, camera, and maps, providing a central graphical user interface to manage and view the status of the drone and connected peripherals.

Este proyecto, desarrollado en Object Pascal (Lazarus/Free Pascal), es una aplicación para el control remoto y monitoreo de drones. Integra múltiples dispositivos y funcionalidades como joystick, GPS, cámara y mapas, ofreciendo una interfaz gráfica central para que el usuario gestione y visualice el estado del drone y los periféricos conectados.

---

## Estrutura do Projeto / Project Structure / Estructura del Proyecto

- **main.pas**  
  Implementa a interface gráfica principal do sistema. Gerencia a ativação e monitoramento dos controles, incluindo o joystick, atualizando indicadores visuais e controlando o drone via formulário de conexão.

- **config.pas**  
  Fornece a interface para configuração dos parâmetros de comunicação e seleção do joystick. Permite a visualização e teste em tempo real dos eixos e botões do controlador, integrando-se com o formulário principal.

- **joystick.pas**  
  Atualmente é um arquivo vazio, reservado para implementação futura das funcionalidades específicas do joystick.

- **gps.pas**  
  Contém o formulário que controla a leitura de dados GPS através da porta serial, decodificando sentenças NMEA para exibir informações de posicionamento, satélites e qualidade do sinal. A interface permanece responsiva durante a captura dos dados.

- **camera.pas**  
  Define uma interface visual para apresentação de imagens da câmera, contendo uma grade customizada, imagem e rótulos. Não possui lógica implementada até o momento.

- **map.pas**  
  Cria um formulário simples para exibição gráfica de mapas através de um componente grid. Serve como base visual para manipulações futuras, sem eventos ou lógica atual implementados.

- **conectioncx10w.pas**  
  Implementa a comunicação via TCP/UDP com o drone, podendo enviar e receber pacotes, habilitar funcionalidades específicas e transmitir comandos do joystick em tempo real, com tratamento de erros e monitoramento integrado.

- **funcs.pas**  
  Contém funções utilitárias, dentre elas a função `MAPA`, que realiza mapeamento linear de valores analógicos, convertendo-os para o intervalo byte standard (0-255), fundamental para normalização e controle do sistema.

---

## Instalação / Installation / Instalación

1. Tenha instalado o Lazarus e Free Pascal em seu ambiente de desenvolvimento.  
2. Clone ou obtenha os arquivos fonte do projeto.  
3. Abra o projeto principal (`main.pas`) no Lazarus.  
4. Compile e execute o projeto.

---

## Funcionalidades Atuais / Current Features / Funcionalidades Actuales

- Interface gráfica principal para controle e monitoramento do drone.  
- Configuração e visualização do estado do joystick em tempo real.  
- Leitura e processamento de dados GPS via porta serial com decodificação NMEA.  
- Comunicação via TCP/UDP para envio de comandos e monitoramento do drone.  
- Exibição inicial de interfaces para câmera e mapa (estrutura visual sem lógicas implementadas).  
- Função de mapeamento linear para normalização dos sinais analógicos.

---

## Avaliação do Momento Atual do Desenvolvimento / Current Development Status / Evaluación del Estado Actual del Desarrollo

O projeto está em estágio intermediário, com a infraestrutura básica do sistema e integração dos principais dispositivos estabelecida. A interface principal e configuração do joystick estão em funcionamento, assim como a comunicação de dados GPS e controle via rede está implementada.

Entretanto, módulos como joystick.pas e alguns formulários como camera.pas e map.pas possuem estrutura visual, mas ainda carecem de lógica e funcionalidades avançadas. A função de mapeamento está presente mas não contempla tratamento de erros robusto. A documentação e validação completa, especialmente para tratamento de exceções e integrações finais, ainda são necessárias para um sistema estável e avançado.

---

## Contato / Contact / Contacto

Para dúvidas, colaboração ou sugestões, entrar em contato com a equipe de desenvolvimento via [email ou outro meio].

---

## Licença / License / Licencia

Este projeto está sob uma licença livre, permitindo que qualquer usuário utilize, modifique e distribua o código-fonte conforme as condições específicas da licença adotada pela equipe de desenvolvimento. Detalhes precisos sobre os termos devem ser obtidos diretamente com a equipe mantenedora do projeto.

This project is under a free license, allowing any user to use, modify, and distribute the source code under the specific conditions of the license adopted by the development team. Precise details about the terms should be obtained directly from the project's maintainers.

Este proyecto está bajo una licencia libre, que permite a cualquier usuario utilizar, modificar y distribuir el código fuente conforme las condiciones específicas de la licencia adoptada por el equipo de desarrollo. Los detalles precisos sobre los términos deben obtenerse directamente del equipo mantenedor del proyecto.

---

## Site Oficial / Official Website / Sitio Oficial

Para mais informações, documentação e atualizações do projeto, visite o site oficial do projeto:  
[https://maurinsoft.com.br/wp/projetos-open-source/projeto-cockpit-drone/](https://maurinsoft.com.br/wp/projetos-open-source/projeto-cockpit-drone/)

---
