extends SceneTree

var results: Array = []
const MVP_CASE_IDS := ["prologue_clock", "false_invoice", "shadow_camera"]


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, condition: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": condition, "evidence": evidence})


func begin_policy_case(gs: Node, registry: Node, case_id: String) -> Dictionary:
	gs.reset_game()
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	gs.campaign_state.currentAct = registry.get_case(case_id).get("act", "PROLOGUE")
	return gs.begin_case(case_id)


func discover_visible(gs: Node, case_id: String, mode: String, rng: RandomNumberGenerator) -> Array:
	var discoveries: Array = []
	var budget := 99 if mode == "evidence_first" else (2 if mode == "rush" else rng.randi_range(1, 5))
	for _pass in range(20):
		if discoveries.size() >= budget:
			break
		var public_state: Dictionary = gs.get_case_public_state(case_id)
		var available: Array = public_state.get("availableEvidence", [])
		if available.is_empty():
			break
		var row: Dictionary = available[0] if mode != "random_valid" else available[rng.randi_range(0, available.size() - 1)]
		var required_tools: Array = row.get("requiredTools", [])
		if not required_tools.is_empty():
			gs.select_tool(String(required_tools[0]))
		var discovery: Dictionary = gs.discover_case_evidence(case_id, row.get("id", ""))
		if not bool(discovery.get("ok", false)):
			break
		if discovery.get("code", "") == "DISCOVERED":
			discoveries.append(row.get("id", ""))
	return discoveries


func choose_visible_report(public_state: Dictionary, mode: String, rng: RandomNumberGenerator) -> Dictionary:
	var hypotheses: Array = public_state.get("hypotheses", [])
	var discovered: Array = public_state.get("discoveredEvidence", [])
	if hypotheses.is_empty():
		return {"hypothesisId": "", "citations": []}
	if mode == "rush":
		return {
			"hypothesisId": hypotheses[0].get("id", ""),
			"citations": discovered.slice(0, mini(2, discovered.size())).map(func(row: Dictionary): return row.get("id", ""))
		}
	if mode == "random_valid":
		var random_hypothesis: Dictionary = hypotheses[rng.randi_range(0, hypotheses.size() - 1)]
		var candidate_ids: Array = discovered.map(func(row: Dictionary): return row.get("id", ""))
		var citations: Array = []
		while not candidate_ids.is_empty() and citations.size() < rng.randi_range(1, maxi(1, candidate_ids.size())):
			citations.append(candidate_ids.pop_at(rng.randi_range(0, candidate_ids.size() - 1)))
		return {"hypothesisId": random_hypothesis.get("id", ""), "citations": citations}

	# Evidence-first sees only the public ledger. It selects the hypothesis with
	# the greatest visible SUPPORT minus REFUTE score and cites every discovered
	# supporting observation. Canonical IDs and resolution thresholds are never
	# passed to this policy.
	var best_hypothesis: String = hypotheses[0].get("id", "")
	var best_score := -999999
	for hypothesis: Dictionary in hypotheses:
		var hypothesis_id: String = hypothesis.get("id", "")
		var score := 0
		for row: Dictionary in discovered:
			for relation: Dictionary in row.get("relations", []):
				if relation.get("hypothesis_id", "") != hypothesis_id:
					continue
				var strength := int(relation.get("strength", 0))
				score += strength if relation.get("stance", "") == "SUPPORT" else -strength
		if score > best_score:
			best_score = score
			best_hypothesis = hypothesis_id
	var citations: Array = []
	for row: Dictionary in discovered:
		if not bool(row.get("citationAllowed", false)):
			continue
		for relation: Dictionary in row.get("relations", []):
			if relation.get("hypothesis_id", "") == best_hypothesis and relation.get("stance", "") == "SUPPORT":
				citations.append(row.get("id", ""))
				break
	return {"hypothesisId": best_hypothesis, "citations": citations, "visibleScore": best_score}


func policy_next_action(public_state: Dictionary) -> Dictionary:
	var available: Array = public_state.get("availableEvidence", [])
	if not available.is_empty():
		var row: Dictionary = available[0]
		return {"action": "DISCOVER", "evidenceId": row.get("id", ""), "requiredTools": row.get("requiredTools", []).duplicate()}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var report := choose_visible_report(public_state, "evidence_first", rng)
	return {"action": "REPORT", "hypothesisId": report.get("hypothesisId", ""), "citations": report.get("citations", [])}


func result_score(result: Dictionary) -> float:
	var score := 4.0 if bool(result.get("conclusionAccurate", false)) else 0.0
	score += {"STRONG": 3.0, "PLAUSIBLE": 1.0, "INCONCLUSIVE": 0.0}.get(result.get("substantiation", "INCONCLUSIVE"), 0.0)
	score += {"masterful": 2.0, "credible": 1.0}.get(result.get("outcome", ""), 0.0)
	return score


