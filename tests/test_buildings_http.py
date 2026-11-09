"""Exercise the actual Pascal loader over loopback, including its disk cache."""
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest
from urllib.parse import parse_qs
from http.server import BaseHTTPRequestHandler, HTTPServer


@unittest.skipUnless(os.environ.get('COCKPIT_BUILDINGS_LOADER_EXE'), 'Pascal simulator loader executable not configured')
class BuildingHTTPTests(unittest.TestCase):
    def test_post_geometry_and_cache(self):
        fixture = (Path(__file__).parent / 'fixtures/osm_buildings.json').read_bytes()
        requests = []

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                requests.append(body)
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(fixture)))
                self.end_headers()
                self.wfile.write(fixture)

            def log_message(self, *args):
                pass

        server = HTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.serve_forever)
        thread.start()
        try:
            with tempfile.TemporaryDirectory() as cache:
                result = subprocess.run([
                    os.environ['COCKPIT_BUILDINGS_LOADER_EXE'],
                    f'http://127.0.0.1:{server.server_port}/api/interpreter', cache, 'http'
                ], capture_output=True, text=True, timeout=15)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(len(requests), 1, 'Reload must read the disk cache')
                self.assertIn(b'data=', requests[0])
                query = parse_qs(requests[0].decode())['data'][0]
                self.assertIn('out geom', query)
                self.assertIn('["highway"]', query)
                self.assertIn('["landuse"]', query)
        finally:
            server.shutdown()
            thread.join()
            server.server_close()


if __name__ == '__main__':
    unittest.main()
