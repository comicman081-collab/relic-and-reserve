extends SceneTree

## Diagnostic-only Stage 1/5/10 judgment-pressure baseline. This harness reads
## the live runtime registry and GameState APIs, writes one QA JSON report, and
## never changes production source/data or exports/packages the project.

const REPORT_PATH := "res://qa/R3_STAGE_PRESSURE_BASELINE.json"
const AUDITED_STAGES := [1, 5, 10]
const PRICE_PRESET_ORDER := ["FAST", "BALANCED", "HIGH"]
const PRICE_PRESETS := {
	"FAST": {"startingRatio": 0.50, "reserveRatio": 0.60},
	"BALANCED": {"startingRatio": 0.60, "reserveRatio": 0.72},
	"HIGH": {"startingRatio": 0.68, "reserveRatio": 0.82}
}
const AUCTION_SAMPLE_COUNT := 64
const AUCTION_MASTER_SEED_BASE := 930001
const AUCTION_MASTER_SEED_STRIDE := 7919
const AUCTION_FIXTURE_SPEC_ID := "artifact_061"
const AUCTION_FIXTURE_ARTIFACT_SEED := 424242
const AUCTION_FIXTURE_UNIQUE_ID := "stage_pressure_control_fixture"
const AUCTION_FIXTURE_DAY := 4


func _init() -> void:
	call_deferred("run")


func rounded(value: float) -> float:
	return snappedf(value, 0.000001)


func localized_english(value: Variant) -> String:
	if value is Dictionary:
		return String(value.get("en", value.get("ko", "")))
	return String(value)


func approximately(left: float, right: float, tolerance: float = 0.000002) -> bool:
	return absf(left - right) <= tolerance


func case_risk_counts(stage_reports: Dictionary, stage_id: int, case_id: String) -> Dictionary:
	for row_value: Variant in stage_reports.get(str(stage_id), {}).get("evidencePressure", {}).get("cases", []):
		if row_value is Dictionary and String(row_value.get("caseId", "")) == case_id:
			return row_value.get("opportunitiesByRisk", {}).duplicate(true)
	return {}


func spec_required_tools(stage_reports: Dictionary, stage_id: int, spec_id: String) -> Array:
	for row_value: Variant in stage_reports.get(str(stage_id), {}).get("repairToolRoutes", {}).get("specs", []):
		if row_value is Dictionary and String(row_value.get("specId", "")) == spec_id:
			return row_value.get("requiredTools", []).duplicate()
	return []


func numeric_distribution(values: Array) -> Dictionary:
	if values.is_empty():
		return {"count": 0, "min": 0.0, "p50": 0.0, "p90": 0.0, "max": 0.0, "mean": 0.0}
	var ordered: Array = values.duplicate()
	ordered.sort()
	var total := 0.0
	for value: Variant in ordered:
		total += float(value)
	var last_index := ordered.size() - 1
	return {
		"count": ordered.size(),
		"min": rounded(float(ordered[0])),
		"p50": rounded(float(ordered[int(floor(float(last_index) * 0.50))])),
		"p90": rounded(float(ordered[int(floor(float(last_index) * 0.90))])),
		"max": rounded(float(ordered[last_index])),
		"mean": rounded(total / float(ordered.size()))
	}


