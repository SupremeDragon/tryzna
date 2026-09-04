"""Вирізає предмет, знятий на рівному тлі, у спрайт із прозорістю.

Третій спосіб вирізки в проєкті, і в кожного своя причина існувати:

| інструмент     | що знімає            | коли треба |
|----------------|----------------------|------------|
| `cut_band.py`  | нічого, ріже смугу   | шари фону з цілого кадру |
| `key_dark.py`  | світле тло           | силует темніший за тло |
| `key_flat.py`  | рівне тло будь-якого тону | предмет і темніший, І світліший за тло |

Останній випадок — це береза: стовбур білий, гілки чорні, тло сіре між ними.
Поріг за яскравістю тут безсилий, бо предмет лежить по ОБИДВА боки від тла.
Тому рахується відстань кольору до тла, а не яскравість.

    python tools/key_flat.py вхід.png game/art/plyn/tree_a.png
    python tools/key_flat.py вхід.png вихід.png --low 26 --high 62
"""
import argparse
import os
from collections import Counter

from PIL import Image, ImageChops, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def detect_background(img: Image.Image) -> tuple:
    """Найчастіший колір по краях кадру — це тло.

    Саме по краях, а не в середині: у середині стоїть предмет, і на вузькому
    силуеті на кшталт дерева найчастішим кольором цілком може виявитися він.
    """
    w, h = img.size
    edge = max(2, min(w, h) // 12)
    band = Image.new("RGB", (w, edge * 2))
    band.paste(img.crop((0, 0, w, edge)), (0, 0))
    band.paste(img.crop((0, h - edge, w, h)), (0, edge))
    small = band.resize((max(w // 6, 1), 8))
    return Counter(small.getdata()).most_common(1)[0][0]


def key_flat(
    img: Image.Image, low: int, high: int, blur: float
) -> Image.Image:
    rgb = img.convert("RGB")
    bg = detect_background(rgb)
    diff = ImageChops.difference(rgb, Image.new("RGB", rgb.size, bg)).convert("L")
    if blur > 0.0:
        diff = diff.filter(ImageFilter.GaussianBlur(blur))

    span = max(high - low, 1)
    table = [
        0 if v <= low else 255 if v >= high else int((v - low) / span * 255)
        for v in range(256)
    ]

    out = rgb.convert("RGBA")
    out.putalpha(diff.point(table))
    return out, bg


def trim(rgba: Image.Image, keep: int = 6) -> Image.Image:
    box = rgba.split()[3].point(lambda v: 255 if v > keep else 0).getbbox()
    return rgba.crop(box) if box else rgba


def main() -> None:
    ap = argparse.ArgumentParser(description="Предмет на рівному тлі в спрайт")
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--low", type=int, default=24, help="нижче — тло")
    ap.add_argument("--high", type=int, default=60, help="вище — предмет")
    ap.add_argument("--blur", type=float, default=0.5)
    ap.add_argument("--no-trim", action="store_true")
    args = ap.parse_args()

    src = args.src if os.path.isabs(args.src) else os.path.join(ROOT, args.src)
    dst = args.dst if os.path.isabs(args.dst) else os.path.join(ROOT, args.dst)

    out, bg = key_flat(Image.open(src), args.low, args.high, args.blur)
    if not args.no_trim:
        out = trim(out)

    os.makedirs(os.path.dirname(dst), exist_ok=True)
    out.save(dst)
    print("%s  %s  тло %s" % (dst, out.size, bg))


if __name__ == "__main__":
    main()
