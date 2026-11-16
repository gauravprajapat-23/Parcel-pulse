extends RefCounted
class_name RouteScheduler

# Original schedule remains the default for Phase 1 regression compatibility.
const SCHEDULE = [
	"red", "blue", "green", "red", "green", "blue",
	"blue", "red", "green", "red", "blue", "green",
	"red", "green", "blue", "blue", "red", "green",
]
const SPAWN_INTERVAL: float = 2.45

var schedule: Array[String] = []
var spawn_interval: float = SPAWN_INTERVAL
var next_index: int = 0
var time_to_next: float = 0.0


func _init() -> void:
	configure(SCHEDULE, SPAWN_INTERVAL)


func configure(new_schedule: Array, interval: float) -> bool:
	if new_schedule.is_empty() or interval <= 0.0:
		return false
	var verified: Array[String] = []
	for entry in new_schedule:
		var destination: String = str(entry)
		if not DeliveryParcel.MARKERS.has(destination):
			return false
		verified.append(destination)
	schedule = verified
	spawn_interval = interval
	reset()
	return true


func reset() -> void:
	next_index = 0
	time_to_next = 0.0


func tick(delta: float) -> Array[String]:
	var due: Array[String] = []
	if delta <= 0.0 or next_index >= schedule.size():
		return due
	time_to_next -= delta
	while time_to_next <= 0.0 and next_index < schedule.size():
		due.append(schedule[next_index])
		next_index += 1
		time_to_next += spawn_interval
	return due


func is_exhausted() -> bool:
	return next_index >= schedule.size()
