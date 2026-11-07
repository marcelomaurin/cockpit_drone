# Integracao multiplayer — Arquitetura e Uso

> **REGRA DE ARQUITETURA:**  
> A entrada e gerenciamento do **Multiplayer (Mundo Compartilhado)** são feitos exclusivamente através do **Simulador Cockpit Drone** (`simulador/simulador.exe`), e **NÃO no Cockpit Drone** (`drone.exe`).  
> 
> - **Servidor oficial em produção:** `https://maurinsoft.com.br/cockpit/`  
> - O Cockpit Drone conecta-se localmente (`127.0.0.1`) ao simulador para controle de voo e vídeo.  
> - O Simulador é quem mantém o link HTTP/REST com o servidor multiplayer e projeta os vizinhos no mapa e na câmera 3D.


## Implementado nesta etapa

- Cliente `cockpit_multiplayer.pas`: publica a posicao da simulacao de rota a cada 500 ms e consulta `/nearby` em thread propria. A interface nao faz chamadas HTTP.
- Entrada/saida explicita pelo botao Multiplayer da janela principal; a URL base e informada na entrada.
- Marcadores amarelos no mapa com identificador e distancia; painel na camera com identificador, distancia horizontal e altitude. O painel da camera e uma lista de proximidade, nao uma projecao sobre o video.
- Snapshots substituem a lista anterior; falhas e ausencia de posicao removem participantes. HTTP 401 causa nova sessao; falhas transitorias tentam novamente apos 2 segundos.
- Cliente HTTP com limites de conexao/leitura e registro do transporte TLS (OpenSSL precisa estar disponivel para HTTPS).
- Parser valida coordenadas, altitude, distancia <= 2000 m e limita a 100 participantes.

## Como usar

1. Disponibilize `PHP/` em servidor PHP 8.1+ com as rotas do `.htaccess`, configurando o armazenamento conforme `PHP/README.md`.
2. No cockpit, ative uma simulacao de rota com coordenadas validas.
3. Clique em **Entrar multiplayer** e informe a URL base (exemplo `http://127.0.0.1:8080`; nao inclua `/nearby`).
4. Outra sessao REST deve publicar telemetria no mesmo servidor com `lat`, `lon`, `altitude_m` e `state`. `name` opcional e usado como rotulo; sem ele aparece o identificador da sessao.
5. Abra mapa/camera. As atualizacoes de tela ocorrem a cada 250 ms; a consulta de rede, a cada 500 ms.
6. Ao parar a simulacao, a sessao e encerrada. Ao retomar, uma nova sessao e criada. **Sair multiplayer** desliga o cliente.

## Validacao local

Lazarus 4.4 / FPC 3.2.2, Windows i386.

- 50 testes Python existentes: aprovados.
- `tests/test_multiplayer_state.pas`: compilado e aprovado; limites 1999/2000/2001 m, coordenadas invalidas, campos ausentes, snapshot vazio e resposta malformada.
- `tests/test_multiplayer_http.pas` com `tests/run_multiplayer_http.py`: compilado e aprovado; polling HTTP real em localhost, expiracao 401, reconexao, limpeza e disconnect. Servidor de teste Python, nao PHP.
- `simulador/src/simulador.lpi`: compilado; executavel `simulador/simulador.exe`. Dois warnings preexistentes registrados no log.
- `src/drone.lpi`: tentativa bloqueada em `src/rotavoo.pas:31`: unidade `aidronemavlink` ausente. A pasta local `CHATGPT/pacote/AI Drone` contem apenas `aidronefq777.pas` e README.

Para reproduzir os testes novos (substitua `fpc` pelo caminho do compilador):

```text
mkdir build-multiplayer
fpc -Fusrc -FUbuild-multiplayer -FEbuild-multiplayer tests/test_multiplayer_state.pas
build-multiplayer/test_multiplayer_state.exe
fpc -Fusrc -FUbuild-multiplayer -FEbuild-multiplayer tests/test_multiplayer_http.pas
python tests/run_multiplayer_http.py build-multiplayer/test_multiplayer_http.exe
```

## Limites e pendencias

- Integracao inicial restrita a simulacao de rota do cockpit; nao publica automaticamente GPS de equipamento fisico nem a posicao do simulador separado.
- A pasta local `simulador/` conserva seu protocolo `servidor_mundo/public/api.php`. Ele NAO e intercambiavel com o REST de `PHP/` usado nesta integracao.
- Ainda nao ha interpolacao, projecao perspectiva de participantes no video ou UI de eventos multiplayer.
- Interface completa ainda nao validada visualmente devido a dependencia de compilacao ausente. A compilacao do modulo de rede nao prova a compilacao do cockpit completo.
- PHP nao encontrado no PATH nem nos diretorios de instalacao verificados: testes contra backend PHP real, MySQL/APCu, HTTPS e multiplos computadores pendentes.
- O encerramento aguarda a requisicao em curso e usa timeouts de 1500 ms por operacao; nao ha cancelamento imediato de DNS.

## Preservacao

Master atualizada por fast-forward de `74f1f175a7cc63172d1eda65d6ea22abcb452b48` para `575ec3a`. README local e pasta simulador preservados com backup antes da atualizacao. Nenhum commit ou push feito nesta etapa.

## Atualizacao WebSocket

O transporte WS/WSS foi implementado posteriormente nesta mesma data. Consulte [WEBSOCKET.md](WEBSOCKET.md) para uso e validacoes atuais com PHP real. As limitacoes acima descrevem a etapa HTTP inicial.
