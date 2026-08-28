extends Node
## Збереження. Версіонується з першого дня — інакше збереження Акту I
## не завантажиться в Акт II, і вся ідея наскрізного Реєстру діянь помре.

const SLOT_COUNT: int = 3
const AUTO_SLOT: int = -1

signal saved(slot: int)
signal loaded(slot: int)


func slot_path(slot: int) -> String:
	if slot == AUTO_SLOT:
		return "user://save_auto.json"
	return "user://save_%d.json" % slot


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func save_to(slot: int) -> Error:
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		var err: Error = FileAccess.get_open_error()
		push_error("Не вдалося записати збереження в слот %d (код %d)." % [slot, err])
		return err

	file.store_string(JSON.stringify(GameState.to_dict(), "\t"))
	file.close()
	saved.emit(slot)
	return OK


func load_from(slot: int) -> Error:
	if not has_save(slot):
		return ERR_FILE_NOT_FOUND

	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()

	var raw: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(raw)
	if parsed is not Dictionary:
		push_error("Збереження в слоті %d пошкоджене." % slot)
		return ERR_PARSE_ERROR

	if not GameState.from_dict(parsed as Dictionary):
		return ERR_INVALID_DATA

	loaded.emit(slot)
	return OK


func erase(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot)))
