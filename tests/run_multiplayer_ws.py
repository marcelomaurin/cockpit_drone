"""Real PHP REST + Ratchet integration, isolated config/storage. Requires websockets>=14.
Usage: python tests/run_multiplayer_ws.py /path/php [native_test.exe]
Run composer install in PHP/ first. No production config is read or overwritten.
"""
import json
import os
from pathlib import Path
import queue
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
from websockets.sync.client import connect

ROOT = Path(__file__).resolve().parents[1]

def port():
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]

def receive(ws, predicate, timeout=5):
    end=time.monotonic()+timeout
    while time.monotonic()<end:
        v=json.loads(ws.recv(timeout=max(.01,end-time.monotonic())))
        if predicate(v): return v
    raise AssertionError('Expected message not received')

def snapshot(ws, count):
    return receive(ws, lambda v: v.get('type')=='snapshot' and len(v['participants'])==count)

def telemetry(ws, lat=-21.17):
    ws.send(json.dumps({'type':'telemetry','telemetry':{'lat':lat,'lon':-47.81,'altitude_m':10}}))

def rest(base, route, token=None, body=None):
    headers={'Content-Type':'application/json'}
    if token: headers['Authorization']='Bearer '+token
    data=json.dumps(body).encode() if body is not None else None
    with urllib.request.urlopen(urllib.request.Request(base+'/'+route,data=data,headers=headers),timeout=5) as r:
        return json.load(r)

def main():
    php=str(Path(sys.argv[1]).resolve())
    native=str(Path(sys.argv[2]).resolve()) if len(sys.argv)>2 else None
    with tempfile.TemporaryDirectory(prefix='cockpit-ws-') as tmp:
        tmp=Path(tmp); app=tmp/'PHP'
        shutil.copytree(ROOT/'PHP',app,ignore=shutil.ignore_patterns('config.php'))
        shutil.copyfile(app/'config_sample.php',app/'config.php')
        wsport,httpport=port(),port()
        env=dict(os.environ,DRONE_STORAGE='files',DRONE_DATA_DIR=str(tmp/'data'),
                 DRONE_WS_LISTEN=f'127.0.0.1:{wsport}',DRONE_WS_ORIGINS='https://allowed.example')
        base=f'http://127.0.0.1:{httpport}'; url=f'ws://127.0.0.1:{wsport}'
        children=[]
        with open(tmp/'server.log','w+') as log:
            try:
                for args in ([php,'ws-server.php'],[php,'-S',f'127.0.0.1:{httpport}','-t','.', 'index.php']):
                    children.append(subprocess.Popen(args,cwd=app,env=env,stdout=log,stderr=log))
                for _ in range(60):
                    try:
                        rest(base,'health')
                        with socket.create_connection(('127.0.0.1',wsport),timeout=.2): pass
                        break
                    except OSError: time.sleep(.1)
                else: raise AssertionError('Server startup failed')
                subprocess.run([php, str(app/'tests/smoke.php'), base],check=True,timeout=20)
                with connect(url) as a, connect(url) as b:
                    ca=receive(a,lambda v:v.get('type')=='connected')
                    cb=receive(b,lambda v:v.get('type')=='connected')
                    assert ca['token']!=cb['token']
                    telemetry(a); telemetry(b)
                    assert snapshot(a,1)['participants'][0]['id']==cb['id']
                    snapshot(b,1)
                    telemetry(b,-22)
                    snapshot(a,0); snapshot(b,0)
                    telemetry(b); snapshot(a,1); snapshot(b,1)
                    a.send(json.dumps({'type':'event','event':{'type':'simulation.test','payload':{'value':1}}}))
                    events=receive(b,lambda v:v.get('type')=='events')
                    assert events['events'][0]['sender_id']==ca['id']
                    a.send('{bad')
                    receive(a,lambda v:v.get('type')=='error')
                    telemetry(a,91)
                    receive(a,lambda v:v.get('type')=='error')
                    telemetry(a)
                    token=rest(base,'connect',body={})['token']
                    rest(base,'telemetry',token,{'lat':-21.17,'lon':-47.81,'altitude_m':20})
                    snapshot(a,2)
                    assert len(rest(base,'nearby',token)['participants'])==2
                    rest(base,'disconnect',token,{})
                    snapshot(a,1)
                    b.close(); snapshot(a,0)
                    rest(base,'disconnect',ca['token'],{})
                    try:
                        while True: a.recv(timeout=3)
                    except Exception as e:
                        from websockets.exceptions import ConnectionClosed
                        assert isinstance(e,ConnectionClosed),type(e)
                print('PASS: PHP WS peers, range filtering, events, invalid input, REST interoperability, revocation')
                with connect(url,origin='https://denied.example') as denied:
                    from websockets.exceptions import ConnectionClosed
                    try: denied.recv(timeout=3); raise AssertionError('Origin accepted')
                    except ConnectionClosed: pass
                print('PASS: unauthorized browser origin rejected')
                if native:
                    with connect(url) as peer:
                        receive(peer,lambda v:v.get('type')=='connected'); telemetry(peer)
                        p=subprocess.Popen([native,url],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
                        children.append(p); lines=queue.Queue()
                        def read():
                            for line in p.stdout: lines.put(line.strip())
                        threading.Thread(target=read,daemon=True).start()
                        assert lines.get(timeout=10)=='SEEN'
                        telemetry(peer,-22)
                        assert lines.get(timeout=10)=='CLEARED'
                        telemetry(peer)
                        assert p.wait(timeout=10)==0
                        print(lines.get(timeout=2))
                    # Restart the real WS process while the native client is running.
                    with connect(url) as peer:
                        receive(peer,lambda v:v.get('type')=='connected'); telemetry(peer)
                        p=subprocess.Popen([native,url],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
                        children.append(p); lines=queue.Queue()
                        threading.Thread(target=read,daemon=True).start()
                        assert lines.get(timeout=10)=='SEEN'
                        children[0].terminate(); children[0].wait(timeout=5)
                        assert lines.get(timeout=10)=='CLEARED'
                        time.sleep(3) # includes a refused reconnect attempt
                        server=subprocess.Popen([php,'ws-server.php'],cwd=app,env=env,stdout=log,stderr=log)
                        children.append(server)
                        for _ in range(50):
                            try:
                                with socket.create_connection(('127.0.0.1',wsport),timeout=.2): pass
                                break
                            except OSError: time.sleep(.1)
                        with connect(url) as replacement:
                            receive(replacement,lambda v:v.get('type')=='connected'); telemetry(replacement)
                            assert p.wait(timeout=15)==0
                            print(lines.get(timeout=2))
                        print('PASS: native client reconnects after PHP process restart')
                print('PASS: real PHP integration completed')
            except BaseException:
                log.flush(); log.seek(0); print(log.read()[-10000:]); raise
            finally:
                for p in reversed(children):
                    if p.poll() is None: p.terminate()
                    try: p.wait(timeout=5)
                    except subprocess.TimeoutExpired: p.kill(); p.wait()

if __name__=='__main__': main()
