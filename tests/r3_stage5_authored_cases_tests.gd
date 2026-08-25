extends SceneTree

## Stage 5 authored-v2 integration, protected Shadow Camera, and legacy-save
## compatibility contract. The suite uses only generic public runtime paths and
## writes only isolated QA/save evidence.

const CASE_IDS := ["collector_promise", "three_cameras", "shadow_camera"]
const NEW_CASE_IDS := ["collector_promise", "three_cameras"]
const EXPECTED_TEST_COUNT := 11
const REPORT_PATH := "res://qa/R3_STAGE5_AUTHORED_CASES_TESTS.json"
const MIGRATION_FIXTURE_PATH := "user://r3_stage5_authored_migration_fixture.json"
const STAGE_MULTIPLIER := 1.31079601
const SHADOW_PATH := "res://data/cases/authored_v2/shadow_camera.json"
const SHADOW_SHA256 := "09fd2bc681ae4897b1d2cac324996bda80f4f21d07f0d5d0823a1cb07acf0664"

const ONE_PHYSICAL_CAMERA_EN := "Only one disputed third camera was physically received; the two comparison cameras exist only in records and photographs."
const ONE_PHYSICAL_CAMERA_KO := "실물로 인수된 것은 분쟁 중인 세 번째 카메라 한 대뿐이며, 비교 대상 두 카메라는 기록과 사진으로만 존재한다."

const EXPECTED_IDENTITIES := {
	"collector_promise": {
		"spec": "artifact_021",
		"story": "story_artifact_13",
		"canonical": "hyp.collector_promise.genuine_barometer_modern_capsule_repair",
		"provenance": "src.collector_promise.document.transfer_repair_receipt"
	},
	"three_cameras": {
		"spec": "artifact_033",
		"story": "story_artifact_14",
		"canonical": "hyp.three_cameras.modern_reproduction_copied_from_reference_pair",
		"provenance": "src.three_cameras.document.reference_pair_photo_ledger"
	},
	"shadow_camera": {
		"spec": "artifact_048",
		"story": "story_artifact_15",
		"canonical": "hyp.late_composite",
		"provenance": ""
	}
}

const EXPECTED_SOURCES := {
	"collector_promise": [
		"src.collector_promise.artifact.period_body_identity",
		"src.collector_promise.artifact.modern_capsule_repair",
		"src.collector_promise.document.transfer_repair_receipt",
		"src.collector_promise.npc.victor_promise_context",
		"src.collector_promise.reference.aurelian_model120_history"
	],
	"three_cameras": [
		"src.three_cameras.artifact.received_camera_body",
		"src.three_cameras.artifact.copied_repair_surface",
		"src.three_cameras.document.reference_pair_photo_ledger",
		"src.three_cameras.npc.victor_single_lot_account",
		"src.three_cameras.reference.marrow_model132_history"
	],
	"shadow_camera": [
		"src.shadow_camera.artifact.mount_wear",
		"src.shadow_camera.artifact.uv_shadow_mark",
		"src.shadow_camera.artifact.internal_spacer",
		"src.shadow_camera.document.repair_leaf",
		"src.shadow_camera.npc.lena_invoice_account",
		"src.shadow_camera.reference.model147_material_note"
	]
}

const EXPECTED_RISKS := {
	"collector_promise": {"NONE": 4, "LOW": 1, "HIGH": 0},
	"three_cameras": {"NONE": 4, "LOW": 1, "HIGH": 0},
	"shadow_camera": {"NONE": 0, "LOW": 5, "HIGH": 1}
}

const EXPECTED_RISK_ROWS := {
	"collector_promise": {
		"src.collector_promise.artifact.modern_capsule_repair": {"level": "LOW", "tools": ["precision_screwdriver"]}
	},
	"three_cameras": {
		"src.three_cameras.artifact.copied_repair_surface": {"level": "LOW", "tools": ["material_scanner"]}
	},
	"shadow_camera": {
		"src.shadow_camera.artifact.mount_wear": {"level": "LOW", "tools": []},
		"src.shadow_camera.artifact.uv_shadow_mark": {"level": "HIGH", "tools": ["uv_lamp"]},
		"src.shadow_camera.artifact.internal_spacer": {"level": "LOW", "tools": ["precision_screwdriver"]},
		"src.shadow_camera.document.repair_leaf": {"level": "LOW", "tools": []},
		"src.shadow_camera.npc.lena_invoice_account": {"level": "LOW", "tools": []},
		"src.shadow_camera.reference.model147_material_note": {"level": "LOW", "tools": ["reference_database"]}
	}
}

