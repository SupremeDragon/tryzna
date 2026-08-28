extends Node
## Реєстр діянь — хребет усієї трилогії.
##
## Це НЕ карма зі шкалою «добро/зло». Це список. Гра просто записує, що ти зробив,
## і ніколи не показує оцінки. Оцінку один раз зачитає Воротар наприкінці Акту II.
##
## Теги потрібні лише Акту II — вони визначать, у який шар Ниці впаде гравець.

const TAGS: Array[StringName] = [
	&"насильство",
	&"милосердя",
	&"брехня",
	&"віра",
	&"звязок",
	&"байдужість",
]

var _deeds: Array[Dictionary] = []


## Записати вчинок. `tags` мають бути з TAGS.
func record(id: StringName, text: String, tags: Array[StringName] = [], weight: float = 1.0) -> void:
	for tag: StringName in tags:
		if tag not in TAGS:
			push_warning("Реєстр: невідомий тег «%s» у вчинку «%s»." % [tag, id])

	var deed: Dictionary = {
		"id": String(id),
		"text": text,
		"year": GameState.year,
		"tags": tags.map(func(t: StringName) -> String: return String(t)),
		"weight": weight,
	}
	_deeds.append(deed)
	EventBus.deed_recorded.emit(deed)


func deeds() -> Array[Dictionary]:
	return _deeds.duplicate(true)


func count() -> int:
	return _deeds.size()


## Сума ваг за тегом. Використає Акт II.
func weight_of(tag: StringName) -> float:
	var total: float = 0.0
	for deed: Dictionary in _deeds:
		if String(tag) in (deed.get("tags", []) as Array):
			total += float(deed.get("weight", 1.0))
	return total


func to_array() -> Array:
	return _deeds.duplicate(true)


func from_array(data: Array) -> void:
	_deeds.clear()
	for entry: Variant in data:
		if entry is Dictionary:
			_deeds.append(entry as Dictionary)


func clear() -> void:
	_deeds.clear()
