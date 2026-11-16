extends HBoxContainer
class_name HudPanel

@onready var deliveries_card: StatCard = $Deliveries
@onready var score_card: StatCard = $Score
@onready var lives_card: StatCard = $Lives


func _ready() -> void:
	deliveries_card.configure("Deliveries", "◆", ParcelTheme.GOLD)
	score_card.configure("Score", "★", ParcelTheme.CYAN)
	lives_card.configure("Tries left", "♥", ParcelTheme.RED)
	update_stats(0, 0, 0)


func update_stats(delivered: int, score: int, mistakes: int) -> void:
	if not is_node_ready():
		return
	deliveries_card.set_value("%d/%d" % [delivered, ShiftController.REQUIRED_DELIVERIES])
	score_card.set_value(str(score))
	lives_card.set_value(str(maxi(0, ShiftController.MAX_MISTAKES - mistakes)))
