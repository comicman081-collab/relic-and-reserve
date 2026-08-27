extends SceneTree

## Stage 10 fresh artifact binding, legacy preservation and pair-render QA.
## Grand Reserve remains a separate state machine; this suite only verifies
## that the two Stage 10 case files issue the two newly introduced specs.

const REPORT_PATH := "res://qa/R3_STAGE10_ARTIFACT_IDENTITY_TESTS.json"
const EXPECTED := {
	"master_camera": {"spec": "artifact_079", "story": "story_artifact_25", "truth": "hyp.master_camera.genuine_with_period_clamp_service", "recipe": "SPECTROSCOPE", "mesh": "res://assets/artifacts/model_05.obj", "legacy": "artifact_056"},
	"master_mechanism": {"spec": "artifact_080", "story": "story_artifact_26", "truth": "hyp.master_mechanism.genuine_observatory_regulator", "recipe": "ASTRONOMICAL_REGULATOR", "mesh": "res://assets/artifacts/watch.obj", "legacy": "artifact_060"}
}
const CASE_IDS := ["master_camera", "master_mechanism"]
var results: Array = []

func _init() -> void:
	call_deferred("run")

func record(test_id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": test_id, "name": name, "executed": true, "passed": passed, "evidence": evidence})

func finish(gs: Node) -> void:
	var passed := results.filter(func(row: Dictionary): return bool(row.get("passed", false))).size()
	var report := {"suite": "R3 Stage 10 Artifact Identity", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "expectedCount": results.size(), "tests": results}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify(report))
	gs.persistence_enabled = false
	quit(0 if passed == results.size() else 1)

func start_stage_ten(gs: Node) -> Dictionary:
	gs.persistence_enabled = false
	gs.player_profile = gs.default_player_profile()
	gs.player_profile.highestUnlockedStage = 10
	return gs.new_game(10)

