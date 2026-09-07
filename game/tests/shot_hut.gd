extends Node
## Знімки порога й нутрощів хати: як це бачить гравець.

func _ready() -> void:
	var play: Node = (load("res://scenes/play.tscn") as PackedScene).instantiate()
	add_child(play)
	await get_tree().process_frame

	var hero: Node2D = play._hero
	var sill: Vector2i = play._doors[0]
	hero.position = hero.center_of(sill)
	for i: int in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../builds/shots/18-door.png")
	print("знято: 18-door.png")

	var down := InputEventAction.new()
	down.action = "ui_accept"
	down.pressed = true
	Input.parse_input_event(down)
	for j: int in 14:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../builds/shots/19-hut.png")
	print("знято: 19-hut.png")
	get_tree().quit()
