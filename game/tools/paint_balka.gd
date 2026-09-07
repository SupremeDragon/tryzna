extends SceneTree
## Малює Тиху Балку й зберігає її окремою сценою.
##
## Карта Міші лежить у scenes/plyn_map.tscn і НЕ чіпається: своя пишеться поруч.
##
## Малювати кодом і малювати мишею — не суперники. Мишею зручно ставити те, що
## бачиш; кодом зручно те, що має правило: узлісся, яке густішає до краю, або
## дорога, яка йде від воріт до майдану. Тому тут описані саме правила.
##
## Запуск:  Godot --headless --path game --script res://tools/paint_balka.gd

const TILE_SET := "res://art/plyn/terrain.tres"
const OUT := "res://scenes/balka.tscn"

## ЩО лежить на клітинці. Без цього дерева сідали у воду, а паркан перегороджував
## дорогу: перевірки «чи вже щось стоїть» замало, треба знати ЩО саме стоїть.
enum Kind { NONE, GRASS, DIRT, WATER, SAND, STONE, YARD, BUILDING }

# Плитки. Номери — з art/plyn/atlas_terrain-склад.txt, у вигляді (стовпець, рядок).
const GRASS: Array[Vector2i] = [
	Vector2i(3, 0), Vector2i(5, 0), Vector2i(7, 0),
	Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1),
	Vector2i(7, 2), Vector2i(9, 2), Vector2i(0, 3), Vector2i(2, 3),
]
const GRASS_RICH: Array[Vector2i] = [
	Vector2i(2, 0), Vector2i(4, 0), Vector2i(0, 1),   # з кущами
	Vector2i(8, 2),                                    # з квітами
	Vector2i(1, 1), Vector2i(4, 3), Vector2i(7, 9),    # з брилами
]
const DIRT: Array[Vector2i] = [
	Vector2i(5, 2), Vector2i(6, 2), Vector2i(5, 3), Vector2i(6, 3),
	Vector2i(7, 3), Vector2i(9, 3), Vector2i(0, 4), Vector2i(1, 4),
]
const DIRT_STONY := Vector2i(8, 3)
const SAND: Array[Vector2i] = [
	Vector2i(7, 1), Vector2i(8, 1), Vector2i(9, 1),
	Vector2i(0, 8), Vector2i(1, 8), Vector2i(2, 8), Vector2i(3, 8),
]
const SHORE: Array[Vector2i] = [Vector2i(1, 3), Vector2i(8, 4), Vector2i(9, 4)]
const WATER: Array[Vector2i] = [
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
	Vector2i(3, 7), Vector2i(4, 7), Vector2i(6, 7), Vector2i(8, 7),
]
const STONE: Array[Vector2i] = [
	Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5),
	Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5), Vector2i(3, 6),
]
const FENCE: Array[Vector2i] = [
	Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
	Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4),
]
const TREES: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(8, 0), Vector2i(9, 0), Vector2i(2, 1),
]
const FIR := Vector2i(3, 1)
const BUSH := Vector2i(0, 0)

const HOUSES: Array[Vector2i] = [
	Vector2i(4, 9), Vector2i(5, 9), Vector2i(6, 9), Vector2i(6, 8),
]
const WELL := Vector2i(3, 9)
const BARN: Array[Vector2i] = [Vector2i(0, 9), Vector2i(1, 9), Vector2i(2, 9)]
const HAY: Array[Vector2i] = [Vector2i(0, 7), Vector2i(1, 7)]
const CHEST: Array[Vector2i] = [Vector2i(0, 6), Vector2i(1, 6)]

## Розмір поля в клітинках від центру.
const REACH: int = 28
## Півширина дороги: 0 і 1, тобто дві клітинки.
const ROAD_HALF: int = 1

