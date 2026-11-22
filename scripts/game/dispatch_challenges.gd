extends RefCounted
class_name DispatchChallenges

# The same three clear, optional mini-contracts on every map. The requested
# color rotates with the stage. All conditions use *actual* Arcade deliveries.
const COLOR_TARGETS = ["red", "green", "blue", "red", "green"]
const MISSION_COUNT: int = 3


static func mission_for(index: int, level_index: int) -> Dictionary:
	if index < 0 or index >= MISSION_COUNT:
		return {}
	match index:
		0:
			var color_index: int = posmod(level_index, COLOR_TARGETS.size())
			var color: String = COLOR_TARGETS[color_index]
			return {
				"id": "color_run", "title": color.to_upper() + " DELIVERY",
				"target": color, "goal": 2, "reward": 150,
				"hint": "Send 2 %s parcels to their homes" % color.to_upper()
			}
		1:
			return {
				"id": "clean_streak", "title": "CLEAN STREAK",
				"target": "", "goal": 3, "reward": 200,
				"hint": "Make 3 correct deliveries in a row"
			}
		2:
			return {
				"id": "gold_express", "title": "GOLD EXPRESS",
				"target": "", "goal": 1, "reward": 250,
				"hint": "Beat the timer on one golden parcel"
			}
	return {}
