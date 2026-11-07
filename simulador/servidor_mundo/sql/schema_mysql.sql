-- Servidor de mundo compartilhado: MySQL / MariaDB.
-- Guarda só o estado atual dos drones ativos, eventos dos últimos 60 s e
-- contadores de limite. Nenhum histórico de voo é mantido.

CREATE TABLE IF NOT EXISTS drones (
  id          VARCHAR(16)  NOT NULL PRIMARY KEY,
  token_hash  CHAR(64)     NOT NULL UNIQUE,
  ip          VARCHAR(45)  NOT NULL,
  apelido     VARCHAR(32)  NOT NULL,
  modelo      VARCHAR(24)  NOT NULL,
  lat         DOUBLE       NOT NULL,
  lon         DOUBLE       NOT NULL,
  alt         FLOAT        NOT NULL DEFAULT 0,
  rumo        SMALLINT     NOT NULL DEFAULT 0,
  velocidade  FLOAT        NOT NULL DEFAULT 0,
  estado      VARCHAR(16)  NOT NULL DEFAULT 'parado',
  bateria     TINYINT      NULL,
  criado_em   BIGINT       NOT NULL,
  atualizado  BIGINT       NOT NULL,
  INDEX idx_pos (lat, lon),
  INDEX idx_atualizado (atualizado),
  INDEX idx_ip (ip)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS eventos (
  seq        BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
  drone_id   VARCHAR(16)  NOT NULL,
  apelido    VARCHAR(32)  NOT NULL,
  tipo       VARCHAR(16)  NOT NULL,
  conteudo   TEXT         NOT NULL,
  lat        DOUBLE       NOT NULL,
  lon        DOUBLE       NOT NULL,
  quando     BIGINT       NOT NULL,
  INDEX idx_quando (quando),
  INDEX idx_pos (lat, lon)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS limites (
  chave     VARCHAR(80)  NOT NULL PRIMARY KEY,
  inicio    BIGINT       NOT NULL,
  contagem  INT          NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
