#!/usr/bin/env python3
"""Images de la fiche App Store d'Écho : une fresque continue coupée en 6 images (iPhone 6,9 pouces, 1320 × 2868).

Le fond, la traînée lumineuse, son fantôme et les orbes passent d'une image à l'autre : en faisant défiler la fiche,
on voit un seul grand décor. Chaque image montre des parties dans un vrai iPhone, avec une phrase courte qui donne envie.
Sources : captures du simulateur dans echo/docs/captures (workflow « Écho Captures »).
Usage : python3 -I echo/scripts/app-store-frames.py   → echo/docs/app-store/01-….png
"""
import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs" / "captures"
OUT = ROOT / "docs" / "app-store"
W, H, N = 1320, 2868, 6
PW = W * N
FONTS = Path("/usr/share/fonts/opentype/inter")
TITLE = str(FONTS / "InterDisplay-ExtraBold.otf")
LABEL = str(FONTS / "Inter-Bold.otf")

CYAN, PINK, GOLD, ORANGE, WHITE = (77, 240, 255), (255, 77, 154), (255, 216, 77), (255, 150, 60), (255, 255, 255)
random.seed(4)


# MARK: Fresque de fond


def path_y(x: float) -> float:
    """La traînée qui traverse toute la fresque."""
    return H * 0.6 + 420 * math.sin(x / 1150 + 0.6) + 170 * math.sin(x / 410 + 1.3)


