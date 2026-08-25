extends SceneTree

## Public Stage Clear replay-feedback contract. Headless fixtures only.

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func approx_equal(left: float, right: float, epsilon: float = 0.0001) -> bool:
	return absf(left - right) <= epsilon


func append_stage_fixture(gs: Node, registry: Node, stage_id: int) -> Dictionary:
	var by_case := {}
	var stage: Dictionary = registry.get_stage_definition(stage_id)
	var introduced: Array = stage.get("introduced_artifact_ids", [])
	var index := 0
	for case_value: Variant in stage.get("case_ids", []):
		var case_id := String(case_value)
		var story_case: Dictionary = registry.get_case(case_id)
		var spec_id := String(story_case.get("rewardSpecId", ""))
		if spec_id.is_empty() and not introduced.is_empty():
			spec_id = String(introduced[index % introduced.size()])
		var artifact: Dictionary = gs.new_artifact(spec_id, 730000 + stage_id * 100 + index, "feedback_s%02d_%02d" % [stage_id, index])
		artifact.caseId = case_id
		artifact.caseResolved = true
		gs.inventory.append(artifact)
		gs.campaign_state.caseArtifactLedger[case_id] = {
			"issued": true, "artifactUid": artifact.uniqueId,
			"disposition": "INVENTORY", "saleTransactionId": "",
			"publicConditionSnapshot": {}, "publicAppraisalSnapshot": 0
		}
		gs.campaign_state.caseStates[case_id] = gs.default_case_runtime_state()
		by_case[case_id] = artifact
		index += 1
	return by_case


func seed_stage_fixture(gs: Node, registry: Node, stage_id: int = 1) -> Dictionary:
	gs.reset_game()
	gs.current_stage = stage_id
	gs.stage_run_state = gs.default_stage_run_state(stage_id)
	gs.stage_run_state.status = "RUNNING"
	var cases: Array = registry.get_stage_definition(stage_id).get("case_ids", [])
	if not cases.is_empty():
		gs.campaign_state.currentAct = String(registry.get_case(String(cases[0])).get("act", "PROLOGUE"))
	return append_stage_fixture(gs, registry, stage_id)


func evidence_ids(definition: Dictionary) -> Array:
	var ids: Array = []
	for row_value: Variant in definition.get("evidence", []):
		var row: Dictionary = row_value
		var row_id := String(row.get("id", ""))
		if not row_id.is_empty() and not ids.has(row_id):
			ids.append(row_id)
	return ids


func independent_citation_ids(definition: Dictionary) -> Array:
	var ids: Array = []
	var groups := {}
	var required := int(definition.get("resolution", {}).get("strong_min_independent_support", 0))
	for row_value: Variant in definition.get("evidence", []):
		var row: Dictionary = row_value
		var row_id := String(row.get("id", ""))
		var group_id := String(row.get("independence_key", ""))
		if row_id.is_empty() or group_id.is_empty() or groups.has(group_id):
			continue
		groups[group_id] = true
		ids.append(row_id)
		if ids.size() >= required:
			break
	return ids


func set_investigation(gs: Node, registry: Node, stage_id: int, mode: String) -> void:
	for case_value: Variant in registry.get_stage_definition(stage_id).get("case_ids", []):
		var case_id := String(case_value)
		var definition: Dictionary = gs.case_definition(case_id)
		var state: Dictionary = gs.ensure_case_runtime_state(case_id)
		state.discoveredEvidenceIds = evidence_ids(definition) if mode in ["DISCOVERY", "FULL"] else []
		state.citedEvidenceIds = independent_citation_ids(definition) if mode in ["CITATION", "FULL"] else []


func axis(feedback: Dictionary, axis_id: String) -> Dictionary:
	return feedback.get("axes", {}).get(axis_id, {})


