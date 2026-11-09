# Simulador 0.46 — treinamento e cenário urbano

> **Atualização de 09/11/2026 (código-fonte, requer recompilar o simulador):** casas térreas em proporção real, lotes com muro e quintal e o treinamento de inspeção de criadouros do *Aedes aegypti*, com gabarito para o instrutor. Veja [quintais e criadouros](QUINTAIS_AEDES.md). Os números de construções citados abaixo descrevem o executável 0.46.

![Simulador 0.46 com mapa OpenStreetMap](../../docs/img/simulador-mapa.png)

*Simulador 0.46 na vista Mapa de cima, no ponto padrão, com 172 construções (captura de tela real). Outras vistas no [guia ilustrado das telas](../../docs/TELAS_0.46.md).*

## Sinal infinito

No simulador, abra **Simulação** e marque **Sinal infinito (treinamento)**. A opção funciona com todos os 14 modelos, em qualquer distância e altura, e pode ser alterada durante o voo. A escolha é salva imediatamente em `simulador.ini`, seção `[treinamento]`, chave `sinal_infinito`.

Com a opção desligada, cada equipamento mantém seu alcance normal. O Cheerson CX-10W e o FQ777-954 continuam com **30 metros**, contados pela distância entre o ponto de partida e o drone, incluindo a altura. Com a opção ligada, o limite de alcance e a falha simulada Perda de sinal são ignorados. O painel mostra SINAL INFINITO e a opção de injetar perda de sinal fica indisponível.

Bateria, vento, GPS, comandos do modelo e recuperação de queda continuam funcionando. Sinal infinito remove a perda simulada de rádio; uma desconexão efetiva do controle/programa ainda pode acionar os tempos de proteção de cada protocolo, pois faltam comandos reais recebidos. Não é gerado acelerador artificial para substituir um controle desconectado.

## Casas e prédios nos terrenos

Em **Mapa**, escolha **OpenStreetMap (ruas)**. Mantenha **Construções 3D no OpenStreetMap** e **Simular casas nos terrenos** marcadas e clique **Aplicar mapa**.

O simulador combina duas fontes de cenário:

- Construções cadastradas no OSM: respeita seus contornos e usa altura/andares quando disponíveis.
- Construções de treinamento: preenche espaços livres nas áreas residenciais cadastradas, com casas e prédios de apartamentos, alinhados às vias próximas. São construções fictícias, não uma reprodução dos imóveis reais.

A geração reserva a largura da rua e mais três metros de recuo em cada lado para calçadas/afastamento. Quando há largura ou número de faixas no mapa, usa essas informações; caso contrário, estima a largura pelo tipo de via. Verifica o contorno inteiro da construção, inclusive cruzamentos e ruas diagonais, para evitar ocupar a faixa reservada. Pátios internos, parques, áreas verdes/água, estacionamentos e construções já cadastradas têm prioridade. A posição dos imóveis simulados usa coordenadas fixas para evitar que mudem de lugar ao carregar a região vizinha.

O painel informa quantas construções vieram do OSM e quantas foram simuladas. Desmarcar Simular casas nos terrenos e usar Aplicar mapa conserva apenas os edifícios cadastrados. Desligar Construções 3D remove todo o cenário de construções. A opção de terrenos usa áreas residenciais gerais; o OSM nem sempre contém os limites cadastrais de cada lote. Não é uma reconstrução de lotes oficiais.

Ruas e calçadas também são desenhadas a partir dos mesmos vetores usados para reservar espaço, mantendo o cenário alinhado. O chão usa os blocos do mapa quando disponíveis. Na ausência de vetores, a versão 0.46 também extrai construções e terrenos dos blocos do mapa OSM-Carto em cache: reconhece polígonos de edifícios e áreas de terreno/residenciais pela cor e contorno, preserva vazios internos e exige recuo de 3 m da imagem das ruas em toda a área ocupada. Só preenche quarteirões pequenos fechados ou áreas predominantemente residenciais. Isso depende da paleta padrão do mapa; estilos personalizados podem não oferecer dados suficientes. Alturas extraídas da imagem são estimadas, e as construções geradas continuam fictícias. Água, áreas verdes e ruas não são terrenos de geração.

## Ver as construções no Cockpit Drone

No cockpit, marque **Configuração → Tipo de equipamento → Modo simulador**, selecione o mesmo equipamento e ative a câmera. O simulador publica um quadro da **câmera do drone** em 640 × 360, até dez vezes por segundo, no arquivo temporário compartilhado `cockpit_sim_camera.bmp`.

A imagem para o cockpit é independente da vista escolhida no simulador: mudar para terceira pessoa ou mapa não transforma a câmera do cockpit em outro ângulo. O cockpit consulta esse quadro somente quando Modo simulador está selecionado.

