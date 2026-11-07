<?php
declare(strict_types=1);
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');
header('X-Content-Type-Options: nosniff');
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
// The welcome page is available even before configuring storage.
$path = rtrim((string)parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH), '/');
$route = basename($path);
$scriptDir = rtrim(str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '/index.php')), '/');
$isHome = $path === '' || $route === 'index.php' || $path === $scriptDir;
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
if ($isHome && in_array($method, ['GET', 'HEAD'], true)) {
    header('Content-Type: text/html; charset=utf-8');
    if ($method === 'GET') readfile(__DIR__ . '/home.html');
    exit;
}

// Tutorial do simulador e do cockpit
if (($route === 'tutorial.php' || $route === 'tutorial') && in_array($method, ['GET', 'HEAD'], true)) {
    header('Content-Type: text/html; charset=utf-8');
    if ($method === 'GET') require __DIR__ . '/tutorial.php';
    exit;
}

// Se for requisição ao endpoint de mundo compartilhado do simulador (api.php ou POST com ação no corpo)
if ($route === 'api.php' || $route === 'api') {
    require __DIR__ . '/api.php';
    exit;
}
if ($method === 'POST' && ($isHome || $route === 'index.php')) {
    $rawPeek = file_get_contents('php://input', false, null, 0, 512);
    if ($rawPeek && str_contains($rawPeek, '"acao"')) {
        require __DIR__ . '/api.php';
        exit;
    }
}

try {
    $configFile = __DIR__ . '/config.php';
    if (!is_file($configFile)) reply(503, [
        'error'=>'configuration_required',
        'message'=>'Copie config_sample.php para config.php e configure o ambiente.'
    ]);
    $config = require $configFile;
    if (!is_array($config)) throw new RuntimeException('Invalid configuration');
    require_once __DIR__ . '/storage.php';
    $storage=$config['storage'];
    $store=createStore($config);
    $allowedRoutes=['health','connect','telemetry','nearby','events','disconnect','heartbeat'];
    if (!in_array($route,$allowedRoutes,true)) reply(404,['error'=>'unknown_endpoint']);
    $method=$_SERVER['REQUEST_METHOD']??'GET';
    if ($route==='health' && $method==='GET') reply(200,['status'=>'ok','storage'=>$storage]);
    if ($route==='connect' && $method==='POST') {
        $ip = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';
        $maxSessions = (int)($config['max_active_sessions'] ?? 100);
        $rateLimit = (int)($config['rate_limit_per_minute'] ?? 15);
        $activeSessions = count($store->sessions());
        if ($activeSessions >= $maxSessions) {
            reply(503, ['error' => 'max_sessions_reached', 'message' => 'Capacidade maxima de sessoes ativas atingida.']);
        }
        $ipHash = hash('sha256', 'ip_' . $ip);
        $rateKey = 'ratelimit_' . $ipHash;
        $rateData = $store->get($rateKey) ?? ['count' => 0, 'window' => time()];
        if (time() - ($rateData['window'] ?? 0) < 60) {
            if (($rateData['count'] ?? 0) >= $rateLimit) {
                reply(429, ['error' => 'rate_limit_exceeded', 'message' => 'Muitas tentativas de conexao. Aguarde 1 minuto.']);
            }
            $rateData['count'] = ($rateData['count'] ?? 0) + 1;
        } else {
            $rateData = ['count' => 1, 'window' => time()];
        }
        $store->put($rateKey, $rateData, 60);

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
        $self['updated_at']=time();
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
        $v=body();
        if (!isset($v['type']) || !is_string($v['type']) || !preg_match('/^[a-zA-Z0-9_.-]{1,64}$/',$v['type']))
            reply(400,['error'=>'invalid_event_type']);
        $v['lat']=$self['lat']; $v['lon']=$self['lon'];
        $id=$store->appendEvent($key,$v); reply(201,['id'=>$id]);
    }
    if ($route==='events' && $method==='GET') {
        if ($self['lat']===null) reply(409,['error'=>'send_telemetry_first']);
        $afterRaw=$_GET['after']??'0';
        if (!is_string($afterRaw) || !preg_match('/^[0-9]{1,19}$/',$afterRaw))
            reply(400,['error'=>'invalid_event_cursor']);
        $after=(int)$afterRaw; $out=[];
        foreach ($store->events($after) as $e) {
            if ($e['sender']===$key) continue;
            $sender=$store->get($e['sender']);
            if (!$sender || !isset($e['data']['lat'],$e['data']['lon'])) continue;
            if (distance($self['lat'],$self['lon'],$e['data']['lat'],$e['data']['lon'])<=(float)$config['radius_m'])
                $out[]=['id'=>$e['id'],'sender_id'=>$sender['id'],'event'=>$e['data']];
        }
        $last=$after;
        foreach ($out as $event) $last=max($last,(int)$event['id']);
        reply(200,['events'=>$out,'next_after'=>$last]);
    }
    reply(404,['error'=>'unknown_endpoint']);
} catch (Throwable $e) {
    error_log('Drone API: '.$e->getMessage());
    reply(500,['error'=>'server_error']);
}
