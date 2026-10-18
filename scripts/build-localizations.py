#!/usr/bin/env python3
import json, pathlib, sys

def escape(value):
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")

def convert(catalog_path, output_dir, table):
    catalog = json.loads(pathlib.Path(catalog_path).read_text())
    languages = {lang for entry in catalog["strings"].values() for lang in entry.get("localizations", {})}
    for lang in sorted(languages):
        lines = []
        for key, entry in sorted(catalog["strings"].items()):
            unit = entry.get("localizations", {}).get(lang, {}).get("stringUnit")
            if unit and unit.get("value"):
                lines.append(f'"{escape(key)}" = "{escape(unit["value"])}";')
        folder = pathlib.Path(output_dir) / f"{lang}.lproj"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / f"{table}.strings").write_text("\n".join(lines) + "\n", encoding="utf-8")

if __name__ == "__main__":
    source, output = sys.argv[1], sys.argv[2]
    for catalog in sorted(pathlib.Path(source).glob("*.xcstrings")):
        convert(catalog, output, catalog.stem)
