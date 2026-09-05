extends Control
## Головне меню «Тризни».
##
## Меню тут не заставка, а перше речення гри. Тому воно не показує ні героя, ні
## бою, ні краєвиду — воно показує ТЕМРЯВУ З ОДНИМ ВОГНИКОМ. Це і є образ усієї
## гри: душа, яка сама собі світить, і більше нікого.
##
## Малюється кодом, а не картинкою, і це свідомо. Намальоване меню довелося б
## перемальовувати щоразу, коли міняється стиль світу, — а стиль ми міняли вже
## двічі. Пил, заграва й дихання світла беруться з тієї самої логіки, що вже
## працює в Ниці, тож меню й гра говорять однією мовою без жодного файлу.

const TITLE: String = "ТРИЗНА"

## Рядки під назвою. Міняються при кожному запуску — дрібниця, але вона одразу
## каже, що гра про вибір, а не про перемогу.
const EPIGRAPHS: Array[String] = [
	"Ти не памʼятаєш, що зробив. Це і є вирок.",
	"Смерть забирає глибину. Піднесення забирає висоту.",
	"Майже всі лишаються внизу. Виходить той, хто змінився.",
	"Ти не знав. А може, не хотів знати.",
]

const ITEMS: Array[String] = [
	"Нова гра",
	"Продовжити",
	"Налаштування",
	"Вийти",
]

const INK := Color(0.92, 0.90, 0.86)
const INK_DIM := Color(0.52, 0.51, 0.50)
const EMBER := Color(0.78, 0.28, 0.20)

## Пилинка. Та сама ідея, що в Ниці: поки нічого не рухається, око читає
## картину, а не місце.
class Mote extends RefCounted:
	var pos: Vector2 = Vector2.ZERO
	var drift: Vector2 = Vector2.ZERO
	var size: float = 2.0
	var phase: float = 0.0
	var depth: float = 0.5

	func _init(p_pos: Vector2, p_depth: float, p_phase: float) -> void:
		pos = p_pos
		depth = p_depth
		phase = p_phase
		size = lerpf(1.1, 3.0, p_depth)
		drift = Vector2(lerpf(-7.0, 11.0, p_phase / TAU), lerpf(4.0, 13.0, p_depth))

	func step(dt: float, field: Vector2) -> void:
		phase += dt * lerpf(0.5, 1.2, depth)
		pos += drift * dt
		pos.x += sin(phase) * 7.0 * dt
		pos.x = fposmod(pos.x, field.x)
		pos.y = fposmod(pos.y, field.y)


var _motes: Array[Mote] = []
var _time: float = 0.0
var _picked: int = 0
var _epigraph: String = ""
var _has_save: bool = false
## Мʼяка кругла заграва. Робиться раз при старті — щокадрове малювання
## градієнта колами коштувало б дорожче й виглядало гірше.
var _glow: Texture2D = null

@onready var _title: Label = $Title
@onready var _epigraph_label: Label = $Epigraph
@onready var _menu: VBoxContainer = $Menu


func _ready() -> void:
	randomize()
	_epigraph = EPIGRAPHS[randi() % EPIGRAPHS.size()]
	_epigraph_label.text = _epigraph
	_title.text = TITLE

	# Автослот — той, у який гра пише сама. Саме він і означає «є що продовжити».
	_has_save = SaveSystem.has_save(SaveSystem.AUTO_SLOT)

	_glow = _make_glow()
	_seed_motes()
	_build_items()
	set_process(true)


## Кругла пляма з мʼяким спадом. Godot уміє це сам через GradientTexture2D —
## не треба ні файлу, ні малювання руками.
func _make_glow() -> Texture2D:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([
		Color(EMBER.r, EMBER.g, EMBER.b, 0.30),
		Color(EMBER.r, EMBER.g, EMBER.b, 0.11),
		Color(EMBER.r, EMBER.g, EMBER.b, 0.0),
	])

	var tex := GradientTexture2D.new()
	tex.gradient = ramp
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 512
	tex.height = 512
	return tex


