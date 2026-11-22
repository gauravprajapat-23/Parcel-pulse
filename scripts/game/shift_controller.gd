extends RefCounted
class_name ShiftController

signal phase_changed(new_phase: int)
signal parcel_spawned(parcel: DeliveryParcel)
signal delivery_scored(parcel: DeliveryParcel, matched: bool)
signal totals_changed(score: int, correct: int, mistakes: int)
signal shift_finished(success: bool, score: int, correct: int, mistakes: int)
signal level_changed(level_index: int)

enum Phase { READY, RUNNING, PAUSED, FINISHED }

const REQUIRED_DELIVERIES: int = 12
const MAX_MISTAKES: int = 3
const SEGMENT_SECONDS: float = 1.06
const SCORE_PER_DELIVERY: int = 100
const EXPRESS_EVERY: int = 4
const EXPRESS_DEADLINE: float = 5.0
const EXPRESS_BONUS: int = 100
const COMBO_START: int = 3
const MAX_COMBO_BONUS: int = 100
const RUSH_DURATION: float = 7.0
const RUSH_SPEED: float = 1.18
const FOCUS_DURATION: float = 4.0
const FOCUS_SPEED: float = 0.58
const FOCUS_START_CHARGES: int = 2

var board: BoardState = BoardState.new()
var scheduler: RouteScheduler = RouteScheduler.new()
var parcels: Array[DeliveryParcel] = []
var phase: Phase = Phase.READY
var score: int = 0
var correct: int = 0
var mistakes: int = 0
var last_success: bool = false
var level_index: int = 0
var required_deliveries: int = REQUIRED_DELIVERIES
var _next_parcel_id: int = 1

# Classic mode is the default to preserve deterministic Phase 1–2 test
# contracts. The user-facing GameScreen explicitly enables Arcade mode.
var arcade_mode: bool = false
var combo: int = 0
var best_combo: int = 0
var express_delivered: int = 0
var bonus_score: int = 0
var rush_remaining: float = 0.0
var focus_remaining: float = 0.0
var focus_charges: int = FOCUS_START_CHARGES
var last_delivery_points: int = 0


func select_level(index: int) -> bool:
	# Level selection is allowed only from READY/FINISHED; switching mid-shift
	# would invalidate the active parcel route and the result.
	if phase == Phase.RUNNING or phase == Phase.PAUSED:
		return false
	var level: Dictionary = LevelCatalog.get_level(index)
	if level.is_empty() or not LevelCatalog.validate(level):
		return false
	if not board.configure(level, index):
		return false
	if not scheduler.configure(level["schedule"], float(level["spawn_interval"])):
		return false
	_reset_session()
	level_index = index
	required_deliveries = int(level["quota"])
	phase = Phase.READY
	level_changed.emit(level_index)
	phase_changed.emit(phase)
	totals_changed.emit(score, correct, mistakes)
	return true


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
	combo = 0
	best_combo = 0
	express_delivered = 0
	bonus_score = 0
	rush_remaining = 0.0
	focus_remaining = 0.0
	focus_charges = FOCUS_START_CHARGES
	last_delivery_points = 0


func activate_focus() -> bool:
	# Two optional slow-time assists per shift. Cannot consume charges while
	# paused, outside a shift, or when a boost is already running.
	if not arcade_mode or phase != Phase.RUNNING:
		return false
	if focus_charges <= 0 or focus_remaining > 0.0:
		return false
	focus_charges -= 1
	focus_remaining = FOCUS_DURATION
	return true


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
	var simulation_delta: float = delta
	if arcade_mode:
		var speed: float = 1.0
		if focus_remaining > 0.0:
			speed = FOCUS_SPEED
		elif rush_remaining > 0.0:
			speed = RUSH_SPEED
		focus_remaining = maxf(0.0, focus_remaining - delta)
		rush_remaining = maxf(0.0, rush_remaining - delta)
		simulation_delta *= speed
	for target in scheduler.tick(simulation_delta):
		if phase != Phase.RUNNING:
			break
		_spawn_parcel(target)
	for parcel in parcels:
		if phase != Phase.RUNNING:
			break
		if parcel.active:
			_advance_parcel(parcel, simulation_delta)
	for index in range(parcels.size() - 1, -1, -1):
		if not parcels[index].active:
			parcels.remove_at(index)
	if phase == Phase.RUNNING and scheduler.is_exhausted() and parcels.is_empty():
		_finish(false)


func _spawn_parcel(target: String) -> void:
	var parcel := DeliveryParcel.new(_next_parcel_id, target)
	if arcade_mode:
		parcel.arcade_eligible = true
		parcel.is_express = parcel.parcel_id % EXPRESS_EVERY == 0
		if parcel.is_express:
			parcel.express_time_left = EXPRESS_DEADLINE
	_next_parcel_id += 1
	parcel.next_node = board.get_next_node("depot")
	if not board.is_valid_edge("depot", parcel.next_node):
		# Keep it active until the delivery handler records the error exactly once.
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
		if parcel.is_express:
			parcel.express_time_left = maxf(0.0, parcel.express_time_left - step)
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
	last_delivery_points = 0
	if matched:
		correct += 1
		last_delivery_points = SCORE_PER_DELIVERY
		if arcade_mode and parcel.arcade_eligible:
			combo += 1
			best_combo = maxi(best_combo, combo)
			if combo >= COMBO_START:
				last_delivery_points += mini(
					MAX_COMBO_BONUS, (combo - COMBO_START + 1) * 25
				)
			if parcel.is_express and parcel.express_time_left > 0.0:
				last_delivery_points += EXPRESS_BONUS
				express_delivered += 1
			if combo > 0 and combo % 5 == 0:
				rush_remaining = RUSH_DURATION
		score += last_delivery_points
		bonus_score += last_delivery_points - SCORE_PER_DELIVERY
	else:
		mistakes += 1
		if arcade_mode:
			combo = 0
	delivery_scored.emit(parcel, matched)
	totals_changed.emit(score, correct, mistakes)
	if correct >= required_deliveries:
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
