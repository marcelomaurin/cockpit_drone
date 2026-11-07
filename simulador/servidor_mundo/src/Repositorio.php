<?php
declare(strict_types=1);

namespace MundoDrone;

use PDO;

/**
 * Acesso ao banco (MySQL/MariaDB ou SQLite), sempre com consultas preparadas.
 * Guarda só o estado atual dos drones ativos e os eventos dos últimos segundos.
 */
final class Repositorio
{
    private PDO $pdo;
    private string $driver;

    public function __construct(string $dsn, string $usuario = '', string $senha = '')
    {
        if (str_starts_with($dsn, 'sqlite:')) {
            $arquivo = substr($dsn, 7);
            if ($arquivo !== ':memory:' && !is_dir(dirname($arquivo))) {
                mkdir(dirname($arquivo), 0770, true);
            }
        }
        $this->pdo = new PDO($dsn, $usuario, $senha, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
        $this->driver = (string) $this->pdo->getAttribute(PDO::ATTR_DRIVER_NAME);
        if ($this->driver === 'sqlite') {
            $this->pdo->exec('PRAGMA journal_mode=WAL');
            $this->pdo->exec('PRAGMA busy_timeout=3000');
            $this->criaTabelasSqlite();
        }
    }

    private function criaTabelasSqlite(): void
    {
        $this->pdo->exec(file_get_contents(__DIR__ . '/../sql/schema_sqlite.sql'));
    }

    public function pdo(): PDO
    {
        return $this->pdo;
    }

    /** @return array<string, mixed>|null */
    public function droneDoToken(string $tokenHash): ?array
    {
        $st = $this->pdo->prepare('SELECT * FROM drones WHERE token_hash = ?');
        $st->execute([$tokenHash]);
        $linha = $st->fetch();
        return $linha === false ? null : $linha;
    }

    public function idExiste(string $id): bool
    {
        $st = $this->pdo->prepare('SELECT 1 FROM drones WHERE id = ?');
        $st->execute([$id]);
        return $st->fetchColumn() !== false;
    }

    public function dronesDoIp(string $ip, int $desde): int
    {
        $st = $this->pdo->prepare('SELECT COUNT(*) FROM drones WHERE ip = ? AND atualizado >= ?');
        $st->execute([$ip, $desde]);
        return (int) $st->fetchColumn();
    }

    /** @param array<string, mixed> $d */
    public function insereDrone(array $d): void
    {
        $st = $this->pdo->prepare(
            'INSERT INTO drones (id, token_hash, ip, apelido, modelo, lat, lon, alt, rumo, velocidade,
                estado, bateria, criado_em, atualizado)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?, NULL, ?, ?)'
        );
        $st->execute([
            $d['id'], $d['token_hash'], $d['ip'], $d['apelido'], $d['modelo'],
            $d['lat'], $d['lon'], $d['alt'], 'parado', $d['agora'], $d['agora'],
        ]);
    }

    /** @param array<string, mixed> $d */
    public function atualizaDrone(string $id, array $d): void
    {
        $st = $this->pdo->prepare(
            'UPDATE drones SET lat = ?, lon = ?, alt = ?, rumo = ?, velocidade = ?, estado = ?,
                bateria = ?, atualizado = ? WHERE id = ?'
        );
        $st->execute([
            $d['lat'], $d['lon'], $d['alt'], $d['rumo'], $d['velocidade'], $d['estado'],
            $d['bateria'], $d['agora'], $id,
        ]);
    }

    public function removeDrone(string $id): void
    {
        $st = $this->pdo->prepare('DELETE FROM drones WHERE id = ?');
        $st->execute([$id]);
    }

    /**
     * Drones ativos dentro do retângulo (o filtro exato por distância é feito depois).
     * @param array{latMin: float, latMax: float, lonMin: float, lonMax: float} $r
     * @return list<array<string, mixed>>
     */
    public function dronesNoRetangulo(array $r, string $excetoId, int $desde): array
    {
        $st = $this->pdo->prepare(
            'SELECT id, apelido, modelo, lat, lon, alt, rumo, velocidade, estado, bateria, atualizado
               FROM drones
              WHERE lat BETWEEN ? AND ? AND lon BETWEEN ? AND ?
                AND atualizado >= ? AND id <> ?'
        );
        $st->execute([$r['latMin'], $r['latMax'], $r['lonMin'], $r['lonMax'], $desde, $excetoId]);
        return $st->fetchAll();
    }

    public function insereEvento(string $droneId, string $apelido, string $tipo, string $conteudo,
        float $lat, float $lon, int $agora): int
    {
        $st = $this->pdo->prepare(
            'INSERT INTO eventos (drone_id, apelido, tipo, conteudo, lat, lon, quando) VALUES (?, ?, ?, ?, ?, ?, ?)'
        );
        $st->execute([$droneId, $apelido, $tipo, $conteudo, $lat, $lon, $agora]);
        return (int) $this->pdo->lastInsertId();
    }

    /**
     * Eventos novos cuja origem está no retângulo (o filtro exato vem depois).
     * @param array{latMin: float, latMax: float, lonMin: float, lonMax: float} $r
     * @return list<array<string, mixed>>
     */
    public function eventosNoRetangulo(array $r, int $depoisSeq, int $desde, string $excetoDrone): array
    {
        $st = $this->pdo->prepare(
            'SELECT seq, drone_id, apelido, tipo, conteudo, lat, lon, quando
               FROM eventos
              WHERE seq > ? AND quando >= ? AND drone_id <> ?
                AND lat BETWEEN ? AND ? AND lon BETWEEN ? AND ?
              ORDER BY seq LIMIT 50'
        );
        $st->execute([$depoisSeq, $desde, $excetoDrone, $r['latMin'], $r['latMax'], $r['lonMin'], $r['lonMax']]);
        return $st->fetchAll();
    }

    public function ultimoSeqEvento(): int
    {
        return (int) $this->pdo->query('SELECT COALESCE(MAX(seq), 0) FROM eventos')->fetchColumn();
    }

    /**
     * Janela fixa de contagem. Devolve a contagem depois de somar 1.
     */
    public function contaLimite(string $chave, int $janelaMs, int $agora): int
    {
        $inicio = intdiv($agora, $janelaMs) * $janelaMs;
        if ($this->driver === 'mysql') {
            $st = $this->pdo->prepare(
                'INSERT INTO limites (chave, inicio, contagem) VALUES (?, ?, 1)
                 ON DUPLICATE KEY UPDATE contagem = IF(inicio = VALUES(inicio), contagem + 1, 1),
                                         inicio = VALUES(inicio)'
            );
        } else {
            $st = $this->pdo->prepare(
                'INSERT INTO limites (chave, inicio, contagem) VALUES (?, ?, 1)
                 ON CONFLICT(chave) DO UPDATE SET
                   contagem = CASE WHEN limites.inicio = excluded.inicio THEN limites.contagem + 1 ELSE 1 END,
                   inicio = excluded.inicio'
            );
        }
        $st->execute([$chave, $inicio]);
        $st = $this->pdo->prepare('SELECT contagem FROM limites WHERE chave = ?');
        $st->execute([$chave]);
        return (int) $st->fetchColumn();
    }

    public function limpa(int $dronesAntesDe, int $eventosAntesDe, int $limitesAntesDe): void
    {
        $this->pdo->prepare('DELETE FROM drones WHERE atualizado < ?')->execute([$dronesAntesDe]);
        $this->pdo->prepare('DELETE FROM eventos WHERE quando < ?')->execute([$eventosAntesDe]);
        $this->pdo->prepare('DELETE FROM limites WHERE inicio < ?')->execute([$limitesAntesDe]);
    }
}
