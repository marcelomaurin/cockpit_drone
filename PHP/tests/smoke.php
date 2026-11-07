<?php
declare(strict_types=1);
/**
 * Smoke test for deployed/local API. Run:
 *   php PHP/tests/smoke.php https://example.com/PHP
 * Requires PHP curl extension. Uses two independent sessions.
 */
$base = rtrim($argv[1] ?? '', '/');
if (!filter_var($base, FILTER_VALIDATE_URL)) {
    fwrite(STDERR, "Usage: php smoke.php https://host/PHP\n");
    exit(2);
}
function callApi(string $base, string $method, string $path, ?string $token=null, ?array $body=null): array {
    $ch=curl_init($base.$path);
    $headers=['Accept: application/json'];
    if ($token!==null) $headers[]='Authorization: Bearer '.$token;
    if ($body!==null) $headers[]='Content-Type: application/json';
    curl_setopt_array($ch,[
        CURLOPT_RETURNTRANSFER=>true,
        CURLOPT_CUSTOMREQUEST=>$method,
        CURLOPT_HTTPHEADER=>$headers,
        CURLOPT_TIMEOUT=>10,
        CURLOPT_POSTFIELDS=>$body!==null?json_encode($body,JSON_THROW_ON_ERROR):null,
    ]);
    $raw=curl_exec($ch);
    if ($raw===false) throw new RuntimeException(curl_error($ch));
    $status=curl_getinfo($ch,CURLINFO_HTTP_CODE);
    curl_close($ch);
    $json=json_decode($raw,true);
    if (!is_array($json)) throw new RuntimeException("Non-JSON response: $status ".substr($raw,0,200));
    return [$status,$json];
}
function expect(bool $ok, string $message): void {
    if (!$ok) throw new RuntimeException("FAIL: $message");
    echo "PASS: $message\n";
}
try {
    [$status,$health]=callApi($base,'GET','/health');
    expect($status===200 && ($health['status']??'')==='ok','health');
    [$s,$a]=callApi($base,'POST','/connect');
    [$t,$b]=callApi($base,'POST','/connect');
    expect($s===201 && $t===201 && isset($a['token'],$b['token']) && $a['token']!==$b['token'],'unique session tokens');
    $ta=$a['token']; $tb=$b['token'];
    [$s]=callApi($base,'GET','/nearby',$ta);
    expect($s===409,'telemetry required before nearby');
    [$s]=callApi($base,'POST','/telemetry',$ta,['lat'=>-21.1700,'lon'=>-47.8100,'alt'=>10]);
    expect($s===200,'telemetry A');
    [$s]=callApi($base,'POST','/telemetry',$tb,['lat'=>-21.1710,'lon'=>-47.8100,'alt'=>11]);
    expect($s===200,'telemetry B');
    [$s,$near]=callApi($base,'GET','/nearby',$ta);
    expect($s===200 && count($near['participants']??[])===1,'nearby 2 km includes B');
    [$s,$ev]=callApi($base,'POST','/events',$tb,['type'=>'ping','payload'=>'smoke']);
    expect($s===201 && isset($ev['id']),'event publish');
    [$s,$evs]=callApi($base,'GET','/events?after=0',$ta);
    expect($s===200 && count($evs['events']??[])>=1,'event received');
    [$s]=callApi($base,'POST','/telemetry',$tb,['lat'=>-22.0000,'lon'=>-47.8100]);
    expect($s===200,'move B away');
    [$s,$near]=callApi($base,'GET','/nearby',$ta);
    expect($s===200 && count($near['participants']??[])===0,'2 km radius excludes B');
    [$s]=callApi($base,'POST','/disconnect',$ta);
    expect($s===200,'disconnect');
    [$s]=callApi($base,'GET','/nearby',$ta);
    expect($s===401,'revoked token denied');
    callApi($base,'POST','/disconnect',$tb);
    echo "Smoke test completed.\n";
} catch (Throwable $e) {
    fwrite(STDERR,$e->getMessage()."\n");
    exit(1);
}
