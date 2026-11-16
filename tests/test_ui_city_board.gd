extends SceneTree

# UI-01B regression: procedural scene composition and one geometric source
# of truth for roads and cart positions. Does not claim device visual parity.
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
	_test_geometry()
	await _test_scene_and_input()
	print("Parcel Pulse UI-01B: %d passed, %d failed." % [passed, failed])
	quit(1 if failed > 0 else 0)


func _test_geometry() -> void:
	var landscape: Vector2 = Vector2(480, 570)
	var narrow: Vector2 = Vector2(275, 400)
	for bounds in [landscape, narrow]:
		for source in BoardState.EDGES.keys():
			var outgoing: Array = BoardState.EDGES[source]
			for target in outgoing:
				var origin: Vector2 = CityBoardGeometry.node_point(str(source), bounds)
				var end: Vector2 = CityBoardGeometry.node_point(str(target), bounds)
				var first: Vector2 = CityBoardGeometry.route_point(str(source), str(target), 0.0, bounds)
				var last: Vector2 = CityBoardGeometry.route_point(str(source), str(target), 1.0, bounds)
				_check("%s->%s road starts on node for %s" % [source, target, bounds], first.distance_to(origin) < 0.02)
				_check("%s->%s road ends on node for %s" % [source, target, bounds], last.distance_to(end) < 0.02)
				var points: PackedVector2Array = CityBoardGeometry.route_polyline(str(source), str(target), bounds)
				_check("%s->%s road has sampled path" % [source, target], points.size() >= 18)
				var midpoint: Vector2 = CityBoardGeometry.route_point(str(source), str(target), 0.5, bounds)
				_check("%s->%s midpoint stays inside the board" % [source, target],
					midpoint.x >= 0.0 and midpoint.x <= bounds.x and midpoint.y >= 0.0 and midpoint.y <= bounds.y)
				_check("%s->%s tangent is usable" % [source, target],
					CityBoardGeometry.route_tangent(str(source), str(target), 0.4, bounds).length() > 0.9)

	_check("invalid graph edge never draws a road",
		CityBoardGeometry.route_polyline("depot", "green", landscape).is_empty())
	_check("invalid graph edge cannot invent a cart destination",
		CityBoardGeometry.route_point("depot", "green", 0.5, landscape)
		== CityBoardGeometry.node_point("depot", landscape))
	_check("curved route visually differs from straight-line interpolation",
		CityBoardGeometry.route_point("hub", "west", 0.5, landscape).distance_to(
			CityBoardGeometry.node_point("hub", landscape).lerp(
				CityBoardGeometry.node_point("west", landscape), 0.5
			)
		) > 0.3)


func _test_scene_and_input() -> void:
	var scene: PackedScene = load("res://scenes/game_screen.tscn")
	if scene == null:
		_check("gameplay scene loads", false)
		return
	var game := scene.instantiate() as GameScreen
	if game == null:
		_check("gameplay root type", false)
		return
	root.add_child(game)
	await process_frame

	var board: BoardView = game.board_view
	_check("board builds one static city layer", board.city_art is CityBoardArt)
	_check("board builds one dynamic overlay", board.dynamic_layer is CityBoardOverlay)
	_check("city and dynamic layers occupy the same board bounds",
		board.city_art.size.distance_to(board.dynamic_layer.size) <= 1.0)
	_check("decorations do not block touches",
		board.city_art.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and board.dynamic_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and board.mouse_filter == Control.MOUSE_FILTER_STOP)
	_check("overlay references the authoritative controller", board.dynamic_layer.controller == game.controller)
	_check("board keeps clipping within its frame", board.clip_contents)

	game.play_button.pressed.emit()
	game.controller.advance(0.2)
	_check("a live parcel exists", game.controller.parcels.size() > 0)
	if not game.controller.parcels.is_empty():
		var parcel: DeliveryParcel = game.controller.parcels[0]
		var displayed: Vector2 = board.get_rendered_parcel_position(parcel)
		var expected: Vector2 = CityBoardGeometry.route_point(
			parcel.current_node, parcel.next_node, parcel.progress, board.size
		)
		_check("moving cart exactly follows the drawn curved road", displayed.distance_to(expected) < 0.01)

	var old_route: String = game.controller.board.get_next_node("hub")
	var touched: bool = board.toggle_at_local_position(board._point("hub"))
	_check("junction remains tappable at its displayed center",
		touched and game.controller.board.get_next_node("hub") != old_route)
	game._update_guidance()
	_check("guide focus reaches dynamic layer",
		board.dynamic_layer.guide_focus == board.guide_focus
		and board.dynamic_layer.guide_needs_action == board.guide_needs_action)
	game.pause_button.pressed.emit()
	_check("paused board ignores touch", not board.toggle_at_local_position(board._point("hub")))
	game.queue_free()
	await process_frame
