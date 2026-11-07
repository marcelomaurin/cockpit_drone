<?php
declare(strict_types=1);
function distance(float $a, float $b, float $c, float $d): float {
    $x = deg2rad($c-$a); $y = deg2rad($d-$b);
    $h = sin($x/2)**2 + cos(deg2rad($a))*cos(deg2rad($c))*sin($y/2)**2;
    return 6371000 * 2 * asin(min(1.0, sqrt($h)));
}
interface Store {
    public function get(string $key): ?array;
    public function put(string $key, array $value, int $ttl): void;
    public function remove(string $key): void;
    public function sessions(): array;
    public function appendEvent(string $sender, array $value): int;
    public function events(int $after): array;
}
final class FileStore implements Store {
    private string $dir;
    public function __construct(string $dir) {
        $this->dir = $dir;
        if (!is_dir($dir) && !mkdir($dir, 0700, true) && !is_dir($dir)) throw new RuntimeException('Cannot create data directory');
        if (!is_writable($dir)) throw new RuntimeException('Data directory not writable');
    }
    private function path(string $key): string { return $this->dir . '/s_' . hash('sha256', $key) . '.json'; }
    public function get(string $key): ?array {
        $p=$this->path($key); if (!is_file($p)) return null;
        $f=fopen($p,'rb'); if (!$f) return null;
        flock($f,LOCK_SH); $raw=stream_get_contents($f); flock($f,LOCK_UN); fclose($f);
        $v=json_decode((string)$raw,true);
        return is_array($v) && ($v['expiry']??0)>time() ? $v['data'] : null;
    }
    public function put(string $key,array $value,int $ttl): void {
        $p=$this->path($key); $f=fopen($p,'c+b'); if (!$f) throw new RuntimeException('Cannot open session');
        flock($f,LOCK_EX); ftruncate($f,0); rewind($f);
        fwrite($f,json_encode(['expiry'=>time()+$ttl,'data'=>$value],JSON_THROW_ON_ERROR));
        fflush($f); flock($f,LOCK_UN); fclose($f);
    }
    public function remove(string $key): void { @unlink($this->path($key)); }
    public function sessions(): array {
        $out=[];
        foreach (glob($this->dir.'/s_*.json') ?: [] as $p) {
            $f=@fopen($p,'rb'); if (!$f) continue;
            flock($f,LOCK_SH); $raw=stream_get_contents($f); flock($f,LOCK_UN); fclose($f);
            $v=json_decode((string)$raw,true);
            if (is_array($v) && ($v['expiry']??0)>time() && isset($v['data'])) $out[]=$v['data'];
            // Expired records are ignored; do not race a concurrent renewal by unlinking.

        }
        return $out;
    }
    private function eventFile(): string { return $this->dir.'/events.json'; }
    public function appendEvent(string $sender,array $value): int {
        $f=fopen($this->eventFile(),'c+b'); if (!$f) throw new RuntimeException('Cannot open events');
        flock($f,LOCK_EX); $list=json_decode((string)stream_get_contents($f),true);
        if (!is_array($list)) $list=[];
        $id=max((int)floor(microtime(true)*1000000), (int)($list[count($list)-1]['id']??0)+1);
        $list[]= ['id'=>$id,'sender'=>$sender,'data'=>$value,'at'=>time()];
        $list=array_values(array_filter($list,fn($e)=>($e['at']??0)>time()-120));
        rewind($f); ftruncate($f,0); fwrite($f,json_encode($list,JSON_THROW_ON_ERROR)); fflush($f);
        flock($f,LOCK_UN); fclose($f); return $id;
    }
    public function events(int $after): array {
        $f=@fopen($this->eventFile(),'rb');
        if (!$f) return [];
        flock($f,LOCK_SH); $raw=stream_get_contents($f); flock($f,LOCK_UN); fclose($f);
        $v=json_decode((string)$raw,true);
        return array_values(array_filter(is_array($v)?$v:[],fn($e)=>($e['id']??0)>$after && ($e['at']??0)>time()-120));
    }
}
final class ApcuStore implements Store {
    public function __construct() {
        if (!function_exists('apcu_enabled') || !apcu_enabled()) throw new RuntimeException('APCu disabled');
    }
    public function get(string $key): ?array { $v=apcu_fetch('drone:s:'.$key); return is_array($v)?$v:null; }
    public function put(string $key,array $value,int $ttl): void {
        apcu_store('drone:s:'.$key,$value,$ttl);
        apcu_store('drone:idx:'.$key,time()+$ttl,$ttl);
    }
    public function remove(string $key): void { apcu_delete('drone:s:'.$key); apcu_delete('drone:idx:'.$key); }
    public function sessions(): array {
        $out=[]; $it=new APCUIterator('/^drone:idx:/');
        foreach ($it as $row) {
            $key=substr($row['key'],strlen('drone:idx:'));
            $v=$this->get($key); if ($v!==null) $out[]=$v;
        }
        return $out;
    }
    public function appendEvent(string $sender,array $value): int {
        $id=(int)floor(microtime(true)*1000000);
        apcu_store('drone:event:'.$id,['id'=>$id,'sender'=>$sender,'data'=>$value,'at'=>time()],120);
        return $id;
    }
    public function events(int $after): array {
        $out=[]; $it=new APCUIterator('/^drone:event:/');
        foreach ($it as $row) {
            $e=$row['value']; if (($e['id']??0)>$after) $out[]=$e;
        }
        usort($out,fn($a,$b)=>$a['id']<=>$b['id']); return $out;
    }
}
final class MysqlStore implements Store {
    private PDO $db;
    public function __construct(array $cfg) {
        $this->db=new PDO($cfg['dsn'],$cfg['user'],$cfg['password'],[
            PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES=>false
        ]);
        // Idempotent bootstrap: create missing tables and seed absent parameters.
        // Existing data (including a newer VERSAO) must remain unchanged.
        $schema = file_get_contents(__DIR__ . '/schema.sql');
        if ($schema === false) throw new RuntimeException('Cannot read database schema');
        foreach (explode(';', $schema) as $statement) {
            $statement = trim($statement);
            if ($statement !== '') $this->db->exec($statement);
        }
    }
    public function get(string $key): ?array {
        $q=$this->db->prepare('SELECT payload FROM drone_sessions WHERE token_hash=? AND expires_at>?');
        $q->execute([$key,time()]); $v=$q->fetchColumn();
        return $v===false?null:json_decode($v,true);
    }
    public function put(string $key,array $value,int $ttl): void {
        $q=$this->db->prepare('INSERT INTO drone_sessions(token_hash,payload,expires_at) VALUES(?,?,?) ON DUPLICATE KEY UPDATE payload=VALUES(payload),expires_at=VALUES(expires_at)');
        $q->execute([$key,json_encode($value,JSON_THROW_ON_ERROR),time()+$ttl]);
    }
    public function remove(string $key): void {
        $q=$this->db->prepare('DELETE FROM drone_sessions WHERE token_hash=?'); $q->execute([$key]);
    }
    public function sessions(): array {
        $q=$this->db->prepare('SELECT payload FROM drone_sessions WHERE expires_at>?');
        $q->execute([time()]);
        return array_map(fn($r)=>json_decode($r['payload'],true),$q->fetchAll());
    }
    public function appendEvent(string $sender,array $value): int {
        $q=$this->db->prepare('INSERT INTO drone_events(sender_hash,payload,created_at) VALUES(?,?,?)');
        $q->execute([$sender,json_encode($value,JSON_THROW_ON_ERROR),time()]);
        return (int)$this->db->lastInsertId();
    }
    public function events(int $after): array {
        $q=$this->db->prepare('SELECT id,sender_hash,payload,created_at FROM drone_events WHERE id>? AND created_at>? ORDER BY id ASC LIMIT 500');
        $q->execute([$after,time()-120]); $out=[];
        foreach ($q as $r) $out[]=['id'=>(int)$r['id'],'sender'=>$r['sender_hash'],'data'=>json_decode($r['payload'],true),'at'=>(int)$r['created_at']];
        return $out;
    }
}
function createStore(array $config): Store {
    return match ($config['storage']) {
        'files' => new FileStore($config['data_dir']),
        'mysql' => new MysqlStore($config['mysql']),
        'apcu' => new ApcuStore(),
        default => throw new RuntimeException('Invalid storage backend'),
    };
}
