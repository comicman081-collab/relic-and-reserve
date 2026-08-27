extends Node

# Last-mile portrait layout guard for tutorial overlays. Adding the spotlight
# creates new Controls and can cause MobileWebLayout to run one more responsive
# pass after MobileCaseTutorialUX. This guard keeps the authored mobile dossier
# contract (overview, clue cards, citations, hypotheses = one column) stable.

var interface: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_discover.call_deferred()


func _process(_delta: float) -> void:
	if interface == null or not is_instance_valid(interface) or not interface.is_inside_tree():
		_discover()
		return
	if not _is_portrait() or _screen_name() != "case_dossier":
		return
	_enforce_columns()


func _on_node_added(node: Node) -> void:
	if node is Control and node.name == "R3Interface":
		interface = node
		return
	if interface != null and is_instance_valid(interface) and interface.is_ancestor_of(node):
		call_deferred("_enforce_columns")


func _discover() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var candidate := scene.find_child("R3Interface", true, false)
	if candidate is Control:
		interface = candidate


func _is_portrait() -> bool:
	var bridge := get_tree().root.get_node_or_null("MobileWebLayout")
	if bridge != null and bridge.has_method("is_portrait_layout"):
		return bool(bridge.call("is_portrait_layout"))
	return interface != null and interface.size.y > interface.size.x * 1.08


func _screen_name() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	var value: Variant = scene.get("screen")
	return "" if value == null else str(value)


func _enforce_columns() -> void:
	if interface == null or not is_instance_valid(interface):
		return
	var briefing := interface.find_child("CaseTile_briefing", true, false) as Control
	if briefing != null and briefing.get_parent() is GridContainer:
		(briefing.get_parent() as GridContainer).columns = 1
	var evidence_cards := interface.find_children("CaseEvidenceCard_*", "Button", true, false)
	if not evidence_cards.is_empty():
		var evidence := evidence_cards[0] as Control
		if evidence != null and evidence.get_parent() is GridContainer:
			(evidence.get_parent() as GridContainer).columns = 1
	var hypotheses := interface.find_children("CaseHypothesis_*", "Button", true, false)
	if not hypotheses.is_empty():
		var hypothesis := hypotheses[0] as Control
		if hypothesis != null and hypothesis.get_parent() is GridContainer:
			(hypothesis.get_parent() as GridContainer).columns = 1
	var citations := interface.find_children("CaseCitation_*", "Button", true, false)
	if not citations.is_empty():
		var citation := citations[0] as Control
		if citation != null and citation.get_parent() is GridContainer:
			(citation.get_parent() as GridContainer).columns = 1
