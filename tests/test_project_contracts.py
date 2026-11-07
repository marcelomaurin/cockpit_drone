"""Static safety checks; these do not replace compilation or hardware tests."""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

class ProjectContracts(unittest.TestCase):
    def test_catalog_unique_models_and_status(self):
        catalog = json.loads((ROOT / "data/drone_models.json").read_text(encoding="utf-8"))
        self.assertGreaterEqual(len(catalog["models"]), 1)
        seen = set()
        for model in catalog["models"]:
            key = (model["brand"], model["model"])
            self.assertNotIn(key, seen)
            seen.add(key)
            self.assertIn("control_status", model)
            if model.get("cockpit_protocol_index") is None:
                self.assertNotEqual(model["control_status"], "hardware_validated")

    def test_joystick_read_semantics(self):
        source = (ROOT / "src/joystick.pas").read_text(encoding="utf-8")
        block = source.split("function TJoystickController.UpdateState: Boolean;", 1)[-1]
        self.assertIn("FState := NewState;", block)
        self.assertIn("Result := True;", block)
        self.assertIn("ResetState;", block)

    def test_main_handles_poll_failure(self):
        source = (ROOT / "src/main.pas").read_text(encoding="utf-8")
        self.assertIn("JoyDisponivel := FJoystick.UpdateState;", source)
        self.assertIn("X0 := refJoy;", source)

    def test_all_requested_languages(self):
        source = (ROOT / "src/cockpit_i18n.pas").read_text(encoding="utf-8")
        for language in ("pt-BR", "en", "es", "fr", "de", "ru", "zh-CN", "ja", "ar", "hi"):
            self.assertIn("'" + language + "'", source)

if __name__ == "__main__":
    unittest.main()
