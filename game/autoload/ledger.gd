extends Node
## Реєстр діянь ГОЛОВНОГО ГЕРОЯ — тонка обгортка над `DeedLedger`.
##
## Уся логіка живе в `core/soul/deed_ledger.gd`, бо в Акті III такий реєстр
## потрібен кожній названій людині, а не тільки гравцю. Тут лишається лише те,
## що справді глобальне: чия саме це сторінка, звідки береться рік, і хто
## розповідає про запис решті гри.

const TAGS: Array[StringName] = DeedLedger.TAGS

var hero: DeedLedger = DeedLedger.new()


func _ready() -> void:
	hero.deed_recorded.connect(_on_deed_recorded)


## Рік підставляється тут: `core/` не має права знати про GameState.
func record(
	id: StringName, text: String,
	tags: Array[StringName] = [], weight: float = 1.0
) -> void:
	hero.record(id, text, GameState.year, tags, weight)


## Молитва Ости-смертної. Пишемо вже в Акті I: у Акті III якийсь бог
## читатиме ЇЇ сторінку — див. docs/07-висі-геймплей.md, §13.
func record_prayer(id: StringName, about: String, for_self: bool = true) -> void:
	hero.record_prayer(id, about, GameState.year, for_self)


func deeds() -> Array[Dictionary]:
	return hero.deeds.duplicate(true)


func count() -> int:
	return hero.count()


func prayer_count() -> int:
	return hero.prayer_count()


func prayers_for_self() -> int:
	return hero.prayers_for_self()


func weight_of(tag: StringName) -> float:
	return hero.weight_of(tag)


func to_dict() -> Dictionary:
	return hero.to_dict()


func from_dict(data: Dictionary) -> void:
	hero.from_dict(data)


func clear() -> void:
	hero.clear()


func _on_deed_recorded(deed: Dictionary) -> void:
	EventBus.deed_recorded.emit(deed)
