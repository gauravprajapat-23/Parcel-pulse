extends SceneTree

# ARCADE-03: temporary street incidents, safe rescue input, deterministic
# timers and no breakage of Classic/older Arcade score contracts.
const TEMP_SAVE: String = "user://arcade_03_incidents_test.json"
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
	_test_incident_catalog_and_geometry()
	_test_controller_reward_and_timing()
	_test_optional_compatibility()
	await _test_game_screen_controls()
	print("Parcel Pulse ARCADE-03: %d passed, %d failed." % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_incident_catalog_and_geometry() -> void:
	for stage in range(LevelCatalog.count()):
		var board := BoardState.new()
		_check("map %d configures for incidents" % stage,
			board.configure(LevelCatalog.get_level(stage), stage))
		var events := RoadIncidents.new()
		_check("map %d starts incident-free" % stage,
			not events.active and events.started_count == 0)
		_check("map %d does not start before countdown" % stage,
			events.advance(RoadIncidents.FIRST_DELAY - 0.1, board) == ""
			and not events.active)
		_check("map %d starts first jam deterministically" % stage,
			events.advance(0.2, board) == "started"
			and events.active and events.node_id == "hub")
		_check("map %d jam covers a real incoming road" % stage,
			board.is_valid_edge(events.approach_from, events.node_id))
		_check("map %d jam only slows the affected segment" % stage,
			is_equal_approx(
				events.speed_factor(events.approach_from, events.node_id),
				RoadIncidents.SLOW_FACTOR
			)
			and is_equal_approx(events.speed_factor("red", "blue"), 1.0))
		_check("map %d player can clear an incident once" % stage,
			events.clear() and not events.clear()
			and events.cleared_count == 1)
		_check("map %d next incident respects cooldown" % stage,
			events.advance(RoadIncidents.BETWEEN_DELAY - 0.1, board) == ""
			and not events.active)
		_check("map %d starts a second, different jam" % stage,
			events.advance(0.2, board) == "started"
			and events.active and events.node_id != "hub"
			and board.is_valid_edge(events.approach_from, events.node_id))
		_check("map %d incident can expire safely" % stage,
			events.advance(RoadIncidents.DURATION + 0.1, board) == "expired"
			and not events.active)
		_check("map %d cannot start unlimited jams" % stage,
			events.advance(120.0, board) == "" and events.started_count == 2
			and events.cleared_count == 1)
		events.reset()
		_check("map %d reset restores deterministic initial state" % stage,
			events.started_count == 0 and events.cleared_count == 0
			and is_equal_approx(events.next_in, RoadIncidents.FIRST_DELAY))


func _test_controller_reward_and_timing() -> void:
	var c := ShiftController.new()
	c.arcade_mode = true
	c.incidents_enabled = true
	var triggered: Array[String] = []
	var resolved: Array[Dictionary] = []
	c.incident_started.connect(func(id: String) -> void: triggered.append(id))
	c.incident_resolved.connect(
		func(id: String, cleared: bool, bonus: int) -> void:
			resolved.append({"junction": id, "cleared": cleared, "bonus": bonus})
	)
	c.start_shift()
	_check("clearing before a jam is rejected", not c.clear_road_incident())
	# Trigger through the real controller with a tiny physics slice so no
	# unrealistic multi-parcel delivery or time skip can mask the behavior.
	c.incidents.next_in = 0.01
	c.advance(0.02)
	_check("controller announces an active incident",
		c.incidents.active and triggered == ["hub"]
		and c.phase == ShiftController.Phase.RUNNING)
	_check("active incident does not delete a graph edge",
		c.board.is_valid_edge(c.incidents.approach_from, c.incidents.node_id))

	var slow_parcel := DeliveryParcel.new(900, "red")
	slow_parcel.current_node = c.incidents.approach_from
	slow_parcel.next_node = c.incidents.node_id
	c._advance_parcel(slow_parcel, 0.4)
	var slow_progress: float = slow_parcel.progress
	_check("affected parcel still moves forward",
		slow_progress > 0.0 and slow_progress < 0.3)
	_check("jam uses correct slow-speed fraction",
		absf(slow_progress - 0.4 * RoadIncidents.SLOW_FACTOR / ShiftController.SEGMENT_SECONDS) < 0.01)

	var previous_score: int = c.score
	var previous_mistakes: int = c.mistakes
	_check("player rescue is accepted and awards the fixed bonus",
		c.clear_road_incident()
		and c.score == previous_score + RoadIncidents.CLEAR_BONUS)
	_check("rescue changes no routes, delivery count or mistake count",
		c.correct == 0 and c.mistakes == previous_mistakes
		and c.board.get_next_node("hub") == "west")
	_check("incident reward is tracked separately from dispatch",
		c.incident_bonus_score == RoadIncidents.CLEAR_BONUS
		and c.bonus_score == RoadIncidents.CLEAR_BONUS
		and c.dispatch_bonus_score == 0)
	_check("rescue completion fires exactly once",
		resolved.size() == 1 and bool(resolved[0]["cleared"])
		and int(resolved[0]["bonus"]) == RoadIncidents.CLEAR_BONUS)
	_check("repeat rescue cannot farm points", not c.clear_road_incident()
		and c.score == previous_score + RoadIncidents.CLEAR_BONUS)

	slow_parcel.progress = 0.0
	c._advance_parcel(slow_parcel, 0.4)
	_check("cleared incoming road immediately runs at normal speed",
		slow_parcel.progress > slow_progress + 0.1)
	c.set_paused(true)
	var waiting: float = c.incidents.next_in
	c.advance(4.0)
	_check("Pause freezes the next incident timer",
		is_equal_approx(c.incidents.next_in, waiting))
	_check("cannot clear an incident while paused", not c.clear_road_incident())
	c.set_paused(false)
	# A second incident starts after a deterministic 12-second cooldown.
	c.incidents.next_in = 0.01
	c.advance(0.02)
	_check("second jam starts at a different road",
		c.incidents.active and c.incidents.node_id == "west"
		and triggered.size() == 2)
	var pre_timeout_score: int = c.score
	var pre_timeout_mistakes: int = c.mistakes
	c.incidents.remaining = 0.01
	c.advance(0.02)
	_check("uncleared incident expires automatically without punishment",
		not c.incidents.active and c.score == pre_timeout_score
		and c.mistakes == pre_timeout_mistakes)
	_check("timeout emits zero-reward resolution",
		resolved.size() == 2 and not bool(resolved[1]["cleared"])
		and int(resolved[1]["bonus"]) == 0)
	c.restart_shift()
	_check("Retry resets timer, event count and reward",
		c.incident_bonus_score == 0
		and c.incidents.started_count == 0
		and c.incidents.cleared_count == 0
		and not c.incidents.active)
	c.incidents.next_in = 0.01
	c.advance(0.02)
	c.exit_shift()
	_check("Exit clears active hazard and restores READY",
		c.phase == ShiftController.Phase.READY
		and not c.incidents.active and not c.clear_road_incident())


func _test_optional_compatibility() -> void:
	var classic := ShiftController.new()
	classic.start_shift()
	classic.advance(20.0)
	_check("Classic mode never enables incidents",
		not classic.incidents.active and classic.incidents.started_count == 0)
	var arcade := ShiftController.new()
	arcade.arcade_mode = true
	arcade.start_shift()
	arcade.advance(20.0)
	_check("Arcade defaults remain incident-free for older tests",
		not arcade.incidents.active and arcade.incidents.started_count == 0)
	_check("old controllers cannot collect incident bonuses",
		not classic.clear_road_incident() and not arcade.clear_road_incident())


func _test_game_screen_controls() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
	var scene: PackedScene = load("res://scenes/game_screen.tscn")
	if scene == null:
		_check("game scene loads", false)
		return
	var game := scene.instantiate() as GameScreen
	if game == null:
		_check("game screen is attached", false)
		return
	game.progress_save_path = TEMP_SAVE
	root.add_child(game)
	await process_frame
	_check("real game enables incidents and rescue UI",
		game.controller.incidents_enabled
		and game.board_view.clear_road_button is Button)
	_check("clear control hidden while READY",
		not game.board_view.clear_road_button.visible)
	game.play_button.pressed.emit()
	_check("clear control hidden before incident appears",
		not game.board_view.clear_road_button.visible)
	game.controller.incidents.next_in = 0.01
	game.controller.advance(0.02)
	_check("active jam shows a rescue control with countdown",
		game.controller.incidents.active
		and game.board_view.clear_road_button.visible
		and game.board_view.clear_road_button.text.contains("CLEAR"))
	for small_size in [Vector2(215, 250), Vector2(228, 285), Vector2(260, 340)]:
		var isolated := BoardView.new()
		isolated.bind_controller(game.controller)
		isolated.size = small_size
		root.add_child(isolated)
		await process_frame
		var focus_rect := Rect2(
			isolated.focus_button.position, isolated.focus_button.size
		)
		var clear_rect := Rect2(
			isolated.clear_road_button.position, isolated.clear_road_button.size
		)
		_check("board %s: rescue/Focus controls never overlap" % small_size,
			not focus_rect.intersects(clear_rect))
		_check("board %s: controls remain inside board" % small_size,
			Rect2(Vector2.ZERO, isolated.size).encloses(focus_rect)
			and Rect2(Vector2.ZERO, isolated.size).encloses(clear_rect))
		isolated.queue_free()
		await process_frame
	var mark: Vector2 = game.board_view.incident_marker_position()
	_check("road warning point lies inside the visible board",
		Rect2(Vector2.ZERO, game.board_view.size).has_point(mark))
	var heading_before: String = game.controller.board.get_next_node("hub")
	var previous_score: int = game.controller.score
	_check("tapping the road marker clears the jam",
		game.board_view.clear_incident_at_local_position(mark))
	_check("road rescue tap does not rotate nearby junction",
		game.controller.board.get_next_node("hub") == heading_before)
	_check("marker rescue pays once and hides clear control",
		game.controller.score == previous_score + RoadIncidents.CLEAR_BONUS
		and not game.board_view.clear_road_button.visible)
	var earned_effect: bool = false
	for effect in game.board_view.juice_layer.effects:
		if str(effect["kind"]) == "rescue":
			earned_effect = int(effect.get("points", 0)) == RoadIncidents.CLEAR_BONUS
	_check("player sees a correctly labeled rescue reward", earned_effect)
	game.controller.incidents.next_in = 0.01
	game.controller.advance(0.02)
	game.controller.set_paused(true)
	_check("rescue button disabled when paused",
		game.board_view.clear_road_button.visible
		and game.board_view.clear_road_button.disabled)
	var paused_bonus: int = game.controller.incident_bonus_score
	game.board_view.clear_road_button.pressed.emit()
	_check("paused button press cannot grant a reward",
		game.controller.incident_bonus_score == paused_bonus
		and game.controller.incidents.active)
	game.controller.set_paused(false)
	game.board_view.clear_road_button.pressed.emit()
	_check("working rescue button grants one-time reward",
		game.controller.incident_bonus_score == paused_bonus + RoadIncidents.CLEAR_BONUS)
	game.restart_button.pressed.emit()
	_check("Retry clears incident UI and player score",
		not game.board_view.clear_road_button.visible
		and game.controller.incident_bonus_score == 0
		and game.controller.score == 0)
	game.exit_button.pressed.emit()
	_check("Exit keeps rescue control hidden",
		game.controller.phase == ShiftController.Phase.READY
		and not game.board_view.clear_road_button.visible)
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SAVE + ".tmp"))