var _rng := RandomNumberGenerator.new()
var _ground: TileMapLayer
var _props: TileMapLayer
## Vector2i -> Kind. Пам'ять карти: хто вже зайняв клітинку і чим саме.
var _kind: Dictionary = {}


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

	print("карта -> %s, землі %d, предметів %d"
		% [OUT, _ground.get_used_cells().size(), _props.get_used_cells().size()])
	quit()


func _pick(from: Array[Vector2i]) -> Vector2i:
	return from[_rng.randi() % from.size()]


func _put(at: Vector2i, tile: Vector2i, kind: Kind) -> void:
	_ground.set_cell(at, 0, tile)
	_kind[at] = kind


func _kind_at(at: Vector2i) -> Kind:
	return _kind.get(at, Kind.NONE)


## Чи можна тут ростити. Тільки трава — і жодного сусіда-води: дерево на самому
## березі виглядає так, ніби воно росте з ополонки.
func _plantable(at: Vector2i) -> bool:
	if _kind_at(at) != Kind.GRASS:
		return false
	if _props.get_cell_source_id(at) != -1:
		return false
	for step: Vector2i in [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]:
		if _kind_at(at + step) == Kind.WATER:
			return false
	return true


func _on_road(at: Vector2i) -> bool:
	return (at.x >= 0 and at.x <= ROAD_HALF) or (at.y >= 0 and at.y <= ROAD_HALF)


func _paint() -> void:
	_paint_field()
	_paint_pond()
	_paint_roads()
	_paint_square()
	_paint_village()
	_paint_forest()


func _paint_field() -> void:
	for y: int in range(-REACH, REACH + 1):
		for x: int in range(-REACH, REACH + 1):
			if absi(x) + absi(y) > REACH:
				continue
			# Дрібнота на землі — рідко, інакше поле рябіє.
			var tile: Vector2i = (
				_pick(GRASS_RICH) if _rng.randf() < 0.06 else _pick(GRASS)
			)
			_put(Vector2i(x, y), tile, Kind.GRASS)


func _paint_pond() -> void:
	# Спершу вода, потім по її межі — берег. Так берег лягає точно там, де
	# треба, і не доводиться перелічувати клітинки руками.
	var pond := Vector2i(-11, 7)
	for y: int in range(-7, 8):
		for x: int in range(-7, 8):
			var at: Vector2i = pond + Vector2i(x, y)
			if absi(x) + absi(y) <= 4:
				_put(at, _pick(WATER), Kind.WATER)
	for y2: int in range(-8, 9):
		for x2: int in range(-8, 9):
			var at2: Vector2i = pond + Vector2i(x2, y2)
			var d: int = absi(x2) + absi(y2)
			if (d == 5 or d == 6) and _kind_at(at2) == Kind.GRASS:
				_put(at2, _pick(SHORE), Kind.SAND)


func _paint_roads() -> void:
	# Головна з півдня на північ, поперечна зі сходу на захід. Смуга завширшки
	# у дві клітинки: одна читається як стежка, три — як площа.
	for y: int in range(-REACH + 3, REACH - 2):
		for w: int in range(0, ROAD_HALF + 1):
			if _kind_at(Vector2i(w, y)) == Kind.GRASS:
				_put(Vector2i(w, y), _pick(DIRT), Kind.DIRT)
	for x: int in range(-REACH + 3, REACH - 2):
		for w2: int in range(0, ROAD_HALF + 1):
			if _kind_at(Vector2i(x, w2)) == Kind.GRASS:
				_put(Vector2i(x, w2), _pick(DIRT), Kind.DIRT)

	# Каміння на дорозі — сліди того, що нею їздять.
	for i: int in range(20):
		var along: int = _rng.randi_range(-REACH + 4, REACH - 4)
		var at: Vector2i = (
			Vector2i(_rng.randi_range(0, ROAD_HALF), along) if _rng.randf() < 0.5
			else Vector2i(along, _rng.randi_range(0, ROAD_HALF))
		)
		if _kind_at(at) == Kind.DIRT:
			_put(at, DIRT_STONY, Kind.DIRT)


