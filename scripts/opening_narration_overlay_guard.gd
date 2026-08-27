extends Node

# Keeps the tap-through opening strictly single-page. OpeningNarrationDirector
# replaces its overlay during a GUI input callback; queue_free alone can leave the
# retired page visible to tree queries until the frame boundary. Detach any older
# sibling immediately when the replacement enters the tree, then free it safely.

const OVERLAY_NAME := "OpeningNarrationOverlay"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if not node is Control or node.name != OVERLAY_NAME:
		return
	var parent := node.get_parent()
	if parent == null:
		return
	for sibling: Node in parent.get_children():
		if sibling == node or sibling.name != OVERLAY_NAME:
			continue
		parent.remove_child(sibling)
		sibling.queue_free()
