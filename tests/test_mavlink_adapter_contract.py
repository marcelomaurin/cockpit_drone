"""Static regression checks for the simulator-only MAVLink safety gate.

These checks do not replace compiling Pascal or SITL integration tests.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
ADAPTER = ROOT / "src" / "mavlink_vehicle_adapter.pas"
CONTRACT = ROOT / "src" / "vehicle_control_contract.pas"


class MavlinkAdapterContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.adapter = ADAPTER.read_text(encoding="utf-8")
        cls.contract = CONTRACT.read_text(encoding="utf-8")

    def test_adapter_checks_contract_first(self):
        self.assertIn("ValidateCommand(Cmd, Reason)", self.adapter)

    def test_adapter_fails_closed_for_real_hardware(self):
        self.assertRegex(self.adapter, r"if not State\.SimulatorOnly then")

    def test_adapter_requires_fresh_heartbeat_and_input(self):
        self.assertIn("if not State.HeartbeatFresh then", self.adapter)
        self.assertIn("if not State.InputFresh then", self.adapter)

    def test_adapter_requires_mode_and_arm_confirmation(self):
        self.assertIn("if not State.ModeApproved then", self.adapter)
        self.assertIn("if Cmd.Armed <> State.AutopilotArmed then", self.adapter)

    def test_vehicle_class_is_checked(self):
        self.assertIn("Cmd.VehicleClass <> State.VehicleClass", self.adapter)

    def test_all_five_vehicle_classes_present(self):
        for cls in ("vcMultirotor", "vcFixedWing", "vcHelicopter",
                    "vcBoat", "vcSubmersible"):
            with self.subTest(vehicle_class=cls):
                self.assertIn(cls, self.contract)

    def test_no_transport_calls_in_adapter(self):
        self.assertNotRegex(self.adapter.lower(), r"\b(sendto|sendmessage|sendpacket|udp\.send|tcp\.send)\b")


if __name__ == "__main__":
    unittest.main()
