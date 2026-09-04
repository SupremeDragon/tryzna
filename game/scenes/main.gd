extends Node2D
## M1 — сірий прототип. Доказ головного концепту «Тризни».
##
## Тут немає жодного арту: тільки прямокутники.
##
## ТРИ ОКРЕМІ ЛОКАЦІЇ, а не одна з трьома камерами. Це принципово:
## складання камери відбувається на локації, яку ти ПОКИДАЄШ (твоє село
## сплющується в силует, поки ти з нього йдеш), а потім вона відступає — і
## приходить справжній світ призначення. Три такти:
##
##   1. МОРФ    — геометрія навколо тебе втрачає вимір
##   2. ПАУЗА   — ти лежиш плазом у світі, який щойно був живим
##   3. ПЕРЕХІД — старе відступає, приходить новий світ
##
## Керування залежить від світу — див. _hint_for().

const PLAYER_HEIGHT: float = 118.0
const PLAYER_HALF_WIDTH: float = 26.0

## Такти переходу після завершення морфу, у секундах.
## Наскільки камера підіймається над гравцем у площинному світі.
const CAMERA_LIFT_FLAT: float = 250.0

## Світло душі. У Ниці персонаж — єдине джерело світла, бо він і є душа:
## світ мертвих не освітлений, освітлений той, хто крізь нього йде.
##
## Прив'язано до сплющеності, а не до режиму світу: коли гравець помирає й
## світ втрачає глибину, темрява надходить РАЗОМ із цим. Окремого переходу
## не треба — смерть сама себе й затемнює.
## Темрява в Ниці лежить МІЖ предметами, а не на них.
##
## Спершу я затемнив усе до 0.30 — і разом із тінтами шарів (0.46) від
## намальованої яскравості лишалося чотирнадцять відсотків. Вийшло багно.
## Арт уже намальований темним; рушію лишається тільки трохи його притінити
## й додати світло душі згори, а не гасити все й підсвічувати наново.
## Скільки темряви лягає між сусідніми шарами заднього плану.
## Саме вона розділяє ряди по глибині — без неї шари читаються наліпками.
const LAYER_HAZE: float = 0.13

## На скільки земля виступає за прохідну зону, щоб обрив було видно.
const EDGE_OVERHANG: float = 150.0

const DARKNESS_FLAT := Color(0.66, 0.66, 0.70)
const SOUL_LIGHT_TINT := Color(0.92, 0.94, 1.0)
const SOUL_LIGHT_ENERGY: float = 1.15

const BEAT_LIE_STILL: float = 0.45
const BEAT_VEIL_IN: float = 0.55
const BEAT_VEIL_OUT: float = 0.75


## Сірий бокс: коробка в логічному просторі.
class Prop extends RefCounted:
	var pos: Vector3 = Vector3.ZERO  # центр основи
	var size: Vector2 = Vector2(90.0, 90.0)  # ширина по x, глибина по y
	var height: float = 140.0
	var tint: float = 0.0
	## Чи впирається в неї тіло. Помости в Плині й ґрати позаду в Ниці — ні.
	var solid: bool = true

	func _init(
		p_pos: Vector3, p_size: Vector2, p_height: float, p_tint: float,
		p_solid: bool = true
	) -> void:
		pos = p_pos
		size = p_size
		height = p_height
		tint = p_tint
		solid = p_solid


## Хтось, хто ходить своїми справами. Потрібен, щоб було видно, ЧИЙ час стоїть.
class Wanderer extends RefCounted:
	var pos: Vector3 = Vector3.ZERO
	var home: Vector3 = Vector3.ZERO
	var span: Vector2 = Vector2(200.0, 90.0)
	var rate: float = 0.6
	var phase: float = 0.0

	func _init(p_home: Vector3, p_span: Vector2, p_rate: float, p_phase: float) -> void:
		home = p_home
		span = p_span
		rate = p_rate
		phase = p_phase
		step(0.0)

	func step(dt: float) -> void:
		phase += dt * rate
		pos = Vector3(
			home.x + sin(phase) * span.x,
			home.y + cos(phase * 0.7) * span.y,
			0.0
		)

## Смуга заднього плану. Рухається повільніше за світ — і від цього світ
## здається глибоким, хоча жодної глибини в ньому немає.
##
## `parallax`: 0 — шар приклеєний до камери (нескінченно далеко),
##             1 — живе у світі нарівні з гравцем,
##           >1 — ближче за гравця (передній план, летить назустріч).
class Backdrop extends RefCounted:
	enum Kind { HILLS, BARS, HAZE, TEXTURE }

	var parallax: float = 0.3
	var kind: Kind = Kind.HILLS
	var color: Color = Color.GRAY
	var lift: float = 0.0        # на скільки підняти над горизонтом
	var amplitude: float = 120.0 # висота горбів / довжина ґрат
	var wavelength: float = 520.0
	var phase: float = 0.0
	var thickness: float = 90.0  # для HAZE: піврозмах смуги

	## Для TEXTURE: сам малюнок, його масштаб і те, наскільки він притемнений.
	## Темряву накладаємо ТУТ, а не в картинці: згенерувати шар чорним означало б
	## зробити його невирізуваним, бо чорне від чорного не відділити.
	var texture: Texture2D = null
	var scale: float = 1.0
	## Наскільки тайли гуляють по вертикалі, щоб ряд не був лінійкою.
	var tile_jitter: float = 0.0

	## Шар із текстури. Темрява накладається тінтом, а не запікається в картинку.
	static func textured(
		p_parallax: float, p_texture: Texture2D, p_scale: float,
		p_tint: Color, p_lift: float = 0.0, p_jitter: float = 0.0,
		p_phase: float = 0.0
	) -> Backdrop:
		var layer := Backdrop.new(
			p_parallax, Kind.TEXTURE, p_tint, p_lift, 0.0, 0.0, p_phase
		)
		layer.texture = p_texture
		layer.scale = p_scale
		layer.tile_jitter = p_jitter
		return layer

	func _init(
		p_parallax: float, p_kind: Kind, p_color: Color,
		p_lift: float, p_amplitude: float, p_wavelength: float, p_phase: float,
		p_thickness: float = 90.0
	) -> void:
		parallax = p_parallax
		kind = p_kind
		color = p_color
		lift = p_lift
		amplitude = p_amplitude
		wavelength = p_wavelength
		phase = p_phase
		thickness = p_thickness


## Культ Сліз. Одна атака, завжди з видимим замахом.
class Enemy extends RefCounted:
	var pos: Vector3 = Vector3.ZERO
	var home: Vector3 = Vector3.ZERO
	var brain: EnemyBrain = EnemyBrain.new()
	var body: Combatant = Combatant.new(3)
	var death_fade: float = 0.0

	func _init(p_home: Vector3) -> void:
		home = p_home
		pos = p_home

	func plane() -> Vector2:
		return Vector2(pos.x, pos.y)


@onready var _camera: Camera2D = $Camera2D
@onready var _darkness: CanvasModulate = $Darkness
@onready var _soul_light: PointLight2D = $SoulLight
@onready var _hud: Label = $HUD/Readout
@onready var _hint: Label = $HUD/Hint

var _mover: MovementSolver.MoverState = MovementSolver.MoverState.new()
var _props: Array[Prop] = []
var _wanderers: Array[Wanderer] = []

