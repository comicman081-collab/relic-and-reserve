extends SceneTree

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func visible_copy(root: Node) -> String:
	var copy := ""
	for label: Label in root.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			copy += label.text + "\n"
	for button: Button in root.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			copy += button.text + "\n"
	return copy


func layout_signature(control: Control) -> Array:
	return [control.position.x, control.position.y, control.size.x, control.size.y]


func reaction_is_settled(anchor: Control) -> bool:
	return is_equal_approx(anchor.scale.x, 1.0) \
		and is_equal_approx(anchor.scale.y, 1.0) \
		and is_zero_approx(anchor.rotation_degrees) \
		and is_equal_approx(anchor.modulate.a, 1.0) \
		and not bool(anchor.get_meta("reaction_running", false))


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	gs.reset_game()
	gs.persistence_enabled = false
	gs.language = "ko"
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.language = "ko"
	main.clear_ui()

	var host := Control.new()
	host.name = "ReactionFixtureHost"
	host.position = Vector2(20, 20)
	host.size = Vector2(1240, 620)
	main.ui.add_child(host)
	var row := HBoxContainer.new()
	row.name = "ReactionFixtureRow"
	row.position = Vector2(20, 20)
	row.size = Vector2(1160, 330)
	row.add_theme_constant_override("separation", 16)
	host.add_child(row)

	var fixture_specs := [
		{"character": "auctioneer", "state": "INTRO", "kind": "alpha_settle"},
		{"character": "shopkeeper", "state": "PURCHASE_OK", "kind": "gentle_pop"},
		{"character": "bidder_01", "state": "DROPOUT", "kind": "soft_tilt"}
	]
	var fixture_panels: Array = []
	var fixture_cues: Array = []
	for spec: Dictionary in fixture_specs:
		var cue: Dictionary = main.character_cue(String(spec.character), String(spec.state))
		fixture_cues.append(cue)
		var panel: PanelContainer = main.make_portrait_dialogue_panel(cue, 220.0, 150.0)
		fixture_panels.append(panel)
		row.add_child(panel)
	var sibling_cta := Button.new()
	sibling_cta.name = "ReactionSiblingCTA"
	sibling_cta.text = "계속"
	sibling_cta.custom_minimum_size = Vector2(160, 52)
	row.add_child(sibling_cta)
	await process_frame
	await process_frame

	var anchors: Array = []
	var contracts: Array = []
	var contract_failures: Array = []
	for fixture_index: int in range(fixture_panels.size()):
		var fixture_panel: PanelContainer = fixture_panels[fixture_index]
		var anchor: Control = fixture_panel.find_child("PortraitReactionAnchor", true, false)
		anchors.append(anchor)
		var contract: Dictionary = anchor.get_meta("reaction_contract", {}) if anchor != null else {}
		contracts.append(contract)
		var final_transform: Dictionary = contract.get("finalTransform", {})
		if anchor == null \
			or String(contract.get("kind", "")) != String(fixture_specs[fixture_index].kind) \
			or int(contract.get("durationMs", 0)) < 100 \
			or int(contract.get("durationMs", 0)) > 180 \
			or final_transform.get("scale", []) != [1.0, 1.0] \
			or not is_zero_approx(float(final_transform.get("rotationDegrees", 1.0))) \
			or not is_equal_approx(float(final_transform.get("alpha", 0.0)), 1.0):
			contract_failures.append({"fixture": fixture_index, "contract": contract})
	record(
		"MVP-CHARACTER-REACTION-01",
		"Neutral, positive and negative portraits expose a named child-only reaction anchor with a public 100-180 ms contract",
		anchors.size() == 3 and anchors.all(func(anchor: Variant): return anchor != null and anchor.name == "PortraitReactionAnchor") and contract_failures.is_empty(),
		{"contracts": contracts, "failures": contract_failures}
	)

	var panel_layout_before: Array = fixture_panels.map(func(panel: PanelContainer): return layout_signature(panel))
	var portrait_layout_before: Array = fixture_panels.map(func(panel: PanelContainer): return layout_signature(panel.find_child("CharacterPortrait", true, false)))
	var anchor_layout_before: Array = anchors.map(func(anchor: Control): return layout_signature(anchor))
	var cta_layout_before := layout_signature(sibling_cta)
	await create_timer(0.24).timeout
	await process_frame
	var panel_layout_after: Array = fixture_panels.map(func(panel: PanelContainer): return layout_signature(panel))
	var portrait_layout_after: Array = fixture_panels.map(func(panel: PanelContainer): return layout_signature(panel.find_child("CharacterPortrait", true, false)))
	var anchor_layout_after: Array = anchors.map(func(anchor: Control): return layout_signature(anchor))
	var cta_layout_after := layout_signature(sibling_cta)
	var dialogues: Array = row.find_children("CharacterDialogue", "Label", true, false)
	var state_labels: Array = row.find_children("CharacterSemanticState", "Label", true, false)
	record(
		"MVP-CHARACTER-REACTION-02",
		"Every reaction settles exactly to opaque unit transform while portrait, panel and sibling CTA layout geometry remain unchanged",
		anchors.all(func(anchor: Control): return reaction_is_settled(anchor)) \
			and panel_layout_before == panel_layout_after \
			and portrait_layout_before == portrait_layout_after \
			and anchor_layout_before == anchor_layout_after \
			and cta_layout_before == cta_layout_after \
			and dialogues.size() == 3 \
			and dialogues.all(func(label: Label): return label.max_lines_visible == 2 and not label.text.is_empty()) \
			and state_labels.size() == 3,
		{"panelBefore": panel_layout_before, "panelAfter": panel_layout_after, "portraitBefore": portrait_layout_before, "portraitAfter": portrait_layout_after, "anchorBefore": anchor_layout_before, "anchorAfter": anchor_layout_after, "ctaBefore": cta_layout_before, "ctaAfter": cta_layout_after, "settled": anchors.map(func(anchor: Control): return reaction_is_settled(anchor))}
	)

	var korean_copy := visible_copy(row)
	var korean_expected := fixture_cues.all(func(cue: Dictionary): return korean_copy.contains(main.character_state_label(String(cue.semanticState))) and korean_copy.contains(String(cue.dialogue)))
	main.clear_ui()
	main.language = "en"
	gs.language = "en"
	var english_cue: Dictionary = main.character_cue("shopkeeper", "PURCHASE_OK")
	var english_panel: PanelContainer = main.make_portrait_dialogue_panel(english_cue, 250.0, 180.0)
	main.ui.add_child(english_panel)
	await process_frame
	var english_copy := visible_copy(english_panel)
	var raw_expression_hidden := ["NEUTRAL", "POSITIVE", "NEGATIVE"].all(func(token: String): return not korean_copy.contains(token) and not english_copy.contains(token))
	record(
		"MVP-CHARACTER-REACTION-03",
		"Micro-reactions retain localized semantic and two-line dialogue copy without exposing expression enums",
		korean_expected \
			and english_copy.contains(main.character_state_label("PURCHASE_OK")) \
			and english_copy.contains(String(english_cue.dialogue)) \
			and english_panel.find_children("CharacterDialogue", "Label", true, false).all(func(label: Label): return label.max_lines_visible == 2) \
			and raw_expression_hidden,
		{"koreanCopy": korean_copy, "englishCopy": english_copy, "rawExpressionHidden": raw_expression_hidden}
	)

	# Exercise the deferred-start/free path, then repeatedly replace a running
	# reaction. Only the last live panel may retain an anchor.
	main.clear_ui()
	var disposable: PanelContainer = main.make_portrait_dialogue_panel(main.character_cue("bidder_01", "DROPOUT"), 220.0, 150.0)
	main.ui.add_child(disposable)
	main.clear_ui()
	await process_frame
	var final_panel: PanelContainer
	for rebuild_index: int in range(10):
		main.clear_ui()
		var rebuild_state: String = ["INTRO", "SOLD", "NO_SALE"][rebuild_index % 3]
		final_panel = main.make_portrait_dialogue_panel(main.character_cue("auctioneer", rebuild_state), 220.0, 150.0)
		main.ui.add_child(final_panel)
		await process_frame
	await create_timer(0.24).timeout
	await process_frame
	var live_anchors: Array = main.ui.find_children("PortraitReactionAnchor", "Control", true, false)
	var live_dialogues: Array = main.ui.find_children("CharacterDialogue", "Label", true, false)
	record(
		"MVP-CHARACTER-REACTION-04",
		"Deferred and rapid panel rebuilds leave one settled live anchor with no transform drift or lost dialogue",
		live_anchors.size() == 1 \
			and reaction_is_settled(live_anchors[0]) \
			and not live_anchors[0].has_meta("_reaction_tween") \
			and live_dialogues.size() == 1 \
			and not live_dialogues[0].text.is_empty() \
			and final_panel != null \
			and final_panel.is_inside_tree(),
		{"liveAnchors": live_anchors.size(), "settled": reaction_is_settled(live_anchors[0]) if live_anchors.size() == 1 else false, "hasTween": live_anchors[0].has_meta("_reaction_tween") if live_anchors.size() == 1 else null, "dialogues": live_dialogues.size()}
	)

	var passed := results.filter(func(result: Dictionary): return bool(result.passed)).size()
	var report := {"suite": "R3 Character Micro-Reaction UI", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "skipped": 0, "tests": results}
	var output := FileAccess.open("res://qa/R3_CHARACTER_REACTION_UI_TESTS.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	main.queue_free()
	quit(0 if passed == results.size() else 1)
