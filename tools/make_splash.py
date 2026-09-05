"""Малює екран запуску — те, що видно, поки рушій ще вантажиться.

Це не те саме, що «Поріг» між меню й грою. Поріг малює сама гра, а цей екран
показує Godot ЩЕ ДО того, як гра почала існувати: жодного коду тут виконати
неможливо, тому він мусить бути звичайною картинкою.

Тому й малюємо його кодом наперед — щоб він був у тій самій темряві з тією
самою загравою, що й меню, і перехід між ними не читався як зміна гри.

    python tools/make_splash.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "art", "splash.png")

WIDTH, HEIGHT = 1280, 720
BACK = (14, 13, 16)
EMBER = (200, 72, 52)
INK = (240, 236, 228)

# Шрифти, у яких точно є кирилиця. Перший знайдений і беремо.
FONTS = [
    r"C:\Windows\Fonts\segoeuib.ttf",
    r"C:\Windows\Fonts\arialbd.ttf",
    r"C:\Windows\Fonts\calibrib.ttf",
    r"C:\Windows\Fonts\segoeui.ttf",
    r"C:\Windows\Fonts\arial.ttf",
]


def pick_font(size: int):
    for path in FONTS:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def main() -> None:
    img = Image.new("RGB", (WIDTH, HEIGHT), BACK)
    px = img.load()

    # Заграва знизу — та сама, що в меню. Рахуємо попіксельно: картинка
    # робиться раз, тож швидкість тут не має значення, а кілець немає.
    cx, cy = WIDTH * 0.5, HEIGHT * 0.86
    radius = HEIGHT * 0.72
    for y in range(HEIGHT):
        for x in range(WIDTH):
            d = math.dist((x, y), (cx, cy)) / radius
            if d >= 1.0:
                continue
            k = (1.0 - d) ** 2.2 * 0.42
            r, g, b = px[x, y]
            px[x, y] = (
                min(int(r + EMBER[0] * k), 255),
                min(int(g + EMBER[1] * k), 255),
                min(int(b + EMBER[2] * k), 255),
            )

    d = ImageDraw.Draw(img)
    font = pick_font(96)
    text = "ТРИЗНА"
    box = d.textbbox((0, 0), text, font=font)
    tx = (WIDTH - (box[2] - box[0])) // 2 - box[0]
    ty = int(HEIGHT * 0.40) - box[1]

    # Тепла обводка замість тіні: назва має світитися, а не лежати на папері.
    for dx in range(-3, 4):
        for dy in range(-3, 4):
            if dx * dx + dy * dy > 9:
                continue
            d.text((tx + dx, ty + dy), text, font=font, fill=(90, 26, 18))
    d.text((tx, ty), text, font=font, fill=INK)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT)
    print("екран запуску ->", OUT, img.size)


if __name__ == "__main__":
    main()
