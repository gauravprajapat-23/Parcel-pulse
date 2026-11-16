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
var progress_profile: Dictionary = {}
var progress_save_path: String = ProgressStore.SAVE_PATH
var level_row: HBoxContainer
var level_name_label: Label
var level_info_label: Label
var previous_level_button: Button
var next_level_button: Button
var _last_guidance: String = ""
var play_button: Button
var pause_button: Button
var restart_button: Button
var exit_button: Button
var result_backdrop: ColorRect
var result_panel: ResultScreen
var sfx_player: SfxPlayer
var sound_button: Button
var motion_button: Button
var screen_margins: MarginContainer
var screen_column: VBoxContainer
var header_row: HBoxContainer
var title_parcel: Label
var title_pulse: Label
var tagline_label: Label
var board_container: PanelContainer
var coach_container: PanelContainer
var reduced_motion: bool = false
var _last_viewport_size: Vector2 = Vector2.ZERO
var _result_tween: Tween
var _score_tween: Tween
var _last_android_back_msec: int = -1000
const ANDROID_BACK_DEBOUNCE_MS: int = 300


func _ready() -> void:
	_build_interface()
	progress_profile = ProgressStore.load_profile(progress_save_path)
	# Returning players see the first unlocked uncleared level instead of
	# restarting at Stage 1 every time the app opens.
	var suggested_level: int = ProgressStore.recommended_level(progress_profile)
	if suggested_level > 0:
		controller.select_level(suggested_level)
	controller.phase_changed.connect(_on_phase_changed)
	controller.level_changed.connect(_on_level_changed)
	controller.totals_changed.connect(_on_totals_changed)
	controller.delivery_scored.connect(_on_delivery_scored)
	controller.shift_finished.connect(_on_shift_finished)
	_on_phase_changed(controller.phase)
	_on_totals_changed(controller.score, controller.correct, controller.mistakes)
	_update_guidance()
	_update_level_selection()
	resized.connect(_on_root_resized)
	_apply_responsive_layout(get_viewport_rect().size)


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

	screen_margins = MarginContainer.new()
	screen_margins.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_margins.add_theme_constant_override("margin_left", 16)
	screen_margins.add_theme_constant_override("margin_right", 16)
	screen_margins.add_theme_constant_override("margin_top", 20)
	screen_margins.add_theme_constant_override("margin_bottom", 18)
	add_child(screen_margins)

	screen_column = VBoxContainer.new()
	screen_column.add_theme_constant_override("separation", 10)
	screen_margins.add_child(screen_column)

	# UI-01A: brand typography and stat cards share one palette.
	header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 7)
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	screen_column.add_child(header_row)
	title_parcel = Label.new()
	title_parcel.text = "PARCEL"
	ParcelTheme.label_style(title_parcel, 30, ParcelTheme.TEXT)
	header_row.add_child(title_parcel)
	title_pulse = Label.new()
	title_pulse.text = "PULSE"
	ParcelTheme.label_style(title_pulse, 30, ParcelTheme.GOLD)
	header_row.add_child(title_pulse)
	sound_button = Button.new()
	sound_button.text = "SFX ON"
	sound_button.custom_minimum_size = Vector2(76, 48)
	ParcelTheme.style_button(sound_button, "quiet")
	sound_button.add_theme_font_size_override("font_size", 12)
	sound_button.tooltip_text = "Toggle sound effects"
	sound_button.pressed.connect(_on_sound_toggle_pressed)
	header_row.add_child(sound_button)
	motion_button = Button.new()
	motion_button.text = "MOTION ON"
	motion_button.custom_minimum_size = Vector2(98, 48)
	ParcelTheme.style_button(motion_button, "quiet")
	motion_button.add_theme_font_size_override("font_size", 11)
	motion_button.tooltip_text = "Toggle decorative motion and animations"
	motion_button.pressed.connect(_on_motion_toggle_pressed)
	header_row.add_child(motion_button)

	tagline_label = Label.new()
	tagline_label.text = "ROUTE  •  DELIVER  •  KEEP THE CITY MOVING"
	tagline_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ParcelTheme.label_style(tagline_label, 12, ParcelTheme.CYAN)
	screen_column.add_child(tagline_label)

	hud_panel = HUD_SCENE.instantiate() as HudPanel
	screen_column.add_child(hud_panel)
	progress_label = hud_panel.deliveries_card.value_label
	score_label = hud_panel.score_card.value_label
	mistakes_label = hud_panel.lives_card.value_label

	# Select and preview offline stages from READY; locked stages stay visible
	# but cannot start until the previous stage is completed.
	level_row = HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 7)
	screen_column.add_child(level_row)
	previous_level_button = Button.new()
	previous_level_button.text = "◀"
	previous_level_button.custom_minimum_size = Vector2(50, 42)
	ParcelTheme.style_button(previous_level_button, "quiet")
	previous_level_button.pressed.connect(_on_previous_level)
	level_row.add_child(previous_level_button)
	var stage_center := VBoxContainer.new()
	stage_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_center.add_theme_constant_override("separation", 1)
	level_row.add_child(stage_center)
	level_name_label = Label.new()
	level_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_name_label.clip_text = true
	ParcelTheme.label_style(level_name_label, 15, ParcelTheme.GOLD_LIGHT)
	stage_center.add_child(level_name_label)
	level_info_label = Label.new()
	level_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_info_label.clip_text = true
	ParcelTheme.label_style(level_info_label, 11, ParcelTheme.MUTED)
	stage_center.add_child(level_info_label)
	next_level_button = Button.new()
	next_level_button.text = "▶"
	next_level_button.custom_minimum_size = Vector2(50, 42)
	ParcelTheme.style_button(next_level_button, "quiet")
	next_level_button.pressed.connect(_on_next_level)
	level_row.add_child(next_level_button)

	board_container = PanelContainer.new()
	board_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_container.add_theme_stylebox_override(
		"panel", ParcelTheme.panel_style(ParcelTheme.PANEL, ParcelTheme.BORDER, 22, 2)
	)
	screen_column.add_child(board_container)

	board_view = BoardView.new()
	board_view.custom_minimum_size = Vector2(260, 340)
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.bind_controller(controller)
	board_view.junction_activated.connect(_on_junction_activated)
	board_container.add_child(board_view)

	# The guidance panel stays compact; its on/off control lives in the action bar.
	coach_container = PanelContainer.new()
	coach_container.add_theme_stylebox_override(
		"panel", ParcelTheme.panel_style(ParcelTheme.PANEL, ParcelTheme.BORDER, 16, 1)
	)
	screen_column.add_child(coach_container)
	var coach_margin := MarginContainer.new()
	coach_margin.add_theme_constant_override("margin_left", 12)
	coach_margin.add_theme_constant_override("margin_right", 12)
	coach_margin.add_theme_constant_override("margin_top", 8)
	coach_margin.add_theme_constant_override("margin_bottom", 8)
	coach_container.add_child(coach_margin)
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
	screen_column.add_child(hint_label)

	action_bar = ACTION_BAR_SCENE.instantiate() as ActionBar
	screen_column.add_child(action_bar)
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
	result_panel.next_stage_requested.connect(_on_result_next_stage)
	result_backdrop.resized.connect(_center_result)
	_center_result()


