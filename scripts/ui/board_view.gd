extends Control
class_name BoardView

signal junction_activated(node_id: String)

# UI-01B composition layer. CityBoardArt renders static decorative content,
# CityBoardOverlay renders moving visuals. Both use the same visual geometry.
# Input and gameplay remain owned by this view and ShiftController respectively.
var controller: ShiftController
var guide_focus: String = ""
var guide_needs_action: bool = false
var city_art: CityBoardArt
var dynamic_layer: CityBoardOverlay
var juice_layer: GameJuice
var reduced_motion: bool = false


func bind_controller(value: ShiftController) -> void:
	if controller != null:
		if controller.board.junction_changed.is_connected(_on_junction_changed):
			controller.board.junction_changed.disconnect(_on_junction_changed)
		if controller.phase_changed.is_connected(_on_phase_changed):
			controller.phase_changed.disconnect(_on_phase_changed)
		if controller.board.map_changed.is_connected(_on_map_changed):
			controller.board.map_changed.disconnect(_on_map_changed)
	controller = value
	controller.board.junction_changed.connect(_on_junction_changed)
	controller.phase_changed.connect(_on_phase_changed)
	controller.board.map_changed.connect(_on_map_changed)
	if city_art != null:
		city_art.board = controller.board
		city_art.queue_redraw()
	if juice_layer != null:
		juice_layer.board = controller.board
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
	city_art.board = controller.board if controller != null else null
	city_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(city_art)
	_stretch_layer(city_art)

	dynamic_layer = CityBoardOverlay.new()
	dynamic_layer.name = "DynamicOverlay"
	dynamic_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dynamic_layer)
	_stretch_layer(dynamic_layer)
	dynamic_layer.controller = controller
	dynamic_layer.guide_focus = guide_focus
	dynamic_layer.guide_needs_action = guide_needs_action

	juice_layer = GameJuice.new()
	juice_layer.name = "FeedbackOverlay"
	juice_layer.board = controller.board if controller != null else null
	juice_layer.reduced_motion = reduced_motion
	dynamic_layer.reduced_motion = reduced_motion
	juice_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(juice_layer)
	_stretch_layer(juice_layer)
	resized.connect(_on_board_resized)
	# A PanelContainer can finish its size negotiation after _ready().
	# Final synchronization also covers first launch and device resizes.
	call_deferred("_on_board_resized")


func _stretch_layer(layer: Control) -> void:
	# PRESET_FULL_RECT by itself may preserve offsets from an early layout
	# pass. All three drawing layers must use exactly the board's geometry.
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.offset_left = 0.0
	layer.offset_top = 0.0
	layer.offset_right = 0.0
	layer.offset_bottom = 0.0


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if dynamic_layer != null:
		dynamic_layer.set_reduced_motion(enabled)
	if juice_layer != null:
		juice_layer.reduced_motion = enabled
		juice_layer.queue_redraw()


func get_junction_hit_radius() -> float:
	return minf(72.0, maxf(48.0, minf(size.x, size.y) * 0.13))


func _on_map_changed(_new_index: int) -> void:
	clear_feedback()
	if dynamic_layer != null:
		dynamic_layer.reset_junction_animations()
	if city_art != null:
		city_art.queue_redraw()
	if dynamic_layer != null:
		dynamic_layer.queue_redraw()


func _on_board_resized() -> void:
	for layer in [city_art, dynamic_layer, juice_layer]:
		if layer != null:
			_stretch_layer(layer)
			layer.queue_redraw()


func _process(delta: float) -> void:
	if controller != null and controller.phase == ShiftController.Phase.RUNNING:
		if dynamic_layer != null:
			dynamic_layer.advance_visual(delta)


func _on_junction_changed(node_id: String, _target: String) -> void:
	if dynamic_layer != null:
		dynamic_layer.animate_junction(node_id)
	if juice_layer != null:
		juice_layer.show_junction(node_id)
	junction_activated.emit(node_id)


func _on_phase_changed(_phase: int) -> void:
	if dynamic_layer != null:
		dynamic_layer.queue_redraw()


func _point(node_id: String) -> Vector2:
	return CityBoardGeometry.node_point(node_id, size, controller.board)


func _normalized_point(value: Vector2) -> Vector2:
	return Vector2(value.x * size.x, value.y * size.y)


func get_rendered_parcel_position(parcel: DeliveryParcel) -> Vector2:
	return CityBoardGeometry.route_point(
		parcel.current_node, parcel.next_node, parcel.progress, size, controller.board
	)


func show_delivery_feedback(parcel: DeliveryParcel, matched: bool) -> void:
	if juice_layer != null:
		juice_layer.show_delivery(parcel, matched)


func clear_feedback() -> void:
	if juice_layer != null:
		juice_layer.clear_effects()
	if dynamic_layer != null:
		dynamic_layer.route_flow_phase = 0.0
		dynamic_layer.queue_redraw()


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


const AMBIGUOUS_TOUCH_MARGIN: float = 8.0


func junction_at_local_position(local_position: Vector2) -> String:
	# Use the closest real junction even when large touch circles overlap.
	# Reject the thin region where two switches are equally plausible,
	# rather than silently toggling a different switch on a small phone.
	if controller == null or size.x <= 0.0 or size.y <= 0.0:
		return ""
	if not Rect2(Vector2.ZERO, size).has_point(local_position):
		return ""
	var nearest_id: String = ""
	var nearest_distance: float = INF
	var second_distance: float = INF
	for junction_id in controller.board.junction_ids:
		var distance: float = local_position.distance_to(_point(junction_id))
		if distance < nearest_distance:
			second_distance = nearest_distance
			nearest_distance = distance
			nearest_id = junction_id
		elif distance < second_distance:
			second_distance = distance
	if nearest_distance > get_junction_hit_radius():
		return ""
	if second_distance - nearest_distance < AMBIGUOUS_TOUCH_MARGIN:
		return ""
	return nearest_id


func toggle_at_local_position(local_position: Vector2) -> bool:
	if controller == null or controller.phase != ShiftController.Phase.RUNNING:
		return false
	var nearest_id: String = junction_at_local_position(local_position)
	if nearest_id.is_empty():
		return false
	if not controller.toggle_junction(nearest_id):
		return false
	if dynamic_layer != null:
		dynamic_layer.queue_redraw()
	return true
