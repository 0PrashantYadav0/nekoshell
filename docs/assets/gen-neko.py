#!/usr/bin/env python3
"""Build the neko mascot: a low-poly mesh (neko.stl) and a render of it (neko.png).

Original artwork, MIT. Standard library only, like the other generators
here, so `python3 docs/assets/gen-neko.py` reproduces both files on any Mac.
The mesh is a chibi black cat sitting on a prompt block; the render is a 3/4 view under
one key light with a shadow map, a hemisphere ambient, Blinn-Phong highlights
and a rim light, drawn at twice the output size and box-filtered down, on a
transparent background with a soft contact shadow so it sits on either GitHub
theme. Colours are Catppuccin mocha.
"""
import math
import struct
import sys
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = 600  # output size in pixels; the render runs at 2x and downsamples
SS = 2
W = H = OUT * SS
SHADOW = 1024  # shadow map side

# Materials: (albedo sRGB hex, specular strength, shininess).
MAT = {
    "fur": ("#181825", 0.42, 28.0),
    "ear": ("#f5c2e7", 0.10, 16.0),
    "iris": ("#a6e3a1", 0.60, 60.0),
    "pupil": ("#11111b", 0.90, 90.0),
    "shine": ("#f8f8ff", 0.0, 1.0),
    "mouth": ("#f5c2e7", 0.10, 8.0),
    "nose": ("#f38ba8", 0.50, 40.0),
    "blush": ("#f38ba8", 0.05, 8.0),
    "block": ("#cba6f7", 0.30, 40.0),
    "chevron": ("#1e1e2e", 0.55, 48.0),
    "cursor": ("#f9e2af", 0.35, 32.0),
    "ground": ("#000000", 0.0, 1.0),
}


# --- vectors ----------------------------------------------------------------
def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def mul(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(a):
    length = math.sqrt(dot(a, a)) or 1.0
    return (a[0] / length, a[1] / length, a[2] / length)


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)


def frame(axis, hint=(0.0, 1.0, 0.0)):
    """Two unit vectors perpendicular to axis."""
    axis = norm(axis)
    if abs(dot(axis, hint)) > 0.95:
        hint = (1.0, 0.0, 0.0)
    u = norm(cross(hint, axis))
    v = cross(axis, u)
    return u, v


# --- mesh primitives --------------------------------------------------------
# A triangle is ((p0, n0), (p1, n1), (p2, n2), material). Smooth surfaces
# carry per-vertex normals; faceted ones repeat the face normal.
tris = []


def flat(p0, p1, p2, mat):
    n = norm(cross(sub(p1, p0), sub(p2, p0)))
    tris.append(((p0, n), (p1, n), (p2, n), mat))


def ellipsoid(center, radii, seg, rings, mat):
    rx, ry, rz = radii
    grid = []
    for i in range(rings + 1):
        phi = math.pi * i / rings
        row = []
        for j in range(seg + 1):
            theta = 2 * math.pi * j / seg
            x, y, z = math.sin(phi) * math.cos(theta), math.cos(phi), math.sin(phi) * math.sin(theta)
            p = (center[0] + rx * x, center[1] + ry * y, center[2] + rz * z)
            n = norm((x / rx, y / ry, z / rz))
            row.append((p, n))
        grid.append(row)
    for i in range(rings):
        for j in range(seg):
            a, b = grid[i][j], grid[i][j + 1]
            c, d = grid[i + 1][j], grid[i + 1][j + 1]
            if i > 0:
                tris.append((a, c, b, mat))
            if i < rings - 1:
                tris.append((b, c, d, mat))


def cone(base, tip, radius, seg, mat, squash=1.0):
    """A closed cone with faceted sides; squash flattens it across its width."""
    axis = sub(tip, base)
    u, v = frame(axis, (0.0, 0.0, 1.0))
    ring = []
    for j in range(seg):
        t = 2 * math.pi * j / seg
        ring.append(add(base, add(mul(u, radius * math.cos(t)), mul(v, radius * squash * math.sin(t)))))
    for j in range(seg):
        a, b = ring[j], ring[(j + 1) % seg]
        flat(a, b, tip, mat)
        flat(b, a, base, mat)


