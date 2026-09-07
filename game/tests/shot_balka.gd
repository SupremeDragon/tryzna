extends Node
## Знімок намальованої Балки.

func _ready() -> void:
	add_child((load("res://scenes/balka.tscn") as PackedScene).instantiate())
	for i: int in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://../builds/shots/13-balka.png")
	print("знято: 13-balka.png")
	get_tree().quit()
