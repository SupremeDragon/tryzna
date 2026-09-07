extends Node
## Знімки героя на карті: на майдані й біля хати.
##
## Друга точка не для краси. Саме там видно, чи працює сортування по Y: герой
## за хатою має ховатися за нею, а перед хатою — затуляти її.

const SPOTS: Array[Vector2i] = [Vector2i(-2, 2), Vector2i(7, 9)]
const NAMES: Array[String] = ["15-hero.png", "16-hero-house.png"]


func _ready() -> void:
	var play: Node = (load("res://scenes/play.tscn") as PackedScene).instantiate()
	add_child(play)
	await get_tree().process_frame

	var map: Node = play.get_child(0)
	var ground: TileMapLayer = map.get_node("Земля") as TileMapLayer
	var hero: Node2D = map.get_node("Предмети/Герой") as Node2D

	for i: int in SPOTS.size():
		hero.position = ground.map_to_local(SPOTS[i])
		for f: int in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			"res://../builds/shots/" + NAMES[i]
		)
		print("знято: " + NAMES[i])

	get_tree().quit()