def tube(path, r0, r1, seg, mat):
    """A tube swept along a polyline, tapering from r0 to r1, capped at both ends."""
    rings = []
    for i, p in enumerate(path):
        prev_p = path[max(i - 1, 0)]
        next_p = path[min(i + 1, len(path) - 1)]
        axis = sub(next_p, prev_p)
        u, v = frame(axis)
        r = r0 + (r1 - r0) * i / (len(path) - 1)
        ring = []
        for j in range(seg + 1):
            t = 2 * math.pi * j / seg
            n = norm(add(mul(u, math.cos(t)), mul(v, math.sin(t))))
            ring.append((add(p, mul(n, r)), n))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for j in range(seg):
            a, b = rings[i][j], rings[i][j + 1]
            c, d = rings[i + 1][j], rings[i + 1][j + 1]
            tris.append((a, b, c, mat))
            tris.append((b, d, c, mat))
    ellipsoid(path[0], (r0, r0, r0), seg, 6, mat)
    ellipsoid(path[-1], (r1, r1, r1), seg, 6, mat)


def box(lo, hi, mat, rot=0.0, about=None):
    """An axis-aligned box, optionally turned by rot radians around the z axis."""
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    c = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    if rot:
        cx, cy = about
        cs, sn = math.cos(rot), math.sin(rot)
        c = [(cx + (x - cx) * cs - (y - cy) * sn, cy + (x - cx) * sn + (y - cy) * cs, z) for x, y, z in c]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (0, 4, 7, 3)]
    for a, b, cc, d in faces:
        flat(c[a], c[b], c[cc], mat)
        flat(c[a], c[cc], c[d], mat)


def bezier(p0, p1, p2, p3, n):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c = lerp(p0, p1, t), lerp(p1, p2, t), lerp(p2, p3, t)
        d, e = lerp(a, b, t), lerp(b, c, t)
        out.append(lerp(d, e, t))
    return out


# --- the neko ---------------------------------------------------------------
def build():
    """A chibi black cat on a prompt block: the head is most of it."""
    top = 0.9  # the block's top face
    box((-1.7, 0.0, -0.95), (1.7, top, 0.95), "block")
    # The prompt on the front face: a chevron of two bars, and a cursor.
    z0, z1 = 0.95, 1.04
    box((-1.15, 0.36, z0), (-0.62, 0.50, z1), "chevron", rot=math.radians(42), about=(-0.62, 0.43))
    box((-1.15, 0.36, z0), (-0.62, 0.50, z1), "chevron", rot=math.radians(-42), about=(-0.62, 0.43))
    box((-0.32, 0.26, z0), (0.10, 0.62, z1), "cursor")

    body = (0.0, top + 0.58, 0.10)
    ellipsoid(body, (0.74, 0.62, 0.68), 32, 18, "fur")
    head = (0.0, top + 1.72, 0.14)
    ellipsoid(head, (1.18, 1.00, 1.08), 44, 26, "fur")
    for side in (-1, 1):
        base = (side * 0.66, head[1] + 0.62, head[2] - 0.05)
        tip = (side * 1.02, head[1] + 1.42, head[2] - 0.18)
        cone(base, tip, 0.34, 10, "fur", squash=0.7)
        # The inner ear pokes through the front of the outer one.
        inner_base = (side * 0.66, head[1] + 0.70, head[2] + 0.12)
        inner_tip = (side * 0.96, head[1] + 1.26, head[2] - 0.02)
        cone(inner_base, inner_tip, 0.19, 10, "ear", squash=0.55)
        # Eyes: an iris, a pupil a little in front of it, two highlights.
        eye = (side * 0.46, head[1] - 0.06, head[2] + 1.00)
        ellipsoid(eye, (0.20, 0.26, 0.09), 18, 12, "iris")
        ellipsoid((eye[0], eye[1] - 0.01, eye[2] + 0.05), (0.10, 0.17, 0.09), 14, 10, "pupil")
        ellipsoid((eye[0] - 0.06 * side, eye[1] + 0.11, eye[2] + 0.10), (0.065, 0.065, 0.035), 10, 6, "shine")
        ellipsoid((eye[0] + 0.07 * side, eye[1] - 0.11, eye[2] + 0.10), (0.03, 0.03, 0.02), 8, 5, "shine")
        ellipsoid((side * 0.80, head[1] - 0.32, head[2] + 0.80), (0.16, 0.09, 0.05), 12, 8, "blush")
        # Each half of the w mouth is a short tube.
        m = bezier((side * 0.02, head[1] - 0.36, head[2] + 1.06), (side * 0.12, head[1] - 0.46, head[2] + 1.06), (side * 0.22, head[1] - 0.46, head[2] + 1.05), (side * 0.30, head[1] - 0.36, head[2] + 1.02), 8)
        tube(m, 0.022, 0.022, 8, "mouth")
        # Front paws.
        ellipsoid((side * 0.38, top + 0.18, 0.62), (0.26, 0.18, 0.28), 16, 10, "fur")
    ellipsoid((0.0, head[1] - 0.26, head[2] + 1.06), (0.09, 0.06, 0.05), 12, 8, "nose")
    tail = bezier((0.45, top + 0.36, -0.45), (1.45, top + 0.30, -0.60), (1.55, top + 0.10, 0.55), (1.00, top + 0.15, 0.75), 22)
    tube(tail, 0.17, 0.11, 12, "fur")
    # A shadow catcher: an invisible floor that only shows where a shadow falls.
    g = 8.0
    flat((-g, 0.0, -g), (-g, 0.0, g), (g, 0.0, g), "ground")
    flat((-g, 0.0, -g), (g, 0.0, g), (g, 0.0, -g), "ground")