func _on_root_resized() -> void:
	# The resize signal also occurs on foldable and orientation transitions.
	_apply_responsive_layout(get_viewport_rect().size)


func _apply_responsive_layout(logical_size: Vector2) -> void:
	if screen_margins == null or logical_size.x <= 0.0 or logical_size.y <= 0.0:
		return
	if logical_size == _last_viewport_size:
		return
	_last_viewport_size = logical_size
	var metrics: Dictionary = MobileLayout.metrics(logical_size)
	var outer: int = int(metrics["outer"])
	var top: int = int(metrics["top"])
	var bottom: int = int(metrics["bottom"])
	# Non-edge-to-edge Android windows already exclude the system bars. Only
	# add additional cutout padding when the OS reports actual overlapping space.
	var safe := Vector4.ZERO
	if OS.get_name() == "Android":
		safe = MobileLayout.extra_safe_insets(
			DisplayServer.get_display_safe_area(),
			DisplayServer.window_get_size(), logical_size
		)
	screen_margins.add_theme_constant_override("margin_left", outer + roundi(safe.x))
	screen_margins.add_theme_constant_override("margin_right", outer + roundi(safe.z))
	screen_margins.add_theme_constant_override("margin_top", top + roundi(safe.y))
	screen_margins.add_theme_constant_override("margin_bottom", bottom + roundi(safe.w))
	screen_column.add_theme_constant_override("separation", int(metrics["gap"]))
	header_row.add_theme_constant_override(
		"separation", 4 if MobileLayout.profile_for(logical_size) != MobileLayout.FULL else 7
	)
	motion_button.custom_minimum_size.x = 82.0 if MobileLayout.profile_for(logical_size) != MobileLayout.FULL else 98.0
	sound_button.custom_minimum_size.x = 64.0 if MobileLayout.profile_for(logical_size) != MobileLayout.FULL else 76.0
	ParcelTheme.label_style(title_parcel, int(metrics["title"]), ParcelTheme.TEXT)
	ParcelTheme.label_style(title_pulse, int(metrics["title"]), ParcelTheme.GOLD)
	tagline_label.visible = bool(metrics["subtitle"])
	hud_panel.apply_layout_metrics(int(metrics["stats_height"]))
	board_view.custom_minimum_size = metrics["board"]
	ParcelTheme.label_style(coach_label, int(metrics["coach_font"]), ParcelTheme.GOLD_LIGHT)
	coach_label.custom_minimum_size = Vector2(0, float(metrics["coach_height"]))
	level_name_label.add_theme_font_size_override(
		"font_size", 12 if MobileLayout.profile_for(logical_size) == MobileLayout.SMALL else 15
	)
	level_info_label.add_theme_font_size_override(
		"font_size", 10 if MobileLayout.profile_for(logical_size) == MobileLayout.SMALL else 11
	)
	previous_level_button.custom_minimum_size.y = float(metrics["action_height"])
	next_level_button.custom_minimum_size.y = float(metrics["action_height"])
	hint_label.visible = bool(metrics["hint"])
	action_bar.set_button_height(float(metrics["action_height"]))
	sound_button.add_theme_font_size_override("font_size", int(metrics["sound_font"]))
	motion_button.add_theme_font_size_override("font_size", int(metrics["sound_font"]))
	_center_result()


