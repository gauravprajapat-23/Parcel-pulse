extends Control
class_name GameScreen

const RESULTS_SCENE = preload("res://scenes/result_screen.tscn")
const HUD_SCENE = preload("res://scenes/ui/hud_panel.tscn")
const ACTION_BAR_SCENE = preload("res://scenes/ui/action_bar.tscn")

var controller: ShiftController = ShiftController.new()
var board_view: BoardView
var hud_panel: HudPanel
var action_bar: ActionBar
var progress_label: Label
var score_label: Label
var mistakes_label: Label
var hint_label: Label
var coach_label: Label
var guide_button: Button
var guide_enabled: bool = true
var _last_guidance: String = ""
var play_button: Button
var pause_button: Button
var restart_button: Button
var exit_button: Button
var result_backdrop: ColorRect
var result_panel: ResultScreen
var sfx_player: SfxPlayer
var sound_button: Button
var _result_tween: Tween
var _score_tween: Tween
var _last_android_back_msec: int = -1000
const ANDROID_BACK_DEBOUNCE_MS: int = 300


func _ready() -> void:
	_build_interface()
	controller.phase_changed.connect(_on_phase_changed)
	controller.totals_changed.connect(_on_totals_changed)
	controller.delivery_scored.connect(_on_delivery_scored)
	controller.shift_finished.connect(_on_shift_finished)
	_on_phase_changed(controller.phase)
	_on_totals_changed(controller.score, controller.correct, controller.mistakes)
	_update_guidance()


func _physics_process(delta: float) -> void:
	controller.advance(delta)
	_update_guidance()


func _notification(what: int) -> void:
	# Android Back should not abruptly close an active delivery shift.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		# Godot 4.7.x / Android 16 may emit duplicate Back notifications.
		var now_msec: int = Time.get_ticks_msec()
		if now_msec - _last_android_back_msec >= ANDROID_BACK_DEBOUNCE_MS:
			_last_android_back_msec = now_msec
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
	sfx_player = SfxPlayer.new()
	sfx_player.name = "UiSounds"
	add_child(sfx_player)
	var backdrop := ColorRect.new()
	backdrop.color = ParcelTheme.BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var margins := MarginContainer.new()
	margins.set_anchors_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 16)
	margins.add_theme_constant_override("margin_right", 16)
	margins.add_theme_constant_override("margin_top", 20)
	margins.add_theme_constant_override("margin_bottom", 18)
	add_child(margins)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margins.add_child(column)

	# UI-01A: brand typography and stat cards share one palette.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 7)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(title_row)
	var parcel_title := Label.new()
	parcel_title.text = "PARCEL"
	ParcelTheme.label_style(parcel_title, 30, ParcelTheme.TEXT)
	title_row.add_child(parcel_title)
	var pulse_title := Label.new()
	pulse_title.text = "PULSE"
	ParcelTheme.label_style(pulse_title, 30, ParcelTheme.GOLD)
	title_row.add_child(pulse_title)
	sound_button = Button.new()
	sound_button.text = "SFX ON"
	sound_button.custom_minimum_size = Vector2(76, 44)
	ParcelTheme.style_button(sound_button, "quiet")
	sound_button.add_theme_font_size_override("font_size", 12)
	sound_button.pressed.connect(_on_sound_toggle_pressed)
	title_row.add_child(sound_button)

	var subtitle := Label.new()
	subtitle.text = "ROUTE  •  DELIVER  •  KEEP THE CITY MOVING"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ParcelTheme.label_style(subtitle, 12, ParcelTheme.CYAN)
	column.add_child(subtitle)

	hud_panel = HUD_SCENE.instantiate() as HudPanel
	column.add_child(hud_panel)
	progress_label = hud_panel.deliveries_card.value_label
	score_label = hud_panel.score_card.value_label
	mistakes_label = hud_panel.lives_card.value_label

	var board_panel := PanelContainer.new()
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.add_theme_stylebox_override(
		"panel", ParcelTheme.panel_style(ParcelTheme.PANEL, ParcelTheme.BORDER, 22, 2)
	)
	column.add_child(board_panel)

	board_view = BoardView.new()
	board_view.custom_minimum_size = Vector2(260, 340)
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.bind_controller(controller)
	board_view.junction_activated.connect(_on_junction_activated)
	board_panel.add_child(board_view)

	# The guidance panel stays compact; its on/off control lives in the action bar.
	var coach_panel := PanelContainer.new()
	coach_panel.add_theme_stylebox_override(
		"panel", ParcelTheme.panel_style(ParcelTheme.PANEL, ParcelTheme.BORDER, 16, 1)
	)
	column.add_child(coach_panel)
	var coach_margin := MarginContainer.new()
	coach_margin.add_theme_constant_override("margin_left", 12)
	coach_margin.add_theme_constant_override("margin_right", 12)
	coach_margin.add_theme_constant_override("margin_top", 8)
	coach_margin.add_theme_constant_override("margin_bottom", 8)
	coach_panel.add_child(coach_margin)
	coach_label = Label.new()
	coach_label.text = "MATCH COLOR + SHAPE. Tap the golden switches."
	coach_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coach_label.custom_minimum_size = Vector2(0, 36)
	ParcelTheme.label_style(coach_label, 16, ParcelTheme.GOLD_LIGHT)
	coach_margin.add_child(coach_label)

	hint_label = Label.new()
	hint_label.text = "Tap the golden junctions to switch tracks."
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ParcelTheme.label_style(hint_label, 14, ParcelTheme.MUTED)
	column.add_child(hint_label)

	action_bar = ACTION_BAR_SCENE.instantiate() as ActionBar
	column.add_child(action_bar)
	# Legacy aliases remain available to old callers, but this is one
	# primary action whose meaning depends on the current shift phase.
	play_button = action_bar.primary_button
	pause_button = action_bar.primary_button
	restart_button = action_bar.retry_button
	guide_button = action_bar.guide_button
	exit_button = action_bar.exit_button
	action_bar.primary_requested.connect(_on_primary_pressed)
	action_bar.retry_requested.connect(_on_restart_pressed)
	action_bar.guide_requested.connect(_on_guide_pressed)
	action_bar.exit_requested.connect(_on_exit_pressed)

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


