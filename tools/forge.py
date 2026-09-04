"""Генерація арту через Forge, який крутиться на іншій машині.

Forge має HTTP-API. Це означає, що не треба ходити в браузер, набирати
проміт руками й перекладати файли між теками: генерація стає такою самою
командою, як тест чи збірка.

Головне, заради чого цей файл існує: **замок стилю виконується кодом**.
У `art_src/STYLE_PROMPT.txt` записано, що хвіст стилю додається до КОЖНОЇ
генерації без винятку. Поки це робилося руками, забути його було питанням
часу. Тепер забути неможливо — проміт складається за §5 замка тут, а я
описую тільки зміст.

Приклади:

    python tools/forge.py --list
    python tools/forge.py nyts-far
    python tools/forge.py nyts-far --count 6 --seed 1000
    python tools/forge.py --subject "a clay jug on a table" \
        --world plyn --light object --name jug

Результат лягає в `art_src/raw/<дата>/`. Ця тека поза git навмисно:
сирі генерації важкі й одноразові, у репозиторій іде тільки відібране.
"""
import argparse
import base64
import datetime
import json
import os
import sys
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "art_src", "raw")

# Машина з відеокартою. Forge має бути запущений з `--api --listen`,
# інакше він слухає тільки сам себе й ззовні недоступний.
HOST = os.environ.get("TRYZNA_FORGE", "http://smd:7860")


# --- Замок стилю (art_src/STYLE_PROMPT.txt) ----------------------------------
# Дослівно з файлу. Якщо міняється там — міняється тут, і навпаки; розходження
# двох копій гірше за відсутність однієї.

STYLE_TAIL = (
    "painterly digital illustration, hand-painted texture, visible brush strokes, "
    "soft edges, no hard outlines, muted desaturated palette, subtle film grain, "
    "clean readable silhouette"
)

NEGATIVE = (
    "anime, manga, 3D render, CGI, photorealistic, neon colours, "
    "glossy plastic surfaces, hard black outlines, cel shading, lens flare, "
    "text, letters, watermark, signature, logo, UI elements, modern objects, "
    # Люди пролазять навіть у порожні печери — модель любить ставити фігурку
    # «для масштабу». Нам вона зайва: у кадрі має бути тільки гравець.
    "person, people, human figure, silhouette of a man, character, creature, "
    # DreamShaper любить лишати незафарбований папір по краях і виходить
    # «мазок на аркуші», а не кадр. Міша це вже забракував, тож глушимо.
    "white border, paper texture, sketchbook page, unpainted margin, "
    "canvas edge, framed picture, vignette, torn paper"
)

PALETTE = {
    "plyn": (
        "muted earth palette: moss green, ochre, weathered grey stone, "
        "faded warm timber; damp autumn, lived-in, quiet"
    ),
    "nyts": (
        "near-monochrome: charcoal, ash grey, soot black; "
        "exactly one accent colour, dull dried-blood red; "
        "airless, still, flat, like a shadow theatre"
    ),
    "vysi": (
        "aged parchment and pale gold, brown ink linework, "
        "surrounded by flat void black; like an old drawn map"
    ),
}

# §3 замка: об'єкти світить рушій, тому на картинці світло пласке;
# дальні фони рушій майже не чіпає, тому світло можна запікати.
LIGHT = {
    "object": (
        "flat even ambient lighting, no cast shadows, no rim light, "
        "no strong highlights, isolated on a plain flat background"
    ),
    "backdrop": "soft diffuse light source, gentle atmospheric haze",
}


def compose(subject: str, world: str, light: str) -> str:
    """Складає проміт за §5 замка: спершу зміст, потім стиль.

    Порядок не косметичний: генератор важить перші слова більше за останні,
    тому зміст мусить іти першим, інакше вийде красивий стиль ні про що.
    """
    return ", ".join([subject, PALETTE[world], LIGHT[light], STYLE_TAIL])


# --- Замовлення --------------------------------------------------------------
# Іменовані завдання. Тримаються тут, а не в голові, щоб генерацію можна було
# ПОВТОРИТИ через місяць і отримати те саме.

JOBS: dict[str, dict] = {
    # Найдальший шар Ниці. Головне про нього: власної перспективи він мати
    # НЕ повинен. Глибину в кадрі дають стовпи, що стоять попереду; якщо
    # задник теж почне тікати в точку сходу, два ракурси битимуться.
    # Тому — далека стіна темряви й заграва, а не тунель.
    "nyts-far": {
        "subject": (
            "a vast wall of darkness deep underground, distant cavern far away, "
            "distant fires deep in the centre far away, dull red glow on black rock, "
            "an enormous underground hall, flat frontal view, "
            "no tunnel, no vanishing point, no perspective lines, "
            "wide horizontal composition, image fills the entire frame edge to edge"
        ),
        "world": "nyts",
        "light": "backdrop",
        "size": (1024, 448),
        "cfg": 6.0,
        "steps": 30,
        # «Заграва» дуже легко читається як лава: варто сказати red glow —
        # і DreamShaper малює вулкан. Наш червоний — засохлої крові, холодний
        # і мертвий, тож вогонь глушимо окремо, саме для цього замовлення.
        # Коротко і прицільно. Довгий негатив SD1.5 не витримує: він починає
        # воювати з промітом і вигадувати сюжети замість пейзажу. Гасимо рівно
        # дві помилки — лаву й відкрите небо, решту витягне тонування в рушії.
        "extra_negative": "lava river, molten liquid, volcano, open sky, animal, face",
    },
}


