extends SceneTree

## Stage 9 authored-v2 contract: fresh identities, evidence pressure, ordered
## outcomes, and preservation of the old recorder/gauge bindings.

const REPORT_PATH := "res://qa/R3_STAGE9_AUTHORED_CASES_TESTS.json"
const CASE_IDS := ["master_recorder", "master_gauge"]
const EXPECTED := {
	"master_recorder": {"spec": "artifact_078", "story": "story_artifact_23", "truth": "hyp.master_recorder.genuine_field_recorder_with_period_transport_repair", "recipe": "WIRE_RECORDER", "mesh": "res://assets/artifacts/model_02.obj", "legacy": "artifact_054", "legacy_story": ""},
	"master_gauge": {"spec": "artifact_077", "story": "story_artifact_24", "truth": "hyp.master_gauge.genuine_signal_lantern", "recipe": "SIGNAL_LANTERN", "mesh": "res://assets/artifacts/telephone.obj", "legacy": "artifact_055", "legacy_story": ""}
}

var results: Array = []

func _init() -> void:
	call_deferred("run")

func record(test_id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": test_id, "name": name, "executed": true, "passed": passed, "evidence": evidence})

func discover_all(gs: Node, case_id: String) -> Dictionary:
	var discovered: Array = []
	var wrong_tool_zero := true
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
				gs.select_tool(String(required[0]))
			var result: Dictionary = gs.discover_case_evidence(case_id, String(row.get("id", "")))
			if bool(result.get("ok", false)):
				discovered.append(String(row.get("id", "")))
				progressed = true
		if not progressed:
			break
	return {"ids": discovered, "wrongToolZero": wrong_tool_zero}

func finish(gs: Node) -> void:
	var passed := results.filter(func(row: Dictionary): return bool(row.get("passed", false))).size()
	var report := {"suite": "R3 Stage 9 Authored Cases", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "expectedCount": 6, "tests": results}
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
	gs.player_profile = gs.default_player_profile()
	gs.player_profile.highestUnlockedStage = 9
	var stage_start: Dictionary = gs.new_game(9)
	var data_rows: Dictionary = {}
	var data_ok: bool = bool(stage_start.get("ok", false)) and is_equal_approx(float(stage_start.get("difficultyMultiplier", 0.0)), pow(1.07, 8))
	for case_id: String in CASE_IDS:
		var expected: Dictionary = EXPECTED[case_id]
		var definition: Dictionary = registry.get_case_v2(case_id)
		var story_case: Dictionary = registry.get_case(case_id)
		var source_rows: Array = definition.get("evidence", [])
		var kinds: Array = source_rows.map(func(row: Dictionary): return String(row.get("source", {}).get("kind", "")))
		var risk_counts := {"NONE": 0, "LOW": 0, "HIGH": 0}
		for row: Dictionary in source_rows:
			var risk := String(row.get("risk", {}).get("level", "NONE"))
			risk_counts[risk] = int(risk_counts.get(risk, 0)) + 1
		var provenance := source_rows.filter(func(row: Dictionary): return String(row.get("public_clue_id", "")) == "PROVENANCE")
		var row_ok: bool = String(story_case.get("rewardSpecId", "")) == String(expected.spec) and String(story_case.get("storyArtifactId", "")) == String(expected.story) and String(definition.get("artifact_spec_id", "")) == String(expected.spec) and String(definition.get("canonical_hypothesis_id", "")) == String(expected.truth) and kinds.count("ARTIFACT") == 2 and kinds.count("DOCUMENT") == 2 and kinds.count("NPC") == 1 and kinds.count("REFERENCE") == 1 and risk_counts == {"NONE": 4, "LOW": 1, "HIGH": 1} and provenance.size() == 1 and String(provenance[0].get("source", {}).get("kind", "")) == "DOCUMENT"
		data_ok = data_ok and row_ok
		data_rows[case_id] = {"sources": source_rows.size(), "kinds": kinds, "risk": risk_counts, "provenance": provenance.size(), "ok": row_ok}
	record("S9-DATA-01", "Stage 9 cases bind fresh authored identities with six-source topology and exact risk pressure", data_ok, {"stageStart": stage_start, "cases": data_rows, "stageMultiplier": registry.stage_difficulty_multiplier(9)})

	var issuance_rows: Dictionary = {}
	var issuance_ok := true
	for case_id: String in CASE_IDS:
		var expected: Dictionary = EXPECTED[case_id]
		var artifact: Dictionary = gs.begin_case(case_id)
		var repeated: Dictionary = gs.begin_case(case_id)
		var row_ok: bool = not artifact.is_empty() and repeated == artifact and gs.inventory.size() == 1 and String(artifact.get("uniqueId", "")) == "case_%s" % case_id and String(artifact.get("artifactSpecId", "")) == String(expected.spec) and String(artifact.get("storyArtifactId", "")) == String(expected.story) and String(artifact.get("authenticityTruth", "")) == String(expected.truth)
		issuance_ok = issuance_ok and row_ok
		issuance_rows[case_id] = {"uid": artifact.get("uniqueId", ""), "spec": artifact.get("artifactSpecId", ""), "story": artifact.get("storyArtifactId", ""), "truth": artifact.get("authenticityTruth", ""), "repeatSame": repeated == artifact, "ok": row_ok}
		gs.inventory = []
		gs.campaign_state.caseArtifactLedger.erase(case_id)
		gs.campaign_state.activeCaseId = ""
	record("S9-ISSUE-02", "Fresh Stage 9 issuance remains one stable UID per case without duplicate paths", issuance_ok, issuance_rows)

	var runtime_rows: Dictionary = {}
	var runtime_ok := true
	for case_id: String in CASE_IDS:
		var artifact: Dictionary = gs.begin_case(case_id)
		var discovery := discover_all(gs, case_id)
		var definition: Dictionary = registry.get_case_v2(case_id)
		var required: Array = [String(definition.get("resolution", {}).get("required_source_refs", [])[0]), String(definition.get("resolution", {}).get("required_source_refs", [])[1]), String(definition.get("resolution", {}).get("required_source_refs", [])[2]), String(definition.get("resolution", {}).get("required_source_refs", [])[3])]
		var canonical := String(definition.get("canonical_hypothesis_id", ""))
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
		var expected: Dictionary = EXPECTED[case_id]
		var render_dto: Dictionary = registry.get_artifact_instance_render_dto(artifact)
		var case_ok: bool = discovery.ids.size() == 6 and bool(discovery.wrongToolZero) and String(empty.get("code", "")) == "CITATION_REQUIRED" and String(mentor.get("outcome", "")) == "reviewed_with_mentor" and String(credible.get("outcome", "")) == "credible" and String(masterful.get("outcome", "")) == "masterful" and String(mistaken.get("outcome", "")) == "mistaken" and String(render_dto.get("recipe", "")) == String(expected.recipe) and String(render_dto.get("meshPath", "")) == String(expected.mesh)
		runtime_ok = runtime_ok and case_ok
		runtime_rows[case_id] = {"discovered": discovery.ids, "wrongToolZero": discovery.wrongToolZero, "empty": empty, "mentor": mentor, "credible": credible, "masterful": masterful, "mistaken": mistaken, "recipe": render_dto.get("recipe", ""), "mesh": render_dto.get("meshPath", ""), "ok": case_ok}
		gs.inventory = []
		gs.campaign_state.caseArtifactLedger.erase(case_id)
		gs.campaign_state.activeCaseId = ""
	var swapped_recorder: Dictionary = registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_078", "storyArtifactId": "story_artifact_24"})
	var swapped_gauge: Dictionary = registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_077", "storyArtifactId": "story_artifact_23"})
	runtime_ok = runtime_ok and String(swapped_recorder.get("recipe", "")) == "DEFAULT" and String(swapped_gauge.get("recipe", "")) == "DEFAULT"
	runtime_rows["pairIsolation"] = {"swappedRecorder": swapped_recorder.get("recipe", ""), "swappedGauge": swapped_gauge.get("recipe", "")}
	record("S9-REASON-03", "Stage 9 evidence drives fail-closed, mentor, credible, masterful and mistaken outcomes while pair renderers remain isolated", runtime_ok, runtime_rows)

	var legacy_rows: Dictionary = {}
	var legacy_ok := true
	for case_id: String in CASE_IDS:
		var expected: Dictionary = EXPECTED[case_id]
		var legacy: Dictionary = gs.new_artifact(String(expected.legacy), 994400 + CASE_IDS.find(case_id), "case_%s_legacy" % case_id)
		legacy.caseId = case_id
		legacy.storyArtifactId = String(expected.legacy_story)
		gs.inventory = [legacy]
		var before := JSON.stringify(gs.serialize_instance(legacy))
		var loaded: bool = gs.apply_save_data(gs.save_payload())
		var after_artifact: Dictionary = gs.find_inventory_instance(legacy.uniqueId)
		var row_ok: bool = loaded and before == JSON.stringify(gs.serialize_instance(after_artifact)) and String(after_artifact.get("artifactSpecId", "")) == String(expected.legacy)
		legacy_ok = legacy_ok and row_ok
		legacy_rows[case_id] = {"loaded": loaded, "spec": after_artifact.get("artifactSpecId", ""), "story": after_artifact.get("storyArtifactId", ""), "ok": row_ok}
	record("S9-LEGACY-04", "Legacy Stage 9 bindings remain exact and do not migrate to fresh 077/078 identities", legacy_ok, legacy_rows)

	var public_state: Dictionary = gs.get_case_public_state("master_recorder")
	var surface := JSON.stringify(public_state)
	var leaks := ["canonical_hypothesis_id", "authoring_truth_hypothesis_id", "authenticityTruth", "trueMarketBaseline", "trueHistoricalSignificance"]
	var leak_free := leaks.all(func(token: String): return not surface.contains(token))
	record("S9-PUBLIC-05", "Stage 9 public dossier keeps hidden truth and internal source identifiers out of the player surface", leak_free, {"keys": public_state.keys(), "leaks": leaks.filter(func(token: String): return surface.contains(token))})

	var lock_payload: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cases/authored_v2.lock.json"))
	var lock_ids: Array = []
	if lock_payload is Dictionary:
		for entry: Dictionary in lock_payload.get("files", []):
			if String(entry.get("case_id", "")) in CASE_IDS:
				lock_ids.append(String(entry.get("case_id", "")))
	record("S9-LOCK-06", "Stage 9 authored files are present in the immutable lock manifest", CASE_IDS.all(func(case_id: String): return lock_ids.has(case_id)), {"lockIds": lock_ids})
	finish(gs)
