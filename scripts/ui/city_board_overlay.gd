extends Control
class_name CityBoardOverlay

# Lightweight dynamic layer: route selections, gold switches, guide highlight,
# and parcel carts. Background scenery is cached by the sibling CityBoardArt.
var controller: ShiftController
var guide_focus: String = ""
var guide_needs_action: bool = false
var route_flow_phase: float = 0.0
var reduced_motion: bool = false
var _draw_accumulator: float = 0.0
var _junction_angles: Dictionary = {}
var _junction_targets: Dictionary = {}
const JUNCTION_ROTATION_SPEED: float = 14.0
const VISUAL_FRAME_STEP: float = 1.0 / 30.0

const COLOR_RED: Color = Color("#FF738C")
const COLOR_BLUE: Color = Color("#5CC8FF")
const COLOR_GREEN: Color = Color("#83F2AC")
const GOLD: Color = Color("#FFD16B")
const INK: Color = Color("#123046")


func reset_junction_animations() -> void:
	_junction_angles.clear()
	_junction_targets.clear()
	queue_redraw()


func selected_junction_heading(node_id: String) -> Vector2:
	if controller == null or not controller.board.is_junction(node_id):
		return Vector2.UP
	var route: String = controller.board.get_next_node(node_id)
	return CityBoardGeometry.route_tangent(node_id, route, 0.05, size, controller.board)


func displayed_junction_heading(node_id: String) -> Vector2:
	if _junction_angles.has(node_id):
		return Vector2.RIGHT.rotated(float(_junction_angles[node_id]))
	return selected_junction_heading(node_id)


func animate_junction(node_id: String) -> void:
	if controller == null or not controller.board.is_junction(node_id):
		return
	var selected_route: String = controller.board.get_next_node(node_id)
	var target_angle: float = selected_junction_heading(node_id).angle()
	if reduced_motion:
		_junction_angles[node_id] = target_angle
		_junction_targets.erase(node_id)
		queue_redraw()
		return
	if not _junction_angles.has(node_id):
		# The controller signal fires after the selected exit changes.
		# The other branch gives the actual previous arrow orientation.
		var exits: Array = controller.board.edges[node_id]
		for exit_id in exits:
			if str(exit_id) != selected_route:
				var previous: Vector2 = CityBoardGeometry.route_tangent(
					node_id, str(exit_id), 0.05, size, controller.board
				)
				_junction_angles[node_id] = previous.angle()
				break
	_junction_targets[node_id] = target_angle
	queue_redraw()


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if enabled:
		route_flow_phase = 0.0
		for node_id in _junction_targets.keys():
			_junction_angles[node_id] = float(_junction_targets[node_id])
		_junction_targets.clear()
	_draw_accumulator = 0.0
	queue_redraw()


func advance_visual(delta: float) -> void:
	if controller == null or controller.phase != ShiftController.Phase.RUNNING:
		return
	var step: float = maxf(delta, 0.0)
	# Accessibility: keep the carts updating, but remove decorative motion.
	if not reduced_motion:
		route_flow_phase = fposmod(route_flow_phase + step * 0.22, 1.0)
	for node_id in _junction_targets.keys():
		var target_angle: float = float(_junction_targets[node_id])
		var current_angle: float = float(_junction_angles[node_id])
		var next_angle: float = lerp_angle(
			current_angle, target_angle, clampf(step * JUNCTION_ROTATION_SPEED, 0.0, 1.0)
		)
		if absf(wrapf(target_angle - next_angle, -PI, PI)) <= 0.02:
			next_angle = target_angle
			_junction_targets.erase(node_id)
		_junction_angles[node_id] = next_angle
	_draw_accumulator += step
	if _draw_accumulator >= VISUAL_FRAME_STEP:
		_draw_accumulator = fposmod(_draw_accumulator, VISUAL_FRAME_STEP)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if controller == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_draw_active_routes()
	_draw_junctions()
	_draw_carts()


func _scale() -> float:
	return CityBoardGeometry.scale_for(size)


func _point(node_id: String) -> Vector2:
	return CityBoardGeometry.node_point(node_id, size, controller.board)


func _draw_active_routes() -> void:
	var s: float = _scale()
	for from_id in controller.board.edges.keys():
		var to_id: String = controller.board.get_next_node(from_id)
		if not controller.board.is_valid_edge(from_id, to_id):
			continue
		var tint: Color = _route_color(to_id)
		var road := CityBoardGeometry.route_polyline(str(from_id), to_id, size, 20, controller.board)
		var aura: Color = tint
		aura.a = 0.18
		draw_polyline(road, aura, 17.0 * s, true)
		var line_color: Color = tint
		line_color.a = 0.78 + 0.08 * sin(route_flow_phase * TAU)
		draw_polyline(road, line_color, 3.0 * s, true)
		for base_t in [0.16, 0.45, 0.74]:
			var t: float = fposmod(float(base_t) + route_flow_phase, 1.0)
			if t >= 0.08 and t <= 0.92:
				_draw_chevron(from_id, to_id, t, tint, s)


