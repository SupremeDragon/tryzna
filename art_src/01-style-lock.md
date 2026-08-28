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

> **Два правила, без яких перевірка не має сенсу:**
>
> 1. **Нічого не дописуй спереду.** Хвіст стилю вже стоїть у кінці кожного
>    блоку. Якщо додати його ще й на початку, промпт спрацює — але ми
>    перестанемо знати, ЩО саме дало результат, а замок мусить фіксувати
>    відомий промпт.
> 2. **Завантажуй файл, а не роби знімок екрана.** У знімку лишається рамка
>    інтерфейсу й падає роздільність. Нам потрібен чистий PNG.

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

## Картинка 2 — НИЦЬ. Перший шар `[v2]`

Формат: **16:9**.
Файл: `raw/nyts_bg_layer1_v02.png`

> **Що змінено проти v1 і чому.** У v1 червоний акцент вийшов ледь помітним —
> а в нас правило «монохром плюс ОДИН колір», і цей один мусить працювати,
> інакше він не акцент. Ще з'явилася стеля, через яку зал став кінцевим,
> хоча ґрати мали б іти вгору без кінця.

```
An endless flat corridor seen strictly from the side, like a shadow theatre.
Tall thin vertical stone bars stand in a row across the whole frame and
continue upward past the top edge of the image. A single flat floor line
runs edge to edge. Grey ash and bone dust drifted against the base of the
bars. Everything reads as flat silhouette — no depth, no perspective, no
vanishing point. One dull dried-blood red glow burns in the middle distance:
it is the only colour anywhere in the image. No people. No sky. No ceiling.
No horizon. Airless and still.
Near-monochrome: charcoal, ash grey, soot black, with exactly one accent
colour — dull dried-blood red. Painterly digital illustration, hand-painted
texture, visible brush strokes, soft edges, no hard outlines, muted
desaturated palette, subtle film grain, clean readable silhouette, no text,
no letters, no watermark, no signature. Avoid: anime, manga, 3D render, CGI,
photorealistic, neon colours, glossy plastic surfaces, hard black outlines,
cel shading, lens flare, text, logos, UI elements, modern objects.
```

---

## Картинка 3 — ВИСІ. Край Ладу `[v2]`

Формат: **16:9**.
Файл: `raw/vys_bg_kray_v02.png`

> **Що змінено проти v1 і чому.** У v1 по кутах з'явилися **хмари** — саме
> там, де мали бути інші краї інших рас. Хмари означають небо й атмосферу,
> а Висі це плато, що висить у порожнечі; вони руйнують не композицію, а
> сенс. Другорядне: край плато вийшов **рваним папером**, через що кадр
> читався як «карта на столі», а не «світ згори». Рваний, не прямокутний
> край — знахідка й лишається, але це має бути **розламаний камінь**.

```
A single vast plateau of pale bare stone floating alone in absolute empty
blackness, seen from directly overhead. Its edges are jagged broken rock,
raw and cracked, not torn paper. The surface is dust-pale and bare, marked
with a faint drafted grid, and scattered across it are the dark burnt
footprints and foundations of destroyed buildings, drawn in brown ink.
Far away in the blackness, small and dim, the pale shapes of a few other
plateaus of the same kind. Absolutely nothing else exists around them.
No clouds. No sky. No atmosphere. No horizon. No stars. Strictly flat
overhead view, no perspective.
Aged parchment and pale gold, brown ink linework, surrounded by flat void
black. Painterly digital illustration, hand-painted texture, visible brush
strokes, soft edges, no hard outlines, muted desaturated palette, subtle
film grain, clean readable silhouette, no text, no letters, no watermark,
no signature. Avoid: clouds, sky, anime, manga, 3D render, CGI,
photorealistic, neon colours, glossy plastic surfaces, hard black outlines,
cel shading, lens flare, text, logos, UI elements, modern objects.
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
5. Вердикти по кожній партії я пишу в [00-журнал.md](00-журнал.md), щоб через
   півроку не переоткривати ті самі висновки.

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

**Важлива відмінність.** Це правило про **стиль**. Помилка в описі змісту
(зайві хмари, слабкий акцент, не той край) стилю не стосується й
перегенерації всього не вимагає — виправляється один промпт.

---

## РЕЗУЛЬТАТ `[2026-08-29]`

**Умова 1 — тест глека: ПРОЙДЕНО.** Глек став поруч із селом як з тієї самої
гри: та сама вохра, той самий приглушений тон, той самий мазок.

**Умова 2 — три світи як три світи: ПРОЙДЕНО** з двома змістовими правками
(Ниць і Висі, промпти v2 вище).

**Стиль зафіксовано.** Хвіст стилю в [STYLE_PROMPT.txt](STYLE_PROMPT.txt)
більше не чернетка.

---

## Чого НЕ робимо на цьому етапі

- ❌ Не генеруємо персонажів. Вони йдуть кутаут-рігінгом і мають окремий
  пайплайн — див. [docs/05-арт-пайплайн.md](../docs/05-арт-пайплайн.md), §2.
- ❌ Не генеруємо «локацію Балки з усіма шарами». Шари збираються з окремих
  елементів, а не ріжуться з однієї картинки — див. §3 того ж документа.
- ❌ Не правимо промпт «щоб вийшло гарніше». Мета зараз — не краса, а
  перевірка. Красу наводимо після того, як замок закрито.
