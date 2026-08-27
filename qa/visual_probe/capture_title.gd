extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var gs: Node = get_root().get_node("GameState")
	gs.persistence_enabled = false
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	for _frame in range(8):
		await process_frame
	for locale: String in ["ko", "en"]:
		for scale_value: float in [1.0, 1.16]:
			gs.language = locale
			main.language = locale
			main.ui_text_scale = scale_value
			main.show_title()
			for _frame in range(8):
				await process_frame
			var image: Image = get_root().get_viewport().get_texture().get_image()
			image.save_png("res://qa/visual_probe/title_%s_%s.png" % [locale, "116" if scale_value > 1.0 else "100"])
		main.language = locale
		main.ui_text_scale = 1.16
		main.show_settings()
		for _frame in range(8):
			await process_frame
		var settings_image: Image = get_root().get_viewport().get_texture().get_image()
		settings_image.save_png("res://qa/visual_probe/settings_%s_116.png" % locale)
	var portrait_texture: Texture2D = load("res://assets/portraits/mara_venn_positive.svg")
	if portrait_texture != null:
		var portrait_image := portrait_texture.get_image()
		portrait_image.save_png("res://qa/visual_probe/mara_venn_positive.png")
	main.queue_free()
	await process_frame
	quit(0)
