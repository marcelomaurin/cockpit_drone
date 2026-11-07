"""Tello shared-physics adapter regression tests (no hardware)."""
import importlib.util
from pathlib import Path
import unittest

PATH = Path(__file__).resolve().parents[1] / "tools" / "simulator_tello_endpoint.py"
spec = importlib.util.spec_from_file_location("simulator_tello_endpoint", PATH)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class TelloSharedPhysicsTests(unittest.TestCase):
    def setUp(self):
        self.sim = module.TelloSimulator(port=0, state_port=0, physics_port=14563)
        self.sent = []
        self.sim.send_controls = lambda: self.sent.append(dict(self.sim.controls))

    def tearDown(self):
        self.sim.command_socket.close()
        self.sim.state_socket.close()
        self.sim.physics_socket.close()

    def test_takeoff_and_land_do_not_overwrite_physics_altitude(self):
        self.assertEqual(self.sim.command(b"command", ("127.0.0.1", 1000)), "ok")
        self.sim.state["altitude_m"] = 2.5
        self.assertEqual(self.sim.command(b"takeoff", ("127.0.0.1", 1000)), "ok")
        self.assertEqual(self.sim.state["altitude_m"], 2.5)
        self.assertEqual(self.sim.command(b"land", ("127.0.0.1", 1000)), "ok")
        self.assertEqual(self.sim.state["altitude_m"], 2.5)

    def test_rc_controls_do_not_modify_physics_telemetry(self):
        self.sim.command(b"command", ("127.0.0.1", 1000))
        self.sim.command(b"takeoff", ("127.0.0.1", 1000))
        self.sim.state["heading_deg"] = 30
        self.sim.state["speed_mps"] = 3
        self.assertIsNone(self.sim.command(b"rc 20 30 40 50", ("127.0.0.1", 1000)))
        self.assertEqual(self.sim.state["heading_deg"], 30)
        self.assertEqual(self.sim.state["speed_mps"], 3)
        self.assertAlmostEqual(self.sent[-1]["roll"], .2)
        self.assertAlmostEqual(self.sent[-1]["pitch"], .3)

    def test_invalid_rc_rejected(self):
        self.sim.command(b"command", ("127.0.0.1", 1000))
        self.sim.command(b"takeoff", ("127.0.0.1", 1000))
        self.assertEqual(self.sim.command(b"rc 200 0 0 0", ("127.0.0.1", 1000)), "error")


if __name__ == "__main__":
    unittest.main()
