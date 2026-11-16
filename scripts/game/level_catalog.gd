extends RefCounted
class_name LevelCatalog

# Offline levels are built into the app. Each configuration owns its graph,
# positions, switch defaults, delivery sequence and difficulty. No editor,
# backend, or remote level loading is needed.
const DESTINATIONS = ["red", "blue", "green"]
const LEVELS = [
	{
		"id": "old_town",
		"difficulty": 1,
		"name": "Old Town",
		"tagline": "Learn the golden switches",
		"palette": 0,
		"quota": 12,
		"spawn_interval": 2.45,
		"nodes": {
			"depot": Vector2(0.50, 0.89),
			"hub": Vector2(0.50, 0.68),
			"west": Vector2(0.26, 0.44),
			"east": Vector2(0.74, 0.44),
			"red": Vector2(0.12, 0.15),
			"blue": Vector2(0.50, 0.13),
			"green": Vector2(0.88, 0.15),
		},
		"edges": {
			"depot": ["hub"],
			"hub": ["west", "east"],
			"west": ["red", "blue"],
			"east": ["blue", "green"],
		},
		"defaults": {"hub": 0, "west": 0, "east": 1},
		"schedule": [
			"red", "blue", "green", "red", "green", "blue",
			"blue", "red", "green", "red", "blue", "green",
			"red", "green", "blue", "blue", "red", "green",
		],
	},
	{
		"id": "mirror_market",
		"difficulty": 2,
		"name": "Mirror Market",
		"tagline": "Destinations have switched sides",
		"palette": 1,
		"quota": 13,
		"spawn_interval": 2.30,
		"nodes": {
			"depot": Vector2(0.52, 0.89),
			"hub": Vector2(0.50, 0.68),
			"west": Vector2(0.24, 0.47),
			"east": Vector2(0.76, 0.43),
			"red": Vector2(0.88, 0.15),
			"blue": Vector2(0.50, 0.13),
			"green": Vector2(0.12, 0.15),
		},
		"edges": {
			"depot": ["hub"],
			"hub": ["west", "east"],
			"west": ["green", "blue"],
			"east": ["blue", "red"],
		},
		"defaults": {"hub": 0, "west": 0, "east": 1},
		"schedule": [
			"green", "red", "blue", "red", "green", "blue",
			"green", "blue", "red", "red", "green", "blue",
			"red", "green", "blue", "green", "red", "blue",
		],
	},
	{
		"id": "canal_crossing",
		"difficulty": 3,
		"name": "Canal Crossing",
		"tagline": "A fourth junction changes everything",
		"palette": 2,
		"quota": 14,
		"spawn_interval": 2.15,
		"nodes": {
			"depot": Vector2(0.52, 0.90),
			"hub": Vector2(0.52, 0.70),
			"west": Vector2(0.25, 0.48),
			"east": Vector2(0.77, 0.48),
			"upper": Vector2(0.50, 0.31),
			"red": Vector2(0.12, 0.13),
			"blue": Vector2(0.50, 0.11),
			"green": Vector2(0.88, 0.13),
		},
		"edges": {
			"depot": ["hub"],
			"hub": ["west", "east"],
			"west": ["red", "upper"],
			"east": ["upper", "green"],
			"upper": ["blue", "green"],
		},
		"defaults": {"hub": 0, "west": 0, "east": 1, "upper": 0},
		"schedule": [
			"red", "blue", "green", "green", "red", "blue",
			"red", "green", "blue", "blue", "red", "green",
			"green", "blue", "red", "blue", "green", "red",
			"blue", "green",
		],
	},
	{
		"id": "riverside_switch",
		"name": "Riverside Switch",
		"tagline": "Two approaches to the same houses",
		"palette": 3,
		"difficulty": 4,
		"quota": 15,
		"spawn_interval": 2.10,
		"nodes": {
			"depot": Vector2(0.48, 0.90),
			"hub": Vector2(0.48, 0.71),
			"west": Vector2(0.23, 0.49),
			"east": Vector2(0.77, 0.46),
			"upper": Vector2(0.50, 0.30),
			"red": Vector2(0.12, 0.14),
			"blue": Vector2(0.50, 0.12),
			"green": Vector2(0.89, 0.14),
		},
		"edges": {
			"depot": ["hub"],
			"hub": ["east", "west"],
			"west": ["upper", "red"],
			"east": ["green", "upper"],
			"upper": ["blue", "green"],
		},
		"defaults": {"hub": 1, "west": 1, "east": 0, "upper": 0},
		"schedule": [
			"blue", "red", "green", "blue", "green", "red",
			"blue", "green", "red", "green", "blue", "red",
			"blue", "red", "green", "blue", "green", "red",
			"green", "blue", "red",
		],
	},
	{
		"id": "beacon_docks",
		"name": "Beacon Docks",
		"tagline": "Five junctions, one busy harbor",
		"palette": 4,
		"difficulty": 5,
		"quota": 16,
		"spawn_interval": 2.05,
		"nodes": {
			"depot": Vector2(0.50, 0.91),
			"hub": Vector2(0.50, 0.75),
			"west": Vector2(0.24, 0.57),
			"east": Vector2(0.76, 0.57),
			"north_west": Vector2(0.28, 0.36),
			"north_east": Vector2(0.72, 0.36),
			"red": Vector2(0.12, 0.12),
			"blue": Vector2(0.50, 0.11),
			"green": Vector2(0.88, 0.12),
		},
		"edges": {
			"depot": ["hub"],
			"hub": ["west", "east"],
			"west": ["red", "north_west"],
			"east": ["north_east", "green"],
			"north_west": ["blue", "red"],
			"north_east": ["green", "blue"],
		},
		"defaults": {
			"hub": 0, "west": 0, "east": 1,
			"north_west": 0, "north_east": 1,
		},
		"schedule": [
			"red", "green", "blue", "red", "blue", "green",
			"green", "blue", "red", "blue", "red", "green",
			"blue", "green", "red", "green", "blue", "red",
			"green", "blue", "red", "blue",
		],
	},
]


