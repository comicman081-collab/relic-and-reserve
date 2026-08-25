extends SceneTree

## Stage 4 authored-v2 integration contract.
##
## The suite exercises only generic registry/GameState paths. It does not
## rewrite authored definitions and writes only its isolated QA report/log.

const CASE_IDS := ["false_invoice", "mislabelled_collection", "observatory_instrument"]
const NEW_CASE_IDS := ["mislabelled_collection", "observatory_instrument"]
const EXPECTED_TEST_COUNT := 7
const REPORT_PATH := "res://qa/R3_STAGE4_AUTHORED_CASES_TESTS.json"
const STAGE_MULTIPLIER := 1.225043

const EXPECTED_IDENTITIES := {
	"mislabelled_collection": {
		"spec": "artifact_018", "story": "story_artifact_11",
		"provenance": "src.mislabelled_collection.document.collection_invoice"
	},
	"observatory_instrument": {
		"spec": "artifact_011", "story": "story_artifact_12",
		"provenance": "src.observatory_instrument.document.auction_receipt"
	}
}

const EXPECTED_RISKS := {
	"mislabelled_collection": {"NONE": 5, "LOW": 1, "HIGH": 0},
	"observatory_instrument": {"NONE": 4, "LOW": 1, "HIGH": 1}
}

const EXPECTED_RISK_TOOLS := {
	"mislabelled_collection": {"LOW": ["material_scanner"], "HIGH": []},
	"observatory_instrument": {"LOW": ["material_scanner"], "HIGH": ["precision_screwdriver"]}
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
	var report := {
		"suite": "R3 Stage 4 Authored Cases",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"skipped": 0,
		"expectedCount": EXPECTED_TEST_COUNT,
		"tests": results
	}
	var report_file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(report, "  "))
		report_file.close()
	print(JSON.stringify(report))
	gs.persistence_enabled = false
	quit(0 if passed == EXPECTED_TEST_COUNT and results.size() == EXPECTED_TEST_COUNT else 1)


func blocked_remaining(code: String) -> void:
	var rows := [
		["S4-AUTHORED-GENERIC-02", "Stage 4 definitions stay on generic mutation-zero paths"],
		["S4-AUTHORED-IDENTITY-03", "Stage 4 fresh artifact identities are exact"],
		["S4-AUTHORED-STRUCTURE-04", "Stage 4 evidence graphs meet the six-source contract"],
		["S4-AUTHORED-RISK-05", "Stage 4 risk gates apply exact scaled penalties"],
		["S4-AUTHORED-PROVENANCE-06", "Stage 4 provenance bridges exactly once"],
		["S4-AUTHORED-OUTCOMES-07", "Stage 4 ordered outcomes execute through the public evaluator"]
	]
	for row: Array in rows:
		record(String(row[0]), String(row[1]), false, {"code": code})


func stage_four_profile(gs: Node) -> Dictionary:
	var profile: Dictionary = gs.default_player_profile()
	profile["highestUnlockedStage"] = 4
	profile["clearedStages"] = [1, 2, 3]
	profile["stageBest"] = {"1": 55.0, "2": 58.0, "3": 61.0}
	return profile


func start_stage_four(gs: Node) -> Dictionary:
	gs.persistence_enabled = false
	gs.player_profile = stage_four_profile(gs)
	var started: Dictionary = gs.new_game(4)
	gs.persistence_enabled = false
	return started


func begin_stage_four_case(gs: Node, case_id: String) -> Dictionary:
	var started := start_stage_four(gs)
	var artifact: Dictionary = gs.begin_case(case_id) if bool(started.get("ok", false)) else {}
	return {"start": started, "artifact": artifact}


func authority_signature(gs: Node) -> String:
	return JSON.stringify({
		"save": gs.save_payload(),
		"profile": gs.profile_payload(),
		"rng": int(gs.rng.state),
		"money": int(gs.money),
		"day": int(gs.day),
		"auction": gs.pending_auction.duplicate(true)
	})


