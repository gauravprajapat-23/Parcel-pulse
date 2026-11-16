extends RefCounted
class_name CityBoardGeometry

# Presentation-only Bezier geometry for the existing directed graph.
# Both roads and moving parcel carts use the same evaluator.
const CURVATURE: Dictionary = {
	"depot:hub": 0.0,
	"hub:west": 0.08,
	"hub:east": -0.08,
	"west:red": -0.07,
	"west:blue": 0.07,
	"east:blue": -0.07,
	"east:green": 0.07,
}


static func node_point(node_id: String, bounds: Vector2, board: BoardState = null) -> Vector2:
	var positions: Dictionary = board.nodes if board != null else BoardState.NODES
	if not positions.has(node_id):
		return Vector2.ZERO
	var uv: Vector2 = positions[node_id]
	return Vector2(uv.x * bounds.x, uv.y * bounds.y)


static func route_point(from_id: String, to_id: String, t: float, bounds: Vector2, board: BoardState = null) -> Vector2:
	var start: Vector2 = node_point(from_id, bounds, board)
	var finish: Vector2 = node_point(to_id, bounds, board)
	var connections: Dictionary = board.edges if board != null else BoardState.EDGES
	if not connections.has(from_id):
		return start
	var options: Array = connections[from_id]
	if not options.has(to_id):
		return start
	var delta: Vector2 = finish - start
	var perpendicular := Vector2(-delta.y, delta.x)
	var bend: float = float(CURVATURE.get(from_id + ":" + to_id, 0.0))
	var c1: Vector2 = start + delta * 0.34 + perpendicular * bend
	var c2: Vector2 = start + delta * 0.66 + perpendicular * bend
	var fraction: float = clampf(t, 0.0, 1.0)
	var inverse: float = 1.0 - fraction
	return (
		start * inverse * inverse * inverse
		+ 3.0 * c1 * inverse * inverse * fraction
		+ 3.0 * c2 * inverse * fraction * fraction
		+ finish * fraction * fraction * fraction
	)


static func route_tangent(from_id: String, to_id: String, t: float, bounds: Vector2, board: BoardState = null) -> Vector2:
	var a: Vector2 = route_point(from_id, to_id, clampf(t - 0.01, 0.0, 1.0), bounds, board)
	var b: Vector2 = route_point(from_id, to_id, clampf(t + 0.01, 0.0, 1.0), bounds, board)
	var vector: Vector2 = b - a
	if vector.length_squared() < 0.0001:
		return Vector2.UP
	return vector.normalized()


static func route_polyline(from_id: String, to_id: String, bounds: Vector2, steps: int = 20, board: BoardState = null) -> PackedVector2Array:
	var result := PackedVector2Array()
	var connections: Dictionary = board.edges if board != null else BoardState.EDGES
	if not connections.has(from_id):
		return result
	var options: Array = connections[from_id]
	if not options.has(to_id):
		return result
	var count: int = maxi(2, steps)
	for index in range(count + 1):
		result.append(route_point(from_id, to_id, float(index) / float(count), bounds, board))
	return result


static func scale_for(bounds: Vector2) -> float:
	# UI scales down on narrower phones; hit targets remain independent.
	return clampf(minf(bounds.x / 480.0, bounds.y / 570.0), 0.55, 1.2)
