"""Робить із клаптя картинки безшовну плитку для землі.

Земля тиляться на весь екран, тому шов на стику видно одразу, а дзеркальна
плитка дає впізнавану симетрію — око чіпляється за неї ще швидше, ніж за шов.

Тут інший спосіб: картинка змішується зі своїм дзеркальним відображенням за
лінійним градієнтом. На лівому краї лишається оригінал, на правому —
дзеркало, а дзеркало на правому краї дорівнює оригіналу на лівому. Тобто
краї сходяться самі собою, без ретуші. Те саме по вертикалі.

Ціна — легке двоїння в середині плитки. Для трави й землі це непомітно,
для цегли чи дощок було б неприйнятно.

    python tools/make_tile.py art_src/approved/plyn_ref_balka_v01.jpg \
        game/art/plyn/ground.png --box 0.22 0.80 0.62 1.00 --size 640
"""
import argparse
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def blend_axis(im: Image.Image, horizontal: bool) -> Image.Image:
    """Змішує картинку з її дзеркалом за градієнтом уздовж однієї осі."""
    w, h = im.size
    mirror = im.transpose(
        Image.FLIP_LEFT_RIGHT if horizontal else Image.FLIP_TOP_BOTTOM
    )

    n = w if horizontal else h
    ramp = Image.new("L", (n, 1) if horizontal else (1, n))
    px = ramp.load()
    for i in range(n):
        v = int(i / float(n - 1) * 255)
        if horizontal:
            px[i, 0] = v
        else:
            px[0, i] = v

    return Image.composite(mirror, im, ramp.resize((w, h)))


def main() -> None:
    ap = argparse.ArgumentParser(description="Безшовна плитка з клаптя кадру")
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument(
        "--box", nargs=4, type=float, required=True,
        metavar=("Л", "В", "П", "Н"), help="частки ширини й висоти, 0..1",
    )
    ap.add_argument("--size", type=int, default=640)
    args = ap.parse_args()

    src = args.src if os.path.isabs(args.src) else os.path.join(ROOT, args.src)
    dst = args.dst if os.path.isabs(args.dst) else os.path.join(ROOT, args.dst)

    img = Image.open(src).convert("RGB")
    w, h = img.size
    l, t, r, b = args.box
    patch = img.crop((int(w * l), int(h * t), int(w * r), int(h * b)))
    patch = patch.resize((args.size, args.size), Image.LANCZOS)

    tile = blend_axis(blend_axis(patch, True), False)

    os.makedirs(os.path.dirname(dst), exist_ok=True)
    tile.save(dst)
    print("плитка -> %s %s" % (dst, tile.size))


if __name__ == "__main__":
    main()
