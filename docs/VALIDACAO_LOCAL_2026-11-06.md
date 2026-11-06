# Correções e validação local — 2026-11-06

## Escopo efetivamente executado

Auditoria dos dois repositórios, preservação de mudanças locais, correção de defeitos reproduzidos e testes. Conforme orientação posterior do usuário, instaladores, numeração de versão e release ficaram com a outra sessão. Nenhuma nova tentativa de compilação foi iniciada após a ordem de parar.

Bases consultadas: Cockpit Drone `master` em `2cdc32d`; CHATGPT `main` em `2591acb2`. `git fetch origin` confirmou ambas alinhadas com seus respectivos remotos. Não foi necessário aplicar merge, reset ou stash. O branch `origin/feat/fq777-954` já é ancestral da `master`. A busca nos textos dos branches locais e remotos dos dois projetos não encontrou a descrição individual de CD-001 a CD-018; portanto esses IDs não foram marcados como concluídos.

## Defeitos corrigidos

1. **Ponte SITL não compilava:** `poStderrToOut` não existe no FPC 3.2.2. Substituído por `poStderrToOutPut`, confirmado no código-fonte local do compilador. O teste de ciclo de vida passou depois da correção.
2. **Dois testes Python desatualizados:** GCS e rover terrestre são descartados pelo monitor e retornam `None`; os testes ainda acessavam um dicionário. Ajustadas as expectativas para verificar explicitamente o descarte, preservando o comportamento do monitor.
3. **Dependências legadas bloqueavam o aplicativo:** removidos `fpowm`, `lazupdate`, `playwavepackage`, `MPlayerControlLaz` e `laz_acs`, sem referências funcionais restantes. Os dois componentes não visuais de áudio sem uso foram retirados do formulário. GPS, serial, mapa e controles utilizados foram mantidos. O joystick vem do pacote `bgragames`, evitando duplicar as mesmas units via outro pacote.
4. **MAPA podia dar a volta no byte:** o teste de entrada abaixo do mínimo falhou antes da correção. O cálculo agora satura a entrada na faixa, limita a saída a 0..255 e rejeita números não finitos ou intervalo de entrada nulo. Neutralidade do controlador também foi testada.
5. **Rotas aceitavam valores não finitos:** o teste reproduziu a aceitação de `NaN` pelo leitor numérico. Leitura e validação agora rejeitam NaN/infinito antes de cálculos de distância e tempo; também rejeitam limite de distância não positivo e limites de altitude invertidos. Incluídos casos para coordenadas, altitude, velocidade, home e configurações.
6. **Monitor SITL dependia da pasta de abertura:** agora é localizado em `tools/` ao lado do executável ou um nível acima, no layout de desenvolvimento. `COCKPIT_PYTHON` permite escolher explicitamente o interpretador. A descoberta foi testada com pastas temporárias.

Adicionados `tools/test_local.ps1`, `requirements-sitl.txt` e workflow de regressão para tornar os testes reproduzíveis. O workflow foi escrito, mas sua execução remota não foi acionada nem comprovada.

## Evidências obtidas antes da ordem de não recompilar

| Verificação | Resultado comprovado |
|---|---|
| Lazarus instalado | 4.6 |
| Free Pascal | 3.2.2; testes iniciais i386 e regressão final x86_64 |
| Python usado nos testes | 3.13.7 |
| pymavlink em pasta isolada | 2.4.50; fastcrc 0.5.0 e lxml 6.1.3 |
| `openai_core` | Recompilação completa aprovada; há warnings legados |
| `openai_input` | Recompilação completa aprovada; há warnings legados |
| `openai_hardware` | Recompilação completa aprovada, incluindo `aideviceidentifier` local |
| `openai_video` | Recompilação completa aprovada |
| `openai_drone` | Recompilação completa aprovada |
| `src/drone.lpi` Windows x86_64 | Compilação final aprovada, exit 0; 5222 linhas recompiladas |
| Suítes Pascal próprias | 6 aprovadas em x86_64, com `-Cr -Co -Ci -gl` |
| Teste `TAIJoystick` do framework | Aprovado com dispositivo simulado |
| Python completo | 39 testes aprovados, sem skips, incluindo 2 testes UDP reais |
| UDP MAVLink → monitor Python | Heartbeat, IDs, classe, uint32 máximo, armamento relatado e timeout aprovados |
| UDP MAVLink → Python → ponte Pascal | Recepção, limpeza integral após timeout e Stop repetido aprovados |

As seis suítes Pascal são estado SITL, ciclo de vida da ponte, validação MAVLink, mapeamento de entrada, validação de rotas e localização dos scripts. O programa Pascal de loopback é um sétimo binário de apoio, exercitado por um dos 39 testes Python, e não é contado como outra suíte independente.

O arquivo LazMapViewer arquivado localmente estava corrompido. Foi obtida cópia válida do catálogo oficial, pacote 1.0.2, usada em configuração Lazarus separada. URL: https://packages.lazarus-ide.org/LazMapViewer.zip . SHA-256 do ZIP: `c0d6248302b57a0a383237f5139c38b941d52616db79e68851f803895f8de394`.

## Preservação e concorrência

O diff original dos dois arquivos locais de hardware foi comparado novamente e permanece idêntico. Os nove arquivos inicialmente não rastreados também permanecem idênticos por SHA-256. O registro de pacotes regenerou código de registro; a formatação e ordem incidentais foram restauradas à situação original após conferir equivalência. As mudanças funcionais locais de hardware foram preservadas.

Foram observadas edições concorrentes em versão, instaladores e arquivos RIA. Elas ficaram fora das correções e não foram revertidas. O executável resultante foi produzido antes da última orientação de parar; nenhuma nova compilação será inferida ou prometida a partir deste relatório.

## Limites e pendências reais

- **ArduPilot SITL não executado:** nenhum simulador instalado foi localizado nos diretórios pesquisados e WSL não estava pronto para execução. Mensagens MAVLink em loopback comprovam a cadeia de telemetria, mas não equivalem a um autopiloto SITL.
- **Interface visual não validada:** Computer Use não conseguiu listar janelas mesmo após as tentativas de recuperação; não foi feito ensaio visual nem teste de navegação.
- **Linux:** compilação do aplicativo e execução do novo workflow não verificadas.
- **Hardware/voo/FFmpeg/visão/idiomas:** nenhum ensaio físico ou homologação de vídeo, modelos de IA e tradução completa foi realizado nesta etapa.
- **Warnings:** Lazarus ainda avisa sobre `main`/`main.lfm` encontrados também no diretório de exemplo AISerial do framework. Os builds concluíram; a origem desses nomes duplicados permanece registrada para revisão.
- **Distribuição:** instaladores, versão e publicação permanecem sob responsabilidade da outra sessão, conforme instrução explícita do usuário.

Essas pendências impedem afirmar finalização integral das 18 tarefas ou prontidão de produção.

## Como reproduzir os testes quando houver autorização para isso

Na raiz do Cockpit, instale `requirements-sitl.txt` no Python de teste e execute `tools/test_local.ps1` com `-Compiler`, `-Python` e `-MavlinkIntegration`. O script gera logs por etapa e `results.json`. Sem a opção de integração, os testes UDP podem ser pulados; essa execução reduzida não equivale ao resultado de 39 testes sem skips registrado acima.

Os logs integrais, resultados e verificação de preservação acompanham o arquivo de evidências desta execução. Nenhum comando deste roteiro foi executado novamente após a ordem de não recompilar.