func _paint_square() -> void:
	# Брук на перехресті. Центр села — це місце, де сходяться дороги.
	for y: int in range(-3, 5):
		for x: int in range(-3, 5):
			var at := Vector2i(x, y)
			if absi(x) + absi(y) <= 5 and _kind_at(at) != Kind.WATER:
				_put(at, _pick(STONE), Kind.STONE)

	# Криниця посеред майдану — те, до чого в селі сходяться всі.
	_props.set_cell(Vector2i(3, 3), 0, WELL)
	_kind[Vector2i(3, 3)] = Kind.BUILDING


func _paint_village() -> void:
	# Двір: будівля з торця, паркан по двох сторонах, і все це ПОРУЧ із дорогою,
	# але не НА ній. У селі не будують у полі — будують при дорозі.
	var yards: Array[Vector2i] = [
		Vector2i(4, -8), Vector2i(4, -14), Vector2i(-6, -8), Vector2i(-6, -14),
		Vector2i(4, 8), Vector2i(4, 14), Vector2i(-6, 8), Vector2i(-6, 14),
		Vector2i(8, 4), Vector2i(14, 4), Vector2i(-12, 4), Vector2i(-18, 4),
		Vector2i(8, -6), Vector2i(14, -6),
	]

	for i: int in yards.size():
		_build_yard(yards[i], i)


func _build_yard(corner: Vector2i, index: int) -> void:
	# Спершу перевіряємо ВЕСЬ двір, і тільки потім ставимо. Інакше половина
	# паркана лягає, а половина впирається в дорогу — і виходить огорожа
	# нізвідки в нікуди.
	var cells: Array[Vector2i] = []
	for k: int in range(4):
		cells.append(corner + Vector2i(k, 0))
		cells.append(corner + Vector2i(0, k))
	for at: Vector2i in cells:
		if _kind_at(at) != Kind.GRASS or _on_road(at):
			return

	for at2: Vector2i in cells:
		_put(at2, _pick(FENCE), Kind.YARD)

	# Будівля стоїть у глибині двору, спиною до кута.
	var house_at: Vector2i = corner + Vector2i(2, 2)
	if _kind_at(house_at) == Kind.GRASS and not _on_road(house_at):
		var what: Vector2i = HOUSES[index % HOUSES.size()]
		if index % 5 == 4:
			what = _pick(BARN)
		_props.set_cell(house_at, 0, what)
		_kind[house_at] = Kind.BUILDING

		# Дрібнота у дворі: сіно чи скриня. Не в кожному — інакше село
		# виглядає як склад.
		var yard_spot: Vector2i = corner + Vector2i(1, 2)
		if index % 3 == 0 and _kind_at(yard_spot) == Kind.GRASS:
			_props.set_cell(yard_spot, 0, _pick(HAY) if index % 2 == 0 else _pick(CHEST))
			_kind[yard_spot] = Kind.BUILDING


func _paint_forest() -> void:
	# Ліс густішає до краю. Це і межа світу, і причина, чому вона там: стіну
	# ставити не треба, у ліс просто не йдуть.
	for y: int in range(-REACH, REACH + 1):
		for x: int in range(-REACH, REACH + 1):
			var at := Vector2i(x, y)
			var far: int = absi(x) + absi(y)
			if far > REACH or not _plantable(at):
				continue
			var edge: float = float(far) / float(REACH)
			if _rng.randf() > pow(maxf(edge - 0.58, 0.0) / 0.42, 1.5):
				continue
			_props.set_cell(at, 0, FIR if _rng.randf() < 0.3 else _pick(TREES))

	# Гай і кущі всередині — щоб поле не було голим полем.
	for i: int in range(90):
		var at2 := Vector2i(_rng.randi_range(-22, 22), _rng.randi_range(-22, 22))
		if absi(at2.x) + absi(at2.y) > 22 or not _plantable(at2):
			continue
		_props.set_cell(at2, 0, BUSH if _rng.randf() < 0.45 else _pick(TREES))
