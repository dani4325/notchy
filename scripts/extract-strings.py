#!/usr/bin/env python3
import re, sys, json, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCES = [ROOT / "Sources"]
LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
SKIP_LINE = re.compile(r'logger\.|Logger\(|systemName:|systemImage:|forKey|Notification\.Name|subsystem:|category:|HexColor\(|\.custom\(|family:|withExtension|forResource|URL\(|appendingPathComponent|bundleIdentifier|static let .*Key|case .* = "|fileExtension|kAudio|"com\.|label: "com|#expect|UTType')
TECHNICAL = re.compile(r'^[A-Za-z0-9_.\-/:%@#\\()\[\]]*$')

def interpolate(text):
    return re.sub(r'\\\((.*?)\)', '%@', text)

def literals():
    found = {}
    for base in SOURCES:
        for path in sorted(base.rglob("*.swift")):
            for number, line in enumerate(path.read_text().splitlines(), 1):
                if SKIP_LINE.search(line):
                    continue
                for match in LITERAL.finditer(line):
                    raw = match.group(1)
                    if not raw or TECHNICAL.match(raw.replace(' ', '_')) and ' ' not in raw and not re.search(r'[áéíóúñÁÉÍÓÚÑ¿¡]', raw):
                        if not re.fullmatch(r'[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+', raw):
                            continue
                    key = interpolate(raw)
                    found.setdefault(key, []).append(f"{path.relative_to(ROOT)}:{number}")
    return found

if __name__ == "__main__":
    result = literals()
    if "--json" in sys.argv:
        print(json.dumps(result, ensure_ascii=False, indent=1))
    else:
        for key, places in sorted(result.items()):
            print(f"{key!r:70} {places[0]}")
        print(len(result), "cadenas", file=sys.stderr)
