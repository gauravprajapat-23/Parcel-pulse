extends RefCounted
class_name BoardState

signal junction_changed(node_id: String, outgoing_node: String)

# All coordinates are normalized to the board view. Roads cannot point outside
# this directed acyclic graph, so parcels cannot enter an infinite route loop.
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

var selected_output: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	selected_output = {"hub": 0, "west": 0, "east": 1}


func has_node(node_id: String) -> bool:
	return NODES.has(node_id)


func is_destination(node_id: String) -> bool:
	return DESTINATION_IDS.has(node_id)


func is_junction(node_id: String) -> bool:
	return JUNCTION_IDS.has(node_id)


func get_position_normalized(node_id: String) -> Vector2:
	if not has_node(node_id):
		return Vector2.ZERO
	return NODES[node_id]


func is_valid_edge(from_node: String, to_node: String) -> bool:
	if not EDGES.has(from_node) or not has_node(to_node):
		return false
	var options: Array = EDGES[from_node]
	return options.has(to_node)


func get_next_node(node_id: String) -> String:
	if not EDGES.has(node_id):
		return ""
	var options: Array = EDGES[node_id]
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
	var options: Array = EDGES[node_id]
	if options.size() != 2:
		return false
	selected_output[node_id] = posmod(int(selected_output.get(node_id, 0)) + 1, options.size())
	junction_changed.emit(node_id, get_next_node(node_id))
	return true
