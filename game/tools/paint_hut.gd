extends SceneTree
## Малює нутрощі хати й зберігає їх окремою сценою.
##
## Набір Міші — це надвір'я: трава, вода, дерева, кубики. Кімнати в ньому немає
## жодної, тож нутрощі складені з того ж таки: долівка з ґрунту, стіни з
## дерев'яних кубів, вогнище й мотлох.
##
## Стіни малюються ТІЛЬКИ з двох дальніх боків. Це не лінощі: ближні стіни
## затуляли б саму кімнату, і гравець дивився б на дах замість того, що
## всередині. Так роблять усі ізометричні інтер'єри, і саме тому вони на вигляд
## «розрізані».
##
## Запуск:  Godot --headless --path game --script res://tools/paint_hut.gd

const TILE_SET := "res://art/plyn/terrain.tres"
const OUT := "res://scenes/hut.tscn"

## Розмір кімнати в клітинках.
const ROOM := Vector2i(7, 6)

const FLOOR: Array[Vector2i] = [
	Vector2i(1, 2), Vector2i(2, 2), Vector2i(11, 2), Vector2i(0, 3), Vector2i(1, 3),
]
const FLOOR_WORN: Array[Vector2i] = [Vector2i(2, 3), Vector2i(4, 3)]
## Поріг: камінь на виході, щоб було видно, куди йти. Спершу я взяв сюди 3-6 і
## отримав калюжу посеред хати: 3-6 — це берег, і половина плитки в ньому вода.
const DOORSTEP := Vector2i(2, 4)

const WALL: Array[Vector2i] = [Vector2i(5, 7), Vector2i(6, 7)]
const WALL_WINDOW := Vector2i(8, 7)
const WALL_DOOR := Vector2i(7, 7)

const HEARTH := Vector2i(10, 8)
const BARREL := Vector2i(7, 8)
const BOX := Vector2i(8, 8)
const CHEST: Array[Vector2i] = [Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5)]

var _rng := RandomNumberGenerator.new()
var _ground: TileMapLayer
var _props: TileMapLayer


func _init() -> void:
	_rng.seed = 1703

	var set: TileSet = load(TILE_SET) as TileSet
	if set == null:
		push_error("Немає набору: " + TILE_SET)
		quit(1)
		return

	var root := Node2D.new()
	root.name = "Хата"

	# Тло. Без нього кімната висить у сірій порожнечі рушія, і замість «я в
	# хаті» виходить «я на летючому острівці».
	#
	# Це ВЕЛИЧЕЗНИЙ прямокутник у самій сцені, а не окремий шар полотна:
	# CanvasLayer не успадковує видимість батька, і, ховаючи хату, він лишався
	# б на екрані й затуляв двір.
	var dark := ColorRect.new()
	dark.name = "Тло"
	dark.color = Color(0.07, 0.06, 0.05)
	dark.size = Vector2(20000.0, 20000.0)
	dark.position = Vector2(-10000.0, -10000.0)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dark)

	_ground = _layer(root, "Земля", set, false)
	_props = _layer(root, "Предмети", set, true)

	# Присмерк. Надворі сонце, у хаті — вогнище й вікна; без цього кімната
	# світиться так само яскраво, як подвір'я, і не читається як «всередині».
	var dusk := CanvasModulate.new()
	dusk.name = "Присмерк"
	dusk.color = Color(0.74, 0.66, 0.60)
	root.add_child(dusk)

	_paint()

	# Поріг — місце, де гравець опиняється, увійшовши, і звідки виходить.
	var step := Marker2D.new()
	step.name = "Поріг"
	step.position = _ground.map_to_local(Vector2i(ROOM.x - 1, ROOM.y - 1))
	root.add_child(step)

	_own(root, root)

	var packed := PackedScene.new()
	if packed.pack(root) != OK or ResourceSaver.save(packed, OUT) != OK:
		push_error("Не збереглося: " + OUT)
		quit(1)
		return

	print("хата -> %s, землі %d, предметів %d" % [
		OUT, _ground.get_used_cells().size(), _props.get_used_cells().size(),
	])
	quit()


func _paint() -> void:
	for y: int in range(ROOM.y):
		for x: int in range(ROOM.x):
			var at := Vector2i(x, y)
			var tile: Vector2i = (
				_pick(FLOOR_WORN) if _rng.randf() < 0.16 else _pick(FLOOR)
			)
			_ground.set_cell(at, 0, tile)

	# Дальні стіни: ряд перед кімнатою по кожній осі, плюс спільний ріг.
	for x2: int in range(-1, ROOM.x):
		_ground.set_cell(Vector2i(x2, -1), 0, _pick(FLOOR))
		_props.set_cell(Vector2i(x2, -1), 0, _wall(x2, 2))
	for y2: int in range(0, ROOM.y):
		_ground.set_cell(Vector2i(-1, y2), 0, _pick(FLOOR))
		_props.set_cell(Vector2i(-1, y2), 0, _wall(y2, 3))

	# Вогнище в дальньому розі — те, довкола чого кімната й будується.
	_props.set_cell(Vector2i(1, 1), 0, HEARTH)

	# Мотлох попід стінами. Посеред кімнати він заважав би ходити.
	_props.set_cell(Vector2i(ROOM.x - 1, 0), 0, _pick(CHEST))
	_props.set_cell(Vector2i(ROOM.x - 1, 1), 0, BARREL)
	_props.set_cell(Vector2i(0, ROOM.y - 2), 0, BOX)
	_props.set_cell(Vector2i(4, 0), 0, BARREL)

	# Поріг видно здалеку: світліша плитка на виході.
	_ground.set_cell(Vector2i(ROOM.x - 1, ROOM.y - 1), 0, DOORSTEP)


## Плитка стіни. Вікно кожні кілька кубів, двері раз на стіну — глуха стіна
## від рогу до рогу читається як паркан, а не як житло.
func _wall(k: int, window_every: int) -> Vector2i:
	if k == 1:
		return WALL_DOOR
	if k > 0 and k % window_every == 0:
		return WALL_WINDOW
	return _pick(WALL)


func _own(root: Node, node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		_own(root, child)


func _layer(root: Node2D, name: String, set: TileSet, sorted: bool) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = name
	layer.tile_set = set
	layer.y_sort_enabled = sorted
	root.add_child(layer)
	return layer


func _pick(from: Array[Vector2i]) -> Vector2i:
	return from[_rng.randi() % from.size()]
