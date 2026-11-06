# API REST JSON — Servidor Multiplayer Cockpit Drone

**Versão:** proposta v1 • **Estado:** contrato de API para implementação, ainda não homologado.

## Convenções

- Base URL: `https://<host>/api/v1`. Somente HTTPS em produção.
- Requisições com corpo: `Content-Type: application/json; charset=utf-8`; respostas JSON.
- Todos os endpoints exceto `connect` e `health` exigem `Authorization: Bearer <token>`.
- Cada chamada de `connect` gera **novo token**, inclusive reconexões. Não reutilizar tokens.
- Coordenadas em WGS84, graus decimais; altitude em metros; velocidade em m/s; tempo em Unix epoch milissegundos UTC.
- `vehicle_id` identifica veículo na sessão; `session_id` é identificador opaco do servidor.
- Limite de proximidade: distância geodésica **horizontal <= 2000 m** entre posições recentes de sessões. A altitude não altera esse limite na v1.
- Versão do contrato: `/v1`; campos adicionais opcionais devem ser ignorados por clientes antigos.

## 1. Criar sessão

`POST /connect` — sem autenticação.

Requisição:
```json
{"client_version":"0.1.0","installation_id":"local-opaque-id","vehicle":{"vehicle_id":"drone-01","model_id":"quad-x","type":"multirotor"}}
```

Resposta `201 Created`:
```json
{"session_id":"s_8f2a","token":"<segredo_aleatorio>","expires_at":"2026-11-06T23:00:00Z","heartbeat_interval_ms":10000,"telemetry_interval_ms":200}
```

`installation_id` é opcional e não deve conter dados pessoais. O servidor gera token de alta entropia com `random_bytes`, guarda apenas hash e revoga o token no encerramento ou expiração. `expires_at` é limite absoluto configurável; inatividade também encerra a sessão. O token nunca aparece em logs ou consultas de vizinhos.

## 2. Enviar telemetria

`POST /telemetry` — Bearer obrigatório.

Requisição:
```json
{"vehicle_id":"drone-01","sequence":125,"timestamp_ms":1794000000000,"latitude":-21.17,"longitude":-47.81,"altitude_m":610.2,"heading_deg":90.0,"speed_mps":12.4,"battery_pct":78.5,"state":"flying"}
```

Resposta `200 OK`:
```json
{"accepted":true,"sequence":125,"server_time_ms":1794000000100}
```

Validar latitude [-90,90], longitude [-180,180], heading [0,360), battery [0,100], valores finitos, velocidade não negativa, tamanho do corpo, posse do veículo, timestamp em janela tolerada e sequência estritamente crescente por veículo/sessão. Atualizar somente o estado mais recente no caminho crítico.

## 3. Consultar veículos próximos

`GET /nearby?since=cursor_opaco&limit=100` — Bearer obrigatório; `since` opcional.

Resposta `200 OK`:
```json
{"server_time_ms":1794000000200,"radius_m":2000,"next_cursor":"cursor_opaco_2","vehicles":[{"session_id":"s_other","vehicle_id":"boat-02","model_id":"boat-small","latitude":-21.171,"longitude":-47.812,"altitude_m":605.0,"heading_deg":45,"speed_mps":3.1,"battery_pct":62,"state":"moving","updated_at_ms":1794000000100}]}
```

A localização de referência é a última telemetria válida e recente **da sessão autenticada**. O servidor filtra candidatos por índice espacial e confirma distância geodésica <= 2000 m. Não retornar sessão própria, sessões expiradas, posições antigas ou tokens. O cursor deve permitir atualizações incrementais; quando entidades saírem do raio, a resposta deverá indicar remoções (`removed`) ou exigir snapshot completo periódico para impedir fantasmas no cliente. Sem posição própria recente: `409 POSITION_REQUIRED`.

## 4. Publicar evento virtual

`POST /events` — Bearer obrigatório.

Requisição:
```json
{"event_id":"evt-001","vehicle_id":"drone-01","type":"simulation.projectile","timestamp_ms":1794000000300,"payload":{"virtual_object_id":"p-1","position":{"latitude":-21.17,"longitude":-47.81,"altitude_m":610},"velocity_mps":{"north":10,"east":0,"up":0}}}
```

Resposta `202 Accepted`:
```json
{"accepted":true,"event_id":"evt-001"}
```

Eventos são **somente dados de simulação/jogo**. O servidor não calcula trajetória, impacto ou colisão e não transmite comandos a equipamentos físicos. Validar tipos de evento permitidos, tamanho e esquema do payload. O simulador resolve a física. Eventos são disponibilizados apenas a sessões elegíveis no raio de 2 km, via `GET /events?since=<cursor>`, que responde `{"events":[],"next_cursor":"..."}`. Aplicar TTL curto e idempotência por `event_id`.

## 5. Encerrar sessão

`POST /disconnect` — Bearer obrigatório. Corpo opcional `{}`. Resposta `200 OK`: `{"disconnected":true}`. Revogar token imediatamente. Na reconexão, sempre chamar `connect` e receber token diferente.

## 6. Saúde

`GET /health` — resposta `200 OK`: `{"status":"ok","api_version":"v1"}`. Não expor detalhes do banco.

## Erros e HTTP

Formato comum:
```json
{"error":{"code":"INVALID_TELEMETRY","message":"latitude fora do intervalo"}}
```

- `400` JSON inválido, parâmetros/tipos/faixas incorretos.
- `401` token ausente, inválido, expirado ou revogado.
- `403` veículo não pertence à sessão.
- `404` recurso inexistente.
- `409` `POSITION_REQUIRED`, `OUT_OF_ORDER` ou conflito de sequência.
- `413` payload excessivo; `429` excesso de chamadas; `500` falha interna; `503` indisponibilidade.
- Nunca retornar SQL, token, hash ou detalhes internos em erros.

## Fluxo recomendado

1. Simulador inicia veículo e chama `connect`; armazena token apenas em memória.
2. Publica `telemetry` periodicamente (intervalo sugerido inicial: 200 ms, configurável).
3. Consulta `nearby` e `GET /events` com cursores, renderiza vizinhos e interpola movimento.
4. Envia `events` de interações virtuais; os simuladores verificam colisões e resultados.
5. Ao sair, chama `disconnect`. Após perda de sessão, faz novo `connect` com token novo.

## Implementação e testes

PHP 8+, PDO com prepared statements, MySQL 8+, índices de sessão/tempo e espacial, HTTPS, rate limiting e expiração de dados. Usar JSON compacto, sem interface web. Medir latência p50/p95 e carga simultânea; HTTP polling não garante tempo real rígido.

Testes obrigatórios: dois `connect` geram tokens diferentes; token antigo revogado/expirado falha; telemetria inválida rejeitada; limites 1999/2000/2001 m; sessão sem posição; veículos distantes nunca aparecem; eventos filtrados; cursor/removidos; reconexão; concorrência e carga.

**Referências internas:** [SERVIDOR_MULTIPLAYER_PHP.md](SERVIDOR_MULTIPLAYER_PHP.md) e [SIMULADOR_ARQUITETURA.md](SIMULADOR_ARQUITETURA.md).
