"""Малює віньєтку — затемнення до країв кадру.

Найдешевший спосіб перестати виглядати «картинкою на екрані»: коли кут кадру
темніший за середину, око перестає читати межі екрана як межі малюнка.

Робиться текстурою, а не малюванням у світі: у світових координатах вона
з'їжджає разом із камерою й лягає видимим коробом. Її місце — екранний шар.

Запуск:  python tools/make_vignette.py
"""
import math
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "art", "vignette.png")

WIDTH, HEIGHT = 512, 288   # розтягнеться на весь екран, деталей тут не треба
CLEAR = 0.42               # частка радіуса, де ще зовсім прозоро
STRENGTH = 235             # альфа в найтемнішому куті
FALLOFF = 1.9


def main():
    img = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    px = img.load()
    cx, cy = WIDTH / 2.0, HEIGHT / 2.0
    max_r = math.sqrt(cx * cx + cy * cy)

    for y in range(HEIGHT):
        dy = y - cy
        for x in range(WIDTH):
            dx = x - cx
            r = math.sqrt(dx * dx + dy * dy) / max_r
            if r <= CLEAR:
                continue
            k = (r - CLEAR) / (1.0 - CLEAR)
            px[x, y] = (0, 0, 0, int(min(1.0, math.pow(k, FALLOFF)) * STRENGTH))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("готово ->", OUT, img.size)


if __name__ == "__main__":
    main()
