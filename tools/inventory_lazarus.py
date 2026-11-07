#!/usr/bin/env python3
"""Inventory Lazarus project references without requiring FPC/Lazarus.

Run from any working directory:
    python tools/inventory_lazarus.py
    python tools/inventory_lazarus.py --json
"""
import argparse
import json
import pathlib
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXTENSIONS = {".lpi", ".lpk"}

def inventory(root=ROOT):
    projects = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in EXTENSIONS:
            continue
        rel = str(path.relative_to(root))
        item = {"path": rel, "kind": path.suffix.lower(), "packages": [], "units": [], "error": None}
        try:
            tree = ET.parse(path)
            for element in tree.iter():
                if element.tag == "RequiredPackages":
                    for package in element.iter("PackageName"):
                        if package.get("Value"):
                            item["packages"].append(package.get("Value"))
                    for package in element.iter("Item"):
                        if package.get("Name"):
                            item["packages"].append(package.get("Name"))
                if element.tag == "Filename" and element.get("Value"):
                    item["units"].append(element.get("Value"))
            item["packages"] = sorted(set(item["packages"]))
            item["units"] = sorted(set(item["units"]))
        except (ET.ParseError, OSError) as exc:
            item["error"] = str(exc)
        projects.append(item)
    sources = sorted(str(p.relative_to(root)) for p in root.rglob("*.pas") if p.is_file())
    return {"projects": projects, "pascal_source_count": len(sources),
            "pascal_sources": sources, "missing_project": not any(p["kind"] == ".lpi" for p in projects)}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true", help="Machine-readable output")
    parser.add_argument("--root", type=pathlib.Path, default=ROOT, help="Repository checkout to inspect")
    args = parser.parse_args()
    result = inventory(args.root.resolve())
    if args.json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print("Pascal units:", result["pascal_source_count"])
        for p in result["projects"]:
            print(f"{p['kind']} {p['path']}")
            if p["error"]:
                print("  XML ERROR:", p["error"])
            for package in p["packages"]:
                print("  package:", package)
        if result["missing_project"]:
            print("WARNING: No Lazarus .lpi project found")
    return 1 if result["missing_project"] or any(p["error"] for p in result["projects"]) else 0

if __name__ == "__main__":
    raise SystemExit(main())
