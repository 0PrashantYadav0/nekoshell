#!/usr/bin/env python3
"""Generate data/palettes.json from catppuccin/palette at a pinned commit.

Downloads palette.json from
https://raw.githubusercontent.com/catppuccin/palette/<sha>/palette.json and writes
one object per flavour (latte, frappe, macchiato, mocha), each mapping the 26
Catppuccin role names to a lowercase hex string without the leading "#". Flavours
are written in alphabetical order; inside a flavour the roles keep Catppuccin's
own order (rosewater first, crust last). Standard library only.

Pinned commit: 07d02aa110ef9eb7e7427afca5c73ba9cf7f8ebd
(catppuccin/palette main, resolved 2026-09-11 via
`git ls-remote https://github.com/catppuccin/palette.git main`).
"""
import json
import urllib.request
from pathlib import Path

SHA = "07d02aa110ef9eb7e7427afca5c73ba9cf7f8ebd"
URL = f"https://raw.githubusercontent.com/catppuccin/palette/{SHA}/palette.json"
FLAVOURS = ("frappe", "latte", "macchiato", "mocha")
# Two flavours known by heart. If upstream ever renames or restyles a role these
# stop matching and the generator refuses to write a wrong palette.
SANITY = {"mocha": ("base", "1e1e2e"), "latte": ("base", "eff1f5")}


def fetch_palette():
    with urllib.request.urlopen(URL) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main():
    upstream = fetch_palette()
    out = {}
    for flavour in sorted(FLAVOURS):
        colors = upstream[flavour]["colors"]
        roles = sorted(colors, key=lambda name: colors[name]["order"])
        out[flavour] = {name: colors[name]["hex"].lstrip("#").lower() for name in roles}
        if len(out[flavour]) != 26:
            raise SystemExit(f"{flavour}: expected 26 roles, got {len(out[flavour])}")

    for flavour, (role, expected) in SANITY.items():
        got = out[flavour][role]
        if got != expected:
            raise SystemExit(f"{flavour}.{role}: expected {expected}, got {got}")

    dest = Path(__file__).resolve().parent.parent / "data" / "palettes.json"
    dest.parent.mkdir(parents=True, exist_ok=True)
    with dest.open("w", encoding="utf-8") as f:
        json.dump(out, f, indent=2)
        f.write("\n")
    print(f"wrote {dest} ({len(out)} flavours)")


if __name__ == "__main__":
    main()
