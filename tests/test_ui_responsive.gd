extends SceneTree

# UI-01D: small-screen profiles, safe-area math and accessibility controls.
# Synthetic dimensions validate layout logic, not Android notch hardware.
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
	_test_layout_policies()
	_test_safe_area()
	await _test_responsive_scene()
	print("Parcel Pulse UI-01D: %d passed, %d failed." % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_layout_policies() -> void:
	var cases: Array[Vector2] = [
		Vector2(320, 640), Vector2(360, 780), Vector2(393, 852),
		Vector2(540, 960), Vector2(720, 1280)
	]
	for viewport in cases:
		var layout: Dictionary = MobileLayout.metrics(viewport)
		_check("screen %s has enough modeled content space" % viewport,
			MobileLayout.fits_minimum_content(viewport))
		_check("screen %s keeps board large enough to tap" % viewport,
			(layout["board"] as Vector2).x >= 215.0)
		_check("screen %s keeps at least 56px action height" % viewport,
			int(layout["action_height"]) >= 56)
	_check("short viewport selects compact profile",
		MobileLayout.profile_for(Vector2(360, 640)) == MobileLayout.SMALL)
	_check("normal phone selects compact profile",
		MobileLayout.profile_for(Vector2(393, 852)) == MobileLayout.COMPACT)
	_check("reference viewport selects full profile",
		MobileLayout.profile_for(Vector2(540, 960)) == MobileLayout.FULL)


func _test_safe_area() -> void:
	var logical := Vector2(540, 960)
	var no_cutout: Vector4 = MobileLayout.extra_safe_insets(
		Rect2i(0, 0, 1080, 2400), Vector2i(1080, 2400), logical
	)
	_check("full-size safe area adds no inset", no_cutout == Vector4.ZERO)
	var bars_already_excluded: Vector4 = MobileLayout.extra_safe_insets(
		Rect2i(0, 80, 1080, 2240), Vector2i(1080, 2240), logical
	)
	_check("non-edge-to-edge window does not double-pad", bars_already_excluded == Vector4.ZERO)
	var cutout: Vector4 = MobileLayout.extra_safe_insets(
		Rect2i(0, 80, 1080, 2240), Vector2i(1080, 2400), logical
	)
	_check("top and bottom unsafe areas become logical padding",
		is_equal_approx(cutout.y, 32.0) and is_equal_approx(cutout.w, 32.0))
	_check("no unexpected left/right insets", cutout.x == 0.0 and cutout.z == 0.0)
	_check("invalid physical dimensions return zero",
		MobileLayout.extra_safe_insets(Rect2i(), Vector2i.ZERO, logical) == Vector4.ZERO)


func _test_responsive_scene() -> void:
	var scene: PackedScene = load("res://scenes/game_screen.tscn")
	if scene == null:
		_check("gameplay scene loads", false)
		return
	var game := scene.instantiate() as GameScreen
	if game == null:
		_check("gameplay root script loads", false)
		return
	root.add_child(game)
	await process_frame

	_check("visible motion toggle available to players",
		game.motion_button != null and game.motion_button.text == "MOTION ON")
	_check("sound toggle stays independent",
		game.sound_button != null and game.sfx_player is SfxPlayer)

	game._apply_responsive_layout(Vector2(360, 640))
	_check("small profile hides extra subtitle and hint",
		not game.tagline_label.visible and not game.hint_label.visible)
	_check("small profile lowers board min while keeping play space",
		is_equal_approx(game.board_view.custom_minimum_size.y, 250.0))
	_check("small profile sets 56px action targets",
		is_equal_approx(game.action_bar.primary_button.custom_minimum_size.y, 56.0))
	_check("small profile has compact stat cards",
		is_equal_approx(game.hud_panel.deliveries_card.custom_minimum_size.y, 62.0))
	_check("narrow header shrinks secondary controls",
		game.motion_button.custom_minimum_size.x <= 82.0)

	game._apply_responsive_layout(Vector2(540, 960))
	_check("full layout restores title tagline and HUD",
		game.tagline_label.visible
		and is_equal_approx(game.hud_panel.deliveries_card.custom_minimum_size.y, 76.0))
	_check("full layout restores generous action targets",
		is_equal_approx(game.action_bar.primary_button.custom_minimum_size.y, 64.0))
	_check("junction remains at least 48px tappable",
		game.board_view.get_junction_hit_radius() >= 48.0)
	_check("invalid tap rejected", not game.board_view.toggle_at_local_position(Vector2(-200, -200)))

	game.play_button.pressed.emit()
	game.controller.advance(0.05)
	game.motion_button.pressed.emit()
	_check("motion toggle updates visible label and game state",
		game.reduced_motion and game.motion_button.text == "MOTION OFF"
		and game.board_view.reduced_motion)
	_check("reduced motion propagates to both draw layers",
		game.board_view.dynamic_layer.reduced_motion
		and game.board_view.juice_layer.reduced_motion)
	var before_flow: float = game.board_view.dynamic_layer.route_flow_phase
	game.board_view._process(0.4)
	_check("motion-off stops route shimmer but not the game",
		is_equal_approx(game.board_view.dynamic_layer.route_flow_phase, before_flow)
		and game.controller.phase == ShiftController.Phase.RUNNING)

	var old_route: String = game.controller.board.get_next_node("hub")
	var touched: bool = game.board_view.toggle_at_local_position(game.board_view._point("hub"))
	_check("motion-off preserves successful route selection",
		touched and game.controller.board.get_next_node("hub") != old_route)
	_check("motion-off suppresses decorative tap ripples",
		game.board_view.juice_layer.active_feedback_count() == 0)

	if not game.controller.parcels.is_empty():
		var parcel: DeliveryParcel = game.controller.parcels[0]
		parcel.current_node = "red"
		game.controller._register_delivery(parcel, true)
		_check("motion-off retains success text and authoritative scoring",
			game.board_view.juice_layer.active_feedback_count() == 1
			and game.controller.score == 100)

	game.motion_button.pressed.emit()
	_check("motion can be enabled again without restarting",
		not game.reduced_motion and game.motion_button.text == "MOTION ON"
		and not game.board_view.dynamic_layer.reduced_motion)
	game.restart_button.pressed.emit()
	_check("retry still clears effects after changing motion setting",
		game.board_view.juice_layer.active_feedback_count() == 0
		and game.controller.correct == 0 and game.controller.mistakes == 0)
	game.queue_free()
	await process_frame