func _route_color(destination_id: String) -> Color:
	match destination_id:
		"red": return COLOR_RED
		"blue": return COLOR_BLUE
		"green": return COLOR_GREEN
		_:
			if controller != null and controller.board.is_junction(destination_id):
				var next_id: String = controller.board.get_next_node(destination_id)
				if next_id != "" and next_id != destination_id:
					return _route_color(next_id)
	return Color("#73E4DE")


func _draw_chevron(from_id: String, to_id: String, t: float, tint: Color, s: float) -> void:
	var point: Vector2 = CityBoardGeometry.route_point(from_id, to_id, t, size, controller.board)
	var tangent: Vector2 = CityBoardGeometry.route_tangent(from_id, to_id, t, size, controller.board)
	var perpendicular := Vector2(-tangent.y, tangent.x)
	var tip: Vector2 = point + tangent * 6.0 * s
	var back: Vector2 = point - tangent * 4.0 * s
	draw_line(back + perpendicular * 5.0 * s, tip, tint.lightened(0.23), 2.3 * s, true)
	draw_line(back - perpendicular * 5.0 * s, tip, tint.lightened(0.23), 2.3 * s, true)


func _draw_junctions() -> void:
	var s: float = _scale()
	for junction_id in controller.board.junction_ids:
		var center: Vector2 = _point(junction_id)
		var heading: Vector2 = displayed_junction_heading(junction_id)
		draw_circle(center + Vector2(1, 4) * s, 30 * s, Color("#07121C", 0.65), true)
		draw_circle(center, 30 * s, Color("#F9B852", 0.20), true)
		draw_circle(center, 24 * s, GOLD, true)
		draw_circle(center, 18 * s, Color("#895B2E"), true)
		draw_circle(center, 14 * s, Color("#F9CB70"), true)
		var tangent := Vector2(-heading.y, heading.x)
		# A wide, asymmetric arrowhead makes the selected branch readable
		# at a glance, even with the guide turned off.
		var point: Vector2 = center + heading * 8.0 * s
		draw_line(center - heading * 9.0 * s, point, INK, 4.0 * s, true)
		draw_colored_polygon(PackedVector2Array([
			point + heading * 7.0 * s,
			point - heading * 3.0 * s + tangent * 6.5 * s,
			point - heading * 3.0 * s - tangent * 6.5 * s
		]), INK)

	if controller.board.is_junction(guide_focus):
		var target: Vector2 = _point(guide_focus)
		var focus_color: Color = ParcelTheme.GOLD_LIGHT if guide_needs_action else ParcelTheme.GREEN
		var glow: Color = focus_color
		glow.a = 0.23
		draw_arc(target, 35 * s, 0.0, TAU, 44, glow, 12 * s, true)
		draw_arc(target, 35 * s, 0.0, TAU, 44, focus_color, 3.2 * s, true)


func _draw_carts() -> void:
	for parcel in controller.parcels:
		if not parcel.active:
			continue
		var at: Vector2 = CityBoardGeometry.route_point(
			parcel.current_node, parcel.next_node, parcel.progress, size, controller.board
		)
		var direction: Vector2 = CityBoardGeometry.route_tangent(
			parcel.current_node, parcel.next_node, parcel.progress, size, controller.board
		)
		_draw_cart(at, direction, parcel.destination, _scale())


func _draw_cart(center: Vector2, direction: Vector2, target: String, s: float) -> void:
	var across := Vector2(-direction.y, direction.x)
	var half_length: float = 15.0 * s
	var half_width: float = 12.0 * s
	var body_tint: Color = _route_color(target)
	var shadow := center + Vector2(2, 4) * s
	draw_circle(shadow, 19.0 * s, Color("#020B14", 0.45), true)
	# Wheel brackets remain darker than the colored package body.
	for side in [-1, 1]:
		var offset: Vector2 = across * float(side) * 11.0 * s
		draw_circle(center + offset + direction * 7.0 * s, 4.2 * s, Color("#081824"), true)
		draw_circle(center + offset - direction * 7.0 * s, 4.2 * s, Color("#081824"), true)

	var corners := PackedVector2Array([
		center - direction * half_length - across * half_width,
		center + direction * half_length - across * half_width,
		center + direction * half_length + across * half_width,
		center - direction * half_length + across * half_width
	])
	draw_colored_polygon(corners, body_tint.darkened(0.22))
	var top := PackedVector2Array([
		center - direction * 11.0 * s - across * 9.0 * s,
		center + direction * 11.0 * s - across * 9.0 * s,
		center + direction * 11.0 * s + across * 9.0 * s,
		center - direction * 11.0 * s + across * 9.0 * s
	])
	draw_colored_polygon(top, body_tint)
	draw_line(center - direction * 10 * s, center + direction * 10 * s, Color.WHITE, 1.0 * s, true)
	_draw_symbol(center, target, Color("#FFFFFF"), 7.0 * s)


func _draw_symbol(center: Vector2, target: String, ink: Color, radius: float) -> void:
	match target:
		"red":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -radius), center + Vector2(radius, 0),
				center + Vector2(0, radius), center + Vector2(-radius, 0)
			]), ink)
		"blue":
			draw_circle(center, radius * 0.8, ink, true)
		"green":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -radius),
				center + Vector2(radius, radius * 0.8),
				center + Vector2(-radius, radius * 0.8)
			]), ink)
