"""Робить із темного силуету на світлому тлі шар із прозорістю.

Чим відрізняється від `cut_layers.py`: той знімає тло за РІЗНИЦЕЮ КОЛЬОРУ й
розрахований на рівний фон. Коли фон із градієнтом — а серпанок між колонами
саме такий, знизу світліший за верх, — різниця дає ореоли по краях.

Тут інакше: прозорість береться просто з ЯСКРАВОСТІ. Темне — предмет,
світле — повітря, між ними мʼякий перехід. Для силуетів це і точніше,
і чесніше: у площинному світі Ниці стовп — це і є силует.

    python tools/key_dark.py вхід.png game/art/nyts/pillars_mid.png
    python tools/key_dark.py вхід.png вихід.png --lo 70 --hi 150 --tint 0.55
"""
import argparse
import os

from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def key_dark(
    img: Image.Image, lo: int, hi: int, tint: float, blur: float
) -> Image.Image:
    """lo — темніше за це повністю непрозоре, hi — світліше повністю прозоре."""
    rgb = img.convert("RGB")
    lum = rgb.convert("L")
    if blur > 0.0:
        # Ледь розмити маску, а не картинку: прибирає рвані пікселі по краю,
        # не чіпаючи самої фактури каменю.
        lum = lum.filter(ImageFilter.GaussianBlur(blur))

    span = max(hi - lo, 1)
    table = [
        255 if v <= lo else 0 if v >= hi else int((hi - v) / span * 255)
        for v in range(256)
    ]

    out = rgb.copy()
    if tint != 1.0:
        out = out.point(lambda v: int(v * tint))
    out = out.convert("RGBA")
    out.putalpha(lum.point(table))
    return out


def feather_sides(rgba: Image.Image, px: int) -> Image.Image:
    """Розчиняє прозорість до нуля біля лівого й правого країв.

    Шари фону тиляться по горизонталі. Якщо на краю картинки лишається хоч
    якась непрозорість, на кожному стику видно рівний вертикальний шов —
    саме те, через що кадр читається як складений із плиток. Верх і низ не
    чіпаємо: колони там обрізані рамкою навмисно.
    """
    if px <= 0:
        return rgba
    # split() віддає КОПІЮ каналу, тож правити його на місці марно —
    # прозорість треба зібрати окремо й покласти назад через putalpha.
    w, h = rgba.size
    ramp = Image.new("L", (w, 1), 255)
    row = ramp.load()
    for x in range(min(px, w // 2)):
        k = int(x / float(px) * 255)
        row[x, 0] = k
        row[w - 1 - x, 0] = k

    alpha = rgba.split()[3]
    from PIL import ImageChops as _chops

    alpha = _chops.multiply(alpha, ramp.resize((w, h)))
    out = rgba.copy()
    out.putalpha(alpha)
    return out


def trim(rgba: Image.Image, keep: int = 2) -> Image.Image:
    """Зрізає повністю порожні краї, щоб шар не тягав за собою пусте поле."""
    box = rgba.split()[3].point(lambda v: 255 if v > keep else 0).getbbox()
    return rgba.crop(box) if box else rgba


def main() -> None:
    ap = argparse.ArgumentParser(description="Силует у прозорість за яскравістю")
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--lo", type=int, default=70, help="повна непрозорість")
    ap.add_argument("--hi", type=int, default=150, help="повна прозорість")
    ap.add_argument("--tint", type=float, default=1.0, help="притемнити колір")
    ap.add_argument("--blur", type=float, default=0.6)
    ap.add_argument("--feather", type=int, default=0, help="розчинити бічні краї")
    ap.add_argument("--no-trim", action="store_true")
    args = ap.parse_args()

    img = Image.open(args.src)
    out = key_dark(img, args.lo, args.hi, args.tint, args.blur)
    if not args.no_trim:
        out = trim(out)
    out = feather_sides(out, args.feather)

    dst = args.dst if os.path.isabs(args.dst) else os.path.join(ROOT, args.dst)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    out.save(dst)

    alpha = out.split()[3]
    covered = sum(1 for v in alpha.getdata() if v > 8) / float(out.width * out.height)
    print("%s -> %s  %s  непрозоро %.0f%%" % (args.src, dst, out.size, covered * 100))


if __name__ == "__main__":
    main()
