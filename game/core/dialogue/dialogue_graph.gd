class_name DialogueGraph
extends RefCounted
## Розмова, прочитана з JSON.
##
## Формат описано в docs/04-технічне-тз.md, §4. Клас нічого не виконує — він
## лише тримає вузли й уміє їх віддавати. Ходить по них DialogueRunner.
##
## Правило №1 архітектури: `core/` не знає ні про GameState, ні про Ledger,
## ні про сцену. Умови й наслідки — це рядки, які тлумачить хтось зовні.

var id: StringName = &""
var speaker: StringName = &""
var start_node: StringName = &""

## id вузла -> сам вузол.
var _nodes: Dictionary = {}

## Помилки розбору. Порожньо — граф справний.
var errors: Array[String] = []


static func from_json(raw: String, source_name: String = "") -> DialogueGraph:
	var graph := DialogueGraph.new()
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is not Dictionary:
		graph.errors.append("%s: не JSON-обʼєкт" % source_name)
		return graph

	var data: Dictionary = parsed as Dictionary
	graph.id = StringName(data.get("id", source_name))
	graph.speaker = StringName(data.get("speaker", ""))

	var nodes: Variant = data.get("nodes", [])
	if nodes is not Array or (nodes as Array).is_empty():
		graph.errors.append("%s: немає жодного вузла" % graph.id)
		return graph

	for entry: Variant in nodes as Array:
		if entry is not Dictionary:
			graph.errors.append("%s: вузол не є обʼєктом" % graph.id)
			continue
		var node: Dictionary = entry as Dictionary
		var node_id: StringName = StringName(node.get("id", ""))
		if node_id == &"":
			graph.errors.append("%s: вузол без id" % graph.id)
			continue
		if graph._nodes.has(node_id):
			graph.errors.append("%s: id вузла «%s» повторюється" % [graph.id, node_id])
			continue
		graph._nodes[node_id] = node
		if graph.start_node == &"":
			graph.start_node = node_id

	graph._check_links()
	return graph


## Найчастіша помилка в діалогах — посилання на вузол, якого немає.
## Ловимо її при завантаженні, а не тоді, коли гравець туди дійде.
func _check_links() -> void:
	for node_id: StringName in _nodes:
		var node: Dictionary = _nodes[node_id]
		for target: StringName in _targets_of(node):
			if target != &"" and not _nodes.has(target):
				errors.append(
					"%s: вузол «%s» веде в «%s», якого немає" % [id, node_id, target]
				)


func _targets_of(node: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	if node.has("next"):
		out.append(StringName(node["next"]))
	for choice: Variant in (node.get("choices", []) as Array):
		if choice is Dictionary and (choice as Dictionary).has("next"):
			out.append(StringName((choice as Dictionary)["next"]))
	return out


func is_valid() -> bool:
	return errors.is_empty() and not _nodes.is_empty()


func has_node(node_id: StringName) -> bool:
	return _nodes.has(node_id)


func node(node_id: StringName) -> Dictionary:
	return _nodes.get(node_id, {})


func node_count() -> int:
	return _nodes.size()