func run() -> void:
	var registry: Node = get_root().get_node("RuntimeRegistry")
	var gs: Node = get_root().get_node("GameState")
	gs.persistence_enabled = false
	var stage_start := start_stage_ten(gs)
	var start_ok: bool = bool(stage_start.get("ok", false)) and is_equal_approx(float(stage_start.get("difficultyMultiplier", 0.0)), pow(1.07, 9))
	var issuance_rows: Dictionary = {}
	var issuance_ok := start_ok
	for case_id: String in CASE_IDS:
		var expected: Dictionary = EXPECTED[case_id]
		var artifact: Dictionary = gs.begin_case(case_id)
		var repeated: Dictionary = gs.begin_case(case_id)
		var case_inventory_count: int = gs.inventory.filter(func(row: Variant): return row is Dictionary and String(row.get("caseId", "")) == case_id).size()
		var row_ok: bool = not artifact.is_empty() and repeated == artifact and case_inventory_count == 1 \
				and String(artifact.get("uniqueId", "")) == "case_%s" % case_id \
				and String(artifact.get("artifactSpecId", "")) == String(expected.spec) \
				and String(artifact.get("storyArtifactId", "")) == String(expected.story) \
				and String(artifact.get("authenticityTruth", "")) == String(expected.truth)
		issuance_ok = issuance_ok and row_ok
		issuance_rows[case_id] = {"uid": artifact.get("uniqueId", ""), "spec": artifact.get("artifactSpecId", ""), "story": artifact.get("storyArtifactId", ""), "truth": artifact.get("authenticityTruth", ""), "repeatSame": repeated == artifact, "caseInventoryCount": case_inventory_count, "ok": row_ok}
		gs.inventory = []
		gs.campaign_state.caseArtifactLedger.erase(case_id)
		gs.campaign_state.activeCaseId = ""
	record("S10-ISSUE-01", "Stage 10 cases issue the fresh 079/080 identities once with the canonical 7-percent curve", issuance_ok, {"stage": stage_start, "cases": issuance_rows})

	var evidence_rows: Dictionary = {}
	var evidence_ok := true
	for case_id: String in CASE_IDS:
		var definition: Dictionary = gs.case_definition(case_id)
		var risk_counts := {"NONE": 0, "LOW": 0, "HIGH": 0}
		for row_value: Variant in definition.get("evidence", []):
			if row_value is Dictionary:
				var level := String(row_value.get("risk", {}).get("level", "NONE"))
				risk_counts[level] = int(risk_counts.get(level, 0)) + 1
		var public: Dictionary = gs.get_case_public_state(case_id)
		var surface := JSON.stringify(public)
		var leaks: Array = ["story_artifact_25", "story_artifact_26", "authenticityTruth", "canonical_hypothesis_id", "authoring_truth_hypothesis_id", "trueMarketBaseline"].filter(func(token: String): return surface.contains(token))
		var expected_counts := {"NONE": 4, "LOW": 1, "HIGH": 1}
		var row_ok: bool = definition.get("evidence", []).size() == 6 and risk_counts == expected_counts and leaks.is_empty()
		evidence_ok = evidence_ok and row_ok
		evidence_rows[case_id] = {"evidence": definition.get("evidence", []).size(), "risk": risk_counts, "leaks": leaks, "ok": row_ok}
	record("S10-CASE-02", "Fresh Stage 10 case conditions expose authored low/high pressure without hidden story or truth identifiers", evidence_ok, evidence_rows)

	var visual_rows: Dictionary = {}
	var visual_ok := true
	for case_id: String in CASE_IDS:
		var expected: Dictionary = EXPECTED[case_id]
		var artifact: Dictionary = gs.new_artifact(String(expected.spec), 100000 + CASE_IDS.find(case_id), "stage10_visual_%s" % case_id)
		artifact.storyArtifactId = String(expected.story)
		var dto: Dictionary = registry.get_artifact_instance_render_dto(artifact)
		var row_ok: bool = String(dto.get("recipe", "")) == String(expected.recipe) and String(dto.get("meshPath", "")) == String(expected.mesh)
		visual_ok = visual_ok and row_ok
		visual_rows[case_id] = {"recipe": dto.get("recipe", ""), "mesh": dto.get("meshPath", ""), "ok": row_ok}
	var swapped_prism: Dictionary = registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_079", "storyArtifactId": "story_artifact_26"})
	var swapped_regulator: Dictionary = registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_080", "storyArtifactId": "story_artifact_25"})
	visual_ok = visual_ok and String(swapped_prism.get("recipe", "")) == "DEFAULT" and String(swapped_regulator.get("recipe", "")) == "DEFAULT"
	visual_rows["pairIsolation"] = {"swappedPrism": swapped_prism.get("recipe", ""), "swappedRegulator": swapped_regulator.get("recipe", "")}
	record("S10-VISUAL-03", "Stage 10 fresh artifacts use distinct local spectroscope/regulator recipes and swapped pairs fail closed to DEFAULT", visual_ok, visual_rows)

	var legacy_rows: Dictionary = {}
	var legacy_ok := true
	for case_id: String in CASE_IDS:
		var expected: Dictionary = EXPECTED[case_id]
		var legacy: Dictionary = gs.new_artifact(String(expected.legacy), 110000 + CASE_IDS.find(case_id), "stage10_legacy_%s" % case_id)
		legacy.caseId = case_id
		legacy.storyArtifactId = ""
		legacy.authenticityTruth = "GENUINE"
		gs.inventory = [legacy]
		var before := JSON.stringify(gs.serialize_instance(legacy))
		var payload: Dictionary = gs.save_payload().duplicate(true)
		var loaded: bool = gs.apply_save_data(payload)
		var after: Dictionary = gs.find_inventory_instance(legacy.uniqueId)
		var row_ok: bool = loaded and before == JSON.stringify(gs.serialize_instance(after)) and String(after.get("artifactSpecId", "")) == String(expected.legacy) and String(after.get("storyArtifactId", "")) == ""
		legacy_ok = legacy_ok and row_ok
		legacy_rows[case_id] = {"loaded": loaded, "spec": after.get("artifactSpecId", ""), "story": after.get("storyArtifactId", ""), "ok": row_ok}
	record("S10-LEGACY-04", "Previously issued 056/060 artifacts remain exact and are never silently rebound to fresh 079/080", legacy_ok, legacy_rows)
	finish(gs)
