#!/usr/bin/env python3
"""Standalone local Cheerson/FQ777 virtual flight dynamics receiver.

Receives normalized control JSON from simulator_cheerson_endpoint.py over
loopback UDP. Uses simplified kinematics; never communicates with hardware.
"""
import argparse
import json
import math
import select
import socket
import time


def clamp(v, low, high):
    return max(low, min(high, v))


class VirtualCheerson:
    def __init__(self, port, lat, lon):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(("127.0.0.1", port))
        self.state = dict(lat=lat, lon=lon, altitude_m=0., heading_deg=0.,
                          speed_mps=0., battery_pct=100., roll_deg=0.,
                          pitch_deg=0.)
        self.controls = dict(roll=0., pitch=0., throttle=0., yaw=0.)
        self.last_control = 0.
        self.last_step = time.monotonic()

    def receive(self, payload):
        try:
            obj = json.loads(payload)
            if not isinstance(obj, dict):
                return
            values = {}
            for key in self.controls:
                value = float(obj[key])
                if not math.isfinite(value):
                    return
                values[key] = clamp(value, 0, 1) if key == "throttle" else clamp(value, -1, 1)
            self.controls.update(values)
            self.last_control = time.monotonic()
        except (ValueError, KeyError, TypeError, UnicodeDecodeError):
            return

    def step(self, dt):
        if self.last_control == 0 or time.monotonic() - self.last_control > 0.5:
            self.controls.update(roll=0., pitch=0., throttle=0., yaw=0.)
        s = self.state
        c = self.controls
        if s["battery_pct"] <= 0:
            c["throttle"] = 0.
        vertical = (c["throttle"] - 0.45) * 3.0 if c["throttle"] > 0 else -1.5
        s["altitude_m"] = max(0., s["altitude_m"] + vertical * dt)
        s["heading_deg"] = (s["heading_deg"] + c["yaw"] * 90 * dt) % 360
        s["roll_deg"] = c["roll"] * 25
        s["pitch_deg"] = c["pitch"] * 25
        speed_north = c["pitch"] * 8
        speed_east = c["roll"] * 8
        yaw = math.radians(s["heading_deg"])
        north = speed_north * math.cos(yaw) - speed_east * math.sin(yaw)
        east = speed_north * math.sin(yaw) + speed_east * math.cos(yaw)
        if s["altitude_m"] <= 0:
            north = east = 0
        s["speed_mps"] = math.hypot(north, east)
        s["lat"] = clamp(s["lat"] + north * dt / 111195., -90, 90)
        cos_lat = math.cos(math.radians(s["lat"]))
        if abs(cos_lat) > 1e-6:
            s["lon"] = (s["lon"] + east * dt / (111195. * cos_lat) + 180) % 360 - 180
        s["battery_pct"] = max(0., s["battery_pct"] - dt * (0.002 + c["throttle"] * 0.008))

    def run(self, state_port):
        tx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        next_report = 0.
        try:
            while True:
                ready, _, _ = select.select([self.sock], [], [], 0.02)
                if ready:
                    payload, _ = self.sock.recvfrom(4096)
                    self.receive(payload)
                now = time.monotonic()
                dt = clamp(now - self.last_step, 0, 0.1)
                self.last_step = now
                self.step(dt)
                if now >= next_report:
                    tx.sendto(json.dumps(self.state).encode("utf-8"),
                              ("127.0.0.1", state_port))
                    next_report = now + 0.1
        finally:
            tx.close()
            self.sock.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--control-port", type=int, default=14563)
    parser.add_argument("--state-port", type=int, default=14562)
    parser.add_argument("--lat", type=float, default=-21.17)
    parser.add_argument("--lon", type=float, default=-47.81)
    args = parser.parse_args()
    VirtualCheerson(args.control_port, args.lat, args.lon).run(args.state_port)
