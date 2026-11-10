extends RefCounted
class_name DeliveryParcel

const MARKERS = {"red": "DIAMOND", "blue": "CIRCLE", "green": "TRIANGLE"}

var parcel_id: int = 0
var destination: String = "red"
var symbol: String = "DIAMOND"
var current_node: String = "depot"
var next_node: String = "hub"
var progress: float = 0.0
var travel_direction: Vector2 = Vector2.UP
var active: bool = true


func _init(id: int = 0, target: String = "red") -> void:
	parcel_id = id
	destination = target
	symbol = str(MARKERS.get(target, "UNKNOWN"))
