"""Малює плитки землі кодом, а не нейромережею.

Чому не Forge. DreamShaper — модель ІЛЮСТРАЦІЙ. Дев'ять спроб поспіль на різних
промптах вона малювала краєвид із небом і обрієм замість рівної поверхні:
у неї немає поняття «текстура», у неї є поняття «картина». Для предметів це
перевага, для плитки — глухий кут.

А в тому стилі, який обрав Міша, земля пласка й проста: базовий колір, кілька
плям, дрібні штрихи. Це дешевше й надійніше намалювати руками — і плитка тоді
безшовна ЗА ПОБУДОВОЮ, бо кожен штрих, що виліз за край, домальовується
з протилежного боку.

    python tools/make_ground.py --out game/art/plyn --size 256
"""
import argparse
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def wrapped(draw_one, n: int) -> None:
    """Малює те саме дев'ять разів зі зсувами — тоді край переходить сам.

    Найпростіший спосіб зробити безшовність без жодного змішування: те, що
    вилізло за правий край, з'являється зліва, бо його там і намалювали.
    """
    for dy in (-n, 0, n):
        for dx in (-n, 0, n):
            draw_one(dx, dy)


def blob(d: ImageDraw.ImageDraw, x, y, r, colour, n) -> None:
    wrapped(lambda dx, dy: d.ellipse(
        [x + dx - r, y + dy - r, x + dx + r, y + dy + r], fill=colour), n)


def stroke(d: ImageDraw.ImageDraw, x, y, dx2, dy2, w, colour, n) -> None:
    wrapped(lambda dx, dy: d.line(
        [x + dx, y + dy, x + dx + dx2, y + dy + dy2], fill=colour, width=w), n)


def grass(n: int, rng: random.Random, base, dark, light, flower) -> Image.Image:
    img = Image.new("RGB", (n, n), base)
    d = ImageDraw.Draw(img)

    # Плями тону. Саме вони не дають траві читатися однією заливкою.
    for _ in range(26):
        blob(d, rng.uniform(0, n), rng.uniform(0, n), rng.uniform(n * 0.06, n * 0.16),
             dark if rng.random() < 0.5 else light, n)
    img = img.filter(ImageFilter.GaussianBlur(n * 0.02))

    d = ImageDraw.Draw(img)
    # Травинки. Короткі, майже вертикальні, двох тонів.
    for _ in range(int(n * 3.2)):
        x, y = rng.uniform(0, n), rng.uniform(0, n)
        h = rng.uniform(n * 0.012, n * 0.032)
        lean = rng.uniform(-0.35, 0.35) * h
        stroke(d, x, y, lean, -h, 1, light if rng.random() < 0.6 else dark, n)

    # Кілька ромашок — у референсі вони є, і саме вони роблять газон живим.
    for _ in range(max(int(n * 0.03), 2)):
        x, y = rng.uniform(0, n), rng.uniform(0, n)
        blob(d, x, y, n * 0.011, flower, n)
        blob(d, x, y, n * 0.004, (250, 214, 90), n)
    return img


def sand(n: int, rng: random.Random, base, dark, light, pebble) -> Image.Image:
    img = Image.new("RGB", (n, n), base)
    d = ImageDraw.Draw(img)
    for _ in range(20):
        blob(d, rng.uniform(0, n), rng.uniform(0, n), rng.uniform(n * 0.08, n * 0.2),
             dark if rng.random() < 0.5 else light, n)
    img = img.filter(ImageFilter.GaussianBlur(n * 0.03))

    d = ImageDraw.Draw(img)
    for _ in range(int(n * 0.22)):
        x, y = rng.uniform(0, n), rng.uniform(0, n)
        r = rng.uniform(n * 0.005, n * 0.014)
        blob(d, x, y, r, pebble, n)
    return img


def soil(n: int, rng: random.Random, base, dark, sprout) -> Image.Image:
    img = Image.new("RGB", (n, n), base)
    d = ImageDraw.Draw(img)
    rows = 5
    step = n / float(rows)
    for i in range(rows):
        y = (i + 0.5) * step
        wrapped(lambda dx, dy, y=y: d.rectangle(
            [dx, y + dy - step * 0.16, n + dx, y + dy + step * 0.16], fill=dark), n)
    img = img.filter(ImageFilter.GaussianBlur(n * 0.012))

    d = ImageDraw.Draw(img)
    for i in range(rows):
        y = (i + 0.5) * step
        for k in range(6):
            x = (k + 0.5) * n / 6.0 + rng.uniform(-n * 0.02, n * 0.02)
            blob(d, x, y, n * 0.022, sprout, n)
    return img


def water(n: int, rng: random.Random, base, dark, light) -> Image.Image:
    img = Image.new("RGB", (n, n), base)
    d = ImageDraw.Draw(img)
    for _ in range(14):
        blob(d, rng.uniform(0, n), rng.uniform(0, n), rng.uniform(n * 0.1, n * 0.22),
             dark, n)
    img = img.filter(ImageFilter.GaussianBlur(n * 0.05))

    d = ImageDraw.Draw(img)
    for _ in range(int(n * 0.16)):
        x, y = rng.uniform(0, n), rng.uniform(0, n)
        w = rng.uniform(n * 0.05, n * 0.14)
        stroke(d, x, y, w, math.sin(x) * n * 0.01, max(int(n * 0.008), 1), light, n)
    return img


def main() -> None:
    ap = argparse.ArgumentParser(description="Плитки землі, намальовані кодом")
    ap.add_argument("--out", default="game/art/plyn")
    ap.add_argument("--size", type=int, default=256)
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()

    out = args.out if os.path.isabs(args.out) else os.path.join(ROOT, args.out)
    os.makedirs(out, exist_ok=True)
    n = args.size

    # Палітра знята з референсу, який дав Міша.
    made = {
        "grass_a": grass(n, random.Random(args.seed),
                         (108, 176, 56), (78, 140, 40), (148, 202, 78), (240, 240, 226)),
        # ТОЙ САМИЙ базовий тон, що й у grass_a, і відрізняється лише випадок.
        # Різні базові кольори на крупній сітці читаються квадратами: карта
        # вкривається світлими й темними латками завбільшки з плитку.
        "grass_b": grass(n, random.Random(args.seed + 1),
                         (108, 176, 56), (78, 140, 40), (148, 202, 78), (240, 240, 226)),
        "dirt_a": sand(n, random.Random(args.seed + 2),
                       (222, 194, 140), (198, 168, 116), (238, 214, 168), (176, 154, 118)),
        "dirt_b": sand(n, random.Random(args.seed + 3),
                       (222, 194, 140), (198, 168, 116), (238, 214, 168), (176, 154, 118)),
        "soil_a": soil(n, random.Random(args.seed + 4),
                       (108, 74, 48), (82, 54, 34), (146, 60, 46)),
        "water_a": water(n, random.Random(args.seed + 5),
                         (62, 142, 196), (44, 116, 172), (132, 200, 236)),
    }

    for name, img in made.items():
        path = os.path.join(out, name + ".png")
        img.save(path)
        print("%-9s -> %s" % (name, path))


if __name__ == "__main__":
    main()
