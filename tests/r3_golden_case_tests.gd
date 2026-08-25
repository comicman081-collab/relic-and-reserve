extends SceneTree

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, condition: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": condition, "evidence": evidence})


func begin_prologue(gs: Node) -> Dictionary:
	gs.reset_game()
	gs.persistence_enabled = false
	return gs.begin_case("prologue_clock")


func discover_all(gs: Node, case_id: String) -> Array:
	var discoveries: Array = []
	for _pass in range(12):
		var public_state: Dictionary = gs.get_case_public_state(case_id)
		var progressed := false
		for row: Dictionary in public_state.get("availableEvidence", []):
			if not row.get("requiredTools", []).is_empty():
				gs.select_tool(String(row.requiredTools[0]))
			var result: Dictionary = gs.discover_case_evidence(case_id, row.id)
			if bool(result.get("ok", false)) and result.get("code", "") == "DISCOVERED":
				discoveries.append(row.id)
				progressed = true
		if not progressed:
			break
	return discoveries


func collect_buttons(root: Node, output: Array) -> void:
	if root is Button:
		output.append(root)
	for child: Node in root.get_children():
		collect_buttons(child, output)


func find_button_prefix(root: Node, prefix: String) -> Button:
	var buttons: Array = []
	collect_buttons(root, buttons)
	for child: Button in buttons:
		if child.name.begins_with(prefix):
			return child
	return null


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.persistence_enabled = false
	var definition: Dictionary = registry.get_case_v2("prologue_clock")
	record(
		"M2-DATA-01",
		"Protected authored-v2 Prologue loads with valid runtime source indexes",
		registry.authored_case_errors.is_empty()
			and not definition.is_empty()
			and int(definition.get("schema_version", 0)) == 2
			and definition.get("hypotheses", []).size() == 3
			and definition.get("evidence", []).size() == 5
			and registry.document_to_cases.get("document_01", []).has("prologue_clock")
			and registry.npc_to_cases.get("mara_venn", []).has("prologue_clock")
			and registry.reference_to_cases.get("period_ref_01", []).has("prologue_clock"),
		{"errors": registry.authored_case_errors, "hypotheses": definition.get("hypotheses", []).size(), "evidence": definition.get("evidence", []).size()}
	)

	var artifact := begin_prologue(gs)
	var initial_public: Dictionary = gs.get_case_public_state("prologue_clock")
	var public_json := JSON.stringify(initial_public)
	record(
		"M2-PRIVACY-01",
		"Player case state excludes canonical answer and hidden valuation fields",
		not artifact.is_empty()
			and not public_json.contains("canonical_hypothesis")
			and not public_json.contains("winning_hypothesis")
			and not public_json.contains("authoring_truth")
			and not public_json.contains("authenticityTruth")
			and not public_json.contains("trueMarket"),
		initial_public.keys()
	)

	var high_risk_id := ""
	for row: Dictionary in initial_public.get("availableEvidence", []):
		if row.get("riskLevel", "NONE") == "HIGH":
			high_risk_id = row.id
	var integrity_before := float(artifact.historicalIntegrity)
	var risk_result: Dictionary = gs.discover_case_evidence("prologue_clock", high_risk_id) if not high_risk_id.is_empty() else {}
	record(
		"M2-RISK-01",
		"Risk is public before action and the warned investigation applies its authored consequence",
		not high_risk_id.is_empty()
			and bool(risk_result.get("ok", false))
			and float(artifact.historicalIntegrity) < integrity_before,
		{"evidenceId": high_risk_id, "before": integrity_before, "after": artifact.historicalIntegrity, "result": risk_result}
	)

	var locked_document_id := "src.prologue.document.service_card"
	var locked_before := begin_prologue(gs)
	var locked_result: Dictionary = gs.discover_case_evidence("prologue_clock", locked_document_id)
	record(
		"M2-UNLOCK-01",
		"Cross-source document discovery is locked until its physical prerequisite is recorded",
		not locked_before.is_empty() and not bool(locked_result.get("ok", true)) and locked_result.get("code", "") == "EVIDENCE_LOCKED",
		locked_result
	)

	artifact = begin_prologue(gs)
	var discoveries := discover_all(gs, "prologue_clock")
	var complete_public: Dictionary = gs.get_case_public_state("prologue_clock")
	record(
		"M2-LEDGER-01",
		"Golden Case discovers artifact, document, NPC, and reference evidence into a persistent ledger",
		discoveries.size() == 5
			and complete_public.get("discoveredEvidence", []).size() == 5
			and ["ARTIFACT", "DOCUMENT", "NPC", "REFERENCE"].all(func(kind: String): return complete_public.discoveredEvidence.any(func(row: Dictionary): return row.sourceKind == kind)),
		{"discoveries": discoveries, "sources": complete_public.get("discoveredEvidence", []).map(func(row: Dictionary): return row.sourceKind)}
	)

	var masterful_citations := [
		"src.prologue.artifact.backplate_screws",
		"src.prologue.artifact.bridge_stamp",
		"src.prologue.document.service_card"
	]
	var masterful: Dictionary = gs.resolve_case_v2("prologue_clock", "hyp.period_repair", masterful_citations)
	record(
		"M2-REPORT-01",
		"Correct conclusion with required independent evidence earns masterful substantiation",
		bool(masterful.get("ok", false))
			and bool(masterful.get("conclusionAccurate", false))
			and bool(masterful.get("substantiated", false))
			and masterful.get("outcome", "") == "masterful"
			and int(masterful.get("independentSourceCount", 0)) >= 3,
		masterful
	)

	artifact = begin_prologue(gs)
	gs.discover_case_evidence("prologue_clock", "src.prologue.artifact.backplate_screws")
	gs.discover_case_evidence("prologue_clock", "src.prologue.document.service_card")
	var credible: Dictionary = gs.resolve_case_v2("prologue_clock", "hyp.period_repair", ["src.prologue.artifact.backplate_screws", "src.prologue.document.service_card"])
	record(
		"M2-REPORT-02",
		"Correct conclusion with thinner evidence stays credible rather than masterful",
		bool(credible.get("ok", false))
			and bool(credible.get("conclusionAccurate", false))
			and not bool(credible.get("substantiated", true))
			and credible.get("outcome", "") == "credible",
		credible
	)

	artifact = begin_prologue(gs)
	discover_all(gs, "prologue_clock")
	var wrong: Dictionary = gs.resolve_case_v2("prologue_clock", "hyp.untouched_original", ["src.prologue.artifact.bridge_stamp"])
	record(
		"M2-REPORT-03",
		"One-citation wrong claim reaches the authored mentor fallback; mistaken requires two cited findings",
		bool(wrong.get("ok", false))
			and not bool(wrong.get("conclusionAccurate", true))
			and wrong.get("substantiation", "") == "INCONCLUSIVE"
			and not bool(wrong.get("substantiated", true))
			and wrong.get("outcome", "") == "reviewed_with_mentor"
			and wrong.get("citedEvidenceIds", []).size() == 1,
		wrong
	)

	artifact = begin_prologue(gs)
	gs.persistence_enabled = true
	gs.discover_case_evidence("prologue_clock", "src.prologue.artifact.backplate_screws")
	gs.set_case_hypothesis("prologue_clock", "hyp.period_repair")
	gs.toggle_case_citation("prologue_clock", "src.prologue.artifact.backplate_screws")
	var save_path := "res://qa/r3_golden_case_save.json"
	gs.remove_save_file(save_path)
	gs.remove_save_file(save_path + gs.SAVE_TEMP_SUFFIX)
	gs.remove_save_file(save_path + gs.SAVE_BACKUP_SUFFIX)
	var saved: bool = bool(gs.save_game(save_path))
	gs.campaign_state = gs.default_campaign_state()
	gs.inventory = []
	var loaded: bool = bool(gs.load_game(save_path))
	var restored_public: Dictionary = gs.get_case_public_state("prologue_clock")
	record(
		"M2-SAVE-01",
		"Evidence ledger, hypothesis, citations, and issued artifact identity survive save/reload",
		saved and loaded
			and restored_public.get("discoveredEvidence", []).size() == 1
			and restored_public.get("selectedHypothesisId", "") == "hyp.period_repair"
			and restored_public.get("citedEvidenceIds", []).has("src.prologue.artifact.backplate_screws")
			and not gs.find_case_artifact("prologue_clock").is_empty(),
		{"saved": saved, "loaded": loaded, "public": restored_public}
	)

	gs.persistence_enabled = false
	artifact = begin_prologue(gs)
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.selected = artifact
	main.load_artifact(artifact)
	main.show_case_dossier("prologue_clock")
	await process_frame
	var evidence_button := find_button_prefix(main, "CaseEvidence_")
	var report_button := find_button_prefix(main, "ResolveCaseReport")
	var ui_buttons: Array = []
	collect_buttons(main, ui_buttons)
	var evidence_button_present: bool = evidence_button != null
	var report_button_present: bool = report_button != null
	var button_names: Array = ui_buttons.map(func(button: Button): return String(button.name))
	var warning_visible := false
	for label: Node in main.find_children("*", "Label", true, false):
		if String(label.text).contains("Photograph") or String(label.text).contains("촬영"):
			warning_visible = true
	var screen_before: String = main.screen
	main.toggle_language()
	await process_frame
	record(
		"M2-UI-01",
		"Case dossier exposes evidence actions, pre-action risk, report control, and survives locale refresh",
		evidence_button_present and report_button_present and warning_visible and screen_before == "case_dossier" and main.screen == "case_dossier",
		{"evidenceButton": evidence_button_present, "reportButton": report_button_present, "warning": warning_visible, "screen": main.screen, "buttons": button_names}
	)
	main.queue_free()

	var passed := 0
	for result: Dictionary in results:
		if result.passed:
			passed += 1
	var report := {"suite": "R3 Prologue Golden Case", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "skipped": 0, "tests": results}
	var output := FileAccess.open("res://qa/R3_GOLDEN_CASE_TESTS.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	quit(0 if passed == results.size() else 1)
