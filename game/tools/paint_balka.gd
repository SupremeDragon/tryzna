extends SceneTree
## Малює Тиху Балку й зберігає її окремою сценою.
##
## Карта Міші лежить у scenes/plyn_map.tscn і НЕ чіпається: своя тут пишеться
## поруч, у scenes/balka.tscn. Дві карти краще за одну зіпсовану.
##
## Малювати кодом і малювати мишею — не суперники. Мишею зручно ставити те, що
## бачиш; кодом зручно те, що має правило: узлісся, яке густішає до краю,
## або дорога, яка йде від воріт до майдану. Тому тут описані саме правила, а
## не координати кожної клітинки.
##
## Запуск:  Godot --headless --path game --script res://tools/paint_balka.gd

const TILE_SET := "res://art/plyn/terrain.tres"
const OUT := "res://scenes/balka.tscn"

# Плитки. Номери — з art/plyn/atlas_terrain-склад.txt.
const GRASS: Array[Vector2i] = [
	Vector2i(3, 0), Vector2i(5, 0), Vector2i(7, 0),
	Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1),
	Vector2i(7, 2), Vector2i(9, 2), Vector2i(0, 3), Vector2i(2, 3), Vector2i(3, 3),
]
const GRASS_RICH: Array[Vector2i] = [
	Vector2i(2, 0), Vector2i(4, 0), Vector2i(0, 1),   # з кущами
	Vector2i(8, 2),                                    # з квітами
	Vector2i(1, 1), Vector2i(4, 3), Vector2i(0, 5),    # з брилами
]
const DIRT: Array[Vector2i] = [
	Vector2i(5, 2), Vector2i(6, 2), Vector2i(5, 3), Vector2i(6, 3),
	Vector2i(7, 3), Vector2i(9, 3), Vector2i(0, 4), Vector2i(1, 4),
]
const DIRT_STONY := Vector2i(8, 3)
const SAND: Array[Vector2i] = [Vector2i(7, 1), Vector2i(8, 1), Vector2i(9, 1)]
const SHORE: Array[Vector2i] = [Vector2i(1, 3), Vector2i(8, 4), Vector2i(9, 4)]
const WATER: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]
const STONE: Array[Vector2i] = [Vector2i(3, 2), Vector2i(4, 2)]
const FENCE: Array[Vector2i] = [
	Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
	Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4),
]
const TREES: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(8, 0), Vector2i(9, 0), Vector2i(2, 1),
]
const FIR := Vector2i(3, 1)
const BUSH := Vector2i(0, 0)

## Розмір поля в клітинках від центру.
const REACH: int = 26

var _rng := RandomNumberGenerator.new()
var _ground: TileMapLayer
var _props: TileMapLayer


func _init() -> void:
	_rng.seed = 20260907

	var set: TileSet = load(TILE_SET) as TileSet
	if set == null:
		push_error("Немає набору: " + TILE_SET)
		quit(1)
		return

	var root := Node2D.new()
	root.name = "Балка"

	var cam := Camera2D.new()
	cam.name = "Камера"
	cam.zoom = Vector2(0.22, 0.22)
	root.add_child(cam)

	_ground = TileMapLayer.new()
	_ground.name = "Земля"
	_ground.tile_set = set
	root.add_child(_ground)

	_props = TileMapLayer.new()
	_props.name = "Предмети"
	_props.tile_set = set
	_props.y_sort_enabled = true
	root.add_child(_props)

	_paint()

	for child: Node in root.get_children():
		child.owner = root

	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("Не зібралося в сцену")
		quit(1)
		return
	if ResourceSaver.save(packed, OUT) != OK:
		push_error("Не збереглося: " + OUT)
		quit(1)
		return

	print("карта -> %s, клітинок землі %d, предметів %d"
		% [OUT, _ground.get_used_cells().size(), _props.get_used_cells().size()])
	quit()


func _pick(from: Array[Vector2i]) -> Vector2i:
	return from[_rng.randi() % from.size()]


func _put_ground(at: Vector2i, tile: Vector2i) -> void:
	_ground.set_cell(at, 0, tile)


