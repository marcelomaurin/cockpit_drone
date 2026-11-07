"""Faz o papel dos componentes AR.Drone, FQ777/CX-10W, CDP (ESP32) e ESP-Drone do cockpit."""
import socket, struct, time, sys
modelo = sys.argv[1]
def crc16(b):
    c = 0xFFFF
    for x in b:
        c ^= x << 8
        for _ in range(8):
            c = ((c << 1) ^ 0x1021) & 0xFFFF if c & 0x8000 else (c << 1) & 0xFFFF
    return c
if modelo == "ardrone":
    at = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    nav = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); nav.bind(("0.0.0.0", 5554)); nav.settimeout(1)
    seq = 0
    def envia(t):
        at.sendto(t.encode(), ("127.0.0.1", 5556))
    def ciclo(seg, ref, pcmd):
        global seq
        t = time.time()
        while time.time() - t < seg:
            seq += 1; s = f"AT*REF={seq},{ref}\r"; seq += 1; s += pcmd.format(seq) + "\r"; envia(s); time.sleep(0.03)
    f = struct.unpack("<i", struct.pack("<f", -0.5))[0]   # arfagem -0,5 = para frente no AR.Drone
    ciclo(1, 0x11540000, "AT*PCMD={},0,0,0,0,0")
    ciclo(3, 0x11540200, "AT*PCMD={},0,0,0,0,0")
    ciclo(2, 0x11540200, "AT*PCMD={},1,0,%d,0,0" % f)
    ciclo(4, 0x11540000, "AT*PCMD={},0,0,0,0,0")
    d = nav.recvfrom(2048)[0]
    hdr, st, sq = struct.unpack_from("<III", d, 0)
    tag, tam, ctrl, bat, theta, phi, psi, alt = struct.unpack_from("<HHIIfffi", d, 16)
    print(f"navdata hdr={hdr:#x} estado={st:#x} bat={bat} alt_mm={alt} tamanho={len(d)}")
elif modelo in ("fq777", "cx10w"):
    tcp = socket.create_connection(("127.0.0.1", 8888), timeout=2); tcp.send(b"\x00" * 106)
    u = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    def pkt(r, p, a, g):
        b = [0xCC, r, p, a, g, 0]; x = 0
        for v in b[1:6]: x ^= v
        return bytes(b + [x, 0x33])
    for acel, seg in ((0, 0.5), (200, 2.0), (130, 2.0), (0, 2.5)):
        t = time.time()
        while time.time() - t < seg:
            u.sendto(pkt(127, 160, acel, 127), ("127.0.0.1", 8895)); time.sleep(0.05)
    print("fq777 enviado")
elif modelo == "esp32":
    u = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); u.settimeout(1)
    seq = 0
    def controle(r, p, y, a, flags):
        global seq
        seq += 1
        b = b"CD\x01\x01" + struct.pack("<H", seq) + struct.pack("<hhhHB", r, p, y, a, flags)
        return b + struct.pack("<H", crc16(b))
    def ciclo(seg, a, flags):
        t = time.time()
        while time.time() - t < seg:
            u.sendto(controle(0, 0, 0, a, flags), ("127.0.0.1", 4210)); time.sleep(0.03)
    ciclo(0.5, 0, 1); ciclo(2, 600, 1); ciclo(1.5, 450, 1)
    d = u.recvfrom(256)[0]
    print("telemetria", d[:4], "estado", d[6], "mV", struct.unpack_from("<H", d, 7)[0], "crc ok", crc16(d[:-2]) == struct.unpack_from("<H", d, len(d)-2)[0], "tam", len(d))
    ciclo(0.5, 0, 2)   # corte
    d = u.recvfrom(256)[0]; print("apos corte estado", d[6])
elif modelo == "espdrone":
    u = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); u.bind(("0.0.0.0", 2399)); u.settimeout(1)
    def cmd(r, p, y, t):
        b = bytes([0x3C]) + struct.pack("<fffH", r, -p, y, t)
        return b + bytes([sum(b) & 0xFF])
    for th, seg in ((0, 0.5), (45000, 2), (37000, 1.5)):
        t0 = time.time()
        while time.time() - t0 < seg:
            u.sendto(cmd(0, 5, 0, th), ("127.0.0.1", 2390)); time.sleep(0.02)
    print("resposta", u.recvfrom(64)[0].hex())
