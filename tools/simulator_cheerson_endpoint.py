#!/usr/bin/env python3
"""Cheerson CX-10W / FQ777-954 protocol emulator for Cockpit Drone.

The Cockpit's aidronecx10w is derived from aidronefq777: TCP 8888
initialization and UDP 8895 8-byte stick packets. Video is not emulated.
Use --host 127.0.0.1 for local development; real drone AP IP is 172.16.10.1.
"""
import argparse
import json
import math
import select
import socket
import threading
import os
import time


class CheersonEndpoint:
    def __init__(self, host, tcp_port, udp_port, state_port):
        self.tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.tcp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.tcp.bind((host, tcp_port))
        self.tcp.listen(5)
        self.tcp.setblocking(False)
        self.udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.udp.bind((host, udp_port))
        self.state_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.state_socket.bind(("127.0.0.1", state_port))
        self.connections = {}
        self.state = dict(roll=0., pitch=0., throttle=0., yaw=0.,
                          battery_pct=100., altitude_m=0.)
        self.last_command = 0.
        self.lock = threading.Lock()
        self.physics_stop = threading.Event()
        self.physics_thread = None
        self.physics_port = None
        self.video_file = None
        self.video_clients = set()
        self.video_thread = None

    def command(self, data):
        if len(data) != 8 or data[0] != 0xCC or data[7] != 0x33:
            return
        checksum = 0
        for b in data[1:6]:
            checksum ^= b
        if checksum != data[6]:
            return
        with self.lock:
            self.state.update(roll=(data[1] - 127) / 128,
                              pitch=(data[2] - 127) / 128,
                              throttle=data[3] / 255,
                              yaw=(data[4] - 127) / 128)
            self.last_command = time.monotonic()

    def update_state(self, data):
        try:
            obj = json.loads(data)
            if not isinstance(obj, dict):
                return
            for key in ("battery_pct", "altitude_m"):
                if key in obj:
                    value = float(obj[key])
                    if math.isfinite(value):
                        self.state[key] = value
        except (ValueError, TypeError, UnicodeDecodeError):
            pass

    def video_loop(self):
        # The caller supplies Annex-B H.264 (720x576 recommended).
        # No fake image is claimed: stream an existing encoded sequence.
        try:
            while not self.physics_stop.is_set():
                if not self.video_clients:
                    self.physics_stop.wait(0.1)
                    continue
                with open(self.video_file, 'rb') as source:
                    while not self.physics_stop.is_set() and self.video_clients:
                        chunk = source.read(1200)
                        if not chunk:
                            break
                        for client in tuple(self.video_clients):
                            try:
                                client.sendall(chunk)
                            except OSError:
                                self.video_clients.discard(client)
                        self.physics_stop.wait(0.01)
        except OSError as exc:
            print('Video stream error:', exc)

    def physics_loop(self, port):
        sender = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            while not self.physics_stop.wait(0.05):
                with self.lock:
                    snapshot = dict(self.state)
                sender.sendto(json.dumps(snapshot).encode('utf-8'), ('127.0.0.1', port))
        finally:
            sender.close()

    def run(self):
        if self.video_file:
            if not os.path.isfile(self.video_file):
                raise FileNotFoundError(self.video_file)
            self.video_thread = threading.Thread(target=self.video_loop, daemon=True)
            self.video_thread.start()
        if self.physics_port is not None:
            self.physics_thread = threading.Thread(target=self.physics_loop,
                args=(self.physics_port,), daemon=True)
            self.physics_thread.start()
        while True:
            watched = [self.tcp, self.udp, self.state_socket] + list(self.connections)
            readable, _, _ = select.select(watched, [], [], 0.05)
            for sock in readable:
                if sock is self.tcp:
                    client, _ = sock.accept()
                    client.setblocking(False)
                    self.connections[client] = bytearray()
                elif sock is self.udp:
                    data, _ = sock.recvfrom(2048)
                    self.command(data)
                elif sock is self.state_socket:
                    data, _ = sock.recvfrom(4096)
                    self.update_state(data)
                else:
                    try:
                        data = sock.recv(4096)
                        if not data:
                            raise ConnectionError("client disconnected")
                        buf = self.connections[sock]
                        buf.extend(data)
                        if len(buf) > 16384:
                            raise ConnectionError("handshake too long")
                        # TCP initialization packets are 106 bytes and start ITd.
                        while len(buf) >= 106:
                            packet = bytes(buf[:106])
                            del buf[:106]
                            if not packet.startswith(b"ITd"):
                                raise ConnectionError("invalid handshake")
                            # Magic VIDEO_2 is identified by its marker bytes.
                            if packet[6] == 0x58 and packet[10:12] == b'\\x80\\x86':
                                if self.video_file:
                                    self.video_clients.add(sock)
                        # Keep all three TCP channels open (control and video).
                    except (OSError, ConnectionError):
                        self.connections.pop(sock, None)
                        self.video_clients.discard(sock)
                        sock.close()
            if self.last_command and time.monotonic() - self.last_command > 0.5:
                with self.lock:
                    self.state.update(roll=0., pitch=0., throttle=0., yaw=0.)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--tcp-port", type=int, default=8888)
    parser.add_argument("--udp-port", type=int, default=8895)
    parser.add_argument("--state-port", type=int, default=14562)
    parser.add_argument("--video-h264", default=None,
                        help="existing Annex-B H.264 stream for the video TCP channel")
    parser.add_argument("--physics-port", type=int, default=None,
                        help="send normalized controls as JSON to local simulator UDP port")
    args = parser.parse_args()
    endpoint = CheersonEndpoint(args.host, args.tcp_port, args.udp_port, args.state_port)
    endpoint.physics_port = args.physics_port
    endpoint.video_file = args.video_h264
    endpoint.run()
