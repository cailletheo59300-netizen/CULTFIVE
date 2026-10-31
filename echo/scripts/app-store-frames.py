#!/usr/bin/env python3
"""Images de la fiche App Store d'Écho : une fresque continue coupée en 6 images (iPhone 6,9 pouces, 1320 × 2868).

Le fond, la traînée lumineuse, son fantôme et les orbes passent d'une image à l'autre : en faisant défiler la fiche,
on voit un seul grand décor. Chaque image explique une étape du jeu (accroche + capture ou schéma + étiquettes).
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
    size = 116
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


def phone(img: Image.Image, shot_name: str, cx: float, top: float, width: int, angle: float, glow) -> tuple[Image.Image, callable]:
    """Pose une capture dans un téléphone (bord noir arrondi, halo coloré, légère inclinaison).
    Renvoie aussi une fonction qui convertit un point de la capture (pixels d'origine) en point de la fresque."""
    shot = Image.open(next(SOURCE.glob(f"*-{shot_name}.png"))).convert("RGB")
    s = width / shot.width
    height = int(shot.height * s)
    shot = shot.resize((width, height), Image.LANCZOS)
    bezel = 22
    fw, fh = width + 2 * bezel, height + 2 * bezel
    frame = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle([0, 0, fw - 1, fh - 1], radius=96, fill=(8, 8, 14, 255),
                                            outline=(255, 255, 255, 70), width=3)
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, width, height], radius=76, fill=255)
    frame.paste(shot, (bezel, bezel), mask)
    rotated = frame.rotate(angle, resample=Image.BICUBIC, expand=True)
    px, py = cx - rotated.width / 2, top + fh / 2 - rotated.height / 2
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    alpha = rotated.split()[3].point(lambda a: 150 if a > 0 else 0)
    tint = Image.new("RGBA", rotated.size, glow + (0,))
    tint.putalpha(alpha)
    shadow.alpha_composite(tint, (int(px), int(py) + 30))
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(55)))
    img.alpha_composite(rotated, (int(px), int(py)))

    center = (cx, top + fh / 2)
    a = math.radians(angle)

    def to_canvas(sx: float, sy: float) -> tuple[float, float]:
        x = bezel + sx * s - fw / 2
        y = bezel + sy * s - fh / 2
        # Rotation PIL : sens inverse des aiguilles d'une montre, axe y vers le bas.
        return center[0] + x * math.cos(a) + y * math.sin(a), center[1] - x * math.sin(a) + y * math.cos(a)

    return img, to_canvas


def label(img: Image.Image, text: str, at: tuple[float, float], to: tuple[float, float], color) -> Image.Image:
    """Étiquette (pastille de texte) reliée par un trait à un point de la capture."""
    d = ImageDraw.Draw(img)
    f = font(LABEL, 50)
    tw = f.getlength(text)
    x, y = at
    d.line([at, to], fill=color + (255,), width=6)
    r = 14
    d.ellipse([to[0] - r, to[1] - r, to[0] + r, to[1] + r], fill=color + (255,), outline=WHITE + (255,), width=4)
    box = [x - tw / 2 - 34, y - 46, x + tw / 2 + 34, y + 46]
    halo = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(halo).rounded_rectangle(box, radius=46, fill=color + (160,))
    img = Image.alpha_composite(img, halo.filter(ImageFilter.GaussianBlur(18)))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=46, fill=color + (255,))
    d.text((x, y), text, font=f, fill=(10, 10, 30), anchor="mm")
    return img


