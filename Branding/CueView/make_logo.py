"""Erzeugt Icon und Wortmarke von CueView (Variante A: Bildschirm mit Play und KlangNIVEAU-Schwung).

Aufruf aus dem Repo-Stamm:  python3 Branding/CueView/make_logo.py
Benötigt Pillow und die macOS-Schriften Snell Roundhand und Avenir Next.
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).parent
DARK, RED, ORANGE, PAPER = (0x15, 0x13, 0x13), (0xEE, 0x1C, 0x25), (0xFF, 0x76, 0x2F), (0xF2, 0xF1, 0xEF)
SS = 4  # Überabtastung für glatte Kanten


def gradient(size, start, end, angle):
    small = Image.new("RGBA", (64, 64))
    ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    span = abs(64 * ca) + abs(64 * sa)
    for y in range(64):
        for x in range(64):
            t = min(max(((x - 32) * ca + (y - 32) * sa) / span + 0.5, 0), 1)
            small.putpixel((x, y), tuple(int(start[i] + (end[i] - start[i]) * t) for i in range(3)) + (255,))
    return small.resize(size, Image.BILINEAR)


def tapered_arc(box, start, end, width, steps=240):
    """Polygon eines Bogens, der zu beiden Enden spitz zuläuft – wie der Schwung im KlangNIVEAU-Logo."""
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    rx, ry = (box[2] - box[0]) / 2, (box[3] - box[1]) / 2
    outer, inner = [], []
    for i in range(steps + 1):
        t = i / steps
        a = math.radians(start + (end - start) * t)
        half = width / 2 * math.sin(math.pi * t) ** 0.7
        outer.append((cx + (rx + half) * math.cos(a), cy + (ry + half) * math.sin(a)))
        inner.append((cx + (rx - half) * math.cos(a), cy + (ry - half) * math.sin(a)))
    return outer + inner[::-1]


def paint(image, fill, draw):
    mask = Image.new("L", image.size, 0)
    draw(ImageDraw.Draw(mask))
    layer = fill if isinstance(fill, Image.Image) else Image.new("RGBA", image.size, fill + (255,))
    image.paste(layer, (0, 0), mask)


def icon(size=1024):
    S, u = size * SS, size * SS / 1024
    image = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    margin = (1024 - 824) / 2 * u  # macOS-Icon-Raster
    paint(image, gradient((S, S), (0x24, 0x20, 0x20), (0x0F, 0x0D, 0x0D), 90),
          lambda d: d.rounded_rectangle((margin, margin, S - margin, S - margin), radius=185 * u, fill=255))
    warm = gradient((S, S), RED, ORANGE, -20)
    # Bildschirm mit Fuß
    paint(image, PAPER, lambda d: d.rounded_rectangle((262 * u, 340 * u, 762 * u, 650 * u), radius=40 * u, outline=255, width=int(30 * u)))
    paint(image, PAPER, lambda d: d.rectangle((476 * u, 650 * u, 548 * u, 706 * u), fill=255))
    paint(image, PAPER, lambda d: d.rounded_rectangle((386 * u, 698 * u, 638 * u, 730 * u), radius=16 * u, fill=255))
    # Play-Dreieck mit gerundeten Ecken (über Konturstrich)
    cx, cy, h = 522 * u, 495 * u, 170 * u
    triangle = [(cx - h * 0.45, cy - h * 0.52), (cx - h * 0.45, cy + h * 0.52), (cx + h * 0.55, cy)]
    corner = 9 * u

    def rounded_triangle(d):
        d.polygon(triangle, fill=255)
        for i, (x, y) in enumerate(triangle):
            d.line([(x, y), triangle[(i + 1) % 3]], fill=255, width=int(2 * corner))
            d.ellipse((x - corner, y - corner, x + corner, y + corner), fill=255)

    paint(image, warm, rounded_triangle)
    # KlangNIVEAU-Schwung über dem Bildschirm
    paint(image, warm, lambda d: d.polygon(tapered_arc((150 * u, 236 * u, 880 * u, 830 * u), 198, 342, 54 * u), fill=255))
    return image.resize((size, size), Image.LANCZOS)


def wordmark(tagline=True):
    W, H = 1600 * SS, (560 if tagline else 470) * SS
    u = SS
    image = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    script = ImageFont.truetype("/System/Library/Fonts/Supplemental/SnellRoundhand.ttc", 300 * u, index=2)
    heavy = ImageFont.truetype("/System/Library/Fonts/Avenir Next.ttc", 250 * u, index=8)
    warm = gradient((W, H), RED, ORANGE, -10)
    paint(image, warm, lambda d: (d.text((300 * u, -10 * u), "Cue", font=script, fill=255),
                                  d.polygon(tapered_arc((120 * u, 70 * u, 1500 * u, 380 * u), 195, 345, 30 * u), fill=255)))
    draw = ImageDraw.Draw(image)
    draw.text(((W - draw.textlength("VIEW", font=heavy)) / 2 + 120 * u, 215 * u), "VIEW", font=heavy, fill=PAPER)
    if tagline:
        small = ImageFont.truetype("/System/Library/Fonts/Avenir Next.ttc", 44 * u, index=2)
        text = " ".join("MESSE-PLAYER · KLANGNIVEAU")
        draw.text(((W - draw.textlength(text, font=small)) / 2 + 120 * u, 470 * u), text, font=small, fill=PAPER)
    image = image.crop(image.getbbox())
    return image.resize((image.width // SS, image.height // SS), Image.LANCZOS)


if __name__ == "__main__":
    icon().save(OUT / "cueview-icon-1024.png")
    wordmark().save(OUT / "cueview-wortmarke.png")
    wordmark(tagline=False).save(OUT / "cueview-wortmarke-kopf.png")
    print("Icon und Wortmarken erzeugt in", OUT)
