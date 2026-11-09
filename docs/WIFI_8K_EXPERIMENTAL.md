# WIFI_8K — controle experimental na 0.46

Implementados no cockpit e no simulador dois formatos candidatos. O SSID observado pelo usuário é `WIFI_8K_a83a9a`; esse nome, sozinho, não identifica o fabricante, os comandos, o vídeo ou o IP. Não há confirmação de que esse aparelho aceite qualquer uma das variantes. Não se troca de variante automaticamente.

| Variante | Controle | Inicialização | Quadro |
| --- | --- | --- | --- |
| Legacy9 | UDP 7099, 25 Hz por padrão | `01 01` e repetição a cada segundo; `08 01` ao encerrar | `03 66 R P T Y Flags XOR 99`; XOR de R/P/T/Y/Flags |
| E58_8 | UDP 8090, 25 Hz por padrão | `42 76` na porta auxiliar 8080 antes de enviar controles | `66 R P T Y Flags XOR 99`; XOR apenas de R/P/T/Y |

Eixos neutros = 128. Flags de decolagem = 01, pouso = 02 e corte = 04. Portas, taxa e variante podem ser ajustadas na configuração. A variante E58_8 é uma implementação separada, não apenas a remoção do primeiro byte da Legacy9.

## Treinar sem o drone físico

1. Abra o simulador e escolha **WIFI_8K experimental**. Inicie a simulação.
2. No cockpit, escolha **Experimental / WIFI_8K** e marque **Modo simulador**.
3. Na aba WIFI_8K, escolha Legacy9 ou E58_8 e salve. A permissão de comandos reais não é necessária no simulador.
4. Ative seu Xbox 360 com perfil Modo 2. Centralize a subida e use **A** ou o botão de decolagem. Manche esquerdo vertical sobe/desce, esquerdo horizontal gira, direito vertical avança/recua e direito horizontal desloca lateralmente. **B** pousa; **Espaço** ou CORTAR interrompe motores.
5. Depois de cortar ou cair, centralize o manche e faça novo pedido de decolagem. O corte permanece travado até esse novo pedido.

O simulador usa somente 127.0.0.1, os mesmos bytes de controle e confirmação local de protocolo. Não procura redes nem muda o Wi-Fi. Não inventa telemetria GPS para WIFI_8K.

## Conectar o equipamento real

1. Desmarque Modo simulador, com Start desligado. Na aba WIFI_8K, selecione a interface Wi-Fi física, procure redes e selecione **a rede exata** do seu equipamento. O filtro aceita o prefixo literal Wifi_8k_ sem distinguir maiúsculas/minúsculas.
2. Use Conectar Wi-Fi; informe senha apenas se a rede a exigir. A senha não é gravada neste perfil. A conexão é confirmada consultando o SSID efetivamente associado.
3. Use Ler IP/gateway. O programa lê os dados fornecidos pelo Windows para a interface selecionada; não assume que 192.168.0.1 ou qualquer outro IP seja o drone. O gateway preenche o destino somente quando não foi informado outro. Se houver duas interfaces Wi-Fi, é preciso escolher uma.
4. Confirme variante, IP, porta de controle, porta auxiliar e taxa. Para habilitar o candidato no equipamento, marque **Permitir comandos reais experimentais**. Essa opção inicia desmarcada.
5. Inicie a conexão. A associação Wi-Fi e a contagem de datagramas enviados não comprovam que os motores ou o vídeo tenham respondido. A conexão suspende o envio ao perder o SSID escolhido. A tela permite restaurar a rede Wi-Fi anterior.

A falta de entrada atualizada por mais de 500 ms solicita pouso/desarmamento. O corte impede o rearme sem novo A com o controle na posição neutra apropriada. A perda real da rede impede que o computador garanta a entrega de um comando de pouso; continua valendo o comportamento do firmware embarcado.

## Vídeo

A configuração aceita uma **URL opcional de fluxo HTTP(S), RTSP ou UDP identificado**. O FFmpeg incluído converte o fluxo para a câmera do cockpit. O teste local usou MJPEG por HTTP e conferiu quadros 640×360. Não é implementada nem declarada validada a reconstrução de vídeo UDP proprietário WIFI_8K com fragmentação desconhecida. A porta auxiliar E58 8080 é usada pela inicialização do controle, não prova a existência de vídeo nessa porta. A câmera sintética funciona em Modo simulador independentemente do vídeo do aparelho.

## O que foi confirmado

Passaram codificação/decodificação, limites/checksums, associação simulada com confirmação de SSID, perda/restauração de conexão e persistência. Também passou cockpit real → datagramas candidatos → emulador → física, com decolagem e corte em ambas as variantes.

No computador do usuário, as buscas nativas atualizadas localizaram redes próximas, mas **não localizaram WIFI_8K_a83a9a**. A tentativa de associação direta também foi recusada pelo Windows como rede indisponível. Não houve captura da comunicação desse drone nem envio de comando de voo físico. A identificação final continua pendente de comunicação observável, aplicativo/manual ou captura.

## Fontes do formato

- [Especificação solicitada, issue #3](https://github.com/marcelomaurin/cockpit_drone/issues/3).
- [CommandAGI — DroneProtocol.kt](https://github.com/CommandAGI/commandagi-example-android-human-and-drone-control/blob/main/app/src/main/java/com/commandagi/humanrobot/drone/DroneProtocol.kt).
- [RC-Swamp — observações da comunicação Legacy9](https://github.com/CraxCurl/RC-Swamp/blob/main/working.md).
- [Maritaca E88 — protocolo E58_8 e inicialização](https://github.com/popolony2k/maritaca-e88-controller/blob/main/README.md).

Implementação própria a partir dos campos documentados; não foi copiado código dessas implementações.