def panorama() -> Image.Image:
    # Couleurs des 6 images (de gauche à droite) : nuit, océan, encre-nuit, nuit, violet, synthwave.
    keys = [(16, 20, 62), (6, 52, 78), (30, 18, 70), (14, 18, 58), (44, 14, 78), (58, 10, 68)]
    xs = np.arange(PW)
    centers = np.array([W * (i + 0.5) for i in range(N)])
    cols = np.stack([np.interp(xs, centers, [k[c] for k in keys]) for c in range(3)], axis=1)
    ys = np.linspace(0, 1, H)[:, None, None]
    shade = 1.0 - 0.72 * ys ** 1.3
    img = (cols[None, :, :] * shade).clip(0, 255).astype(np.uint8)
    base = Image.fromarray(img, "RGB")

    # Nébuleuses (dessinées en petit puis floutées, pour aller vite).
    small = Image.new("RGB", (PW // 6, H // 6))
    d = ImageDraw.Draw(small)
    for i in range(16):
        cx, cy = random.uniform(0, PW), random.uniform(0, H)
        r = random.uniform(500, 1100)
        color = random.choice([(40, 120, 160), (140, 40, 120), (80, 40, 170), (20, 110, 120), (150, 60, 40)])
        d.ellipse([(cx - r) / 6, (cy - r * 0.7) / 6, (cx + r) / 6, (cy + r * 0.7) / 6], fill=color)
    glow = small.filter(ImageFilter.GaussianBlur(45)).resize((PW, H), Image.BILINEAR)
    base = ImageChops.add(base, Image.blend(Image.new("RGB", (PW, H)), glow, 0.45))

    layer = Image.new("RGBA", (PW, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(1400):
        x, y = random.uniform(0, PW), random.uniform(0, H)
        r = random.choice([1.5, 2, 2.5, 3, 4])
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, random.randint(70, 220)))
    for _ in range(70):
        sparkle(d, random.uniform(0, PW), random.uniform(0, H), random.uniform(10, 24), (255, 255, 255, 170))
    base = Image.alpha_composite(base.convert("RGBA"), layer)

    # La traînée du joueur (cyan) et, juste derrière, son fantôme (rose, en pointillés) : l'idée du jeu.
    pts = [(x, path_y(x)) for x in range(-200, PW + 200, 6)]
    ghost = [(x - 520, y) for x, y in pts]
    base = glow_line(base, pts, CYAN, 26, 9)
    dots = Image.new("RGBA", (PW, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(dots)
    for i, (x, y) in enumerate(ghost[::10]):
        r = 9
        d.ellipse([x - r, y - r, x + r, y + r], fill=PINK + (230,))
    base = Image.alpha_composite(base, dots.filter(ImageFilter.GaussianBlur(10)))
    base = Image.alpha_composite(base, dots)
    # Orbes dorés posés sur la traînée, à cheval sur les bords des images.
    for x in [W * 1.0 - 40, W * 2.0 + 30, W * 3.0 - 20, W * 4.0 + 40, W * 5.0 - 30, W * 5.75]:
        base = orb(base, x, path_y(x) - 120, 46)
    return base


def glow_line(img: Image.Image, pts, color, width: int, core: int) -> Image.Image:
    halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).line(pts, fill=color + (170,), width=width, joint="curve")
    img = Image.alpha_composite(img, halo.filter(ImageFilter.GaussianBlur(26)))
    line = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(line)
    d.line(pts, fill=color + (255,), width=core + 6, joint="curve")
    d.line(pts, fill=(235, 255, 255, 255), width=max(2, core - 4), joint="curve")
    return Image.alpha_composite(img, line)


def orb(img: Image.Image, x: float, y: float, r: float, color=GOLD) -> Image.Image:
    halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).ellipse([x - r * 2.6, y - r * 2.6, x + r * 2.6, y + r * 2.6], fill=color + (150,))
    img = Image.alpha_composite(img, halo.filter(ImageFilter.GaussianBlur(40)))
    ImageDraw.Draw(img).ellipse([x - r, y - r, x + r, y + r], fill=color + (255,))
    return img


def sparkle(d: ImageDraw.ImageDraw, x: float, y: float, s: float, fill) -> None:
    t = s * 0.18
    d.polygon([(x, y - s), (x + t, y - t), (x + s, y), (x + t, y + t), (x, y + s), (x - t, y + t), (x - s, y), (x - t, y - t)],
              fill=fill)


# MARK: Éléments d'une image


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def caption(img: Image.Image, x0: int, step: int | None, line1: str, line2: str, color) -> Image.Image:
    """Accroche en haut de l'image : pastille d'étape, ligne blanche, ligne en couleur avec halo."""
    d = ImageDraw.Draw(img)
    top = 150
    if step is not None:
        r = 46
        cx = x0 + W / 2
        d.ellipse([cx - r, top - r + 20, cx + r, top + r + 20], fill=color + (255,))
        f = font(TITLE, 56)
        d.text((cx, top + 20), str(step), font=f, fill=(10, 10, 30), anchor="mm")
        top += 120
    size = 132
    while size > 60 and max(font(TITLE, size).getlength(t) for t in (line1, line2)) > W - 150:
        size -= 4
    f = font(TITLE, size)
    for i, (text, fill) in enumerate([(line1, WHITE), (line2, color)]):
        y = top + i * int(size * 1.16)
        if fill != WHITE:
            halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
            ImageDraw.Draw(halo).text((x0 + W / 2, y), text, font=f, fill=fill + (210,), anchor="ma")
            img = Image.alpha_composite(img, halo.filter(ImageFilter.GaussianBlur(20)))
            d = ImageDraw.Draw(img)
        d.text((x0 + W / 2, y), text, font=f, fill=fill, anchor="ma")
    return img


def rr_mask(size: tuple[int, int], radius: float, inset: float = 0) -> Image.Image:
    """Masque de rectangle arrondi lissé (dessiné 4× plus grand puis réduit : bords sans escalier)."""
    k = 4
    big = Image.new("L", (size[0] * k, size[1] * k), 0)
    ImageDraw.Draw(big).rounded_rectangle([inset * k, inset * k, (size[0] - inset) * k - 1, (size[1] - inset) * k - 1],
                                          radius=radius * k, fill=255)
    return big.resize(size, Image.LANCZOS)


def find_shot(name: str) -> Path:
    """Capture `*-<name>.png` (ex. « partie-night-neon »), sinon la capture du même décor."""
    found = next(SOURCE.glob(f"*-{name}.png"), None)
    if found is None and name.count("-") >= 2:
        found = next(SOURCE.glob(f"*-{name.rsplit('-', 1)[0]}*.png"), None)
    if found is None:
        raise SystemExit(f"Capture manquante : {name}")
    return found


def iphone(shot: Image.Image, width: int) -> Image.Image:
    """Capture dans un iPhone : coins très arrondis comme l'écran, bord en titane, bordure noire fine, boutons."""
    s = width / shot.width
    height = int(shot.height * s)
    screen = shot.resize((width, height), Image.LANCZOS)
    bezel, rim, pad = 18, 9, 14
    sw, sh = width + 2 * bezel, height + 2 * bezel
    fw, fh = sw + 2 * rim, sh + 2 * rim
    canvas = Image.new("RGBA", (fw + 2 * pad, fh + 2 * pad), (0, 0, 0, 0))
    screen_radius = width * 0.14
    # Boutons latéraux (action et volume à gauche, marche à droite), sous le cadre.
    d = ImageDraw.Draw(canvas)
    button = (70, 72, 80, 255)
    for y, h in [(0.17, 0.045), (0.25, 0.08), (0.35, 0.08)]:
        d.rounded_rectangle([pad - 7, pad + fh * y, pad + 10, pad + fh * (y + h)], radius=6, fill=button)
    d.rounded_rectangle([pad + fw - 10, pad + fh * 0.27, pad + fw + 7, pad + fh * 0.4], radius=6, fill=button)
    # Cadre titane : dégradé clair-sombre, liseré brillant.
    body = Image.new("RGBA", (fw, fh))
    grad = np.linspace(0, 1, fw)[None, :]
    tone = (120 + 60 * np.cos(grad * math.pi * 2) ** 2).astype(np.uint8)
    metal = np.stack([np.repeat(tone, fh, 0) * 0.62, np.repeat(tone, fh, 0) * 0.64, np.repeat(tone, fh, 0) * 0.7,
                      np.full((fh, fw), 255)], axis=2).clip(0, 255).astype(np.uint8)
    body = Image.fromarray(metal, "RGBA")
    outer = rr_mask((fw, fh), screen_radius + bezel + rim)
    frame = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    frame.paste(body, (0, 0), outer)
    # Bordure noire puis écran.
    black = Image.new("RGBA", (fw, fh), (6, 6, 9, 255))
    frame.paste(black, (0, 0), rr_mask((fw, fh), screen_radius + bezel, inset=rim))
    shine = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    ImageDraw.Draw(shine).rounded_rectangle([1, 1, fw - 2, fh - 2], radius=screen_radius + bezel + rim,
                                            outline=(235, 238, 245, 170), width=2)
    frame = Image.alpha_composite(frame, shine)
    screen_layer = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    screen_layer.paste(screen, (rim + bezel, rim + bezel), rr_mask((width, height), screen_radius))
    frame = Image.alpha_composite(frame, screen_layer)
    canvas.alpha_composite(frame, (pad, pad))
    return canvas


def phone(img: Image.Image, shot_name: str, cx: float, top: float, width: int, angle: float, glow) -> Image.Image:
    """Pose une capture dans un iPhone (légère inclinaison, halo coloré dessous)."""
    frame = iphone(Image.open(find_shot(shot_name)).convert("RGB"), width)
    rotated = frame.rotate(angle, resample=Image.BICUBIC, expand=True)
    px, py = cx - rotated.width / 2, top + frame.height / 2 - rotated.height / 2
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    alpha = rotated.split()[3].point(lambda a: 170 if a > 0 else 0)
    tint = Image.new("RGBA", rotated.size, glow + (0,))
    tint.putalpha(alpha)
    shadow.alpha_composite(tint, (int(px), int(py) + 40))
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(60)))
    img.alpha_composite(rotated, (int(px), int(py)))
    return img


