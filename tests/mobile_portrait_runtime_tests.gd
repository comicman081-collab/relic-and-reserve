extends SceneTree

# Runtime regression gate for the portrait shape reported from Android mobile Web.
# This test intentionally checks visible bounds, not only that the logical canvas
# became taller than 720. A centered-anchor Control can still be completely
# offscreen while the canvas dimensions themselves look correct.
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("MOBILE_PORTRAIT_QA: " + message)


func _inside_horizontal_bounds(control: Control, parent_width: float, label: String) -> void:
	_check(control.position.x >= -1.0, label + " must not start left of the viewport")
	_check(control.position.x + control.size.x <= parent_width + 1.0, label + " must not extend right of the viewport")


func _inside_vertical_bounds(control: Control, parent_height: float, label: String) -> void:
	_check(control.position.y >= -1.0, label + " must not start above the viewport")
	_check(control.position.y + control.size.y <= parent_height + 1.0, label + " must not extend below the viewport")


func _run() -> void:
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
	for _frame in range(8):
		await process_frame

	var bridge := root.get_node_or_null("MobileWebLayout")
	_check(bridge != null, "MobileWebLayout autoload must be active")
	if bridge == null:
		quit(1)
		return

	var ui := scene.find_child("R3Interface", true, false) as Control
	_check(ui != null, "R3Interface must exist")
	if ui == null:
		quit(1)
		return

	print("MOBILE_PORTRAIT_QA physical=", DisplayServer.window_get_size(), " logical_ui=", ui.size)
	_check(bool(bridge.call("is_portrait_layout")), "390x700 must select portrait layout")
	_check(ui.size.x >= 1200.0, "portrait logical width must preserve the 1280 design baseline")
	_check(ui.size.y >= 1800.0, "portrait logical height must expand well beyond 720 instead of letterboxing")
	_check(ui.size.y > ui.size.x * 1.45, "portrait logical canvas must be materially taller than wide")

	var title_menu := ui.find_child("TitleMenu", true, false) as Control
	_check(title_menu != null, "portrait title menu must exist")
	if title_menu != null:
		print("MOBILE_PORTRAIT_QA title pos=", title_menu.position, " size=", title_menu.size, " min=", title_menu.get_combined_minimum_size(), " anchors=", Vector4(title_menu.anchor_left, title_menu.anchor_top, title_menu.anchor_right, title_menu.anchor_bottom), " offsets=", Vector4(title_menu.offset_left, title_menu.offset_top, title_menu.offset_right, title_menu.offset_bottom))
		_inside_horizontal_bounds(title_menu, ui.size.x, "TitleMenu")
		_inside_vertical_bounds(title_menu, ui.size.y, "TitleMenu")
		var title_center_x := title_menu.position.x + title_menu.size.x * 0.5
		_check(absf(title_center_x - ui.size.x * 0.5) <= 4.0, "TitleMenu must be horizontally centered in the actual viewport")
		_check(title_menu.size.x >= ui.size.x * 0.70, "TitleMenu must use a readable portrait width")
		for button_name in ["NewGameButton", "ContinueButton", "TitleLanguageButton"]:
			var button := title_menu.find_child(button_name, true, false) as Control
			_check(button != null, button_name + " must exist")
			if button != null:
				var absolute_left := title_menu.position.x + button.position.x
				var absolute_right := absolute_left + button.size.x
				_check(absolute_left >= -1.0, button_name + " must not be clipped on the left")
				_check(absolute_right <= ui.size.x + 1.0, button_name + " must not be clipped on the right")
				_check(button.size.y >= 140.0, button_name + " must have a large portrait touch target")

	var cameras := scene.find_children("*", "Camera3D", true, false)
	_check(not cameras.is_empty(), "portrait scene camera must exist")
	if not cameras.is_empty():
		var scene_camera := cameras[0] as Camera3D
		_check(scene_camera != null and scene_camera.keep_aspect == Camera3D.KEEP_WIDTH, "portrait camera must preserve the authored horizontal composition")

	scene.call("show_workshop")
	for _frame in range(8):
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
		_inside_horizontal_bounds(header, ui.size.x, "Header")
		_inside_vertical_bounds(header, ui.size.y, "Header")
		_check(header.position.y <= 45.0, "header must sit near the top of the usable viewport")
		_check(header.size.x >= ui.size.x - 100.0, "header must use almost the full portrait width")
	if content != null:
		_inside_horizontal_bounds(content, ui.size.x, "ContentMargin")
		_inside_vertical_bounds(content, ui.size.y, "ContentMargin")
		_check(content.size.x >= ui.size.x - 100.0, "content must use almost the full portrait width")
		_check(content.size.y >= 800.0, "content must consume the formerly empty lower portrait area")
	if status != null:
		_inside_horizontal_bounds(status, ui.size.x, "StatusMessage")
		_inside_vertical_bounds(status, ui.size.y, "StatusMessage")
	if status != null and navigation != null:
		_check(status.position.y + status.size.y <= navigation.position.y + 2.0, "status must remain above bottom navigation")
	if navigation != null:
		_inside_horizontal_bounds(navigation, ui.size.x, "Navigation")
		_inside_vertical_bounds(navigation, ui.size.y, "Navigation")
		var bottom_gap := ui.size.y - (navigation.position.y + navigation.size.y)
		print("MOBILE_PORTRAIT_QA nav=", navigation.position, " ", navigation.size, " bottom_gap=", bottom_gap)
		_check(absf(bottom_gap - 34.0) <= 10.0, "3x3 navigation must anchor to the usable bottom edge")
		_check(navigation.size.y >= 450.0, "portrait navigation must use three large touch rows")
		_check(navigation.get_child_count() >= 9, "normal shell must expose all nine navigation actions")
		for child in navigation.get_children():
			if child is Control:
				_inside_horizontal_bounds(child, navigation.size.x, "Navigation child " + child.name)
				_inside_vertical_bounds(child, navigation.size.y, "Navigation child " + child.name)
		if navigation.get_child_count() >= 9:
			var first_button := navigation.get_child(0) as Control
			var fourth_button := navigation.get_child(3) as Control
			var last_button := navigation.get_child(8) as Control
			_check(first_button != null and fourth_button != null and last_button != null, "navigation children must remain Controls")
			if first_button != null and fourth_button != null and last_button != null:
				_check(fourth_button.position.y > first_button.position.y + 100.0, "navigation item 4 must begin the second row")
				_check(last_button.position.y > fourth_button.position.y + 100.0, "navigation item 9 must occupy the third row")
				_check(first_button.size.y >= 150.0, "portrait nav touch targets must be substantially taller than desktop")

	if failures.is_empty():
		print("MOBILE_PORTRAIT_RUNTIME_QA: PASS")
		quit(0)
	else:
		print("MOBILE_PORTRAIT_RUNTIME_QA: FAIL count=", failures.size(), " failures=", failures)
		quit(1)
