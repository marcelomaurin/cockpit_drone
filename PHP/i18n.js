/**
 * Cockpit Drone - Internacionalização (i18n)
 * 10 Idiomas: pt-BR (Padrão), en, es, fr, de, ru, zh-CN, ja, ar, hi
 */
(function() {
  'use strict';

  var translations = {
    'pt-BR': {
      'lang_name': 'Português (Brasil)',
      'nav_home': 'Início / Servidor',
      'nav_download': '📥 Baixar Simulação (bin/)',
      'nav_tutorial': 'Tutorial de Uso',
      'nav_connect': 'Conectar',
      'nav_install': 'Instalar o serviço',
      'nav_help': 'Ajuda',
      'nav_github': 'GitHub do projeto',
      'hero_eyebrow': 'Servidor multiplayer • simulação compartilhada',
      'hero_title': 'Um mesmo espaço de voo.<br>Vários participantes.',
      'hero_lead': 'Este servidor conecta sessões do Cockpit Drone para compartilhar posições e eventos de simulação. Participantes a até <strong>2 km</strong> aparecem no mapa e na lista da câmera.',
      'btn_download_gh': '📥 Baixar Simulação no GitHub',
      'btn_tutorial': '📖 Tutorial de Uso',
      'btn_how_download': 'Como Baixar',
      'btn_how_connect': 'Como conectar o cockpit',
      'btn_setup_server': 'Configurar o servidor',
      'btn_status_api': 'Status da API',
      'sec_download_eyebrow': 'Download & Simulação',
      'sec_download_title': 'Baixe o Cockpit Drone e o Simulador',
      'sec_download_lead': 'Para começar a simular e pilotar, acesse a pasta oficial de binários compilados ou baixe o instalador para Windows diretamente do GitHub.',
      'card_bin_title': '📁 Pasta bin/ no GitHub',
      'card_bin_desc': 'Contém os executáveis compilados do <strong>Cockpit Drone (drone.exe)</strong>, do <strong>Simulador 3D (simulador.exe)</strong> e o instalador oficial:',
      'card_ctrl_title': '🕹️ Experiência de Controle: Joystick vs Teclado',
      'card_ctrl_p1': '<strong>O simulador é melhor rodado em um joystick analógico</strong> (como controles USB de videogame ou manches de voo), pois proporciona controle contínuo e suave dos 4 eixos de voo (arfagem, rolagem, guinada e aceleração).',
      'card_ctrl_p2': '<em>No entanto, o simulador e o cockpit também podem ser pilotados perfeitamente pelo teclado</em>, contando com corte de emergência na barra de espaço e centralização automática.',
      'btn_see_tutorial': 'Ver Tutorial Completo e Mapa de Teclas',
      'tut_hero_eyebrow': 'Guia Oficial • Simulação e Voo',
      'tut_hero_title': 'Tutorial do Simulador de Drone e do Cockpit',
      'tut_hero_lead': 'Aprenda a baixar, configurar e pilotar drones com o Cockpit Drone e seu simulador físico 3D integrado. Conecte-se localmente ou participe do mundo compartilhado online.',
      'tut_btn_download_bin': '📥 Baixar Simulação na pasta bin/ do GitHub',
      'tut_btn_controls': 'Controles (Joystick & Teclado)',
      'tut_btn_start_flight': 'Como Iniciar o Voo',
      'tut_btn_back_server': 'Voltar ao Servidor',
      'tut_sec1_title': 'Onde Baixar a Simulação e o Cockpit',
      'tut_sec2_title': 'Joystick vs. Teclado: Qual Usar?',
      'tut_sec3_title': 'Mapa Completo de Teclas',
      'tut_sec4_title': 'Passo a Passo: Como Rodar a Simulação',
      'tut_sec5_title': 'Mundo Compartilhado (Multiplayer)',
      'footer_text': 'Cockpit Drone • Projeto de código aberto para telemetria, simulação e pilotagem de drones.'
    },
    'en': {
      'lang_name': 'English',
      'nav_home': 'Home / Server',
      'nav_download': '📥 Download Simulation (bin/)',
      'nav_tutorial': 'Usage Tutorial',
      'nav_connect': 'Connect',
      'nav_install': 'Install Service',
      'nav_help': 'Help',
      'nav_github': 'Project GitHub',
      'hero_eyebrow': 'Multiplayer server • shared simulation',
      'hero_title': 'One shared airspace.<br>Multiple participants.',
      'hero_lead': 'This server connects Cockpit Drone sessions to share positions and simulation events. Participants within up to <strong>2 km</strong> appear on the tactical map and camera list.',
      'btn_download_gh': '📥 Download Simulation on GitHub',
      'btn_tutorial': '📖 Usage Tutorial',
      'btn_how_download': 'How to Download',
      'btn_how_connect': 'How to connect the cockpit',
      'btn_setup_server': 'Configure server',
      'btn_status_api': 'API Status',
      'sec_download_eyebrow': 'Download & Simulation',
      'sec_download_title': 'Download Cockpit Drone and Simulator',
      'sec_download_lead': 'To start simulating and flying, access the official compiled binaries folder or download the Windows installer directly from GitHub.',
      'card_bin_title': '📁 bin/ folder on GitHub',
      'card_bin_desc': 'Contains compiled executables for <strong>Cockpit Drone (drone.exe)</strong>, <strong>3D Simulator (simulador.exe)</strong> and the official installer:',
      'card_ctrl_title': '🕹️ Control Experience: Joystick vs Keyboard',
      'card_ctrl_p1': '<strong>The simulator runs best on an analog joystick</strong> (such as USB gaming gamepads or flight sticks), offering continuous and smooth control over all 4 flight axes (pitch, roll, yaw, and throttle).',
      'card_ctrl_p2': '<em>However, the simulator and cockpit can also be perfectly flown via keyboard</em>, featuring emergency cut on Spacebar and automatic auto-centering.',
      'btn_see_tutorial': 'View Full Tutorial and Key Map',
      'tut_hero_eyebrow': 'Official Guide • Simulation & Flight',
      'tut_hero_title': 'Cockpit Drone & Flight Simulator Tutorial',
      'tut_hero_lead': 'Learn how to download, configure, and fly drones with Cockpit Drone and its integrated 3D physics simulator. Connect locally or join the online shared airspace.',
      'tut_btn_download_bin': '📥 Download Simulation in GitHub bin/ folder',
      'tut_btn_controls': 'Controls (Joystick & Keyboard)',
      'tut_btn_start_flight': 'How to Start Flying',
      'tut_btn_back_server': 'Back to Server',
      'tut_sec1_title': 'Where to Download Simulation & Cockpit',
      'tut_sec2_title': 'Joystick vs. Keyboard: Which to Use?',
      'tut_sec3_title': 'Complete Keyboard Mapping',
      'tut_sec4_title': 'Step by Step: How to Run Simulation',
      'tut_sec5_title': 'Shared Airspace (Multiplayer)',
      'footer_text': 'Cockpit Drone • Open-source project for drone telemetry, simulation and flight control.'
    },
    'es': {
      'lang_name': 'Español',
      'nav_home': 'Inicio / Servidor',
      'nav_download': '📥 Descargar Simulación (bin/)',
      'nav_tutorial': 'Tutorial de Uso',
      'nav_connect': 'Conectar',
      'nav_install': 'Instalar servicio',
      'nav_help': 'Ayuda',
      'nav_github': 'GitHub del proyecto',
      'hero_eyebrow': 'Servidor multijugador • simulación compartida',
      'hero_title': 'Un mismo espacio aéreo.<br>Varios participantes.',
      'hero_lead': 'Este servidor conecta sesiones de Cockpit Drone para compartir posiciones y eventos. Participantes a hasta <strong>2 km</strong> aparecen en el mapa táctico y la cámara.',
      'btn_download_gh': '📥 Descargar Simulación en GitHub',
      'btn_tutorial': '📖 Tutorial de Uso',
      'btn_how_download': 'Cómo Descargar',
      'btn_how_connect': 'Cómo conectar la cabina',
      'btn_setup_server': 'Configurar servidor',
      'btn_status_api': 'Estado de API',
      'sec_download_eyebrow': 'Descarga y Simulación',
      'sec_download_title': 'Descargue Cockpit Drone y el Simulador',
      'sec_download_lead': 'Para comenzar a simular y pilotar, acceda a la carpeta oficial de binarios compilados o descargue el instalador para Windows desde GitHub.',
      'card_bin_title': '📁 Carpeta bin/ en GitHub',
      'card_bin_desc': 'Contiene los ejecutables compilados de <strong>Cockpit Drone (drone.exe)</strong>, el <strong>Simulador 3D (simulador.exe)</strong> y el instalador oficial:',
      'card_ctrl_title': '🕹️ Experiencia de Control: Joystick vs Teclado',
      'card_ctrl_p1': '<strong>El simulador funciona mejor con un joystick analógico</strong> (como mandos USB de juegos o palancas de vuelo), ofreciendo control continuo y suave en los 4 ejes de vuelo.',
      'card_ctrl_p2': '<em>Sin embargo, el simulador y la cabina también se pueden pilotar perfectamente con el teclado</em>, con corte de emergencia en la barra espaciadora y centrado automático.',
      'btn_see_tutorial': 'Ver Tutorial Completo y Mapa de Teclas',
      'tut_hero_eyebrow': 'Guía Oficial • Simulación y Vuelo',
      'tut_hero_title': 'Tutorial del Simulador de Drones y Cabina',
      'tut_hero_lead': 'Aprenda a descargar, configurar y pilotar drones con Cockpit Drone y su simulador de física 3D integrado.',
      'tut_btn_download_bin': '📥 Descargar Simulación en carpeta bin/ de GitHub',
      'tut_btn_controls': 'Controles (Joystick y Teclado)',
      'tut_btn_start_flight': 'Cómo Iniciar el Vuelo',
      'tut_btn_back_server': 'Volver al Servidor',
      'tut_sec1_title': 'Dónde Descargar la Simulación y Cabina',
      'tut_sec2_title': 'Joystick vs. Teclado: ¿Cuál Usar?',
      'tut_sec3_title': 'Mapa Completo de Teclas',
      'tut_sec4_title': 'Paso a Paso: Cómo Ejecutar la Simulación',
      'tut_sec5_title': 'Mundo Compartido (Multijugador)',
      'footer_text': 'Cockpit Drone • Proyecto de código abierto para telemetría, simulación y pilotaje de drones.'
    },
    'fr': {
      'lang_name': 'Français',
      'nav_home': 'Accueil / Serveur',
      'nav_download': '📥 Télécharger Simulation (bin/)',
      'nav_tutorial': 'Tutoriel d\'Utilisation',
      'nav_connect': 'Connecter',
      'nav_install': 'Installer le service',
      'nav_help': 'Aide',
      'nav_github': 'GitHub du projet',
      'hero_eyebrow': 'Serveur multijoueur • simulation partagée',
      'hero_title': 'Un même espace aérien.<br>Plusieurs participants.',
      'hero_lead': 'Ce serveur relie les sessions Cockpit Drone pour partager positions et événements. Les participants jusqu\'à <strong>2 km</strong> s\'affichent sur la carte.',
      'btn_download_gh': '📥 Télécharger Simulation sur GitHub',
      'btn_tutorial': '📖 Tutoriel d\'Utilisation',
      'btn_how_download': 'Comment Télécharger',
      'btn_how_connect': 'Comment connecter le cockpit',
      'btn_setup_server': 'Configurer le serveur',
      'btn_status_api': 'Statut API',
      'sec_download_eyebrow': 'Téléchargement & Simulation',
      'sec_download_title': 'Téléchargez Cockpit Drone et le Simulateur',
      'sec_download_lead': 'Pour commencer à simuler et piloter, accédez au dossier officiel des binaires ou téléchargez l\'installateur Windows depuis GitHub.',
      'card_bin_title': '📁 Dossier bin/ sur GitHub',
      'card_bin_desc': 'Contient les exécutables de <strong>Cockpit Drone (drone.exe)</strong>, du <strong>Simulateur 3D (simulador.exe)</strong> et l\'installateur officiel :',
      'card_ctrl_title': '🕹️ Expérience de Contrôle : Joystick vs Clavier',
      'card_ctrl_p1': '<strong>Le simulateur fonctionne mieux avec une manette analogique</strong> (joysticks de vol ou manettes USB), offrant un contrôle fluide et précis sur les 4 axes de vol.',
      'card_ctrl_p2': '<em>Cependant, le simulateur et le cockpit peuvent aussi être pilotés parfaitement au clavier</em>, avec arrêt d\'urgence sur la barre d\'espace.',
      'btn_see_tutorial': 'Voir le Tutoriel Complet et les Raccourcis',
      'tut_hero_eyebrow': 'Guide Officiel • Simulation et Vol',
      'tut_hero_title': 'Tutoriel Simulateur de Drone et Cockpit',
      'tut_hero_lead': 'Apprenez à télécharger, configurer et piloter avec Cockpit Drone et son simulateur 3D physique intégré.',
      'tut_btn_download_bin': '📥 Télécharger la Simulation (dossier bin/)',
      'tut_btn_controls': 'Commandes (Joystick & Clavier)',
      'tut_btn_start_flight': 'Comment Démarrer le Vol',
      'tut_btn_back_server': 'Retour au Serveur',
      'tut_sec1_title': 'Où Télécharger la Simulation et le Cockpit',
      'tut_sec2_title': 'Joystick vs Clavier : Lequel Choisir ?',
      'tut_sec3_title': 'Carte Complète des Touches',
      'tut_sec4_title': 'Étape par Étape : Lancer la Simulation',
      'tut_sec5_title': 'Espace Aérien Partagé (Multijoueur)',
      'footer_text': 'Cockpit Drone • Projet open source pour la télémétrie, la simulation et le pilotage de drones.'
    },
    'de': {
      'lang_name': 'Deutsch',
      'nav_home': 'Startseite / Server',
      'nav_download': '📥 Simulation Herunterladen (bin/)',
      'nav_tutorial': 'Bedienungsanleitung',
      'nav_connect': 'Verbinden',
      'nav_install': 'Dienst installieren',
      'nav_help': 'Hilfe',
      'nav_github': 'Projekt-GitHub',
      'hero_eyebrow': 'Multiplayer-Server • geteilte Simulation',
      'hero_title': 'Ein gemeinsamer Luftraum.<br>Mehrere Teilnehmer.',
      'hero_lead': 'Dieser Server verbindet Cockpit-Drone-Sitzungen zur Übertragung von Positionen und Ereignissen. Teilnehmer im Umkreis von bis zu <strong>2 km</strong> erscheinen auf der Karte.',
      'btn_download_gh': '📥 Simulation auf GitHub herunterladen',
      'btn_tutorial': '📖 Anleitung',
      'btn_how_download': 'Herunterladen',
      'btn_how_connect': 'Cockpit verbinden',
      'btn_setup_server': 'Server einrichten',
      'btn_status_api': 'API-Status',
      'sec_download_eyebrow': 'Download & Simulation',
      'sec_download_title': 'Cockpit Drone und Simulator herunterladen',
      'sec_download_lead': 'Laden Sie die kompilierten Binärdateien oder das Installationsprogramm für Windows direkt von GitHub herunter.',
      'card_bin_title': '📁 Ordner bin/ auf GitHub',
      'card_bin_desc': 'Enthält die ausführbaren Dateien von <strong>Cockpit Drone (drone.exe)</strong>, dem <strong>3D-Simulator (simulador.exe)</strong> und das Setup:',
      'card_ctrl_title': '🕹️ Steuerung: Joystick vs. Tastatur',
      'card_ctrl_p1': '<strong>Der Simulator läuft am besten mit einem analogen Joystick</strong> (z. B. USB-Gamepads oder Flug-Joysticks) für stufenlose Kontrolle über alle 4 Achsen.',
      'card_ctrl_p2': '<em>Der Simulator und das Cockpit können jedoch auch problemlos mit der Tastatur geflogen werden</em>, inklusive Notabschaltung per Leertaste.',
      'btn_see_tutorial': 'Vollständige Anleitung & Tastenbelegung ansehen',
      'tut_hero_eyebrow': 'Offizieller Leitfaden • Simulation & Flug',
      'tut_hero_title': 'Cockpit Drone & Flugsimulator Anleitung',
      'tut_hero_lead': 'Erfahren Sie, wie Sie Drohnen mit Cockpit Drone und dem integrierten 3D-Physiksimulator fliegen und konfigurieren.',
      'tut_btn_download_bin': '📥 Simulation im bin/-Ordner herunterladen',
      'tut_btn_controls': 'Steuerung (Joystick & Tastatur)',
      'tut_btn_start_flight': 'Flug starten',
      'tut_btn_back_server': 'Zurück zum Server',
      'tut_sec1_title': 'Download von Simulation & Cockpit',
      'tut_sec2_title': 'Joystick oder Tastatur: Was ist besser?',
      'tut_sec3_title': 'Komplette Tastenbelegung',
      'tut_sec4_title': 'Schritt-für-Schritt-Anleitung',
      'tut_sec5_title': 'Gemeinsamer Luftraum (Multiplayer)',
      'footer_text': 'Cockpit Drone • Open-Source-Projekt für Telemetrie, Simulation und Drohnensteuerung.'
    },
    'ru': {
      'lang_name': 'Русский',
      'nav_home': 'Главная / Сервер',
      'nav_download': '📥 Скачать симуляцию (bin/)',
      'nav_tutorial': 'Руководство пользователя',
      'nav_connect': 'Подключение',
      'nav_install': 'Установка службы',
      'nav_help': 'Помощь',
      'nav_github': 'GitHub проекта',
      'hero_eyebrow': 'Многопользовательский сервер • общая симуляция',
      'hero_title': 'Единое воздушное пространство.<br>Несколько участников.',
      'hero_lead': 'Этот сервер объединяет сеансы Cockpit Drone для обмена координатами и событиями. Участники в радиусе до <strong>2 км</strong> отображаются на карте.',
      'btn_download_gh': '📥 Скачать симуляцию с GitHub',
      'btn_tutorial': '📖 Руководство',
      'btn_how_download': 'Как скачать',
      'btn_how_connect': 'Как подключить кабину',
      'btn_setup_server': 'Настройка сервера',
      'btn_status_api': 'Статус API',
      'sec_download_eyebrow': 'Загрузка и симуляция',
      'sec_download_title': 'Скачать Cockpit Drone и симулятор',
      'sec_download_lead': 'Для начала симуляции и полетов скачайте скомпилированные файлы или установщик Windows с GitHub.',
      'card_bin_title': '📁 Папка bin/ на GitHub',
      'card_bin_desc': 'Содержит исполняемые файлы <strong>Cockpit Drone (drone.exe)</strong>, <strong>3D-симулятора (simulador.exe)</strong> и установщик:',
      'card_ctrl_title': '🕹️ Управление: Джойстик или Клавиатура',
      'card_ctrl_p1': '<strong>Симулятор лучше всего запускать с аналоговым джойстиком</strong> (геймпады USB или летные джойстики), обеспечивающим плавный контроль 4 осей полета.',
      'card_ctrl_p2': '<em>Тем не менее, симулятором и кабиной можно полноценно управлять и с клавиатуры</em>, с аварийной остановкой по клавише Пробел.',
      'btn_see_tutorial': 'Открыть полное руководство и раскладку клавиш',
      'tut_hero_eyebrow': 'Официальное руководство • Полеты и симуляция',
      'tut_hero_title': 'Руководство по Cockpit Drone и симулятору',
      'tut_hero_lead': 'Узнайте, как скачать, настроить и управлять дронами с помощью Cockpit Drone и встроенного 3D-симулятора.',
      'tut_btn_download_bin': '📥 Скачать симуляцию (папка bin/)',
      'tut_btn_controls': 'Управление (Джойстик и Клавиатура)',
      'tut_btn_start_flight': 'Как начать полет',
      'tut_btn_back_server': 'Назад к серверу',
      'tut_sec1_title': 'Где скачать симуляцию и кабину',
      'tut_sec2_title': 'Джойстик против Клавиатуры: Что выбрать?',
      'tut_sec3_title': 'Полная раскладка клавиш',
      'tut_sec4_title': 'Пошаговая инструкция запуска',
      'tut_sec5_title': 'Общий мир (Мультиплеер)',
      'footer_text': 'Cockpit Drone • Проект с открытым исходным кодом для телеметрии, симуляции и управления дронами.'
    },
    'zh-CN': {
      'lang_name': '中文 (简体)',
      'nav_home': '首页 / 服务器',
      'nav_download': '📥 下载模拟器 (bin/)',
      'nav_tutorial': '使用教程',
      'nav_connect': '连接',
      'nav_install': '安装服务',
      'nav_help': '帮助',
      'nav_github': '项目 GitHub',
      'hero_eyebrow': '多人在线服务器 • 共享模拟空域',
      'hero_title': '同一个空域。<br>多位飞行员共同探索。',
      'hero_lead': '本服务器连接 Cockpit Drone 会话以共享飞行位置和事件。方圆 <strong>2 公里</strong>内的飞行员会实时显示在战术地图与画面上。',
      'btn_download_gh': '📥 从 GitHub 下载模拟器',
      'btn_tutorial': '📖 使用教程',
      'btn_how_download': '如何下载',
      'btn_how_connect': '如何连接座舱',
      'btn_setup_server': '配置服务器',
      'btn_status_api': 'API 状态',
      'sec_download_eyebrow': '下载与模拟',
      'sec_download_title': '下载 Cockpit Drone 与飞行模拟器',
      'sec_download_lead': '如需开始模拟与飞行，请访问 GitHub 上的官方已编译程序目录或直接下载 Windows 安装包。',
      'card_bin_title': '📁 GitHub 上的 bin/ 目录',
      'card_bin_desc': '包含编译好的 <strong>Cockpit Drone (drone.exe)</strong>、<strong>3D 模拟器 (simulador.exe)</strong> 以及官方安装包：',
      'card_ctrl_title': '🕹️ 操控体验：摇杆 vs 键盘',
      'card_ctrl_p1': '<strong>模拟器在模拟摇杆（手柄）上体验最佳</strong>（如 USB 游戏手柄或专业飞行摇杆），可在 4 个飞行轴向（俯仰、横滚、偏航与油门）上提供平滑精准的连续输入。',
      'card_ctrl_p2': '<em>然而，模拟器和座舱也完全支持键盘操作</em>，内置空格键紧急停机和 R 键自动回中平衡功能。',
      'btn_see_tutorial': '查看完整教程与键盘按键映射',
      'tut_hero_eyebrow': '官方指南 • 模拟与飞行',
      'tut_hero_title': 'Cockpit Drone 与飞行模拟器使用教程',
      'tut_hero_lead': '学习如何下载、配置并使用 Cockpit Drone 及其内置 3D 物理模拟器来驾驶无人机。',
      'tut_btn_download_bin': '📥 从 GitHub bin/ 目录下载模拟器',
      'tut_btn_controls': '控制方式（摇杆与键盘）',
      'tut_btn_start_flight': '如何起飞',
      'tut_btn_back_server': '返回服务器首页',
      'tut_sec1_title': '在哪里下载模拟器与座舱',
      'tut_sec2_title': '摇杆对比键盘：该选哪种？',
      'tut_sec3_title': '完整按键操作映射表',
      'tut_sec4_title': '分步指南：如何运行模拟',
      'tut_sec5_title': '共享空域（多人联机）',
      'footer_text': 'Cockpit Drone • 用于无人机遥测、模拟与飞行的开源项目。'
    },
    'ja': {
      'lang_name': '日本語',
      'nav_home': 'ホーム / サーバー',
      'nav_download': '📥 シミュレーターをダウンロード (bin/)',
      'nav_tutorial': '利用チュートリアル',
      'nav_connect': '接続方法',
      'nav_install': 'サーバー構築',
      'nav_help': 'ヘルプ',
      'nav_github': 'GitHub リポジトリ',
      'hero_eyebrow': 'マルチプレイヤーサーバー • 共有フライトシミュレーション',
      'hero_title': 'ひとつの空域。<br>複数のパイロットで共有。',
      'hero_lead': 'Cockpit Drone セッションを接続し、位置情報やイベントをリアルタイムに共有します。半径 <strong>2 km</strong> 以内のドローンがマップ上に表示されます。',
      'btn_download_gh': '📥 GitHub からシミュレーターを入手',
      'btn_tutorial': '📖 利用チュートリアル',
      'btn_how_download': 'ダウンロード方法',
      'btn_how_connect': 'コックピット接続',
      'btn_setup_server': 'サーバー設定',
      'btn_status_api': 'API ステータス',
      'sec_download_eyebrow': 'ダウンロード & シミュレーション',
      'sec_download_title': 'Cockpit Drone とシミュレーターのダウンロード',
      'sec_download_lead': 'シミュレーションを開始するには、GitHub の公式コンパイル済みフォルダにアクセスするか、Windows 向けインストーラーをダウンロードしてください。',
      'card_bin_title': '📁 GitHub の bin/ フォルダ',
      'card_bin_desc': '<strong>Cockpit Drone (drone.exe)</strong>、<strong>3D シミュレーター (simulador.exe)</strong>、公式インストーラーが含まれています：',
      'card_ctrl_title': '🕹️ 操作感：ジョイスティック vs キーボード',
      'card_ctrl_p1': '<strong>シミュレーターはアナログジョイスティック（フライトスティックやゲームパッド）での操作が最も適しています</strong>。4軸（ピッチ、ロール、ヨー、スロットル）を滑らかに制御できます。',
      'card_ctrl_p2': '<em>ただし、キーボードでも問題なく操縦可能です</em>。スペースキーによる緊急停止や、Rキーでの自動水平復帰機能を搭載しています。',
      'btn_see_tutorial': 'チュートリアルとキーマップを確認',
      'tut_hero_eyebrow': '公式ガイド • シミュレーションとフライト',
      'tut_hero_title': 'Cockpit Drone & フライトシミュレーター チュートリアル',
      'tut_hero_lead': 'Cockpit Drone と内蔵の 3D 物理シミュレーターを使ってドローンを操縦する方法を学びます。',
      'tut_btn_download_bin': '📥 bin/ フォルダからダウンロード',
      'tut_btn_controls': '操作方法（ジョイスティック / キーボード）',
      'tut_btn_start_flight': '飛行開始ステップ',
      'tut_btn_back_server': 'サーバーページに戻る',
      'tut_sec1_title': 'シミュレーターとコックピットの入手先',
      'tut_sec2_title': 'ジョイスティックとキーボード：どちらを使うべき？',
      'tut_sec3_title': '完全なキー割り当て一覧',
      'tut_sec4_title': 'ステップバイステップ：起動とフライト',
      'tut_sec5_title': '共有ワールド（マルチプレイヤー）',
      'footer_text': 'Cockpit Drone • テレメトリ、シミュレーション、ドローン制御のためのオープンソースプロジェクト。'
    },
    'ar': {
      'lang_name': 'العربية',
      'nav_home': 'الرئيسية / الخادم',
      'nav_download': '📥 تحميل المحاكاة (bin/)',
      'nav_tutorial': 'دليل الاستخدام',
      'nav_connect': 'الاتصال',
      'nav_install': 'تثبيت الخدمة',
      'nav_help': 'المساعدة',
      'nav_github': 'مشروع GitHub',
      'hero_eyebrow': 'خادم متعدد اللاعبين • محاكاة مشتركة',
      'hero_title': 'مجال جوي مشترك واحد.<br>طيارون متعددون.',
      'hero_lead': 'يربط هذا الخادم جلسات Cockpit Drone لمشاركة المواقع وأحداث المحاكاة. يظهر المشاركون حتى مسافة <strong>2 كم</strong> على الخريطة.',
      'btn_download_gh': '📥 تحميل المحاكاة من GitHub',
      'btn_tutorial': '📖 دليل الاستخدام',
      'btn_how_download': 'كيفية التحميل',
      'btn_how_connect': 'كيفية ربط قمرة القيادة',
      'btn_setup_server': 'تهيئة الخادم',
      'btn_status_api': 'حالة API',
      'sec_download_eyebrow': 'التحميل والمحاكاة',
      'sec_download_title': 'تحميل Cockpit Drone والمحاكي',
      'sec_download_lead': 'لبدء المحاكاة والطيران، تفضل بزيارة المجلد الرسمي للبرامج المترجمة أو قم بتنزيل برنامج التثبيت لنظام Windows مباشرة من GitHub.',
      'card_bin_title': '📁 مجلد bin/ على GitHub',
      'card_bin_desc': 'يحتوي على البرامج التنفيذية لـ <strong>Cockpit Drone (drone.exe)</strong> و <strong>محاكي الأبعاد الثلاثية (simulador.exe)</strong> وبرنامج التثبيت:',
      'card_ctrl_title': '🕹️ تجربة التحكم: عصا التحكم مقابل لوحة المفاتيح',
      'card_ctrl_p1': '<strong>المحاكي يعمل بأفضل شكل باستخدام عصا تحكم تناظرية (Joystick)</strong> (مثل أذرع الألعاب USB)، مما يوفر تحكماً سلساً ودقيقاً في محاور الطيران الأربعة.',
      'card_ctrl_p2': '<em>ومع ذلك، يمكن التحكم في المحاكي وقمرة القيادة بشكل ممتاز عبر لوحة المفاتيح أيضاً</em>، مع ميزة الإيقاف الفوري للطوارئ بمفتاح المسافة.',
      'btn_see_tutorial': 'عرض الدليل الكامل وخريطة المفاتيح',
      'tut_hero_eyebrow': 'الدليل الرسمي • المحاكاة والطيران',
      'tut_hero_title': 'دليل محاكي الدرون وقمرة القيادة',
      'tut_hero_lead': 'تعلم كيفية تنزيل وتهيئة وقيادة الطائرات بدون طيار باستخدام Cockpit Drone والمحاكي الفيزيائي ثلاثي الأبعاد المدمج.',
      'tut_btn_download_bin': '📥 تحميل المحاكاة من مجلد bin/',
      'tut_btn_controls': 'عناصر التحكم (عصا التحكم ولوحة المفاتيح)',
      'tut_btn_start_flight': 'كيفية بدء الطيران',
      'tut_btn_back_server': 'العودة إلى الخادم',
      'tut_sec1_title': 'من أين يمكن تنزيل المحاكاة وقمرة القيادة',
      'tut_sec2_title': 'عصا التحكم مقابل لوحة المفاتيح: أيهما تختار؟',
      'tut_sec3_title': 'خريطة المفاتيح الكاملة',
      'tut_sec4_title': 'خطوة بخطوة: كيفية تشغيل المحاكاة',
      'tut_sec5_title': 'العالم المشترك (متعدد اللاعبين)',
      'footer_text': 'Cockpit Drone • مشروع مفتوح المصدر للقياس عن بعد ومحاكاة وقيادة الدرون.'
    },
    'hi': {
      'lang_name': 'हिन्दी (Hindi)',
      'nav_home': 'होम / सर्वर',
      'nav_download': '📥 सिमुलेशन डाउनलोड करें (bin/)',
      'nav_tutorial': 'उपयोग ट्यूटोरियल',
      'nav_connect': 'कनेक्ट करें',
      'nav_install': 'सर्विस स्थापित करें',
      'nav_help': 'सहायता',
      'nav_github': 'प्रोजेक्ट GitHub',
      'hero_eyebrow': 'मल्टीप्लेयर सर्वर • साझा सिमुलेशन',
      'hero_title': 'एक ही हवाई क्षेत्र।<br>कई पायलट एक साथ।',
      'hero_lead': 'यह सर्वर स्थिति और सिमुलेशन इवेंट्स साझा करने के लिए Cockpit Drone सत्रों को जोड़ता है। <strong>2 किमी</strong> तक के प्रतिभागी मानचित्र पर दिखाई देते हैं।',
      'btn_download_gh': '📥 GitHub से सिमुलेशन डाउनलोड करें',
      'btn_tutorial': '📖 उपयोग ट्यूटोरियल',
      'btn_how_download': 'कैसे डाउनलोड करें',
      'btn_how_connect': 'कॉकपिट कैसे कनेक्ट करें',
      'btn_setup_server': 'सर्वर कॉन्फ़िगर करें',
      'btn_status_api': 'API स्थिति',
      'sec_download_eyebrow': 'डाउनलोड और सिमुलेशन',
      'sec_download_title': 'Cockpit Drone और सिमुलेटर डाउनलोड करें',
      'sec_download_lead': 'सिमुलेशन और उड़ान शुरू करने के लिए, GitHub पर आधिकारिक बाइनरी फ़ोल्डर पर जाएँ या Windows इंस्टॉलर डाउनलोड करें।',
      'card_bin_title': '📁 GitHub पर bin/ फ़ोल्डर',
      'card_bin_desc': 'इसमें <strong>Cockpit Drone (drone.exe)</strong>, <strong>3D सिमुलेटर (simulador.exe)</strong> और इंस्टॉलर शामिल हैं:',
      'card_ctrl_title': '🕹️ नियंत्रण अनुभव: जॉयस्टिक बनाम कीबोर्ड',
      'card_ctrl_p1': '<strong>सिमुलेटर को एनालॉग जॉयस्टिक पर सबसे अच्छा चलाया जाता है</strong> (जैसे USB गेमपैड या फ़्लाइट स्टिक), जो 4 उड़ान अक्षों पर सुचारू और सटीक नियंत्रण प्रदान करता है।',
      'card_ctrl_p2': '<em>हालाँकि, सिमुलेटर और कॉकपिट को कीबोर्ड से भी पूरी तरह उड़ाया जा सकता है</em>, जिसमें स्पेसबार पर आपातकालीन कट-ऑफ शामिल है।',
      'btn_see_tutorial': 'पूरा ट्यूटोरियल और की-मैप देखें',
      'tut_hero_eyebrow': 'आधिकारिक गाइड • सिमुलेशन और उड़ान',
      'tut_hero_title': 'Cockpit Drone और उड़ान सिमुलेटर ट्यूटोरियल',
      'tut_hero_lead': 'Cockpit Drone और इसके 3D भौतिकी सिमुलेटर के साथ ड्रोन उड़ाना और कॉन्फ़िगर करना सीखें।',
      'tut_btn_download_bin': '📥 GitHub bin/ फ़ोल्डर से डाउनलोड करें',
      'tut_btn_controls': 'नियंत्रण (जॉयस्टिक और कीबोर्ड)',
      'tut_btn_start_flight': 'उड़ान कैसे शुरू करें',
      'tut_btn_back_server': 'सर्वर पर वापस जाएँ',
      'tut_sec1_title': 'सिमुलेशन और कॉकपिट कहाँ से डाउनलोड करें',
      'tut_sec2_title': 'जॉयस्टिक बनाम कीबोर्ड: किसका उपयोग करें?',
      'tut_sec3_title': 'पूरी कीबोर्ड मैपिंग तालिका',
      'tut_sec4_title': 'कदम-दर-कदम: सिमुलेशन कैसे चलाएँ',
      'tut_sec5_title': 'साझा दुनिया (मल्टीप्लेयर)',
      'footer_text': 'Cockpit Drone • ड्रोन टेलीमेट्री, सिमुलेशन और नियंत्रण के लिए ओपन-सोर्स प्रोजेक्ट।'
    }
  };

  function getSavedLanguage() {
    // 1. URL parameter (?lang=...)
    var params = new URLSearchParams(window.location.search);
    var langParam = params.get('lang');
    if (langParam && translations[langParam]) {
      return langParam;
    }
    // 2. localStorage
    var stored = localStorage.getItem('drone_lang');
    if (stored && translations[stored]) {
      return stored;
    }
    // 3. Cookie
    var match = document.cookie.match(new RegExp('(^| )drone_lang=([^;]+)'));
    if (match && translations[match[2]]) {
      return match[2];
    }
    // 4. Default: Portuguese (pt-BR)
    return 'pt-BR';
  }

  function applyLanguage(lang) {
    if (!translations[lang]) lang = 'pt-BR';
    
    // Save preference
    localStorage.setItem('drone_lang', lang);
    document.cookie = 'drone_lang=' + lang + ';path=/;max-age=31536000';

    // HTML lang and direction (RTL for Arabic)
    document.documentElement.lang = lang;
    if (lang === 'ar') {
      document.documentElement.dir = 'rtl';
    } else {
      document.documentElement.dir = 'ltr';
    }

    // Sync select dropdown if present
    var select = document.getElementById('lang-select');
    if (select && select.value !== lang) {
      select.value = lang;
    }

    // Translate elements with data-i18n
    var dict = translations[lang] || translations['pt-BR'];
    var elements = document.querySelectorAll('[data-i18n]');
    for (var i = 0; i < elements.length; i++) {
      var el = elements[i];
      var key = el.getAttribute('data-i18n');
      if (dict[key]) {
        if (el.tagName === 'INPUT' && (el.type === 'button' || el.type === 'submit')) {
          el.value = dict[key];
        } else {
          el.innerHTML = dict[key];
        }
      }
    }
  }

  window.changeLanguage = function(lang) {
    applyLanguage(lang);
  };

  // Initialize on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
      applyLanguage(getSavedLanguage());
    });
  } else {
    applyLanguage(getSavedLanguage());
  }
})();
