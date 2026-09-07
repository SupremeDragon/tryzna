extends SceneTree
## Перевірка намальованої карти: не дивимося на неї очима, а рахуємо.
##
## Кожна перевірка тут зʼявилася з чужого ока: Міша подивився на карту й сказав,
## що дерева лягають на воду, а паркан перегороджує дорогу. Щоб таке не
## поверталося, воно рахується.
##
## Запуск:  Godot --headless --path game --script res://tests/check_map.gd

const MAP := "res://scenes/balka.tscn"

## Плитки ті самі, що й у малювальника, і в тому самому вигляді, щоб їх можна
## було звірити очима: art/plyn/atlas_terrain-склад.txt.
const WATER: Array[Vector2i] = [
	Vector2i(8, 1), Vector2i(9, 1), Vector2i(10, 1),
	Vector2i(1, 6), Vector2i(2, 6), Vector2i(4, 6), Vector2i(6, 6), Vector2i(7, 6),
]
const FENCE: Array[Vector2i] = [
	Vector2i(1, 10), Vector2i(2, 10), Vector2i(3, 10),
	Vector2i(4, 10), Vector2i(5, 10), Vector2i(6, 10),
]
const BOAT := Vector2i(9, 8)
const ROAD_HALF: int = 1


func _init() -> void:
	var map: Node = (load(MAP) as PackedScene).instantiate()
	var ground: TileMapLayer = map.get_node("Земля")
	var props: TileMapLayer = map.get_node("Предмети")
	var roofs: TileMapLayer = map.get_node("Дахи")

	# Човен у воді — єдине, чому там місце.
	var in_water: int = 0
	for cell: Vector2i in props.get_used_cells():
		if props.get_cell_atlas_coords(cell) == BOAT:
			continue
		if WATER.has(ground.get_cell_atlas_coords(cell)):
			in_water += 1

	var fence_on_road: int = 0
	for cell2: Vector2i in props.get_used_cells():
		if not FENCE.has(props.get_cell_atlas_coords(cell2)):
			continue
		if _on_road(cell2):
			fence_on_road += 1

	# Дах без стіни висів би просто в повітрі: другий ярус зсунутий угору на
	# висоту бічних граней, і без кубика під ним це видно одразу.
	var roof_adrift: int = 0
	for cell3: Vector2i in roofs.get_used_cells():
		if props.get_cell_source_id(cell3) == -1:
			roof_adrift += 1

	var faults: int = in_water + fence_on_road + roof_adrift
	print("предметів у воді: %d" % in_water)
	print("парканів на дорозі: %d" % fence_on_road)
	print("дахів без стіни: %d" % roof_adrift)
	print("ПІДСУМОК: %s" % ("чисто" if faults == 0 else "Є ВАДИ"))
	quit(0 if faults == 0 else 1)


func _on_road(at: Vector2i) -> bool:
	return (at.x >= 0 and at.x <= ROAD_HALF) or (at.y >= 0 and at.y <= ROAD_HALF)
