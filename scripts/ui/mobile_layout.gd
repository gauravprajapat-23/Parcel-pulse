extends RefCounted
class_name MobileLayout

# UI-01D: predictable layout profiles and conservative display-safe padding.
# This class contains no scene or gameplay state and can be tested headlessly.
const FULL: int = 0
const COMPACT: int = 1
const SMALL: int = 2


static func profile_for(viewport_size: Vector2) -> int:
	if viewport_size.x < 370.0 or viewport_size.y < 740.0:
		return SMALL
	if viewport_size.x < 480.0 or viewport_size.y < 900.0:
		return COMPACT
	return FULL


static func metrics(viewport_size: Vector2) -> Dictionary:
	match profile_for(viewport_size):
		SMALL:
			return {
				"outer": 9, "top": 10, "bottom": 10, "gap": 5,
				"title": 19, "subtitle": false, "board": Vector2(215, 250),
				"stats_height": 62, "action_height": 56,
				"coach_font": 13, "coach_height": 30,
				"hint": false, "sound_font": 10
			}
		COMPACT:
			return {
				"outer": 12, "top": 14, "bottom": 12, "gap": 7,
				"title": 23, "subtitle": false, "board": Vector2(228, 285),
				"stats_height": 68, "action_height": 60,
				"coach_font": 14, "coach_height": 34,
				"hint": true, "sound_font": 11
			}
		_:
			return {
				"outer": 16, "top": 20, "bottom": 18, "gap": 10,
				"title": 30, "subtitle": true, "board": Vector2(260, 340),
				"stats_height": 76, "action_height": 64,
				"coach_font": 16, "coach_height": 36,
				"hint": true, "sound_font": 12
			}


static func extra_safe_insets(safe_rect: Rect2i, window_pixels: Vector2i, logical_size: Vector2) -> Vector4:
	# Safe rect and window dimensions are in physical screen pixels.
	# Do not add the system-bar inset twice when Android has already given the
	# game a smaller, non-edge-to-edge window.
	if window_pixels.x <= 0 or window_pixels.y <= 0:
		return Vector4.ZERO
	if safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		return Vector4.ZERO
	if window_pixels.x <= safe_rect.size.x and window_pixels.y <= safe_rect.size.y:
		return Vector4.ZERO
	var left_px: float = maxf(0.0, float(safe_rect.position.x))
	var top_px: float = maxf(0.0, float(safe_rect.position.y))
	var right_px: float = maxf(0.0, float(window_pixels.x - safe_rect.end.x))
	var bottom_px: float = maxf(0.0, float(window_pixels.y - safe_rect.end.y))
	# Clamp unusual desktop/foldable data rather than swallowing the controls.
	return Vector4(
		minf(48.0, left_px * logical_size.x / float(window_pixels.x)),
		minf(48.0, top_px * logical_size.y / float(window_pixels.y)),
		minf(48.0, right_px * logical_size.x / float(window_pixels.x)),
		minf(48.0, bottom_px * logical_size.y / float(window_pixels.y))
	)


static func fits_minimum_content(viewport_size: Vector2) -> bool:
	var m: Dictionary = metrics(viewport_size)
	var width_needed: float = float(m["outer"]) * 2.0 + float((m["board"] as Vector2).x)
	# Estimated static minimum for the title, 3 stat cards, guide, buttons
	# and seven inter-container gaps. Viewport tests still inspect real nodes.
	var height_needed: float = float(m["top"]) + float(m["bottom"]) 		+ 37.0 + float(m["stats_height"]) + float((m["board"] as Vector2).y) 		+ 16.0 + float(m["coach_height"]) + 2.0 * float(m["action_height"]) 		+ 8.0 + 6.0 * float(m["gap"])
	if bool(m["subtitle"]):
		height_needed += 20.0
	if bool(m["hint"]):
		height_needed += 22.0
	return viewport_size.x >= width_needed and viewport_size.y >= height_needed
