"""Exercise the real optional video decoder against a local MJPEG stream."""
import http.server, pathlib, subprocess, sys, threading, time
exe, ffmpeg, fixture, output = sys.argv[1:]
output = pathlib.Path(output).resolve(); output.mkdir(parents=True, exist_ok=True)
jpeg = output / 'fpv-fixture.jpg'
subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-i', fixture, '-frames:v', '1', '-y', str(jpeg)], check=True)
data = jpeg.read_bytes()
class Handler(http.server.BaseHTTPRequestHandler):
 def do_GET(self):
  self.send_response(200); self.send_header('Content-Type','multipart/x-mixed-replace; boundary=frame'); self.end_headers()
  try:
   for _ in range(200):
    self.wfile.write(b'--frame\r\nContent-Type: image/jpeg\r\nContent-Length: '+str(len(data)).encode()+b'\r\n\r\n'+data+b'\r\n');self.wfile.flush();time.sleep(.1)
  except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError): pass
 def log_message(self, *args): pass
server = http.server.ThreadingHTTPServer(('127.0.0.1',0),Handler); server.daemon_threads=True
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
 subprocess.run([exe, f'http://127.0.0.1:{server.server_port}/video', ffmpeg, str(output/'url-frame.bmp')], check=True, timeout=25)
finally: server.shutdown();server.server_close()
