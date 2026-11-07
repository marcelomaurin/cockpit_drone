# Protocolo do mundo compartilhado (versão 1)

**Servidor Oficial:** `https://maurinsoft.com.br/cockpit/`

> **Nota de Arquitetura:** A entrada multiplayer é feita no **Simulador**, não no Cockpit Drone. O simulador realiza as chamadas ao servidor e exibe os participantes no raio de 2 km.


Toda chamada é um `POST` em `api.php` com corpo JSON (no máximo 4 KB) e o campo `acao`. Fora `entrar` e `status`, toda chamada precisa do cabeçalho `Authorization: Bearer <token>`. Um `GET api.php` responde o `status`.

Unidades: graus decimais (WGS84), altura em metros acima da partida, rumo de 0 a 359, velocidade em m/s e horários em milissegundos desde 1970 (UTC).

## Regras

1. A entrada é livre: não há usuário nem senha.
2. Cada entrada cria um drone e um token. O token é a única prova de que quem envia é aquele drone.
3. O servidor identifica o drone sempre pelo token. Um `id` enviado no corpo é ignorado.
4. Cada resposta traz só drones e eventos a até **2.000 m** da posição atual de quem pergunta, pela distância de haversine na horizontal.
5. Fora do círculo nada é repassado: nem posição, nem apelido, nem contagem.
6. Um drone sem atualizar por 30 s sai do mundo, e o token deixa de valer.

## entrar

```json
{ "versao": 1, "acao": "entrar", "apelido": "Marcelo-RP", "modelo": "tello",
  "posicao": { "lat": -21.1767, "lon": -47.8208, "alt": 0 } }
```
```json
{ "ok": true, "id": "d_8f3a21", "token": "<64 hexadecimais>", "validade_s": 30,
  "raio_m": 2000, "intervalo_ms": 500, "ultimo_evento": 1042 }
```

## atualizar

```json
{ "versao": 1, "acao": "atualizar", "posicao": { "lat": -21.1771, "lon": -47.8199, "alt": 35.2 },
  "rumo": 92, "velocidade": 4.1, "estado": "voando", "bateria": 71, "ultimo_evento": 1042 }
```
```json
{ "ok": true, "agora": 1794501234567,
  "vizinhos": [ { "id": "d_17c0b9", "apelido": "Ana", "modelo": "ardrone",
      "posicao": { "lat": -21.1802, "lon": -47.8150, "alt": 20.0 }, "rumo": 270,
      "velocidade": 2.3, "estado": "voando", "bateria": "alta", "distancia_m": 640,
      "atualizado": 1794501234120 } ],
  "eventos": [ { "seq": 1043, "de": "d_17c0b9", "apelido": "Ana", "tipo": "mensagem",
      "conteudo": "Bom voo!", "quando": 1794501233900 } ] }
```

`estado` pode ser `parado`, `voando`, `pousando` ou `caiu`. A bateria dos vizinhos vem só como faixa: `alta` (50% ou mais), `media` (20% a 49%) ou `baixa`. Os eventos vêm com `seq` maior que `ultimo_evento`, no máximo 50 por resposta. Os próprios eventos não voltam.

## evento

```json
{ "versao": 1, "acao": "evento", "tipo": "marcador",
  "conteudo": { "lat": -21.1780, "lon": -47.8190, "rotulo": "Pouso aqui" } }
```
```json
{ "ok": true, "seq": 1044, "entregue_a": 3 }
```

| Tipo | Conteúdo |
|---|---|
| `mensagem` | Texto de 1 a 200 caracteres |
| `sinal` | Texto curto (até 20 caracteres), por exemplo `luzes` |
| `marcador` | `lat`, `lon` (a até 2 km de quem envia) e `rotulo` (até 40 caracteres) |

A origem do evento é a posição do drone do token no momento do envio. Eventos valem por 60 s.

## sair e status

`{ "acao": "sair" }` → `{ "ok": true }`. O token deixa de valer.

`status` → `{ "ok": true, "versao": 1, "raio_m": 2000, "intervalo_ms": 500 }`. Ele não traz nada sobre drones.

## Erros e limites

O corpo de erro é sempre `{"ok":false,"erro":"<código>","mensagem":"<texto>"}`.

| HTTP | Quando |
|---|---|
| 400 | JSON inválido, campo fora do limite ou salto de posição |
| 401 | Token ausente, inválido ou vencido (o cliente entra de novo) |
| 405 | Método diferente de POST (fora `status`) |
| 429 | Limite excedido |
| 500 | Erro interno (registrado no log do PHP) |

| Limite | Valor |
|---|---|
| `atualizar` por token | 4 por segundo |
| Entradas por endereço IP | 10 por minuto |
| Drones ativos por endereço IP | 5 |
| Eventos por token | 1 por segundo |
| Salto de posição | Velocidade implícita acima de 60 m/s (e mais de 30 m) é recusada |
| Apelido | 3 a 32 caracteres: letras, números, `-` e `_` |

O limite de salto impede o teletransporte: um drone só chega a outra área voando até ela. Sair e entrar de novo em outro ponto é permitido, porque a entrada é livre; o limite por endereço reduz o uso para varrer o mapa.
