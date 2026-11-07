; Instalador do Cockpit Drone — Inno Setup 6
; Compile no Windows, a partir da pasta install:  ISCC.exe cockpitdrone.iss
; Saída: bin\setup_cockpit_drone_0.41.exe
;
; Antes de compilar:
;   1. Compile o projeto src\drone.lpi no Lazarus — gera src\drone.exe.
;   2. Compile o simulador em simulador\src\simulador.lpi — gera simulador\simulador.exe.
;   3. (Opcional) coloque o ffmpeg.exe em install\redist\ para a câmera do
;      CX-10W, FQ777-954 e AR.Drone funcionar sem instalar nada a mais.

#define MyAppName "Cockpit Drone"
#define MyAppVersion "0.41"
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
OutputDir={#Raiz}\bin
OutputBaseFilename=setup_cockpit_drone_{#MyAppVersion}
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
Source: "{#Raiz}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs
Source: "{#Raiz}\src\imgs\*"; DestDir: "{app}\imgs"; Flags: ignoreversion recursesubdirs
; Decodificador de vídeo (opcional): install\redist\ffmpeg.exe
Source: "redist\ffmpeg.exe"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "redist\ffmpeg-LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
; Firmware do drone ESP32 e documentação do protocolo CDP
Source: "{#Raiz}\firmware\*"; DestDir: "{app}\firmware"; Flags: ignoreversion recursesubdirs
; Simulador de voo do Cockpit Drone
Source: "{#Raiz}\simulador\simulador.exe"; DestDir: "{app}\simulador"; Flags: ignoreversion
Source: "{#Raiz}\simulador\config\*"; DestDir: "{app}\simulador\config"; Flags: ignoreversion recursesubdirs
Source: "{#Raiz}\simulador\docs\*"; DestDir: "{app}\simulador\docs"; Flags: ignoreversion recursesubdirs skipifsourcedoesntexist
Source: "{#Raiz}\README.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autoprograms}\Simulador Cockpit Drone"; Filename: "{app}\simulador\simulador.exe"; WorkingDir: "{app}\simulador"
Name: "{autoprograms}\Firmware do drone ESP32"; Filename: "{app}\firmware"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{autodesktop}\Simulador Cockpit Drone"; Filename: "{app}\simulador\simulador.exe"; WorkingDir: "{app}\simulador"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
