"""Малює заграву в глибині Ниці.

Заграва — це світло, а не предмет. Мазок їй шкодить: згенерована вручну вона
читалася плямою фарби, а не сяйвом. Тому робимо її математикою: рівний
радіальний спад від тьмяно-червоного до чорного, плюс дрібне зерно, щоб не
виглядала як градієнт із фотошопу поруч із мальованим каменем.

Єдина барва в усьому світі мертвих — саме ця.

Запуск:  python tools/make_glow.py
"""
import math
import os
import random
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "art", "nyts", "glow.png")

WIDTH, HEIGHT = 1536, 864
CORE = (168, 44, 34)     # тьмяна запечена кров
CORE_RADIUS = 0.13       # частка висоти, де світло майже повне
FALLOFF = 2.3            # що більше, то щільніша темрява навколо
GRAIN = 5                # розмах зерна


def main():
    img = Image.new("RGB", (WIDTH, HEIGHT), (0, 0, 0))
    px = img.load()
    cx, cy = WIDTH / 2.0, HEIGHT / 2.0
    # Нормуємо по висоті, щоб пляма лишалася круглою на широкому кадрі.
    norm = HEIGHT / 2.0
    rng = random.Random(4041)

    for y in range(HEIGHT):
        dy = (y - cy) / norm
        for x in range(WIDTH):
            dx = (x - cx) / norm
            r = math.sqrt(dx * dx + dy * dy)

            if r <= CORE_RADIUS:
                k = 1.0
            else:
                k = max(0.0, 1.0 - (r - CORE_RADIUS) / (1.6 - CORE_RADIUS))
                k = math.pow(k, FALLOFF)

            n = rng.randint(-GRAIN, GRAIN)
            px[x, y] = (
                max(0, min(255, int(CORE[0] * k) + n)),
                max(0, min(255, int(CORE[1] * k) + n)),
                max(0, min(255, int(CORE[2] * k) + n)),
            )

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("готово ->", OUT, img.size)


if __name__ == "__main__":
    main()
