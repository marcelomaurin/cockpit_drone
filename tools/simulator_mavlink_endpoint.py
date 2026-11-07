#!/usr/bin/env python3
"""Virtual MAVLink v1/v2 drone endpoint. Simulation only; no physical I/O.
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

CRC_EXTRA = {70: 124, 0: 50, 1: 124, 24: 24, 30: 39, 33: 104, 76: 152, 77: 143}
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
    def __init__(self, port, state_port, system_id, physics_port=None, host='127.0.0.1'):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((host, port))
        self.state_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.state_sock.bind(("127.0.0.1", state_port))
        self.physics_port = physics_port
        self.physics_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.controls = dict(throttle=0., turn=0., climb=0., brake=0., roll=0., pitch=0.)
        self.last_control = 0.
        self.peer = None
        self.system_id = system_id
        self.sequence = 0
        self.protocol_version = 2
        self.armed = False
        self.start = time.monotonic()
        self.state = dict(lat=0., lon=0., altitude_m=0., heading_deg=0.,
                          speed_mps=0., battery_pct=100., roll_deg=0., pitch_deg=0.)

    def send(self, msgid, payload):
        if self.peer is None:
            return
        if self.protocol_version == 2:
            header = bytes((len(payload), 0, 0, self.sequence, self.system_id, 1)) + msgid.to_bytes(3, "little")
            magic = b"\xfd"
        else:
            header = bytes((len(payload), self.sequence, self.system_id, 1, msgid))
            magic = b"\xfe"
        checksum = crc_x25(header + payload + bytes((CRC_EXTRA[msgid],)))
        self.sock.sendto(magic + header + payload + struct.pack("<H", checksum), self.peer)
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

    def send_controls(self):
        if self.physics_port is not None:
            self.physics_sock.sendto(json.dumps(self.controls).encode('utf-8'),
                                     ('127.0.0.1', self.physics_port))

    def receive(self, data, address):
        # MAVLink 2 header: magic, length, incompat, compat, sequence,
        # system, component, 24-bit message id. Signed frames are rejected
        # because no signing key has been configured for this local simulator.
        if len(data) < 8:
            return
        if data[0] == 0xFD:
            if len(data) < 12 or data[2] != 0:
                return
            length = data[1]
            if len(data) != length + 12:
                return
            msgid = int.from_bytes(data[7:10], 'little')
            header_end = 10
            version = 2
        elif data[0] == 0xFE:
            length = data[1]
            if len(data) != length + 8:
                return
            msgid = data[5]
            header_end = 6
            version = 1
        else:
            return
        if msgid not in CRC_EXTRA:
            return
        expected = crc_x25(data[1:header_end + length] + bytes((CRC_EXTRA[msgid],)))
        if struct.unpack_from("<H", data, header_end + length)[0] != expected:
            return
        self.protocol_version = version
        payload = data[header_end:header_end + length]
        self.peer = address
        if msgid == 76 and length >= 33:
            params = struct.unpack_from("<7f", payload, 0)
            command, target_system, target_component, confirmation = struct.unpack_from("<HBBB", payload, 28)
            if target_system not in (0, self.system_id) or target_component not in (0, 1):
                return
            result = 3  # MAV_RESULT_UNSUPPORTED by default
            if command == MAV_CMD_COMPONENT_ARM_DISARM:
                self.armed = params[0] >= 0.5
                if not self.armed:
                    self.controls = dict.fromkeys(self.controls, 0.)
                    self.send_controls()
                result = 0
            elif command == MAV_CMD_REQUEST_MESSAGE:
                if int(params[0]) == 0:
                    self.heartbeat()
                    result = 0
            self.send(77, struct.pack("<HB", command, result))
        elif msgid == 70 and length >= 18:
            # RC_CHANNELS_OVERRIDE: eight uint16 channels + target system/component.
            channels = struct.unpack_from('<8H', payload, 0)
            target_system, target_component = struct.unpack_from('<BB', payload, 16)
            if target_system not in (0, self.system_id) or target_component not in (0, 1):
                return
            if not self.armed:
                return
            def axis(v):
                return max(-1., min(1., (v - 1500) / 500.))
            if any(v in (0, 65535) for v in channels[:4]):
                return
            self.controls.update(roll=axis(channels[0]), pitch=axis(channels[1]),
                                 throttle=max(0., min(1., (channels[2] - 1000) / 1000.)),
                                 turn=axis(channels[3]),
                                 climb=axis(channels[2]), brake=0.)
            self.last_control = time.monotonic()
            self.send_controls()

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
            if self.last_control and now - self.last_control > 0.5:
                self.controls = dict.fromkeys(self.controls, 0.)
                self.send_controls()
                self.last_control = 0.
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
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--physics-port", type=int, default=None)
    parser.add_argument("--state-port", type=int, default=14560)
    parser.add_argument("--system-id", type=int, default=1)
    args = parser.parse_args()
    if not (1 <= args.system_id <= 255):
        parser.error("system-id must be between 1 and 255")
    Endpoint(args.port, args.state_port, args.system_id, args.physics_port, args.host).run()
