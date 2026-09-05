extends Node
## Знімок меню й порогу. Тимчасовий інструмент перевірки, не частина гри.
##
## Сцену НЕ міняємо, а підвішуємо як дочірню: change_scene_to_file() звільняє
## поточну сцену разом із цим скриптом, і чекати після неї вже нікому.

func _ready() -> void:
	var menu: Node = (load("res://scenes/menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	for i: int in 45:
		await get_tree().process_frame
	await _save("10-menu.png")

	Loading.begin("res://scenes/main.tscn", true)
	for i: int in 30:
		await get_tree().process_frame
	await _save("11-porih.png")

	get_tree().quit()


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("res://../builds/shots/" + name)
	print("знято: ", name)
