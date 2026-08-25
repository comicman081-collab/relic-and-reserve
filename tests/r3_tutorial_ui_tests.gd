extends SceneTree

const CASE_ID := "prologue_clock"
const TUTORIAL_STEPS := ["INVESTIGATE", "CITE", "REPORT", "REPAIR", "LIST", "AUCTION"]

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func settle_ui() -> void:
	# The guidance target is resolved after locale-aware container layout, then
	# scrolled once on the following frame.
	for _frame in range(4):
		await process_frame


func visible_copy(root: Node) -> String:
	var copy := ""
	for label: Label in root.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			copy += label.text + "\n"
	for button: Button in root.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			copy += button.text + "\n"
	return copy


func tutorial_target_name(main: Node) -> String:
	return String(main.tutorial_target_control.name) if main.tutorial_target_control != null else ""


func tutorial_target_layout(main: Node) -> Dictionary:
	var rail: Control = main.find_child("TutorialGuidanceRail", true, false)
	var outline: Control = main.find_child("TutorialTargetOutline", true, false)
	var nav: Control = main.find_child("Navigation", true, false)
	var status: Control = main.find_child("StatusMessage", true, false)
	var target: Control = main.tutorial_target_control
	if rail == null or outline == null or nav == null or status == null or target == null:
		return {"ok": false, "reason": "missing", "target": tutorial_target_name(main)}
	var target_rect := target.get_global_rect()
	var rail_rect := rail.get_global_rect()
	var nav_rect := nav.get_global_rect()
	var status_rect := status.get_global_rect()
	var within_content := target_rect.position.x >= 34.0 and target_rect.position.y >= 82.0 and target_rect.end.x <= 1246.0 and target_rect.end.y <= 608.0
	var separated := not target_rect.intersects(rail_rect) and not target_rect.intersects(nav_rect) and not target_rect.intersects(status_rect)
	return {
		"ok": within_content and separated and outline.get_global_rect().intersects(target_rect),
		"target": tutorial_target_name(main),
		"targetRect": [target_rect.position.x, target_rect.position.y, target_rect.size.x, target_rect.size.y],
		"withinContent": within_content,
		"separated": separated,
		"accented": outline.get_global_rect().intersects(target_rect)
	}


func visible_control_layout(main: Node, node_name: String) -> Dictionary:
	var control: Control = main.find_child(node_name, true, false)
	var nav: Control = main.find_child("Navigation", true, false)
	var status: Control = main.find_child("StatusMessage", true, false)
	if control == null or nav == null or status == null or not control.is_visible_in_tree():
		return {"ok": false, "reason": "missing", "control": node_name}
	var rect := control.get_global_rect()
	var within_content := rect.position.x >= 34.0 and rect.position.y >= 82.0 and rect.end.x <= 1246.0 and rect.end.y <= 608.0
	var separated := not rect.intersects(nav.get_global_rect()) and not rect.intersects(status.get_global_rect())
	return {"ok": within_content and separated, "control": node_name, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "withinContent": within_content, "separated": separated}


func inspection_columns_layout(main: Node) -> Dictionary:
	var info: Control = main.find_child("InspectionInfoColumn", true, false)
	var controls: Control = main.find_child("InspectionControlsColumn", true, false)
	var clue_grid: GridContainer = main.find_child("InspectionClueGrid", true, false)
	if info == null or controls == null or clue_grid == null:
		return {"ok": false, "reason": "missing inspection columns"}
	var info_rect := info.get_global_rect()
	var controls_rect := controls.get_global_rect()
	var gap := controls_rect.position.x - info_rect.end.x
	var compact_clues := clue_grid.get_children().all(func(child: Node): return child is Button and (child as Button).size.x <= 235.0 and not (child as Button).text.begins_with("INSPECT ") and not (child as Button).text.ends_with(" 조사"))
	return {
		"ok": gap >= 12.0 and not info_rect.intersects(controls_rect) and controls_rect.end.x <= 1246.0 and compact_clues,
		"infoRect": [info_rect.position.x, info_rect.position.y, info_rect.size.x, info_rect.size.y],
		"controlsRect": [controls_rect.position.x, controls_rect.position.y, controls_rect.size.x, controls_rect.size.y],
		"gap": gap,
		"compactClues": compact_clues,
		"clueLabels": clue_grid.get_children().map(func(child: Node): return (child as Button).text if child is Button else "")
	}


