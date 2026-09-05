"""Ріже аркуш тайлсету на окремі клітинки.

Аркуш приходить однією картинкою з намальованою сіткою. Щоб ним користуватися,
його треба розібрати: кожна клітинка — окремий файл, який рушій вантажить як
плитку або як спрайт.

Крок сітки й початок задаються явно, а не вгадуються: у намальованих аркушах
лінії сітки самі по собі темні пікселі, і автоматичний пошук плутає їх із
деревами. Простіше подивитися один раз і записати числа.

    python tools/slice_tileset.py art_src/approved/tileset.jpeg \\
        art_src/tiles --step 102.4 --origin 102 204 --cols 18 --rows 16
    python tools/slice_tileset.py ... --sheet   (підписаний оглядовий аркуш)
"""
import argparse
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def cell_box(ox: float, oy: float, step: float, col: int, row: int, inset: int):
    x0 = ox + col * step
    y0 = oy + row * step
    return (
        int(round(x0)) + inset,
        int(round(y0)) + inset,
        int(round(x0 + step)) - inset,
        int(round(y0 + step)) - inset,
    )


def main() -> None:
    ap = argparse.ArgumentParser(description="Нарізати аркуш тайлсету")
    ap.add_argument("src")
    ap.add_argument("dst", help="тека для клітинок")
    ap.add_argument("--step", type=float, default=102.4)
    ap.add_argument("--origin", nargs=2, type=float, default=[102.0, 204.0])
    ap.add_argument("--cols", type=int, default=18)
    ap.add_argument("--rows", type=int, default=16)
    ap.add_argument(
        "--inset", type=int, default=2,
        help="скільки пікселів зрізати з кожного боку, щоб прибрати лінію сітки",
    )
    ap.add_argument("--size", type=int, default=0, help="привести клітинку до розміру")
    ap.add_argument("--sheet", action="store_true", help="лише оглядовий аркуш")
    args = ap.parse_args()

    src = args.src if os.path.isabs(args.src) else os.path.join(ROOT, args.src)
    dst = args.dst if os.path.isabs(args.dst) else os.path.join(ROOT, args.dst)
    img = Image.open(src).convert("RGB")
    ox, oy = args.origin

    if args.sheet:
        # Оглядовий аркуш із номерами: рядок-стовпець на кожній клітинці.
        # Без нього неможливо сказати «візьми клітинку 4-11», а без цього
        # неможливо описати, з чого складається карта.
        scale = 3
        small = img.resize((img.width // scale, img.height // scale), Image.LANCZOS)
        d = ImageDraw.Draw(small)
        for row in range(args.rows):
            for col in range(args.cols):
                x0, y0, x1, y1 = cell_box(ox, oy, args.step, col, row, 0)
                d.rectangle(
                    [x0 // scale, y0 // scale, x1 // scale, y1 // scale],
                    outline=(255, 40, 40),
                )
                d.text(
                    (x0 // scale + 2, y0 // scale + 1),
                    "%d-%d" % (row, col), fill=(255, 255, 0),
                )
        out = os.path.join(ROOT, "builds", "tileset-map.png")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        small.save(out)
        print("оглядовий аркуш ->", out, small.size)
        return

    os.makedirs(dst, exist_ok=True)
    made = 0
    for row in range(args.rows):
        for col in range(args.cols):
            cell = img.crop(cell_box(ox, oy, args.step, col, row, args.inset))
            if args.size:
                cell = cell.resize((args.size, args.size), Image.LANCZOS)
            cell.save(os.path.join(dst, "c_%02d_%02d.png" % (row, col)))
            made += 1
    print("нарізано %d клітинок -> %s" % (made, dst))


if __name__ == "__main__":
    main()