## Плити землі в логічних координатах (x, глибина). Плинь — одна суцільна,
## Ниць — вузький коридор, Висі — архіпелаг країв.
var _plates: Array[Rect2] = []
var _bounds: Rect2 = Rect2()

## Куди можна ходити. Вужче за землю — щоб її край не потрапляв у кадр.
var _walk_bounds: Rect2 = Rect2()
var _backdrops: Array[Backdrop] = []

## Намальована підлога. Є тільки там, де рівень справді площинний.
var _floor_texture: Texture2D = null

## Уступ — це шматок тієї самої кам'яної підлоги, піднятий над землею.
## Тому окремої текстури не малюємо: беремо ту, що вже є.
var _ledge_texture: Texture2D = null
var _solid_world: SolidWorld = SolidWorld.new()

## Розвʼязувач, що перехоплює керування посеред складання камери.
var _fold_solver: SideSolver = null

# --- Бій ---
const DODGE_TIME: float = 0.20
const DODGE_INVULN: float = 0.16
const DODGE_COOLDOWN: float = 0.55
const ABILITY_COOLDOWN: float = 3.0
const ABILITY_RADIUS: float = 210.0
const ABILITY_PUSH: float = 260.0

var _enemies: Array[Enemy] = []
var _hero: Combatant = Combatant.new(4)
var _swing: AttackState = AttackState.new(0.12, 0.15, 0.25)
var _dodge_cd: float = 0.0
var _ability_cd: float = 0.0
var _ability_flash: float = 0.0
var _hit_flash: float = 0.0

var _sky: Color = Color.BLACK
var _ground: Color = Color.DIM_GRAY
var _accent: Color = Color.WHITE

var _veil: float = 0.0
var _veil_color: Color = Color.BLACK

const KIND_PROP: int = 0
const KIND_WANDERER: int = 1
const KIND_PLAYER: int = 2
const KIND_ENEMY: int = 3


func _ready() -> void:
	_load_world(WorldMode.current)
	_sky = WorldMode.sky_color()
	_ground = WorldMode.ground_color()
	_accent = WorldMode.accent_color()
	_camera.zoom = Vector2.ONE * float(WorldMode.ZOOM_FOR[WorldMode.current])

	EventBus.world_fold_finished.connect(_on_fold_finished)
	_refresh_hint()


# --- Три світи ---------------------------------------------------------------

func _load_world(mode: WorldMode.Mode) -> void:
	_props.clear()
	_wanderers.clear()
	_plates.clear()
	_enemies.clear()
	_backdrops.clear()

	var spawn: Vector3 = Vector3.ZERO
	match mode:
		WorldMode.Mode.PLYN: spawn = _build_plyn()
		WorldMode.Mode.NYTS: spawn = _build_nyts()
		WorldMode.Mode.VYS: spawn = _build_vys()

	_bounds = _plates[0]
	for plate: Rect2 in _plates:
		_bounds = _bounds.merge(plate)

	var inset: float = minf(700.0, _bounds.size.x * 0.25)
	_walk_bounds = Rect2(
		_bounds.position.x + inset, _bounds.position.y,
		_bounds.size.x - inset * 2.0, _bounds.size.y
	)

	_floor_texture = load("res://art/nyts/floor.png") as Texture2D \
		if mode == WorldMode.Mode.NYTS else null
	_ledge_texture = _floor_texture

	_solid_world.clear()
	for prop: Prop in _props:
		if prop.solid:
			_solid_world.add_box(prop.pos, prop.size, prop.height)
	WorldMode.set_solid_world(_solid_world)

	_mover.position = spawn
	_mover.velocity = Vector3.ZERO
	_hero.revive()
	# revive() дає невразливість, і на респауні це читається як «мене щойно
	# вдарили». Поява у світі має бути тихою.
	_hero.invuln_left = 0.0
	_swing.cancel()
	_camera.reset_smoothing()


## ПЛИНЬ — «Тиха Балка». Село: розкидані хати, каплиця, помости, люди.
func _build_plyn() -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260828

	_plates.append(Rect2(-2600.0, -420.0, 5200.0, 1560.0))

	# Хати навколо майдану.
	for i: int in range(6):
		var x: float = -1250.0 + float(i) * 520.0
		for j: int in range(3):
			var y: float = 140.0 + float(j) * 330.0
			if absf(x) < 320.0 and j == 0:
				continue  # майдан перед гравцем лишаємо порожнім
			_props.append(Prop.new(
				Vector3(x + rng.randf_range(-70.0, 70.0), y, 0.0),
				Vector2(rng.randf_range(190.0, 290.0), rng.randf_range(170.0, 250.0)),
				rng.randf_range(70.0, 190.0),
				rng.randf()
			))

	# Низькі помости. Не суцільні: через них переступають, їх не обходять.
	for k: int in range(5):
		_props.append(Prop.new(
			Vector3(-1000.0 + float(k) * 500.0, 620.0, 0.0),
			Vector2(340.0, 300.0), 22.0, 0.15, false
		))

	# Каплиця й дзвіниці на дальньому краї.
	for m: int in range(4):
		_props.append(Prop.new(
			Vector3(-820.0 + float(m) * 560.0, -280.0, 0.0),
			Vector2(240.0, 200.0), 360.0 + float(m) * 70.0, 0.85
		))

	# Селяни. Поки ти живий — вони ходять.
	for w: int in range(9):
		_wanderers.append(Wanderer.new(
			Vector3(-1150.0 + float(w) * 290.0, 260.0 + rng.randf_range(-120.0, 520.0), 0.0),
			Vector2(rng.randf_range(140.0, 300.0), rng.randf_range(50.0, 140.0)),
			rng.randf_range(0.35, 0.8), rng.randf_range(0.0, TAU)
		))

	# ПЛИНЬ — паралакс помірний. У трьох чвертях камера ходить в обидва боки,
	# і далина здебільшого лежить углиб, а не вбік. Три смуги позаду й одна
	# попереду — цього досить, більше вже не читається.
	_backdrops.append(Backdrop.new(0.12, Backdrop.Kind.HILLS,
		Color("39463c"), 250.0, 190.0, 1500.0, 0.0))
	_backdrops.append(Backdrop.new(0.28, Backdrop.Kind.HILLS,
		Color("36443b"), 150.0, 140.0, 900.0, 1.7))
	_backdrops.append(Backdrop.new(0.45, Backdrop.Kind.HILLS,
		Color("33403a"), 60.0, 100.0, 640.0, 3.3))
	_backdrops.append(Backdrop.new(0.62, Backdrop.Kind.HAZE,
		Color(0.75, 0.79, 0.76, 0.20), 30.0, 0.0, 0.0, 0.0, 120.0))
	# Передній план: летить швидше за гравця. Найдешевший спосіб додати обʼєм.
	_backdrops.append(Backdrop.new(1.45, Backdrop.Kind.HAZE,
		Color(0.10, 0.13, 0.11, 0.26), -620.0, 0.0, 0.0, 0.0, 220.0))

	# Культ Сліз прийшов у Балку. Бій живе в Плині: у Ниці його майже немає,
	# а у Висі немає взагалі — див. docs/03-геймплей.md.
	_enemies.append(Enemy.new(Vector3(560.0, 120.0, 0.0)))
	_enemies.append(Enemy.new(Vector3(-640.0, 380.0, 0.0)))

	return Vector3(0.0, 0.0, 0.0)


