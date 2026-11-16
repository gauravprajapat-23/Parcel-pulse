extends GridContainer
class_name ActionBar

signal primary_requested()
signal retry_requested()
signal guide_requested()
signal exit_requested()

@onready var primary_button: ActionButton = $Primary
@onready var retry_button: ActionButton = $Retry
@onready var guide_button: ActionButton = $Guide
@onready var exit_button: ActionButton = $Exit


func _ready() -> void:
	primary_button.configure("PLAY", "play", "gold")
	retry_button.configure("RETRY", "retry", "secondary")
	guide_button.configure("GUIDE ON", "guide", "secondary")
	exit_button.configure("EXIT", "exit", "quiet")
	primary_button.pressed.connect(func() -> void: primary_requested.emit())
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	guide_button.pressed.connect(func() -> void: guide_requested.emit())
	exit_button.pressed.connect(func() -> void: exit_requested.emit())
	apply_phase(ShiftController.Phase.READY)


func apply_phase(phase: int) -> void:
	if not is_node_ready():
		return
	match phase:
		ShiftController.Phase.READY:
			primary_button.configure("PLAY", "play", "gold")
		ShiftController.Phase.RUNNING:
			primary_button.configure("PAUSE", "pause", "gold")
		ShiftController.Phase.PAUSED:
			primary_button.configure("RESUME", "play", "gold")
		ShiftController.Phase.FINISHED:
			primary_button.configure("PLAY", "play", "gold")
	primary_button.disabled = phase == ShiftController.Phase.FINISHED
	retry_button.disabled = phase == ShiftController.Phase.READY
	exit_button.disabled = phase == ShiftController.Phase.READY
	primary_button.queue_redraw()
	retry_button.queue_redraw()
	exit_button.queue_redraw()


func set_guide_enabled(enabled: bool) -> void:
	if not is_node_ready():
		return
	guide_button.configure("GUIDE ON" if enabled else "GUIDE OFF", "guide", "secondary")


func set_button_height(height: float) -> void:
	if not is_node_ready():
		return
	for button in [primary_button, retry_button, guide_button, exit_button]:
		button.custom_minimum_size.y = height
