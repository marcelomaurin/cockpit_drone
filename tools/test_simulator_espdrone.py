#!/usr/bin/env python3
"""Loopback end-to-end smoke test: CRTP -> virtual motion -> UDP state.

Run from repository root:
    python tools/test_simulator_espdrone.py
No drone, joystick, third-party packages or network connection required.
"""
import json
import socket
import struct
import subprocess
import sys
import time
from pathlib import Path


def commander(thrust, roll=0., pitch=0., yaw=0.):
    data = bytes([0x3C]) + struct.pack("<fffH", roll, -pitch, yaw, thrust)
    return data + bytes([sum(data) & 255])


def main():
    endpoint = Path(__file__).with_name("simulator_espdrone_endpoint.py")
    telemetry = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    telemetry.bind(("127.0.0.1", 0))
    telemetry.settimeout(1.0)
    control = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    control.bind(("127.0.0.1", 0))
    port_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    port_sock.bind(("127.0.0.1", 0))
    endpoint_port = port_sock.getsockname()[1]
    port_sock.close()
    proc = subprocess.Popen(
        [sys.executable, str(endpoint), "--host", "127.0.0.1",
         "--port", str(endpoint_port), "--physics-port", str(telemetry.getsockname()[1])],
        stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    try:
        time.sleep(0.15)
        if proc.poll() is not None:
            raise AssertionError("Endpoint exited before receiving commands")
        def read_state():
            deadline = time.monotonic() + 1.
            while time.monotonic() < deadline:
                data, _ = telemetry.recvfrom(4096)
                value = json.loads(data)
                if "state" in value:
                    return value
            raise AssertionError("No virtual state received")

        # Unlock thrust by first sending zero, as the real component does.
        control.sendto(commander(0), ("127.0.0.1", endpoint_port))
        time.sleep(0.1)
        baseline = read_state()
        assert baseline["controls"]["throttle"] == 0
        for _ in range(20):
            control.sendto(commander(42000, yaw=60), ("127.0.0.1", endpoint_port))
            time.sleep(0.03)
        result = read_state()
        # Drain queued older datagrams to obtain a fresh state.
        telemetry.setblocking(False)
        try:
            while True:
                data, _ = telemetry.recvfrom(4096)
                result = json.loads(data)
        except BlockingIOError:
            pass
        assert result["controls"]["throttle"] > 0.6, result
        assert result["state"]["speed"] > 0, result
        assert result["state"]["heading"] != 0, result
        assert result["state"]["altitude"] > 0, result
        print("PASS: CRTP commands changed virtual speed, heading and altitude")
        return 0
    finally:
        proc.terminate()
        try:
            proc.communicate(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.communicate()
        control.close()
        telemetry.close()


if __name__ == "__main__":
    sys.exit(main())