func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if motion_button != null:
		motion_button.text = "MOTION OFF" if enabled else "MOTION ON"
	if board_view != null:
		board_view.set_reduced_motion(enabled)
	if enabled:
		if _score_tween != null and _score_tween.is_running():
			_score_tween.kill()
		if _result_tween != null and _result_tween.is_running():
			_result_tween.kill()
		if score_label != null:
			score_label.modulate = Color.WHITE
		if result_backdrop != null:
			result_backdrop.modulate.a = 1.0


func _on_motion_toggle_pressed() -> void:
	set_reduced_motion(not reduced_motion)


func _center_result() -> void:
	if result_panel == null or result_backdrop == null:
		return
	var box_width: float = minf(420.0, maxf(220.0, result_backdrop.size.x - 24.0))
	var box_height: float = minf(350.0, maxf(270.0, result_backdrop.size.y - 24.0))
	result_panel.position = Vector2(
		(result_backdrop.size.x - box_width) * 0.5,
		(result_backdrop.size.y - box_height) * 0.5
	)
	result_panel.size = Vector2(box_width, box_height)


func _on_previous_level() -> void:
	_select_preview_level(controller.level_index - 1)


func _on_next_level() -> void:
	_select_preview_level(controller.level_index + 1)


func _select_preview_level(index: int) -> void:
	if controller.phase != ShiftController.Phase.READY:
		return
	if controller.select_level(index):
		_hide_results_and_reset_fx()
		_update_guidance()


func _on_result_next_stage() -> void:
	if controller.phase != ShiftController.Phase.FINISHED or not controller.last_success:
		return
	var target: int = controller.level_index + 1
	if target >= LevelCatalog.count() or not ProgressStore.is_unlocked(progress_profile, target):
		return
	_on_exit_pressed()
	_select_preview_level(target)


func _on_level_changed(_index: int) -> void:
	_update_level_selection()
	_update_guidance()


