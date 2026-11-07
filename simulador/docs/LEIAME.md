# Simulador Cockpit Drone

O simulador é um segundo executável do projeto, separado do cockpit. Ele se passa pelo equipamento real: o Cockpit Drone conecta nele como se fosse o drone, e você voa sobre imagem de satélite real (Google). Quando o Google não está disponível, o chão vira o mapa de ruas do OpenStreetMap. O simulador também pode entrar num **mundo compartilhado** (servidor PHP) e mostrar outros usuários a até 2 km.

| Documento | Conteúdo |
|---|---|
| [arquitetura.md](arquitetura.md) | Unidades, linhas de execução, travas e fluxo de dados |
| [modelos.md](modelos.md) | Protocolo emulado e comportamento de cada equipamento |
| [protocolo_mundo.md](protocolo_mundo.md) | Mensagens JSON do servidor de mundo compartilhado |
| [instalacao_servidor.md](instalacao_servidor.md) | Como instalar o servidor PHP (MySQL ou SQLite) |
| [testes.md](testes.md) | Testes automáticos dos emuladores e do servidor |

## Pastas

```
simulador/
├─ src/                 fontes Lazarus (simulador.lpi)
│  ├─ nucleo/           tipos, geografia, física, simulação, HTTP
│  ├─ protocolos/       UDP/TCP e um emulador por protocolo
│  ├─ mapa/             blocos Google / OpenStreetMap e cache
│  ├─ mundo/            cliente do servidor compartilhado
│  ├─ visao/            câmera, terceira pessoa e mapa de cima
│  └─ forms/            janela principal (montada em código)
├─ config/equipamentos.json   parâmetros de cada modelo
├─ servidor_mundo/      servidor PHP do mundo compartilhado
├─ testes/              programas de console e scripts que fazem o papel do cockpit
└─ docs/                esta documentação
```

## Compilar

Requisitos: Lazarus 3.x com Free Pascal 3.2.2. Não usa pacotes externos (só a LCL).

1. Abra `simulador/src/simulador.lpi` no Lazarus e compile, ou rode `lazbuild simulador/src/simulador.lpi`.
2. O executável sai em `simulador/simulador.exe` (no Linux, `simulador/simulador`), ao lado de `config/`.

Para os mapas e o mundo compartilhado por HTTPS, o Windows precisa das DLLs do OpenSSL 1.1 ao lado do executável: `libssl-1_1-x64.dll` e `libcrypto-1_1-x64.dll` (as mesmas usadas pela suíte CHATGPT). Sem elas, o simulador funciona, mas sem mapa e sem servidor HTTPS (um servidor de mundo em `http://` continua funcionando).

## Usar com o cockpit

1. Abra o `simulador.exe`, escolha o **modelo** e o **ponto de partida**. Na vista *Mapa de cima*, um clique escolhe a partida.
2. Clique em **Ligar equipamento**. O painel mostra as portas abertas.
3. No cockpit, em Configuração, escolha o mesmo protocolo e troque o IP do drone pelo IP da máquina do simulador. Na mesma máquina, use `127.0.0.1`.
4. Conecte no cockpit e voe. O simulador mostra a câmera do drone, a terceira pessoa ou o mapa, e o painel com altura, velocidade, bateria e fase do voo.

| Modelo | No cockpit (Configuração) | Observação |
|---|---|---|
| DJI Tello | seção [TELLO]: IP `127.0.0.1` | O simulador responde na UDP 8889 e envia o estado para a 8890 |
| Parrot AR.Drone 2.0 | seção [ARDRONE]: IP `127.0.0.1` | Navdata enviado para a 5554 de quem conectar |
| MAVLink | seção [MAVLINK]: porta 14550 | O simulador envia de 14551 para `127.0.0.1:14550`, como o SITL |
| Cheerson CX-10W | seção [CX10W]: IP `127.0.0.1`, TCP 8888, UDP 8895 | — |
| FQ777-954 | seção [FQ777]: IP `127.0.0.1` e **desligue o Wi-Fi automático** | Sem isso o cockpit procura a rede do drone e não liga |
| Drone ESP32 | seção [ESP32DRONE]: IP `127.0.0.1`, porta 4210 | Mesmo protocolo CDP do firmware |
| ESP-Drone / OpenDrone | seção [ESPDRONE]: IP `127.0.0.1`, porta 2390 | — |

