; Instalador do Cockpit Drone — Inno Setup 6
; Compile no Windows, a partir da pasta install:  ISCC.exe cockpitdrone.iss
; Saída: install\win32\win_setup_043.exe
;
; Antes de compilar:
;   1. Compile o projeto src\drone.lpi no Lazarus — gera src\drone.exe.
;   2. (Opcional) coloque o ffmpeg.exe em install\redist\ para a câmera do
;      CX-10W, FQ777-954 e AR.Drone funcionar sem instalar nada a mais.

#define MyAppName "Cockpit Drone"
#define MyAppVersion "0.43"
#define MyAppPublisher "Maurinsoft.com.br"
#define MyAppURL "https://maurinsoft.com.br/wp/projetos-open-source/projeto-cockpit-drone/"
#define MyAppExeName "drone.exe"
#define Raiz ".."

[Setup]
; Mesmo AppId das versões anteriores: atualiza a instalação existente.
AppId={{7B571BE6-D01D-45BB-8C50-0EE5765DDFE7}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
VersionInfoVersion={#MyAppVersion}.0.0
DefaultDirName={autopf}\cockpit drone
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=win32
OutputBaseFilename=win_setup_043
SetupIconFile={#Raiz}\src\drone.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Dirs]
; O drone.cfg, os vídeos e os quadros são gravados na pasta do programa.
Name: "{app}"; Permissions: users-modify

[Files]
Source: "{#Raiz}\src\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#Raiz}\src\objetos.json"; DestDir: "{app}"; Flags: onlyifdoesntexist
Source: "{#Raiz}\src\imgs\*"; DestDir: "{app}\imgs"; Flags: ignoreversion recursesubdirs
; Decodificador de vídeo (opcional): install\redist\ffmpeg.exe
Source: "redist\ffmpeg.exe"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "redist\ffmpeg-LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
; Firmware do drone ESP32 e documentação do protocolo CDP
Source: "{#Raiz}\firmware\*"; DestDir: "{app}\firmware"; Flags: ignoreversion recursesubdirs
Source: "{#Raiz}\README.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autoprograms}\Firmware do drone ESP32"; Filename: "{app}\firmware"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
