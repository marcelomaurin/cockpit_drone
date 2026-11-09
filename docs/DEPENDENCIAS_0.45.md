# Dependências da distribuição 0.45

O instalador é para Windows 10/11 x64 e inclui os componentes de execução abaixo. Não precisa de Lazarus/FPC ou Python instalado para usar o programa e o monitor SITL. O instalador não baixa dependências durante a instalação.

| Componente | Distribuição e uso |
| --- | --- |
| Cockpit Drone e Simulador | Binários Windows x64 0.45.0.0. Units Lazarus AI Suite (drone/input/hardware/vídeo), LCL, BGRA, SdpoJoystick, mapa, GPS, serial e CADSys utilizadas no programa foram vinculadas aos executáveis; não é necessário instalar pacotes .lpk no computador do piloto. |
| FFmpeg 8.1 | Build estático win64 GPL do FFmpeg-Builds, usado pelo decodificador H.264. ffmpeg.exe fica ao lado de drone.exe; licença em licenses. Codificação H.264 e decodificação BGRA testadas. |
| OpenSSL 3.5.9 LTS x64 | Build FireDaemon, DLLs libssl-3-x64.dll/libcrypto-3-x64.dll ao lado de ambos os executáveis. O binding local compat/openssl.pas conserva a interface FPC 3.2.2 e ajusta carregamento e nomes de funções da API 3. Conexão HTTPS e leitura de certificado remoto testadas. Não são distribuídas as antigas DLLs 1.0/1.1. |
| Python 3.13.7 privado x64 | Pacote embutido oficial Python em runtime/python, incluindo as DLLs de execução fornecidas por esse pacote e licença. Não altera o Python global. COCKPIT_PYTHON continua disponível para substituição explícita. |
| pymavlink 2.4.50, fastcrc 0.5.0 e lxml 6.1.3 | Incluídos no Python privado, com metadados/licenças. O monitor SITL e seus scripts ficam em tools; integração UDP/Python/Pascal testada. |
| Arquivos de execução | Catálogo de modelos, objetos, imagens, firmware, configurações/documentação do simulador, guia de pilotagem e avisos de terceiros incluídos. |
| APIs do Windows | WinHTTP/WebSocket, WinMM, XInput, rede, gráficos e demais DLLs do Windows são fornecidas pelo sistema operacional. O instalador não substitui essas DLLs. O controle Xbox conectado foi reconhecido pela API XInput do Windows no dispositivo 1. |

## Origem e integridade

- FFmpeg: https://github.com/FFmpeg-Builds/FFmpeg-Builds/releases/download/latest/ffmpeg-n8.1-latest-win64-gpl-8.1.zip
  SHA-256 do ZIP: 15D6AB92A0BB22ACEFFC8C363150C37A4A40A90CABBAEF325AB30B580FF24A71 (conferido com checksums.sha256 do publicador). O endereço latest é mutável; o hash identifica o arquivo exato desta distribuição.
- FFmpeg/build scripts e fontes: https://github.com/FFmpeg-Builds/FFmpeg-Builds e https://ffmpeg.org/download.html#get-sources . Configuração e versão completas são informadas por ffmpeg.exe -version; a licença GPL incluída acompanha o binário.
- OpenSSL: https://download.firedaemon.com/FireDaemon-OpenSSL/openssl-3.5.9.zip
  SHA-256 do ZIP: 76DA391395BE029B44794857B9FF380255E02A0960A98314CD3F6A6816D82696 (conferido com a página do publicador https://www.firedaemon.com/download-firedaemon-openssl).
- Python: https://www.python.org/ftp/python/3.13.7/python-3.13.7-embed-amd64.zip . Dependências Python fixadas em requirements-sitl.txt e instaladas em diretório privado.
- Binding OpenSSL: derivado da unit openssl.pas do FPC 3.2.2 instalado; copyright/licença preservados no arquivo. Compatibilidade da recuperação de certificados com OpenSSL 3: https://gitlab.com/freepascal.org/fpc/source/-/work_items/39998 .

O arquivo runtime-manifest-0.45.json da distribuição registra tamanho, SHA-256 e dependências PE do conteúdo. O build do instalador falha se FFmpeg, OpenSSL ou Python privado estiverem ausentes.

## Validação

Foram aprovados os 65 testes Python, incluindo integração UDP, as seis suítes Pascal existentes e as novas regressões de joystick/Cheerson e perfil/configuração. O cenário de joystick usa entradas reproduzíveis, o construtor do pacote do componente Cheerson e o emulador/física reais do projeto; não equivale a voo físico. O controle físico foi detectado e sua leitura em repouso foi examinada.

A inicialização do aplicativo foi acompanhada até a criação da janela principal e o laço de eventos, mas o controle visual remoto não conseguiu selecionar sua janela. Não se afirma ensaio visual completo nem homologação de todos os modelos reais. Bibliotecas adicionais de módulos opcionais não usados pelos executáveis não são incluídas por mera existência no repositório de dependências.

## Reproduzir

Use Lazarus 4.6/FPC 3.2.2 x64 com os pacotes registrados. Compile src/drone.lpi e simulador/src/simulador.lpi. Os caminhos de compatibilidade já constam dos projetos. Mantenha os dois binários de OpenSSL ao lado de cada executável. Prepare runtime/python e install/redist com os arquivos de origem acima. Compile install/cockpitdrone.iss com Inno Setup 7 para produzir bin/setup_cockpit_drone_0.45.exe. O NSIS alternativo foi atualizado, mas a distribuição desta execução usa Inno Setup.

Regressões: tools/test_local.ps1 -MavlinkIntegration -Python <runtime/python/python.exe> e tools/test_joystick.ps1 com a configuração Lazarus registrada. A própria compilação do instalador exige todos os arquivos de execução, sem dependências opcionais silenciosamente ignoradas.
