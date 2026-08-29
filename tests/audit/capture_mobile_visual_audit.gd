extends SceneTree

# Audit-only real-framebuffer capture. It exercises the production responsive
# controls at a common 390 x 700 portrait viewport without writing saves or
# changing any authoritative gameplay state.

const VIEWPORT_SIZE := Vector2i(390, 700)
const OUTPUT_DIR := "res://qa/mobile_visual_audit"
const CASE_ID := "prologue_clock"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _capture(label: String) -> void:
	await _wait_frames(8)
	var frame := root.get_viewport().get_texture().get_image()
	var output_path := "%s/%s_390x700.png" % [OUTPUT_DIR, label]
	var result := frame.save_png(output_path)
	if result != OK:
		failures.append("capture_failed:%s:%s" % [label, result])
		push_error("MOBILE_VISUAL_AUDIT: failed to save %s" % output_path)


func _print_geometry(main: Node, names: Array[String]) -> void:
	for node_name: String in names:
		var control := main.find_child(node_name, true, false) as Control
		if control != null:
			print("MOBILE_VISUAL_GEOMETRY %s rect=%s min=%s visible=%s" % [node_name, control.get_global_rect(), control.get_combined_minimum_size(), control.is_visible_in_tree()])
			if node_name == "Navigation":
				for child: Node in control.get_children():
					if child is Control:
						var nav_child := child as Control
						var nav_text := (nav_child as Button).text if nav_child is Button else ""
						print("MOBILE_VISUAL_NAV %s text=%s rect=%s visible=%s modulate=%s" % [nav_child.name, nav_text, nav_child.get_global_rect(), nav_child.is_visible_in_tree(), nav_child.modulate])


func _skip_tutorial_overlay(main: Node, game_state: Node) -> void:
	var director := root.get_node_or_null("TutorialSpotlightDirector")
	if director != null and director.has_method("_remove_overlay"):
		director.call("_remove_overlay")
	var result: Variant = game_state.call("skip_tutorial_guidance")
	if result is Dictionary and bool((result as Dictionary).get("ok", false)):
		if main.has_method("refresh_current_screen"):
			main.call("refresh_current_screen")
	await _wait_frames(6)


func _run() -> void:
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	await _wait_frames(3)

	var packed := load("res://scenes/Main.tscn") as PackedScene
	if packed == null:
		failures.append("main_scene_missing")
		quit(1)
		return
	var main := packed.instantiate()
	root.add_child(main)
	current_scene = main
	await _wait_frames(12)

	var game_state := root.get_node_or_null("GameState")
	if game_state == null:
		failures.append("game_state_missing")
		main.free()
		quit(1)
		return
	game_state.set("persistence_enabled", false)
	game_state.call("reset_game")
	game_state.set("player_profile", game_state.call("default_player_profile"))
	game_state.set("language", "ko")
	main.set("language", "ko")
	main.show_title()
	await _capture("01_title_ko")

	var new_game: Dictionary = game_state.call("new_game", 1)
	if not bool(new_game.get("ok", false)):
		failures.append("new_game_failed")
	else:
		game_state.call("begin_case", CASE_ID)
		main.show_case_dossier(CASE_ID)
		await _wait_frames(6)
		_print_geometry(main, ["TutorialIntroPanel", "TutorialIntroTitle", "TutorialIntroScroll", "TutorialIntroBody", "TutorialIntroNext", "TutorialExpertSkip"])
		print("MOBILE_VISUAL_OVERLAY_COUNT ", main.find_children("TutorialSpotlightOverlay", "Control", true, false).size())
		await _capture("02_tutorial_intro_ko")
		await _skip_tutorial_overlay(main, game_state)
		main.show_case_dossier(CASE_ID)
		await _capture("03_case_dossier_ko")
		main.show_workshop()
		await _wait_frames(4)
		_print_geometry(main, ["Header", "ContentMargin", "Navigation", "StatusMessage", "TutorialReplayButton"])
		await _capture("04_workshop_ko")
		main.show_market()
		await _wait_frames(4)
		_print_geometry(main, ["Header", "ContentMargin", "Navigation", "StatusMessage"])
		await _capture("05_market_ko")
		main.show_inventory()
		await _wait_frames(4)
		_print_geometry(main, ["Header", "ContentMargin", "Navigation", "StatusMessage"])
		await _capture("06_inventory_ko")
		main.show_upgrades()
		await _capture("07_upgrades_ko")
		main.show_settings()
		await _capture("08_settings_ko")

	if main.has_node("BGMManager"):
		var bgm := main.get_node("BGMManager")
		if bgm is AudioStreamPlayer:
			bgm.stop()
			bgm.stream = null
	main.free()
	await process_frame
	print("MOBILE_VISUAL_AUDIT: %s" % ("PASS" if failures.is_empty() else "FAIL %s" % failures))
	quit(0 if failures.is_empty() else 1)
