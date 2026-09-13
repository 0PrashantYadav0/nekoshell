#!/usr/bin/env python3
"""Write the nekoshell profile for Apple Terminal.app as a .terminal file.

A .terminal file is an XML plist whose top-level dictionary is one profile:
the same dictionary Terminal keeps under "Window Settings" -> <name> in
com.apple.Terminal, so the adapter can hand the file straight to
`defaults write com.apple.Terminal "Window Settings" -dict-add nekoshell`.

Colours come from core/theme/palettes.json, the one palette file every themed
part of the rig is generated from (see core/theme/gen-palettes.py). Terminal
stores each colour and the font as an NSKeyedArchiver binary plist (an NSColor
or NSFont archive), which plistlib can build because it knows about UID.

Usage: build-profile.py --root /path/to/checkout --out FILE
                        [--flavor mocha] [--font JetBrainsMonoNF-Regular] [--size 15]
"""
import argparse
import json
import plistlib
from pathlib import Path

PROFILE_NAME = "nekoshell"

# ANSI 0..15, the same roles in the same order as the iTerm2 adapter, under
# the key names Terminal.app uses for them.
ANSI_KEYS = [
    "ANSIBlackColor", "ANSIRedColor", "ANSIGreenColor", "ANSIYellowColor",
    "ANSIBlueColor", "ANSIMagentaColor", "ANSICyanColor", "ANSIWhiteColor",
    "ANSIBrightBlackColor", "ANSIBrightRedColor", "ANSIBrightGreenColor",
    "ANSIBrightYellowColor", "ANSIBrightBlueColor", "ANSIBrightMagentaColor",
    "ANSIBrightCyanColor", "ANSIBrightWhiteColor",
]
ANSI = ["surface1", "red", "green", "yellow", "blue", "pink", "teal", "subtext1",
        "surface2", "red", "green", "yellow", "blue", "pink", "teal", "subtext0"]

# Terminal.app has no keys for cursor text, selected text or link colour, so
# those roles from the shared rule have nowhere to go here.
COLOR_KEYS = {
    "TextColor": "text",
    "TextBoldColor": "text",
    "BackgroundColor": "base",
    "CursorColor": "rosewater",
    "SelectionColor": "surface2",
}


def load_palette(root, flavor):
    palettes = Path(root) / "core" / "theme" / "palettes.json"
    with palettes.open(encoding="utf-8") as f:
        data = json.load(f)
    if flavor not in data:
        raise SystemExit(f"unknown flavour: {flavor} (have {', '.join(sorted(data))})")
    return data[flavor]


def archive(objects):
    """An NSKeyedArchiver plist whose root is objects[0], as binary plist bytes.

    objects[0] is the root object; "$null" is prepended for it, so a UID(n) in
    the caller's dictionaries points at objects[n - 1].
    """
    doc = {
        "$version": 100000,
        "$archiver": "NSKeyedArchiver",
        "$top": {"root": plistlib.UID(1)},
        "$objects": ["$null"] + objects,
    }
    return plistlib.dumps(doc, fmt=plistlib.FMT_BINARY)


def color(palette, role):
    """An NSColor archive in device RGB: the shape Terminal's own profiles use.

    NSRGB holds the three components as decimal strings separated by spaces,
    NUL-terminated. Values are rounded so the text stays short.
    """
    h = palette[role]
    parts = " ".join(f"{int(h[i:i + 2], 16) / 255:.6g}" for i in (0, 2, 4))
    return archive([
        {"NSRGB": parts.encode() + b"\x00", "NSColorSpace": 2, "$class": plistlib.UID(2)},
        {"$classname": "NSColor", "$classes": ["NSColor", "NSObject"]},
    ])


def font(name, size):
    """An NSFont archive. NSfFlags 16 is what Terminal writes for every font."""
    return archive([
        {"NSSize": float(size), "NSfFlags": 16, "NSName": plistlib.UID(2), "$class": plistlib.UID(3)},
        name,
        {"$classname": "NSFont", "$classes": ["NSFont", "NSObject"]},
    ])


def profile(palette, font_name, size):
    p = {
        "name": PROFILE_NAME,
        "type": "Window Settings",
        "ProfileCurrentVersion": 2.09,
        "Font": font(font_name, size),
        "FontAntialias": True,
        "FontWidthSpacing": 1.0,
        "FontHeightSpacing": 1.0,
        "columnCount": 120,
        "rowCount": 36,
        "BackgroundBlur": 0.0,
        "Bell": False,
        "VisualBell": False,
        "ShowWindowSettingsNameInTitle": False,
        "useOptionAsMetaKey": True,
        # 1: close the window when the shell exits cleanly, so the music
        # window goes away when the player quits instead of sitting on
        # "[Process completed]".
        "shellExitAction": 1,
    }
    for key, role in COLOR_KEYS.items():
        p[key] = color(palette, role)
    for key, role in zip(ANSI_KEYS, ANSI):
        p[key] = color(palette, role)
    return p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--flavor", default="mocha", help="Catppuccin flavour name")
    ap.add_argument("--font", default="JetBrainsMonoNF-Regular",
                    help="PostScript name of the font, as Terminal.app wants it")
    ap.add_argument("--size", type=float, default=15)
    a = ap.parse_args()
    palette = load_palette(a.root, a.flavor)
    doc = profile(palette, a.font, a.size)
    with open(a.out, "wb") as f:
        plistlib.dump(doc, f, fmt=plistlib.FMT_XML, sort_keys=True)


if __name__ == "__main__":
    main()
