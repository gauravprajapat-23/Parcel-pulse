extends Control
class_name BoardView

# Render-only view: all routing, scoring and delivery states belong to
# ShiftController and BoardState.
var controller: ShiftController

const INK = Color("#d9edfa")
const ROAD_BACK = Color("#162b40")
const ROAD_FRONT = Color("#34516a")
const COLORS = {
	"red": Color("#ff6d8e"),
	"blue": Color("#57b5f7"),
	"green": Color("#7ce0a8"),
}


func bind_controller(value: ShiftController) -> void:
	controller = value
	controller.board.junction_changed.connect(_on_junction_changed)
	controller.phase_changed.connect(_on_phase_changed)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


func _process(_delta: float) -> void:
	if controller != null and controller.phase == ShiftController.Phase.RUNNING:
		queue_redraw()


func _on_junction_changed(_id: String, _target: String) -> void:
	queue_redraw()


func _on_phase_changed(_phase: int) -> void:
	queue_redraw()


func _point(node_id: String) -> Vector2:
	return _normalized_point(controller.board.get_position_normalized(node_id))


func _normalized_point(value: Vector2) -> Vector2:
	return Vector2(value.x * size.x, value.y * size.y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#102238"))
	if controller == null:
		return

	# Draw every possible legal edge before indicating each active direction.
	for start_id in BoardState.EDGES.keys():
		var origin: Vector2 = _point(str(start_id))
		var options: Array = BoardState.EDGES[start_id]
		for end_id in options:
			var destination: Vector2 = _point(str(end_id))
			draw_line(origin, destination, ROAD_BACK, 23.0, true)
			draw_line(origin, destination, ROAD_FRONT, 13.0, true)

	for destination_id in BoardState.DESTINATION_IDS:
		var center: Vector2 = _point(destination_id)
		var color: Color = COLORS[destination_id]
		draw_circle(center, 32.0, ROAD_BACK, true)
		draw_circle(center, 27.0, color, true)
		_draw_symbol(center, destination_id, Color("#142034"), 15.0)
		draw_string(
			get_theme_default_font(), center + Vector2(-38, 54),
			destination_id.capitalize(), HORIZONTAL_ALIGNMENT_CENTER, 76,
			17, INK
		)

	var depot_center: Vector2 = _point("depot")
	draw_circle(depot_center, 28.0, Color("#ffbd5f"), true)
	draw_rect(Rect2(depot_center - Vector2(11, 8), Vector2(22, 19)), Color("#263044"), true)
	draw_line(depot_center + Vector2(-11, -8), depot_center + Vector2(0, -17), Color.WHITE, 3.0, true)
	draw_line(depot_center + Vector2(0, -17), depot_center + Vector2(11, -8), Color.WHITE, 3.0, true)
	draw_string(
		get_theme_default_font(), depot_center + Vector2(-37, 52),
		"DEPOT", HORIZONTAL_ALIGNMENT_CENTER, 74, 17, INK
	)

	for junction_id in BoardState.JUNCTION_IDS:
		var center: Vector2 = _point(junction_id)
		var outgoing: String = controller.board.get_next_node(junction_id)
		var direction: Vector2 = (_point(outgoing) - center).normalized()
		draw_circle(center, 31.0, Color("#0d1a2b"), true)
		draw_circle(center, 25.0, Color("#ffc465"), true)
		draw_circle(center, 19.0, Color("#36536a"), true)
		draw_line(center - direction * 9.0, center + direction * 15.0, Color.WHITE, 4.0, true)
		var tip: Vector2 = center + direction * 19.0
		var side: Vector2 = Vector2(-direction.y, direction.x)
		draw_colored_polygon(PackedVector2Array([
			tip, tip - direction * 9.0 + side * 6.0,
			tip - direction * 9.0 - side * 6.0
		]), Color.WHITE)

	for parcel in controller.parcels:
		if not parcel.active:
			continue
		var position: Vector2 = _normalized_point(controller.get_parcel_position(parcel))
		draw_circle(position + Vector2(1, 4), 22.0, Color(0.0, 0.0, 0.0, 0.25), true)
		draw_circle(position, 20.0, COLORS.get(parcel.destination, Color.WHITE), true)
		draw_arc(position, 20.0, 0.0, TAU, 28, Color.WHITE, 2.0, true)
		_draw_symbol(position, parcel.destination, Color("#152339"), 10.0)


func _draw_symbol(center: Vector2, kind: String, tint: Color, radius: float) -> void:
	match kind:
		"red":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -radius), center + Vector2(radius, 0),
				center + Vector2(0, radius), center + Vector2(-radius, 0)
			]), tint)
		"blue":
			draw_circle(center, radius * 0.8, tint, true)
		"green":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -radius),
				center + Vector2(radius, radius * 0.8),
				center + Vector2(-radius, radius * 0.8)
			]), tint)


func _gui_input(event: InputEvent) -> void:
	if controller == null or controller.phase != ShiftController.Phase.RUNNING:
		return
	var tap_position: Vector2
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
			return
		tap_position = click.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return
		tap_position = touch.position
	else:
		return

	var hit_radius: float = maxf(40.0, minf(size.x, size.y) * 0.10)
	for junction_id in BoardState.JUNCTION_IDS:
		if tap_position.distance_to(_point(junction_id)) <= hit_radius:
			if controller.toggle_junction(junction_id):
				queue_redraw()
			accept_event()
			return
