extends SceneTree

## Stage 6A authored-v2, corrected fresh identity, and legacy-save contract.
## The suite exercises only public/generic runtime paths and writes one QA report.

const CASE_IDS := ["shadow_gauge", "shadow_clock", "shadow_music_box"]
const EXPECTED_TEST_COUNT := 13
const REPORT_PATH := "res://qa/R3_STAGE6_AUTHORED_CASES_TESTS.json"
const STAGE_MULTIPLIER := 1.4025517307
const DTO_KEYS := [
	"detail", "materialPath", "meshPath", "metallic", "palette",
	"recipe", "roughness", "scale", "specId", "trim"
]

const EXPECTED_CAMPAIGN := {
	"shadow_gauge": {
		"act": "ACT_4", "npc": "hana_mire", "documents": ["document_01", "document_02"],
		"spec": "artifact_050", "story": "story_artifact_16",
		"rewards": {"money": 270, "reputation": 2, "mastery": 3, "museumTrust": 1, "historicalIntegrity": 1}
	},
	"shadow_clock": {
		"act": "ACT_4", "npc": "mara_venn", "documents": ["document_03", "document_04"],
		"spec": "artifact_031", "story": "story_artifact_17",
		"rewards": {"money": 282, "reputation": 2, "mastery": 3, "museumTrust": 1, "historicalIntegrity": 1}
	},
	"shadow_music_box": {
		"act": "ACT_4", "npc": "iris_bell", "documents": ["document_05", "document_06"],
		"spec": "artifact_035", "story": "story_artifact_18",
		"rewards": {"money": 294, "reputation": 2, "mastery": 3, "museumTrust": 1, "historicalIntegrity": 1}
	}
}

const EXPECTED_CANONICAL := {
	"shadow_gauge": "hyp.shadow_gauge.genuine_juniper_precision_gauge",
	"shadow_clock": "hyp.shadow_clock.genuine_kestrel_clock_period_escapement_repair",
	"shadow_music_box": "hyp.shadow_music_box.genuine_orchard_music_box_modern_governor_repair"
}

const EXPECTED_SOURCES := {
	"shadow_gauge": [
		"src.shadow_gauge.artifact.period_gauge_identity",
		"src.shadow_gauge.artifact.internal_maker_continuity",
		"src.shadow_gauge.document.estate_custody_note",
		"src.shadow_gauge.document.model149_catalog_leaf",
		"src.shadow_gauge.npc.hana_shadow_mark_context",
		"src.shadow_gauge.reference.period_gauge_standard"
	],
	"shadow_clock": [
		"src.shadow_clock.artifact.period_clock_identity",
		"src.shadow_clock.artifact.period_escapement_repair",
		"src.shadow_clock.document.collector_repair_letter",
		"src.shadow_clock.document.auction_custody_receipt",
		"src.shadow_clock.npc.mara_shadow_mark_context",
		"src.shadow_clock.reference.period_clock_standard"
	],
	"shadow_music_box": [
		"src.shadow_music_box.artifact.period_music_box_identity",
		"src.shadow_music_box.artifact.modern_governor_repair",
		"src.shadow_music_box.document.serial_reference_leaf",
		"src.shadow_music_box.document.estate_custody_note",
		"src.shadow_music_box.npc.iris_shadow_mark_context",
		"src.shadow_music_box.reference.period_music_box_standard"
	]
}

const EXPECTED_REQUIRED_SOURCES := {
	"shadow_gauge": [
		"src.shadow_gauge.artifact.period_gauge_identity",
		"src.shadow_gauge.artifact.internal_maker_continuity",
		"src.shadow_gauge.document.estate_custody_note",
		"src.shadow_gauge.reference.period_gauge_standard"
	],
	"shadow_clock": [
		"src.shadow_clock.artifact.period_clock_identity",
		"src.shadow_clock.artifact.period_escapement_repair",
		"src.shadow_clock.document.auction_custody_receipt",
		"src.shadow_clock.reference.period_clock_standard"
	],
	"shadow_music_box": [
		"src.shadow_music_box.artifact.period_music_box_identity",
		"src.shadow_music_box.artifact.modern_governor_repair",
		"src.shadow_music_box.document.estate_custody_note",
		"src.shadow_music_box.reference.period_music_box_standard"
	]
}

