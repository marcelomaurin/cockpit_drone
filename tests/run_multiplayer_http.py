"""Exercise the compiled Pascal worker against a local HTTP fixture (not PHP)."""
import http.server
import json
import subprocess
import sys
import threading

class Handler(http.server.BaseHTTPRequestHandler):
    connections = 0
    polls = 0
    disconnects = 0
    def log_message(self, *args): pass
    def answer(self, code, value):
        data = json.dumps(value).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def do_POST(self):
        value = json.loads(self.rfile.read(int(self.headers.get('Content-Length', 0))) or b'{}')
        if self.path == '/connect':
            Handler.connections += 1
            return self.answer(201, {'token': str(Handler.connections)*64})
        if self.path == '/telemetry':
            assert value['lat'] == -21.17 and value['state'] == 'simulation'
            assert self.headers['Authorization'].startswith('Bearer ')
            return self.answer(200, {'status':'ok'})
        if self.path == '/disconnect':
            Handler.disconnects += 1
            return self.answer(200, {'status':'disconnected'})
        self.answer(404,{})
    def do_GET(self):
        assert self.path == '/nearby'
        Handler.polls += 1
        if Handler.polls == 2:
            return self.answer(401, {'error':'invalid_or_expired_token'})
        self.answer(200, {'participants':[{'id':'peer','distance_m':10,
            'telemetry':{'lat':-21.17,'lon':-47.81,'altitude_m':12}}]})

with http.server.ThreadingHTTPServer(('127.0.0.1',0), Handler) as server:
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        subprocess.run([sys.argv[1], f'http://127.0.0.1:{server.server_port}'],check=True,timeout=20)
        assert Handler.connections == 2, Handler.connections
        assert Handler.disconnects == 1, Handler.disconnects
        print('PASS: two sessions and explicit disconnect verified by server')
    finally:
        server.shutdown()
