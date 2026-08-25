extends SceneTree

## Stage 3 authored-v2 acceptance contract.
##
## This suite exercises only the generic RuntimeRegistry/GameState public paths.
## It never patches production data and writes only its dedicated QA report.

const CASE_IDS := ["garage_lamp", "telephone_trace", "early_camera"]
const EXPECTED_TEST_COUNT := 8
const REPORT_PATH := "res://qa/R3_STAGE3_AUTHORED_CASES_TESTS.json"
const LOG_PATH := "res://qa/R3_STAGE3_AUTHORED_CASES_TESTS.log"

const EXPECTED_ARTIFACT_SPECS := {
	"garage_lamp": "artifact_007",
	"telephone_trace": "artifact_015",
	"early_camera": "artifact_003"
}

const EXPECTED_RISKS := {
	"garage_lamp": {"NONE": 4, "LOW": 1, "HIGH": 0},
	"telephone_trace": {"NONE": 4, "LOW": 1, "HIGH": 1},
	"early_camera": {"NONE": 3, "LOW": 1, "HIGH": 1}
}

const EXPECTED_RISK_TOOLS := {
	"garage_lamp": {
		"src.garage_lamp.artifact.socket_service_marks": ["precision_screwdriver"]
	},
	"telephone_trace": {
		"src.telephone_trace.artifact.shell_material_serial": ["material_scanner"],
		"src.telephone_trace.artifact.terminal_safety_repair": ["precision_screwdriver"]
	},
	"early_camera": {
		"src.early_camera.artifact.body_material_scan": ["material_scanner"],
		"src.early_camera.artifact.uv_label_fasteners": ["uv_lamp"]
	}
}