const EXPECTED_OUTCOME_THRESHOLDS := {
	"collector_promise": {"masterful": [4, 4, 4], "masterfulRequiresAll": false, "credible": [3, 3, 3], "mistakenCitations": 2},
	"three_cameras": {"masterful": [4, 4, 4], "masterfulRequiresAll": false, "credible": [3, 3, 3], "mistakenCitations": 2},
	"shadow_camera": {"masterful": [4, 4, 4], "masterfulRequiresAll": true, "credible": [2, 2, 1], "mistakenCitations": 2}
}

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(test_id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": test_id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func cleanup_save(gs: Node, path: String) -> void:
	for candidate: String in [path, path + gs.SAVE_TEMP_SUFFIX, path + gs.SAVE_BACKUP_SUFFIX]:
		gs.remove_save_file(candidate)


func finish(gs: Node) -> void:
	cleanup_save(gs, MIGRATION_FIXTURE_PATH)
	gs.persistence_enabled = false
	var passed: int = results.filter(func(row: Dictionary): return bool(row.get("passed", false))).size()
	var report := {
		"suite": "R3 Stage 5 Authored Cases",
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
	quit(0 if passed == EXPECTED_TEST_COUNT and results.size() == EXPECTED_TEST_COUNT else 1)


func blocked_remaining(code: String) -> void:
	var rows := [
		["S5-AUTHORED-GENERIC-02", "Stage 5 definitions stay on generic mutation-zero paths"],
		["S5-AUTHORED-IDENTITY-03", "Stage 5 fresh artifact identities are exact"],
		["S5-AUTHORED-SOURCES-04", "Stage 5 source graphs and outcome ladders are exact"],
		["S5-AUTHORED-ONE-PHYSICAL-05", "Three Cameras public copy establishes one physical disputed camera"],
		["S5-AUTHORED-RISK-06", "Stage 5 risk gates and pressure are exact"],
		["S5-AUTHORED-PROVENANCE-07", "Stage 5 provenance and known-clue bridges are exact"],
		["S5-AUTHORED-OUTCOMES-08", "Stage 5 outcome rules execute through the public evaluator"],
		["S5-AUTHORED-MIGRATION-09", "Unresolved colon-ID authored state canonicalizes safely"],
		["S5-AUTHORED-MIGRATION-SCOPE-10", "Stage 5 migration has zero collateral authority mutation"],
		["S5-AUTHORED-RESOLVED-HISTORY-11", "Resolved authored history remains exact"]
	]
	for row: Array in rows:
		record(String(row[0]), String(row[1]), false, {"code": code})


func stage_five_profile(gs: Node) -> Dictionary:
	var profile: Dictionary = gs.default_player_profile()
	profile["highestUnlockedStage"] = 5
	profile["clearedStages"] = [1, 2, 3, 4]
	profile["stageBest"] = {"1": 55.0, "2": 58.0, "3": 61.0, "4": 64.0}
	return profile


func start_stage_five(gs: Node) -> Dictionary:
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	gs.player_profile = stage_five_profile(gs)
	var started: Dictionary = gs.new_game(5)
	gs.campaign_test_mode = true
	gs.persistence_enabled = false
	return started


func prepare_prior_stage_cases(gs: Node, case_id: String) -> bool:
	var ready := true
	for ordered_case_id: String in CASE_IDS:
		if ordered_case_id == case_id:
			break
		ready = bool(gs.prepare_case_for_test(ordered_case_id)) and ready
	return ready


func begin_stage_five_case(gs: Node, case_id: String) -> Dictionary:
	var started := start_stage_five(gs)
	var prior_cases_ready := bool(started.get("ok", false)) and prepare_prior_stage_cases(gs, case_id)
	var artifact: Dictionary = gs.begin_case(case_id) if prior_cases_ready else {}
	return {"start": started, "priorCasesReady": prior_cases_ready, "artifact": artifact}


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


func evidence_ids(definition: Dictionary) -> Array:
	var output: Array = []
	for evidence_value: Variant in definition.get("evidence", []):
		if evidence_value is Dictionary:
			output.append(String(evidence_value.get("id", "")))
	return output


func unique_strings(values: Array) -> Array:
	var output: Array = []
	for value: Variant in values:
		var rendered := String(value)
		if not output.has(rendered):
			output.append(rendered)
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


func outcome_ladder_exact(case_id: String, definition: Dictionary) -> bool:
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
	var expected: Dictionary = EXPECTED_OUTCOME_THRESHOLDS[case_id]
	var masterful: Array = expected.masterful
	var credible: Array = expected.credible
	return rules.map(func(rule: Dictionary): return String(rule.get("outcome_id", ""))) \
		== ["masterful", "credible", "mistaken", "reviewed_with_mentor"] \
		and rules[0].get("correctness", "") == "CORRECT" \
		and bool(rules[0].get("requires_all_required_sources", false)) == bool(expected.masterfulRequiresAll) \
		and [int(rules[0].get("minimum_independent_groups", -1)), int(rules[0].get("minimum_citations", -1)), int(rules[0].get("minimum_net_support", -1))] == masterful \
		and rules[1].get("correctness", "") == "CORRECT" \
		and not bool(rules[1].get("requires_all_required_sources", true)) \
		and [int(rules[1].get("minimum_independent_groups", -1)), int(rules[1].get("minimum_citations", -1)), int(rules[1].get("minimum_net_support", -1))] == credible \
		and rules[2].get("correctness", "") == "INCORRECT" \
		and int(rules[2].get("minimum_citations", -1)) == int(expected.mistakenCitations) \
		and rules[3].get("correctness", "") == "ANY" and bool(rules[3].get("fallback", false))


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


func json_semantically_equal(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func add_migration_artifact(gs: Node, case_id: String, spec_id: String, story_id: String, seed_value: int) -> Dictionary:
	var artifact: Dictionary = gs.new_artifact(spec_id, seed_value, "case_%s" % case_id)
	artifact["caseId"] = case_id
	artifact["storyArtifactId"] = story_id
	artifact["authenticityTruth"] = "GENUINE_WITH_PERIOD_REPAIR"
	artifact["knownClues"] = ["PROVENANCE", "MATERIAL", "%s:legacy_visible" % case_id]
	artifact["evidence"] = [{"clueType": "%s:legacy" % case_id, "observation": "preserve", "supports": [], "contradicts": [], "confidenceWeight": 0.37}]
	artifact["playerHypothesis"] = "GENUINE_WITH_PERIOD_REPAIR"
	artifact["confidence"] = 0.73
	artifact["historicalIntegrity"] = 62.25 + float(seed_value % 5)
	artifact["restorationCost"] = 48.5 + float(seed_value % 7)
	artifact["restorationQuality"] = 27.0
	artifact["listing"] = {"starting": 181, "reserve": 249, "confidence": 0.71, "disclosure": "LIKELY"}
	gs.inventory.append(artifact)
	gs.campaign_state.caseArtifactLedger[case_id] = {
		"issued": true,
		"artifactUid": artifact.uniqueId,
		"disposition": "INVENTORY",
		"saleTransactionId": "",
		"publicConditionSnapshot": {"historicalIntegrity": artifact.historicalIntegrity},
		"publicAppraisalSnapshot": artifact.baseValue,
		"migrationSentinel": "ledger:%s" % case_id
	}
	return artifact


func stale_case_state(case_id: String, definition: Dictionary) -> Dictionary:
	var ids := evidence_ids(definition)
	return {
		"state": {
			"discoveredEvidenceIds": ["%s:material" % case_id, ids[1], ids[0], ids[1], 1978, "%s:repair_trace" % case_id],
			"selectedHypothesisId": "GENUINE_WITH_PERIOD_REPAIR",
			"citedEvidenceIds": ["%s:material" % case_id, ids[0], ids[2], ids[1], ids[0]],
			"resolved": false,
			"resolutionResult": {"outcome": "stale_fallback_result", "marker": case_id},
			"migrationSentinel": {"marker": case_id, "keep": [3, 1, 4]}
		},
		"expectedDiscovered": [ids[1], ids[0]],
		"expectedCited": [ids[0], ids[1]]
	}


func protected_migration_snapshot(gs: Node) -> Dictionary:
	var campaign_without_states: Dictionary = gs.campaign_state.duplicate(true)
	campaign_without_states.erase("caseStates")
	return {
		"inventory": gs.inventory.duplicate(true),
		"ledger": gs.campaign_state.get("caseArtifactLedger", {}).duplicate(true),
		"campaignWithoutCaseStates": campaign_without_states,
		"profile": gs.profile_payload(),
		"economy": {"money": gs.money, "reputation": gs.reputation, "day": gs.day, "ownedUpgrades": gs.owned_upgrades.duplicate()},
		"rng": int(gs.rng.state),
		"knownClues": gs.inventory.map(func(artifact: Dictionary): return artifact.get("knownClues", []).duplicate()),
		"repair": gs.inventory.map(func(artifact: Dictionary): return {"integrity": artifact.get("historicalIntegrity", 0.0), "cost": artifact.get("restorationCost", 0.0), "quality": artifact.get("restorationQuality", 0.0)}),
		"auction": {"pending": gs.pending_auction.duplicate(true), "listings": gs.inventory.map(func(artifact: Dictionary): return artifact.get("listing", {}).duplicate(true))},
		"tutorial": gs.stage_run_state.get("tutorialCompletedSteps", []).duplicate(),
		"telemetry": gs.stage_run_state.get("telemetry", {}).duplicate(true)
	}


func run() -> void:
	var registry: Node = get_root().get_node("RuntimeRegistry")
	var gs: Node = get_root().get_node("GameState")
	gs.persistence_enabled = false

	var definitions: Dictionary = {}
	var missing_methods: Array = []
	for method_name: String in [
		"new_game", "begin_case", "case_definition", "discover_case_evidence",
		"get_case_public_state", "evaluate_case_submission", "listing_public_status_tags",
		"auction_public_reason_tags", "save_game", "load_game"
	]:
		if not gs.has_method(method_name):
			missing_methods.append(method_name)
	var fallback_count := 0
	for case_id: String in CASE_IDS:
		var definition: Dictionary = registry.get_case_v2(case_id)
		definitions[case_id] = definition
		if definition.is_empty() or int(gs.case_definition(case_id).get("schema_version", 0)) != 2:
			fallback_count += 1
	var stage_definition: Dictionary = registry.get_stage_definition(5)
	var shadow_hash := FileAccess.get_sha256(SHADOW_PATH)
	var data_ready: bool = missing_methods.is_empty() and fallback_count == 0
	var data_ok: bool = data_ready and registry.authored_case_errors.is_empty() \
		and stage_definition.get("case_ids", []) == CASE_IDS \
		and is_equal_approx(float(registry.stage_difficulty_multiplier(5)), STAGE_MULTIPLIER) \
		and CASE_IDS.all(func(case_id: String): return registry.authored_cases_v2.has(case_id)) \
		and shadow_hash == SHADOW_SHA256
	record(
		"S5-AUTHORED-DATA-01",
		"Stage 5 resolves Collector Promise, Three Cameras, then protected Shadow Camera with the exact multiplier and zero fallback",
		data_ok,
		{"missingMethods": missing_methods, "registryErrors": registry.authored_case_errors, "authoredCount": registry.authored_cases_v2.size(), "caseOrder": stage_definition.get("case_ids", []), "fallbackCount": fallback_count, "difficultyMultiplier": registry.stage_difficulty_multiplier(5), "shadowSha256": shadow_hash}
	)
	if not data_ready:
		blocked_remaining("STAGE5_AUTHORED_DATA_NOT_READY")
		finish(gs)
		return

	start_stage_five(gs)
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
	var generic_ok: bool = runtime_exact and before_authority == authority_signature(gs) \
		and before_campaign == JSON.stringify(registry.campaign) and before_stage == JSON.stringify(registry.stage_definitions)
	for hits_value: Variant in source_hits.values():
		for hit_value: Variant in (hits_value as Dictionary).values():
			generic_ok = generic_ok and not bool(hit_value)
	record(
		"S5-AUTHORED-GENERIC-02",
		"Both new cases use generic registry/public paths without save, economy, auction, RNG, campaign, or stage mutation",
		generic_ok,
		{"runtimeExact": runtime_exact, "caseIdHits": source_hits, "authorityMutation0": before_authority == authority_signature(gs), "campaignMutation0": before_campaign == JSON.stringify(registry.campaign), "stageMutation0": before_stage == JSON.stringify(registry.stage_definitions)}
	)

	var identity_ok := true
	var identity_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var expected: Dictionary = EXPECTED_IDENTITIES[case_id]
		var campaign_case: Dictionary = registry.get_case(case_id)
		var story: Dictionary = registry.story_artifacts.get(String(campaign_case.get("storyArtifactId", "")), {})
		var started := start_stage_five(gs)
		var prior_cases_ready := bool(started.get("ok", false)) and prepare_prior_stage_cases(gs, case_id)
		var pressure_before := runtime_pressure_signature(gs)
		var artifact: Dictionary = gs.begin_case(case_id) if prior_cases_ready else {}
		var pressure_after := runtime_pressure_signature(gs)
		var case_ok: bool = bool(started.get("ok", false)) and prior_cases_ready and not artifact.is_empty() \
			and String(definitions[case_id].get("artifact_spec_id", "")) == String(expected.spec) \
			and String(definitions[case_id].get("canonical_hypothesis_id", "")) == String(expected.canonical) \
			and String(campaign_case.get("rewardSpecId", "")) == String(expected.spec) \
			and String(campaign_case.get("storyArtifactId", "")) == String(expected.story) \
			and String(story.get("baseSpecId", "")) == String(expected.spec) \
			and String(artifact.get("artifactSpecId", "")) == String(expected.spec) \
			and String(artifact.get("storyArtifactId", "")) == String(expected.story) \
			and String(artifact.get("uniqueId", "")) == "case_%s" % case_id \
			and pressure_before == pressure_after and registry.get_stage_definition(5).get("case_ids", []) == CASE_IDS
		identity_ok = identity_ok and case_ok
		identity_rows[case_id] = {"authoredSpec": definitions[case_id].get("artifact_spec_id", ""), "campaignSpec": campaign_case.get("rewardSpecId", ""), "story": campaign_case.get("storyArtifactId", ""), "storySpec": story.get("baseSpecId", ""), "runtimeSpec": artifact.get("artifactSpecId", ""), "uid": artifact.get("uniqueId", ""), "canonical": definitions[case_id].get("canonical_hypothesis_id", ""), "priorCasesReady": prior_cases_ready, "pressureMutation0": pressure_before == pressure_after, "ok": case_ok}
	record(
		"S5-AUTHORED-IDENTITY-03",
		"All Stage 5 definitions, campaign records, story artifacts, and fresh runtime artifacts preserve exact identities",
		identity_ok,
		identity_rows
	)

	var sources_ok := true
	var source_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var relations := relation_summary(definition)
		var all_linked := not relations.is_empty()
		var all_stances: Array = []
		for stances_value: Variant in relations.values():
			var stances: Array = stances_value
			all_linked = all_linked and not stances.is_empty()
			for stance_value: Variant in stances:
				if not all_stances.has(String(stance_value)):
					all_stances.append(String(stance_value))
		var expected_count := (EXPECTED_SOURCES[case_id] as Array).size()
		var expected_artifact_count := 3 if case_id == "shadow_camera" else 2
		var kinds: Array = definition.get("evidence", []).map(func(row: Dictionary): return String(row.get("source", {}).get("kind", "")))
		var case_ok: bool = evidence_ids(definition) == EXPECTED_SOURCES[case_id] \
			and independence_groups(definition).size() == expected_count \
			and kinds.count("ARTIFACT") == expected_artifact_count and kinds.count("DOCUMENT") == 1 \
			and kinds.count("NPC") == 1 and kinds.count("REFERENCE") == 1 \
			and source_kinds(definition) == ["ARTIFACT", "DOCUMENT", "NPC", "REFERENCE"] \
			and all_linked and all_stances.has("SUPPORT") and all_stances.has("REFUTE") \
			and outcome_ladder_exact(case_id, definition)
		sources_ok = sources_ok and case_ok
		source_rows[case_id] = {"sources": evidence_ids(definition), "groups": independence_groups(definition), "kinds": kinds, "relations": relations, "outcomeRules": definition.get("resolution", {}).get("outcome_rules", []), "ok": case_ok}
	record(
		"S5-AUTHORED-SOURCES-04",
		"Stage 5 source IDs, independent groups, source kinds, contested relations, and case-specific outcome thresholds are exact",
		sources_ok,
		source_rows
	)

	var camera_fixture := begin_stage_five_case(gs, "three_cameras")
	var camera_public: Dictionary = gs.get_case_public_state("three_cameras")
	var public_copy := JSON.stringify(camera_public)
	var one_physical_ok: bool = not camera_fixture.get("artifact", {}).is_empty() \
		and public_copy.contains(ONE_PHYSICAL_CAMERA_EN) and public_copy.contains(ONE_PHYSICAL_CAMERA_KO) \
		and String(camera_fixture.get("artifact", {}).get("artifactSpecId", "")) == "artifact_033" \
		and String(camera_fixture.get("artifact", {}).get("uniqueId", "")) == "case_three_cameras" \
		and public_private_fields_hidden(camera_public)
	record(
		"S5-AUTHORED-ONE-PHYSICAL-05",
		"Three Cameras bilingual public copy states that only the disputed third camera is physical and the comparison pair is documentary",
		one_physical_ok,
		{"enPresent": public_copy.contains(ONE_PHYSICAL_CAMERA_EN), "koPresent": public_copy.contains(ONE_PHYSICAL_CAMERA_KO), "runtimeArtifactSpec": camera_fixture.get("artifact", {}).get("artifactSpecId", ""), "runtimeUid": camera_fixture.get("artifact", {}).get("uniqueId", ""), "publicPrivacy": public_private_fields_hidden(camera_public)}
	)

	var risk_ok := true
	var risk_rows: Dictionary = {}
	var aggregate_counts := {"NONE": 0, "LOW": 0, "HIGH": 0}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var counts := {"NONE": 0, "LOW": 0, "HIGH": 0}
		var actual_risk_rows: Dictionary = {}
		var runtime_rows: Array = []
		for evidence_value: Variant in definition.get("evidence", []):
			if not evidence_value is Dictionary:
				continue
			var evidence: Dictionary = evidence_value
			var level := String(evidence.get("risk", {}).get("level", "NONE"))
			counts[level] = int(counts.get(level, 0)) + 1
			aggregate_counts[level] = int(aggregate_counts.get(level, 0)) + 1
			if level == "NONE":
				continue
			var evidence_id := String(evidence.get("id", ""))
			var tools: Array = evidence.get("unlock", {}).get("requires_tools", [])
			actual_risk_rows[evidence_id] = {"level": level, "tools": tools}
			var fixture := begin_stage_five_case(gs, case_id)
			var artifact: Dictionary = fixture.get("artifact", {})
			var prerequisites_ok := not artifact.is_empty() and satisfy_requirements(gs, case_id, definition, evidence_id)
			var wrong_result: Dictionary = {"code": "NOT_APPLICABLE"}
			var wrong_mutation_zero := true
			if not tools.is_empty():
				var wrong_tool := "soft_brush" if not tools.has("soft_brush") else "uv_lamp"
				gs.select_tool(wrong_tool)
				var wrong_before := authority_signature(gs)
				wrong_result = gs.discover_case_evidence(case_id, evidence_id)
				wrong_mutation_zero = authority_signature(gs) == wrong_before
				gs.select_tool(String(tools[0]))
			var integrity_before := float(artifact.get("historicalIntegrity", 0.0))
			var discovery: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
			var expected_penalty := (1.0 if level == "LOW" else 3.0) * STAGE_MULTIPLIER
			var integrity_after := float(artifact.get("historicalIntegrity", 0.0))
			var tool_gate_ok := tools.is_empty() or (not bool(wrong_result.get("ok", true)) and String(wrong_result.get("code", "")) == "TOOL_REQUIRED" and wrong_mutation_zero)
			var row_ok: bool = prerequisites_ok and tool_gate_ok \
				and bool(discovery.get("ok", false)) and String(discovery.get("code", "")) == "DISCOVERED" \
				and is_equal_approx(float(discovery.get("appliedRiskPenalty", -1.0)), expected_penalty) \
				and is_equal_approx(integrity_before - integrity_after, expected_penalty)
			runtime_rows.append({"id": evidence_id, "level": level, "tools": tools, "wrongResult": wrong_result, "wrongMutation0": wrong_mutation_zero, "expectedPenalty": expected_penalty, "actualPenalty": discovery.get("appliedRiskPenalty", -1), "integrity": [integrity_before, integrity_after], "ok": row_ok})
		var case_ok: bool = counts == EXPECTED_RISKS[case_id] and actual_risk_rows == EXPECTED_RISK_ROWS[case_id] \
			and runtime_rows.all(func(row: Dictionary): return bool(row.get("ok", false)))
		risk_ok = risk_ok and case_ok
		risk_rows[case_id] = {"counts": counts, "expectedCounts": EXPECTED_RISKS[case_id], "riskRows": actual_risk_rows, "expectedRiskRows": EXPECTED_RISK_ROWS[case_id], "runtime": runtime_rows, "ok": case_ok}
	var weighted_total := (float(aggregate_counts.LOW) + 3.0 * float(aggregate_counts.HIGH)) * STAGE_MULTIPLIER
	var weighted_per_action := weighted_total / 16.0
	risk_ok = risk_ok and aggregate_counts == {"NONE": 8, "LOW": 7, "HIGH": 1} \
		and is_equal_approx(weighted_total, 13.1079601) and is_equal_approx(weighted_per_action, 0.81924750625)
	record(
		"S5-AUTHORED-RISK-06",
		"Stage 5 preserves 16 evidence actions, exact sparse case risks, protected Shadow pressure, and 1.31079601-scaled tool-gated penalties",
		risk_ok,
		{"multiplier": registry.stage_difficulty_multiplier(5), "aggregateCounts": aggregate_counts, "weightedTotal": weighted_total, "weightedPerAction": weighted_per_action, "cases": risk_rows}
	)

	var provenance_ok := true
	var provenance_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var tagged: Array = definition.get("evidence", []).filter(func(row: Dictionary): return String(row.get("public_clue_id", "")) == "PROVENANCE")
		var fixture := begin_stage_five_case(gs, case_id)
		var artifact: Dictionary = fixture.get("artifact", {})
		var public_before: Dictionary = gs.get_case_public_state(case_id)
		var listing_before: Array = gs.listing_public_status_tags(artifact, "UNCERTAIN") if not artifact.is_empty() else []
		var auction_before: Array = gs.auction_public_reason_tags(artifact, {}, "NO_SALE", {"reserve": 100, "hammer": 0, "reserve_met": false}) if not artifact.is_empty() else []
		var expected_id := String(EXPECTED_IDENTITIES[case_id].provenance)
		var discovery: Dictionary = {"code": "NOT_APPLICABLE"}
		var duplicate: Dictionary = {"code": "NOT_APPLICABLE"}
		if not expected_id.is_empty() and tagged.size() == 1 and not artifact.is_empty():
			var tagged_row: Dictionary = tagged[0]
			if satisfy_requirements(gs, case_id, definition, expected_id):
				var tools: Array = tagged_row.get("unlock", {}).get("requires_tools", [])
				if not tools.is_empty():
					gs.select_tool(String(tools[0]))
				discovery = gs.discover_case_evidence(case_id, expected_id)
				duplicate = gs.discover_case_evidence(case_id, expected_id)
		elif expected_id.is_empty() and not artifact.is_empty():
			discover_all(gs, case_id)
		var public_after: Dictionary = gs.get_case_public_state(case_id)
		var listing_after: Array = gs.listing_public_status_tags(artifact, "UNCERTAIN") if not artifact.is_empty() else []
		var auction_after: Array = gs.auction_public_reason_tags(artifact, {}, "BID", {}) if not artifact.is_empty() else []
		var case_ok := false
		if expected_id.is_empty():
			case_ok = tagged.is_empty() and artifact.get("knownClues", []).count("PROVENANCE") == 0 \
				and reason_has(listing_before, "PROVENANCE_UNCERTAIN") and reason_has(auction_before, "PROVENANCE_UNCERTAIN") \
				and reason_has(listing_after, "PROVENANCE_UNCERTAIN") and auction_after.is_empty() \
				and not reason_has(listing_after, "PROVENANCE_STRONG") and not reason_has(auction_after, "PROVENANCE_STRONG")
		else:
			var tagged_row: Dictionary = tagged[0] if tagged.size() == 1 else {}
			case_ok = tagged.size() == 1 and String(tagged_row.get("id", "")) == expected_id \
				and tagged_row.get("source", {}).get("kind", "") == "DOCUMENT" and tagged_row.get("reliability", "") == "HIGH" \
				and reason_has(listing_before, "PROVENANCE_UNCERTAIN") and reason_has(auction_before, "PROVENANCE_UNCERTAIN") \
				and bool(discovery.get("ok", false)) and discovery.get("code", "") == "DISCOVERED" \
				and bool(duplicate.get("ok", false)) and duplicate.get("code", "") == "ALREADY_DISCOVERED" \
				and artifact.get("knownClues", []).count("PROVENANCE") == 1 \
				and reason_has(listing_after, "PROVENANCE_STRONG") and reason_has(auction_after, "PROVENANCE_STRONG")
		case_ok = case_ok and public_private_fields_hidden(public_before) and public_private_fields_hidden(public_after)
		provenance_ok = provenance_ok and case_ok
		provenance_rows[case_id] = {"taggedCount": tagged.size(), "expectedId": expected_id, "discovery": discovery, "duplicate": duplicate, "knownClueCount": artifact.get("knownClues", []).count("PROVENANCE") if not artifact.is_empty() else -1, "before": {"listing": listing_before, "auction": auction_before}, "after": {"listing": listing_after, "auction": auction_after}, "publicPrivacy": public_private_fields_hidden(public_before) and public_private_fields_hidden(public_after), "ok": case_ok}
	record(
		"S5-AUTHORED-PROVENANCE-07",
		"The two new strong-document provenance sources bridge exactly once while protected Shadow Camera remains explicitly unbridged",
		provenance_ok,
		provenance_rows
	)

	var outcomes_ok := true
	var outcome_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var fixture := begin_stage_five_case(gs, case_id)
		var discovered := discover_all(gs, case_id)
		var canonical := String(definition.get("canonical_hypothesis_id", ""))
		var wrong := wrong_hypothesis_with_two_refutations(definition)
		var expected: Dictionary = EXPECTED_OUTCOME_THRESHOLDS[case_id]
		var masterful_count := int((expected.masterful as Array)[1])
		var credible_count := int((expected.credible as Array)[1])
		var correct_citations: Array = definition.get("resolution", {}).get("required_source_refs", []).duplicate() \
			if bool(expected.masterfulRequiresAll) \
			else citation_rows_for_relation(definition, canonical, "SUPPORT", masterful_count)
		var credible_citations := correct_citations.slice(0, credible_count)
		var wrong_citations := citation_rows_for_relation(definition, wrong, "REFUTE", int(expected.mistakenCitations))
		var before := authority_signature(gs)
		var empty: Dictionary = gs.evaluate_case_submission(case_id, canonical, [])
		var correct_one: Dictionary = gs.evaluate_case_submission(case_id, canonical, correct_citations.slice(0, 1))
		var credible: Dictionary = gs.evaluate_case_submission(case_id, canonical, credible_citations)
		var masterful: Dictionary = gs.evaluate_case_submission(case_id, canonical, correct_citations)
		var wrong_one: Dictionary = gs.evaluate_case_submission(case_id, wrong, wrong_citations.slice(0, 1))
		var wrong_two: Dictionary = gs.evaluate_case_submission(case_id, wrong, wrong_citations)
		var after := authority_signature(gs)
		var case_ok: bool = not fixture.get("artifact", {}).is_empty() and discovered.size() == definition.get("evidence", []).size() \
			and outcome_ladder_exact(case_id, definition) and correct_citations.size() == masterful_count \
			and credible_citations.size() == credible_count and wrong_citations.size() == int(expected.mistakenCitations) \
			and not bool(empty.get("ok", true)) and empty.get("code", "") == "CITATION_REQUIRED" \
			and bool(correct_one.get("ok", false)) and correct_one.get("outcome", "") == "reviewed_with_mentor" \
			and bool(credible.get("ok", false)) and credible.get("outcome", "") == "credible" \
			and int(credible.get("independentSourceCount", -1)) == credible_count \
			and bool(masterful.get("ok", false)) and masterful.get("outcome", "") == "masterful" \
			and int(masterful.get("independentSourceCount", -1)) == masterful_count and bool(masterful.get("substantiated", false)) \
			and bool(wrong_one.get("ok", false)) and wrong_one.get("outcome", "") == "reviewed_with_mentor" \
			and bool(wrong_two.get("ok", false)) and wrong_two.get("outcome", "") == "mistaken" \
			and int(wrong_two.get("netScore", 0)) < 0 and not bool(wrong_two.get("conclusionAccurate", true)) and before == after
		outcomes_ok = outcomes_ok and case_ok
		outcome_rows[case_id] = {"rulesExact": outcome_ladder_exact(case_id, definition), "discovered": discovered.size(), "canonical": canonical, "wrong": wrong, "correctCitations": correct_citations, "credibleCitations": credible_citations, "wrongCitations": wrong_citations, "empty": empty, "correct1": correct_one, "credible": credible, "masterful": masterful, "wrong1": wrong_one, "wrong2": wrong_two, "evaluationMutation0": before == after, "ok": case_ok}
	record(
		"S5-AUTHORED-OUTCOMES-08",
		"All Stage 5 cases execute their exact masterful, credible, mistaken, mentor fallback, and empty-report fail-closed contracts",
		outcomes_ok,
		outcome_rows
	)

	gs.persistence_enabled = false
	gs.reset_game()
	gs.campaign_test_mode = true
	gs.money = 3579
	gs.reputation = 41
	gs.day = 7
	gs.selected_tool = "precision_scale"
	gs.owned_upgrades = ["upgrade_01"]
	gs.campaign_state.storyFlags["stage5MigrationSentinel"] = "campaign-preserve"
	gs.stage_run_state.tutorialCompletedSteps = ["INVESTIGATE", "CITE"]
	gs.stage_run_state.telemetry["investigationActions"] = 17
	gs.stage_run_state.telemetry["investigationRiskActions"] = 6
	gs.stage_run_state.telemetry["investigationRiskWeightSum"] = 8.75
	var expected_states: Dictionary = {}
	var target_artifacts: Dictionary = {}
	var seed_value := 950100
	for case_id: String in NEW_CASE_IDS:
		var fixture := stale_case_state(case_id, definitions[case_id])
		expected_states[case_id] = fixture
		gs.campaign_state.caseStates[case_id] = fixture.state.duplicate(true)
		var identity: Dictionary = EXPECTED_IDENTITIES[case_id]
		target_artifacts[case_id] = add_migration_artifact(gs, case_id, String(identity.spec), String(identity.story), seed_value)
		seed_value += 1
	var resolved_historical_state := {
		"discoveredEvidenceIds": ["shadow_camera:material", "shadow_camera:provenance"],
		"selectedHypothesisId": "FORGERY",
		"citedEvidenceIds": ["shadow_camera:material"],
		"resolved": true,
		"resolutionResult": {"outcome": "masterful", "historicalReceipt": "keep-exact"},
		"migrationSentinel": {"resolved": true, "keep": [9, 2, 6]}
	}
	gs.campaign_state.caseStates["shadow_camera"] = resolved_historical_state.duplicate(true)
	gs.campaign_state.activeCaseId = "collector_promise"
	var before_protected := protected_migration_snapshot(gs)
	gs.persistence_enabled = true
	var saved := bool(gs.save_game(MIGRATION_FIXTURE_PATH))
	var loaded := saved and bool(gs.load_game(MIGRATION_FIXTURE_PATH))
	gs.persistence_enabled = false
	var membership_ok := loaded
	var membership_rows: Dictionary = {}
	for case_id: String in NEW_CASE_IDS:
		var expected: Dictionary = expected_states[case_id]
		var actual: Dictionary = gs.campaign_state.caseStates.get(case_id, {})
		var definition_ids := evidence_ids(definitions[case_id])
		var discovered_actual: Array = actual.get("discoveredEvidenceIds", [])
		var cited_actual: Array = actual.get("citedEvidenceIds", [])
		var subsets_exact: bool = discovered_actual.all(func(value: Variant): return definition_ids.has(String(value))) \
			and cited_actual.all(func(value: Variant): return discovered_actual.has(String(value)))
		var case_ok: bool = discovered_actual == expected.expectedDiscovered and cited_actual == expected.expectedCited \
			and subsets_exact and String(actual.get("selectedHypothesisId", "invalid")) == "" \
			and actual.get("resolutionResult", {"invalid": true}).is_empty() \
			and json_semantically_equal(actual.get("migrationSentinel", {}), expected.state.migrationSentinel)
		membership_ok = membership_ok and case_ok
		membership_rows[case_id] = {"actual": actual, "definitionIds": definition_ids, "expectedDiscovered": expected.expectedDiscovered, "expectedCited": expected.expectedCited, "citedSubsetDiscoveredSubsetDefinition": subsets_exact, "ok": case_ok}
	record(
		"S5-AUTHORED-MIGRATION-09",
		"Unresolved Stage 5 colon-ID saves retain only ordered current evidence with cited subset discovered subset definition and clear stale conclusions",
		membership_ok,
		{"saved": saved, "loaded": loaded, "cases": membership_rows}
	)

	var after_protected := protected_migration_snapshot(gs)
	var artifact_exact := true
	var artifact_rows: Dictionary = {}
	for case_id: String in NEW_CASE_IDS:
		var before_artifact: Dictionary = target_artifacts[case_id]
		var after_artifact: Dictionary = gs.find_inventory_instance("case_%s" % case_id)
		var case_ok: bool = not after_artifact.is_empty() and json_semantically_equal(after_artifact, before_artifact)
		artifact_exact = artifact_exact and case_ok
		artifact_rows[case_id] = {"before": before_artifact, "after": after_artifact, "ok": case_ok}
	var protected_exact := json_semantically_equal(before_protected, after_protected)
	record(
		"S5-AUTHORED-MIGRATION-SCOPE-10",
		"Canonicalization mutates no artifact, ledger, economy, RNG, known clue, repair, auction, tutorial, telemetry, profile, or campaign state outside caseStates",
		protected_exact and artifact_exact,
		{"protectedExact": protected_exact, "artifacts": artifact_rows, "before": before_protected, "after": after_protected}
	)

	var resolved_after: Dictionary = gs.campaign_state.caseStates.get("shadow_camera", {})
	record(
		"S5-AUTHORED-RESOLVED-HISTORY-11",
		"Resolved Shadow Camera history remains semantically exact even when it contains pre-authored colon identifiers",
		json_semantically_equal(resolved_after, resolved_historical_state),
		{"before": resolved_historical_state, "after": resolved_after}
	)

	finish(gs)
