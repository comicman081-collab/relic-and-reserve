extends SceneTree

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func prefix(gs: Node) -> Array:
	return gs.player_profile.get("tutorialCompletedSteps", []).duplicate()


func run_prefix(gs: Node) -> Array:
	return gs.stage_run_state.get("tutorialCompletedSteps", []).duplicate()


func first_open_evidence(definition: Dictionary) -> String:
	for evidence_value: Variant in definition.get("evidence", []):
		var evidence: Dictionary = evidence_value
		if evidence.get("unlock", {}).get("requires_all", []).is_empty() and evidence.get("unlock", {}).get("requires_tools", []).is_empty():
			return String(evidence.get("id", ""))
	return ""


func reload_committed_run_with_stale_profile(gs: Node, payload: Dictionary, stale_prefix: Array, expected_prefix: Array) -> Dictionary:
	var stale_profile: Dictionary = gs.player_profile.duplicate(true)
	stale_profile.tutorialCompletedSteps = stale_prefix.duplicate()
	gs.player_profile = stale_profile
	# Replace transient memory markers so success must come from the payload and
	# its run-authoritative mirror, not from the just-completed action in memory.
	gs.current_stage = 2
	gs.stage_run_state = gs.default_stage_run_state(2)
	gs.inventory = []
	var validation: Dictionary = gs.validate_save_payload(payload)
	var applied: bool = gs.apply_save_data(payload)
	return {
		"ok": bool(validation.get("ok", false)) and applied and prefix(gs) == expected_prefix and run_prefix(gs) == expected_prefix,
		"validation": validation,
		"applied": applied,
		"profile": prefix(gs),
		"run": run_prefix(gs),
		"public": gs.tutorial_public_state()
	}


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.persistence_enabled = false
	gs.player_profile = gs.default_player_profile()
	var started: Dictionary = gs.new_game(1)
	var artifact: Dictionary = gs.begin_case("prologue_clock")
	var artifact_id := String(artifact.get("uniqueId", ""))
	var definition: Dictionary = gs.case_definition("prologue_clock")
	var evidence_id := first_open_evidence(definition)
	var expected_steps := ["INVESTIGATE", "CITE", "REPORT", "REPAIR", "LIST", "AUCTION"]

	var before_discover := prefix(gs)
	var discovered: Dictionary = gs.discover_case_evidence("prologue_clock", evidence_id)
	var discover_payload: Dictionary = gs.save_payload()
	var discover_reload := reload_committed_run_with_stale_profile(gs, discover_payload, before_discover, expected_steps.slice(0, 1))
	var discover_ok: bool = bool(started.get("ok", false)) and not artifact_id.is_empty() and not evidence_id.is_empty() and bool(discovered.get("ok", false)) and bool(discover_reload.ok) and int(discover_reload.public.get("step", 0)) == 2
	record(
		"TUTORIAL-TX-DISCOVER",
		"A committed evidence discovery restores its run tutorial prefix when the profile write was interrupted",
		discover_ok,
		{"action": discovered, "reload": discover_reload}
	)

	var before_cite := prefix(gs)
	var cited: bool = gs.toggle_case_citation("prologue_clock", evidence_id)
	var cite_payload: Dictionary = gs.save_payload()
	var cite_reload := reload_committed_run_with_stale_profile(gs, cite_payload, before_cite, expected_steps.slice(0, 2))
	var cited_state: Dictionary = gs.ensure_case_runtime_state("prologue_clock")
	var cite_ok: bool = cited and bool(cite_reload.ok) and cited_state.get("citedEvidenceIds", []).has(evidence_id) and int(cite_reload.public.get("step", 0)) == 3
	record(
		"TUTORIAL-TX-CITE",
		"A committed citation and its tutorial prefix survive an interrupted profile update without asking for the citation again",
		cite_ok,
		{"cited": cited, "reload": cite_reload, "citedEvidenceIds": cited_state.get("citedEvidenceIds", [])}
	)

	var before_report := prefix(gs)
	var resolved: Dictionary = gs.resolve_case_v2("prologue_clock", String(definition.get("canonical_hypothesis_id", "")), [evidence_id])
	var report_payload: Dictionary = gs.save_payload()
	var report_reload := reload_committed_run_with_stale_profile(gs, report_payload, before_report, expected_steps.slice(0, 3))
	var report_artifact: Dictionary = gs.find_inventory_instance(artifact_id)
	var report_ok: bool = bool(resolved.get("ok", false)) and bool(report_reload.ok) and gs.campaign_state.completedCases.has("prologue_clock") and bool(report_artifact.get("caseResolved", false)) and int(report_reload.public.get("step", 0)) == 4
	record(
		"TUTORIAL-TX-REPORT",
		"A resolved case report and its run prefix reload together before profile reconciliation",
		report_ok,
		{"result": resolved, "reload": report_reload, "caseCompleted": gs.campaign_state.completedCases.has("prologue_clock")}
	)

	var before_repair := prefix(gs)
	var selected_tool: bool = gs.select_tool("precision_screwdriver")
	var repaired_message: String = gs.repair(report_artifact)
	var repair_payload: Dictionary = gs.save_payload()
	var repair_reload := reload_committed_run_with_stale_profile(gs, repair_payload, before_repair, expected_steps.slice(0, 4))
	var repaired_artifact: Dictionary = gs.find_inventory_instance(artifact_id)
	var repair_ok: bool = selected_tool and repaired_message == "Mechanism repaired." and bool(repair_reload.ok) and bool(repaired_artifact.get("repaired", false)) and not repaired_artifact.get("damageInstances", []).has("CRACK") and int(repair_reload.public.get("step", 0)) == 5
	record(
		"TUTORIAL-TX-REPAIR",
		"A saved repair with an older profile reloads as repaired and advances guidance instead of requesting an impossible repeat repair",
		repair_ok,
		{"message": repaired_message, "reload": repair_reload, "repaired": repaired_artifact.get("repaired", false), "damages": repaired_artifact.get("damageInstances", [])}
	)

	var before_list := prefix(gs)
	var listed: bool = gs.list_auction(repaired_artifact, 10, 20, float(repaired_artifact.get("confidence", 0.0)), "LIKELY")
	var list_payload: Dictionary = gs.save_payload()
	var list_reload := reload_committed_run_with_stale_profile(gs, list_payload, before_list, expected_steps.slice(0, 5))
	var listed_artifact: Dictionary = gs.find_inventory_instance(artifact_id)
	var list_ok: bool = listed and bool(list_reload.ok) and int(listed_artifact.get("listing", {}).get("starting", 0)) == 10 and int(listed_artifact.get("listing", {}).get("reserve", 0)) == 20 and int(list_reload.public.get("step", 0)) == 6
	record(
		"TUTORIAL-TX-LIST",
		"A committed listing and its run prefix survive an older profile without relisting the artifact",
		list_ok,
		{"listed": listed, "reload": list_reload, "listing": listed_artifact.get("listing", {})}
	)

	var before_sale := prefix(gs)
	# Exercise the authoritative public auction boundary. Calling
	# apply_sale_result directly would bypass listing telemetry and produce a v6
	# payload whose auction count has no matching listing event.
	var pending_sale: Dictionary = gs.create_pending_auction(listed_artifact)
	var sale_result: Dictionary = gs.commit_pending_auction(String(pending_sale.get("transactionId", ""))) \
		if bool(pending_sale.get("ok", false)) else {"ok": false, "code": "PENDING_CREATE_FAILED"}
	var sale_payload: Dictionary = gs.save_payload()
	var sale_reload := reload_committed_run_with_stale_profile(gs, sale_payload, before_sale, expected_steps)
	var sold_absent: bool = gs.find_inventory_instance(artifact_id).is_empty()
	var sale_recorded: bool = not gs.auction_history.is_empty() and String(gs.auction_history[-1].get("status", "")) == "SOLD" and gs.transactions.any(func(row: Dictionary): return String(row.get("instanceId", "")) == artifact_id and String(row.get("type", "")) == "sale")
	var sale_ok: bool = bool(pending_sale.get("ok", false)) and bool(sale_result.get("reserve_met", false)) \
		and bool(sale_reload.ok) and sold_absent and sale_recorded \
		and not bool(sale_reload.public.get("visible", true)) and int(sale_reload.public.get("step", 0)) == 6
	record(
		"TUTORIAL-TX-SOLD",
		"A public pending-auction SOLD commit reloads with matching v6 telemetry and completes guidance instead of requesting another auction",
		sale_ok,
		{"pending": pending_sale, "result": sale_result, "reload": sale_reload, "soldAbsent": sold_absent, "saleRecorded": sale_recorded, "history": gs.auction_history[-1] if not gs.auction_history.is_empty() else {}}
	)

	# A present malformed mirror is authoritative but safe: it truncates to the
	# exact authored prefix and clamps a stale longer profile. An absent mirror is
	# a legacy v5 save and is seeded once from the durable profile.
	gs.player_profile = gs.default_player_profile()
	gs.new_game(1)
	var base_payload: Dictionary = gs.save_payload()
	var full_prefix: Array = expected_steps.duplicate()
	var malformed_cases := [
		{"value": "REPORT", "expected": []},
		{"value": ["CITE", "INVESTIGATE"], "expected": []},
		{"value": ["INVESTIGATE", "REPORT", "CITE"], "expected": ["INVESTIGATE"]},
		{"value": ["INVESTIGATE", "INVESTIGATE"], "expected": ["INVESTIGATE"]},
		{"value": ["UNKNOWN"], "expected": []}
	]
	var malformed_results: Array = []
	var malformed_ok := true
	for malformed: Dictionary in malformed_cases:
		var malformed_payload: Dictionary = base_payload.duplicate(true)
		malformed_payload.stageRunState.tutorialCompletedSteps = malformed.value
		gs.player_profile = gs.default_player_profile()
		gs.player_profile.tutorialCompletedSteps = full_prefix.duplicate()
		var validation: Dictionary = gs.validate_save_payload(malformed_payload)
		var applied: bool = gs.apply_save_data(malformed_payload)
		var expected: Array = malformed.expected
		var case_ok: bool = bool(validation.get("ok", false)) and applied and prefix(gs) == expected and run_prefix(gs) == expected
		malformed_ok = malformed_ok and case_ok
		malformed_results.append({"input": malformed.value, "expected": expected, "profile": prefix(gs), "run": run_prefix(gs), "ok": case_ok})
	var legacy_payload: Dictionary = base_payload.duplicate(true)
	legacy_payload.stageRunState.erase("tutorialCompletedSteps")
	gs.player_profile = gs.default_player_profile()
	gs.player_profile.tutorialCompletedSteps = ["INVESTIGATE", "CITE"]
	var legacy_valid: Dictionary = gs.validate_save_payload(legacy_payload)
	var legacy_applied: bool = gs.apply_save_data(legacy_payload)
	var legacy_ok: bool = bool(legacy_valid.get("ok", false)) and legacy_applied and prefix(gs) == ["INVESTIGATE", "CITE"] and run_prefix(gs) == ["INVESTIGATE", "CITE"] and int(gs.tutorial_public_state().get("step", 0)) == 3
	record(
		"TUTORIAL-TX-NORMALIZE",
		"Malformed run mirrors truncate safely, stale profiles cannot skip actions, and legacy saves without a mirror seed from their valid profile",
		malformed_ok and legacy_ok,
		{"malformed": malformed_results, "legacy": {"validation": legacy_valid, "applied": legacy_applied, "profile": prefix(gs), "run": run_prefix(gs), "public": gs.tutorial_public_state()}}
	)

	# Generic edge: if REPORT is the final scoped case, advance the mirror before
	# maybe_case_complete_and_unlock changes RUNNING to CLEARED.
	gs.player_profile = gs.default_player_profile()
	gs.new_game(1)
	var stage_one_cases: Array = registry.get_stage_definition(1).get("case_ids", [])
	var final_case_id := String(stage_one_cases[-1])
	for case_index in range(stage_one_cases.size() - 1):
		var completed_case_id := String(stage_one_cases[case_index])
		gs.campaign_state.completedCases[completed_case_id] = true
		gs.campaign_state.caseOutcomes[completed_case_id] = "credible"
	gs.campaign_state.currentAct = String(registry.get_case(final_case_id).get("act", "PROLOGUE"))
	gs.campaign_state.activeCaseId = ""
	var final_artifact: Dictionary = gs.begin_case(final_case_id)
	var final_definition: Dictionary = gs.case_definition(final_case_id)
	var final_evidence_id := first_open_evidence(final_definition)
	var final_discovered: Dictionary = gs.discover_case_evidence(final_case_id, final_evidence_id)
	var final_cited: bool = gs.toggle_case_citation(final_case_id, final_evidence_id)
	var prefix_before_final_report := prefix(gs)
	var final_resolved: Dictionary = gs.resolve_case_v2(final_case_id, String(final_definition.get("canonical_hypothesis_id", "")), [final_evidence_id])
	var final_payload: Dictionary = gs.save_payload()
	var final_reload := reload_committed_run_with_stale_profile(gs, final_payload, prefix_before_final_report, expected_steps.slice(0, 3))
	var final_edge_ok: bool = not final_artifact.is_empty() and bool(final_discovered.get("ok", false)) and final_cited and bool(final_resolved.get("ok", false)) and String(gs.stage_run_state.get("status", "")) == "CLEARED" and bool(final_reload.ok) and prefix(gs) == expected_steps.slice(0, 3) and run_prefix(gs) == expected_steps.slice(0, 3)
	record(
		"TUTORIAL-TX-FINAL-REPORT",
		"A final scoped-case report advances the run mirror before Stage Clear and still reconciles an interrupted profile",
		final_edge_ok,
		{"caseId": final_case_id, "discovered": final_discovered, "cited": final_cited, "resolved": final_resolved, "status": gs.stage_run_state.get("status", ""), "reload": final_reload}
	)

	var passed := results.filter(func(result: Dictionary): return bool(result.passed)).size()
	var report := {"suite": "R3 Tutorial Run/Profile Crash Recovery", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "skipped": 0, "tests": results}
	var output := FileAccess.open("res://qa/R3_TUTORIAL_CRASH_RECOVERY_TESTS.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	quit(0 if passed == results.size() else 1)
