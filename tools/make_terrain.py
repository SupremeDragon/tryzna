"""Робить із однієї плитки АТЛАС ПЕРЕХОДІВ на 16 клітин.

Навіщо. Якщо просто класти квадрат стежки на квадрат трави, вийде стежка з
прямих квадратів — саме те, через що тайлсет виглядає складеним із кубиків.
Потрібно, щоб клітинка знала СУСІДІВ: там, де поруч така сама стежка, вона
доходить до краю впритул; там, де поруч трава, — заокруглюється й розчиняється.

Комбінацій сусідів рівно шістнадцять (північ, схід, південь, захід — є або
немає), тому атлас 4x4. Номер клітини = бітова маска сусідів:
    1 — північ, 2 — схід, 4 — південь, 8 — захід.

Прозорість запікається в саму картинку. Godot тоді малює звичайний
draw_texture_rect_region, без жодного шейдера, а вся складність лишається тут.

    python tools/make_terrain.py game/art/plyn/dirt_a.png \
        game/art/plyn/terrain_dirt.png
"""
import argparse
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def build_mask(n: int, links: int, inset: float, radius: float, blur: float):
    """Маска однієї клітини для заданого набору сусідів."""
    # Малюємо у збільшеному масштабі й зменшуємо: інакше заокруглення рвані.
    scale = 4
    big = n * scale
    m = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(m)

    pad = int(inset * big)
    r = int(radius * big)
    d.rounded_rectangle([pad, pad, big - pad, big - pad], radius=r, fill=255)

    # Там, де поруч така сама земля, клітинка доростає до краю — інакше на
    # кожному стику лишалася б перетяжка, і стежка виглядала б як ланцюг
    # окремих плям, а не як стежка.
    if links & 1:   # північ
        d.rectangle([pad, 0, big - pad, pad + r], fill=255)
    if links & 2:   # схід
        d.rectangle([big - pad - r, pad, big, big - pad], fill=255)
    if links & 4:   # південь
        d.rectangle([pad, big - pad - r, big - pad, big], fill=255)
    if links & 8:   # захід
        d.rectangle([0, pad, pad + r, big - pad], fill=255)

    m = m.resize((n, n), Image.LANCZOS)
    if blur > 0.0:
        m = m.filter(ImageFilter.GaussianBlur(blur))
    return m


def main() -> None:
    ap = argparse.ArgumentParser(description="Атлас переходів для однієї землі")
    ap.add_argument("src", help="безшовна плитка")
    ap.add_argument("dst", help="куди покласти атлас 4x4")
    ap.add_argument("--inset", type=float, default=0.10,
                    help="наскільки клітинка не доходить до краю без сусіда")
    ap.add_argument("--radius", type=float, default=0.30)
    ap.add_argument("--blur", type=float, default=2.2)
    args = ap.parse_args()

    src = args.src if os.path.isabs(args.src) else os.path.join(ROOT, args.src)
    dst = args.dst if os.path.isabs(args.dst) else os.path.join(ROOT, args.dst)

    tile = Image.open(src).convert("RGBA")
    n = tile.width
    atlas = Image.new("RGBA", (n * 4, n * 4), (0, 0, 0, 0))

    for links in range(16):
        cell = tile.copy()
        cell.putalpha(build_mask(n, links, args.inset, args.radius, args.blur))
        atlas.paste(cell, ((links % 4) * n, (links // 4) * n))

    os.makedirs(os.path.dirname(dst), exist_ok=True)
    atlas.save(dst)
    print("атлас -> %s %s (клітина %d)" % (dst, atlas.size, n))


if __name__ == "__main__":
    main()
