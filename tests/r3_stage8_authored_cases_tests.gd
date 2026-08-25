extends SceneTree

## Stage 8 authored-v2 contract: fresh identities, public evidence pressure,
## ordered outcomes, pair-keyed visual identity, and legacy save preservation.

const REPORT_PATH := "res://qa/R3_STAGE8_AUTHORED_CASES_TESTS.json"
const CASE_IDS := ["master_chronometer", "master_optical"]
const EXPECTED := {
	"master_chronometer": {
		"spec": "artifact_061", "story": "story_artifact_21",
		"truth": "hyp.master_chronometer.genuine_precision_chronometer",
		"npc": "mara_venn", "recipe": "CHRONOMETER", "mesh": "res://assets/artifacts/clock.obj",
		"tool": "precision_scale", "required": [
			"src.master_chronometer.artifact.escapement_consistency",
			"src.master_chronometer.artifact.timing_mark_sequence",
			"src.master_chronometer.document.bench_log",
			"src.master_chronometer.reference.precision_standard"
		]
	},
	"master_optical": {
		"spec": "artifact_075", "story": "story_artifact_22",
		"truth": "hyp.master_optical.genuine_microscope_with_period_optical_repair",
		"npc": "victor_hale", "recipe": "MICROSCOPE", "mesh": "res://assets/artifacts/binoculars.obj",
		"tool": "material_scanner", "required": [
			"src.master_optical.artifact.body_construction",
			"src.master_optical.artifact.period_repair_seam",
			"src.master_optical.document.repair_register",
			"src.master_optical.reference.microscopy_standard"
		]
	}
}

var results: Array = []

func _init() -> void:
	call_deferred("run")

func record(test_id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": test_id, "name": name, "executed": true, "passed": passed, "evidence": evidence})

func finish(gs: Node) -> void:
	var passed := results.filter(func(row: Dictionary): return bool(row.get("passed", false))).size()
	var report := {"suite": "R3 Stage 8 Authored Cases", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "expectedCount": 7, "tests": results}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify(report))
	gs.persistence_enabled = false
	quit(0 if passed == 7 and results.size() == 7 else 1)

func start_stage_eight(gs: Node) -> Dictionary:
	gs.persistence_enabled = false
	gs.player_profile = gs.default_player_profile()
	gs.player_profile.highestUnlockedStage = 8
	return gs.new_game(8)

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

