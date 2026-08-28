extends Node
## Глобальний стан партії. Все, що має пережити перезавантаження сцени.
##
## ВАЖЛИВО: тут не місце для посилань на вузли сцени. Тільки дані.

const SAVE_VERSION: int = 1

## Вікові стани Ости. Впливають на статистики, спрайт і доступні квести.
enum Age { CHILD, YOUTH, ADULT, ELDER, OLD }

var save_version: int = SAVE_VERSION
var mortal_name: String = ""
var age_stage: Age = Age.YOUTH
var year: int = 19
var chapter: StringName = &"prologue"

## Віра, зібрана вівтарями й храмами. Стартовий капітал бога в Акті III.
var faith: float = 0.0
var believers: int = 0


func to_dict() -> Dictionary:
	return {
		"save_version": save_version,
		"mortal_name": mortal_name,
		"age_stage": int(age_stage),
		"year": year,
		"chapter": String(chapter),
		"faith": faith,
		"believers": believers,
		"ledger": Ledger.to_array(),
	}


func from_dict(data: Dictionary) -> bool:
	var version: int = int(data.get("save_version", 0))
	if version > SAVE_VERSION:
		push_error("Збереження новішої версії (%d), ніж підтримує гра (%d)." % [version, SAVE_VERSION])
		return false

	mortal_name = String(data.get("mortal_name", ""))
	age_stage = data.get("age_stage", Age.YOUTH) as Age
	year = int(data.get("year", 19))
	chapter = StringName(data.get("chapter", "prologue"))
	faith = float(data.get("faith", 0.0))
	believers = int(data.get("believers", 0))
	Ledger.from_array(data.get("ledger", []) as Array)
	return true


func age_label() -> String:
	match age_stage:
		Age.CHILD: return "дитина"
		Age.YOUTH: return "юність"
		Age.ADULT: return "зрілість"
		Age.ELDER: return "літня"
		Age.OLD: return "старість"
	return "?"
