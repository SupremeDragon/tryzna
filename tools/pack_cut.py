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


def key_alpha(a: np.ndarray, bg: np.ndarray, tolerance: float) -> np.ndarray:
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    return np.clip((dist - tolerance * 0.6) / (tolerance * 0.4), 0.0, 1.0)


def fill_holes(alpha: np.ndarray) -> np.ndarray:
    """Повертає непрозорість тому, що всередині контуру.

    Сірий камінь близький кольором до синьо-сірого тла, і ключ вигризає в ньому
    плями. Справжнє тло дотикається краю картинки, а пляма в камені — ні, тому
    розрізняємо їх за звʼязністю.
    """
    h, w = alpha.shape
    solid = (alpha > 0.5).astype(np.uint8)
    mark = Image.fromarray(((1 - solid) * 255).astype(np.uint8), "L")
    padded = Image.new("L", (w + 2, h + 2), 255)
    padded.paste(mark, (1, 1))
    ImageDraw.floodfill(padded, (0, 0), 128)
    outside = np.asarray(padded.crop((1, 1, w + 1, h + 1))) == 128
    return np.where(outside, alpha, 1.0)


def cut_background(img: Image.Image, tolerance: int) -> Image.Image:
    rgb = img.convert("RGB")
    a = np.asarray(rgb).astype(np.int32)
    h, w = a.shape[:2]

    # Тло — НАЙЧАСТІШИЙ колір плитки, а не колір її кутів.
    #
    # Кути я пробував двічі й двічі помилявся: у вирізках Міші по краю лежить
    # ТЕМНА ЛІНІЯ СІТКИ вихідного аркуша (близько 34,41,69), і саме її я брав
    # за взірець тла. Справжнє тло синьо-сіре, близько 80,95,126. Через це ключ
    # знімав не те, що треба, — а виглядало це як «ключ не працює».
    #
    # Найчастіший колір тут надійний: тла на плитці більше, ніж будь-чого.
    from collections import Counter

    # Беремо не весь кадр, а СМУГУ ПІД ТЕМНОЮ РАМКОЮ: від 4 до 14 пікселів від
    # краю. У кадрі цілком може переважати сама плитка (у трьох із пʼятдесяти
    # так і вийшло, і найчастішим кольором ставала трава), а в цій смузі тло є
    # завжди — кубик до неї не дістає.
    ring = np.concatenate([
        a[4:14, :].reshape(-1, 3), a[-14:-4, :].reshape(-1, 3),
        a[:, 4:14].reshape(-1, 3), a[:, -14:-4].reshape(-1, 3),
    ])
    bg = np.array(Counter(map(tuple, ring)).most_common(1)[0][0], dtype=np.float64)

    # Поріг ПІДБИРАЄТЬСЯ для кожної плитки окремо, і міряється не колір, а
    # РЕЗУЛЬТАТ: скільки картинки лишилося непрозорим після повного проходу.
    #
    # Спершу я перевіряв, чи прозорі кути, — і перевірка виявилася порожньою:
    # кути це саме те місце, звідки береться взірець тла, тож вони прозорі
    # завжди, за будь-якого порогу.
    #
    # Ізометричний кубик займає приблизно три пʼятих свого квадрата. Якщо після
    # зняття лишилося більше чотирьох пʼятих — тло не знялося. Беремо перший
    # поріг, за якого доля вкладається в межу.
    # Межа знизу так само потрібна, як згори. Спершу я брав просто найменшу
    # непрозорість — і три плитки зникли зовсім: найменша непрозорість буває
    # саме тоді, коли ключ зʼїв усе. Кубик займає від третини до чотирьох
    # пʼятих свого квадрата; беремо перший поріг, що влучає в цю вилку.
    best: np.ndarray | None = None
    best_miss: float = 1e9
    for probe in (tolerance, 62, 80, 100, 125, 155, 195, 240):
        dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
        alpha = np.clip((dist - probe * 0.6) / (probe * 0.4), 0.0, 1.0)
        alpha = fill_holes(alpha)
        share = float((alpha > 0.5).mean())

        if 0.34 <= share <= 0.80:
            best = alpha
            break

        # Наскільки далеко від вилки — щоб було що взяти, коли не влучив ніхто.
        miss = (0.34 - share) if share < 0.34 else (share - 0.80)
        if miss < best_miss:
            best_miss = miss
            best = alpha

    # Темну рамку по краю стираємо окремо: вона не тло за кольором, тож ключ
    # її не бере, і в грі вона малює тонкий темний прямокутник довкола плитки.
    edge = 3
    best[:edge, :] = 0.0
    best[-edge:, :] = 0.0
    best[:, :edge] = 0.0
    best[:, -edge:] = 0.0

    out = rgb.convert("RGBA")
    out.putalpha(Image.fromarray((best * 255).astype(np.uint8), "L"))
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
