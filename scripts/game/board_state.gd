extends RefCounted
class_name BoardState

signal junction_changed(node_id: String, outgoing_node: String)
signal map_changed(level_index: int)

# Original constants stay available to all Phase 1 tests and default helpers.
const NODES = {
	"depot": Vector2(0.50, 0.89),
	"hub": Vector2(0.50, 0.68),
	"west": Vector2(0.26, 0.44),
	"east": Vector2(0.74, 0.44),
	"red": Vector2(0.12, 0.15),
	"blue": Vector2(0.50, 0.13),
	"green": Vector2(0.88, 0.15),
}
const EDGES = {
	"depot": ["hub"],
	"hub": ["west", "east"],
	"west": ["red", "blue"],
	"east": ["blue", "green"],
}
const JUNCTION_IDS = ["hub", "west", "east"]
const DESTINATION_IDS = ["red", "blue", "green"]

var level_index: int = 0
var palette: int = 0
var nodes: Dictionary = NODES.duplicate(true)
var edges: Dictionary = EDGES.duplicate(true)
var junction_ids: Array[String] = ["hub", "west", "east"]
var destination_ids: Array[String] = ["red", "blue", "green"]
var default_selections: Dictionary = {"hub": 0, "west": 0, "east": 1}
var selected_output: Dictionary = {}


func _init() -> void:
	reset()


func configure(level: Dictionary, index: int) -> bool:
	if not LevelCatalog.validate(level):
		return false
	var next_nodes: Dictionary = (level["nodes"] as Dictionary).duplicate(true)
	var next_edges: Dictionary = (level["edges"] as Dictionary).duplicate(true)
	var next_defaults: Dictionary = (level["defaults"] as Dictionary).duplicate(true)
	var switches: Array[String] = []
	for node_id in next_edges:
		if str(node_id) != "depot":
			switches.append(str(node_id))
	switches.sort()
	nodes = next_nodes
	edges = next_edges
	default_selections = next_defaults
	junction_ids = switches
	level_index = index
	palette = int(level.get("palette", 0))
	reset()
	map_changed.emit(level_index)
	return true


func reset() -> void:
	selected_output = default_selections.duplicate(true)


func has_node(node_id: String) -> bool:
	return nodes.has(node_id)


func is_destination(node_id: String) -> bool:
	return destination_ids.has(node_id)


func is_junction(node_id: String) -> bool:
	return junction_ids.has(node_id)


func get_position_normalized(node_id: String) -> Vector2:
	if not has_node(node_id):
		return Vector2.ZERO
	return nodes[node_id]


func is_valid_edge(from_node: String, to_node: String) -> bool:
	if not edges.has(from_node) or not has_node(to_node):
		return false
	var options: Array = edges[from_node]
	return options.has(to_node)


func get_next_node(node_id: String) -> String:
	if not edges.has(node_id):
		return ""
	var options: Array = edges[node_id]
	var selection: int = int(selected_output.get(node_id, 0))
	if selection < 0 or selection >= options.size():
		return ""
	var next_node: String = str(options[selection])
	if not is_valid_edge(node_id, next_node):
		return ""
	return next_node


func toggle_junction(node_id: String) -> bool:
	if not is_junction(node_id):
		return false
	var options: Array = edges[node_id]
	if options.size() != 2:
		return false
	selected_output[node_id] = posmod(int(selected_output.get(node_id, 0)) + 1, options.size())
	junction_changed.emit(node_id, get_next_node(node_id))
	return true
