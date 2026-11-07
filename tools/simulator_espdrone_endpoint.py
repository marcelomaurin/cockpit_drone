#!/usr/bin/env python3
"""ESP-Drone / OpenDrone CRTP-over-UDP emulator for Cockpit Drone.

Matches the TAIDroneESPDrone component in marcelomaurin/CHATGPT:
UDP 2390, 16-byte commander packet (0x3C, 3 float32 + uint16 + checksum).
Runs on loopback by default; never connects to real flight hardware.
"""
import argparse
import json
import math
import threading
import select
import socket
import struct
import time


def clamp(value, lo, hi):
    return max(lo, min(hi, value))


class ESPDroneEndpoint:
    def __init__(self, host, port, physics_port=None):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((host, port))
        self.peer = None
        self.physics_port = physics_port
        self.physics = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.controls = dict(roll=0., pitch=0., yaw=0., throttle=0.)
        self.last_packet = 0.
        self.thrust_unlocked = False
        self.packets = 0
        self.position = dict(x=0., y=0., altitude=0., heading=0., speed=0.)
        self.last_step = time.monotonic()

    def receive(self, data, peer):
        if len(data) != 16 or data[0] != 0x3C:
            return False
        if sum(data[:-1]) & 255 != data[-1]:
            return False
        roll_deg, inverted_pitch_deg, yaw_rate, thrust = struct.unpack_from("<fffH", data, 1)
        if not all(math.isfinite(v) for v in (roll_deg, inverted_pitch_deg, yaw_rate)):
            return False
        self.peer = peer
        self.last_packet = time.monotonic()
        self.packets += 1
        if thrust == 0:
            self.thrust_unlocked = True
        self.controls.update(
            roll=clamp(roll_deg / 20., -1., 1.),
            pitch=clamp(-inverted_pitch_deg / 20., -1., 1.),
            yaw=clamp(yaw_rate / 120., -1., 1.),
            throttle=clamp(thrust / 60000., 0., 1.) if self.thrust_unlocked else 0.)
        return True

    def step_physics(self, dt):
        # Local deterministic motion model; does not command physical hardware.
        dt = clamp(dt, 0., 0.1)
        target = self.controls['throttle'] * 12.
        self.position['speed'] += clamp(target - self.position['speed'], -3*dt, 3*dt)
        self.position['heading'] = (self.position['heading'] + self.controls['yaw']*90*dt) % 360
        angle = math.radians(self.position['heading'])
        self.position['x'] += math.sin(angle)*self.position['speed']*dt
        self.position['y'] += math.cos(angle)*self.position['speed']*dt
        self.position['altitude'] = max(0., self.position['altitude'] + (self.controls['throttle']-.5)*3*dt)

    def run(self):
        next_reply = 0.
        while True:
            now = time.monotonic()
            if self.last_packet and now - self.last_packet > 0.5:
                self.controls.update(roll=0., pitch=0., yaw=0., throttle=0.)
            self.step_physics(now - self.last_step)
            self.last_step = now
            if self.peer and now >= next_reply:
                # Cockpit marks the link alive after receiving any datagram.
                self.sock.sendto(b"\x3c\x3c", self.peer)
                next_reply = now + 0.2
            if self.physics_port is not None:
                self.physics.sendto(json.dumps(dict(controls=self.controls, state=self.position)).encode("utf-8"),
                                    ("127.0.0.1", self.physics_port))
            ready, _, _ = select.select([self.sock], [], [], 0.02)
            if ready:
                data, peer = self.sock.recvfrom(1024)
                self.receive(data, peer)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=2390)
    parser.add_argument("--physics-port", type=int, default=None)
    args = parser.parse_args()
    ESPDroneEndpoint(args.host, args.port, args.physics_port).run()
