extends Control
class_name BoardView

signal junction_activated(node_id: String)
signal incident_cleared()

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
var arcade_banner: Label
var focus_button: Button
var clear_road_button: Button


func bind_controller(value: ShiftController) -> void:
	if controller != null:
		if controller.board.junction_changed.is_connected(_on_junction_changed):
			controller.board.junction_changed.disconnect(_on_junction_changed)
		if controller.phase_changed.is_connected(_on_phase_changed):
			controller.phase_changed.disconnect(_on_phase_changed)
		if controller.board.map_changed.is_connected(_on_map_changed):
			controller.board.map_changed.disconnect(_on_map_changed)
		if controller.incident_changed.is_connected(_on_incident_changed):
			controller.incident_changed.disconnect(_on_incident_changed)
	controller = value
	controller.board.junction_changed.connect(_on_junction_changed)
	controller.phase_changed.connect(_on_phase_changed)
	controller.board.map_changed.connect(_on_map_changed)
	controller.incident_changed.connect(_on_incident_changed)
	if city_art != null:
		city_art.board = controller.board
		city_art.queue_redraw()
	if juice_layer != null:
		juice_layer.board = controller.board
	if dynamic_layer != null:
		dynamic_layer.controller = controller
		dynamic_layer.queue_redraw()
	_update_arcade_controls()


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
	_build_arcade_controls()
	resized.connect(_on_board_resized)
	# A PanelContainer can finish its size negotiation after _ready().
	# Final synchronization also covers first launch and device resizes.
	call_deferred("_on_board_resized")


func _build_arcade_controls() -> void:
	# Compact, non-scrolling controls sit over quiet parts of the board:
	# the skyline and lower-right pavement, away from the route switches.
	arcade_banner = Label.new()
	arcade_banner.name = "ArcadeBanner"
	arcade_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ParcelTheme.label_style(arcade_banner, 13, ParcelTheme.GOLD_LIGHT)
	arcade_banner.add_theme_color_override("font_shadow_color", Color("#071729"))
	arcade_banner.add_theme_constant_override("shadow_offset_x", 1)
	arcade_banner.add_theme_constant_override("shadow_offset_y", 2)
	arcade_banner.text = "EXPRESS  ·  COMBOS  ·  RUSH HOUR"
	add_child(arcade_banner)

	focus_button = Button.new()
	focus_button.name = "FocusButton"
	focus_button.custom_minimum_size = Vector2(116, 48)
	ParcelTheme.style_button(focus_button, "gold")
	focus_button.add_theme_font_size_override("font_size", 13)
	focus_button.tooltip_text = "Slow time for four seconds (two charges per shift)"
	focus_button.text = "FOCUS ×2"
	focus_button.pressed.connect(_on_focus_pressed)
	add_child(focus_button)

	clear_road_button = Button.new()
	clear_road_button.name = "ClearRoadButton"
	clear_road_button.custom_minimum_size = Vector2(110, 48)
	ParcelTheme.style_button(clear_road_button, "gold")
	clear_road_button.add_theme_font_size_override("font_size", 12)
	clear_road_button.tooltip_text = "Clear the road jam and earn 75 bonus points"
	clear_road_button.text = "CLEAR ROAD"
	clear_road_button.pressed.connect(_on_clear_road_pressed)
	add_child(clear_road_button)
	_update_arcade_controls()


func _on_focus_pressed() -> void:
	if controller != null and controller.activate_focus():
		_update_arcade_controls()
		if dynamic_layer != null:
			dynamic_layer.queue_redraw()


func _on_clear_road_pressed() -> void:
	if controller == null or not controller.clear_road_incident():
		return
	incident_cleared.emit()
	_update_arcade_controls()
	if dynamic_layer != null:
		dynamic_layer.queue_redraw()


func _on_incident_changed() -> void:
	_update_arcade_controls()
	if dynamic_layer != null:
		dynamic_layer.queue_redraw()


func incident_marker_position() -> Vector2:
	if controller == null or not controller.incidents.active:
		return Vector2(-1000.0, -1000.0)
	return CityBoardGeometry.route_point(
		controller.incidents.approach_from,
		controller.incidents.node_id, 0.52, size, controller.board
	)


func clear_incident_at_local_position(local_position: Vector2) -> bool:
	if controller == null or not controller.incidents.active:
		return false
	if controller.phase != ShiftController.Phase.RUNNING:
		return false
	if not Rect2(Vector2.ZERO, size).has_point(local_position):
		return false
	var marker: Vector2 = incident_marker_position()
	var junction: Vector2 = _point(controller.incidents.node_id)
	# The marker sits on an incoming road, sometimes quite close to the
	# gold junction. Never steal a deliberate touch on that switch itself.
	var radius: float = minf(26.0, maxf(15.0, marker.distance_to(junction) * 0.72))
	if local_position.distance_to(marker) > radius:
		return false
	_on_clear_road_pressed()
	return true