func runtime_pressure_signature(gs: Node) -> String:
	return JSON.stringify({
		"money": int(gs.money),
		"day": int(gs.day),
		"reputation": int(gs.reputation),
		"mastery": gs.campaign_state.get("mastery", {}).duplicate(true),
		"auction": gs.pending_auction.duplicate(true),
		"rng": int(gs.rng.state)
	})


func evidence_by_id(definition: Dictionary, evidence_id: String) -> Dictionary:
	for evidence_value: Variant in definition.get("evidence", []):
		if evidence_value is Dictionary and String(evidence_value.get("id", "")) == evidence_id:
			return evidence_value
	return {}


func unique_strings(values: Array) -> Array:
	var output: Array = []
	for value: Variant in values:
		var text := String(value)
		if not output.has(text):
			output.append(text)
	return output


func source_kinds(definition: Dictionary) -> Array:
	var kinds: Array = []
	for evidence_value: Variant in definition.get("evidence", []):
		if evidence_value is Dictionary:
			kinds.append(String(evidence_value.get("source", {}).get("kind", "")))
	kinds = unique_strings(kinds)
	kinds.sort()
	return kinds


func independence_groups(definition: Dictionary) -> Array:
	var groups: Array = []
	for evidence_value: Variant in definition.get("evidence", []):
		if evidence_value is Dictionary:
			groups.append(String(evidence_value.get("independence_key", "")))
	return unique_strings(groups)


func relation_summary(definition: Dictionary) -> Dictionary:
	var matrix: Dictionary = {}
	for hypothesis_value: Variant in definition.get("hypotheses", []):
		if hypothesis_value is Dictionary:
			matrix[String(hypothesis_value.get("id", ""))] = []
	for evidence_value: Variant in definition.get("evidence", []):
		if not evidence_value is Dictionary:
			continue
		for relation_value: Variant in evidence_value.get("relations", []):
			if not relation_value is Dictionary:
				continue
			var hypothesis_id := String(relation_value.get("hypothesis_id", ""))
			var stance := String(relation_value.get("stance", ""))
			if matrix.has(hypothesis_id) and not (matrix[hypothesis_id] as Array).has(stance):
				(matrix[hypothesis_id] as Array).append(stance)
	return matrix


func satisfy_requirements(gs: Node, case_id: String, definition: Dictionary, evidence_id: String, visiting: Dictionary = {}) -> bool:
	if visiting.has(evidence_id):
		return false
	visiting[evidence_id] = true
	var evidence := evidence_by_id(definition, evidence_id)
	if evidence.is_empty():
		return false
	for requirement_value: Variant in evidence.get("unlock", {}).get("requires_all", []):
		var requirement_id := String(requirement_value)
		var discovered_ids: Array = gs.get_case_public_state(case_id).get("discoveredEvidence", []).map(
			func(row: Dictionary): return String(row.get("id", ""))
		)
		if discovered_ids.has(requirement_id):
			continue
		if not satisfy_requirements(gs, case_id, definition, requirement_id, visiting):
			return false
		var prerequisite := evidence_by_id(definition, requirement_id)
		var tools: Array = prerequisite.get("unlock", {}).get("requires_tools", [])
		if not tools.is_empty():
			gs.select_tool(String(tools[0]))
		var discovery: Dictionary = gs.discover_case_evidence(case_id, requirement_id)
		if not bool(discovery.get("ok", false)) or not String(discovery.get("code", "")) in ["DISCOVERED", "ALREADY_DISCOVERED"]:
			return false
	visiting.erase(evidence_id)
	return true


func discover_all(gs: Node, case_id: String) -> Array:
	var discovered: Array = []
	for _pass: int in range(20):
		var progressed := false
		for row_value: Variant in gs.get_case_public_state(case_id).get("availableEvidence", []):
			if not row_value is Dictionary:
				continue
			var row: Dictionary = row_value
			var tools: Array = row.get("requiredTools", [])
			if not tools.is_empty():
				gs.select_tool(String(tools[0]))
			var discovery: Dictionary = gs.discover_case_evidence(case_id, String(row.get("id", "")))
			if bool(discovery.get("ok", false)) and String(discovery.get("code", "")) == "DISCOVERED":
				discovered.append(String(row.get("id", "")))
				progressed = true
		if not progressed:
			break
	return discovered


