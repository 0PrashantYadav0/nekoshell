#!/usr/bin/env python3
"""Write the nekoshell iTerm2 dynamic profile file (main profile + Spotify panel).

Usage: build-profiles.py --root /path/to/checkout --out FILE [--window-type N]
"""
import argparse
import json
import shlex

MAIN_GUID = "4E4B4F53-4845-4C4C-0001-000000000001"
PANEL_GUID = "4E4B4F53-4845-4C4C-0002-000000000002"
FONT = "JetBrainsMonoNF-Regular 15"

MOCHA = {
    "base": "1e1e2e", "mantle": "181825", "crust": "11111b",
    "surface0": "313244", "surface1": "45475a", "surface2": "585b70",
    "overlay0": "6c7086", "subtext0": "a6adc8", "subtext1": "bac2de",
    "text": "cdd6f4", "rosewater": "f5e0dc", "pink": "f5c2e7", "mauve": "cba6f7",
    "red": "f38ba8", "peach": "fab387", "yellow": "f9e2af", "green": "a6e3a1",
    "teal": "94e2d5", "sky": "89dceb", "blue": "89b4fa", "lavender": "b4befe",
}

ANSI = ["surface1", "red", "green", "yellow", "blue", "pink", "teal", "subtext1",
        "surface2", "red", "green", "yellow", "blue", "pink", "teal", "subtext0"]


def color(name):
    h = MOCHA[name]
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return {"Red Component": r, "Green Component": g, "Blue Component": b,
            "Alpha Component": 1, "Color Space": "sRGB"}


def base_profile(name, guid):
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
        "Foreground Color": color("text"),
        "Background Color": color("base"),
        "Bold Color": color("text"),
        "Cursor Color": color("rosewater"),
        "Cursor Text Color": color("base"),
        "Cursor Guide Color": color("surface0"),
        "Selection Color": color("surface2"),
        "Selected Text Color": color("text"),
        "Link Color": color("blue"),
        "Badge Color": color("peach"),
        "Use Tab Color": True,
        "Tab Color": color("mauve"),
    }
    for i, role in enumerate(ANSI):
        p[f"Ansi {i} Color"] = color(role)
    return p


def panel_profile(root, window_type):
    p = base_profile("nekoshell panel", PANEL_GUID)
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
    ap.add_argument("--window-type", type=int, default=6,
                    help="iTerm2 numeric window type for 'Right of screen'")
    a = ap.parse_args()
    doc = {"Profiles": [base_profile("nekoshell", MAIN_GUID), panel_profile(a.root, a.window_type)]}
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    main()
