extends PanelContainer
class_name ResultScreen

signal retry_requested()
signal menu_requested()
signal next_stage_requested()

const ACTION_BUTTON_SCENE = preload("res://scenes/ui/action_button.tscn")

var title_label: Label
var details_label: Label
var rating_label: Label
var next_stage_button: ActionButton
var menu_button: ActionButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style())
	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 20)
	padding.add_theme_constant_override("margin_right", 20)
	padding.add_theme_constant_override("margin_top", 25)
	padding.add_theme_constant_override("margin_bottom", 22)
	add_child(padding)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	padding.add_child(column)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color("#fff0c9"))
	column.add_child(title_label)
	rating_label = Label.new()
	rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rating_label.add_theme_font_size_override("font_size", 24)
	rating_label.add_theme_color_override("font_color", ParcelTheme.GOLD_LIGHT)
	column.add_child(rating_label)

	details_label = Label.new()
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.add_theme_font_size_override("font_size", 19)
	column.add_child(details_label)

	var retry_button := ACTION_BUTTON_SCENE.instantiate() as ActionButton
	column.add_child(retry_button)
	retry_button.configure("PLAY AGAIN", "retry", "gold")
	retry_button.pressed.connect(func() -> void: retry_requested.emit())

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)

	next_stage_button = ACTION_BUTTON_SCENE.instantiate() as ActionButton
	actions.add_child(next_stage_button)
	next_stage_button.configure("NEXT STAGE", "play", "gold")
	next_stage_button.pressed.connect(func() -> void: next_stage_requested.emit())
	next_stage_button.visible = false

	menu_button = ACTION_BUTTON_SCENE.instantiate() as ActionButton
	actions.add_child(menu_button)
	menu_button.configure("LEVELS", "exit", "secondary")
	menu_button.pressed.connect(func() -> void: menu_requested.emit())


func show_result(
		success: bool, earned_score: int, delivered: int, errors: int,
		quota: int = ShiftController.REQUIRED_DELIVERIES, has_next: bool = false
	) -> void:
	next_stage_button.visible = success and has_next
	title_label.text = "SHIFT COMPLETE!" if success else "SHIFT ENDED"
	if success:
		var stars: int = clampi(3 - errors, 1, 3)
		rating_label.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	else:
		rating_label.text = "KEEP PRACTICING"
	details_label.text = "DELIVERED %d / %d    MISTAKES %d / 3\nSCORE  %d" % [
		delivered, quota, errors, earned_score
	]


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ParcelTheme.PANEL_RAISED
	style.border_color = ParcelTheme.CYAN
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	return style
