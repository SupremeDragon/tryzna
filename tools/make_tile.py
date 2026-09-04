"""Робить із клаптя картинки безшовну плитку землі.

Плитка землі повторюється на весь екран, тому важать дві речі: щоб не було
шва на стику і щоб не було ВІЗЕРУНКА. Друге складніше за перше.

Перший підхід був дзеркальний: картинка змішувалася зі своїм відображенням за
градієнтом, і краї сходилися самі собою. Краї справді сходилися — але на
площі це давало виразний калейдоскоп, і око знаходило його швидше, ніж
знайшло б шов.

Тут інший спосіб, класичний. Беремо два примірники: оригінал і зсунутий на
пів-плитки по обох осях. У зсунутого шов опиняється посередині, а краї
натомість чисті. Змішуємо їх вагою «відстань до найближчого краю»: біля краю
переважає зсунутий, у центрі — оригінал. Виходить плитка без шва й БЕЗ
СИМЕТРІЇ — ціною легкого двоїння, якого на траві не видно.

    python tools/make_tile.py ДЖЕРЕЛО game/art/plyn/grass_a.png \
        --box 0.10 0.42 0.62 0.94 --size 512
"""
import argparse
import os

from PIL import Image, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _edge_weight(n: int) -> list[float]:
    """Відстань до найближчого краю, від 0 на краю до 1 посередині."""
    half = max((n - 1) / 2.0, 1.0)
    return [min(i, n - 1 - i) / half for i in range(n)]


def seamless(im: Image.Image) -> Image.Image:
    w, h = im.size
    shifted = ImageChops.offset(im, w // 2, h // 2)

    wx = _edge_weight(w)
    wy = _edge_weight(h)
    # Ваги для зсунутого — ті самі, але зміщені: там, де оригінал біля краю,
    # зсунутий у своїй серединi, і навпаки.
    sx = wx[w // 2:] + wx[: w // 2]
    sy = wy[h // 2:] + wy[: h // 2]

    mask = Image.new("L", (w, h))
    px = mask.load()
    for y in range(h):
        ay = wy[y]
        by = sy[y]
        for x in range(w):
            a = wx[x] * ay
            b = sx[x] * by
            total = a + b
            px[x, y] = 128 if total <= 0.0 else int(a / total * 255.0)

    # mask=255 -> оригінал, mask=0 -> зсунутий.
    return Image.composite(im, shifted, mask)


def main() -> None:
    ap = argparse.ArgumentParser(description="Безшовна плитка з клаптя кадру")
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument(
        "--box", nargs=4, type=float, required=True,
        metavar=("Л", "В", "П", "Н"), help="частки ширини й висоти, 0..1",
    )
    ap.add_argument("--size", type=int, default=512)
    args = ap.parse_args()

    src = args.src if os.path.isabs(args.src) else os.path.join(ROOT, args.src)
    dst = args.dst if os.path.isabs(args.dst) else os.path.join(ROOT, args.dst)

    img = Image.open(src).convert("RGB")
    w, h = img.size
    left, top, right, bottom = args.box
    patch = img.crop(
        (int(w * left), int(h * top), int(w * right), int(h * bottom))
    ).resize((args.size, args.size), Image.LANCZOS)

    tile = seamless(patch)

    os.makedirs(os.path.dirname(dst), exist_ok=True)
    tile.save(dst)
    print("плитка -> %s %s" % (dst, tile.size))


if __name__ == "__main__":
    main()
