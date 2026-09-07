extends Node
## Перевірка героя: чи він іде і чи його тримає паркан.
##
## Перевіряти рух очима на знімку не вийде — на знімку герой стоїть. Тому тут
## натискаються ті самі дії, що й з клавіатури, і рахується, що з того вийшло.
##
## Запуск:  Godot --headless --path game res://tests/check_hero.tscn

## Скільки кадрів тримаємо кнопку. При 60 к/с це приблизно піввідсекунди.
const FRAMES: int = 30

var _faults: int = 0


func _ready() -> void:
	var play: Node = (load("res://scenes/play.tscn") as PackedScene).instantiate()
	add_child(play)
	await get_tree().process_frame

	var map: Node = play.get_child(0)
	var ground: TileMapLayer = map.get_node("Земля") as TileMapLayer
	var props: TileMapLayer = map.get_node("Предмети") as TileMapLayer
	var hero: Node2D = map.get_node("Предмети/Герой") as Node2D

	# 1. Іде туди, куди сказано.
	hero.position = ground.map_to_local(Vector2i(-2, 2))
	var was: Vector2 = hero.position
	await _hold("move_down")
	_want(hero.position.y > was.y + 20.0, "герой іде вниз по екрану")

	was = hero.position
	await _hold("move_up")
	_want(hero.position.y < was.y - 20.0, "герой іде вгору по екрану")

	# 2. Не проходить крізь те, що стоїть. Шукаємо зайняту клітинку поруч і
	# впираємося в неї: якщо перепон немає, перевіряти нічого.
	var wall: Vector2i = _find_wall(ground, props)
	_want(wall != Vector2i.MAX, "на карті є в що впертися")
	if wall != Vector2i.MAX:
		hero.position = ground.map_to_local(wall + Vector2i(-1, -1))
		for i: int in FRAMES * 3:
			Input.action_press("move_down")
			Input.action_press("move_right")
			await get_tree().process_frame
		Input.action_release("move_down")
		Input.action_release("move_right")
		_want(
			ground.local_to_map(hero.position) != wall,
			"герой не заліз у зайняту клітинку"
		)

	print("ПІДСУМОК: %s" % ("чисто" if _faults == 0 else "Є ВАДИ"))
	get_tree().quit(0 if _faults == 0 else 1)


func _hold(action: String) -> void:
	Input.action_press(action)
	for i: int in FRAMES:
		await get_tree().process_frame
	Input.action_release(action)


## Клітинка з предметом, у яку є куди впертися по діагоналі.
func _find_wall(ground: TileMapLayer, props: TileMapLayer) -> Vector2i:
	for cell: Vector2i in props.get_used_cells():
		var from: Vector2i = cell + Vector2i(-1, -1)
		if ground.get_cell_source_id(from) != -1 and props.get_cell_source_id(from) == -1:
			return cell
	return Vector2i.MAX


func _want(ok: bool, what: String) -> void:
	if ok:
		print("  ok   %s" % what)
	else:
		print("  ВАДА %s" % what)
		_faults += 1