func _update_arcade_controls() -> void:
	if arcade_banner == null or focus_button == null or clear_road_button == null or controller == null:
		return
	var is_arcade: bool = controller.arcade_mode
	var is_live: bool = controller.phase == ShiftController.Phase.RUNNING
	var is_paused: bool = controller.phase == ShiftController.Phase.PAUSED
	arcade_banner.visible = is_arcade and (
		is_live or is_paused or controller.phase == ShiftController.Phase.READY
	)
	focus_button.visible = is_arcade and (is_live or is_paused)
	var incident_active: bool = (
		is_arcade and controller.incidents_enabled and controller.incidents.active
	)
	clear_road_button.visible = incident_active and (is_live or is_paused)
	clear_road_button.disabled = not is_live
	if incident_active:
		var clear_text: String = "CLEAR %ds" % ceili(controller.incidents.remaining)
		if clear_road_button.text != clear_text:
			clear_road_button.text = clear_text
	if not is_arcade:
		return
	var message: String = "GOLD EXPRESS  ·  COMBOS  ·  RUSH HOUR"
	if is_live or is_paused:
		message = "COMBO ×%d" % controller.combo
		if controller.rush_remaining > 0.0:
			message += "  ·  RUSH %ds" % ceili(controller.rush_remaining)
		elif controller.combo >= 3:
			message += "  ·  STREAK BONUS!"
	if arcade_banner.text != message:
		arcade_banner.text = message
	var focus_text: String = "FOCUS ×%d" % controller.focus_charges
	if controller.focus_remaining > 0.0:
		focus_text = "SLOW %ds" % ceili(controller.focus_remaining)
	if focus_button.text != focus_text:
		focus_button.text = focus_text
	var cannot_focus: bool = (
		not is_live or controller.focus_charges <= 0 or controller.focus_remaining > 0.0
	)
	if focus_button.disabled != cannot_focus:
		focus_button.disabled = cannot_focus


func _layout_arcade_controls() -> void:
	if arcade_banner == null or focus_button == null:
		return
	var small: bool = size.x < 320.0
	arcade_banner.position = Vector2(12, 8)
	arcade_banner.size = Vector2(maxf(0.0, size.x - 24.0), 24.0)
	arcade_banner.add_theme_font_size_override("font_size", 11 if small else 13)
	# Keep both 48px high controls on opposite corners of the board,
	# preserving a clear central gap for the depot even on narrow phones.
	var button_width: float = clampf((size.x - 44.0) * 0.5, 78.0, 118.0)
	focus_button.size = Vector2(button_width, 48.0)
	focus_button.position = Vector2(
		maxf(8.0, size.x - button_width - 12.0),
		maxf(8.0, size.y - 60.0)
	)
	clear_road_button.size = Vector2(button_width, 48.0)
	clear_road_button.position = Vector2(12.0, maxf(8.0, size.y - 60.0))
	clear_road_button.add_theme_font_size_override("font_size", 10 if small else 12)


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
	_layout_arcade_controls()


func _process(delta: float) -> void:
	if controller != null and controller.phase == ShiftController.Phase.RUNNING:
		if dynamic_layer != null:
			dynamic_layer.advance_visual(delta)
	_update_arcade_controls()


func _on_junction_changed(node_id: String, _target: String) -> void:
	if dynamic_layer != null:
		dynamic_layer.animate_junction(node_id)
	if juice_layer != null:
		juice_layer.show_junction(node_id)
	junction_activated.emit(node_id)


func _on_phase_changed(_phase: int) -> void:
	if dynamic_layer != null:
		dynamic_layer.queue_redraw()
	_update_arcade_controls()


func _point(node_id: String) -> Vector2:
	return CityBoardGeometry.node_point(node_id, size, controller.board)


func _normalized_point(value: Vector2) -> Vector2:
	return Vector2(value.x * size.x, value.y * size.y)


func get_rendered_parcel_position(parcel: DeliveryParcel) -> Vector2:
	return CityBoardGeometry.route_point(
		parcel.current_node, parcel.next_node, parcel.progress, size, controller.board
	)


func show_incident_feedback(junction_id: String, reward: int) -> void:
	if juice_layer != null:
		juice_layer.show_road_rescue_reward(junction_id, reward)


func show_dispatch_feedback(reward: int) -> void:
	if juice_layer != null:
		juice_layer.show_dispatch_reward(reward)


func show_delivery_feedback(
		parcel: DeliveryParcel, matched: bool,
		points: int = ShiftController.SCORE_PER_DELIVERY
	) -> void:
	if juice_layer != null:
		juice_layer.show_delivery(parcel, matched, points)


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
	if clear_incident_at_local_position(click.position):
		accept_event()
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
