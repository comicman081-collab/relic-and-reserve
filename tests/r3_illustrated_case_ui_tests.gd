extends SceneTree

const CASE_ID := "prologue_clock"
const ICON_NAMES := [
	"briefing", "core_question", "objective", "artifact", "document", "npc", "reference", "clue_generic",
	"hypothesis", "support", "refute", "tool", "risk", "locked", "citation", "report"
]

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func all_buttons(root: Node) -> Array:
	return root.find_children("*", "Button", true, false)


func button_named(root: Node, prefix: String) -> Button:
	for candidate: Node in all_buttons(root):
		if candidate is Button and String(candidate.name).begins_with(prefix):
			return candidate
	return null


func visible_copy(root: Node) -> String:
	var entries: Array = []
	for candidate: Node in root.find_children("*", "Label", true, false):
		if candidate is Label and candidate.is_visible_in_tree():
			entries.append(candidate.text)
	for candidate: Node in all_buttons(root):
		if candidate is Button and candidate.is_visible_in_tree():
			entries.append(candidate.text)
	return "\n".join(entries)


func discover_all(gs: Node) -> void:
	for _pass in range(12):
		var progressed := false
		for evidence: Dictionary in gs.get_case_public_state(CASE_ID).get("availableEvidence", []):
			if not evidence.get("requiredTools", []).is_empty():
				gs.select_tool(String(evidence.requiredTools[0]))
			var outcome: Dictionary = gs.discover_case_evidence(CASE_ID, evidence.id)
			if outcome.get("code", "") == "DISCOVERED":
				progressed = true
		if not progressed:
			break


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.reset_game()
	gs.persistence_enabled = false
	gs.language = "ko"
	var artifact: Dictionary = gs.begin_case(CASE_ID)
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.language = "ko"
	main.selected = artifact
	main.load_artifact(artifact)
	main.show_case_dossier(CASE_ID)
	await process_frame

	var actual_svg_names: Array = []
	for file_name: String in DirAccess.get_files_at("res://assets/ui/case_icons"):
		if file_name.ends_with(".svg"):
			actual_svg_names.append(file_name.trim_suffix(".svg"))
	actual_svg_names.sort()
	var expected_names := ICON_NAMES.duplicate()
	expected_names.sort()
	var textures_load := ICON_NAMES.all(func(icon_name: String): return load("res://assets/ui/case_icons/%s.svg" % icon_name) is Texture2D)
	record(
		"MVP-ILLUSTRATED-01",
		"Exactly sixteen coherent case pictogram resources exist and import as textures",
		actual_svg_names == expected_names and textures_load,
		{"expected": expected_names, "actual": actual_svg_names, "texturesLoad": textures_load}
	)

	var tile_summaries: Array = main.find_children("CaseTileSummary_*", "Label", true, false)
	var tile_character_count := 0
	for summary: Label in tile_summaries:
		tile_character_count += summary.text.length()
	var evidence_cards: Array = []
	for button: Node in all_buttons(main):
		if String(button.name).begins_with("CaseEvidenceCard_"):
			evidence_cards.append(button)
	var body_leaked := evidence_cards.any(func(card: Button): return card.text.contains("나사 머리 아래까지") or card.text.contains("Beneath the dust"))
	record(
		"MVP-ILLUSTRATED-02",
		"Artifact identity plus three compact illustrated overview tiles and two-column collapsed clue cards replace body-heavy copy",
		tile_summaries.size() == 4 and tile_character_count <= 170 and evidence_cards.size() == 5 and not body_leaked and evidence_cards.all(func(card: Button): return card.text.count("\n") == 1),
		{"tiles": tile_summaries.size(), "tileCharacters": tile_character_count, "cards": evidence_cards.size(), "bodyLeaked": body_leaked}
	)

	var discovered_before: int = gs.get_case_public_state(CASE_ID).get("discoveredEvidence", []).size()
	var first_evidence_id := "src.prologue.artifact.backplate_screws"
	main.select_case_evidence_detail(CASE_ID, first_evidence_id)
	await process_frame
	var discovered_after_select: int = gs.get_case_public_state(CASE_ID).get("discoveredEvidence", []).size()
	var investigate_button := button_named(main, "CaseEvidence_")
	var risk_copy := visible_copy(main)
	record(
		"MVP-ILLUSTRATED-03",
		"Selecting a clue reveals its risk before a separate investigation action mutates state",
		discovered_before == discovered_after_select and investigate_button != null and risk_copy.contains("위험 높음") and risk_copy.contains("산화 경계"),
		{"before": discovered_before, "afterSelect": discovered_after_select, "action": investigate_button != null, "riskVisible": risk_copy.contains("산화 경계")}
	)

	var locked_id := "src.prologue.npc.mara_statement"
	main.select_case_evidence_detail(CASE_ID, locked_id)
	await process_frame
	var locked_copy := visible_copy(main)
	var no_internal_ids := not locked_copy.contains("src.") and not locked_copy.contains("hyp.") and not locked_copy.contains("precision_screwdriver")
	var locked_action: Label = main.find_child("CaseLockedActionTarget", true, false)
	var locked_title: Label = main.find_child("CaseEvidenceDisplayTitle", true, false)
	var locked_meta: Label = main.find_child("CaseEvidenceSourceMeta", true, false)
	var locked_icon: TextureRect = main.find_child("CaseLockedSourceIcon", true, false)
	var expected_locked_copy := "물어보기 · 인물"
	record(
		"MVP-ILLUSTRATED-04",
		"Locked clue detail exposes only localized action and public target with a lock icon, never source kind, prerequisite ids, tools or hidden body",
		locked_action != null and locked_action.text == expected_locked_copy \
			and locked_title != null and locked_title.text == expected_locked_copy \
			and locked_meta != null and locked_meta.text == "잠김" \
			and locked_icon != null and locked_icon.texture != null \
			and not locked_copy.contains("스승님은 손상된") and no_internal_ids,
		{"actionTarget": locked_action.text if locked_action != null else "", "title": locked_title.text if locked_title != null else "", "meta": locked_meta.text if locked_meta != null else "", "lockIcon": locked_icon != null, "bodyHidden": not locked_copy.contains("스승님은 손상된"), "noInternalIds": no_internal_ids}
	)

	var selected_before_locale: String = main.case_detail_evidence_id
	main.toggle_language()
	await process_frame
	var selected_after_locale: String = main.case_detail_evidence_id
	var focus_ready := true
	var tooltip_ready := true
	var refreshed_cards: Array = []
	for button: Node in all_buttons(main):
		if String(button.name).begins_with("CaseEvidenceCard_"):
			refreshed_cards.append(button)
	for card: Button in refreshed_cards:
		focus_ready = focus_ready and card.focus_mode != Control.FOCUS_NONE
		tooltip_ready = tooltip_ready and not card.tooltip_text.is_empty()
	record(
		"MVP-ILLUSTRATED-05",
		"Clue selection survives locale refresh and cards retain keyboard focus and explanatory tooltips",
		selected_before_locale == locked_id and selected_after_locale == locked_id and main.screen == "case_dossier" and focus_ready and tooltip_ready,
		{"before": selected_before_locale, "after": selected_after_locale, "screen": main.screen, "focus": focus_ready, "tooltips": tooltip_ready}
	)

	gs.reset_game()
	gs.persistence_enabled = false
	artifact = gs.begin_case(CASE_ID)
	discover_all(gs)
	gs.set_case_hypothesis(CASE_ID, "hyp.untouched_original")
	gs.toggle_case_citation(CASE_ID, first_evidence_id)
	main.language = "en"
	main.selected = artifact
	main.load_artifact(artifact)
	main.case_detail_evidence_id = first_evidence_id
	main.show_case_dossier(CASE_ID)
	await process_frame
	var final_copy := visible_copy(main)
	var citation_card := button_named(main, "ReportCitationRemove_")
	var relation_icons := 0
	for icon: Node in main.find_children("*", "TextureRect", true, false):
		if icon is TextureRect and icon.texture in [load("res://assets/ui/case_icons/support.svg"), load("res://assets/ui/case_icons/refute.svg")]:
			relation_icons += 1
	record(
		"MVP-ILLUSTRATED-06",
		"Full selected detail preserves support/refute semantics and report citation cards show an independent-source count",
		citation_card != null and citation_card.text.contains("REFUTE") and final_copy.to_lower().contains("independent sources") and final_copy.contains("●") and relation_icons >= 2,
		{"citation": citation_card.text if citation_card != null else "", "independenceDots": final_copy.count("●"), "relationIcons": relation_icons}
	)

	var long_unbounded_paragraphs: Array = []
	for candidate: Node in main.find_children("*", "Label", true, false):
		if candidate is Label and candidate.is_visible_in_tree() and candidate.text.length() > 54 and (candidate.max_lines_visible < 1 or candidate.max_lines_visible > 2):
			long_unbounded_paragraphs.append(candidate.text)
	record(
		"MVP-ILLUSTRATED-07",
		"Visible explanatory paragraphs are capped to two lines while full clue text remains available in chunks",
		long_unbounded_paragraphs.is_empty() and final_copy.contains("oxidation ring"),
		{"unbounded": long_unbounded_paragraphs, "fullDetailPresent": final_copy.contains("oxidation ring")}
	)

	gs.reset_game()
	gs.persistence_enabled = false
	gs.language = "ko"
	main.language = "ko"
	var expansion_artifact: Dictionary = gs.new_artifact("artifact_061", 610061, "illustrated_inspection")
	main.selected = expansion_artifact
	main.load_artifact(expansion_artifact)
	main.show_inspection()
	await process_frame
	var observable_tile := main.find_child("InspectionObservableTile", true, false)
	var observable_summary := main.find_child("CaseTileSummary_clue_generic", true, false)
	var expected_observable: String = registry.get_spec("artifact_061").get("inspectionObservable", {}).get("ko", "")
	var observable_tooltip := String(observable_tile.tooltip_text) if observable_tile != null else ""
	record(
		"MVP-ILLUSTRATED-08",
		"Expansion inspection observations render as a compact localized illustrated clue tile with full text in its tooltip",
		observable_tile != null and observable_summary is Label and observable_summary.max_lines_visible == 2 and observable_summary.text.begins_with("소금기에") and observable_summary.text.length() <= 42 and observable_tooltip == expected_observable,
		{"tile": observable_tile != null, "summary": observable_summary.text if observable_summary is Label else "", "tooltip": observable_tooltip, "expected": expected_observable}
	)

	gs.reset_game()
	gs.persistence_enabled = false
	gs.language = "ko"
	artifact = gs.begin_case(CASE_ID)
	main.language = "ko"
	main.selected = artifact
	main.load_artifact(artifact)
	main.show_case_dossier(CASE_ID)
	await process_frame
	main.equip_case_tool_from_ui(CASE_ID, "precision_screwdriver")
	await process_frame
	var equipped_status := String(main.status.text)
	record(
		"MVP-ILLUSTRATED-09",
		"Tool activation status uses a localized player-facing name instead of an internal identifier",
		equipped_status.contains("정밀 드라이버") and not equipped_status.contains("precision_screwdriver"),
		{"status": equipped_status}
	)

	expansion_artifact = gs.new_artifact("artifact_061", 610062, "repair_tool_integration")
	expansion_artifact.damageInstances = ["MECHANICAL_WEAR"]
	gs.select_tool("soft_brush")
	main.selected = expansion_artifact
	main.load_artifact(expansion_artifact)
	main.show_inspection()
	await process_frame
	var repair_hint := main.find_child("RepairToolAnyOneHint", true, false)
	var repair_tradeoff_tile := main.find_child("RepairTradeoffTile", true, false)
	var repair_tool_buttons: Array = main.find_children("RepairTool_*", "Button", true, false)
	var repair_button := main.find_child("Tool_repair", true, false)
	var screwdriver_button := main.find_child("RepairTool_precision_screwdriver", true, false)
	var repair_hint_text: String = repair_hint.text if repair_hint is Label else ""
	var repair_tradeoff_present := repair_tradeoff_tile != null
	var repair_tool_count := repair_tool_buttons.size()
	var visible_repair_tools := repair_tool_buttons.map(func(button: Button): return button.text)
	var inspection_copy := visible_copy(main)
	var no_expansion_raw_tokens := ["artifact_061", "stage_variant_061", "clock.obj", "SERIAL_PATTERN", "MECHANISM", "TOOL_MARK", "PATINA"].all(func(token: String): return not inspection_copy.contains(token))
	if screwdriver_button is Button:
		screwdriver_button.emit_signal("pressed")
		await process_frame
		repair_button = main.find_child("Tool_repair", true, false)
	if repair_button is Button:
		repair_button.emit_signal("pressed")
		await process_frame
	var repair_status := String(main.status.text)
	record(
		"MVP-ILLUSTRATED-10",
		"Expansion repair requirements render trade-off plus data-driven localized choices, and any one recommended tool completes repair without a mismatch penalty",
		repair_hint_text.contains("중 하나") and repair_tradeoff_present and repair_tool_count == 2 and visible_repair_tools.any(func(text: String): return text.contains("정밀 드라이버") and text.contains("사용 가능")) and visible_repair_tools.any(func(text: String): return text.contains("광택 패드") and text.contains("사용 가능")) and inspection_copy.contains("정밀 시계") and inspection_copy.contains("일련번호") and not inspection_copy.contains("일련번호 조사") and no_expansion_raw_tokens and gs.selected_tool == "precision_screwdriver" and not expansion_artifact.damageInstances.has("MECHANICAL_WEAR") and repair_status == "수리를 마쳤습니다.",
		{"hint": repair_hint_text, "tradeoff": repair_tradeoff_present, "tools": visible_repair_tools, "friendlyVisual": inspection_copy.contains("정밀 시계"), "friendlyClues": inspection_copy.contains("일련번호") and not inspection_copy.contains("일련번호 조사"), "noRawTokens": no_expansion_raw_tokens, "selectedTool": gs.selected_tool, "damage": expansion_artifact.damageInstances, "status": repair_status}
	)

	gs.reset_game()
	gs.persistence_enabled = false
	gs.language = "ko"
	main.language = "ko"
	artifact = gs.begin_case(CASE_ID)
	main.selected = artifact
	main.load_artifact(artifact)
	main.show_campaign()
	await process_frame
	var legacy_campaign_copy := visible_copy(main)
	main.show_workshop()
	await process_frame
	var workshop_copy := visible_copy(main)
	main.show_inventory()
	await process_frame
	var inventory_copy := visible_copy(main)
	main.show_market()
	await process_frame
	var market_copy := visible_copy(main)
	var first_market_spec: Dictionary = registry.get_spec(gs.market_roster[0].get("specId", "")) if not gs.market_roster.is_empty() else {}
	var market_category_id: String = String(first_market_spec.get("category", ""))
	var market_category_label: String = main.friendly_artifact_visual(first_market_spec)
	main.discover_case_evidence_from_ui(CASE_ID, "src.prologue.npc.mara_statement")
	await process_frame
	var investigate_status := String(main.status.text)
	main.resolve_case_report_from_ui(CASE_ID)
	await process_frame
	var report_status := String(main.status.text)
	var final_artifact: Dictionary = gs.new_artifact("artifact_061", 611111, "raw_unique_should_hide")
	final_artifact.playerHypothesis = "GENUINE"
	final_artifact.knownClues = ["documented maker mark", "period tool trace"]
	final_artifact.historicalIntegrity = 80.0
	gs.inventory.append(final_artifact)
	main.show_final_lot_selection()
	await process_frame
	var final_lot_copy := visible_copy(main)
	gs.campaign_state.currentEnding = "ENDING_S"
	gs.campaign_state.grandReserve.score = {}
	gs.campaign_state.grandReserve.results = [{"artifact": {"displayName": "검증 출품작"}, "auction": {"sale_status": "SOLD", "hammer": 100}}]
	main.show_ending()
	await process_frame
	var ending_copy := visible_copy(main)
	gs.campaign_state.endingUnlocked = ["ENDING_S"]
	main.show_postgame()
	await process_frame
	var postgame_copy := visible_copy(main)
	var raw_token_checks := {
		"campaignLocation": legacy_campaign_copy.contains("작은 공방") and not legacy_campaign_copy.contains("small_workshop"),
		"workshop": workshop_copy.contains("닫힌 공방") and not workshop_copy.contains("PROLOGUE"),
		"inventory": inventory_copy.contains("닫힌 공방") and not inventory_copy.contains(CASE_ID),
		"market": not market_category_label.is_empty() and market_copy.contains(market_category_label) and not market_copy.contains(market_category_id),
		"investigation": investigate_status.contains("단서 조건") and not investigate_status.contains("EVIDENCE_LOCKED"),
		"report": report_status.contains("가설을 먼저") and not report_status.contains("INVALID_HYPOTHESIS"),
		"grandReserve": not final_lot_copy.contains("raw_unique_should_hide") and final_lot_copy.contains("정밀 시계"),
		"ending": ending_copy.contains("리저브의 거장") and ending_copy.contains("낙찰") and not ending_copy.contains("ENDING_S") and not ending_copy.contains("SOLD"),
		"postgame": postgame_copy.contains("리저브의 거장") and not postgame_copy.contains("ENDING_S")
	}
	record(
		"MVP-ILLUSTRATED-11",
		"Workshop, market, inventory, case failures, Grand Reserve, ending, and gallery expose localized player labels with no raw runtime tokens",
		raw_token_checks.values().all(func(value: Variant): return bool(value)),
		{"checks": raw_token_checks, "investigationStatus": investigate_status, "reportStatus": report_status, "finalLot": final_lot_copy, "ending": ending_copy, "postgame": postgame_copy}
	)

	gs.reset_game()
	gs.persistence_enabled = false
	gs.language = "ko"
	main.language = "ko"
	artifact = gs.begin_case(CASE_ID)
	var authored_evidence: Dictionary = {}
	for candidate: Dictionary in gs.case_definition(CASE_ID).get("evidence", []):
		if candidate.get("source", {}).get("kind", "") == "ARTIFACT" and candidate.get("unlock", {}).get("requires_all", []).is_empty():
			authored_evidence = candidate
			break
	var required_auth_tools: Array = authored_evidence.get("unlock", {}).get("requires_tools", [])
	if not required_auth_tools.is_empty():
		gs.select_tool(String(required_auth_tools[0]))
	var authored_discovery: Dictionary = gs.discover_case_evidence(CASE_ID, String(authored_evidence.get("id", ""))) if not authored_evidence.is_empty() else {}
	var authored_runtime_evidence: Dictionary = artifact.evidence[-1] if not artifact.evidence.is_empty() else {}
	main.selected = artifact
	main.show_authentication()
	await process_frame
	var authored_public_row: Dictionary = main.case_evidence_row(gs.get_case_public_state(CASE_ID), String(authored_evidence.get("id", "")))
	var expected_auth_title_ko: String = String(main.case_evidence_title(CASE_ID, authored_public_row))
	var expected_auth_observation_ko := String(authored_runtime_evidence.get("observation", {}).get("ko", "")) if authored_runtime_evidence.get("observation", {}) is Dictionary else ""
	var authored_auth_copy_ko := visible_copy(main)
	main.language = "en"
	gs.language = "en"
	main.show_authentication()
	await process_frame
	var expected_auth_title_en: String = String(main.case_evidence_title(CASE_ID, authored_public_row))
	var expected_auth_observation_en := String(authored_runtime_evidence.get("observation", {}).get("en", "")) if authored_runtime_evidence.get("observation", {}) is Dictionary else ""
	var authored_auth_copy_en := visible_copy(main)
	var authored_source_id := String(authored_runtime_evidence.get("clueType", ""))
	record(
		"MVP-ILLUSTRATED-13",
		"Authentication localizes authored-v2 observation dictionaries and resolves source evidence IDs to authored public titles in Korean and English",
		bool(authored_discovery.get("ok", false)) and authored_runtime_evidence.get("observation", {}) is Dictionary and not expected_auth_title_ko.is_empty() and not expected_auth_observation_ko.is_empty() and authored_auth_copy_ko.contains(expected_auth_title_ko) and authored_auth_copy_ko.contains(expected_auth_observation_ko) and not authored_auth_copy_ko.contains(authored_source_id) and not authored_auth_copy_ko.contains("{ \"en\"") and not expected_auth_title_en.is_empty() and not expected_auth_observation_en.is_empty() and authored_auth_copy_en.contains(expected_auth_title_en) and authored_auth_copy_en.contains(expected_auth_observation_en) and not authored_auth_copy_en.contains(authored_source_id) and not authored_auth_copy_en.contains("Src."),
		{"evidenceIdHidden": authored_source_id, "ko": {"title": expected_auth_title_ko, "observation": expected_auth_observation_ko}, "en": {"title": expected_auth_title_en, "observation": expected_auth_observation_en}}
	)

	gs.reset_game()
	gs.persistence_enabled = false
	gs.language = "ko"
	main.language = "ko"
	artifact = gs.begin_case(CASE_ID)
	discover_all(gs)
	var resolved_definition: Dictionary = gs.case_definition(CASE_ID)
	var resolved_hypothesis := String(resolved_definition.get("canonical_hypothesis_id", ""))
	gs.set_case_hypothesis(CASE_ID, resolved_hypothesis)
	var resolved_citations: Array = []
	for resolved_evidence: Dictionary in gs.get_case_public_state(CASE_ID).get("evidence", []):
		if bool(resolved_evidence.get("discovered", false)) and bool(resolved_evidence.get("citationAllowed", true)):
			var resolved_evidence_id := String(resolved_evidence.get("id", ""))
			resolved_citations.append(resolved_evidence_id)
			gs.toggle_case_citation(CASE_ID, resolved_evidence_id)
	var resolved_result: Dictionary = gs.resolve_case_v2(CASE_ID, resolved_hypothesis, resolved_citations)
	main.selected = artifact
	main.load_artifact(artifact)
	main.show_case_dossier(CASE_ID)
	await process_frame
	var resolved_copy_ko := visible_copy(main)
	var substantiation_id := String(resolved_result.get("substantiation", "INCONCLUSIVE"))
	var expected_substantiation_ko: String = main.case_substantiation_label(substantiation_id)
	gs.language = "en"
	main.language = "en"
	main.show_case_dossier(CASE_ID)
	await process_frame
	var resolved_copy_en := visible_copy(main)
	var expected_substantiation_en: String = main.case_substantiation_label(substantiation_id)
	var raw_substantiation_hidden := ["STRONG", "PLAUSIBLE", "INCONCLUSIVE"].all(func(token: String): return not resolved_copy_ko.contains(token) and not resolved_copy_en.contains(token))
	var substantiation_fixtures := {
		"STRONG": {"ko": "강한 입증", "en": "Strong support"},
		"PLAUSIBLE": {"ko": "개연성 있음", "en": "Plausible"},
		"INCONCLUSIVE": {"ko": "결론 보류", "en": "Inconclusive"}
	}
	var fixture_failures: Array = []
	for fixture_locale: String in ["ko", "en"]:
		main.language = fixture_locale
		for fixture_id: String in substantiation_fixtures:
			var fixture_result := {"conclusionAccurate": true, "substantiation": fixture_id, "independentSourceCount": 2}
			var fixture_verdict: String = main.case_resolution_verdict_text(fixture_result)
			var expected_fixture: String = String(substantiation_fixtures[fixture_id][fixture_locale])
			if not fixture_verdict.contains(expected_fixture) or fixture_verdict.contains(fixture_id):
				fixture_failures.append({"locale": fixture_locale, "id": fixture_id, "verdict": fixture_verdict, "expected": expected_fixture})
		var unknown_token := "UNAUTHORED_RESULT_CODE"
		var unknown_verdict: String = main.case_resolution_verdict_text({"conclusionAccurate": false, "substantiation": unknown_token, "independentSourceCount": 0})
		var expected_unknown := "검토 중" if fixture_locale == "ko" else "Pending review"
		if not unknown_verdict.contains(expected_unknown) or unknown_verdict.contains(unknown_token):
			fixture_failures.append({"locale": fixture_locale, "id": unknown_token, "verdict": unknown_verdict, "expected": expected_unknown})
	main.language = "en"
	record(
		"MVP-ILLUSTRATED-14",
		"Resolved dossier verdict localizes all three substantiation results in Korean and English without exposing runtime enums",
		bool(resolved_result.get("ok", false)) and not expected_substantiation_ko.is_empty() and resolved_copy_ko.contains(expected_substantiation_ko) and not expected_substantiation_en.is_empty() and resolved_copy_en.contains(expected_substantiation_en) and raw_substantiation_hidden and fixture_failures.is_empty(),
		{"substantiationId": substantiation_id, "ko": expected_substantiation_ko, "en": expected_substantiation_en, "rawHidden": raw_substantiation_hidden, "fixtureFailures": fixture_failures}
	)

	gs.reset_game()
	gs.persistence_enabled = false
	var repair_reachability_failures: Array = []
	for artifact_number: int in range(61, 81):
		var spec_id := "artifact_%03d" % artifact_number
		var repair_candidate: Dictionary = gs.new_artifact(spec_id, 700000 + artifact_number, "repair_reach_%03d" % artifact_number)
		var authored_faults: Array = repair_candidate.get("possibleFaults", []).duplicate()
		var runtime_repairables: Array = gs.repairable_damage_types(repair_candidate)
		var recommended_tools: Array = gs.repair_requirements(repair_candidate).get("requiredTools", [])
		if authored_faults.is_empty() or recommended_tools.is_empty() or not authored_faults.all(func(fault: Variant): return runtime_repairables.has(fault)):
			repair_reachability_failures.append({"spec": spec_id, "reason": "contract", "faults": authored_faults, "runtime": runtime_repairables, "tools": recommended_tools})
			continue
		repair_candidate.damageInstances = authored_faults.duplicate()
		gs.select_tool(String(recommended_tools[0]))
		var reachability_message: String = gs.repair(repair_candidate)
		var remaining_faults: Array = authored_faults.filter(func(fault: Variant): return repair_candidate.damageInstances.has(fault))
		if not remaining_faults.is_empty() or repair_candidate.damageInstances.has("SCRATCH") or not bool(repair_candidate.repaired) or reachability_message != "Mechanism repaired.":
			repair_reachability_failures.append({"spec": spec_id, "reason": "runtime", "remaining": remaining_faults, "damage": repair_candidate.damageInstances, "message": reachability_message, "tool": gs.selected_tool})
	record(
		"MVP-ILLUSTRATED-12",
		"All twenty expansion artifacts can repair every authored fault with any one recommended tool, including non-legacy damage families",
		repair_reachability_failures.is_empty(),
		{"artifactCount": 20, "failures": repair_reachability_failures, "artifact070Covered": true}
	)

	var passed := results.filter(func(result: Dictionary): return bool(result.passed)).size()
	var report := {"suite": "R3 Illustrated Case UI", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "skipped": 0, "tests": results}
	var output := FileAccess.open("res://qa/R3_ILLUSTRATED_CASE_UI_TESTS.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	main.queue_free()
	quit(0 if passed == results.size() else 1)
