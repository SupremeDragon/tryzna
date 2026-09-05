"""Зливає кілька аркушів тайлсету в один, лишаючи кожну плитку по разу.

Аркушів десять, і вони здебільшого повторюють одне одного: та сама трава, та
сама вода, ті самі стіни. Працювати з десятьма аркушами означає щоразу
згадувати, у якому з них потрібна плитка. Один аркуш без дублікатів — це і
менше файлів, і більше різноманіття на очах одразу.

Як визначається дублікат: клітинка зменшується до 24x24 і порівнюється з уже
взятими за сумою квадратів різниць. Поріг свідомо не нульовий — аркуші
згенеровані, і та сама трава на двох із них відрізняється на кілька тонів,
хоча для гри це одна й та сама плитка.

Порожні клітинки (саме тло аркуша) викидаються окремо: їх у кожному аркуші
десятки, і вони тільки роздували б результат.

    python tools/merge_tilesets.py --out art_src/approved/tileset_master.png
"""
import argparse
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Аркуш, крок x, крок y, початок x, початок y, стовпців, рядків, перший рядок.
# Числа знайдено tools/grid_probe.py й уточнено refine_grid().
#
# Сюди входять ЛИШЕ справжні сітки плиток. Два аркуші з десяти виявилися
# ВІТРИНАМИ: на них зібрані сцени — снігове плато, замерзле озеро, крижані
# зали. Сітки в них немає, і нарізка давала уламки скель замість плиток.
# Вони лишаються в art_src/tilesets/ як довідка й джерело для окремих речей.
#
# Аркуші персонажів теж не тут: у них цінний ПОРЯДОК кадрів, бо це анімація,
# і дедуплікація його б перемішала.
SHEETS = [
    ("RPG_2.5D_tile_set_2K_202609051118.jpeg", 191.85, 188.50, 62, 30, 14, 7, 0),
    ("RPG_2.5D_tile_set_2K_202609051120.jpeg", 191.65, 189.50, 1, 23, 14, 7, 0),
    ("RPG_2.5D_tile_set_2K_202609051121.jpeg", 191.95, 189.00, 60, 29, 14, 7, 0),
    ("RPG_2.5D_tile_set_2K_202609051125.jpeg", 190.95, 194.00, 5, 193, 14, 6, 0),
    ("RPG_2.5D_tile_set_2K_202609051126.jpeg", 190.95, 188.45, 5, 30, 14, 7, 0),
    ("RPG_2.5D_tile_set_2K_202609051131.jpeg", 192.00, 188.50, 60, 30, 14, 7, 0),
    ("о.jpeg", 191.85, 189.30, 3, 24, 14, 7, 0),
]

CELL = 192          # розмір клітинки у зведеному аркуші
HASH = 24           # до якого розміру стискаємо для порівняння
SAME = 5.0          # середня різниця на канал, нижче якої це та сама плитка
EMPTY_SPREAD = 9.0  # розкид кольору, нижче якого клітинка — саме тло


def refine_grid(a: np.ndarray, bg: float, sx, sy, ox, oy, cols, rows):
    """Підганяє сітку по КРАЯХ клітинок.

    Груба оцінка (grid_probe) знаходить крок приблизно, і на чотирнадцятому
    стовпці помилка в піввідсотка перетворюється на десять пікселів — плитки
    починають різатися навпіл. Тут та сама ідея, але міра інша: правильна
    сітка та, у якої в рамці навколо кожної клітинки найбільше ТЛА. Плитка
    лежить усередині клітинки й до країв не дістає.
    """
    height, width = a.shape[:2]
    flat = a.sum(axis=2)
    is_bg = np.abs(flat - bg) < 30

    def score(sx2, sy2, ox2, oy2) -> float:
        total = 0.0
        seen = 0
        for row in range(rows):
            for col in range(cols):
                x0 = int(round(ox2 + col * sx2))
                y0 = int(round(oy2 + row * sy2))
                x1 = int(round(ox2 + (col + 1) * sx2))
                y1 = int(round(oy2 + (row + 1) * sy2))
                if x0 < 0 or y0 < 0 or x1 >= width or y1 >= height:
                    continue
                ring = np.concatenate([
                    is_bg[y0:y0 + 3, x0:x1].reshape(-1),
                    is_bg[y1 - 3:y1, x0:x1].reshape(-1),
                    is_bg[y0:y1, x0:x0 + 3].reshape(-1),
                    is_bg[y0:y1, x1 - 3:x1].reshape(-1),
                ])
                if ring.size:
                    total += float(ring.mean())
                    seen += 1
        return total / max(seen, 1)

    best = (score(sx, sy, ox, oy), sx, sy, ox, oy)
    for dsx in (-0.6, -0.3, -0.15, 0.0, 0.15, 0.3, 0.6):
        for dsy in (-0.6, -0.3, -0.15, 0.0, 0.15, 0.3, 0.6):
            for dox in range(-8, 9, 2):
                for doy in range(-8, 9, 2):
                    cand = (sx + dsx, sy + dsy, ox + dox, oy + doy)
                    s = score(*cand)
                    if s > best[0]:
                        best = (s, ) + cand
    return best


