extends PanelContainer
class_name ResultScreen

signal retry_requested()
signal menu_requested()

var title_label: Label
var details_label: Label


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
	column.add_theme_constant_override("separation", 15)
	padding.add_child(column)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color("#fff0c9"))
	column.add_child(title_label)

	details_label = Label.new()
	details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.add_theme_font_size_override("font_size", 19)
	column.add_child(details_label)

	var retry_button := Button.new()
	retry_button.text = "PLAY AGAIN"
	retry_button.custom_minimum_size = Vector2(0, 48)
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	column.add_child(retry_button)

	var menu_button := Button.new()
	menu_button.text = "BACK TO MENU"
	menu_button.custom_minimum_size = Vector2(0, 48)
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	column.add_child(menu_button)


func show_result(success: bool, earned_score: int, delivered: int, errors: int) -> void:
	title_label.text = "SHIFT COMPLETE!" if success else "SHIFT ENDED"
	details_label.text = "Delivered: %d/12     Errors: %d/3\nScore: %d" % [
		delivered, errors, earned_score
	]


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#20334c")
	style.border_color = Color("#6985a3")
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	return style
