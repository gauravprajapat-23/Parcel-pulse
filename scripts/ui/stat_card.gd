extends PanelContainer
class_name StatCard

@onready var glyph_label: Label = $Inner/Row/Glyph
@onready var value_label: Label = $Inner/Row/Column/Value
@onready var caption_label: Label = $Inner/Row/Column/Caption

var accent: Color = ParcelTheme.CYAN


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", ParcelTheme.panel_style(
		ParcelTheme.PANEL, ParcelTheme.BORDER_SOFT, 16, 1
	))
	ParcelTheme.label_style(glyph_label, 25, accent)
	ParcelTheme.label_style(value_label, 23, ParcelTheme.TEXT)
	ParcelTheme.label_style(caption_label, 11, ParcelTheme.MUTED)


func configure(caption: String, glyph: String, highlight: Color) -> void:
	accent = highlight
	if not is_node_ready():
		return
	glyph_label.text = glyph
	caption_label.text = caption.to_upper()
	glyph_label.add_theme_color_override("font_color", accent)


func set_value(value: String) -> void:
	if is_node_ready():
		value_label.text = value


func apply_compact(compact: bool, height: int) -> void:
	if not is_node_ready():
		return
	custom_minimum_size.y = float(height)
	# At the narrowest width, prioritize readable values and captions.
	glyph_label.visible = height > 62
	ParcelTheme.label_style(glyph_label, 20 if compact else 25, accent)
	ParcelTheme.label_style(value_label, 19 if compact else 23, ParcelTheme.TEXT)
	ParcelTheme.label_style(caption_label, 10 if compact else 11, ParcelTheme.MUTED)
