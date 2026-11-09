; Instalador do Cockpit Drone — NSIS 3 (alternativa ao cockpitdrone.iss)
; Compile a partir da pasta install:
;   makensis cockpitdrone.nsi
;   makensis -DEXE=caminho\drone.exe cockpitdrone.nsi   (outro executável)
; Saída: bin\setup_cockpit_drone_0.46.exe

Unicode true
SetCompressor /SOLID lzma

!define APP_NAME      "Cockpit Drone"
!define APP_VERSION   "0.46"
!define APP_PUBLISHER "Maurinsoft.com.br"
!define APP_URL       "https://maurinsoft.com.br/wp/projetos-open-source/projeto-cockpit-drone/"
!define APP_EXE       "drone.exe"
!define RAIZ          ".."
!define UNINST_KEY    "Software\Microsoft\Windows\CurrentVersion\Uninstall\CockpitDrone"
!ifndef EXE
  !define EXE "${RAIZ}\src\drone.exe"
!endif

!include "MUI2.nsh"
!include "x64.nsh"

Name "${APP_NAME} ${APP_VERSION}"
OutFile "..\bin\setup_cockpit_drone_0.46.exe"
InstallDir "$PROGRAMFILES64\cockpit drone"
InstallDirRegKey HKLM "${UNINST_KEY}" "InstallLocation"
RequestExecutionLevel admin
BrandingText "${APP_PUBLISHER}"

VIProductVersion "0.46.0.0"
VIAddVersionKey /LANG=1046 "ProductName" "${APP_NAME}"
VIAddVersionKey /LANG=1046 "ProductVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=1046 "CompanyName" "${APP_PUBLISHER}"
VIAddVersionKey /LANG=1046 "FileDescription" "Instalador do ${APP_NAME}"
VIAddVersionKey /LANG=1046 "FileVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=1046 "LegalCopyright" "${APP_PUBLISHER}"

!define MUI_ICON "${RAIZ}\src\drone.ico"
!define MUI_UNICON "${RAIZ}\src\drone.ico"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Abrir o ${APP_NAME}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "PortugueseBR"

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "O ${APP_NAME} ${APP_VERSION} requer Windows de 64 bits."
    Abort
  ${EndIf}
  SetRegView 64
FunctionEnd

Section "${APP_NAME} (obrigatório)" SecPrograma
  SectionIn RO
  SetOutPath "$INSTDIR"
  File "/oname=${APP_EXE}" "${EXE}"
  File "${RAIZ}\README.md"
  SetOverwrite off
  File "${RAIZ}\src\objetos.json"
  SetOverwrite on
  SetOutPath "$INSTDIR\imgs"
  File /r "${RAIZ}\src\imgs\*.*"
  SetOutPath "$INSTDIR\data"
  File /r "${RAIZ}\data\*.*"
  ; Decodificador de vídeo: ffmpeg (GPL, build BtbN/FFmpeg-Builds), copiado
  ; para install\redist antes de compilar o instalador (não fica no git).
  SetOutPath "$INSTDIR"
  File "redist\ffmpeg.exe"
  File "redist\libcrypto-3-x64.dll"
  File "redist\libssl-3-x64.dll"
  SetOutPath "$INSTDIR\runtime\python"
  File /r "${RAIZ}\runtime\python\*.*"
  SetOutPath "$INSTDIR\tools"
  File "${RAIZ}\tools\*.py"
  SetOutPath "$INSTDIR\docs"
  File "${RAIZ}\docs\PROTOCOLOS_0.46.md"
  File "${RAIZ}\docs\CONTROLES_0.46.md"
  File "${RAIZ}\docs\DEPENDENCIAS_0.46.md"
  File "${RAIZ}\docs\WIFI_8K_EXPERIMENTAL.md"
  File "${RAIZ}\docs\WIFI_8K_EXPERIMENTAL.en.md"
  SetOutPath "$INSTDIR"
  File "${RAIZ}\runtime-manifest-0.46.json"
  SetOutPath "$INSTDIR\licenses"
  File "redist\OpenSSL-LICENSE.txt"
  File "${RAIZ}\docs\THIRD_PARTY_NOTICES_0.46.txt"
  SetOutPath "$INSTDIR"
  File "redist\ffmpeg-LICENSE.txt"

  ; Vídeos e quadros são gravados na pasta do programa.
  nsExec::Exec 'icacls "$INSTDIR" /grant *S-1-5-32-545:(OI)(CI)M /T /Q'

  CreateShortCut "$SMPROGRAMS\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"

  WriteUninstaller "$INSTDIR\desinstalar.exe"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKLM "${UNINST_KEY}" "Publisher" "${APP_PUBLISHER}"
  WriteRegStr HKLM "${UNINST_KEY}" "URLInfoAbout" "${APP_URL}"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\${APP_EXE}"
  WriteRegStr HKLM "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNINST_KEY}" "UninstallString" '"$INSTDIR\desinstalar.exe"'
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoRepair" 1
SectionEnd

