extends Control
class_name GameScreen

const RESULTS_SCENE = preload("res://scenes/result_screen.tscn")

var controller: ShiftController = ShiftController.new()
var board_view: BoardView
var progress_label: Label
var score_label: Label
var mistakes_label: Label
var hint_label: Label
var play_button: Button
var pause_button: Button
var restart_button: Button
var exit_button: Button
var result_backdrop: ColorRect
var result_panel: ResultScreen


func _ready() -> void:
	_build_interface()
	controller.phase_changed.connect(_on_phase_changed)
	controller.totals_changed.connect(_on_totals_changed)
	controller.delivery_scored.connect(_on_delivery_scored)
	controller.shift_finished.connect(_on_shift_finished)
	_on_phase_changed(controller.phase)
	_on_totals_changed(controller.score, controller.correct, controller.mistakes)


func _physics_process(delta: float) -> void:
	controller.advance(delta)


func _notification(what: int) -> void:
	# Android Back should not abruptly close an active delivery shift.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		handle_back_request()
	elif what == NOTIFICATION_APPLICATION_PAUSED and is_node_ready():
		if controller.phase == ShiftController.Phase.RUNNING:
			controller.set_paused(true)


func _unhandled_key_input(event: InputEvent) -> void:
	# Match desktop Escape to Android system Back for manual testing.
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			handle_back_request()
			get_viewport().set_input_as_handled()


func handle_back_request() -> void:
	match controller.phase:
		ShiftController.Phase.RUNNING:
			controller.set_paused(true)
		ShiftController.Phase.PAUSED, ShiftController.Phase.FINISHED:
			_on_exit_pressed()
		ShiftController.Phase.READY:
			get_tree().quit()


func _build_interface() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#101b2c")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var margins := MarginContainer.new()
	margins.set_anchors_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 20)
	margins.add_theme_constant_override("margin_right", 20)
	margins.add_theme_constant_override("margin_top", 28)
	margins.add_theme_constant_override("margin_bottom", 24)
	add_child(margins)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margins.add_child(column)

	var heading := Label.new()
	heading.text = "PARCEL PULSE"
	heading.add_theme_font_size_override("font_size", 34)
	heading.add_theme_color_override("font_color", Color("#ffe0a7"))
	column.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = "ONE TAP. PERFECT DELIVERIES."
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("#9fb7cb"))
	column.add_child(subtitle)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	column.add_child(stats)
	progress_label = _make_stat(stats)
	score_label = _make_stat(stats)
	mistakes_label = _make_stat(stats)

	var board_panel := PanelContainer.new()
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.add_theme_stylebox_override("panel", _panel_style())
	column.add_child(board_panel)

	board_view = BoardView.new()
	board_view.custom_minimum_size = Vector2(260, 340)
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.bind_controller(controller)
	board_panel.add_child(board_view)

	hint_label = Label.new()
	hint_label.text = "Tap the golden junctions to switch tracks."
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.add_theme_color_override("font_color", Color("#c5d8e9"))
	column.add_child(hint_label)

	var actions := GridContainer.new()
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	column.add_child(actions)
	play_button = _make_button(actions, "PLAY")
	pause_button = _make_button(actions, "PAUSE")
	restart_button = _make_button(actions, "RETRY")
	exit_button = _make_button(actions, "EXIT")
	play_button.pressed.connect(_on_play_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	result_backdrop = ColorRect.new()
	result_backdrop.color = Color(0.02, 0.04, 0.09, 0.79)
	result_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	result_backdrop.visible = false
	add_child(result_backdrop)
	result_panel = RESULTS_SCENE.instantiate() as ResultScreen
	result_backdrop.add_child(result_panel)
	result_panel.retry_requested.connect(_on_restart_pressed)
	result_panel.menu_requested.connect(_on_exit_pressed)
	result_backdrop.resized.connect(_center_result)
	_center_result()


func _make_stat(parent: HBoxContainer) -> Label:
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#edf4ff"))
	parent.add_child(label)
	return label


func _make_button(parent: GridContainer, caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_font_size_override("font_size", 17)
	parent.add_child(button)
	return button


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#102238")
	style.border_color = Color("#48627c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	return style


func _center_result() -> void:
	if result_panel == null or result_backdrop == null:
		return
	var box_width: float = minf(420.0, maxf(260.0, result_backdrop.size.x - 32.0))
	result_panel.position = Vector2(
		(result_backdrop.size.x - box_width) * 0.5,
		(result_backdrop.size.y - 310.0) * 0.5
	)
	result_panel.size = Vector2(box_width, 310)


func _on_play_pressed() -> void:
	result_backdrop.visible = false
	controller.start_shift()


func _on_pause_pressed() -> void:
	controller.set_paused(controller.phase == ShiftController.Phase.RUNNING)


func _on_restart_pressed() -> void:
	result_backdrop.visible = false
	controller.restart_shift()


func _on_exit_pressed() -> void:
	result_backdrop.visible = false
	controller.exit_shift()


func _on_phase_changed(new_phase: int) -> void:
	match new_phase:
		ShiftController.Phase.READY:
			hint_label.text = "Press PLAY to start your delivery shift."
		ShiftController.Phase.RUNNING:
			hint_label.text = "Tap the golden junctions to switch tracks."
		ShiftController.Phase.PAUSED:
			hint_label.text = "Paused. Routes and parcels are frozen."
		ShiftController.Phase.FINISHED:
			hint_label.text = "Shift over. Review your deliveries."
	play_button.disabled = new_phase != ShiftController.Phase.READY
	pause_button.disabled = new_phase == ShiftController.Phase.READY or new_phase == ShiftController.Phase.FINISHED
	restart_button.disabled = new_phase == ShiftController.Phase.READY
	exit_button.disabled = new_phase == ShiftController.Phase.READY
	pause_button.text = "RESUME" if new_phase == ShiftController.Phase.PAUSED else "PAUSE"
	board_view.queue_redraw()


func _on_totals_changed(new_score: int, delivered: int, errors: int) -> void:
	progress_label.text = "✓ %d / %d" % [delivered, ShiftController.REQUIRED_DELIVERIES]
	score_label.text = "%d PTS" % new_score
	mistakes_label.text = "✕ %d / %d" % [errors, ShiftController.MAX_MISTAKES]


func _on_delivery_scored(_parcel: DeliveryParcel, matched: bool) -> void:
	if matched:
		hint_label.text = "Nice delivery! Keep those routes moving."
	else:
		hint_label.text = "Wrong house! Change the next junction."


func _on_shift_finished(success: bool, earned_score: int, delivered: int, errors: int) -> void:
	result_panel.show_result(success, earned_score, delivered, errors)
	result_backdrop.visible = true
	_center_result()
