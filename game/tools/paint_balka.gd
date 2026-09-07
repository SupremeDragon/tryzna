extends SceneTree
## Малює Тиху Балку й зберігає її окремою сценою.
##
## Карта Міші лежить у scenes/plyn_map.tscn і НЕ чіпається: своя пишеться поруч.
##
## Малювати кодом і малювати мишею — не суперники. Мишею зручно ставити те, що
## бачиш; кодом зручно те, що має правило: узлісся, яке густішає до краю, або
## паркан, який обходить двір і лишає хвіртку до дороги.
##
## Запуск:  Godot --headless --path game --script res://tools/paint_balka.gd

const TILE_SET := "res://art/plyn/terrain.tres"
const OUT := "res://scenes/balka.tscn"


## ЩО лежить на клітинці. Без цього дерева сідали у воду, а паркан перегороджував
## дорогу: перевірки «чи вже щось стоїть» замало, треба знати ЩО саме стоїть.
enum Kind { NONE, GRASS, DIRT, WATER, SAND, STONE, YARD, BUILDING }

# --- плитки (стовпець, рядок) з art/plyn/atlas_terrain-склад.txt --------------

## Чиста трава. Її найбільше, тож і варіантів беремо всі, які є: одна плитка на
## все поле читається як шпалери, хоч би якою гарною вона була.
const GRASS: Array[Vector2i] = [
	Vector2i(3, 0), Vector2i(5, 0), Vector2i(2, 1), Vector2i(3, 1),
	Vector2i(4, 1), Vector2i(3, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(8, 2),
]
## Трава з чимось: кущиком, квітами, камінцем, латкою землі.
const GRASS_RICH: Array[Vector2i] = [
	Vector2i(2, 0), Vector2i(4, 0), Vector2i(7, 0), Vector2i(10, 0),
	Vector2i(11, 0), Vector2i(10, 2), Vector2i(0, 10),
	Vector2i(4, 2), Vector2i(9, 2), Vector2i(7, 2),
]
const DIRT: Array[Vector2i] = [
	Vector2i(1, 2), Vector2i(2, 2), Vector2i(11, 2),
	Vector2i(0, 3), Vector2i(1, 3), Vector2i(3, 3), Vector2i(5, 3),
]
const DIRT_RICH: Array[Vector2i] = [Vector2i(2, 3), Vector2i(4, 3)]
const SAND: Array[Vector2i] = [
	Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 1),
	Vector2i(10, 5), Vector2i(11, 5), Vector2i(8, 6), Vector2i(9, 6),
	Vector2i(10, 6), Vector2i(11, 6), Vector2i(0, 7), Vector2i(1, 7),
]
const SAND_RICH: Array[Vector2i] = [Vector2i(6, 5), Vector2i(7, 5)]
const SHORE := Vector2i(3, 6)
const WATER: Array[Vector2i] = [
	Vector2i(8, 1), Vector2i(9, 1), Vector2i(10, 1),
	Vector2i(1, 6), Vector2i(2, 6), Vector2i(4, 6), Vector2i(6, 6), Vector2i(7, 6),
]
const STONE: Array[Vector2i] = [
	Vector2i(11, 1), Vector2i(0, 2), Vector2i(2, 4), Vector2i(3, 4),
	Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4),
	Vector2i(8, 4), Vector2i(9, 4),
]
## Готові паркани набору — кубики землі, на яких паркан намальований ОДРАЗУ
## кутом, по двох дальніх ребрах ромба. Такою плиткою двір не обвести: у ряд
## вони лягають то внапуск, то з дірками, і на екрані це читалося як розкидані
## стовпчики. Лишаємо їх на випадкові тини серед поля.
const FENCE: Array[Vector2i] = [
	Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3),
	Vector2i(9, 3), Vector2i(10, 3), Vector2i(11, 3),
]

