extends Node
## Балка, по якій можна ходити: карта, герой, мешканці й двері в хату.
##
## Карта й герой лишаються окремими сценами навмисно. `balka.tscn` перемальовує
## код (tools/paint_balka.gd) і щоразу переписує файл цілком — усе, що вкладене
## в неї руками, зникло б із першим же перемальовуванням. Тому малювальник
## лишає в сцені самі МІТКИ — де стоять люди й де пороги, — а хто там стане й
## що станеться на порозі, вирішується тут.

const MAP := "res://scenes/balka.tscn"
const HUT := "res://scenes/hut.tscn"
const HERO := "res://scenes/hero.tscn"
const VILLAGER := "res://scenes/villager.tscn"
## Де герой прокидається: майдан біля вогнища.
const START := Vector2i(3, 3)

## Пари рядків аркуша для селян: селянка, селянин, вартовий. Герой має свою
## пару (0 і 1) і в цей перелік не входить — інакше по селу ходили б двійники.
const FOLK_ROWS: Array[int] = [2, 4, 6]

var _map: Node2D
var _hut: Node2D
var _hero: Node2D
var _hint: Label
## Пороги хат у клітинках карти.
var _doors: Array[Vector2i] = []
## Куди вийти назад.
var _came_from := Vector2i.ZERO
var _inside: bool = false


func _ready() -> void:
	_map = (load(MAP) as PackedScene).instantiate() as Node2D
	add_child(_map)

	# Оглядова камера з малювальника знімала карту цілком; тут веде камера
	# героя, і дві камери на сцені сваряться за те, чия правда.
	var wide: Node = _map.get_node_or_null("Камера")
	if wide != null:
		wide.queue_free()

	var ground: TileMapLayer = _map.get_node("Земля") as TileMapLayer
	var props: TileMapLayer = _map.get_node("Предмети") as TileMapLayer

	# Герой стає ВСЕРЕДИНУ шару предметів, а не поруч із ним: тільки так він
	# сортується по Y разом із деревами й хатами й заходить за них, а не
	# ковзає поверх усього.
	_hero = (load(HERO) as PackedScene).instantiate() as Node2D
	_hero.position = ground.map_to_local(START)
	props.add_child(_hero)

	_settle(props)
	_collect_doors(ground)
	_make_hint()


## Розселяє мешканців по мітках, які лишив малювальник.
func _settle(props: TileMapLayer) -> void:
	var marks: Node = _map.get_node_or_null("Мешканці")
	if marks == null:
		return
	var folk: PackedScene = load(VILLAGER) as PackedScene
	for i: int in marks.get_child_count():
		var mark: Node2D = marks.get_child(i) as Node2D
		var one: Node2D = folk.instantiate() as Node2D
		one.row_front = FOLK_ROWS[i % FOLK_ROWS.size()]
		one.row_back = one.row_front + 1
		one.position = mark.position
		props.add_child(one)
	# Мітки своє відпрацювали. Лишати їх у сцені — це лишати два джерела
	# правди про те, де стоять люди.
	marks.queue_free()


func _collect_doors(ground: TileMapLayer) -> void:
	var marks: Node = _map.get_node_or_null("Двері")
	if marks == null:
		return
	for mark: Node in marks.get_children():
		_doors.append(ground.local_to_map((mark as Node2D).position))
	marks.queue_free()


func _make_hint() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Підказка"
	add_child(layer)

	_hint = Label.new()
	_hint.name = "Напис"
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.offset_top = -76.0
	_hint.offset_bottom = -36.0
	# Обведення, а не підкладка: напис має читатися і на траві, і на бруку, і
	# при цьому не затуляти те, на що гравець дивиться.
	_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.visible = false
	layer.add_child(_hint)


func _process(_delta: float) -> void:
	if _hero == null:
		return
	if _inside:
		_hint.text = "Пробіл — вийти"
		_hint.visible = _at_doorstep()
	else:
		_hint.text = "Пробіл — увійти"
		_hint.visible = _door_here() != Vector2i.MAX


func _unhandled_input(event: InputEvent) -> void:
	# Прогулянка запускається сама по собі, без меню, тож і вийти з неї має
	# бути чим.
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
		return

	if not event.is_action_pressed("ui_accept"):
		return
	if _inside:
		if _at_doorstep():
			_go_outside()
		return
	var door: Vector2i = _door_here()
	if door != Vector2i.MAX:
		_go_inside(door)


## Поріг, на якому стоїть герой, або Vector2i.MAX.
func _door_here() -> Vector2i:
	var cell: Vector2i = _hero.cell_at(_hero.position)
	return cell if _doors.has(cell) else Vector2i.MAX


func _at_doorstep() -> bool:
	var sill: Node2D = _hut.get_node("Поріг") as Node2D
	return _hero.position.distance_to(sill.position) < 100.0


func _go_inside(door: Vector2i) -> void:
	if _hut == null:
		_hut = (load(HUT) as PackedScene).instantiate() as Node2D
		add_child(_hut)
	_came_from = door
	_show(_map, false)
	_show(_hut, true)
	_move_hero(
		_hut.get_node("Предмети") as TileMapLayer,
		(_hut.get_node("Поріг") as Node2D).position
	)
	_inside = true


func _go_outside() -> void:
	_show(_hut, false)
	_show(_map, true)
	var ground: TileMapLayer = _map.get_node("Земля") as TileMapLayer
	_move_hero(
		_map.get_node("Предмети") as TileMapLayer, ground.map_to_local(_came_from)
	)
	_inside = false


## Ховаємо карту разом із її ходом часу: інакше селяни надворі й далі ходять,
## поки герой сидить у хаті, і карта дарма їсть кадри.
func _show(what: Node2D, on: bool) -> void:
	what.visible = on
	what.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _move_hero(into: TileMapLayer, where: Vector2) -> void:
	_hero.reparent(into)
	_hero.position = where
	# Шари в новій карті свої. Поки герой їх не перечитає, він ходить по памʼяті
	# попередньої — і проходить крізь стіни.
	_hero.rebind()
	_hero.stand()
