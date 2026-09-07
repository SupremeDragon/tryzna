"""Робить із кубиків-парканів накладки на пів-грані.

Навіщо. Усі шість парканів у наборі Міші намальовані однаково: кубик землі, а
на ньому паркан ОДРАЗУ ПО ДВОХ передніх ребрах ромба, кутом. Такою плиткою не
можна обвести двір: у ряд вони лягають то внапуск, то з дірками — на екрані це
читалося як розкидані стовпчики, а не як огорожа.

Що робимо, по кроках.

1. Віднімаємо від паркана ту саму травʼяну плитку, на якій його намалювали
   (3-0 — вона збігається з ним попіксельно), і лишається сам паркан без землі.
   Тепер це НАКЛАДКА: під нею видно будь-яку землю, а не тільки ту траву.

2. РОЗТЯГУЄМО. Паркан намальований усередині клітинки, з відступом: деревина
   займає 27..165 пікселя, а ромб — 10..181. Саме через цей відступ між
   сусідніми парканами зяяли дірки. Збільшення в 1.24 раза точно накладає
   кінці паркана на кути ромба, і ряд стає суцільним.

3. Ріжемо навпіл по вертикалі. Ліва половина лягає на ребро до сусіда (x, y+1),
   права — на ребро до сусіда (x+1, y). Ріжемо з напуском, щоб кутовий стовпчик
   потрапив в обидві половинки: тоді ряд закінчується стовпцем, а не обрубком.

Кладемо в порожні клітинки атласу (рядок 10). Запускати ПІСЛЯ pack_cut.py:

    python tools/make_fence_overlays.py
"""
import os

import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ATLAS = os.path.join(ROOT, "game", "art", "plyn", "atlas_terrain.png")
CELL = 192

## Травʼяна плитка, на якій намальовані паркани. Знайдена перебором: з усіх
## плиток набору саме вона найменше різниться з парканом по бічних гранях.
GRASS = (3, 0)

## Звідки беремо паркан і куди кладемо: (джерело, ліва, права, кут цілий).
##
## Кут потрібен окремою плиткою: у західно-північному розі двору сходяться
## обидва ребра, а на клітинку кладеться одна плитка, не дві.
PAIRS = [
    ((7, 3), (1, 10), (2, 10), (5, 10)),
    ((11, 3), (3, 10), (4, 10), (6, 10)),
]

## Напуск половинок від центру клітинки, пікселів.
OVERLAP = 10

## Наскільки збільшити паркан, щоб він сів рівно на ребра ромба, і навколо якої
## точки. Числа зміряні: деревина займає 27..165 по ширині, ромб — 10..181,
## тобто 171 / 138. Точка по вертикалі підібрана так, щоб низ паркана ліг на
## нижній кут ромба (126), а не висів над ним.
GROW = 171.0 / 138.0
PIVOT = (96.0, 28.0)


def cell(a: np.ndarray, c: int, r: int) -> np.ndarray:
    return a[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL].copy()


def wood_only(fence: np.ndarray, grass: np.ndarray) -> np.ndarray:
    """Лишає саме дерево: те, чого немає на травʼяній плитці й що коричневе.

    Однієї різниці замало: трава на двох плитках трохи різна пікселями, і
    різниця сама по собі лишає зелений шум по всьому ромбу. Дерево коричневе,
    а трава зелена, тож друга умова — червоного більше, ніж зеленого.
    """
    diff = (np.abs(fence[:, :, :3] - grass[:, :, :3]).sum(axis=2)
            + np.abs(fence[:, :, 3] - grass[:, :, 3]))
    brown = (fence[:, :, 0] - fence[:, :, 1]) >= 10
    keep = (diff > 60) & (fence[:, :, 3] > 100) & brown

    # Дрібний бруд по бічних гранях кубика теж коричневий, і за кольором його
    # не відсіяти. Але паркан — суцільні бруси завтовшки з півдесятка пікселів,
    # а бруд — поодинокі крапки, тож знімаємо його розмиканням: спершу
    # звужуємо маску на піксель (крапки зникають), потім вертаємо ширину.
    mask = Image.fromarray((keep * 255).astype(np.uint8), "L")
    mask = mask.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MaxFilter(3))
    keep = np.asarray(mask) > 127

    out = fence.copy()
    out[:, :, 3] = np.where(keep, fence[:, :, 3], 0)
    return out


def grow(tile: np.ndarray) -> np.ndarray:
    """Розтягує накладку від PIVOT у GROW разів, лишаючись у тій самій клітинці."""
    img = Image.fromarray(tile.astype(np.uint8), "RGBA")
    big = img.resize(
        (int(round(CELL * GROW)), int(round(CELL * GROW))), Image.NEAREST
    )
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    out.paste(big, (
        int(round(PIVOT[0] * (1.0 - GROW))),
        int(round(PIVOT[1] * (1.0 - GROW))),
    ))
    return np.asarray(out).astype(np.int32)


def half(tile: np.ndarray, left: bool) -> np.ndarray:
    out = tile.copy()
    mid = CELL // 2
    if left:
        out[:, mid + OVERLAP:, 3] = 0
    else:
        out[:, :mid - OVERLAP, 3] = 0
    return out


def main() -> None:
    img = Image.open(ATLAS).convert("RGBA")
    a = np.asarray(img).astype(np.int32)
    grass = cell(a, *GRASS)

    for src, lt, rt, corner in PAIRS:
        wood = grow(wood_only(cell(a, *src), grass))
        for dst, piece, what in (
            (lt, half(wood, True), "ліве ребро"),
            (rt, half(wood, False), "праве ребро"),
            (corner, wood, "кут"),
        ):
            c, r = dst
            a[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL] = piece
            print("паркан %d-%d -> %d-%d  %s" % (src[0], src[1], c, r, what))

    Image.fromarray(a.astype(np.uint8), "RGBA").save(ATLAS)
    print("атлас оновлено:", ATLAS)


if __name__ == "__main__":
    main()
