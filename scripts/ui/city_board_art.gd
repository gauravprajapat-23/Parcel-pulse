extends Control
class_name CityBoardArt

var board: BoardState

# Static, handcrafted procedural city backdrop. No textures, plugins or
# copyrighted artwork. Redrawn only on resize, not every gameplay frame.
const NIGHT: Color = Color("#071C31")
const ASPHALT: Color = Color("#19334B")
const CURB: Color = Color("#647D8C")
const LANE: Color = Color("#7FA8B9")
const RED_HOUSE: Color = Color("#FF6D87")
const BLUE_HOUSE: Color = Color("#56B7FF")
const GREEN_HOUSE: Color = Color("#75DF9D")
const HOUSE_WALL: Color = Color("#E2E3D8")
const WARM_WINDOW: Color = Color("#FFD77E")
const TREE_GREEN: Color = Color("#176F60")
const TREE_TOP: Color = Color("#279879")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or board == null:
		return
	_draw_sky_and_blocks()
	_draw_roads()
	_draw_park_details()
	_draw_destinations()
	_draw_depot()


func _scale() -> float:
	return CityBoardGeometry.scale_for(size)


func _uv(x: float, y: float) -> Vector2:
	return Vector2(x * size.x, y * size.y)


func _draw_sky_and_blocks() -> void:
	var base: Color = NIGHT
	match board.palette:
		1: base = Color("#183049")
		2: base = Color("#0E3C3C")
	draw_rect(Rect2(Vector2.ZERO, size), base)
	for index in range(7):
		var shade: Color = base.lightened(0.12).lerp(base.darkened(0.07), float(index) / 6.0)
		draw_rect(Rect2(0, size.y * float(index) / 7.0, size.x, size.y / 7.0 + 1.0), shade)

	# Quiet skyline: deliberately low-contrast so destinations stay readable.
	for index in range(15):
		var x: float = float(index) / 15.0 * size.x
		var height_ratio: float = 0.055 + float((index * 11 + 3) % 7) * 0.012
		var building_h: float = size.y * height_ratio
		var top: float = size.y * 0.26 - building_h
		draw_rect(Rect2(x, top, size.x / 14.5, building_h), Color("#0B253A"))
		for row in range(2):
			for col in range(2):
				if (index + row * 2 + col) % 3 != 0:
					draw_rect(Rect2(
						x + 5.0 * _scale() + float(col) * 12.0 * _scale(),
						top + 8.0 * _scale() + float(row) * 13.0 * _scale(),
						3.0 * _scale(), 5.0 * _scale()
					), Color("#806E59"))
	for i in range(18):
		var star: Vector2 = _uv(float((i * 47 + 19) % 97) / 97.0, float((i * 13 + 7) % 23) / 180.0)
		draw_circle(star, 0.9 * _scale(), Color("#87C6E2", 0.6), true)

	# Pavement islands give the miniature board a clear playable footprint.
	for spot in [Vector2(0.07, 0.61), Vector2(0.91, 0.58), Vector2(0.13, 0.82), Vector2(0.83, 0.86)]:
		draw_circle(_uv(spot.x, spot.y), 36.0 * _scale(), Color("#21495A"), true)
		draw_circle(_uv(spot.x, spot.y), 32.0 * _scale(), Color("#1B5A57"), true)


func _draw_roads() -> void:
	var s: float = _scale()
	for from_id in board.edges.keys():
		var exits: Array = board.edges[from_id]
		for to_id in exits:
			var road: PackedVector2Array = CityBoardGeometry.route_polyline(
				str(from_id), str(to_id), size, 20, board
			)
			draw_polyline(road, Color("#061421"), 43.0 * s, true)
			draw_polyline(road, CURB, 36.0 * s, true)
			draw_polyline(road, ASPHALT, 29.0 * s, true)
			# Small discrete center markings keep branching routes legible.
			for marker in range(2, 9, 2):
				var fraction: float = float(marker) / 10.0
				var before: Vector2 = CityBoardGeometry.route_point(
					str(from_id), str(to_id), fraction - 0.025, size, board
				)
				var after: Vector2 = CityBoardGeometry.route_point(
					str(from_id), str(to_id), fraction + 0.025, size, board
				)
				draw_line(before, after, Color("#8DB0BF", 0.7), 2.0 * s, true)


