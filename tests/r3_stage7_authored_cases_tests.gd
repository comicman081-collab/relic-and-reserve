extends SceneTree

## Stage 7A authored-v2, fresh identity, Stage 8 isolation, and legacy-save contract.
## The suite exercises generic public runtime paths and writes one QA report.

const CASE_IDS := ["shadow_optic", "composite_prototype"]
const STAGE8_CASE_IDS := ["master_chronometer", "master_optical"]
const EXPECTED_TEST_COUNT := 12
const REPORT_PATH := "res://qa/R3_STAGE7_AUTHORED_CASES_TESTS.json"
const STAGE_MULTIPLIER := 1.500730351849
const STAGE8_MULTIPLIER := 1.60578147647843

const EXPECTED_CAMPAIGN := {
	"shadow_optic": {
		"act": "ACT_4", "npc": "victor_hale", "documents": ["document_07", "document_08"],
		"spec": "artifact_057", "story": "story_artifact_19",
		"rewards": {"money": 306, "reputation": 2, "mastery": 3, "museumTrust": 1, "historicalIntegrity": 1}
	},
	"composite_prototype": {
		"act": "ACT_4", "npc": "noah_stern", "documents": ["document_09", "document_10"],
		"spec": "artifact_059", "story": "story_artifact_20",
		"rewards": {"money": 318, "reputation": 2, "mastery": 3, "museumTrust": 1, "historicalIntegrity": 1}
	}
}

const EXPECTED_STAGE8_CAMPAIGN := {
	"master_chronometer": {
		"act": "ACT_5", "npc": "mara_venn", "documents": ["document_11", "document_12"],
		"spec": "artifact_061", "story": "story_artifact_21",
		"rewards": {"money": 330, "reputation": 4, "mastery": 7, "museumTrust": 3, "historicalIntegrity": 1}
	},
	"master_optical": {
		"act": "ACT_5", "npc": "victor_hale", "documents": ["document_13", "document_14"],
		"spec": "artifact_075", "story": "story_artifact_22",
		"rewards": {"money": 342, "reputation": 4, "mastery": 7, "museumTrust": 3, "historicalIntegrity": 1}
	}
}

const EXPECTED_CANONICAL := {
	"shadow_optic": "hyp.shadow_optic.later_reproduction_using_period_style",
	"composite_prototype": "hyp.composite_prototype.composite_forgery_from_mixed_parts"
}

const EXPECTED_SOURCES := {
	"shadow_optic": [
		"src.shadow_optic.artifact.period_mismatch_materials",
		"src.shadow_optic.artifact.uv_replica_adhesive",
		"src.shadow_optic.document.archive_custody_record",
		"src.shadow_optic.document.serial_reference_leaf",
		"src.shadow_optic.npc.victor_shadow_mark_context",
		"src.shadow_optic.reference.period_telescope_standard"
	],
	"composite_prototype": [
		"src.composite_prototype.artifact.mixed_period_components",
		"src.composite_prototype.artifact.modern_adapter_construction",
		"src.composite_prototype.document.archive_custody_record",
		"src.composite_prototype.document.reserve_catalog_entry",
		"src.composite_prototype.npc.noah_prototype_context",
		"src.composite_prototype.reference.period_measuring_standard"
	]
}

const EXPECTED_REQUIRED_SOURCES := {
	"shadow_optic": [
		"src.shadow_optic.artifact.period_mismatch_materials",
		"src.shadow_optic.artifact.uv_replica_adhesive",
		"src.shadow_optic.document.archive_custody_record",
		"src.shadow_optic.reference.period_telescope_standard"
	],
	"composite_prototype": [
		"src.composite_prototype.artifact.mixed_period_components",
		"src.composite_prototype.artifact.modern_adapter_construction",
		"src.composite_prototype.document.archive_custody_record",
		"src.composite_prototype.reference.period_measuring_standard"
	]
}

const EXPECTED_PROVENANCE := {
	"shadow_optic": "src.shadow_optic.document.archive_custody_record",
	"composite_prototype": "src.composite_prototype.document.archive_custody_record"
}

const EXPECTED_NPC_EXPRESSION := {
	"shadow_optic": "neutral",
	"composite_prototype": "concerned"
}

const EXPECTED_RISK_TOOLS := {
	"shadow_optic": {
		"src.shadow_optic.artifact.period_mismatch_materials": {"level": "LOW", "tools": ["material_scanner"]},
		"src.shadow_optic.artifact.uv_replica_adhesive": {"level": "HIGH", "tools": ["uv_lamp"]}
	},
	"composite_prototype": {
		"src.composite_prototype.artifact.mixed_period_components": {"level": "LOW", "tools": ["precision_scale"]},
		"src.composite_prototype.artifact.modern_adapter_construction": {"level": "HIGH", "tools": ["repair_toolkit"]}
	}
}

const LEGACY_SPECS := {
	"shadow_optic": "artifact_051",
	"composite_prototype": "artifact_057"
}

