"""Робить із фігурки в наборі Міші аркуш героя: два ракурси, хода, тінь.

Чому не генерацією. На машині з відеокартою стоїть один DreamShaper 8 і жодної
LoRA під піксель-арт. Він малює гарні мультяшні ілюстрації, але не спрайти:
пропорції дорослі замість «двоголових», обведення немає, а «пікселі» на ньому
несправжні й після зменшення до півсотні пікселів перетворюються на кашу.
Поруч із фігурками Міші такий герой — чужий. Тому герой береться з НАБОРУ, а
код доробляє те, чого в наборі немає.

Чого немає. Фігурка одна й дивиться на глядача. Для ізометрії треба чотири
напрямки — але їх саме два: рух на +x і +y іде НА глядача (перед), на -x і -y —
ВІД глядача (спина), а ліворуч-праворуч дає дзеркало. Тож досить двох ракурсів.

Спину роблю з переду: заклеюю обличчя волоссям. На такому розмірі спина й перед
і справді різняться майже тільки цим.

Хода — два кроки: у другому кадрі смуга з ногами віддзеркалена. Нога, що була
попереду, стає задньою; разом із похитуванням, яке додає рушій, цього досить.

    python tools/make_hero.py
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ATLAS = os.path.join(ROOT, "game", "art", "plyn", "atlas_terrain.png")
OUT = os.path.join(ROOT, "game", "art", "plyn", "hero.png")
SHADOW = os.path.join(ROOT, "game", "art", "plyn", "shadow.png")
CELL = 192

## Кого беремо з атласу і як його звати. Порядок рядків в аркуші такий самий.
WHO = [
    ("hero", (10, 9)),
    ("selianka", (3, 9)),
    ("selianyn", (9, 9)),
    ("varta", (11, 9)),
]

## Розмір клітинки аркуша. З запасом на похитування.
FRAME = (96, 136)
## Скільки кадрів у ряду: спокій, крок, спокій, крок другою ногою.
STEPS = 2


def tile(atlas: np.ndarray, c: int, r: int) -> Image.Image:
    piece = atlas[r * CELL:(r + 1) * CELL, c * CELL:(c + 1) * CELL]
    ys, xs = np.nonzero(piece[:, :, 3] > 100)
    return Image.fromarray(
        piece[ys.min():ys.max() + 1, xs.min():xs.max() + 1].astype(np.uint8), "RGBA"
    )


def legs_band(img: Image.Image) -> int:
    """Від якого рядка починаються ноги.

    Шукаємо не «низ спрайта», а місце, де силует РОЗПАДАЄТЬСЯ НАДВОЄ: доти це
    одна пляма тулуба, а нижче — дві ноги. Так смуга знаходиться сама, і для
    кожної фігурки своя, замість підібраного на око числа.
    """
    a = np.asarray(img)
    solid = a[:, :, 3] > 100
    for y in range(a.shape[0] - 1, a.shape[0] // 2, -1):
        row = solid[y]
        runs = int(np.count_nonzero(row[1:] & ~row[:-1])) + int(row[0])
        if runs < 2:
            return y + 1
    return a.shape[0] * 3 // 4


def step(img: Image.Image, swap: bool) -> Image.Image:
    if not swap:
        return img.copy()
    top = legs_band(img)
    out = img.copy()
    band = img.crop((0, top, img.width, img.height))
    out.paste(band.transpose(Image.FLIP_LEFT_RIGHT), (0, top))
    return out


def biggest_blob(mask: np.ndarray) -> np.ndarray:
    """Найбільша звʼязна пляма маски.

    Потрібна саме пляма, а не всі пікселі кольору шкіри разом: у чарівниці
    світлий ще й набалдашник посоха, і прямокутник «від найлівішого до
    найправішого» накривав пів кадру.
    """
    h, w = mask.shape
    src = Image.fromarray(np.where(mask, 255, 0).astype(np.uint8), "L")
    best = np.zeros_like(mask)
    seen = np.zeros_like(mask)
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or seen[y, x]:
                continue
            probe = src.copy()
            ImageDraw.floodfill(probe, (x, y), 128)
            blob = np.asarray(probe) == 128
            seen |= blob
            if blob.sum() > best.sum():
                best = blob
    return best


def back(img: Image.Image) -> Image.Image:
    """Заклеює обличчя волоссям: із переду виходить спина.

    Обличчя — найбільша пляма кольору шкіри у верхній половині фігурки. Очі
    лежать усередині неї, і їх треба заклеїти теж, інакше вони лишаються на
    потилиці двома дірками; тому беремо не саму пляму, а всі непрозорі пікселі
    в її прямокутнику.

    Колір беремо з РАМКИ навколо обличчя — це і є волосся. Спершу я копіював
    рядок над обличчям, і в чарівниці там виявилося порожньо: замість потилиці
    вийшла чорна дірка.
    """
    a = np.asarray(img).astype(np.int32).copy()
    h, w = a.shape[:2]
    half = h // 2

    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    skin = (al > 100) & (r > 190) & (g > 150) & (b > 120) & (r > b + 20)
    skin[half:] = False
    if not skin.any():
        return img.copy()

    face = biggest_blob(skin)
    ys, xs = np.nonzero(face)
    top, bottom = int(ys.min()), int(ys.max())
    left, right = int(xs.min()), int(xs.max())

    # Волосся — найчастіший непрозорий колір у рамці навколо обличчя.
    ring = np.zeros((h, w), dtype=bool)
    ring[max(top - 4, 0):bottom + 5, max(left - 4, 0):right + 5] = True
    ring[top:bottom + 1, left:right + 1] = False
    ring &= al > 100
    if not ring.any():
        return img.copy()
    hair = np.array(
        Image.fromarray(a[ring][:, :3].astype(np.uint8).reshape(-1, 1, 3), "RGB")
        .quantize(colors=1).convert("RGB").getpixel((0, 0))
    )

    inside = np.zeros((h, w), dtype=bool)
    inside[top:bottom + 1, left:right + 1] = True
    inside &= al > 100
    a[inside, :3] = hair

    # Знизу потилиця темніша: без цього вона читається як пласка пляма.
    shade = np.zeros((h, w), dtype=bool)
    shade[max(bottom - 4, top):bottom + 1, left:right + 1] = True
    shade &= inside
    a[shade, :3] = (hair * 0.72).astype(np.int32)

    return Image.fromarray(a.astype(np.uint8), "RGBA")


def sheet() -> None:
    atlas = np.asarray(Image.open(ATLAS).convert("RGBA")).astype(np.int32)
    rows: list[Image.Image] = []
    names: list[str] = []

    for name, at in WHO:
        front = tile(atlas, *at)
        for view, img in (("перед", front), ("спина", back(front))):
            strip = Image.new("RGBA", (FRAME[0] * STEPS, FRAME[1]), (0, 0, 0, 0))
            for i in range(STEPS):
                frame = step(img, i == 1)
                strip.paste(
                    frame,
                    (i * FRAME[0] + (FRAME[0] - frame.width) // 2,
                     FRAME[1] - frame.height),
                    frame,
                )
            rows.append(strip)
            names.append("%s / %s" % (name, view))

    out = Image.new("RGBA", (FRAME[0] * STEPS, FRAME[1] * len(rows)), (0, 0, 0, 0))
    for i, strip in enumerate(rows):
        out.paste(strip, (0, i * FRAME[1]), strip)
    out.save(OUT)

    with open(os.path.splitext(OUT)[0] + "-склад.txt", "w", encoding="utf-8") as fh:
        fh.write("Аркуш героїв. Клітинка %dx%d, %d кадри ходи в рядку.\n\n"
                 % (FRAME[0], FRAME[1], STEPS))
        for i, n in enumerate(names):
            fh.write("рядок %d  %s\n" % (i, n))

    print("аркуш -> %s  %s  рядків %d" % (OUT, out.size, len(rows)))


def shadow() -> None:
    """Тінь під ногами. Без неї фігурка не стоїть на землі, а висить над нею."""
    big = Image.new("L", (256, 128), 0)
    ImageDraw.Draw(big).ellipse((16, 16, 240, 112), fill=225)
    big = big.filter(ImageFilter.GaussianBlur(14))
    out = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    out.putalpha(big.resize((64, 32), Image.LANCZOS))
    out.save(SHADOW)
    print("тінь -> %s" % SHADOW)


if __name__ == "__main__":
    sheet()
    shadow()
