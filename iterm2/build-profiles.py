#!/usr/bin/env python3
"""Write the nekoshell iTerm2 dynamic profile file (main profile + Spotify panel).

Colours come from data/palettes.json, the one palette file every themed part of
the rig is generated from (see scripts/gen-palettes.py).

Usage: build-profiles.py --root /path/to/checkout --out FILE
                         [--flavor mocha] [--window-type N]
"""
import argparse
import json
import shlex
from pathlib import Path

PALETTES = Path(__file__).resolve().parent.parent / "data" / "palettes.json"

MAIN_GUID = "4E4B4F53-4845-4C4C-0001-000000000001"
PANEL_GUID = "4E4B4F53-4845-4C4C-0002-000000000002"
FONT = "JetBrainsMonoNF-Regular 15"

ANSI = ["surface1", "red", "green", "yellow", "blue", "pink", "teal", "subtext1",
        "surface2", "red", "green", "yellow", "blue", "pink", "teal", "subtext0"]


def load_palette(flavor):
    with PALETTES.open(encoding="utf-8") as f:
        palettes = json.load(f)
    if flavor not in palettes:
        raise SystemExit(f"unknown flavour: {flavor} (have {', '.join(sorted(palettes))})")
    return palettes[flavor]


def color(palette, name):
    h = palette[name]
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return {"Red Component": r, "Green Component": g, "Blue Component": b,
            "Alpha Component": 1, "Color Space": "sRGB"}


def base_profile(palette, name, guid):
    p = {
        "Name": name,
        "Guid": guid,
        "Tags": ["nekoshell"],
        "Normal Font": FONT,
        "ASCII Ligatures": True,
        "Use Non-ASCII Font": False,
        "Use Bold Font": True,
        "Use Bright Bold": True,
        "Minimum Contrast": 0,
        "Cursor Type": 1,
        "Blinking Cursor": False,
        "Unlimited Scrollback": True,
        "Silence Bell": True,
        "Show Status Bar": False,
        "Blur": True,
        "Blur Radius": 24,
        "Transparency": 0.1,
        "Initial Use Transparency": True,
        "Window Type": 0,
        "Foreground Color": color(palette, "text"),
        "Background Color": color(palette, "base"),
        "Bold Color": color(palette, "text"),
        "Cursor Color": color(palette, "rosewater"),
        "Cursor Text Color": color(palette, "base"),
        "Cursor Guide Color": color(palette, "surface0"),
        "Selection Color": color(palette, "surface2"),
        "Selected Text Color": color(palette, "text"),
        "Link Color": color(palette, "blue"),
        "Badge Color": color(palette, "peach"),
        "Use Tab Color": True,
        "Tab Color": color(palette, "mauve"),
    }
    for i, role in enumerate(ANSI):
        p[f"Ansi {i} Color"] = color(palette, role)
    return p


def panel_profile(palette, root, window_type):
    p = base_profile(palette, "nekoshell panel", PANEL_GUID)
    p.update({
        "Transparency": 0.06,
        "Has Hotkey": True,
        "HotKey Key Code": 46,
        "HotKey Characters": "µ",
        "HotKey Characters Ignoring Modifiers": "m",
        "HotKey Modifier Flags": 524288,
        "HotKey Window Animates": True,
        "HotKey Window AutoHides": True,
        "HotKey Window Floats": True,
        "HotKey Window Reopens On Activation": False,
        "HotKey Window Dock Click Action": 0,
        "Window Type": window_type,
        "Space": -1,
        "Screen": -2,
        "Columns": 60,
        "Rows": 40,
        "Custom Command": "Yes",
        "Command": f"/usr/bin/env NEKOSHELL_PANEL=1 {shlex.quote(root)}/bin/nekoshell-music",
    })
    return p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--flavor", default="mocha", help="Catppuccin flavour name")
    ap.add_argument("--window-type", type=int, default=6,
                    help="iTerm2 numeric window type for 'Right of screen'")
    a = ap.parse_args()
    palette = load_palette(a.flavor)
    doc = {"Profiles": [base_profile(palette, "nekoshell", MAIN_GUID),
                        panel_profile(palette, a.root, a.window_type)]}
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    main()
