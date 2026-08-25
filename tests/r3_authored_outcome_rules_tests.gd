extends SceneTree

## Ordered authored outcome-rule acceptance.
##
## The suite uses public case discovery/evaluation paths for gameplay outcomes,
## mutates only isolated in-memory fixtures for ruleless/fail-closed probes, and
## writes one count report. It never writes release or package artifacts.

const REPORT_PATH := "res://qa/R3_AUTHORED_OUTCOME_RULES_TESTS.json"
const EXPECTED_TEST_COUNT := 9
const AUTHORED_CASE_IDS := [
	"prologue_clock", "false_invoice", "shadow_camera",
	"leave_patina", "estate_compass", "pawn_watch"
]
const PROTECTED_CASE_IDS := ["prologue_clock", "false_invoice", "shadow_camera"]
const PAWN_CORRECT := "hyp.pawn_watch.period_repair"
const PAWN_WRONG := "hyp.pawn_watch.modern_parts"
const PAWN_SUPPORT := [
	"src.pawn_watch.artifact.bridge_service_marks",
	"src.pawn_watch.artifact.escape_wheel_measurement",
	"src.pawn_watch.document.pawn_ticket"
]
const PAWN_MASTERFUL := [
	"src.pawn_watch.artifact.bridge_service_marks",
	"src.pawn_watch.artifact.escape_wheel_measurement",
	"src.pawn_watch.document.pawn_ticket",
	"src.pawn_watch.reference.brasswell_service_gauge"
]
const PAWN_REFUTING_WRONG := [
	"src.pawn_watch.artifact.escape_wheel_measurement",
	"src.pawn_watch.document.pawn_ticket"
]

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(test_id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": test_id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func finish(gs: Node) -> void:
	var passed: int = results.filter(func(row: Dictionary): return bool(row.get("passed", false))).size()
	var report := {
		"suite": "R3 Authored Outcome Rules",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"skipped": 0,
		"expectedCount": EXPECTED_TEST_COUNT,
		"tests": results
	}
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print(JSON.stringify(report))
	gs.persistence_enabled = false
	quit(0 if passed == EXPECTED_TEST_COUNT and results.size() == EXPECTED_TEST_COUNT else 1)


func authority_signature(gs: Node) -> String:
	return JSON.stringify({"run": gs.save_payload(), "profile": gs.profile_payload()})


func begin_authored_case(gs: Node, registry: Node, case_id: String) -> Dictionary:
	gs.persistence_enabled = false
	gs.reset_game()
	gs.persistence_enabled = false
	gs.campaign_state.currentAct = String(registry.get_case(case_id).get("act", ""))
	return gs.begin_case(case_id)


func discover_all(gs: Node, case_id: String) -> Array:
	var discovered_ids: Array = []
	for _pass: int in range(20):
		var public_state: Dictionary = gs.get_case_public_state(case_id)
		var progressed := false
		for row_value: Variant in public_state.get("availableEvidence", []):
			if not row_value is Dictionary:
				continue
			var row: Dictionary = row_value
			var tools: Array = row.get("requiredTools", [])
			if not tools.is_empty():
				gs.select_tool(String(tools[0]))
			var discovered: Dictionary = gs.discover_case_evidence(case_id, String(row.get("id", "")))
			if bool(discovered.get("ok", false)) and String(discovered.get("code", "")) == "DISCOVERED":
				discovered_ids.append(String(row.get("id", "")))
				progressed = true
		if not progressed:
			break
	return discovered_ids


func wrong_hypothesis(definition: Dictionary) -> String:
	var canonical := String(definition.get("canonical_hypothesis_id", ""))
	for hypothesis_value: Variant in definition.get("hypotheses", []):
		if hypothesis_value is Dictionary:
			var hypothesis_id := String((hypothesis_value as Dictionary).get("id", ""))
			if not hypothesis_id.is_empty() and hypothesis_id != canonical:
				return hypothesis_id
	return ""


func rule_shape_ok(rule: Dictionary) -> bool:
	var expected_keys := [
		"outcome_id", "correctness", "requires_all_required_sources",
		"minimum_independent_groups", "minimum_citations",
		"minimum_net_support", "fallback"
	]
	return expected_keys.all(func(key: String): return rule.has(key)) \
		and not rule.has("outcome") and not rule.has("requires_correct_hypothesis") \
		and rule.get("minimum_independent_groups") is int \
		and rule.get("minimum_citations") is int \
		and rule.get("minimum_net_support") is int


func normalized_rules_exact(definition: Dictionary) -> bool:
	var rules_value: Variant = definition.get("resolution", {}).get("outcome_rules", null)
	if not rules_value is Array:
		return false
	var rules: Array = rules_value
	if rules.size() != 4 or not rules.all(func(rule: Variant): return rule is Dictionary and rule_shape_ok(rule)):
		return false
	var masterful: Dictionary = rules[0]
	var credible: Dictionary = rules[1]
	var mistaken: Dictionary = rules[2]
	var fallback: Dictionary = rules[3]
	return rules.map(func(rule: Dictionary): return rule.get("outcome_id", "")) \
		== ["masterful", "credible", "mistaken", "reviewed_with_mentor"] \
		and String(masterful.get("correctness", "")) == "CORRECT" \
		and bool(masterful.get("requires_all_required_sources", false)) \
		and int(masterful.get("minimum_net_support", -1)) == int(masterful.get("minimum_independent_groups", -2)) \
		and String(credible.get("correctness", "")) == "CORRECT" \
		and not bool(credible.get("requires_all_required_sources", true)) \
		and int(credible.get("minimum_net_support", -1)) == 1 \
		and String(mistaken.get("correctness", "")) == "INCORRECT" \
		and int(mistaken.get("minimum_independent_groups", -1)) == 0 \
		and int(mistaken.get("minimum_citations", -1)) == 2 \
		and int(mistaken.get("minimum_net_support", -1)) == 0 \
		and String(fallback.get("correctness", "")) == "ANY" \
		and bool(fallback.get("fallback", false)) \
		and not bool(fallback.get("requires_all_required_sources", true)) \
		and int(fallback.get("minimum_independent_groups", -1)) == 0 \
		and int(fallback.get("minimum_citations", -1)) == 0 \
		and int(fallback.get("minimum_net_support", -1)) == 0


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.persistence_enabled = false

	var normalized_evidence: Dictionary = {}
	var required_cases_present := AUTHORED_CASE_IDS.all(func(case_id: String): return registry.authored_cases_v2.has(case_id))
	var all_rules_exact: bool = registry.authored_case_errors.is_empty() \
		and registry.authored_cases_v2.size() >= AUTHORED_CASE_IDS.size() \
		and required_cases_present
	for case_id: String in AUTHORED_CASE_IDS:
		var definition: Dictionary = registry.get_case_v2(case_id)
		var exact := normalized_rules_exact(definition)
		all_rules_exact = all_rules_exact and exact
		normalized_evidence[case_id] = {
			"exact": exact,
			"rules": definition.get("resolution", {}).get("outcome_rules", [])
		}
	record(
		"AUTHORED-RULES-NORMALIZE-01",
		"The six established authored cases preserve ordered normalized rules and deterministic threshold defaults as the registry expands",
		all_rules_exact,
		{"registryErrors": registry.authored_case_errors, "authoredCount": registry.authored_cases_v2.size(), "requiredCasesPresent": required_cases_present, "cases": normalized_evidence}
	)

	var pawn_artifact := begin_authored_case(gs, registry, "pawn_watch")
	var pawn_discovered := discover_all(gs, "pawn_watch")
	var pawn_ladder_before := authority_signature(gs)
	var pawn_ladder_rng := int(gs.rng.state)
	var pawn_two: Dictionary = gs.evaluate_case_submission("pawn_watch", PAWN_CORRECT, PAWN_SUPPORT.slice(0, 2))
	var pawn_three: Dictionary = gs.evaluate_case_submission("pawn_watch", PAWN_CORRECT, PAWN_SUPPORT)
	var pawn_ladder_after := authority_signature(gs)
	record(
		"AUTHORED-RULES-PAWN-LADDER-01",
		"Pawn Watch correct 2/2 reaches mentor review while correct 3/3 reaches credible",
		not pawn_artifact.is_empty() and pawn_discovered.size() == 6 \
			and bool(pawn_two.get("ok", false)) \
			and String(pawn_two.get("outcome", "")) == "reviewed_with_mentor" \
			and String(pawn_two.get("substantiation", "")) == "INCONCLUSIVE" \
			and not bool(pawn_two.get("substantiated", true)) \
			and int(pawn_two.get("independentSourceCount", -1)) == 2 \
			and bool(pawn_three.get("ok", false)) \
			and String(pawn_three.get("outcome", "")) == "credible" \
			and String(pawn_three.get("substantiation", "")) == "PLAUSIBLE" \
			and not bool(pawn_three.get("substantiated", true)) \
			and int(pawn_three.get("independentSourceCount", -1)) == 3 \
			and pawn_ladder_before == pawn_ladder_after and pawn_ladder_rng == int(gs.rng.state),
		{"two": pawn_two, "three": pawn_three, "stateMutation0": pawn_ladder_before == pawn_ladder_after, "rngMutation0": pawn_ladder_rng == int(gs.rng.state)}
	)

	var wrong_before := authority_signature(gs)
	var wrong_rng := int(gs.rng.state)
	var wrong_one: Dictionary = gs.evaluate_case_submission("pawn_watch", PAWN_WRONG, PAWN_REFUTING_WRONG.slice(0, 1))
	var wrong_two: Dictionary = gs.evaluate_case_submission("pawn_watch", PAWN_WRONG, PAWN_REFUTING_WRONG)
	var wrong_after := authority_signature(gs)
	record(
		"AUTHORED-RULES-PAWN-WRONG-01",
		"Pawn Watch wrong 1-citation report reaches mentor fallback and wrong 2+ reaches mistaken even with negative net",
		bool(wrong_one.get("ok", false)) and String(wrong_one.get("outcome", "")) == "reviewed_with_mentor" \
			and int(wrong_one.get("netScore", 0)) < 0 \
			and String(wrong_one.get("substantiation", "")) == "INCONCLUSIVE" \
			and bool(wrong_two.get("ok", false)) and String(wrong_two.get("outcome", "")) == "mistaken" \
			and int(wrong_two.get("netScore", 0)) < 0 \
			and String(wrong_two.get("substantiation", "")) == "INCONCLUSIVE" \
			and not bool(wrong_two.get("substantiated", true)) \
			and wrong_before == wrong_after and wrong_rng == int(gs.rng.state),
		{"one": wrong_one, "two": wrong_two, "stateMutation0": wrong_before == wrong_after, "rngMutation0": wrong_rng == int(gs.rng.state)}
	)

	var precedence_before := authority_signature(gs)
	var precedence_rng := int(gs.rng.state)
	var pawn_masterful: Dictionary = gs.evaluate_case_submission("pawn_watch", PAWN_CORRECT, PAWN_MASTERFUL)
	var precedence_after := authority_signature(gs)
	record(
		"AUTHORED-RULES-PRECEDENCE-01",
		"First-match precedence awards Pawn Watch masterful before its credible rule",
		bool(pawn_masterful.get("ok", false)) and String(pawn_masterful.get("outcome", "")) == "masterful" \
			and bool(pawn_masterful.get("requiredSourcesMet", false)) \
			and int(pawn_masterful.get("independentSourceCount", -1)) == 4 \
			and int(pawn_masterful.get("netScore", -1)) >= 4 \
			and String(pawn_masterful.get("substantiation", "")) == "STRONG" \
			and bool(pawn_masterful.get("substantiated", false)) \
			and precedence_before == precedence_after and precedence_rng == int(gs.rng.state),
		{"result": pawn_masterful, "stateMutation0": precedence_before == precedence_after, "rngMutation0": precedence_rng == int(gs.rng.state)}
	)

	var original_pawn: Dictionary = registry.authored_cases_v2.get("pawn_watch", {}).duplicate(true)
	var ruleless_input: Dictionary = original_pawn.duplicate(true)
	ruleless_input["resolution"].erase("outcome_rules")
	var ruleless_definition: Dictionary = registry.normalize_authored_case_v2(ruleless_input)
	registry.authored_cases_v2["pawn_watch"] = ruleless_definition
	var ruleless_before := authority_signature(gs)
	var ruleless_rng := int(gs.rng.state)
	var ruleless_two: Dictionary = gs.evaluate_case_submission("pawn_watch", PAWN_CORRECT, PAWN_SUPPORT.slice(0, 2))
	var ruleless_after := authority_signature(gs)
	registry.authored_cases_v2["pawn_watch"] = original_pawn
	record(
		"AUTHORED-RULES-LEGACY-01",
		"A normalized ruleless definition retains the exact legacy strong/plausible matcher",
		ruleless_definition.get("resolution", {}).get("outcome_rules", null) == [] \
			and int(ruleless_definition.get("resolution", {}).get("strong_min_independent_support", -1)) == 4 \
			and int(ruleless_definition.get("resolution", {}).get("plausible_min_independent_support", -1)) == 2 \
			and bool(ruleless_two.get("ok", false)) and String(ruleless_two.get("outcome", "")) == "credible" \
			and String(ruleless_two.get("substantiation", "")) == "PLAUSIBLE" \
			and not bool(ruleless_two.get("substantiated", true)) \
			and ruleless_before == ruleless_after and ruleless_rng == int(gs.rng.state),
		{"normalizedRules": ruleless_definition.get("resolution", {}).get("outcome_rules", null), "legacyThresholds": ruleless_definition.get("resolution", {}), "result": ruleless_two, "stateMutation0": ruleless_before == ruleless_after, "rngMutation0": ruleless_rng == int(gs.rng.state)}
	)

	var empty_artifact := begin_authored_case(gs, registry, "pawn_watch")
	var empty_before := authority_signature(gs)
	var empty_rng := int(gs.rng.state)
	var empty_evaluation: Dictionary = gs.evaluate_case_submission("pawn_watch", PAWN_CORRECT, [])
	var empty_resolution: Dictionary = gs.resolve_case_v2("pawn_watch", PAWN_CORRECT, [])
	var empty_after := authority_signature(gs)
	var pending_before: Dictionary = gs.pending_auction.duplicate(true)
	gs.pending_auction = gs.default_pending_auction()
	gs.pending_auction["status"] = "PENDING"
	var locked_before := authority_signature(gs)
	var locked_rng := int(gs.rng.state)
	var locked_empty: Dictionary = gs.resolve_case_v2("pawn_watch", PAWN_CORRECT, [])
	var locked_after := authority_signature(gs)
	gs.pending_auction = pending_before
	record(
		"AUTHORED-RULES-EMPTY-01",
		"Domain evaluation rejects zero citations without mutation while pending-auction lock keeps priority",
		not empty_artifact.is_empty() \
			and not bool(empty_evaluation.get("ok", true)) and String(empty_evaluation.get("code", "")) == "CITATION_REQUIRED" \
			and not bool(empty_resolution.get("ok", true)) and String(empty_resolution.get("code", "")) == "CITATION_REQUIRED" \
			and empty_before == empty_after and empty_rng == int(gs.rng.state) \
			and not bool(locked_empty.get("ok", true)) and String(locked_empty.get("code", "")) == "PENDING_AUCTION_LOCKED" \
			and locked_before == locked_after and locked_rng == int(gs.rng.state),
		{"evaluate": empty_evaluation, "resolve": empty_resolution, "locked": locked_empty, "emptyStateMutation0": empty_before == empty_after, "emptyRngMutation0": empty_rng == int(gs.rng.state), "lockStateMutation0": locked_before == locked_after, "lockRngMutation0": locked_rng == int(gs.rng.state)}
	)

	var protected_ok := true
	var protected_evidence: Dictionary = {}
	for case_id: String in PROTECTED_CASE_IDS:
		var definition: Dictionary = registry.get_case_v2(case_id)
		var artifact := begin_authored_case(gs, registry, case_id)
		var discovered: Array = discover_all(gs, case_id)
		var required: Array = definition.get("resolution", {}).get("required_source_refs", []).duplicate()
		var masterful_citations: Array = discovered.duplicate()
		var masterful_before := authority_signature(gs)
		var masterful_rng := int(gs.rng.state)
		var masterful: Dictionary = gs.evaluate_case_submission(case_id, String(definition.get("canonical_hypothesis_id", "")), masterful_citations)
		var masterful_after := authority_signature(gs)
		artifact = begin_authored_case(gs, registry, case_id)
		discovered = discover_all(gs, case_id)
		var wrong_id := wrong_hypothesis(definition)
		var wrong_citations: Array = discovered.slice(0, mini(2, discovered.size()))
		var mistaken_before := authority_signature(gs)
		var mistaken_rng := int(gs.rng.state)
		var mistaken: Dictionary = gs.evaluate_case_submission(case_id, wrong_id, wrong_citations)
		var mistaken_after := authority_signature(gs)
		var case_ok: bool = not artifact.is_empty() and discovered.size() == definition.get("evidence", []).size() \
			and not required.is_empty() and required.all(func(evidence_id: Variant): return masterful_citations.has(evidence_id)) \
			and bool(masterful.get("ok", false)) \
			and String(masterful.get("outcome", "")) == "masterful" and bool(masterful.get("substantiated", false)) \
			and masterful_before == masterful_after and masterful_rng == int(gs.rng.state) \
			and wrong_citations.size() == 2 and bool(mistaken.get("ok", false)) \
			and String(mistaken.get("outcome", "")) == "mistaken" and not bool(mistaken.get("conclusionAccurate", true)) \
			and mistaken_before == mistaken_after and mistaken_rng == int(gs.rng.state)
		protected_ok = protected_ok and case_ok
		protected_evidence[case_id] = {"ok": case_ok, "masterful": masterful, "wrongTwoPlus": mistaken, "masterfulMutation0": masterful_before == masterful_after, "wrongMutation0": mistaken_before == mistaken_after}
	record(
		"AUTHORED-RULES-PROTECTED-01",
		"The three established authored cases retain masterful and wrong-two-plus mistaken outcomes",
		protected_ok,
		protected_evidence
	)

	var validation_base: Dictionary = registry.get_case_v2("pawn_watch").duplicate(true)
	var hostile_codes: Dictionary = {}
	var bad_order: Dictionary = validation_base.duplicate(true)
	var bad_order_rules: Array = bad_order["resolution"]["outcome_rules"]
	var swapped: Variant = bad_order_rules[0]
	bad_order_rules[0] = bad_order_rules[1]
	bad_order_rules[1] = swapped
	hostile_codes["order"] = registry.validate_authored_case_v2(bad_order).get("code", "")
	var bad_threshold: Dictionary = validation_base.duplicate(true)
	bad_threshold["resolution"]["outcome_rules"][0]["minimum_net_support"] = -1
	hostile_codes["threshold"] = registry.validate_authored_case_v2(bad_threshold).get("code", "")
	var bad_fallback_position: Dictionary = validation_base.duplicate(true)
	bad_fallback_position["resolution"]["outcome_rules"][1]["fallback"] = true
	hostile_codes["fallbackPosition"] = registry.validate_authored_case_v2(bad_fallback_position).get("code", "")
	var bad_fallback_condition: Dictionary = validation_base.duplicate(true)
	bad_fallback_condition["resolution"]["outcome_rules"][-1]["minimum_citations"] = 1
	hostile_codes["fallbackCondition"] = registry.validate_authored_case_v2(bad_fallback_condition).get("code", "")
	var missing_fallback: Dictionary = validation_base.duplicate(true)
	missing_fallback["resolution"]["outcome_rules"].pop_back()
	hostile_codes["missingFallback"] = registry.validate_authored_case_v2(missing_fallback).get("code", "")
	var bad_fraction_raw: Dictionary = validation_base.duplicate(true)
	bad_fraction_raw["resolution"]["outcome_rules"][0]["minimum_citations"] = 1.5
	var bad_fraction_normalized: Dictionary = registry.normalize_authored_case_v2(bad_fraction_raw)
	hostile_codes["fraction"] = registry.validate_authored_case_v2(bad_fraction_normalized).get("code", "")
	record(
		"AUTHORED-RULES-FAIL-CLOSED-01",
		"Runtime validation rejects reordered, malformed-threshold and non-final or conditional fallback rules",
		hostile_codes == {
			"order": "INVALID_OUTCOME_RULE_ORDER",
			"threshold": "INVALID_OUTCOME_RULE_THRESHOLD",
			"fallbackPosition": "INVALID_OUTCOME_RULE_FALLBACK",
			"fallbackCondition": "INVALID_OUTCOME_RULE_FALLBACK",
			"missingFallback": "INVALID_OUTCOME_RULE_FALLBACK",
			"fraction": "INVALID_OUTCOME_RULE_THRESHOLD"
		},
		hostile_codes
	)

	var privacy_artifact := begin_authored_case(gs, registry, "pawn_watch")
	discover_all(gs, "pawn_watch")
	var public_before: Dictionary = gs.get_case_public_state("pawn_watch")
	var privacy_before := authority_signature(gs)
	var privacy_rng := int(gs.rng.state)
	var preview: Dictionary = gs.evaluate_case_submission("pawn_watch", PAWN_CORRECT, PAWN_SUPPORT.slice(0, 1))
	var public_after: Dictionary = gs.get_case_public_state("pawn_watch")
	var privacy_after := authority_signature(gs)
	var public_json := JSON.stringify({"before": public_before, "after": public_after, "preview": preview})
	var forbidden_tokens := [
		"outcome_rules", "outcome_id", "correctness", "minimum_net_support",
		"requires_correct_hypothesis", "canonical_hypothesis_id",
		"winning_hypothesis_id", "required_source_refs"
	]
	var leaks: Array = forbidden_tokens.filter(func(token: String): return public_json.contains(token))
	record(
		"AUTHORED-RULES-PUBLIC-01",
		"Public dossier and evaluation expose outcomes but no raw rule or canonical-answer fields",
		not privacy_artifact.is_empty() and bool(preview.get("ok", false)) \
			and String(preview.get("outcome", "")) == "reviewed_with_mentor" \
			and leaks.is_empty() and privacy_before == privacy_after and privacy_rng == int(gs.rng.state),
		{"outcome": preview.get("outcome", ""), "publicKeys": public_after.keys(), "previewKeys": preview.keys(), "leaks": leaks, "stateMutation0": privacy_before == privacy_after, "rngMutation0": privacy_rng == int(gs.rng.state)}
	)

	finish(gs)
