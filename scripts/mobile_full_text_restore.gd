extends Node

# Some desktop controls intentionally store shortened display text and keep the
# authored full copy in tooltip_text. Tooltips are not usable on touch devices,
# so portrait mobile restores that full copy into the visible label itself.

var interface: Control
var queued := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_discover.call_deferred()


func _discover() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var candidate := scene.find_child("R3Interface", true, false)
	if candidate is Control:
		interface = candidate
		_queue_restore()


func _on_node_added(node: Node) -> void:
	if node is Control and node.name == "R3Interface":
		interface = node
		_queue_restore()
	elif interface != null and is_instance_valid(interface) and interface.is_ancestor_of(node):
		_queue_restore()


func _queue_restore() -> void:
	if queued:
		return
	queued = true
	_restore_deferred.call_deferred()


func _restore_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	queued = false
	if interface == null or not is_instance_valid(interface) or not _is_portrait():
		return
	for node: Node in interface.find_children("CaseTileSummary_*", "Label", true, false):
		var label := node as Label
		var tile := _ancestor_panel(label)
		if label != null and tile != null and not tile.tooltip_text.is_empty():
			_make_full_label(label, tile.tooltip_text)
	for label_name in ["CaseReportPrompt", "CaseCitationLocator"]:
		var label := interface.find_child(label_name, true, false) as Label
		if label != null and not label.tooltip_text.is_empty():
			_make_full_label(label, label.tooltip_text)
	for node: Node in interface.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.tooltip_text.length() > label.text.length() + 3 and (label.text.ends_with("…") or label.text.contains("…")):
			_make_full_label(label, label.tooltip_text)


func _is_portrait() -> bool:
	var bridge := get_tree().root.get_node_or_null("MobileWebLayout")
	if bridge != null and bridge.has_method("is_portrait_layout"):
		return bool(bridge.call("is_portrait_layout"))
	return interface != null and interface.size.y > interface.size.x * 1.08


func _ancestor_panel(node: Node) -> PanelContainer:
	var current := node
	while current != null and current != interface:
		if current is PanelContainer:
			return current as PanelContainer
		current = current.get_parent()
	return null


func _make_full_label(label: Label, full_text: String) -> void:
	label.text = full_text
	label.max_lines_visible = -1
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.clip_text = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
