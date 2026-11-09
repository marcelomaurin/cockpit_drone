# Em desenvolvimento — 2026-11-09 (código-fonte; executáveis 0.46 ainda não recompilados)

- Proporções do cenário: casas simuladas térreas (~3 m) ou sobrados (~6 m) com telhado de quatro águas; prédios simulados raros e só fora do modo de mapa em cache; construções do mapa sem altura passam a ser casa térrea, comércio de 6 m ou galpão de 8 m conforme a área, em vez de prédios de 15 m.
- Lotes de 13 × 20 m encostados ao longo das ruas, com muro, portão, garagem e quintal.
- Treinamento de inspeção do *Aedes aegypti*: vasos com/sem prato, piscina verde/tratada, caixa d'água destampada/tampada, pneus, tanque de peixes abandonado/com peixes e baldes destampados/emborcados, com sorteio fixo por lugar; opção "Quintais com criadouros (Aedes)", contagem no painel e gabarito CSV para o instrutor.
- Opção "Câmera de inspeção (60 graus para baixo)" no simulador, aplicada também à imagem enviada ao cockpit.
- Novo teste `tests/test_criadouros.pas` incluído em `tools/test_simulator.ps1`. Guia: [quintais e criadouros](simulador/docs/QUINTAIS_AEDES.md).

# Versão 0.46 — 2026-11-08

- Câmera com construções do OSM e casas/prédios de treinamento nos terrenos; fallback de blocos OSM-Carto reais em cache e rejeição de arquivos de projeto usados por engano como dados OSM.
- Sinal infinito opcional para 14 modelos, mantendo 30 m no Cheerson quando desligado; recuperação e rearme após queda.
- Dois candidatos WIFI_8K (Legacy9 e E58_8) no cockpit e simulador; busca/associação Wi-Fi, IP/gateway da interface escolhida e vídeo por URL opcional.
- MSPv1/MSPv2, CRSF, SBUS e iBUS: saída serial e simulação dos mesmos quadros;30 perfis por protocolo/categoria e física de solo, superfície, submerso e asa fixa.
- Xbox 360 por XInput, Modo 2/RT e personalização por modelo; modo simulador separado da conexão real.
- Instalador Windows x64 com FFmpeg, OpenSSL3 e Python/pymavlink privados. Novos protocolos reais permanecem experimentais, sem validação física deste drone ou receptores seriais.
- Documentação (09/11/2026): [guia ilustrado das telas](docs/TELAS_0.46.md) com 17 capturas reais do `drone.exe` e do `simulador.exe` 0.46 (hashes conferidos com o manifesto), e imagens nos README, no manual SUS, nos controles e no guia do simulador.

## 0.45 — 2026-11-08

- WIFI_8K experimental, conforme issue #3: perfil próprio, descoberta por prefixo, associação confirmada, restauração solicitada da rede anterior e estados separados. Vídeo/controle/telemetria aguardam validação; não são enviados pacotes candidatos.

- Opção persistida Sinal infinito no simulador, para todos os modelos; alcances normais preservados, inclusive 30 m do Cheerson/FQ777.
- Geração de casas e prédios em terrenos residenciais OSM, reservando vias/calçadas e excluindo áreas livres e imóveis cadastrados. Ruas vetoriais alinhadas ao cenário.
- Câmera dedicada para o cockpit em 640x360, independente da vista do simulador, e leitura restrita ao modo simulado. Exportação de bitmap validada.

- Recuperação automática de queda em 1,5 s, sem reabrir sockets; Reiniciar libera pausa e estado de voo dos protocolos.
- Cheerson/FQ777 exige novo mínimo de acelerador após recuperação; testada nova decolagem pela cadeia Xbox.
- Construções 3D por contornos OSM, com alturas/andares, pátios, oclusão, cache, servidor configurável e arquivo JSON local. Consulta externa não confirmada nesta rede; testes com resposta HTTP local aprovados.

- Corrigida leitura do Xbox 360: XInput, eixos/gatilhos independentes e neutralização após perda de leitura.
- Perfis Modo 2, RT, personalizado e legado; eixos, sentidos, zona morta e botões salvos por marca/modelo.
- Modo simulador em Tipo de equipamento, com endereços e portas locais e sem busca de Wi-Fi real; endereços reais preservados.
- Instalador x64 completo com simulador, FFmpeg, OpenSSL 3.5.9 e Python privado com dependências SITL.
- Regressões da cadeia Xbox → pacote Cheerson → física, persistência de perfis, vídeo e conexão HTTPS.

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