func _center_result() -> void:
	if result_panel == null or result_backdrop == null:
		return
	var box_width: float = minf(420.0, maxf(260.0, result_backdrop.size.x - 32.0))
	result_panel.position = Vector2(
		(result_backdrop.size.x - box_width) * 0.5,
		(result_backdrop.size.y - 350.0) * 0.5
	)
	result_panel.size = Vector2(box_width, 350)


func _on_sound_toggle_pressed() -> void:
	sfx_player.set_enabled(not sfx_player.enabled)
	sound_button.text = "SFX ON" if sfx_player.enabled else "SFX OFF"


func _on_junction_activated(_node_id: String) -> void:
	sfx_player.play_event("tap")


func _hide_results_and_reset_fx() -> void:
	if _result_tween != null and _result_tween.is_running():
		_result_tween.kill()
	result_backdrop.visible = false
	result_backdrop.modulate.a = 1.0
	board_view.clear_feedback()
	if _score_tween != null and _score_tween.is_running():
		_score_tween.kill()
	score_label.modulate = Color.WHITE


func _on_guide_pressed() -> void:
	guide_enabled = not guide_enabled
	action_bar.set_guide_enabled(guide_enabled)
	_last_guidance = ""
	_update_guidance()


func _update_guidance() -> void:
	if coach_label == null or board_view == null:
		return
	if not guide_enabled:
		if _last_guidance != "OFF":
			coach_label.text = "Routing guide hidden. Tap GUIDE OFF to restore."
			board_view.set_guide_focus("", false)
			_last_guidance = "OFF"
		return
	var advice: Dictionary = RoutingCoach.get_guidance(controller)
	var message: String = str(advice["message"])
	var focus: String = str(advice["focus"])
	var needs_action: bool = bool(advice["needs_action"])
	if _last_guidance != message:
		coach_label.text = message
		_last_guidance = message
	board_view.set_guide_focus(focus, needs_action)


func _on_primary_pressed() -> void:
	match controller.phase:
		ShiftController.Phase.READY:
			_on_play_pressed()
		ShiftController.Phase.RUNNING, ShiftController.Phase.PAUSED:
			_on_pause_pressed()


func _on_play_pressed() -> void:
	_hide_results_and_reset_fx()
	controller.start_shift()


func _on_pause_pressed() -> void:
	controller.set_paused(controller.phase == ShiftController.Phase.RUNNING)
	sfx_player.play_event("pause")


func _on_restart_pressed() -> void:
	_hide_results_and_reset_fx()
	controller.restart_shift()


func _on_exit_pressed() -> void:
	_hide_results_and_reset_fx()
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
	action_bar.apply_phase(new_phase)
	board_view.queue_redraw()
	_update_guidance()


func _on_totals_changed(new_score: int, delivered: int, errors: int) -> void:
	hud_panel.update_stats(delivered, new_score, errors)


func _on_delivery_scored(parcel: DeliveryParcel, matched: bool) -> void:
	board_view.show_delivery_feedback(parcel, matched)
	sfx_player.play_event("success" if matched else "mistake")
	if matched:
		hint_label.text = "Delivered! +%d points." % ShiftController.SCORE_PER_DELIVERY
		if _score_tween != null and _score_tween.is_running():
			_score_tween.kill()
		score_label.modulate = ParcelTheme.GOLD_LIGHT
		_score_tween = create_tween()
		_score_tween.tween_property(score_label, "modulate", Color.WHITE, 0.35)
	else:
		hint_label.text = "Wrong house! Check the color and symbol."


func _on_shift_finished(success: bool, earned_score: int, delivered: int, errors: int) -> void:
	result_panel.show_result(success, earned_score, delivered, errors)
	result_backdrop.visible = true
	result_backdrop.modulate.a = 0.0
	_center_result()
	if _result_tween != null and _result_tween.is_running():
		_result_tween.kill()
	_result_tween = create_tween()
	_result_tween.set_trans(Tween.TRANS_CUBIC)
	_result_tween.set_ease(Tween.EASE_OUT)
	_result_tween.tween_property(result_backdrop, "modulate:a", 1.0, 0.24)
	sfx_player.play_event("win" if success else "mistake")
