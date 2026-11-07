"""HTTP entrypoint regression checks using an isolated PHP config and storage."""
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

ROOT=Path(__file__).resolve().parents[1]

def main():
    php=str(Path(sys.argv[1]).resolve())
    with tempfile.TemporaryDirectory(prefix='cockpit-entrypoint-') as directory:
        root=Path(directory)
        for name in ('index.php','storage.php','schema.sql','config_sample.php','home.html'):
            shutil.copyfile(ROOT/'PHP'/name,root/name)
        with socket.socket() as s:
            s.bind(('127.0.0.1',0)); port=s.getsockname()[1]
        env=dict(os.environ,DRONE_STORAGE='files',DRONE_DATA_DIR=str(root/'data'))
        with open(root/'php.log','w+') as log:
            process=subprocess.Popen([php,'-S',f'127.0.0.1:{port}','index.php'],cwd=root,env=env,stdout=log,stderr=log)
            def request(path):
                try: response=urllib.request.urlopen(f'http://127.0.0.1:{port}'+path,timeout=3)
                except urllib.error.HTTPError as e: response=e
                with response:
                    content=response.read().decode('utf-8')
                    data=json.loads(content) if 'application/json' in response.headers.get('Content-Type','') else content
                    return response.status,data
            try:
                for _ in range(50):
                    try: status,data=request('/health'); break
                    except urllib.error.URLError: time.sleep(.1)
                else: raise AssertionError('PHP did not start')
                assert status==503 and data['error']=='configuration_required',(status,data)
                status,data=request('/index.php')
                assert status==200 and '<html lang="pt-BR">' in data
                shutil.copyfile(root/'config_sample.php',root/'config.php')
                for path in ('/','/index.php','/PHP/index.php'):
                    status,data=request(path)
                    assert status==200 and 'Entrar multiplayer' in data and 'php ws-server.php' in data,(path,status)
                status,data=request('/health')
                assert status==200 and data['status']=='ok'
                status,data=request('/unknown')
                assert status==404 and data['error']=='unknown_endpoint'
                (root/'config.php').write_text('<?php return false;')
                status,data=request('/health')
                assert status==500 and data=={'error':'server_error'},(status,data)
                print('PASS: Portuguese homepage with/without config; JSON health; unknown route 404; controlled configuration errors')
            finally:
                process.terminate(); process.wait(timeout=5)

if __name__=='__main__': main()
