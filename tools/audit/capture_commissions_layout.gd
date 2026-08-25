extends SceneTree

## Audit-only original-resolution capture for the commission board.


func _init() -> void:
	call_deferred("run")


func settle(frames: int = 8) -> void:
	for _frame: int in range(frames):
		await process_frame


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	gs.persistence_enabled = false
	gs.reset_game()
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await settle()
	main.language = "ko"
	gs.language = "ko"
	main.show_commissions()
	await settle()
	var image := get_root().get_viewport().get_texture().get_image()
	var path := "res://qa/audio_layout/commissions_ko.png"
	DirAccess.make_dir_recursive_absolute("D:/AI 종합 폴더/Games/유물경매 게임/RELIC_AND_RESERVE_R3/qa/audio_layout")
	var error := image.save_png(path)
	var report := {"saved": error == OK, "path": path, "size": [image.get_width(), image.get_height()], "error": error}
	var file := FileAccess.open("res://qa/R3_AUDIO_LAYOUT_CAPTURE.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify(report))
	main.queue_free()
	await process_frame
	gs.persistence_enabled = true
	quit(0 if error == OK else 1)
