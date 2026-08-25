extends SceneTree

## Runtime acceptance for the sparse Stage 5/10 authored-risk and repair-tool
## diversity contract. The suite uses public gameplay APIs only and never
## exports or packages the project.

const REPORT_PATH := "res://qa/R3_AUTHORED_PRESSURE_RUNTIME_TESTS.json"

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(test_id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": test_id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func approximately(left: float, right: float, tolerance: float = 0.0001) -> bool:
	return absf(left - right) <= tolerance


func raw_telemetry(gs: Node) -> Dictionary:
	var value: Variant = gs.stage_run_state.get("telemetry", {})
	return value.duplicate(true) if value is Dictionary else {}


func start_stage(gs: Node, stage_id: int) -> Dictionary:
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	gs.reset_game()
	gs.player_profile = gs.default_player_profile()
	gs.player_profile.highestUnlockedStage = 10
	gs.player_profile.clearedStages = range(1, stage_id)
	return gs.new_game(stage_id)


func evidence_row(public_state: Dictionary, evidence_id: String) -> Dictionary:
	for row_value: Variant in public_state.get("evidence", []):
		if row_value is Dictionary and String(row_value.get("id", "")) == evidence_id:
			return row_value
	return {}


func exercise_evidence(gs: Node, case_id: String, evidence_id: String, expected_level: String, expected_penalty: float) -> Dictionary:
	var artifact: Dictionary = gs.find_case_artifact(case_id)
	var public_before: Dictionary = gs.get_case_public_state(case_id)
	var row: Dictionary = evidence_row(public_before, evidence_id)
	var warning_value: Variant = row.get("riskWarning", {})
	var warning: Dictionary = warning_value if warning_value is Dictionary else {}
	var public_json := JSON.stringify(public_before)
	var integrity_before := float(artifact.get("historicalIntegrity", 0.0))
	var telemetry_before := raw_telemetry(gs)
	var first: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
	var integrity_after := float(artifact.get("historicalIntegrity", 0.0))
	var telemetry_after := raw_telemetry(gs)
	var duplicate: Dictionary = gs.discover_case_evidence(case_id, evidence_id)
	var telemetry_duplicate := raw_telemetry(gs)
	var public_safe := not public_json.contains("groundTruth") \
		and not public_json.contains("authenticityTruth") \
		and not public_json.contains("canonical_hypothesis_id") \
		and not public_json.contains("trueMarket") \
		and not public_json.contains("riskWeight")
	var passed := not row.is_empty() \
		and bool(row.get("unlocked", false)) \
		and String(row.get("riskLevel", "")) == expected_level \
		and not String(warning.get("en", "")).is_empty() \
		and not String(warning.get("ko", "")).is_empty() \
		and public_safe \
		and bool(first.get("ok", false)) \
		and String(first.get("code", "")) == "DISCOVERED" \
		and String(first.get("riskLevel", "")) == expected_level \
		and approximately(float(first.get("appliedRiskPenalty", -1.0)), expected_penalty) \
		and approximately(integrity_before - integrity_after, expected_penalty) \
		and int(telemetry_after.get("investigationActions", 0)) == int(telemetry_before.get("investigationActions", 0)) + 1 \
		and int(telemetry_after.get("investigationRiskActions", 0)) == int(telemetry_before.get("investigationRiskActions", 0)) + 1 \
		and approximately(float(telemetry_after.get("investigationRiskWeightSum", 0.0)) - float(telemetry_before.get("investigationRiskWeightSum", 0.0)), expected_penalty) \
		and bool(duplicate.get("ok", false)) \
		and String(duplicate.get("code", "")) == "ALREADY_DISCOVERED" \
		and telemetry_duplicate == telemetry_after
	return {
		"passed": passed,
		"caseId": case_id,
		"evidenceId": evidence_id,
		"riskLevel": row.get("riskLevel", ""),
		"warningLocalized": not String(warning.get("en", "")).is_empty() and not String(warning.get("ko", "")).is_empty(),
		"expectedPenalty": expected_penalty,
		"appliedPenalty": first.get("appliedRiskPenalty", -1.0),
		"integrityDelta": integrity_before - integrity_after,
		"telemetryDelta": float(telemetry_after.get("investigationRiskWeightSum", 0.0)) - float(telemetry_before.get("investigationRiskWeightSum", 0.0)),
		"duplicateCode": duplicate.get("code", ""),
		"publicSafe": public_safe
	}


func finish_suite(gs: Node) -> void:
	var passed := results.filter(func(result: Dictionary): return bool(result.get("passed", false))).size()
	var report := {
		"suite": "R3 Authored Stage Pressure Runtime",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"skipped": 0,
		"tests": results
	}
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print(JSON.stringify(report))
	gs.persistence_enabled = false
	quit(0 if passed == results.size() else 1)


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")

	var started_five := start_stage(gs, 5)
	var collector_artifact: Dictionary = gs.begin_case("collector_promise")
	var collector_root: Dictionary = gs.discover_case_evidence("collector_promise", "src.collector_promise.artifact.period_body_identity")
	gs.select_tool("precision_screwdriver")
	var collector := exercise_evidence(gs, "collector_promise", "src.collector_promise.artifact.modern_capsule_repair", "LOW", pow(1.07, 4))
	record(
		"AUTHORED-PRESSURE-STAGE5-01",
		"Collector repair trace discloses LOW risk before action and applies the Stage 5 penalty exactly once",
		bool(started_five.get("ok", false)) and not collector_artifact.is_empty() \
			and bool(collector_root.get("ok", false)) and bool(collector.get("passed", false)),
		{"prerequisite": collector_root, "riskEvidence": collector}
	)

	started_five = start_stage(gs, 5)
	var prior_five_complete: bool = bool(gs.prepare_case_for_test("collector_promise"))
	var cameras_artifact: Dictionary = gs.begin_case("three_cameras")
	var cameras_root: Dictionary = gs.discover_case_evidence("three_cameras", "src.three_cameras.artifact.received_camera_body")
	gs.select_tool("material_scanner")
	var cameras := exercise_evidence(gs, "three_cameras", "src.three_cameras.artifact.copied_repair_surface", "LOW", pow(1.07, 4))
	record(
		"AUTHORED-PRESSURE-STAGE5-02",
		"Three Cameras repair trace keeps the second sparse Stage 5 LOW-risk route public and exactly once",
		bool(started_five.get("ok", false)) and prior_five_complete and not cameras_artifact.is_empty() \
			and bool(cameras_root.get("ok", false)) and bool(cameras.get("passed", false)),
		{"prerequisite": cameras_root, "riskEvidence": cameras}
	)

	var started_ten := start_stage(gs, 10)
	var camera_artifact: Dictionary = gs.begin_case("master_camera")
	var master_camera := exercise_evidence(gs, "master_camera", "master_camera:construction_method", "LOW", pow(1.07, 9))
	record(
		"AUTHORED-PRESSURE-STAGE10-01",
		"Prototype Camera construction discloses LOW risk and consumes the Stage 10 multiplier once",
		bool(started_ten.get("ok", false)) and not camera_artifact.is_empty() and bool(master_camera.get("passed", false)),
		master_camera
	)

	started_ten = start_stage(gs, 10)
	var prior_ten_complete: bool = bool(gs.prepare_case_for_test("master_camera"))
	var mechanism_artifact: Dictionary = gs.begin_case("master_mechanism")
	var material := exercise_evidence(gs, "master_mechanism", "master_mechanism:material", "LOW", pow(1.07, 9))
	var mechanism := exercise_evidence(gs, "master_mechanism", "master_mechanism:mechanism", "HIGH", 3.0 * pow(1.07, 9))
	record(
		"AUTHORED-PRESSURE-STAGE10-02",
		"Decorative Mechanism exposes one LOW and one HIGH choice while each consequence and telemetry event commits once",
		bool(started_ten.get("ok", false)) and prior_ten_complete and not mechanism_artifact.is_empty() and bool(material.get("passed", false)) and bool(mechanism.get("passed", false)),
		{"material": material, "mechanism": mechanism}
	)

	var stage5_counts := {"NONE": 0, "LOW": 0, "HIGH": 0}
	for case_id: String in ["collector_promise", "three_cameras"]:
		for evidence_value: Variant in gs.case_definition(case_id).get("evidence", []):
			if evidence_value is Dictionary:
				var level := String(evidence_value.get("risk", {}).get("level", "NONE"))
				stage5_counts[level] = int(stage5_counts.get(level, 0)) + 1
	var stage10_counts := {"NONE": 0, "LOW": 0, "HIGH": 0}
	for case_id: String in ["master_camera", "master_mechanism"]:
		for evidence_value: Variant in gs.case_definition(case_id).get("evidence", []):
			if evidence_value is Dictionary:
				var level := String(evidence_value.get("risk", {}).get("level", "NONE"))
				stage10_counts[level] = int(stage10_counts.get(level, 0)) + 1
	var tool_routes := {
		"artifact_069": registry.get_spec("artifact_069").get("repairProfile", {}).get("requiredTools", []),
		"artifact_070": registry.get_spec("artifact_070").get("repairProfile", {}).get("requiredTools", []),
		"artifact_079": registry.get_spec("artifact_079").get("repairProfile", {}).get("requiredTools", []),
		"artifact_080": registry.get_spec("artifact_080").get("repairProfile", {}).get("requiredTools", [])
	}
	var stage5_intersection: Array = tool_routes.artifact_069.filter(func(tool_id: Variant): return tool_routes.artifact_070.has(tool_id))
	var stage10_intersection: Array = tool_routes.artifact_079.filter(func(tool_id: Variant): return tool_routes.artifact_080.has(tool_id))
	var contract_exact: bool = stage5_counts == {"NONE": 8, "LOW": 2, "HIGH": 0} \
		and stage10_counts == {"NONE": 5, "LOW": 2, "HIGH": 1} \
		and tool_routes.artifact_069 == ["precision_screwdriver", "reference_database"] \
		and tool_routes.artifact_070 == ["cleaning_cloth", "precision_scale", "repair_toolkit"] \
		and tool_routes.artifact_079 == ["material_scanner", "uv_lamp"] \
		and tool_routes.artifact_080 == ["precision_scale", "precision_screwdriver", "reference_database"] \
		and stage5_intersection.is_empty() and stage10_intersection.is_empty()
	record(
		"AUTHORED-PRESSURE-CONTENT-01",
		"Sparse risk counts and same-stage repair-tool routes remain exact and disjoint",
		contract_exact,
		{"stage5Risk": stage5_counts, "stage10Risk": stage10_counts, "toolRoutes": tool_routes, "stage5Intersection": stage5_intersection, "stage10Intersection": stage10_intersection}
	)

	finish_suite(gs)
