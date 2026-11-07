#!/usr/bin/env python3
"""Parrot AR.Drone 2.0 virtual AT command and navdata endpoint.
Based on aidroneardrone.pas in the Cockpit's CHATGPT component library.
Video PaVE/TCP 5555 is not implemented yet. No hardware access.
"""
import argparse
import json
import math
import select
import socket
import struct
import time

REF_TAKEOFF = 0x200
REF_EMERGENCY = 0x100
NAVDATA_HEADER = 0x55667788


def at_float(value):
    return struct.unpack("<f", struct.pack("<I", int(value) & 0xffffffff))[0]


class ARDroneEndpoint:
    def __init__(self, host, command_port, nav_port, state_port):
        self.command = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.command.bind((host, command_port))
        self.nav = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.nav.bind((host, nav_port))
        self.local_state = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.local_state.bind(("127.0.0.1", state_port))
        self.nav_peer = None
        self.sequence = 1
        self.flying = False
        self.emergency = False
        self.last_at = 0.
        self.state = dict(battery_pct=100., altitude_m=0.,
                          pitch_deg=0., roll_deg=0., heading_deg=0.,
                          vx=0., vy=0., vz=0.)
        self.controls = dict(roll=0., pitch=0., climb=0., yaw=0.)

    def receive_at(self, data):
        for raw in data.decode("ascii", errors="ignore").split("\r"):
            parts = raw.strip().split("=", 1)
            if len(parts) != 2 or not parts[0].startswith("AT*"):
                continue
            name = parts[0][3:]
            fields = parts[1].split(",")
            try:
                int(fields[0])
                if name == "REF" and len(fields) >= 2:
                    flags = int(fields[1])
                    self.emergency = bool(flags & REF_EMERGENCY)
                    self.flying = bool(flags & REF_TAKEOFF) and not self.emergency
                    if not self.flying:
                        self.controls = dict.fromkeys(self.controls, 0.)
                elif name == "PCMD" and len(fields) >= 6:
                    enabled = int(fields[1])
                    if enabled and self.flying:
                        values = [at_float(x) for x in fields[2:6]]
                        if all(math.isfinite(x) for x in values):
                            self.controls.update(zip(("roll", "pitch", "climb", "yaw"),
                                                     (max(-1., min(1., x)) for x in values)))
                    else:
                        self.controls = dict.fromkeys(self.controls, 0.)
                elif name in ("FTRIM", "CONFIG", "COMWDG", "CTRL"):
                    pass
            except (ValueError, OverflowError, struct.error):
                continue
        self.last_at = time.monotonic()

    def update_state(self, data):
        try:
            obj = json.loads(data)
            if not isinstance(obj, dict):
                return
            for key in self.state:
                if key in obj:
                    value = float(obj[key])
                    if math.isfinite(value):
                        self.state[key] = value
        except (ValueError, TypeError, UnicodeDecodeError):
            pass

    def send_navdata(self):
        if self.nav_peer is None:
            return
        s = self.state
        state_bits = (1 if self.flying else 0) | (0x80000000 if self.emergency else 0)
        demo = struct.pack("<IIffffifff", 0, int(max(0, min(100, s["battery_pct"]))),
                           s["pitch_deg"] * 1000, s["roll_deg"] * 1000,
                           s["heading_deg"] * 1000, 0.,
                           int(s["altitude_m"] * 1000),
                           s["vx"] * 1000, s["vy"] * 1000, s["vz"] * 1000)
        option = struct.pack("<HH", 0, len(demo) + 4) + demo
        header = struct.pack("<IIII", NAVDATA_HEADER, state_bits, self.sequence, 0)
        body = header + option
        checksum = sum(body) & 0xffffffff
        body += struct.pack("<HHI", 0xffff, 8, checksum)
        self.nav.sendto(body, self.nav_peer)
        self.sequence += 1

    def run(self):
        next_nav = 0.
        while True:
            now = time.monotonic()
            if now - self.last_at > 2.:
                self.controls = dict.fromkeys(self.controls, 0.)
            if now >= next_nav:
                self.send_navdata()
                next_nav = now + 0.1
            ready, _, _ = select.select([self.command, self.nav, self.local_state], [], [], 0.02)
            for sock in ready:
                data, peer = sock.recvfrom(4096)
                if sock is self.command:
                    self.receive_at(data)
                elif sock is self.nav:
                    self.nav_peer = peer
                else:
                    self.update_state(data)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--command-port", type=int, default=5556)
    parser.add_argument("--nav-port", type=int, default=5554)
    parser.add_argument("--state-port", type=int, default=14564)
    args = parser.parse_args()
    ARDroneEndpoint(args.host, args.command_port, args.nav_port, args.state_port).run()