## НИЦЬ — «Перший шар». Коридор: глибини немає, є тільки довжина й висота.
## Ліс вертикальних ґрат, уступи, і мертві, що ходять туди-сюди по своїй смузі.
func _build_nyts() -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = 771

	# Плита вузька: у профілі глибина все одно не видима, і рівень —
	# це смуга, а не майдан. Гравець тут не блукає, він ІДЕ.
	_plates.append(Rect2(-4200.0, -60.0, 8000.0, 120.0))

	# НИЦЬ — паралакс тут працює на повну. Це сайд-скрол, камера їздить
	# горизонтально, і саме для цього випадку паралакс і вигадали.
	# Пʼять шарів: від ледь видимого відблиску в глибині до ґрат, що
	# проносяться перед самим обличчям.
	# Заграва — єдина барва в усьому світі. Текстурою, а не смугою: смуга
	# читалася як намальована лінійкою й різала кадр навпіл.
	var glow_tex: Texture2D = load("res://art/nyts/glow.png") as Texture2D
	if glow_tex != null:
		_backdrops.append(Backdrop.textured(
			0.05, glow_tex, 0.55, Color(0.62, 0.24, 0.19, 0.55), 190.0
		))

	# Колонада. Одна й та сама розріджена картинка працює двома шарами: далекий
	# менший, вищий над підлогою й темніший. Підйом над лінією підлоги — це
	# підроблений горизонт: у площинному світі глибини немає, і без нього всі
	# стовпи стояли б на одній лінії, наче в один ряд.
	var row_tex: Texture2D = load("res://art/nyts/pillars_row.png") as Texture2D
	var near_tex: Texture2D = load("res://art/nyts/pillars_near.png") as Texture2D
	var front_tex: Texture2D = load("res://art/nyts/pillars_front.png") as Texture2D

	if row_tex != null:
		_backdrops.append(Backdrop.textured(
			0.14, row_tex, 0.42, Color(0.40, 0.40, 0.45), 165.0, 26.0, 0.0
		))
		_backdrops.append(Backdrop.textured(
			0.34, row_tex, 0.70, Color(0.68, 0.68, 0.73), 72.0, 34.0, 2.1
		))
	if near_tex != null:
		_backdrops.append(Backdrop.textured(
			0.60, near_tex, 0.55, Color(0.96, 0.96, 1.0), 0.0, 18.0, 4.4
		))
	if front_tex != null:
		# Передній план заходить нижче підлоги — він же перед нею.
		_backdrops.append(Backdrop.textured(
			1.50, front_tex, 2.10, Color(0.16, 0.16, 0.19), -140.0
		))

	# Ґрат-декорацій тут більше немає: їхню роботу перебрали намальовані
	# шари колонади. Вони лишалися сірими прямокутниками серед мальованого
	# світу й дублювали те, що вже є позаду.

	# Уступи — суцільні. Висота стрибка ~184, тому все нижче можна взяти.
	for k: int in range(11):
		_props.append(Prop.new(
			Vector3(-2900.0 + float(k) * 560.0, 0.0, 0.0),
			Vector2(rng.randf_range(240.0, 420.0), 60.0),
			rng.randf_range(40.0, 150.0),
			0.9
		))

	# Мертві. Ходять по своїй смузі вперед-назад і не бачать одне одного.
	for w: int in range(14):
		_wanderers.append(Wanderer.new(
			Vector3(-3000.0 + float(w) * 440.0, 0.0, 0.0),
			Vector2(rng.randf_range(60.0, 170.0), 0.0),
			rng.randf_range(0.15, 0.4), rng.randf_range(0.0, TAU)
		))

	return Vector3(-3000.0, 0.0, 0.0)


## ВИСІ — «Край Ладу». Архіпелаг плато в порожнечі. Своє плато — випалене:
## самі руїни. Сусідні краї цілі, і на них ще щось стоїть.
func _build_vys() -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4041

	# Край Ладу — центральний, найбільший, і на ньому майже нічого не лишилося.
	_plates.append(Rect2(-900.0, -100.0, 1800.0, 1000.0))
	# Сусідні краї інших рас.
	_plates.append(Rect2(-2500.0, -700.0, 1100.0, 620.0))
	_plates.append(Rect2(1250.0, -560.0, 900.0, 540.0))
	_plates.append(Rect2(-1900.0, 1080.0, 1250.0, 520.0))
	_plates.append(Rect2(1050.0, 940.0, 1000.0, 640.0))

	# ВИСІ — паралаксу НЕМАЄ, і це не економія, а рішення.
	# У карти немає глибини. Щойно задній план почне рухатися повільніше,
	# карта перетвориться на пейзаж — а це рівно те, чого ми уникаємо.
	# Порожнеча навколо плато мусить бути мертвою.

	# Руїни Ладу: низькі уламки, розкидані без ладу. Іронія навмисна.
	# Нічого не суцільне: за каноном у Висі взагалі не ходять (див.
	# docs/07, канон 7), і зіткнення тут не має сенсу.
	for i: int in range(18):
		_props.append(Prop.new(
			Vector3(rng.randf_range(-780.0, 780.0), rng.randf_range(0.0, 800.0), 0.0),
			Vector2(rng.randf_range(90.0, 230.0), rng.randf_range(80.0, 200.0)),
			rng.randf_range(18.0, 70.0),
			rng.randf() * 0.3,
			false
		))

	# Чужі краї — цілі: там стоять високі споруди, і на карті вони темні.
	var foreign: Array[Rect2] = [_plates[1], _plates[2], _plates[3], _plates[4]]
	for plate: Rect2 in foreign:
		for k: int in range(5):
			_props.append(Prop.new(
				Vector3(
					rng.randf_range(plate.position.x + 120.0, plate.end.x - 120.0),
					rng.randf_range(plate.position.y + 110.0, plate.end.y - 110.0),
					0.0
				),
				Vector2(rng.randf_range(130.0, 230.0), rng.randf_range(120.0, 200.0)),
				rng.randf_range(220.0, 430.0),
				0.8,
				false
			))

	# Сутності інших рас. У Висі час стоїть — вони не рухаються ніколи.
	for w: int in range(7):
		_wanderers.append(Wanderer.new(
			Vector3(rng.randf_range(-2200.0, 1900.0), rng.randf_range(-500.0, 1400.0), 0.0),
			Vector2(90.0, 40.0), 0.2, rng.randf_range(0.0, TAU)
		))

	return Vector3(0.0, 380.0, 0.0)


# --- Переходи ----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action("quit_game"):
		get_tree().quit()
	elif event.is_action("debug_die"):
		_die()
	elif event.is_action("debug_live"):
		_return_to_plyn()
	elif event.is_action("debug_ascend"):
		_ascend()
	elif event.is_action("attack"):
		_swing.press()
	elif event.is_action("ability"):
		_cast_ability()