Section "Simulador Cockpit Drone" SecSimulador
  SetOutPath "$INSTDIR\simulador"
  File "${RAIZ}\simulador\simulador.exe"
  File "redist\libcrypto-3-x64.dll"
  File "redist\libssl-3-x64.dll"
  SetOutPath "$INSTDIR\simulador\config"
  File /r "${RAIZ}\simulador\config\*.*"
  CreateShortCut "$SMPROGRAMS\Simulador Cockpit Drone.lnk" "$INSTDIR\simulador\simulador.exe" "" "$INSTDIR\simulador\simulador.exe" 0
SectionEnd

Section "Firmware do drone ESP32" SecFirmware
  SetOutPath "$INSTDIR\firmware"
  File /r "${RAIZ}\firmware\*.*"
  CreateShortCut "$SMPROGRAMS\Firmware do drone ESP32.lnk" "$INSTDIR\firmware"
SectionEnd

Section /o "Atalho na área de trabalho" SecDesktop
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
  CreateShortCut "$DESKTOP\Simulador Cockpit Drone.lnk" "$INSTDIR\simulador\simulador.exe"
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecPrograma} "O cockpit e os arquivos necessários."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecSimulador} "Simulador de voo com emulação de drones, mapa de satélite e mundo compartilhado."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecFirmware} "Código-fonte do firmware do drone ESP32 e o protocolo CDP."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} "Cria atalhos na área de trabalho."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Function un.onInit
  SetRegView 64
FunctionEnd

Section "Uninstall"
  Delete "$INSTDIR\${APP_EXE}"
  Delete "$INSTDIR\README.md"
  Delete "$INSTDIR\objetos.json"
  Delete "$INSTDIR\ffmpeg.exe"
  Delete "$INSTDIR\ffmpeg-LICENSE.txt"
  Delete "$INSTDIR\libcrypto-3-x64.dll"
  Delete "$INSTDIR\libssl-3-x64.dll"
  Delete "$INSTDIR\runtime-manifest-0.46.json"
  RMDir /r "$INSTDIR\runtime"
  RMDir /r "$INSTDIR\tools"
  RMDir /r "$INSTDIR\docs"
  RMDir /r "$INSTDIR\licenses"
  Delete "$INSTDIR\desinstalar.exe"
  RMDir /r "$INSTDIR\imgs"
  RMDir /r "$INSTDIR\firmware"
  RMDir /r "$INSTDIR\simulador"
  ; Vídeos e quadros gravados pelo usuário são mantidos.
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\Simulador Cockpit Drone.lnk"
  Delete "$SMPROGRAMS\Firmware do drone ESP32.lnk"
  Delete "$DESKTOP\${APP_NAME}.lnk"
  Delete "$DESKTOP\Simulador Cockpit Drone.lnk"
  DeleteRegKey HKLM "${UNINST_KEY}"
SectionEnd
