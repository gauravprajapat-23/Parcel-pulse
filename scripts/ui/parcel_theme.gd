extends RefCounted
class_name ParcelTheme

# UI-01A: shared palette and reusable styling. Gameplay rules remain separate.
const BACKDROP: Color = Color("#071729")
const PANEL: Color = Color("#0B2B43")
const PANEL_RAISED: Color = Color("#13364F")
const BORDER: Color = Color("#3ACDD9")
const BORDER_SOFT: Color = Color("#356A7F")
const GOLD: Color = Color("#FFC54F")
const GOLD_LIGHT: Color = Color("#FFE4A2")
const CYAN: Color = Color("#5BE3E8")
const GREEN: Color = Color("#81F2A9")
const RED: Color = Color("#FF738C")
const TEXT: Color = Color("#F0F8FF")
const MUTED: Color = Color("#A9C6D6")
const DISABLED: Color = Color("#586D80")
const BUTTON_DARK: Color = Color("#0C6179")


static func panel_style(
		fill_color: Color = PANEL,
		border_color: Color = BORDER_SOFT,
		corner_radius: int = 18,
		border_width: int = 2
	) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.shadow_color = Color(0.0, 0.65, 0.8, 0.12)
	style.shadow_size = 4
	return style


static func label_style(label: Label, font_size: int, color: Color = TEXT) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)


static func style_button(button: Button, tone: String = "secondary") -> void:
	var fill: Color = BUTTON_DARK
	var edge: Color = CYAN
	var ink: Color = TEXT
	match tone:
		"gold":
			fill = GOLD
			edge = GOLD_LIGHT
			ink = BACKDROP
		"quiet":
			fill = PANEL_RAISED
			edge = BORDER_SOFT
		"danger":
			fill = Color("#55354E")
			edge = RED

	var hover: Color = fill.lightened(0.10)
	var down: Color = fill.darkened(0.15)
	button.add_theme_stylebox_override("normal", panel_style(fill, edge, 18, 2))
	button.add_theme_stylebox_override("hover", panel_style(hover, edge.lightened(0.1), 18, 2))
	button.add_theme_stylebox_override("pressed", panel_style(down, edge, 18, 2))
	button.add_theme_stylebox_override("disabled", panel_style(Color("#183248"), Color("#304E64"), 18, 1))
	# Preserve a visible focus outline for keyboard and accessibility navigation.
	button.add_theme_stylebox_override("focus", panel_style(Color.TRANSPARENT, GOLD_LIGHT, 18, 2))
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.22))
	button.add_theme_font_size_override("font_size", 19)
