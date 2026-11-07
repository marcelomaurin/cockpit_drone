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
        for name in ('index.php','api.php','storage.php','schema.sql','config_sample.php','home.html'):
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

                # Testes do protocolo do simulador (api.php)
                status,data=request('/api.php')
                assert status==200 and data.get('ok') is True and data.get('versao')==1 and 'raio_m' in data, (status,data)

                def post_json(path, payload, token=None):
                    body = json.dumps(payload).encode('utf-8')
                    headers = {'Content-Type': 'application/json'}
                    if token:
                        headers['Authorization'] = f'Bearer {token}'
                    req = urllib.request.Request(f'http://127.0.0.1:{port}' + path, data=body, headers=headers)
                    try:
                        resp = urllib.request.urlopen(req, timeout=3)
                    except urllib.error.HTTPError as e:
                        resp = e
                    with resp:
                        content = resp.read().decode('utf-8')
                        return resp.status, json.loads(content) if 'application/json' in resp.headers.get('Content-Type','') else content

                # Entrar via api.php
                st_entrar, resp_entrar = post_json('/api.php', {'versao': 1, 'acao': 'entrar', 'apelido': 'Piloto1', 'modelo': 'tello', 'posicao': {'lat': -21.17, 'lon': -47.82, 'alt': 5.0}})
                assert st_entrar == 200 and resp_entrar.get('ok') is True, (st_entrar, resp_entrar)
                tok = resp_entrar['token']
                id1 = resp_entrar['id']
                assert len(tok) == 64 and len(id1) == 16

                # Atualizar via api.php
                st_upd, resp_upd = post_json('/api.php', {'versao': 1, 'acao': 'atualizar', 'posicao': {'lat': -21.17, 'lon': -47.82, 'alt': 12.0}, 'rumo': 90, 'velocidade': 4.0, 'estado': 'voando', 'ultimo_evento': 0}, token=tok)
                assert st_upd == 200 and resp_upd.get('ok') is True and 'vizinhos' in resp_upd and 'eventos' in resp_upd, (st_upd, resp_upd)

                # Evento via api.php
                st_ev, resp_ev = post_json('/api.php', {'versao': 1, 'acao': 'evento', 'tipo': 'mensagem', 'conteudo': 'O mundo compartilhado funciona!'}, token=tok)
                assert st_ev == 200 and resp_ev.get('ok') is True, (st_ev, resp_ev)

                # Entrar via fallback /index.php com acao
                st_fb, resp_fb = post_json('/index.php', {'versao': 1, 'acao': 'entrar', 'apelido': 'Piloto2', 'modelo': 'cx10w'})
                assert st_fb == 200 and resp_fb.get('ok') is True and 'token' in resp_fb, (st_fb, resp_fb)

                # Sair via api.php
                st_sair, resp_sair = post_json('/api.php', {'versao': 1, 'acao': 'sair'}, token=tok)
                assert st_sair == 200 and resp_sair.get('ok') is True, (st_sair, resp_sair)
                (root/'config.php').write_text('<?php return false;')
                status,data=request('/health')
                assert status==500 and data=={'error':'server_error'},(status,data)
                print('PASS: Portuguese homepage with/without config; JSON health; unknown route 404; controlled configuration errors')
            finally:
                process.terminate(); process.wait(timeout=5)

if __name__=='__main__': main()
