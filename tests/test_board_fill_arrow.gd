extends SceneTree

# UI board geometry regression: prevents city art shrinking into the corner.
# Exercises an actual route toggle and its visual heading through the overlay.
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
	await _test_layers_and_arrow()
	await _test_gameplay_scene()
	print("Parcel Pulse board fill and arrow: %d passed, %d failed." % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check_layer_rects(board: BoardView, label: String) -> void:
	for layer in [board.city_art, board.dynamic_layer, board.juice_layer]:
		_check("%s: %s is at board origin" % [label, layer.name],
			layer.position.distance_to(Vector2.ZERO) < 0.1)
		_check("%s: %s fills board size" % [label, layer.name],
			layer.size.distance_to(board.size) < 1.0)
		_check("%s: %s does not consume taps" % [label, layer.name],
			layer.mouse_filter == Control.MOUSE_FILTER_IGNORE)


func _test_layers_and_arrow() -> void:
	var controller := ShiftController.new()
	var board := BoardView.new()
	board.name = "BoardUnderTest"
	board.bind_controller(controller)
	board.size = Vector2(420, 460)
	root.add_child(board)
	await process_frame
	_check("standalone board has the requested dimensions",
		board.size.distance_to(Vector2(420, 460)) < 1.0)
	_check_layer_rects(board, "initial 420x460")

	board.size = Vector2(280, 330)
	await process_frame
	_check_layer_rects(board, "resize to 280x330")

	board.size = Vector2(396, 390)
	await process_frame
	_check_layer_rects(board, "resize to 396x390")

	controller.start_shift()
	var old_route: String = controller.board.get_next_node("hub")
	var old_heading: Vector2 = board.dynamic_layer.displayed_junction_heading("hub")
	var tap: bool = board.toggle_at_local_position(board._point("hub"))
	var new_route: String = controller.board.get_next_node("hub")
	var desired: Vector2 = board.dynamic_layer.selected_junction_heading("hub")
	_check("hub changes selected branch", tap and new_route != old_route)
	_check("new branch has a visibly different direction",
		old_heading.dot(desired) < 0.85)
	_check("route tap starts an arrow transition",
		board.dynamic_layer._junction_targets.has("hub"))
	board.dynamic_layer.advance_visual(0.015)
	var intermediate: Vector2 = board.dynamic_layer.displayed_junction_heading("hub")
	_check("arrow visibly begins turning toward chosen branch",
		intermediate.dot(desired) > old_heading.dot(desired))
	board.dynamic_layer.advance_visual(0.2)
	var final_heading: Vector2 = board.dynamic_layer.displayed_junction_heading("hub")
	_check("arrow settles on current selected route",
		final_heading.dot(desired) > 0.99)
	_check("arrow animation finishes cleanly",
		not board.dynamic_layer._junction_targets.has("hub"))

	board.set_reduced_motion(true)
	var previous: String = controller.board.get_next_node("hub")
	_check("motion OFF still accepts switch input",
		board.toggle_at_local_position(board._point("hub"))
		and controller.board.get_next_node("hub") != previous)
	_check("motion OFF immediately points to selected branch",
		board.dynamic_layer.displayed_junction_heading("hub").dot(
			board.dynamic_layer.selected_junction_heading("hub")
		) > 0.999)
	controller.set_paused(true)
	_check("pause prevents switches",
		not board.toggle_at_local_position(board._point("hub")))
	controller.exit_shift()
	_check("old animation state is clear when map changes",
		controller.select_level(4)
		and board.dynamic_layer._junction_targets.is_empty())
	_check_layer_rects(board, "after Beacon Docks preview")
	board.queue_free()
	await process_frame


func _test_gameplay_scene() -> void:
	var scene := load("res://scenes/game_screen.tscn") as PackedScene
	if scene == null:
		_check("game scene loads", false)
		return
	var game := scene.instantiate() as GameScreen
	game.progress_save_path = "user://board_fill_arrow_test_progress.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress_save_path))
	root.add_child(game)
	await process_frame
	await process_frame
	var board: BoardView = game.board_view
	_check("gameplay board occupies its panel width",
		board.size.x >= game.board_container.size.x * 0.90)
	_check("gameplay board occupies its panel height",
		board.size.y >= game.board_container.size.y * 0.90)
	_check_layer_rects(board, "actual gameplay panel")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(
		"user://board_fill_arrow_test_progress.json"
	))
