extends Node
## Перевірка дверей: увійшов у хату, вийшов туди ж, звідки заходив.
##
## Перевіряти це очима на знімку не вийде: на знімку двері зачинені. Тому тут
## надсилається та сама дія, що й з клавіатури, і рахується, що з того вийшло.
##
## Запуск:  Godot --headless --path game res://tests/check_door.tscn

var _faults: int = 0


func _ready() -> void:
	var play: Node = (load("res://scenes/play.tscn") as PackedScene).instantiate()
	add_child(play)
	await get_tree().process_frame

	# Лізу в поле з підкресленням навмисно: пороги знає сама сцена, і другого
	# джерела правди про них заводити не варто.
	var doors: Array = play._doors
	_want(doors.size() > 0, "малювальник лишив пороги (%d)" % doors.size())
	if doors.is_empty():
		_done()
		return

	var hero: Node2D = play._hero
	var sill: Vector2i = doors[0]
	hero.position = hero.center_of(sill)
	await _press("ui_accept")
	_want(play._inside, "герой увійшов у хату")
	_want(
		hero.get_parent().get_parent().name == "Хата",
		"герой опинився саме в хаті, а не деінде"
	)

	# У хаті теж має бути куди йти: поріг вільний, стіни ні.
	_want(not hero.blocked(hero.position), "на порозі в хаті можна стояти")

	await _press("ui_accept")
	_want(not play._inside, "герой вийшов надвір")
	_want(hero.cell_at(hero.position) == sill, "вийшов туди ж, звідки заходив")

	_done()


func _press(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	for i: int in 4:
		await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	for j: int in 4:
		await get_tree().process_frame


func _want(ok: bool, what: String) -> void:
	if ok:
		print("  ok   %s" % what)
	else:
		print("  ВАДА %s" % what)
		_faults += 1


func _done() -> void:
	print("ПІДСУМОК: %s" % ("чисто" if _faults == 0 else "Є ВАДИ"))
	get_tree().quit(0 if _faults == 0 else 1)
