"""MAVLink 1/2 framing and command regression tests (local sockets only)."""
import importlib.util
import struct
import unittest
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "tools" / "simulator_mavlink_endpoint.py"
spec = importlib.util.spec_from_file_location("virtual_mavlink", path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def frame(msgid, payload, version=2):
    if version == 2:
        header = bytes([len(payload), 0, 0, 0, 42, 1]) + msgid.to_bytes(3, "little")
        magic = b"\xfd"
    else:
        header = bytes([len(payload), 0, 42, 1, msgid])
        magic = b"\xfe"
    crc = mod.crc_x25(header + payload + bytes([mod.CRC_EXTRA[msgid]]))
    return magic + header + payload + struct.pack("<H", crc)


class MAVLink2Tests(unittest.TestCase):
    def setUp(self):
        self.ep = mod.Endpoint(0, 0, 1, physics_port=None)
        self.ep.send_controls = lambda: None

    def tearDown(self):
        self.ep.sock.close()
        self.ep.state_sock.close()
        self.ep.physics_sock.close()

    def test_arm_v2(self):
        payload = struct.pack("<7fHBBB", 1., 0., 0., 0., 0., 0., 0.,
                              mod.MAV_CMD_COMPONENT_ARM_DISARM, 1, 1, 0)
        self.ep.receive(frame(76, payload), ("127.0.0.1", 12345))
        self.assertTrue(self.ep.armed)
        self.assertEqual(self.ep.protocol_version, 2)

    def test_arm_v1_compatibility(self):
        payload = struct.pack("<7fHBBB", 1., 0., 0., 0., 0., 0., 0.,
                              mod.MAV_CMD_COMPONENT_ARM_DISARM, 1, 1, 0)
        self.ep.receive(frame(76, payload, 1), ("127.0.0.1", 12345))
        self.assertTrue(self.ep.armed)
        self.assertEqual(self.ep.protocol_version, 1)

    def test_reject_bad_crc(self):
        payload = struct.pack("<7fHBBB", 1., 0., 0., 0., 0., 0., 0.,
                              mod.MAV_CMD_COMPONENT_ARM_DISARM, 1, 1, 0)
        packet = bytearray(frame(76, payload))
        packet[-1] ^= 1
        self.ep.receive(packet, ("127.0.0.1", 12345))
        self.assertFalse(self.ep.armed)

    def test_rc_v2_requires_armed(self):
        payload = struct.pack("<8HBB", 1500, 1500, 1800, 1500,
                              1500, 1500, 1500, 1500, 1, 1)
        self.ep.receive(frame(70, payload), ("127.0.0.1", 12345))
        self.assertEqual(self.ep.controls["throttle"], 0)
        self.ep.armed = True
        self.ep.receive(frame(70, payload), ("127.0.0.1", 12345))
        self.assertAlmostEqual(self.ep.controls["throttle"], .8)


if __name__ == "__main__":
    unittest.main()
