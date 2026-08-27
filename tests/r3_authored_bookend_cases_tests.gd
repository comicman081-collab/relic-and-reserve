extends SceneTree

## Runtime contract for the four authored-v2 definitions that close the
## Stage 1 and Stage 10 gaps. This suite deliberately exercises public case
## APIs instead of treating schema validation as proof of playable content.

const REPORT_PATH := "res://qa/R3_AUTHORED_BOOKEND_CASES_TESTS.json"
const CASE_IDS := ["silent_radio", "perfect_fake", "master_camera", "master_mechanism"]
const EXPECTED := {
	"silent_radio": {
		"stage": 1,
		"spec": "artifact_004",
		"story": "story_artifact_02",
		"truth": "hyp.silent_radio.genuine_with_period_condenser_repair",
		"risk": {"NONE": 5, "LOW": 0, "HIGH": 1},
		"risk_by_id": {
			"src.silent_radio.artifact.serial_oxidation": "NONE",
			"src.silent_radio.artifact.condenser_service_seam": "HIGH"
		}
	},
	"perfect_fake": {
		"stage": 1,
		"spec": "artifact_003",
		"story": "story_artifact_03",
		"truth": "hyp.perfect_fake.genuine_with_modern_conservation_repair",
		"risk": {"NONE": 5, "LOW": 0, "HIGH": 1},
		"risk_by_id": {
			"src.perfect_fake.artifact.casting_serial_continuity": "NONE",
			"src.perfect_fake.artifact.bellows_repair_boundary": "HIGH"
		}
	},
	"master_camera": {
		"stage": 10,
		"spec": "artifact_079",
		"story": "story_artifact_25",
		"truth": "hyp.master_camera.genuine_with_period_clamp_service",
		"risk": {"NONE": 4, "LOW": 1, "HIGH": 1}
	},
	"master_mechanism": {
		"stage": 10,
		"spec": "artifact_080",
		"story": "story_artifact_26",
		"truth": "hyp.master_mechanism.genuine_observatory_regulator",
		"risk": {"NONE": 4, "LOW": 1, "HIGH": 1}
	}
}

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(test_id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": test_id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func start_case_stage(gs: Node, case_id: String) -> Dictionary:
	var stage_id := int(EXPECTED[case_id].stage)
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	gs.player_profile = gs.default_player_profile()
	gs.player_profile.highestUnlockedStage = stage_id
	var started: Dictionary = gs.new_game(stage_id)
	gs.campaign_test_mode = true
	var prerequisite_ok := true
	if stage_id == 1:
		prerequisite_ok = bool(gs.prepare_case_for_test("prologue_clock"))
	started["prerequisiteOk"] = prerequisite_ok
	return started


func discover_all(gs: Node, case_id: String) -> Dictionary:
	var discovered: Array = []
	var wrong_tool_zero := true
	var tool_gate_attempts := 0
	for _pass in range(16):
		var progressed := false
		for row_value: Variant in gs.get_case_public_state(case_id).get("evidence", []):
			if not row_value is Dictionary:
				continue
			var row: Dictionary = row_value
			if bool(row.get("discovered", false)) or not bool(row.get("unlocked", false)):
				continue
			var required: Array = row.get("requiredTools", [])
			if not required.is_empty():
				gs.select_tool("soft_brush")
				var before := JSON.stringify(gs.save_payload())
				var blocked: Dictionary = gs.discover_case_evidence(case_id, String(row.get("id", "")))
				wrong_tool_zero = wrong_tool_zero and String(blocked.get("code", "")) == "TOOL_REQUIRED" and before == JSON.stringify(gs.save_payload())
				tool_gate_attempts += 1
				gs.select_tool(String(required[0]))
			var result: Dictionary = gs.discover_case_evidence(case_id, String(row.get("id", "")))
			if bool(result.get("ok", false)):
				discovered.append(String(row.get("id", "")))
				progressed = true
		if not progressed:
			break
	return {"ids": discovered, "wrongToolZero": wrong_tool_zero, "toolGateAttempts": tool_gate_attempts}


func finish(gs: Node) -> void:
	var passed := results.filter(func(row: Dictionary): return bool(row.get("passed", false))).size()
	var report := {
		"suite": "R3 Authored Bookend Cases",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"expectedCount": 6,
		"tests": results
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify(report))
	gs.persistence_enabled = false
	quit(0 if passed == 6 and results.size() == 6 else 1)


func run() -> void:
	var registry: Node = get_root().get_node("RuntimeRegistry")
	var gs: Node = get_root().get_node("GameState")
	gs.persistence_enabled = false

	var all_campaign_cases_authored: bool = registry.authored_cases_v2.size() == registry.campaign_cases.size()
	for campaign_case_id: String in registry.campaign_cases.keys():
		all_campaign_cases_authored = all_campaign_cases_authored and registry.authored_cases_v2.has(campaign_case_id)
	var topology_ok: bool = all_campaign_cases_authored
	var topology_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var expected: Dictionary = EXPECTED[case_id]
		var definition: Dictionary = registry.get_case_v2(case_id)
		var story_case: Dictionary = registry.get_case(case_id)
		var evidence: Array = definition.get("evidence", [])
		var kinds: Array = evidence.map(func(row: Dictionary): return String(row.get("source", {}).get("kind", "")))
		var risk_counts := {"NONE": 0, "LOW": 0, "HIGH": 0}
		for row: Dictionary in evidence:
			var risk := String(row.get("risk", {}).get("level", "NONE"))
			risk_counts[risk] = int(risk_counts.get(risk, 0)) + 1
		var risk_by_id_ok := true
		for evidence_id: String in expected.get("risk_by_id", {}).keys():
			var matching: Array = evidence.filter(func(row: Dictionary): return String(row.get("id", "")) == evidence_id)
			risk_by_id_ok = risk_by_id_ok and matching.size() == 1 \
				and String(matching[0].get("risk", {}).get("level", "NONE")) == String(expected.risk_by_id[evidence_id])
		var provenance: Array = evidence.filter(func(row: Dictionary): return String(row.get("public_clue_id", "")) == "PROVENANCE")
		var outcomes: Array = definition.get("resolution", {}).get("outcome_rules", []).map(func(row: Dictionary): return String(row.get("outcome_id", "")))
		var row_ok: bool = not definition.is_empty() \
			and String(story_case.get("rewardSpecId", "")) == String(expected.spec) \
			and String(story_case.get("storyArtifactId", "")) == String(expected.story) \
			and String(definition.get("artifact_spec_id", "")) == String(expected.spec) \
			and String(definition.get("canonical_hypothesis_id", "")) == String(expected.truth) \
			and definition.get("hypotheses", []).size() == 3 and evidence.size() == 6 \
			and kinds.count("ARTIFACT") == 2 and kinds.count("DOCUMENT") == 2 and kinds.count("NPC") == 1 and kinds.count("REFERENCE") == 1 \
			and risk_counts == expected.risk and risk_by_id_ok \
			and provenance.size() == 1 and String(provenance[0].get("source", {}).get("kind", "")) == "DOCUMENT" \
			and definition.get("resolution", {}).get("required_source_refs", []).size() == 4 \
			and outcomes == ["masterful", "credible", "mistaken", "reviewed_with_mentor"]
		topology_ok = topology_ok and row_ok
		topology_rows[case_id] = {"evidence": evidence.size(), "kinds": kinds, "risk": risk_counts, "riskByIdOk": risk_by_id_ok, "provenance": provenance.size(), "outcomes": outcomes, "ok": row_ok}
	record("BOOKEND-DATA-01", "Every campaign case is authored-v2 and the four bookends preserve exact stage-calibrated six-source risk topology", topology_ok, {"authored": registry.authored_cases_v2.size(), "campaign": registry.campaign_cases.size(), "cases": topology_rows})

	var issuance_ok := true
	var issuance_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var expected: Dictionary = EXPECTED[case_id]
		var started := start_case_stage(gs, case_id)
		var artifact: Dictionary = gs.begin_case(case_id)
		var repeated: Dictionary = gs.begin_case(case_id)
		var uid := "case_%s" % case_id
		var case_inventory_count: int = gs.inventory.filter(func(row: Variant): return row is Dictionary and String(row.get("uniqueId", "")) == uid).size()
		var row_ok: bool = bool(started.get("ok", false)) and bool(started.get("prerequisiteOk", false)) \
			and is_equal_approx(float(started.get("difficultyMultiplier", 0.0)), pow(1.07, int(expected.stage) - 1)) \
			and not artifact.is_empty() and repeated == artifact and case_inventory_count == 1 \
			and String(artifact.get("uniqueId", "")) == uid \
			and String(artifact.get("artifactSpecId", "")) == String(expected.spec) \
			and String(artifact.get("storyArtifactId", "")) == String(expected.story) \
			and String(artifact.get("authenticityTruth", "")) == String(expected.truth)
		issuance_ok = issuance_ok and row_ok
		issuance_rows[case_id] = {"stage": expected.stage, "started": started, "uid": artifact.get("uniqueId", ""), "spec": artifact.get("artifactSpecId", ""), "story": artifact.get("storyArtifactId", ""), "truth": artifact.get("authenticityTruth", ""), "repeatSame": repeated == artifact, "uidCount": case_inventory_count, "ok": row_ok}
	record("BOOKEND-ISSUE-02", "Stage 1 and Stage 10 issue one stable authoritative artifact per new authored case", issuance_ok, issuance_rows)

	var discovery_ok := true
	var outcome_ok := true
	var runtime_rows: Dictionary = {}
	for case_id: String in CASE_IDS:
		var expected: Dictionary = EXPECTED[case_id]
		var started := start_case_stage(gs, case_id)
		var artifact: Dictionary = gs.begin_case(case_id)
		var discovery: Dictionary = discover_all(gs, case_id)
		var definition: Dictionary = registry.get_case_v2(case_id)
		var required: Array = definition.get("resolution", {}).get("required_source_refs", []).duplicate()
		var canonical := String(expected.truth)
		var empty: Dictionary = gs.evaluate_case_submission(case_id, canonical, [])
		var mentor: Dictionary = gs.evaluate_case_submission(case_id, canonical, required.slice(0, 1))
		var credible: Dictionary = gs.evaluate_case_submission(case_id, canonical, required.slice(0, 3))
		var masterful: Dictionary = gs.evaluate_case_submission(case_id, canonical, required)
		var wrong_hypothesis := ""
		for hypothesis: Dictionary in definition.get("hypotheses", []):
			if String(hypothesis.get("id", "")) != canonical:
				wrong_hypothesis = String(hypothesis.get("id", ""))
				break
		var mistaken: Dictionary = gs.evaluate_case_submission(case_id, wrong_hypothesis, required)
		var row_discovery_ok: bool = bool(started.get("ok", false)) and not artifact.is_empty() \
			and discovery.ids.size() == 6 and int(discovery.toolGateAttempts) >= 2 and bool(discovery.wrongToolZero)
		var row_outcome_ok: bool = String(empty.get("code", "")) == "CITATION_REQUIRED" \
			and String(mentor.get("outcome", "")) == "reviewed_with_mentor" \
			and String(credible.get("outcome", "")) == "credible" \
			and String(masterful.get("outcome", "")) == "masterful" \
			and String(mistaken.get("outcome", "")) == "mistaken"
		discovery_ok = discovery_ok and row_discovery_ok
		outcome_ok = outcome_ok and row_outcome_ok
		runtime_rows[case_id] = {"discovery": discovery, "empty": empty, "mentor": mentor, "credible": credible, "masterful": masterful, "mistaken": mistaken, "discoveryOk": row_discovery_ok, "outcomeOk": row_outcome_ok}
	record("BOOKEND-DISCOVERY-03", "All 24 authored findings unlock through dependencies and wrong-tool attempts mutate no authority", discovery_ok, runtime_rows)
	record("BOOKEND-OUTCOME-04", "All four ordered rule sets fail closed and distinguish mentor, credible, masterful and mistaken reports", outcome_ok, runtime_rows)

	var privacy_ok := true
	var privacy_rows: Dictionary = {}
	var forbidden_keys := ["canonical_hypothesis_id", "authoring_truth_hypothesis_id", "authenticityTruth", "winning_hypothesis_id", "outcome_rules", "required_source_refs"]
	for case_id: String in CASE_IDS:
		var public_state: Dictionary = gs.get_case_public_state(case_id)
		var surface := JSON.stringify(public_state)
		var leaks: Array = forbidden_keys.filter(func(token: String): return surface.contains(token))
		privacy_ok = privacy_ok and leaks.is_empty()
		privacy_rows[case_id] = {"leaks": leaks, "artifactId": public_state.get("artifactId", ""), "keys": public_state.keys()}
	record("BOOKEND-PUBLIC-05", "Bookend public dossiers exclude canonical truth and private authoring rules", privacy_ok, privacy_rows)

	var lock_payload: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cases/authored_v2.lock.json"))
	var lock_ids: Array = []
	if lock_payload is Dictionary:
		for entry: Dictionary in lock_payload.get("files", []):
			if String(entry.get("case_id", "")) in CASE_IDS:
				lock_ids.append(String(entry.get("case_id", "")))
	var lock_ok := CASE_IDS.all(func(case_id: String): return lock_ids.has(case_id)) and lock_ids.size() == CASE_IDS.size()
	record("BOOKEND-LOCK-06", "All four authored case files are protected by the immutable hash manifest", lock_ok, {"lockIds": lock_ids})
	finish(gs)
