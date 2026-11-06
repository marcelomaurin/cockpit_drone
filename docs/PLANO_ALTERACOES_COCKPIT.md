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

### Resiliência da CI e inventário parametrizável — 2026-11-06

- Corrigido o workflow para executar a coleta de `lazarus-inventory.json` com `if: always()`, mesmo se os testes de contrato falharem.
- O utilitário `tools/inventory_lazarus.py` aceita `--root CAMINHO` para inventariar checkouts externos ou diretórios de teste sem alterar o código.
- **Estado:** alterações publicadas, mas ainda não foi possível confirmar a execução do GitHub Actions nem compilar o Cockpit. A Fase 0 permanece em andamento.

### Diagnóstico de compilação Linux — 2026-11-06

- Criado `.github/workflows/lazarus-build.yml`, acionável manualmente (`workflow_dispatch`) e em pull requests que alterem fontes Pascal, projetos Lazarus ou o próprio workflow.
- O job Ubuntu 24.04 instala `lazarus` e `fpc`, registra versões, produz inventário de projetos e tenta compilar todos os arquivos `.lpi` encontrados.
- Logs e inventário são preservados como artefato `lazarus-linux-build-diagnostics`, mesmo em caso de falha. Dependências externas não são instaladas automaticamente; falhas de pacotes são evidências para a próxima correção.
- **Estado:** workflow publicado; nenhuma execução, compilação verde ou homologação de hardware confirmada. Windows permanece pendente.

## 9. Referências técnicas

