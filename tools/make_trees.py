"""Малює дерева, кущі й пеньки кодом.

Та сама причина, що й у make_ground.py, тільки гостріша. Дерева з генерації
виходили або з темним німбом, або на декоративному постаменті, або наполовину
з'їденими вирізкою: дерево ЗЕЛЕНЕ, тло теж зелене, і різати їх одне від одного
доводиться на око.

А в обраному стилі крона — це просто купка кругів двох відтінків на короткому
стовбурі. Такого коду тридцять рядків, і він дає чисту прозорість, однаковий
силует і будь-яку кількість варіантів без жодної генерації.

    python tools/make_trees.py --out game/art/plyn --size 256
"""
import argparse
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _shadowed(img: Image.Image, alpha: float = 0.22) -> Image.Image:
    """Мʼяка тінь під кроною — те, що садовить дерево на землю."""
    w, h = img.size
    shade = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(shade)
    d.ellipse(
        [w * 0.22, h * 0.80, w * 0.78, h * 0.98],
        fill=(20, 40, 16, int(alpha * 255)),
    )
    shade = shade.filter(ImageFilter.GaussianBlur(w * 0.02))
    shade.alpha_composite(img)
    return shade


def leafy(n: int, rng: random.Random, dark, mid, light, bark, bark_dark):
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Стовбур. Трохи розширений донизу — так він читається як дерево, а не
    # як паличка, навіть коли крона його майже накриває.
    tw = n * 0.055
    d.polygon(
        [
            (n * 0.5 - tw * 0.7, n * 0.55),
            (n * 0.5 + tw * 0.7, n * 0.55),
            (n * 0.5 + tw * 1.5, n * 0.88),
            (n * 0.5 - tw * 1.5, n * 0.88),
        ],
        fill=bark,
    )
    d.polygon(
        [
            (n * 0.5 - tw * 0.7, n * 0.55),
            (n * 0.5 - tw * 0.1, n * 0.55),
            (n * 0.5 + tw * 0.3, n * 0.88),
            (n * 0.5 - tw * 1.5, n * 0.88),
        ],
        fill=bark_dark,
    )

    # Крона: спершу темна основа, потім середній тон, потім світлі маківки.
    # Три шари й дають той обʼєм, за який цей стиль і люблять.
    def puffs(colour, count, cx, cy, spread, rmin, rmax):
        for _ in range(count):
            ang = rng.uniform(0.0, math.tau)
            dist = rng.uniform(0.0, spread)
            x = cx + math.cos(ang) * dist
            y = cy + math.sin(ang) * dist * 0.72
            r = rng.uniform(rmin, rmax)
            d.ellipse([x - r, y - r, x + r, y + r], fill=colour)

    cx, cy = n * 0.5, n * 0.38
    puffs(dark, 9, cx, cy + n * 0.02, n * 0.16, n * 0.13, n * 0.19)
    puffs(mid, 8, cx, cy - n * 0.01, n * 0.15, n * 0.11, n * 0.16)
    puffs(light, 6, cx, cy - n * 0.06, n * 0.13, n * 0.07, n * 0.11)
    return _shadowed(img)


def conifer(n: int, rng: random.Random, dark, mid, light, bark):
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    d.rectangle([n * 0.46, n * 0.74, n * 0.54, n * 0.90], fill=bark)

    tiers = 4
    for i in range(tiers):
        k = i / float(tiers - 1)
        top = n * (0.08 + k * 0.42)
        bottom = top + n * 0.26
        half = n * (0.12 + k * 0.16)
        colour = [dark, mid, mid, light][i % 3] if i else light
        d.polygon(
            [(n * 0.5, top), (n * 0.5 + half, bottom), (n * 0.5 - half, bottom)],
            fill=colour,
        )
        # Ліва половина трохи темніша — дешеве, але переконливе світло збоку.
        d.polygon(
            [(n * 0.5, top), (n * 0.5, bottom), (n * 0.5 - half, bottom)],
            fill=dark,
        )
    return _shadowed(img, 0.18)


def shrub(n: int, rng: random.Random, dark, mid, light):
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for colour, count, dy, rmin, rmax in (
        (dark, 5, 0.60, 0.13, 0.18),
        (mid, 4, 0.56, 0.10, 0.15),
        (light, 3, 0.50, 0.06, 0.10),
    ):
        for _ in range(count):
            x = n * 0.5 + rng.uniform(-n * 0.18, n * 0.18)
            y = n * dy + rng.uniform(-n * 0.04, n * 0.04)
            r = rng.uniform(n * rmin, n * rmax)
            d.ellipse([x - r, y - r, x + r, y + r], fill=colour)
    return _shadowed(img, 0.16)


def stump(n: int, rng: random.Random, bark, bark_dark, rings):
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([n * 0.30, n * 0.52, n * 0.70, n * 0.80], fill=bark_dark)
    d.rectangle([n * 0.30, n * 0.58, n * 0.70, n * 0.72], fill=bark_dark)
    d.ellipse([n * 0.30, n * 0.46, n * 0.70, n * 0.66], fill=bark)
    d.ellipse([n * 0.38, n * 0.51, n * 0.62, n * 0.61], fill=rings)
    return _shadowed(img, 0.14)


def main() -> None:
    ap = argparse.ArgumentParser(description="Дерева й кущі, намальовані кодом")
    ap.add_argument("--out", default="game/art/plyn")
    ap.add_argument("--size", type=int, default=256)
    ap.add_argument("--seed", type=int, default=11)
    args = ap.parse_args()

    out = args.out if os.path.isabs(args.out) else os.path.join(ROOT, args.out)
    os.makedirs(out, exist_ok=True)
    n = args.size

    # Палітра знята з референсу Міші.
    dark = (46, 110, 40)
    mid = (74, 150, 48)
    light = (128, 196, 66)
    bark = (122, 82, 48)
    bark_dark = (92, 60, 34)

    made = {}
    for i in range(3):
        made["tree_%s" % "abc"[i]] = leafy(
            n, random.Random(args.seed + i), dark, mid, light, bark, bark_dark
        )
    for i in range(2):
        made["pine_%s" % "ab"[i]] = conifer(
            n, random.Random(args.seed + 10 + i), (30, 78, 44), (44, 104, 54),
            (66, 134, 62), bark_dark
        )
    for i in range(2):
        made["bush_%s" % "ab"[i]] = shrub(
            n, random.Random(args.seed + 20 + i), dark, mid, light
        )
    made["stump_a"] = stump(n, random.Random(args.seed + 30),
                            (156, 112, 66), bark_dark, (188, 148, 96))

    for name, img in made.items():
        path = os.path.join(out, name + ".png")
        img.save(path)
        print("%-8s -> %s" % (name, path))


if __name__ == "__main__":
    main()
