#!/usr/bin/env python3
"""Ryze/DJI Tello SDK-compatible virtual UDP endpoint (simulation only).
Command port defaults to 8889; state telemetry goes to port 8890 on the
client that first sends 'command'. Video is not emulated.
"""
import argparse
import json
import math
import select
import socket
import time


class TelloSimulator:
    def __init__(self, port=8889, state_port=14561, physics_port=None):
        self.command_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.command_socket.bind(("0.0.0.0", port))
        self.state_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.state_socket.bind(("127.0.0.1", state_port))
        self.physics_port = physics_port
        self.physics_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.controls = dict(throttle=0., turn=0., climb=0., brake=0., roll=0., pitch=0.)
        self.client = None
        self.sdk = False
        self.flying = False
        self.state = dict(altitude_m=0.0, battery_pct=100.0,
                          speed_mps=0.0, heading_deg=0.0,
                          roll_deg=0.0, pitch_deg=0.0)
        self.start = time.monotonic()
        self.last_rc = 0.0

    def command(self, data, peer):
        cmd = data.decode("ascii", errors="ignore").strip().lower()
        if cmd == "command":
            self.client = peer[0]
            self.sdk = True
            return "ok"
        if not self.sdk:
            return "error"
        if cmd == "takeoff":
            if self.flying:
                return "error"
            self.flying = True
            self.controls['climb'] = 0.6
            self.send_controls()
            if self.physics_port is None:
                self.state["altitude_m"] = max(0.5, self.state["altitude_m"])
            return "ok"
        if cmd == "land":
            self.flying = False
            self.controls.update(throttle=0., turn=0., climb=-0.6, roll=0., pitch=0.)
            self.send_controls()
            if self.physics_port is None:
                self.state["altitude_m"] = 0.0
            return "ok"
        if cmd == "emergency":
            self.flying = False
            self.state["altitude_m"] = 0.0
            return "ok"
        if cmd == 'stop':
            self.controls.update(throttle=0., turn=0., climb=0., roll=0., pitch=0.)
            self.send_controls()
        if cmd in ("streamon", "streamoff", "stop"):
            return "ok" if cmd != "streamon" else "error"  # no video encoder
        if cmd == "battery?":
            return str(int(self.state["battery_pct"]))
        if cmd == "height?":
            return str(int(self.state["altitude_m"] * 100))
        if cmd == "time?":
            return str(int(time.monotonic() - self.start))
        if cmd == "speed?":
            return str(int(self.state["speed_mps"] * 100))
        if cmd == "sdk?":
            return "20"
        if cmd == "sn?":
            return "SIMULATOR"
        if cmd.startswith("rc "):
            parts = cmd.split()
            if len(parts) != 5:
                return "error"
            try:
                values = [int(p) for p in parts[1:]]
            except ValueError:
                return "error"
            if any(abs(v) > 100 for v in values):
                return "error"
            if self.flying:
                self.controls.update(throttle=max(abs(values[0]), abs(values[1])) / 100.,
                                     turn=values[3] / 100., climb=values[2] / 100.,
                                     roll=values[0] / 100., pitch=values[1] / 100.)
                self.send_controls()
                self.last_rc = time.monotonic()
                if self.physics_port is None:
                    self.state["speed_mps"] = max(abs(values[0]), abs(values[1])) / 100 * 8
                    self.state["heading_deg"] = (self.state["heading_deg"] + values[3] * 0.02) % 360
                    self.state["altitude_m"] = max(0, self.state["altitude_m"] + values[2] * 0.001)
            return None  # Tello RC does not ACK
        return "error"

    def send_controls(self):
        if self.physics_port is not None:
            self.physics_socket.sendto(json.dumps(self.controls).encode('utf-8'),
                                       ('127.0.0.1', self.physics_port))

    def update(self, data):
        try:
            obj = json.loads(data)
            if not isinstance(obj, dict):
                return
            updates = {}
            for key in self.state:
                if key in obj:
                    v = float(obj[key])
                    if not math.isfinite(v):
                        return
                    updates[key] = v
            self.state.update(updates)
        except (ValueError, TypeError, UnicodeDecodeError):
            return

    def broadcast_state(self):
        if not self.client or not self.sdk:
            return
        s = self.state
        msg = ("pitch:{pitch};roll:{roll};yaw:{yaw};vgx:0;vgy:0;vgz:0;"
               "templ:25;temph:25;tof:{height};h:{height};bat:{battery};"
               "baro:0.00;time:{elapsed};agx:0.00;agy:0.00;agz:0.00;").format(
            pitch=int(s["pitch_deg"]), roll=int(s["roll_deg"]),
            yaw=int(s["heading_deg"]), height=int(s["altitude_m"] * 100),
            battery=int(max(0, min(100, s["battery_pct"]))),
            elapsed=int(time.monotonic() - self.start))
        self.command_socket.sendto(msg.encode("ascii"), (self.client, 8890))

    def run(self):
        next_state = 0.0
        while True:
            now = time.monotonic()
            if self.physics_port is not None and self.last_rc and now - self.last_rc > 0.5:
                self.controls.update(throttle=0., turn=0., climb=0., roll=0., pitch=0.)
                self.send_controls()
                self.last_rc = 0.
            if now >= next_state:
                self.broadcast_state()
                next_state = now + 0.1
            ready, _, _ = select.select([self.command_socket, self.state_socket], [], [], 0.05)
            for sock in ready:
                data, peer = sock.recvfrom(4096)
                if sock is self.state_socket:
                    self.update(data)
                else:
                    reply = self.command(data, peer)
                    if reply is not None:
                        sock.sendto(reply.encode("ascii"), peer)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8889)
    parser.add_argument("--state-port", type=int, default=14561)
    parser.add_argument("--physics-port", type=int, default=None)
    args = parser.parse_args()
    TelloSimulator(args.port, args.state_port, args.physics_port).run()