As imagens camera-low.png e camera-high.png foram exportadas pelo próprio caminho de câmera usado no cockpit, com cenário sintético de teste. Demonstram construções nos terrenos, ruas e calçadas livres; não retratam uma cidade real. As janelas inteiras do cockpit e do simulador foram capturadas depois, em 09/11/2026, e estão no [guia ilustrado das telas](../../docs/TELAS_0.46.md). O novo arquivo camera-mapa-real.png foi exportado por GeraQuadroCamera com blocos OSM reais do local padrão: 172 construções, das quais 152 geradas nos terrenos. Essa saída também foi carregada pelo caminho de bitmap da câmera do cockpit.

## Internet, cache e exemplo local

A fonte padrão é https://overpass-api.de/api/interpreter. O campo Servidor de construções aceita outro serviço Overpass compatível por HTTPS; clique Aplicar mapa para trocar. A consulta inclui edifícios, áreas residenciais, vias e áreas que devem permanecer livres. Os dados são lidos em segundo plano e guardados por sete dias, com limite de tamanho e espera progressiva após falhas. A instância local limita a 80 tentativas e aproximadamente 8 MiB de respostas por dia. Na distribuição ampla, use um provedor adequado ao total de usuários.

Os servidores públicos testados anteriormente falharam nesta rede por TLS/resolução de nome. O recebimento online de dados reais permanece sem confirmação. Foram validados consulta HTTP local, reaproveitamento do cache, importação de arquivo JSON e fallback usando blocos reais de mapa já em cache. A importação agora rejeita JSON de projeto/rota sem a coleção OSM elements; na inicialização uma fonte local inválida é ignorada, com registro do motivo, para permitir o cenário do mapa. O arquivo inválido original não é modificado.

Para demonstrar sem internet, escolha **Arquivo OSM...**, abra `exemplo_construcoes_sinteticas.json` nesta pasta, use latitude **-21.1767** e longitude **-47.8208**, escolha OpenStreetMap e aplique o mapa. O exemplo contém uma área residencial, ruas, uma praça e um pátio; foram geradas 88 casas e 23 prédios nos espaços permitidos. O mapa real do local pode não combinar com o exemplo, pois os vetores deste arquivo são fictícios. **Usar internet** restaura a fonte configurada.

Para uma região real, importe uma exportação JSON do Overpass com geometria (`out geom`) que inclua edifícios, `landuse=residential`, `highway` e áreas de exclusão (`landuse`, `leisure`, `natural`, `area:highway` e estacionamentos). Um arquivo contendo somente edifícios não permite inferir com segurança os terrenos e as ruas; nesse caso são mostrados apenas os imóveis cadastrados.

## Voltar a voar depois de cair

Aguarde cerca de 1,5 segundo. O simulador recoloca o drone em pé no local da queda, com motores parados e bateria restaurada, mantendo a conexão. No Cheerson/FQ777, baixe o acelerador totalmente antes de acelerar outra vez. No perfil RT, solte o gatilho. Nos demais modelos, repita seu procedimento de armamento/decolagem. Reiniciar também libera a pausa e volta à origem. Falhas selecionadas, como vento ou perda de GPS, continuam ativas.

## Validação

Passaram: alcance normal e infinito nos 14 modelos, Cheerson com 30 m, altitude, alternância em voo, recepção e resposta UDP além do alcance; retomada após queda; pipeline Xbox/Cheerson; geometria de edifícios; geração de casas/prédios sem ocupar ruas, calçadas, cruzamentos, pátio ou praça; preservação de imóveis cadastrados; posições estáveis entre regiões; carregamento HTTP/cache/JSON local; exportação real da câmera e leitura pelo formato de bitmap usado no cockpit. As duas prévias foram inspecionadas.

Nenhuma biblioteca adicional foi introduzida. Permanecem FFmpeg, OpenSSL 3 e Python privado com as dependências da 0.46. Esta atualização não adiciona colisão física com as construções.

Referências: [áreas residenciais OSM](https://wiki.openstreetmap.org/wiki/Tag:landuse=residential), [largura das vias](https://wiki.openstreetmap.org/wiki/Key:width), [Simple 3D Buildings](https://wiki.openstreetmap.org/wiki/Simple_3D_buildings), [Overpass API](https://wiki.openstreetmap.org/wiki/Overpass_API). Dados OSM: © OpenStreetMap contributors, ODbL. As construções procedurais são fictícias.

## Novas categorias

O simulador inclui WIFI_8K e seis categorias RC, além dos sete modelos anteriores. Os detalhes de formatos, canais e física de cada categoria estão em [protocolos 0.46](../../docs/PROTOCOLOS_0.46.md). Para carros/barcos use acelerador centrado para neutro/ré; para submarinos use-o para subir/descer; para avião use mínimo ao armar e acelere na pista.
