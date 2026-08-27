extends Node

# Mobile portrait presentation bridge.
# The gameplay UI is authored against a 1280x720 landscape baseline. On a
# portrait Web viewport Godot's canvas_items + expand stretch exposes extra
# vertical logical space. This bridge fills that space without changing any
# gameplay/save authority and restores the authored geometry in landscape.

const PORTRAIT_LABEL_SCALE := 2.40
const PORTRAIT_BUTTON_FONT_SCALE := 3.00
const PORTRAIT_ICON_SCALE := 1.30
const PORTRAIT_SIDE_PAD := 36.0
const PORTRAIT_TOP_PAD := 28.0
const PORTRAIT_BOTTOM_PAD := 34.0
const PORTRAIT_HEADER_HEIGHT := 190.0
const PORTRAIT_CONTENT_TOP := 238.0
const PORTRAIT_STATUS_HEIGHT := 82.0
const PORTRAIT_NAV_COLUMNS := 3
const PORTRAIT_NAV_BUTTON_HEIGHT := 156.0
const PORTRAIT_NAV_GAP := 12.0

const META_BASE_FONT := &"mobile_base_font_size"
const META_BASE_MIN := &"mobile_base_minimum_size"
const META_BASE_ICON_MAX := &"mobile_base_icon_max_width"
const META_BASE_COLUMNS := &"mobile_base_grid_columns"
const META_BASE_POSITION := &"mobile_base_position"
const META_BASE_SIZE := &"mobile_base_size"
const META_BASE_ANCHORS := &"mobile_base_anchors"
const META_BASE_SEPARATION := &"mobile_base_separation"
const META_CAMERA_KEEP_ASPECT := &"mobile_base_camera_keep_aspect"

var interface: Control
var layout_queued := false
var audio_unlocked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	get_tree().root.size_changed.connect(_on_root_size_changed)
	_discover_interface.call_deferred()


func _discover_interface() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var candidate := scene.find_child("R3Interface", true, false)
	if candidate is Control:
		_attach_interface(candidate)


func _on_node_added(node: Node) -> void:
	if node is Control and node.name == "R3Interface":
		_attach_interface(node)
		return
	if interface != null and is_instance_valid(interface) and interface.is_ancestor_of(node):
		_queue_layout()


func _attach_interface(candidate: Control) -> void:
	if interface != null and is_instance_valid(interface) and interface != candidate:
		if interface.resized.is_connected(_on_interface_resized):
			interface.resized.disconnect(_on_interface_resized)
	interface = candidate
	interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not interface.resized.is_connected(_on_interface_resized):
		interface.resized.connect(_on_interface_resized)
	_queue_layout()


func _on_root_size_changed() -> void:
	if interface != null and is_instance_valid(interface):
		interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_queue_layout()


func _on_interface_resized() -> void:
	_queue_layout()


func _queue_layout() -> void:
	if layout_queued:
		return
	layout_queued = true
	_apply_layout_deferred.call_deferred()


func _apply_layout_deferred() -> void:
	await get_tree().process_frame
	layout_queued = false
	if interface == null or not is_instance_valid(interface) or not interface.is_inside_tree():
		_discover_interface()
		return
	interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var portrait := is_portrait_layout()
	_apply_responsive_style(interface, portrait)
	_layout_title_menu(portrait)
	_layout_screen_shell(portrait)
	_layout_camera_for_portrait(portrait)


func is_portrait_layout() -> bool:
	var physical_size := DisplayServer.window_get_size()
	if physical_size.x > 0 and physical_size.y > 0:
		return float(physical_size.y) > float(physical_size.x) * 1.08
	if interface == null or not is_instance_valid(interface):
		return false
	return interface.size.y > interface.size.x * 1.08


func _input(event: InputEvent) -> void:
	if audio_unlocked:
		return
	var user_gesture := false
	if event is InputEventScreenTouch:
		user_gesture = event.pressed
	elif event is InputEventMouseButton:
		user_gesture = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventKey:
		user_gesture = event.pressed
	if user_gesture:
		audio_unlocked = true
		_resume_mobile_web_audio()


func _resume_mobile_web_audio() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var bgm_node := scene.find_child("BGMManager", true, false)
	if bgm_node is AudioStreamPlayer and bgm_node.stream != null and not bgm_node.playing:
		bgm_node.play()


func _apply_responsive_style(root: Control, portrait: bool) -> void:
	_style_control(root, portrait)
	for node in root.find_children("*", "Control", true, false):
		if node is Control:
			_style_control(node, portrait)


