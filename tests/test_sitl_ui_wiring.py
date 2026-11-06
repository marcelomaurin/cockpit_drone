"""Static wiring checks; compilation and SITL runtime tests are still required."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class SitlUiWiringTests(unittest.TestCase):
    def test_main_has_explicit_opt_in(self):
        source = (ROOT / "src/main.pas").read_text(encoding="utf-8")
        for marker in (
            "FSitlTimer.Enabled := False;",
            "procedure TfrmMain.SitlToggle(Sender: TObject);",
            "procedure TfrmMain.SitlTick(Sender: TObject);",
            "FSitlBridge.Start(PythonExe, ScriptPath)",
            "FSitlBridge.Poll(GetTickCount64)",
            "FSitlBridge.Stop;",
            "FSitlStatus.Caption",
        ):
            self.assertIn(marker, source)

    def test_bridge_drains_output_before_exit(self):
        source = (ROOT / "src/sitl_telemetry_bridge.pas").read_text(encoding="utf-8")
        poll = source.split("procedure TSitlTelemetryBridge.Poll(", 1)[1]
        self.assertLess(poll.index("FProcess.Output.NumBytesAvailable"),
                        poll.index("if not FProcess.Running then"))
        self.assertIn("poStderrToOut", source)

    def test_monitor_is_read_only(self):
        source = (ROOT / "tools/sitl_heartbeat_monitor.py").read_text(encoding="utf-8")
        self.assertIn("udpin:127.0.0.1:", source)
        self.assertIn('"control_authorized": False', source)
        self.assertNotIn("command_long_send(", source)
        self.assertNotIn("set_mode_send(", source)

if __name__ == "__main__":
    unittest.main()