const LEGACY_TRUTHS := {
	"shadow_optic": "REPRODUCTION",
	"composite_prototype": "FORGERY"
}

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(test_id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": test_id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func finish(gs: Node) -> void:
	gs.persistence_enabled = false
	var passed: int = results.filter(func(row: Dictionary): return bool(row.get("passed", false))).size()
	var report := {
		"suite": "R3 Stage 7 Authored Cases",
		"executed": results.size(), "passed": passed, "failed": results.size() - passed,
		"skipped": 0, "expectedCount": EXPECTED_TEST_COUNT, "tests": results
	}
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print(JSON.stringify(report))
	quit(0 if passed == EXPECTED_TEST_COUNT and results.size() == EXPECTED_TEST_COUNT else 1)


func blocked_remaining(code: String) -> void:
	var rows := [
		["S7-AUTHORED-GENERIC-02", "Stage 7 definitions stay on generic mutation-zero paths"],
		["S7-AUTHORED-CAMPAIGN-03", "Stage 7 campaign bindings and rewards are exact"],
		["S7-AUTHORED-STAGE8-04", "Stage 8 scope remains exact and unauthored"],
		["S7-AUTHORED-SOURCES-05", "Stage 7 source graphs are exact"],
		["S7-AUTHORED-ISSUANCE-06", "Stage 7 fresh issuance identities are exact"],
		["S7-AUTHORED-RISK-07", "Stage 7 risk and tool routes are exact"],
		["S7-AUTHORED-PROVENANCE-08", "Stage 7 provenance bridges are exact"],
		["S7-AUTHORED-OUTCOMES-09", "Stage 7 ordered outcomes execute exactly"],
		["S7-AUTHORED-LEGACY-10", "Stage 7 legacy ledgers issue no duplicates"],
		["S7-AUTHORED-SCOPE-11", "Stage 7 canonicalization is idempotent and scoped"],
		["S7-AUTHORED-HISTORY-12", "Resolved history and Stage 8 data remain exact"]
	]
	for row: Array in rows:
		record(String(row[0]), String(row[1]), false, {"code": code})


func semantic_equal(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func stage_seven_profile(gs: Node) -> Dictionary:
	var profile: Dictionary = gs.default_player_profile()
	profile["highestUnlockedStage"] = 7
	profile["clearedStages"] = [1, 2, 3, 4, 5, 6]
	profile["stageBest"] = {"1": 55.0, "2": 58.0, "3": 61.0, "4": 64.0, "5": 67.0, "6": 70.0}
	return profile


func start_stage_seven(gs: Node) -> Dictionary:
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	gs.player_profile = stage_seven_profile(gs)
	var started: Dictionary = gs.new_game(7)
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	return started


func prepare_prior_cases(gs: Node, case_id: String) -> bool:
	var ready: bool = true
	for ordered_case_id: String in CASE_IDS:
		if ordered_case_id == case_id:
			break
		ready = bool(gs.prepare_case_for_test(ordered_case_id)) and ready
	return ready


func begin_stage_seven_case(gs: Node, case_id: String) -> Dictionary:
	var started := start_stage_seven(gs)
	var prior_ready: bool = bool(started.get("ok", false)) and prepare_prior_cases(gs, case_id)
	var artifact: Dictionary = gs.begin_case(case_id) if prior_ready else {}
	return {"start": started, "priorReady": prior_ready, "artifact": artifact}


func evidence_ids(definition: Dictionary) -> Array:
	var output: Array = []
	for value: Variant in definition.get("evidence", []):
		if value is Dictionary:
			output.append(String(value.get("id", "")))
	return output


func evidence_by_id(definition: Dictionary, evidence_id: String) -> Dictionary:
	for value: Variant in definition.get("evidence", []):
		if value is Dictionary and String(value.get("id", "")) == evidence_id:
			return value
	return {}


func unique_strings(values: Array) -> Array:
	var output: Array = []
	for value: Variant in values:
		var rendered := String(value)
		if not output.has(rendered):
			output.append(rendered)
	return output


func satisfy_requirements(gs: Node, case_id: String, definition: Dictionary, evidence_id: String, visiting: Dictionary = {}) -> bool:
	if visiting.has(evidence_id):
		return false
	visiting[evidence_id] = true
	var row := evidence_by_id(definition, evidence_id)
	if row.is_empty():
		return false
	for required_value: Variant in row.get("unlock", {}).get("requires_all", []):
		var required_id := String(required_value)
		var discovered: Array = gs.get_case_public_state(case_id).get("discoveredEvidence", []).map(
			func(item: Dictionary): return String(item.get("id", ""))
		)
		if discovered.has(required_id):
			continue
		if not satisfy_requirements(gs, case_id, definition, required_id, visiting):
			return false
		var prerequisite := evidence_by_id(definition, required_id)
		var tools: Array = prerequisite.get("unlock", {}).get("requires_tools", [])
		if not tools.is_empty():
			gs.select_tool(String(tools[0]))
		var result: Dictionary = gs.discover_case_evidence(case_id, required_id)
		if not bool(result.get("ok", false)) or not String(result.get("code", "")) in ["DISCOVERED", "ALREADY_DISCOVERED"]:
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
			var result: Dictionary = gs.discover_case_evidence(case_id, String(row.get("id", "")))
			if bool(result.get("ok", false)) and String(result.get("code", "")) == "DISCOVERED":
				discovered.append(String(row.get("id", "")))
				progressed = true
		if not progressed:
			break
	return discovered


func citation_rows(definition: Dictionary, hypothesis_id: String, stance: String, count: int) -> Array:
	var rows: Array = []
	var groups: Array = []
	for value: Variant in definition.get("evidence", []):
		if not value is Dictionary:
			continue
		var group_id := String(value.get("independence_key", ""))
		if groups.has(group_id):
			continue
		var matches := false
		for relation_value: Variant in value.get("relations", []):
			if relation_value is Dictionary \
					and String(relation_value.get("hypothesis_id", "")) == hypothesis_id \
					and String(relation_value.get("stance", "")) == stance:
				matches = true
				break
		if matches:
			groups.append(group_id)
			rows.append(String(value.get("id", "")))
			if rows.size() == count:
				break
	return rows


func wrong_hypothesis(definition: Dictionary) -> String:
	var canonical := String(definition.get("canonical_hypothesis_id", ""))
	for value: Variant in definition.get("hypotheses", []):
		if value is Dictionary:
			var hypothesis_id := String(value.get("id", ""))
			if hypothesis_id != canonical and citation_rows(definition, hypothesis_id, "REFUTE", 2).size() == 2:
				return hypothesis_id
	return ""


func outcome_rules_exact(definition: Dictionary) -> bool:
	var rules_value: Variant = definition.get("resolution", {}).get("outcome_rules", null)
	if not rules_value is Array or rules_value.size() != 4:
		return false
	var rules: Array = rules_value
	return rules.map(func(row: Dictionary): return String(row.get("outcome_id", ""))) \
		== ["masterful", "credible", "mistaken", "reviewed_with_mentor"] \
		and rules[0].get("correctness", "") == "CORRECT" \
		and not bool(rules[0].get("requires_all_required_sources", true)) \
		and [int(rules[0].get("minimum_independent_groups", -1)), int(rules[0].get("minimum_citations", -1)), int(rules[0].get("minimum_net_support", -1))] == [4, 4, 4] \
		and not bool(rules[0].get("fallback", true)) \
		and rules[1].get("correctness", "") == "CORRECT" \
		and not bool(rules[1].get("requires_all_required_sources", true)) \
		and [int(rules[1].get("minimum_independent_groups", -1)), int(rules[1].get("minimum_citations", -1)), int(rules[1].get("minimum_net_support", -1))] == [3, 3, 3] \
		and not bool(rules[1].get("fallback", true)) \
		and rules[2].get("correctness", "") == "INCORRECT" \
		and not bool(rules[2].get("requires_all_required_sources", true)) \
		and [int(rules[2].get("minimum_independent_groups", -1)), int(rules[2].get("minimum_citations", -1)), int(rules[2].get("minimum_net_support", -1))] == [0, 2, 0] \
		and not bool(rules[2].get("fallback", true)) \
		and rules[3].get("correctness", "") == "ANY" \
		and not bool(rules[3].get("requires_all_required_sources", true)) \
		and [int(rules[3].get("minimum_independent_groups", -1)), int(rules[3].get("minimum_citations", -1)), int(rules[3].get("minimum_net_support", -1))] == [0, 0, 0] \
		and bool(rules[3].get("fallback", false))


func reason_has(tags: Array, code: String) -> bool:
	for value: Variant in tags:
		if value is Dictionary and String(value.get("code", "")) == code:
			return true
	return false


func public_private_fields_hidden(value: Variant) -> bool:
	var payload := JSON.stringify(value)
	for token: String in [
		"canonical_hypothesis_id", "winning_hypothesis_id", "authoring_truth_hypothesis_id",
		"authenticityTruth", "trueMarketBaseline", "trueRarity", "trueHistoricalSignificance",
		"originalParts", "replacementParts", "public_clue_id"
	]:
		if payload.contains(token):
			return false
	return true


func risk_counts(definition: Dictionary) -> Dictionary:
	var counts := {"NONE": 0, "LOW": 0, "HIGH": 0}
	for value: Variant in definition.get("evidence", []):
		if value is Dictionary:
			var level := String(value.get("risk", {}).get("level", "NONE"))
			counts[level] = int(counts.get(level, 0)) + 1
	return counts


func pressure_signature(gs: Node) -> String:
	return JSON.stringify({
		"money": int(gs.money), "reputation": int(gs.reputation), "day": int(gs.day),
		"rng": str(gs.rng.state), "pendingAuction": gs.pending_auction,
		"tutorial": gs.stage_run_state.get("tutorialCompletedSteps", []),
		"telemetry": gs.stage_run_state.get("telemetry", {})
	})


func stale_case_state(case_id: String, definition: Dictionary) -> Dictionary:
	var ids := evidence_ids(definition)
	return {
		"state": {
			"discoveredEvidenceIds": [ids[1], "%s:legacy_material" % case_id, ids[0], ids[1], 707],
			"selectedHypothesisId": "GENUINE_WITH_PERIOD_REPAIR",
			"citedEvidenceIds": [ids[0], "%s:legacy_citation" % case_id, ids[1], ids[0]],
			"resolved": false,
			"resolutionResult": {"outcome": "legacy_pending_result", "case": case_id},
			"migrationSentinel": {"case": case_id, "keep": [7, 0, 7]}
		},
		"expectedDiscovered": [ids[1], ids[0]],
		"expectedCited": [ids[0], ids[1]]
	}


func build_legacy_payload(gs: Node, definitions: Dictionary) -> Dictionary:
	start_stage_seven(gs)
	gs.money = 4707
	gs.reputation = 43
	gs.day = 10
	gs.selected_tool = "precision_scale"
	gs.owned_upgrades = ["upgrade_01"]
	gs.stage_run_state.tutorialCompletedSteps = []
	gs.stage_run_state.telemetry.investigationActions = 29
	gs.stage_run_state.telemetry.investigationRiskActions = 7
	gs.stage_run_state.telemetry.investigationRiskWeightSum = 14.25
	gs.campaign_state.storyFlags["stage7MigrationSentinel"] = "preserve"
	gs.inventory = []
	gs.campaign_state.caseStates = {}
	gs.campaign_state.caseArtifactLedger = {}
	var seed_value := 970700
	for case_id: String in CASE_IDS:
		var expected: Dictionary = EXPECTED_CAMPAIGN[case_id]
		var artifact: Dictionary = gs.new_artifact(String(LEGACY_SPECS[case_id]), seed_value, "case_%s" % case_id)
		seed_value += 1
		artifact["caseId"] = case_id
		artifact["storyArtifactId"] = String(expected.story)
		artifact["authenticityTruth"] = String(LEGACY_TRUTHS[case_id])
		artifact["knownClues"] = ["MATERIAL", "%s:legacy_visible" % case_id]
		artifact["evidence"] = [{"clueType": "%s:legacy" % case_id, "observation": "preserve", "supports": [], "contradicts": [], "confidenceWeight": 0.47}]
		artifact["playerHypothesis"] = String(LEGACY_TRUTHS[case_id])
		artifact["confidence"] = 0.77
		artifact["historicalIntegrity"] = 62.5 + float(seed_value % 4)
		artifact["restorationCost"] = 57.5 + float(seed_value % 6)
		artifact["restorationQuality"] = 27.0
		artifact["listing"] = {"starting": 223, "reserve": 289, "confidence": 0.75, "disclosure": "LIKELY"}
		gs.inventory.append(artifact)
		gs.campaign_state.caseArtifactLedger[case_id] = {
			"issued": true, "artifactUid": artifact.uniqueId, "disposition": "INVENTORY",
			"saleTransactionId": "", "publicConditionSnapshot": {"historicalIntegrity": artifact.historicalIntegrity},
			"publicAppraisalSnapshot": artifact.baseValue, "migrationSentinel": "ledger:%s" % case_id
		}
		gs.campaign_state.caseStates[case_id] = stale_case_state(case_id, definitions[case_id]).state.duplicate(true)
	gs.campaign_state.activeCaseId = "shadow_optic"
	var historical_state := {
		"discoveredEvidenceIds": ["shadow_music_box:material", "shadow_music_box:provenance"],
		"selectedHypothesisId": "GENUINE_WITH_MODERN_REPAIR", "citedEvidenceIds": ["shadow_music_box:material"],
		"resolved": true,
		"resolutionResult": {"outcome": "credible", "historicalReceipt": "keep-exact"},
		"migrationSentinel": {"resolved": true, "keep": [1, 9, 6]}
	}
	gs.campaign_state.caseStates["shadow_music_box"] = historical_state
	gs.campaign_state.completedCases["shadow_music_box"] = true
	gs.campaign_state.caseOutcomes["shadow_music_box"] = "credible"
	gs.campaign_state.caseArtifactLedger["shadow_music_box"] = {
		"issued": true, "artifactUid": "case_shadow_music_box_historical", "disposition": "SOLD",
		"saleTransactionId": "stage7-historical-sale", "publicConditionSnapshot": {"historicalIntegrity": 66.0},
		"publicAppraisalSnapshot": 810, "migrationSentinel": "sale-ledger-exact"
	}
	gs.transactions = [{"id": "stage7-historical-sale", "type": "sale", "instanceId": "case_shadow_music_box_historical", "amount": 846, "day": 9, "sentinel": "transaction-exact"}]
	gs.auction_history = [{"artifactId": "case_shadow_music_box_historical", "result": {"transactionId": "stage7-historical-sale", "sale_status": "SOLD", "reserve_met": true, "hammer": 914, "net": 846, "sentinel": "receipt-exact"}}]
	return gs.save_payload().duplicate(true)


func protected_payload_snapshot(payload: Dictionary) -> Dictionary:
	var campaign: Dictionary = payload.get("campaign", {}).duplicate(true)
	campaign.erase("caseStates")
	return {
		"money": payload.get("money", 0), "reputation": payload.get("reputation", 0), "day": payload.get("day", 0),
		"rngStateExact": payload.get("rngStateExact", ""), "inventory": payload.get("inventory", []),
		"transactions": payload.get("transactions", []), "auctionHistory": payload.get("auctionHistory", []),
		"pendingAuction": payload.get("pendingAuction", {}), "upgrades": payload.get("upgrades", []),
		"selectedTool": payload.get("selectedTool", ""), "campaignWithoutCaseStates": campaign,
		"tutorial": payload.get("stageRunState", {}).get("tutorialCompletedSteps", []),
		"telemetry": payload.get("stageRunState", {}).get("telemetry", {})
	}


func campaign_row_exact(actual: Dictionary, expected: Dictionary) -> bool:
	return String(actual.get("act", "")) == String(expected.act) \
		and String(actual.get("npcId", "")) == String(expected.npc) \
		and actual.get("documentIds", []) == expected.documents \
		and semantic_equal(actual.get("rewards", {}), expected.rewards) \
		and String(actual.get("rewardSpecId", "")) == String(expected.spec) \
		and String(actual.get("storyArtifactId", "")) == String(expected.story)


func stage_eight_snapshot(registry: Node) -> Dictionary:
	var rows := {}
	for case_id: String in STAGE8_CASE_IDS:
		rows[case_id] = registry.get_case(case_id).duplicate(true)
	return {"stage": registry.get_stage_definition(8).duplicate(true), "cases": rows}


func run() -> void:
	var registry: Node = get_root().get_node("RuntimeRegistry")
	var gs: Node = get_root().get_node("GameState")
	gs.persistence_enabled = false
	var definitions: Dictionary = {}
	var fallback_count := 0
	var missing_methods: Array = []
	for method_name: String in [
		"new_game", "begin_case", "case_definition", "get_case_public_state",
		"discover_case_evidence", "evaluate_case_submission", "resolve_case_v2",
		"apply_save_data", "save_payload", "listing_public_status_tags", "auction_public_reason_tags"
	]:
		if not gs.has_method(method_name):
			missing_methods.append(method_name)
	for case_id: String in CASE_IDS:
		var definition: Dictionary = registry.get_case_v2(case_id)
		definitions[case_id] = definition
		if definition.is_empty() or int(gs.case_definition(case_id).get("schema_version", 0)) != 2:
			fallback_count += 1
	var stage_definition: Dictionary = registry.get_stage_definition(7)
	var lock_payload: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cases/authored_v2.lock.json"))
	var locked_cases: Array = []
	var lock_hashes_exact := lock_payload is Dictionary
	if lock_payload is Dictionary:
		for entry_value: Variant in lock_payload.get("files", []):
			if not entry_value is Dictionary:
				continue
			var entry: Dictionary = entry_value
			var case_id := String(entry.get("case_id", ""))
			if not CASE_IDS.has(case_id):
				continue
			locked_cases.append(case_id)
			var resource_path := "res://" + String(entry.get("path", ""))
			lock_hashes_exact = lock_hashes_exact and FileAccess.file_exists(resource_path) \
				and FileAccess.get_sha256(resource_path) == String(entry.get("sha256", ""))
	var data_ready: bool = missing_methods.is_empty() and fallback_count == 0
	var data_ok: bool = data_ready and registry.authored_case_errors.is_empty() \
		and registry.stage_definition_errors.is_empty() and registry.authored_cases_v2.size() == 26 \
		and stage_definition.get("case_ids", []) == CASE_IDS \
		and stage_definition.get("introduced_artifact_ids", []) == ["artifact_073", "artifact_074"] \
		and is_equal_approx(float(registry.stage_difficulty_multiplier(7)), STAGE_MULTIPLIER) \
		and unique_strings(locked_cases).size() == 2 and lock_hashes_exact \
		and CASE_IDS.all(func(case_id: String): return registry.authored_cases_v2.has(case_id))
	record(
		"S7-AUTHORED-DATA-01",
		"Stage 7 resolves two hash-locked authored cases in exact order at the canonical multiplier with zero fallback while later authored stages remain registered",
		data_ok,
		{"missingMethods": missing_methods, "fallbackCount": fallback_count, "authoredCount": registry.authored_cases_v2.size(), "caseOrder": stage_definition.get("case_ids", []), "introduced": stage_definition.get("introduced_artifact_ids", []), "difficulty": registry.stage_difficulty_multiplier(7), "lockedCases": locked_cases, "lockHashesExact": lock_hashes_exact, "authoredErrors": registry.authored_case_errors, "stageErrors": registry.stage_definition_errors}
	)
	if not data_ready:
		blocked_remaining("STAGE7_AUTHORED_DATA_NOT_READY")
		finish(gs)
		return

	var stage8_before := stage_eight_snapshot(registry)
	start_stage_seven(gs)
	var source_by_path := {
		"gameState": FileAccess.get_file_as_string("res://scripts/game_state.gd"),
		"main3d": FileAccess.get_file_as_string("res://scripts/main3d.gd")
	}
	var before_query := JSON.stringify(gs.save_payload())
	var source_hits: Dictionary = {}
	var query_exact := true
	for case_id: String in CASE_IDS:
		var hits: Dictionary = {}
		for source_name: String in source_by_path.keys():
			hits[source_name] = String(source_by_path[source_name]).contains(case_id)
		source_hits[case_id] = hits
		query_exact = query_exact and registry.get_case_v2(case_id) == gs.case_definition(case_id)
	var generic_ok: bool = query_exact and before_query == JSON.stringify(gs.save_payload())
	for hit_rows: Variant in source_hits.values():
		for hit_value: Variant in (hit_rows as Dictionary).values():
			generic_ok = generic_ok and not bool(hit_value)
	record(
		"S7-AUTHORED-GENERIC-02",
		"Both Stage 7 cases use generic read-only registry and gameplay paths",
		generic_ok,
		{"runtimeExact": query_exact, "caseIdHits": source_hits, "saveMutation0": before_query == JSON.stringify(gs.save_payload())}
	)

	var campaign_ok: bool = true
	var campaign_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var expected: Dictionary = EXPECTED_CAMPAIGN[case_id]
		var story_case: Dictionary = registry.get_case(case_id)
		var story_artifact: Dictionary = registry.story_artifacts.get(String(story_case.get("storyArtifactId", "")), {})
		var case_ok: bool = campaign_row_exact(story_case, expected) \
			and String(story_artifact.get("baseSpecId", "")) == String(expected.spec) \
			and String(definitions[case_id].get("artifact_spec_id", "")) == String(expected.spec) \
			and String(definitions[case_id].get("canonical_hypothesis_id", "")) == String(EXPECTED_CANONICAL[case_id])
		campaign_ok = campaign_ok and case_ok
		campaign_rows[case_id] = {"case": story_case, "storyBaseSpec": story_artifact.get("baseSpecId", ""), "authoredSpec": definitions[case_id].get("artifact_spec_id", ""), "canonical": definitions[case_id].get("canonical_hypothesis_id", ""), "ok": case_ok}
	record(
		"S7-AUTHORED-CAMPAIGN-03",
		"Stage 7 keeps exact ACT 4, NPC, document, reward, story and corrected 057/059 artifact bindings",
		campaign_ok,
		campaign_rows
	)

	var stage8_definition: Dictionary = registry.get_stage_definition(8)
	var stage8_rows: Dictionary = {}
	var stage8_ok: bool = stage8_definition.get("case_ids", []) == STAGE8_CASE_IDS \
		and stage8_definition.get("introduced_artifact_ids", []) == ["artifact_075", "artifact_076"] \
		and is_equal_approx(float(registry.stage_difficulty_multiplier(8)), STAGE8_MULTIPLIER)
	for case_id: String in STAGE8_CASE_IDS:
		var actual: Dictionary = registry.get_case(case_id)
		var row_ok: bool = campaign_row_exact(actual, EXPECTED_STAGE8_CAMPAIGN[case_id]) \
			and not registry.get_case_v2(case_id).is_empty() \
			and String(registry.get_case_v2(case_id).get("artifact_spec_id", "")) == String(EXPECTED_STAGE8_CAMPAIGN[case_id].spec)
		stage8_ok = stage8_ok and row_ok
		stage8_rows[case_id] = {"case": actual, "authored": not registry.get_case_v2(case_id).is_empty(), "ok": row_ok}
	record(
		"S7-AUTHORED-STAGE8-04",
		"Stage 8 resolves exactly master_chronometer then master_optical with fresh authored bindings and preserved ACT 5 rewards",
		stage8_ok,
		{"stage": stage8_definition, "cases": stage8_rows}
	)

	var source_ok: bool = true
	var source_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var kinds: Array = definition.get("evidence", []).map(func(row: Dictionary): return String(row.get("source", {}).get("kind", "")))
		var groups := unique_strings(definition.get("evidence", []).map(func(row: Dictionary): return String(row.get("independence_key", ""))))
		var relation_complete: bool = true
		var npc_expression := ""
		for evidence_value: Variant in definition.get("evidence", []):
			if evidence_value is Dictionary and String(evidence_value.get("source", {}).get("kind", "")) == "NPC":
				npc_expression = String(evidence_value.get("presentation", {}).get("npc_portrait", {}).get("expression", ""))
		for hypothesis_value: Variant in definition.get("hypotheses", []):
			if not hypothesis_value is Dictionary:
				relation_complete = false
				continue
			var hypothesis_id := String(hypothesis_value.get("id", ""))
			var relations: Array = []
			for evidence_value: Variant in definition.get("evidence", []):
				if evidence_value is Dictionary:
					for relation_value: Variant in evidence_value.get("relations", []):
						if relation_value is Dictionary and String(relation_value.get("hypothesis_id", "")) == hypothesis_id:
							relations.append(String(relation_value.get("stance", "")))
			relation_complete = relation_complete and not relations.is_empty()
		var case_ok: bool = evidence_ids(definition) == EXPECTED_SOURCES[case_id] \
			and definition.get("resolution", {}).get("required_source_refs", []) == EXPECTED_REQUIRED_SOURCES[case_id] \
			and kinds.count("ARTIFACT") == 2 and kinds.count("DOCUMENT") == 2 \
			and kinds.count("NPC") == 1 and kinds.count("REFERENCE") == 1 \
			and groups.size() == 6 and relation_complete and outcome_rules_exact(definition) \
			and npc_expression == String(EXPECTED_NPC_EXPRESSION[case_id])
		source_ok = source_ok and case_ok
		source_rows[case_id] = {"ids": evidence_ids(definition), "kinds": kinds, "groups": groups, "required": definition.get("resolution", {}).get("required_source_refs", []), "npcExpression": npc_expression, "rules": definition.get("resolution", {}).get("outcome_rules", []), "ok": case_ok}
	record(
		"S7-AUTHORED-SOURCES-05",
		"Each Stage 7 graph has exact A2/D2/NPC1/REF1 sources, six groups and an ordered four-step outcome ladder",
		source_ok,
		source_rows
	)

	var issuance_ok: bool = true
	var issuance_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var fixture := begin_stage_seven_case(gs, case_id)
		var artifact: Dictionary = fixture.artifact
		var expected: Dictionary = EXPECTED_CAMPAIGN[case_id]
		var before_pressure := pressure_signature(gs)
		var repeated: Dictionary = gs.begin_case(case_id) if not artifact.is_empty() else {}
		var case_ok: bool = bool(fixture.start.get("ok", false)) and bool(fixture.priorReady) \
			and not artifact.is_empty() and repeated == artifact and gs.inventory.size() == 1 \
			and String(artifact.get("uniqueId", "")) == "case_%s" % case_id \
			and String(artifact.get("artifactSpecId", "")) == String(expected.spec) \
			and String(artifact.get("storyArtifactId", "")) == String(expected.story) \
			and String(artifact.get("authenticityTruth", "")) == String(EXPECTED_CANONICAL[case_id]) \
			and before_pressure == pressure_signature(gs)
		issuance_ok = issuance_ok and case_ok
		issuance_rows[case_id] = {"uid": artifact.get("uniqueId", ""), "spec": artifact.get("artifactSpecId", ""), "story": artifact.get("storyArtifactId", ""), "truth": artifact.get("authenticityTruth", ""), "repeatSame": repeated == artifact, "inventoryCount": gs.inventory.size(), "pressureMutation0": before_pressure == pressure_signature(gs), "ok": case_ok}
	record(
		"S7-AUTHORED-ISSUANCE-06",
		"Fresh Stage 7 issuance is exactly optic 057 and composite 059 with stable one-per-case UIDs",
		issuance_ok,
		issuance_rows
	)

	var risk_ok: bool = true
	var risk_rows: Dictionary = {}
	var aggregate := {"NONE": 0, "LOW": 0, "HIGH": 0}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var counts := risk_counts(definition)
		for level: String in aggregate.keys():
			aggregate[level] = int(aggregate[level]) + int(counts[level])
		var actual_tools: Dictionary = {}
		var runtime_rows: Array = []
		for evidence_value: Variant in definition.get("evidence", []):
			if not evidence_value is Dictionary:
				continue
			var level := String(evidence_value.get("risk", {}).get("level", "NONE"))
			if level == "NONE":
				continue
			var evidence_id := String(evidence_value.get("id", ""))
			var tools: Array = evidence_value.get("unlock", {}).get("requires_tools", [])
			actual_tools[evidence_id] = {"level": level, "tools": tools}
			var fixture := begin_stage_seven_case(gs, case_id)
			var artifact: Dictionary = fixture.artifact
			var prerequisites_ok: bool = not artifact.is_empty() and satisfy_requirements(gs, case_id, definition, evidence_id)
			var wrong_tool := "soft_brush" if not tools.has("soft_brush") else "uv_lamp"
			gs.select_tool(wrong_tool)
			var wrong_before := JSON.stringify(gs.save_payload())
			var wrong_result: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
			var wrong_zero: bool = wrong_before == JSON.stringify(gs.save_payload())
			gs.select_tool(String(tools[0]))
			var integrity_before := float(artifact.get("historicalIntegrity", 0.0))
			var discovery: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
			var expected_penalty := (1.0 if level == "LOW" else 3.0) * STAGE_MULTIPLIER
			var integrity_after := float(artifact.get("historicalIntegrity", 0.0))
			var duplicate_before := JSON.stringify(gs.save_payload())
			var duplicate: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
			var duplicate_zero: bool = duplicate_before == JSON.stringify(gs.save_payload())
			var row_ok: bool = prerequisites_ok \
				and not bool(wrong_result.get("ok", true)) and String(wrong_result.get("code", "")) == "TOOL_REQUIRED" and wrong_zero \
				and bool(discovery.get("ok", false)) and String(discovery.get("code", "")) == "DISCOVERED" \
				and is_equal_approx(float(discovery.get("appliedRiskPenalty", -1.0)), expected_penalty) \
				and is_equal_approx(integrity_before - integrity_after, expected_penalty) \
				and bool(duplicate.get("ok", false)) and String(duplicate.get("code", "")) == "ALREADY_DISCOVERED" and duplicate_zero
			runtime_rows.append({"id": evidence_id, "level": level, "tools": tools, "wrong": wrong_result, "penalty": discovery.get("appliedRiskPenalty", -1), "expectedPenalty": expected_penalty, "duplicate": duplicate, "ok": row_ok})
		var case_ok: bool = counts == {"NONE": 4, "LOW": 1, "HIGH": 1} and actual_tools == EXPECTED_RISK_TOOLS[case_id] \
			and runtime_rows.all(func(row: Dictionary): return bool(row.get("ok", false)))
		risk_ok = risk_ok and case_ok
		risk_rows[case_id] = {"counts": counts, "tools": actual_tools, "runtime": runtime_rows, "ok": case_ok}
	var weighted_total := (float(aggregate.LOW) + 3.0 * float(aggregate.HIGH)) * STAGE_MULTIPLIER
	risk_ok = risk_ok and aggregate == {"NONE": 8, "LOW": 2, "HIGH": 2} \
		and is_equal_approx(weighted_total, 12.005842814792)
	record(
		"S7-AUTHORED-RISK-07",
		"Each Stage 7 case exposes NONE4/LOW1/HIGH1 with distinct tool gates and exactly one 1.500730351849 pressure multiplier",
		risk_ok,
		{"aggregate": aggregate, "weightedTotal": weighted_total, "cases": risk_rows}
	)

	var provenance_ok: bool = true
	var provenance_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var tagged: Array = definition.get("evidence", []).filter(func(row: Dictionary): return String(row.get("public_clue_id", "")) == "PROVENANCE")
		var fixture := begin_stage_seven_case(gs, case_id)
		var artifact: Dictionary = fixture.artifact
		var listing_before: Array = gs.listing_public_status_tags(artifact, "UNCERTAIN")
		var auction_before: Array = gs.auction_public_reason_tags(artifact, {}, "NO_SALE", {"reserve": 100, "hammer": 0, "reserve_met": false})
		var evidence_id := String(EXPECTED_PROVENANCE[case_id])
		var prerequisites_ok: bool = satisfy_requirements(gs, case_id, definition, evidence_id)
		var row := evidence_by_id(definition, evidence_id)
		var tools: Array = row.get("unlock", {}).get("requires_tools", [])
		if not tools.is_empty():
			gs.select_tool(String(tools[0]))
		var discovery: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
		var duplicate_before := JSON.stringify(gs.save_payload())
		var duplicate: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
		var duplicate_zero: bool = duplicate_before == JSON.stringify(gs.save_payload())
		var listing_after: Array = gs.listing_public_status_tags(artifact, "UNCERTAIN")
		var auction_after: Array = gs.auction_public_reason_tags(artifact, {}, "BID", {})
		var public_state: Dictionary = gs.get_case_public_state(case_id)
		var case_ok: bool = tagged.size() == 1 and String(tagged[0].get("id", "")) == evidence_id \
			and String(tagged[0].get("source", {}).get("kind", "")) == "DOCUMENT" \
			and String(tagged[0].get("reliability", "")) == "HIGH" \
			and String(tagged[0].get("risk", {}).get("level", "")) == "NONE" and prerequisites_ok \
			and reason_has(listing_before, "PROVENANCE_UNCERTAIN") and reason_has(auction_before, "PROVENANCE_UNCERTAIN") \
			and bool(discovery.get("ok", false)) and String(discovery.get("code", "")) == "DISCOVERED" \
			and bool(duplicate.get("ok", false)) and String(duplicate.get("code", "")) == "ALREADY_DISCOVERED" and duplicate_zero \
			and artifact.get("knownClues", []).count("PROVENANCE") == 1 \
			and reason_has(listing_after, "PROVENANCE_STRONG") and reason_has(auction_after, "PROVENANCE_STRONG") \
			and public_private_fields_hidden(public_state)
		provenance_ok = provenance_ok and case_ok
		provenance_rows[case_id] = {"tagged": tagged, "discovery": discovery, "duplicate": duplicate, "knownClues": artifact.get("knownClues", []), "before": {"listing": listing_before, "auction": auction_before}, "after": {"listing": listing_after, "auction": auction_after}, "ok": case_ok}
	record(
		"S7-AUTHORED-PROVENANCE-08",
		"Each Stage 7 case has one sole high-reliability, risk-free DOCUMENT provenance bridge that commits once",
		provenance_ok,
		provenance_rows
	)

	var outcomes_ok: bool = true
	var outcome_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var fixture := begin_stage_seven_case(gs, case_id)
		var discovered := discover_all(gs, case_id)
		var canonical := String(EXPECTED_CANONICAL[case_id])
		var wrong := wrong_hypothesis(definition)
		var required: Array = EXPECTED_REQUIRED_SOURCES[case_id]
		var wrong_rows := citation_rows(definition, wrong, "REFUTE", 2)
		var before := JSON.stringify(gs.save_payload())
		var empty: Dictionary = gs.evaluate_case_submission(case_id, canonical, [])
		var correct_one: Dictionary = gs.evaluate_case_submission(case_id, canonical, required.slice(0, 1))
		var credible: Dictionary = gs.evaluate_case_submission(case_id, canonical, required.slice(0, 3))
		var masterful: Dictionary = gs.evaluate_case_submission(case_id, canonical, required)
		var wrong_one: Dictionary = gs.evaluate_case_submission(case_id, wrong, wrong_rows.slice(0, 1))
		var mistaken: Dictionary = gs.evaluate_case_submission(case_id, wrong, wrong_rows)
		var after := JSON.stringify(gs.save_payload())
		var case_ok: bool = not fixture.artifact.is_empty() and discovered.size() == 6 \
			and outcome_rules_exact(definition) and wrong_rows.size() == 2 \
			and not bool(empty.get("ok", true)) and String(empty.get("code", "")) == "CITATION_REQUIRED" \
			and bool(correct_one.get("ok", false)) and String(correct_one.get("outcome", "")) == "reviewed_with_mentor" \
			and bool(credible.get("ok", false)) and String(credible.get("outcome", "")) == "credible" \
			and bool(masterful.get("ok", false)) and String(masterful.get("outcome", "")) == "masterful" and bool(masterful.get("substantiated", false)) \
			and bool(wrong_one.get("ok", false)) and String(wrong_one.get("outcome", "")) == "reviewed_with_mentor" \
			and bool(mistaken.get("ok", false)) and String(mistaken.get("outcome", "")) == "mistaken" \
			and int(mistaken.get("netScore", 0)) < 0 and not bool(mistaken.get("conclusionAccurate", true)) \
			and before == after
		outcomes_ok = outcomes_ok and case_ok
		outcome_rows[case_id] = {"discovered": discovered, "wrong": wrong, "required": required, "empty": empty, "mentor": correct_one, "credible": credible, "masterful": masterful, "mistaken": mistaken, "mutation0": before == after, "ok": case_ok}
	record(
		"S7-AUTHORED-OUTCOMES-09",
		"Both Stage 7 public evaluators execute mentor, credible, masterful and mistaken in order while empty reports fail closed",
		outcomes_ok,
		outcome_rows
	)

	var legacy_payload := build_legacy_payload(gs, definitions)
	var legacy_validation: Dictionary = gs.validate_save_payload(legacy_payload)
	var legacy_applied := bool(gs.apply_save_data(legacy_payload))
	var artifact_expected: Dictionary = {}
	for saved_value: Variant in legacy_payload.get("inventory", []):
		if saved_value is Dictionary:
			artifact_expected[String(saved_value.get("caseId", ""))] = saved_value
	var legacy_ok: bool = legacy_applied
	var legacy_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var expected_saved: Dictionary = artifact_expected.get(case_id, {})
		var actual: Dictionary = gs.find_inventory_instance("case_%s" % case_id)
		var actual_saved: Dictionary = gs.serialize_instance(actual) if not actual.is_empty() else {}
		var ledger_expected: Dictionary = legacy_payload.campaign.caseArtifactLedger[case_id]
		var case_ok: bool = not actual.is_empty() and semantic_equal(actual_saved, expected_saved) \
			and String(actual.get("artifactSpecId", "")) == String(LEGACY_SPECS[case_id]) \
			and String(actual.get("storyArtifactId", "")) == String(EXPECTED_CAMPAIGN[case_id].story) \
			and String(actual.get("uniqueId", "")) == "case_%s" % case_id \
			and semantic_equal(gs.campaign_state.caseArtifactLedger[case_id], ledger_expected)
		legacy_ok = legacy_ok and case_ok
		legacy_rows[case_id] = {"expected": expected_saved, "actual": actual_saved, "ledgerExact": semantic_equal(gs.campaign_state.caseArtifactLedger[case_id], ledger_expected), "ok": case_ok}
	var duplicate_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var targeted_payload: Dictionary = legacy_payload.duplicate(true)
		targeted_payload.campaign.activeCaseId = case_id
		var loaded := bool(gs.apply_save_data(targeted_payload))
		var before := JSON.stringify(gs.save_payload())
		var returned: Dictionary = gs.begin_case(case_id) if loaded else {}
		var row_ok: bool = loaded and String(returned.get("uniqueId", "")) == "case_%s" % case_id \
			and String(returned.get("artifactSpecId", "")) == String(LEGACY_SPECS[case_id]) \
			and String(returned.get("storyArtifactId", "")) == String(EXPECTED_CAMPAIGN[case_id].story) \
			and gs.inventory.size() == 2 and before == JSON.stringify(gs.save_payload())
		legacy_ok = legacy_ok and row_ok
		duplicate_rows[case_id] = {"returnedUid": returned.get("uniqueId", ""), "returnedSpec": returned.get("artifactSpecId", ""), "returnedStory": returned.get("storyArtifactId", ""), "inventoryCount": gs.inventory.size(), "mutation0": before == JSON.stringify(gs.save_payload()), "ok": row_ok}
	record(
		"S7-AUTHORED-LEGACY-10",
		"Legacy story19+051 and story20+057 artifacts, mutable fields and ledgers remain exact with zero duplicate issuance",
		bool(legacy_validation.get("ok", false)) and legacy_ok,
		{"validation": legacy_validation, "artifacts": legacy_rows, "duplicates": duplicate_rows}
	)

	legacy_applied = bool(gs.apply_save_data(legacy_payload))
	var canonical_ok: bool = legacy_applied
	var canonical_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var expected := stale_case_state(case_id, definitions[case_id])
		var actual: Dictionary = gs.campaign_state.caseStates.get(case_id, {})
		var valid_ids := evidence_ids(definitions[case_id])
		var discovered_actual: Array = actual.get("discoveredEvidenceIds", [])
		var cited_actual: Array = actual.get("citedEvidenceIds", [])
		var subset_exact := discovered_actual.all(func(value: Variant): return valid_ids.has(String(value))) \
			and cited_actual.all(func(value: Variant): return discovered_actual.has(String(value)))
		var case_ok: bool = discovered_actual == expected.expectedDiscovered and cited_actual == expected.expectedCited \
			and subset_exact and String(actual.get("selectedHypothesisId", "invalid")) == "" \
			and actual.get("resolutionResult", {"invalid": true}).is_empty() \
			and semantic_equal(actual.get("migrationSentinel", {}), expected.state.migrationSentinel)
		canonical_ok = canonical_ok and case_ok
		canonical_rows[case_id] = {"actual": actual, "expectedDiscovered": expected.expectedDiscovered, "expectedCited": expected.expectedCited, "subsetExact": subset_exact, "ok": case_ok}
	var before_protected := protected_payload_snapshot(legacy_payload)
	var first_normalized_payload: Dictionary = gs.save_payload().duplicate(true)
	var after_protected := protected_payload_snapshot(first_normalized_payload)
	var profile_before: Dictionary = gs.profile_payload().duplicate(true)
	var second_applied := bool(gs.apply_save_data(first_normalized_payload))
	var second_payload: Dictionary = gs.save_payload().duplicate(true)
	var scoped_ok: bool = canonical_ok and second_applied and semantic_equal(before_protected, after_protected) \
		and semantic_equal(first_normalized_payload, second_payload) \
		and semantic_equal(profile_before, gs.profile_payload())
	record(
		"S7-AUTHORED-SCOPE-11",
		"Unresolved Stage 7 state canonicalization is exact, idempotent, and changes no economy, RNG, artifact, ledger, auction, tutorial, telemetry or profile authority",
		scoped_ok,
		{"cases": canonical_rows, "protectedMutation0": semantic_equal(before_protected, after_protected), "idempotent": semantic_equal(first_normalized_payload, second_payload), "profileMutation0": semantic_equal(profile_before, gs.profile_payload())}
	)

	var historical_before: Dictionary = legacy_payload.campaign.caseStates.shadow_music_box
	var historical_ledger_before: Dictionary = legacy_payload.campaign.caseArtifactLedger.shadow_music_box
	var stage8_after := stage_eight_snapshot(registry)
	var history_ok: bool = semantic_equal(gs.campaign_state.caseStates.get("shadow_music_box", {}), historical_before) \
		and bool(gs.campaign_state.completedCases.get("shadow_music_box", false)) \
		and String(gs.campaign_state.caseOutcomes.get("shadow_music_box", "")) == "credible" \
		and semantic_equal(gs.campaign_state.caseArtifactLedger.get("shadow_music_box", {}), historical_ledger_before) \
		and semantic_equal(gs.transactions, legacy_payload.transactions) \
		and semantic_equal(gs.auction_history, legacy_payload.auctionHistory) \
		and semantic_equal(stage8_before, stage8_after)
	record(
		"S7-AUTHORED-HISTORY-12",
		"Resolved Stage 6 history, SOLD ledger, receipts and all Stage 8 definitions remain semantically exact",
		history_ok,
		{"caseState": gs.campaign_state.caseStates.get("shadow_music_box", {}), "ledger": gs.campaign_state.caseArtifactLedger.get("shadow_music_box", {}), "transactions": gs.transactions, "auctionHistory": gs.auction_history, "stage8Mutation0": semantic_equal(stage8_before, stage8_after)}
	)

	finish(gs)
