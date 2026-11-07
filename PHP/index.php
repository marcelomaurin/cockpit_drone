<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
$config = require __DIR__ . '/config.php';
function reply(int $code, array $data): never {
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}
function body(): array {
    $raw = file_get_contents('php://input');
    if ($raw === false || strlen($raw) > 65536) reply(413, ['error'=>'payload_too_large']);
    $v = json_decode($raw, true);
    if (!is_array($v) || array_is_list($v)) reply(400, ['error'=>'invalid_json_object']);
    return $v;
}
function coordinate($v, float $min, float $max): float {
    if (!is_int($v) && !is_float($v)) reply(400, ['error'=>'invalid_coordinates']);
    $n = (float)$v;
    if (!is_finite($n) || $n < $min || $n > $max) reply(400, ['error'=>'invalid_coordinates']);
    return $n;
}
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
            $v=json_decode((string)@file_get_contents($p),true);
            if (is_array($v) && ($v['expiry']??0)>time() && isset($v['data'])) $out[]=$v['data'];
            elseif (is_array($v) && ($v['expiry']??0)<=time()) @unlink($p);
        }
        return $out;
    }
    private function eventFile(): string { return $this->dir.'/events.json'; }
    public function appendEvent(string $sender,array $value): int {
        $f=fopen($this->eventFile(),'c+b'); if (!$f) throw new RuntimeException('Cannot open events');
        flock($f,LOCK_EX); $list=json_decode((string)stream_get_contents($f),true);
        if (!is_array($list)) $list=[];
        $id=(int)floor(microtime(true)*1000000);
        $list[]= ['id'=>$id,'sender'=>$sender,'data'=>$value,'at'=>time()];
        $list=array_values(array_filter($list,fn($e)=>($e['at']??0)>time()-120));
        rewind($f); ftruncate($f,0); fwrite($f,json_encode($list,JSON_THROW_ON_ERROR)); fflush($f);
        flock($f,LOCK_UN); fclose($f); return $id;
    }
    public function events(int $after): array {
        $v=json_decode((string)@file_get_contents($this->eventFile()),true);
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
try {
    $storage=$config['storage'];
    $store=match($storage) {
        'files'=>new FileStore($config['data_dir']),
        'apcu'=>new ApcuStore(),
        'mysql'=>new MysqlStore($config['mysql']),
        default=>throw new RuntimeException('Invalid storage backend')
    };
    $path=parse_url($_SERVER['REQUEST_URI']??'/',PHP_URL_PATH);
    $path=rtrim((string)$path,'/');
    $route=basename($path);
    $method=$_SERVER['REQUEST_METHOD']??'GET';
    if ($route==='health' && $method==='GET') reply(200,['status'=>'ok','storage'=>$storage]);
    if ($route==='connect' && $method==='POST') {
        $token=bin2hex(random_bytes(32)); $key=hash('sha256',$token);
        $store->put($key,['id'=>substr($key,0,16),'key'=>$key,'lat'=>null,'lon'=>null,'telemetry'=>[]],(int)$config['session_ttl']);
        reply(201,['token'=>$token,'expires_in'=>(int)$config['session_ttl']]);
    }
    $header=$_SERVER['HTTP_AUTHORIZATION']??$_SERVER['REDIRECT_HTTP_AUTHORIZATION']??'';
    if (!preg_match('/^Bearer ([a-f0-9]{64})$/i',$header,$m)) reply(401,['error'=>'bearer_token_required']);
    $key=hash('sha256',strtolower($m[1])); $self=$store->get($key);
    if ($self===null) reply(401,['error'=>'invalid_or_expired_token']);
    if ($route==='disconnect' && $method==='POST') { $store->remove($key); reply(200,['status'=>'disconnected']); }
    if ($route==='telemetry' && $method==='POST') {
        $v=body();
        $self['lat']=coordinate($v['lat']??null,-90,90);
        $self['lon']=coordinate($v['lon']??null,-180,180);
        $self['telemetry']=$v;
        $store->put($key,$self,(int)$config['session_ttl']);
        reply(200,['status'=>'ok']);
    }
    if ($route==='nearby' && $method==='GET') {
        if ($self['lat']===null) reply(409,['error'=>'send_telemetry_first']);
        $out=[];
        foreach ($store->sessions() as $other) {
            if (($other['key']??'')===$key || !isset($other['lat'],$other['lon'])) continue;
            $d=distance($self['lat'],$self['lon'],$other['lat'],$other['lon']);
            if ($d<=(float)$config['radius_m']) $out[]=['id'=>$other['id'],'distance_m'=>round($d,1),'telemetry'=>$other['telemetry']];
        }
        reply(200,['participants'=>$out,'radius_m'=>$config['radius_m']]);
    }
    if ($route==='heartbeat' && $method==='POST') {
        $store->put($key,$self,(int)$config['session_ttl']);
        reply(200,['status'=>'ok','expires_in'=>(int)$config['session_ttl']]);
    }
    if ($route==='events' && $method==='POST') {
        if ($self['lat']===null) reply(409,['error'=>'send_telemetry_first']);
        $v=body(); $v['lat']=$self['lat']; $v['lon']=$self['lon'];
        $id=$store->appendEvent($key,$v); reply(201,['id'=>$id]);
    }
    if ($route==='events' && $method==='GET') {
        if ($self['lat']===null) reply(409,['error'=>'send_telemetry_first']);
        $after=max(0,(int)($_GET['after']??0)); $out=[];
        foreach ($store->events($after) as $e) {
            if ($e['sender']===$key) continue;
            $sender=$store->get($e['sender']);
            if (!$sender || !isset($sender['lat'],$sender['lon'])) continue;
            if (distance($self['lat'],$self['lon'],$sender['lat'],$sender['lon'])<=(float)$config['radius_m'])
                $out[]=['id'=>$e['id'],'sender_id'=>$sender['id'],'event'=>$e['data']];
        }
        reply(200,['events'=>$out]);
    }
    reply(404,['error'=>'unknown_endpoint']);
} catch (Throwable $e) {
    error_log('Drone API: '.$e->getMessage());
    reply(500,['error'=>'server_error']);
}