func dossier_readability_layout(main: Node) -> Dictionary:
	var rows: Control = main.find_child("CaseDossierRows", true, false)
	var scroll: ScrollContainer = main.find_child("CaseDossierScroll", true, false)
	var risk: Label = main.find_child("CaseEvidenceRiskLabel", true, false)
	var prompt: Label = main.find_child("CaseReportPrompt", true, false)
	var empty_citations: Label = main.find_child("CaseEmptyCitations", true, false)
	var widths := {
		"rows": rows.size.x if rows != null else 0.0,
		"risk": risk.size.x if risk != null else 0.0,
		"prompt": prompt.size.x if prompt != null else 0.0,
		"emptyCitations": empty_citations.size.x if empty_citations != null else 0.0
	}
	return {
		"ok": rows != null and scroll != null and risk != null and prompt != null and empty_citations != null \
			and rows.size.x >= 1100.0 and risk.size.x >= 120.0 and prompt.size.x >= 600.0 and empty_citations.size.x >= 300.0 \
			and scroll.scroll_horizontal == 0,
		"widths": widths,
		"horizontalScroll": scroll.scroll_horizontal if scroll != null else -1
	}


func first_unlocked_tool_free_evidence(gs: Node) -> String:
	for evidence_value: Variant in gs.case_definition(CASE_ID).get("evidence", []):
		var evidence: Dictionary = evidence_value
		if evidence.get("unlock", {}).get("requires_all", []).is_empty() and evidence.get("unlock", {}).get("requires_tools", []).is_empty():
			return String(evidence.get("id", ""))
	return ""


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	# Test guidance from an explicit fresh-profile fixture. reset_game preserves
	# player progression by design, so relying on whatever profile the editor last
	# loaded would make this UI contract order-dependent.
	gs.player_profile = gs.default_player_profile()
	gs.reset_game()
	gs.persistence_enabled = false
	gs.language = "ko"
	var stage_start: Dictionary = gs.new_game(1)
	var artifact: Dictionary = gs.begin_case(CASE_ID)
	var evidence_id := first_unlocked_tool_free_evidence(gs)
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await settle_ui()
	main.language = "ko"
	main.selected = artifact
	main.load_artifact(artifact)
	main.case_detail_evidence_id = evidence_id
	main.show_case_dossier(CASE_ID)
	await settle_ui()

	var rails: Array = main.find_children("TutorialGuidanceRail", "PanelContainer", true, false)
	var rail: PanelContainer = rails[0] if rails.size() == 1 else null
	var counter: Label = main.find_child("TutorialStepCounter", true, false)
	var title: Label = main.find_child("TutorialStepTitle", true, false)
	var instruction: Label = main.find_child("TutorialStepText", true, false)
	var icon: TextureRect = main.find_child("TutorialGuidanceIcon", true, false)
	var outline: PanelContainer = main.find_child("TutorialTargetOutline", true, false)
	var nav: Control = main.find_child("Navigation", true, false)
	var status: Control = main.find_child("StatusMessage", true, false)
	var step_one_target := tutorial_target_name(main)
	var step_one_copy := visible_copy(main)
	var raw_targets_hidden := ["CaseEvidence_", "CaseEvidenceCard_", "INVESTIGATE", "EVIDENCE_DISCOVERED", "route_ui_ids", "target_ui_id"].all(func(token: String): return not step_one_copy.contains(token))
	var layout_clear := rail != null and nav != null and status != null and not rail.get_global_rect().intersects(nav.get_global_rect()) and not rail.get_global_rect().intersects(status.get_global_rect())
	var target_accented := outline != null and main.tutorial_target_control != null and outline.get_global_rect().intersects(main.tutorial_target_control.get_global_rect())
	var compact_rail := rail != null and rail.size.y <= 64.0 and counter != null and counter.text == "안내 1/6" and title != null and title.max_lines_visible == 1 and instruction != null and instruction.max_lines_visible == 1 and icon != null and icon.texture != null
	var focus_and_tooltip: bool = main.tutorial_target_control != null and main.tutorial_target_control.has_focus() and main.tutorial_target_control.tooltip_text.contains("안내 1/6")
	var step_one_layout := tutorial_target_layout(main)
	var korean_dossier_layout := dossier_readability_layout(main)
	record(
		"MVP-TUTORIAL-UI-01",
		"Stage 1 renders one compact illustrated Korean guidance rail and accents the enabled keyboard target without exposing route identifiers or overlapping navigation",
		bool(stage_start.get("ok", false)) and not artifact.is_empty() and not evidence_id.is_empty() and rails.size() == 1 and compact_rail and raw_targets_hidden and layout_clear and target_accented and focus_and_tooltip and step_one_target.begins_with("CaseEvidence_") and bool(step_one_layout.get("ok", false)) and bool(korean_dossier_layout.get("ok", false)),
		{"rails": rails.size(), "counter": counter.text if counter != null else "", "title": title.text if title != null else "", "instruction": instruction.text if instruction != null else "", "target": step_one_target, "railHeight": rail.size.y if rail != null else -1, "rawHidden": raw_targets_hidden, "layoutClear": layout_clear, "accented": target_accented, "focus": focus_and_tooltip, "targetLayout": step_one_layout, "dossierLayout": korean_dossier_layout}
	)

	var route_targets: Dictionary = {"step1": step_one_target}
	var route_layouts: Dictionary = {"step1": step_one_layout}
	var discovery: Dictionary = gs.discover_case_evidence(CASE_ID, evidence_id)
	main.case_detail_evidence_id = evidence_id
	main.show_case_dossier(CASE_ID)
	await settle_ui()
	route_targets.step2 = tutorial_target_name(main)
	route_layouts.step2 = tutorial_target_layout(main)
	var cited: bool = bool(gs.toggle_case_citation(CASE_ID, evidence_id))
	main.show_case_dossier(CASE_ID)
	await settle_ui()
	route_targets.step3_disabled = tutorial_target_name(main)
	route_layouts.step3_disabled = tutorial_target_layout(main)
	var definition: Dictionary = gs.case_definition(CASE_ID)
	var canonical_hypothesis := String(definition.get("canonical_hypothesis_id", ""))
	var hypothesis_selected: bool = bool(gs.set_case_hypothesis(CASE_ID, canonical_hypothesis))
	main.show_case_dossier(CASE_ID)
	await settle_ui()
	route_targets.step3_ready = tutorial_target_name(main)
	route_layouts.step3_ready = tutorial_target_layout(main)
	var resolved: Dictionary = gs.resolve_case_v2(CASE_ID, canonical_hypothesis, [evidence_id])
	main.show_case_dossier(CASE_ID)
	await settle_ui()
	route_targets.step4_case = tutorial_target_name(main)
	route_layouts.step4_case = tutorial_target_layout(main)
	main.show_inventory()
	await settle_ui()
	route_targets.step4_inventory = tutorial_target_name(main)
	route_layouts.step4_inventory = tutorial_target_layout(main)
	gs.selected_tool = "soft_brush"
	main.show_inspection()
	await settle_ui()
	route_targets.step4_tool_needed = tutorial_target_name(main)
	route_layouts.step4_tool_needed = tutorial_target_layout(main)
	var required_tools: Array = gs.repair_requirements(artifact).get("requiredTools", [])
	var recommended_selected: bool = not required_tools.is_empty() and bool(gs.select_tool(String(required_tools[0])))
	main.show_inspection()
	await settle_ui()
	route_targets.step4_tool_ready = tutorial_target_name(main)
	route_layouts.step4_tool_ready = tutorial_target_layout(main)
	route_layouts.step4_dossier_route = visible_control_layout(main, "OpenCaseDossier")
	route_layouts.step4_inspection_columns = inspection_columns_layout(main)
	var repaired: String = String(gs.repair(artifact))
	main.show_inspection()
	await settle_ui()
	route_targets.step5_inspection = tutorial_target_name(main)
	route_layouts.step5_inspection = tutorial_target_layout(main)
	gs.authenticate(artifact)
	main.show_authentication()
	await settle_ui()
	route_targets.step5_authentication = tutorial_target_name(main)
	route_layouts.step5_authentication = tutorial_target_layout(main)
	main.accept_hypothesis_from_ui()
	await settle_ui()
	route_targets.step5_price = tutorial_target_name(main)
	route_layouts.step5_price = tutorial_target_layout(main)
	main.select_listing_price_preset("FAST")
	await settle_ui()
	route_targets.step5_disclosure = tutorial_target_name(main)
	route_layouts.step5_disclosure = tutorial_target_layout(main)
	main.select_listing_disclosure("CERTAIN")
	await settle_ui()
	route_targets.step5_confirm = tutorial_target_name(main)
	route_layouts.step5_confirm = tutorial_target_layout(main)
	main.confirm_listing_from_ui()
	await settle_ui()
	route_targets.step6 = tutorial_target_name(main)
	route_layouts.step6 = tutorial_target_layout(main)
	for _auction_step in range(16):
		var auction_cue: Dictionary = main.auction_public_cue_state()
		if auction_cue.is_empty() or bool(auction_cue.get("isFinal", false)):
			break
		main.advance_auction_cue()
		await settle_ui()
	route_targets.step6_final = tutorial_target_name(main)
	route_layouts.step6_final = tutorial_target_layout(main)
	var all_route_layouts_clear: bool = route_layouts.values().all(func(layout_value: Variant): return layout_value is Dictionary and bool(layout_value.get("ok", false)))
	var route_ok: bool = bool(discovery.get("ok", false)) \
		and cited \
		and hypothesis_selected \
		and bool(resolved.get("ok", false)) \
		and recommended_selected \
		and not repaired.is_empty() \
		and String(route_targets.step2).begins_with("CaseCitation_") \
		and String(route_targets.step3_disabled).begins_with("CaseHypothesis_") \
		and route_targets.step3_ready == "ResolveCaseReport" \
		and route_targets.step4_case == "CaseContinue" \
		and String(route_targets.step4_inventory).begins_with("InspectLot_") \
		and String(route_targets.step4_tool_needed).begins_with("RepairTool_") \
		and route_targets.step4_tool_ready == "Tool_repair" \
		and route_targets.step5_inspection == "AuthenticateButton" \
		and route_targets.step5_authentication == "AcceptHypothesisButton" \
		and String(route_targets.step5_price).begins_with("ListingPrice_") \
		and String(route_targets.step5_disclosure).begins_with("ListingDisclosure_") \
		and route_targets.step5_confirm == "ListingConfirmButton" \
		and route_targets.step6 == "AuctionCueNext" \
		and route_targets.step6_final == "HammerButton" \
		and all_route_layouts_clear
	record(
		"MVP-TUTORIAL-UI-02",
		"All six authored routes resolve to the nearest visible enabled control; repair, authentication and dossier actions remain above navigation",
		route_ok,
		{"targets": route_targets, "layouts": route_layouts, "allLayoutsClear": all_route_layouts_clear, "discovery": discovery, "resolved": resolved, "requiredTools": required_tools, "repair": repaired, "completed": gs.player_profile.get("tutorialCompletedSteps", [])}
	)

	main.finalize_sale_from_ui()
	await settle_ui()
	var hidden_after_completion: bool = main.find_children("TutorialGuidanceRail", "PanelContainer", true, false).is_empty() and not bool(gs.tutorial_public_state().get("visible", true)) and gs.player_profile.get("tutorialCompletedSteps", []) == TUTORIAL_STEPS
	main.show_stage_select()
	await settle_ui()
	var replay_buttons: Array = main.find_children("TutorialReplayButton", "Button", true, false)
	var stage_select_copy := visible_copy(main)
	var no_authority_buttons := main.find_children("TutorialNext*", "Button", true, false).is_empty() and main.find_children("TutorialSkip*", "Button", true, false).is_empty() and not stage_select_copy.contains("건너뛰기") and not stage_select_copy.contains("SKIP GUIDE")
	if replay_buttons.size() == 1:
		(replay_buttons[0] as Button).pressed.emit()
	await settle_ui()
	var replay_state: Dictionary = gs.tutorial_public_state()
	var replayed_without_fake_completion: bool = bool(replay_state.get("visible", false)) and int(replay_state.get("step", 0)) == 1 and gs.current_stage == 1 and gs.player_profile.get("tutorialCompletedSteps", []).is_empty()
	record(
		"MVP-TUTORIAL-UI-03",
		"Guidance hides after 6/6 and the single compact replay-help action restarts Stage 1 without skip or Next controls mutating authoritative progress",
		hidden_after_completion and replay_buttons.size() == 1 and no_authority_buttons and replayed_without_fake_completion,
		{"hiddenAfterSix": hidden_after_completion, "replayButtons": replay_buttons.size(), "noSkipNext": no_authority_buttons, "replayState": replay_state, "completedAfterReplay": gs.player_profile.get("tutorialCompletedSteps", [])}
	)

	gs.language = "en"
	main.language = "en"
	var english_artifact: Dictionary = gs.begin_case(CASE_ID)
	main.selected = english_artifact
	main.load_artifact(english_artifact)
	main.case_detail_evidence_id = evidence_id
	main.show_case_dossier(CASE_ID)
	await settle_ui()
	var english_rails: Array = main.find_children("TutorialGuidanceRail", "PanelContainer", true, false)
	var english_counter: Label = main.find_child("TutorialStepCounter", true, false)
	var english_title: Label = main.find_child("TutorialStepTitle", true, false)
	var english_instruction: Label = main.find_child("TutorialStepText", true, false)
	var english_copy := visible_copy(main)
	var english_raw_hidden := ["CaseEvidence_", "target_ui_id", "route_ui_ids", "EVIDENCE_DISCOVERED"].all(func(token: String): return not english_copy.contains(token))
	var english_target_layout := tutorial_target_layout(main)
	var english_dossier_layout := dossier_readability_layout(main)
	record(
		"MVP-TUTORIAL-UI-04",
		"Locale refresh rebuilds the same one-rail contract in English with one-line copy, focusable target, public tooltip and no internal route text",
		english_rails.size() == 1 and english_counter != null and english_counter.text == "GUIDE 1/6" and english_title != null and english_title.text == "Inspect one clue" and english_title.max_lines_visible == 1 and english_instruction != null and english_instruction.text == "Check the risk, then record one clue." and english_instruction.max_lines_visible == 1 and main.tutorial_target_control != null and main.tutorial_target_control.focus_mode != Control.FOCUS_NONE and main.tutorial_target_control.tooltip_text.contains("GUIDE 1/6") and english_raw_hidden and tutorial_target_name(main).begins_with("CaseEvidence_") and bool(english_target_layout.get("ok", false)) and bool(english_dossier_layout.get("ok", false)),
		{"rails": english_rails.size(), "counter": english_counter.text if english_counter != null else "", "title": english_title.text if english_title != null else "", "instruction": english_instruction.text if english_instruction != null else "", "target": tutorial_target_name(main), "rawHidden": english_raw_hidden, "targetLayout": english_target_layout, "dossierLayout": english_dossier_layout}
	)

	var passed := results.filter(func(result: Dictionary): return bool(result.passed)).size()
	var report := {"suite": "R3 Tutorial Guidance UI", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "skipped": 0, "tests": results}
	var output := FileAccess.open("res://qa/R3_TUTORIAL_UI_TESTS.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	main.queue_free()
	await process_frame
	quit(0 if passed == results.size() else 1)
