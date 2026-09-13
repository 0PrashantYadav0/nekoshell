#!/usr/bin/env python3
"""Write the nekoshell iTerm2 dynamic profile file (main profile + music panel).

Colours come from core/theme/palettes.json, the one palette file every themed
part of the rig is generated from (see core/theme/gen-palettes.py).

Usage: build-profiles.py --root /path/to/checkout --out FILE
                         [--flavor mocha] [--window-type N]
                         [--background PATH] [--blend N]

--background sets "Background Image Location" on both profiles and --blend the
"Blend" that fades it behind the text (0 = the image untouched, 1 = the
background colour on top of it). `--background ""` removes both keys again.
Neither flag given leaves the file exactly as it was before they existed.
"""
import argparse
import json
import shlex
from pathlib import Path

# terminals/iterm2/build-profiles.py -> the checkout root is two levels up.
PALETTES = Path(__file__).resolve().parents[2] / "core" / "theme" / "palettes.json"

MAIN_GUID = "4E4B4F53-4845-4C4C-0001-000000000001"
PANEL_GUID = "4E4B4F53-4845-4C4C-0002-000000000002"
# Replaced in main() from --font and --size; the default is what the adapter prints.
FONT = "JetBrainsMonoNF-Regular 15"

ANSI = ["surface1", "red", "green", "yellow", "blue", "pink", "teal", "subtext1",
        "surface2", "red", "green", "yellow", "blue", "pink", "teal", "subtext0"]

# The status bar, left to right. Keys are iTerm2's own, read out of its source:
# a layout is {"components": [...], "advanced configuration": {...}} and each
# component is {"class": ..., "configuration": {"knobs": {...}}}. A component
# with no "configuration" is dropped, so every one of these carries a knobs
# dictionary even where it has nothing to say.
#
# The working directory and git components need iTerm2 shell integration, which
# install.sh downloads and .zshrc sources. The spring pushes everything after it
# to the right edge.
STATUS_BAR_COMPONENTS = [
    ("iTermStatusBarWorkingDirectoryComponent", {"base: priority": 5}),
    ("iTermStatusBarGitComponent", {"base: priority": 5}),
    # The spring reads a different knob per layout algorithm: the spring constant
    # under "tightly packed", the size multiple under "stable", which is the one
    # the advanced configuration below selects.
    ("iTermStatusBarSpringComponent", {"iTermStatusBarSpringComponentSizeMultipleKey": 1}),
    ("iTermStatusBarCPUUtilizationComponent", {"base: priority": 4}),
    ("iTermStatusBarMemoryUtilizationComponent", {"base: priority": 3}),
    ("iTermStatusBarBatteryComponent", {"base: priority": 2}),
    ("iTermStatusBarClockComponent", {"format": "H:mm", "base: priority": 6}),
]


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


def status_bar_layout(palette):
    """The main profile's status bar. iTerm2 ignores a layout it cannot read."""
    return {
        "components": [{"class": cls, "configuration": {"knobs": knobs}}
                       for cls, knobs in STATUS_BAR_COMPONENTS],
        "advanced configuration": {
            # "separator color" was retired after 3.0.0beta1; "separator color 2"
            # is the key iTerm2 reads now.
            "separator color 2": color(palette, "surface1"),
            "background color": color(palette, "mantle"),
            "default text color": color(palette, "text"),
            "algorithm": 0,  # stable: components keep their place as widths change
            "remove empty components": True,
            "draw separator between status bar and terminal": True,
            "font": FONT,
        },
    }


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
        "Use Cursor Guide": True,
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
        "Command": f"/usr/bin/env NEKOSHELL_PANEL=1 {shlex.quote(root)}/bin/nekoshell music --here",
    })
    return p


def apply_background(profiles, background, blend):
    """Set or clear the background image keys on every profile.

    An empty --background is the "no image" instruction, so it takes the blend
    with it: a Blend left behind on a profile with no image is a knob iTerm2
    would keep showing with nothing to apply it to.
    """
    for p in profiles:
        if background is not None:
            if background:
                p["Background Image Location"] = background
            else:
                p.pop("Background Image Location", None)
                p.pop("Blend", None)
        if blend is not None and p.get("Background Image Location"):
            p["Blend"] = blend


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--flavor", default="mocha", help="Catppuccin flavour name")
    ap.add_argument("--font", default="JetBrainsMonoNF-Regular",
                    help="PostScript font name, what the adapter's terminal_font_name prints")
    ap.add_argument("--size", type=int, default=15, help="font size in points")
    ap.add_argument("--window-type", type=int, default=6,
                    help="iTerm2 numeric window type for 'Right of screen'")
    ap.add_argument("--background", default=None,
                    help="background image path; an empty value clears it")
    ap.add_argument("--blend", type=float, default=None,
                    help="how far the background colour fades the image, 0..1")
    a = ap.parse_args()
    global FONT
    FONT = f"{a.font} {a.size}"
    if a.blend is not None and not 0 <= a.blend <= 1:
        raise SystemExit(f"--blend must be between 0 and 1, not {a.blend}")
    palette = load_palette(a.flavor)
    primary = base_profile(palette, "nekoshell", MAIN_GUID)
    # Only the main profile gets a status bar. The panel is a 60-column Spotify
    # window, where a status row would cost a line of the queue for nothing.
    primary["Show Status Bar"] = True
    primary["Status Bar Layout"] = status_bar_layout(palette)
    profiles = [primary, panel_profile(palette, a.root, a.window_type)]
    apply_background(profiles, a.background, a.blend)
    doc = {"Profiles": profiles}
    with open(a.out, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    main()
