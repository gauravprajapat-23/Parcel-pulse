extends SceneTree

# Phase 2 — graph variations, real deliveries, progression and UI gating.
# Tests write only to dedicated user:// test files, never the player's save.
var passed: int = 0
var failed: int = 0
const PROFILE_TEST_PATH = "user://phase2_levels_regression.json"


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
	_test_catalog()
	_test_progress_records()
	_test_file_round_trip()
	_test_real_delivery_for_each_map()
	await _test_stage_ui()
	print("Parcel Pulse Phase 2: %d passed, %d failed." % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_catalog() -> void:
	_check("five distinct stages", LevelCatalog.count() == 5)
	_check("out-of-bounds level rejected", LevelCatalog.get_level(-1).is_empty() and LevelCatalog.get_level(LevelCatalog.count()).is_empty())
	var ids: Dictionary = {}
	for index in range(LevelCatalog.count()):
		var definition: Dictionary = LevelCatalog.get_level(index)
		_check("stage %d schema and graph validated" % index, LevelCatalog.validate(definition))
		_check("stage %d unique identifier" % index, not ids.has(definition["id"]))
		ids[definition["id"]] = true
		var c := ShiftController.new()
		_check("stage %d can be selected in READY" % index, c.select_level(index))
		_check("stage %d quota and spawn timing loaded" % index,
			c.required_deliveries == int(definition["quota"])
			and is_equal_approx(c.scheduler.spawn_interval, float(definition["spawn_interval"])))
		for target in LevelCatalog.DESTINATIONS:
			_check("stage %d reaches %s from depot" % [index, target],
				LevelCatalog.path_exists(c.board.edges, "depot", target))
		_check("stage %d has all required maps and switches" % index,
			c.board.junction_ids.size() >= 3 and c.board.nodes.has("depot"))
		var expected: String = RoutingCoach.desired_exit("hub", "red", c.board)
		_check("stage %d guide suggests a reachable branch" % index,
			c.board.is_valid_edge("hub", expected)
			and LevelCatalog.path_exists(c.board.edges, expected, "red"))
		c.start_shift()
		_check("stage %d cannot switch maps mid-shift" % index, not c.select_level(0))
		c.set_paused(true)
		_check("stage %d cannot switch maps while paused" % index, not c.select_level(1))
		c.exit_shift()
		_check("stage %d preserves selection after Exit" % index, c.level_index == index)

	var second: Dictionary = LevelCatalog.get_level(1)
	var first: Dictionary = LevelCatalog.get_level(0)
	var third: Dictionary = LevelCatalog.get_level(2)
	_check("stage 2 has a different destination placement",
		second["nodes"]["red"] != first["nodes"]["red"])
	_check("stage 2 reverses branch destinations",
		second["edges"]["west"].has("green") and second["edges"]["east"].has("red"))
	_check("stage 3 adds an actual fourth switch",
		third["edges"].has("upper") and not first["edges"].has("upper"))
	_check("stage 3 guide routes blue through the extra junction",
		RoutingCoach.desired_exit("west", "blue", _configured_board(2)) == "upper")
	var broken: Dictionary = LevelCatalog.get_level(1)
	broken["edges"]["west"] = ["west", "blue"]
	_check("self-loop map is rejected", not LevelCatalog.validate(broken))
	_check("broken graph does not affect built-in catalog",
		LevelCatalog.validate(LevelCatalog.get_level(1)))


func _configured_board(index: int) -> BoardState:
	var board := BoardState.new()
	board.configure(LevelCatalog.get_level(index), index)
	return board


func _test_progress_records() -> void:
	var base: Dictionary = ProgressStore.initial_profile()
	_check("new player has only first stage unlocked",
		ProgressStore.is_unlocked(base, 0) and not ProgressStore.is_unlocked(base, 1))
	var unauthorized: Dictionary = ProgressStore.record_win(base, 2, 2500, 0)
	_check("locked stage cannot silently unlock itself",
		int(unauthorized["unlocked"]) == 1)
	var first: Dictionary = ProgressStore.record_win(base, 0, 1200, 1)
	_check("first clear unlocks second stage", int(first["unlocked"]) == 2)
	_check("stars reflect remaining attempts", int(first["best"]["0"]["stars"]) == 2)
	_check("initial high score preserved",
		int(first["best"]["0"]["score"]) == 1200)
	var retry: Dictionary = ProgressStore.record_win(first, 0, 900, 2)
	_check("worse retry does not reduce best score or stars",
		int(retry["best"]["0"]["score"]) == 1200
		and int(retry["best"]["0"]["stars"]) == 2)
	var second: Dictionary = ProgressStore.record_win(retry, 1, 1300, 0)
	_check("second clear unlocks the third stage",
		int(second["unlocked"]) == 3)
	var third: Dictionary = ProgressStore.record_win(second, 2, 1400, 0)
	_check("third clear unlocks Riverside Switch",
		int(third["unlocked"]) == 4)
	var fourth: Dictionary = ProgressStore.record_win(third, 3, 1500, 1)
	_check("fourth clear unlocks Beacon Docks",
		int(fourth["unlocked"]) == 5)
	var fifth: Dictionary = ProgressStore.record_win(fourth, 4, 1600, 0)
	_check("final stage does not unlock a nonexistent sixth stage",
		int(fifth["unlocked"]) == LevelCatalog.count())
	_check("invalid save input falls back safely",
		int(ProgressStore.sanitize({"version": -1, "unlocked": 999})["unlocked"]) == 1)
	_check("unlocks are bounded to existing levels",
		int(ProgressStore.sanitize({"version": 1, "unlocked": 999, "best": {}})["unlocked"])
		== LevelCatalog.count())
	_check("record_win does not change the original profile", int(base["unlocked"]) == 1)


func _test_file_round_trip() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_TEST_PATH))
	var base: Dictionary = ProgressStore.initial_profile()
	_check("missing profile loads safe first stage",
		int(ProgressStore.load_profile(PROFILE_TEST_PATH)["unlocked"]) == 1)
	var first: Dictionary = ProgressStore.record_win(base, 0, 1200, 0)
	_check("save creates offline progress file",
		ProgressStore.save_profile(first, PROFILE_TEST_PATH))
	var loaded: Dictionary = ProgressStore.load_profile(PROFILE_TEST_PATH)
	_check("save/load retains unlocked stage",
		int(loaded["unlocked"]) == 2)
	_check("save/load retains best score and stars",
		int(loaded["best"]["0"]["score"]) == 1200
		and int(loaded["best"]["0"]["stars"]) == 3)
	var again: Dictionary = ProgressStore.record_win(loaded, 1, 1300, 1)
	_check("saving over existing profile works",
		ProgressStore.save_profile(again, PROFILE_TEST_PATH))
	_check("new profile contains unlocked third stage",
		int(ProgressStore.load_profile(PROFILE_TEST_PATH)["unlocked"]) == 3)
	var bad: FileAccess = FileAccess.open(PROFILE_TEST_PATH, FileAccess.WRITE)
	if bad != null:
		bad.store_string("{this is not valid JSON")
		bad.close()
	_check("corrupted save recovers safely",
		int(ProgressStore.load_profile(PROFILE_TEST_PATH)["unlocked"]) == 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_TEST_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_TEST_PATH + ".tmp"))


