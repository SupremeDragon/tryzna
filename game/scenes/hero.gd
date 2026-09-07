extends Node2D
## Герой, який ходить Балкою.
##
## Куди він дивиться. В ізометрії чотири напрямки руху, а ракурсів треба лише
## два: рух на +x і +y іде НА глядача, на -x і -y — ВІД нього, а ліворуч і
## праворуч дає дзеркало. Тому в аркуші два рядки, а не чотири.
##
## Що робить рушій, а що картинка. Ноги міняються місцями в самому аркуші
## (tools/make_hero.py), а похитування додається тут: якщо ним знехтувати,
## фігурка тупцює на місці, замість того щоб іти.
##
## Тінь окремим спрайтом і НЕ похитується разом із тілом. Тінь лежить на землі;
## коли вона стрибала вгору-вниз разом із героєм, він не йшов, а підлітав.

const SHEET := "res://art/plyn/hero.png"
const SHADOW := "res://art/plyn/shadow.png"
const FRAME := Vector2i(96, 136)

## Рядки аркуша. Повний перелік — art/plyn/hero-склад.txt.
const ROW_FRONT: int = 0
const ROW_BACK: int = 1

const SPEED: float = 260.0
## Скільки триває один крок. Менше — метушня, більше — герой ковзає.
const STEP_TIME: float = 0.20
## На скільки підстрибує тіло посеред кроку.
const BOB: float = 5.0

## Вода. Ті самі числа, що в малювальника: art/plyn/atlas_terrain-склад.txt.
const WATER: Array[Vector2i] = [
	Vector2i(8, 1), Vector2i(9, 1), Vector2i(10, 1),
	Vector2i(1, 6), Vector2i(2, 6), Vector2i(4, 6), Vector2i(6, 6), Vector2i(7, 6),
]

var _body: Sprite2D
var _shadow: Sprite2D
var _ground: TileMapLayer
var _props: TileMapLayer
var _clock: float = 0.0


func _ready() -> void:
	var sheet: Texture2D = load(SHEET) as Texture2D

	_shadow = Sprite2D.new()
	_shadow.name = "Тінь"
	_shadow.texture = load(SHADOW) as Texture2D
	_shadow.position = Vector2(0.0, -6.0)
	_shadow.scale = Vector2(1.2, 1.2)
	_shadow.modulate = Color(0.0, 0.0, 0.0, 0.40)
	add_child(_shadow)

	_body = Sprite2D.new()
	_body.name = "Тіло"
	_body.texture = _region(sheet, 0, ROW_FRONT)
	_body.centered = false
	_body.offset = Vector2(-FRAME.x / 2.0, -FRAME.y)
	# Без цього піксельні краї розмиваються, і герой стає ватяним поруч
	# із чіткими плитками.
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_body)

	var cam := Camera2D.new()
	cam.name = "Камера"
	cam.zoom = Vector2(0.6, 0.6)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	add_child(cam)

	# Шари карти шукаємо вгору по дереву: герой живе всередині шару «Предмети»,
	# щоб сортуватися по Y разом із деревами й хатами.
	var map: Node = get_parent()
	while map != null and not map.has_node("Земля"):
		map = map.get_parent()
	if map == null:
		push_error("Герой не всередині карти: нема шару «Земля»")
		return
	_ground = map.get_node("Земля") as TileMapLayer
	_props = map.get_node("Предмети") as TileMapLayer


func _process(delta: float) -> void:
	if _ground == null:
		return

	var dir: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)
	# Стрілки запасним ходом: у мапі дій прописані тільки WASD і геймпад, а
	# перше, що людина пробує в незнайомій грі, — саме стрілки.
	if dir == Vector2.ZERO:
		dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir.length() > 1.0:
		dir = dir.normalized()

	if dir != Vector2.ZERO:
		_slide(dir * SPEED * delta)
		_clock += delta
		# Дивиться туди, куди йде: вниз по екрану — обличчям, угору — спиною.
		var row: int = ROW_BACK if dir.y < -0.1 else ROW_FRONT
		var frame: int = 0 if fmod(_clock, STEP_TIME * 2.0) < STEP_TIME else 1
		_body.texture = _region(_body.texture.atlas, frame, row)
		if absf(dir.x) > 0.05:
			_body.flip_h = dir.x < 0.0
		_body.position.y = -absf(sin(_clock / STEP_TIME * PI)) * BOB
	else:
		_clock = 0.0
		_body.texture = _region(_body.texture.atlas, 0, _current_row())
		_body.position.y = 0.0


## Рухаємося окремо по кожній осі: коли впираєшся в паркан навскоси, так
## лишається змога ковзнути вздовж нього, а не застрягти.
func _slide(step: Vector2) -> void:
	var next := Vector2(position.x + step.x, position.y)
	if not _blocked(next):
		position = next
	next = Vector2(position.x, position.y + step.y)
	if not _blocked(next):
		position = next


func _blocked(at: Vector2) -> bool:
	var cell: Vector2i = _ground.local_to_map(at)
	if _ground.get_cell_source_id(cell) == -1:
		return true
	if WATER.has(_ground.get_cell_atlas_coords(cell)):
		return true
	# Усе, що стоїть на шарі предметів, — перепона: дерево, паркан, хата, бочка.
	# Сам герой не плитка, тож на себе не натрапить.
	return _props != null and _props.get_cell_source_id(cell) != -1


func _current_row() -> int:
	var region: AtlasTexture = _body.texture as AtlasTexture
	return int(region.region.position.y) / FRAME.y


func _region(sheet: Texture2D, frame: int, row: int) -> AtlasTexture:
	var region := AtlasTexture.new()
	region.atlas = sheet
	region.region = Rect2(
		float(frame * FRAME.x), float(row * FRAME.y), float(FRAME.x), float(FRAME.y)
	)
	return region
