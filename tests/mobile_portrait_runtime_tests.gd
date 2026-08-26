extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("MOBILE_PORTRAIT_QA: " + message)


func _run() -> void:
	# Match the usable browser area of a 390 px wide portrait phone after the
	# browser/status/navigation chrome is excluded. Project stretch is expected
	# to turn this into a tall logical canvas rather than a 1280x720 letterbox.
	DisplayServer.window_set_size(Vector2i(390, 700))
	root.size = Vector2i(390, 700)
	await process_frame

	var packed := load("res://scenes/Main.tscn") as PackedScene
	_check(packed != null, "Main scene must load")
	if packed == null:
		quit(1)
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	for _frame in range(4):
		await process_frame

	var bridge := root.get_node_or_null("MobileWebLayout")
	_check(bridge != null, "MobileWebLayout autoload must be active")
	if bridge == null:
		quit(1)
		return

	var physical := DisplayServer.window_get_size()
	var ui := scene.find_child("R3Interface", true, false) as Control
	_check(ui != null, "R3Interface must exist")
	if ui == null:
		quit(1)
		return

	print("MOBILE_PORTRAIT_QA physical=", physical, " logical_ui=", ui.size)
	_check(bool(bridge.call("is_portrait_layout")), "390x700 must select portrait layout")
	_check(ui.size.x >= 1200.0, "portrait logical width must preserve the 1280 design baseline")
	_check(ui.size.y >= 1800.0, "portrait logical height must expand well beyond 720 instead of letterboxing")
	_check(ui.size.y > ui.size.x * 1.45, "portrait logical canvas must be materially taller than wide")

	# Exercise a normal screen_shell screen, not only the title screen.
	scene.call("show_workshop")
	for _frame in range(4):
		await process_frame

	var header := ui.find_child("Header", true, false) as Control
	var content := ui.find_child("ContentMargin", true, false) as Control
	var navigation := ui.find_child("Navigation", true, false) as Control
	var status := ui.find_child("StatusMessage", true, false) as Control
	_check(header != null, "portrait shell header must exist")
	_check(content != null, "portrait shell content region must exist")
	_check(navigation != null, "portrait shell navigation must exist")
	_check(status != null, "portrait shell status region must exist")

	if header != null:
		_check(header.position.y <= 45.0, "header must sit near the top of the usable viewport")
		_check(header.size.x >= ui.size.x - 100.0, "header must use almost the full portrait width")
	if content != null:
		_check(content.size.x >= ui.size.x - 100.0, "content must use almost the full portrait width")
		_check(content.size.y >= 800.0, "content must consume the formerly empty lower portrait area")
	if status != null and navigation != null:
		_check(status.position.y + status.size.y <= navigation.position.y + 2.0, "status must remain above bottom navigation")
	if navigation != null:
		var bottom_gap := ui.size.y - (navigation.position.y + navigation.size.y)
		print("MOBILE_PORTRAIT_QA nav=", navigation.position, " ", navigation.size, " bottom_gap=", bottom_gap)
		_check(absf(bottom_gap - 42.0) <= 10.0, "3x3 navigation must anchor to the usable bottom edge")
		_check(navigation.size.y >= 430.0, "portrait navigation must use three large touch rows")
		_check(navigation.get_child_count() >= 9, "normal shell must expose all nine navigation actions")
		if navigation.get_child_count() >= 9:
			var first_button := navigation.get_child(0) as Control
			var fourth_button := navigation.get_child(3) as Control
			var last_button := navigation.get_child(8) as Control
			_check(first_button != null and fourth_button != null and last_button != null, "navigation children must remain Controls")
			if first_button != null and fourth_button != null and last_button != null:
				_check(fourth_button.position.y > first_button.position.y + 100.0, "navigation item 4 must begin the second row")
				_check(last_button.position.y > fourth_button.position.y + 100.0, "navigation item 9 must occupy the third row")
				_check(first_button.size.y >= 140.0, "portrait nav touch targets must be substantially taller than desktop")

	if failures.is_empty():
		print("MOBILE_PORTRAIT_RUNTIME_QA: PASS")
		quit(0)
	else:
		print("MOBILE_PORTRAIT_RUNTIME_QA: FAIL count=", failures.size(), " failures=", failures)
		quit(1)
