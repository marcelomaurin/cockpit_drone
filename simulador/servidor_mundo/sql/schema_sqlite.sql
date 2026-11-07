-- Servidor de mundo compartilhado: SQLite (criado sozinho na primeira chamada).
CREATE TABLE IF NOT EXISTS drones (
  id          TEXT    NOT NULL PRIMARY KEY,
  token_hash  TEXT    NOT NULL UNIQUE,
  ip          TEXT    NOT NULL,
  apelido     TEXT    NOT NULL,
  modelo      TEXT    NOT NULL,
  lat         REAL    NOT NULL,
  lon         REAL    NOT NULL,
  alt         REAL    NOT NULL DEFAULT 0,
  rumo        INTEGER NOT NULL DEFAULT 0,
  velocidade  REAL    NOT NULL DEFAULT 0,
  estado      TEXT    NOT NULL DEFAULT 'parado',
  bateria     INTEGER NULL,
  criado_em   INTEGER NOT NULL,
  atualizado  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_drones_pos ON drones (lat, lon);
CREATE INDEX IF NOT EXISTS idx_drones_atualizado ON drones (atualizado);
CREATE INDEX IF NOT EXISTS idx_drones_ip ON drones (ip);

CREATE TABLE IF NOT EXISTS eventos (
  seq        INTEGER PRIMARY KEY AUTOINCREMENT,
  drone_id   TEXT    NOT NULL,
  apelido    TEXT    NOT NULL,
  tipo       TEXT    NOT NULL,
  conteudo   TEXT    NOT NULL,
  lat        REAL    NOT NULL,
  lon        REAL    NOT NULL,
  quando     INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_eventos_quando ON eventos (quando);
CREATE INDEX IF NOT EXISTS idx_eventos_pos ON eventos (lat, lon);

CREATE TABLE IF NOT EXISTS limites (
  chave     TEXT    NOT NULL PRIMARY KEY,
  inicio    INTEGER NOT NULL,
  contagem  INTEGER NOT NULL
);
