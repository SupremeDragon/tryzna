# Завдання 01 — зафіксувати стиль

**Мета:** не «намалювати гарні картинки», а отримати відповідь на одне питання —
**чи тримається наш стиль на різних сюжетах**. Поки відповіді немає, робити
локації немає сенсу: перемальовувати доведеться все.

**Де робимо:** [Flow](https://flow.google) — теперішній інструмент Google Labs.
Whisk згорнули 30 квітня 2026, його функція «референс стилю» (Subject + Scene +
Style) переїхала у Flow. Якщо в тебе ще відкривається ImageFX — теж годиться,
промпти однакові.

---

## Як складати промпт

Беремо блоки з [STYLE_PROMPT.txt](STYLE_PROMPT.txt) і склеюємо **саме в такому
порядку**: зміст → палітра → освітлення → хвіст стилю → чого не хочемо.

Нижче все вже склеєне. **Копіюй цілком, нічого не міняй** — у цьому й суть
перевірки.

---

## Картинка 1 — ПЛИНЬ. Тиха Балка

Формат: **16:9**, найбільша роздільність, яку дає інструмент.
Файл: `raw/plyn_bg_balka_v01.png`

```
A small isolated village in a shallow river valley, seen from a slightly
elevated three-quarter view. Thatched timber huts with sagging roofs, a
crooked wooden fence, a stone well, wet autumn grass, bare birch trees,
low morning mist lying along the ground, rolling hills fading into haze on
the horizon. Empty — no people, no animals. Damp, quiet, lived-in.
Muted earth palette: moss green, ochre, weathered grey stone, faded warm
timber. Soft overcast daylight, diffuse high light source, gentle
atmospheric haze. Painterly digital illustration, hand-painted texture,
visible brush strokes, soft edges, no hard outlines, muted desaturated
palette, subtle film grain, clean readable silhouette, no text, no letters,
no watermark, no signature. Avoid: anime, manga, 3D render, CGI,
photorealistic, neon colours, glossy plastic surfaces, hard black outlines,
cel shading, lens flare, text, logos, UI elements, modern objects.
```

---

## Картинка 2 — НИЦЬ. Перший шар

Формат: **16:9**.
Файл: `raw/nyts_bg_layer1_v01.png`

```
An endless flat corridor seen strictly from the side, like a shadow theatre.
Tall thin vertical stone bars stand in a row across the frame, receding into
blackness. A single flat floor line runs edge to edge. Ash and dust on the
ground. Everything reads as silhouette. One dull glow far away in the dark.
No people. No sky. No horizon. Airless and still.
Near-monochrome: charcoal, ash grey, soot black, with exactly one accent
colour — dull dried-blood red. Painterly digital illustration, hand-painted
texture, visible brush strokes, soft edges, no hard outlines, muted
desaturated palette, subtle film grain, clean readable silhouette, no text,
no letters, no watermark, no signature. Avoid: anime, manga, 3D render, CGI,
photorealistic, neon colours, glossy plastic surfaces, hard black outlines,
cel shading, lens flare, text, logos, UI elements, modern objects.
```

---

## Картинка 3 — ВИСІ. Край Ладу

Формат: **16:9**.
Файл: `raw/vys_bg_kray_v01.png`

```
A vast flat plateau floating alone in absolute darkness, seen from directly
overhead like an old drawn map. The plateau surface is pale parchment-
coloured stone with a faint drafted grid. Scattered across it are the low
burnt footprints of destroyed buildings, drawn in brown ink. Far away in the
black void, the pale edges of other distant plateaus. Strictly flat overhead
view — no perspective, no horizon, no sky.
Aged parchment and pale gold, brown ink linework, surrounded by flat void
black. Painterly digital illustration, hand-painted texture, visible brush
strokes, soft edges, no hard outlines, muted desaturated palette, subtle
film grain, clean readable silhouette, no text, no letters, no watermark,
no signature. Avoid: anime, manga, 3D render, CGI, photorealistic, neon
colours, glossy plastic surfaces, hard black outlines, cel shading, lens
flare, text, logos, UI elements, modern objects.
```

---

## Картинка 4 — ГЛЕК. Це і є перевірка

Формат: **1:1**.
Файл: `raw/item_jug_v01.png`

Три попередні картинки — це три різні світи, і вони **мусять** виглядати
по-різному. Тому вони нічого не доводять.

А глек доводить. Це побутовий предмет, інший сюжет, інший формат, інше
освітлення. **Якщо він виглядає так, ніби з тієї самої гри, що й три
попередні, — стиль тримається.** Якщо ні — хвіст стилю треба правити.

```
A simple hand-made clay water jug, old and chipped, standing upright,
centred, seen straight on. Game item icon.
Muted earth palette: ochre, weathered grey, faded warm clay. Flat even
ambient lighting, no cast shadows, no rim light, no strong highlights,
isolated on a plain flat background. Painterly digital illustration,
hand-painted texture, visible brush strokes, soft edges, no hard outlines,
muted desaturated palette, subtle film grain, clean readable silhouette,
no text, no letters, no watermark, no signature. Avoid: anime, manga,
3D render, CGI, photorealistic, neon colours, glossy plastic surfaces,
hard black outlines, cel shading, lens flare, text, logos, UI elements,
modern objects.
```

---

## Порядок роботи

1. Кожен промпт прогнати **3–4 рази**, вибрати найкращий варіант.
2. Зберегти у `art_src/raw/` під іменами вище. **Імена файлів тільки
   латиницею** — ми вже наступали на кирилицю в шляхах, і це коштувало
   зламаних викликів.
3. Невдалі варіанти теж лишити, з суфіксом `_v02`, `_v03`. Вони знадобляться,
   коли підбиратимемо стиль.
4. Сказати мені, що готово. **Я подивлюся на всі чотири й скажу, що тримається,
   а що ні** — я не можу генерувати, але бачити й оцінювати можу.

---

## Критерій приймання `[v1]`

Стиль вважається **зафіксованим**, коли виконано обидві умови:

1. **Тест глека.** Поклади всі чотири поруч. Стороння людина має сказати, що
   це одна гра. Не «схожі картинки» — а саме одна гра.
2. **Три світи читаються як три світи.** Плинь — обʼємна й тепла. Ниць —
   пласка й майже без кольору. Висі — креслення, а не пейзаж. Якщо Ниць
   вийшла «просто темним пейзажем», а не силуетом — це провал, і виправляти
   треба промпт, а не приймати як є.

Якщо хоч одна умова не виконана — **правимо хвіст стилю й перегенеровуємо
всі чотири**, а не одну невдалу. Інакше замок не замок.

---

## Чого НЕ робимо на цьому етапі

- ❌ Не генеруємо персонажів. Вони йдуть кутаут-рігінгом і мають окремий
  пайплайн — див. [docs/05-арт-пайплайн.md](../docs/05-арт-пайплайн.md), §2.
- ❌ Не генеруємо «локацію Балки з усіма шарами». Шари збираються з окремих
  елементів, а не ріжуться з однієї картинки — див. §3 того ж документа.
- ❌ Не правимо промпт «щоб вийшло гарніше». Мета зараз — не краса, а
  перевірка. Красу наводимо після того, як замок закрито.
