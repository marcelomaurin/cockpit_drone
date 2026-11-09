[Português](README.md) · [English](README.en.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [日本語](README.ja.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

# Cockpit Drone - Système de Contrôle, Télémétrie et Simulation

Application complète développée en Object Pascal (Lazarus / Free Pascal) pour le pilotage à distance, la surveillance télémétrique et la simulation physique 3D de drones. Intègre la gestion de manettes analogiques, capteurs GPS, flux vidéo en direct (H.264 et caméra synthétique), cartographie tactique (OpenStreetMap) et prise en charge de multiples protocoles de vol.

---

<p align="center">
  <img src="docs/img/cockpit-principal.png" alt="Fenêtre principale du Cockpit Drone 0.46" width="49%">
  <img src="docs/img/simulador-mapa.png" alt="Simulateur Cockpit Drone 0.46 avec OpenStreetMap" width="49%">
</p>
<p align="center"><em>Cockpit (à gauche) et Simulateur (à droite), version 0.46 — captures d'écran réelles des exécutables du dépôt.</em> · <a href="docs/TELAS_0.46.md">Guide illustré des écrans, en portugais</a></p>

## Sommaire

1. [Vue d'ensemble](#vue-densemble)
2. [Structure du Projet](#structure-du-projet)
3. [Protocoles Pris en Charge](#protocoles-pris-en-charge)
4. [Simulateur 3D Officiel et Multijoueur](#simulateur-3d-officiel-et-multijoueur)
5. [Commandes : Manette vs Clavier](#commandes--manette-vs-clavier)
6. [Installation et Prérequis](#installation-et-prérequis)
7. [Planification de Vol Autonome](#planification-de-vol-autonome)
8. [Téléchargement des Binaires Compilés](#téléchargement-des-binaires-compilés)
9. [Contact et Licence](#contact-et-licence)

---

## Vue d'ensemble

Le système **Cockpit Drone** repose sur un thread de communication dédié découplé de l'interface graphique. Cela garantit que les cycles de commande de vol (toutes les 50 ms) ne sont jamais bloqués par l'interface utilisateur.

Fonctionnalités clés :
- **Sécurité en Vol :** Thread indépendant avec coupure d'urgence sur la barre d'espace et maintien automatique en vol stationnaire.
- **Interface Tactique Multi-fenêtres :** Instruments de bord, statut LED, affichage tête haute (HUD), suivi cartographique et vidéo en temps réel.
- **Écosystème Intégré :** Comprend le **Simulateur 3D** (`simulador/simulador.exe`) à dynamique 6DOF et le serveur multijoueur PHP/WebSocket (`PHP/`).

---

## Structure du Projet

- **`src/main.pas` :** Tableau de bord principal avec instruments visuels et voyants LED.
- **`src/config.pas` :** Configuration des protocoles, étalonnage de la manette et sélecteur de langue.
- **`src/joystick.pas` :** Gestion des manettes et sticks analogiques (DirectInput / SDL).
- **`src/gps.pas` :** Décodage NMEA série et qualité du signal GPS.
- **`src/camera.pas` :** Décodage vidéo H.264 FFmpeg et caméra synthétique partagée.
- **`src/map.pas` :** Cartographie OpenStreetMap avec trajectoire, waypoints et zone de sécurité (geofence).
- **`simulador/` :** Simulateur de vol 3D autonome avec moteur physique aérodynamique.
- **`PHP/` :** Serveur de monde partagé synchronisant les appareils dans un rayon de 2 km.

---

## Simulateur 3D Officiel et Multijoueur

> **ACCÈS MULTIJOUEUR :**  
> La connexion au monde partagé s'effectue via le **Simulateur** (`simulador.exe`) :  
> 1. Ouvrez `simulador.exe`.  
> 2. Dans le panneau **Monde partagé**, saisissez l'adresse du serveur (officiel : `https://maurinsoft.com.br/cockpit/`) et votre pseudo, puis cliquez sur **Entrer**.  
> 3. Les appareils dans un rayon de **2 km** apparaissent sur la carte et la vue 3D.  
> 4. **Cockpit Drone** (`drone.exe`) se connecte localement sur `127.0.0.1`.

---

## Téléchargement des Binaires

Retrouvez les exécutables dans le dossier [`bin/`](bin/) :
- **`bin/setup_cockpit_drone_0.41.exe` :** Installateur complet pour Windows.
- **`bin/drone.exe` :** Exécutable Cockpit Drone.
- **`bin/simulador.exe` :** Exécutable Simulateur 3D.

---

## Contact et Licence

- **Auteur :** Marcelo Maurin Martins (marcelomaurinmartins@gmail.com)
- **Site Web :** [Maurinsoft - Cockpit Drone](https://maurinsoft.com.br/wp/projetos-open-source/projeto-cockpit-drone/)