Se o simulador e o cockpit ficarem em máquinas diferentes, informe o IP da máquina do simulador no cockpit. Libere também as portas no Firewall do Windows. No MAVLink, informe no simulador o IP do cockpit.

Só um equipamento fica ligado por vez: as portas são as do equipamento real e não podem ser abertas duas vezes na mesma máquina.

## Mapas

| Fonte | Quando é usada | Imagem |
|---|---|---|
| Google Map Tiles API | Com chave de API (campo *Chave Google*) e o Google respondendo | Satélite |
| OpenStreetMap | Sem chave, chave recusada, cota esgotada ou 5 falhas seguidas nos blocos do Google | Mapa de ruas |

No modo **Automático**, o simulador troca sozinho para o OpenStreetMap e avisa no registro. Depois ele tenta o Google de novo a cada 5 minutos. A fonte também pode ser fixada em *Google* ou *OpenStreetMap*.

Regras respeitadas, conforme as políticas das duas fontes:

- O simulador só busca os blocos que estão na tela. Não há download de áreas antes do voo nem modo sem internet.
- O cache em disco segue o `Cache-Control` e revalida com `ETag`. Sem prazo informado, o OpenStreetMap guarda 7 dias, e os blocos do Google não vão para o disco.
- O crédito fica sempre visível no canto inferior direito: "Google Maps" com os direitos da área, ou "© OpenStreetMap contributors".
- O OpenStreetMap recebe um `User-Agent` próprio e fixo. Se o uso crescer, aponte *Blocos OSM* para um servidor de blocos próprio.

A chave do Google é cobrada por bloco depois da cota gratuita. O painel *Mapa* mostra quantos blocos foram baixados e quantos vieram do cache.

## Mundo compartilhado (Multiplayer)

> **ATENÇÃO:**  
> A entrada no modo **Multiplayer** é feita diretamente no **Simulador**, através do painel lateral *Mundo compartilhado*, e **NÃO no Cockpit Drone**.  
> O Cockpit Drone conecta-se apenas ao simulador local (`127.0.0.1`) para comandos e telemetria.

- **Servidor oficial:** `https://maurinsoft.com.br/cockpit/`

1. No simulador, no grupo *Mundo compartilhado*, defina a URL do servidor como `https://maurinsoft.com.br/cockpit/`, digite seu **Apelido** e clique em **Entrar**.
2. Outros drones conectados a até 2 km aparecem em amarelo na câmera e no mapa, com o apelido e a distância.
3. **Enviar** manda uma mensagem para quem está a até 2 km. **Piscar luzes** manda um sinal. **Marcar este ponto** deixa um marcador no mapa dos vizinhos.

Se o servidor cair, o voo continua: os vizinhos somem e o simulador tenta de novo a cada 2 s.

## Falhas para testar o cockpit

| Falha | Efeito |
|---|---|
| Perda de sinal | O simulador para de receber e de responder, como fora do alcance |
| Perda de GPS | O MAVLink passa a informar GPS sem fixação (o ArduCopter emulado pousa) |
| Bateria fraca | A bateria vai para 12%, e cada modelo reage como o real |
| Vento | Vento constante de 0 a 15 m/s, vindo do rumo escolhido |
| Atraso de rede | Cada pacote recebido é processado 100 a 1000 ms depois |

**Reiniciar na partida** recria o drone no ponto de partida, por exemplo depois de uma queda (toque no chão acima de 2 m/s).

## Preferências

As preferências ficam em `simulador.ini`, na pasta do usuário: `%LOCALAPPDATA%\CockpitDroneSimulador\` no Windows e `~/.config/CockpitDroneSimulador/` no Linux. Elas incluem a chave do Google, a fonte do mapa, o servidor, o apelido, a última partida e o último modelo. O cache de mapas fica na mesma pasta. Nada disso vai para o repositório.

## Limitações desta versão

- Ainda não há vídeo para o cockpit: a câmera aparece só na janela do simulador. O Tello responde `ok` a `streamon`, mas não envia H.264.
- O chão é plano, sem relevo nem prédios, e não há colisão entre drones.
- Com proxy, o HTTPS não funciona: o cliente HTTP do Free Pascal 3.2.2 não abre túnel (CONNECT) por proxy.
- Os parâmetros de `equipamentos.json` são valores iniciais. Ajuste pela ficha técnica e voando o equipamento real lado a lado.
