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


def fill_holes(rgba: Image.Image, edge: int = 40) -> Image.Image:
    """Робить непрозорим усе, що ВСЕРЕДИНІ контуру предмета.

    Головне виправлення для будівель. Вирізка за різницею кольору знімає все,
    що схоже на тло, — а стіна зрубу сірувато-бура, і тло генерації теж сіре.
    Через це середина стіни ставала напівпрозорою разом із тлом, і крізь хату
    було видно паркан. Поріг тут не рятує: підняти означає з'їсти край,
    опустити — лишити тло.

    Тому тло визначається не кольором, а ЗВ'ЯЗНІСТЮ: справжнє тло дотикається
    краю кадру, а дірка в стіні — ні. Заливаємо ззовні й лишаємо непрозорим
    усе, куди залив не дістався.

    УВАГА: для дерева це неприпустимо. Просвіти між гілками — теж «дірки», і
    після заливки береза стає суцільною плямою. Тому окремий прапорець, а не
    типова поведінка.
    """
    from PIL import ImageDraw

    alpha = rgba.split()[3]
    w, h = alpha.size

    # Рамка в один піксель, щоб заливу було звідки початися навіть тоді,
    # коли предмет торкається краю кадру.
    outside = Image.new("L", (w + 2, h + 2), 0)
    outside.paste(alpha.point(lambda v: 255 if v > edge else 0), (1, 1))
    ImageDraw.floodfill(outside, (0, 0), 128)

    inner = outside.crop((1, 1, w + 1, h + 1)).point(
        lambda v: 0 if v == 128 else 255
    )

    # Дві дії, і обидві потрібні.
    #
    # 1. Все, що ВСЕРЕДИНІ контуру, стає непрозорим — це лікує прозорі стіни.
    # 2. Все, що ЗЗОВНІ, множиться на нуль — це лікує «квадратики». Поріг
    #    лишає навколо предмета ледь помітну рамку майже-тла, і в грі вона
    #    читається як прямокутник довкола кожної хати. Порогом її не прибрати:
    #    вона й є те, що поріг не добрав.
    #
    # Край згладжуємо розмиттям МАСКИ, а не альфи: так силует лишається
    # чистим, але не рветься пилкою.
    soft = inner.filter(ImageFilter.GaussianBlur(1.1))
    out = rgba.copy()
    out.putalpha(ImageChops.multiply(ImageChops.lighter(alpha, inner), soft))
    return out


def oval_cut(rgba: Image.Image, power: float = 3.2, fade: float = 0.16):
    """Гасить прозорість до нуля в кутах кадру.

    Найчастіша й найгірша вада згенерованого пропса: модель домальовує під
    предметом клапоть землі, і той клапоть доходить до краю кадру. Вирізка за
    кольором лишає його як частину предмета — і в грі кожна хата стоїть у
    видимому прямокутнику, а напівпрозорі краї того прямокутника читаються як
    прозора стіна. Саме про це Міша сказав двічі.

    Порогом не лікується: клапоть справді не тло, він намальований. Лікується
    формою — предмет вписується в округлий прямокутник, а кути кадру
    вирізаються. Показник степеня 3.2 дає не еліпс, а саме округлений
    прямокутник: еліпс зрізав би кути даху.
    """
    w, h = rgba.size
    mask = Image.new("L", (w, h))
    px = mask.load()
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    inner = 1.0 - fade
    for y in range(h):
        ny = abs(y - cy) / cy if cy > 0 else 0.0
        for x in range(w):
            nx = abs(x - cx) / cx if cx > 0 else 0.0
            r = (nx ** power + ny ** power) ** (1.0 / power)
            if r <= inner:
                px[x, y] = 255
            elif r >= 1.0:
                px[x, y] = 0
            else:
                px[x, y] = int((1.0 - (r - inner) / fade) * 255)

    out = rgba.copy()
    out.putalpha(ImageChops.multiply(rgba.split()[3], mask))
    return out


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
    ap.add_argument(
        "--no-oval", action="store_true",
        help="не зрізати кути кадру (тільки для того, що справді прямокутне)",
    )
    ap.add_argument(
        "--fill-holes", action="store_true",
        help="залити напівпрозорі дірки всередині контуру (будівлі, НЕ дерева)",
    )
    args = ap.parse_args()

    src = args.src if os.path.isabs(args.src) else os.path.join(ROOT, args.src)
    dst = args.dst if os.path.isabs(args.dst) else os.path.join(ROOT, args.dst)

    out, bg = key_flat(Image.open(src), args.low, args.high, args.blur)
    if args.fill_holes:
        out = fill_holes(out)
    if not args.no_oval:
        out = oval_cut(out)
    if not args.no_trim:
        out = trim(out)

    os.makedirs(os.path.dirname(dst), exist_ok=True)
    out.save(dst)
    print("%s  %s  тло %s" % (dst, out.size, bg))


if __name__ == "__main__":
    main()
