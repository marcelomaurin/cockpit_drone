# Cockpit Drone 0.46 — comandos de pilotagem

## Conectar ao simulador Cheerson

1. Abra o Simulador Cockpit Drone, selecione Cheerson CX-10W e inicie a simulação.
2. No Cockpit, abra Configuração → Tipo de equipamento. Escolha Cheerson / CX-10W e marque **Modo simulador**. O aplicativo usa 127.0.0.1, TCP 8888 e UDP 8895; não procura rede Wi-Fi de drone. Os endereços reais permanecem salvos.
3. Em Joystick, escolha Controle 1 e ative o joystick. Em Controle de voo, escolha **Automático** ou **Modo 2** e clique em **Salvar e testar perfil**, com Start desligado.
4. No teste, confira os quatro comandos. Feche a configuração, baixe o manche esquerdo até o fim e ligue Start. Aguarde a conexão e mantenha a aceleração baixa brevemente para liberar a trava.
5. Suba o manche esquerdo gradualmente acima do centro. O Cheerson deve decolar no simulador. Para descer, reduza gradualmente a aceleração; ao tocar o chão, leve-a ao mínimo. Desligue Start para terminar a conexão.

## Xbox 360 — perfil Modo 2

| Comando | Controle |
| --- | --- |
| Aceleração / subida e descida | Manche esquerdo, vertical |
| Girar para esquerda/direita (guinada) | Manche esquerdo, horizontal |
| Avançar / recuar (arfagem) | Manche direito, vertical |
| Deslocar para esquerda/direita (rolagem) | Manche direito, horizontal |
| Decolar / armar, quando o protocolo permite | A |
| Pousar / desarmar, quando o protocolo permite | B |

O Xbox tem molas: ao soltar o manche esquerdo ele volta ao centro. Um radiocontrole tradicional de aceleração pode não ter essa mola. Por isso, no Cheerson, soltar o manche não corta a aceleração. Use mínimo para parar e o botão de corte da conexão para interromper os motores. A tela de teste informa o percentual real de aceleração.

## Comportamento por equipamento

| Modelo/adaptador | Comando vertical e procedimento |
| --- | --- |
| Cheerson CX-10W | Aceleração direta 0–100%; mínimo libera a trava. Não há decolagem/pouso automático por A/B. Centro é aproximadamente 50% de empuxo, sem controle automático de altitude. |
| FQ777-954 | Aceleração direta; mínimo e rearme na janela de conexão. B corta motores; o modo real mantém a confirmação de rearme existente. Com joystick geral ativado, usa o perfil desta marca/modelo; a entrada antiga da aba FQ777 permanece disponível quando o joystick geral está desligado. |
| DJI/Ryze Tello | A decola e B pousa; manche vertical comanda velocidade de subida/descida e centro solicita pairar, conforme o SDK Tello. |
| Parrot AR.Drone 2.0 | A decola e B pousa; comando vertical é velocidade de subida/descida e centro solicita pairar. |
| Drone ESP32 (CDP) | A arma com acelerador baixo; B desarma; aceleração direta. O firmware continua validando o armamento. |
| ESP-Drone / OpenDrone | Aceleração direta pelo protocolo CRTP; mantém o procedimento de liberação/corte do adaptador. |
| MAVLink (ArduPilot/PX4) | Canais de rolagem, arfagem, guinada e aceleração do adaptador MAVLink; armamento, decolagem e modos continuam nas funções do autopiloto/rota. A/B não ganham ações de armamento não implementadas. |

O catálogo não transforma modelos sem adaptador em equipamentos suportados. O padrão foi aproximado pelos controles Modo 2 e pelas funções efetivamente existentes nas dependências; não é uma homologação de cada controle original ou de voo físico.

## Personalizar e testar

Escolha a marca/modelo antes de ajustar. Em **Controle de voo**, selecione **Personalizado** para escolher os quatro eixos, inverter sentidos, configurar a zona morta e os botões. A configuração é salva por marca/modelo em drone_model.ini, na pasta de configurações do usuário. Ao trocar de modelo, seus ajustes ficam separados.

Xbox/XInput: eixo 0 = esquerdo X, 1 = esquerdo Y, 2 = direito X, 3 = direito Y, 4 = LT e 5 = RT. Para acelerador no RT, escolha o perfil **Xbox — acelerador no RT**: gatilho solto é zero e apertado aumenta a aceleração. Os gatilhos permanecem independentes. O perfil **Legado** mantém a interpretação antiga X/Y/Z e seis botões para compatibilidade. Joysticks genéricos permanecem no perfil legado quando Automático está selecionado.

No perfil Modo 2 os botões alternativos de giro e centralização ficam desativados; podem ser associados em Personalizado. Os números de botões são A=1, B=2, X=3, Y=4, LB=5, RB=6; zero desativa a função. Teste sentidos e mínimo antes de ligar Start. Alterações de perfil são aplicadas com Start desligado.

## Diagnóstico corrigido

O eixo Z genérico do Xbox combina os gatilhos. Na leitura observada, gatilhos soltos produziam 32767, convertido em 127/255 de aceleração. Isso não satisfaz o mínimo exigido pela trava do Cheerson. A versão 0.46 usa XInput para os controles Xbox, com perfil Modo 2 ou gatilhos independentes, e conserva a leitura genérica para os demais joysticks. Uma leitura inválida ou desconexão zera os comandos; não há troca automática para outro controle no meio da leitura.

Documentação consultada: Microsoft XInput/DirectInput (https://learn.microsoft.com/en-us/windows/win32/xinput/xinput-and-directinput), manual Tello (https://dl-cdn.ryzerobotics.com/downloads/Tello/20180404/Tello_User_Manual_V1.2_EN.pdf) e componentes locais de cada adaptador da Lazarus AI Suite.

Se o controle perder a conexão ou produzir uma leitura inválida, a aceleração é zerada e a leitura fica desativada. Reconecte o controle, desligue Start, baixe a aceleração ao mínimo e ligue Start novamente. A posição real é lida antes do primeiro comando; uma centralização interna do programa não libera a trava de aceleração.


## Nova tentativa após queda no simulador

Aguarde cerca de 1,5 segundo para a recuperação automática. No Cheerson/FQ777, baixe o acelerador ao mínimo e volte a subir gradualmente; no perfil RT, solte o gatilho antes. A conexão continua aberta. Em outros modelos, repita o armamento/decolagem próprio do equipamento. Reiniciar também libera queda/pausa e volta à origem. Veja [cenário 3D e recuperação](../simulador/docs/SIMULADOR_0.46.md).


## Treinar sem limite de rádio

No simulador, marque **Simulação → Sinal infinito (treinamento)**. Vale para todos os modelos e fica salvo. Ao desmarcar, o Cheerson/FQ777 mantém 30 metros de alcance normal, incluindo a altura. O cockpit continua usando Modo simulador em Configuração. Para construções nos terrenos e a câmera, consulte o guia do simulador.

## Novos equipamentos

Consulte [protocolos e veículos 0.46](PROTOCOLOS_0.46.md) para os cinco formatos RC, 30 perfis e controles de avião, helicóptero, carro, barco e submarino. O [WIFI_8K experimental](WIFI_8K_EXPERIMENTAL.md) tem dois candidatos selecionáveis no cockpit e simulador.
