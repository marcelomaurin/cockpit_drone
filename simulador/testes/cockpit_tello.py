"""Faz o papel do TAIDroneTello do cockpit contra o simulador (127.0.0.1)."""
import socket, time, sys
cmd = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); cmd.settimeout(1)
est = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); est.bind(("0.0.0.0", 8890)); est.settimeout(1)
alvo = ("127.0.0.1", 8889)
def envia(t, resp=True):
    cmd.sendto(t.encode(), alvo)
    if resp:
        r = cmd.recvfrom(1024)[0].decode()
        print(f"{t} -> {r}"); return r
envia("command")
print("estado:", est.recvfrom(1024)[0].decode().strip()[:80])
envia("takeoff"); time.sleep(3)
t0 = time.time()
while time.time() - t0 < 3:
    envia("rc 0 60 0 0", resp=False); time.sleep(0.05)
envia("rc 0 0 0 0", resp=False)
e = est.recvfrom(1024)[0].decode().strip(); print("estado em voo:", e[:120])
envia("battery?")
envia("land"); time.sleep(4)
print("estado final:", est.recvfrom(1024)[0].decode().strip()[:120])