- [MAVLink](https://mavlink.io/en/)
- [ArduPilot](https://ardupilot.org/)
- [ArduSub](https://ardupilot.org/sub/)
- [ArduPilot SITL](https://ardupilot.org/dev/docs/sitl-simulator-software-in-the-loop.html)
- [Ultralytics tracking](https://docs.ultralytics.com/modes/track/)
- [MediaPipe Pose](https://ai.google.dev/edge/mediapipe/solutions/vision/pose_landmarker)
- [GNU gettext](https://www.gnu.org/software/gettext/manual/)


### Diagnóstico de build Linux — acompanhamento de execução (2026-11-06)

**Estado: aguardando execução verificável.** O workflow `.github/workflows/lazarus-build.yml` contém `workflow_dispatch` e tentativa de compilação com `lazbuild` no Ubuntu 24.04. A consulta de execuções associadas ao commit `76ddf811` não retornou execuções (a consulta do conector é limitada a execuções disparadas por pull request); isso **não comprova** que nenhuma execução manual ocorreu.

**Procedimento:** abrir GitHub Actions > *Lazarus build diagnostic* > *Run workflow* na branch `master`; após o término, registrar URL/ID da execução, conclusão, versão FPC/Lazarus, primeiro erro relevante, dependências ausentes e links dos artefatos `lazarus-linux-build-diagnostics`.

**Critério para atualizar tarefas:** marcar inventário executado apenas após conferir `lazarus-inventory.json`; marcar build aprovado apenas com execução concluída com sucesso e logs correspondentes; caso falhe, abrir pendências por erro de compilação e corrigir por ordem de dependência. Não registrar testes de hardware sem evidência.

| Item | Estado | Evidência pendente |
|---|---|---|
| Workflow Linux configurado | Implementado, não validado nesta revisão | URL da execução e resultado |
| Inventário real de dependências | Pendente | `lazarus-inventory.json` |
| Compilação Lazarus Linux | Pendente | `build.log` e versões do compilador |
| Compilação Windows | Pendente | Workflow e logs próprios |


### Segurança FQ777 — bloqueio conservador (2026-11-06)

- Alterado `src/conectionfq777.pas`: o corte de motores não é mais liberado automaticamente quando o acelerador retorna ao mínimo.
- Enquanto `ControlConnected=False`, o timer não chama `SetSticks`, mantém corte travado e zera a aceleração de teclado.
- **Restrição intencional:** o corte agora começa ativado e não existe rearme pela interface; o FQ777 fica indisponível para acionamento de motores até implementação e teste de rearme explícito com condições de segurança. Não utilizar em voo real.
- **Pendente:** implementar botão/fluxo de rearme com confirmação, acelerador mínimo, conexão estável, política para perda de joystick e testes sem hélices; verificar semântica real de `TAIDroneFQ777.ControlConnected`, compilar Lazarus e ensaiar em bancada.
- **Estado:** código publicado, sem compilação nem validação física. A Fase 1 permanece aberta; não marcar dirigibilidade como concluída.


### Rearme explícito FQ777 — 2026-11-06

- Adicionado botão de rearme manual em `src/conectionfq777.pas`, com confirmação, conexão de controle ativa, acelerador mínimo e eixos direcionais centralizados quando joystick conectado. Comandos de corte ativos impedem rearme.
- Com corte ativo, o timer neutraliza também rolagem, arfagem e guinada, além do acelerador; perda de conexão mantém bloqueio.
- **Estado: implementação inicial, não homologada.** Não há prova de compilação, teste de firmware, estabilidade do enlace ou resposta dos motores. Rearme não implica autorização para voo real.
- **Pendências de segurança:** teste de leitura inválida do joystick, confirmação da escala de acelerador em cada configuração, debouncing de conexão, prevenção de comandos de teclado durante diálogo modal, ensaio sem hélices e verificação de failsafe no firmware. Manter Fase 1 aberta até essas evidências.


### Revisão de entrada FQ777 — 2026-11-06

- Alteração no código: perda de joystick anteriormente conectado passa a manter o corte até rearme manual.
- Sem joystick conectado, a contribuição do acelerador desse dispositivo passa a ser zero, inclusive com opção de eixo centrado.
- Commit de código: `74f31c9d`.
- Pendente: compilação, testes de reconexão, ensaio em bancada sem hélices e homologação. Não liberado para voo.


### Contrato comum de comandos — 2026-11-06

- Criado `src/vehicle_control_contract.pas` com tipos separados para multirrotor, asa fixa, helicóptero, barco e submersível.
- Cada classe possui lista de eixos permitidos, comando neutro e validação de intervalo [-1,1], valores finitos e comandos desarmados neutros.
- **Escopo:** contrato de dados independente de protocolo; ainda não está ligado aos adaptadores MAVLink, FQ777 ou à interface. Não há controle físico novo.
- **Pendente:** testes unitários, integração por adaptador, definição de convenções e faixas por protocolo, política de failsafe, compilação Lazarus e validação em simulador. Fase 2 permanece parcial.


### Mapeamento MAVLink por classe — 2026-11-06

- Criado `docs/MAVLINK_MAPEAMENTO_VEICULOS.md` com matriz de comandos para multirrotor, avião, helicóptero, barco e submersível, regras de segurança e checklist de implementação.
- Estado: **documentação publicada; adaptadores MAVLink e testes SITL pendentes**. Nenhum equipamento adicional foi habilitado para controle.


### Validação de adaptador MAVLink — 2026-11-06

- Criado `src/mavlink_vehicle_adapter.pas` com `TMavlinkAdapterState` e `ValidateMavlinkDispatch`.
- Verificações iniciais: contrato válido, classe de veículo coincidente, heartbeat e entrada recentes, modo aprovado e estado de armamento confirmado.
- A validação só permite fluxo marcado `SimulatorOnly`; não existe serialização ou transporte MAVLink, nem controle físico habilitado.
- **Estado: código publicado, não compilado e não integrado ao Cockpit.** Pendentes testes unitários, tratamento de timeouts com relógio monotônico, descoberta de capacidades, integração SITL e definição dos modos específicos por veículo.


### Testes de contrato do adaptador MAVLink — 2026-11-06

- Criado `tests/test_mavlink_adapter_contract.py` com verificações estáticas para contrato, classes de veículos, heartbeat, entrada, modo, armamento e bloqueio de hardware.
- **Limitação:** testes estáticos verificam presença de guardas no código, não executam Pascal, não exercitam os ramos da validação nem demonstram interoperabilidade MAVLink/SITL.
- **Estado:** arquivo publicado; execução da suíte, testes comportamentais Pascal, integração no CI, compilação e testes SITL pendentes.


### CI e testes comportamentais MAVLink — 2026-11-06

- Atualizado `.github/workflows/project-contracts.yml` para executar explicitamente `test_mavlink_adapter_contract.py` antes da suíte geral (a suíte geral também inclui esse arquivo).
- Criado `tests/test_mavlink_validation.pas`, programa de testes comportamentais para comando neutro, bloqueio de transporte físico, heartbeat/entrada obsoletos, modo inválido, classe incompatível, movimento desarmado e eixo proibido.
- **Estado:** arquivos publicados; teste Pascal não foi compilado nem executado, e execução verde do CI não foi confirmada. O teste Pascal ainda não integra o workflow; permanece para a etapa de compilação previamente adiada.


### Preparação ArduPilot SITL — 2026-11-06

- Criado `docs/SITL_INTEGRACAO.md`: arquitetura planejada de transporte UDP em loopback, parser MAVLink v2, heartbeat, identificação de veículo, cenários de falha e critérios de aceite.
- Criado `tests/test_sitl_contract.py`: verificações estáticas de documentação e restrição de simulação no adaptador.
- **Estado:** especificação e testes estáticos publicados. Ainda não existe comunicação MAVLink com SITL implementada, nem compilação ou execução de testes confirmada. Integração permanece pendente.


### Monitor MAVLink de heartbeat SITL — 2026-11-06

- Criado `tools/sitl_heartbeat_monitor.py`, receptor **somente leitura** de mensagens HEARTBEAT com `pymavlink`, limitado a UDP loopback `127.0.0.1:14550` por padrão.
- O monitor registra ID de sistema/componente, classe do veículo, estado de armamento relatado e timeout por relógio monotônico; nunca autoriza controle ou envia comandos.
- Criado `tests/test_sitl_heartbeat_monitor.py` para classificação de barco, rover e estação de controle, e separação entre telemetria e autorização.
- Uso previsto: `python tools/sitl_heartbeat_monitor.py --port 14550` após instalar `pymavlink` e iniciar SITL com saída UDP para loopback.
- **Estado:** código publicado, não executado contra SITL. Não há integração do receptor ao Lazarus, autenticação de origem, testes de rede ou controle de veículos. Compilação e homologação continuam pendentes.


### Estado interno de telemetria SITL em Pascal — 2026-11-06

- Criado `src/sitl_telemetry_state.pas`: interpreta eventos JSON de heartbeat/timeout produzidos pelo monitor Python, mantém classe, IDs, modo, armamento relatado e estado de conexão.
- Inclui expiração local com relógio monotônico fornecido pelo chamador e rejeição de JSON inválido/IDs fora da faixa.
- **Estado:** módulo de dados publicado, sem integração ainda ao formulário Lazarus ou leitura do stdout do processo Python. Não controla veículos e não autoriza armamento. Compilação e testes pendentes.


### Ponte de processo Python para telemetria SITL — 2026-11-06

- Criado `src/sitl_telemetry_bridge.pas`, que inicia o monitor Python com `TProcess`, lê stdout em blocos limitados, processa JSON por linha via `sitl_telemetry_state.pas`, expira heartbeat e encerra o subprocesso.
- Integração **somente leitura**, sem canal de comando ou conexão com hardware.
- **Pendente:** conectar o bridge ao formulário Lazarus e timer de interface, compilar, tratar stderr e saída inesperada, testar encerramento e reconexão, verificar compatibilidade entre plataformas. Não há validação em execução.


### Painel de telemetria SITL na interface principal — 2026-11-06

- Integrado `src/sitl_telemetry_bridge.pas` ao `src/main.pas` com painel inferior, botão de ativação/desativação explícita e timer de 250 ms para leitura de eventos.
- O painel apresenta conexão, classe de veículo, sistema/componente, modo numérico e estado de armamento **relatado**. O monitor não controla nem autoriza o veículo.
- Criado `tests/test_sitl_ui_wiring.py` com verificações estáticas de inicialização opt-in, encerramento, leitura e restrição a telemetria.
- **Estado:** código publicado na `master`, sem compilação Lazarus, teste do subprocesso ou execução ArduPilot SITL comprovados. Não marcar integração validada nem liberar controle físico.
- **Próximos itens:** verificar compatibilidade FPC/Lazarus, tratar stderr e encerramento do subprocesso sem travar UI, testar fluxo real e compatibilidade Windows/Linux, validar tradução e posicionamento do painel nos oito idiomas.


### Teste Pascal de telemetria na CI Linux — 2026-11-06

- Adicionado `tests/test_sitl_telemetry_state.pas`, com verificações de JSON inválido, heartbeat, identificadores, estado de armamento relatado, timeout e recuperação de conexão.
- Atualizado `.github/workflows/lazarus-build.yml` para compilar e executar esse teste com FPC no job Linux e armazenar os logs de compilação e execução em `build-diagnostics/`.
- **Estado:** alterações publicadas na `master`; ainda não há resultado de execução do workflow nem compilação Lazarus confirmada. A integração SITL e a segurança de voo não estão homologadas.


### Diagnóstico automático e erros do monitor — 2026-11-06

- Workflow `.github/workflows/lazarus-build.yml` agora também é acionado por `push` na `master` quando arquivos Pascal/Lazarus ou o próprio workflow mudarem; anteriormente só era manual/PR.
- Ponte SITL passa a apresentar mensagens de stderr do Python (limitadas a 240 caracteres) no diagnóstico, incluindo possíveis falhas de dependência `pymavlink`.
- **Pendente:** consultar resultado do GitHub Actions, corrigir erros de compilação identificados, testar subprocesso Windows/Linux e SITL real; nenhum teste físico homologado.


### Teste de ciclo de vida da ponte SITL — 2026-11-06

- Criado `tests/test_sitl_telemetry_bridge.pas`: verifica estado inicial desligado, rejeição de script inexistente, mensagem de erro, estado desconectado e chamadas repetidas de `Stop`.
- Adicionado ao diagnóstico `.github/workflows/lazarus-build.yml` para compilação e execução com FPC; logs de teste preservados em `build-diagnostics/`.
- **Pendente:** obter resultados de execução da CI, corrigir eventuais erros FPC/Lazarus, testar processo Python real com `pymavlink` e SITL, validar segurança e dispositivos reais.


### Preservação de erros de saída do monitor SITL — 2026-11-06

- Ajustada `TSitlTelemetryBridge.Poll` para consumir a saída disponível do subprocesso antes de avaliar seu encerramento, preservando mensagens de falha do Python.
- Incluído teste estático de regressão em `tests/test_sitl_ui_wiring.py` verificando a ordem da leitura e a captura de stderr.
- **Não validado em execução:** resultados de CI, compilação Lazarus, Python/pymavlink real, SITL e veículos físicos.


### Tipagem de eventos de telemetria SITL — 2026-11-06

- `src/sitl_telemetry_state.pas`: eventos heartbeat com `system_id`/`component_id` não numéricos ou `vehicle_class` não textual são rejeitados sem atualizar o estado nem o relógio de heartbeat.
- `tests/test_sitl_telemetry_state.pas`: acrescentadas verificações para tipos incorretos e preservação de `LastHeartbeatMs`.
- **Pendente:** conferir compilação/execução real na CI; ampliar validação de campos opcionais e intervalos, testar ArduPilot SITL e homologar hardware.


### Validação dos campos opcionais do heartbeat SITL — 2026-11-06

- `custom_mode`, quando presente, deve ser numérico; `armed_reported`, quando presente, deve ser booleano. Tipos incompatíveis rejeitam o evento sem alterar o heartbeat.
- Testes Pascal acrescentados para valores textuais indevidos nos dois campos e preservação de `LastHeartbeatMs`.
- **Estado:** publicado na `master`, sem confirmação de compilação/execução da CI ou homologação com SITL e hardware.


### Filtro de heartbeats MAVLink não veiculares — 2026-11-06

- `tools/sitl_heartbeat_monitor.py`: descarta mensagens HEARTBEAT de GCS e tipos MAV_TYPE sem classificação veicular suportada, impedindo que substituam o estado exibido de veículo.
- `tests/test_sitl_heartbeat_mapper.py`: testa rejeição de GCS/tipos não suportados, classes multirotor/helicóptero/barco/submersível e separação entre armamento relatado e autorização de controle.
- **Limitação:** ainda não há fixação de `system_id`/`component_id` por sessão; múltiplos veículos suportados na mesma porta podem alternar a telemetria exibida. Corrigir antes de uso operacional. Testes e CI ainda sem resultado de execução confirmado.


### Fixação de origem MAVLink na sessão SITL — 2026-11-06

- Monitor Python fixa a origem de heartbeat suportada pelo par `system_id`/`component_id`; heartbeats de outras origens não renovam o timeout nem substituem a telemetria da sessão.
- A origem é liberada após timeout, permitindo nova seleção automática. Incluído teste estático de regressão no mapper.
- **Pendente:** testes dinâmicos de múltiplas origens, seleção explícita de veículo, resultados de CI, compilação Lazarus, validação SITL e hardware. A fixação não autoriza comandos físicos.


### Testes dinâmicos de múltiplas origens SITL — 2026-11-06

- Extraída a classe Python `HeartbeatSourceLock`, sem dependência de `pymavlink`, para testar seleção de origem MAVLink de forma isolada.
- `tests/test_sitl_heartbeat_mapper.py` agora verifica dinamicamente bloqueio de segunda origem, renovação de heartbeat pela origem selecionada e transferência de origem após timeout.
- **Estado:** código e testes publicados; ainda sem evidência de execução da CI, integração ArduPilot SITL ou validação física.


### Validação de origem e expiração antes da leitura — 2026-11-06

- `tools/sitl_heartbeat_monitor.py`: rejeita heartbeats com `system_id`/`component_id` fora de 1..255 e expira a origem anterior antes de aceitar novos heartbeats.
- `tests/test_sitl_heartbeat_mapper.py`: testes para IDs inválidos e transição após timeout.
- **Pendente:** execução confirmada da CI e testes integrados com ArduPilot SITL e hardware. O monitor permanece estritamente de leitura.


### CI dos testes Python SITL — 2026-11-06

- `.github/workflows/lazarus-build.yml`: adicionado `python3 -m unittest discover -s tests -p 'test_sitl_*.py' -v` com `pipefail` e log `build-diagnostics/sitl-python-tests.log`.
- Os gatilhos de `push` e `pull_request` incluem alterações no monitor Python e testes `test_sitl_*.py`, além dos arquivos Pascal/Lazarus.
- **Estado:** alterações publicadas; sem confirmação de execução do workflow. Falhas de build ou testes devem ser verificadas nos logs antes de homologação.


### Evitar estado residual em heartbeats SITL — 2026-11-06

- `src/sitl_telemetry_state.pas`: novo heartbeat é construído a partir de estado limpo; `armed_reported` e `custom_mode` ausentes não herdam valores da mensagem anterior.
- `tests/test_sitl_telemetry_state.pas`: regressão para verificar desarmado relatado e modo padrão quando os campos opcionais estão ausentes.
- **Pendente:** confirmar compilação e execução na CI; testar com ArduPilot SITL real e dispositivos físicos antes de homologar.
