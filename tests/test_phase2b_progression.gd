extends SceneTree

# Phase 2B deterministic level balance and progression usability regression.
# Uses a separate user:// save; never touches the player's own progress.
const SAVE_TEST: String = "user://phase2b_progression_test.json"
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
	_test_catalog_ramp()
	_test_full_guided_shifts()
	_test_progress_compatibility()
	await _test_next_stage_ui()
	print("Parcel Pulse Phase 2B: %d passed, %d failed." % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_catalog_ramp() -> void:
	_check("five graph-distinct levels exist", LevelCatalog.count() == 5)
	var previous_quota: int = 0
	var previous_interval: float = 999.0
	var ids: Dictionary = {}
	for index in range(LevelCatalog.count()):
		var level: Dictionary = LevelCatalog.get_level(index)
		_check("level %d passes catalog validation" % index, LevelCatalog.validate(level))
		var id: String = str(level["id"])
		_check("level %d has unique id" % index, not ids.has(id))
		ids[id] = true
		var quota: int = int(level["quota"])
		var interval: float = float(level["spawn_interval"])
		_check("level %d increases quota gradually" % index,
			quota > previous_quota and (index == 0 or quota == previous_quota + 1))
		_check("level %d speeds up gradually" % index,
			interval <= previous_interval and (index == 0 or previous_interval - interval < 0.3))
		_check("level %d exposes a difficulty label" % index,
			LevelCatalog.difficulty_text(index) != "UNKNOWN")
		previous_quota = quota
		previous_interval = interval
		var board := BoardState.new()
		_check("level %d can configure board" % index, board.configure(level, index))
		var switches: int = board.junction_ids.size()
		_check("level %d has appropriate switches" % index, switches >= 3 and switches <= 5)
		for destination in LevelCatalog.DESTINATIONS:
			_check("level %d can reach %s" % [index, destination],
				LevelCatalog.path_exists(board.edges, "depot", destination))
	_check("new levels each have different edges",
		LevelCatalog.get_level(3)["edges"] != LevelCatalog.get_level(4)["edges"])
	_check("fifth map has five tappable junctions",
		LevelCatalog.get_level(4)["edges"].size() - 1 == 5)


func _guided_switches(c: ShiftController) -> void:
	# Prioritize the parcel with least remaining time to each junction.
	var candidates: Dictionary = {}
	for parcel in c.parcels:
		if not parcel.active or parcel.progress < 0.65:
			continue
		if not c.board.is_junction(parcel.next_node):
			continue
		var target: String = RoutingCoach.desired_exit(
			parcel.next_node, parcel.destination, c.board
		)
		if not c.board.is_valid_edge(parcel.next_node, target):
			continue
		var seconds_left: float = (1.0 - parcel.progress) * ShiftController.SEGMENT_SECONDS
		if not candidates.has(parcel.next_node) or seconds_left < float(candidates[parcel.next_node]["eta"]):
			candidates[parcel.next_node] = {"route": target, "eta": seconds_left}
	for junction_id in candidates:
		var desired: String = str(candidates[junction_id]["route"])
		if c.board.get_next_node(str(junction_id)) != desired:
			c.toggle_junction(str(junction_id))


func _test_full_guided_shifts() -> void:
	for index in range(LevelCatalog.count()):
		var c := ShiftController.new()
		_check("level %d selects successfully" % index, c.select_level(index))
		c.start_shift()
		# Model one controlled frame at a time; no time skips or synthetic
		# scoring. Every success comes from reaching a real destination node.
		for frame in range(12000):
			if c.phase == ShiftController.Phase.FINISHED:
				break
			_guided_switches(c)
			c.advance(1.0 / 60.0)
		_check("level %d can be completed with real parcel movement" % index,
			c.phase == ShiftController.Phase.FINISHED and c.last_success)
		_check("level %d reaches the exact target quota" % index,
			c.correct == c.required_deliveries and c.score >= c.required_deliveries * 100)
		_check("level %d guided run has zero mistakes" % index, c.mistakes == 0)
		_check("level %d finished run ignores later updates" % index,
			c.phase == ShiftController.Phase.FINISHED)
		var stable_score: int = c.score
		c.advance(10.0)
		_check("level %d cannot score after completion" % index, c.score == stable_score)


func _test_progress_compatibility() -> void:
	var migrated: Dictionary = ProgressStore.sanitize({
		"version": 1,
		"unlocked": 3,
		"best": {
			"0": {"score": 1200, "stars": 2},
			"1": {"score": 1300, "stars": 3}
		}
	})
	_check("existing v1 saves keep previously unlocked stages",
		int(migrated["unlocked"]) == 3)
	_check("old best scores remain available",
		int(migrated["best"]["0"]["score"]) == 1200)
	_check("old save resumes at first uncleared stage",
		ProgressStore.recommended_level(migrated) == 2)
	_check("completed count ignores uncleared stages",
		ProgressStore.completed_count(migrated) == 2)

	var fresh: Dictionary = ProgressStore.initial_profile()
	_check("fresh save resumes at first stage",
		ProgressStore.recommended_level(fresh) == 0)
	for index in range(LevelCatalog.count()):
		_check("stage %d is unlocked in order" % index,
			ProgressStore.is_unlocked(fresh, index))
		fresh = ProgressStore.record_win(
			fresh, index, int(LevelCatalog.get_level(index)["quota"]) * 100, 0
		)
		_check("stage %d best record is saved" % index,
			int(fresh["best"][str(index)]["stars"]) == 3)
	_check("all five stages can become unlocked",
		int(fresh["unlocked"]) == LevelCatalog.count())
	_check("full completion resumes at last stage",
		ProgressStore.recommended_level(fresh) == LevelCatalog.count() - 1)
	_check("five completions counted from best records",
		ProgressStore.completed_count(fresh) == LevelCatalog.count())
	_check("locked stage bypass still rejected",
		not ProgressStore.is_unlocked(ProgressStore.initial_profile(), 4))


func _test_next_stage_ui() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TEST))
	var scene: PackedScene = load("res://scenes/game_screen.tscn")
	if scene == null:
		_check("gameplay scene can be loaded", false)
		return
	var game := scene.instantiate() as GameScreen
	if game == null:
		_check("gameplay GameScreen script is attached", false)
		return
	game.progress_save_path = SAVE_TEST
	root.add_child(game)
	await process_frame
	_check("level strip includes five-stage count",
		game.level_name_label.text.contains("01/05"))
	_check("level detail includes quota and difficulty",
		game.level_info_label.text.contains("INTRO") and game.level_info_label.text.contains("12"))
	game.next_level_button.pressed.emit()
	_check("preview of locked second stage works",
		game.controller.level_index == 1 and game.play_button.disabled)
	_check("locked stage has useful explanation",
		game.level_info_label.text.contains("LOCKED"))
	game.previous_level_button.pressed.emit()

	for index in range(LevelCatalog.count()):
		_check("selected stage %d is unlocked" % index,
			ProgressStore.is_unlocked(game.progress_profile, index))
		game.play_button.pressed.emit()
		_check("stage %d runs" % index, game.controller.phase == ShiftController.Phase.RUNNING)
		for n in range(game.controller.required_deliveries):
			game.controller._register_delivery(DeliveryParcel.new(100 + n, "red"), true)
		_check("stage %d completes with correct quota" % index,
			game.controller.phase == ShiftController.Phase.FINISHED and game.controller.last_success)
		var is_last: bool = index == LevelCatalog.count() - 1
		_check("stage %d next button visibility is correct" % index,
			game.result_panel.next_stage_button.visible == not is_last)
		if not is_last:
			game.result_panel.next_stage_button.pressed.emit()
			_check("stage %d next button selects the unlocked stage" % index,
				game.controller.phase == ShiftController.Phase.READY
				and game.controller.level_index == index + 1)
		else:
			game.result_panel.menu_requested.emit()
	_check("selector shows full completion progress",
		game.level_info_label.text.contains("5/5 CLEARED"))
	_check("win progression persisted to isolated disk file",
		int(ProgressStore.load_profile(SAVE_TEST)["unlocked"]) == LevelCatalog.count())

	game.queue_free()
	await process_frame
	var reopened := scene.instantiate() as GameScreen
	reopened.progress_save_path = SAVE_TEST
	root.add_child(reopened)
	await process_frame
	_check("returning player resumes at last completed stage",
		reopened.controller.level_index == LevelCatalog.count() - 1)
	reopened.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TEST))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_TEST + ".tmp"))
