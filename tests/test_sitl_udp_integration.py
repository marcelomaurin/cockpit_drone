"""Real MAVLink UDP loopback integration; never connects to physical vehicles.

Run with pymavlink installed. Set COCKPIT_BRIDGE_TEST_EXE to the compiled
Pascal test_sitl_bridge_loopback executable to also test the complete bridge.
"""
import json
import os
from pathlib import Path
import queue
import socket
import subprocess
import sys
import threading
import time
import unittest

try:
    from pymavlink import mavutil
except ImportError:
    mavutil = None

ROOT = Path(__file__).resolve().parents[1]


def free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def output_queue(process):
    lines = queue.Queue()
    def read():
        for line in process.stdout:
            lines.put(line.rstrip())
        lines.put(None)
    threading.Thread(target=read, daemon=True).start()
    return lines


def next_line(lines, timeout=5):
    line = lines.get(timeout=timeout)
    if line is None:
        raise AssertionError('subprocess exited before expected output')
    return line


@unittest.skipIf(mavutil is None, 'install requirements-sitl.txt for UDP integration')
class SitlUdpIntegrationTests(unittest.TestCase):
    def test_python_monitor_receives_wire_heartbeat_and_expires(self):
        port = free_port()
        process = subprocess.Popen(
            [sys.executable, '-u', str(ROOT / 'tools/sitl_heartbeat_monitor.py'),
             '--port', str(port), '--timeout', '0.5'],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        sender = mavutil.mavlink_connection(
            f'udpout:127.0.0.1:{port}', source_system=37, source_component=1)
        lines = output_queue(process)
        try:
            deadline = time.monotonic() + 6
            heartbeat = None
            while time.monotonic() < deadline:
                sender.mav.heartbeat_send(2, 3, 128, 0xFFFFFFFF, 4)
                try:
                    heartbeat = json.loads(lines.get(timeout=0.15))
                    break
                except queue.Empty:
                    pass
            self.assertIsNotNone(heartbeat, 'no wire heartbeat received')
            self.assertEqual(heartbeat['system_id'], 37)
            self.assertEqual(heartbeat['component_id'], 1)
            self.assertEqual(heartbeat['vehicle_class'], 'multirotor')
            self.assertEqual(heartbeat['custom_mode'], 0xFFFFFFFF)
            self.assertTrue(heartbeat['armed_reported'])
            self.assertFalse(heartbeat['control_authorized'])
            timeout_event = json.loads(next_line(lines, 4))
            self.assertEqual(timeout_event['event'], 'heartbeat_timeout')
            self.assertFalse(timeout_event['control_authorized'])
        finally:
            sender.close()
            process.terminate()
            process.communicate(timeout=5)

    @unittest.skipUnless(os.environ.get('COCKPIT_BRIDGE_TEST_EXE'),
                         'compile Pascal bridge loopback harness first')
    def test_pascal_bridge_reads_python_monitor_and_clears_state(self):
        port = free_port()
        process = subprocess.Popen(
            [os.environ['COCKPIT_BRIDGE_TEST_EXE'], sys.executable,
             str(ROOT / 'tools/sitl_heartbeat_monitor.py'), str(port)],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        sender = mavutil.mavlink_connection(
            f'udpout:127.0.0.1:{port}', source_system=37, source_component=1)
        lines = output_queue(process)
        try:
            self.assertEqual(next_line(lines, 5), 'READY')
            deadline = time.monotonic() + 6
            connected = False
            while time.monotonic() < deadline:
                sender.mav.heartbeat_send(2, 3, 128, 0xFFFFFFFF, 4)
                try:
                    line = lines.get(timeout=0.15)
                    self.assertEqual(line, 'CONNECTED')
                    connected = True
                    break
                except queue.Empty:
                    pass
            self.assertTrue(connected, 'Pascal did not receive telemetry')
            self.assertTrue(next_line(lines, 6).startswith('PASS:'))
            self.assertEqual(process.wait(timeout=5), 0)
        finally:
            sender.close()
            if process.poll() is None:
                process.terminate()
            process.communicate(timeout=5)


if __name__ == '__main__':
    unittest.main()