func run_policy(gs: Node, registry: Node, case_id: String, mode: String, seed_value: int) -> Dictionary:
	var artifact := begin_policy_case(gs, registry, case_id)
	if artifact.is_empty():
		return {"ok": false, "code": "CASE_DID_NOT_BEGIN"}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var discoveries := discover_visible(gs, case_id, mode, rng)
	var public_state: Dictionary = gs.get_case_public_state(case_id)
	var report := choose_visible_report(public_state, mode, rng)
	var resolution: Dictionary = gs.resolve_case_v2(case_id, report.get("hypothesisId", ""), report.get("citations", []))
	return {
		"ok": bool(resolution.get("ok", false)),
		"caseId": case_id,
		"mode": mode,
		"discoveries": discoveries,
		"report": report,
		"resolution": resolution,
		"score": result_score(resolution),
		"money": gs.money
	}


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.persistence_enabled = false

	var authored_ids: Array = registry.authored_cases_v2.keys()
	authored_ids.sort()
	record(
		"MVP-DATA-01",
		"The three protected authored-v2 contrast cases remain registered as later stages gain authored content",
		authored_ids.size() >= MVP_CASE_IDS.size() \
			and MVP_CASE_IDS.all(func(case_id: String): return authored_ids.has(case_id)) \
			and registry.authored_case_errors.is_empty() \
			and registry.campaign_cases.size() == 26,
		{"authored": authored_ids, "campaignCases": registry.campaign_cases.size(), "errors": registry.authored_case_errors}
	)

	var production_source := FileAccess.get_file_as_string("res://scripts/game_state.gd") + FileAccess.get_file_as_string("res://scripts/main3d.gd")
	record(
		"MVP-GENERIC-01",
		"MVP cases use the generic production resolver and UI with no case-id gameplay branch",
		not production_source.contains("\"false_invoice\"") and not production_source.contains("\"shadow_camera\""),
		{"falseInvoiceBranch": production_source.contains("\"false_invoice\""), "shadowCameraBranch": production_source.contains("\"shadow_camera\"")}
	)

	var evidence_runs: Array = []
	var rush_runs: Array = []
	var random_runs: Array = []
	for case_id: String in MVP_CASE_IDS:
		evidence_runs.append(run_policy(gs, registry, case_id, "evidence_first", 1001))
		rush_runs.append(run_policy(gs, registry, case_id, "rush", 1001))
		for seed_value in range(1, 31):
			random_runs.append(run_policy(gs, registry, case_id, "random_valid", seed_value))
	var evidence_average: float = evidence_runs.reduce(func(total: float, row: Dictionary): return total + float(row.get("score", 0.0)), 0.0) / float(evidence_runs.size())
	var rush_average: float = rush_runs.reduce(func(total: float, row: Dictionary): return total + float(row.get("score", 0.0)), 0.0) / float(rush_runs.size())
	var random_average: float = random_runs.reduce(func(total: float, row: Dictionary): return total + float(row.get("score", 0.0)), 0.0) / float(random_runs.size())
	record(
		"MVP-POLICY-01",
		"Player-visible Evidence-first policy outperforms Rush and Random-valid across all three reasoning topologies",
		evidence_runs.all(func(row: Dictionary): return bool(row.get("ok", false)))
			and random_runs.all(func(row: Dictionary): return bool(row.get("ok", false)))
			and evidence_average > rush_average
			and evidence_average > random_average,
		{"evidenceAverage": evidence_average, "rushAverage": rush_average, "randomAverage": random_average, "evidenceRuns": evidence_runs, "rushRuns": rush_runs}
	)

	var truth_flip_failures: Array = []
	for case_id: String in MVP_CASE_IDS:
		begin_policy_case(gs, registry, case_id)
		var definition: Dictionary = registry.authored_cases_v2[case_id]
		var original_canonical: String = definition.get("canonical_hypothesis_id", "")
		var alternate: String = definition.get("hypotheses", [])[0].get("id", "")
		if alternate == original_canonical and definition.get("hypotheses", []).size() > 1:
			alternate = definition.hypotheses[1].get("id", "")
		var before_public: Dictionary = gs.get_case_public_state(case_id)
		var before_action := policy_next_action(before_public)
		definition.canonical_hypothesis_id = alternate
		var after_public: Dictionary = gs.get_case_public_state(case_id)
		var after_action := policy_next_action(after_public)
		definition.canonical_hypothesis_id = original_canonical
		if JSON.stringify(before_public) != JSON.stringify(after_public) or before_action != after_action:
			truth_flip_failures.append({"caseId": case_id, "beforeAction": before_action, "afterAction": after_action})
	record(
		"MVP-PRIVACY-01",
		"Hidden canonical truth flip cannot change public state or the visible-policy next action",
		truth_flip_failures.is_empty(),
		truth_flip_failures
	)

	var determinism_failures: Array = []
	for case_id: String in MVP_CASE_IDS:
		var first := run_policy(gs, registry, case_id, "evidence_first", 4404)
		var second := run_policy(gs, registry, case_id, "evidence_first", 4404)
		var first_contract := {"report": first.get("report", {}), "resolution": first.get("resolution", {}), "money": first.get("money", 0)}
		var second_contract := {"report": second.get("report", {}), "resolution": second.get("resolution", {}), "money": second.get("money", 0)}
		if first_contract != second_contract:
			determinism_failures.append({"caseId": case_id, "first": first_contract, "second": second_contract})
	record(
		"MVP-DETERMINISM-01",
		"Same seed and visible action sequence produce deterministic report and reward results",
		determinism_failures.is_empty(),
		determinism_failures
	)

	var passed := 0
	for result: Dictionary in results:
		if result.passed:
			passed += 1
	var report := {"suite": "R3 authored-v2 MVP policy", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "skipped": 0, "tests": results}
	var output := FileAccess.open("res://qa/R3_MVP_POLICY_TESTS.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	quit(0 if passed == results.size() else 1)
