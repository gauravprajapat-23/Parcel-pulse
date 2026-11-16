extends Button
class_name ActionButton

# A reusable, touch-sized, styled button. The icon is drawn as vector geometry
# instead of relying on platform-specific emoji or external font resources.
var glyph: String = "play"
var tone: String = "secondary"


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_style()


func configure(caption: String, icon_name: String, button_tone: String = "secondary") -> void:
	text = caption
	glyph = icon_name
	tone = button_tone
	if is_node_ready():
		_apply_style()
		queue_redraw()


func _apply_style() -> void:
	ParcelTheme.style_button(self, tone)


func _draw() -> void:
	var center := Vector2(24.0, size.y * 0.5)
	var ink: Color = ParcelTheme.BACKDROP if tone == "gold" else ParcelTheme.TEXT
	if disabled:
		ink = ParcelTheme.DISABLED
	match glyph:
		"play":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-6, -10),
				center + Vector2(10, 0),
				center + Vector2(-6, 10)
			]), ink)
		"pause":
			draw_rect(Rect2(center + Vector2(-10, -10), Vector2(7, 20)), ink)
			draw_rect(Rect2(center + Vector2(3, -10), Vector2(7, 20)), ink)
		"retry":
			draw_arc(center, 9.0, 0.6, TAU - 0.55, 22, ink, 3.4, true)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(9, -7), center + Vector2(13, -15),
				center + Vector2(3, -12)
			]), ink)
		"guide":
			draw_line(center + Vector2(0, -8), center + Vector2(0, 10), ink, 2.5, true)
			draw_line(center + Vector2(0, -7), center + Vector2(-11, -10), ink, 2.5, true)
			draw_line(center + Vector2(-11, -10), center + Vector2(-11, 7), ink, 2.5, true)
			draw_line(center + Vector2(-11, 7), center + Vector2(0, 10), ink, 2.5, true)
			draw_line(center + Vector2(0, -7), center + Vector2(11, -10), ink, 2.5, true)
			draw_line(center + Vector2(11, -10), center + Vector2(11, 7), ink, 2.5, true)
			draw_line(center + Vector2(11, 7), center + Vector2(0, 10), ink, 2.5, true)
		"exit":
			draw_line(center + Vector2(-12, -11), center + Vector2(-12, 11), ink, 3.0, true)
			draw_line(center + Vector2(-12, -11), center + Vector2(2, -11), ink, 3.0, true)
			draw_line(center + Vector2(-12, 11), center + Vector2(2, 11), ink, 3.0, true)
			draw_line(center + Vector2(-4, 0), center + Vector2(12, 0), ink, 3.0, true)
			draw_line(center + Vector2(6, -6), center + Vector2(12, 0), ink, 3.0, true)
			draw_line(center + Vector2(6, 6), center + Vector2(12, 0), ink, 3.0, true)
