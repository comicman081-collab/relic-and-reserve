extends SceneTree

## Off-screen 1280x720 MVP capture for the Stage 9 artifact silhouettes.
## This is QA-only: it uses the live autoloads, disables persistence, and
## never opens an editor or creates a Windows/package artifact.

const OUTPUT_DIR := "res://qa/renders"

func _init() -> void:
	call_deferred("capture")

func snap(name: String) -> void:
	await process_frame
	await process_frame
	var image := get_root().get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [OUTPUT_DIR, name])

func capture_case(main: Node, gs: Node, case_id: String, locale: String, output_name: String) -> void:
	gs.persistence_enabled = false
	gs.player_profile = gs.default_player_profile()
	gs.player_profile.highestUnlockedStage = 9
	gs.new_game(9)
	var artifact: Dictionary = gs.begin_case(case_id)
	print("STAGE9_CAPTURE_CASE case=", case_id, " uid=", artifact.get("uniqueId", ""), " spec=", artifact.get("artifactSpecId", ""))
	main.language = locale
	main.selected = artifact
	main.load_artifact(artifact)
	main.show_inspection()
	await snap(output_name.replace("_dossier", "_inspection"))
	main.show_case_dossier(case_id)
	await snap(output_name)

func capture() -> void:
	var gs: Node = get_root().get_node("GameState")
	await process_frame
	gs.persistence_enabled = false
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await capture_case(main, gs, "master_recorder", "en", "stage9_en_recorder_dossier")
	await capture_case(main, gs, "master_recorder", "ko", "stage9_ko_recorder_dossier")
	await capture_case(main, gs, "master_gauge", "en", "stage9_en_signal_lantern_dossier")
	print("STAGE9_MVP_CAPTURES_CREATED")
	main.queue_free()
	gs.persistence_enabled = false
	quit(0)
