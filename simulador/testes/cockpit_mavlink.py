"""Estação de solo mínima (como o TAIDroneMavlink): escuta 14550, arma, decola, rota e RTL."""
import time, sys
from pymavlink import mavutil
m = mavutil.mavlink_connection("udpin:0.0.0.0:14550", source_system=255, source_component=190, dialect="ardupilotmega")
m.mav = mavutil.mavlink.MAVLink(m, srcSystem=255, srcComponent=190); m.mav.WIRE_PROTOCOL_VERSION = "1.0"
hb = m.wait_heartbeat(timeout=5); print("HEARTBEAT", hb.type, hb.autopilot, hb.custom_mode, "sys", m.target_system)
def hb_gcs(): m.mav.heartbeat_send(6, 8, 0, 0, 4)
def cmd(c, *p):
    p = list(p) + [0]*(7-len(p))
    m.mav.command_long_send(1, 1, c, 0, *p)
    a = m.recv_match(type="COMMAND_ACK", blocking=True, timeout=3)
    print("ACK", c, a.result if a else None)
def espera(seg):
    t = time.time()
    while time.time() - t < seg:
        hb_gcs()
        msg = m.recv_match(type=["GLOBAL_POSITION_INT","STATUSTEXT","MISSION_ITEM_REACHED"], blocking=True, timeout=1)
        if msg and msg.get_type() == "STATUSTEXT": print("TXT", msg.text)
        if msg and msg.get_type() == "MISSION_ITEM_REACHED": print("ALCANCOU", msg.seq)
    p = m.recv_match(type="GLOBAL_POSITION_INT", blocking=True, timeout=2)
    print(f"POS alt={p.relative_alt/1000:.1f} lat={p.lat/1e7:.6f} lon={p.lon/1e7:.6f}")
hb_gcs()
st = m.recv_match(type="SYS_STATUS", blocking=True, timeout=3); print("BATERIA", st.battery_remaining)
cmd(176, 1, 4)        # GUIDED
cmd(400, 1)           # armar
cmd(22, 0,0,0,0,0,0, 10)  # decolar 10 m
espera(9)
# rota: 0 home, 1 takeoff, 2 waypoint 60 m ao norte, 3 RTL
lat0, lon0 = -21.1767, -47.8208
itens = [(16,0,lat0,lon0,0),(22,3,lat0,lon0,10),(16,3,lat0+0.00054,lon0,12),(20,2,0,0,0)]
m.mav.mission_count_send(1, 1, len(itens))
enviados = 0
while enviados < len(itens):
    r = m.recv_match(type=["MISSION_REQUEST_INT","MISSION_REQUEST","MISSION_ACK"], blocking=True, timeout=3)
    if r is None: print("sem pedido"); sys.exit(1)
    if r.get_type() == "MISSION_ACK": break
    c, f, la, lo, al = itens[r.seq]
    m.mav.mission_item_int_send(1, 1, r.seq, f, c, 0, 1, 0, 2, 0, 0, int(la*1e7), int(lo*1e7), al)
    enviados += 1
a = m.recv_match(type="MISSION_ACK", blocking=True, timeout=3); print("MISSION_ACK", a.type if a else None)
cmd(300, 0, 0)
espera(25)
espera(10)
hb2 = m.recv_match(type="HEARTBEAT", blocking=True, timeout=3); print("FIM modo", hb2.custom_mode, "armado", bool(hb2.base_mode & 128))