## Паркан-НАКЛАДКА: половина кута, без власного кубика землі. Робиться з
## кутових парканів у tools/make_fence_overlays.py. Під ним видно будь-яку
## землю, і з половинок складається замкнений периметр будь-якого розміру.
##
## Паркан на цих кубиках намальований по ПЕРЕДНІХ ребрах ромба, не по дальніх:
## ліва половина — межа з сусідом (x, y+1), права — межа з сусідом (x+1, y).
## Тому огорожа двору малюється на його ближніх до глядача клітинках, а дальні
## два боки — на сусідніх клітинках ЗА двором.
const FENCE_SW: Array[Vector2i] = [Vector2i(1, 10), Vector2i(3, 10)]
const FENCE_SE: Array[Vector2i] = [Vector2i(2, 10), Vector2i(4, 10)]
## Ріг двору, де сходяться обидва ребра: на клітинку кладеться одна плитка.
const FENCE_CORNER: Array[Vector2i] = [Vector2i(5, 10), Vector2i(6, 10)]

const TREES: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(8, 0), Vector2i(9, 0), Vector2i(0, 1), Vector2i(1, 1),
]
const BUSH := Vector2i(0, 0)
const ROCK: Array[Vector2i] = [Vector2i(9, 5), Vector2i(5, 6)]
const MUSHROOMS: Array[Vector2i] = [Vector2i(1, 8), Vector2i(2, 8), Vector2i(3, 8)]

## Готові будиночки. Це ЦІЛІ будівлі — стіни й дах разом, — а не самі дахи.
## Я довго приймав їх за дахи й ставив поверх ящиків, ніби ті ящики стіни; від
## того хата й виглядала як хата на коробках. Ящики повернулися у двір.
const HOUSE: Array[Vector2i] = [Vector2i(10, 7), Vector2i(11, 7), Vector2i(0, 8)]
## Камʼяний підмурок під житло: піднімає хату на ярус і дає їй опору.
const FOOTING := Vector2i(9, 7)
## Хижа — маленька будівля цілком в одній плитці.
const HUT := Vector2i(2, 7)

## Мотлох у дворі. Тільки дрібне: бочки, ящики, скриня. Кубики-ящики 5-7 і 6-7
## сюди не годяться — вони заввишки з хату й у дворі читаються як друга будівля.
const YARD_STUFF: Array[Vector2i] = [
	Vector2i(7, 8), Vector2i(7, 8), Vector2i(8, 8), Vector2i(8, 8), Vector2i(0, 5),
]
const CAMPFIRE := Vector2i(10, 8)
const STALL := Vector2i(11, 8)
const RUNESTONE: Array[Vector2i] = [Vector2i(4, 8), Vector2i(5, 8), Vector2i(6, 8)]

## Розмір поля в клітинках від центру.
const REACH: int = 36
## Півширина дороги: 0 і 1, тобто дві клітинки.
const ROAD_HALF: int = 1

var _rng := RandomNumberGenerator.new()
var _ground: TileMapLayer
var _props: TileMapLayer
var _footings: TileMapLayer
var _kind: Dictionary = {}
## Де стоятимуть селяни. Малювальник знає, де в нього двори; сцена, яку він
## пише, — уже ні, тож місця треба лишити в ній самій, а не вгадувати потім.
var _folk: Array[Vector2i] = []
## Пороги хат: клітинка перед дверима, з якої заходять досередини.
var _doors: Array[Vector2i] = []


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

	_ground = _layer(root, "Земля", set, Vector2.ZERO, false)
	# Підмурки окремим шаром, і саме ПІД предметами. Це не другий ярус: підняття
	# зашите в самі плитки хат (tools/build_tileset.gd), тож хата лежить у тому
	# самому шарі, що й дерева з героєм, і сортується разом із ними. Підмурку
	# сортування не треба: під ним нічого не ходить.
	_footings = _layer(root, "Підмурки", set, Vector2.ZERO, false)
	_props = _layer(root, "Предмети", set, Vector2.ZERO, true)

	_paint()

	var folk := Node2D.new()
	folk.name = "Мешканці"
	root.add_child(folk)
	for i: int in _folk.size():
		var mark := Marker2D.new()
		mark.name = "Мешканець %d" % (i + 1)
		mark.position = _ground.map_to_local(_folk[i])
		folk.add_child(mark)

	var doors := Node2D.new()
	doors.name = "Двері"
	root.add_child(doors)
	for j: int in _doors.size():
		var sill := Marker2D.new()
		sill.name = "Поріг %d" % (j + 1)
		sill.position = _ground.map_to_local(_doors[j])
		doors.add_child(sill)

	# Власника треба проставити ВСЬОМУ дереву, не тільки першому рівню: те, що
	# без власника, у збережену сцену не потрапляє, і мітки зникали мовчки.
	_own(root, root)

	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("Не зібралося в сцену")
		quit(1)
		return
	if ResourceSaver.save(packed, OUT) != OK:
		push_error("Не збереглося: " + OUT)
		quit(1)
		return

	print("карта -> %s, землі %d, предметів %d, підмурків %d, мешканців %d" % [
		OUT, _ground.get_used_cells().size(), _props.get_used_cells().size(),
		_footings.get_used_cells().size(), _folk.size(),
	])
	print("порогів: %d" % _doors.size())
	quit()


