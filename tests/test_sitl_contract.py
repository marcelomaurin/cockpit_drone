"""Static checks for the SITL-only integration specification.

Does not start ArduPilot or verify MAVLink packets.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SitlDocumentationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.doc = (ROOT / "docs" / "SITL_INTEGRACAO.md").read_text(encoding="utf-8")
        cls.adapter = (ROOT / "src" / "mavlink_vehicle_adapter.pas").read_text(encoding="utf-8")

    def test_loopback_is_required_in_plan(self):
        self.assertIn("127.0.0.1:14550", self.doc)
        self.assertIn("loopback", self.doc)

    def test_no_hardware_in_current_adapter(self):
        self.assertIn("if not State.SimulatorOnly then", self.adapter)

    def test_critical_failures_are_documented(self):
        for condition in ("Sem heartbeat", "Heartbeat obsoleto",
                          "Classe incompatível", "Modo não aprovado",
                          "Entrada obsoleta", "Reconexão"):
            with self.subTest(condition=condition):
                self.assertIn(condition, self.doc)


if __name__ == "__main__":
    unittest.main()
