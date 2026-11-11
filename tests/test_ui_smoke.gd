extends SceneTree

# UI signal and synthetic-pointer smoke tests. No external testing framework.
# These do not replace real Android touch testing.
var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(label: String, valid: bool) -> void:
	if valid:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)


func _run() -> void:
	var scene: PackedScene = load("res://scenes/game_screen.tscn")
	if scene == null:
		_check("game scene loads", false)
		quit(1)
		return
	var game := scene.instantiate() as GameScreen
	if game == null:
		_check("game scene is a GameScreen", false)
		quit(1)
		return
	root.add_child(game)
	await process_frame
	_check("gameplay UI scene initializes", game.board_view != null and game.play_button != null and game.result_panel != null)
	_check("mobile action buttons use two-column layout", game.play_button.get_parent() is GridContainer and (game.play_button.get_parent() as GridContainer).columns == 2)
	_check("ready screen offers play", not game.play_button.disabled)
	_check("guide visible on first launch", game.coach_label != null and game.guide_button != null and game.guide_enabled)
	_check("new player receives guidance", not game.coach_label.text.is_empty())
	_check("ready screen prevents switching", not game.board_view.toggle_at_local_position(game.board_view._point("hub")))

	game.play_button.pressed.emit()
	_check("play starts shift", game.controller.phase == ShiftController.Phase.RUNNING and game.play_button.disabled)
	var tap: Vector2 = game.board_view._point("hub")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = tap
	game.board_view._gui_input(mouse)
	_check("mouse tap switches route once", game.controller.board.get_next_node("hub") == "east")
	game._update_guidance()
	_check("live guide responds to route change", game.board_view.guide_focus == "hub" and game.board_view.guide_needs_action)
	game.guide_button.pressed.emit()
	_check("guide can be hidden during play", not game.guide_enabled and game.board_view.guide_focus == "")
	game.guide_button.pressed.emit()
	_check("guide can be restored during play", game.guide_enabled and game.board_view.guide_focus == "hub")

	var touch := InputEventScreenTouch.new()
	touch.position = tap
	touch.pressed = true
	game.board_view._gui_input(touch)
	_check("raw touch does not duplicate emulated click", game.controller.board.get_next_node("hub") == "east")
	_check("off-board tap is ignored", not game.board_view.toggle_at_local_position(Vector2(-2000, -2000)))

	game.pause_button.pressed.emit()
	_check("pause button freezes phase", game.controller.phase == ShiftController.Phase.PAUSED and game.pause_button.text == "RESUME")
	_check("paused board rejects route taps", not game.board_view.toggle_at_local_position(tap))
	game.pause_button.pressed.emit()
	_check("resume button restarts phase", game.controller.phase == ShiftController.Phase.RUNNING)

	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check("Back pauses an active shift instead of quitting", game.controller.phase == ShiftController.Phase.PAUSED)
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check("duplicate Android Back notification does not exit the shift", game.controller.phase == ShiftController.Phase.PAUSED)
	game.handle_back_request()
	_check("Back from pause returns to ready", game.controller.phase == ShiftController.Phase.READY)
	game.play_button.pressed.emit()
	_check("new shift starts after Back navigation", game.controller.phase == ShiftController.Phase.RUNNING)
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check("backgrounding an active shift pauses it", game.controller.phase == ShiftController.Phase.PAUSED)
	game.pause_button.pressed.emit()
	game.restart_button.pressed.emit()
	_check("retry resets junction choices", game.controller.board.get_next_node("hub") == "west" and game.controller.correct == 0)
	for n in range(ShiftController.REQUIRED_DELIVERIES):
		game.controller._register_delivery(DeliveryParcel.new(n, "red"), true)
	_check("winning result overlay appears", game.result_backdrop.visible and game.controller.phase == ShiftController.Phase.FINISHED)
	game.result_panel.retry_requested.emit()
	_check("results retry returns to running without overlay", not game.result_backdrop.visible and game.controller.phase == ShiftController.Phase.RUNNING)
	game.exit_button.pressed.emit()
	_check("exit returns to ready screen", game.controller.phase == ShiftController.Phase.READY and not game.play_button.disabled)
	game.queue_free()
	await process_frame
	print("Parcel Pulse UI smoke: %d passed, %d failed." % [passed, failed])
	quit(1 if failed > 0 else 0)