# MARK: Les 6 images


def sticker(img: Image.Image, text: str, at: tuple[float, float], color, size: int, angle: float) -> Image.Image:
    """Gros texte lumineux incliné (ex. « ×5 »)."""
    f = font(TITLE, size)
    box = f.getbbox(text)
    layer = Image.new("RGBA", (box[2] + 120, box[3] + 120), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((60, 60), text, font=f, fill=color + (255,))
    glow = layer.filter(ImageFilter.GaussianBlur(26))
    layer = Image.alpha_composite(glow, layer).rotate(angle, resample=Image.BICUBIC, expand=True)
    img.alpha_composite(layer, (int(at[0] - layer.width / 2), int(at[1] - layer.height / 2)))
    return img


def build() -> Image.Image:
    img = panorama()
    x = lambda i: W * i

    # Téléphones à cheval sur deux images (derrière les téléphones principaux) : plus de parties, défilement continu.
    img = phone(img, "partie-ocean-electric", x(1), 1500, 560, 9, CYAN)
    img = phone(img, "partie-night-comet", x(2), 1560, 560, -9, PINK)
    img = phone(img, "partie-synthwave-neon", x(4), 1500, 560, 9, PINK)
    img = phone(img, "partie-forest-sakura", x(5), 1560, 560, -9, GOLD)

    img = caption(img, x(0), None, "Ne touche pas", "ton passé", CYAN)
    img = phone(img, "partie-night-neon", x(0) + W / 2, 760, 840, -3, CYAN)

    img = caption(img, x(1), None, "Chaque manche,", "un fantôme de plus", PINK)
    img = phone(img, "partie-ink-sakura", x(1) + W / 2, 760, 840, 3, PINK)

    img = caption(img, x(2), None, "Frôle-les pour", "exploser ton score", GOLD)
    img = phone(img, "partie-ocean-bubbles", x(2) + W / 2, 760, 840, -3, GOLD)
    img = sticker(img, "×5", (x(2) + 1080, 1060), GOLD, 210, -12)

    img = caption(img, x(3), None, "Des traînées", "de folie", ORANGE)
    img = phone(img, "partie-forest-fire", x(3) + W / 2, 760, 840, 3, ORANGE)

    img = caption(img, x(4), None, "Un nouveau défi", "chaque jour", PINK)
    img = phone(img, "accueil", x(4) + W / 2, 760, 840, -3, PINK)

    img = caption(img, x(5), None, "16 traînées,", "5 décors animés", GOLD)
    img = phone(img, "partie-synthwave-galaxy", x(5) + W / 2 - 190, 860, 680, -7, PINK)
    img = phone(img, "boutique-trails", x(5) + W / 2 + 170, 990, 680, 5, GOLD)
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.png"):
        old.unlink()
    fresco = build().convert("RGB")
    names = ["ton-passe", "fantomes", "score", "trainees", "defi-du-jour", "collection"]
    for i, name in enumerate(names):
        path = OUT / f"{i + 1:02d}-{name}.png"
        fresco.crop((i * W, 0, (i + 1) * W, H)).save(path)
        print("✓", path.relative_to(ROOT.parent))


if __name__ == "__main__":
    main()
