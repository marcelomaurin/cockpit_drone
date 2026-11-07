[Português](README.md) · [English](README.en.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [日本語](README.ja.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

# Cockpit Drone - Control, Telemetry and Simulation System

A comprehensive application developed in Object Pascal (Lazarus / Free Pascal) for remote piloting, real-time telemetry monitoring, and 3D physical simulation of unmanned aerial vehicles (UAVs). Integrates analog joystick control, GPS sensors, live video streams (H.264 & synthetic camera), tactical geospatial maps (OpenStreetMap), and multiple drone communication protocols.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Project Structure](#project-structure)
3. [Supported Drone Protocols](#supported-drone-protocols)
4. [Official 3D Simulator & Multiplayer](#official-3d-simulator--multiplayer)
5. [Controls: Joystick vs Keyboard](#controls-joystick-vs-keyboard)
6. [Installation & Requirements](#installation--requirements)
7. [Autonomous Flight Planning](#autonomous-flight-planning)
8. [Compiled Binaries Download](#compiled-binaries-download)
9. [Contact & License](#contact--license)

---

## Project Overview

**Cockpit Drone** is built with a dedicated background thread architecture decoupled from the Graphical User Interface (GUI). This guarantees that critical flight loops (50 ms command cycles) and incoming telemetry packets are never stalled by modal dialogs or UI freezes.

Key Features:
- **Failsafe Flight Loop:** Independent worker thread with emergency kill-switch on Spacebar and smooth hover recovery.
- **Multi-Window Tactical Interface:** Flight instruments, LED telemetry status, military-grade Head-Up Display (HUD), interactive map tracking, and low-latency video feed.
- **Complete Ecosystem:** Bundles the **Official 3D Flight Simulator** (`simulador/simulador.exe`) with 6DOF dynamics and a dedicated PHP/WebSocket multiplayer backend (`PHP/`).

---

## Project Structure

- **`src/main.pas`:** Main GUI dashboard managing visual controls, LED indicators, command shortcuts, and subsystem telemetry.
- **`src/config.pas`:** Configuration panel with protocol selection, real-time joystick calibration, key binding tester, and language selector.
- **`src/joystick.pas`:** Hardware joystick and gamepad polling (DirectInput / SDL) with axis scaling and deadzone filtering.
- **`src/gps.pas`:** Serial port receiver and NMEA decoder displaying coordinates, satellites in view, and fix status.
- **`src/camera.pas`:** H.264 video pipeline via FFmpeg and shared memory synthetic simulator camera feed (`cockpit_sim_camera.bmp`).
- **`src/map.pas`:** OpenStreetMap (MapViewer) tracking breadcrumbs, waypoints, and customizable geofences.
- **`simulador/`:** Standalone 3D flight simulator project (`simulador.lpi`), emulating flight dynamics, physics, and synthetic camera.
- **`PHP/`:** HTTP/WebSocket shared world server synchronizing drones within a 2 km proximity bubble.

---

## Supported Drone Protocols

Drone protocols are modular components from the [Lazarus AI Suite (CHATGPT)](https://github.com/marcelomaurin/CHATGPT) (`openai_drone` package):

| Drone / Protocol | Component | Channel & Characteristics |
|---|---|---|
| **Cheerson CX-10W** | `TAIDroneCX10W` | Wi-Fi UDP 8895 / TCP 8888, 50 ms cycles, H.264 video |
| **MAVLink (ArduPilot/PX4)** | `TAIDroneMavlink` | UDP 14550, full telemetry, autonomous waypoints & mission plans |
| **DJI / Ryze Tello** | `TAIDroneTello` | Wi-Fi UDP text commands/state, H.264 video stream |
| **ESP-Drone / OpenDrone** | `TAIDroneESPDrone` | Espressif CRTP protocol over UDP 2390 |
| **FQ777-954** | `TAIDroneFQ777` | Automatic Wi-Fi association, proportional control, H.264 video |
| **Parrot AR.Drone 2.0** | `TAIDroneARDrone` | AT commands (UDP 5556), navdata (UDP 5554), video (TCP 5555) |
| **ESP32 Drone (Cockpit)** | `TAIDroneCDP` | Open source custom CDP protocol with ESP32 + MPU6050 |

---

## Official 3D Simulator & Multiplayer

The repository includes the **Cockpit Drone Simulator** (`simulador/simulador.exe`), a standalone 3D flight simulator running over satellite or OpenStreetMap imagery.

> **IMPORTANT — MULTIPLAYER ACCESS:**  
> Connecting to the **Multiplayer Shared World** is initiated via the **Simulator** (`simulador.exe`):  
> 
> 1. Launch `simulador.exe`.  
> 2. In the **Shared world** panel, enter the server URL (official: `https://maurinsoft.com.br/cockpit/`) and your **Callsign**, then click **Join**.  
> 3. Aircraft within **2 km** will appear on your map and 3D camera.  
> 4. **Cockpit Drone** (`drone.exe`) connects locally to `127.0.0.1` to pilot, monitor telemetry, and display flight instruments.

---

## Controls: Joystick vs Keyboard

- **Analog Joystick (Recommended):** Smooth and continuous 4-axis control (pitch, roll, yaw, and throttle). Supports flight sticks, Xbox/PlayStation gamepads, and USB RC transmitters.
- **Keyboard:** Full keyboard navigation with auto-hover decay and **panic kill switch** on Spacebar.

### Primary Key Map

| Command | Primary Key | Alternate Key | Effect |
|---|---|---|---|
| **Forward (Pitch +)** | `W` | `Up Arrow` | Tilts nose down / forward flight |
| **Backward (Pitch -)** | `S` | `Down Arrow` | Tilts nose up / brake |
| **Left (Roll -)** | `A` | `Left Arrow` | Banks left |
| **Right (Roll +)** | `D` | `Right Arrow` | Banks right |
| **Climb (Throttle +)** | `E` | `Page Up` | Increases motor power / altitude |
| **Descend (Throttle -)** | `Q` | `Page Down` | Decreases throttle / descent |
| **Rotate Left (Yaw -)** | `1` or `Z` | Button 1 | Counter-clockwise yaw spin |
| **Rotate Right (Yaw +)** | `2` or `X` | Button 2 | Clockwise yaw spin |
| **Takeoff / Arm** | `3` or `Insert` | Button 3 | Arms motors or auto-takeoff |
| **Land / Disarm** | `4` or `Delete` | Button 4 | Auto-land or disarms motors |
| **Hover / Center** | `5` or `R` / `Home` | Button 5 | Neutralizes tilt and stabilizes hover |
| **PANIC KILL** | `Spacebar` | Emergency Button | Instantly cuts all motors to zero |
| **Tactical HUD** | `T` | — | Toggles military Head-Up Display |
| **Camera Window** | `C` | — | Toggles live video feed |
| **Map Window** | `M` | — | Toggles tactical map |
| **GPS Window** | `G` | — | Toggles GPS telemetry panel |

---

## Installation & Requirements

1. Install **Lazarus IDE** and **Free Pascal**.
2. Install dependencies from [Lazarus AI Suite (CHATGPT)](https://github.com/marcelomaurin/CHATGPT).
3. Open `src/drone.lpi` in Lazarus and build.
4. For video decoding, ensure `ffmpeg.exe` is in the same directory as `drone.exe` or available on system PATH.

---

## Autonomous Flight Planning

For autonomous GPS-equipped UAVs (such as MAVLink / ArduPilot / PX4):
1. Click the **Flight Plan** button on the main dashboard.
2. Add waypoints directly on the OpenStreetMap interface or import `.waypoints` files.
3. Configure altitude, airspeed, geofence radius, and end-of-mission behavior (RTL, Land, or Hover).
4. Click **Send to Drone** and confirm execution.

---

## Compiled Binaries Download

Pre-compiled Windows binaries and installer are located in the [`bin/`](bin/) folder:
- **`bin/setup_cockpit_drone_0.41.exe`:** Full Windows installer with simulator, cockpit, and runtime assets.
- **`bin/drone.exe`:** Cockpit Drone executable.
- **`bin/simulador.exe`:** 3D Flight Simulator executable.

---

## Contact & License

- **Author:** Marcelo Maurin Martins
- **Email:** marcelomaurinmartins@gmail.com
- **WhatsApp:** +55 16 98143-4112
- **Official Website:** [Maurinsoft - Cockpit Drone](https://maurinsoft.com.br/wp/projetos-open-source/projeto-cockpit-drone/)
- **License:** Open Source under permissive free software terms.
