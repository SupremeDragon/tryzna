extends "res://scenes/walker.gd"
## Герой: той, хто ходить із клавіатури.
##
## Усе, що спільне з селянами — картинка, хода, тінь, перепони, — лежить у
## walker.gd. Тут лишилося одне рішення: куди йти.


func _ready() -> void:
	row_front = 0
	row_back = 1
	super._ready()

	var cam := Camera2D.new()
	cam.name = "Камера"
	cam.zoom = Vector2(0.6, 0.6)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	add_child(cam)


func _process(delta: float) -> void:
	var dir: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)
	# Стрілки запасним ходом: у мапі дій прописані тільки WASD і геймпад, а
	# перше, що людина пробує в незнайомій грі, — саме стрілки.
	if dir == Vector2.ZERO:
		dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir.length() > 1.0:
		dir = dir.normalized()

	if dir == Vector2.ZERO:
		stand()
	else:
		walk(dir, delta)
