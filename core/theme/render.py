#!/usr/bin/env python3
"""render.py PALETTES SRC DST FLAVOR: substitute @@FLAVOR@@, @@TITLE@@,
@@hex:ROLE@@, @@HEX:ROLE@@, @@sgr:ROLE@@, @@rgb:ROLE@@ from the flavour's palette."""
import json, re, sys
palettes, src, dst, flavor = sys.argv[1:5]
p = json.load(open(palettes))[flavor]
def rgb(role): h = p[role]; return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
def repl(m):
    kind, role = m.group(1), m.group(2)
    if kind == "hex": return p[role]
    if kind == "HEX": return "#" + p[role]
    if kind == "sgr": return "38;2;%d;%d;%d" % rgb(role)
    if kind == "rgb": return "%d,%d,%d" % rgb(role)
    raise SystemExit("unknown placeholder kind: " + kind)
text = open(src, encoding="utf-8").read()
text = text.replace("@@FLAVOR@@", flavor).replace("@@TITLE@@", flavor.capitalize())
text = re.sub(r"@@(hex|HEX|sgr|rgb):([a-z0-9]+)@@", repl, text)
open(dst, "w", encoding="utf-8").write(text)
