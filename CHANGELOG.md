# Versão 0.46 — 2026-11-08

- Câmera com construções do OSM e casas/prédios de treinamento nos terrenos; fallback de blocos OSM-Carto reais em cache e rejeição de arquivos de projeto usados por engano como dados OSM.
- Sinal infinito opcional para 14 modelos, mantendo 30 m no Cheerson quando desligado; recuperação e rearme após queda.
- Dois candidatos WIFI_8K (Legacy9 e E58_8) no cockpit e simulador; busca/associação Wi-Fi, IP/gateway da interface escolhida e vídeo por URL opcional.
- MSPv1/MSPv2, CRSF, SBUS e iBUS: saída serial e simulação dos mesmos quadros;30 perfis por protocolo/categoria e física de solo, superfície, submerso e asa fixa.
- Xbox 360 por XInput, Modo 2/RT e personalização por modelo; modo simulador separado da conexão real.
- Instalador Windows x64 com FFmpeg, OpenSSL3 e Python/pymavlink privados. Novos protocolos reais permanecem experimentais, sem validação física deste drone ou receptores seriais.

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
