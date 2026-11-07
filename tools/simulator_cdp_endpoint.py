#!/usr/bin/env python3
"""Virtual ESP32 Cockpit Drone Protocol v1 endpoint, UDP only.
Implements firmware/esp32_drone/PROTOCOLO.md without physical motor output.
"""
import argparse
import json
import math
import select
import socket
import struct
import time

HEADER = b"CD\x01"
CONTROL = 0x01
CALIBRATE = 0x02
TELEMETRY = 0x81


def crc16(data):
    value = 0xFFFF
    for b in data:
        value ^= b << 8
        for _ in range(8):
            value = ((value << 1) ^ (0x1021 if value & 0x8000 else 0)) & 0xFFFF
    return value


def packet(kind, sequence, payload=b""):
    body = HEADER + bytes([kind]) + struct.pack("<H", sequence) + payload
    return body + struct.pack("<H", crc16(body))


def decode(data):
    if len(data) < 8 or data[:3] != HEADER:
        return None
    length = {CONTROL: 17, CALIBRATE: 8}.get(data[3])
    if length is None or len(data) != length:
        return None
    if crc16(data[:-2]) != struct.unpack_from("<H", data, len(data) - 2)[0]:
        return None
    return data[3], struct.unpack_from("<H", data, 4)[0], data[6:-2]


class VirtualCDP:
    def __init__(self, host, port, physics_port=None):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((host, port))
        self.physics_port = physics_port
        self.physics_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.peer = None
        self.seq = 0
        self.armed = False
        self.cut_latched = False
        self.last_control = 0.
        self.roll = self.pitch = self.yaw = 0
        self.throttle = 0
        self.state = 0
        self.calibration_until = 0.
        self.control_count = 0
        self.window_start = time.monotonic()
        self.control_rate = 0

    def receive(self, data, peer):
        decoded = decode(data)
        if decoded is None:
            return
        kind, _, payload = decoded
        self.peer = peer
        if kind == CALIBRATE:
            if not self.armed:
                self.state = 4
                self.calibration_until = time.monotonic() + 1.
            return
        roll, pitch, yaw, throttle, flags = struct.unpack("<hhhHB", payload)
        self.last_control = time.monotonic()
        self.control_count += 1
        self.roll = max(-1000, min(1000, roll))
        self.pitch = max(-1000, min(1000, pitch))
        self.yaw = max(-1000, min(1000, yaw))
        requested_arm = bool(flags & 1)
        cut = bool(flags & 2)
        if cut:
            self.cut_latched = True
            self.armed = False
            self.state = 3
        elif self.cut_latched:
            if not requested_arm:
                self.cut_latched = False
                self.state = 0
        elif self.armed and not requested_arm:
            self.armed = False
            self.state = 0
        elif not self.armed and requested_arm and throttle <= 50 and abs(roll) < 900 and abs(pitch) < 900:
            self.armed = True
            self.state = 1
        self.throttle = throttle if self.armed else 0
        self.send_controls()

    def send_controls(self):
        if self.physics_port is None:
            return
        throttle = max(0., min(1., self.throttle / 1000.)) if self.armed else 0.
        controls = dict(throttle=throttle,
                        turn=self.yaw / 1000. if self.armed else 0.,
                        climb=max(-1., min(1., (throttle - .45) / .55)) if self.armed else 0.,
                        brake=0., roll=self.roll / 1000. if self.armed else 0.,
                        pitch=self.pitch / 1000. if self.armed else 0.)
        self.physics_socket.sendto(json.dumps(controls).encode('utf-8'),
                                   ('127.0.0.1', self.physics_port))

    def tick(self):
        now = time.monotonic()
        if self.state == 4 and now >= self.calibration_until:
            self.state = 0
        if self.last_control and now - self.last_control > 0.5:
            self.armed = False
            self.throttle = 0
            self.state = 2
            self.send_controls()
            self.last_control = 0.
        if now - self.window_start >= 1:
            self.control_rate = self.control_count
            self.control_count = 0
            self.window_start = now

    def telemetry(self):
        if self.peer is None:
            return
        alerts = 2  # virtual sensor OK
        if not self.armed:
            alerts |= 4
        payload = struct.pack("<BHhhhHbHBH", self.state, 4000,
                              int(self.roll * 2), int(self.pitch * 2),
                              int(self.yaw * 2), self.throttle,
                              -40, 200, alerts, min(self.control_rate, 65535))
        self.sock.sendto(packet(TELEMETRY, self.seq, payload), self.peer)
        self.seq = (self.seq + 1) & 0xFFFF

    def run(self):
        next_telemetry = 0.
        while True:
            now = time.monotonic()
            if now >= next_telemetry:
                self.tick()
                self.telemetry()
                next_telemetry = now + 0.1
            ready, _, _ = select.select([self.sock], [], [], 0.02)
            if ready:
                self.receive(*self.sock.recvfrom(1024))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=4210)
    parser.add_argument("--physics-port", type=int, default=None)
    args = parser.parse_args()
    VirtualCDP(args.host, args.port, args.physics_port).run()
