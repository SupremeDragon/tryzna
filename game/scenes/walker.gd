extends Node2D
## Спільне для всіх, хто ходить: герой і селяни.
##
## Тут немає жодного рішення про те, КУДИ йти. Герой бере напрямок із
## клавіатури, селянин — зі своєї голови, а все інше — картинка, хода,
## сортування, перепони — однакове, і живе в одному місці.
##
## Куди він дивиться. В ізометрії чотири напрямки руху, а ракурсів треба лише
## два: рух на +x і +y іде НА глядача, на -x і -y — ВІД нього, а ліворуч і
## праворуч дає дзеркало. Тому в аркуші два рядки на фігурку, а не чотири.
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

## Скільки триває один крок. Менше — метушня, більше — фігурка ковзає.
const STEP_TIME: float = 0.20
## На скільки підстрибує тіло посеред кроку.
const BOB: float = 5.0

## Вода. Ті самі числа, що в малювальника: art/plyn/atlas_terrain-склад.txt.
const WATER: Array[Vector2i] = [
	Vector2i(8, 1), Vector2i(9, 1), Vector2i(10, 1),
	Vector2i(1, 6), Vector2i(2, 6), Vector2i(4, 6), Vector2i(6, 6), Vector2i(7, 6),
]

## Пара рядків аркуша: перед і спина. Задається до додавання в дерево.
var row_front: int = 0
var row_back: int = 1
var speed: float = 260.0

var _body: Sprite2D
var _shadow: Sprite2D
var _sheet: Texture2D
var _ground: TileMapLayer
var _props: TileMapLayer
var _clock: float = 0.0
var _row: int = 0


func _ready() -> void:
	_sheet = load(SHEET) as Texture2D
	_row = row_front

	_shadow = Sprite2D.new()
	_shadow.name = "Тінь"
	_shadow.texture = load(SHADOW) as Texture2D
	_shadow.position = Vector2(0.0, -6.0)
	_shadow.scale = Vector2(1.2, 1.2)
	_shadow.modulate = Color(0.0, 0.0, 0.0, 0.40)
	add_child(_shadow)

	_body = Sprite2D.new()
	_body.name = "Тіло"
	_body.centered = false
	_body.offset = Vector2(-FRAME.x / 2.0, -FRAME.y)
	# Без цього піксельні краї розмиваються, і фігурка стає ватяною поруч
	# із чіткими плитками.
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body.texture = _region(0, _row)
	add_child(_body)

	rebind()


## Перечитує, в якій карті фігурка опинилася.
##
## Окремим викликом, а не тільки при народженні: герой переходить із подвір'я в
## хату, і це вже інша карта з іншими шарами. Поки шари бралися один раз, у
## хаті він ходив по памʼяті двору — і провалювався крізь стіни.
func rebind() -> void:
	# Шари шукаємо вгору по дереву: фігурка живе ВСЕРЕДИНІ шару «Предмети»,
	# щоб сортуватися по Y разом із деревами й хатами.
	var map: Node = get_parent()
	while map != null and not map.has_node("Земля"):
		map = map.get_parent()
	if map == null:
		push_error("Фігурка не всередині карти: нема шару «Земля»")
		return
	_ground = map.get_node("Земля") as TileMapLayer
	_props = map.get_node("Предмети") as TileMapLayer


## Крок у бік `dir` (одиничний вектор екранного напрямку) за `delta` секунд.
func walk(dir: Vector2, delta: float) -> void:
	if _ground == null:
		return
	_slide(dir * speed * delta)
	_clock += delta
	# Дивиться туди, куди йде: вниз по екрану — обличчям, угору — спиною.
	_row = row_back if dir.y < -0.1 else row_front
	var frame: int = 0 if fmod(_clock, STEP_TIME * 2.0) < STEP_TIME else 1
	_body.texture = _region(frame, _row)
	if absf(dir.x) > 0.05:
		_body.flip_h = dir.x < 0.0
	_body.position.y = -absf(sin(_clock / STEP_TIME * PI)) * BOB


func stand() -> void:
	_clock = 0.0
	_body.texture = _region(0, _row)
	_body.position.y = 0.0


## Рухаємося окремо по кожній осі: коли впираєшся в паркан навскоси, так
## лишається змога ковзнути вздовж нього, а не застрягти.
func _slide(step: Vector2) -> void:
	var next := Vector2(position.x + step.x, position.y)
	if not blocked(next):
		position = next
	next = Vector2(position.x, position.y + step.y)
	if not blocked(next):
		position = next


func blocked(at: Vector2) -> bool:
	if _ground == null:
		return true
	var cell: Vector2i = _ground.local_to_map(at)
	if _ground.get_cell_source_id(cell) == -1:
		return true
	if WATER.has(_ground.get_cell_atlas_coords(cell)):
		return true
	# Усе, що стоїть на шарі предметів, — перепона: дерево, паркан, хата, бочка.
	# Самі фігурки не плитки, тож одна на одну не натрапить: вони ходять рідко
	# й повільно, і штовхатися їм ніде.
	return _props != null and _props.get_cell_source_id(cell) != -1


func cell_at(at: Vector2) -> Vector2i:
	return _ground.local_to_map(at)


func center_of(cell: Vector2i) -> Vector2:
	return _ground.map_to_local(cell)


func _region(frame: int, row: int) -> AtlasTexture:
	var region := AtlasTexture.new()
	region.atlas = _sheet
	region.region = Rect2(
		float(frame * FRAME.x), float(row * FRAME.y), float(FRAME.x), float(FRAME.y)
	)
	return region