func _seed_motes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var field: Vector2 = size
	_motes.clear()
	for i: int in 70:
		_motes.append(Mote.new(
			Vector2(rng.randf() * field.x, rng.randf() * field.y),
			rng.randf(), rng.randf() * TAU
		))


func _build_items() -> void:
	for child: Node in _menu.get_children():
		child.queue_free()

	for i: int in ITEMS.size():
		var item := Label.new()
		item.text = ITEMS[i]
		item.add_theme_font_size_override("font_size", 30)
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		item.set_meta("index", i)
		item.gui_input.connect(_on_item_input.bind(i))
		item.mouse_entered.connect(func() -> void: _picked = i)
		_menu.add_child(item)

	_refresh_items()


func _refresh_items() -> void:
	for i: int in _menu.get_child_count():
		var item := _menu.get_child(i) as Label
		# «Продовжити» без збереження не ховаємо, а гасимо: сховані пункти
		# змушують гравця гадати, чи вони взагалі бувають.
		var locked: bool = i == 1 and not _has_save
		var chosen: bool = i == _picked
		item.text = ("  %s" % ITEMS[i]) if not chosen else ("▸ %s" % ITEMS[i])
		item.modulate = INK if chosen else INK_DIM
		if locked:
			item.modulate = INK_DIM.darkened(0.45)


func _process(delta: float) -> void:
	_time += delta
	for mote: Mote in _motes:
		mote.step(delta, size)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	if event.is_action("ui_down"):
		_picked = (_picked + 1) % ITEMS.size()
		_refresh_items()
	elif event.is_action("ui_up"):
		_picked = (_picked - 1 + ITEMS.size()) % ITEMS.size()
		_refresh_items()
	elif event.is_action("ui_accept"):
		_activate(_picked)
	elif event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_tree().quit()


func _on_item_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		_picked = index
		_refresh_items()
		_activate(index)


func _activate(index: int) -> void:
	match index:
		0:
			_start_game(true)
		1:
			if _has_save:
				_start_game(false)
		2:
			pass  # `[?]` Налаштування — окремий екран, ще не зроблений.
		3:
			get_tree().quit()


func _start_game(fresh: bool) -> void:
	Loading.begin("res://scenes/main.tscn", fresh)


func _draw() -> void:
	var view := Rect2(Vector2.ZERO, size)

	# Тло: не рівна чорнота, а темрява з теплом унизу. Рівна заливка читається
	# як «фон не завантажився», а нерівна — як простір.
	draw_rect(view, Color(0.055, 0.052, 0.062))

	# Заграва — ТЕКСТУРОЮ, а не десятком кіл. Кола з різною прозорістю дають
	# видимі кільця: кожне має свій різкий край, і разом вони читаються як
	# мішень, а не як світло.
	var breath: float = 1.0 + sin(_time * 0.9) * 0.06 + sin(_time * 2.3 + 0.7) * 0.02
	if _glow != null:
		var r: float = size.y * 0.62 * breath
		draw_texture_rect(
			_glow,
			Rect2(Vector2(size.x * 0.5 - r, size.y * 0.78 - r), Vector2(r * 2.0, r * 2.0)),
			false, Color(1.0, 1.0, 1.0, 0.55)
		)

	for mote: Mote in _motes:
		var twinkle: float = 0.55 + sin(mote.phase * 1.7) * 0.45
		draw_circle(
			mote.pos, mote.size,
			Color(0.74, 0.72, 0.70, lerpf(0.05, 0.20, mote.depth) * twinkle)
		)

	# Віньєтка: кути темніші за середину, і кадр перестає читатися як
	# прямокутник на екрані.
	var steps: int = 26
	for i: int in range(steps):
		var k: float = float(i) / float(steps)
		var inset: float = size.y * 0.5 * k
		draw_rect(
			Rect2(Vector2(inset * (size.x / size.y), inset),
				Vector2(size.x - inset * 2.0 * (size.x / size.y), size.y - inset * 2.0)),
			Color(0.0, 0.0, 0.0, 0.018), false, size.y * 0.03
		)