func run() -> void:
	var registry: Node = get_root().get_node("RuntimeRegistry")
	var gs: Node = get_root().get_node("GameState")
	var stage_start := start_stage_eight(gs)
	var data_rows: Dictionary = {}
	var data_ok := bool(stage_start.get("ok", false)) and is_equal_approx(float(stage_start.get("difficultyMultiplier", 0.0)), pow(1.07, 7))
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
		var row_ok: bool = String(story_case.get("rewardSpecId", "")) == String(expected.spec) \
			and String(story_case.get("storyArtifactId", "")) == String(expected.story) \
			and String(definition.get("artifact_spec_id", "")) == String(expected.spec) \
			and String(definition.get("canonical_hypothesis_id", "")) == String(expected.truth) \
			and kinds.count("ARTIFACT") == 2 and kinds.count("DOCUMENT") == 2 and kinds.count("NPC") == 1 and kinds.count("REFERENCE") == 1 \
			and risk_counts == {"NONE": 4, "LOW": 1, "HIGH": 1} and provenance.size() == 1 \
			and String(provenance[0].get("source", {}).get("kind", "")) == "DOCUMENT" \
			and String(provenance[0].get("source", {}).get("ref_id", "")) == ("document_21" if case_id == "master_chronometer" else "document_22")
		data_ok = data_ok and row_ok
		data_rows[case_id] = {"sources": source_rows.size(), "kinds": kinds, "risk": risk_counts, "provenance": provenance.size(), "ok": row_ok}
	record("S8-DATA-01", "Both Stage 8 cases resolve to fresh authored identities with exact six-source pressure and one provenance bridge", data_ok, {"stageStart": stage_start, "cases": data_rows, "stageMultiplier": registry.stage_difficulty_multiplier(8)})

	var issuance_rows: Dictionary = {}
	var issuance_ok := true
	for case_id: String in CASE_IDS:
		var expected: Dictionary = EXPECTED[case_id]
		var artifact: Dictionary = gs.begin_case(case_id)
		var repeated: Dictionary = gs.begin_case(case_id)
		var row_ok: bool = not artifact.is_empty() and repeated == artifact and gs.inventory.size() == 1 \
			and String(artifact.get("uniqueId", "")) == "case_%s" % case_id \
			and String(artifact.get("artifactSpecId", "")) == String(expected.spec) \
			and String(artifact.get("storyArtifactId", "")) == String(expected.story) \
			and String(artifact.get("authenticityTruth", "")) == String(expected.truth)
		issuance_ok = issuance_ok and row_ok
		issuance_rows[case_id] = {"uid": artifact.get("uniqueId", ""), "spec": artifact.get("artifactSpecId", ""), "story": artifact.get("storyArtifactId", ""), "truth": artifact.get("authenticityTruth", ""), "repeatSame": repeated == artifact, "ok": row_ok}
		gs.inventory = []
		gs.campaign_state.caseArtifactLedger.erase(case_id)
		gs.campaign_state.activeCaseId = ""
	record("S8-ISSUE-02", "Fresh Stage 8 issuance is one stable UID per case with no duplicate path", issuance_ok, issuance_rows)

	var runtime_rows: Dictionary = {}
	var runtime_ok := true
	for case_id: String in CASE_IDS:
		var expected: Dictionary = EXPECTED[case_id]
		var artifact: Dictionary = gs.begin_case(case_id)
		var discovery := discover_all(gs, case_id)
		var definition: Dictionary = registry.get_case_v2(case_id)
		var required: Array = expected.required
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
		var dto: Dictionary = registry.get_artifact_instance_render_dto(artifact)
		var case_ok: bool = not artifact.is_empty() and discovery.ids.size() == 6 and bool(discovery.wrongToolZero) \
			and String(empty.get("code", "")) == "CITATION_REQUIRED" \
			and String(mentor.get("outcome", "")) == "reviewed_with_mentor" \
			and String(credible.get("outcome", "")) == "credible" \
			and String(masterful.get("outcome", "")) == "masterful" \
			and String(mistaken.get("outcome", "")) == "mistaken" \
			and String(dto.get("recipe", "")) == String(expected.recipe) and String(dto.get("meshPath", "")) == String(expected.mesh)
		runtime_ok = runtime_ok and case_ok
		runtime_rows[case_id] = {"discovered": discovery.ids, "wrongToolZero": discovery.wrongToolZero, "empty": empty, "mentor": mentor, "credible": credible, "masterful": masterful, "mistaken": mistaken, "recipe": dto.get("recipe", ""), "mesh": dto.get("meshPath", ""), "ok": case_ok}
		gs.inventory = []
		gs.campaign_state.caseArtifactLedger.erase(case_id)
		gs.campaign_state.activeCaseId = ""
	record("S8-REASON-03", "Stage 8 evidence is consumed by the ordered mentor/credible/masterful/mistaken evaluator and pair renderer", runtime_ok, runtime_rows)

	var legacy_rows: Dictionary = {}
	var legacy_ok := true
	for case_id: String in CASE_IDS:
		var legacy_spec := "artifact_052" if case_id == "master_chronometer" else "artifact_053"
		var legacy: Dictionary = gs.new_artifact(legacy_spec, 884400 + CASE_IDS.find(case_id), "case_%s_legacy" % case_id)
		legacy.caseId = case_id
		legacy.storyArtifactId = ""
		legacy.authenticityTruth = "GENUINE"
		gs.inventory = [legacy]
		gs.campaign_state.caseArtifactLedger = {case_id: {"issued": true, "artifactUid": legacy.uniqueId, "disposition": "INVENTORY", "saleTransactionId": "legacy-keep", "publicConditionSnapshot": {"historicalIntegrity": 77.0}, "publicAppraisalSnapshot": 500}}
		var payload: Dictionary = gs.save_payload().duplicate(true)
		var before := JSON.stringify(payload.inventory[0])
		var loaded: bool = gs.apply_save_data(payload)
		var after_artifact: Dictionary = gs.find_inventory_instance(legacy.uniqueId)
		var row_ok: bool = loaded and before == JSON.stringify(gs.serialize_instance(after_artifact)) \
			and String(after_artifact.get("artifactSpecId", "")) == legacy_spec and String(after_artifact.get("storyArtifactId", "")) == ""
		legacy_ok = legacy_ok and row_ok
		legacy_rows[case_id] = {"loaded": loaded, "before": JSON.parse_string(before), "after": gs.serialize_instance(after_artifact), "ok": row_ok}
	record("S8-LEGACY-04", "Legacy Stage 8 issued artifact specs 052/053 remain byte-exact and are never silently migrated to fresh 061/075 bindings", legacy_ok, legacy_rows)

	var invalid_pair: Dictionary = registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_075", "storyArtifactId": "story_artifact_21"})
	var pair_isolation: Dictionary = registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_061", "storyArtifactId": "story_artifact_21"})
	record("S8-VISUAL-05", "Stage 8 pair renderer is isolated: valid pairs are special, swapped story/spec pairs are DEFAULT", String(pair_isolation.get("recipe", "")) == "CHRONOMETER" and String(invalid_pair.get("recipe", "")) == "DEFAULT", {"valid": pair_isolation, "swapped": invalid_pair})

	var public_state: Dictionary = gs.get_case_public_state("master_chronometer")
	var surface := JSON.stringify(public_state)
	var leaks: Array = ["canonical_hypothesis_id", "authoring_truth_hypothesis_id", "authenticityTruth", "trueMarketBaseline", "trueHistoricalSignificance", "trueMarketBaseline"].filter(func(token: String): return surface.contains(token))
	record("S8-PUBLIC-06", "Stage 8 public dossier does not leak hidden truth or internal source identifiers", leaks.is_empty(), {"leaks": leaks, "keys": public_state.keys()})

	var lock: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cases/authored_v2.lock.json"))
	var lock_ids: Array = []
	if lock is Dictionary:
		for row: Dictionary in lock.get("files", []):
			if CASE_IDS.has(String(row.get("case_id", ""))):
				lock_ids.append(String(row.get("case_id", "")))
	record("S8-LOCK-07", "Stage 8 authored files are both present in the immutable lock manifest", lock_ids == CASE_IDS, {"lockIds": lock_ids})
	finish(gs)
