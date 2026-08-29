"""Ріже згенеровані кадри Ниці на шари з прозорим тлом.

Тло в цих кадрах — рівний сірий, тому знімається порогом за різницею кольору.
Заодно відділяє смугу стовпів від підлоги: підлога — суцільна по всій ширині,
стовпи — розріджені, і це видно по частці непрозорих пікселів у рядку.
"""
import os
from collections import Counter
from PIL import Image, ImageChops

SRC = r"F:\Tryzna\art_src"
OUT = r"F:\Tryzna\game\art\nyts"
os.makedirs(OUT, exist_ok=True)

SOFT_LOW = 26    # нижче цієї різниці — тло
SOFT_HIGH = 58   # вище — предмет; між ними мʼякий край


def detect_background(img: Image.Image) -> tuple:
    """Найчастіший колір у верхній смузі — це тло."""
    w, h = img.size
    band = img.crop((0, int(h * 0.30), w, int(h * 0.45))).resize((w // 8, 40))
    return Counter(band.getdata()).most_common(1)[0][0]


def key_out(img: Image.Image, bg: tuple) -> Image.Image:
    solid = Image.new("RGB", img.size, bg)
    diff = ImageChops.difference(img, solid).convert("L")
    table = [
        0 if v < SOFT_LOW
        else 255 if v > SOFT_HIGH
        else int((v - SOFT_LOW) / (SOFT_HIGH - SOFT_LOW) * 255)
        for v in range(256)
    ]
    out = img.convert("RGBA")
    out.putalpha(diff.point(table))
    return out


def row_coverage(alpha: Image.Image) -> list:
    """Частка непрозорих пікселів у кожному рядку."""
    w, h = alpha.size
    small = alpha.resize((160, h))
    px = small.load()
    return [sum(1 for x in range(160) if px[x, y] > 100) / 160.0 for y in range(h)]


def split_pillars_and_floor(rgba: Image.Image) -> tuple:
    """Верх — балка стелі, середина — стовпи, низ — підлога.

    Стовпи впізнаються за тим, що вони НЕ заповнюють рядок цілком.
    """
    cover = row_coverage(rgba.getchannel("A"))
    h = len(cover)

    top = 0
    while top < h and cover[top] > 0.60:
        top += 1
    bottom = h - 1
    while bottom > top and cover[bottom] > 0.60:
        bottom -= 1

    pillars = rgba.crop((0, top, rgba.width, bottom + 1))
    floor = rgba.crop((0, bottom + 1, rgba.width, h))
    return pillars, floor


def coverage_of(rgba: Image.Image) -> float:
    small = rgba.getchannel("A").resize((200, 120))
    px = small.load()
    hits = sum(1 for y in range(120) for x in range(200) if px[x, y] > 100)
    return hits / (200.0 * 120.0)


JOBS = [
    ("Stone_bars_in_corridor_silhouette_202608291920.jpeg", "pillars_near", True),
    ("Stone_bars_in_corridor_silhouette_202608291909.jpeg", "pillars_mid", False),
    ("Stone_bars_in_corridor_silhouette_202608291914.jpeg", "pillars_front", False),
]

for filename, name, keep_floor in JOBS:
    path = os.path.join(SRC, filename)
    if not os.path.exists(path):
        print("немає:", filename)
        continue

    img = Image.open(path).convert("RGB")
    bg = detect_background(img)
    rgba = key_out(img, bg)
    pillars, floor = split_pillars_and_floor(rgba)

    pillars.save(os.path.join(OUT, name + ".png"))
    print("%-16s тло=%s  розмір=%dx%d  заповнення=%.0f%%" % (
        name, bg, pillars.width, pillars.height, coverage_of(pillars) * 100
    ))

    if keep_floor and floor.height > 40:
        floor.save(os.path.join(OUT, "floor.png"))
        print("%-16s розмір=%dx%d" % ("floor", floor.width, floor.height))

print("\nготово ->", OUT)
