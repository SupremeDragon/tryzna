extends CanvasLayer
## Екран завантаження — «Поріг».
##
## Чесно кажучи, зараз наша гра вантажиться за пів секунди, і технічної потреби
## в цьому екрані немає. Але він тут не заради техніки.
##
## По-перше, різкий стрибок із меню в гру читається як збій, а не як перехід:
## око не встигає, і перші секунди гри витрачаються на «що сталося».
## По-друге, це єдине місце, де гра говорить із гравцем від себе — і саме тому
## тут стоять рядки світу, а не смужка з відсотками. Відсотки нічого не кажуть.
##
## Коли рівні виростуть, екран почне робити й свою пряму роботу — вантажити.
## Тому завантаження тут ЧЕСНО потокове, а не вдаване: `load_threaded_request`.

## Скільки екран тримається щонайменше. Менше — і рядок не встигають прочитати,
## більше — і це вже не поріг, а очікування.
const MIN_SHOW: float = 1.6
const FADE: float = 0.35

const LINES: Array[String] = [
	"Час тече тільки внизу.",
	"Сутність не вмирає — її розвіює.",
	"Смертні виробляють час. Того, чого сутності не мають.",
	"Прибулого зважують за тим, що він робив, а не за тим, що казав.",
	"Ниць — не пересадка. Для майже всіх це кінцева.",
	"Вищий бачить нижчого. Нижчий вищого — ні.",
	"За все є ціна, і платять нею вгорі так само, як унизу.",
]

var _target: String = ""
var _fresh: bool = true
var _elapsed: float = 0.0
var _busy: bool = false

var _veil: ColorRect
var _title: Label
var _line: Label
var _dots: Label


func _ready() -> void:
	layer = 128
	_build()
	visible = false
	set_process(false)


func _build() -> void:
	_veil = ColorRect.new()
	_veil.color = Color(0.05, 0.048, 0.058)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	_title = Label.new()
	_title.text = "ПОРІГ"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(0.62, 0.60, 0.58))
	box.add_child(_title)

	_line = Label.new()
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(760.0, 0.0)
	_line.add_theme_font_size_override("font_size", 34)
	_line.add_theme_color_override("font_color", Color(0.90, 0.88, 0.84))
	box.add_child(_line)

	# Три крапки, що зʼявляються по черзі. Це не прикраса: без жодного руху
	# екран читається як зависання.
	_dots = Label.new()
	_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dots.add_theme_font_size_override("font_size", 26)
	_dots.add_theme_color_override("font_color", Color(0.55, 0.30, 0.24))
	box.add_child(_dots)


## Почати перехід. `fresh` — чи стирати попередній прогрес.
func begin(scene_path: String, fresh: bool = true) -> void:
	if _busy:
		return
	_busy = true
	_target = scene_path
	_fresh = fresh
	_elapsed = 0.0

	_line.text = LINES[randi() % LINES.size()]
	visible = true
	_veil.modulate.a = 0.0
	set_process(true)

	ResourceLoader.load_threaded_request(scene_path)

	var tween := create_tween()
	tween.tween_property(_veil, "modulate:a", 1.0, FADE)


func _process(delta: float) -> void:
	_elapsed += delta
	_dots.text = ".".repeat(1 + int(_elapsed * 2.0) % 3)

	if _elapsed < MIN_SHOW:
		return

	var progress: Array = []
	var status: int = ResourceLoader.load_threaded_get_status(_target, progress)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return

	set_process(false)

	if status != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("Не вдалося завантажити %s (стан %d)" % [_target, status])
		_finish()
		return

	# `[?]` Нова гра поки не стирає стан: GameState не має reset(), і вигадувати
	# його наосліп не варто — це рішення про те, що саме вважати «новою грою».

	var packed: PackedScene = ResourceLoader.load_threaded_get(_target) as PackedScene
	get_tree().change_scene_to_packed(packed)
	_finish()


func _finish() -> void:
	var tween := create_tween()
	tween.tween_interval(0.05)
	tween.tween_property(_veil, "modulate:a", 0.0, FADE)
	tween.tween_callback(func() -> void:
		visible = false
		_busy = false
	)
