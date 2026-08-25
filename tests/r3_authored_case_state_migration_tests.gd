extends SceneTree

## Generic save-compatibility contract for cases that gain authored-v2 evidence
## after an unresolved fallback case state has already been persisted.

const EXPECTED_TEST_COUNT := 5
const REPORT_PATH := "res://qa/R3_AUTHORED_CASE_STATE_MIGRATION_TESTS.json"
const LOG_PATH := "res://qa/R3_AUTHORED_CASE_STATE_MIGRATION_TESTS.log"
const FIXTURE_PATH := "user://r3_authored_case_state_migration_fixture.json"
const NORMALIZED_PATH := "user://r3_authored_case_state_migration_normalized.json"
const TARGETS := {
	"mislabelled_collection": {
		"spec": "artifact_018",
		"story": "story_artifact_11",
		"legacy_hypothesis": "GENUINE",
		"canonical": "hyp.mislabelled_collection.genuine_projector_swapped_accession_label"
	},
	"observatory_instrument": {
		"spec": "artifact_011",
		"story": "story_artifact_12",
		"legacy_hypothesis": "GENUINE_WITH_PERIOD_REPAIR",
		"canonical": "hyp.observatory_instrument.genuine_period_pivot_repair"
	}
}
const REAL_AUTHORED_CASE := "garage_lamp"

var results: Array = []
var injected_case_ids: Array = []
var registry: Node


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


func localized(text: String) -> Dictionary:
	return {"en": text, "ko": text}


func projected_definition(case_id: String, spec_id: String, canonical: String) -> Dictionary:
	var hypotheses: Array = [
		{"id": "%s.option_a" % case_id, "label": localized("Option A")},
		{"id": canonical, "label": localized("Canonical option")},
		{"id": "%s.option_c" % case_id, "label": localized("Option C")}
	]
	var evidence: Array = []
	for index: int in range(4):
		var evidence_id := "src.%s.fixture_%d" % [case_id, index + 1]
		evidence.append({
			"id": evidence_id,
			"source": {"kind": "ARTIFACT", "ref_id": spec_id, "entry_id": evidence_id},
			"text": localized("Projected authored evidence %d" % (index + 1)),
			"public_clue_id": "",
			"discover_action_id": "inspect",
			"unlock": {"requires_all": [], "requires_tools": []},
			"risk": {"level": "NONE", "warning": localized("")},
			"reliability": "HIGH",
			"independence_key": "fixture_group_%d" % (index + 1),
			"relations": [
				{"hypothesis_id": canonical, "stance": "SUPPORT", "strength": 2},
				{"hypothesis_id": "%s.option_a" % case_id, "stance": "REFUTE", "strength": 1},
				{"hypothesis_id": "%s.option_c" % case_id, "stance": "REFUTE", "strength": 1}
			],
			"citation": {"allowed": true, "id": "cite.%s.fixture_%d" % [case_id, index + 1], "label": localized("Fixture citation %d" % (index + 1))},
			"presentation": {
				"source_display_name": localized("Fixture source %d" % (index + 1)),
				"unlock_action_label": localized("Inspect"),
				"unlock_target_label": localized("the fixture"),
				"short_observation": localized("Projected authored evidence %d" % (index + 1)),
				"citation_locator": localized("Fixture locator %d" % (index + 1)),
				"npc_portrait": {}
			}
		})
	return {
		"schema_version": 2,
		"case_id": case_id,
		"title": localized(case_id),
		"artifact_spec_id": spec_id,
		"artifact_display_name": localized(case_id),
		"presentation": {"artifact_display_name": localized(case_id)},
		"briefing": localized("Projected authored fixture"),
		"central_question": localized("Which option is supported?"),
		"fiction_notice": localized("Fictional fixture"),
		"success": localized("Accepted"),
		"failure": localized("Reviewed"),
		"hypotheses": hypotheses,
		"canonical_hypothesis_id": canonical,
		"evidence": evidence,
		"resolution": {
			"strong_min_independent_support": 4,
			"strong_min_net_score": 4,
			"strong_min_citations": 4,
			"required_source_refs": [],
			"plausible_min_independent_support": 1,
			"plausible_min_net_score": 1,
			"plausible_min_citations": 1,
			"report_prompt": localized("Cite the evidence."),
			"outcome_rules": [
				{"outcome_id": "masterful", "correctness": "CORRECT", "requires_all_required_sources": false, "minimum_independent_groups": 4, "minimum_citations": 4, "minimum_net_support": 4, "fallback": false},
				{"outcome_id": "credible", "correctness": "CORRECT", "requires_all_required_sources": false, "minimum_independent_groups": 1, "minimum_citations": 1, "minimum_net_support": 1, "fallback": false},
				{"outcome_id": "mistaken", "correctness": "INCORRECT", "requires_all_required_sources": false, "minimum_independent_groups": 0, "minimum_citations": 1, "minimum_net_support": 0, "fallback": false},
				{"outcome_id": "reviewed_with_mentor", "correctness": "ANY", "requires_all_required_sources": false, "minimum_independent_groups": 0, "minimum_citations": 0, "minimum_net_support": 0, "fallback": true}
			]
		}
	}


