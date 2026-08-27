extends Node

# Keeps the opening/menu onboarding readable on tall mobile Web viewports.
# This layer constrains presentation geometry only; gameplay and save state are untouched.

const OVERLAY_NAME := "OpeningNarrationOverlay"
const PANEL_NAME := "OpeningNarrationPanel"
const CONTENT_NAME := "OpeningNarrationContent"

var interface: Control
var queued := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_discover.call_deferred()


func _process(_delta: float) -> void:
	if interface == null or not is_instance_valid(interface):
		_discover()
		return
	if _is_portrait():
		_apply_portrait_constraints()


func _discover() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var candidate := scene.find_child("R3Interface", true, false)
	if candidate is Control:
		interface = candidate
		_queue_apply()


func _on_node_added(node: Node) -> void:
	if node is Control and node.name == "R3Interface":
		interface = node
		_queue_apply()
		return
	if interface != null and is_instance_valid(interface) and interface.is_ancestor_of(node):
		if node.name in [OVERLAY_NAME, PANEL_NAME, CONTENT_NAME] or String(node.name).begins_with("OpeningTab") or String(node.name).begins_with("OpeningNarration"):
			_queue_apply()


func _queue_apply() -> void:
	if queued:
		return
	queued = true
	_apply_deferred.call_deferred()


func _apply_deferred() -> void:
	await get_tree().process_frame
	queued = false
	if _is_portrait():
		_apply_portrait_constraints()


func _is_portrait() -> bool:
	return interface != null and is_instance_valid(interface) and interface.size.y > interface.size.x * 1.05


func _apply_portrait_constraints() -> void:
	var overlay := interface.find_child(OVERLAY_NAME, true, false) as Control
	if overlay == null:
		return
	var panel := overlay.find_child(PANEL_NAME, true, false) as PanelContainer
	if panel == null:
		return

	# Pin the dialog to real interface edges. The old fixed width could be wider
	# than the effective Web canvas after mobile safe-area/browser scaling.
	var side_margin := clampf(interface.size.x * 0.055, 30.0, 58.0)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.offset_left = side_margin
	panel.offset_right = -side_margin

	var panel_width := maxf(320.0, interface.size.x - side_margin * 2.0)
	var inner_width := maxf(260.0, panel_width - 64.0)
	var card_text_width := maxf(220.0, inner_width - 56.0)

	var content := panel.find_child(CONTENT_NAME, true, false) as VBoxContainer
	if content != null:
		content.custom_minimum_size.x = inner_width
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for node in panel.find_children("OpeningNarration*", "Label", true, false):
		var label := node as Label
		if label == null:
			continue
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		label.max_lines_visible = -1
		label.clip_text = false
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if label.name in ["OpeningNarrationBody", "OpeningNarrationTitle", "OpeningNarrationTapHint"]:
			label.custom_minimum_size.x = inner_width

	for node in panel.find_children("OpeningTabCard_*", "PanelContainer", true, false):
		var card := node as PanelContainer
		if card == null:
			continue
		card.custom_minimum_size.x = inner_width
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for node in panel.find_children("OpeningTabBody_*", "Label", true, false):
		var body := node as Label
		if body == null:
			continue
		body.custom_minimum_size.x = card_text_width
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		body.max_lines_visible = -1
		body.clip_text = false
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for node in panel.find_children("OpeningTabTitle_*", "Label", true, false):
		var title := node as Label
		if title == null:
			continue
		title.custom_minimum_size.x = card_text_width
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