func _die() -> void:
	if WorldMode.current == WorldMode.Mode.NYTS or WorldMode.is_folding or _veil > 0.0:
		return
	Ledger.record(&"debug_death", "Помер(ла) у сірому прототипі", [&"віра"], 1.0)
	EventBus.player_died.emit(&"debug")
	_transition(WorldMode.Mode.NYTS, WorldMode.FOLD_DURATION_DEATH, 0.0, Color.BLACK)


func _ascend() -> void:
	if WorldMode.current == WorldMode.Mode.VYS or WorldMode.is_folding or _veil > 0.0:
		return
	_transition(
		WorldMode.Mode.VYS, WorldMode.FOLD_DURATION_ASCENT,
		WorldMode.ASCENT_HOLD, Color("fff4dc")
	)


func _return_to_plyn() -> void:
	if WorldMode.current == WorldMode.Mode.PLYN or WorldMode.is_folding or _veil > 0.0:
		return
	_transition(WorldMode.Mode.PLYN, WorldMode.FOLD_DURATION_CAST_DOWN, 0.0, Color.BLACK)


func _transition(mode: WorldMode.Mode, duration: float, hold: float, veil: Color) -> void:
	_veil_color = veil
	WorldMode.fold_to(mode, duration, hold)
	_tween_camera(mode, duration, hold)


func _tween_camera(mode: WorldMode.Mode, duration: float, hold: float) -> void:
	var zoom: float = float(WorldMode.ZOOM_FOR[mode])
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if hold > 0.0:
		tween.tween_interval(hold)
	tween.tween_property(_camera, "zoom", Vector2.ONE * zoom, duration)
	tween.parallel().tween_method(_blend_palette.bind(mode), 0.0, 1.0, duration)


## Морф скінчився. Далі — пауза, завіса, підміна локації, поява.
func _on_fold_finished(mode: int) -> void:
	_blend_palette(1.0, mode as WorldMode.Mode)

	var tween := create_tween()
	tween.tween_interval(BEAT_LIE_STILL)
	tween.tween_method(_set_veil, 0.0, 1.0, BEAT_VEIL_IN)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func() -> void:
		_load_world(mode as WorldMode.Mode)
		_refresh_hint()
	)
	tween.tween_method(_set_veil, 1.0, 0.0, BEAT_VEIL_OUT)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _set_veil(value: float) -> void:
	_veil = value


func _blend_palette(t: float, mode: WorldMode.Mode) -> void:
	_sky = WorldMode.sky_color().lerp(WorldMode.SKY_FOR[mode] as Color, t)
	_ground = WorldMode.ground_color().lerp(WorldMode.GROUND_FOR[mode] as Color, t)
	_accent = WorldMode.accent_color().lerp(WorldMode.ACCENT_FOR[mode] as Color, t)


## Підказка показує тільки те, що працює ТУТ. Стрибок є лише в Ниці.
func _hint_for(mode: WorldMode.Mode) -> String:
	match mode:
		WorldMode.Mode.PLYN:
			return "WASD — рух   ·   J — удар   ·   Пробіл — ухилення   ·   Q — відштовх"\
				+ "   ·   K — померти   ·   U — піднестися   ·   Esc"
		WorldMode.Mode.NYTS:
			return "A / D — іти   ·   Пробіл — стрибок   ·   L — назад у Плинь   ·   Esc — вихід"
		WorldMode.Mode.VYS:
			return "WASD — рух   ·   L — назад у Плинь   ·   Esc — вихід"
	return ""


func _refresh_hint() -> void:
	_hint.text = _hint_for(WorldMode.current)


# --- Симуляція ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Пробіл робить те, що має сенс у цьому світі: у Ниці стрибок (єдиний світ,
	# де є висота під ногами), деінде — ухилення.
	var space: bool = Input.is_action_just_pressed("jump")
	var jump: bool = space and WorldMode.current == WorldMode.Mode.NYTS
	if space and WorldMode.current != WorldMode.Mode.NYTS:
		_try_dodge(input)

	# Під час смерті керування підкоряється НОВОМУ світу, щойно глибина
	# сплющилась наполовину. Гравець фізично відчуває втрату виміру.
	var solver: MovementSolver = WorldMode.solver()
	if WorldMode.is_folding and Projector.flatness() > 0.5:
		if _fold_solver == null:
			_fold_solver = SideSolver.new(300.0)
			_fold_solver.world = _solid_world
		solver = _fold_solver
	else:
		_fold_solver = null

	solver.step(_mover, input, jump, delta)
	_clamp_to_world()

	if WorldMode.time_flowing:
		for wanderer: Wanderer in _wanderers:
			wanderer.step(delta)

	_update_combat(delta)

	# У профілі камера піднімається: підлога має лежати в нижній чверті кадру,
	# а не посередині. Інакше під ногами зяє півекрана порожнечі, а стовпи
	# зрізає верхнім краєм на середині зросту.
	var lift: float = lerpf(
		PLAYER_HEIGHT * 0.5, CAMERA_LIFT_FLAT, Projector.flatness()
	)
	_camera.position = Projector.project(_mover.position) - Vector2(0.0, lift)
	_update_soul_light()
	queue_redraw()
	_update_hud()


# --- Бій ---------------------------------------------------------------------

func _try_dodge(input: Vector2) -> void:
	if _dodge_cd > 0.0 or not _hero.is_alive():
		return
	var dir: Vector2 = input if input.length_squared() > 0.001 else _mover.facing_dir
	WorldMode.solver().start_dash(dir, DODGE_TIME)
	_hero.invuln_left = maxf(_hero.invuln_left, DODGE_INVULN)
	_dodge_cd = DODGE_COOLDOWN
	_swing.cancel()


## «Відштовх» — підпис Ости. Вона не воїн: її сила не в лезі, а в тому, щоб
## зрушити чуже з місця. Шкоди не завдає, збиває замах і розкидає.
func _cast_ability() -> void:
	if _ability_cd > 0.0 or not _hero.is_alive():
		return
	_ability_cd = ABILITY_COOLDOWN
	_ability_flash = 0.45

	var origin: Vector2 = Vector2(_mover.position.x, _mover.position.y)
	for enemy: Enemy in _enemies:
		if not enemy.body.is_alive():
			continue
		var offset: Vector2 = enemy.plane() - origin
		if offset.length() > ABILITY_RADIUS:
			continue
		var push: Vector2 = offset.normalized() * ABILITY_PUSH
		enemy.pos.x += push.x
		enemy.pos.y += push.y
		enemy.body.stagger_left = maxf(enemy.body.stagger_left, 0.9)
		enemy.brain.interrupt()