func evidence_pressure_for_stage(gs: Node, registry: Node, stage_id: int, execution_errors: Array) -> Dictionary:
	var stage_definition: Dictionary = registry.get_stage_definition(stage_id)
	if stage_definition.is_empty():
		execution_errors.append("MISSING_STAGE_DEFINITION:%d" % stage_id)
		return {}
	var opportunities := {"NONE": 0, "LOW": 0, "HIGH": 0}
	var weighted_by_level := {"NONE": 0.0, "LOW": 0.0, "HIGH": 0.0}
	var action_rows: Array = []
	var case_rows: Array = []
	var invalid_levels: Array = []
	for case_id_value: Variant in stage_definition.get("case_ids", []):
		var case_id := String(case_id_value)
		var definition: Dictionary = gs.case_definition(case_id)
		if definition.is_empty():
			execution_errors.append("MISSING_CASE_DEFINITION:%d:%s" % [stage_id, case_id])
			continue
		var case_counts := {"NONE": 0, "LOW": 0, "HIGH": 0}
		var evidence_rows: Array = definition.get("evidence", []) if definition.get("evidence", []) is Array else []
		for evidence_value: Variant in evidence_rows:
			if not evidence_value is Dictionary:
				execution_errors.append("INVALID_EVIDENCE_ROW:%d:%s" % [stage_id, case_id])
				continue
			var evidence: Dictionary = evidence_value
			var risk_level := String(evidence.get("risk", {}).get("level", "NONE")).to_upper()
			if not risk_level in ["NONE", "LOW", "HIGH"]:
				invalid_levels.append({"caseId": case_id, "evidenceId": String(evidence.get("id", "")), "riskLevel": risk_level})
				continue
			var applied_weight := float(gs.investigation_risk_penalty(risk_level, stage_id))
			opportunities[risk_level] = int(opportunities[risk_level]) + 1
			case_counts[risk_level] = int(case_counts[risk_level]) + 1
			weighted_by_level[risk_level] = float(weighted_by_level[risk_level]) + applied_weight
			action_rows.append({
				"caseId": case_id,
				"evidenceId": String(evidence.get("id", "")),
				"riskLevel": risk_level,
				"baseWeight": float({"NONE": 0.0, "LOW": 1.0, "HIGH": 3.0}.get(risk_level, 0.0)),
				"difficultyAppliedWeight": rounded(applied_weight),
				"requiresEvidence": evidence.get("unlock", {}).get("requires_all", []).duplicate(),
				"requiredTools": evidence.get("unlock", {}).get("requires_tools", []).duplicate()
			})
		case_rows.append({
			"caseId": case_id,
			"title": localized_english(definition.get("title", case_id)),
			"schemaVersion": int(definition.get("schema_version", 0)),
			"evidenceActions": evidence_rows.size(),
			"opportunitiesByRisk": case_counts
		})
	if not invalid_levels.is_empty():
		execution_errors.append("INVALID_RISK_LEVELS_STAGE_%d" % stage_id)
	var action_count := action_rows.size()
	var risk_action_count := int(opportunities.LOW) + int(opportunities.HIGH)
	var weighted_total := float(weighted_by_level.NONE) + float(weighted_by_level.LOW) + float(weighted_by_level.HIGH)
	return {
		"caseIds": stage_definition.get("case_ids", []).duplicate(),
		"cases": case_rows,
		"difficultyMultiplier": rounded(float(registry.stage_difficulty_multiplier(stage_id))),
		"baseWeightByRisk": {"NONE": 0.0, "LOW": 1.0, "HIGH": 3.0},
		"difficultyAppliedUnitWeight": {
			"NONE": rounded(float(gs.investigation_risk_penalty("NONE", stage_id))),
			"LOW": rounded(float(gs.investigation_risk_penalty("LOW", stage_id))),
			"HIGH": rounded(float(gs.investigation_risk_penalty("HIGH", stage_id)))
		},
		"evidenceActions": action_count,
		"riskBearingActions": risk_action_count,
		"safeActions": int(opportunities.NONE),
		"opportunitiesByRisk": opportunities,
		"difficultyAppliedWeightByRisk": {
			"NONE": rounded(float(weighted_by_level.NONE)),
			"LOW": rounded(float(weighted_by_level.LOW)),
			"HIGH": rounded(float(weighted_by_level.HIGH))
		},
		"weightedRiskTotal": rounded(weighted_total),
		"weightedRiskPerEvidenceAction": rounded(weighted_total / float(action_count)) if action_count > 0 else 0.0,
		"weightedRiskPerRiskOpportunity": rounded(weighted_total / float(risk_action_count)) if risk_action_count > 0 else 0.0,
		"invalidRiskLevels": invalid_levels,
		"actions": action_rows
	}


