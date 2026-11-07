# Joystick: comandos e configuração

Em **Configurações > Comandos do Joystick** cada eixo e botão do joystick recebe uma função. O mapa é gravado na seção `[JOYSTICK_MAPA]` do `drone.cfg` e passa a valer no cockpit ao fechar Configurações. Sem essa seção (arquivos antigos), vale o mapa anterior: eixos X/Y/Z e botões 1 a 6.

O joystick é lido pelo Windows (winmm): até 6 eixos (X, Y, Z, R, U, V) e 16 botões.

## Perfis prontos

| Perfil | Rolagem | Arfagem | Guinada | Acelerador | Pânico |
|---|---|---|---|---|---|
| Manche simples (padrão) | X | Y | botões 1/2 | Z | — |
| Manche com torção ou pedal | X | Y | R (torção/pedal) | Z invertido (alavanca à frente = mais) | botão 2 |
| Videogame, Modo 2 | U (direito, horizontal) | R (direito, vertical) | X (esquerdo, horizontal) | Y invertido (esquerdo para cima = mais) | botão 7 (Back) |
| Videogame, Modo 1 | U (direito, horizontal) | Y (esquerdo, vertical) | X (esquerdo, horizontal) | R invertido (direito para cima = mais) | botão 7 (Back) |

Botões nos perfis de videogame: A decolar/armar, B pousar/desarmar, X pairar, Y manobra, LB/RB girar.

No controle de videogame o analógico do acelerador volta ao centro quando solto, que corresponde ao pairar (subida zero) nos drones com altitude automática (Tello, AR.Drone) e a 50% de aceleração nos demais.

## Ajuste manual

- **Eixo**: qual eixo físico comanda a função. "Nenhum" deixa a função no centro (o acelerador fica em zero e passa a ser controlado só pelo teclado, E/Q).
- **Inverter**: espelha o eixo quando o sentido está trocado.
- **Capturar**: clique, deixe os comandos soltos e leve o comando até o fim no sentido indicado (direita, frente, girar à direita, máximo). O eixo e a inversão são escolhidos sozinhos. Para botões, clique e aperte o botão. A captura desiste após 6 segundos.
- **Ao vivo**: mostra o valor de cada função com o mapa da tela, antes de salvar, e a leitura bruta de todos os eixos e botões.

Um mesmo eixo ou botão em duas funções é conflito: a tela avisa em vermelho e o mapa não é salvo (o anterior continua valendo).

## Pânico

A barra de espaço ou o botão de pânico do joystick zera o acelerador, centraliza os eixos e ignora os botões. A trava só solta depois de soltar o pânico **e** levar o acelerador do joystick ao mínimo, para o drone não voltar a acelerar sozinho.

O FQ777-954 tem leitura própria de joystick e eixos configurados na sua aba; o mapa desta página vale para os demais drones.
