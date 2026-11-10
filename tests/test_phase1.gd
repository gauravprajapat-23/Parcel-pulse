extends SceneTree

# Dependency-free headless regression suite:
# godot --headless --path . --script res://tests/test_phase1.gd
var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_board_routes()
	_test_invalid_junctions()
	_test_movement_and_correct_delivery()
	_test_wrong_delivery()
	_test_pausing_and_resuming()
	_test_failure_at_three_errors()
	_test_restart_clears_state()
	_test_duplicate_scoring_guard()
	_test_success_and_single_finish_signal()
	_test_full_shift_with_real_routing()
	_test_bad_route_is_safe()
	print("Parcel Pulse Phase 1: %d passed, %d failed." % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(description: String, condition: bool) -> void:
	if condition:
		passed += 1
		print("PASS ", description)
	else:
		failed += 1
		push_error("FAIL " + description)


func _step(controller: ShiftController, duration: float) -> void:
	var remaining: float = duration
	while remaining > 0.00001:
		var timestep: float = minf(1.0 / 60.0, remaining)
		controller.advance(timestep)
		remaining -= timestep


func _test_board_routes() -> void:
	var board := BoardState.new()
	_check("three junctions and three destinations", BoardState.JUNCTION_IDS.size() == 3 and BoardState.DESTINATION_IDS.size() == 3)
	_check("depot links to hub", board.get_next_node("depot") == "hub")
	_check("hub initially routes west", board.get_next_node("hub") == "west")
	_check("hub toggle routes east", board.toggle_junction("hub") and board.get_next_node("hub") == "east")
	_check("west toggle routes blue", board.toggle_junction("west") and board.get_next_node("west") == "blue")
	_check("east initially routes green", board.get_next_node("east") == "green")
	board.reset()
	_check("board reset restores routes", board.get_next_node("hub") == "west" and board.get_next_node("west") == "red")
	_check("all destination nodes exist", board.has_node("red") and board.has_node("blue") and board.has_node("green"))


func _test_invalid_junctions() -> void:
	var board := BoardState.new()
	_check("unknown junction rejected", not board.toggle_junction("missing"))
	_check("destination cannot be toggled", not board.toggle_junction("red"))
	_check("unknown edge rejected", not board.is_valid_edge("depot", "green"))
	_check("unknown next node is safe", board.get_next_node("missing") == "")
	_check("terminal node has no outgoing route", board.get_next_node("red") == "")


func _test_movement_and_correct_delivery() -> void:
	var controller := ShiftController.new()
	controller.start_shift()
	_step(controller, 0.1)
	_check("first parcel spawns", controller.parcels.size() == 1)
	if controller.parcels.is_empty():
		return
	var parcel: DeliveryParcel = controller.parcels[0]
	var before: Vector2 = controller.get_parcel_position(parcel)
	_step(controller, 0.4)
	var after: Vector2 = controller.get_parcel_position(parcel)
	_check("parcel moves each physics tick", before.distance_to(after) > 0.001)
	_check("direction vector is stored", parcel.travel_direction.length() > 0.9)
	_step(controller, 3.0)
	_check("first red parcel reaches red house", controller.correct >= 1 and controller.score >= 100)
	_check("successful delivery does not count as mistake", controller.mistakes == 0)


func _test_wrong_delivery() -> void:
	var controller := ShiftController.new()
	controller.start_shift()
	controller.toggle_junction("west")
	_step(controller, 3.5)
	_check("red parcel to blue house counts as error", controller.mistakes == 1)
	_check("wrong delivery awards no points", controller.score == 0)


func _test_pausing_and_resuming() -> void:
	var controller := ShiftController.new()
	controller.start_shift()
	_step(controller, 0.2)
	var before: float = controller.parcels[0].progress
	controller.set_paused(true)
	_step(controller, 5.0)
	_check("paused phase entered", controller.phase == ShiftController.Phase.PAUSED)
	_check("paused parcel position freezes", is_equal_approx(before, controller.parcels[0].progress))
	_check("paused scheduler stays frozen", controller.scheduler.next_index == 1)
	_check("cannot toggle while paused", not controller.toggle_junction("hub"))
	controller.set_paused(false)
	_step(controller, 0.2)
	_check("resume unfreezes parcels", controller.phase == ShiftController.Phase.RUNNING and controller.parcels[0].progress > before)


func _test_failure_at_three_errors() -> void:
	var controller := ShiftController.new()
	var finished_events: Array[bool] = []
	controller.shift_finished.connect(func(success: bool, _score: int, _correct: int, _mistakes: int) -> void: finished_events.append(success))
	controller.start_shift()
	_step(controller, 23.0)
	_check("three wrong deliveries finish the shift", controller.phase == ShiftController.Phase.FINISHED and controller.mistakes == 3)
	_check("failed shift reports false once", finished_events.size() == 1 and not finished_events[0])
	var settled_score: int = controller.score
	_step(controller, 10.0)
	_check("finished game cannot score again", controller.score == settled_score and finished_events.size() == 1)


func _test_restart_clears_state() -> void:
	var controller := ShiftController.new()
	controller.start_shift()
	_step(controller, 5.0)
	controller.restart_shift()
	_check("restart clears active packages", controller.parcels.is_empty())
	_check("restart clears score and mistakes", controller.score == 0 and controller.correct == 0 and controller.mistakes == 0)
	_check("restart resets schedule", controller.scheduler.next_index == 0)
	_check("restart sets RUNNING", controller.phase == ShiftController.Phase.RUNNING)
	_step(controller, 0.02)
	_check("new shift spawns exactly one first parcel", controller.parcels.size() == 1 and controller.scheduler.next_index == 1)
	controller.exit_shift()
	_check("exit clears shift and returns to READY", controller.phase == ShiftController.Phase.READY and controller.parcels.is_empty())
	_check("cannot toggle when ready", not controller.toggle_junction("west"))


func _test_duplicate_scoring_guard() -> void:
	var controller := ShiftController.new()
	controller.start_shift()
	var parcel := DeliveryParcel.new(42, "red")
	controller._register_delivery(parcel, true)
	controller._register_delivery(parcel, true)
	_check("same parcel cannot award twice", controller.correct == 1 and controller.score == 100)
	_check("duplicate never adds a mistake", controller.mistakes == 0)


func _test_success_and_single_finish_signal() -> void:
	var controller := ShiftController.new()
	var wins: Array[bool] = []
	controller.shift_finished.connect(func(success: bool, _score: int, _correct: int, _mistakes: int) -> void: wins.append(success))
	controller.start_shift()
	for n in range(ShiftController.REQUIRED_DELIVERIES):
		controller._register_delivery(DeliveryParcel.new(n, "red"), true)
	_check("quota finishes a successful shift", controller.phase == ShiftController.Phase.FINISHED and controller.last_success)
	_check("win score matches exactly 12 deliveries", controller.correct == 12 and controller.score == 1200)
	controller._register_delivery(DeliveryParcel.new(99, "red"), true)
	_check("finished shift emits result only once", wins.size() == 1 and wins[0] and controller.correct == 12)


func _guide_parcels(controller: ShiftController) -> void:
	# The test player toggles junctions shortly before each arrival.
	for parcel in controller.parcels:
		if not parcel.active or parcel.progress < 0.8:
			continue
		var desired: String = ""
		if parcel.next_node == "hub":
			desired = "east" if parcel.destination == "green" else "west"
		elif parcel.next_node == "west":
			desired = "blue" if parcel.destination == "blue" else "red"
		elif parcel.next_node == "east":
			desired = "green" if parcel.destination == "green" else "blue"
		if desired != "" and controller.board.get_next_node(parcel.next_node) != desired:
			controller.toggle_junction(parcel.next_node)


func _test_full_shift_with_real_routing() -> void:
	var controller := ShiftController.new()
	controller.start_shift()
	for n in range(2600):
		if controller.phase == ShiftController.Phase.FINISHED:
			break
		_guide_parcels(controller)
		controller.advance(1.0 / 60.0)
	_check("full playable shift reaches quota via actual routes", controller.phase == ShiftController.Phase.FINISHED and controller.last_success)
	_check("full playable shift earns at least 12 correct", controller.correct == 12 and controller.mistakes == 0)


func _test_bad_route_is_safe() -> void:
	var controller := ShiftController.new()
	controller.start_shift()
	controller.board.selected_output["west"] = 99
	_step(controller, 3.5)
	_check("invalid junction selection is handled as mistake", controller.mistakes == 1 and controller.correct == 0)
	_check("invalid junction selection does not crash the shift", controller.phase == ShiftController.Phase.RUNNING)
