extends RefCounted
class_name RouteScheduler

# A fixed, repeatable schedule allows every shift to be reproduced during
# tests. There are more parcels than the winning quota so two mistakes are
# recoverable without paying for a second chance.
const SCHEDULE = [
	"red", "blue", "green", "red", "green", "blue",
	"blue", "red", "green", "red", "blue", "green",
	"red", "green", "blue", "blue", "red", "green",
]
const SPAWN_INTERVAL: float = 2.45

var next_index: int = 0
var time_to_next: float = 0.0


func reset() -> void:
	next_index = 0
	time_to_next = 0.0


func tick(delta: float) -> Array[String]:
	var due: Array[String] = []
	if delta <= 0.0 or next_index >= SCHEDULE.size():
		return due
	time_to_next -= delta
	while time_to_next <= 0.0 and next_index < SCHEDULE.size():
		due.append(str(SCHEDULE[next_index]))
		next_index += 1
		time_to_next += SPAWN_INTERVAL
	return due


func is_exhausted() -> bool:
	return next_index >= SCHEDULE.size()
