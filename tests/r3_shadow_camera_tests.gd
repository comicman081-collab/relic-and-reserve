extends SceneTree

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, condition: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": condition, "evidence": evidence})


func begin_shadow_camera(gs: Node) -> Dictionary:
	gs.reset_game()
	gs.persistence_enabled = false
	gs.campaign_state.currentAct = "ACT_4"
	gs.campaign_state.activeCaseId = ""
	return gs.begin_case("shadow_camera")


func discover(gs: Node, evidence_id: String, tool_id: String = "") -> Dictionary:
	if not tool_id.is_empty():
		gs.select_tool(tool_id)
	return gs.discover_case_evidence("shadow_camera", evidence_id)


func discover_full_chain(gs: Node) -> Array:
	var discovered: Array = []
	var steps := [
		["src.shadow_camera.artifact.mount_wear", ""],
		["src.shadow_camera.artifact.uv_shadow_mark", "uv_lamp"],
		["src.shadow_camera.artifact.internal_spacer", "precision_screwdriver"],
		["src.shadow_camera.document.repair_leaf", ""],
		["src.shadow_camera.npc.lena_invoice_account", ""],
		["src.shadow_camera.reference.model147_material_note", "reference_database"]
	]
	for step: Array in steps:
		var result: Dictionary = discover(gs, step[0], step[1])
		if bool(result.get("ok", false)) and result.get("code", "") == "DISCOVERED":
			discovered.append(step[0])
	return discovered


