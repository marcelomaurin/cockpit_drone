# Plano de alterações — Cockpit Drone

**Versão do plano:** 1.0 — 2026-11-06  
**Escopo:** dirigibilidade, veículos aéreos/aquáticos, visão computacional, internacionalização, documentação e distribuição.  
**Estado geral:** planejamento; nenhum item abaixo deve ser interpretado como homologado em hardware.

## 1. Objetivo e critérios gerais

Transformar o Cockpit em estação de controle multiplataforma, modular e segura, com protocolos documentados, reconhecimento visual opcional e oito idiomas. Preservar compatibilidade com os drones existentes e com os componentes reutilizáveis do repositório [CHATGPT](https://github.com/marcelomaurin/CHATGPT).

**Definição de concluído:** código integrado na principal, compilação Windows/Linux, testes automatizados, simulação quando aplicável, documentação atualizada e evidências reproduzíveis. **Homologação física** é uma etapa distinta, por modelo/firmware, e não pode ser inferida do protocolo.

## 2. Diagnóstico inicial (não homologado)

| Área | Base existente | Lacuna |
|---|---|---|
| Controles | Eixos proporcionais e zona morta no caminho comum | Calibração, inversão, perda de sinal, FQ777 independente, segurança por veículo |
| Protocolos | CX-10W, MAVLink, Tello, ESP-Drone, FQ777, AR.Drone, ESP32/CDP | Testes por firmware/modelo e perfis de controle |
| Catálogo | `data/drone_models.json`, com perfis adicionais | Adaptadores de avião, helicóptero, barco e ROV; não confundir catálogo com suporte |
| Vídeo | Quadros H.264 decodificados em algumas conexões | Cobertura por protocolo, qualidade, latência e estados de desconexão |
| Visão | `tools/drone_vision.py` (YOLO, BoT-SORT, MediaPipe) | Processo gerenciado, resultados estruturados no Lazarus, overlays, múltiplas poses, desempenho |
| Idiomas | `src/cockpit_i18n.pas`, seletor e guia introdutório | Catálogo integral, atualização dinâmica, árabe RTL, testes Unicode, manuais |
| Qualidade | Código publicado | CI, compilação reproduzível, testes SITL, pacote e documentação de versão |

## 3. Fases e entregas

### Fase 0 — Inventário, compilação e testes de base (P0)

- [ ] Inventariar `.lpi`, dependências Lazarus AI Suite, versões FPC/Lazarus e sistemas suportados. **Parcial:** script de inventário XML `.lpi`/`.lpk` criado em `tools/inventory_lazarus.py`, com testes unitários de fixtures e execução adicionada ao workflow; execução verde, identificação completa de dependências e versões ainda pendentes.
- [ ] Compilar em Windows e Linux e registrar erros reais; corrigir falhas sem modificar comportamento de voo sem testes.
- [ ] Criar CI com build e verificações estáticas, além de testes de parsing do catálogo e localização. **Parcial: testes estáticos de contratos e workflow GitHub Actions adicionados; build Lazarus e execução verde do workflow ainda não confirmados.**
- [ ] Definir contrato comum de telemetria, comando, capacidades e erros; identificar diferenças entre controladores.
- [ ] Documentar instalação, requisitos, permissões e reprodução dos testes. **Parcial:** criado `docs/COMPILACAO_E_VALIDACAO.md` com roteiro, requisitos conhecidos e matriz de evidências; versões exatas e instalação completa ainda dependem do inventário.

**Aceite:** builds reproduzíveis e relatório de testes com logs e versões.

### Fase 1 — Dirigibilidade e segurança (P0)

- [ ] Criar `TComandoVeiculo` com eixos normalizados, timestamp, origem, validade e estado de armamento.
- [x] Separar leitura de joystick de sucesso de leitura: `UpdateState=True` indica leitura bem-sucedida mesmo sem mudança; exceções retornam `False` e neutralizam o estado. **Implementado em código, ainda sem compilação/teste físico.**
- [ ] Calibração por dispositivo: centro, mínimos/máximos, inversão, zona morta, curva e perfil persistente.
- [ ] Revisar neutralização do botão B5 e mapear o caminho independente do FQ777. **B5 corrigido no caminho comum; revisão do FQ777 pendente.**
- [ ] Watchdog de comando e vídeo/telemetria; perda de entrada aplica política específica por veículo, não uma aceleração genérica.
- [ ] Introduzir limites, autorização explícita para armar, parada de emergência e registro de eventos.
- [ ] Testar eixos e misturas em bancada **sem hélices/propulsores** e em simulação.

**Aceite:** matriz de testes de neutralidade, extremos, falha de joystick, falha de rede e retomada, por protocolo. Não habilitar controle físico sem revisão.

### Fase 2 — Abstração de classes e protocolos (P0/P1)

- [ ] Interface `IVehicleAdapter`: conectar, capacidades, estado, armar/desarmar, comandos, vídeo, telemetria e failsafe.
- [ ] Classes `multirotor`, `fixed_wing`, `vtol`, `helicopter`, `boat`, `sailboat`, `rov`.
- [ ] Adaptadores MAVLink por classe: identificar tipo e modo real a partir de heartbeat/capabilities antes de habilitar controles.
- [ ] Asa fixa: superfícies de controle e potência; helicóptero: cíclico/coletivo/cauda; barco: leme/reversão; ROV: 6 graus de liberdade quando suportados.
- [ ] Integração ArduPilot SITL: Plane, Copter/heli, Rover/Boat e Sub; registrar mensagens e comportamento.
- [ ] Revisar transportes UDP/TCP/serial, descoberta, reconexão, autenticação quando suportada e limites de latência.
- [ ] Manter DJI/Parrot SDK e outros modelos sem adaptador como **não controláveis**, mesmo que listados.
- [ ] Wi-Fi subaquático: usar ponte de superfície e tether, não prometer RF Wi-Fi submerso.

**Aceite:** perfil só muda para `simulator_validated` após testes SITL; `hardware_validated` exige evidência por modelo/firmware. Não expor comandos de aeronave em barco/ROV.

### Fase 3 — Vídeo, detecção e interpretação (P1)

- [ ] Normalizar interface de frames (timestamp, origem, resolução, formato, taxa, perdas) entre conexões.
- [ ] Gerenciar worker local Python: iniciar, parar, detectar falha, escolher CPU/GPU e configurar taxa.
- [ ] Substituir arquivos BMP por IPC/fila com limite e descarte de frames antigos; evitar bloquear UI/controle.
- [ ] YOLO para pessoas/objetos, BoT-SORT para tracking e MediaPipe para pose; definir suporte explícito a múltiplas poses (modelo adequado).
- [ ] Exibir caixas, classes, confiança, IDs e pontos/esqueleto sobre o vídeo.
- [ ] Contrato JSON versionado e testes com quadros gravados, incluindo ausência de pessoas e falhas.
- [ ] Adaptador de visão do framework CHATGPT para análise descritiva **sob demanda**, local/remota, com consentimento e política de retenção.
- [ ] IA de visão permanece separada do piloto; nenhum movimento automático por texto/objeto sem autorização e camada de segurança dedicada.

**Aceite:** desempenho/latência mensurados, overlay alinhado, falhas isoladas do controle e resultados reprodutíveis.

### Fase 4 — Internacionalização completa (P1)

Idiomas: **pt-BR, en, es, zh-CN, ar, de, ru, hi** (hindi representa a opção indiana inicialmente).

- [ ] Extrair textos de telas, menus, botões, tooltips, mensagens, estados, erros e diálogos para catálogo por chave estável.
- [ ] Utilizar mecanismo compatível com Lazarus/GetText ou catálogo UTF-8 versionado, sem associar tradução à legenda atual.
- [ ] Persistir idioma; aplicar sem reiniciar quando possível; fallback para pt-BR; preservar códigos de protocolo e marcas.
- [ ] Validar caracteres Unicode, fontes e disposição RTL para árabe, inclusive alinhamento e controles.
- [ ] Criar manuais completos em oito idiomas: instalação, operação, joystick, vídeo/IA, segurança, modelos, FAQ e diagnóstico.
- [ ] Documentar como contribuir com traduções e adicionar verificação de chaves ausentes à CI.

**Aceite:** todas as telas percorridas em oito idiomas, sem strings não traduzidas no fluxo principal, e revisão humana dos termos críticos de segurança.

### Fase 5 — Homologação e distribuição (P1/P2)

- [ ] Matriz por veículo: fabricante/modelo/firmware, protocolo, vídeo, telemetria, controle, failsafe e evidência.
- [ ] Ensaios SITL, bancada sem atuadores e campo controlado com procedimentos de segurança.
- [ ] Instaladores Windows/Linux, empacotamento de dependências opcionais de visão, checksums e notas de versão.
- [ ] Guia de migração, backup de configurações e rollback.
- [ ] Atualizar README, docs e catálogo de compatibilidade a cada versão.

**Aceite:** pacotes instaláveis, resultados rastreáveis e limitações publicadas por equipamento.

## 4. Organização de código proposta

```text
src/
  core/             comandos, estados, capacidades, failsafe
  input/            joystick, calibração, perfis
  vehicles/         adaptadores por classe
  video/            fontes e pipeline de frames
  vision/           cliente IPC, resultados, overlays
  i18n/             catálogos e carregamento de idiomas
tools/
  drone_vision.py   worker de detecção (evoluir)
tests/
  unit/ integration/ sitl/ fixtures/
docs/
  PLANO_ALTERACOES_COCKPIT.md
  LANGUAGES.md
  COMPATIBILIDADE.md
  TESTES_E_HOMOLOGACAO.md
  manuals/<idioma>/
```

A migração deve ser incremental, mantendo as units atuais até que os testes cubram as substitutas.

## 5. Priorização, dependências e responsáveis

| Ordem | Entrega | Prioridade | Depende de | Evidência exigida |
|---|---|---|---|---|
| 1 | Build/CI e inventário | P0 | — | logs Windows/Linux |
| 2 | Controle e failsafe | P0 | 1 | testes de comando e falha |
| 3 | Classes de veículo/MAVLink | P0 | 2 | SITL por classe |
| 4 | Vídeo e visão integrada | P1 | 1 | testes de frames e UI |
| 5 | Idiomas e documentação | P1 | 1 | cobertura de traduções |
| 6 | Homologação e releases | P1 | 2–5 | matriz e pacotes |

**Responsável técnico:** a designar. Cada tarefa deve registrar issue/PR, autor, revisão, versão, evidência e estado (planejado, em desenvolvimento, testado em simulador, validado em hardware).

## 6. Riscos e mitigação

- **Acionamento indevido:** neutralidade por classe, watchdog, autorização para armar, testes SITL e bloqueio padrão.
- **Protocolo conhecido ≠ compatibilidade:** não liberar modelo por simples presença no catálogo.
- **IA bloquear o controle:** processos separados, filas limitadas e prioridade à comunicação de voo.
- **Baixa confiabilidade do vídeo:** métricas de atraso, descarte de quadros antigos e estado visível.
- **Tradução de comandos de segurança:** revisão humana, testes RTL e fallback seguro.
- **Dependências e licenças:** registrar versões, licenças e requisitos de modelos/SDKs antes de distribuir.

## 7. Checklist de encerramento do projeto

- [ ] Build Windows/Linux aprovado
- [ ] Testes automatizados e SITL aprovados
- [ ] Joystick e failsafe verificados por classe
- [ ] Catálogo com status verdadeiro por modelo/firmware
- [ ] Vídeo e visão integrados e testados
- [ ] ChatGPT/LLM visual opcional e isolado do controle
- [ ] Oito idiomas completos e revisados
- [ ] Manuais completos nos oito idiomas
- [ ] Instaladores, hashes e rollback
- [ ] Evidência de validação física somente onde houver ensaio real

## 8. Registro de execução

| Data | Entrega | Arquivos | Estado | Evidência |
|---|---|---|---|---|
| 2026-11-06 | Leitura de joystick retorna sucesso mesmo com eixos constantes; estado neutralizado em exceção | `src/joystick.pas` | Código implementado; compilação pendente | commit `22d0ba99` |
| 2026-11-06 | Main usa resultado real da leitura; B5 mantém X/Y centralizados | `src/main.pas` | Código implementado; simulação/hardware pendentes | commit `d2be32c6` |

**Próxima execução:** inventário de dependências e build Lazarus; testes automatizados de joystick; inspeção do caminho FQ777; política de failsafe por classe de veículo.

### Revisão do FQ777-954 — 2026-11-06

**Estado:** inspeção de código concluída; correções ainda não aplicadas e não validadas.

- O módulo `src/conectionfq777.pas` faz polling de `TAIJoystick` e substitui por estado padrão quando a leitura falha. Verificar se a perda do joystick durante a operação exige bloqueio de aceleração e recuperação explícita.
- A lógica `FCorte` libera automaticamente o corte quando o acelerador volta ao mínimo. Exigir avaliação de segurança e teste em bancada sem hélices antes de alterar.
- O timer envia `SetSticks` periodicamente. Confirmar comportamento da biblioteca `TAIDroneFQ777` quando `ControlConnected=False` e a existência de watchdog no firmware.
- Validar alternância teclado/joystick, eixo de aceleração centrado ou não, e ausência de entradas.
- **Não considerar homologado** até revisão da biblioteca `openai_drone`, testes automatizados e ensaios em bancada.

### Automação de contratos — 2026-11-06

- Adicionado `tests/test_project_contracts.py` com testes estáticos para unicidade/status do catálogo, semântica de leitura do joystick, uso do resultado no formulário principal e presença dos oito códigos de idioma.
- Adicionado `.github/workflows/project-contracts.yml` para executar os testes em pushes na `master`, pull requests e manualmente.
- **Estado:** arquivos publicados. Ainda não há evidência de execução bem-sucedida no GitHub Actions, compilação FPC/Lazarus ou testes de hardware. Testes estáticos não demonstram segurança de voo.
- **Próximo passo:** inspecionar execução do workflow, corrigir eventuais falhas, criar ambiente de build com dependências Lazarus AI Suite e testes SITL.

### Procedimento de compilação — 2026-11-06

- Criado `docs/COMPILACAO_E_VALIDACAO.md`, com execução dos testes Python, preparação Lazarus/FPC, dependências, checklist e cuidados para ensaios de controle.
- **Estado:** documentação publicada; nenhuma compilação Windows/Linux ou execução verde de CI foi confirmada nesta etapa.
- **Próxima entrega:** inventariar projetos `.lpi` e pacotes `.lpk`, obter build real e registrar erros antes de marcar Fase 0 concluída.

### Inventário automatizado — 2026-11-06

- Criado `tools/inventory_lazarus.py`: percorre projetos `.lpi` e pacotes `.lpk`, lê referências XML, conta units Pascal e oferece saída `--json`.
- Execução prevista: `python tools/inventory_lazarus.py --json`. O comando sinaliza erro quando não encontra `.lpi` ou quando um XML não pode ser analisado.
- **Estado:** script publicado, não executado em checkout completo neste ambiente; não foi possível comprovar builds ou resolver dependências de terceiros.
- **Pendente:** executar inventário em checkout real, corrigir referências, fixar versões de FPC/Lazarus, integrar build à CI.

### Testes do inventário e integração CI — 2026-11-06

- Criado `tests/test_inventory_lazarus.py`: testes de XML válido, pacotes, units, ausência de `.lpi` e XML inválido usando diretórios temporários.
- Atualizado `.github/workflows/project-contracts.yml` para executar `python tools/inventory_lazarus.py --json` após a suíte de contratos.
- O inventário retorna código de erro se não existir projeto `.lpi` ou se houver XML inválido. **Se o projeto estiver ausente no checkout, o workflow falhará intencionalmente**; essa falha deve orientar a correção do repositório, não ser ignorada.
- **Estado:** alterações publicadas; execução do CI e compilação Lazarus ainda não verificadas. Nenhuma etapa de homologação marcada como concluída.

### Correção de inventário e artefatos CI — 2026-11-06

- Corrigido `tools/inventory_lazarus.py` para coletar nomes de pacotes apenas sob `RequiredPackages`, evitando confundir outros elementos `Item` com dependências.
- Expandido `tests/test_inventory_lazarus.py` com um `Item` que não é pacote, para impedir regressão.
- Atualizado `.github/workflows/project-contracts.yml` para produzir `lazarus-inventory.json` e anexá-lo como artefato do workflow, inclusive quando etapas anteriores falharem.
- **Estado:** alterações de código e CI publicadas; execução verde, build Lazarus e testes físicos ainda não comprovados.

## 9. Referências técnicas

- [MAVLink](https://mavlink.io/en/)
- [ArduPilot](https://ardupilot.org/)
- [ArduSub](https://ardupilot.org/sub/)
- [ArduPilot SITL](https://ardupilot.org/dev/docs/sitl-simulator-software-in-the-loop.html)
- [Ultralytics tracking](https://docs.ultralytics.com/modes/track/)
- [MediaPipe Pose](https://ai.google.dev/edge/mediapipe/solutions/vision/pose_landmarker)
- [GNU gettext](https://www.gnu.org/software/gettext/manual/)
