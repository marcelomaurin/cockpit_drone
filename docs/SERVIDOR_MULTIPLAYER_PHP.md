# Servidor multiplayer de telemetria — especificação v1

Status: especificação de arquitetura; **não implementado**.

## Objetivo
Web service PHP simples, sem interface web, com MySQL e JSON sobre HTTPS. Receber telemetria de simuladores e disponibilizar aos participantes ativos a até **2.000 metros** de distância horizontal. O servidor **não simula física, colisões, armamentos ou trajetória**: retransmite eventos virtuais e estados. Não encaminha comandos a hardware real.

## Sessões
- POST /api/v1/connect: cria **token criptograficamente aleatório novo em toda conexão**, inclusive reconexões. Resposta: session_id, token, expires_at, heartbeat_interval_ms. Nunca reutilizar token antigo.
- POST /api/v1/disconnect: encerra sessão e revoga token.
- Sessões expiram por inatividade; tokens são enviados por Authorization: Bearer e guardados apenas como hash no banco. Usar HTTPS, limite de requisições e não registrar tokens em logs.
- Uma nova conexão do mesmo cliente invalida sua sessão anterior quando for possível associá-las por identificador de instalação; sem identidade persistente, a sessão antiga expira por timeout. Token identifica sessão, não pessoa, e sua posse não impede roubo se exposto.

## API JSON proposta
- POST /api/v1/telemetry: publica {sequence, timestamp_ms, vehicle_id, model_id, latitude, longitude, altitude_m, heading_deg, speed_mps, battery_pct, state}. Validar tipos, faixas, sequência crescente e tamanho máximo.
- GET /api/v1/nearby?since=<cursor>: devolve apenas estados e eventos de outras sessões ativas em raio <= 2000 m, com cursor de atualização; nunca retornar tokens. Paginação e limites de payload.
- POST /api/v1/events: retransmite eventos de simulação {event_id, type, timestamp_ms, payload} somente aos vizinhos elegíveis; eventos são dados de jogo, sem cálculo de impacto no servidor.
- GET /api/v1/health: saúde do serviço, sem informações sensíveis.
- Erros: JSON {error:{code,message}}, com HTTP 400, 401, 403, 409, 429 ou 500 conforme o caso.

## Proximidade e privacidade
- Consultar somente participantes ativos com telemetria recente; aplicar filtro espacial por caixa delimitadora/indexação e confirmar distância geodésica (Haversine ou ST_Distance_Sphere), **<= 2000 m**.
- Usar posição validada e atual da sessão requisitante; não aceitar coordenada arbitrária na consulta nearby. Altitude pode ser apresentada, mas não entra no raio horizontal nesta versão.
- Eventos também obedecem ao filtro espacial; nenhum dado de sessão distante deve vazar em respostas, contagens ou erros.
- Retenção curta para telemetria e expiração de sessões; definir política operacional de limpeza.

## MySQL (modelo lógico)
sessions(id, token_hash, installation_id_hash NULL, created_at, expires_at, last_seen_at, revoked_at);
vehicles(id, session_id, model_id, type);
telemetry_latest(session_id, vehicle_id, latitude, longitude, altitude_m, heading_deg, speed_mps, battery_pct, sequence, updated_at, spatial_index);
simulation_events(id, session_id, type, payload_json, created_at, expires_at).
Índices para sessão, validade, atualização e consulta geoespacial. Não armazenar histórico completo no caminho crítico.

## Desempenho
- PHP 8+ com PDO e prepared statements; MySQL 8+; endpoints stateless e respostas JSON compactas.
- Publicação e consulta em lotes, polling incremental inicialmente; frequências configuráveis (exemplo inicial 5 Hz) e testes de carga antes de estabelecer SLA.
- Não prometer latência de tempo real rígido via HTTP/PHP; medir p50/p95, perda de atualizações e concorrência.

## Segurança e aceite
- Validar token, propriedade do veículo, ordem temporal e rate limits em toda escrita.
- Nunca transmitir instruções de controle de veículos físicos; separar completamente ambiente simulado.
- Testar: token novo a cada conexão; token revogado; consulta a 1999/2000/2001 m; telemetria obsoleta; posição inválida; concorrência; reconexão; não vazamento entre sessões; desempenho sob carga.