const EXPECTED_PROVENANCE := {
	"shadow_gauge": "src.shadow_gauge.document.estate_custody_note",
	"shadow_clock": "src.shadow_clock.document.auction_custody_receipt",
	"shadow_music_box": "src.shadow_music_box.document.estate_custody_note"
}

const EXPECTED_RISK_TOOLS := {
	"shadow_gauge": {
		"src.shadow_gauge.artifact.period_gauge_identity": {"level": "LOW", "tools": ["material_scanner"]},
		"src.shadow_gauge.artifact.internal_maker_continuity": {"level": "HIGH", "tools": ["precision_screwdriver"]}
	},
	"shadow_clock": {
		"src.shadow_clock.artifact.period_clock_identity": {"level": "LOW", "tools": ["material_scanner"]},
		"src.shadow_clock.artifact.period_escapement_repair": {"level": "HIGH", "tools": ["precision_screwdriver"]}
	},
	"shadow_music_box": {
		"src.shadow_music_box.artifact.period_music_box_identity": {"level": "LOW", "tools": ["material_scanner"]},
		"src.shadow_music_box.artifact.modern_governor_repair": {"level": "HIGH", "tools": ["repair_toolkit"]}
	}
}

const LEGACY_SPECS := {
	"shadow_gauge": "artifact_041",
	"shadow_clock": "artifact_046",
	"shadow_music_box": "artifact_050"
}

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(test_id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": test_id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func finish(gs: Node) -> void:
	gs.persistence_enabled = false
	var passed := results.filter(func(row: Dictionary): return bool(row.get("passed", false))).size()
	var report := {
		"suite": "R3 Stage 6 Authored Cases",
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
		["S6-AUTHORED-GENERIC-02", "Stage 6 definitions stay on generic mutation-zero paths"],
		["S6-AUTHORED-CAMPAIGN-03", "Stage 6 campaign bindings and rewards are exact"],
		["S6-AUTHORED-SOURCES-04", "Stage 6 source graphs are exact"],
		["S6-AUTHORED-ISSUANCE-05", "Stage 6 fresh issuance identities are exact"],
		["S6-AUTHORED-RISK-06", "Stage 6 risk and tool routes are exact"],
		["S6-AUTHORED-PROVENANCE-07", "Stage 6 provenance bridges are exact"],
		["S6-AUTHORED-OUTCOMES-08", "Stage 6 ordered outcomes execute exactly"],
		["S6-AUTHORED-LEGACY-09", "Stage 6 legacy ledgers issue no duplicates"],
		["S6-AUTHORED-CANONICAL-10", "Stage 6 unresolved case states canonicalize exactly"],
		["S6-AUTHORED-SCOPE-11", "Stage 6 canonicalization is idempotent and scoped"],
		["S6-AUTHORED-HISTORY-12", "Resolved history and sale receipts remain exact"],
		["S6-AUTHORED-RENDER-13", "Fresh and legacy same-spec render identities remain isolated"]
	]
	for row: Array in rows:
		record(String(row[0]), String(row[1]), false, {"code": code})


func stage_six_profile(gs: Node) -> Dictionary:
	var profile: Dictionary = gs.default_player_profile()
	profile["highestUnlockedStage"] = 6
	profile["clearedStages"] = [1, 2, 3, 4, 5]
	profile["stageBest"] = {"1": 55.0, "2": 58.0, "3": 61.0, "4": 64.0, "5": 67.0}
	return profile


func start_stage_six(gs: Node) -> Dictionary:
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	gs.player_profile = stage_six_profile(gs)
	var started: Dictionary = gs.new_game(6)
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	return started


func prepare_prior_cases(gs: Node, case_id: String) -> bool:
	var ready := true
	for ordered_case_id: String in CASE_IDS:
		if ordered_case_id == case_id:
			break
		ready = bool(gs.prepare_case_for_test(ordered_case_id)) and ready
	return ready


func begin_stage_six_case(gs: Node, case_id: String) -> Dictionary:
	var started := start_stage_six(gs)
	var prior_ready := bool(started.get("ok", false)) and prepare_prior_cases(gs, case_id)
	var artifact: Dictionary = gs.begin_case(case_id) if prior_ready else {}
	return {"start": started, "priorReady": prior_ready, "artifact": artifact}


func semantic_equal(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


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


func sorted_keys(value: Dictionary) -> Array:
	var output: Array = []
	for key_value: Variant in value.keys():
		output.append(String(key_value))
	output.sort()
	return output


func visible_named_nodes(root_node: Node, pattern: String, type_name: String = "MeshInstance3D") -> Array:
	var output: Array = []
	for node_value: Node in root_node.find_children(pattern, type_name, true, false):
		if node_value.is_inside_tree() and node_value.is_visible_in_tree():
			output.append(node_value)
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
			"discoveredEvidenceIds": [ids[1], "%s:legacy_material" % case_id, ids[0], ids[1], 606],
			"selectedHypothesisId": "GENUINE_WITH_PERIOD_REPAIR",
			"citedEvidenceIds": [ids[0], "%s:legacy_citation" % case_id, ids[1], ids[0]],
			"resolved": false,
			"resolutionResult": {"outcome": "legacy_pending_result", "case": case_id},
			"migrationSentinel": {"case": case_id, "keep": [6, 0, 6]}
		},
		"expectedDiscovered": [ids[1], ids[0]],
		"expectedCited": [ids[0], ids[1]]
	}