func _own(root: Node, node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		_own(root, child)


func _layer(
	root: Node2D, name: String, set: TileSet, offset: Vector2, sorted: bool
) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = name
	layer.tile_set = set
	layer.position = offset
	layer.y_sort_enabled = sorted
	root.add_child(layer)
	return layer


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
	if _kind_at(at) != Kind.GRASS or _props.get_cell_source_id(at) != -1:
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
			var tile: Vector2i = (
				_pick(GRASS_RICH) if _rng.randf() < 0.13 else _pick(GRASS)
			)
			_put(Vector2i(x, y), tile, Kind.GRASS)


func _paint_pond() -> void:
	# Спершу вода, потім по її межі — берег. Так берег лягає точно там, де
	# треба, і не доводиться перелічувати клітинки руками.
	var pond := Vector2i(-12, 8)
	for y: int in range(-8, 9):
		for x: int in range(-8, 9):
			var at: Vector2i = pond + Vector2i(x, y)
			if absi(x) + absi(y) <= 5:
				_put(at, _pick(WATER), Kind.WATER)
	for y2: int in range(-9, 10):
		for x2: int in range(-9, 10):
			var at2: Vector2i = pond + Vector2i(x2, y2)
			var d: int = absi(x2) + absi(y2)
			if d >= 6 and d <= 7 and _kind_at(at2) == Kind.GRASS:
				_put(at2, SHORE if _rng.randf() < 0.35 else _pick(SAND), Kind.SAND)

	# Човен біля берега — дрібниця, від якої ставок стає чиїмось.
	_props.set_cell(pond + Vector2i(5, 1), 0, Vector2i(9, 8))


func _paint_roads() -> void:
	for y: int in range(-REACH + 3, REACH - 2):
		for w: int in range(0, ROAD_HALF + 1):
			_lay_road(Vector2i(w, y))
	for x: int in range(-REACH + 3, REACH - 2):
		for w2: int in range(0, ROAD_HALF + 1):
			_lay_road(Vector2i(x, w2))

	# Піщані узбіччя: там, де дорога межує з травою, земля світлішає.
	for cell: Vector2i in _kind.keys():
		if _kind_at(cell) != Kind.GRASS or _rng.randf() > 0.45:
			continue
		for step: Vector2i in [
			Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		]:
			if _kind_at(cell + step) == Kind.DIRT:
				_put(cell, _pick(SAND), Kind.SAND)
				break


func _lay_road(at: Vector2i) -> void:
	if _kind_at(at) != Kind.GRASS:
		return
	var tile: Vector2i = _pick(DIRT_RICH) if _rng.randf() < 0.12 else _pick(DIRT)
	_put(at, tile, Kind.DIRT)


func _paint_square() -> void:
	for y: int in range(-4, 6):
		for x: int in range(-4, 6):
			var at := Vector2i(x, y)
			if absi(x) + absi(y) <= 6 and _kind_at(at) != Kind.WATER:
				_put(at, _pick(STONE), Kind.STONE)

	# Ятка й вогнище на майдані — те, задля чого сюди сходяться.
	_props.set_cell(Vector2i(4, 3), 0, STALL)
	_props.set_cell(Vector2i(-2, 4), 0, CAMPFIRE)
	_kind[Vector2i(4, 3)] = Kind.BUILDING
	_kind[Vector2i(-2, 4)] = Kind.BUILDING

	# Двоє на майдані: біля ятки й біля вогнища. Порожній майдан читається не
	# як центр села, а як місце, звідки всі пішли.
	_folk.append(Vector2i(3, 2))
	_folk.append(Vector2i(-1, 3))

	# Каменеписьмо на околиці майдану — натяк на те, що світ старший за село.
	_props.set_cell(Vector2i(-4, -3), 0, _pick(RUNESTONE))


func _paint_village() -> void:
	# Двори не розставлені руками, а ПРИКЛАДАЮТЬСЯ. Перебираємо місця по сітці
	# від перехрестя й далі, і садиба стає там, де влізла ціла. Так село
	# густішає біля майдану й рідшає до узлісся само собою — і не доводиться
	# правити список координат щоразу, як зсунеться дорога чи ставок.
	# Крок 7 = двір 6 плюс один зовнішній ряд під паркан: садиби стають упритул,
	# але не наїжджають одна на одну.
	#
	# Смуги рахуються від дороги НАЗОВНІ, окремо в плюс і в мінус: якщо просто
	# помножити номер на крок, найближчі до перехрестя двори сідають просто на
	# дорогу або на майдан і відпадають усі до одного.
	var lines: Array[int] = []
	for i: int in range(6):
		lines.append(5 + i * 7)
		lines.append(-6 - i * 7)
	var spots: Array[Vector2i] = []
	for gy: int in lines:
		for gx: int in lines:
			spots.append(Vector2i(gx, gy))
	spots.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return absi(a.x) + absi(a.y) < absi(b.x) + absi(b.y)
	)

	var built: int = 0
	for spot: Vector2i in spots:
		if built >= 18:
			break
		if _build_estate(spot, built):
			built += 1
	print("садиб: %d" % built)


