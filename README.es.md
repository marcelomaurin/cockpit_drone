[Português](README.md) · [English](README.en.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [日本語](README.ja.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

# Cockpit Drone - Sistema de Control, Telemetría y Simulación

Aplicación integral desarrollada en Object Pascal (Lazarus / Free Pascal) para control remoto, monitoreo de telemetría y simulación física 3D de drones y vehículos aéreos no tripulados. Integra control por joystick analógico, sensores GPS, transmisión de vídeo en vivo (H.264 y cámara sintética), mapas tácticos geoespaciales (OpenStreetMap) y soporte para múltiples protocolos de vuelo.

---

<p align="center">
  <img src="docs/img/cockpit-principal.png" alt="Ventana principal del Cockpit Drone 0.46" width="49%">
  <img src="docs/img/simulador-mapa.png" alt="Simulador del Cockpit Drone 0.46 con OpenStreetMap" width="49%">
</p>
<p align="center"><em>Cockpit (izquierda) y Simulador (derecha), versión 0.46 — capturas de pantalla reales de los ejecutables del repositorio.</em> · <a href="docs/TELAS_0.46.md">Guía ilustrada de las pantallas, en portugués</a></p>

## Índice

1. [Visión General](#visión-general)
2. [Estructura del Proyecto](#estructura-del-proyecto)
3. [Protocolos Compatibles](#protocolos-compatibles)
4. [Simulador 3D Oficial y Multijugador](#simulador-3d-oficial-y-multijugador)
5. [Controles: Joystick vs Teclado](#controles-joystick-vs-teclado)
6. [Instalación y Requisitos](#instalación-y-requisitos)
7. [Planificación de Rutas de Vuelo](#planificación-de-rutas-de-vuelo)
8. [Descarga de Binarios Compilados](#descarga-de-binarios-compilados)
9. [Contacto y Licencia](#contacto-y-licencia)

---

## Visión General

El sistema **Cockpit Drone** cuenta con un bucle de control en hilo independiente desacoplado de la interfaz gráfica (UI). Esto asegura que la transmisión continua de comandos de vuelo (cada 50 ms) y la recepción de telemetría nunca sufran retrasos ni bloqueos por ventanas modales.

Características principales:
- **Bucle de Vuelo Seguro:** Hilo de trabajo independiente con corte de pánico en la barra espaciadora y retorno suave a sustentación (*hover*).
- **Interfaz Táctica Multiventana:** Instrumentos de vuelo, estado de telemetría por LEDs, HUD militar, mapa interactivo y vídeo de baja latencia.
- **Ecosistema Completo:** Incluye el **Simulador 3D Oficial** (`simulador/simulador.exe`) con física 6DOF y el servidor multijugador PHP/WebSocket (`PHP/`).

---

## Estructura del Proyecto

- **`src/main.pas`:** Panel principal del sistema con instrumentación visual, LEDs de estado y gestión de módulos.
- **`src/config.pas`:** Configuración de protocolos, calibración de joystick en tiempo real, prueba de teclado y selector de idioma.
- **`src/joystick.pas`:** Gestión de controladores físicos (DirectInput / SDL) con ajuste de zonas muertas.
- **`src/gps.pas`:** Lectura de puerto serie y decodificación NMEA con estado de satélites y fijación GPS.
- **`src/camera.pas`:** Decodificación de vídeo H.264 mediante FFmpeg y recepción de cámara sintética (`cockpit_sim_camera.bmp`).
- **`src/map.pas`:** Mapa geoespacial OpenStreetMap con rastro de vuelo, waypoints y geocercas.
- **`simulador/`:** Simulador físico 3D independiente con dinámica aerodinámica y soporte de red.
- **`PHP/`:** Servidor de simulación compartida que sincroniza drones en un radio de hasta 2 km.

---

## Protocolos Compatibles

Los protocolos forman parte de la biblioteca [Lazarus AI Suite (CHATGPT)](https://github.com/marcelomaurin/CHATGPT) (paquete `openai_drone`):

| Dron / Protocolo | Componente | Descripción y Canales |
|---|---|---|
| **Cheerson CX-10W** | `TAIDroneCX10W` | Wi-Fi UDP 8895 / TCP 8888, comandos a 50 ms y vídeo H.264 |
| **MAVLink (ArduPilot/PX4)** | `TAIDroneMavlink` | UDP 14550, telemetría completa y misiones autónomas |
| **DJI / Ryze Tello** | `TAIDroneTello` | Wi-Fi UDP comandos/telemetría y vídeo H.264 |
| **ESP-Drone / OpenDrone** | `TAIDroneESPDrone` | Protocolo CRTP sobre UDP 2390 |
| **FQ777-954** | `TAIDroneFQ777` | Conexión Wi-Fi automática, control proporcional y cámara |
| **Parrot AR.Drone 2.0** | `TAIDroneARDrone` | Comandos AT (UDP 5556), telemetría (UDP 5554) y vídeo TCP 5555 |
| **Drone ESP32 (Cockpit)** | `TAIDroneCDP` | Protocolo CDP propio para controladora ESP32 + MPU6050 |

---

## Simulador 3D Oficial y Multijugador

El proyecto incluye el **Simulador Cockpit Drone** (`simulador/simulador.exe`), ejecutable autónomo con soporte multijugador online.

> **IMPORTANTE — ACCESO MULTIJUGADOR:**  
> La conexión al **Mundo Compartido** se realiza desde el **Simulador** (`simulador.exe`):  
> 
> 1. Abre `simulador.exe`.  
> 2. En el panel **Mundo compartido**, introduce la dirección del servidor (oficial: `https://maurinsoft.com.br/cockpit/`) y tu **Alias**, y pulsa **Entrar**.  
> 3. Los drones en un radio de hasta **2 km** aparecerán en el mapa y la cámara.  
> 4. **Cockpit Drone** (`drone.exe`) se conecta localmente a `127.0.0.1` para pilotar y visualizar telemetría.

---

## Controles: Joystick vs Teclado

- **Joystick Analógico (Recomendado):** Control continuo y suave en los 4 ejes de vuelo. Compatible con mandos USB, palancas HOTAS y emisoras RC.
- **Teclado:** Control completo mediante teclado con corte de emergencia en la barra espaciadora.

### Mapa de Teclas Principal

| Comando | Tecla Principal | Tecla Alternativa | Acción |
|---|---|---|---|
| **Adelante (Pitch +)** | `W` | `Flecha Arriba` | Inclina morro abajo / avance |
| **Atrás (Pitch -)** | `S` | `Flecha Abajo` | Inclina morro arriba / freno |
| **Izquierda (Roll -)** | `A` | `Flecha Izquierda` | Alabeo a la izquierda |
| **Derecha (Roll +)** | `D` | `Flecha Derecha` | Alabeo a la derecha |
| **Subir (Throttle +)** | `E` | `Page Up` | Incrementa aceleración y altitud |
| **Bajar (Throttle -)** | `Q` | `Page Down` | Reduce potencia y desciende |
| **Girar Izquierda (Yaw -)** | `1` o `Z` | Botón 1 | Guiñada antihoraria |
| **Girar Derecha (Yaw +)** | `2` o `X` | Botón 2 | Guiñada horaria |
| **Despegar / Armar** | `3` o `Insert` | Botón 3 | Despegue automático o armado |
| **Aterrizar / Desarmar** | `4` o `Delete` | Botón 4 | Aterrizaje automático |
| **Flotar / Centrar** | `5` o `R` / `Home` | Botón 5 | Centra mandos y estabiliza |
| **CORTE DE PÁNICO** | `Espacio` | Botón Emergencia | Apagado inmediato de motores |
| **HUD Táctico** | `T` | — | Alterna el Head-Up Display |
| **Ventana Cámara** | `C` | — | Abre/cierra el vídeo en vivo |
| **Ventana Mapa** | `M` | — | Abre/cierra el mapa de navegación |
| **Ventana GPS** | `G` | — | Abre/cierra telemetría GPS |

---

## Instalación y Requisitos

1. Instala **Lazarus IDE** y **Free Pascal**.
2. Instala los paquetes de [Lazarus AI Suite (CHATGPT)](https://github.com/marcelomaurin/CHATGPT).
3. Abre `src/drone.lpi` en Lazarus y compila.
4. Para la cámara, asegúrate de tener `ffmpeg.exe` junto a `drone.exe` o en el PATH del sistema.

---

## Descarga de Binarios Compilados

Encuentra los binarios e instalador listos en la carpeta [`bin/`](bin/):
- **`bin/setup_cockpit_drone_0.41.exe`:** Instalador completo para Windows.
- **`bin/drone.exe`:** Ejecutable de Cockpit Drone.
- **`bin/simulador.exe`:** Ejecutable del Simulador 3D.

---

## Contacto y Licencia

- **Autor:** Marcelo Maurin Martins
- **E-mail:** marcelomaurinmartins@gmail.com
- **WhatsApp:** +55 16 98143-4112
- **Sitio Oficial:** [Maurinsoft - Cockpit Drone](https://maurinsoft.com.br/wp/projetos-open-source/projeto-cockpit-drone/)
- **Licencia:** Código abierto bajo licencia permisiva.