func tool_routes_for_stage(registry: Node, stage_id: int, execution_errors: Array) -> Dictionary:
	var definition: Dictionary = registry.get_stage_definition(stage_id)
	var introduced_ids: Array = definition.get("introduced_artifact_ids", []).duplicate()
	if introduced_ids.size() != 2:
		execution_errors.append("INTRODUCED_SPEC_COUNT_NOT_TWO:%d:%d" % [stage_id, introduced_ids.size()])
	var spec_rows: Array = []
	var required_sets: Array = []
	var coverage := {}
	for spec_id_value: Variant in introduced_ids:
		var spec_id := String(spec_id_value)
		var spec: Dictionary = registry.get_spec(spec_id)
		if spec.is_empty():
			execution_errors.append("MISSING_INTRODUCED_SPEC:%d:%s" % [stage_id, spec_id])
			continue
		var required_tools: Array = spec.get("repairProfile", {}).get("requiredTools", []).duplicate()
		required_sets.append(required_tools)
		for tool_value: Variant in required_tools:
			var tool_id := String(tool_value)
			if not coverage.has(tool_id):
				coverage[tool_id] = []
			coverage[tool_id].append(spec_id)
		spec_rows.append({
			"specId": spec_id,
			"displayName": String(spec.get("displayName", spec_id)),
			"requiredTools": required_tools,
			"requiredToolCount": required_tools.size(),
			"toleranceMm": float(spec.get("repairProfile", {}).get("toleranceMm", 0.0))
		})
	var shared_tools: Array = []
	if required_sets.size() == 2:
		for tool_value: Variant in required_sets[0]:
			var tool_id := String(tool_value)
			if required_sets[1].has(tool_id) and not shared_tools.has(tool_id):
				shared_tools.append(tool_id)
	shared_tools.sort()
	var maximum_single_tool_coverage := 0
	for coverage_value: Variant in coverage.values():
		if coverage_value is Array:
			maximum_single_tool_coverage = maxi(maximum_single_tool_coverage, coverage_value.size())
	var single_tool_convergence := introduced_ids.size() == 2 and maximum_single_tool_coverage >= 2
	return {
		"introducedSpecIds": introduced_ids,
		"introducedSpecCountExactTwo": introduced_ids.size() == 2 and spec_rows.size() == 2,
		"specs": spec_rows,
		"requiredToolsIntersection": shared_tools,
		"singleToolCoverage": coverage,
		"maximumSingleToolCoverage": maximum_single_tool_coverage,
		"singleToolConvergence": single_tool_convergence,
		"noSharedOptimalTool": not single_tool_convergence
	}


func controlled_public_fixture(gs: Node) -> Dictionary:
	var artifact: Dictionary = gs.new_artifact(AUCTION_FIXTURE_SPEC_ID, AUCTION_FIXTURE_ARTIFACT_SEED, AUCTION_FIXTURE_UNIQUE_ID)
	artifact["playerHypothesis"] = gs.truth_to_hypothesis(String(artifact.get("authenticityTruth", "UNKNOWN")))
	artifact["confidence"] = 0.78
	artifact["cleanliness"] = 78.0
	artifact["surfaceCondition"] = 78.0
	artifact["structuralCondition"] = 78.0
	artifact["mechanicalCondition"] = 78.0
	artifact["historicalIntegrity"] = 78.0
	artifact["restorationQuality"] = 52.0
	artifact["knownClues"] = ["PROVENANCE"]
	artifact["inspected"] = true
	artifact["caseId"] = ""
	artifact["caseResolved"] = false
	return artifact


