[Português](README.md) · [English](README.en.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [日本語](README.ja.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

# Cockpit Drone - Steuerung, Telemetrie und 3D-Simulation

Vollständige Anwendung entwickelt in Object Pascal (Lazarus / Free Pascal) für Fernsteuerung, Echtzeit-Telemetrie und 3D-Physiksimulation von Drohnen und unbemannten Fluggeräten (UAV). Unterstützt analoge Joysticks, serielle GPS-Empfänger, Live-Videostreams (H.264 & synthetische Kamera), OpenStreetMap-Karten und diverse Flugprotokolle.

---

## Inhaltsverzeichnis

1. [Projektübersicht](#projektübersicht)
2. [Projektstruktur](#projektstruktur)
3. [Unterstützte Protokolle](#unterstützte-protokolle)
4. [3D-Simulator & Multiplayer](#3d-simulator--multiplayer)
5. [Steuerung: Joystick vs. Tastatur](#steuerung-joystick-vs-tastatur)
6. [Download kompilierter Binärdateien](#download-kompilierter-binärdateien)
7. [Kontakt und Lizenz](#kontakt-und-lizenz)

---

## Projektübersicht

**Cockpit Drone** arbeitet mit einem dedizierten Hintergrund-Thread, der von der Benutzeroberfläche (GUI) entkoppelt ist. Dies garantiert, dass die Steuerungszyklen (50 ms) und der Telemetrieempfang niemals durch UI-Ereignisse blockiert werden.

Wesentliche Merkmale:
- **Ausfallsichere Steuerung:** Separater Worker-Thread mit Not-Aus über die Leertaste und sanfter Rückkehr in den Schwebeflug.
- **Taktische Benutzeroberfläche:** Fluginstrumente, LED-Telemetriestatus, Head-Up-Display (HUD), Kartenverfolgung und Videobild.
- **Gesamtsystem:** Enthält den eigenständigen **3D-Simulator** (`simulador/simulador.exe`) und den PHP/WebSocket-Server (`PHP/`).

---

## 3D-Simulator & Multiplayer

> **WICHTIGER HINWEIS ZUM MEHRSPIELERMODUS:**  
> Der Beitritt zur **Gemeinsamen Welt (Multiplayer)** erfolgt über den **Simulator** (`simulador.exe`):  
> 1. Starten Sie `simulador.exe`.  
> 2. Tragen Sie im Bereich **Gemeinsame Welt** die Server-Adresse (`https://maurinsoft.com.br/cockpit/`) und Ihren Rufnamen ein und klicken Sie auf **Beitreten**.  
> 3. Teilnehmer im Umkreis von **2 km** erscheinen auf der taktischen Karte.  
> 4. **Cockpit Drone** (`drone.exe`) verbindet sich lokal über `127.0.0.1`.

---

## Download kompilierter Binärdateien

Vorkompilierte Dateien befinden sich im Ordner [`bin/`](bin/):
- **`bin/setup_cockpit_drone_0.41.exe`:** Vollständiges Windows-Setup.
- **`bin/drone.exe`:** Cockpit Drone Programm.
- **`bin/simulador.exe`:** 3D-Simulator Programm.

---

## Kontakt und Lizenz

- **Autor:** Marcelo Maurin Martins (marcelomaurinmartins@gmail.com)
- **Webseite:** [Maurinsoft - Cockpit Drone](https://maurinsoft.com.br/wp/projetos-open-source/projeto-cockpit-drone/)
