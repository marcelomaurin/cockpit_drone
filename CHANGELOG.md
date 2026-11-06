# Histórico de alterações

## Correções locais ainda sem release — 2026-11-06

- Corrigida opção inválida de redirecionamento de stderr da ponte SITL no FPC.
- Ajustados dois testes de descarte de heartbeats não veiculares ao contrato atual.
- Retiradas dependências e componentes legados sem referências funcionais.
- Corrigida saturação de eixos e rejeição de valores inválidos em MAPA.
- Rejeitados números não finitos em leitura e validação de rotas.
- Corrigida localização do monitor SITL e adicionada escolha de Python por COCKPIT_PYTHON.
- Acrescentados testes Pascal de entrada/rotas/caminhos e integração UDP Python/Pascal, executor local e workflow.

Validação: cinco pacotes do framework e aplicativo Windows x86_64 compilados; seis suítes Pascal, teste de joystick do framework e 39 testes Python aprovados. ArduPilot SITL, interface visual, Linux e hardware não validados. [Relatório completo](docs/VALIDACAO_LOCAL_2026-11-06.md).

Instaladores, versão e release ficaram com a outra sessão; nenhuma nova compilação foi iniciada após a ordem do usuário de parar.
