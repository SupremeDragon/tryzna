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
    # УВАГА: тут НЕ МОЖНА писати «silhouette of a man». SD важить кожне слово
    # окремо, і слово «silhouette» глушило силуети взагалі — а саме силует нам
    # і потрібен від кожного шару фону. Через це замість гребеня пагорбів
    # виходив туман. Людей проганяємо словами, які значать тільки людей.
    "person, people, human figure, man, woman, character, creature, "
    # DreamShaper любить лишати незафарбований папір по краях і виходить
    # «мазок на аркуші», а не кадр. Міша це вже забракував, тож глушимо.
    "white border, paper texture, sketchbook page, unpainted margin, "
    "canvas edge, framed picture, vignette, torn paper"
)

# --- ДРУГИЙ СТИЛЬ: «ЯСНИЙ» ----------------------------------------------------
# Міша показав референс і сказав прямо, що наш приглушений осінній стиль йому
# не подобається, а цей — подобається. Це його гра, тож Плинь переходить на
# нього. Старий замок нікуди не дівається: Ниць і Висі лишаються на ньому,
# і саме тому стиль тут ПАРАМЕТР, а не заміна.
BRIGHT_TAIL = (
    "vibrant stylized top down game art, cozy fantasy village, "
    "clean bold shapes, soft cel shading, saturated cheerful colours, "
    "crisp readable silhouette, warm sunlight, high contrast"
)

BRIGHT_NEGATIVE = (
    "photorealistic, photo, realistic texture, muted, desaturated, grim, dark, "
    "gloomy, fog, haze, blurry, noisy, grainy, 3D render, sketch, "
    "text, letters, watermark, signature, "
    "person, people, human figure, man, woman, character, "
    "white border, paper texture, unpainted margin, canvas edge, vignette"
)

