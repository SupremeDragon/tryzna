"""Складає кілька картинок в один аркуш, щоб дивитися їх разом.

Коли генерацій чотири-вісім, відкривати їх по одній — це втрачати саме те,
заради чого їх кілька: порівняння. Аркуш ставить їх поруч і підписує
номерами, щоб можна було сказати «третя» й обидва розуміли, про яку мова.

    python tools/sheet.py art_src/raw/2026-09-04/nyts-far-*.png
    python tools/sheet.py <файли> --out builds/sheet.png --cols 2 --width 1400
"""
import argparse
import glob
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

PAD = 10
LABEL = 26
BG = (24, 24, 26)
INK = (215, 215, 220)


def main() -> None:
    ap = argparse.ArgumentParser(description="Аркуш порівняння генерацій")
    ap.add_argument("patterns", nargs="+", help="файли або маски")
    ap.add_argument("--out", default=os.path.join(ROOT, "builds", "sheet.png"))
    ap.add_argument("--cols", type=int, default=2)
    ap.add_argument("--width", type=int, default=1400, help="ширина всього аркуша")
    args = ap.parse_args()

    paths: list[str] = []
    for pattern in args.patterns:
        paths.extend(sorted(glob.glob(pattern)) or [pattern])
    paths = [p for p in paths if os.path.isfile(p)]
    if not paths:
        raise SystemExit("Нічого не знайдено.")

    cols = min(args.cols, len(paths))
    rows = (len(paths) + cols - 1) // cols
    cell_w = (args.width - PAD * (cols + 1)) // cols

    images = [Image.open(p).convert("RGB") for p in paths]
    # Висота комірки — по найвищій картинці, щоб рядки не «їздили».
    cell_h = max(int(im.height * cell_w / im.width) for im in images)

    sheet = Image.new(
        "RGB",
        (args.width, PAD + rows * (cell_h + LABEL + PAD)),
        BG,
    )
    draw = ImageDraw.Draw(sheet)

    for i, (path, im) in enumerate(zip(paths, images)):
        col, row = i % cols, i // cols
        x = PAD + col * (cell_w + PAD)
        y = PAD + row * (cell_h + LABEL + PAD)
        thumb = im.resize((cell_w, int(im.height * cell_w / im.width)), Image.LANCZOS)
        sheet.paste(thumb, (x, y))
        draw.text(
            (x + 4, y + thumb.height + 5),
            "%d.  %s" % (i + 1, os.path.basename(path)),
            fill=INK,
        )

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    sheet.save(args.out)
    print("аркуш ->", args.out, sheet.size)


if __name__ == "__main__":
    main()