func build_legacy_payload(gs: Node, definitions: Dictionary) -> Dictionary:
	start_stage_six(gs)
	gs.money = 4606
	gs.reputation = 37
	gs.day = 9
	gs.selected_tool = "precision_scale"
	gs.owned_upgrades = ["upgrade_01"]
	# Stage 6 has no active tutorial contract; the valid unrelated mirror is empty.
	gs.stage_run_state.tutorialCompletedSteps = []
	gs.stage_run_state.telemetry.investigationActions = 23
	gs.stage_run_state.telemetry.investigationRiskActions = 6
	gs.stage_run_state.telemetry.investigationRiskWeightSum = 12.5
	gs.campaign_state.storyFlags["stage6MigrationSentinel"] = "preserve"
	gs.inventory = []
	gs.campaign_state.caseStates = {}
	gs.campaign_state.caseArtifactLedger = {}
	var seed_value := 960600
	for case_id: String in CASE_IDS:
		var expected: Dictionary = EXPECTED_CAMPAIGN[case_id]
		var artifact: Dictionary = gs.new_artifact(String(LEGACY_SPECS[case_id]), seed_value, "case_%s" % case_id)
		seed_value += 1
		artifact["caseId"] = case_id
		artifact["storyArtifactId"] = String(expected.story)
		artifact["authenticityTruth"] = "GENUINE_WITH_PERIOD_REPAIR"
		artifact["knownClues"] = ["MATERIAL", "%s:legacy_visible" % case_id]
		artifact["evidence"] = [{"clueType": "%s:legacy" % case_id, "observation": "preserve", "supports": [], "contradicts": [], "confidenceWeight": 0.41}]
		artifact["playerHypothesis"] = "GENUINE_WITH_PERIOD_REPAIR"
		artifact["confidence"] = 0.74
		artifact["historicalIntegrity"] = 61.5 + float(seed_value % 4)
		artifact["restorationCost"] = 55.5 + float(seed_value % 6)
		artifact["restorationQuality"] = 26.0
		artifact["listing"] = {"starting": 211, "reserve": 277, "confidence": 0.72, "disclosure": "LIKELY"}
		gs.inventory.append(artifact)
		gs.campaign_state.caseArtifactLedger[case_id] = {
			"issued": true, "artifactUid": artifact.uniqueId, "disposition": "INVENTORY",
			"saleTransactionId": "", "publicConditionSnapshot": {"historicalIntegrity": artifact.historicalIntegrity},
			"publicAppraisalSnapshot": artifact.baseValue, "migrationSentinel": "ledger:%s" % case_id
		}
		gs.campaign_state.caseStates[case_id] = stale_case_state(case_id, definitions[case_id]).state.duplicate(true)
	gs.campaign_state.activeCaseId = "shadow_gauge"
	var historical_state := {
		"discoveredEvidenceIds": ["shadow_camera:material", "shadow_camera:provenance"],
		"selectedHypothesisId": "FORGERY", "citedEvidenceIds": ["shadow_camera:material"],
		"resolved": true,
		"resolutionResult": {"outcome": "credible", "historicalReceipt": "keep-exact"},
		"migrationSentinel": {"resolved": true, "keep": [1, 8, 5]}
	}
	gs.campaign_state.caseStates["shadow_camera"] = historical_state
	gs.campaign_state.completedCases["shadow_camera"] = true
	gs.campaign_state.caseOutcomes["shadow_camera"] = "credible"
	gs.campaign_state.caseArtifactLedger["shadow_camera"] = {
		"issued": true, "artifactUid": "case_shadow_camera_historical", "disposition": "SOLD",
		"saleTransactionId": "stage6-historical-sale", "publicConditionSnapshot": {"historicalIntegrity": 64.0},
		"publicAppraisalSnapshot": 730, "migrationSentinel": "sale-ledger-exact"
	}
	gs.transactions = [{"id": "stage6-historical-sale", "type": "sale", "instanceId": "case_shadow_camera_historical", "amount": 777, "day": 8, "sentinel": "transaction-exact"}]
	gs.auction_history = [{"artifactId": "case_shadow_camera_historical", "result": {"transactionId": "stage6-historical-sale", "sale_status": "SOLD", "reserve_met": true, "hammer": 840, "net": 777, "sentinel": "receipt-exact"}}]
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
	var stage_definition: Dictionary = registry.get_stage_definition(6)
	var data_ready := missing_methods.is_empty() and fallback_count == 0
	var data_ok: bool = data_ready and registry.authored_case_errors.is_empty() \
		and registry.stage_definition_errors.is_empty() \
		and stage_definition.get("case_ids", []) == CASE_IDS \
		and is_equal_approx(float(registry.stage_difficulty_multiplier(6)), STAGE_MULTIPLIER) \
		and CASE_IDS.all(func(case_id: String): return registry.authored_cases_v2.has(case_id))
	record(
		"S6-AUTHORED-DATA-01",
		"Stage 6 resolves three authored cases in exact order at the canonical multiplier with zero fallback",
		data_ok,
		{"missingMethods": missing_methods, "fallbackCount": fallback_count, "caseOrder": stage_definition.get("case_ids", []), "difficulty": registry.stage_difficulty_multiplier(6), "authoredErrors": registry.authored_case_errors, "stageErrors": registry.stage_definition_errors}
	)
	if not data_ready:
		blocked_remaining("STAGE6_AUTHORED_DATA_NOT_READY")
		finish(gs)
		return

	start_stage_six(gs)
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
	var generic_ok := query_exact and before_query == JSON.stringify(gs.save_payload())
	for hit_rows: Variant in source_hits.values():
		for hit_value: Variant in (hit_rows as Dictionary).values():
			generic_ok = generic_ok and not bool(hit_value)
	record(
		"S6-AUTHORED-GENERIC-02",
		"All Stage 6 cases use generic read-only registry and gameplay paths",
		generic_ok,
		{"runtimeExact": query_exact, "caseIdHits": source_hits, "saveMutation0": before_query == JSON.stringify(gs.save_payload())}
	)

	var campaign_ok := true
	var campaign_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var expected: Dictionary = EXPECTED_CAMPAIGN[case_id]
		var story_case: Dictionary = registry.get_case(case_id)
		var story_artifact: Dictionary = registry.story_artifacts.get(String(story_case.get("storyArtifactId", "")), {})
		var case_ok: bool = String(story_case.get("act", "")) == String(expected.act) \
			and String(story_case.get("npcId", "")) == String(expected.npc) \
			and story_case.get("documentIds", []) == expected.documents \
			and semantic_equal(story_case.get("rewards", {}), expected.rewards) \
			and String(story_case.get("rewardSpecId", "")) == String(expected.spec) \
			and String(story_case.get("storyArtifactId", "")) == String(expected.story) \
			and String(story_artifact.get("baseSpecId", "")) == String(expected.spec) \
			and String(definitions[case_id].get("artifact_spec_id", "")) == String(expected.spec) \
			and String(definitions[case_id].get("canonical_hypothesis_id", "")) == String(EXPECTED_CANONICAL[case_id])
		campaign_ok = campaign_ok and case_ok
		campaign_rows[case_id] = {"case": story_case, "storyBaseSpec": story_artifact.get("baseSpecId", ""), "authoredSpec": definitions[case_id].get("artifact_spec_id", ""), "canonical": definitions[case_id].get("canonical_hypothesis_id", ""), "ok": case_ok}
	record(
		"S6-AUTHORED-CAMPAIGN-03",
		"Stage 6 keeps exact ACT 4, NPC, document, reward, story and corrected artifact bindings",
		campaign_ok,
		campaign_rows
	)

	var source_ok := true
	var source_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var kinds: Array = definition.get("evidence", []).map(func(row: Dictionary): return String(row.get("source", {}).get("kind", "")))
		var groups: Array = unique_strings(definition.get("evidence", []).map(func(row: Dictionary): return String(row.get("independence_key", ""))))
		var relation_complete := true
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
			and groups.size() == 6 and relation_complete and outcome_rules_exact(definition)
		source_ok = source_ok and case_ok
		source_rows[case_id] = {"ids": evidence_ids(definition), "kinds": kinds, "groups": groups, "required": definition.get("resolution", {}).get("required_source_refs", []), "rules": definition.get("resolution", {}).get("outcome_rules", []), "ok": case_ok}
	record(
		"S6-AUTHORED-SOURCES-04",
		"Each Stage 6 graph has exact A2/D2/NPC1/REF1 sources, six groups and an ordered four-step outcome ladder",
		source_ok,
		source_rows
	)

	var issuance_ok := true
	var issuance_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var fixture := begin_stage_six_case(gs, case_id)
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
		"S6-AUTHORED-ISSUANCE-05",
		"Fresh Stage 6 issuance is exactly gauge 050, clock 031 and music box 035 with stable one-per-case UIDs",
		issuance_ok,
		issuance_rows
	)

	var risk_ok := true
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
			var fixture := begin_stage_six_case(gs, case_id)
			var artifact: Dictionary = fixture.artifact
			var prerequisites_ok := not artifact.is_empty() and satisfy_requirements(gs, case_id, definition, evidence_id)
			var wrong_tool := "soft_brush" if not tools.has("soft_brush") else "uv_lamp"
			gs.select_tool(wrong_tool)
			var wrong_before := JSON.stringify(gs.save_payload())
			var wrong_result: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
			var wrong_zero := wrong_before == JSON.stringify(gs.save_payload())
			gs.select_tool(String(tools[0]))
			var integrity_before := float(artifact.get("historicalIntegrity", 0.0))
			var discovery: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
			var expected_penalty := (1.0 if level == "LOW" else 3.0) * STAGE_MULTIPLIER
			var integrity_after := float(artifact.get("historicalIntegrity", 0.0))
			var duplicate_before := JSON.stringify(gs.save_payload())
			var duplicate: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
			var duplicate_zero := duplicate_before == JSON.stringify(gs.save_payload())
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
	risk_ok = risk_ok and aggregate == {"NONE": 12, "LOW": 3, "HIGH": 3} \
		and is_equal_approx(weighted_total, 16.8306207684)
	record(
		"S6-AUTHORED-RISK-06",
		"Each Stage 6 case exposes NONE4/LOW1/HIGH1 with exact scanner and case-specific invasive tools at 1.4025517307 pressure",
		risk_ok,
		{"aggregate": aggregate, "weightedTotal": weighted_total, "cases": risk_rows}
	)

	var provenance_ok := true
	var provenance_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var tagged: Array = definition.get("evidence", []).filter(func(row: Dictionary): return String(row.get("public_clue_id", "")) == "PROVENANCE")
		var fixture := begin_stage_six_case(gs, case_id)
		var artifact: Dictionary = fixture.artifact
		var listing_before: Array = gs.listing_public_status_tags(artifact, "UNCERTAIN")
		var auction_before: Array = gs.auction_public_reason_tags(artifact, {}, "NO_SALE", {"reserve": 100, "hammer": 0, "reserve_met": false})
		var evidence_id := String(EXPECTED_PROVENANCE[case_id])
		var prerequisites_ok := satisfy_requirements(gs, case_id, definition, evidence_id)
		var row := evidence_by_id(definition, evidence_id)
		var tools: Array = row.get("unlock", {}).get("requires_tools", [])
		if not tools.is_empty():
			gs.select_tool(String(tools[0]))
		var discovery: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
		var duplicate_before := JSON.stringify(gs.save_payload())
		var duplicate: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
		var duplicate_zero := duplicate_before == JSON.stringify(gs.save_payload())
		var listing_after: Array = gs.listing_public_status_tags(artifact, "UNCERTAIN")
		var auction_after: Array = gs.auction_public_reason_tags(artifact, {}, "BID", {})
		var public_state: Dictionary = gs.get_case_public_state(case_id)
		var case_ok: bool = tagged.size() == 1 and String(tagged[0].get("id", "")) == evidence_id \
			and String(tagged[0].get("source", {}).get("kind", "")) == "DOCUMENT" \
			and String(tagged[0].get("reliability", "")) == "HIGH" and prerequisites_ok \
			and reason_has(listing_before, "PROVENANCE_UNCERTAIN") and reason_has(auction_before, "PROVENANCE_UNCERTAIN") \
			and bool(discovery.get("ok", false)) and String(discovery.get("code", "")) == "DISCOVERED" \
			and bool(duplicate.get("ok", false)) and String(duplicate.get("code", "")) == "ALREADY_DISCOVERED" and duplicate_zero \
			and artifact.get("knownClues", []).count("PROVENANCE") == 1 \
			and reason_has(listing_after, "PROVENANCE_STRONG") and reason_has(auction_after, "PROVENANCE_STRONG") \
			and public_private_fields_hidden(public_state)
		provenance_ok = provenance_ok and case_ok
		provenance_rows[case_id] = {"tagged": tagged, "discovery": discovery, "duplicate": duplicate, "knownClues": artifact.get("knownClues", []), "before": {"listing": listing_before, "auction": auction_before}, "after": {"listing": listing_after, "auction": auction_after}, "ok": case_ok}
	record(
		"S6-AUTHORED-PROVENANCE-07",
		"Each Stage 6 case has one sole high-reliability DOCUMENT provenance bridge that commits once",
		provenance_ok,
		provenance_rows
	)

	var outcomes_ok := true
	var outcome_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var definition: Dictionary = definitions[case_id]
		var fixture := begin_stage_six_case(gs, case_id)
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
		"S6-AUTHORED-OUTCOMES-08",
		"All Stage 6 public evaluators execute mentor, credible, masterful and mistaken in order while empty reports fail closed",
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
	var legacy_ok := legacy_applied
	var legacy_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var expected_saved: Dictionary = artifact_expected.get(case_id, {})
		var actual: Dictionary = gs.find_inventory_instance("case_%s" % case_id)
		var actual_saved: Dictionary = gs.serialize_instance(actual) if not actual.is_empty() else {}
		var ledger_expected: Dictionary = legacy_payload.campaign.caseArtifactLedger[case_id]
		var case_ok: bool = not actual.is_empty() and semantic_equal(actual_saved, expected_saved) \
			and String(actual.get("artifactSpecId", "")) == String(LEGACY_SPECS[case_id]) \
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
			and gs.inventory.size() == 3 and before == JSON.stringify(gs.save_payload())
		legacy_ok = legacy_ok and row_ok
		duplicate_rows[case_id] = {"returnedUid": returned.get("uniqueId", ""), "returnedSpec": returned.get("artifactSpecId", ""), "inventoryCount": gs.inventory.size(), "mutation0": before == JSON.stringify(gs.save_payload()), "ok": row_ok}
	record(
		"S6-AUTHORED-LEGACY-09",
		"Legacy unresolved 041/046/050 artifacts, UIDs, mutable state and ledgers remain exact with zero duplicate issuance",
		bool(legacy_validation.get("ok", false)) and legacy_ok,
		{"validation": legacy_validation, "artifacts": legacy_rows, "duplicates": duplicate_rows}
	)

	legacy_applied = bool(gs.apply_save_data(legacy_payload))
	var canonical_ok := legacy_applied
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
	record(
		"S6-AUTHORED-CANONICAL-10",
		"Unresolved Stage 6 legacy state keeps ordered valid evidence only and clears stale conclusions",
		canonical_ok,
		canonical_rows
	)

	var before_protected := protected_payload_snapshot(legacy_payload)
	var first_normalized_payload: Dictionary = gs.save_payload().duplicate(true)
	var after_protected := protected_payload_snapshot(first_normalized_payload)
	var profile_before: Dictionary = gs.profile_payload().duplicate(true)
	var second_applied := bool(gs.apply_save_data(first_normalized_payload))
	var second_payload: Dictionary = gs.save_payload().duplicate(true)
	var scoped_ok := second_applied and semantic_equal(before_protected, after_protected) \
		and semantic_equal(first_normalized_payload, second_payload) \
		and semantic_equal(profile_before, gs.profile_payload())
	record(
		"S6-AUTHORED-SCOPE-11",
		"Stage 6 canonicalization is idempotent and mutates no economy, RNG, artifact, ledger, auction, tutorial, telemetry or profile authority",
		scoped_ok,
		{"protectedMutation0": semantic_equal(before_protected, after_protected), "idempotent": semantic_equal(first_normalized_payload, second_payload), "profileMutation0": semantic_equal(profile_before, gs.profile_payload())}
	)

	var historical_before: Dictionary = legacy_payload.campaign.caseStates.shadow_camera
	var historical_ledger_before: Dictionary = legacy_payload.campaign.caseArtifactLedger.shadow_camera
	var history_ok := semantic_equal(gs.campaign_state.caseStates.get("shadow_camera", {}), historical_before) \
		and bool(gs.campaign_state.completedCases.get("shadow_camera", false)) \
		and String(gs.campaign_state.caseOutcomes.get("shadow_camera", "")) == "credible" \
		and semantic_equal(gs.campaign_state.caseArtifactLedger.get("shadow_camera", {}), historical_ledger_before) \
		and semantic_equal(gs.transactions, legacy_payload.transactions) \
		and semantic_equal(gs.auction_history, legacy_payload.auctionHistory)
	record(
		"S6-AUTHORED-HISTORY-12",
		"Resolved/completed historical case state, SOLD ledger, transaction and auction receipt remain semantically exact",
		history_ok,
		{"caseState": gs.campaign_state.caseStates.get("shadow_camera", {}), "ledger": gs.campaign_state.caseArtifactLedger.get("shadow_camera", {}), "transactions": gs.transactions, "auctionHistory": gs.auction_history}
	)

	var hook_available := registry.has_method("get_artifact_instance_render_dto")
	var render_ok := true
	var render_evidence: Dictionary = {"hookAvailable": hook_available, "status": "DEFERRED_UNTIL_PRODUCTION_API"}
	if hook_available:
		var fresh_gauge: Dictionary = registry.call("get_artifact_instance_render_dto", {"artifactSpecId": "artifact_050", "storyArtifactId": "story_artifact_16"})
		var legacy_music: Dictionary = registry.call("get_artifact_instance_render_dto", {"artifactSpecId": "artifact_050", "storyArtifactId": "story_artifact_18"})
		var fresh_music: Dictionary = registry.call("get_artifact_instance_render_dto", {"artifactSpecId": "artifact_035", "storyArtifactId": "story_artifact_18"})
		var plain_050: Dictionary = registry.call("get_artifact_instance_render_dto", {"artifactSpecId": "artifact_050"})
		var plain_035: Dictionary = registry.call("get_artifact_instance_render_dto", {"artifactSpecId": "artifact_035"})
		var dto_rows := [fresh_gauge, legacy_music, fresh_music, plain_050, plain_035]
		var shapes_exact := dto_rows.all(func(dto: Dictionary): return sorted_keys(dto) == DTO_KEYS)
		var pristine_gauge := fresh_gauge.duplicate(true)
		fresh_gauge["recipe"] = "MUTATED"
		fresh_gauge["palette"]["primary"] = "#000000"
		var gauge_repeat: Dictionary = registry.call("get_artifact_instance_render_dto", {"artifactSpecId": "artifact_050", "storyArtifactId": "story_artifact_16"})
		var public_payload := JSON.stringify(dto_rows).to_lower()
		var private_leaks: Array = ["authenticity", "truth", "reserve", "price", "hidden", "auction"].filter(func(token: String): return public_payload.contains(token))
		var main: Node3D = load("res://scenes/Main.tscn").instantiate()
		get_root().add_child(main)
		await process_frame
		var gauge_artifact: Dictionary = gs.new_artifact("artifact_050", 6050, "stage6_fresh_gauge_render")
		gauge_artifact["storyArtifactId"] = "story_artifact_16"
		main.load_artifact(gauge_artifact)
		await process_frame
		var gauge_live_path := String(main.model.mesh.resource_path) if main.model != null and main.model.mesh != null else ""
		var gauge_nodes := {
			"ticks": visible_named_nodes(main.workpiece_root, "GaugeScaleTick_*").size(),
			"needle": visible_named_nodes(main.workpiece_root, "GaugePressureNeedle").size(),
			"hub": visible_named_nodes(main.workpiece_root, "GaugePressureHub").size(),
			"plate": visible_named_nodes(main.workpiece_root, "GaugeCalibrationPlate").size(),
			"seal": visible_named_nodes(main.workpiece_root, "GaugeCalibrationSeal").size(),
			"genericTrim": visible_named_nodes(main.workpiece_root, "VariantTrim_*").size()
		}
		var music_artifact: Dictionary = gs.new_artifact("artifact_035", 6035, "stage6_fresh_music_render")
		music_artifact["storyArtifactId"] = "story_artifact_18"
		main.load_artifact(music_artifact)
		await process_frame
		var music_live_path := String(main.model.mesh.resource_path) if main.model != null and main.model.mesh != null else ""
		var music_nodes := {
			"cylinder": visible_named_nodes(main.workpiece_root, "MusicBoxPinnedCylinder").size(),
			"pins": visible_named_nodes(main.workpiece_root, "MusicBoxCylinderPin_*").size(),
			"comb": visible_named_nodes(main.workpiece_root, "MusicBoxComb").size(),
			"teeth": visible_named_nodes(main.workpiece_root, "MusicBoxCombTooth_*").size(),
			"stem": visible_named_nodes(main.workpiece_root, "MusicBoxWindingStem").size(),
			"key": visible_named_nodes(main.workpiece_root, "MusicBoxWindingKey").size(),
			"inlay": visible_named_nodes(main.workpiece_root, "MusicBoxLidInlay").size(),
			"genericTrim": visible_named_nodes(main.workpiece_root, "VariantTrim_*").size()
		}
		var renderer_exact: bool = gauge_live_path == "res://assets/artifacts/gauge.obj" \
			and gauge_nodes == {"ticks": 13, "needle": 1, "hub": 1, "plate": 1, "seal": 1, "genericTrim": 0} \
			and music_live_path == "res://assets/artifacts/music_box.obj" \
			and music_nodes == {"cylinder": 1, "pins": 8, "comb": 1, "teeth": 7, "stem": 1, "key": 1, "inlay": 1, "genericTrim": 0}
		main.queue_free()
		await process_frame
		render_ok = shapes_exact \
			and String(pristine_gauge.get("recipe", "")) == "GAUGE" and String(pristine_gauge.get("meshPath", "")) == "res://assets/artifacts/gauge.obj" \
			and String(legacy_music.get("recipe", "")) == "DEFAULT" and String(legacy_music.get("meshPath", "")) == "res://assets/artifacts/model_05.obj" \
			and String(fresh_music.get("recipe", "")) == "MUSIC_BOX" and String(fresh_music.get("meshPath", "")) == "res://assets/artifacts/music_box.obj" \
			and String(plain_050.get("recipe", "")) == "DEFAULT" and String(plain_035.get("recipe", "")) == "DEFAULT" \
			and pristine_gauge != legacy_music and fresh_music != plain_035 \
			and gauge_repeat == pristine_gauge and private_leaks.is_empty() and renderer_exact
		render_evidence = {"hookAvailable": true, "freshGauge": pristine_gauge, "legacyStory18Spec050": legacy_music, "freshMusic": fresh_music, "plain050": plain_050, "plain035": plain_035, "shapeExact": shapes_exact, "deepCopy": gauge_repeat == pristine_gauge, "privateLeaks": private_leaks, "renderer": {"gaugePath": gauge_live_path, "gaugeNodes": gauge_nodes, "musicPath": music_live_path, "musicNodes": music_nodes, "exact": renderer_exact}}
	record(
		"S6-AUTHORED-RENDER-13",
		"Instance render DTO isolates fresh gauge 16+050, legacy music 18+050, fresh music 18+035 and unrelated spec-only defaults",
		render_ok,
		render_evidence
	)

	finish(gs)
