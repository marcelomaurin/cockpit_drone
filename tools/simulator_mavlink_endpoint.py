#!/usr/bin/env python3
"""Virtual MAVLink v1 drone endpoint. Simulation only; no physical I/O.
UDP 14550 receives GCS messages; telemetry is sent to the last GCS peer.
UDP 14560 accepts local JSON state updates from the simulator.
"""
import argparse
import json
import math
import select
import socket
import struct
import time

CRC_EXTRA = {0: 50, 1: 124, 24: 24, 30: 39, 33: 104, 76: 152, 77: 143}
MAV_CMD_COMPONENT_ARM_DISARM = 400
MAV_CMD_REQUEST_MESSAGE = 512


def crc_x25(data):
    crc = 0xFFFF
    for b in data:
        tmp = b ^ (crc & 0xFF)
        tmp ^= (tmp << 4) & 0xFF
        crc = ((crc >> 8) ^ (tmp << 8) ^ (tmp << 3) ^ (tmp >> 4)) & 0xFFFF
    return crc


class Endpoint:
    def __init__(self, port, state_port, system_id):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(("0.0.0.0", port))
        self.state_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.state_sock.bind(("127.0.0.1", state_port))
        self.peer = None
        self.system_id = system_id
        self.sequence = 0
        self.armed = False
        self.start = time.monotonic()
        self.state = dict(lat=0., lon=0., altitude_m=0., heading_deg=0.,
                          speed_mps=0., battery_pct=100., roll_deg=0., pitch_deg=0.)

    def send(self, msgid, payload):
        if self.peer is None:
            return
        header = bytes((len(payload), self.sequence, self.system_id, 1, msgid))
        checksum = crc_x25(header + payload + bytes((CRC_EXTRA[msgid],)))
        self.sock.sendto(b"\xfe" + header + payload + struct.pack("<H", checksum), self.peer)
        self.sequence = (self.sequence + 1) & 255

    def heartbeat(self):
        base_mode = 1 | (128 if self.armed else 0)
        self.send(0, struct.pack("<IBBBBB", 0, 2, 3, base_mode, 4, 3))

    def telemetry(self):
        s = self.state
        ms = int((time.monotonic() - self.start) * 1000) & 0xFFFFFFFF
        lat = int(max(-90, min(90, s["lat"])) * 1e7)
        lon = int(max(-180, min(180, s["lon"])) * 1e7)
        alt = int(s["altitude_m"] * 1000)
        heading = int(s["heading_deg"] % 360 * 100)
        speed = int(max(0, s["speed_mps"]) * 100)
        self.send(33, struct.pack("<IiiiihhhH", ms, lat, lon, alt, alt,
                                  0, 0, speed, heading))
        self.send(30, struct.pack("<Iffffff", ms,
                                  math.radians(s["roll_deg"]),
                                  math.radians(s["pitch_deg"]),
                                  math.radians(s["heading_deg"]), 0., 0., 0.))
        self.send(1, struct.pack("<IIIHHhHHHHHHb", 0, 0, 0, 0, 0, 0,
                                 0, 0, 0, 0, 0, 0, int(max(0, min(100, s["battery_pct"])))))

    def receive(self, data, address):
        # Validate complete MAVLink v1 frame before acting on commands.
        if len(data) < 8 or data[0] != 0xFE:
            return
        length = data[1]
        if len(data) != length + 8:
            return
        msgid = data[5]
        if msgid not in CRC_EXTRA:
            return
        expected = crc_x25(data[1:6 + length] + bytes((CRC_EXTRA[msgid],)))
        if struct.unpack_from("<H", data, 6 + length)[0] != expected:
            return
        self.peer = address
        if msgid == 76 and length >= 33:
            params = struct.unpack_from("<7f", data, 6)
            command, target_system, target_component, confirmation = struct.unpack_from("<HBBB", data, 34)
            if target_system not in (0, self.system_id) or target_component not in (0, 1):
                return
            result = 3  # MAV_RESULT_UNSUPPORTED by default
            if command == MAV_CMD_COMPONENT_ARM_DISARM:
                self.armed = params[0] >= 0.5
                result = 0
            elif command == MAV_CMD_REQUEST_MESSAGE:
                if int(params[0]) == 0:
                    self.heartbeat()
                    result = 0
            self.send(77, struct.pack("<HB", command, result))

    def update_state(self, data):
        try:
            incoming = json.loads(data)
            for key in self.state:
                if key in incoming:
                    value = float(incoming[key])
                    if not math.isfinite(value):
                        return
                    self.state[key] = value
        except (ValueError, TypeError, UnicodeDecodeError):
            return

    def run(self):
        next_heartbeat = 0.
        next_telemetry = 0.
        while True:
            now = time.monotonic()
            if now >= next_heartbeat:
                self.heartbeat()
                next_heartbeat = now + 1.
            if now >= next_telemetry:
                self.telemetry()
                next_telemetry = now + 0.2
            readable, _, _ = select.select([self.sock, self.state_sock], [], [], 0.05)
            for sock in readable:
                data, addr = sock.recvfrom(4096)
                if sock is self.sock:
                    self.receive(data, addr)
                else:
                    self.update_state(data)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=14550)
    parser.add_argument("--state-port", type=int, default=14560)
    parser.add_argument("--system-id", type=int, default=1)
    args = parser.parse_args()
    if not (1 <= args.system_id <= 255):
        parser.error("system-id must be between 1 and 255")
    Endpoint(args.port, args.state_port, args.system_id).run()
