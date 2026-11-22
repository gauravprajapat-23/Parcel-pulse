extends RefCounted
class_name RoadIncidents

# Deterministic temporary traffic jams; no paths are deleted or rerouted.
# The affected incoming road slows to 45% until cleared or timed out.
const FIRST_DELAY: float = 9.0
const BETWEEN_DELAY: float = 12.0
const DURATION: float = 9.0
const SLOW_FACTOR: float = 0.45
const MAX_PER_SHIFT: int = 2
const CLEAR_BONUS: int = 75
const PREFERRED_JUNCTIONS = ["hub", "west", "east", "upper", "north_west", "north_east"]

var active: bool = false
var node_id: String = ""
var approach_from: String = ""
var remaining: float = 0.0
var next_in: float = FIRST_DELAY
var started_count: int = 0
var cleared_count: int = 0


func reset() -> void:
	active = false
	node_id = ""
	approach_from = ""
	remaining = 0.0
	next_in = FIRST_DELAY
	started_count = 0
	cleared_count = 0


func cancel() -> void:
	active = false
	node_id = ""
	approach_from = ""
	remaining = 0.0


func _approach_for(board: BoardState, junction_id: String) -> String:
	var incoming: Array[String] = []
	for source in board.edges.keys():
		var road: String = str(source)
		if board.is_valid_edge(road, junction_id):
			incoming.append(road)
	incoming.sort()
	if incoming.is_empty():
		return ""
	return incoming[0]


func advance(delta: float, board: BoardState) -> String:
	# Called only while the shift is RUNNING, so Pause freezes all timers.
	if delta <= 0.0 or board == null:
		return ""
	if active:
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.0:
			_finish(false)
			return "expired"
		return ""
	if started_count >= MAX_PER_SHIFT:
		return ""
	next_in -= delta
	if next_in > 0.0:
		return ""
	var available: Array[String] = []
	for name in PREFERRED_JUNCTIONS:
		if board.is_junction(str(name)) and _approach_for(board, str(name)) != "":
			available.append(str(name))
	if available.is_empty():
		next_in = BETWEEN_DELAY
		return ""
	node_id = available[started_count % available.size()]
	approach_from = _approach_for(board, node_id)
	active = true
	remaining = DURATION
	started_count += 1
	return "started"


func _finish(manually_cleared: bool) -> void:
	active = false
	remaining = 0.0
	next_in = BETWEEN_DELAY
	if manually_cleared:
		cleared_count += 1


func clear() -> bool:
	if not active:
		return false
	_finish(true)
	return true


func speed_factor(from_id: String, to_id: String) -> float:
	if active and from_id == approach_from and to_id == node_id:
		return SLOW_FACTOR
	return 1.0
