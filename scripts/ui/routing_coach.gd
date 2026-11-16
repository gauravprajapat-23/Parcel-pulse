extends RefCounted
class_name RoutingCoach

# Read-only, optional teaching assistance. Never changes board state.
# Advise the next junction a parcel is actually approaching, not a future
# switch that might misroute an earlier parcel.
const SYMBOLS = {"red": "DIAMOND", "blue": "CIRCLE", "green": "TRIANGLE"}


static func get_guidance(controller: ShiftController) -> Dictionary:
	if controller.phase != ShiftController.Phase.RUNNING:
		return {"message": "Press PLAY to learn the routes.", "focus": "", "needs_action": false}

	var nearest: DeliveryParcel = null
	var nearest_time: float = INF
	for parcel in controller.parcels:
		if not parcel.active or not controller.board.is_junction(parcel.next_node):
			continue
		var remaining: float = (1.0 - parcel.progress) * ShiftController.SEGMENT_SECONDS
		if remaining < nearest_time:
			nearest_time = remaining
			nearest = parcel

	if nearest == null:
		if controller.scheduler.next_index < controller.scheduler.schedule.size():
			var upcoming: String = str(controller.scheduler.schedule[controller.scheduler.next_index])
			return {
				"message": "NEXT: %s (%s). Match its home!" % [upcoming.to_upper(), SYMBOLS.get(upcoming, "?")],
				"focus": "", "needs_action": false
			}
		return {"message": "Final deliveries on their way.", "focus": "", "needs_action": false}

	var junction_id: String = nearest.next_node
	var desired: String = desired_exit(junction_id, nearest.destination, controller.board)
	if not controller.board.is_valid_edge(junction_id, desired):
		# The package already entered an irreversible wrong branch.
		# Never tell a player to tap toward a non-matching destination.
		var correct_branch: String = desired_exit("hub", nearest.destination, controller.board).to_upper()
		return {
			"message": "%s took the wrong branch! Choose HUB to %s next time." % [
				nearest.destination.to_upper(), correct_branch
			],
			"focus": "", "needs_action": false
		}
	var needs_action: bool = controller.board.get_next_node(junction_id) != desired
	var verb: String = "TAP" if needs_action else "READY"
	var message: String = "%s: %s %s to %s" % [
		nearest.destination.to_upper(), verb, junction_id.to_upper(), desired.to_upper()
	]
	return {"message": message, "focus": junction_id, "needs_action": needs_action}


static func desired_exit(junction_id: String, destination: String, board: BoardState = null) -> String:
	# Path-finding advice is read-only: switch state and scoring are untouched.
	var roads: Dictionary = board.edges if board != null else BoardState.EDGES
	if not roads.has(junction_id):
		return ""
	var exits: Array = roads[junction_id]
	for next_id in exits:
		var target_id: String = str(next_id)
		if target_id == destination or LevelCatalog.path_exists(roads, target_id, destination):
			return target_id
	return ""
