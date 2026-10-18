#!/usr/bin/env python3
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from importlib.machinery import SourceFileLoader
extract = SourceFileLoader("extract", str(ROOT / "scripts/extract-strings.py")).load_module()

NOT_UI = {
    " ", ",", "×", "ゴ", "ゴゴゴ", "Notchy", "Spotify", "Music", "Glitch", "Serif", "Panel", "Manual", "General", "Zoom",
    "Album", "Artist", "Duration", "Name", "Playback Position", "Player State", "Playing", "Stopped", "Total Time",
    "next track", "previous track", "--debounce=80", "init(coder:) is not supported", "\\u{1F}",
    "Bebas Neue", "Big Shoulders Stencil Display", "Cormorant Garamond", "Dela Gothic One", "Nixie One", "Share Tech Mono",
    "Color no válido: %@", "%@ %", "%@, %@ %",
}

def main():
    catalog = json.loads((ROOT / "Resources/Localization/Localizable.xcstrings").read_text())["strings"]
    missing, untranslated = [], []
    for key, places in sorted(extract.literals().items()):
        if key in NOT_UI or key.startswith("tell application") or key.startswith("builtin-"):
            continue
        normalized = re.sub(r"Volumen %@ por ciento", "Volumen %lld por ciento", key)
        if any(name in key for name in ["Eighty-Six", "Titan", "Clover", "Bleach", "Chainsaw", "Alchemist", "Frieren", "JoJo", "Jujutsu", "Mob Psycho", "Naruto", "One Piece", "Orb:", "Steins", "Tokyo", "Violet"]):
            continue
        entry = catalog.get(normalized)
        if entry is None:
            missing.append((key, places[0]))
        elif not entry["localizations"].get("en", {}).get("stringUnit", {}).get("value"):
            untranslated.append(key)
    for key, place in missing:
        print(f"FALTA  {key!r}  ({place})")
    for key in untranslated:
        print(f"SIN EN {key!r}")
    print(f"{len(missing)} sin catalogar, {len(untranslated)} sin traducir")
    return 1 if missing or untranslated else 0

if __name__ == "__main__":
    sys.exit(main())
