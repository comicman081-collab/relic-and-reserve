extends SceneTree

## Off-screen 1280x720 capture for the two fresh Stage 10 artifact silhouettes.
## QA-only; persistence is disabled and no Windows/package artifact is built.

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
	gs.player_profile.highestUnlockedStage = 10
	gs.new_game(10)
	var artifact: Dictionary = gs.begin_case(case_id)
	print("STAGE10_CAPTURE_CASE case=", case_id, " uid=", artifact.get("uniqueId", ""), " spec=", artifact.get("artifactSpecId", ""), " story=", artifact.get("storyArtifactId", ""))
	main.language = locale
	main.selected = artifact
	main.load_artifact(artifact)
	main.show_inspection()
	await snap(output_name)

func capture() -> void:
	var gs: Node = get_root().get_node("GameState")
	await process_frame
	gs.persistence_enabled = false
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	await capture_case(main, gs, "master_camera", "en", "stage10_en_spectroscope_inspection")
	await capture_case(main, gs, "master_mechanism", "en", "stage10_en_regulator_inspection")
	await capture_case(main, gs, "master_mechanism", "ko", "stage10_ko_regulator_inspection")
	print("STAGE10_MVP_CAPTURES_CREATED")
	main.queue_free()
	gs.persistence_enabled = false
	quit(0)
