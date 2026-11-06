"""Tests for the Lazarus inventory parser, without requiring Lazarus."""
import importlib.util
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("inventory_lazarus", ROOT / "tools/inventory_lazarus.py")
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)

class InventoryTests(unittest.TestCase):
    def test_valid_project_and_package(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            (root / "cockpit.lpi").write_text(
                '<CONFIG><ProjectOptions><RequiredPackages>'
                '<Item Name="LCL"/><Item Name="OpenAI_Drone"/>'
                '</RequiredPackages></ProjectOptions>'
                '<CompilerOptions><SearchPaths><OtherUnitFiles Value="src"/></SearchPaths>'
                '</CompilerOptions></CONFIG>', encoding="utf-8")
            (root / "support.lpk").write_text(
                '<CONFIG><Package><Files><Item><Filename Value="support.pas"/>'
                '</Item></Files></Package></CONFIG>', encoding="utf-8")
            (root / "support.pas").write_text("unit support; interface end.", encoding="utf-8")
            result = module.inventory(root)
            self.assertFalse(result["missing_project"])
            self.assertEqual(result["pascal_source_count"], 1)
            project = next(x for x in result["projects"] if x["kind"] == ".lpi")
            self.assertEqual(project["packages"], ["LCL", "OpenAI_Drone"])
            package = next(x for x in result["projects"] if x["kind"] == ".lpk")
            self.assertEqual(package["units"], ["support.pas"])

    def test_missing_project_and_invalid_xml(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            (root / "broken.lpk").write_text("<CONFIG><broken>", encoding="utf-8")
            result = module.inventory(root)
            self.assertTrue(result["missing_project"])
            self.assertIsNotNone(result["projects"][0]["error"])

if __name__ == "__main__":
    unittest.main()