# --- STL --------------------------------------------------------------------
def write_stl(path):
    """Binary STL, z-up (the usual convention for the format), one shell per part."""

    def zup(p):
        return (p[0], -p[2], p[1])

    out = bytearray(b"nekoshell neko, MIT".ljust(80, b"\0"))
    solid = [t for t in tris if t[3] != "ground"]
    out += struct.pack("<I", len(solid))
    for (p0, _), (p1, _), (p2, _), _ in solid:
        a, b, c = zup(p0), zup(p1), zup(p2)
        n = norm(cross(sub(b, a), sub(c, a)))
        out += struct.pack("<12fH", *n, *a, *b, *c, 0)
    path.write_bytes(out)


# --- rendering --------------------------------------------------------------
def look_at(eye, target, up=(0.0, 1.0, 0.0)):
    f = norm(sub(target, eye))
    r = norm(cross(f, up))
    u = cross(r, f)
    return eye, f, r, u


def rasterise(project, width, height, want_attrs):
    """Scanline-free triangle fill with edge functions and a z-buffer.

    project(p) -> (sx, sy, depth). Returns the depth buffer and, if asked,
    per-pixel (material, position, normal) tuples for the shading pass.
    """
    depth = [float("inf")] * (width * height)
    attrs = [None] * (width * height) if want_attrs else None
    for (p0, n0), (p1, n1), (p2, n2), mat in tris:
        s0, s1, s2 = project(p0), project(p1), project(p2)
        if s0 is None or s1 is None or s2 is None:
            continue
        area = (s1[0] - s0[0]) * (s2[1] - s0[1]) - (s2[0] - s0[0]) * (s1[1] - s0[1])
        if abs(area) < 1e-9:
            continue
        xmin = max(int(min(s0[0], s1[0], s2[0])), 0)
        xmax = min(int(max(s0[0], s1[0], s2[0])) + 1, width - 1)
        ymin = max(int(min(s0[1], s1[1], s2[1])), 0)
        ymax = min(int(max(s0[1], s1[1], s2[1])) + 1, height - 1)
        if xmin > xmax or ymin > ymax:
            continue
        inv = 1.0 / area
        for y in range(ymin, ymax + 1):
            py = y + 0.5
            row = y * width
            for x in range(xmin, xmax + 1):
                px = x + 0.5
                w0 = ((s1[0] - px) * (s2[1] - py) - (s2[0] - px) * (s1[1] - py)) * inv
                if w0 < 0:
                    continue
                w1 = ((s2[0] - px) * (s0[1] - py) - (s0[0] - px) * (s2[1] - py)) * inv
                if w1 < 0:
                    continue
                w2 = 1.0 - w0 - w1
                if w2 < 0:
                    continue
                z = w0 * s0[2] + w1 * s1[2] + w2 * s2[2]
                i = row + x
                if z >= depth[i]:
                    continue
                depth[i] = z
                if want_attrs:
                    pos = (w0 * p0[0] + w1 * p1[0] + w2 * p2[0], w0 * p0[1] + w1 * p1[1] + w2 * p2[1], w0 * p0[2] + w1 * p1[2] + w2 * p2[2])
                    nrm = (w0 * n0[0] + w1 * n1[0] + w2 * n2[0], w0 * n0[1] + w1 * n1[1] + w2 * n2[1], w0 * n0[2] + w1 * n1[2] + w2 * n2[2])
                    attrs[i] = (mat, pos, nrm)
    return depth, attrs


