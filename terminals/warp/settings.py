#!/usr/bin/env python3
"""Read, set or remove one dotted key in a TOML file, leaving every other line
exactly as it was.

Usage: settings.py FILE get KEY
       settings.py FILE set KEY VALUE [TAG]
       settings.py FILE unset KEY

Warp keeps its settings in ~/.warp/settings.toml, a file the Settings panel
rewrites and the user may edit by hand, so nekoshell cannot render it whole
the way it renders its own files. There is also no include mechanism in TOML
to hang a nekoshell file off. This edits the one key instead, and it works on
lines rather than a parsed document because a parse-and-dump would throw away
the user's comments and layout, and because the system python3 (3.9) has no
TOML parser at all.

KEY is a dotted path such as appearance.themes.theme. VALUE is raw TOML text
(`"dark"`, `15.0`, `{ custom = { name = "x", path = "y" } }`); it is written
as given. TAG, when present, is appended as a trailing comment so the line can
be told apart from one the user wrote.

`get` prints every line that defines KEY or something under it: the key line
itself, a dotted form inside a parent section, or the whole body of a
[KEY] / [KEY.sub] section, whichever shape the file uses. It prints the
right-hand side for a key line and exits 1 when nothing defines KEY.

`set` removes every one of those shapes first, so the key is never defined
twice (which Warp rejects as a syntax error and then ignores the whole file),
then writes the new line in the place TOML allows it:
  1. directly under a [parent] header when one exists;
  2. else as a dotted key under the longest existing header that is a prefix
     of the parent (a `[appearance]` header takes `themes.theme = ...`),
     because adding a `[parent]` header below keys that already defined that
     table through dots is a TOML error;
  3. else among the root keys, when root keys already define the parent's
     table through dots, for the same reason;
  4. else as a new [parent] section at the end of the file.
"""
import os
import re
import sys

HEADER = re.compile(r'^\s*\[(\[?)\s*([^\]]+?)\s*\]\]?\s*(#.*)?$')
KEYLINE = re.compile(r'^\s*([A-Za-z0-9_.\-"\']+)\s*=\s*(.*?)\s*$')


def norm(name):
    """A dotted TOML key with the quotes stripped from each segment."""
    parts = []
    for seg in name.split("."):
        seg = seg.strip()
        if len(seg) >= 2 and seg[0] == seg[-1] and seg[0] in "\"'":
            seg = seg[1:-1]
        parts.append(seg)
    return ".".join(parts)


def classify(lines):
    """One (kind, path, rhs) per line: header, key or other. Key paths are
    absolute (section + key)."""
    out = []
    section = ""
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            out.append(("other", None, None))
            continue
        m = HEADER.match(line)
        if m:
            section = norm(m.group(2))
            out.append(("header", section, None))
            continue
        m = KEYLINE.match(line)
        if m:
            key = norm(m.group(1))
            path = section + "." + key if section else key
            out.append(("key", path, m.group(2)))
            continue
        out.append(("other", None, None))
    return out


def under(path, key):
    return path == key or path.startswith(key + ".")


def owned_lines(lines, key):
    """Indexes of every line that defines KEY: matching key lines, and every
    line of a section whose header is KEY or below it."""
    kinds = classify(lines)
    owned = set()
    in_owned_section = False
    for i, (kind, path, _rhs) in enumerate(kinds):
        if kind == "header":
            in_owned_section = under(path, key)
            if in_owned_section:
                owned.add(i)
        elif in_owned_section:
            owned.add(i)
        elif kind == "key" and under(path, key):
            owned.add(i)
    return owned, kinds


TAG_COMMENT = re.compile(r'\s+#\s*nekoshell\s*$')


def cmd_get(lines, key):
    owned, kinds = owned_lines(lines, key)
    found = False
    for i in sorted(owned):
        kind, path, rhs = kinds[i]
        if kind == "key" and path == key:
            # Only our own tag is stripped: a `#` inside a string value is
            # part of the value, and a comment of the user's is theirs.
            print(TAG_COMMENT.sub("", rhs))
        else:
            print(lines[i].rstrip("\n"))
        found = True
    return 0 if found else 1


def insert_position(lines, key):
    """(index, text) for the new line defining KEY, per the rules above."""
    kinds = classify(lines)
    parent, _, leaf = key.rpartition(".")
    headers = [(i, p) for i, (k, p, _) in enumerate(kinds) if k == "header"]
    first_header = headers[0][0] if headers else len(lines)
    if parent:
        for i, p in headers:
            if p == parent:
                return i + 1, leaf
        best = None
        for i, p in headers:
            if parent.startswith(p + ".") and (best is None or len(p) > len(best[1])):
                best = (i, p)
        if best is not None:
            return best[0] + 1, key[len(best[1]) + 1:]
        root_defines_parent = any(
            k == "key" and under(p, parent) for k, p, _ in kinds[:first_header]
        )
        if root_defines_parent:
            return first_header, key
        return None, leaf
    return first_header, leaf


def cmd_set(lines, key, value, tag):
    owned, _ = owned_lines(lines, key)
    kept = [l for i, l in enumerate(lines) if i not in owned]
    suffix = "  # " + tag if tag else ""
    pos, name = insert_position(kept, key)
    new = name + " = " + value + suffix + "\n"
    if pos is None:
        parent = key.rpartition(".")[0]
        if kept and not kept[-1].endswith("\n"):
            kept[-1] += "\n"
        if kept and kept[-1].strip():
            kept.append("\n")
        kept.append("[" + parent + "]\n")
        kept.append(new)
    else:
        kept.insert(pos, new)
    return kept


def cmd_unset(lines, key):
    owned, _ = owned_lines(lines, key)
    return [l for i, l in enumerate(lines) if i not in owned]


def main(argv):
    if len(argv) < 4:
        sys.exit(__doc__.strip().split("\n", 1)[0])
    path, action, key = argv[1], argv[2], norm(argv[3])
    lines = []
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
    if action == "get":
        sys.exit(cmd_get(lines, key))
    if action == "set":
        if len(argv) < 5:
            sys.exit("settings.py: set needs a VALUE")
        out = cmd_set(lines, key, argv[4], argv[5] if len(argv) > 5 else "")
    elif action == "unset":
        out = cmd_unset(lines, key)
    else:
        sys.exit("settings.py: unknown action " + action)
    # A temp file beside the destination, renamed into place: a crash half way
    # must not leave Warp reading a truncated settings file.
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.writelines(out)
    os.replace(tmp, path)


if __name__ == "__main__":
    main(sys.argv)
