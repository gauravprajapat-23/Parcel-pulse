extends SceneTree

# Arcade upgrade: bonus parcels, combo streaks, Rush Hour and Focus.
# All tests use deterministic controller state and an isolated UI save file.
var passed: int = 0
var failed: int = 0
const TEMP_SAVE: String = "user://arcade_upgrade_test_progress.json"


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
	_test_classic_contract()
	_test_combo_express_and_rush()
	_test_focus_and_reset()
	await _test_live_ui()
	print("Parcel Pulse Arcade: %d passed, %d failed." % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_classic_contract() -> void:
	var classic := ShiftController.new()
	_check("Classic remains default for programmatic controllers", not classic.arcade_mode)
	classic.start_shift()
	for i in range(4):
		var parcel := DeliveryParcel.new(i, "red")
		classic._register_delivery(parcel, true)
	_check("Classic keeps exactly 100 points per delivery", classic.score == 400)
	_check("Classic never awards combo or Express bonuses",
		classic.combo == 0 and classic.bonus_score == 0 and classic.express_delivered == 0)
	_check("Classic rejects Focus", not classic.activate_focus())
	classic.exit_shift()


func _test_combo_express_and_rush() -> void:
	var c := ShiftController.new()
	c.arcade_mode = true
	c.start_shift()
	var earned: Array[int] = []
	for index in range(5):
		c._spawn_parcel("red")
		var parcel: DeliveryParcel = c.parcels[c.parcels.size() - 1]
		_check("spawned parcel %d opts into arcade scoring" % (index + 1),
			parcel.arcade_eligible)
		_check("Express is deterministic at parcel %d" % (index + 1),
			parcel.is_express == (index + 1 == 4))
		parcel.current_node = "red"
		c._register_delivery(parcel, true)
		earned.append(c.last_delivery_points)
	_check("combo builds through five correct deliveries",
		c.combo == 5 and c.best_combo == 5)
	_check("Express earns double base plus current combo bonus",
		earned[3] == 250 and c.express_delivered == 1)
	_check("points rise with the combo streak",
		earned == [100, 100, 125, 250, 175])
	_check("actual score and bonus tally agree",
		c.score == 750 and c.bonus_score == 250)
	_check("five-in-a-row activates Rush Hour",
		is_equal_approx(c.rush_remaining, ShiftController.RUSH_DURATION))
	var synthetic := DeliveryParcel.new(100, "red")
	c._register_delivery(synthetic, true)
	_check("old synthetic scoring contracts remain 100 points",
		c.last_delivery_points == 100 and c.score == 850 and c.combo == 5)

	var missed := DeliveryParcel.new(101, "green")
	missed.arcade_eligible = true
	c._register_delivery(missed, false)
	_check("wrong delivery resets combo, not lifetime best",
		c.combo == 0 and c.best_combo == 5 and c.mistakes == 1)
	_check("wrong delivery never grants points",
		c.last_delivery_points == 0 and c.score == 850)
	var late := DeliveryParcel.new(102, "blue")
	late.arcade_eligible = true
	late.is_express = true
	late.express_time_left = 0.0
	var previous: int = c.express_delivered
	c._register_delivery(late, true)
	_check("late Express still delivers, but without Express bonus",
		c.last_delivery_points == 100 and c.express_delivered == previous)
	_check("late Express cannot lose a life just for missing the bonus",
		c.mistakes == 1 and c.combo == 1)
	c._register_delivery(late, true)
	_check("same Express cannot pay out twice", c.score == 950)


func _test_focus_and_reset() -> void:
	var c := ShiftController.new()
	c.arcade_mode = true
	c.start_shift()
	_check("first Focus use consumes one of two charges", c.activate_focus()
		and c.focus_charges == 1 and is_equal_approx(c.focus_remaining, 4.0))
	_check("Focus cannot be stacked", not c.activate_focus())
	c.set_paused(true)
	c.advance(2.0)
	_check("Focus remains frozen while paused",
		is_equal_approx(c.focus_remaining, ShiftController.FOCUS_DURATION))
	_check("Focus cannot be spent while paused", not c.activate_focus())
	c.set_paused(false)
	c.advance(1.0)
	_check("Focus duration counts down in real seconds",
		is_equal_approx(c.focus_remaining, 3.0))
	_check("time-slowing scales parcel movement and spawn clock",
		c.parcels.size() == 1 and c.parcels[0].progress > 0.4
		and c.parcels[0].progress < 0.7)
	c.advance(3.1)
	_check("Focus expires and clears its active timer",
		is_zero_approx(c.focus_remaining))
	_check("second Focus use consumes final charge",
		c.activate_focus() and c.focus_charges == 0)
	_check("Focus refuses any third activation", not c.activate_focus())
	c.exit_shift()
	_check("leaving a shift restores boost charges and clears timers",
		c.focus_charges == 2 and is_zero_approx(c.focus_remaining)
		and is_zero_approx(c.rush_remaining))
	_check("exiting a shift resets combos and bonus scores",
		c.combo == 0 and c.best_combo == 0 and c.bonus_score == 0)


func _test_live_ui() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
	var scene: PackedScene = load("res://scenes/game_screen.tscn")
	if scene == null:
		_check("Arcade game scene loads", false)
		return
	var game := scene.instantiate() as GameScreen
	if game == null:
		_check("Arcade game script attached", false)
		return
	game.progress_save_path = TEMP_SAVE
	root.add_child(game)
	await process_frame
	_check("interactive game enables Arcade while Classic tests do not",
		game.controller.arcade_mode)
	_check("board has status and Focus controls",
		game.board_view.arcade_banner is Label
		and game.board_view.focus_button is Button)
	_check("Focus is hidden until the shift starts",
		not game.board_view.focus_button.visible)
	game.play_button.pressed.emit()
	_check("Focus appears during gameplay",
		game.board_view.focus_button.visible
		and game.board_view.focus_button.text == "FOCUS ×2")
	game.board_view.focus_button.pressed.emit()
	_check("Focus button consumes a real gameplay charge",
		game.controller.focus_charges == 1
		and game.controller.focus_remaining > 0.0)
	_check("active Focus cannot be used again",
		game.board_view.focus_button.disabled)
	game.restart_button.pressed.emit()
	_check("Retry restores Arcade Focus charges",
		game.controller.focus_charges == 2 and game.controller.combo == 0)
	# Synthetic test completions should not receive arcade score bonuses.
	for index in range(game.controller.required_deliveries):
		game.controller._register_delivery(DeliveryParcel.new(100 + index, "red"), true)
	_check("existing fake-delivery UI tests still earn exactly base points",
		game.controller.score == game.controller.required_deliveries * 100)
	game.exit_button.pressed.emit()
	_check("Arcade status remains available before another round",
		game.controller.phase == ShiftController.Phase.READY
		and game.board_view.arcade_banner.visible)

	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE + ".tmp"))