func _step_controller(c: ShiftController, seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.000001:
		var step: float = minf(1.0 / 60.0, remaining)
		c.advance(step)
		remaining -= step


func _test_real_delivery_for_each_map() -> void:
	for index in range(LevelCatalog.count()):
		var c := ShiftController.new()
		c.select_level(index)
		c.start_shift()
		# Exercise the actual graph, not a mocked success event.
		_step_controller(c, 0.05)
		_check("stage %d spawns first expected parcel" % index,
			c.parcels.size() == 1
			and c.parcels[0].destination == str(c.scheduler.schedule[0]))
		for frame in range(1300):
			if c.correct >= 1 or c.phase == ShiftController.Phase.FINISHED:
				break
			for parcel in c.parcels:
				if not parcel.active or parcel.progress < 0.65 or not c.board.is_junction(parcel.next_node):
					continue
				var desired: String = RoutingCoach.desired_exit(
					parcel.next_node, parcel.destination, c.board
				)
				if desired != "" and c.board.get_next_node(parcel.next_node) != desired:
					c.toggle_junction(parcel.next_node)
			c.advance(1.0 / 60.0)
		_check("stage %d delivers a real moving parcel" % index,
			c.correct >= 1 and c.score >= 100 and c.mistakes == 0)
		var alternate: Dictionary = LevelCatalog.get_level(index)
		var origin: Vector2 = CityBoardGeometry.node_point("depot", Vector2(400, 560), c.board)
		_check("stage %d cart coordinates follow the selected map" % index,
			origin.distance_to(Vector2(
				alternate["nodes"]["depot"].x * 400.0,
				alternate["nodes"]["depot"].y * 560.0
			)) < 0.01)


func _test_stage_ui() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_TEST_PATH))
	var scene: PackedScene = load("res://scenes/game_screen.tscn")
	var game := scene.instantiate() as GameScreen
	if game == null:
		_check("stage selector game scene loads", false)
		return
	game.progress_save_path = PROFILE_TEST_PATH
	root.add_child(game)
	await process_frame
	_check("stage selector visible in READY",
		game.level_row.visible and game.level_name_label.text.contains("Old Town"))
	game.next_level_button.pressed.emit()
	_check("locked stage can be previewed", game.controller.level_index == 1)
	_check("locked stage cannot start",
		game.play_button.disabled and game.play_button.text == "LOCKED")
	game._on_play_pressed()
	_check("direct play request cannot bypass level lock",
		game.controller.phase == ShiftController.Phase.READY)
	game.previous_level_button.pressed.emit()
	_check("previous stage returns to the first unlocked map",
		game.controller.level_index == 0 and not game.play_button.disabled)

	game.play_button.pressed.emit()
	_check("selector hidden during active shift", not game.level_row.visible)
	for n in range(game.controller.required_deliveries):
		game.controller._register_delivery(DeliveryParcel.new(n, "red"), true)
	_check("successful first stage writes progress",
		int(ProgressStore.load_profile(PROFILE_TEST_PATH)["unlocked"]) == 2)
	game.result_panel.menu_requested.emit()
	game.next_level_button.pressed.emit()
	_check("second stage becomes playable after first win",
		game.controller.level_index == 1 and not game.play_button.disabled)
	_check("stage-specific quota appears in HUD", game.progress_label.text == "0/13")
	_check("selected map changes actual road graph",
		game.controller.board.edges["west"].has("green"))
	game.play_button.pressed.emit()
	for n in range(game.controller.required_deliveries):
		game.controller._register_delivery(DeliveryParcel.new(100 + n, "red"), true)
	game.result_panel.menu_requested.emit()
	game.next_level_button.pressed.emit()
	_check("third stage unlocks with a fourth junction",
		game.controller.level_index == 2 and game.controller.board.junction_ids.size() == 4)
	_check("third stage UI reflects quota", game.progress_label.text == "0/14")
	_check("new progress persisted after second win",
		int(ProgressStore.load_profile(PROFILE_TEST_PATH)["unlocked"]) == 3)

	game.queue_free()
	await process_frame
	var reopened := scene.instantiate() as GameScreen
	reopened.progress_save_path = PROFILE_TEST_PATH
	root.add_child(reopened)
	await process_frame
	_check("fresh game loads prior unlocks from disk",
		int(reopened.progress_profile["unlocked"]) == 3)
	reopened.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_TEST_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_TEST_PATH + ".tmp"))
