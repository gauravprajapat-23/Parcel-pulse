extends SceneTree

# Run with a visible Godot window, not --headless.
# Captures all five READY-stage previews without writing player progress.
const OUT: String = "res://build/phase2c_visual"
const SCENE: PackedScene = preload("res://scenes/game_screen.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Screenshot capture requires a visible renderer (omit --headless).")
		quit(1)
		return
	var path: String = ProjectSettings.globalize_path(OUT)
	if DirAccess.make_dir_recursive_absolute(path) != OK:
		push_error("Could not create screenshot folder: " + path)
		quit(1)
		return
	var window_size: Vector2i = DisplayServer.window_get_size()
	var dims: String = "%dx%d" % [window_size.x, window_size.y]
	for index in range(LevelCatalog.count()):
		var game := SCENE.instantiate() as GameScreen
		if game == null:
			push_error("Unable to instantiate GameScreen for screenshot capture.")
			quit(1)
			return
		game.progress_save_path = "user://phase2c_capture_unused.json"
		root.add_child(game)
		await process_frame
		if not game.controller.select_level(index):
			push_error("Cannot preview level: " + str(index))
			game.queue_free()
			quit(1)
			return
		# Wait for the root viewport to redraw the new stage's roads, UI and
		# city background, otherwise get_image() may capture the old frame.
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		if image == null or image.is_empty():
			push_error("Godot renderer returned an empty screenshot.")
			game.queue_free()
			quit(1)
			return
		var name: String = "stage_%02d_%s.png" % [index + 1, dims]
		var target: String = path.path_join(name)
		var result: Error = image.save_png(target)
		if result != OK:
			push_error("Could not write screenshot: " + target)
			game.queue_free()
			quit(1)
			return
		print("CAPTURED: " + target)
		game.queue_free()
		await process_frame
	print("CAPTURE COMPLETE: %d stage previews at %s" % [LevelCatalog.count(), dims])
	quit(0)
