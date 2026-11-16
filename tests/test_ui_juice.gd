extends SceneTree

# UI-01C: event-driven game-feel regression. Does not verify audible output,
# frame pacing, or actual display behavior on physical Android devices.
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
	var scene: PackedScene = load("res://scenes/game_screen.tscn")
	if scene == null:
		_check("game scene imports", false)
		quit(1)
		return
	var game := scene.instantiate() as GameScreen
	if game == null:
		_check("game root has GameScreen script", false)
		quit(1)
		return
	# Isolate synthetic wins from the player's real Android/desktop save.
	game.progress_save_path = "user://phase2_test_ui_juice_profile.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress_save_path))
	root.add_child(game)
	await process_frame

	_check("visual feedback is a separate no-input layer",
		game.board_view.juice_layer is GameJuice
		and game.board_view.juice_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_check("generated sound system is present", game.sfx_player is SfxPlayer)
	_check("five original sound cues are available", game.sfx_player._players.size() == 5)
	for sound_name in ["tap", "success", "mistake", "win", "pause"]:
		var player: AudioStreamPlayer = game.sfx_player._players[sound_name]
		var wav := player.stream as AudioStreamWAV
		_check("cue %s has playable PCM data" % sound_name,
			wav != null and wav.data.size() > 100 and wav.mix_rate == SfxPlayer.SAMPLE_RATE)

	game.sound_button.pressed.emit()
	_check("sound can be muted from UI", not game.sfx_player.enabled and game.sound_button.text == "SFX OFF")
	game.sound_button.pressed.emit()
	_check("sound can be enabled from UI", game.sfx_player.enabled and game.sound_button.text == "SFX ON")
	# Silence testing: sounds are validated as data but needn't be audible in CI.
	game.sfx_player.set_enabled(false)
	game.play_button.pressed.emit()
	game.controller.advance(0.05)
	_check("starting a shift keeps score at zero", game.controller.score == 0 and game.controller.mistakes == 0)

	var first_effects: int = game.board_view.juice_layer.active_feedback_count()
	var tapped: bool = game.board_view.toggle_at_local_position(game.board_view._point("hub"))
	_check("a valid tap adds one feedback event",
		tapped and game.board_view.juice_layer.active_feedback_count() == first_effects + 1)
	_check("tap ripple changes no score or mistakes",
		game.controller.score == 0 and game.controller.mistakes == 0)

	var before_flow: float = game.board_view.dynamic_layer.route_flow_phase
	game.board_view._process(0.4)
	_check("running routes advance the visual shimmer",
		game.board_view.dynamic_layer.route_flow_phase != before_flow)
	game.pause_button.pressed.emit()
	var paused_flow: float = game.board_view.dynamic_layer.route_flow_phase
	game.board_view._process(0.4)
	_check("paused routes freeze shimmer",
		is_equal_approx(game.board_view.dynamic_layer.route_flow_phase, paused_flow))
	game.pause_button.pressed.emit()

	# One real parcel is enough to verify visual effects observe controller
	# events rather than awarding score independently.
	if not game.controller.parcels.is_empty():
		var parcel: DeliveryParcel = game.controller.parcels[0]
		parcel.current_node = "red"
		var effects_before: int = game.board_view.juice_layer.active_feedback_count()
		game.controller._register_delivery(parcel, true)
		_check("correct delivery adds one +100 effect",
			game.board_view.juice_layer.active_feedback_count() == effects_before + 1
			and game.controller.score == 100)
		game.controller._register_delivery(parcel, true)
		_check("duplicate parcel result adds no reward or feedback",
			game.board_view.juice_layer.active_feedback_count() == effects_before + 1
			and game.controller.score == 100)

	var wrong := DeliveryParcel.new(101, "green")
	wrong.current_node = "blue"
	var after_success: int = game.board_view.juice_layer.active_feedback_count()
	game.controller._register_delivery(wrong, false)
	_check("wrong delivery creates one warning, not extra points",
		game.board_view.juice_layer.active_feedback_count() == after_success + 1
		and game.controller.score == 100 and game.controller.mistakes == 1)

	game.restart_button.pressed.emit()
	_check("retry clears stale effects and flowing-route phase",
		game.board_view.juice_layer.active_feedback_count() == 0
		and is_zero_approx(game.board_view.dynamic_layer.route_flow_phase))
	_check("retry still resets authoritative game state",
		game.controller.score == 0 and game.controller.correct == 0
		and game.controller.mistakes == 0)

	for n in range(ShiftController.REQUIRED_DELIVERIES):
		var success_parcel := DeliveryParcel.new(200 + n, "red")
		success_parcel.current_node = "red"
		game.controller._register_delivery(success_parcel, true)
	_check("successful result overlay has a rating",
		game.result_backdrop.visible and game.result_panel.rating_label != null
		and game.result_panel.rating_label.text == "★★★")
	_check("result transition does not change completed score",
		game.controller.phase == ShiftController.Phase.FINISHED
		and game.controller.score == ShiftController.REQUIRED_DELIVERIES * ShiftController.SCORE_PER_DELIVERY)
	game.result_panel.retry_requested.emit()
	_check("result retry hides overlay and clears feedback",
		not game.result_backdrop.visible
		and game.board_view.juice_layer.active_feedback_count() == 0)
	game.exit_button.pressed.emit()
	_check("exit leaves game ready without effects",
		game.controller.phase == ShiftController.Phase.READY
		and game.board_view.juice_layer.active_feedback_count() == 0)

	game.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress_save_path))
	await process_frame

	var isolated := GameJuice.new()
	root.add_child(isolated)
	isolated.show_junction("west")
	isolated.show_junction("invalid")
	_check("invalid junction cannot create a ripple", isolated.active_feedback_count() == 1)
	isolated._process(GameJuice.EFFECT_LIFETIME + 0.1)
	_check("expired effects are removed", isolated.active_feedback_count() == 0)
	isolated.queue_free()

	print("Parcel Pulse UI-01C: %d passed, %d failed." % [passed, failed])
	quit(1 if failed > 0 else 0)