const EXPECTED_PROVENANCE := {
	"garage_lamp": "src.garage_lamp.document.service_receipt",
	"telephone_trace": "src.telephone_trace.document.safety_repair_log",
	"early_camera": "src.early_camera.document.display_serial_register"
}

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(test_id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({
		"id": test_id,
		"name": name,
		"executed": true,
		"passed": passed,
		"evidence": evidence
	})


func finish(gs: Node) -> void:
	var passed: int = results.filter(func(row: Dictionary): return bool(row.get("passed", false))).size()
	var report: Dictionary = {
		"suite": "R3 Stage 3 Authored Cases",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"skipped": 0,
		"expectedCount": EXPECTED_TEST_COUNT,
		"tests": results
	}
	var output: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	var log_lines: Array = [
		"suite=R3 Stage 3 Authored Cases",
		"executed=%d" % results.size(),
		"passed=%d" % passed,
		"failed=%d" % (results.size() - passed),
		"skipped=0"
	]
	for result_value: Variant in results:
		var result: Dictionary = result_value as Dictionary
		log_lines.append("%s=%s" % [String(result.get("id", "")), "PASS" if bool(result.get("passed", false)) else "FAIL"])
	var log_output: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if log_output != null:
		log_output.store_string("\n".join(log_lines) + "\n")
		log_output.close()
	print(JSON.stringify(report))
	gs.persistence_enabled = false
	quit(0 if passed == EXPECTED_TEST_COUNT and results.size() == EXPECTED_TEST_COUNT else 1)


func blocked_remaining(code: String) -> void:
	var rows: Array = [
		["S3-AUTHORED-GENERIC-01", "Stage 3 stays on generic registry, public-state, and resolver paths"],
		["S3-AUTHORED-STRUCTURE-01", "Stage 3 evidence graphs meet the contested-source contract"],
		["S3-AUTHORED-RISK-01", "Stage 3 risks and tool gates are exact and differentiated"],
		["S3-AUTHORED-PROVENANCE-01", "Stage 3 provenance bridges once without private leakage"],
		["S3-AUTHORED-OUTCOMES-01", "Stage 3 ordered outcome rules execute the 4/3/2/fallback ladder"],
		["S3-AUTHORED-PHONE-FRESH-01", "Fresh Telephone Trace issuance uses artifact 015"],
		["S3-AUTHORED-PHONE-LEGACY-01", "Legacy Telephone Trace artifact 010 remains untouched"]
	]
	for row_value: Variant in rows:
		var row: Array = row_value as Array
		record(String(row[0]), String(row[1]), false, {"code": code})


func stage_three_profile(gs: Node) -> Dictionary:
	var profile: Dictionary = gs.default_player_profile()
	profile["highestUnlockedStage"] = 3
	profile["clearedStages"] = [1, 2]
	profile["stageBest"] = {"1": 55.0, "2": 58.0}
	return profile


func start_stage_three(gs: Node) -> Dictionary:
	gs.persistence_enabled = false
	gs.player_profile = stage_three_profile(gs)
	var started: Dictionary = gs.new_game(3)
	gs.persistence_enabled = false
	return started


func begin_stage_three_case(gs: Node, case_id: String) -> Dictionary:
	var started: Dictionary = start_stage_three(gs)
	var artifact: Dictionary = gs.begin_case(case_id) if bool(started.get("ok", false)) else {}
	return {"start": started, "artifact": artifact}


func state_signature(gs: Node) -> String:
	return JSON.stringify({"run": gs.save_payload(), "profile": gs.profile_payload()})


func evidence_by_id(definition: Dictionary, evidence_id: String) -> Dictionary:
	for evidence_value: Variant in definition.get("evidence", []):
		if evidence_value is Dictionary and String((evidence_value as Dictionary).get("id", "")) == evidence_id:
			return evidence_value as Dictionary
	return {}


func unique_strings(values: Array) -> Array:
	var output: Array = []
	for value: Variant in values:
		var text: String = String(value)
		if not output.has(text):
			output.append(text)
	return output


func source_kinds(definition: Dictionary) -> Array:
	var kinds: Array = []
	for evidence_value: Variant in definition.get("evidence", []):
		if evidence_value is Dictionary:
			kinds.append(String((evidence_value as Dictionary).get("source", {}).get("kind", "")))
	kinds = unique_strings(kinds)
	kinds.sort()
	return kinds


func independence_groups(definition: Dictionary) -> Array:
	var groups: Array = []
	for evidence_value: Variant in definition.get("evidence", []):
		if evidence_value is Dictionary:
			groups.append(String((evidence_value as Dictionary).get("independence_key", "")))
	return unique_strings(groups)


func relation_summary(definition: Dictionary) -> Dictionary:
	var hypothesis_ids: Array = []
	for hypothesis_value: Variant in definition.get("hypotheses", []):
		if hypothesis_value is Dictionary:
			hypothesis_ids.append(String((hypothesis_value as Dictionary).get("id", "")))
	var by_hypothesis: Dictionary = {}
	for hypothesis_id: String in hypothesis_ids:
		by_hypothesis[hypothesis_id] = []
	for evidence_value: Variant in definition.get("evidence", []):
		if not evidence_value is Dictionary:
			continue
		for relation_value: Variant in (evidence_value as Dictionary).get("relations", []):
			if not relation_value is Dictionary:
				continue
			var relation: Dictionary = relation_value as Dictionary
			var hypothesis_id: String = String(relation.get("hypothesis_id", ""))
			var stance: String = String(relation.get("stance", ""))
			if by_hypothesis.has(hypothesis_id) and not (by_hypothesis[hypothesis_id] as Array).has(stance):
				(by_hypothesis[hypothesis_id] as Array).append(stance)
	return by_hypothesis


func satisfy_requirements(gs: Node, case_id: String, definition: Dictionary, evidence_id: String, visiting: Dictionary = {}) -> bool:
	if visiting.has(evidence_id):
		return false
	visiting[evidence_id] = true
	var evidence: Dictionary = evidence_by_id(definition, evidence_id)
	if evidence.is_empty():
		return false
	for requirement_value: Variant in evidence.get("unlock", {}).get("requires_all", []):
		var requirement_id: String = String(requirement_value)
		var discovered_ids: Array = gs.get_case_public_state(case_id).get("discoveredEvidence", []).map(
			func(row: Dictionary): return String(row.get("id", ""))
		)
		if discovered_ids.has(requirement_id):
			continue
		if not satisfy_requirements(gs, case_id, definition, requirement_id, visiting):
			return false
		var requirement: Dictionary = evidence_by_id(definition, requirement_id)
		var tools: Array = requirement.get("unlock", {}).get("requires_tools", [])
		if not tools.is_empty():
			gs.select_tool(String(tools[0]))
		var discovered: Dictionary = gs.discover_case_evidence(case_id, requirement_id)
		if not bool(discovered.get("ok", false)) or not String(discovered.get("code", "")) in ["DISCOVERED", "ALREADY_DISCOVERED"]:
			return false
	visiting.erase(evidence_id)
	return true


func discover_all(gs: Node, case_id: String) -> Array:
	var discovered_ids: Array = []
	for _pass: int in range(20):
		var public_state: Dictionary = gs.get_case_public_state(case_id)
		var progressed: bool = false
		for row_value: Variant in public_state.get("availableEvidence", []):
			if not row_value is Dictionary:
				continue
			var row: Dictionary = row_value as Dictionary
			var required_tools: Array = row.get("requiredTools", [])
			if not required_tools.is_empty():
				gs.select_tool(String(required_tools[0]))
			var result: Dictionary = gs.discover_case_evidence(case_id, String(row.get("id", "")))
			if bool(result.get("ok", false)) and String(result.get("code", "")) == "DISCOVERED":
				discovered_ids.append(String(row.get("id", "")))
				progressed = true
		if not progressed:
			break
	return discovered_ids


func citation_rows_for_relation(definition: Dictionary, hypothesis_id: String, stance: String, count: int) -> Array:
	var rows: Array = []
	var groups: Array = []
	for evidence_value: Variant in definition.get("evidence", []):
		if not evidence_value is Dictionary:
			continue
		var evidence: Dictionary = evidence_value as Dictionary
		var group_id: String = String(evidence.get("independence_key", ""))
		if groups.has(group_id):
			continue
		var matches: bool = false
		for relation_value: Variant in evidence.get("relations", []):
			if relation_value is Dictionary:
				var relation: Dictionary = relation_value as Dictionary
				if String(relation.get("hypothesis_id", "")) == hypothesis_id and String(relation.get("stance", "")) == stance:
					matches = true
					break
		if matches:
			groups.append(group_id)
			rows.append(String(evidence.get("id", "")))
			if rows.size() == count:
				break
	return rows


func wrong_hypothesis(definition: Dictionary) -> String:
	var canonical: String = String(definition.get("canonical_hypothesis_id", ""))
	for hypothesis_value: Variant in definition.get("hypotheses", []):
		if hypothesis_value is Dictionary:
			var hypothesis_id: String = String((hypothesis_value as Dictionary).get("id", ""))
			if not hypothesis_id.is_empty() and hypothesis_id != canonical:
				return hypothesis_id
	return ""


func rule_ladder_exact(definition: Dictionary) -> bool:
	var rules_value: Variant = definition.get("resolution", {}).get("outcome_rules", null)
	if not rules_value is Array:
		return false
	var rules: Array = rules_value
	if rules.size() != 4:
		return false
	for rule_value: Variant in rules:
		if not rule_value is Dictionary:
			return false
		var rule: Dictionary = rule_value as Dictionary
		for key: String in ["outcome_id", "correctness", "requires_all_required_sources", "minimum_independent_groups", "minimum_citations", "minimum_net_support", "fallback"]:
			if not rule.has(key):
				return false
		if not rule.get("minimum_independent_groups") is int or not rule.get("minimum_citations") is int or not rule.get("minimum_net_support") is int:
			return false
	var masterful: Dictionary = rules[0]
	var credible: Dictionary = rules[1]
	var mistaken: Dictionary = rules[2]
	var fallback: Dictionary = rules[3]
	return rules.map(func(rule: Dictionary): return String(rule.get("outcome_id", ""))) \
		== ["masterful", "credible", "mistaken", "reviewed_with_mentor"] \
		and String(masterful.get("correctness", "")) == "CORRECT" \
		and not bool(masterful.get("requires_all_required_sources", true)) \
		and int(masterful.get("minimum_independent_groups", -1)) == 4 \
		and int(masterful.get("minimum_citations", -1)) == 4 \
		and int(masterful.get("minimum_net_support", -1)) == 4 \
		and String(credible.get("correctness", "")) == "CORRECT" \
		and not bool(credible.get("requires_all_required_sources", true)) \
		and int(credible.get("minimum_independent_groups", -1)) == 3 \
		and int(credible.get("minimum_citations", -1)) == 3 \
		and int(credible.get("minimum_net_support", -1)) == 3 \
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


func reason_has(tags: Array, code: String) -> bool:
	for tag_value: Variant in tags:
		if tag_value is Dictionary and String((tag_value as Dictionary).get("code", "")) == code:
			return true
	return false


func public_private_fields_hidden(public_state: Dictionary) -> bool:
	var payload: String = JSON.stringify(public_state)
	for token: String in [
		"canonical_hypothesis_id", "winning_hypothesis_id", "authoring_truth_hypothesis_id",
		"authenticityTruth", "trueMarketBaseline", "trueRarity", "trueHistoricalSignificance",
		"originalParts", "replacementParts", "public_clue_id"
	]:
		if payload.contains(token):
			return false
	return true


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.persistence_enabled = false

	var required_methods: Array = [
		"new_game", "begin_case", "case_definition", "discover_case_evidence",
		"get_case_public_state", "evaluate_case_submission", "listing_public_status_tags",
		"auction_public_reason_tags"
	]
	var missing_methods: Array = []
	for method_name: String in required_methods:
		if not gs.has_method(method_name):
			missing_methods.append(method_name)
	var definitions: Dictionary = {}
	var fallback_count: int = 0
	var identity_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = registry.get_case_v2(case_id)
		definitions[case_id] = definition
		var public_definition: Dictionary = gs.case_definition(case_id)
		if definition.is_empty() or int(public_definition.get("schema_version", 0)) != 2:
			fallback_count += 1
		identity_rows[case_id] = {
			"schemaVersion": definition.get("schema_version", 0),
			"artifactSpecId": definition.get("artifact_spec_id", ""),
			"campaignRewardSpecId": registry.get_case(case_id).get("rewardSpecId", ""),
			"runtimeExact": definition == public_definition
		}
	var stage_definition: Dictionary = registry.get_stage_definition(3)
	var data_ready: bool = missing_methods.is_empty() and fallback_count == 0
	var data_ok: bool = data_ready and registry.authored_case_errors.is_empty() \
		and registry.authored_cases_v2.size() >= CASE_IDS.size() \
		and CASE_IDS.all(func(case_id: String): return registry.authored_cases_v2.has(case_id)) \
		and stage_definition.get("case_ids", []) == CASE_IDS \
		and is_equal_approx(float(registry.stage_difficulty_multiplier(3)), pow(1.07, 2))
	for case_id: String in CASE_IDS:
		data_ok = data_ok and String((definitions[case_id] as Dictionary).get("artifact_spec_id", "")) == String(EXPECTED_ARTIFACT_SPECS[case_id]) \
			and bool((identity_rows[case_id] as Dictionary).get("runtimeExact", false))
	record(
		"S3-AUTHORED-DATA-01",
		"Stage 3 resolves its three ordered authored-v2 definitions with zero fallback as the registry grows",
		data_ok,
		{"missingMethods": missing_methods, "registryErrors": registry.authored_case_errors, "authoredCount": registry.authored_cases_v2.size(), "caseOrder": stage_definition.get("case_ids", []), "fallbackCount": fallback_count, "difficultyMultiplier": registry.stage_difficulty_multiplier(3), "cases": identity_rows}
	)
	if not data_ready:
		blocked_remaining("STAGE3_AUTHORED_DATA_NOT_READY")
		finish(gs)
		return

	# Generic architecture: case IDs may exist in data and tests, but never as
	# resolver/renderer branches in production GameState or Main.
	var game_state_source: String = FileAccess.get_file_as_string("res://scripts/game_state.gd")
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main3d.gd")
	var runtime_registry_source: String = FileAccess.get_file_as_string("res://scripts/runtime_registry.gd")
	var source_hits: Dictionary = {}
	var generic_ok: bool = runtime_registry_source.contains("normalize_authored_case_v2") \
		and game_state_source.contains("evaluate_case_submission") \
		and main_source.contains("show_case_dossier")
	for case_id: String in CASE_IDS:
		var hits: Dictionary = {
			"gameState": game_state_source.contains(case_id),
			"main3d": main_source.contains(case_id),
			"runtimeRegistry": runtime_registry_source.contains(case_id)
		}
		source_hits[case_id] = hits
		generic_ok = generic_ok and not bool(hits.get("gameState", false)) \
			and not bool(hits.get("main3d", false)) and not bool(hits.get("runtimeRegistry", false))
	var generic_fixture: Dictionary = begin_stage_three_case(gs, "garage_lamp")
	var generic_public: Dictionary = gs.get_case_public_state("garage_lamp")
	generic_ok = generic_ok and not (generic_fixture.get("artifact", {}) as Dictionary).is_empty() \
		and bool(generic_public.get("ok", false)) and String(generic_public.get("caseId", "")) == "garage_lamp" \
		and generic_public.has("hypotheses") and generic_public.has("evidence") and generic_public.has("availableEvidence")
	record(
		"S3-AUTHORED-GENERIC-01",
		"Stage 3 stays on generic authored normalization, public-state, resolver, and dossier paths with no case-id branches",
		generic_ok,
		{"caseIdHits": source_hits, "genericTokens": {"normalizer": runtime_registry_source.contains("normalize_authored_case_v2"), "evaluator": game_state_source.contains("evaluate_case_submission"), "dossier": main_source.contains("show_case_dossier")}, "publicContractKeys": generic_public.keys()}
	)

	# Four source kinds, five-plus genuinely independent groups, support/refute
	# coverage, and at least one real dependency rejection per case.
	var structure_ok: bool = true
	var structure_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var relations: Dictionary = relation_summary(definition)
		var every_hypothesis_linked: bool = not relations.is_empty()
		var collective_stances: Array = []
		for hypothesis_id: String in relations.keys():
			var stances: Array = relations[hypothesis_id]
			every_hypothesis_linked = every_hypothesis_linked and not stances.is_empty()
			for stance_value: Variant in stances:
				if not collective_stances.has(String(stance_value)):
					collective_stances.append(String(stance_value))
		var support_and_refute_present: bool = collective_stances.has("SUPPORT") and collective_stances.has("REFUTE")
		var dependency_rows: Array = definition.get("evidence", []).filter(
			func(row: Dictionary): return not row.get("unlock", {}).get("requires_all", []).is_empty()
		)
		var locked_result: Dictionary = {}
		var fixture: Dictionary = begin_stage_three_case(gs, case_id)
		if not dependency_rows.is_empty() and not (fixture.get("artifact", {}) as Dictionary).is_empty():
			locked_result = gs.discover_case_evidence(case_id, String((dependency_rows[0] as Dictionary).get("id", "")))
		var rules: Array = definition.get("resolution", {}).get("outcome_rules", [])
		var masterful: Dictionary = rules[0] if not rules.is_empty() and rules[0] is Dictionary else {}
		var one_source_solve_impossible: bool = int(masterful.get("minimum_citations", 0)) >= 2 \
			and int(masterful.get("minimum_independent_groups", 0)) >= 2 \
			and int(masterful.get("minimum_net_support", 0)) >= 2
		var case_ok: bool = definition.get("hypotheses", []).size() == 3 \
			and source_kinds(definition) == ["ARTIFACT", "DOCUMENT", "NPC", "REFERENCE"] \
			and independence_groups(definition).size() >= 5 \
			and every_hypothesis_linked and support_and_refute_present and dependency_rows.size() >= 1 \
			and one_source_solve_impossible \
			and not bool(locked_result.get("ok", true)) and String(locked_result.get("code", "")) == "EVIDENCE_LOCKED"
		structure_ok = structure_ok and case_ok
		structure_rows[case_id] = {"hypotheses": definition.get("hypotheses", []).size(), "sourceKinds": source_kinds(definition), "groups": independence_groups(definition), "relations": relations, "everyHypothesisLinked": every_hypothesis_linked, "collectiveStances": collective_stances, "supportAndRefutePresent": support_and_refute_present, "dependencyRows": dependency_rows.map(func(row: Dictionary): return row.get("id", "")), "lockedResult": locked_result, "masterfulThresholds": masterful, "oneSourceSolveImpossible": one_source_solve_impossible, "ok": case_ok}
	record(
		"S3-AUTHORED-STRUCTURE-01",
		"Every Stage 3 case has four evidence kinds, five-plus groups, contested hypotheses, dependencies, and no one-source masterful path",
		structure_ok,
		structure_rows
	)

	# Exact Stage 3 risks and differentiated tool gates, including wrong-tool
	# mutation-zero and correctly scaled risk penalties through the public API.
	var risk_ok: bool = true
	var risk_rows: Dictionary = {}
	var all_risky_tool_sets: Array = []
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var counts: Dictionary = {"NONE": 0, "LOW": 0, "HIGH": 0}
		var actual_tool_map: Dictionary = {}
		var runtime_rows: Array = []
		for evidence_value: Variant in definition.get("evidence", []):
			if not evidence_value is Dictionary:
				continue
			var evidence: Dictionary = evidence_value as Dictionary
			var level: String = String(evidence.get("risk", {}).get("level", "NONE"))
			counts[level] = int(counts.get(level, 0)) + 1
			if level == "NONE":
				continue
			var evidence_id: String = String(evidence.get("id", ""))
			var tools: Array = evidence.get("unlock", {}).get("requires_tools", [])
			actual_tool_map[evidence_id] = tools.duplicate()
			all_risky_tool_sets.append(tools.duplicate())
			var fixture: Dictionary = begin_stage_three_case(gs, case_id)
			var artifact: Dictionary = fixture.get("artifact", {})
			var prerequisites_ok: bool = not artifact.is_empty() and satisfy_requirements(gs, case_id, definition, evidence_id)
			var wrong_tool: String = "soft_brush"
			if tools.has(wrong_tool):
				wrong_tool = "uv_lamp" if not tools.has("uv_lamp") else "precision_screwdriver"
			var wrong_selected: bool = bool(gs.select_tool(wrong_tool))
			var wrong_state_before: String = state_signature(gs)
			var wrong_rng_before: int = int(gs.rng.state)
			var wrong_result: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
			var wrong_ok: bool = prerequisites_ok and wrong_selected \
				and not bool(wrong_result.get("ok", true)) and String(wrong_result.get("code", "")) == "TOOL_REQUIRED" \
				and state_signature(gs) == wrong_state_before and int(gs.rng.state) == wrong_rng_before
			if not tools.is_empty():
				gs.select_tool(String(tools[0]))
			var integrity_before: float = float(artifact.get("historicalIntegrity", 0.0))
			var discovered: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
			var expected_penalty: float = (1.0 if level == "LOW" else 3.0) * float(registry.stage_difficulty_multiplier(3))
			var integrity_after: float = float(artifact.get("historicalIntegrity", 0.0))
			var correct_ok: bool = bool(discovered.get("ok", false)) and String(discovered.get("code", "")) == "DISCOVERED" \
				and is_equal_approx(float(discovered.get("appliedRiskPenalty", -1.0)), expected_penalty) \
				and is_equal_approx(integrity_before - integrity_after, expected_penalty)
			runtime_rows.append({"evidenceId": evidence_id, "level": level, "tools": tools, "wrongTool": wrong_tool, "wrongResult": wrong_result, "wrongMutation0": wrong_ok, "expectedPenalty": expected_penalty, "discovery": discovered, "integrity": [integrity_before, integrity_after], "ok": wrong_ok and correct_ok})
		var none_majority: bool = int(counts.get("NONE", 0)) > int(counts.get("LOW", 0)) + int(counts.get("HIGH", 0))
		var case_ok: bool = counts == EXPECTED_RISKS[case_id] \
			and actual_tool_map == EXPECTED_RISK_TOOLS[case_id] and none_majority \
			and runtime_rows.all(func(row: Dictionary): return bool(row.get("ok", false)))
		if case_id in ["telephone_trace", "early_camera"]:
			var case_tools: Array = []
			for tool_values: Variant in actual_tool_map.values():
				for tool_value: Variant in tool_values as Array:
					if not case_tools.has(String(tool_value)):
						case_tools.append(String(tool_value))
			case_ok = case_ok and case_tools.size() == 2
		risk_ok = risk_ok and case_ok
		risk_rows[case_id] = {"counts": counts, "expectedCounts": EXPECTED_RISKS[case_id], "toolMap": actual_tool_map, "expectedToolMap": EXPECTED_RISK_TOOLS[case_id], "noneMajority": none_majority, "runtime": runtime_rows, "ok": case_ok}
	var shared_tool_candidates: Array = all_risky_tool_sets[0].duplicate() if not all_risky_tool_sets.is_empty() else []
	for tool_set_value: Variant in all_risky_tool_sets:
		var tool_set: Array = tool_set_value as Array
		shared_tool_candidates = shared_tool_candidates.filter(func(tool: Variant): return tool_set.has(tool))
	var distinct_risky_tools: Array = []
	for tool_set_value: Variant in all_risky_tool_sets:
		for tool_value: Variant in tool_set_value as Array:
			if not distinct_risky_tools.has(String(tool_value)):
				distinct_risky_tools.append(String(tool_value))
	risk_ok = risk_ok and shared_tool_candidates.is_empty() and distinct_risky_tools.size() == 3
	record(
		"S3-AUTHORED-RISK-01",
		"Stage 3 has exact LOW/HIGH/NONE counts, differentiated risky tools, wrong-tool rejection, and no universal risky-path tool",
		risk_ok,
		{"cases": risk_rows, "distinctRiskyTools": distinct_risky_tools, "universalRiskyTools": shared_tool_candidates}
	)

	# One strong document per case is the only provenance bridge. Public listing
	# reasons transition on discovery while private truth never affects them or
	# escapes the public case payload.
	var provenance_ok: bool = true
	var provenance_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var tagged: Array = definition.get("evidence", []).filter(
			func(row: Dictionary): return String(row.get("public_clue_id", "")) == "PROVENANCE"
		)
		var tagged_row: Dictionary = tagged[0] if tagged.size() == 1 and tagged[0] is Dictionary else {}
		var fixture: Dictionary = begin_stage_three_case(gs, case_id)
		var artifact: Dictionary = fixture.get("artifact", {})
		var public_before: Dictionary = gs.get_case_public_state(case_id)
		var before_listing: Array = gs.listing_public_status_tags(artifact, "UNCERTAIN") if not artifact.is_empty() else []
		var before_auction: Array = gs.auction_public_reason_tags(artifact, {}, "NO_SALE", {"reserve": 100, "hammer": 0, "reserve_met": false}) if not artifact.is_empty() else []
		var evidence_id: String = String(tagged_row.get("id", ""))
		var prerequisites_ok: bool = not artifact.is_empty() and not tagged_row.is_empty() \
			and satisfy_requirements(gs, case_id, definition, evidence_id)
		var tools: Array = tagged_row.get("unlock", {}).get("requires_tools", [])
		if not tools.is_empty():
			gs.select_tool(String(tools[0]))
		var discovery: Dictionary = gs.discover_case_evidence(case_id, evidence_id) if prerequisites_ok else {}
		var public_after: Dictionary = gs.get_case_public_state(case_id)
		var after_listing: Array = gs.listing_public_status_tags(artifact, "UNCERTAIN") if not artifact.is_empty() else []
		var after_auction: Array = gs.auction_public_reason_tags(artifact, {}, "BID", {}) if not artifact.is_empty() else []
		var hidden_variant: Dictionary = artifact.duplicate(true)
		hidden_variant["authenticityTruth"] = "FORGERY"
		hidden_variant["trueRarity"] = 99.0
		hidden_variant["trueHistoricalSignificance"] = 77.0
		hidden_variant["trueMarketBaseline"] = 999999
		hidden_variant["originalParts"] = 0
		hidden_variant["replacementParts"] = 99
		var hidden_invariant: bool = gs.listing_public_status_tags(hidden_variant, "UNCERTAIN") == after_listing \
			and gs.auction_public_reason_tags(hidden_variant, {}, "BID", {}) == after_auction
		var case_ok: bool = tagged.size() == 1 and evidence_id == String(EXPECTED_PROVENANCE[case_id]) \
			and String(tagged_row.get("source", {}).get("kind", "")) == "DOCUMENT" \
			and String(tagged_row.get("reliability", "")) == "HIGH" \
			and artifact.get("knownClues", []).count("PROVENANCE") == 1 \
			and reason_has(before_listing, "PROVENANCE_UNCERTAIN") and reason_has(before_auction, "PROVENANCE_UNCERTAIN") \
			and bool(discovery.get("ok", false)) and String(discovery.get("code", "")) == "DISCOVERED" \
			and reason_has(after_listing, "PROVENANCE_STRONG") and reason_has(after_auction, "PROVENANCE_STRONG") \
			and public_private_fields_hidden(public_before) and public_private_fields_hidden(public_after) and hidden_invariant
		provenance_ok = provenance_ok and case_ok
		provenance_rows[case_id] = {"taggedCount": tagged.size(), "evidenceId": evidence_id, "sourceKind": tagged_row.get("source", {}).get("kind", ""), "reliability": tagged_row.get("reliability", ""), "beforeKnownClues": 0 if reason_has(before_listing, "PROVENANCE_UNCERTAIN") else -1, "beforeListing": before_listing, "beforeAuction": before_auction, "discovery": discovery, "knownClueCount": artifact.get("knownClues", []).count("PROVENANCE") if not artifact.is_empty() else -1, "afterListing": after_listing, "afterAuction": after_auction, "publicPrivateHidden": public_private_fields_hidden(public_before) and public_private_fields_hidden(public_after), "hiddenTruthInvariant": hidden_invariant, "ok": case_ok}
	record(
		"S3-AUTHORED-PROVENANCE-01",
		"Each Stage 3 case exposes exactly one strong-document provenance bridge with uncertain-to-strong public reasons and zero private leakage",
		provenance_ok,
		provenance_rows
	)

	# Ordered rules are verified structurally and through the real evaluator:
	# correct 4/4 masterful, correct 3/3 credible, correct 2 fallback, incorrect
	# 2 mistaken, incorrect 1 fallback, and empty citations fail closed.
	var outcomes_ok: bool = true
	var outcome_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var fixture: Dictionary = begin_stage_three_case(gs, case_id)
		var discovered: Array = discover_all(gs, case_id)
		var canonical: String = String(definition.get("canonical_hypothesis_id", ""))
		var wrong: String = wrong_hypothesis(definition)
		var correct_citations: Array = citation_rows_for_relation(definition, canonical, "SUPPORT", 4)
		var wrong_citations: Array = citation_rows_for_relation(definition, wrong, "REFUTE", 2)
		var before_signature: String = state_signature(gs)
		var before_rng: int = int(gs.rng.state)
		var empty: Dictionary = gs.evaluate_case_submission(case_id, canonical, [])
		var correct_one: Dictionary = gs.evaluate_case_submission(case_id, canonical, correct_citations.slice(0, 1))
		var correct_two: Dictionary = gs.evaluate_case_submission(case_id, canonical, correct_citations.slice(0, 2))
		var correct_three: Dictionary = gs.evaluate_case_submission(case_id, canonical, correct_citations.slice(0, 3))
		var correct_four: Dictionary = gs.evaluate_case_submission(case_id, canonical, correct_citations)
		var wrong_one: Dictionary = gs.evaluate_case_submission(case_id, wrong, wrong_citations.slice(0, 1))
		var wrong_two: Dictionary = gs.evaluate_case_submission(case_id, wrong, wrong_citations)
		var case_ok: bool = not (fixture.get("artifact", {}) as Dictionary).is_empty() \
			and discovered.size() == definition.get("evidence", []).size() \
			and rule_ladder_exact(definition) and correct_citations.size() == 4 and wrong_citations.size() == 2 \
			and not bool(empty.get("ok", true)) and String(empty.get("code", "")) == "CITATION_REQUIRED" \
			and bool(correct_one.get("ok", false)) and String(correct_one.get("outcome", "")) == "reviewed_with_mentor" \
			and String(correct_one.get("substantiation", "")) == "INCONCLUSIVE" \
			and bool(correct_two.get("ok", false)) and String(correct_two.get("outcome", "")) == "reviewed_with_mentor" \
			and bool(correct_three.get("ok", false)) and String(correct_three.get("outcome", "")) == "credible" \
			and int(correct_three.get("independentSourceCount", -1)) == 3 and int(correct_three.get("netScore", -1)) >= 3 \
			and bool(correct_four.get("ok", false)) and String(correct_four.get("outcome", "")) == "masterful" \
			and int(correct_four.get("independentSourceCount", -1)) == 4 and int(correct_four.get("netScore", -1)) >= 4 \
			and bool(correct_four.get("substantiated", false)) and String(correct_four.get("substantiation", "")) == "STRONG" \
			and bool(wrong_one.get("ok", false)) and String(wrong_one.get("outcome", "")) == "reviewed_with_mentor" \
			and bool(wrong_two.get("ok", false)) and String(wrong_two.get("outcome", "")) == "mistaken" \
			and int(wrong_two.get("netScore", 0)) < 0 and not bool(wrong_two.get("conclusionAccurate", true)) \
			and state_signature(gs) == before_signature and int(gs.rng.state) == before_rng
		outcomes_ok = outcomes_ok and case_ok
		outcome_rows[case_id] = {"rulesExact": rule_ladder_exact(definition), "discoveredCount": discovered.size(), "evidenceCount": definition.get("evidence", []).size(), "correctCitations": correct_citations, "wrongHypothesis": wrong, "wrongCitations": wrong_citations, "empty": empty, "correct1": correct_one, "correct2": correct_two, "correct3": correct_three, "correct4": correct_four, "wrong1": wrong_one, "wrong2": wrong_two, "stateMutation0": state_signature(gs) == before_signature, "rngMutation0": int(gs.rng.state) == before_rng, "ok": case_ok}
	record(
		"S3-AUTHORED-OUTCOMES-01",
		"All Stage 3 cases execute the ordered masterful 4/4, credible 3/3, mistaken wrong+2, mentor fallback ladder, with empty-report fail-closed",
		outcomes_ok,
		outcome_rows
	)

	# The approved identity correction affects only fresh Telephone Trace issue:
	# campaign reward, story base, authored artifact and runtime instance are 015.
	var phone_case: Dictionary = registry.get_case("telephone_trace")
	var phone_story: Dictionary = registry.story_artifacts.get(String(phone_case.get("storyArtifactId", "")), {})
	var phone_definition: Dictionary = definitions["telephone_trace"]
	var phone_spec: Dictionary = registry.get_spec("artifact_015")
	var old_spec: Dictionary = registry.get_spec("artifact_010")
	var fresh_fixture: Dictionary = begin_stage_three_case(gs, "telephone_trace")
	var fresh_artifact: Dictionary = fresh_fixture.get("artifact", {})
	var profile_fields_exact: bool = true
	for field_name: String in ["materialSet", "possibleFaults", "restorationProfile", "collectorTags", "visualVariant", "baseModel"]:
		profile_fields_exact = profile_fields_exact and fresh_artifact.get(field_name) == phone_spec.get(field_name)
	var fresh_ok: bool = bool(fresh_fixture.get("start", {}).get("ok", false)) and not fresh_artifact.is_empty() \
		and String(phone_case.get("rewardSpecId", "")) == "artifact_015" \
		and String(phone_story.get("baseSpecId", "")) == "artifact_015" \
		and String(phone_definition.get("artifact_spec_id", "")) == "artifact_015" \
		and String(fresh_artifact.get("artifactSpecId", "")) == "artifact_015" \
		and String(fresh_artifact.get("uniqueId", "")) == "case_telephone_trace" \
		and String(fresh_artifact.get("storyArtifactId", "")) == "story_artifact_08" \
		and int(old_spec.get("baseValue", -1)) == 281 and int(phone_spec.get("baseValue", -1)) == 376 \
		and int(phone_spec.get("baseValue", 0)) - int(old_spec.get("baseValue", 0)) == 95 \
		and int(fresh_artifact.get("baseValue", -1)) == 376 and int(fresh_artifact.get("trueMarketBaseline", -1)) == 376 \
		and String(fresh_artifact.get("visualSignature", "")) == String(registry.visual_signature("artifact_015")) \
		and profile_fields_exact
	record(
		"S3-AUTHORED-PHONE-FRESH-01",
		"Fresh Telephone Trace issuance consistently uses campaign/story/authored artifact 015 with the exact 281-to-376 base correction and derived profile",
		fresh_ok,
		{"campaignRewardSpecId": phone_case.get("rewardSpecId", ""), "storyBaseSpecId": phone_story.get("baseSpecId", ""), "authoredSpecId": phone_definition.get("artifact_spec_id", ""), "runtime": {"uid": fresh_artifact.get("uniqueId", ""), "artifactSpecId": fresh_artifact.get("artifactSpecId", ""), "storyArtifactId": fresh_artifact.get("storyArtifactId", ""), "baseValue": fresh_artifact.get("baseValue", -1), "trueMarketBaseline": fresh_artifact.get("trueMarketBaseline", -1), "baseModel": fresh_artifact.get("baseModel", ""), "visualVariant": fresh_artifact.get("visualVariant", ""), "visualSignature": fresh_artifact.get("visualSignature", "")}, "oldBaseValue": old_spec.get("baseValue", -1), "newBaseValue": phone_spec.get("baseValue", -1), "delta": int(phone_spec.get("baseValue", 0)) - int(old_spec.get("baseValue", 0)), "profileFieldsExact": profile_fields_exact}
	)

	# A durable pre-correction ledger retains artifact 010, its UID, inventory,
	# runtime state, seed-derived instance data and RNG exactly when reopened.
	var legacy_started: Dictionary = start_stage_three(gs)
	var legacy_artifact: Dictionary = gs.new_artifact("artifact_010", 930010, "case_telephone_trace")
	legacy_artifact["caseId"] = "telephone_trace"
	legacy_artifact["storyArtifactId"] = "story_artifact_08"
	legacy_artifact["historicalIntegrity"] = 61.25
	legacy_artifact["knownClues"] = ["MATERIAL"]
	gs.inventory = [legacy_artifact]
	gs.campaign_state.activeCaseId = "telephone_trace"
	gs.campaign_state.caseArtifactLedger["telephone_trace"] = {
		"issued": true,
		"artifactUid": "case_telephone_trace",
		"disposition": "INVENTORY",
		"saleTransactionId": "",
		"publicConditionSnapshot": {"historicalIntegrity": 61.25},
		"publicAppraisalSnapshot": 281
	}
	var legacy_case_state: Dictionary = gs.ensure_case_runtime_state("telephone_trace")
	legacy_case_state["selectedHypothesisId"] = String(phone_definition.get("canonical_hypothesis_id", ""))
	legacy_case_state["discoveredEvidenceIds"] = ["src.telephone_trace.artifact.shell_material_serial"]
	var legacy_payload_before: String = state_signature(gs)
	var legacy_inventory_before: Dictionary = legacy_artifact.duplicate(true)
	var legacy_ledger_before: Dictionary = gs.campaign_state.caseArtifactLedger["telephone_trace"].duplicate(true)
	var legacy_state_before: Dictionary = legacy_case_state.duplicate(true)
	var legacy_rng_before: int = int(gs.rng.state)
	var legacy_returned: Dictionary = gs.begin_case("telephone_trace")
	var legacy_ok: bool = bool(legacy_started.get("ok", false)) \
		and String(legacy_returned.get("uniqueId", "")) == "case_telephone_trace" \
		and String(legacy_returned.get("artifactSpecId", "")) == "artifact_010" \
		and int(legacy_returned.get("baseValue", -1)) == 281 \
		and gs.inventory.size() == 1 and gs.inventory[0] == legacy_inventory_before \
		and gs.campaign_state.caseArtifactLedger["telephone_trace"] == legacy_ledger_before \
		and gs.campaign_state.caseStates["telephone_trace"] == legacy_state_before \
		and state_signature(gs) == legacy_payload_before and int(gs.rng.state) == legacy_rng_before
	record(
		"S3-AUTHORED-PHONE-LEGACY-01",
		"An already-issued Telephone Trace artifact 010 keeps its UID, instance, ledger, case state, and RNG exactly with no migration",
		legacy_ok,
		{"returned": {"uid": legacy_returned.get("uniqueId", ""), "artifactSpecId": legacy_returned.get("artifactSpecId", ""), "baseValue": legacy_returned.get("baseValue", -1)}, "inventoryCount": gs.inventory.size(), "inventoryExact": gs.inventory[0] == legacy_inventory_before if not gs.inventory.is_empty() else false, "ledgerExact": gs.campaign_state.caseArtifactLedger["telephone_trace"] == legacy_ledger_before, "caseStateExact": gs.campaign_state.caseStates["telephone_trace"] == legacy_state_before, "stateMutation0": state_signature(gs) == legacy_payload_before, "rngMutation0": int(gs.rng.state) == legacy_rng_before}
	)

	finish(gs)
