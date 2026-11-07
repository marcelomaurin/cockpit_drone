# WebSocket multiplayer

## Implementacao

- `PHP/ws-server.php`: processo PHP CLI persistente usando Ratchet. `composer.lock` fixa as dependencias.
- `PHP/storage.php`: armazenamento compartilhado com `index.php`; MySQL cria as tabelas ausentes e `params.VERSAO=0.01` conforme schema.sql. Sem sobrescrever versoes existentes.
- `src/multiplayer_websocket.pas`: WinHTTP do Windows 8+; ws/wss, validacao TLS padrao do sistema, leitura em thread e cancelamento ao fechar.
- `src/cockpit_multiplayer.pas`: publica a posicao da simulacao de rota a cada 500 ms, recebe snapshots sem consultar `/nearby`, reconecta apos 2 s e limpa participantes ao perder conexao. Snapshot sem atualizacao por 5 s causa reconexao.
- `PHP/multiplayer.js`: cliente ES module para o site, com callbacks de participantes, estado e eventos.

O servidor envia mudancas imediatamente apos telemetria WebSocket. Um temporizador de 200 ms detecta mudancas feitas pelo REST e expiracao de sessoes. Snapshots completos tambem sao enviados a cada segundo, mesmo sem movimento. Saida do raio ou desconexao remove o participante no snapshot seguinte. Apos encerramento abrupto do processo servidor, as sessoes persistidas expiram pelo session_ttl configurado (120 s por padrao).

## Instalar e iniciar

Na pasta PHP, execute:

```sh
composer install --no-dev --prefer-dist
# Somente na primeira instalacao: copie config_sample.php para config.php.
php ws-server.php
```

Configure `config.php` com backend `files` ou `mysql`, o mesmo do REST. APCu e recusado no WS porque processos CLI/web nao compartilham seu cache de forma confiavel.

Variaveis opcionais do modelo:

- `DRONE_WS_LISTEN=127.0.0.1:8081`: interface/porta de escuta.
- `DRONE_WS_ORIGINS=https://seu-site.example`: origens de navegadores permitidas, separadas por virgula. Sem lista, conexoes de navegador com Origin sao recusadas; cliente nativo sem Origin e aceito.

No cockpit, clique Entrar multiplayer e informe `ws://127.0.0.1:8081`. Ative a simulacao de rota e abra mapa/camera. URLs HTTP/HTTPS continuam selecionando o transporte REST anterior.

Em producao, mantenha o processo sob um supervisor (systemd/Supervisor/servico Windows) e use proxy reverso com certificado valido. Exemplo de trecho Nginx dentro de um servidor HTTPS existente:

```nginx
location /ws {
    proxy_pass http://127.0.0.1:8081;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_read_timeout 75s;
}
```

O cliente usa `wss://seu-site.example/ws`. Nao e suficiente enviar ws-server.php para hospedagem que execute apenas requisicoes PHP comuns; e necessario permitir processo persistente e proxy WebSocket.

## Protocolo JSON

Ao abrir, servidor envia `connected` com id/token da nova sessao. O socket fica associado a essa sessao; o cliente nao pode escolher outro remetente. Fechar o socket revoga a sessao. A entrada e anonima, como no REST existente.

Cliente envia:

```json
{"type":"telemetry","telemetry":{"lat":-21.17,"lon":-47.81,"altitude_m":10,"name":"Piloto"}}
{"type":"event","event":{"type":"simulation.test","payload":{"value":1}}}
{"type":"heartbeat"}
{"type":"disconnect"}
```

Servidor envia `snapshot` com `participants`, `events` com eventos de vizinhos, `event_ack`, `heartbeat` ou `error`. Distancia horizontal maxima de 2000 m; sessao propria excluida. Snapshot limitado a 100 participantes, 100 sockets por processo, 20 mensagens/s/socket e 64 KB por mensagem de aplicacao. Limite de 64 KB e aplicado depois da remontagem de frames pelo Ratchet; limite de memoria do PHP e limite adicional do proxy continuam necessarios para exposicao publica.

## Cliente do site

```js
import {CockpitMultiplayer} from './multiplayer.js';
const world = new CockpitMultiplayer('wss://seu-site.example/ws',
  participants => atualizarMarcadores(participants),
  status => console.log(status),
  events => console.log(events));
world.setPosition(-21.17, -47.81, 10, 'Piloto');
world.start();
// world.stop() ao sair.
```

`atualizarMarcadores` e o callback do mapa da pagina. Renderize nomes como texto, nunca HTML.

## Testes e limites

- PHP 8.5.12 portatil, hash oficial conferido; dependencias Ratchet emitem avisos de depreciacao nessa versao, sem falhas nos testes.
- FPC 3.2.2 Windows i386: cliente WebSocket e testes compilados.
- `python tests/run_multiplayer_ws.py CAMINHO_PHP [CAMINHO_TESTE_PASCAL]`: inicia servidores reais em portas temporarias e copia configuracao para pasta isolada. Nao usa config.php de producao. Requer `composer install` e Python `websockets==14.1`.
- Verifica REST original, dois sockets, raio, eventos, entrada invalida, origem recusada, revogacao REST, recepcao Pascal, limpeza e reconexao apos reiniciar o processo PHP.
- Teste Pascal: compilar `tests/test_multiplayer_ws.pas` com `-Fusrc` e diretorios de saida temporarios.
- Interface completa do cockpit ainda bloqueada pela unidade externa `aidronemavlink` ausente. O executavel de teste utiliza o cliente real sem carregar essa interface.
- WSS usa WinHTTP com verificacao de certificado, mas nao foi ensaiado com dominio/certificado de producao. MySQL, multiplos servidores e carga elevada nao foram homologados. O cliente nativo novo e Windows; em outros sistemas use HTTP ate adicionar outro transporte WS.
- Eventos chegam ao servidor e ao cliente JavaScript; a interface Lazarus continua exibindo participantes e ainda nao possui painel de eventos.

Referencias de implementacao: https://github.com/ratchetphp/Ratchet e https://learn.microsoft.com/en-us/windows/win32/api/winhttp/nf-winhttp-winhttpwebsocketcompleteupgrade