func _update_level_selection() -> void:
	if level_row == null or not is_node_ready():
		return
	var index: int = controller.level_index
	var definition: Dictionary = LevelCatalog.get_level(index)
	var unlocked: bool = ProgressStore.is_unlocked(progress_profile, index)
	var best: Dictionary = progress_profile.get("best", {})
	var record: Dictionary = best.get(str(index), {})
	level_name_label.text = "STAGE %02d/%02d · %s" % [
		index + 1, LevelCatalog.count(), str(definition.get("name", "Unknown"))
	]
	level_name_label.tooltip_text = str(definition.get("tagline", ""))
	var completed: int = ProgressStore.completed_count(progress_profile)
	if not unlocked:
		level_info_label.text = "LOCKED · CLEAR STAGE %02d" % index
	elif int(record.get("stars", 0)) > 0:
		level_info_label.text = "%s  BEST %d  ·  %d/%d CLEARED" % [
			"★".repeat(int(record["stars"])),
			int(record.get("score", 0)), completed, LevelCatalog.count()
		]
	else:
		level_info_label.text = "%s  ·  %d TO DELIVER  ·  %d/%d CLEARED" % [
			LevelCatalog.difficulty_text(index),
			int(definition.get("quota", 12)), completed, LevelCatalog.count()
		]
	level_info_label.tooltip_text = str(definition.get("tagline", ""))
	previous_level_button.disabled = index <= 0
	next_level_button.disabled = index >= LevelCatalog.count() - 1
	level_row.visible = controller.phase == ShiftController.Phase.READY
	if controller.phase == ShiftController.Phase.READY:
		if unlocked:
			action_bar.primary_button.configure("PLAY", "play", "gold")
			action_bar.primary_button.disabled = false
			hint_label.text = str(definition.get("tagline", ""))
		else:
			action_bar.primary_button.configure("LOCKED", "play", "quiet")
			action_bar.primary_button.disabled = true
			hint_label.text = "Win Stage %d to unlock this map." % index


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
	if not ProgressStore.is_unlocked(progress_profile, controller.level_index):
		hint_label.text = "This stage is locked. Clear the previous one first."
		return
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
	_update_level_selection()
	board_view.queue_redraw()
	_update_guidance()


func _on_totals_changed(new_score: int, delivered: int, errors: int) -> void:
	hud_panel.update_stats(delivered, new_score, errors, controller.required_deliveries)


func _on_delivery_scored(parcel: DeliveryParcel, matched: bool) -> void:
	board_view.show_delivery_feedback(parcel, matched)
	sfx_player.play_event("success" if matched else "mistake")
	if matched:
		hint_label.text = "Delivered! +%d points." % ShiftController.SCORE_PER_DELIVERY
		if _score_tween != null and _score_tween.is_running():
			_score_tween.kill()
		score_label.modulate = ParcelTheme.GOLD_LIGHT
		if not reduced_motion:
			_score_tween = create_tween()
			_score_tween.tween_property(score_label, "modulate", Color.WHITE, 0.35)
		else:
			score_label.modulate = Color.WHITE
	else:
		hint_label.text = "Wrong house! Check the color and symbol."


func _on_shift_finished(success: bool, earned_score: int, delivered: int, errors: int) -> void:
	if success:
		progress_profile = ProgressStore.record_win(
			progress_profile, controller.level_index, earned_score, errors
		)
		if not ProgressStore.save_profile(progress_profile, progress_save_path):
			push_warning("Parcel Pulse progression could not be saved on this device.")
	var next_index: int = controller.level_index + 1
	var next_available: bool = success and ProgressStore.is_unlocked(
		progress_profile, next_index
	)
	result_panel.show_result(
		success, earned_score, delivered, errors, controller.required_deliveries,
		next_available
	)
	result_backdrop.visible = true
	result_backdrop.modulate.a = 1.0 if reduced_motion else 0.0
	_center_result()
	if _result_tween != null and _result_tween.is_running():
		_result_tween.kill()
	if not reduced_motion:
		_result_tween = create_tween()
		_result_tween.set_trans(Tween.TRANS_CUBIC)
		_result_tween.set_ease(Tween.EASE_OUT)
		_result_tween.tween_property(result_backdrop, "modulate:a", 1.0, 0.24)
	sfx_player.play_event("win" if success else "mistake")