## Наскільки клітинка відстоїть від дорожньої смуги по цій осі.
func _gap(v: int) -> int:
	if v < 0:
		return -v
	return maxi(v - ROAD_HALF, 0)


## Садиба SIZE x SIZE. Повертає true, якщо стала.
##
## Порядок тут не випадковий: спершу перевіряємо ВЕСЬ двір разом із зовнішнім
## рядом, куди стане паркан, і аж потім кладемо першу плитку. Коли я перевіряв
## по ходу, половина паркана вже лежала, а друга впиралася в дорогу.
func _build_estate(corner: Vector2i, index: int) -> bool:
	const SIZE: int = 6
	var last: Vector2i = corner + Vector2i(SIZE - 1, SIZE - 1)

	for y: int in range(-1, SIZE):
		for x: int in range(-1, SIZE):
			var at: Vector2i = corner + Vector2i(x, y)
			if _kind_at(at) != Kind.GRASS or _on_road(at):
				return false

	# Хвіртка дивиться на ту дорогу, до якої ближче: 0 захід, 1 схід,
	# 2 північ, 3 південь. «Захід» тут — бік меншого x, тобто те ребро ромба,
	# що на екрані ліворуч угорі.
	var mid: Vector2i = corner + Vector2i(SIZE / 2, SIZE / 2)
	var side: int
	if _gap(mid.x) <= _gap(mid.y):
		side = 0 if mid.x > ROAD_HALF else 1
	else:
		side = 2 if mid.y > ROAD_HALF else 3

	# Двір: трава, витоптана ближче до хати. Паркан-накладка ляже поверх неї.
	for y2: int in range(SIZE):
		for x2: int in range(SIZE):
			var at2: Vector2i = corner + Vector2i(x2, y2)
			var tile: Vector2i = (
				_pick(GRASS_RICH) if _rng.randf() < 0.18 else _pick(GRASS)
			)
			_put(at2, tile, Kind.YARD)

	var style: int = index % FENCE_SW.size()
	var gate: int = SIZE / 2
	# Ріг ставимо ПЕРШИМ: у ближньому до глядача розі сходяться обидва ребра, а
	# клітинка одна. Якби він ішов після циклу, туди вже лягло б півребра, і
	# _fence() пропустив би ріг як зайняту клітинку.
	_fence(last, FENCE_CORNER[style])
	for k: int in range(SIZE):
		# Межа малюється на тій клітинці, для якої вона ПЕРЕДНЯ. Тому два
		# ближніх боки двору — на самому дворі, а два дальніх — на сусідніх
		# клітинках за ним.
		var skip_x: bool = k == gate and side <= 1
		var skip_y: bool = k == gate and side >= 2
		if not (skip_x and side == 0):
			_fence(Vector2i(corner.x - 1, corner.y + k), FENCE_SE[style])
		if not (skip_x and side == 1):
			_fence(Vector2i(last.x, corner.y + k), FENCE_SE[style])
		if not (skip_y and side == 2):
			_fence(Vector2i(corner.x + k, corner.y - 1), FENCE_SW[style])
		if not (skip_y and side == 3):
			_fence(Vector2i(corner.x + k, last.y), FENCE_SW[style])
	# Зовнішній ряд, де стоїть паркан, теж записуємо за садибою: інакше наступна
	# садиба вважає ці клітинки вільною травою й заходить сусідові на огорожу.
	for k2: int in range(-1, SIZE + 1):
		_kind[Vector2i(corner.x - 1, corner.y + k2)] = Kind.YARD
		_kind[Vector2i(corner.x + k2, corner.y - 1)] = Kind.YARD

	# Житло. Довша частина хати йде вздовж y: саме там гребені дахів сходяться
	# в один, а не стають сходинками, як уздовж x. Розмір різний — у когось
	# хата на дві клітинки, у когось на три, у заможнішого на чотири.
	var shape: Vector2i = [
		Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 2), Vector2i(1, 2),
	][index % 4]
	var home: Vector2i = corner + Vector2i(1, 1)
	_dwelling(home, shape, HOUSE[index % HOUSE.size()])

	# Ганок — найближча до глядача клітинка хати. Звідти й починається стежка.
	var door: Vector2i = home + shape - Vector2i(1, 1)

	# Комора в глибині двору. У кожної пʼятої садиби замість хати сама хижа:
	# село не буває однаковим.
	var shed: Vector2i = corner + Vector2i(SIZE - 2, 1)
	if _kind_at(shed) == Kind.YARD and _props.get_cell_source_id(shed) == -1:
		# Комора — хижа: вона стоїть просто на землі, без підмурка, і вже цим
		# нижча за житло. Одразу видно, котра тут головна хата.
		_props.set_cell(shed, 0, HUT)
		_kind[shed] = Kind.BUILDING

	_walk(corner, last, side, gate, door)

	# Поріг — клітинка ПЕРЕД дверима, бо в саму хату не ступиш: вона зайнята.
	# Двері дивляться на глядача, тож поріг шукаємо з ближнього боку.
	for near: Vector2i in [door + Vector2i(0, 1), door + Vector2i(1, 0)]:
		if _kind_at(near) == Kind.YARD and _props.get_cell_source_id(near) == -1:
			_doors.append(near)
			break

	# Господар. Стає на вільну клітинку свого двору й далі за пʼять клітинок
	# від неї не відходить.
	_settle_folk(corner, SIZE)

	# Дрібнота у дворі: бочки, ящики, скриня. Двір без мотлоху нежилий — але й
	# купа бочок упритул одна до одної не двір, а склад, тож поруч не ставимо.
	for i2: int in range(2):
		var spot: Vector2i = corner + Vector2i(
			_rng.randi_range(1, SIZE - 2), _rng.randi_range(1, SIZE - 2)
		)
		if _kind_at(spot) != Kind.YARD or _props.get_cell_source_id(spot) != -1:
			continue
		if _crowded(spot):
			continue
		_props.set_cell(spot, 0, _pick(YARD_STUFF))
	return true


