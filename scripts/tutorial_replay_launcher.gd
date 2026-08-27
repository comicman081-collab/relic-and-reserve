extends Node

# Adds an explicit, always-available Help / Tutorial Replay button to the Workshop.
# The button resets tutorial guidance only; campaign progress, money, inventory,
# RNG, stage clears, and other gameplay authority are left untouched.

const BUTTON_NAME := "TutorialReplayButton"

var interface: Control
var force_enabled_for_test := false
var queued := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_discover.call_deferred()


func _process(_delta: float) -> void:
	if not _feature_enabled():
		return
	if interface == null or not is_instance_valid(interface):
		_discover()
		return
	_ensure_replay_button()


func _feature_enabled() -> bool:
	return force_enabled_for_test or OS.has_feature("web")


func _discover() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var candidate := scene.find_child("R3Interface", true, false)
	if candidate is Control:
		interface = candidate
		_queue_refresh()


func _on_node_added(node: Node) -> void:
	if node is Control and node.name == "R3Interface":
		interface = node
		_queue_refresh()
		return
	if interface != null and is_instance_valid(interface) and interface.is_ancestor_of(node):
		if node.name == "ScreenContent":
			_queue_refresh()


func _queue_refresh() -> void:
	if queued:
		return
	queued = true
	_refresh_deferred.call_deferred()


func _refresh_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	queued = false
	_ensure_replay_button()


func _screen_name() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	var value: Variant = scene.get("screen")
	return "" if value == null else String(value)


func _ensure_replay_button() -> void:
	if interface == null or not is_instance_valid(interface):
		return
	if _screen_name() != "workshop":
		return
	var content := interface.find_child("ScreenContent", true, false) as VBoxContainer
	if content == null:
		return
	var existing := content.find_child(BUTTON_NAME, false, false) as Button
	if existing != null:
		_apply_button_copy(existing)
		return

	var button := Button.new()
	button.name = BUTTON_NAME
	button.custom_minimum_size = Vector2(0.0, 92.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20)
	button.tooltip_text = _copy(
		"Replay the opening, menu explanations and hands-on tutorial without resetting game progress.",
		"게임 진행은 유지한 채 오프닝, 메뉴 설명과 실전 튜토리얼을 다시 봅니다."
	)
	button.pressed.connect(_on_replay_pressed)
	_apply_button_copy(button)
	content.add_child(button)
	# Keep Help near the top of the Workshop instead of burying it below long status text.
	content.move_child(button, mini(2, content.get_child_count() - 1))


func _apply_button_copy(button: Button) -> void:
	button.text = _copy(
		"HELP · REPLAY TUTORIAL\nOpening + menu guide + hands-on help",
		"도움말 · 튜토리얼 다시 보기\n오프닝 + 메뉴 설명 + 실전 안내"
	)


func _copy(en: String, ko: String) -> String:
	return ko if String(GameState.language) == "ko" else en


func _on_replay_pressed() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("play_sfx"):
		scene.call("play_sfx", "ui_click")

	var button := interface.find_child(BUTTON_NAME, true, false) as Button if interface != null else null
	if GameState.gameplay_mutation_locked():
		if button != null:
			button.text = _copy(
				"Finish the pending auction first, then replay Help.",
				"진행 중인 경매를 먼저 확정한 뒤 도움말을 다시 볼 수 있습니다."
			)
		return

	# This function is deliberately limited to tutorial guidance state.
	# It preserves the current campaign/save and only clears completed guide steps.
	GameState.reset_tutorial_guidance()

	var opening := get_tree().root.get_node_or_null("OpeningNarrationDirector")
	if opening == null:
		if button != null:
			button.text = _copy("Help system unavailable.", "도움말 시스템을 불러오지 못했습니다.")
		return

	opening.set("session_completed", false)
	opening.set("completed_tutorial_cycle", false)
	opening.set("last_tutorial_visible", false)
	opening.set("active", false)
	opening.set("page_index", 0)
	opening.set("interface", interface)
	opening.call("_start_onboarding")
