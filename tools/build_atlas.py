"""Робить із аркуша ЧИСТИЙ атлас із рівним кроком і прозорим тлом.

Навіщо. Godot вантажить тайлсет як атлас: одна картинка, у якій клітинки йдуть
через рівне ціле число пікселів. Наші аркуші згенеровані, і крок у них дробовий
(191.85 на 188.50) — Godot такого не вміє в принципі.

Тому аркуш перескладається: кожна клітинка ріжеться за своїм справжнім місцем і
кладеться в нову картинку рівно через 192 пікселі. Заразом знімається тло —
рівний синьо-сірий, якого в самих плитках немає, тож звичайний ключ за кольором
тут точний, а не приблизний.

    python tools/build_atlas.py art_src/tilesets/лист.jpeg game/art/plyn/atlas.png \\
        --step 191.85 188.50 --origin 62 30 --cols 14 --rows 8 --first-row 1
"""
import argparse
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL = 192


def sheet_background(a: np.ndarray) -> np.ndarray:
    """Тло аркуша — НАЙЧАСТІШИЙ колір усього аркуша.

    Спершу я брав його з кутів кадру — і промахнувся: угорі цих аркушів стоїть
    смуга з назвою, вона темна, і за тло видавала себе саме вона. Через це ключ
    не знімав нічого. Найчастіший колір надійніший: тла на аркуші завжди більше,
    ніж будь-чого іншого.
    """
    from collections import Counter

    sample = a[::5, ::5].reshape(-1, 3)
    common = Counter(map(tuple, sample)).most_common(1)[0][0]
    return np.array(common, dtype=np.float64)


def main() -> None:
    ap = argparse.ArgumentParser(description="Чистий атлас із аркуша")
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--step", nargs=2, type=float, required=True)
    ap.add_argument("--origin", nargs=2, type=float, required=True)
    ap.add_argument("--cols", type=int, required=True)
    ap.add_argument("--rows", type=int, required=True)
    ap.add_argument("--first-row", type=int, default=0,
                    help="з якого рядка починати (0 — з першого; 1 — пропустити назву)")
    ap.add_argument("--tolerance", type=int, default=34,
                    help="наскільки далеко від тла колір ще вважається тлом")
    args = ap.parse_args()

    src = args.src if os.path.isabs(args.src) else os.path.join(ROOT, args.src)
    dst = args.dst if os.path.isabs(args.dst) else os.path.join(ROOT, args.dst)

    img = Image.open(src).convert("RGB")
    a = np.asarray(img).astype(np.int32)
    bg = sheet_background(a)

    sx, sy = args.step
    ox, oy = args.origin
    used_rows = args.rows - args.first_row
    atlas = Image.new("RGBA", (args.cols * CELL, used_rows * CELL), (0, 0, 0, 0))

    for row in range(args.first_row, args.rows):
        for col in range(args.cols):
            x0 = int(round(ox + col * sx))
            y0 = int(round(oy + row * sy))
            x1 = int(round(ox + (col + 1) * sx))
            y1 = int(round(oy + (row + 1) * sy))
            # Останній ряд часто не влазить у аркуш на кілька пікселів —
            # обрізаємо його по краю, а не викидаємо цілком.
            x1 = min(x1, img.width)
            y1 = min(y1, img.height)
            if x1 - x0 < 32 or y1 - y0 < 32:
                continue

            cell = img.crop((x0, y0, x1, y1)).resize((CELL, CELL), Image.LANCZOS)
            c = np.asarray(cell).astype(np.int32)

            # Тло беремо з КУТІВ ЦІЄЇ клітинки, а не з усього аркуша: аркуш
            # згенерований, і відтінок тла на ньому плаває. Один спільний
            # колір або лишав квадрати тла в одних клітинках, або вигризав
            # камінь в інших — середини не було.
            k = 14
            corners = np.concatenate([
                c[:k, :k].reshape(-1, 3), c[:k, -k:].reshape(-1, 3),
                c[-k:, :k].reshape(-1, 3), c[-k:, -k:].reshape(-1, 3),
            ])
            local_bg = np.median(corners, axis=0)
            # Якщо кути зайняті самою плиткою, локальний колір бреше —
            # тоді покладаємося на загальний.
            bg_here = local_bg if np.linalg.norm(local_bg - bg) < 70 else bg

            # Ключ за кольором тла. Мʼякий край: біля порогу прозорість наростає
            # плавно, інакше по силуету йде пилка.
            dist = np.sqrt(((c - bg_here) ** 2).sum(axis=2))
            alpha = np.clip(
                (dist - args.tolerance * 0.6) / (args.tolerance * 0.4), 0.0, 1.0
            )
            # Дірки всередині плитки заливаємо назад. Сірий камінь близький
            # кольором до синьо-сірого тла, і ключ вигризає в ньому плями.
            # Справжнє тло дотикається краю клітинки, а пляма в камені — ні,
            # тому розрізняємо їх за звʼязністю, а не за кольором.
            solid = (alpha > 0.5).astype(np.uint8)
            mark = Image.fromarray(((1 - solid) * 255).astype(np.uint8), "L")
            padded = Image.new("L", (CELL + 2, CELL + 2), 255)
            padded.paste(mark, (1, 1))
            ImageDraw.floodfill(padded, (0, 0), 128)
            outside = np.asarray(padded.crop((1, 1, CELL + 1, CELL + 1))) == 128
            alpha = np.where(outside, alpha, np.maximum(alpha, 1.0))

            # Стираємо крайню рамку клітинки. Там лежать ЛІНІЇ СІТКИ вихідного
            # аркуша: вони темні, ключ їх не бере, і в грі вони малюють темну
            # решітку між плитками. Сама плитка до краю не дістає, тож нічого
            # потрібного тут не втрачається.
            edge = 4
            alpha[:edge, :] = 0.0
            alpha[-edge:, :] = 0.0
            alpha[:, :edge] = 0.0
            alpha[:, -edge:] = 0.0

            rgba = np.dstack([c, (alpha * 255)]).astype(np.uint8)

            atlas.paste(
                Image.fromarray(rgba, mode="RGBA"),
                (col * CELL, (row - args.first_row) * CELL),
            )

    os.makedirs(os.path.dirname(dst), exist_ok=True)
    atlas.save(dst)
    print("атлас -> %s  %s  сітка %d x %d по %d" % (
        dst, atlas.size, args.cols, used_rows, CELL))


if __name__ == "__main__":
    main()
