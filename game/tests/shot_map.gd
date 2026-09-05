extends Node
## Знімок карти на тайлмапі. Перевірка того, чи сходяться ромби.

func _ready() -> void:
	var map: Node2D = (load("res://scenes/plyn_map.tscn") as PackedScene).instantiate()
	add_child(map)
	await get_tree().process_frame
	map.call("fill_demo", 8)
	for i: int in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../builds/shots/12-tilemap.png")
	print("знято: 12-tilemap.png")
	get_tree().quit()
