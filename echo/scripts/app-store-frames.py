#!/usr/bin/env python3
"""Images de la fiche App Store d'Écho (iPhone 6,9 pouces, 1320 × 2868).

Habille les captures du simulateur (echo/docs/captures, workflow « Écho Captures ») : fond aux couleurs du jeu,
phrase d'accroche en haut (deuxième ligne en couleur), capture arrondie avec un halo.
Usage : python3 echo/scripts/app-store-frames.py   → echo/docs/app-store/01-….png
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "docs" / "captures"
OUT = ROOT / "docs" / "app-store"
W, H = 1320, 2868
FONT = "/usr/share/fonts/opentype/inter/InterDisplay-ExtraBold.otf"
if not Path(FONT).exists():
    FONT = "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf"

CYAN, PINK, GOLD, ORANGE = (77, 240, 255), (255, 77, 154), (255, 216, 77), (255, 140, 50)

# (capture, ligne 1, ligne 2 en couleur, couleur)
SLIDES = [
    ("partie-night", "Ton passé", "te poursuit", CYAN),
    ("partie-ocean", "Frôle tes fantômes,", "multiplie ton score", GOLD),
    ("partie-forest", "Des traînées", "spectaculaires", ORANGE),
    ("accueil", "Un défi chaque jour,", "le même pour tous", PINK),
    ("partie-synthwave", "Des décors", "animés", PINK),
    ("boutique-trails", "16 traînées", "à débloquer", GOLD),
]


def background() -> Image.Image:
    img = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(img)
    top, bottom = (22, 12, 58), (4, 5, 15)
    for y in range(H):
        t = y / H
        draw.line([(0, y), (W, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)))
    glow = Image.new("RGB", (W, H))
    g = ImageDraw.Draw(glow)
    g.ellipse([-300, -200, 700, 700], fill=(20, 90, 110))
    g.ellipse([700, 1900, 1700, 3000], fill=(110, 20, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    return Image.blend(img, Image.composite(glow, img, Image.new("L", (W, H), 255)), 0.55)


def rounded(shot: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.size[0], shot.size[1]], radius=radius, fill=255)
    out = Image.new("RGBA", shot.size)
    out.paste(shot, (0, 0), mask)
    return out


def fit_font(text: str, max_width: int, size: int) -> ImageFont.FreeTypeFont:
    while size > 40:
        font = ImageFont.truetype(FONT, size)
        if font.getlength(text) <= max_width:
            return font
        size -= 4
    return ImageFont.truetype(FONT, size)


def slide(name: str, line1: str, line2: str, color) -> Image.Image:
    source = next(SOURCE.glob(f"*-{name}.png"), None)
    if source is None:
        raise SystemExit(f"Capture manquante : *-{name}.png dans {SOURCE}")
    img = background().convert("RGBA")
    draw = ImageDraw.Draw(img)
    size = min(fit_font(line1, W - 140, 112).size, fit_font(line2, W - 140, 112).size)
    font = ImageFont.truetype(FONT, size)
    for i, (text, fill) in enumerate([(line1, (255, 255, 255)), (line2, color)]):
        y = 150 + i * int(size * 1.18)
        x = (W - font.getlength(text)) / 2
        if fill != (255, 255, 255):
            halo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            ImageDraw.Draw(halo).text((x, y), text, font=font, fill=fill + (200,))
            img = Image.alpha_composite(img, halo.filter(ImageFilter.GaussianBlur(18)))
            draw = ImageDraw.Draw(img)
        draw.text((x, y), text, font=font, fill=fill)

    shot = Image.open(source).convert("RGB")
    width = 1040
    height = int(shot.height * width / shot.width)
    shot = rounded(shot.resize((width, height), Image.LANCZOS), 72)
    x, y = (W - width) // 2, 520
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([x - 6, y - 6, x + width + 6, y + height + 6], radius=78, fill=color + (150,))
    img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(40)))
    img.alpha_composite(shot, (x, y))
    ImageDraw.Draw(img).rounded_rectangle([x, y, x + width, y + height], radius=72, outline=(255, 255, 255, 60), width=3)
    return img.convert("RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.png"):
        old.unlink()
    for i, (name, line1, line2, color) in enumerate(SLIDES, start=1):
        path = OUT / f"{i:02d}-{name}.png"
        slide(name, line1, line2, color).save(path)
        print("✓", path.relative_to(ROOT.parent))


if __name__ == "__main__":
    main()
