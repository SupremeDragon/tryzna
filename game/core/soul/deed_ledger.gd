class_name DeedLedger
extends Resource
## Реєстр діянь ОДНІЄЇ душі.
##
## Це не карма зі шкалою. Це список: гра просто записує, що ця істота зробила,
## і ніколи не показує оцінки. Оцінку один раз зачитають на Суді.
##
## Чому Resource, а не автолоад: у Акті III реєстр потрібен КОЖНІЙ названій
## людині — бог читає чужу сторінку, перш ніж відповісти на молитву
## (див. docs/07-висі-геймплей.md, §8). Автолоад на одного гравця це б не витяг.
##
## Клас нічого не знає ні про GameState, ні про EventBus: рік передається
## ззовні. Правило №1 архітектури — `core/` не залежить від автолоадів.

signal deed_recorded(deed: Dictionary)
signal prayer_recorded(prayer: Dictionary)

const TAGS: Array[StringName] = [
	&"насильство",
	&"милосердя",
	&"брехня",
	&"віра",
	&"звязок",
	&"байдужість",
]

@export var deeds: Array[Dictionary] = []

## Молитовний слід: коли й про що ця істота зверталася нагору.
## Той, хто молиться тільки коли припекло, читається інакше за того,
## хто раз попросив за сусіда.
@export var prayers: Array[Dictionary] = []


func record(
	id: StringName, text: String, year: int,
	tags: Array[StringName] = [], weight: float = 1.0
) -> Dictionary:
	for tag: StringName in tags:
		if tag not in TAGS:
			push_warning("Реєстр: невідомий тег «%s» у вчинку «%s»." % [tag, id])

	var deed: Dictionary = {
		"id": String(id),
		"text": text,
		"year": year,
		"tags": tags.map(func(t: StringName) -> String: return String(t)),
		"weight": weight,
	}
	deeds.append(deed)
	deed_recorded.emit(deed)
	return deed


## `for_self` — молився про себе чи про когось іншого. Це головне, що з
## молитовного сліду читає бог.
func record_prayer(id: StringName, about: String, year: int, for_self: bool) -> Dictionary:
	var prayer: Dictionary = {
		"id": String(id),
		"about": about,
		"year": year,
		"for_self": for_self,
	}
	prayers.append(prayer)
	prayer_recorded.emit(prayer)
	return prayer


func count() -> int:
	return deeds.size()


func prayer_count() -> int:
	return prayers.size()


func prayers_for_self() -> int:
	var total: int = 0
	for prayer: Dictionary in prayers:
		if bool(prayer.get("for_self", true)):
			total += 1
	return total


func prayers_for_others() -> int:
	return prayer_count() - prayers_for_self()


## Сума ваг за тегом. Знадобиться Суду наприкінці Акту I і шарам Ниці в Акті II.
func weight_of(tag: StringName) -> float:
	var total: float = 0.0
	for deed: Dictionary in deeds:
		if String(tag) in (deed.get("tags", []) as Array):
			total += float(deed.get("weight", 1.0))
	return total


func clear() -> void:
	deeds.clear()
	prayers.clear()


func to_dict() -> Dictionary:
	return {
		"deeds": deeds.duplicate(true),
		"prayers": prayers.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	clear()
	for entry: Variant in (data.get("deeds", []) as Array):
		if entry is Dictionary:
			deeds.append(entry as Dictionary)
	for entry: Variant in (data.get("prayers", []) as Array):
		if entry is Dictionary:
			prayers.append(entry as Dictionary)
