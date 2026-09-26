#!/usr/bin/env python3
"""Génère l'icône d'app (1024×1024) : le trait de cinq sur encre, diagonale chlorophylle. Python pur (zlib), sans dépendance."""
import math, struct, zlib, sys

N = 1024
INK = (0x16, 0x14, 0x0F)
PAPER = (0xF5, 0xF1, 0xE8)
CHLORO = (0xC6, 0xF4, 0x32)

# Même géométrie que TallyStrokeShape (normalisée), dans un carré centré.
box = 0.56 * N
ox, oy = (N - box) / 2, (N - box / 1.1) / 2
w, h = box, box / 1.1
def pt(x, y): return (ox + x * w, oy + y * h)
segments = []
for i in range(4):
    x = 0.16 + i * 0.21
    segments.append((pt(x - 0.015, 0.94), pt(x + 0.02, 0.06), PAPER))
segments.append((pt(0.02, 0.74), pt(0.98, 0.28), CHLORO))
radius = 0.075 * w / 2

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
        color = INK
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