func install_projected_definitions() -> void:
	for case_id: String in TARGETS.keys():
		if registry.has_authored_case_v2(case_id):
			continue
		var target: Dictionary = TARGETS[case_id]
		registry.authored_cases_v2[case_id] = projected_definition(case_id, String(target.spec), String(target.canonical))
		injected_case_ids.append(case_id)


func remove_projected_definitions() -> void:
	if registry == null:
		return
	for case_id: String in injected_case_ids:
		registry.authored_cases_v2.erase(case_id)
	injected_case_ids.clear()


func evidence_ids(definition: Dictionary) -> Array:
	var ids: Array = []
	for evidence_value: Variant in definition.get("evidence", []):
		if evidence_value is Dictionary:
			var evidence_id := String((evidence_value as Dictionary).get("id", ""))
			if not evidence_id.is_empty():
				ids.append(evidence_id)
	return ids


func stale_case_state(case_id: String, definition: Dictionary, legacy_hypothesis: String, marker: String) -> Dictionary:
	var ids := evidence_ids(definition)
	return {
		"state": {
			"discoveredEvidenceIds": [
				"%s:material" % case_id,
				ids[1],
				ids[0],
				ids[1],
				1978,
				"%s:repair_trace" % case_id
			],
			"selectedHypothesisId": legacy_hypothesis,
			"citedEvidenceIds": [
				"%s:material" % case_id,
				ids[0],
				ids[2],
				ids[1],
				ids[0]
			],
			"resolved": false,
			"resolutionResult": {"outcome": "stale_fallback_result", "marker": marker},
			"migrationSentinel": {"marker": marker, "keep": [3, 1, 4]}
		},
		"expectedDiscovered": [ids[1], ids[0]],
		"expectedCited": [ids[0], ids[1]],
		"sentinel": {"marker": marker, "keep": [3, 1, 4]}
	}


func add_case_artifact(gs: Node, case_id: String, spec_id: String, story_id: String, legacy_truth: String, seed_value: int) -> Dictionary:
	var artifact: Dictionary = gs.new_artifact(spec_id, seed_value, "case_%s" % case_id)
	artifact["caseId"] = case_id
	artifact["storyArtifactId"] = story_id
	artifact["authenticityTruth"] = legacy_truth
	artifact["knownClues"] = ["PROVENANCE", "MATERIAL", "%s:legacy_visible" % case_id]
	artifact["evidence"] = [{"clueType": "%s:legacy" % case_id, "observation": "preserve", "supports": [], "contradicts": [], "confidenceWeight": 0.37}]
	artifact["playerHypothesis"] = legacy_truth
	artifact["confidence"] = 0.73
	artifact["historicalIntegrity"] = 61.25 + float(seed_value % 5)
	artifact["restorationCost"] = 47.5 + float(seed_value % 7)
	artifact["restorationQuality"] = 26.0
	artifact["listing"] = {"starting": 177, "reserve": 244, "confidence": 0.71, "disclosure": "LIKELY"}
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