func _paint() -> void:
	# --- поле -----------------------------------------------------------------
	# Ромб, а не квадрат: в ізометрії квадрат у клітинках виглядає ромбом на
	# екрані й навпаки. Хочемо, щоб на екрані поле було широким і низьким.
	for y: int in range(-REACH, REACH + 1):
		for x: int in range(-REACH, REACH + 1):
			if absi(x) + absi(y) > REACH:
				continue
			var tile: Vector2i = _pick(GRASS)
			# Дрібнота на землі — рідко, інакше поле рябіє.
			if _rng.randf() < 0.06:
				tile = _pick(GRASS_RICH)
			_put_ground(Vector2i(x, y), tile)

	# --- ставок ---------------------------------------------------------------
	# Спершу вода, потім по її межі — берег. Так берег точно ляже там, де треба,
	# і не доведеться перелічувати клітинки руками.
	var pond := Vector2i(-10, 6)
	for y: int in range(-6, 7):
		for x: int in range(-6, 7):
			var at: Vector2i = pond + Vector2i(x, y)
			if absi(x) + absi(y) <= 4:
				_put_ground(at, _pick(WATER))
	for y2: int in range(-7, 8):
		for x2: int in range(-7, 8):
			var at2: Vector2i = pond + Vector2i(x2, y2)
			var d: int = absi(x2) + absi(y2)
			if d == 5 or d == 6:
				_put_ground(at2, _pick(SHORE))

	# --- дороги ---------------------------------------------------------------
	# Головна з півдня до майдану, поперечна через усе село. Смуга завширшки
	# у дві клітинки: одна читається як стежка, три — як площа.
	for y3: int in range(-REACH + 3, REACH - 2):
		for w: int in range(0, 2):
			_put_ground(Vector2i(w, y3), _pick(DIRT))
	for x3: int in range(-REACH + 4, REACH - 3):
		for w2: int in range(0, 2):
			_put_ground(Vector2i(x3, w2), _pick(DIRT))

	# Каміння на дорозі — сліди того, що нею їздять.
	for i: int in range(18):
		var along: int = _rng.randi_range(-REACH + 4, REACH - 4)
		if _rng.randf() < 0.5:
			_put_ground(Vector2i(_rng.randi_range(0, 1), along), DIRT_STONY)
		else:
			_put_ground(Vector2i(along, _rng.randi_range(0, 1)), DIRT_STONY)

	# --- майдан ---------------------------------------------------------------
	# Брук на перехресті. Центр села — це те місце, де сходяться дороги.
	for y4: int in range(-3, 4):
		for x4: int in range(-3, 4):
			if absi(x4) + absi(y4) <= 4:
				_put_ground(Vector2i(x4, y4), _pick(STONE))

	# --- піщана стежка до ставка ---------------------------------------------
	var from := Vector2i(-2, 2)
	for step: int in range(14):
		var t: float = float(step) / 13.0
		var at3 := Vector2i(
			int(round(lerpf(float(from.x), float(pond.x + 4), t))),
			int(round(lerpf(float(from.y), float(pond.y - 1), t)))
		)
		_put_ground(at3, _pick(SAND))

	# --- двори ----------------------------------------------------------------
	# Паркан включає власну землю, тому лягає на нижній шар. Двори стоять
	# уздовж доріг: у селі не будують у полі, будують при дорозі.
	for yard: Vector2i in [
		Vector2i(6, -7), Vector2i(-8, -8), Vector2i(8, 7), Vector2i(-7, -3),
	]:
		for k: int in range(5):
			_put_ground(yard + Vector2i(k, 0), _pick(FENCE))
			_put_ground(yard + Vector2i(0, k), _pick(FENCE))

	# --- узлісся --------------------------------------------------------------
	# Дерева густішають до краю. Це і межа світу, і причина, чому вона там:
	# стіну ставити не треба, у ліс просто не йдуть.
	for y5: int in range(-REACH, REACH + 1):
		for x5: int in range(-REACH, REACH + 1):
			var at4 := Vector2i(x5, y5)
			var reach: int = absi(x5) + absi(y5)
			if reach > REACH or _ground.get_cell_source_id(at4) == -1:
				continue
			# Дорогу, майдан і воду лишаємо вільними.
			if (absi(x5) <= 2 and absi(y5) < REACH) or (absi(y5) <= 2 and absi(x5) < REACH):
				continue
			var edge: float = float(reach) / float(REACH)
			if _rng.randf() > pow(maxf(edge - 0.55, 0.0) / 0.45, 1.6):
				continue
			_props.set_cell(at4, 0, FIR if _rng.randf() < 0.3 else _pick(TREES))

	# Гай і кущі всередині — щоб поле не було голим полем.
	for i2: int in range(70):
		var at5 := Vector2i(_rng.randi_range(-20, 20), _rng.randi_range(-20, 20))
		if absi(at5.x) + absi(at5.y) > 20:
			continue
		if absi(at5.x) <= 3 or absi(at5.y) <= 3:
			continue
		if _props.get_cell_source_id(at5) != -1:
			continue
		_props.set_cell(at5, 0, BUSH if _rng.randf() < 0.45 else _pick(TREES))
