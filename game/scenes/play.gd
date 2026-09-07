extends Node
## Балка, по якій можна ходити: карта плюс герой.
##
## Карта й герой лишаються окремими сценами навмисно. `balka.tscn` перемальовує
## код (tools/paint_balka.gd) і щоразу переписує файл цілком — усе, що вкладене
## в неї руками, зникло б із першим же перемальовуванням.

const MAP := "res://scenes/balka.tscn"
const HERO := "res://scenes/hero.tscn"
## Де герой прокидається: майдан біля вогнища.
const START := Vector2i(3, 3)


func _ready() -> void:
	var map: Node = (load(MAP) as PackedScene).instantiate()
	add_child(map)

	# Оглядова камера з малювальника знімала карту цілком; тут веде камера
	# героя, і дві камери на сцені сваряться за те, чия правда.
	var wide: Node = map.get_node_or_null("Камера")
	if wide != null:
		wide.queue_free()

	var ground: TileMapLayer = map.get_node("Земля") as TileMapLayer
	var props: TileMapLayer = map.get_node("Предмети") as TileMapLayer

	# Герой стає ВСЕРЕДИНУ шару предметів, а не поруч із ним: тільки так він
	# сортується по Y разом із деревами й хатами й заходить за них, а не
	# ковзає поверх усього.
	var hero: Node2D = (load(HERO) as PackedScene).instantiate() as Node2D
	hero.position = ground.map_to_local(START)
	props.add_child(hero)


func _unhandled_input(event: InputEvent) -> void:
	# Прогулянка запускається сама по собі, без меню, тож і вийти з неї має
	# бути чим.
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
