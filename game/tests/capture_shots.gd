extends Node
## Знімає сірий прототип у кількох станах складання камери.
## Запуск: tools\shots.bat — результат у builds\shots\
##
## Потрібно, щоб оцінювати головний візуальний прийом за картинками,
## а не за описом. Найдешевша форма перевірки дизайну.

const SHOTS: Array[Dictionary] = [
	{"name": "1-plyn", "mode": 1, "depth": 0.55, "height": 1.0, "note": "Плинь — повний світ"},
	{"name": "2-death-30", "mode": 1, "depth": 0.38, "height": 1.0, "note": "смерть, 30%"},
	{"name": "3-death-65", "mode": 1, "depth": 0.19, "height": 1.0, "note": "смерть, 65%"},
	{"name": "4-nyts", "mode": 2, "depth": 0.0, "height": 1.0, "note": "Ниць — силует"},
	{"name": "5-ascent-40", "mode": 0, "depth": 0.72, "height": 0.86, "note": "піднесення, 40%"},
	{"name": "6-ascent-75", "mode": 0, "depth": 0.86, "height": 0.34, "note": "піднесення, 75% — вежі осідають"},
	{"name": "7-vys", "mode": 0, "depth": 0.92, "height": 0.0, "note": "Висі — карта"},
]

var _main: Node2D


func _ready() -> void:
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../builds/shots")
	DirAccess.make_dir_recursive_absolute(dir)

	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node2D
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame

	for shot: Dictionary in SHOTS:
		WorldMode.set_mode(int(shot["mode"]) as WorldMode.Mode)
		# Кожен світ — окрема локація, а не той самий майдан під іншим кутом.
		_main.call("_load_world", int(shot["mode"]))
		_main.call("_refresh_hint")
		_main.call("_blend_palette", 1.0, int(shot["mode"]))
		# Зум ставимо вручну: у Висі камера мусить відійти далеко.
		var cam: Camera2D = _main.get_node("Camera2D") as Camera2D
		cam.position_smoothing_enabled = false
		cam.zoom = Vector2.ONE * float(WorldMode.ZOOM_FOR[int(shot["mode"])])
		Projector.depth_scale = float(shot["depth"])
		Projector.height_scale = float(shot["height"])
		_main.queue_redraw()

		# Даємо камері доїхати й кадру відмалюватися.
		for _i: int in range(6):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw

		var image: Image = get_viewport().get_texture().get_image()
		var path: String = dir.path_join("%s.png" % shot["name"])
		var err: Error = image.save_png(path)
		if err == OK:
			print("знято: %-12s  %s" % [shot["name"], shot["note"]])
		else:
			printerr("не вдалося зберегти %s (код %d)" % [path, err])

	await _capture_combat(dir)
	await _capture_parallax(dir)

	print("\nЗнімки: %s" % dir)
	get_tree().quit(0)


## Окремий знімок бою: ганяємо симуляцію, доки ворог не замахнеться,
## і ловимо саме той кадр. Телеграф — головне, що треба бачити очима.
func _capture_combat(dir: String) -> void:
	WorldMode.set_mode(WorldMode.Mode.PLYN)
	_main.call("_load_world", int(WorldMode.Mode.PLYN))
	_main.call("_blend_palette", 1.0, int(WorldMode.Mode.PLYN))
	_main.call("_refresh_hint")
	Projector.depth_scale = WorldSpace.DEPTH_PLYN
	Projector.height_scale = WorldSpace.HEIGHT_PLYN

	var cam: Camera2D = _main.get_node("Camera2D") as Camera2D
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2.ONE * 1.15

	# Ставимо Осту впритул до першого ворога.
	var enemies: Array = _main.get("_enemies") as Array
	if enemies.is_empty():
		printerr("немає ворогів для знімка бою")
		return
	var enemy: RefCounted = enemies[0] as RefCounted
	var mover: RefCounted = _main.get("_mover") as RefCounted
	mover.set("position", (enemy.get("pos") as Vector3) - Vector3(150.0, 0.0, 0.0))

	# Чекаємо не просто замаху, а замаху ДОЗРІЛОГО: саме тоді мітка на землі
	# налита й видно, що зараз бахне. На початку замаху вона ще бліда.
	var found: bool = false
	for _i: int in range(600):
		await get_tree().physics_frame
		var brain: RefCounted = enemy.get("brain") as RefCounted
		if int(brain.get("state")) == 2 and float(brain.call("windup_ratio")) > 0.75:
			found = true
			break

	for _i: int in range(2):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image: Image = get_viewport().get_texture().get_image()
	var path: String = dir.path_join("8-combat.png")
	if image.save_png(path) == OK:
		print("знято: %-12s  %s" % ["8-combat", "бій — замах ворога" if found else "бій"])


## Паралакс на одному кадрі не видно. Тому знімаємо ту саму сцену двічі,
## зсунувши камеру: якщо шари поїхали з різною швидкістю — воно працює.
func _capture_parallax(dir: String) -> void:
	var cam: Camera2D = _main.get_node("Camera2D") as Camera2D
	cam.position_smoothing_enabled = false

	for world: Dictionary in [
		{"mode": 2, "name": "nyts", "from": -3000.0, "step": 900.0, "zoom": 0.9},
		{"mode": 1, "name": "plyn", "from": -700.0, "step": 900.0, "zoom": 0.72},
	]:
		var mode: int = int(world["mode"])
		WorldMode.set_mode(mode as WorldMode.Mode)
		_main.call("_load_world", mode)
		_main.call("_refresh_hint")
		_main.call("_blend_palette", 1.0, mode)
		Projector.depth_scale = float(WorldMode.DEPTH_FOR[mode])
		Projector.height_scale = float(WorldMode.HEIGHT_FOR[mode])
		cam.zoom = Vector2.ONE * float(world["zoom"])

		var mover: RefCounted = _main.get("_mover") as RefCounted
		for shot: int in range(2):
			var x: float = float(world["from"]) + float(shot) * float(world["step"])
			mover.set("position", Vector3(x, 0.0, 0.0))
			mover.set("velocity", Vector3.ZERO)
			for _i: int in range(4):
				await get_tree().physics_frame
			await RenderingServer.frame_post_draw

			var image: Image = get_viewport().get_texture().get_image()
			var name: String = "9-parallax-%s-%d.png" % [world["name"], shot + 1]
			if image.save_png(dir.path_join(name)) == OK:
				print("знято: %-22s  камера x=%.0f" % [name, x])
