extends SceneTree

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(label: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)


func _run() -> void:
	_test_ready_and_initial_red()
	_test_second_blue_and_third_green()
	_test_guide_is_pure()
	_test_unreachable_branch_explained()
	print("Parcel Pulse routing coach: %d passed, %d failed." % [passed, failed])
	quit(1 if failed > 0 else 0)


func _step(c: ShiftController, seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.000001:
		var dt: float = minf(1.0 / 60.0, remaining)
		c.advance(dt)
		remaining -= dt


func _test_ready_and_initial_red() -> void:
	var c := ShiftController.new()
	var ready: Dictionary = RoutingCoach.get_guidance(c)
	_check("ready guidance is noninteractive", ready["focus"] == "")
	c.start_shift()
	_step(c, 0.1)
	var first: Dictionary = RoutingCoach.get_guidance(c)
	_check("first red parcel points to hub", first["focus"] == "hub")
	_check("first red parcel needs no default toggle", not first["needs_action"])
	c.toggle_junction("hub")
	var changed: Dictionary = RoutingCoach.get_guidance(c)
	_check("wrong hub selection prompts a tap", changed["needs_action"] and str(changed["message"]).contains("TAP"))


func _test_second_blue_and_third_green() -> void:
	_check("blue from west must go blue", RoutingCoach.desired_exit("west", "blue") == "blue")
	_check("blue from east must go blue", RoutingCoach.desired_exit("east", "blue") == "blue")
	_check("green from hub must go east", RoutingCoach.desired_exit("hub", "green") == "east")
	_check("unknown junction has no fake exit", RoutingCoach.desired_exit("missing", "red") == "")
	var c := ShiftController.new()
	c.start_shift()
	_step(c, 1.2)
	var stage: Dictionary = RoutingCoach.get_guidance(c)
	_check("after hub, coach points at west", stage["focus"] == "west")
	_check("red remains correct on default west route", not stage["needs_action"])


func _test_guide_is_pure() -> void:
	var c := ShiftController.new()
	c.start_shift()
	_step(c, 0.2)
	var before: Dictionary = c.board.selected_output.duplicate()
	var parcel_count: int = c.parcels.size()
	var score_before: int = c.score
	for n in range(40):
		RoutingCoach.get_guidance(c)
	_check("guide never changes routing state", c.board.selected_output == before)
	_check("guide never spawns parcels", c.parcels.size() == parcel_count)
	_check("guide never changes score", c.score == score_before)


func _test_unreachable_branch_explained() -> void:
	_check("green cannot be routed out of west", RoutingCoach.desired_exit("west", "green") == "")
	_check("red cannot be routed out of east", RoutingCoach.desired_exit("east", "red") == "")
	var c := ShiftController.new()
	c.start_shift()
	c.toggle_junction("hub")
	_step(c, 1.2)
	var warning: Dictionary = RoutingCoach.get_guidance(c)
	_check("red on east branch shows a mistake explanation", str(warning["message"]).contains("wrong branch"))
	_check("unreachable parcel is never shown a false target", warning["focus"] == "" and not warning["needs_action"])