static func difficulty_text(index: int) -> String:
	if index < 0 or index >= count():
		return "UNKNOWN"
	match int(LEVELS[index].get("difficulty", 1)):
		1: return "INTRO"
		2: return "EASY"
		3: return "MODERATE"
		4: return "TRICKY"
		_: return "EXPERT"


static func count() -> int:
	return LEVELS.size()


static func get_level(index: int) -> Dictionary:
	if index < 0 or index >= LEVELS.size():
		return {}
	return (LEVELS[index] as Dictionary).duplicate(true)


static func path_exists(edges: Dictionary, start: String, destination: String) -> bool:
	if start == destination:
		return true
	var pending: Array[String] = [start]
	var visited: Dictionary = {}
	while not pending.is_empty():
		var current: String = pending.pop_front()
		if visited.has(current):
			continue
		visited[current] = true
		if not edges.has(current):
			continue
		for successor in edges[current]:
			var next_id: String = str(successor)
			if next_id == destination:
				return true
			if not visited.has(next_id):
				pending.append(next_id)
	return false


static func validate(level: Dictionary) -> bool:
	for required in ["id", "name", "nodes", "edges", "defaults", "schedule", "quota", "spawn_interval", "difficulty"]:
		if not level.has(required):
			return false
	var nodes: Dictionary = level["nodes"]
	var edges: Dictionary = level["edges"]
	var defaults: Dictionary = level["defaults"]
	var sequence: Array = level["schedule"]
	if nodes.size() < 7 or not nodes.has("depot") or edges.is_empty():
		return false
	if int(level["quota"]) < 1 or float(level["spawn_interval"]) <= 0.0:
		return false
	if int(level["difficulty"]) < 1 or int(level["difficulty"]) > 5:
		return false
	if sequence.size() < int(level["quota"]) + 2:
		return false
	for key in ["depot", "red", "blue", "green"]:
		if not nodes.has(key):
			return false
	for node_id in nodes:
		if not nodes[node_id] is Vector2:
			return false
		var position: Vector2 = nodes[node_id]
		if position.x < 0.05 or position.x > 0.95 or position.y < 0.05 or position.y > 0.95:
			return false
	for junction_id in edges:
		var options: Array = edges[junction_id]
		if not nodes.has(junction_id) or options.is_empty():
			return false
		if junction_id == "depot":
			if options.size() != 1:
				return false
		elif options.size() != 2 or not defaults.has(junction_id):
			return false
		if options.size() == 2 and int(defaults.get(junction_id, -1)) not in [0, 1]:
			return false
		var seen: Dictionary = {}
		for neighbor in options:
			var next_id: String = str(neighbor)
			if not nodes.has(next_id) or seen.has(next_id) or next_id == str(junction_id):
				return false
			seen[next_id] = true
			if path_exists(edges, next_id, str(junction_id)):
				return false
	for target in DESTINATIONS:
		if edges.has(target) or not path_exists(edges, "depot", target):
			return false
	for item in sequence:
		if not DESTINATIONS.has(str(item)):
			return false
	return true
