extends Node
## Проба: як із наявних плиток скласти будинок, що не соромно показати.
##
## Це чернетка, а не частина гри. Варіанти стоять в один ряд зліва направо, і
## по знімку видно, який із них живий, а який — купа ящиків.
##
## Запуск:  Godot --path game --resolution 1600x600 res://tests/probe_house.tscn

const TILE_SET := "res://art/plyn/terrain.tres"
const CUBE_LIFT: float = 54.0

const GRASS: Array[Vector2i] = [
	Vector2i(3, 0), Vector2i(5, 0), Vector2i(2, 1), Vector2i(3, 1),
	Vector2i(4, 1), Vector2i(3, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(8, 2),
]
const HOUSE: Array[Vector2i] = [Vector2i(10, 7), Vector2i(11, 7), Vector2i(0, 8)]
const HUT := Vector2i(2, 7)
const CRATE: Array[Vector2i] = [
	Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7), Vector2i(8, 7),
]
const STONE_BLOCK := Vector2i(9, 7)
const HAY: Array[Vector2i] = [Vector2i(0, 7), Vector2i(1, 7)]
const BARREL := Vector2i(7, 8)
const BOX := Vector2i(8, 8)

var _rng := RandomNumberGenerator.new()
var _ground: TileMapLayer
var _props: TileMapLayer
var _upper: TileMapLayer


func _ready() -> void:
	_rng.seed = 7

	var set: TileSet = load(TILE_SET) as TileSet
	var root := Node2D.new()
	add_child(root)

	var cam := Camera2D.new()
	cam.zoom = Vector2(0.42, 0.42)
	cam.position = Vector2(0.0, -120.0)
	root.add_child(cam)

	_ground = _layer(root, set, Vector2.ZERO)
	_props = _layer(root, set, Vector2.ZERO)
	_upper = _layer(root, set, Vector2(0.0, -CUBE_LIFT))

	for y: int in range(-14, 15):
		for x: int in range(-14, 15):
			_ground.set_cell(Vector2i(x, y), 0, GRASS[_rng.randi() % GRASS.size()])

	# А. Два будинки в ряд на камʼяній основі. Мірка, з чим порівнювати решту.
	_at(-12, 12, func(o: Vector2i) -> void:
		_base(o, Vector2i(2, 1), HOUSE[2])
	)

	# Б. Кутом: довша частина вздовж x, коротша вздовж y.
	_at(-8, 8, func(o: Vector2i) -> void:
		_base(o, Vector2i(2, 1), HOUSE[2])
		_props.set_cell(o + Vector2i(0, 1), 0, STONE_BLOCK)
		_upper.set_cell(o + Vector2i(0, 1), 0, HOUSE[2])
	)

	# В. Квадрат 2x2 на основі — чи не завелико.
	_at(-4, 4, func(o: Vector2i) -> void:
		_base(o, Vector2i(2, 2), HOUSE[1])
	)

	# Г. Двір цілком: житло, комора, бочки, ящики.
	_at(0, 0, func(o: Vector2i) -> void:
		_base(o, Vector2i(2, 1), HOUSE[0])
		_props.set_cell(o + Vector2i(0, 3), 0, HUT)
		_props.set_cell(o + Vector2i(2, 2), 0, BARREL)
		_props.set_cell(o + Vector2i(1, 2), 0, BOX)
	)

	# Ґ. Два вздовж y на основі.
	_at(5, -5, func(o: Vector2i) -> void:
		_base(o, Vector2i(1, 2), HOUSE[1])
	)

	# Д. Без основи, три вряд — чи виглядає як довга хата.
	_at(9, -9, func(o: Vector2i) -> void:
		for i2: int in range(3):
			_props.set_cell(o + Vector2i(i2, 0), 0, HOUSE[0])
	)

	for i: int in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"res://../builds/shots/14-house-probe.png"
	)
	print("знято: 14-house-probe.png")
	get_tree().quit()


func _layer(root: Node2D, set: TileSet, offset: Vector2) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = set
	layer.position = offset
	layer.y_sort_enabled = offset != Vector2.ZERO or root.get_child_count() > 1
	root.add_child(layer)
	return layer


func _at(x: int, y: int, build: Callable) -> void:
	build.call(Vector2i(x, y))


## Будівля: камʼяна основа першим ярусом, житло другим.
##
## Плитки 10-7, 11-7 і 0-8 — це не дахи, а ЦІЛІ будиночки, з дахом і стінами
## разом. Я довго ставив їх поверх ящиків, ніби це дахи, — звідси й бралося
## відчуття, що будинок стоїть на купі коробок.
func _base(corner: Vector2i, size: Vector2i, house: Vector2i) -> void:
	for y: int in range(size.y):
		for x: int in range(size.x):
			var at: Vector2i = corner + Vector2i(x, y)
			_props.set_cell(at, 0, STONE_BLOCK)
			_upper.set_cell(at, 0, house)
