"""Ріже згенеровані кадри Ниці на шари з прозорим тлом.

Тло в цих кадрах — рівний сірий або чорний, тому знімається порогом за
різницею кольору. Заодно відрізає суцільні смуги зверху й знизу: балку стелі
й підлогу. Розпізнає їх за часткою непрозорих пікселів у рядку — підлога
заповнює рядок цілком, стовпи лише на чверть.

Запуск:  python tools/cut_layers.py
"""
import os
from collections import Counter
from PIL import Image, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art_src", "approved")
OUT = os.path.join(ROOT, "game", "art", "nyts")

SOFT_LOW = 24     # нижче цієї різниці — тло
SOFT_HIGH = 56    # вище — предмет; між ними мʼякий край
SOLID_ROW = 0.60  # частка непрозорого, за якою рядок вважається суцільним


def detect_background(img):
    """Найчастіший колір у смузі 30-45% висоти — це тло."""
    w, h = img.size
    band = img.crop((0, int(h * 0.30), w, int(h * 0.45))).resize((max(w // 8, 1), 40))
    return Counter(band.getdata()).most_common(1)[0][0]


def key_out(img, bg):
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


def row_coverage(alpha):
    w, h = alpha.size
    small = alpha.resize((160, h))
    px = small.load()
    return [sum(1 for x in range(160) if px[x, y] > 100) / 160.0 for y in range(h)]


def trim_solid_bands(rgba):
    """Знімає суцільні смуги зверху (балка) й знизу (підлога)."""
    cover = row_coverage(rgba.getchannel("A"))
    h = len(cover)

    top = 0
    while top < h and cover[top] > SOLID_ROW:
        top += 1
    bottom = h - 1
    while bottom > top and cover[bottom] > SOLID_ROW:
        bottom -= 1

    pillars = rgba.crop((0, top, rgba.width, bottom + 1))
    floor = rgba.crop((0, bottom + 1, rgba.width, h))
    return pillars, floor


def trim_empty_edges(rgba):
    """Обрізає повністю прозорі поля, щоб масштаб у грі був передбачуваним."""
    box = rgba.getchannel("A").getbbox()
    return rgba.crop(box) if box else rgba


def coverage_of(rgba):
    small = rgba.getchannel("A").resize((200, 120))
    px = small.load()
    hits = sum(1 for y in range(120) for x in range(200) if px[x, y] > 100)
    return hits / (200.0 * 120.0)


# (файл-джерело, назва шару, чи зберігати відрізану підлогу)
JOBS = [
    ("nyts_src_row.png", "pillars_row", False),
    ("nyts_src_front.png", "pillars_front", False),
    ("nyts_src_pillars_near.jpg", "pillars_near", True),
    ("nyts_floor_v01.jpg", "floor_wide", False),
    ("nyts_l1_glow_v01.jpg", "glow", False),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    for filename, name, keep_floor in JOBS:
        path = os.path.join(SRC, filename)
        if not os.path.exists(path):
            print("немає:", filename)
            continue

        img = Image.open(path).convert("RGB")
        bg = detect_background(img)
        rgba = key_out(img, bg)

        if name in ("floor_wide", "glow"):
            # Підлога й заграва суцільні за задумом — смуги з них не ріжемо.
            result = trim_empty_edges(rgba)
            result.save(os.path.join(OUT, name + ".png"))
            print("%-14s тло=%s  %dx%d" % (name, bg, result.width, result.height))
            continue

        pillars, floor = trim_solid_bands(rgba)
        pillars = trim_empty_edges(pillars)

        if name == "pillars_front":
            # У джерелі стовпи стоять по ОБОХ краях. При повторенні вони
            # сходяться парою на кожному стику й перекривають пів екрана.
            # Лишаємо один стовп із запасом порожнечі праворуч.
            pillars = pillars.crop((0, 0, int(pillars.width * 0.62), pillars.height))
        pillars.save(os.path.join(OUT, name + ".png"))
        print("%-14s тло=%s  %dx%d  заповнення=%.0f%%" % (
            name, bg, pillars.width, pillars.height, coverage_of(pillars) * 100
        ))

        if keep_floor and floor.height > 40:
            floor = trim_empty_edges(floor)
            floor.save(os.path.join(OUT, "floor.png"))
            print("%-14s %dx%d" % ("floor", floor.width, floor.height))

    print("\nготово ->", OUT)


if __name__ == "__main__":
    main()
