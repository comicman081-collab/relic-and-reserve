extends Node

# Keeps the tap-through opening strictly single-page. OpeningNarrationDirector
# replaces its overlay during a GUI input callback; queue_free alone can leave a
# retired page in the tree until the frame boundary. Godot may also auto-rename
# the replacement overlay when the old sibling still owns the requested name.
# Detect opening layers by their unique panel child, keep the newest top-level
# layer, detach every older one immediately, then restore the canonical name.

const OVERLAY_NAME := "OpeningNarrationOverlay"
const PANEL_NAME := "OpeningNarrationPanel"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _process(_delta: float) -> void:
	_cleanup_opening_layers()


func _on_node_added(_node: Node) -> void:
	_cleanup_opening_layers.call_deferred()


func _cleanup_opening_layers() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var interface := scene.find_child("R3Interface", true, false)
	if interface == null:
		return
	var candidates: Array[Node] = []
	for child: Node in interface.get_children():
		if child is Control and child.find_child(PANEL_NAME, true, false) != null:
			candidates.append(child)
	if candidates.is_empty():
		return
	var newest := candidates[candidates.size() - 1]
	for candidate: Node in candidates:
		if candidate == newest:
			continue
		if candidate.get_parent() == interface:
			interface.remove_child(candidate)
		candidate.queue_free()
	if newest.get_parent() == interface and newest.name != OVERLAY_NAME:
		newest.name = OVERLAY_NAME