def looks_like_title(cell: Image.Image) -> bool:
    """Смуга з назвою аркуша — це білий текст на рівному тлі.

    Такі клітинки лізли в зведений аркуш десятками: у кожного аркуша вгорі
    підпис, і він ріжеться на шматки нарівні з плитками.
    """
    a = np.asarray(cell, dtype=np.float32)
    white = float(((a > 232).all(axis=2)).mean())
    return white > 0.06


def cell_image(img: Image.Image, sx, sy, ox, oy, col, row) -> Image.Image:
    x0 = int(round(ox + col * sx))
    y0 = int(round(oy + row * sy))
    box = (x0 + 2, y0 + 2, int(round(x0 + sx)) - 2, int(round(y0 + sy)) - 2)
    return img.crop(box).resize((CELL, CELL), Image.LANCZOS)


def signature(cell: Image.Image) -> np.ndarray:
    return np.asarray(
        cell.resize((HASH, HASH), Image.LANCZOS), dtype=np.float32
    ).reshape(-1)


def main() -> None:
    ap = argparse.ArgumentParser(description="Злити аркуші в один без дублікатів")
    ap.add_argument("--src", default="art_src/tilesets")
    ap.add_argument("--out", default="art_src/approved/tileset_master.png")
    ap.add_argument("--cols", type=int, default=14)
    ap.add_argument("--same", type=float, default=SAME)
    args = ap.parse_args()

    src_dir = os.path.join(ROOT, args.src)
    kept: list[Image.Image] = []
    signatures: list[np.ndarray] = []
    origins: list[str] = []
    stats = {"усього": 0, "порожніх": 0, "написів": 0, "дублікатів": 0}

    for name, sx, sy, ox, oy, cols, rows, first in SHEETS:
        path = os.path.join(src_dir, name)
        if not os.path.exists(path):
            print("немає:", name)
            continue
        img = Image.open(path).convert("RGB")
        a = np.asarray(img).astype(np.float32)
        bg = float(np.median(a.sum(axis=2)))
        fit = refine_grid(a, bg, sx, sy, ox, oy, cols, rows)
        sx, sy, ox, oy = fit[1], fit[2], fit[3], fit[4]
        taken = 0
        for row in range(first, rows):
            for col in range(cols):
                cell = cell_image(img, sx, sy, ox, oy, col, row)
                stats["усього"] += 1

                c = np.asarray(cell, dtype=np.float32)
                if float(c.reshape(-1, 3).std(axis=0).mean()) < EMPTY_SPREAD:
                    stats["порожніх"] += 1
                    continue
                if looks_like_title(cell):
                    stats["написів"] += 1
                    continue

                sig = signature(cell)
                dup = False
                for other in signatures:
                    if float(np.abs(sig - other).mean()) < args.same:
                        dup = True
                        break
                if dup:
                    stats["дублікатів"] += 1
                    continue

                kept.append(cell)
                signatures.append(sig)
                origins.append("%s %d-%d" % (name, row, col))
                taken += 1
        print("%-50s узято %d" % (name[:48], taken))

    if not kept:
        raise SystemExit("нічого не взято")

    cols = args.cols
    rows = (len(kept) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * CELL, rows * CELL), (62, 72, 96))
    for i, cell in enumerate(kept):
        sheet.paste(cell, ((i % cols) * CELL, (i // cols) * CELL))

    out = args.out if os.path.isabs(args.out) else os.path.join(ROOT, args.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)

    index = os.path.splitext(out)[0] + "-джерела.txt"
    with open(index, "w", encoding="utf-8") as fh:
        fh.write("Звідки взято кожну клітинку зведеного аркуша.\n")
        fh.write("Рядок-стовпець у зведеному -> аркуш і місце в ньому.\n\n")
        for i, origin in enumerate(origins):
            fh.write("%02d-%02d  %s\n" % (i // cols, i % cols, origin))

    print()
    print("клітинок оглянуто %d, порожніх %d, написів %d, дублікатів %d"
          % (stats["усього"], stats["порожніх"], stats["написів"],
             stats["дублікатів"]))
    print("у зведеному аркуші %d клітинок, сітка %d x %d" % (len(kept), cols, rows))
    print("аркуш ->", out)
    print("джерела ->", index)


if __name__ == "__main__":
    main()
