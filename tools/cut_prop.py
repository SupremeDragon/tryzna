"""Вирізає окремий предмет із цілого кадру в спрайт із мʼякими краями.

Від `cut_band.py` відрізняється тим, що там смуга на всю ширину, а тут —
прямокутник довкола однієї речі: хати, криниці, паркана.

Тло під предметом не вибивається порогом навмисно. Хата стоїть на траві, і
трава під нею — та сама, що тепер лежить у грі землею. Тому дешевше й чесніше
лишити клапоть трави й розчинити краї: у грі він ляже на таку саму траву й
шва не буде. Вибивати силует по контуру доведеться тільки тоді, коли предмет
стоятиме на чомусь іншому.

    python tools/cut_prop.py КАДР game/art/plyn/hata_a.png --box 0.20 0.53 0.41 0.76
"""
import argparse
import os

from PIL import Image, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def ramp(n: int, head: int, tail: int) -> list[int]:
    """Градієнт 0→255→0 із заданими довжинами підйому й спаду."""
    out = [255] * n
    for i in range(min(head, n)):
        out[i] = int(i / float(head) * 255)
    for i in range(min(tail, n)):
        out[n - 1 - i] = min(out[n - 1 - i], int(i / float(tail) * 255))
    return out


def cut(
    img: Image.Image, box: tuple, fade: tuple
) -> Image.Image:
    w, h = img.size
    l, t, r, b = box
    piece = img.convert("RGBA").crop((int(w * l), int(h * t), int(w * r), int(h * b)))
    pw, ph = piece.size

    fl, ft, fr, fb = fade
    cols = ramp(pw, int(pw * fl), int(pw * fr))
    rows = ramp(ph, int(ph * ft), int(ph * fb))

    mx = Image.new("L", (pw, 1))
    mx.putdata(cols)
    my = Image.new("L", (1, ph))
    my.putdata(rows)

    mask = ImageChops.multiply(mx.resize((pw, ph)), my.resize((pw, ph)))
    piece.putalpha(ImageChops.multiply(piece.split()[3], mask))
    return piece


def main() -> None:
    ap = argparse.ArgumentParser(description="Предмет із цілого кадру в спрайт")
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--box", nargs=4, type=float, required=True,
                    metavar=("Л", "В", "П", "Н"))
    ap.add_argument("--fade", nargs=4, type=float,
                    default=[0.10, 0.10, 0.10, 0.16],
                    metavar=("Л", "В", "П", "Н"),
                    help="частка сторони, що розчиняється")
    args = ap.parse_args()

    src = args.src if os.path.isabs(args.src) else os.path.join(ROOT, args.src)
    dst = args.dst if os.path.isabs(args.dst) else os.path.join(ROOT, args.dst)

    out = cut(Image.open(src), tuple(args.box), tuple(args.fade))
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    out.save(dst)
    print("%s  %s" % (dst, out.size))


if __name__ == "__main__":
    main()
