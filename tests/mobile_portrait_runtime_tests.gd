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


func _inside_global_bounds(control: Control, parent: Control, label: String) -> void:
	var control_rect := control.get_global_rect()
	var parent_rect := parent.get_global_rect()
	_check(control_rect.position.x >= parent_rect.position.x - 1.0, label + " must not start left of R3Interface")
	_check(control_rect.end.x <= parent_rect.end.x + 1.0, label + " must not extend right of R3Interface")
	_check(control_rect.position.y >= parent_rect.position.y - 1.0, label + " must not start above R3Interface")
	_check(control_rect.end.y <= parent_rect.end.y + 1.0, label + " must not extend below R3Interface")


func _center_delta(control: Control, parent: Control) -> Vector2:
	return control.get_global_rect().get_center() - parent.get_global_rect().get_center()


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

	print("MOBILE_PORTRAIT_QA physical=", DisplayServer.window_get_size(), " logical_ui=", ui.size, " ui_global=", ui.get_global_rect())
	_check(bool(bridge.call("is_portrait_layout")), "390x700 must select portrait layout")
	_check(ui.size.x >= 1200.0, "portrait logical width must preserve the 1280 design baseline")
	_check(ui.size.y >= 1800.0, "portrait logical height must expand well beyond 720 instead of letterboxing")
	_check(ui.size.y > ui.size.x * 1.45, "portrait logical canvas must be materially taller than wide")

	var title_card := ui.find_child("TitleCard", true, false) as Control
	var title_menu := ui.find_child("TitleMenu", true, false) as Control
	_check(title_card != null, "portrait title card must exist")
	_check(title_menu != null, "portrait title menu must exist")
	if title_card != null:
		print("MOBILE_PORTRAIT_QA card_local=", Rect2(title_card.position, title_card.size), " card_global=", title_card.get_global_rect(), " min=", title_card.get_combined_minimum_size(), " center_delta=", _center_delta(title_card, ui), " anchors=", Vector4(title_card.anchor_left, title_card.anchor_top, title_card.anchor_right, title_card.anchor_bottom))
		_inside_global_bounds(title_card, ui, "TitleCard")
		var card_center_delta := _center_delta(title_card, ui)
		_check(absf(card_center_delta.x) <= 4.0 and absf(card_center_delta.y) <= 4.0, "TitleCard must be centered inside R3Interface")
		_check(title_card.size.x >= ui.size.x * 0.70, "TitleCard must use a readable portrait width")
	if title_menu != null:
		print("MOBILE_PORTRAIT_QA menu_global=", title_menu.get_global_rect(), " min=", title_menu.get_combined_minimum_size(), " center_delta=", _center_delta(title_menu, ui))
		_inside_global_bounds(title_menu, ui, "TitleMenu")
		_check(absf(_center_delta(title_menu, ui).x) <= 4.0, "TitleMenu must be horizontally centered in R3Interface")
		_check(title_menu.size.x >= ui.size.x * 0.70, "TitleMenu must use a readable portrait width")
		var title_logo := title_menu.find_child("TitleLogoText", true, false) as Label
		_check(title_logo != null, "TitleLogoText must exist")
		if title_logo != null:
			_inside_global_bounds(title_logo, ui, "TitleLogoText")
			var logo_font_size := title_logo.get_theme_font_size("font_size")
			_check(logo_font_size >= 88 and logo_font_size <= 96, "portrait title logo must stay near the readable 2.0x scale")
		for button_name in ["NewGameButton", "ContinueButton", "TitleLanguageButton"]:
			var button := title_menu.find_child(button_name, true, false) as Control
			_check(button != null, button_name + " must exist")
			if button != null:
				_inside_global_bounds(button, ui, button_name)
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
		_inside_global_bounds(header, ui, "Header")
		_check(header.position.y <= 45.0, "header must sit near the top of the usable viewport")
		_check(header.size.x >= ui.size.x - 100.0, "header must use almost the full portrait width")
	if content != null:
		_inside_global_bounds(content, ui, "ContentMargin")
		_check(content.size.x >= ui.size.x - 100.0, "content must use almost the full portrait width")
		_check(content.size.y >= 800.0, "content must consume the formerly empty lower portrait area")
	if status != null:
		_inside_global_bounds(status, ui, "StatusMessage")
	if status != null and navigation != null:
		_check(status.position.y + status.size.y <= navigation.position.y + 2.0, "status must remain above bottom navigation")
	if navigation != null:
		_inside_global_bounds(navigation, ui, "Navigation")
		var bottom_gap := ui.size.y - (navigation.position.y + navigation.size.y)
		print("MOBILE_PORTRAIT_QA nav=", navigation.position, " ", navigation.size, " bottom_gap=", bottom_gap)
		_check(absf(bottom_gap - 34.0) <= 10.0, "3x3 navigation must anchor to the usable bottom edge")
		_check(navigation.size.y >= 450.0, "portrait navigation must use three large touch rows")
		_check(navigation.get_child_count() >= 9, "normal shell must expose all nine navigation actions")
		for child in navigation.get_children():
			if child is Control:
				_inside_global_bounds(child, navigation, "Navigation child " + child.name)
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