func _style_control(control: Control, portrait: bool) -> void:
	if control is Label:
		if not control.has_meta(META_BASE_FONT):
			control.set_meta(META_BASE_FONT, control.get_theme_font_size("font_size"))
		var base_label_font := int(control.get_meta(META_BASE_FONT))
		control.add_theme_font_size_override("font_size", maxi(1, roundi(float(base_label_font) * (PORTRAIT_LABEL_SCALE if portrait else 1.0))))
	elif control is Button:
		if not control.has_meta(META_BASE_FONT):
			control.set_meta(META_BASE_FONT, control.get_theme_font_size("font_size"))
		if not control.has_meta(META_BASE_MIN):
			control.set_meta(META_BASE_MIN, control.custom_minimum_size)
		var base_button_font := int(control.get_meta(META_BASE_FONT))
		var base_button_min: Vector2 = control.get_meta(META_BASE_MIN)
		control.add_theme_font_size_override("font_size", maxi(1, roundi(float(base_button_font) * (PORTRAIT_BUTTON_FONT_SCALE if portrait else 1.0))))
		if portrait:
			control.custom_minimum_size = Vector2(base_button_min.x, maxf(base_button_min.y * 1.8, 144.0))
		else:
			control.custom_minimum_size = base_button_min
		if control.has_theme_constant_override("icon_max_width") or control.has_meta(META_BASE_ICON_MAX):
			if not control.has_meta(META_BASE_ICON_MAX):
				control.set_meta(META_BASE_ICON_MAX, control.get_theme_constant("icon_max_width"))
			var base_icon_max := int(control.get_meta(META_BASE_ICON_MAX))
			control.add_theme_constant_override("icon_max_width", maxi(1, roundi(float(base_icon_max) * (1.60 if portrait else 1.0))))
	elif control is TextureRect:
		if not control.has_meta(META_BASE_MIN):
			control.set_meta(META_BASE_MIN, control.custom_minimum_size)
		var base_texture_min: Vector2 = control.get_meta(META_BASE_MIN)
		control.custom_minimum_size = base_texture_min * (PORTRAIT_ICON_SCALE if portrait else 1.0)

	if control is GridContainer:
		if not control.has_meta(META_BASE_COLUMNS):
			control.set_meta(META_BASE_COLUMNS, control.columns)
		var base_columns := int(control.get_meta(META_BASE_COLUMNS))
		control.columns = _portrait_grid_columns(control, base_columns) if portrait else base_columns


func _portrait_grid_columns(grid: GridContainer, base_columns: int) -> int:
	if base_columns <= 1:
		return 1
	if base_columns >= 3:
		return 2
	return base_columns


func _remember_rect(control: Control) -> void:
	if not control.has_meta(META_BASE_POSITION):
		control.set_meta(META_BASE_POSITION, control.position)
	if not control.has_meta(META_BASE_SIZE):
		control.set_meta(META_BASE_SIZE, control.size)


func _remember_anchors(control: Control) -> void:
	if not control.has_meta(META_BASE_ANCHORS):
		control.set_meta(META_BASE_ANCHORS, Vector4(control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom))


func _restore_rect(control: Control) -> void:
	if control.has_meta(META_BASE_POSITION):
		var base_position: Vector2 = control.get_meta(META_BASE_POSITION)
		control.position = base_position
	if control.has_meta(META_BASE_SIZE):
		var base_size: Vector2 = control.get_meta(META_BASE_SIZE)
		control.size = base_size


func _restore_anchors(control: Control) -> void:
	if not control.has_meta(META_BASE_ANCHORS):
		return
	var anchors: Vector4 = control.get_meta(META_BASE_ANCHORS)
	control.anchor_left = anchors.x
	control.anchor_top = anchors.y
	control.anchor_right = anchors.z
	control.anchor_bottom = anchors.w


func _remember_separation(container: BoxContainer) -> void:
	if not container.has_meta(META_BASE_SEPARATION):
		container.set_meta(META_BASE_SEPARATION, container.get_theme_constant("separation"))


func _restore_separation(container: BoxContainer) -> void:
	if container.has_meta(META_BASE_SEPARATION):
		container.add_theme_constant_override("separation", int(container.get_meta(META_BASE_SEPARATION)))


func _layout_title_menu(portrait: bool) -> void:
	if interface == null:
		return
	var candidate := interface.find_child("TitleMenu", true, false)
	if not candidate is VBoxContainer:
		return
	var menu := candidate as VBoxContainer
	_remember_rect(menu)
	_remember_anchors(menu)
	_remember_separation(menu)
	if not portrait:
		_restore_anchors(menu)
		_restore_rect(menu)
		_restore_separation(menu)
		return

	# Portrait title geometry is absolute. Detach it from its authored center
	# anchors first; otherwise changing the tall parent size can translate the
	# menu again after we place it and recreate the off-screen regression.
	menu.anchor_left = 0.0
	menu.anchor_top = 0.0
	menu.anchor_right = 0.0
	menu.anchor_bottom = 0.0

	var menu_width := maxf(280.0, minf(interface.size.x - 96.0, 1040.0))
	var menu_height := minf(790.0, maxf(620.0, interface.size.y * 0.34))
	var menu_x := maxf(24.0, (interface.size.x - menu_width) * 0.5)
	var menu_y := maxf(48.0, minf(interface.size.y * 0.10, 260.0))
	menu.position = Vector2(menu_x, menu_y)
	menu.size = Vector2(menu_width, menu_height)
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 30)