def srgb_to_linear(hexcolour):
    c = [int(hexcolour[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


def linear_to_srgb(v):
    v = max(0.0, min(1.0, v))
    return 1.055 * v ** (1 / 2.4) - 0.055 if v > 0.0031308 else 12.92 * v


def render():
    eye, fwd, right, up = look_at((4.4, 4.9, 7.3), (0.0, 1.75, 0.0))
    fov = math.radians(33.0)
    focal = (H / 2) / math.tan(fov / 2)

    def project(p):
        d = sub(p, eye)
        z = dot(d, fwd)
        if z < 0.1:
            return None
        return (W / 2 + focal * dot(d, right) / z, H / 2 - focal * dot(d, up) / z, z)

    # The shadow map: an orthographic view down the key light.
    light = norm((-0.55, 1.0, 0.72))
    l_fwd = mul(light, -1.0)
    l_right, l_up = frame(l_fwd, (0.0, 1.0, 0.0))
    l_centre = (0.0, 1.4, 0.0)
    l_scale = SHADOW / 7.5

    def light_project(p):
        d = sub(p, l_centre)
        return (SHADOW / 2 + l_scale * dot(d, l_right), SHADOW / 2 - l_scale * dot(d, l_up), dot(d, l_fwd))

    shadow_depth, _ = rasterise(light_project, SHADOW, SHADOW, False)

    def shadow_at(p, n):
        # Normal-offset then compare, averaged over a 5x5 block for soft edges.
        q = add(p, mul(n, 0.015))
        sx, sy, sz = light_project(q)
        cx, cy = int(sx), int(sy)
        lit = 0
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                x, y = cx + dx, cy + dy
                if 0 <= x < SHADOW and 0 <= y < SHADOW and shadow_depth[y * SHADOW + x] + 0.012 < sz:
                    continue
                lit += 1
        return lit / 25.0

    depth, attrs = rasterise(project, W, H, True)

    albedo = {k: srgb_to_linear(v[0]) for k, v in MAT.items()}
    sky = srgb_to_linear("#b4befe")
    floor = srgb_to_linear("#45475a")
    key = 2.0
    pixels = [(0.0, 0.0, 0.0, 0.0)] * (W * H)
    for i, a in enumerate(attrs):
        if a is None:
            continue
        mat, pos, nrm = a
        n = norm(nrm)
        shade = shadow_at(pos, n)
        if mat == "ground":
            # Only the shadow shows on the floor: black, fading with distance from the block.
            fall = max(0.0, 1.0 - (pos[0] ** 2 / 9.0 + pos[2] ** 2 / 6.0) ** 0.5 * 0.55)
            pixels[i] = (0.0, 0.0, 0.0, 0.42 * (1.0 - shade) * fall)
            continue
        base, spec, shine = albedo[mat], MAT[mat][1], MAT[mat][2]
        v = norm(sub(eye, pos))
        hemi = 0.5 + 0.5 * n[1]
        ambient = tuple(sky[c] * hemi + floor[c] * (1.0 - hemi) for c in range(3))
        diffuse = max(0.0, dot(n, light)) * key * shade
        h = norm(add(light, v))
        specular = spec * (max(0.0, dot(n, h)) ** shine) * key * shade
        rim = (0.55 if mat == "fur" else 0.22) * (1.0 - max(0.0, dot(n, v))) ** 3.0
        colour = tuple(base[c] * (0.55 * ambient[c] + diffuse) + specular + rim * sky[c] for c in range(3))
        # A soft shoulder instead of a hard clip, so the lit fur keeps its colour.
        colour = tuple(1.0 - math.exp(-1.35 * c) for c in colour)
        pixels[i] = (colour[0], colour[1], colour[2], 1.0)

    # Box filter down to the output size, with premultiplied alpha.
    rows = []
    for y in range(OUT):
        row = bytearray([0])
        for x in range(OUT):
            r = g = b = a = 0.0
            for dy in range(SS):
                for dx in range(SS):
                    pr, pg, pb, pa = pixels[(y * SS + dy) * W + x * SS + dx]
                    r += pr * pa
                    g += pg * pa
                    b += pb * pa
                    a += pa
            if a > 0:
                r, g, b = r / a, g / a, b / a
            a /= SS * SS
            row += bytes((int(linear_to_srgb(r) * 255 + 0.5), int(linear_to_srgb(g) * 255 + 0.5), int(linear_to_srgb(b) * 255 + 0.5), int(a * 255 + 0.5)))
        rows.append(bytes(row))
    return b"".join(rows)


def write_png(path, raw):
    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", OUT, OUT, 8, 6, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    build()
    write_stl(HERE / "neko.stl")
    print(f"neko.stl: {len(tris) - 2} triangles", file=sys.stderr)
    write_png(HERE / "neko.png", render())
    print(f"neko.png: {OUT}x{OUT}", file=sys.stderr)
