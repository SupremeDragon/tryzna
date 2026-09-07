extends SceneTree
## Перевірка карти: дерева не у воді, паркан не на дорозі.

const WATER: Array[Vector2i] = [
	Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
	Vector2i(3, 7), Vector2i(4, 7), Vector2i(6, 7), Vector2i(8, 7),
]
const FENCE: Array[Vector2i] = [
	Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
	Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 4),
]
const DIRT: Array[Vector2i] = [
	Vector2i(5, 2), Vector2i(6, 2), Vector2i(5, 3), Vector2i(6, 3),
	Vector2i(7, 3), Vector2i(9, 3), Vector2i(0, 4), Vector2i(1, 4),
	Vector2i(8, 3),
]

func _init() -> void:
	var map: Node = (load("res://scenes/balka.tscn") as PackedScene).instantiate()
	var ground: TileMapLayer = map.get_node("Земля")
	var props: TileMapLayer = map.get_node("Предмети")

	var in_water: int = 0
	for cell: Vector2i in props.get_used_cells():
		if WATER.has(ground.get_cell_atlas_coords(cell)):
			in_water += 1

	var fence_on_road: int = 0
	for cell2: Vector2i in ground.get_used_cells():
		if not FENCE.has(ground.get_cell_atlas_coords(cell2)):
			continue
		# Дорога — смуга x у [0,1] або y у [0,1].
		if (cell2.x >= 0 and cell2.x <= 1) or (cell2.y >= 0 and cell2.y <= 1):
			fence_on_road += 1

	print("предметів у воді: %d" % in_water)
	print("парканів на дорозі: %d" % fence_on_road)
	print("ПІДСУМОК: %s" % ("чисто" if in_water == 0 and fence_on_road == 0 else "Є ВАДИ"))
	quit(0 if in_water == 0 and fence_on_road == 0 else 1)
