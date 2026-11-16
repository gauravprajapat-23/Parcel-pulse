extends SceneTree

# Phase 2C touch QA. Uses real BoardView target selection with synthetic
# logical board sizes; physical Android taps still require device sign-off.
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
	for level_index in range(LevelCatalog.count()):
		await _exercise_map(level_index)
	print("Parcel Pulse Phase 2C touch: %d passed, %d failed." % [passed, failed])
	quit(1 if failed > 0 else 0)


func _exercise_map(level_index: int) -> void:
	var controller := ShiftController.new()
	_check("stage %d configures for touch QA" % level_index,
		controller.select_level(level_index))
	var view := BoardView.new()
	view.bind_controller(controller)
	root.add_child(view)
	await process_frame
	for board_size in [Vector2(215, 250), Vector2(228, 285), Vector2(260, 340), Vector2(480, 570)]:
		view.size = board_size
		await process_frame
		_check("stage %d at %s uses a generous target radius" % [level_index, board_size],
			view.get_junction_hit_radius() >= 48.0)
		for junction_id in controller.board.junction_ids:
			var center: Vector2 = view._point(junction_id)
			_check("stage %d: %s is directly touchable at %s" % [level_index, junction_id, board_size],
				view.junction_at_local_position(center) == junction_id)
			for offset in [Vector2(8, 0), Vector2(-8, 0), Vector2(0, 8), Vector2(0, -8)]:
				_check("stage %d: %s near-center target is stable" % [level_index, junction_id],
					view.junction_at_local_position(center + offset) == junction_id)
		_check("stage %d rejects touch outside upper-left board" % level_index,
			view.junction_at_local_position(Vector2(-3, -3)).is_empty())
		_check("stage %d rejects touch outside lower-right board" % level_index,
			view.junction_at_local_position(board_size + Vector2(3, 3)).is_empty())
		if level_index == 4:
			var upper_left: Vector2 = view._point("north_west")
			var lower_left: Vector2 = view._point("west")
			var ambiguous: Vector2 = (upper_left + lower_left) * 0.5
			_check("Beacon Docks: between neighboring switches does not guess",
				view.junction_at_local_position(ambiguous).is_empty())

	controller.start_shift()
	# Input uses emulated mouse presses exactly once and ignores the raw
	# ScreenTouch companion event on Android.
	var first_junction: String = str(controller.board.junction_ids[0])
	var position: Vector2 = view._point(first_junction)
	var initial: String = controller.board.get_next_node(first_junction)
	var events: Array[int] = [0]
	view.junction_activated.connect(func(_id: String) -> void: events[0] += 1)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	view._gui_input(press)
	var toggled: String = controller.board.get_next_node(first_junction)
	_check("stage %d: one press changes only the chosen junction" % level_index,
		toggled != initial and events[0] == 1)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	view._gui_input(release)
	var raw_touch := InputEventScreenTouch.new()
	raw_touch.pressed = true
	raw_touch.position = position
	view._gui_input(raw_touch)
	_check("stage %d: release + emulated touch never double-toggle" % level_index,
		controller.board.get_next_node(first_junction) == toggled and events == 1)
	controller.set_paused(true)
	_check("stage %d: paused touch is blocked" % level_index,
		not view.toggle_at_local_position(position))
	controller.set_paused(false)
	view._gui_input(press)
	_check("stage %d: a second actual press toggles back once" % level_index,
		controller.board.get_next_node(first_junction) == initial and events[0] == 2)
	view.queue_free()
	await process_frame
