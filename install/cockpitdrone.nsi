; Instalador do Cockpit Drone — NSIS 3 (alternativa ao cockpitdrone.iss)
; Compile a partir da pasta install:
;   makensis cockpitdrone.nsi
;   makensis -DEXE=caminho\drone.exe cockpitdrone.nsi   (outro executável)
; Saída: install\win32\win_setup_042.exe

Unicode true
SetCompressor /SOLID lzma

!define APP_NAME      "Cockpit Drone"
!define APP_VERSION   "0.42"
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
OutFile "win32\win_setup_042.exe"
InstallDir "$PROGRAMFILES64\cockpit drone"
InstallDirRegKey HKLM "${UNINST_KEY}" "InstallLocation"
RequestExecutionLevel admin
BrandingText "${APP_PUBLISHER}"

VIProductVersion "0.42.0.0"
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
  ; Decodificador de vídeo opcional (install\redist\ffmpeg.exe)
  SetOutPath "$INSTDIR"
  File /nonfatal "redist\ffmpeg.exe"

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

Section "Firmware do drone ESP32" SecFirmware
  SetOutPath "$INSTDIR\firmware"
  File /r "${RAIZ}\firmware\*.*"
  CreateShortCut "$SMPROGRAMS\Firmware do drone ESP32.lnk" "$INSTDIR\firmware"
SectionEnd

Section /o "Atalho na área de trabalho" SecDesktop
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecPrograma} "O cockpit e os arquivos necessários."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecFirmware} "Código-fonte do firmware do drone ESP32 e o protocolo CDP."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop} "Cria um atalho na área de trabalho."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Function un.onInit
  SetRegView 64
FunctionEnd

Section "Uninstall"
  Delete "$INSTDIR\${APP_EXE}"
  Delete "$INSTDIR\README.md"
  Delete "$INSTDIR\objetos.json"
  Delete "$INSTDIR\ffmpeg.exe"
  Delete "$INSTDIR\desinstalar.exe"
  RMDir /r "$INSTDIR\imgs"
  RMDir /r "$INSTDIR\firmware"
  ; Vídeos e quadros gravados pelo usuário são mantidos.
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\Firmware do drone ESP32.lnk"
  Delete "$DESKTOP\${APP_NAME}.lnk"
  DeleteRegKey HKLM "${UNINST_KEY}"
SectionEnd
