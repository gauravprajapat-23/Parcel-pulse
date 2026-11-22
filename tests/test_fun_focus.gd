extends SceneTree

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(description: String, ok: bool) -> void:
	if ok:
		passed += 1
		print("PASS ", description)
	else:
		failed += 1
		push_error("FAIL " + description)

func _run() -> void:
	var c := ShiftController.new()
	_check("boost cannot start before a shift", not c.activate_focus())
	c.start_shift()
	c.advance(0.01) # Start the scheduler before measuring boosted time.
	_check("no initial focus", c.focus_charges == 0 and not c.activate_focus())
	for n in range(3):
		c._register_delivery(DeliveryParcel.new(n + 1, "red"), true)
	_check("three deliveries create one charge", c.streak == 3 and c.focus_charges == 1)
	_check("three deliveries create bonus", c.score == 325 and c.last_delivery_points == 125)
	_check("focus can activate", c.activate_focus() and c.focus_remaining == ShiftController.FOCUS_SECONDS)
	_check("focus cannot stack", not c.activate_focus())
	var before: float = c.scheduler.time_to_next
	c.advance(1.0)
	_check("focus countdown uses real seconds", is_equal_approx(c.focus_remaining, 4.0))
	_check("focus simulation clock slows", is_equal_approx(c.scheduler.time_to_next, before - ShiftController.FOCUS_SPEED))
	c.set_paused(true)
	var frozen: float = c.focus_remaining
	c.advance(3.0)
	_check("pause freezes focus time", is_equal_approx(c.focus_remaining, frozen) and not c.activate_focus())
	c.set_paused(false)
	c.advance(4.0)
	_check("focus expires", c.focus_remaining == 0.0)
	c._register_delivery(DeliveryParcel.new(4, "red"), false)
	_check("mistake resets streak not earned points", c.streak == 0 and c.score == 325)
	for n in range(6):
		c._register_delivery(DeliveryParcel.new(n + 10, "red"), true)
	_check("charges capped at two", c.focus_charges == 2)
	_check("bonus capped", c.last_delivery_points == 200)
	_check("best streak tracked", c.best_streak == 6)
	c.restart_shift()
	_check("restart resets powers and combo", c.focus_remaining == 0.0 and c.focus_charges == 0 and c.streak == 0 and c.best_streak == 0)
	print("Parcel Pulse FUN-01: %d passed, %d failed." % [passed, failed])
	quit(1 if failed > 0 else 0)
