"""Знаходить сітку аркуша: крок і початок, окремо по кожній осі.

Навіщо окремий інструмент. Аркуші згенеровані нейромережею, а не намальовані
по пікселях: крок у них дробовий і РІЗНИЙ по осях (191.65 на 189.3). Підбирати
такі числа руками — це годину дивитися на червону сітку й пересувати її на
піксель. Тут те саме робиться перебором за півхвилини.

Спосіб простий: лінії сітки темніші за тло, тож для кожного кроку й зсуву
рахуємо, наскільки темно на «гребінці» з таких ліній. Правильний крок дає
найтемнішу гребінку.

    python tools/grid_probe.py art_src/tilesets/лист.jpeg
    python tools/grid_probe.py art_src/tilesets/*.jpeg --min 180 --max 210
"""
import argparse
import glob
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def best_grid(darkness: np.ndarray, length: int, lo: float, hi: float):
    best = None
    for period in np.arange(lo, hi + 0.001, 0.05):
        count = int(length / period)
        if count < 5:
            continue
        for off in np.arange(0.0, period, 1.0):
            xs = (off + np.arange(count + 1) * period).astype(int)
            xs = xs[(xs >= 0) & (xs < length)]
            if len(xs) < 5:
                continue
            score = float(darkness[xs].mean())
            if best is None or score > best[0]:
                best = (score, float(period), float(off), len(xs) - 1)
    return best


def probe(path: str, lo: float, hi: float):
    img = Image.open(path).convert("RGB")
    a = np.asarray(img).astype(float)
    # Тло аркуша — найчастіший тон; лінії сітки помітно темніші за нього.
    bg = float(np.median(a.sum(axis=2)))
    dark = (a.sum(axis=2) < bg - 40).astype(float)

    h, w = dark.shape
    bx = best_grid(dark.mean(axis=0), w, lo, hi)
    by = best_grid(dark.mean(axis=1), h, lo, hi)
    return img.size, bx, by


def main() -> None:
    ap = argparse.ArgumentParser(description="Знайти сітку аркуша")
    ap.add_argument("sheets", nargs="+")
    ap.add_argument("--min", type=float, default=170.0)
    ap.add_argument("--max", type=float, default=215.0)
    args = ap.parse_args()

    paths: list[str] = []
    for pattern in args.sheets:
        found = sorted(glob.glob(pattern))
        paths.extend(found or [pattern])

    for path in paths:
        full = path if os.path.isabs(path) else os.path.join(ROOT, path)
        size, bx, by = probe(full, args.min, args.max)
        name = os.path.basename(path)
        if bx is None or by is None:
            print("%-50s %s  сітки не видно" % (name, size))
            continue
        print(
            "%-50s %s  крок %.2f x %.2f  початок %.0f, %.0f  клітинок %d x %d"
            % (name, size, bx[1], by[1], bx[2], by[2], bx[3], by[3])
        )


if __name__ == "__main__":
    main()
