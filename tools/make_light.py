"""Малює текстуру світла для Light2D.

Не радіальний градієнт «як у редакторі», а свідома крива: маленьке яскраве
ядро й довгий тьмяний ореол. Саме так читається світло, що йде від душі, —
воно нічого не освітлює далеко, зате саме себе показує чітко.

Запуск:  python tools/make_light.py
"""
import math
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "art", "light_soul.png")

SIZE = 512
CORE = 0.10   # частка радіуса, де світло майже повне
FALLOFF = 2.6  # що більше, то різкіше згасання


def main():
    img = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    px = img.load()
    centre = (SIZE - 1) / 2.0

    for y in range(SIZE):
        dy = (y - centre) / centre
        for x in range(SIZE):
            dx = (x - centre) / centre
            r = math.sqrt(dx * dx + dy * dy)
            if r >= 1.0:
                continue
            if r <= CORE:
                a = 1.0
            else:
                k = (r - CORE) / (1.0 - CORE)
                a = math.pow(1.0 - k, FALLOFF)
            px[x, y] = (255, 255, 255, int(a * 255))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("готово ->", OUT, img.size)


if __name__ == "__main__":
    main()