func _update_combat(dt: float) -> void:
	_dodge_cd = maxf(_dodge_cd - dt, 0.0)
	_ability_cd = maxf(_ability_cd - dt, 0.0)
	_ability_flash = maxf(_ability_flash - dt, 0.0)
	_hit_flash = maxf(_hit_flash - dt, 0.0)

	_hero.tick(dt)
	_swing.tick(dt)

	var hero_plane: Vector2 = Vector2(_mover.position.x, _mover.position.y)
	var hero_foot: Rect2 = WorldMode.solver().foot_of(_mover.position)

	# Удар Ости.
	if _swing.consume():
		var box: Rect2 = _swing.box(hero_plane, _mover.facing_dir)
		for enemy: Enemy in _enemies:
			if not enemy.body.is_alive():
				continue
			if box.intersects(_enemy_foot(enemy)) and enemy.body.take_hit(1, 0.35):
				var knock: Vector2 = (enemy.plane() - hero_plane).normalized() * 46.0
				enemy.pos.x += knock.x
				enemy.pos.y += knock.y
				enemy.brain.interrupt()

	for enemy: Enemy in _enemies:
		enemy.body.tick(dt)

		if not enemy.body.is_alive():
			enemy.death_fade = minf(enemy.death_fade + dt * 1.6, 1.0)
			continue

		var velocity: Vector2 = enemy.brain.tick(
			dt, enemy.plane(), hero_plane, enemy.body.is_staggered()
		)
		_move_enemy(enemy, velocity * dt)

		if enemy.brain.consume_strike():
			var reach: Vector2 = enemy.plane() + enemy.brain.facing * 86.0
			var strike := Rect2(reach - Vector2(52.0, 46.0), Vector2(104.0, 92.0))
			if strike.intersects(hero_foot) and _hero.take_hit(1, 0.25):
				_hit_flash = 0.35
				var knock: Vector2 = enemy.brain.facing * 120.0
				_mover.position.x += knock.x
				_mover.position.y += knock.y

	if not _hero.is_alive():
		_collapse()


## Смерть у бою — не смерть персонажа. Ти непритомнієш і втрачаєш час.
## Сюжетна смерть буває тільки в Розділі 6 — див. docs/03-геймплей.md, §3.
func _collapse() -> void:
	Ledger.record(&"debug_collapse", "Знепритомніла в бою", [&"насильство"], 0.5)
	_hero.revive()
	# revive() дає невразливість, і на респауні це читається як «мене щойно
	# вдарили». Поява у світі має бути тихою.
	_hero.invuln_left = 0.0
	_swing.cancel()
	_mover.position = Vector3(0.0, 0.0, 0.0)
	_mover.velocity = Vector3.ZERO
	for enemy: Enemy in _enemies:
		enemy.pos = enemy.home
		enemy.brain.interrupt()


func _enemy_foot(enemy: Enemy) -> Rect2:
	return Rect2(enemy.pos.x - 26.0, enemy.pos.y - 22.0, 52.0, 44.0)


func _move_enemy(enemy: Enemy, delta: Vector2) -> void:
	enemy.pos.x += delta.x
	if _solid_world.overlaps_ground(_enemy_foot(enemy)):
		enemy.pos.x = _solid_world.resolve_ground(_enemy_foot(enemy), 0, delta.x > 0.0)
	enemy.pos.y += delta.y
	if _solid_world.overlaps_ground(_enemy_foot(enemy)):
		enemy.pos.y = _solid_world.resolve_ground(_enemy_foot(enemy), 1, delta.y > 0.0)
	enemy.pos.x = clampf(enemy.pos.x, _bounds.position.x, _bounds.end.x)
	enemy.pos.y = clampf(enemy.pos.y, _bounds.position.y, _bounds.end.y)


## Світло стоїть на рівні грудей, а не під ногами: інакше воно світить у
## підлогу й персонаж лишається темною плямою на світлій калюжі.
func _update_soul_light() -> void:
	var flat: float = Projector.flatness()

	_darkness.color = Color.WHITE.lerp(DARKNESS_FLAT, flat)
	_soul_light.energy = SOUL_LIGHT_ENERGY * flat
	_soul_light.color = SOUL_LIGHT_TINT
	_soul_light.visible = flat > 0.02

	var chest: Vector3 = _mover.position + Vector3(0.0, 0.0, PLAYER_HEIGHT * 0.55)
	_soul_light.position = Projector.project(chest)


func _clamp_to_world() -> void:
	_mover.position.x = clampf(_mover.position.x, _walk_bounds.position.x, _walk_bounds.end.x)
	_mover.position.y = clampf(_mover.position.y, _walk_bounds.position.y, _walk_bounds.end.y)


func _update_hud() -> void:
	var state: String = "перехід…" if WorldMode.is_folding else "стабільно"
	var clock: String = "час тече" if WorldMode.time_flowing else "ЧАС СТОЇТЬ"
	var hearts: String = "".lpad(0)
	for i: int in _hero.max_hp:
		hearts += "♥" if i < _hero.hp else "·"

	var alive_enemies: int = 0
	for enemy: Enemy in _enemies:
		if enemy.body.is_alive():
			alive_enemies += 1

	_hud.text = "%s\nглибина: %.2f (силует %.0f%%)   ·   висота: %.2f (карта %.0f%%)\nрух: %s   ·   %s   ·   %s\nжиття: %s   ·   ворогів: %d   ·   відштовх: %s\nперешкод: %d   ·   шарів фону: %d   ·   Реєстр діянь: %d" % [
		WorldMode.label(),
		Projector.depth_scale, Projector.flatness() * 100.0,
		Projector.height_scale, Projector.mapness() * 100.0,
		WorldMode.solver().label(), state, clock,
		hearts, alive_enemies,
		"готовий" if _ability_cd <= 0.0 else "%.1f с" % _ability_cd,
		_solid_world.count(), _backdrops.size(), Ledger.count(),
	]


# --- Малювання ---------------------------------------------------------------

func _draw() -> void:
	var flat: float = Projector.flatness()
	var mapn: float = Projector.mapness()

	draw_rect(_visible_rect(), _sky)
	_draw_backdrops(false)
	for plate: Rect2 in _plates:
		_draw_plate(plate, flat, mapn)

	# Один список усього, що стоїть на землі, відсортований по глибині.
	# x = ключ сортування, y = тип обʼєкта, z = індекс.
	_draw_ground_markers(mapn)

	var order: Array[Vector3] = []
	for i: int in _props.size():
		order.append(Vector3(_props[i].pos.y, float(KIND_PROP), float(i)))
	for i: int in _wanderers.size():
		order.append(Vector3(_wanderers[i].pos.y, float(KIND_WANDERER), float(i)))
	for i: int in _enemies.size():
		order.append(Vector3(_enemies[i].pos.y, float(KIND_ENEMY), float(i)))
	order.append(Vector3(_mover.position.y, float(KIND_PLAYER), 0.0))
	order.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x > b.x)

	for entry: Vector3 in order:
		match int(entry.y):
			KIND_PROP: _draw_prop(_props[int(entry.z)], flat, mapn)
			KIND_WANDERER: _draw_wanderer(_wanderers[int(entry.z)], flat, mapn)
			KIND_ENEMY: _draw_enemy(_enemies[int(entry.z)], flat, mapn)
			KIND_PLAYER: _draw_player(flat, mapn)

	# Передній план малюється ПІСЛЯ всіх тіл — він же попереду.
	_draw_backdrops(true)

	if _veil > 0.001:
		draw_rect(_visible_rect(), Color(_veil_color, _veil))


