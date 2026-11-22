extends SceneTree

# ARCADE-02: deterministic dispatch contracts, one-time scoring, UI and reset.
# Uses isolated user:// progress; does not touch the player's save.
const TEMP_SAVE: String = "user://dispatch_challenges_test.json"
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


func _deliver_spawned(c: ShiftController, color: String, correct: bool = true) -> DeliveryParcel:
	c._spawn_parcel(color)
	var parcel: DeliveryParcel = c.parcels[c.parcels.size() - 1]
	parcel.current_node = color if correct else "blue"
	c._register_delivery(parcel, correct)
	return parcel


func _run() -> void:
	_test_mission_catalog()
	_test_rewards_and_transitions()
	_test_classic_and_legacy_arcade()
	await _test_game_screen()
	print("Parcel Pulse dispatch tests: %d passed, %d failed." % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_mission_catalog() -> void:
	_check("three challenges per shift", DispatchChallenges.MISSION_COUNT == 3)
	_check("invalid challenge indexes are empty",
		DispatchChallenges.mission_for(-1, 0).is_empty()
		and DispatchChallenges.mission_for(3, 0).is_empty())
	_check("first stage requests red parcels",
		DispatchChallenges.mission_for(0, 0)["target"] == "red")
	_check("second stage requests green parcels",
		DispatchChallenges.mission_for(0, 1)["target"] == "green")
	_check("third stage requests blue parcels",
		DispatchChallenges.mission_for(0, 2)["target"] == "blue")
	for stage in range(LevelCatalog.count()):
		for index in range(DispatchChallenges.MISSION_COUNT):
			var mission: Dictionary = DispatchChallenges.mission_for(index, stage)
			_check("stage %d challenge %d has a real goal and reward" % [stage, index],
				int(mission["goal"]) > 0 and int(mission["reward"]) > 0)


func _test_rewards_and_transitions() -> void:
	var c := ShiftController.new()
	c.arcade_mode = true
	c.dispatch_enabled = true
	var payouts: Array[int] = []
	var titles: Array[String] = []
	c.dispatch_completed.connect(func(title: String, reward: int) -> void:
		titles.append(title)
		payouts.append(reward)
	)
	c.start_shift()
	_check("starting Arcade dispatch resets progress",
		c.mission_index == 0 and c.mission_progress == 0
		and c.missions_completed == 0 and c.dispatch_bonus_score == 0)
	_check("first dispatch is a two-red delivery run",
		c.current_dispatch()["id"] == "color_run"
		and c.current_dispatch()["goal"] == 2)

	var first: DeliveryParcel = _deliver_spawned(c, "red")
	_check("one correct red progresses only the current job",
		c.mission_index == 0 and c.mission_progress == 1 and c.score == 100)
	c._register_delivery(first, true)
	_check("duplicate delivery cannot advance a contract",
		c.mission_index == 0 and c.mission_progress == 1 and c.score == 100)
	_deliver_spawned(c, "red")
	_check("color contract pays exactly once after two eligible parcels",
		c.mission_index == 1 and c.missions_completed == 1
		and c.dispatch_bonus_score == 150 and c.last_mission_reward == 150)
	_check("contract reward included in both score and feedback",
		c.score == 350 and c.last_delivery_points == 250
		and payouts == [150] and titles == ["RED DELIVERY"])

	_deliver_spawned(c, "green", false)
	_check("wrong delivery does not advance streak and still costs a try",
		c.mission_progress == 0 and c.mistakes == 1 and c.combo == 0)
	_deliver_spawned(c, "red")
	_deliver_spawned(c, "blue")
	_check("streak advances only on real Arcade deliveries",
		c.mission_index == 1 and c.mission_progress == 2)
	var synthetic := DeliveryParcel.new(700, "red")
	c._register_delivery(synthetic, true)
	_check("synthetic legacy parcel does not progress dispatch",
		c.mission_index == 1 and c.mission_progress == 2)
	_deliver_spawned(c, "red")
	_check("clean streak contract pays +200 and moves to Gold Express",
		c.mission_index == 2 and c.dispatch_bonus_score == 350
		and c.last_mission_reward == 200)
	_check("second contract completion signal emitted once",
		payouts == [150, 200])

	# The eighth spawned parcel is a deterministic Gold Express.
	_deliver_spawned(c, "blue")
	var gold: DeliveryParcel = _deliver_spawned(c, "red")
	_check("gold parcel is the eighth spawned job",
		gold.parcel_id == 8 and gold.is_express)
	_check("on-time Gold Express completes last optional contract",
		c.current_dispatch().is_empty() and c.missions_completed == 3
		and c.dispatch_bonus_score == 600)
	_check("all three contracts pay once, without changing mistake count",
		payouts == [150, 200, 250] and c.mistakes == 1
		and c.last_mission_reward == 250)
	var before_score: int = c.score
	c._register_delivery(gold, true)
	_check("completing the same Gold Express again never duplicates reward",
		c.score == before_score and payouts.size() == 3)
	_deliver_spawned(c, "green")
	_check("all-contracts-complete cannot pay another reward",
		c.dispatch_bonus_score == 600 and payouts.size() == 3)
	c.restart_shift()
	_check("Retry restores all three jobs and removes old bonuses",
		c.current_dispatch()["id"] == "color_run"
		and c.mission_index == 0 and c.mission_progress == 0
		and c.dispatch_bonus_score == 0 and c.missions_completed == 0)


func _test_classic_and_legacy_arcade() -> void:
	var classic := ShiftController.new()
	classic.start_shift()
	_deliver_spawned(classic, "red")
	_deliver_spawned(classic, "red")
	_check("Classic scoring remains 200 with no contracts",
		classic.score == 200 and classic.missions_completed == 0)
	var arcade := ShiftController.new()
	arcade.arcade_mode = true
	arcade.start_shift()
	_deliver_spawned(arcade, "red")
	_deliver_spawned(arcade, "red")
	_check("Arcade without dispatch preserves earlier scores",
		arcade.score == 200 and arcade.missions_completed == 0
		and arcade.current_dispatch().is_empty())
	var rotated := ShiftController.new()
	rotated.arcade_mode = true
	rotated.dispatch_enabled = true
	rotated.select_level(1)
	rotated.start_shift()
	_deliver_spawned(rotated, "red")
	_check("stage two does not reward the wrong target color",
		rotated.mission_progress == 0)
	_deliver_spawned(rotated, "green")
	_check("stage two progresses its green contract", rotated.mission_progress == 1)
	rotated.exit_shift()
	_check("Exit clears dispatch bonuses and progress",
		rotated.mission_index == 0 and rotated.mission_progress == 0
		and rotated.dispatch_bonus_score == 0)


func _test_game_screen() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
	var scene: PackedScene = load("res://scenes/game_screen.tscn")
	if scene == null:
		_check("game scene imports for dispatch", false)
		return
	var game := scene.instantiate() as GameScreen
	if game == null:
		_check("game uses GameScreen", false)
		return
	game.progress_save_path = TEMP_SAVE
	root.add_child(game)
	await process_frame
	_check("real gameplay enables dispatch and Arcade",
		game.controller.arcade_mode and game.controller.dispatch_enabled)
	_check("dispatch progress is hidden until Play",
		not game.dispatch_label.visible and not game.dispatch_progress.visible)
	game.play_button.pressed.emit()
	_check("first mission is visible without covering the board",
		game.dispatch_label.visible and game.dispatch_progress.visible
		and game.dispatch_label.text.contains("RED DELIVERY"))
	_check("first mission starts at 0/2", game.dispatch_label.text.contains("0/2"))
	_deliver_spawned(game.controller, "red")
	_check("dispatch bar and text track real delivery events",
		game.controller.mission_progress == 1
		and game.dispatch_progress.value == 1.0
		and game.dispatch_label.text.contains("1/2"))
	_deliver_spawned(game.controller, "red")
	_check("new mission immediately appears after completing first",
		game.dispatch_label.text.contains("CLEAN STREAK")
		and game.dispatch_progress.value == 0.0)
	_check("contract emits a visible floating reward",
		game.board_view.juice_layer.active_feedback_count() >= 3)
	game.pause_button.pressed.emit()
	_check("paused mission remains readable but cannot progress through ticking",
		game.controller.phase == ShiftController.Phase.PAUSED
		and game.dispatch_label.visible)
	game.restart_button.pressed.emit()
	_check("Retry resets the displayed mission progress",
		game.controller.mission_index == 0 and game.dispatch_progress.value == 0.0)
	game.exit_button.pressed.emit()
	_check("READY stage preview hides dispatch panel",
		not game.dispatch_label.visible and not game.dispatch_progress.visible)
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE + ".tmp"))