func unique_count(values: Array) -> int:
	var seen := {}
	for value: Variant in values:
		seen[String(value)] = true
	return seen.size()


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.persistence_enabled = false
	var definition: Dictionary = registry.get_case_v2("shadow_camera")
	var raw_file := FileAccess.open("res://data/cases/authored_v2/shadow_camera.json", FileAccess.READ)
	var raw_definition: Dictionary = JSON.parse_string(raw_file.get_as_text()) if raw_file != null else {}
	if raw_file != null:
		raw_file.close()
	var raw_reliabilities: Array = raw_definition.get("sources", []).map(func(row: Dictionary): return row.get("reliability", ""))
	record(
		"M4-SC-DATA-01",
		"Shadow Camera authored-v2 loads with canonical runtime refs and explicit source reliability",
		registry.authored_case_errors.is_empty()
			and not definition.is_empty()
			and definition.get("hypotheses", []).size() == 3
			and definition.get("evidence", []).size() == 6
			and raw_reliabilities.all(func(value: String): return value in ["HIGH", "MEDIUM", "LOW"])
			and registry.document_to_cases.get("document_15", []).has("shadow_camera")
			and registry.npc_to_cases.get("lena_falk", []).has("shadow_camera")
			and registry.reference_to_cases.get("period_ref_15", []).has("shadow_camera"),
		{"errors": registry.authored_case_errors, "hypotheses": definition.get("hypotheses", []).size(), "evidence": definition.get("evidence", []).size(), "reliability": raw_reliabilities}
	)

	var artifact := begin_shadow_camera(gs)
	var initial_public: Dictionary = gs.get_case_public_state("shadow_camera")
	var initial_json := JSON.stringify(initial_public)
	var initial_ids: Array = initial_public.get("availableEvidence", []).map(func(row: Dictionary): return row.id)
	record(
		"M4-SC-PRIVACY-01",
		"Initial player state exposes the physical starting action and risk without leaking authored truth",
		not artifact.is_empty()
			and initial_ids.has("src.shadow_camera.artifact.mount_wear")
			and not initial_ids.has("src.shadow_camera.artifact.uv_shadow_mark")
			and not initial_json.contains("canonical_hypothesis")
			and not initial_json.contains("winning_hypothesis")
			and not initial_json.contains("authoring_truth")
			and not initial_json.contains("authenticityTruth"),
		{"available": initial_ids, "publicKeys": initial_public.keys()}
	)

	var uv_id := "src.shadow_camera.artifact.uv_shadow_mark"
	var internal_id := "src.shadow_camera.artifact.internal_spacer"
	var uv_before_mount: Dictionary = discover(gs, uv_id, "uv_lamp")
	record(
		"M4-SC-SEQUENCE-01",
		"The hidden UV observation is locked until the physical mount observation is recorded",
		not bool(uv_before_mount.get("ok", true)) and uv_before_mount.get("code", "") == "EVIDENCE_LOCKED",
		uv_before_mount
	)

	var integrity_start := float(artifact.historicalIntegrity)
	var mount_result: Dictionary = discover(gs, "src.shadow_camera.artifact.mount_wear")
	var integrity_after_low := float(artifact.historicalIntegrity)
	gs.select_tool("soft_brush")
	var uv_without_tool: Dictionary = gs.discover_case_evidence("shadow_camera", uv_id)
	record(
		"M4-SC-RISK-01",
		"LOW physical observation applies its disclosed consequence and the next hidden step requires the UV tool",
		bool(mount_result.get("ok", false))
			and mount_result.get("riskLevel", "") == "LOW"
			and is_equal_approx(integrity_after_low, integrity_start - 1.0)
			and not bool(uv_without_tool.get("ok", true))
			and uv_without_tool.get("code", "") == "TOOL_REQUIRED"
			and uv_without_tool.get("requiredTools", []).has("uv_lamp"),
		{"mount": mount_result, "integrityBefore": integrity_start, "integrityAfter": integrity_after_low, "uvWithoutTool": uv_without_tool}
	)

	var uv_result: Dictionary = discover(gs, uv_id, "uv_lamp")
	var integrity_after_high := float(artifact.historicalIntegrity)
	gs.select_tool("soft_brush")
	var internal_without_tool: Dictionary = gs.discover_case_evidence("shadow_camera", internal_id)
	record(
		"M4-SC-SEQUENCE-02",
		"HIGH-risk hidden UV capture unlocks the concealed internal observation, which requires precision disassembly",
		bool(uv_result.get("ok", false))
			and uv_result.get("riskLevel", "") == "HIGH"
			and is_equal_approx(integrity_after_high, integrity_after_low - 3.0)
			and not bool(internal_without_tool.get("ok", true))
			and internal_without_tool.get("code", "") == "TOOL_REQUIRED"
			and internal_without_tool.get("requiredTools", []).has("precision_screwdriver"),
		{"uv": uv_result, "integrityBefore": integrity_after_low, "integrityAfter": integrity_after_high, "internalWithoutTool": internal_without_tool}
	)

	var internal_result: Dictionary = discover(gs, internal_id, "precision_screwdriver")
	var integrity_after_internal := float(artifact.historicalIntegrity)
	record(
		"M4-SC-RISK-02",
		"Precision disassembly reveals the second hidden observation with its LOW pre-action risk",
		bool(internal_result.get("ok", false))
			and internal_result.get("riskLevel", "") == "LOW"
			and is_equal_approx(integrity_after_internal, integrity_after_high - 1.0),
		{"result": internal_result, "integrityBefore": integrity_after_high, "integrityAfter": integrity_after_internal}
	)

	artifact = begin_shadow_camera(gs)
	var discovered := discover_full_chain(gs)
	var complete_public: Dictionary = gs.get_case_public_state("shadow_camera")
	var kinds: Array = complete_public.get("discoveredEvidence", []).map(func(row: Dictionary): return row.sourceKind)
	var source_ids: Array = complete_public.get("discoveredEvidence", []).map(func(row: Dictionary): return row.sourceId)
	record(
		"M4-SC-LEDGER-01",
		"Sequential investigation joins physical, document, NPC, and reference corroboration across independent groups",
		discovered.size() == 6
			and ["ARTIFACT", "DOCUMENT", "NPC", "REFERENCE"].all(func(kind: String): return kinds.has(kind))
			and unique_count(source_ids) >= 6,
		{"discovered": discovered, "kinds": kinds, "sourceIds": source_ids}
	)

	var required_citations := [
		"src.shadow_camera.artifact.uv_shadow_mark",
		"src.shadow_camera.artifact.internal_spacer",
		"src.shadow_camera.document.repair_leaf",
		"src.shadow_camera.reference.model147_material_note"
	]
	var masterful: Dictionary = gs.resolve_case_v2("shadow_camera", "hyp.late_composite", required_citations)
	record(
		"M4-SC-REPORT-01",
		"Four-source cross-validation earns a masterful accurate report while distinguishing the genuine body from later additions",
		bool(masterful.get("ok", false))
			and bool(masterful.get("conclusionAccurate", false))
			and bool(masterful.get("substantiated", false))
			and masterful.get("outcome", "") == "masterful"
			and int(masterful.get("independentSourceCount", 0)) >= 4
			and bool(masterful.get("requiredSourcesMet", false)),
		masterful
	)

	artifact = begin_shadow_camera(gs)
	discover_full_chain(gs)
	var refuted: Dictionary = gs.evaluate_case_submission(
		"shadow_camera",
		"hyp.factory_shadow_camera",
		[
			"src.shadow_camera.artifact.uv_shadow_mark",
			"src.shadow_camera.artifact.internal_spacer",
			"src.shadow_camera.document.repair_leaf",
			"src.shadow_camera.reference.model147_material_note"
		]
	)
	record(
		"M4-SC-REPORT-02",
		"The same ledger explicitly refutes the dramatic factory-prototype claim instead of merely supporting the canonical answer",
		bool(refuted.get("ok", false))
			and not bool(refuted.get("conclusionAccurate", true))
			and int(refuted.get("refuteScore", 0)) > int(refuted.get("supportScore", 0))
			and refuted.get("outcome", "") == "mistaken",
		refuted
	)

	var game_state_source := FileAccess.get_file_as_string("res://scripts/game_state.gd")
	record(
		"M4-SC-GENERIC-01",
		"Shadow Camera behavior is data-driven with no case-id branch in gameplay state code",
		not game_state_source.contains("shadow_camera"),
		{"containsCaseId": game_state_source.contains("shadow_camera")}
	)

	var passed := 0
	for result: Dictionary in results:
		if result.passed:
			passed += 1
	var report := {"suite": "R3 Shadow Camera Authored Case", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "skipped": 0, "tests": results}
	var output := FileAccess.open("res://qa/R3_SHADOW_CAMERA_TESTS.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	quit(0 if passed == results.size() else 1)