## Зони ударів — це РОЗМІТКА НА ЗЕМЛІ, і малювати її треба разом із землею,
## а не разом із тілами. Інакше вона то виринає перед бійцями, то ховається
## за ними залежно від глибини, і бій перестає читатися.
func _draw_ground_markers(mapn: float) -> void:
	if mapn > 0.9:
		return

	for enemy: Enemy in _enemies:
		if not enemy.body.is_alive():
			continue
		var warn: float = enemy.brain.windup_ratio()
		if warn <= 0.0:
			continue
		var reach: Vector3 = enemy.pos + Vector3(
			enemy.brain.facing.x * 86.0, enemy.brain.facing.y * 86.0, 0.0
		)
		_draw_marker(
			reach, Vector2(104.0, 92.0), Color("ff6a4d"),
			warn, enemy.brain.is_striking()
		)

	if _swing.is_busy():
		var box: Rect2 = _swing.box(
			Vector2(_mover.position.x, _mover.position.y), _mover.facing_dir
		)
		_draw_marker(
			Vector3(box.get_center().x, box.get_center().y, 0.0), box.size,
			_accent.lightened(0.35), _swing.windup_ratio(), _swing.is_active()
		)

	if _ability_flash > 0.0:
		var origin: Vector2 = Projector.project(Vector3(_mover.position.x, _mover.position.y, 0.0))
		var alpha: float = _ability_flash / 0.45
		draw_set_transform(origin, 0.0, Vector2(1.0, Projector.depth_scale))
		draw_arc(Vector2.ZERO, ABILITY_RADIUS * (1.4 - alpha * 0.4), 0.0, TAU, 64,
			Color(_accent.lightened(0.4), alpha * 0.9), 7.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Одна мітка удару. Заливка наливається разом із замахом, обвід товщає —
## гравець читає «зараз бахне» двома способами одночасно.
func _draw_marker(
	at: Vector3, size: Vector2, tint: Color, ripeness: float, hot: bool
) -> void:
	var center: Vector2 = Projector.project(at)
	var screen := Vector2(size.x, size.y * Projector.depth_scale)
	var rect := Rect2(center - screen * 0.5, screen)

	draw_rect(rect, Color(tint, 0.10 + ripeness * 0.30 if not hot else 0.60))
	draw_rect(rect, Color(tint, 0.45 + ripeness * 0.55), false, 2.0 + ripeness * 3.0)

	# У момент удару — коротка яскрава спалахана по всій зоні.
	if hot:
		draw_rect(rect.grow(6.0), Color(Color.WHITE, 0.45), false, 3.0)


## `foreground`: false — усе, що позаду світу; true — те, що попереду нього.
func _draw_backdrops(foreground: bool) -> void:
	if _backdrops.is_empty():
		return
	var view: Rect2 = _visible_rect()
	var horizon: float = Projector.project(Vector3(0.0, _bounds.position.y, 0.0)).y

	# Між шарами кладемо серпанок. Без нього кожен шар обривається різко й
	# читається наліпкою: видно платформу, за нею одразу другу, а стовпи то
	# втоплені в чорноту, то стирчать поверх неї. У референсі кожен ряд
	# углиб темніший за попередній — це і є атмосфера, тільки намальована.
	var drawn: int = 0

	for layer: Backdrop in _backdrops:
		if (layer.parallax > 1.0) != foreground:
			continue

		# Серпанок лягає ПЕРЕД шаром, тож усе, що позаду, вже під ним.
		if not foreground and drawn > 0:
			draw_rect(view, Color(_sky, LAYER_HAZE))
		drawn += 1
		# Ось і весь паралакс: шар зміщується назустріч камері тим сильніше,
		# чим він далі. На екрані це читається як рух із різною швидкістю.
		var shift: float = _camera.position.x * (1.0 - layer.parallax)
		var baseline: float = horizon - layer.lift

		match layer.kind:
			Backdrop.Kind.HILLS:
				draw_colored_polygon(
					_hill_polygon(view, shift, baseline, layer), layer.color
				)
			Backdrop.Kind.BARS:
				_draw_bars(view, shift, baseline, layer)
			Backdrop.Kind.TEXTURE:
				_draw_textured(view, shift, baseline, layer)
			Backdrop.Kind.HAZE:
				# Кілька вкладених смуг замість однієї: край розмивається,
				# і заграва перестає читатися як намальована лінійкою.
				var bands: int = 5
				for band: int in range(bands):
					var k: float = float(band + 1) / float(bands)
					var half: float = layer.thickness * k
					draw_rect(
						Rect2(Vector2(view.position.x, baseline - half),
							Vector2(view.size.x, half * 2.0)),
						Color(layer.color, layer.color.a / float(bands))
					)


func _hill_polygon(view: Rect2, shift: float, baseline: float, layer: Backdrop) -> PackedVector2Array:
	var points := PackedVector2Array()
	var step: float = 26.0
	var x: float = view.position.x
	while x <= view.end.x:
		var local: float = x - shift
		var wave: float = sin(local / layer.wavelength + layer.phase) * 0.6 \
			+ sin(local / (layer.wavelength * 0.41) + layer.phase * 2.3) * 0.4
		points.append(Vector2(x, baseline - layer.amplitude * (wave * 0.5 + 0.5)))
		x += step
	# Дно пагорбів — сам горизонт. Далина не має права опускатися нижче
	# за землю: інакше вона заливає низ екрана й з-під неї видно край плити.
	points.append(Vector2(view.end.x, baseline + layer.lift))
	points.append(Vector2(view.position.x, baseline + layer.lift))
	return points


## Текстура повторюється вздовж x і стоїть НА лінії підлоги.
##
## Повторення видно оком: та сама картинка через кожні `width` пікселів
## читається як шпалери. Лікуємо не новим артом (варіації, згенеровані
## img2img, відрізнялися від оригіналу менш ніж на відсоток), а двома
## безкоштовними прийомами:
##
##   1. КОЖЕН ДРУГИЙ тайл дзеркалиться — період стає вдвічі довшим;
##   2. кожен тайл трохи зсувається по вертикалі — ряд перестає бути лінійкою.
##
## Зсув детермінований від номера тайла, тож картинка не смикається між
## кадрами й не залежить від того, звідки прийшла камера.
func _draw_textured(view: Rect2, shift: float, baseline: float, layer: Backdrop) -> void:
	if layer.texture == null:
		return
	var width: float = float(layer.texture.get_width()) * layer.scale
	var height: float = float(layer.texture.get_height()) * layer.scale
	if width <= 1.0:
		return

	var index: int = int(floor((view.position.x - shift) / width)) - 1
	while true:
		var x: float = float(index) * width + shift
		if x > view.end.x:
			break

		var jitter: float = sin(float(index) * 7.31 + layer.phase) * layer.tile_jitter
		var y: float = baseline - height + jitter
		var box := Rect2(Vector2.ZERO, Vector2(width, height))

		if index % 2 == 0:
			draw_texture_rect(
				layer.texture, Rect2(Vector2(x, y), box.size), false, layer.color
			)
		else:
			# Дзеркалимо через відʼємний масштаб: правий край тайла стає лівим.
			draw_set_transform(Vector2(x + width, y), 0.0, Vector2(-1.0, 1.0))
			draw_texture_rect(layer.texture, box, false, layer.color)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		index += 1


func _draw_bars(view: Rect2, shift: float, baseline: float, layer: Backdrop) -> void:
	var spacing: float = layer.wavelength
	var index: int = int(floor((view.position.x - shift) / spacing)) - 1
	var width: float = spacing * 0.26
	while true:
		var local: float = float(index) * spacing
		var x: float = local + shift
		if x > view.end.x + spacing:
			break
		# Детермінована «випадковість»: висота залежить від номера ґрати,
		# тож шар виглядає однаково при кожному кадрі й кожному запуску.
		var jitter: float = abs(sin(float(index) * 12.9898 + layer.phase))
		var height: float = layer.amplitude * (0.45 + jitter * 0.55)
		draw_rect(
			Rect2(Vector2(x - width * 0.5, baseline - height), Vector2(width, height)),
			layer.color
		)
		index += 1


func _draw_plate(plate: Rect2, flat: float, mapn: float) -> void:
	var view: Rect2 = _visible_rect()
	var far_y: float = Projector.project(Vector3(0.0, plate.position.y, 0.0)).y
	var near_y: float = Projector.project(Vector3(0.0, plate.end.y, 0.0)).y

	# Коли глибина схлопується, плита вироджується в лінію — і земля мусить
	# долити екран донизу, інакше під підлогою сайд-скрола зяяло б небо.
	var bottom: float = lerpf(near_y, view.end.y, flat)

	# Земля закінчується там, де закінчується прохідна зона (плюс невеликий
	# виступ). Інакше гравець упирається в невидиму стіну посеред підлоги,
	# яка тягнеться далі — найгірше відчуття, яке може дати межа рівня.
	# Тепер підлога просто обривається, а за нею немає нічого.
	var left: float = maxf(plate.position.x, _walk_bounds.position.x - EDGE_OVERHANG)
	var right: float = minf(plate.end.x, _walk_bounds.end.x + EDGE_OVERHANG)
	if right - left < 4.0:
		return

	var rect := Rect2(
		Vector2(left, far_y), Vector2(right - left, maxf(bottom - far_y, 2.0))
	)
	draw_rect(rect, _ground)

	# Смуга на дальньому краї: у трьох чвертях — далина, у профілі — стіна позаду.
	if mapn < 0.98:
		draw_rect(
			Rect2(Vector2(rect.position.x, far_y - 26.0), Vector2(rect.size.x, 26.0)),
			Color(_ground.darkened(0.35), 1.0 - mapn)
		)

	# Під підлогою — не діра, а темна порода. Порожній чорний низ екрана
	# читався як недомальована сцена.
	if flat > 0.5:
		draw_rect(
			Rect2(Vector2(view.position.x, far_y), Vector2(view.size.x, view.end.y - far_y)),
			Color(0.085, 0.08, 0.088)
		)

	# У Ниці підлога намальована, а не залита кольором.
	if _floor_texture != null and flat > 0.5:
		var fh: float = float(_floor_texture.get_height()) * 0.9
		var fw: float = float(_floor_texture.get_width()) * 0.9
		var i: int = int(floor(view.position.x / fw)) - 1
		while float(i) * fw <= view.end.x:
			draw_texture_rect(
				_floor_texture,
				Rect2(Vector2(float(i) * fw, far_y), Vector2(fw, fh)),
				false, Color(0.92, 0.92, 0.96)
			)
			i += 1

	# Кромка обриву: земля темніє перед самим краєм, за нею порожнеча.
	if flat > 0.5:
		var fade: float = 110.0
		for side: int in [0, 1]:
			var fx: float = left if side == 0 else right - fade
			draw_rect(
				Rect2(Vector2(fx, far_y), Vector2(fade, view.end.y - far_y)),
				Color(0.0, 0.0, 0.0, 0.6)
			)

	_draw_grid_on(plate, flat, mapn)

	# Обрис краю. Світ бога — архіпелаг плато, а не безкраїй простір.
	if mapn > 0.02:
		draw_rect(rect, Color(_accent, mapn * 0.75), false, 4.0)

	# Лінію підлоги малюємо тільки поки підлоги немає намальованої.
	if flat > 0.02 and _floor_texture == null:
		draw_line(
			Vector2(rect.position.x, far_y), Vector2(rect.end.x, far_y),
			Color(_accent, flat * 0.8), 3.0
		)


func _draw_grid_on(plate: Rect2, flat: float, mapn: float) -> void:
	# Сітка гасне разом зі сплющенням у силует — видно, як іде розташування.
	# І навпаки розгоряється на карті: там сітка доречна, це креслення.
	var alpha: float = (1.0 - flat) * 0.20 * (1.0 - mapn) + mapn * 0.30
	if alpha <= 0.005:
		return
	var col := Color(_accent.r, _accent.g, _accent.b, alpha)
	var step: float = WorldSpace.CELL * 2.0

	var y: float = ceilf(plate.position.y / step) * step
	while y <= plate.end.y:
		draw_line(
			Projector.project(Vector3(plate.position.x, y, 0.0)),
			Projector.project(Vector3(plate.end.x, y, 0.0)), col, 2.0
		)
		y += step

	var x: float = ceilf(plate.position.x / step) * step
	while x <= plate.end.x:
		draw_line(
			Projector.project(Vector3(x, plate.position.y, 0.0)),
			Projector.project(Vector3(x, plate.end.y, 0.0)), col, 2.0
		)
		x += step


func _draw_prop(prop: Prop, flat: float, mapn: float) -> void:
	var hw: float = prop.size.x * 0.5
	var hd: float = prop.size.y * 0.5
	var base: Vector3 = prop.pos

	# Що площинніший світ, то ближче пропси до силуету: у Ниці світлі коробки
	# б'ються з мальованим тлом, бо там усе читається тінню.
	# Силует задано явним кольором, а не ланцюжком lightened() від палітри:
	# так результат не залежить від того, що саме зараз у палітрі.
	const SILHOUETTE := Color(0.11, 0.11, 0.13)
	var side_col: Color = _ground.lightened(0.18 + prop.tint * 0.12).darkened(0.35)
	var face_col: Color = _ground.lightened(0.30 + prop.tint * 0.18)
	var top_col: Color = _ground.lightened(0.52 + prop.tint * 0.20)
	side_col = side_col.lerp(SILHOUETTE.darkened(0.3), flat)
	face_col = face_col.lerp(SILHOUETTE, flat)
	top_col = top_col.lerp(SILHOUETTE.lightened(0.06), flat)

	# У сірому боксі одразу видно, крізь що можна пройти.
	var pass_through: float = 1.0 if prop.solid else 0.45

	# На карті висоту не видно — її треба ЧИТАТИ. Чим вища споруда, тим
	# темніша її основа: звичайна рельєфна карта, зрозуміла без пояснень.
	var elevation: float = clampf(prop.height / 430.0, 0.0, 1.0)
	top_col = top_col.lerp(_ground.darkened(0.28), elevation * mapn)

	var top: PackedVector2Array = PackedVector2Array([
		Projector.project(base + Vector3(-hw, -hd, prop.height)),
		Projector.project(base + Vector3(hw, -hd, prop.height)),
		Projector.project(base + Vector3(hw, hd, prop.height)),
		Projector.project(base + Vector3(-hw, hd, prop.height)),
	])
	var front: PackedVector2Array = PackedVector2Array([
		Projector.project(base + Vector3(-hw, hd, prop.height)),
		Projector.project(base + Vector3(hw, hd, prop.height)),
		Projector.project(base + Vector3(hw, hd, 0.0)),
		Projector.project(base + Vector3(-hw, hd, 0.0)),
	])
	var side: PackedVector2Array = PackedVector2Array([
		Projector.project(base + Vector3(hw, -hd, prop.height)),
		Projector.project(base + Vector3(hw, hd, prop.height)),
		Projector.project(base + Vector3(hw, hd, 0.0)),
		Projector.project(base + Vector3(hw, -hd, 0.0)),
	])

	if flat < 0.98 and mapn < 0.99:
		draw_colored_polygon(side, Color(side_col, (1.0 - flat) * (1.0 - mapn) * pass_through))
	if flat < 0.98:
		draw_colored_polygon(top, Color(top_col, (1.0 - flat * 0.85) * pass_through))

	# У площинному світі передня грань — це весь пропс, і саме її видно.
	# Тому там, де є намальований камінь, кладемо його замість заливки.
	var textured: bool = flat > 0.5 and prop.solid and _ledge_texture != null
	if textured:
		var top_y: float = Projector.project(base + Vector3(0.0, 0.0, prop.height)).y
		var bottom_y: float = Projector.project(base).y
		draw_texture_rect(
			_ledge_texture,
			Rect2(Vector2(base.x - hw, top_y), Vector2(hw * 2.0, bottom_y - top_y)),
			false, Color(0.88, 0.88, 0.92)
		)
	elif mapn < 0.99:
		draw_colored_polygon(front, Color(face_col, (1.0 - mapn) * pass_through))

	# У силуетному світі пропси темні — але на що можна стати, гравець мусить
	# бачити. Тонка світла грань згори лишає їх читабельними, не роблячи
	# світлими коробками.
	if flat > 0.5 and prop.solid:
		var edge: Vector2 = Projector.project(base + Vector3(-hw, hd, prop.height))
		draw_line(
			edge, Projector.project(base + Vector3(hw, hd, prop.height)),
			Color(_ground.lightened(0.55), flat * 0.55), 2.0
		)

	if mapn > 0.02:
		var outline: PackedVector2Array = top.duplicate()
		outline.append(top[0])
		draw_polyline(
			outline, Color(_accent, mapn * (0.35 + elevation * 0.5)), 1.5 + elevation * 5.0
		)


func _draw_wanderer(w: Wanderer, flat: float, mapn: float) -> void:
	# Той самий закон, що й для пропсів: у площинному світі все читається тінню.
	var col: Color = _ground.lightened(0.62).lerp(Color(0.16, 0.16, 0.18), flat)
	var feet: Vector2 = Projector.project(w.pos)
	var head: Vector2 = Projector.project(w.pos + Vector3(0.0, 0.0, 78.0))

	if mapn < 0.99:
		draw_rect(
			Rect2(Vector2(feet.x - 13.0, head.y), Vector2(26.0, feet.y - head.y)),
			Color(col, 1.0 - mapn)
		)
	# На карті — крапка тушшю. Бог не бачить облич, тільки положення.
	if mapn > 0.02:
		draw_circle(feet, 8.0, Color(_accent, mapn * 0.85))


## Ворог. Найважливіше тут — ТЕЛЕГРАФ: зона майбутнього удару наливається
## кольором ще до самого удару, і гравець устигає відскочити. Без цього бій
## читається як несправедливий, скільки б кадрів анімації в нього не було.
func _draw_enemy(enemy: Enemy, _flat: float, mapn: float) -> void:
	if mapn > 0.9:
		return

	var alive: bool = enemy.body.is_alive()
	var fade: float = (1.0 - enemy.death_fade) if not alive else 1.0
	if fade <= 0.01:
		return

	var feet: Vector2 = Projector.project(enemy.pos)
	var head: Vector2 = Projector.project(enemy.pos + Vector3(0.0, 0.0, 104.0))
	var col: Color = Color("8d3b3b")

	# Тінь.
	draw_set_transform(Projector.project(Vector3(enemy.pos.x, enemy.pos.y, 0.0)),
		0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 30.0, Color(0.0, 0.0, 0.0, 0.3 * fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var flash: bool = enemy.body.invuln_left > 0.32
	var body_col: Color = Color.WHITE if flash else col
	var rect := Rect2(
		Vector2(feet.x - 24.0, head.y), Vector2(48.0, feet.y - head.y)
	)
	draw_rect(rect, Color(body_col, fade))
	draw_rect(rect, Color(body_col.darkened(0.45), fade), false, 3.0)

	# Життя ворога — риски над головою.
	if alive:
		for i: int in enemy.body.max_hp:
			var filled: bool = i < enemy.body.hp
			draw_rect(
				Rect2(Vector2(feet.x - 24.0 + float(i) * 17.0, head.y - 18.0), Vector2(13.0, 5.0)),
				Color(col.lightened(0.5) if filled else col.darkened(0.6), fade)
			)


func _draw_player(flat: float, mapn: float) -> void:
	var p: Vector3 = _mover.position

	# Тінь на землі. У профілі стискається в риску, на карті зникає:
	# у Висі світло звідусіль, тіней немає.
	if mapn < 0.9:
		var shadow_center: Vector2 = Projector.project(Vector3(p.x, p.y, 0.0))
		var lift: float = clampf(p.z / 260.0, 0.0, 1.0)
		draw_set_transform(shadow_center, 0.0, Vector2(1.0, lerpf(0.47, 0.09, flat)))
		draw_circle(
			Vector2.ZERO, 34.0 * (1.0 - lift * 0.35),
			Color(0.0, 0.0, 0.0, 0.35 * (1.0 - lift * 0.5) * (1.0 - mapn))
		)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var feet: Vector2 = Projector.project(p)
	var head: Vector2 = Projector.project(p + Vector3(0.0, 0.0, PLAYER_HEIGHT))

	if mapn < 0.99:
		var body := Rect2(
			Vector2(feet.x - PLAYER_HALF_WIDTH, head.y),
			Vector2(PLAYER_HALF_WIDTH * 2.0, feet.y - head.y)
		)
		var tint: Color = _accent
		if _hero.invuln_left > 0.0:
			# Мигтіння невразливості: видно і те, що влучили, і те, що зараз не вб\'ють.
			tint = _accent.lerp(Color.WHITE, 0.5 + 0.5 * sin(_hero.invuln_left * 60.0))
		draw_rect(body, Color(tint, 1.0 - mapn))
		draw_rect(body, Color(tint.darkened(0.5), 1.0 - mapn), false, 3.0)

		var eye_x: float = feet.x + _mover.facing * PLAYER_HALF_WIDTH * 0.45
		draw_line(
			Vector2(eye_x, lerpf(feet.y, head.y, 0.78)),
			Vector2(eye_x, lerpf(feet.y, head.y, 0.62)),
			Color(_sky, 1.0 - mapn), 5.0
		)

	# На карті ти — не тіло, а мітка. Бог не має тіла в кадрі.
	if mapn > 0.02:
		draw_circle(feet, 26.0, Color(_ground.lightened(0.75), mapn))
		draw_circle(feet, 14.0, Color(_accent, mapn))
		draw_arc(feet, 46.0, 0.0, TAU, 48, Color(_accent, mapn * 0.7), 3.5)


func _visible_rect() -> Rect2:
	var size: Vector2 = get_viewport_rect().size / _camera.zoom
	return Rect2(_camera.position - size * 0.75, size * 1.5)