# --- Розмова з Forge ---------------------------------------------------------


def _post(path: str, payload: dict, timeout: int = 900) -> dict:
    req = urllib.request.Request(
        HOST + path,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def generate(
    subject: str,
    world: str,
    light: str,
    name: str,
    count: int = 4,
    size: tuple[int, int] = (768, 512),
    steps: int = 28,
    cfg: float = 6.0,
    seed: int = -1,
    extra_negative: str = "",
) -> list[str]:
    prompt = compose(subject, world, light)
    print("проміт:\n  " + prompt.replace(", ", ",\n  "))
    print()

    payload = {
        "prompt": prompt,
        "negative_prompt": NEGATIVE + (", " + extra_negative if extra_negative else ""),
        "width": size[0],
        "height": size[1],
        "steps": steps,
        "cfg_scale": cfg,
        "sampler_name": "DPM++ 2M",
        "scheduler": "Karras",
        "batch_size": 1,
        "n_iter": count,
        "seed": seed,
    }

    out_dir = os.path.join(RAW, datetime.date.today().isoformat())
    os.makedirs(out_dir, exist_ok=True)

    print("генерую %d шт. %dx%d на %s…" % (count, size[0], size[1], HOST))
    try:
        result = _post("/sdapi/v1/txt2img", payload)
    except urllib.error.URLError as exc:
        sys.exit(
            "Forge не відповів (%s).\n"
            "Перевір, що він запущений з --api --listen і що адреса %s правильна."
            % (exc, HOST)
        )

    # Forge кладе сюди справжні параметри генерації, зокрема РОЗГОРНУТІ сіди.
    # Без них повторити вдалу картинку неможливо, тому пишемо їх поруч.
    info = json.loads(result.get("info", "{}"))
    seeds = info.get("all_seeds") or [info.get("seed", -1)]

    saved: list[str] = []
    for i, b64 in enumerate(result["images"][:count]):
        s = seeds[i] if i < len(seeds) else -1
        path = os.path.join(out_dir, "%s-%02d-s%s.png" % (name, i + 1, s))
        with open(path, "wb") as fh:
            fh.write(base64.b64decode(b64.split(",", 1)[-1]))
        saved.append(path)
        print("  " + path)

    with open(os.path.join(out_dir, name + ".txt"), "w", encoding="utf-8") as fh:
        fh.write(prompt + "\n\n--- не хочемо ---\n" + payload["negative_prompt"] + "\n\n")
        fh.write("сіди: %s\n" % seeds[:count])

    return saved


def upscale(path: str, scale: float = 2.0, model: str = "R-ESRGAN 4x+") -> str:
    """Збільшує готову картинку тим самим Forge.

    Потрібне тому, що SD1.5 добре малює приблизно до 1024 пікселів, а шари
    фону в нас ширші. Домальовувати різницю генерацією ризиковано — на 6 ГБ
    відеопамʼяті великий кадр просто не влізе, — а нейромережевий апскейл
    робить це окремим дешевим проходом.
    """
    with open(path, "rb") as fh:
        data = base64.b64encode(fh.read()).decode("ascii")

    result = _post(
        "/sdapi/v1/extra-single-image",
        {
            "image": data,
            "upscaling_resize": scale,
            "upscaler_1": model,
            "resize_mode": 0,
        },
    )

    root, ext = os.path.splitext(path)
    out = "%s-x%g%s" % (root, scale, ext)
    with open(out, "wb") as fh:
        fh.write(base64.b64decode(result["image"].split(",", 1)[-1]))
    print("збільшено ->", out)
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description="Генерація арту «Тризни» через Forge")
    ap.add_argument("job", nargs="?", help="назва замовлення з JOBS")
    ap.add_argument("--list", action="store_true", help="показати замовлення")
    ap.add_argument("--subject", help="зміст картинки (замість замовлення)")
    ap.add_argument("--world", choices=sorted(PALETTE), default="nyts")
    ap.add_argument("--light", choices=sorted(LIGHT), default="backdrop")
    ap.add_argument("--name", help="як назвати файли")
    ap.add_argument("--count", type=int, default=4)
    ap.add_argument("--size", help="ШИРИНАxВИСОТА, напр. 896x512")
    ap.add_argument("--steps", type=int)
    ap.add_argument("--cfg", type=float)
    ap.add_argument("--seed", type=int, default=-1)
    ap.add_argument("--upscale", metavar="ФАЙЛ", help="збільшити готову картинку")
    ap.add_argument("--scale", type=float, default=2.0)
    args = ap.parse_args()

    if args.upscale:
        upscale(args.upscale, args.scale)
        return

    if args.list:
        for key, job in sorted(JOBS.items()):
            print("%-14s %s…" % (key, job["subject"][:60]))
        return

    if args.job:
        if args.job not in JOBS:
            sys.exit("Немає такого замовлення: %s (--list покаже наявні)" % args.job)
        job = dict(JOBS[args.job])
        job.setdefault("name", args.job)
    elif args.subject:
        job = {
            "subject": args.subject,
            "world": args.world,
            "light": args.light,
            "name": args.name or "adhoc",
        }
    else:
        sys.exit("Треба або назву замовлення, або --subject. --list покаже наявні.")

    if args.size:
        w, h = args.size.lower().split("x")
        job["size"] = (int(w), int(h))
    for key in ("steps", "cfg"):
        if getattr(args, key) is not None:
            job[key] = getattr(args, key)

    generate(count=args.count, seed=args.seed, **job)


if __name__ == "__main__":
    main()
