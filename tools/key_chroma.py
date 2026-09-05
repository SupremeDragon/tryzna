"""Знімає тло за КОЛЬОРОМ родини — зелень і небо.

Четвертий різак у проєкті, і в нього теж своя причина.

`key_flat` знімає те, що близьке до одного кольору тла. Це працює, поки тло
рівне. Але згенеровані хати стоять на цілому краєвиді: газон, кущі, небо,
пагорби. Одного кольору тла там немає, і поріг доводиться ставити або надто
низько (лишається півкартини), або надто високо — і тоді разом із тлом гинуть
частини самого предмета. Саме так у першої хати лишився самий дах.

Тут інакше: знімається не «схоже на зразок», а ЦІЛА РОДИНА КОЛЬОРІВ. У
череп'яної хати немає ні зеленого, ні блакитного — отже все зелене й блакитне
в кадрі є тлом, хоч би якого воно було відтінку.

Для дерева цей різак НЕПРИДАТНИЙ: дерево саме зелене. Там працює `key_flat`.

    python tools/key_chroma.py вхід.png вихід.png --green --blue
"""
import argparse
import os

from PIL import Image, ImageChops, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

try:  # той самий залив дірок і те саме зрізання кутів, що й у key_flat
    from key_flat import fill_holes, oval_cut, trim
except ImportError:  # запуск не з теки tools
    import sys

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from key_flat import fill_holes, oval_cut, trim


def chroma_mask(
    img: Image.Image, green: bool, blue: bool, strength: float
) -> Image.Image:
    """Прозорість: 0 там, де колір належить знятій родині."""
    r, g, b = img.convert("RGB").split()
    keep = Image.new("L", img.size, 255)

    if green:
        # Зелене — це там, де зеленого помітно більше і за червоне, і за синє.
        over_r = ImageChops.subtract(g, r, scale=1.0, offset=0)
        over_b = ImageChops.subtract(g, b, scale=1.0, offset=0)
        greenness = ImageChops.darker(over_r, over_b)
        keep = ImageChops.darker(keep, greenness.point(
            lambda v: 0 if v > strength else 255))

    if blue:
        over_r2 = ImageChops.subtract(b, r, scale=1.0, offset=0)
        over_g2 = ImageChops.subtract(b, g, scale=1.0, offset=0)
        blueness = ImageChops.darker(over_r2, over_g2)
        keep = ImageChops.darker(keep, blueness.point(
            lambda v: 0 if v > strength else 255))

    # Розмиваємо МАСКУ, щоб край не рвався пилкою.
    return keep.filter(ImageFilter.GaussianBlur(1.0))


def main() -> None:
    ap = argparse.ArgumentParser(description="Зняти тло за родиною кольорів")
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--green", action="store_true", help="зняти зелень")
    ap.add_argument("--blue", action="store_true", help="зняти небо й воду")
    ap.add_argument("--strength", type=int, default=14,
                    help="менше — знімає агресивніше")
    ap.add_argument("--no-fill", action="store_true")
    ap.add_argument("--no-oval", action="store_true")
    args = ap.parse_args()

    src = args.src if os.path.isabs(args.src) else os.path.join(ROOT, args.src)
    dst = args.dst if os.path.isabs(args.dst) else os.path.join(ROOT, args.dst)

    img = Image.open(src).convert("RGBA")
    img.putalpha(chroma_mask(img, args.green, args.blue, args.strength))

    if not args.no_fill:
        # Вікна, двері й тіні всередині будівлі теж бувають синюваті — залив
        # повертає їх, бо вони не дотикаються краю кадру.
        img = fill_holes(img)
    if not args.no_oval:
        img = oval_cut(img)
    img = trim(img)

    os.makedirs(os.path.dirname(dst), exist_ok=True)
    img.save(dst)

    data = list(img.split()[3].get_flattened_data())
    solid = sum(1 for v in data if v >= 225) / float(len(data)) * 100.0
    print("%s  %s  суцільно %.0f%%" % (dst, img.size, solid))


if __name__ == "__main__":
    main()
