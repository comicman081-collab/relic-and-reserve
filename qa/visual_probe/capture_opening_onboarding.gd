extends SceneTree

# Audit-only real-framebuffer capture for the responsive Web onboarding.


func _initialize() -> void:
	_capture.call_deferred()


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	await process_frame
	var gs := root.get_node("GameState")
	var opening := root.get_node("OpeningNarrationDirector")
	gs.set("persistence_enabled", false)
	gs.call("reset_game")
	gs.set("player_profile", gs.call("default_player_profile"))
	gs.set("language", "ko")
	opening.set("force_enabled_for_test", true)
	opening.set("session_completed", false)
	opening.set("active", false)

	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _wait_frames(10)
	gs.call("new_game", 1)
	main.call("show_campaign")
	await _wait_frames(14)

	for page in [0, 3]:
		opening.set("active", true)
		opening.set("page_index", page)
		opening.call("_show_page")
		await _wait_frames(6)
		var frame := root.get_viewport().get_texture().get_image()
		var suffix := "story_ko" if page == 0 else "tabs_ko"
		var error := frame.save_png("res://qa/visual_probe/opening_%s_1280x720.png" % suffix)
		if error != OK:
			push_error("Opening onboarding capture failed: %s" % error)
			quit(1)
			return

	opening.call("_remove_overlay")
	opening.set("active", false)
	main.queue_free()
	await process_frame
	quit(0)
