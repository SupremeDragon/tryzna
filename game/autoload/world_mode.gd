extends Node
## Режим світу — центральна абстракція гри.
##
## Один гравець, три світи. Змінюється не персонаж, а:
##   1) depth_scale і height_scale у Проєкторі (що саме видно)
##   2) підключений MovementSolver (фізика руху)
##   3) чи тече час
##   4) палітра світу
##
## Два переходи — дзеркальні, і саме тому обидва працюють:
##   СМЕРТЬ:     глибина → 0. Світ сплющується в силует. Час унизу тече далі —
##               він іде без тебе, і це найгірше.
##   ПІДНЕСЕННЯ: висота → 0. Світ осідає в карту. Час унизу СПИНЯЄТЬСЯ —
##               ти вийшов із нього, і він більше тебе не стосується.

enum Mode { VYS, PLYN, NYTS }

signal mode_changed(mode: Mode)

const FOLD_DURATION_DEATH: float = 2.6
const FOLD_DURATION_ASCENT: float = 3.2
const FOLD_DURATION_CAST_DOWN: float = 2.4

## Пауза перед піднесенням: час зупиняється раніше, ніж рушає камера.
## Це та затримана секунда, у якій гравець розуміє, що вийшов зі світу.
const ASCENT_HOLD: float = 0.75

const DEPTH_FOR: Dictionary = {
	Mode.VYS: WorldSpace.DEPTH_VYS,
	Mode.PLYN: WorldSpace.DEPTH_PLYN,
	Mode.NYTS: WorldSpace.DEPTH_NYTS,
}

const HEIGHT_FOR: Dictionary = {
	Mode.VYS: WorldSpace.HEIGHT_VYS,
	Mode.PLYN: WorldSpace.HEIGHT_PLYN,
	Mode.NYTS: WorldSpace.HEIGHT_NYTS,
}

## У Висі камера відходить далеко: світ мусить стати МАЛИМ, а не просто плоским.
## Скільки світу видно за раз. Це не косметика, а частина того, чим світи
## відрізняються. Ниць — коридор, і кадр там мусить тиснути. Плинь — поселення,
## і воно читається тільки тоді, коли видно, ЯК двори стоять одне до одного:
## зблизька це просто хата в траві. Висі — карта, її видно найдалі.
const ZOOM_FOR: Dictionary = {
	Mode.VYS: 0.40,
	Mode.PLYN: 0.36,
	Mode.NYTS: 0.90,
}

## Палітри трьох світів. Див. docs/01-світ-і-лор.md, розділ 5.
const SKY_FOR: Dictionary = {
	Mode.VYS: Color("1b1a24"),
	Mode.PLYN: Color("6cb038"),
	Mode.NYTS: Color("0d0e10"),
}

const GROUND_FOR: Dictionary = {
	Mode.VYS: Color("ddcb99"),
	Mode.PLYN: Color("4a5a44"),
	Mode.NYTS: Color("1a1b1e"),
}

const ACCENT_FOR: Dictionary = {
	Mode.VYS: Color("46351d"),  # туш по пергаменту: на карті потрібен контраст, а не сяйво
	Mode.PLYN: Color("c9a227"),
	Mode.NYTS: Color("b83a2e"),
}

var current: Mode = Mode.PLYN
var is_folding: bool = false

## Чи тече час у нижчих світах. Спиняється тільки коли ти сам вийшов із часу.
var time_flowing: bool = true

var _solvers: Dictionary = {}
var _tween: Tween


func _ready() -> void:
	_solvers[Mode.PLYN] = TopDownSolver.new(330.0, true)
	(_solvers[Mode.PLYN] as TopDownSolver).name_label = "ПЛИНЬ"

	# Висі — той самий розвʼязувач, інші константи: повільніше й без інерції.
	_solvers[Mode.VYS] = TopDownSolver.new(220.0, false)
	(_solvers[Mode.VYS] as TopDownSolver).name_label = "ВИСІ"

	_solvers[Mode.NYTS] = SideSolver.new(300.0)

	_apply_instantly(current)


func solver() -> MovementSolver:
	return _solvers[current] as MovementSolver


## Перешкоди поточної локації. Розвʼязувачі спільні для всіх світів, тому
## світ перешкод підмінюється разом із локацією, а не разом із режимом.
func set_solid_world(world: SolidWorld) -> void:
	for key: Variant in _solvers:
		(_solvers[key] as MovementSolver).world = world


func sky_color() -> Color:
	return SKY_FOR[current] as Color


func ground_color() -> Color:
	return GROUND_FOR[current] as Color


func accent_color() -> Color:
	return ACCENT_FOR[current] as Color


func label() -> String:
	match current:
		Mode.VYS: return "ВИСІ — світ сутностей"
		Mode.PLYN: return "ПЛИНЬ — світ смертних"
		Mode.NYTS: return "НИЦЬ — світ мертвих"
	return "?"


## Миттєве перемикання. Для налагодження й завантаження сцен.
func set_mode(mode: Mode) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	is_folding = false
	current = mode
	_apply_instantly(mode)
	mode_changed.emit(mode)


## Складання камери. Головний візуальний прийом гри.
##
## Перехід НЕ універсальний і не має бути: одна локація ніколи не рендериться
## у двох ракурсах. Це заскриптований момент — смерть або піднесення.
func fold_to(mode: Mode, duration: float = FOLD_DURATION_DEATH, hold: float = 0.0) -> void:
	if mode == current or is_folding:
		return

	var from: Mode = current
	is_folding = true
	EventBus.world_fold_started.emit(int(from), int(mode))

	# Час спиняється НА ПОЧАТКУ піднесення — до того, як рушить камера.
	# При смерті світ навпаки продовжує жити: він іде далі без тебе.
	time_flowing = mode != Mode.VYS

	if _tween != null and _tween.is_valid():
		_tween.kill()

	var to_depth: float = float(DEPTH_FOR[mode])
	var to_height: float = float(HEIGHT_FOR[mode])
	var from_height: float = Projector.height_scale

	_tween = create_tween()
	if hold > 0.0:
		_tween.tween_interval(hold)

	# Глибина рухається рано: спершу ти піднімаєшся й бачиш більше.
	_tween.tween_method(_apply_depth, Projector.depth_scale, to_depth, duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Висота — пізно й різко. Момент, коли вежі осідають у власні основи,
	# має бути окремим ударом, а не розмазатися по всьому переходу.
	_tween.parallel().tween_method(_apply_height, from_height, to_height, duration)\
		.set_ease(Tween.EASE_IN if to_height < from_height else Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_QUINT)

	_tween.chain().tween_callback(func() -> void:
		current = mode
		is_folding = false
		time_flowing = mode != Mode.VYS
		mode_changed.emit(mode)
		EventBus.world_fold_finished.emit(int(mode))
	)


func _apply_instantly(mode: Mode) -> void:
	Projector.depth_scale = float(DEPTH_FOR[mode])
	Projector.height_scale = float(HEIGHT_FOR[mode])
	time_flowing = mode != Mode.VYS


func _apply_depth(value: float) -> void:
	Projector.depth_scale = value


func _apply_height(value: float) -> void:
	Projector.height_scale = value