def swipe(img: Image.Image, at: tuple[float, float]) -> Image.Image:
    """Geste du doigt : bout de doigt lumineux et arc de mouvement."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x, y = at
    d.arc([x - 260, y - 150, x + 60, y + 170], start=200, end=330, fill=WHITE + (230,), width=12)
    d.polygon([(x + 30, y - 120), (x + 66, y - 60), (x - 4, y - 70)], fill=WHITE + (230,))
    d.ellipse([x - 230 - 58, y + 20 - 58, x - 230 + 58, y + 20 + 58], fill=WHITE + (90,), outline=WHITE + (230,), width=8)
    img = Image.alpha_composite(img, layer.filter(ImageFilter.GaussianBlur(12)))
    return Image.alpha_composite(img, layer)


def ghost_diagram(img: Image.Image, x0: int) -> Image.Image:
    """Schéma : manche 1 (ton trajet) puis manche 2 (le même trajet devient un fantôme qui te poursuit)."""
    panels = [(760, "Manche 1 : ton trajet"), (1720, "Manche 2 : il te poursuit")]
    curve = lambda t: (x0 + 250 + 820 * t, 0 + 300 - 210 * math.sin(t * math.pi * 1.3) + 120 * t)
    for idx, (top, title) in enumerate(panels):
        card = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ImageDraw.Draw(card).rounded_rectangle([x0 + 110, top, x0 + W - 110, top + 860], radius=60,
                                               fill=(12, 14, 44, 215), outline=(255, 255, 255, 70), width=3)
        img = Image.alpha_composite(img, card)
        d = ImageDraw.Draw(img)
        d.text((x0 + W / 2, top + 80), title, font=font(LABEL, 56), fill=WHITE, anchor="mm")
        pts = [(curve(t / 100)[0], top + 220 + curve(t / 100)[1]) for t in range(101)]
        if idx == 0:
            img = glow_line(img, pts, CYAN, 22, 10)
            img = orb(img, *pts[-1], 40)
            d = ImageDraw.Draw(img)
            d.ellipse([pts[0][0] - 26, pts[0][1] - 26, pts[0][0] + 26, pts[0][1] + 26], fill=WHITE)
        else:
            # Le fantôme rejoue le trajet de la manche 1…
            dots = Image.new("RGBA", img.size, (0, 0, 0, 0))
            dd = ImageDraw.Draw(dots)
            for x, y in pts[:70:4]:
                dd.ellipse([x - 10, y - 10, x + 10, y + 10], fill=PINK + (230,))
            gx, gy = pts[70]
            dd.ellipse([gx - 30, gy - 30, gx + 30, gy + 30], fill=PINK + (255,))
            img = Image.alpha_composite(img, dots.filter(ImageFilter.GaussianBlur(12)))
            img = Image.alpha_composite(img, dots)
            # … pendant que tu traces un nouveau chemin pour l'éviter.
            new = [(x0 + 230 + 800 * (t / 100), top + 640 - 300 * (t / 100) ** 1.4 - 80 * math.sin(t / 100 * 6)) for t in range(101)]
            img = glow_line(img, new, CYAN, 22, 10)
            d = ImageDraw.Draw(img)
            ex, ey = new[-1]
            d.ellipse([ex - 26, ey - 26, ex + 26, ey + 26], fill=WHITE)
            img = label(img, "Évite-le !", (gx + 40, gy + 230), (gx, gy + 34), PINK)
    return img


# MARK: Les 6 images


def build() -> Image.Image:
    img = panorama()
    x = lambda i: W * i

    # 1. Glisser, attraper.
    img = caption(img, x(0), 1, "Glisse ton doigt,", "attrape les orbes", CYAN)
    img, at = phone(img, "partie-ocean", x(0) + W / 2, 780, 860, 3, CYAN)
    img = swipe(img, (x(0) + 1000, 2520))

    # 2. Le principe : la manche devient un fantôme (schéma).
    img = caption(img, x(1), 2, "Chaque manche devient", "un fantôme", PINK)
    img = ghost_diagram(img, x(1))

    # 3. Frôler : le multiplicateur.
    img = caption(img, x(2), 3, "Frôle tes fantômes :", "jusqu'à ×5 !", GOLD)
    img, at = phone(img, "partie-ink", x(2) + W / 2, 780, 860, -3, GOLD)
    img = label(img, "Multiplicateur", (x(2) + 300, 1150), at(585, 462), GOLD)

    # 4. Les échos pâles se dévorent.
    img = caption(img, x(3), 4, "Les échos pâles", "se dévorent", CYAN)
    img, at = phone(img, "partie-night", x(3) + W / 2, 780, 860, 3, CYAN)
    img = label(img, "Écho pâle", (x(3) + 1020, 1180), at(758, 834), WHITE)
    img = label(img, "Toi", (x(3) + 260, 1900), at(704, 1526), CYAN)

    # 5. Défi du jour.
    img = caption(img, x(4), None, "Un défi chaque jour,", "le même pour tous", PINK)
    img, at = phone(img, "accueil", x(4) + W / 2, 780, 860, -3, PINK)
    img = label(img, "Ta série", (x(4) + 1040, 1050), at(470, 360), ORANGE)

    # 6. Collection : traînées et décors (deux téléphones en éventail).
    img = caption(img, x(5), None, "16 traînées,", "5 décors animés", GOLD)
    img, _ = phone(img, "partie-synthwave", x(5) + W / 2 - 200, 880, 680, -7, PINK)
    img, _ = phone(img, "boutique-trails", x(5) + W / 2 + 175, 1010, 680, 5, GOLD)
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.png"):
        old.unlink()
    fresco = build().convert("RGB")
    names = ["glisse", "fantome", "multiplicateur", "echos-pales", "defi-du-jour", "collection"]
    for i, name in enumerate(names):
        path = OUT / f"{i + 1:02d}-{name}.png"
        fresco.crop((i * W, 0, (i + 1) * W, H)).save(path)
        print("✓", path.relative_to(ROOT.parent))


if __name__ == "__main__":
    main()
