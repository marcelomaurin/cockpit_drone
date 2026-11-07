<?php
declare(strict_types=1);

use Ratchet\ConnectionInterface;
use Ratchet\MessageComponentInterface;

final class MultiplayerSocket implements MessageComponentInterface {
    private SplObjectStorage $clients;
    public function __construct(private Store $store, private array $config) {
        $this->clients = new SplObjectStorage();
    }
    public function onOpen(ConnectionInterface $conn) {
        $allowed = $this->config['ws_origins'] ?? [];
        $origin = $conn->httpRequest->getHeaderLine('Origin');
        if ($origin !== '' && !in_array($origin, $allowed, true)) { $conn->close(); return; }
        if (count($this->clients) >= 100) { $conn->close(); return; }
        $token = bin2hex(random_bytes(32));
        $key = hash('sha256', $token);
        try {
            $this->store->put($key, ['id'=>substr($key,0,16), 'key'=>$key,
                'lat'=>null, 'lon'=>null, 'telemetry'=>[]], (int)$this->config['session_ttl']);
            $this->clients[$conn] = ['key'=>$key, 'last'=>'', 'sent'=>0.0,
                'after'=>0, 'window'=>microtime(true), 'count'=>0];
            $this->send($conn, ['type'=>'connected', 'token'=>$token,
                'id'=>substr($key,0,16), 'radius_m'=>$this->config['radius_m']]);
        } catch (Throwable $e) { $this->onError($conn, $e); }
    }
    private function send(ConnectionInterface $conn, array $data): void {
        $conn->send(json_encode($data, JSON_THROW_ON_ERROR | JSON_INVALID_UTF8_SUBSTITUTE));
    }
    private function number(array $v, string $key, float $min, float $max): float {
        $n=$v[$key]??null;
        if ((!is_int($n) && !is_float($n)) || !is_finite((float)$n) || $n<$min || $n>$max)
            throw new InvalidArgumentException('invalid_'.$key);
        return (float)$n;
    }
    public function onMessage(ConnectionInterface $from, $msg) {
        if (!$this->clients->contains($from)) return;
        try {
            if (strlen($msg)>65536) { $from->close(); return; }
            $meta=$this->clients[$from]; $now=microtime(true);
            if ($now-$meta['window']>=1) { $meta['window']=$now; $meta['count']=0; }
            if (++$meta['count']>20) { $from->close(); return; }
            $this->clients[$from]=$meta;
            $v=json_decode($msg,true,32,JSON_THROW_ON_ERROR);
            if (!is_array($v) || array_is_list($v)) throw new InvalidArgumentException('invalid_object');
            $self=$this->store->get($meta['key']);
            if (!$self) { $this->send($from,['type'=>'error','code'=>'session_expired']); $from->close(); return; }
            switch ($v['type']??'') {
                case 'telemetry':
                    $t=$v['telemetry']??null;
                    if (!is_array($t)) throw new InvalidArgumentException('invalid_telemetry');
                    $lat=$this->number($t,'lat',-90,90); $lon=$this->number($t,'lon',-180,180);
                    $alt=$this->number($t,'altitude_m',-10000,100000);
                    if (isset($t['name']) && (!is_string($t['name']) || strlen($t['name'])>64))
                        throw new InvalidArgumentException('invalid_name');
                    $self['lat']=$lat; $self['lon']=$lon; $self['updated_at']=time();
                    $self['telemetry']=['lat'=>$lat,'lon'=>$lon,'altitude_m'=>$alt,'state'=>'simulation',
                        'name'=>$t['name']??$self['id']];
                    $this->store->put($meta['key'],$self,(int)$this->config['session_ttl']);
                    $this->tick(); // push movement to all eligible sockets immediately
                    break;
                case 'event':
                    if ($self['lat']===null) throw new InvalidArgumentException('send_telemetry_first');
                    $e=$v['event']??null;
                    if (!is_array($e) || !is_string($e['type']??null) ||
                        !preg_match('/^[a-zA-Z0-9_.-]{1,64}$/',$e['type']))
                        throw new InvalidArgumentException('invalid_event');
                    $e['lat']=$self['lat']; $e['lon']=$self['lon'];
                    $id=$this->store->appendEvent($meta['key'],$e);
                    $this->send($from,['type'=>'event_ack','id'=>$id]); $this->tick(); break;
                case 'heartbeat':
                    $this->store->put($meta['key'],$self,(int)$this->config['session_ttl']);
                    $this->send($from,['type'=>'heartbeat']); break;
                case 'disconnect': $from->close(); break;
                default: throw new InvalidArgumentException('unknown_type');
            }
        } catch (JsonException|InvalidArgumentException $e) {
            $this->send($from,['type'=>'error','code'=>'invalid_message']);
        } catch (Throwable $e) { $this->onError($from,$e); }
    }
    public function tick(): void {
        try { $sessions=$this->store->sessions(); }
        catch (Throwable $e) {
            error_log('WebSocket storage unavailable');
            foreach (clone $this->clients as $c) $c->close();
            return;
        }
        $active=[]; foreach ($sessions as $s) $active[$s['key']]=$s;
        foreach (clone $this->clients as $c) {
            if (!$this->clients->contains($c)) continue;
            try {
                $meta=$this->clients[$c]; $self=$active[$meta['key']]??null;
                if (!$self) { $c->close(); continue; }
                $out=[];
                if (isset($self['lat'],$self['lon'])) foreach ($sessions as $other) {
                    if ($other['key']===$meta['key'] || !isset($other['lat'],$other['lon'])) continue;
                    $d=distance($self['lat'],$self['lon'],$other['lat'],$other['lon']);
                    if ($d<=(float)$this->config['radius_m'])
                        $out[]=['id'=>$other['id'],'distance_m'=>round($d,1),'telemetry'=>$other['telemetry']];
                }
                usort($out,fn($a,$b)=>strcmp($a['id'],$b['id']));
                $out=array_slice($out,0,100);
                $snapshot=json_encode($out,JSON_THROW_ON_ERROR|JSON_INVALID_UTF8_SUBSTITUTE);
                if ($snapshot!==$meta['last'] || microtime(true)-$meta['sent']>=1) {
                    $this->send($c,['type'=>'snapshot','participants'=>$out,'radius_m'=>$this->config['radius_m']]);
                    $meta['last']=$snapshot; $meta['sent']=microtime(true);
                }
                if (isset($self['lat'],$self['lon'])) {
                    $events=[];
                    foreach ($this->store->events($meta['after']) as $e) {
                        $meta['after']=max($meta['after'],(int)$e['id']);
                        if ($e['sender']===$meta['key'] || !isset($active[$e['sender']])) continue;
                        if (!isset($e['data']['lat'],$e['data']['lon'])) continue;
                        if (distance($self['lat'],$self['lon'],$e['data']['lat'],$e['data']['lon'])<=(float)$this->config['radius_m'])
                            $events[]=['id'=>$e['id'],'sender_id'=>$active[$e['sender']]['id'],'event'=>$e['data']];
                    }
                    if ($events) $this->send($c,['type'=>'events','events'=>$events,'next_after'=>$meta['after']]);
                }
                $this->clients[$c]=$meta;
            } catch (Throwable $e) { $this->onError($c,$e); }
        }
    }
    public function onClose(ConnectionInterface $conn) {
        if ($this->clients->contains($conn)) {
            $key=$this->clients[$conn]['key']; $this->clients->detach($conn);
            try { $this->store->remove($key); } catch (Throwable $e) { error_log('WebSocket cleanup failed'); }
        }
        $this->tick();
    }
    public function onError(ConnectionInterface $conn, \Throwable $e) {
        error_log('WebSocket connection failed: '.get_class($e));
        $conn->close();
    }
}