func public_shape_ok(feedback: Dictionary) -> bool:
	if feedback.size() != 4 or not feedback.has_all(["stage", "axes", "weakest", "adviceCode"]):
		return false
	var axes: Dictionary = feedback.get("axes", {})
	if axes.size() != 3 or not axes.has_all(["investigation", "preservation", "sale"]):
		return false
	for axis_id: String in ["investigation", "preservation", "sale"]:
		var row: Dictionary = axes.get(axis_id, {})
		if row.size() != 3 or not row.has_all(["value", "available", "statusCode"]):
			return false
		if not String(row.get("statusCode", "")) in ["STRONG", "STEADY", "FRAGILE", "UNAVAILABLE", "NO_ATTEMPTS"]:
			return false
	var serialized := JSON.stringify(feedback).to_lower()
	for forbidden: String in ["authenticitytruth", "truerarity", "truehistoricalsignificance", "originalparts", "replacementparts", "basevalue", "artifactuid", "caseid", "evidenceids", "publicappraisal", "reserve"]:
		if serialized.contains(forbidden):
			return false
	return true


func sale_history(uid: String, sold: bool, net: int, appraisal: int = 100, reserve: int = 999) -> Dictionary:
	return {
		"instanceId": uid, "status": "SOLD" if sold else "NO_SALE",
		"publicAppraisal": appraisal,
		"result": {"reserve_met": sold, "net": net, "reserve": reserve}
	}


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.persistence_enabled = false
	gs.player_profile = gs.default_player_profile()

	# Data gate: all 26 scoped cases have a positive satisfiable denominator;
	# the complete authored artifact registry remains exactly 80 specs.
	var scoped_cases := {}
	var invalid_cases: Array = []
	for stage_id in range(1, 11):
		for case_value: Variant in registry.get_stage_definition(stage_id).get("case_ids", []):
			var case_id := String(case_value)
			scoped_cases[case_id] = true
			var definition: Dictionary = gs.case_definition(case_id)
			var required := int(definition.get("resolution", {}).get("strong_min_independent_support", 0))
			var citations: Array = independent_citation_ids(definition)
			if required <= 0 or definition.get("evidence", []).is_empty() or citations.size() < required:
				invalid_cases.append({"case": case_id, "required": required, "groups": citations.size()})
	record("STAGE-FEEDBACK-DATA-01", "All staged cases author valid independent support and all 80 ArtifactSpecs remain registered", registry.specs.size() == 80 and scoped_cases.size() == 26 and invalid_cases.is_empty(), {"specs": registry.specs.size(), "cases": scoped_cases.size(), "invalid": invalid_cases})

	var artifacts: Dictionary = seed_stage_fixture(gs, registry, 1)
	var authority_before := {"stage": gs.current_stage, "run": gs.stage_run_state.duplicate(true), "profile": gs.player_profile.duplicate(true), "completed": gs.campaign_state.completedCases.duplicate(true)}
	var initial: Dictionary = gs.stage_replay_feedback()
	var authority_after := {"stage": gs.current_stage, "run": gs.stage_run_state.duplicate(true), "profile": gs.player_profile.duplicate(true), "completed": gs.campaign_state.completedCases.duplicate(true)}
	var initial_sale: Dictionary = axis(initial, "sale")
	record("STAGE-FEEDBACK-PUBLIC-01", "Compact feedback is public-only, advisory-only, and attempts=0 excludes Sale from weakest", public_shape_ok(initial) and authority_before == authority_after and initial_sale.get("value", 1) == null and not bool(initial_sale.get("available", true)) and String(initial_sale.get("statusCode", "")) == "NO_ATTEMPTS" and String(initial.get("weakest", "")) != "sale" and gs.stage_replay_feedback(99).is_empty(), {"feedback": initial, "authorityUnchanged": authority_before == authority_after})

	set_investigation(gs, registry, 1, "NONE")
	var inv_none := float(axis(gs.stage_replay_feedback(), "investigation").get("value", -1.0))
	set_investigation(gs, registry, 1, "DISCOVERY")
	var inv_discovery := float(axis(gs.stage_replay_feedback(), "investigation").get("value", -1.0))
	set_investigation(gs, registry, 1, "CITATION")
	var inv_citation := float(axis(gs.stage_replay_feedback(), "investigation").get("value", -1.0))
	set_investigation(gs, registry, 1, "FULL")
	var inv_full := float(axis(gs.stage_replay_feedback(), "investigation").get("value", -1.0))
	var first_case := String(registry.get_stage_definition(1).get("case_ids", [""])[0])
	var first_state: Dictionary = gs.ensure_case_runtime_state(first_case)
	first_state.discoveredEvidenceIds.append_array(first_state.discoveredEvidenceIds.duplicate())
	var inv_duplicate := float(axis(gs.stage_replay_feedback(), "investigation").get("value", -1.0))
	record("STAGE-FEEDBACK-INVESTIGATION-01", "Investigation is exactly 35% unique discovery plus 65% independent citation", approx_equal(inv_none, 0.0) and approx_equal(inv_discovery, 35.0) and approx_equal(inv_citation, 65.0) and approx_equal(inv_full, 100.0) and approx_equal(inv_duplicate, 100.0) and inv_citation > inv_discovery, {"none": inv_none, "discovery": inv_discovery, "citation": inv_citation, "full": inv_full, "duplicate": inv_duplicate})

	var authored_original: Dictionary = registry.authored_cases_v2.get("prologue_clock", {}).duplicate(true)
	registry.authored_cases_v2["prologue_clock"].resolution.strong_min_independent_support = 0
	var malformed: Dictionary = gs.stage_replay_feedback()
	registry.authored_cases_v2["prologue_clock"] = authored_original
	var malformed_inv: Dictionary = axis(malformed, "investigation")
	record("STAGE-FEEDBACK-INVESTIGATION-02", "Non-positive independent support fails closed without driving weakest advice", not bool(malformed_inv.get("available", true)) and String(malformed_inv.get("statusCode", "")) == "UNAVAILABLE" and String(malformed.get("weakest", "")) != "investigation", malformed)

	artifacts = seed_stage_fixture(gs, registry, 1)
	var preservation_base := float(axis(gs.stage_replay_feedback(), "preservation").get("value", -1.0))
	var preservation_expected_total := 0.0
	for artifact_value: Variant in artifacts.values():
		var public_artifact: Dictionary = artifact_value
		var visible_mean := (float(public_artifact.surfaceCondition) + float(public_artifact.structuralCondition) + float(public_artifact.mechanicalCondition)) / 3.0
		preservation_expected_total += 0.65 * float(public_artifact.historicalIntegrity) + 0.35 * visible_mean
	var preservation_expected := preservation_expected_total / float(artifacts.size())
	var preservation_artifact: Dictionary = artifacts[String(artifacts.keys()[0])]
	for key: String in ["historicalIntegrity", "surfaceCondition", "structuralCondition", "mechanicalCondition"]:
		preservation_artifact[key] = 0.0
	var preservation_low := float(axis(gs.stage_replay_feedback(), "preservation").get("value", -1.0))
	for key: String in ["historicalIntegrity", "surfaceCondition", "structuralCondition", "mechanicalCondition"]:
		preservation_artifact[key] = 100.0
	var preservation_high := float(axis(gs.stage_replay_feedback(), "preservation").get("value", -1.0))
	record("STAGE-FEEDBACK-PRESERVATION-01", "Preservation is exactly 65% public integrity plus 35% visible condition and untouched artifacts are not automatic 100", approx_equal(preservation_base, preservation_expected) and preservation_base > 0.0 and preservation_base < 100.0 and preservation_low < preservation_base and preservation_high > preservation_low, {"untouched": preservation_base, "expected": preservation_expected, "damaged": preservation_low, "improved": preservation_high})

	artifacts = seed_stage_fixture(gs, registry, 1)
	var sale_artifact: Dictionary = artifacts[String(artifacts.keys()[0])]
	var sale_uid := String(sale_artifact.uniqueId)
	gs.auction_history = [sale_history(sale_uid, false, 0)]
	var no_sale_only := float(axis(gs.stage_replay_feedback(), "sale").get("value", -1.0))
	gs.auction_history = [sale_history(sale_uid, true, 50), sale_history(sale_uid, false, 0)]
	var sale_low := float(axis(gs.stage_replay_feedback(), "sale").get("value", -1.0))
	gs.auction_history[0].result.net = 115
	var realization_up := float(axis(gs.stage_replay_feedback(), "sale").get("value", -1.0))
	gs.auction_history[0].result.reserve = 1
	gs.auction_history[1].result.reserve = 1
	var reserve_only := float(axis(gs.stage_replay_feedback(), "sale").get("value", -1.0))
	gs.auction_history[1] = sale_history(sale_uid, true, 115, 100, 1)
	var conversion_up := float(axis(gs.stage_replay_feedback(), "sale").get("value", -1.0))
	set_investigation(gs, registry, 1, "NONE")
	for artifact_value: Variant in artifacts.values():
		var tied_artifact: Dictionary = artifact_value
		for key: String in ["historicalIntegrity", "surfaceCondition", "structuralCondition", "mechanicalCondition"]:
			tied_artifact[key] = 0.0
	gs.auction_history = [sale_history(sale_uid, false, 0)]
	var tie_feedback: Dictionary = gs.stage_replay_feedback()
	record("STAGE-FEEDBACK-SALE-01", "Sale is 65% conversion plus 35% realization against cached appraisal; reserve is never the denominator", approx_equal(no_sale_only, 0.0) and approx_equal(sale_low, 47.71739, 0.001) and approx_equal(realization_up, 67.5, 0.001) and approx_equal(reserve_only, realization_up) and approx_equal(conversion_up, 100.0) and sale_low < realization_up and realization_up < conversion_up and String(tie_feedback.get("weakest", "")) == "investigation" and String(tie_feedback.get("adviceCode", "")) == "STRENGTHEN_EVIDENCE", {"noSaleOnly": no_sale_only, "low": sale_low, "realizationUp": realization_up, "reserveOnly": reserve_only, "conversionUp": conversion_up, "tie": tie_feedback})

	# The optional argument is the exact appraisal the UI displayed, even when the
	# artifact's older estimatedValue differs. It follows history and SOLD ledger.
	artifacts = seed_stage_fixture(gs, registry, 1)
	var sold_case := String(artifacts.keys()[0])
	var sold_artifact: Dictionary = artifacts[sold_case]
	var sold_uid := String(sold_artifact.uniqueId)
	sold_artifact.historicalIntegrity = 63.0
	sold_artifact.surfaceCondition = 41.0
	sold_artifact.structuralCondition = 52.0
	sold_artifact.mechanicalCondition = 64.0
	sold_artifact.estimatedValue = 200
	var listed: bool = gs.list_auction(sold_artifact, 50, 180, 0.70, "LIKELY", 345)
	sold_artifact.estimatedValue = 999
	var before_sold := float(axis(gs.stage_replay_feedback(), "preservation").get("value", -1.0))
	gs.apply_sale_result(sold_artifact, {"reserve_met": true, "sale_status": "SOLD", "net": 300, "hammer": 330}, false, false)
	var after_sold := float(axis(gs.stage_replay_feedback(), "preservation").get("value", -1.0))
	var sold_ledger: Dictionary = gs.campaign_state.caseArtifactLedger.get(sold_case, {})
	var sold_history: Dictionary = gs.auction_history[-1]
	for key: String in ["historicalIntegrity", "surfaceCondition", "structuralCondition", "mechanicalCondition"]:
		sold_artifact[key] = 0.0
	var sold_stable := float(axis(gs.stage_replay_feedback(), "preservation").get("value", -1.0))
	record("STAGE-FEEDBACK-SNAPSHOT-01", "Explicit displayed appraisal and SOLD public condition survive inventory removal exactly", listed and int(sold_artifact.listing.publicAppraisal) == 345 and int(sold_history.get("publicAppraisal", 0)) == 345 and int(sold_ledger.get("publicAppraisalSnapshot", 0)) == 345 and String(sold_ledger.get("disposition", "")) == "SOLD" and gs.find_inventory_instance(sold_uid).is_empty() and not sold_ledger.get("publicConditionSnapshot", {}).is_empty() and approx_equal(before_sold, after_sold) and approx_equal(after_sold, sold_stable), {"listing": sold_artifact.listing, "historyAppraisal": sold_history.get("publicAppraisal", 0), "ledger": sold_ledger, "before": before_sold, "after": after_sold, "stable": sold_stable})

	artifacts = seed_stage_fixture(gs, registry, 1)
	set_investigation(gs, registry, 1, "DISCOVERY")
	var privacy_before: Dictionary = gs.stage_replay_feedback()
	for artifact_value: Variant in gs.inventory:
		var artifact: Dictionary = artifact_value
		artifact.authenticityTruth = "FORGERY"
		artifact.trueRarity = 999.0
		artifact.trueHistoricalSignificance = 0.001
		artifact.trueMarketBaseline = 1
		artifact.baseValue = 99999999
		artifact.originalParts = 0
		artifact.replacementParts = 99
	var privacy_after: Dictionary = gs.stage_replay_feedback()
	record("STAGE-FEEDBACK-PRIVACY-01", "Hidden truth, rarity, significance, value and originality flips cannot alter axes or advice", privacy_before == privacy_after, {"before": privacy_before, "after": privacy_after})

	# Explicit stage definitions plus ledger UIDs isolate other stages and market/
	# checkpoint lots. Each stage changes only when its own ledger UID is attempted.
	artifacts = seed_stage_fixture(gs, registry, 1)
	var stage2_artifacts: Dictionary = append_stage_fixture(gs, registry, 2)
	var stage2_before: Dictionary = gs.stage_replay_feedback(2)
	var stage1_uid := String(artifacts[String(artifacts.keys()[0])].uniqueId)
	var checkpoint: Dictionary = gs.new_artifact("artifact_061", 989898, "unscoped_checkpoint")
	gs.inventory.append(checkpoint)
	gs.auction_history = [sale_history(stage1_uid, true, 100), sale_history(String(checkpoint.uniqueId), true, 999999, 1)]
	var stage2_after_foreign: Dictionary = gs.stage_replay_feedback(2)
	var stage1_own: Dictionary = gs.stage_replay_feedback(1)
	var stage2_uid := String(stage2_artifacts[String(stage2_artifacts.keys()[0])].uniqueId)
	gs.auction_history.append(sale_history(stage2_uid, true, 100))
	var stage1_after_foreign: Dictionary = gs.stage_replay_feedback(1)
	var stage2_own: Dictionary = gs.stage_replay_feedback(2)
	record("STAGE-FEEDBACK-SCOPE-01", "Stage case-ledger UIDs exclude prior/later stage and unselected checkpoint auction history", stage2_before == stage2_after_foreign and stage1_own == stage1_after_foreign and not bool(axis(stage2_before, "sale").get("available", true)) and bool(axis(stage1_own, "sale").get("available", false)) and bool(axis(stage2_own, "sale").get("available", false)), {"stage1": stage1_own, "stage1AfterForeign": stage1_after_foreign, "stage2Before": stage2_before, "stage2AfterForeign": stage2_after_foreign, "stage2Own": stage2_own})

	# Stage 10 additionally owns its three explicit Grand Reserve selected/result
	# lots, including non-case checkpoint lots, but still excludes unrelated sales.
	artifacts = seed_stage_fixture(gs, registry, 10)
	var stage10_case_uid := String(artifacts[String(artifacts.keys()[0])].uniqueId)
	var reserve_checkpoint_a: Dictionary = gs.new_artifact("artifact_077", 101001, "grand_checkpoint_a")
	var reserve_checkpoint_b: Dictionary = gs.new_artifact("artifact_078", 101002, "grand_checkpoint_b")
	var unrelated: Dictionary = gs.new_artifact("artifact_076", 101003, "grand_unrelated")
	gs.inventory.append_array([reserve_checkpoint_a, reserve_checkpoint_b, unrelated])
	var selected_ids := [stage10_case_uid, String(reserve_checkpoint_a.uniqueId), String(reserve_checkpoint_b.uniqueId)]
	gs.campaign_state.grandReserve.selectedLotIds = selected_ids.duplicate()
	gs.campaign_state.grandReserve.results = selected_ids.map(func(uid: String): return {"artifact": {"instanceId": uid}, "auction": {}})
	gs.auction_history = [
		sale_history(stage10_case_uid, true, 115),
		sale_history(String(reserve_checkpoint_a.uniqueId), false, 0),
		sale_history(String(reserve_checkpoint_b.uniqueId), true, 57),
		sale_history(String(unrelated.uniqueId), true, 999999, 1)
	]
	var grand_with_unrelated: Dictionary = gs.stage_replay_feedback(10)
	var grand_value := float(axis(grand_with_unrelated, "sale").get("value", -1.0))
	gs.auction_history.pop_back()
	var grand_without_unrelated: Dictionary = gs.stage_replay_feedback(10)
	record("STAGE-FEEDBACK-GRAND-01", "Stage 10 Sale includes all three selected Grand Reserve lots including checkpoints and excludes unrelated auctions", grand_with_unrelated == grand_without_unrelated and bool(axis(grand_with_unrelated, "sale").get("available", false)) and approx_equal(grand_value, 69.50725, 0.001), {"selected": selected_ids, "feedback": grand_with_unrelated, "withoutUnrelated": grand_without_unrelated})

	# Save/load preserves the exact public result. NEW GAME clears all run ledger,
	# history, selected lots and their influence.
	var stable_before: Dictionary = gs.stage_replay_feedback(10)
	var payload: Dictionary = gs.save_payload()
	gs.reset_game()
	var loaded: bool = gs.apply_save_data(payload)
	var stable_after: Dictionary = gs.stage_replay_feedback(10)
	var old_uids: Array = payload.get("campaign", {}).get("caseArtifactLedger", {}).values().map(func(row: Dictionary): return String(row.get("artifactUid", "")))
	var new_run: Dictionary = gs.new_game(1)
	var fresh: Dictionary = gs.stage_replay_feedback(1)
	var fresh_ledger: Dictionary = gs.campaign_state.get("caseArtifactLedger", {})
	var leaked_uid := false
	for old_uid: String in old_uids:
		leaked_uid = leaked_uid or fresh_ledger.values().any(func(row: Dictionary): return String(row.get("artifactUid", "")) == old_uid)
	record("STAGE-FEEDBACK-PERSISTENCE-01", "Feedback round-trips saves and NEW GAME cannot leak prior run artifacts or auctions", loaded and stable_before == stable_after and bool(new_run.get("ok", false)) and fresh_ledger.is_empty() and gs.auction_history.is_empty() and gs.campaign_state.grandReserve.selectedLotIds.is_empty() and not leaked_uid and axis(fresh, "sale").get("value", 1) == null and not bool(axis(fresh, "sale").get("available", true)), {"stableBefore": stable_before, "stableAfter": stable_after, "fresh": fresh, "ledger": fresh_ledger.size(), "history": gs.auction_history.size(), "leaked": leaked_uid})

	var passed := results.filter(func(result: Dictionary): return bool(result.passed)).size()
	var report := {"suite": "R3 Stage Replay Feedback", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "skipped": 0, "tests": results}
	var output := FileAccess.open("res://qa/R3_STAGE_REPLAY_FEEDBACK_TESTS.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	quit(0 if passed == results.size() else 1)
