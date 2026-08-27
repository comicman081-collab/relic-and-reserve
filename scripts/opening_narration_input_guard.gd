extends Node

# Prevents one physical mobile tap from advancing two onboarding pages.
# Some Web/mobile browser stacks deliver a touch event and a synthesized mouse
# event for the same gesture. This guard replaces the director's raw dim handler,
# advances once, suppresses the synthetic mouse follow-up, and guarantees that
# the final page closes without requiring the expert-skip button.

const DIM_NAME := "OpeningNarrationDim"
const OVERLAY_NAME := "OpeningNarrationOverlay"
const SYNTHETIC_MOUSE_SUPPRESS_MS := 700

var force_enabled_for_test := false
var suppress_mouse_until_ms := 0
var pending_advance := false
var queued := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_queue_configure()


func _feature_enabled() -> bool:
	return force_enabled_for_test or OS.has_feature("web")


func _on_node_added(node: Node) -> void:
	if node is Control and node.name == DIM_NAME:
		_queue_configure()


func _queue_configure() -> void:
	if queued:
		return
	queued = true
	_configure_deferred.call_deferred()


func _configure_deferred() -> void:
	await get_tree().process_frame
	queued = false
	_configure_current_dim()


func _configure_current_dim() -> void:
	if not _feature_enabled():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var interface := scene.find_child("R3Interface", true, false) as Control
	if interface == null:
		return
	var dim := interface.find_child(DIM_NAME, true, false) as Control
	if dim == null:
		return
	var director := get_tree().root.get_node_or_null("OpeningNarrationDirector")
	if director == null:
		return
	var original := Callable(director, "_on_advance_input")
	if dim.gui_input.is_connected(original):
		dim.gui_input.disconnect(original)
	var guarded := Callable(self, "_on_dim_gui_input")
	if not dim.gui_input.is_connected(guarded):
		dim.gui_input.connect(guarded)


func _on_dim_gui_input(event: InputEvent) -> void:
	if not _feature_enabled():
		return
	var now := Time.get_ticks_msec()
	if event is InputEventScreenTouch and event.pressed:
		# Mobile Web can synthesize a mouse click after this touch. Suppress only
		# that mouse follow-up; a subsequent real ScreenTouch may advance normally.
		suppress_mouse_until_ms = now + SYNTHETIC_MOUSE_SUPPRESS_MS
		_request_advance()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if now <= suppress_mouse_until_ms:
			return
		_request_advance()


func _request_advance() -> void:
	if pending_advance:
		return
	pending_advance = true
	_perform_advance.call_deferred()


func _perform_advance() -> void:
	var director := get_tree().root.get_node_or_null("OpeningNarrationDirector")
	if director == null or not bool(director.get("active")):
		pending_advance = false
		return

	var pages_value: Variant = director.call("onboarding_pages")
	var pages: Array = pages_value if pages_value is Array else []
	var index := int(director.get("page_index"))
	var was_last_page := not pages.is_empty() and index >= pages.size() - 1

	director.call("_advance_page")
	await get_tree().process_frame

	# On the last page, remove any stale queue_free overlay immediately from the
	# UI tree. This makes normal tap-to-finish visibly complete without needing
	# the skip button and prevents a delayed synthetic event hitting stale UI.
	if was_last_page and not bool(director.get("active")):
		_detach_stale_overlay()

	pending_advance = false
	_configure_current_dim()


func _detach_stale_overlay() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var interface := scene.find_child("R3Interface", true, false) as Control
	if interface == null:
		return
	var overlay := interface.find_child(OVERLAY_NAME, true, false)
	if overlay != null and overlay.get_parent() != null:
		overlay.get_parent().remove_child(overlay)
		overlay.queue_free()