func _layout_screen_shell(portrait: bool) -> void:
	if interface == null:
		return
	var header := interface.find_child("Header", true, false)
	var margin := interface.find_child("ContentMargin", true, false)
	var navigation := interface.find_child("Navigation", true, false)
	var status_message := interface.find_child("StatusMessage", true, false)
	if not (header is Control and margin is Control and navigation is Control and status_message is Control):
		return

	_remember_rect(header)
	_remember_rect(margin)
	_remember_rect(navigation)
	_remember_rect(status_message)
	for child in header.get_children():
		if child is Control:
			_remember_rect(child)
	for child in navigation.get_children():
		if child is Control:
			_remember_rect(child)

	if not portrait:
		_restore_rect(header)
		_restore_rect(margin)
		_restore_rect(navigation)
		_restore_rect(status_message)
		for child in header.get_children():
			if child is Control:
				_restore_rect(child)
		for child in navigation.get_children():
			if child is Control:
				_restore_rect(child)
		return

	var available_width := maxf(280.0, interface.size.x - PORTRAIT_SIDE_PAD * 2.0)
	var available_height := maxf(900.0, interface.size.y)

	header.position = Vector2(PORTRAIT_SIDE_PAD, PORTRAIT_TOP_PAD)
	header.size = Vector2(available_width, PORTRAIT_HEADER_HEIGHT)
	_layout_portrait_header(header)

	var nav_count := navigation.get_child_count()
	var nav_rows := maxi(1, ceili(float(nav_count) / float(PORTRAIT_NAV_COLUMNS)))
	var nav_height := float(nav_rows) * PORTRAIT_NAV_BUTTON_HEIGHT + float(maxi(0, nav_rows - 1)) * PORTRAIT_NAV_GAP
	var nav_y := available_height - PORTRAIT_BOTTOM_PAD - nav_height
	var status_y := nav_y - PORTRAIT_STATUS_HEIGHT - 12.0

	navigation.position = Vector2(PORTRAIT_SIDE_PAD, nav_y)
	navigation.size = Vector2(available_width, nav_height)
	_layout_portrait_navigation(navigation)

	status_message.position = Vector2(PORTRAIT_SIDE_PAD + 4.0, status_y)
	status_message.size = Vector2(available_width - 8.0, PORTRAIT_STATUS_HEIGHT)

	var content_bottom := status_y - 18.0
	margin.position = Vector2(PORTRAIT_SIDE_PAD, PORTRAIT_CONTENT_TOP)
	margin.size = Vector2(available_width, maxf(360.0, content_bottom - PORTRAIT_CONTENT_TOP))


func _layout_portrait_header(header: Control) -> void:
	var labels: Array = []
	var skip_button: Control
	for child in header.get_children():
		if child is Label:
			labels.append(child)
		elif child is BaseButton and child.name == "TutorialSkipButton":
			skip_button = child
	if labels.size() > 0:
		var title_label := labels[0] as Label
		title_label.position = Vector2.ZERO
		title_label.size = Vector2(header.size.x, 88.0)
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if labels.size() > 1:
		var stats_label := labels[1] as Label
		var skip_width := 330.0 if skip_button != null else 0.0
		stats_label.position = Vector2(0.0, 98.0)
		stats_label.size = Vector2(maxf(250.0, header.size.x - skip_width - (18.0 if skip_button != null else 0.0)), 78.0)
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if skip_button != null:
		skip_button.position = Vector2(header.size.x - 330.0, 98.0)
		skip_button.size = Vector2(330.0, 78.0)


func _layout_portrait_navigation(navigation: Control) -> void:
	var button_width := (navigation.size.x - PORTRAIT_NAV_GAP * float(PORTRAIT_NAV_COLUMNS - 1)) / float(PORTRAIT_NAV_COLUMNS)
	for button_index in range(navigation.get_child_count()):
		var child := navigation.get_child(button_index)
		if not child is Control:
			continue
		var column := button_index % PORTRAIT_NAV_COLUMNS
		var row := floori(float(button_index) / float(PORTRAIT_NAV_COLUMNS))
		child.position = Vector2(
			float(column) * (button_width + PORTRAIT_NAV_GAP),
			float(row) * (PORTRAIT_NAV_BUTTON_HEIGHT + PORTRAIT_NAV_GAP)
		)
		child.size = Vector2(button_width, PORTRAIT_NAV_BUTTON_HEIGHT)


func _layout_camera_for_portrait(portrait: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var cameras := scene.find_children("*", "Camera3D", true, false)
	if cameras.is_empty():
		return
	var scene_camera := cameras[0] as Camera3D
	if scene_camera == null:
		return
	if not scene_camera.has_meta(META_CAMERA_KEEP_ASPECT):
		scene_camera.set_meta(META_CAMERA_KEEP_ASPECT, int(scene_camera.keep_aspect))
	if portrait:
		scene_camera.keep_aspect = Camera3D.KEEP_WIDTH
	else:
		scene_camera.keep_aspect = int(scene_camera.get_meta(META_CAMERA_KEEP_ASPECT))
