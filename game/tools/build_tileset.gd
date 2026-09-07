extends SceneTree
## Збирає ресурс TileSet з атласу.
##
## Робиться скриптом, а не руками в редакторі, з однієї причини: атлас ми ще
## не раз перескладемо, і клікати двісті плиток заново щоразу — це той вид
## роботи, після якого проєкти кидають.
##
## Запуск:  Godot --headless --path game --script res://tools/build_tileset.gd

const ATLAS := "res://art/plyn/atlas_terrain.png"
const OUT := "res://art/plyn/terrain.tres"

const COLS: int = 10
const ROWS: int = 6
const CELL := Vector2i(192, 192)

## Розмір самого РОМБА, а не картинки. Картинка вища за ромб, бо в кубика
## видно бічні грані — і саме тому ці два числа різні.
const DIAMOND := Vector2i(173, 128)

## Зсув картинки відносно клітинки.
##
## Клітинка — це РОМБ, а картинка — квадрат 192x192, у якому ромб лежить не
## посередині: під ним ще бічні грані кубика. Виміряно на кубику трави:
## найширший рядок ромба стоїть на y=68, а центр картинки — на y=96.
##
## І ще одне, що виявилося не таким, як здавалося: ромб тут НЕ 2:1. Він вищий —
## 173 на 128. Поки я задавав його «як заведено», плитки не сходилися.
const LIFT: int = 28


func _init() -> void:
	var tex: Texture2D = load(ATLAS) as Texture2D
	if tex == null:
		push_error("Немає атласу: " + ATLAS)
		quit(1)
		return

	var set := TileSet.new()
	set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	set.tile_size = DIAMOND

	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = CELL

	var made: int = 0
	for y: int in ROWS:
		for x: int in COLS:
			var at := Vector2i(x, y)
			source.create_tile(at)
			var data: TileData = source.get_tile_data(at, 0)
			data.texture_origin = Vector2i(0, LIFT)
			made += 1

	set.add_source(source, 0)

	var err: int = ResourceSaver.save(set, OUT)
	if err != OK:
		push_error("Не збереглося: %d" % err)
		quit(1)
		return

	print("тайлсет -> %s, плиток %d" % [OUT, made])
	quit()
