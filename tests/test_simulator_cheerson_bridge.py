"""Contract smoke tests for the Cheerson protocol-to-physics path.

Run: python -m unittest discover -s tests -p 'test_simulator_cheerson_bridge.py'
No hardware, network access or FPC required.
"""
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "cheerson_endpoint", ROOT / "tools" / "simulator_cheerson_endpoint.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CheersonBridgeContract(unittest.TestCase):
    def setUp(self):
        self.endpoint = MODULE.CheersonEndpoint("127.0.0.1", 0, 0, 0)

    def tearDown(self):
        self.endpoint.tcp.close()
        self.endpoint.udp.close()
        self.endpoint.state_socket.close()

    @staticmethod
    def packet(roll=127, pitch=127, throttle=200, yaw=127):
        payload = [roll, pitch, throttle, yaw, 0]
        checksum = 0
        for value in payload:
            checksum ^= value
        return bytes([0xCC, *payload, checksum, 0x33])

    def test_valid_sticks_are_normalized(self):
        self.endpoint.command(self.packet(throttle=200, yaw=255))
        self.assertAlmostEqual(self.endpoint.state["throttle"], 200 / 255)
        self.assertAlmostEqual(self.endpoint.state["yaw"], 1.0)
        self.assertGreater(self.endpoint.last_command, 0)

    def test_invalid_checksum_does_not_change_controls(self):
        packet = bytearray(self.packet())
        packet[6] ^= 0x01
        self.endpoint.command(packet)
        self.assertEqual(self.endpoint.state["throttle"], 0.0)
        self.assertEqual(self.endpoint.last_command, 0.0)

    def test_virtual_state_update(self):
        self.endpoint.update_state(json.dumps(
            {"battery_pct": 81, "altitude_m": 3.25}).encode())
        self.assertEqual(self.endpoint.state["battery_pct"], 81)
        self.assertEqual(self.endpoint.state["altitude_m"], 3.25)


if __name__ == "__main__":
    unittest.main()