func protected_snapshot(gs: Node) -> Dictionary:
	var payload: Dictionary = gs.save_payload()
	var campaign: Dictionary = payload.get("campaign", {}).duplicate(true)
	campaign.erase("caseStates")
	payload["campaign"] = campaign
	return {
		"runWithoutCaseStates": payload,
		"profile": gs.profile_payload(),
		"rngState": int(gs.rng.state)
	}


func json_semantically_equal(left: Variant, right: Variant) -> bool:
	# Godot's JSON parser represents persisted numbers as floats. Compare the two
	# values after the same real save boundary so numeric representation alone
	# cannot masquerade as a gameplay mutation.
	var normalized_left: Variant = JSON.parse_string(JSON.stringify(left))
	var normalized_right: Variant = JSON.parse_string(JSON.stringify(right))
	return normalized_left == normalized_right


func first_root_evidence(definition: Dictionary) -> Dictionary:
	for evidence_value: Variant in definition.get("evidence", []):
		if not evidence_value is Dictionary:
			continue
		var evidence: Dictionary = evidence_value
		if (evidence.get("unlock", {}).get("requires_all", []) as Array).is_empty():
			return evidence
	return {}


func finish(gs: Node) -> void:
	remove_projected_definitions()
	gs.persistence_enabled = false
	var passed: int = results.filter(func(row: Dictionary): return bool(row.get("passed", false))).size()
	var report := {
		"suite": "R3 Authored Case State Migration",
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
	var log_lines: Array = [
		"suite=R3 Authored Case State Migration",
		"executed=%d" % results.size(),
		"passed=%d" % passed,
		"failed=%d" % (results.size() - passed),
		"skipped=0"
	]
	for result_value: Variant in results:
		var result: Dictionary = result_value
		log_lines.append("%s=%s" % [String(result.get("id", "")), "PASS" if bool(result.get("passed", false)) else "FAIL"])
	var log_output := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if log_output != null:
		log_output.store_string("\n".join(log_lines) + "\n")
		log_output.close()
	print(JSON.stringify(report))
	quit(0 if passed == EXPECTED_TEST_COUNT and results.size() == EXPECTED_TEST_COUNT else 1)


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	registry = get_root().get_node("RuntimeRegistry")
	install_projected_definitions()
	gs.persistence_enabled = false
	gs.reset_game()
	gs.campaign_test_mode = true
	gs.money = 2468
	gs.reputation = 37
	gs.day = 6
	gs.selected_tool = "precision_scale"
	gs.owned_upgrades = ["upgrade_01"]
	gs.campaign_state.storyFlags["migrationSentinel"] = "campaign-preserve"
	gs.stage_run_state.tutorialCompletedSteps = ["INVESTIGATE", "CITE"]

	var expected_states := {}
	var target_artifacts := {}
	var seed_value := 940100
	for case_id: String in TARGETS.keys():
		var target: Dictionary = TARGETS[case_id]
		var definition: Dictionary = registry.get_case_v2(case_id)
		var fixture := stale_case_state(case_id, definition, String(target.legacy_hypothesis), "target:%s" % case_id)
		expected_states[case_id] = fixture
		gs.campaign_state.caseStates[case_id] = fixture.state.duplicate(true)
		target_artifacts[case_id] = add_case_artifact(gs, case_id, String(target.spec), String(target.story), String(target.legacy_hypothesis), seed_value)
		seed_value += 1

	var real_definition: Dictionary = registry.get_case_v2(REAL_AUTHORED_CASE)
	var real_fixture := stale_case_state(REAL_AUTHORED_CASE, real_definition, "GENUINE_WITH_PERIOD_REPAIR", "real-authored")
	expected_states[REAL_AUTHORED_CASE] = real_fixture
	gs.campaign_state.caseStates[REAL_AUTHORED_CASE] = real_fixture.state.duplicate(true)

	var resolved_case := "early_camera"
	var resolved_historical_state := {
		"discoveredEvidenceIds": ["early_camera:material", "early_camera:provenance"],
		"selectedHypothesisId": "FORGERY",
		"citedEvidenceIds": ["early_camera:material"],
		"resolved": true,
		"resolutionResult": {"outcome": "masterful", "historicalReceipt": "keep-exact"},
		"migrationSentinel": {"resolved": true, "keep": [9, 2, 6]}
	}
	gs.campaign_state.caseStates[resolved_case] = resolved_historical_state.duplicate(true)
	gs.campaign_state.activeCaseId = "mislabelled_collection"

	var before_protected := protected_snapshot(gs)
	gs.persistence_enabled = true
	var saved: bool = bool(gs.save_game(FIXTURE_PATH))
	var loaded: bool = saved and bool(gs.load_game(FIXTURE_PATH))
	gs.persistence_enabled = false

	var membership_ok: bool = loaded
	var membership_rows := {}
	for case_id: String in expected_states.keys():
		var expected: Dictionary = expected_states[case_id]
		var actual: Dictionary = gs.campaign_state.caseStates.get(case_id, {})
		var case_ok: bool = actual.get("discoveredEvidenceIds", []) == expected.expectedDiscovered \
			and actual.get("citedEvidenceIds", []) == expected.expectedCited \
			and String(actual.get("selectedHypothesisId", "invalid")) == "" \
			and actual.get("resolutionResult", {"invalid": true}).is_empty() \
			and json_semantically_equal(actual.get("migrationSentinel", {}), expected.sentinel)
		membership_ok = membership_ok and case_ok
		membership_rows[case_id] = {"actual": actual, "expectedDiscovered": expected.expectedDiscovered, "expectedCited": expected.expectedCited, "ok": case_ok}
	record(
		"AUTHORED-STATE-MIGRATION-01",
		"Unresolved authored states retain only current ordered unique evidence membership and clear invalid hypothesis/result fields",
		membership_ok,
		{"saved": saved, "loaded": loaded, "cases": membership_rows, "injectedCases": injected_case_ids.duplicate()}
	)

	var resolved_after: Dictionary = gs.campaign_state.caseStates.get(resolved_case, {})
	record(
		"AUTHORED-STATE-MIGRATION-02",
		"Resolved authored case history remains exact even when it uses pre-authored identifiers",
		json_semantically_equal(resolved_after, resolved_historical_state),
		{"before": resolved_historical_state, "after": resolved_after}
	)

	var after_protected := protected_snapshot(gs)
	var artifact_rows := {}
	var artifact_exact := true
	for case_id: String in TARGETS.keys():
		var before_artifact: Dictionary = target_artifacts[case_id]
		var after_artifact: Dictionary = gs.find_inventory_instance("case_%s" % case_id)
		var row_ok: bool = not after_artifact.is_empty() \
			and String(after_artifact.get("artifactSpecId", "")) == String(before_artifact.get("artifactSpecId", "")) \
			and String(after_artifact.get("uniqueId", "")) == String(before_artifact.get("uniqueId", "")) \
			and int(after_artifact.get("seed", -1)) == int(before_artifact.get("seed", -2)) \
			and after_artifact.get("knownClues", []) == before_artifact.get("knownClues", []) \
			and json_semantically_equal(after_artifact.get("listing", {}), before_artifact.get("listing", {})) \
			and is_equal_approx(float(after_artifact.get("restorationCost", -1.0)), float(before_artifact.get("restorationCost", -2.0))) \
			and json_semantically_equal(after_artifact, before_artifact)
		artifact_exact = artifact_exact and row_ok
		artifact_rows[case_id] = {"before": before_artifact, "after": after_artifact, "ok": row_ok}
	record(
		"AUTHORED-STATE-MIGRATION-03",
		"Canonicalization preserves artifacts, identity, ledger, economy, RNG, public clues, repair, auction, tutorial, telemetry and schema state",
		json_semantically_equal(before_protected, after_protected) and artifact_exact,
		{"protectedExact": json_semantically_equal(before_protected, after_protected), "artifacts": artifact_rows, "beforeRng": before_protected.rngState, "afterRng": after_protected.rngState}
	)

	gs.persistence_enabled = true
	var normalized_before: Dictionary = gs.save_payload()
	var normalized_saved: bool = bool(gs.save_game(NORMALIZED_PATH))
	var reload_one: bool = normalized_saved and bool(gs.load_game(NORMALIZED_PATH))
	var normalized_after_one: Dictionary = gs.save_payload()
	var reload_two: bool = reload_one and bool(gs.load_game(NORMALIZED_PATH))
	var normalized_after_two: Dictionary = gs.save_payload()
	gs.persistence_enabled = false
	record(
		"AUTHORED-STATE-MIGRATION-04",
		"The normalized authored state is idempotent across repeated save and reload",
		normalized_saved and reload_one and reload_two and normalized_before == normalized_after_one and normalized_after_one == normalized_after_two,
		{"saved": normalized_saved, "reloadOne": reload_one, "reloadTwo": reload_two, "firstExact": normalized_before == normalized_after_one, "secondExact": normalized_after_one == normalized_after_two}
	)

	var playable_ok := true
	var playable_rows := {}
	for case_id: String in TARGETS.keys():
		var definition: Dictionary = registry.get_case_v2(case_id)
		var state: Dictionary = gs.campaign_state.caseStates[case_id]
		state.discoveredEvidenceIds = []
		state.citedEvidenceIds = []
		state.selectedHypothesisId = ""
		state.resolutionResult = {}
		gs.campaign_state.activeCaseId = case_id
		var root_evidence := first_root_evidence(definition)
		var required_tools: Array = root_evidence.get("unlock", {}).get("requires_tools", [])
		if not required_tools.is_empty():
			gs.select_tool(String(required_tools[0]))
		var hypothesis_set: bool = bool(gs.set_case_hypothesis(case_id, String(definition.get("canonical_hypothesis_id", ""))))
		var discovery: Dictionary = gs.discover_case_evidence(case_id, String(root_evidence.get("id", "")))
		var citation_set: bool = bool(gs.toggle_case_citation(case_id, String(root_evidence.get("id", ""))))
		var public_state: Dictionary = gs.get_case_public_state(case_id)
		var resolution: Dictionary = gs.resolve_case_v2(case_id, String(public_state.get("selectedHypothesisId", "")), public_state.get("citedEvidenceIds", []))
		var case_ok: bool = not root_evidence.is_empty() and hypothesis_set \
			and bool(discovery.get("ok", false)) and citation_set \
			and public_state.get("citedEvidenceIds", []) == [root_evidence.get("id", "")] \
			and bool(resolution.get("ok", false)) and String(resolution.get("code", "")) != "CROSS_CASE_EVIDENCE"
		playable_ok = playable_ok and case_ok
		playable_rows[case_id] = {"rootEvidence": root_evidence.get("id", ""), "hypothesisSet": hypothesis_set, "discovery": discovery, "citationSet": citation_set, "publicCitations": public_state.get("citedEvidenceIds", []), "resolution": resolution, "ok": case_ok}
	record(
		"AUTHORED-STATE-MIGRATION-05",
		"Both projected Stage 4 legacy cases can rediscover, cite and resolve after canonicalization without CROSS_CASE_EVIDENCE",
		playable_ok,
		playable_rows
	)

	finish(gs)
