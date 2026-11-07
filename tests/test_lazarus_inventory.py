"""Regression tests for Lazarus dependency inventory."""
import tempfile
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from inventory_lazarus import inventory


class InventoryTests(unittest.TestCase):
    def test_package_names_and_external_dependencies(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "demo.lpi").write_text(
                '<CONFIG><ProjectOptions><RequiredPackages Count="3">'
                '<Item1><PackageName Value="LCL"/></Item1>'
                '<Item2><PackageName Value="lazMapViewerPkg"/></Item2>'
                '<Item3><PackageName Value="localpkg"/></Item3>'
                '</RequiredPackages></ProjectOptions></CONFIG>',
                encoding="utf-8",
            )
            (root / "localpkg.lpk").write_text("<CONFIG/>", encoding="utf-8")
            result = inventory(root)
            project = next(p for p in result["projects"] if p["path"] == "demo.lpi")
            self.assertEqual(project["packages"], ["LCL", "lazMapViewerPkg", "localpkg"])
            self.assertEqual(project["external_packages"], ["lazMapViewerPkg"])


if __name__ == "__main__":
    unittest.main()
