#!/usr/bin/env python3
"""Génère l'icône d'app (1024×1024) : le trait de cinq blanc sur dégradé violet, diagonale jaune soleil. Python pur (zlib), sans dépendance."""
import math, struct, zlib, sys

N = 1024
TOP = (0x7B, 0x5C, 0xFF)      # dégradé violet (haut gauche → bas droite)
BOTTOM = (0x3A, 0x1F, 0xB8)
WHITE = (0xFF, 0xFF, 0xFF)
SUN = (0xFF, 0xD2, 0x3F)

# Même géométrie que TallyStrokeShape (normalisée), dans un carré centré.
box = 0.56 * N
ox, oy = (N - box) / 2, (N - box / 1.1) / 2
w, h = box, box / 1.1
def pt(x, y): return (ox + x * w, oy + y * h)
segments = []
for i in range(4):
    x = 0.16 + i * 0.21
    segments.append((pt(x - 0.015, 0.94), pt(x + 0.02, 0.06), WHITE))
segments.append((pt(0.02, 0.74), pt(0.98, 0.28), SUN))
radius = 0.1 * w / 2

def dist(px, py, a, b):
    (ax, ay), (bx, by) = a, b
    dx, dy = bx - ax, by - ay
    t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    cx, cy = ax + t * dx, ay + t * dy
    return math.hypot(px - cx, py - cy)

rows = []
for y in range(N):
    row = bytearray([0])
    for x in range(N):
        g = (x + y) / (2 * N)
        color = tuple(round(TOP[k] * (1 - g) + BOTTOM[k] * g) for k in range(3))
        for a, b, c in segments:
            d = dist(x + 0.5, y + 0.5, a, b)
            cover = max(0.0, min(1.0, radius - d + 0.5))
            if cover > 0:
                color = tuple(round(color[k] * (1 - cover) + c[k] * cover) for k in range(3))
        row += bytes(color)
    rows.append(bytes(row))

def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", N, N, 8, 2, 0, 0, 0)) \
    + chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
out = sys.argv[1] if len(sys.argv) > 1 else "icon.png"
open(out, "wb").write(png)
print("écrit", out, len(png), "octets")
