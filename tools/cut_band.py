"""Ріже горизонтальну смугу з цілого кадру й робить із неї шар паралаксу.

Метод Міші, і він правильніший за генерацію шарів окремо: на затвердженому
кадрі вже є і композиція, і палітра, і повітряна перспектива. Розібрати
готове — надійніше, ніж шість разів просити нейромережу вгадати те саме.

Смуга непрозора знизу й розчиняється вгорі. Це важливо: у паралаксі дальній
шар перекривається ближчим, тож різати силует по контуру не потрібно — треба
лише, щоб верхній край не був різаною лінією.

    python tools/cut_band.py art_src/approved/plyn_ref_balka_v01.jpg \
        game/art/plyn/hills_far.png --top 0.16 --bottom 0.28
"""
import argparse
import os

from PIL import Image, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def cut(
    img: Image.Image,
    top: float,
    bottom: float,
    fade_top: float,
    fade_bottom: float,
    feather_x: int,
) -> Image.Image:
    w, h = img.size
    band = img.convert("RGBA").crop((0, int(h * top), w, int(h * bottom)))
    bw, bh = band.size

    # Вертикальний градієнт прозорості: скільки зверху й знизу розчинити.
    ramp = Image.new("L", (1, bh), 255)
    col = ramp.load()
    n_top = max(int(bh * fade_top), 0)
    n_bot = max(int(bh * fade_bottom), 0)
    for y in range(n_top):
        col[0, y] = int(y / float(n_top) * 255)
    for y in range(n_bot):
        col[0, bh - 1 - y] = min(col[0, bh - 1 - y], int(y / float(n_bot) * 255))

    mask = ramp.resize((bw, bh))

    if feather_x > 0:
        # Шар тиляться по горизонталі — краї мусять зійти в нуль,
        # інакше на кожному стику стоїть рівний вертикальний шов.
        side = Image.new("L", (bw, 1), 255)
        row = side.load()
        for x in range(min(feather_x, bw // 2)):
            k = int(x / float(feather_x) * 255)
            row[x, 0] = k
            row[bw - 1 - x, 0] = k
        mask = ImageChops.multiply(mask, side.resize((bw, bh)))

    band.putalpha(ImageChops.multiply(band.split()[3], mask))
    return band


def main() -> None:
    ap = argparse.ArgumentParser(description="Смуга з цілого кадру в шар паралаксу")
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--top", type=float, required=True, help="частка висоти, 0..1")
    ap.add_argument("--bottom", type=float, required=True)
    ap.add_argument("--fade-top", type=float, default=0.30)
    ap.add_argument("--fade-bottom", type=float, default=0.10)
    ap.add_argument("--feather", type=int, default=120)
    args = ap.parse_args()

    src = args.src if os.path.isabs(args.src) else os.path.join(ROOT, args.src)
    dst = args.dst if os.path.isabs(args.dst) else os.path.join(ROOT, args.dst)

    out = cut(
        Image.open(src),
        args.top,
        args.bottom,
        args.fade_top,
        args.fade_bottom,
        args.feather,
    )
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    out.save(dst)
    print("%s -> %s  %s" % (os.path.basename(src), dst, out.size))


if __name__ == "__main__":
    main()