func _draw_park_details() -> void:
	var s: float = _scale()
	for spot in [
		Vector2(0.12, 0.36), Vector2(0.88, 0.36),
		Vector2(0.13, 0.57), Vector2(0.87, 0.62),
		Vector2(0.19, 0.73), Vector2(0.76, 0.77),
		Vector2(0.18, 0.96), Vector2(0.83, 0.95)
	]:
		_draw_tree(_uv(spot.x, spot.y), s)
	_draw_lamp(_uv(0.065, 0.47), s)
	_draw_lamp(_uv(0.94, 0.48), s)
	_draw_lamp(_uv(0.84, 0.91), s)
	_draw_fountain(_uv(0.88, 0.79), s)
	_draw_bench(_uv(0.68, 0.87), s)


func _draw_tree(position: Vector2, s: float) -> void:
	draw_circle(position + Vector2(2, 7) * s, 17 * s, Color("#051A28", 0.55), true)
	draw_rect(Rect2(position + Vector2(-3, 1) * s, Vector2(6, 16) * s), Color("#5D493C"))
	draw_circle(position + Vector2(-9, -7) * s, 14 * s, TREE_GREEN, true)
	draw_circle(position + Vector2(8, -9) * s, 16 * s, TREE_GREEN, true)
	draw_circle(position + Vector2(0, -17) * s, 15 * s, TREE_TOP, true)


func _draw_lamp(position: Vector2, s: float) -> void:
	draw_circle(position + Vector2(0, 4) * s, 13 * s, Color("#FFCC75", 0.13), true)
	draw_line(position + Vector2(0, 6) * s, position + Vector2(0, -17) * s, Color("#15202C"), 5.0 * s, true)
	draw_circle(position + Vector2(0, -19) * s, 9 * s, Color("#F6C969", 0.25), true)
	draw_circle(position + Vector2(0, -19) * s, 4 * s, WARM_WINDOW, true)


func _draw_fountain(position: Vector2, s: float) -> void:
	draw_circle(position, 22 * s, Color("#516B7C"), true)
	draw_circle(position, 17 * s, Color("#126B93"), true)
	draw_circle(position, 11 * s, Color("#59C9F4"), true)
	draw_arc(position, 13 * s, 0.0, TAU, 28, Color("#AEF5FF"), 2.0 * s, true)
	draw_line(position + Vector2(0, 2) * s, position + Vector2(0, -17) * s, Color("#95E8FD"), 2.0 * s, true)


func _draw_bench(position: Vector2, s: float) -> void:
	draw_rect(Rect2(position + Vector2(-12, -6) * s, Vector2(24, 8) * s), Color("#AD7955"))
	draw_line(position + Vector2(-8, 2) * s, position + Vector2(-8, 10) * s, Color("#263D49"), 3 * s, true)
	draw_line(position + Vector2(8, 2) * s, position + Vector2(8, 10) * s, Color("#263D49"), 3 * s, true)


func _draw_destinations() -> void:
	_draw_house("red", RED_HOUSE)
	_draw_house("blue", BLUE_HOUSE)
	_draw_house("green", GREEN_HOUSE)


