class_name DialogueRunner
extends RefCounted
## Ходить по графу розмови.
##
## Не знає ні про UI, ні про автолоади. Умови (`requires`) тлумачить не сам —
## запитує назовні через `condition_check`. Наслідки (`ledger`, `prayer`)
## теж не виконує, а віддає назовні сигналом. Завдяки цьому весь діалог
## проганяється в тестах без відкриття гри.

signal line_changed(text: String, speaker: StringName)
signal choices_offered(choices: Array[Dictionary])
signal effect_fired(kind: StringName, value: String)
signal finished()

## Кому поставити питання «чи виконано умову». Приймає рядок, повертає bool.
## Якщо не задано — всі умови вважаються виконаними.
var condition_check: Callable = Callable()

var graph: DialogueGraph = null
var current_id: StringName = &""

var _running: bool = false


func is_running() -> bool:
	return _running


func start(p_graph: DialogueGraph, from: StringName = &"") -> bool:
	if p_graph == null or not p_graph.is_valid():
		return false
	graph = p_graph
	current_id = from if from != &"" else graph.start_node
	_running = true
	_enter(current_id)
	return true


func stop() -> void:
	_running = false
	current_id = &""
	finished.emit()


## Поточний вузол пропонує вибір?
func has_choices() -> bool:
	return not available_choices().is_empty()


## Варіанти, доступні ЗАРАЗ: ті, чия умова виконана.
func available_choices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not _running:
		return out
	var node: Dictionary = graph.node(current_id)
	for entry: Variant in (node.get("choices", []) as Array):
		if entry is not Dictionary:
			continue
		var choice: Dictionary = entry as Dictionary
		if _passes(String(choice.get("requires", ""))):
			out.append(choice)
	return out


## Далі по прямій. Якщо вузол пропонує вибір — нічого не робить:
## з вибору виходять тільки через `choose`.
func advance() -> void:
	if not _running or has_choices():
		return
	var node: Dictionary = graph.node(current_id)
	var next: StringName = StringName(node.get("next", ""))
	if next == &"":
		stop()
		return
	current_id = next
	_enter(current_id)


## `index` — позиція серед ДОСТУПНИХ варіантів, не серед усіх.
func choose(index: int) -> void:
	if not _running:
		return
	var choices: Array[Dictionary] = available_choices()
	if index < 0 or index >= choices.size():
		return

	var choice: Dictionary = choices[index]
	_fire_effects(choice)

	var next: StringName = StringName(choice.get("next", ""))
	if next == &"":
		stop()
		return
	current_id = next
	_enter(current_id)


func _enter(node_id: StringName) -> void:
	var node: Dictionary = graph.node(node_id)
	if node.is_empty():
		stop()
		return

	_fire_effects(node)
	line_changed.emit(String(node.get("text", "")), graph.speaker)

	var choices: Array[Dictionary] = available_choices()
	if not choices.is_empty():
		choices_offered.emit(choices)


## Наслідки віддаємо назовні, а не виконуємо: `core/` не має права
## сам писати в Реєстр діянь чи чіпати стан гри.
func _fire_effects(source: Dictionary) -> void:
	for kind: String in ["ledger", "prayer", "quest", "flag"]:
		if source.has(kind):
			effect_fired.emit(StringName(kind), String(source[kind]))


func _passes(condition: String) -> bool:
	if condition.is_empty():
		return true
	if not condition_check.is_valid():
		return true
	return bool(condition_check.call(condition))