PALETTE = {
    "bright": (
        "lush saturated green grass, warm sandy paths, "
        "rich brown timber and terracotta roofs, clear blue water"
    ),
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


# Хвіст для ОКРЕМИХ ПРЕДМЕТІВ. Теж окремий, і з тієї ж причини: слово «село»
# у хвості сцен змушує модель домальовувати навколо предмета ціле поселення.
# Просив одне дерево — діставав ізометричну діораму з хатами.
# Тло — ЯСКРАВО-РОЖЕВЕ, і це не примха. Вирізка знімає те, що схоже кольором
# на тло; коли тло зелене, разом із ним гине зелене листя й зелені стіни. У
# першої хати так лишився самий дах. Рожевого в наших предметах немає ніде,
# тому поріг можна ставити впевнено, а не компромісно.
PROP_TAIL = (
    "single game asset, one object only, clean cel shaded cartoon style, "
    "saturated colours, crisp readable silhouette, even lighting, "
    "cut out on a solid flat bright magenta pink background, "
    "nothing under the object, no ground, no grass, no scene, no landscape"
)

# Хвіст для ПЛИТОК. Окремий від хвоста сцен навмисно: слова «затишне село»
# змушують модель малювати краєвид, а плитці потрібне протилежне — рівна
# поверхня без глибини, без тіней і без композиції.
TILE_TAIL = (
    "flat seamless game texture, top down orthographic, clean cel shading, "
    "saturated colours, even lighting, no shadows, no depth, no composition, "
    "fills the entire square uniformly"
)


def compose(subject: str, world: str, light: str, tail: str = "") -> str:
    """Складає проміт за §5 замка: спершу зміст, потім стиль.

    Порядок не косметичний: генератор важить перші слова більше за останні,
    тому зміст мусить іти першим, інакше вийде красивий стиль ні про що.
    """
    if tail == "":
        tail = BRIGHT_TAIL if world == "bright" else STYLE_TAIL
    return ", ".join([subject, PALETTE[world], LIGHT[light], tail])


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
    # Колонада Ниці. Перша спроба провалилася повчально: слова
    # «isolated on a plain flat background» дали КАТАЛОГ ТОВАРІВ — коротенькі
    # тумби з тінями на підлозі, кожна окремо посеред кадру. Для шару фону
    # треба протилежне: колони, обрізані рамкою згори й знизу, і темрява
    # між ними. Тло тут не світле, а чорне — і вирізається саме воно.
    "nyts-pillars": {
        "subject": (
            "massive rough stone columns filling the whole image from top to bottom, "
            "cropped by the frame above and below, only the middle of the shafts, "
            "worn dark grey rock, standing far apart with wide gaps, "
            "pure black empty darkness between and behind the columns, "
            "nothing else in the image, no floor, no ceiling"
        ),
        "world": "nyts",
        "light": "backdrop",
        "size": (1024, 448),
        "cfg": 6.5,
        "steps": 30,
        "extra_negative": (
            "full column, capital, base, pedestal, statue, ornament, "
            "greek temple, marble, cast shadow, floor, ground, product photo, "
            "row of objects, small objects, arch, perspective, vanishing point"
        ),
    },
    # Підлога Ниці. Це сайд-скрол, тож підлога — широка смуга внизу кадру,
    # яку видно під невеликим кутом. Головне не дати моделі намалювати
    # кімнату: потрібна САМА поверхня, від краю до краю.
    "nyts-floor": {
        "subject": (
            "a texture of worn cracked dark stone slabs seen from directly above, "
            "flat paving of an ancient hall, grey dust in the joints, "
            "fills the whole frame evenly, no objects on it, no light source, "
            "no walls, no horizon, no sky, no perspective"
        ),
        "world": "nyts",
        "light": "backdrop",
        "size": (1024, 384),
        "cfg": 6.0,
        "steps": 30,
        "extra_negative": (
            "red, blood, moss, landscape, rocks, boulders, hill, fog bank"
        ),
    },
    # ПЛИНЬ. Світ смертних, і саме в ньому відбувається весь Акт I — а фон
    # там досі процедурні смуги. Найдальший шар: пагорби Тихої Балки.
    # Пагорби Плині. Перша спроба дала шість туманних лугів без жодного
    # силуету: слова про серпанок зʼїли форму. Для паралаксу потрібне
    # протилежне — ЧІТКИЙ ГРЕБІНЬ на світлому небі, який ріжеться в
    # прозорість і кладеться шарами, як колони в Ниці.
    "plyn-hills": {
        "subject": (
            "a distant range of low rounded hills along the bottom edge of the image, "
            "dark grey-green hill shapes against the sky, one clean horizon line, "
            "the entire upper two thirds is empty flat pale overcast sky, "
            "nothing in the sky, seen from very far away, damp autumn, "
            "wide horizontal composition"
        ),
        "world": "plyn",
        "light": "backdrop",
        "size": (1024, 384),
        "cfg": 6.5,
        "steps": 30,
        "extra_negative": (
            "forest, trees close up, tree trunks, branches, leaves, "
            "mountains, snow, sunset, dramatic clouds, road, fence, buildings, "
            "foreground grass, field in front, water, reflection, birds"
        ),
    },
    # Дрібнота Плині: дерева, кущі, каміння. Тут та сама «помилка», через яку
    # завалився шар фону, працює НА КОРИСТЬ: слова «isolated on a plain flat
    # background» дають каталог окремих предметів на рівному тлі — і саме це
    # потрібно пропсам, які потім вирізаються в прозорість.
    "plyn-tree": {
        "subject": (
            "one bare autumn birch tree, slender white trunk, thin dark branches, "
            "almost no leaves, whole tree from root to top, seen from slightly above, "
            "on a solid bright magenta background"
        ),
        "world": "plyn",
        "light": "object",
        "size": (448, 704),
        "cfg": 6.5,
        "steps": 30,
        "extra_negative": "forest, many trees, sky, horizon, buildings, path, snow",
    },
    "plyn-bush": {
        "subject": (
            "one low dry autumn shrub with a few grey rocks at its base, "
            "small clump of dead grass, seen from slightly above, "
            "on a solid bright magenta background"
        ),
        "world": "plyn",
        "light": "object",
        "size": (512, 384),
        "cfg": 6.5,
        "steps": 28,
        "extra_negative": "tree, forest, flowers, sky, horizon, buildings, path",
    },
    # Хати Плині ОКРЕМИМИ ПРЕДМЕТАМИ. Спершу вони вирізалися з цілого кадру
    # разом із клаптем тамтешньої трави — і виходили напівпрозорі мазки зі
    # світлим прямокутником навколо. Для смуги фону вирізка з кадру правильна,
    # для предмета, що стоїть на землі, — ні: йому потрібне рівне тло, з якого
    # він знімається начисто (tools/key_flat.py).
    "plyn-hut": {
        "subject": (
            "one small old log cabin with a steep thatched roof, "
            "weathered grey timber walls, low doorway, one tiny window, "
            "the whole building from ground to ridge, seen from high above "
            "at a three quarter angle, standing alone on a plain flat mid grey "
            "background"
        ),
        "world": "plyn",
        "light": "object",
        "size": (576, 512),
        "cfg": 6.5,
        "steps": 30,
        "extra_negative": (
            "village, other buildings, trees, fence, road, sky, horizon, "
            "grass field, landscape, snow, stone castle, brick"
        ),
    },
    "plyn-barn": {
        "subject": (
            "one long low wooden barn with a shingled roof and wide plank doors, "
            "dark weathered timber, the whole building from ground to ridge, "
            "seen from high above at a three quarter angle, "
            "on a solid bright magenta background"
        ),
        "world": "plyn",
        "light": "object",
        "size": (640, 448),
        "cfg": 6.5,
        "steps": 30,
        "extra_negative": (
            "village, other buildings, trees, fence, road, sky, horizon, "
            "grass field, landscape, snow, brick, modern"
        ),
    },
    # --- НАБІР У ЯСНОМУ СТИЛІ (референс Міші) ---------------------------------
    # Ціла карта згори. Модель добре малює СЦЕНУ й погано — текстуру, тож
    # замість боротьби з нею беремо те, що вона вміє, і розбираємо на частини:
    # плитки трави й піску, дерева, хати, грядки. Заразом усе виходить з
    # одного кадру, а отже в одному освітленні й одній палітрі.
    "b-scene": {
        "subject": (
            "top down view of a small fantasy village map, bright green lawns, "
            "winding pale sandy paths crossing the map, round leafy trees and "
            "dark conifers, small houses with red tiled roofs, tilled vegetable "
            "garden plots, wooden fences, a blue stream with a small wooden "
            "bridge, camera directly overhead looking straight down"
        ),
        "world": "bright", "light": "backdrop", "size": (768, 512),
        "cfg": 7.0, "steps": 32,
        "extra_negative": "horizon, sky, clouds, side view, mountains, sea",
    },
    "b-grass": {
        "tail": TILE_TAIL,
        "subject": (
            "flat lawn of bright green grass filling the entire image, "
            "tiny scattered white daisies, cartoon game ground texture, "
            "camera straight overhead, no horizon, no objects, no path"
        ),
        "world": "bright", "light": "backdrop", "size": (512, 512),
        "cfg": 6.5, "steps": 28,
        "extra_negative": "horizon, sky, tree, building, path, road, water",
    },
    "b-path": {
        "tail": TILE_TAIL,
        "subject": (
            "flat pale sandy dirt ground filling the entire image, "
            "warm cream coloured packed sand with tiny pebbles, "
            "cartoon game ground texture, camera straight overhead, "
            "no horizon, no objects, no grass"
        ),
        "world": "bright", "light": "backdrop", "size": (512, 512),
        "cfg": 6.5, "steps": 28,
        "extra_negative": "horizon, sky, tree, building, grass, water, road edges",
    },
    "b-soil": {
        "tail": TILE_TAIL,
        "subject": (
            "flat vegetable garden bed filling the entire image, dark brown "
            "tilled soil in neat rows with small red and green plants, "
            "cartoon game ground texture, camera straight overhead, no horizon"
        ),
        "world": "bright", "light": "backdrop", "size": (512, 512),
        "cfg": 6.5, "steps": 28,
        "extra_negative": "horizon, sky, tree, building, fence, path",
    },
    "b-water": {
        "tail": TILE_TAIL,
        "subject": (
            "flat clear blue river water filling the entire image, gentle "
            "ripples and light reflections, cartoon game water texture, "
            "camera straight overhead, no horizon, no banks, no objects"
        ),
        "world": "bright", "light": "backdrop", "size": (512, 512),
        "cfg": 6.5, "steps": 28,
        "extra_negative": "horizon, sky, shore, grass, boat, waterfall, foam",
    },
    "b-tree": {
        "tail": PROP_TAIL,
        "subject": (
            "one simple small round tree, a single ball of bright green leaves "
            "on a short straight brown trunk, no roots showing, nothing under "
            "it, seen from high above at a slight angle, "
            "on a solid bright magenta background"
        ),
        "world": "bright", "light": "object", "size": (512, 512),
        "cfg": 6.5, "steps": 30,
        "extra_negative": (
            "forest, many trees, grass, ground, soil, platform, pedestal, "
            "stone ring, fence, roots, shadow, horizon, sky, autumn, ornate"
        ),
    },
    "b-pine": {
        "tail": PROP_TAIL,
        "subject": (
            "one simple dark green fir tree, a narrow cone of needles with a "
            "pointed top and a short trunk, nothing under it, seen from high "
            "above at a slight angle, "
            "on a solid bright magenta background"
        ),
        "world": "bright", "light": "object", "size": (448, 640),
        "cfg": 6.5, "steps": 30,
        "extra_negative": (
            "forest, many trees, grass, ground, soil, platform, snow, shadow, "
            "horizon, sky, clouds, mountains, sand"
        ),
    },
    "b-house": {
        "tail": PROP_TAIL,
        "subject": (
            "one cosy half timbered cottage with a steep terracotta red tiled "
            "roof, cream plaster walls and dark wooden beams, a small chimney, "
            "seen from high above at a three quarter angle, whole building, "
            "on a solid bright magenta background"
        ),
        "world": "bright", "light": "object", "size": (576, 512),
        "cfg": 6.5, "steps": 30,
        "extra_negative": "village, other buildings, trees, grass, ground, street, horizon",
    },
    # --- ТАЙЛСЕТ ПЛИНІ -------------------------------------------------------
    # Земля тепер не одна картинка на весь світ, а КЛІТИНКИ. Тайл мусить бути
    # знятий СТРОГО ЗВЕРХУ й без жодної тіні: тінь усередині тайла повторюється
    # разом із ним і одразу видає сітку. З тієї ж причини — «no objects»:
    # камінь у тайлі стане камінням через кожні два метри.
    "tile-grass": {
        "subject": (
            "extreme close up of thick meadow grass, dense blades and moss, "
            "wisps of dry yellow straw, camera directly overhead one metre "
            "away, the grass fills the entire frame, hand painted texture, "
            "no flowers, no bushes, no path, no horizon, no distance"
        ),
        "world": "plyn",
        "light": "backdrop",
        "size": (512, 512),
        "cfg": 6.5,
        "steps": 30,
        "extra_negative": "perspective, horizon, sky, tree, building, person, vignette",
    },
    "tile-dirt": {
        "subject": (
            "extreme close up of bare packed earth ground, brown soil with "
            "small pebbles and dry clods, camera directly overhead one metre "
            "away, the ground fills the entire frame, hand painted texture, "
            "no path, no road, no horizon, no distance"
        ),
        "world": "plyn",
        "light": "backdrop",
        "size": (512, 512),
        "cfg": 6.5,
        "steps": 30,
        "extra_negative": "perspective, horizon, sky, tree, building, person, vignette",
    },
    "tile-field": {
        "subject": (
            "top down view of a ploughed vegetable bed, dark brown soil in "
            "straight parallel furrows with small green sprouts in rows, "
            "hand painted texture, seen straight from above, fills the whole "
            "square evenly, no horizon"
        ),
        "world": "plyn",
        "light": "backdrop",
        "size": (512, 512),
        "cfg": 6.5,
        "steps": 30,
        "extra_negative": "perspective, horizon, sky, tree, building, person, vignette",
    },
    "tile-stone": {
        "subject": (
            "top down view of old cobblestone paving, rounded grey field "
            "stones set in earth with moss in the joints, hand painted "
            "texture, seen straight from above, fills the whole square "
            "evenly, no horizon"
        ),
        "world": "plyn",
        "light": "backdrop",
        "size": (512, 512),
        "cfg": 6.5,
        "steps": 30,
        "extra_negative": "perspective, horizon, sky, tree, building, person, vignette",
    },
    # Каплиця Тихої Балки. Єдина будівля села, якої немає на затвердженому
    # кадрі, тому її доводиться генерувати, а не вирізати. Режим «object»:
    # її світитиме рушій, і на самій картинці тіней бути не повинно.
    "plyn-chapel": {
        "subject": (
            "one small old wooden chapel with a tall shingled bell tower, "
            "dark weathered timber, steep roof, seen from a high three quarter view, "
            "standing alone on plain flat pale grey background"
        ),
        "world": "plyn",
        "light": "object",
        "size": (512, 704),
        "cfg": 6.5,
        "steps": 30,
        "extra_negative": "stone church, dome, cross on top, village, trees, grass",
    },
    # Ближчий шар Плині: смуга лісу. Ріжеться в прозорість, тому тло рівне.
    "plyn-trees": {
        "subject": (
            "a band of bare autumn trees seen from a distance, "
            "thin dark trunks and sparse branches, a treeline, "
            "isolated on a plain flat pale background"
        ),
        "world": "plyn",
        "light": "object",
        "size": (1024, 384),
        "cfg": 6.5,
        "steps": 30,
        "extra_negative": "ground, grass, sky gradient, sun, path, single tree",
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
    tail: str = "",
) -> list[str]:
    prompt = compose(subject, world, light, tail)
    print("проміт:\n  " + prompt.replace(", ", ",\n  "))
    print()

    payload = {
        "prompt": prompt,
        "negative_prompt": (
            (BRIGHT_NEGATIVE if world == "bright" else NEGATIVE)
            + (", " + extra_negative if extra_negative else "")
        ),
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