func citation_rows_for_relation(definition: Dictionary, hypothesis_id: String, stance: String, count: int) -> Array:
	var rows: Array = []
	var groups: Array = []
	for evidence_value: Variant in definition.get("evidence", []):
		if not evidence_value is Dictionary:
			continue
		var group_id := String(evidence_value.get("independence_key", ""))
		if groups.has(group_id):
			continue
		var matches := false
		for relation_value: Variant in evidence_value.get("relations", []):
			if relation_value is Dictionary \
					and String(relation_value.get("hypothesis_id", "")) == hypothesis_id \
					and String(relation_value.get("stance", "")) == stance:
				matches = true
				break
		if matches:
			groups.append(group_id)
			rows.append(String(evidence_value.get("id", "")))
			if rows.size() == count:
				break
	return rows


func wrong_hypothesis_with_two_refutations(definition: Dictionary) -> String:
	var canonical := String(definition.get("canonical_hypothesis_id", ""))
	for hypothesis_value: Variant in definition.get("hypotheses", []):
		if not hypothesis_value is Dictionary:
			continue
		var hypothesis_id := String(hypothesis_value.get("id", ""))
		if hypothesis_id != canonical and citation_rows_for_relation(definition, hypothesis_id, "REFUTE", 2).size() == 2:
			return hypothesis_id
	return ""


func rule_ladder_exact(definition: Dictionary) -> bool:
	var rules_value: Variant = definition.get("resolution", {}).get("outcome_rules", null)
	if not rules_value is Array or rules_value.size() != 4:
		return false
	var rules: Array = rules_value
	for rule_value: Variant in rules:
		if not rule_value is Dictionary:
			return false
		for key: String in ["outcome_id", "correctness", "requires_all_required_sources", "minimum_independent_groups", "minimum_citations", "minimum_net_support", "fallback"]:
			if not rule_value.has(key):
				return false
	var masterful: Dictionary = rules[0]
	var credible: Dictionary = rules[1]
	var mistaken: Dictionary = rules[2]
	var fallback: Dictionary = rules[3]
	return rules.map(func(rule: Dictionary): return String(rule.get("outcome_id", ""))) \
		== ["masterful", "credible", "mistaken", "reviewed_with_mentor"] \
		and masterful.get("correctness", "") == "CORRECT" \
		and int(masterful.get("minimum_independent_groups", -1)) == 4 \
		and int(masterful.get("minimum_citations", -1)) == 4 \
		and int(masterful.get("minimum_net_support", -1)) == 4 \
		and credible.get("correctness", "") == "CORRECT" \
		and int(credible.get("minimum_independent_groups", -1)) == 3 \
		and int(credible.get("minimum_citations", -1)) == 3 \
		and int(credible.get("minimum_net_support", -1)) == 3 \
		and mistaken.get("correctness", "") == "INCORRECT" \
		and int(mistaken.get("minimum_citations", -1)) == 2 \
		and fallback.get("correctness", "") == "ANY" and bool(fallback.get("fallback", false))


func reason_has(tags: Array, code: String) -> bool:
	for tag_value: Variant in tags:
		if tag_value is Dictionary and String(tag_value.get("code", "")) == code:
			return true
	return false


func public_private_fields_hidden(public_state: Dictionary) -> bool:
	var payload := JSON.stringify(public_state)
	for token: String in [
		"canonical_hypothesis_id", "winning_hypothesis_id", "authoring_truth_hypothesis_id",
		"authenticityTruth", "trueMarketBaseline", "trueRarity", "trueHistoricalSignificance",
		"originalParts", "replacementParts", "public_clue_id"
	]:
		if payload.contains(token):
			return false
	return true


