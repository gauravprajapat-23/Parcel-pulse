extends Control
class_name GameJuice

# UI-01C: event-driven effects, strictly presentation-only.
# No gameplay state, scoring, spawning, or route changes live here.
const EFFECT_LIFETIME: float = 0.92
const MAX_EFFECTS: int = 18
const SUCCESS_COLOR: Color = Color("#8AF6AF")
const MISTAKE_COLOR: Color = Color("#FF8291")
const TAP_COLOR: Color = Color("#FFD778")

var effects: Array[Dictionary] = []
var board: BoardState
var reduced_motion: bool = false
var _draw_accumulator: float = 0.0
const VISUAL_FRAME_STEP: float = 1.0 / 30.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func show_junction(node_id: String) -> void:
	if board == null or not board.is_junction(node_id):
		return
	# Junction state still changes and audio still plays; omit the ripple.
	if not reduced_motion:
		_append_effect("tap", node_id)


func show_delivery(
		parcel: DeliveryParcel, matched: bool,
		points: int = ShiftController.SCORE_PER_DELIVERY
	) -> void:
	if parcel == null:
		return
	var node_id: String = parcel.current_node
	if board == null or not board.has_node(node_id):
		node_id = "depot"
	_append_effect("success" if matched else "miss", node_id)
	if not effects.is_empty():
		effects[effects.size() - 1]["points"] = points
		effects[effects.size() - 1]["express"] = parcel.is_express and matched and points > 100


func clear_effects() -> void:
	effects.clear()
	_draw_accumulator = 0.0
	queue_redraw()


func active_feedback_count() -> int:
	return effects.size()


func _append_effect(kind: String, node_id: String) -> void:
	if effects.size() >= MAX_EFFECTS:
		effects.remove_at(0)
	effects.append({"kind": kind, "node": node_id, "elapsed": 0.0})
	queue_redraw()


func _process(delta: float) -> void:
	if effects.is_empty():
		return
	var removed_effect: bool = false
	for index in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[index]
		var elapsed: float = float(effect["elapsed"]) + maxf(delta, 0.0)
		if elapsed >= EFFECT_LIFETIME:
			effects.remove_at(index)
			removed_effect = true
		else:
			effect["elapsed"] = elapsed
			effects[index] = effect
	_draw_accumulator += maxf(delta, 0.0)
	if removed_effect or _draw_accumulator >= VISUAL_FRAME_STEP:
		_draw_accumulator = fposmod(_draw_accumulator, VISUAL_FRAME_STEP)
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var scale_factor: float = CityBoardGeometry.scale_for(size)
	var font: Font = get_theme_default_font()
	for effect in effects:
		var elapsed: float = float(effect["elapsed"])
		var fraction: float = clampf(elapsed / EFFECT_LIFETIME, 0.0, 1.0)
		var fade: float = 1.0 if reduced_motion else 1.0 - fraction
		var anchor: Vector2 = CityBoardGeometry.node_point(str(effect["node"]), size, board)
		var kind: String = str(effect["kind"])
		if kind == "tap":
			if reduced_motion:
				continue
			var radius: float = (27.0 + fraction * 31.0) * scale_factor
			var ring: Color = TAP_COLOR
			ring.a = fade * 0.75
			draw_arc(anchor, radius, 0.0, TAU, 32, ring, 3.5 * scale_factor, true)
			continue
		var is_express: bool = bool(effect.get("express", false))
		var tint: Color = MISTAKE_COLOR
		if kind == "success":
			tint = Color("#FFE58B") if is_express else SUCCESS_COLOR
		tint.a = fade
		var label: String = "MISROUTE!"
		if kind == "success":
			label = "+%d" % int(effect.get("points", 100))
			if is_express:
				label = "EXPRESS " + label
		var rise: float = 0.0 if reduced_motion else fraction * 33.0
		var position: Vector2 = anchor + Vector2(0.0, (-35.0 - rise) * scale_factor)
		var font_size: int = maxi(14, roundi((22.0 if kind == "success" else 16.0) * scale_factor))
		# Soft dark outline keeps the counter legible over houses and roads.
		draw_string_outline(
			font, position, label, HORIZONTAL_ALIGNMENT_CENTER, -1,
			font_size, 4, Color(0.02, 0.08, 0.12, fade * 0.9)
		)
		draw_string(font, position, label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, tint)
		if not reduced_motion:
			var halo: Color = tint
			halo.a *= 0.30
			draw_arc(anchor, (18.0 + fraction * 19.0) * scale_factor, 0.0, TAU, 30, halo, 3.0 * scale_factor, true)