func _draw_house(node_id: String, accent: Color) -> void:
	var s: float = _scale()
	var center: Vector2 = CityBoardGeometry.node_point(node_id, size, board) + Vector2(0, -21) * s
	# Keep the roof (57*s above center) inside the clip area on short phones.
	center.y = maxf(center.y, 61.0 * s)
	var half_width: float = 33.0 * s
	var top: float = center.y - 26.0 * s
	var front: Rect2 = Rect2(
		center.x - half_width, top, 66.0 * s, 53.0 * s
	)
	draw_rect(Rect2(front.position + Vector2(3, 4) * s, front.size), Color("#07131E", 0.55))
	draw_rect(front, HOUSE_WALL)
	draw_rect(Rect2(front.position, Vector2(front.size.x, 6.0 * s)), accent)
	var roof := PackedVector2Array([
		center + Vector2(-41, -23) * s,
		center + Vector2(0, -57) * s,
		center + Vector2(41, -23) * s,
		center + Vector2(34, -18) * s,
		center + Vector2(0, -45) * s,
		center + Vector2(-34, -18) * s,
	])
	draw_colored_polygon(roof, accent.darkened(0.25))
	draw_polyline(PackedVector2Array([
		center + Vector2(-41, -23) * s,
		center + Vector2(0, -57) * s,
		center + Vector2(41, -23) * s
	]), accent.lightened(0.18), 4.0 * s, true)

	for side in [-1, 1]:
		var window_center: Vector2 = center + Vector2(float(side) * 20.0, 7.0) * s
		draw_rect(Rect2(window_center - Vector2(8, 9) * s, Vector2(16, 17) * s), Color("#324251"))
		draw_rect(Rect2(window_center - Vector2(5, 6) * s, Vector2(10, 11) * s), WARM_WINDOW)
		draw_line(window_center + Vector2(0, -6) * s, window_center + Vector2(0, 5) * s, Color("#926B4C"), 2 * s, true)
	var door: Rect2 = Rect2(center + Vector2(-9, 5) * s, Vector2(18, 22) * s)
	draw_rect(door, accent.darkened(0.33))
	draw_circle(center + Vector2(5, 17) * s, 1.4 * s, WARM_WINDOW, true)

	# High-contrast color-and-shape destination emblem above the door.
	var badge: Vector2 = center + Vector2(0, -12) * s
	draw_circle(badge, 15.0 * s, Color("#FFFFFF"), true)
	_draw_emblem(badge, node_id, accent, 10.0 * s)


func _draw_depot() -> void:
	var s: float = _scale()
	var center: Vector2 = CityBoardGeometry.node_point("depot", size, board) + Vector2(0, 15) * s
	var body: Rect2 = Rect2(center + Vector2(-55, -24) * s, Vector2(110, 49) * s)
	draw_rect(Rect2(body.position + Vector2(4, 4) * s, body.size), Color("#07131E", 0.55))
	draw_rect(body, Color("#426982"))
	var roof := PackedVector2Array([
		center + Vector2(-62, -24) * s, center + Vector2(0, -56) * s,
		center + Vector2(62, -24) * s, center + Vector2(56, -16) * s,
		center + Vector2(0, -43) * s, center + Vector2(-56, -16) * s
	])
	draw_colored_polygon(roof, Color("#204965"))
	draw_polyline(PackedVector2Array([
		center + Vector2(-62, -24) * s, center + Vector2(0, -56) * s,
		center + Vector2(62, -24) * s
	]), Color("#86C6E3"), 3.0 * s, true)
	var entrance: Rect2 = Rect2(center + Vector2(-31, -7) * s, Vector2(62, 32) * s)
	draw_rect(entrance, Color("#122D3D"))
	draw_rect(Rect2(entrance.position + Vector2(4, 4) * s, entrance.size - Vector2(8, 4) * s), Color("#A36D35"))
	for i in range(3):
		var p: Vector2 = center + Vector2(-22 + 19 * i, 11 - (i % 2) * 7) * s
		draw_rect(Rect2(p, Vector2(17, 13) * s), Color("#F2BA54"))
		draw_line(p + Vector2(8, 0) * s, p + Vector2(8, 13) * s, Color("#C28231"), 1.5 * s, true)
	var sign: Rect2 = Rect2(center + Vector2(-39, -38) * s, Vector2(78, 23) * s)
	draw_rect(sign, Color("#FFE4A6"))
	draw_string(
		get_theme_default_font(), sign.position + Vector2(0, 17) * s,
		"DEPOT", HORIZONTAL_ALIGNMENT_CENTER, sign.size.x,
		maxi(11, roundi(15 * s)), Color("#163247")
	)


func _draw_emblem(center: Vector2, target: String, tint: Color, radius: float) -> void:
	match target:
		"red":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -radius), center + Vector2(radius, 0),
				center + Vector2(0, radius), center + Vector2(-radius, 0)
			]), tint)
		"blue":
			draw_circle(center, radius * 0.85, tint, true)
		"green":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -radius), center + Vector2(radius, radius * 0.85),
				center + Vector2(-radius, radius * 0.85)
			]), tint)
