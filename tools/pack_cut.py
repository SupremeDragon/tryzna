"""Пакує окремо вирізані плитки в один атлас із прозорим тлом.

Міша вирізав плитки поштучно, кожну своїм файлом. Це набагато надійніше за будь-яку
автоматичну нарізку аркуша: людина бачить, де плитка, а програма мусить вгадувати.
Лишається зняти синьо-сіре тло й скласти все в атлас із рівним кроком — Godot
вантажить тайлсет тільки так.

Плитки вирівнюються по НИЗУ, а не по центру. Кубик землі й дерево — різної
висоти, і якщо центрувати їх, дерево злетить над землею. По низу вони обидва
стоять на одній лінії, як і має бути.

    python tools/pack_cut.py art_src/cut game/art/plyn/atlas_terrain.png --cols 10
"""
import argparse
import os
import re

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CELL = 192
FOOT = 186   # на якій висоті в клітинці стоїть низ плитки


def order_key(name: str):
    m = re.match(r"^(\d+)", name)
    return (0, int(m.group(1))) if m else (1, name)


def cut_background(img: Image.Image, tolerance: int) -> Image.Image:
    rgb = img.convert("RGB")
    a = np.asarray(rgb).astype(np.int32)
    h, w = a.shape[:2]

    # Тло беремо з кутів САМОЇ плитки: у кожного файлу свій відтінок.
    k = max(min(w, h) // 12, 4)
    corners = np.concatenate([
        a[:k, :k].reshape(-1, 3), a[:k, -k:].reshape(-1, 3),
        a[-k:, :k].reshape(-1, 3), a[-k:, -k:].reshape(-1, 3),
    ])
    bg = np.median(corners, axis=0)

    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    alpha = np.clip((dist - tolerance * 0.6) / (tolerance * 0.4), 0.0, 1.0)

    # Дірки всередині заливаємо назад: сірий камінь близький до синьо-сірого
    # тла, і ключ вигризає в ньому плями. Справжнє тло дотикається краю
    # картинки, а пляма в камені — ні.
    solid = (alpha > 0.5).astype(np.uint8)
    mark = Image.fromarray(((1 - solid) * 255).astype(np.uint8), "L")
    padded = Image.new("L", (w + 2, h + 2), 255)
    padded.paste(mark, (1, 1))
    ImageDraw.floodfill(padded, (0, 0), 128)
    outside = np.asarray(padded.crop((1, 1, w + 1, h + 1))) == 128
    alpha = np.where(outside, alpha, 1.0)

    out = rgb.convert("RGBA")
    out.putalpha(Image.fromarray((alpha * 255).astype(np.uint8), "L"))
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description="Атлас із поштучно вирізаних плиток")
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--cols", type=int, default=10)
    ap.add_argument("--tolerance", type=int, default=46)
    args = ap.parse_args()

    src = args.src if os.path.isabs(args.src) else os.path.join(ROOT, args.src)
    dst = args.dst if os.path.isabs(args.dst) else os.path.join(ROOT, args.dst)

    names = sorted(
        (n for n in os.listdir(src) if n.lower().endswith((".png", ".jpg", ".jpeg"))),
        key=order_key,
    )
    if not names:
        raise SystemExit("У теці немає плиток: " + src)

    cols = args.cols
    rows = (len(names) + cols - 1) // cols
    atlas = Image.new("RGBA", (cols * CELL, rows * CELL), (0, 0, 0, 0))
    index: list[str] = []

    for i, name in enumerate(names):
        piece = cut_background(Image.open(os.path.join(src, name)), args.tolerance)
        box = piece.split()[3].point(lambda v: 255 if v > 24 else 0).getbbox()
        if box is None:
            print("порожня:", name)
            continue
        piece = piece.crop(box)

        # По центру за шириною, по НИЗУ за висотою.
        x = (CELL - piece.width) // 2
        y = FOOT - piece.height
        atlas.paste(piece, ((i % cols) * CELL + x, (i // cols) * CELL + y), piece)
        index.append("%02d-%02d  %s  %dx%d" % (i // cols, i % cols, name,
                                               piece.width, piece.height))

    os.makedirs(os.path.dirname(dst), exist_ok=True)
    atlas.save(dst)

    with open(os.path.splitext(dst)[0] + "-склад.txt", "w", encoding="utf-8") as fh:
        fh.write("Що де лежить в атласі. Рядок-стовпець -> файл.\n\n")
        fh.write("\n".join(index) + "\n")

    print("атлас -> %s  %s  сітка %d x %d" % (dst, atlas.size, cols, rows))


if __name__ == "__main__":
    main()