func run() -> void:
	var registry: Node = get_root().get_node("RuntimeRegistry")
	var gs: Node = get_root().get_node("GameState")
	gs.persistence_enabled = false

	var definitions: Dictionary = {}
	var missing_methods: Array = []
	for method_name: String in [
		"new_game", "begin_case", "case_definition", "discover_case_evidence",
		"get_case_public_state", "evaluate_case_submission", "listing_public_status_tags",
		"auction_public_reason_tags"
	]:
		if not gs.has_method(method_name):
			missing_methods.append(method_name)
	var fallback_count := 0
	for case_id: String in NEW_CASE_IDS:
		var definition: Dictionary = registry.get_case_v2(case_id)
		definitions[case_id] = definition
		if definition.is_empty() or int(gs.case_definition(case_id).get("schema_version", 0)) != 2:
			fallback_count += 1
	var stage_definition: Dictionary = registry.get_stage_definition(4)
	var data_ready: bool = missing_methods.is_empty() and fallback_count == 0
	var data_ok: bool = data_ready and registry.authored_case_errors.is_empty() \
		and stage_definition.get("case_ids", []) == CASE_IDS \
		and is_equal_approx(float(registry.stage_difficulty_multiplier(4)), STAGE_MULTIPLIER) \
		and NEW_CASE_IDS.all(func(case_id: String): return registry.authored_cases_v2.has(case_id))
	record(
		"S4-AUTHORED-DATA-01",
		"Stage 4 resolves false invoice then both new authored-v2 cases in order with zero new-case fallback",
		data_ok,
		{"missingMethods": missing_methods, "registryErrors": registry.authored_case_errors, "authoredCount": registry.authored_cases_v2.size(), "caseOrder": stage_definition.get("case_ids", []), "fallbackCount": fallback_count, "difficultyMultiplier": registry.stage_difficulty_multiplier(4)}
	)
	if not data_ready:
		blocked_remaining("STAGE4_AUTHORED_DATA_NOT_READY")
		finish(gs)
		return

	# Registry/public-definition reads remain presentation-neutral and no new case
	# is implemented as a production source branch.
	start_stage_four(gs)
	var source_by_path := {
		"gameState": FileAccess.get_file_as_string("res://scripts/game_state.gd"),
		"main3d": FileAccess.get_file_as_string("res://scripts/main3d.gd"),
		"runtimeRegistry": FileAccess.get_file_as_string("res://scripts/runtime_registry.gd")
	}
	var before_authority := authority_signature(gs)
	var before_campaign := JSON.stringify(registry.campaign)
	var before_stage := JSON.stringify(registry.stage_definitions)
	var source_hits: Dictionary = {}
	var runtime_exact := true
	for case_id: String in NEW_CASE_IDS:
		var hits: Dictionary = {}
		for source_name: String in source_by_path.keys():
			hits[source_name] = String(source_by_path[source_name]).contains(case_id)
		runtime_exact = runtime_exact and registry.get_case_v2(case_id) == gs.case_definition(case_id)
		source_hits[case_id] = hits
	var after_authority := authority_signature(gs)
	var generic_ok: bool = runtime_exact and before_authority == after_authority \
		and before_campaign == JSON.stringify(registry.campaign) \
		and before_stage == JSON.stringify(registry.stage_definitions)
	for hits_value: Variant in source_hits.values():
		for hit_value: Variant in (hits_value as Dictionary).values():
			generic_ok = generic_ok and not bool(hit_value)
	record(
		"S4-AUTHORED-GENERIC-02",
		"Both new cases use generic registry/public paths without changing save, economy, auction, RNG, campaign schema, or case order",
		generic_ok,
		{"runtimeExact": runtime_exact, "caseIdHits": source_hits, "authorityMutation0": before_authority == after_authority, "campaignMutation0": before_campaign == JSON.stringify(registry.campaign), "stageMutation0": before_stage == JSON.stringify(registry.stage_definitions)}
	)

	# Fresh issuance aligns authored, campaign, story and runtime identities. Case
	# entry itself cannot spend currency, advance day, consume RNG, or touch auction.
	var identity_ok := true
	var identity_rows: Dictionary = {}
	for case_id: String in NEW_CASE_IDS:
		var expected: Dictionary = EXPECTED_IDENTITIES[case_id]
		var campaign_case: Dictionary = registry.get_case(case_id)
		var story: Dictionary = registry.story_artifacts.get(String(campaign_case.get("storyArtifactId", "")), {})
		var started := start_stage_four(gs)
		var pressure_before := runtime_pressure_signature(gs)
		var artifact: Dictionary = gs.begin_case(case_id)
		var pressure_after := runtime_pressure_signature(gs)
		var case_ok: bool = bool(started.get("ok", false)) and not artifact.is_empty() \
			and String(definitions[case_id].get("artifact_spec_id", "")) == String(expected.get("spec", "")) \
			and String(campaign_case.get("rewardSpecId", "")) == String(expected.get("spec", "")) \
			and String(campaign_case.get("storyArtifactId", "")) == String(expected.get("story", "")) \
			and String(story.get("baseSpecId", "")) == String(expected.get("spec", "")) \
			and String(artifact.get("artifactSpecId", "")) == String(expected.get("spec", "")) \
			and String(artifact.get("storyArtifactId", "")) == String(expected.get("story", "")) \
			and String(artifact.get("uniqueId", "")) == "case_%s" % case_id \
			and pressure_before == pressure_after \
			and registry.get_stage_definition(4).get("case_ids", []) == CASE_IDS
		identity_ok = identity_ok and case_ok
		identity_rows[case_id] = {"authoredSpec": definitions[case_id].get("artifact_spec_id", ""), "campaignSpec": campaign_case.get("rewardSpecId", ""), "story": campaign_case.get("storyArtifactId", ""), "storySpec": story.get("baseSpecId", ""), "runtimeSpec": artifact.get("artifactSpecId", ""), "uid": artifact.get("uniqueId", ""), "pressureMutation0": pressure_before == pressure_after, "ok": case_ok}
	record(
		"S4-AUTHORED-IDENTITY-03",
		"Fresh Stage 4 issuance keeps artifact 018 and 011 identities exact with economy, auction, RNG, campaign schema, and order mutation-zero",
		identity_ok,
		identity_rows
	)

	var structure_ok := true
	var structure_rows: Dictionary = {}
	for case_id: String in NEW_CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var relations := relation_summary(definition)
		var collective_stances: Array = []
		var every_hypothesis_linked := not relations.is_empty()
		for stances_value: Variant in relations.values():
			var stances: Array = stances_value
			every_hypothesis_linked = every_hypothesis_linked and not stances.is_empty()
			for stance_value: Variant in stances:
				if not collective_stances.has(String(stance_value)):
					collective_stances.append(String(stance_value))
		var dependency_rows: Array = definition.get("evidence", []).filter(
			func(row: Dictionary): return not row.get("unlock", {}).get("requires_all", []).is_empty()
		)
		var fixture := begin_stage_four_case(gs, case_id)
		var locked_result: Dictionary = {}
		if not dependency_rows.is_empty() and not fixture.get("artifact", {}).is_empty():
			locked_result = gs.discover_case_evidence(case_id, String(dependency_rows[0].get("id", "")))
		var rules: Array = definition.get("resolution", {}).get("outcome_rules", [])
		var credible: Dictionary = rules[1] if rules.size() > 1 and rules[1] is Dictionary else {}
		var one_source_credible_impossible := int(credible.get("minimum_citations", 0)) >= 3 \
			and int(credible.get("minimum_independent_groups", 0)) >= 3 \
			and int(credible.get("minimum_net_support", 0)) >= 3
		var case_ok: bool = definition.get("evidence", []).size() == 6 \
			and definition.get("hypotheses", []).size() == 3 \
			and source_kinds(definition) == ["ARTIFACT", "DOCUMENT", "NPC", "REFERENCE"] \
			and independence_groups(definition).size() == 6 and every_hypothesis_linked \
			and collective_stances.has("SUPPORT") and collective_stances.has("REFUTE") \
			and not dependency_rows.is_empty() and one_source_credible_impossible \
			and not bool(locked_result.get("ok", true)) and String(locked_result.get("code", "")) == "EVIDENCE_LOCKED"
		structure_ok = structure_ok and case_ok
		structure_rows[case_id] = {"evidence": definition.get("evidence", []).size(), "hypotheses": definition.get("hypotheses", []).size(), "sourceKinds": source_kinds(definition), "groups": independence_groups(definition), "relations": relations, "dependencies": dependency_rows.map(func(row: Dictionary): return row.get("id", "")), "lockedResult": locked_result, "credible": credible, "oneSourceCredibleImpossible": one_source_credible_impossible, "ok": case_ok}
	record(
		"S4-AUTHORED-STRUCTURE-04",
		"Each new case has six independent sources across four kinds, contested relations, a real lock, and no one-source credible path",
		structure_ok,
		structure_rows
	)

	var risk_ok := true
	var risk_rows: Dictionary = {}
	for case_id: String in NEW_CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var counts := {"NONE": 0, "LOW": 0, "HIGH": 0}
		var tools_by_level := {"LOW": [], "HIGH": []}
		var runtime_rows: Array = []
		for evidence_value: Variant in definition.get("evidence", []):
			if not evidence_value is Dictionary:
				continue
			var evidence: Dictionary = evidence_value
			var level := String(evidence.get("risk", {}).get("level", "NONE"))
			counts[level] = int(counts.get(level, 0)) + 1
			if level == "NONE":
				continue
			var evidence_id := String(evidence.get("id", ""))
			var tools: Array = evidence.get("unlock", {}).get("requires_tools", [])
			for tool_value: Variant in tools:
				if not (tools_by_level[level] as Array).has(String(tool_value)):
					(tools_by_level[level] as Array).append(String(tool_value))
			var fixture := begin_stage_four_case(gs, case_id)
			var artifact: Dictionary = fixture.get("artifact", {})
			var prerequisites_ok := not artifact.is_empty() and satisfy_requirements(gs, case_id, definition, evidence_id)
			var wrong_tool := "soft_brush"
			if tools.has(wrong_tool):
				wrong_tool = "uv_lamp"
			gs.select_tool(wrong_tool)
			var wrong_before := authority_signature(gs)
			var wrong_result: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
			var wrong_mutation_zero := authority_signature(gs) == wrong_before
			if not tools.is_empty():
				gs.select_tool(String(tools[0]))
			var integrity_before := float(artifact.get("historicalIntegrity", 0.0))
			var discovery: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
			var expected_penalty := (1.0 if level == "LOW" else 3.0) * STAGE_MULTIPLIER
			var integrity_after := float(artifact.get("historicalIntegrity", 0.0))
			var row_ok: bool = prerequisites_ok and not bool(wrong_result.get("ok", true)) \
				and String(wrong_result.get("code", "")) == "TOOL_REQUIRED" and wrong_mutation_zero \
				and bool(discovery.get("ok", false)) and String(discovery.get("code", "")) == "DISCOVERED" \
				and is_equal_approx(float(discovery.get("appliedRiskPenalty", -1.0)), expected_penalty) \
				and is_equal_approx(integrity_before - integrity_after, expected_penalty)
			runtime_rows.append({"id": evidence_id, "level": level, "tools": tools, "wrongResult": wrong_result, "wrongMutation0": wrong_mutation_zero, "expectedPenalty": expected_penalty, "actualPenalty": discovery.get("appliedRiskPenalty", -1), "integrity": [integrity_before, integrity_after], "ok": row_ok})
		var case_ok: bool = counts == EXPECTED_RISKS[case_id] \
			and tools_by_level == EXPECTED_RISK_TOOLS[case_id] \
			and runtime_rows.all(func(row: Dictionary): return bool(row.get("ok", false)))
		risk_ok = risk_ok and case_ok
		risk_rows[case_id] = {"counts": counts, "expectedCounts": EXPECTED_RISKS[case_id], "toolsByLevel": tools_by_level, "expectedTools": EXPECTED_RISK_TOOLS[case_id], "runtime": runtime_rows, "ok": case_ok}
	record(
		"S4-AUTHORED-RISK-05",
		"Stage 4 applies exact NONE/LOW/HIGH gates and 1.225043-scaled LOW/HIGH integrity penalties with wrong-tool mutation-zero",
		risk_ok,
		{"multiplier": registry.stage_difficulty_multiplier(4), "cases": risk_rows}
	)

	var provenance_ok := true
	var provenance_rows: Dictionary = {}
	for case_id: String in NEW_CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var tagged: Array = definition.get("evidence", []).filter(
			func(row: Dictionary): return String(row.get("public_clue_id", "")) == "PROVENANCE"
		)
		var tagged_row: Dictionary = tagged[0] if tagged.size() == 1 and tagged[0] is Dictionary else {}
		var fixture := begin_stage_four_case(gs, case_id)
		var artifact: Dictionary = fixture.get("artifact", {})
		var public_before: Dictionary = gs.get_case_public_state(case_id)
		var listing_before: Array = gs.listing_public_status_tags(artifact, "UNCERTAIN") if not artifact.is_empty() else []
		var auction_before: Array = gs.auction_public_reason_tags(artifact, {}, "NO_SALE", {"reserve": 100, "hammer": 0, "reserve_met": false}) if not artifact.is_empty() else []
		var evidence_id := String(tagged_row.get("id", ""))
		var prerequisites_ok := not artifact.is_empty() and not tagged_row.is_empty() \
			and satisfy_requirements(gs, case_id, definition, evidence_id)
		var tools: Array = tagged_row.get("unlock", {}).get("requires_tools", [])
		if not tools.is_empty():
			gs.select_tool(String(tools[0]))
		var discovery: Dictionary = gs.discover_case_evidence(case_id, evidence_id) if prerequisites_ok else {}
		var duplicate: Dictionary = gs.discover_case_evidence(case_id, evidence_id) if bool(discovery.get("ok", false)) else {}
		var public_after: Dictionary = gs.get_case_public_state(case_id)
		var listing_after: Array = gs.listing_public_status_tags(artifact, "UNCERTAIN") if not artifact.is_empty() else []
		var auction_after: Array = gs.auction_public_reason_tags(artifact, {}, "BID", {}) if not artifact.is_empty() else []
		var expected_id := String(EXPECTED_IDENTITIES[case_id].get("provenance", ""))
		var case_ok: bool = tagged.size() == 1 and evidence_id == expected_id \
			and tagged_row.get("source", {}).get("kind", "") == "DOCUMENT" \
			and tagged_row.get("reliability", "") == "HIGH" \
			and reason_has(listing_before, "PROVENANCE_UNCERTAIN") and reason_has(auction_before, "PROVENANCE_UNCERTAIN") \
			and bool(discovery.get("ok", false)) and discovery.get("code", "") == "DISCOVERED" \
			and bool(duplicate.get("ok", false)) and duplicate.get("code", "") == "ALREADY_DISCOVERED" \
			and artifact.get("knownClues", []).count("PROVENANCE") == 1 \
			and reason_has(listing_after, "PROVENANCE_STRONG") and reason_has(auction_after, "PROVENANCE_STRONG") \
			and public_private_fields_hidden(public_before) and public_private_fields_hidden(public_after)
		provenance_ok = provenance_ok and case_ok
		provenance_rows[case_id] = {"taggedCount": tagged.size(), "evidenceId": evidence_id, "expectedId": expected_id, "sourceKind": tagged_row.get("source", {}).get("kind", ""), "reliability": tagged_row.get("reliability", ""), "discovery": discovery, "duplicate": duplicate, "knownClueCount": artifact.get("knownClues", []).count("PROVENANCE") if not artifact.is_empty() else -1, "before": {"listing": listing_before, "auction": auction_before}, "after": {"listing": listing_after, "auction": auction_after}, "publicPrivacy": public_private_fields_hidden(public_before) and public_private_fields_hidden(public_after), "ok": case_ok}
	record(
		"S4-AUTHORED-PROVENANCE-06",
		"Each new case has exactly one strong-document PROVENANCE source whose discovery bridges public listing and auction reasons exactly once",
		provenance_ok,
		provenance_rows
	)

	var outcomes_ok := true
	var outcome_rows: Dictionary = {}
	for case_id: String in NEW_CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var fixture := begin_stage_four_case(gs, case_id)
		var discovered := discover_all(gs, case_id)
		var canonical := String(definition.get("canonical_hypothesis_id", ""))
		var wrong := wrong_hypothesis_with_two_refutations(definition)
		var correct_citations := citation_rows_for_relation(definition, canonical, "SUPPORT", 4)
		var wrong_citations := citation_rows_for_relation(definition, wrong, "REFUTE", 2)
		var before := authority_signature(gs)
		var empty: Dictionary = gs.evaluate_case_submission(case_id, canonical, [])
		var correct_one: Dictionary = gs.evaluate_case_submission(case_id, canonical, correct_citations.slice(0, 1))
		var correct_three: Dictionary = gs.evaluate_case_submission(case_id, canonical, correct_citations.slice(0, 3))
		var correct_four: Dictionary = gs.evaluate_case_submission(case_id, canonical, correct_citations)
		var wrong_one: Dictionary = gs.evaluate_case_submission(case_id, wrong, wrong_citations.slice(0, 1))
		var wrong_two: Dictionary = gs.evaluate_case_submission(case_id, wrong, wrong_citations)
		var after := authority_signature(gs)
		var case_ok: bool = not fixture.get("artifact", {}).is_empty() \
			and discovered.size() == definition.get("evidence", []).size() \
			and rule_ladder_exact(definition) and correct_citations.size() == 4 and wrong_citations.size() == 2 \
			and not bool(empty.get("ok", true)) and empty.get("code", "") == "CITATION_REQUIRED" \
			and bool(correct_one.get("ok", false)) and correct_one.get("outcome", "") == "reviewed_with_mentor" \
			and correct_one.get("substantiation", "") == "INCONCLUSIVE" \
			and bool(correct_three.get("ok", false)) and correct_three.get("outcome", "") == "credible" \
			and int(correct_three.get("independentSourceCount", -1)) == 3 \
			and bool(correct_four.get("ok", false)) and correct_four.get("outcome", "") == "masterful" \
			and int(correct_four.get("independentSourceCount", -1)) == 4 and bool(correct_four.get("substantiated", false)) \
			and bool(wrong_one.get("ok", false)) and wrong_one.get("outcome", "") == "reviewed_with_mentor" \
			and bool(wrong_two.get("ok", false)) and wrong_two.get("outcome", "") == "mistaken" \
			and int(wrong_two.get("netScore", 0)) < 0 and not bool(wrong_two.get("conclusionAccurate", true)) \
			and before == after
		outcomes_ok = outcomes_ok and case_ok
		outcome_rows[case_id] = {"rulesExact": rule_ladder_exact(definition), "discovered": discovered.size(), "evidence": definition.get("evidence", []).size(), "canonical": canonical, "wrong": wrong, "correctCitations": correct_citations, "wrongCitations": wrong_citations, "empty": empty, "correct1": correct_one, "correct3": correct_three, "correct4": correct_four, "wrong1": wrong_one, "wrong2": wrong_two, "evaluationMutation0": before == after, "ok": case_ok}
	record(
		"S4-AUTHORED-OUTCOMES-07",
		"Both new cases execute ordered 4/4 masterful, 3/3 credible, wrong+1 mentor, wrong+2 mistaken, and fail-closed fallback rules without one-source credible",
		outcomes_ok,
		outcome_rows
	)

	finish(gs)
