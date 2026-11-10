extends RefCounted
class_name ShiftController

signal phase_changed(new_phase: int)
signal parcel_spawned(parcel: DeliveryParcel)
signal delivery_scored(parcel: DeliveryParcel, matched: bool)
signal totals_changed(score: int, correct: int, mistakes: int)
signal shift_finished(success: bool, score: int, correct: int, mistakes: int)

enum Phase { READY, RUNNING, PAUSED, FINISHED }

const REQUIRED_DELIVERIES: int = 12
const MAX_MISTAKES: int = 3
const SEGMENT_SECONDS: float = 1.06
const SCORE_PER_DELIVERY: int = 100

var board: BoardState = BoardState.new()
var scheduler: RouteScheduler = RouteScheduler.new()
var parcels: Array[DeliveryParcel] = []
var phase: Phase = Phase.READY
var score: int = 0
var correct: int = 0
var mistakes: int = 0
var last_success: bool = false
var _next_parcel_id: int = 1


func start_shift() -> void:
	_reset_session()
	phase = Phase.RUNNING
	phase_changed.emit(phase)
	totals_changed.emit(score, correct, mistakes)


func restart_shift() -> void:
	start_shift()


func exit_shift() -> void:
	_reset_session()
	phase = Phase.READY
	phase_changed.emit(phase)
	totals_changed.emit(score, correct, mistakes)


func _reset_session() -> void:
	board.reset()
	scheduler.reset()
	parcels.clear()
	_next_parcel_id = 1
	score = 0
	correct = 0
	mistakes = 0
	last_success = false


func set_paused(should_pause: bool) -> void:
	if should_pause and phase == Phase.RUNNING:
		phase = Phase.PAUSED
	elif not should_pause and phase == Phase.PAUSED:
		phase = Phase.RUNNING
	else:
		return
	phase_changed.emit(phase)


func toggle_junction(node_id: String) -> bool:
	if phase != Phase.RUNNING:
		return false
	return board.toggle_junction(node_id)


func advance(delta: float) -> void:
	# Godot calls this from _physics_process at a fixed physics tick.
	if phase != Phase.RUNNING or delta <= 0.0:
		return
	for target in scheduler.tick(delta):
		_spawn_parcel(target)
	for parcel in parcels:
		if phase != Phase.RUNNING:
			break
		if parcel.active:
			_advance_parcel(parcel, delta)
	for index in range(parcels.size() - 1, -1, -1):
		if not parcels[index].active:
			parcels.remove_at(index)
	if phase == Phase.RUNNING and scheduler.is_exhausted() and parcels.is_empty():
		_finish(false)


func _spawn_parcel(target: String) -> void:
	var parcel := DeliveryParcel.new(_next_parcel_id, target)
	_next_parcel_id += 1
	parcel.next_node = board.get_next_node("depot")
	if not board.is_valid_edge("depot", parcel.next_node):
		parcel.active = false
		_register_delivery(parcel, false)
		return
	parcel.travel_direction = (
		board.get_position_normalized(parcel.next_node) -
		board.get_position_normalized(parcel.current_node)
	).normalized()
	parcels.append(parcel)
	parcel_spawned.emit(parcel)


func _advance_parcel(parcel: DeliveryParcel, delta: float) -> void:
	var remaining: float = delta
	var hops: int = 0
	while remaining > 0.000001 and parcel.active and hops < 16:
		hops += 1
		var seconds_left: float = SEGMENT_SECONDS * (1.0 - parcel.progress)
		var step: float = minf(remaining, seconds_left)
		parcel.progress = minf(1.0, parcel.progress + step / SEGMENT_SECONDS)
		remaining -= step
		if parcel.progress < 0.99999:
			break
		parcel.current_node = parcel.next_node
		parcel.progress = 0.0
		if board.is_destination(parcel.current_node):
			_register_delivery(parcel, parcel.current_node == parcel.destination)
			break
		var following: String = board.get_next_node(parcel.current_node)
		if not board.is_valid_edge(parcel.current_node, following):
			_register_delivery(parcel, false)
			break
		parcel.next_node = following
		parcel.travel_direction = (
			board.get_position_normalized(following) -
			board.get_position_normalized(parcel.current_node)
		).normalized()
	if hops >= 16 and parcel.active:
		_register_delivery(parcel, false)


func _register_delivery(parcel: DeliveryParcel, matched: bool) -> void:
	# A completed parcel cannot award points or mistakes twice.
	if not parcel.active or phase != Phase.RUNNING:
		return
	parcel.active = false
	if matched:
		correct += 1
		score += SCORE_PER_DELIVERY
	else:
		mistakes += 1
	delivery_scored.emit(parcel, matched)
	totals_changed.emit(score, correct, mistakes)
	if correct >= REQUIRED_DELIVERIES:
		_finish(true)
	elif mistakes >= MAX_MISTAKES:
		_finish(false)


func _finish(success: bool) -> void:
	if phase != Phase.RUNNING:
		return
	phase = Phase.FINISHED
	last_success = success
	for parcel in parcels:
		parcel.active = false
	phase_changed.emit(phase)
	shift_finished.emit(success, score, correct, mistakes)


func get_parcel_position(parcel: DeliveryParcel) -> Vector2:
	return board.get_position_normalized(parcel.current_node).lerp(
		board.get_position_normalized(parcel.next_node),
		parcel.progress
	)
