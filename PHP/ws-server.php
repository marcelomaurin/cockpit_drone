<?php
declare(strict_types=1);
if (PHP_SAPI !== 'cli') { http_response_code(404); exit; }
require __DIR__.'/vendor/autoload.php';
require __DIR__.'/storage.php';
require __DIR__.'/MultiplayerSocket.php';
$config=require __DIR__.'/config.php';
if ($config['storage']==='apcu') throw new RuntimeException('Use files or mysql to share REST and WS sessions');
$loop=React\EventLoop\Loop::get();
$app=new MultiplayerSocket(createStore($config),$config);
$ws=new Ratchet\WebSocket\WsServer($app);
$ws->enableKeepAlive($loop,30);
$socket=new React\Socket\SocketServer($config['ws_listen']??'127.0.0.1:8081',[], $loop);
$server=new Ratchet\Server\IoServer(new Ratchet\Http\HttpServer($ws),$socket,$loop);
$loop->addPeriodicTimer(0.2,fn()=>$app->tick()); // REST updates and session expiry
fwrite(STDOUT,"Cockpit Drone WebSocket ready\n");
$loop->run();
