#!/usr/bin/env python3
"""Builds Sources/FindSFSymbols/Resources/symbols.json from the SF Symbols app metadata."""
import json
import plistlib
from pathlib import Path

META = Path("/Applications/SF Symbols.app/Contents/Resources/Metadata")
OUT = Path(__file__).resolve().parent.parent / "Sources/FindSFSymbols/Resources/symbols.json"

LOCALES = {
    "ar", "he", "hi", "ja", "ko", "th", "zh", "rtl", "el", "ru", "km", "my", "bn", "gu", "kn",
    "ml", "mni", "mr", "or", "pa", "si", "sat", "ta", "te", "hans", "hant",
}
# Shape and state modifiers. Symbols that differ only by these are one search result.
MODIFIERS = {"fill", "circle", "square", "rectangle", "slash", "inverse", "dashed", "dotted"}


def load(name):
    with open(META / name, "rb") as f:
        return plistlib.load(f)


availability = load("name_availability.plist")
names = availability["symbols"]
# The first iOS version that knows a symbol name. "2022.2" -> 16.4
ios = {year: float(release["iOS"]) for year, release in availability["year_to_release"].items()}
search = load("symbol_search.plist")
symbol_categories = load("symbol_categories.plist")
labels = {c["key"]: c["label"] for c in load("categories.plist")}


def base(name):
    return ".".join(p for p in name.split(".") if p not in MODIFIERS)


groups = {}
for name in names:
    parts = name.split(".")
    if parts[-1] in LOCALES or parts[0].isdigit():
        continue
    groups.setdefault(base(name), []).append(name)

symbols = []
for key, variants in sorted(groups.items()):
    # Show the fill variant if there is one. It reads better as a physical object.
    shown = next((v for v in (key + ".fill", key) if v in variants), min(variants, key=len))
    keywords = sorted({k for v in variants for k in search.get(v, [])})
    categories = sorted({
        labels[c] for v in variants for c in symbol_categories.get(v, [])
        if c in labels and c not in ("all", "whatsnew", "multicolor", "variablecolor", "variable")
    })
    symbols.append({"name": shown, "keywords": keywords, "categories": categories, "ios": ios[names[shown]]})

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(symbols, separators=(",", ":")))
print(f"{len(names)} names -> {len(symbols)} symbols, {OUT.stat().st_size // 1024} KB")
