extends Control
class_name BoardView

# UI-01B composition layer. CityBoardArt renders static decorative content,
# CityBoardOverlay renders moving visuals. Both use the same visual geometry.
# Input and gameplay remain owned by this view and ShiftController respectively.
var controller: ShiftController
var guide_focus: String = ""
var guide_needs_action: bool = false
var city_art: CityBoardArt
var dynamic_layer: CityBoardOverlay


func bind_controller(value: ShiftController) -> void:
	if controller != null:
		if controller.board.junction_changed.is_connected(_on_junction_changed):
			controller.board.junction_changed.disconnect(_on_junction_changed)
		if controller.phase_changed.is_connected(_on_phase_changed):
			controller.phase_changed.disconnect(_on_phase_changed)
	controller = value
	controller.board.junction_changed.connect(_on_junction_changed)
	controller.phase_changed.connect(_on_phase_changed)
	if dynamic_layer != null:
		dynamic_layer.controller = controller
		dynamic_layer.queue_redraw()


func set_guide_focus(node_id: String, needs_action: bool) -> void:
	if guide_focus == node_id and guide_needs_action == needs_action:
		return
	guide_focus = node_id
	guide_needs_action = needs_action
	if dynamic_layer != null:
		dynamic_layer.guide_focus = node_id
		dynamic_layer.guide_needs_action = needs_action
		dynamic_layer.queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	city_art = CityBoardArt.new()
	city_art.name = "CityArt"
	city_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(city_art)
	city_art.set_anchors_preset(Control.PRESET_FULL_RECT)

	dynamic_layer = CityBoardOverlay.new()
	dynamic_layer.name = "DynamicOverlay"
	dynamic_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dynamic_layer)
	dynamic_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dynamic_layer.controller = controller
	dynamic_layer.guide_focus = guide_focus
	dynamic_layer.guide_needs_action = guide_needs_action
	resized.connect(_on_board_resized)


func _on_board_resized() -> void:
	if city_art != null:
		city_art.queue_redraw()
	if dynamic_layer != null:
		dynamic_layer.queue_redraw()


func _process(_delta: float) -> void:
	if controller != null and controller.phase == ShiftController.Phase.RUNNING:
		if dynamic_layer != null:
			dynamic_layer.queue_redraw()


func _on_junction_changed(_id: String, _target: String) -> void:
	if dynamic_layer != null:
		dynamic_layer.queue_redraw()


func _on_phase_changed(_phase: int) -> void:
	if dynamic_layer != null:
		dynamic_layer.queue_redraw()


func _point(node_id: String) -> Vector2:
	return CityBoardGeometry.node_point(node_id, size)


func _normalized_point(value: Vector2) -> Vector2:
	return Vector2(value.x * size.x, value.y * size.y)


func get_rendered_parcel_position(parcel: DeliveryParcel) -> Vector2:
	return CityBoardGeometry.route_point(
		parcel.current_node, parcel.next_node, parcel.progress, size
	)


func _gui_input(event: InputEvent) -> void:
	# Android touch emulation produces mouse input for both buttons and board.
	# Ignoring raw ScreenTouch here prevents a double toggle per touch.
	if not event is InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if toggle_at_local_position(click.position):
		accept_event()


func toggle_at_local_position(local_position: Vector2) -> bool:
	if controller == null or controller.phase != ShiftController.Phase.RUNNING:
		return false
	var radius: float = minf(72.0, maxf(48.0, minf(size.x, size.y) * 0.13))
	var nearest_id: String = ""
	var best_distance: float = INF
	for junction_id in BoardState.JUNCTION_IDS:
		var distance: float = local_position.distance_to(_point(junction_id))
		if distance <= radius and distance < best_distance:
			nearest_id = junction_id
			best_distance = distance
	if nearest_id.is_empty():
		return false
	if not controller.toggle_junction(nearest_id):
		return false
	if dynamic_layer != null:
		dynamic_layer.queue_redraw()
	return true