func auction_baseline_for_stage(gs: Node, registry: Node, stage_id: int, execution_errors: Array) -> Dictionary:
	gs.current_stage = stage_id
	gs.stage_run_state = gs.default_stage_run_state(stage_id)
	gs.stage_run_state["status"] = "RUNNING"
	gs.day = AUCTION_FIXTURE_DAY
	gs.market_state = gs.default_market_state()
	gs.daily_modifiers = {}
	gs.owned_upgrades = []
	var strategy_rows := {}
	for preset_id: String in PRICE_PRESET_ORDER:
		strategy_rows[preset_id] = {
			"preset": preset_id,
			"startingRatio": float(PRICE_PRESETS[preset_id].startingRatio),
			"reserveRatio": float(PRICE_PRESETS[preset_id].reserveRatio),
			"trials": 0,
			"soldCount": 0,
			"noSaleCount": 0,
			"noBidCount": 0,
			"reserveMissCount": 0,
			"hammerValues": [],
			"hammerToReserveRatios": [],
			"noSaleShortfallRatios": []
		}
	var paired_control_stable := true
	var public_fixture_snapshot: Dictionary = {}
	var public_appraisal := 0
	for sample_index in range(AUCTION_SAMPLE_COUNT):
		var paired_master_seed := AUCTION_MASTER_SEED_BASE + sample_index * AUCTION_MASTER_SEED_STRIDE
		gs.master_seed = paired_master_seed
		var fixture := controlled_public_fixture(gs)
		if fixture.is_empty():
			execution_errors.append("AUCTION_FIXTURE_CREATION_FAILED:%d:%d" % [stage_id, sample_index])
			continue
		var sample_appraisal := int(gs.appraise(fixture))
		if public_appraisal == 0:
			public_appraisal = sample_appraisal
			public_fixture_snapshot = {
				"artifactSpecId": String(fixture.get("artifactSpecId", "")),
				"artifactSeed": int(fixture.get("seed", 0)),
				"uniqueId": String(fixture.get("uniqueId", "")),
				"reportedConfidence": float(fixture.get("confidence", 0.0)),
				"condition": {
					"cleanliness": float(fixture.get("cleanliness", 0.0)),
					"surface": float(fixture.get("surfaceCondition", 0.0)),
					"mechanical": float(fixture.get("mechanicalCondition", 0.0))
				},
				"provenanceKnown": fixture.get("knownClues", []).has("PROVENANCE"),
				"disclosure": "LIKELY",
				"publicAppraisal": sample_appraisal,
				"day": AUCTION_FIXTURE_DAY,
				"grandReserve": false
			}
		elif sample_appraisal != public_appraisal:
			paired_control_stable = false
		var bidder_rows: Array = gs.selected_bidders(fixture, false)
		var expected_bidder_ids: Array = bidder_rows.map(func(bidder_value: Variant): return String(bidder_value.get("id", "")) if bidder_value is Dictionary else "")
		var expected_variances: Array = gs.auction_bidder_variances(fixture, bidder_rows)
		for preset_id: String in PRICE_PRESET_ORDER:
			var artifact: Dictionary = fixture.duplicate(true)
			var preset: Dictionary = PRICE_PRESETS[preset_id]
			var starting := int(float(sample_appraisal) * float(preset.startingRatio))
			var reserve := int(float(sample_appraisal) * float(preset.reserveRatio))
			artifact["listing"] = {
				"starting": starting,
				"reserve": reserve,
				"confidence": float(artifact.get("confidence", 0.0)),
				"disclosure": "LIKELY",
				"publicAppraisal": sample_appraisal
			}
			var actual_variances: Array = gs.auction_bidder_variances(artifact, bidder_rows)
			if not gs.canonical_json_values_equal(expected_variances, actual_variances):
				paired_control_stable = false
			var result: Dictionary = gs.auction_with_bidders(artifact, bidder_rows, false)
			var participant_ids: Array = result.get("participants", []).map(func(participant_value: Variant): return String(participant_value.get("id", "")) if participant_value is Dictionary else "")
			if participant_ids != expected_bidder_ids:
				paired_control_stable = false
			var row: Dictionary = strategy_rows[preset_id]
			row.trials = int(row.trials) + 1
			var sold := bool(result.get("reserve_met", false)) and String(result.get("sale_status", "")) == "SOLD"
			var hammer := int(result.get("hammer", 0))
			row.hammerValues.append(hammer)
			row.hammerToReserveRatios.append(float(hammer) / float(reserve) if reserve > 0 else 0.0)
			if sold:
				row.soldCount = int(row.soldCount) + 1
			else:
				row.noSaleCount = int(row.noSaleCount) + 1
				if hammer <= 0:
					row.noBidCount = int(row.noBidCount) + 1
				else:
					row.reserveMissCount = int(row.reserveMissCount) + 1
				row.noSaleShortfallRatios.append(maxf(0.0, float(reserve - hammer) / float(reserve)) if reserve > 0 else 0.0)
	var strategy_reports := {}
	var viable_strategies: Array = []
	var mixed_outcome_strategies: Array = []
	var no_sale_rates: Array = []
	for preset_id: String in PRICE_PRESET_ORDER:
		var raw: Dictionary = strategy_rows[preset_id]
		var trials := int(raw.trials)
		var sold_count := int(raw.soldCount)
		var no_sale_count := int(raw.noSaleCount)
		var sold_rate := float(sold_count) / float(trials) if trials > 0 else 0.0
		var no_sale_rate := float(no_sale_count) / float(trials) if trials > 0 else 0.0
		var viable := sold_count > 0
		var mixed_outcome := sold_count > 0 and no_sale_count > 0
		if viable:
			viable_strategies.append(preset_id)
		if mixed_outcome:
			mixed_outcome_strategies.append(preset_id)
		no_sale_rates.append(no_sale_rate)
		strategy_reports[preset_id] = {
			"startingRatio": rounded(float(raw.startingRatio)),
			"reserveRatio": rounded(float(raw.reserveRatio)),
			"trials": trials,
			"soldCount": sold_count,
			"noSaleCount": no_sale_count,
			"soldProbability": rounded(sold_rate),
			"noSaleProbability": rounded(no_sale_rate),
			"viable": viable,
			"mixedOutcome": mixed_outcome,
			"noSaleDistribution": {
				"NO_BID": int(raw.noBidCount),
				"RESERVE_MISS": int(raw.reserveMissCount)
			},
			"hammer": numeric_distribution(raw.hammerValues),
			"hammerToReserveRatio": numeric_distribution(raw.hammerToReserveRatios),
			"noSaleShortfallRatio": numeric_distribution(raw.noSaleShortfallRatios)
		}
	var min_no_sale_rate: float = float(no_sale_rates.min()) if not no_sale_rates.is_empty() else 0.0
	var max_no_sale_rate: float = float(no_sale_rates.max()) if not no_sale_rates.is_empty() else 0.0
	return {
		"difficultyMultiplier": rounded(float(registry.stage_difficulty_multiplier(stage_id))),
		"fixture": public_fixture_snapshot,
		"pairedSeedPlan": {
			"sampleCount": AUCTION_SAMPLE_COUNT,
			"masterSeedBase": AUCTION_MASTER_SEED_BASE,
			"masterSeedStride": AUCTION_MASTER_SEED_STRIDE,
			"artifactSeed": AUCTION_FIXTURE_ARTIFACT_SEED
		},
		"pairedControlStable": paired_control_stable,
		"strategies": strategy_reports,
		"viableStrategyDefinition": "soldCount > 0 in the deterministic paired sample",
		"viableStrategies": viable_strategies,
		"viableStrategyCount": viable_strategies.size(),
		"atLeastTwoViableStrategies": viable_strategies.size() >= 2,
		"mixedOutcomeStrategies": mixed_outcome_strategies,
		"noSaleProbabilitySpread": rounded(max_no_sale_rate - min_no_sale_rate)
	}


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.reset_game()
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	var execution_errors: Array = []
	var stage_reports := {}
	for stage_id: int in AUDITED_STAGES:
		var evidence_pressure := evidence_pressure_for_stage(gs, registry, stage_id, execution_errors)
		var tool_routes := tool_routes_for_stage(registry, stage_id, execution_errors)
		var auction_baseline := auction_baseline_for_stage(gs, registry, stage_id, execution_errors)
		stage_reports[str(stage_id)] = {
			"stageId": stage_id,
			"title": localized_english(registry.get_stage_definition(stage_id).get("title", {})),
			"evidencePressure": evidence_pressure,
			"repairToolRoutes": tool_routes,
			"controlledAuction": auction_baseline,
			"gates": {
				"noSharedOptimalTool": bool(tool_routes.get("noSharedOptimalTool", false)),
				"atLeastTwoViableStrategies": bool(auction_baseline.get("atLeastTwoViableStrategies", false)),
				"pairedAuctionControlStable": bool(auction_baseline.get("pairedControlStable", false))
			},
			"needsTuning": not bool(tool_routes.get("noSharedOptimalTool", false)) or not bool(auction_baseline.get("atLeastTwoViableStrategies", false))
		}
	var pressure_1 := float(stage_reports.get("1", {}).get("evidencePressure", {}).get("weightedRiskPerEvidenceAction", 0.0))
	var pressure_5 := float(stage_reports.get("5", {}).get("evidencePressure", {}).get("weightedRiskPerEvidenceAction", 0.0))
	var pressure_10 := float(stage_reports.get("10", {}).get("evidencePressure", {}).get("weightedRiskPerEvidenceAction", 0.0))
	var risk_10_gt_5 := pressure_10 > pressure_5
	var risk_5_gte_1 := pressure_5 >= pressure_1
	var risk_progression := risk_10_gt_5 and risk_5_gte_1
	var no_shared_tool := AUDITED_STAGES.all(func(stage_id: Variant): return bool(stage_reports.get(str(int(stage_id)), {}).get("repairToolRoutes", {}).get("noSharedOptimalTool", false)))
	var at_least_two_strategies := AUDITED_STAGES.all(func(stage_id: Variant): return bool(stage_reports.get(str(int(stage_id)), {}).get("controlledAuction", {}).get("atLeastTwoViableStrategies", false)))
	var paired_controls_stable := AUDITED_STAGES.all(func(stage_id: Variant): return bool(stage_reports.get(str(int(stage_id)), {}).get("controlledAuction", {}).get("pairedControlStable", false)))
	var gates := {
		"stage10RiskGreaterThanStage5": risk_10_gt_5,
		"stage5RiskGreaterThanOrEqualToStage1": risk_5_gte_1,
		"riskProgressionStage10GtStage5GteStage1": risk_progression,
		"noSharedOptimalToolAcrossIntroducedPairs": no_shared_tool,
		"atLeastTwoViableAuctionStrategiesEveryStage": at_least_two_strategies,
		"pairedAuctionControlsStable": paired_controls_stable
	}
	# The exact baseline includes the two authored Stage 1 bookends and the two
	# Stage 10 master cases. Passive opening observations are safe; each new case
	# retains one genuinely destructive HIGH-risk follow-up.
	var risk_values_exact: bool = approximately(pressure_1, 0.764706) \
		and approximately(pressure_5, 0.819248) \
		and approximately(pressure_10, 1.225639) \
		and pressure_10 > pressure_5 and pressure_5 > pressure_1
	var stage5_fallback_risk_exact: bool = case_risk_counts(stage_reports, 5, "collector_promise") == {"NONE": 4, "LOW": 1, "HIGH": 0} \
		and case_risk_counts(stage_reports, 5, "three_cameras") == {"NONE": 4, "LOW": 1, "HIGH": 0}
	var stage10_risk_exact: bool = stage_reports.get("10", {}).get("evidencePressure", {}).get("opportunitiesByRisk", {}) == {"NONE": 8, "LOW": 2, "HIGH": 2}
	var risk_sparsity_exact: bool = stage5_fallback_risk_exact and stage10_risk_exact
	var tool_routes_exact: bool = spec_required_tools(stage_reports, 5, "artifact_069") == ["precision_screwdriver", "reference_database"] \
		and spec_required_tools(stage_reports, 5, "artifact_070") == ["cleaning_cloth", "precision_scale", "repair_toolkit"] \
		and spec_required_tools(stage_reports, 10, "artifact_079") == ["material_scanner", "uv_lamp"] \
		and spec_required_tools(stage_reports, 10, "artifact_080") == ["precision_scale", "precision_screwdriver", "reference_database"] \
		and stage_reports.get("5", {}).get("repairToolRoutes", {}).get("requiredToolsIntersection", []) == [] \
		and stage_reports.get("10", {}).get("repairToolRoutes", {}).get("requiredToolsIntersection", []) == []
	var auction_control_unchanged: bool = true
	for stage_id: int in AUDITED_STAGES:
		var strategies: Dictionary = stage_reports.get(str(stage_id), {}).get("controlledAuction", {}).get("strategies", {})
		auction_control_unchanged = auction_control_unchanged \
			and int(strategies.get("FAST", {}).get("soldCount", -1)) == 64 \
			and int(strategies.get("BALANCED", {}).get("soldCount", -1)) == 53 \
			and int(strategies.get("HIGH", {}).get("soldCount", -1)) == 45 \
			and bool(stage_reports.get(str(stage_id), {}).get("controlledAuction", {}).get("pairedControlStable", false))
	var scope_identity_and_execution: bool = execution_errors.is_empty() \
		and stage_reports.get("1", {}).get("evidencePressure", {}).get("opportunitiesByRisk", {}) == {"NONE": 10, "LOW": 4, "HIGH": 3} \
		and registry.get_stage_definition(5).get("case_ids", []) == ["collector_promise", "three_cameras", "shadow_camera"] \
		and registry.get_stage_definition(10).get("case_ids", []) == ["master_camera", "master_mechanism"] \
		and registry.get_stage_definition(5).get("introduced_artifact_ids", []) == ["artifact_069", "artifact_070"] \
		and registry.get_stage_definition(10).get("introduced_artifact_ids", []) == ["artifact_079", "artifact_080"] \
		and approximately(float(registry.stage_difficulty_multiplier(5)), pow(1.07, 4)) \
		and approximately(float(registry.stage_difficulty_multiplier(10)), pow(1.07, 9))
	var acceptance := {
		"riskValuesAndOrdering": risk_values_exact,
		"riskSparsity": risk_sparsity_exact,
		"toolRoutesAndIntersections": tool_routes_exact,
		"pairedAuctionControlUnchanged": auction_control_unchanged,
		"scopeIdentityAndExecution": scope_identity_and_execution
	}
	var acceptance_passed: bool = acceptance.values().all(func(value: Variant): return bool(value))
	var tuning_flags: Array = []
	if not risk_progression:
		tuning_flags.append("RISK_PROGRESSION_STAGE10_GT_STAGE5_GTE_STAGE1_NOT_MET")
	for stage_id: int in AUDITED_STAGES:
		var stage_report: Dictionary = stage_reports[str(stage_id)]
		if not bool(stage_report.get("repairToolRoutes", {}).get("noSharedOptimalTool", false)):
			tuning_flags.append("SHARED_OPTIMAL_TOOL_STAGE_%02d" % stage_id)
		if not bool(stage_report.get("controlledAuction", {}).get("atLeastTwoViableStrategies", false)):
			tuning_flags.append("FEWER_THAN_TWO_VIABLE_AUCTION_STRATEGIES_STAGE_%02d" % stage_id)
		if not bool(stage_report.get("controlledAuction", {}).get("pairedControlStable", false)):
			tuning_flags.append("UNSTABLE_PAIRED_AUCTION_CONTROL_STAGE_%02d" % stage_id)
	var report := {
		"schemaVersion": 1,
		"suite": "R3 Stage 1/5/10 Judgment Pressure Baseline",
		"diagnosticOnly": true,
		"auditedStages": AUDITED_STAGES,
		"methodology": {
			"riskMetric": "sum(investigation_risk_penalty(level, stage)) / evidence action count",
			"riskWeights": {"NONE": 0.0, "LOW": 1.0, "HIGH": 3.0},
			"toolConvergence": "A single allowed requiredTools id appears in both introduced ArtifactSpecs",
			"auctionControl": "One fixed public artifact fixture and identical paired master-seed vector for FAST/BALANCED/HIGH and all audited stages; only stage difficulty and listing price ratios differ",
			"pricePresetRatios": PRICE_PRESETS,
			"viableStrategy": "At least one SOLD result in 64 deterministic paired trials",
			"gateFailuresDoNotFailExecution": true
		},
		"stages": stage_reports,
		"riskProgressionInputs": {"stage1": rounded(pressure_1), "stage5": rounded(pressure_5), "stage10": rounded(pressure_10)},
		"gates": gates,
		"acceptance": acceptance,
		"acceptancePassed": acceptance_passed,
		"executed": acceptance.size(),
		"passed": acceptance.values().count(true),
		"failed": acceptance.values().count(false),
		"skipped": 0,
		"needsTuning": not risk_progression or not no_shared_tool or not at_least_two_strategies or not paired_controls_stable,
		"tuningFlags": tuning_flags,
		"execution": {
			"completed": execution_errors.is_empty() and stage_reports.size() == AUDITED_STAGES.size(),
			"errors": execution_errors
		}
	}
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output == null:
		push_error("Could not open stage pressure report: %s" % REPORT_PATH)
		quit(1)
		return
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	gs.persistence_enabled = false
	quit(0 if execution_errors.is_empty() else 1)