## Ставить мешканця на першу-ліпшу вільну клітинку двору.
func _settle_folk(corner: Vector2i, size: int) -> void:
	for y: int in range(size - 2, 0, -1):
		for x: int in range(size - 2, 0, -1):
			var at: Vector2i = corner + Vector2i(x, y)
			if _kind_at(at) == Kind.YARD and _props.get_cell_source_id(at) == -1:
				_folk.append(at)
				return


## Чи стоїть щось поруч. Дрібнота, поставлена впритул, читається як склад.
func _crowded(at: Vector2i) -> bool:
	for step: Vector2i in [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	]:
		if _props.get_cell_source_id(at + step) != -1:
			return true
	return false


## Житло: камʼяний підмурок першим ярусом, готовий будиночок другим.
func _dwelling(corner: Vector2i, size: Vector2i, house: Vector2i) -> void:
	for y: int in range(size.y):
		for x: int in range(size.x):
			var at: Vector2i = corner + Vector2i(x, y)
			_footings.set_cell(at, 0, FOOTING)
			_props.set_cell(at, 0, house)
			_kind[at] = Kind.BUILDING


## Паркан кладемо, тільки якщо клітинка вільна: у тісних місцях двори стають
## поруч, і другий паркан інакше затирає перший.
func _fence(at: Vector2i, tile: Vector2i) -> void:
	if _props.get_cell_source_id(at) == -1:
		_props.set_cell(at, 0, tile)


