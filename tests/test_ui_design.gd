extends SceneTree

# UI-01A reusable theme/HUD/action-bar contract checks.
# Execute with Godot --headless; these tests do not replace phone screenshots.
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
		_check("gameplay scene imports", false)
		quit(1)
		return
	var game := scene.instantiate() as GameScreen
	if game == null:
		_check("gameplay script imports", false)
		quit(1)
		return
	root.add_child(game)
	await process_frame

	_check("HUD uses three reusable stat cards",
		game.hud_panel != null
		and game.hud_panel.deliveries_card is StatCard
		and game.hud_panel.score_card is StatCard
		and game.hud_panel.lives_card is StatCard)
	_check("HUD initial values use gameplay model",
		game.progress_label.text == "0/12"
		and game.score_label.text == "0"
		and game.mistakes_label.text == "3")
	_check("HUD captions are distinct",
		game.hud_panel.deliveries_card.caption_label.text == "DELIVERIES"
		and game.hud_panel.score_card.caption_label.text == "SCORE"
		and game.hud_panel.lives_card.caption_label.text == "TRIES LEFT")
	_check("HUD has shared neon panel styles",
		game.hud_panel.deliveries_card.has_theme_stylebox_override("panel")
		and game.hud_panel.score_card.has_theme_stylebox_override("panel"))
	_check("actions use exactly four reusable buttons",
		game.action_bar.get_child_count() == 4
		and game.action_bar.columns == 2
		and game.action_bar.primary_button is ActionButton
		and game.action_bar.guide_button is ActionButton)
	_check("button styles include normal, pressed and disabled states",
		game.action_bar.primary_button.has_theme_stylebox_override("normal")
		and game.action_bar.primary_button.has_theme_stylebox_override("pressed")
		and game.action_bar.primary_button.has_theme_stylebox_override("disabled"))
	_check("button touch targets have 64 logical pixel height",
		game.action_bar.primary_button.custom_minimum_size.y >= 64.0
		and game.action_bar.retry_button.custom_minimum_size.y >= 64.0)
	_check("one primary button replaces duplicate Play and Pause",
		game.play_button == game.pause_button
		and game.play_button.text == "PLAY"
		and not game.play_button.disabled)

	game.play_button.pressed.emit()
	_check("primary Play starts exactly one shift",
		game.controller.phase == ShiftController.Phase.RUNNING
		and game.action_bar.primary_button.text == "PAUSE")
	game.pause_button.pressed.emit()
	_check("primary Pause freezes running shift",
		game.controller.phase == ShiftController.Phase.PAUSED
		and game.action_bar.primary_button.text == "RESUME")
	game.pause_button.pressed.emit()
	_check("primary Resume returns to running",
		game.controller.phase == ShiftController.Phase.RUNNING
		and game.action_bar.primary_button.text == "PAUSE")

	game.controller._register_delivery(DeliveryParcel.new(123, "red"), true)
	game.controller._register_delivery(DeliveryParcel.new(124, "red"), false)
	_check("HUD reacts to correct and wrong delivery",
		game.progress_label.text == "1/12"
		and game.score_label.text == "100"
		and game.mistakes_label.text == "2")
	var was_enabled: bool = game.guide_enabled
	game.guide_button.pressed.emit()
	_check("guide action toggles exactly once",
		game.guide_enabled != was_enabled
		and game.action_bar.guide_button.text == "GUIDE OFF")
	game.guide_button.pressed.emit()
	_check("guide can be restored",
		game.guide_enabled == was_enabled
		and game.action_bar.guide_button.text == "GUIDE ON")

	game.restart_button.pressed.emit()
	_check("retry resets HUD and starts a clean shift",
		game.controller.phase == ShiftController.Phase.RUNNING
		and game.progress_label.text == "0/12"
		and game.score_label.text == "0"
		and game.mistakes_label.text == "3")
	game.exit_button.pressed.emit()
	_check("exit returns to ready without losing action controls",
		game.controller.phase == ShiftController.Phase.READY
		and game.action_bar.primary_button.text == "PLAY"
		and not game.action_bar.primary_button.disabled)

	game.queue_free()
	await process_frame
	print("Parcel Pulse UI-01A: %d passed, %d failed." % [passed, failed])
	quit(1 if failed > 0 else 0)
