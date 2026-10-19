#!/usr/bin/env python3
import re, sys, json, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCES = [ROOT / "Sources"]
LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
STRING = r'"(?:[^"\\\n]|\\.)*"'
TECHNICAL_ARGUMENTS = re.compile(
    r'(?:systemName|systemImage|forKey|forResource|withExtension|subsystem|category|family|fileExtension|named|identifier|bundleIdentifier):\s*' + STRING
    + r'|(?:HexColor|URL\(fileURLWithPath:|Notification\.Name|UTType|appendingPathComponent|\.custom|NSDeviceDescriptionKey|Selector)\(\s*' + STRING
    + r'|(?:logger|Self\.logger)\.\w+\(\s*' + STRING
    + r'|Logger\([^)]*\)'
    + r'|' + r'"com\.[^"\n]*"'
    + r'|case\s+\w+\s*=\s*' + STRING
    + r'|static let \w*Key\w*\s*=\s*' + STRING
)
TECHNICAL = re.compile(r'^[A-Za-z0-9_.\-/:%@#\\()\[\]]*$')

def interpolate(text):
    return re.sub(r'\\\((.*?)\)', '%@', text)

def literals(bases=None):
    found = {}
    for base in bases or SOURCES:
        for path in sorted(base.rglob("*.swift")):
            for number, line in enumerate(path.read_text().splitlines(), 1):
                for match in LITERAL.finditer(TECHNICAL_ARGUMENTS.sub("", line)):
                    raw = match.group(1)
                    if not raw or TECHNICAL.match(raw.replace(' ', '_')) and ' ' not in raw and not re.search(r'[áéíóúñÁÉÍÓÚÑ¿¡]', raw):
                        if not re.fullmatch(r'[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+', raw):
                            continue
                    key = interpolate(raw)
                    found.setdefault(key, []).append(f"{path.name}:{number}")
    return found

if __name__ == "__main__":
    result = literals()
    if "--json" in sys.argv:
        print(json.dumps(result, ensure_ascii=False, indent=1))
    else:
        for key, places in sorted(result.items()):
            print(f"{key!r:70} {places[0]}")
        print(len(result), "cadenas", file=sys.stderr)