## Стежка: від дверей до хвіртки й далі від хвіртки до дороги.
##
## Це те, від чого купа хат стає селом: видно, що сюди ходять.
func _walk(
	corner: Vector2i, last: Vector2i, side: int, gate: int, door: Vector2i
) -> void:
	var out: Vector2i = [
		Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
	][side]
	var mouth: Vector2i = [
		Vector2i(corner.x, corner.y + gate), Vector2i(last.x, corner.y + gate),
		Vector2i(corner.x + gate, corner.y), Vector2i(corner.x + gate, last.y),
	][side]

	# Усередині двору: спершу по одній осі, потім по другій.
	var step: Vector2i = door
	while step.x != mouth.x:
		step.x += signi(mouth.x - step.x)
		_tread(step)
	while step.y != mouth.y:
		step.y += signi(mouth.y - step.y)
		_tread(step)

	# Назовні: прямо від хвіртки, поки не впремося в дорогу або майдан.
	var away: Vector2i = mouth
	for i: int in range(14):
		away += out
		var kind: Kind = _kind_at(away)
		if kind == Kind.DIRT or kind == Kind.STONE:
			return
		if kind != Kind.GRASS and kind != Kind.SAND:
			return
		_put(away, _pick(DIRT), Kind.DIRT)


func _tread(at: Vector2i) -> void:
	if _kind_at(at) == Kind.YARD and _props.get_cell_source_id(at) == -1:
		_put(at, _pick(DIRT), Kind.YARD)


func _paint_forest() -> void:
	for y: int in range(-REACH, REACH + 1):
		for x: int in range(-REACH, REACH + 1):
			var at := Vector2i(x, y)
			var far: int = absi(x) + absi(y)
			if far > REACH or not _plantable(at):
				continue
			var edge: float = float(far) / float(REACH)
			if _rng.randf() > pow(maxf(edge - 0.60, 0.0) / 0.40, 1.5):
				continue
			_props.set_cell(at, 0, _pick(TREES))

	# Гай, кущі, каміння й гриби всередині — щоб поле не було голим полем.
	for i: int in range(140):
		var at2 := Vector2i(_rng.randi_range(-24, 24), _rng.randi_range(-24, 24))
		if absi(at2.x) + absi(at2.y) > 24 or not _plantable(at2):
			continue
		var roll: float = _rng.randf()
		if roll < 0.42:
			_props.set_cell(at2, 0, _pick(TREES))
		elif roll < 0.72:
			_props.set_cell(at2, 0, BUSH)
		elif roll < 0.90:
			_props.set_cell(at2, 0, _pick(ROCK))
		else:
			_props.set_cell(at2, 0, _pick(MUSHROOMS))
