extends Node

signal state_changed
signal campaign_changed
signal stage_changed
signal profile_changed

const SAVE_PATH := "user://relic_reserve_save.json"
const PROFILE_PATH := "user://relic_reserve_profile.json"
const SAVE_TEMP_SUFFIX := ".tmp"
const SAVE_BACKUP_SUFFIX := ".bak"
const PROFILE_SCHEMA_VERSION := 1
const STAGE_TELEMETRY_STRATEGIES := ["FAST", "BALANCED", "HIGH", "AUTO_GRAND_RESERVE", "CUSTOM", "LEGACY_UNKNOWN"]
const SAVE_CRASH_TEST_POINTS := [
	"A_TMP_WRITE_INTERRUPTION",
	"B_TMP_COMPLETE_BEFORE_VALIDATION",
	"C_TMP_VALIDATED_BEFORE_BACKUP",
	"D_AFTER_BACKUP_BEFORE_PROMOTE",
	"E_AFTER_PROMOTE_BEFORE_FINAL_VALIDATION",
	"F_CORRUPT_PROMOTED_CURRENT"
]
const HYPOTHESES := [
	"GENUINE",
	"GENUINE_WITH_PERIOD_REPAIR",
	"GENUINE_WITH_MODERN_REPAIR",
	"REPRODUCTION",
	"FORGERY",
	"UNKNOWN"
]
const RARITY_MULTIPLIERS := {
	"common": 1.0,
	"uncommon": 1.25,
	"rare": 1.65,
	"very_rare": 2.2
}
const MUTABLE_INSTANCE_KEYS := [
	"uniqueId", "artifactSpecId", "seed", "authenticityTruth", "originalParts",
	"replacementParts", "damageInstances", "knownClues", "evidence", "playerHypothesis",
	"confidence", "cleanliness", "surfaceCondition", "structuralCondition",
	"mechanicalCondition", "historicalIntegrity", "restorationQuality", "acquisitionPrice",
	"restorationCost", "estimatedValue", "rotation", "zoom", "inspected", "repaired",
	"partStates", "listing", "sold", "caseId", "storyArtifactId", "caseResolved",
	"possibleClues"
]

var save_version := 6
var game_version := "R3"
var money: int = 1200
var reputation: int = 12
var day: int = 1
var inventory: Array = []
var active_workpiece: Dictionary = {}
var transactions: Array = []
var auction_history: Array = []
var statistics: Dictionary = {}
var market_state: Dictionary = {}
var market_roster: Array = []
var market_roster_day: int = 0
var master_seed: int = 481516
var rng := RandomNumberGenerator.new()
var instance_counter: int = 0
var selected_tool := "soft_brush"
var owned_upgrades: Array = []
var language := "en"
var current_event_id := ""
var event_history: Array = []
var daily_modifiers: Dictionary = {}
var pending_auction: Dictionary = {}
var grand_reserve_session: Dictionary = {}
var last_action_error := ""
var campaign_state: Dictionary = {}
var current_stage: int = 1
var stage_run_state: Dictionary = {}
var player_profile: Dictionary = {}
var campaign_test_mode := false
var persistence_enabled := true
var last_load_recovered := false
var last_load_error := ""
var last_save_error := ""
var _save_crash_injection_for_test := ""
var last_profile_load_recovered := false
var last_profile_load_error := ""
var last_profile_save_error := ""
var last_profile_reconciled_from_run := false
var _profile_crash_injection_for_test := ""


func _ready() -> void:
	rng.seed = master_seed
	if statistics.is_empty():
		statistics = default_statistics()
	if market_state.is_empty():
		market_state = default_market_state()
	if campaign_state.is_empty():
		campaign_state = default_campaign_state()
	if player_profile.is_empty():
		player_profile = default_player_profile()
	if pending_auction.is_empty():
		pending_auction = default_pending_auction()
	if grand_reserve_session.is_empty():
		grand_reserve_session = default_grand_reserve_session()
	if stage_run_state.is_empty():
		stage_run_state = default_stage_run_state(current_stage)
	if FileAccess.file_exists(PROFILE_PATH) or FileAccess.file_exists(PROFILE_PATH + SAVE_BACKUP_SUFFIX):
		load_profile()
	if market_roster.is_empty():
		generate_market_roster()


func default_statistics() -> Dictionary:
	return {
		"purchases": 0, "sales": 0, "no_sales": 0, "profit": 0,
		"discoveries": 0, "restorations": 0, "forgeries_detected": 0,
		"authentication_attempts": 0, "authentication_correct": 0,
		"total_auction_revenue": 0, "biggest_profit": 0, "biggest_loss": 0,
		"museum_acquisitions": 0, "original_parts_preserved": 0,
		"commissions": 0, "days_operated": 1
	}


## Every authoritative cash mutation is represented by one append-only ledger row.
## The row stores the before/after balance so UI and audit tooling can explain a
## transaction without reconstructing history from unrelated state.
func append_money_transaction(transaction_type: String, item: String, amount: int, instance_id: String = "", cause: String = "") -> Dictionary:
	var money_after := money
	var money_before := money_after - amount
	var transaction_id := "money_%d_%s_%d" % [day, transaction_type, transactions.size()]
	var row := {
		"id": transaction_id,
		"day": day,
		"type": transaction_type,
		"item": item,
		"amount": amount,
		"moneyBefore": money_before,
		"moneyAfter": money_after
	}
	if not instance_id.is_empty():
		row["instanceId"] = instance_id
	if not cause.is_empty():
		row["cause"] = cause
	transactions.append(row)
	return row


func restoration_cost_units(raw_cost: float) -> int:
	if not is_finite(raw_cost):
		return 0
	return maxi(0, roundi(raw_cost))


func can_pay_restoration_cost(cost: int) -> bool:
	if cost <= 0:
		return true
	if money < cost:
		last_action_error = "INSUFFICIENT_FUNDS"
		return false
	return true


func charge_restoration_cost(artifact: Dictionary, cost: int, action: String) -> bool:
	if not can_pay_restoration_cost(cost):
		return false
	if cost <= 0:
		return true
	money -= cost
	append_money_transaction("restoration", String(artifact.get("displayName", "Artifact")), -cost, String(artifact.get("uniqueId", "")), action)
	return true


func default_stage_telemetry(budget_basis: int = -1) -> Dictionary:
	var resolved_budget := maxi(1, money if budget_basis < 0 else budget_basis)
	var strategy_counts := {}
	for strategy_id: String in STAGE_TELEMETRY_STRATEGIES:
		strategy_counts[strategy_id] = 0
	return {
		"budgetBasis": resolved_budget,
		"repairActions": 0,
		"repairCostAccrued": 0.0,
		"repairToolUseCounts": {},
		"investigationActions": 0,
		"investigationRiskActions": 0,
		"investigationRiskWeightSum": 0.0,
		"listingStrategyCounts": strategy_counts,
		"auctionCount": 0,
		"noSaleCount": 0,
		"relistCount": 0,
		"artifactSalesCount": 0
	}


func default_market_state() -> Dictionary:
	return {
		"mechanical_instruments": 10, "vintage_audio": 14, "optical_devices": 6,
		"ceramics": -4, "office_machines": 8, "scientific_instruments": 11,
		"decorative_objects": 2, "telephony": 7
	}


func default_player_profile() -> Dictionary:
	return {
		"schema_version": PROFILE_SCHEMA_VERSION,
		"highestUnlockedStage": 1,
		"clearedStages": [],
		"stageBest": {},
		"tutorialCompletedSteps": []
	}


func default_stage_run_state(stage_id: int = 1) -> Dictionary:
	var normalized_stage := clampi(stage_id, 1, 10)
	var definition: Dictionary = RuntimeRegistry.get_stage_definition(normalized_stage)
	return {
		"stageId": normalized_stage,
		"status": "NOT_STARTED",
		"difficultyMultiplier": RuntimeRegistry.stage_difficulty_multiplier(normalized_stage),
		"caseIds": definition.get("case_ids", []).duplicate(),
		"grandReserveRequired": bool(definition.get("includes_grand_reserve", false)),
		"startedAtDay": 0,
		"completedAtDay": 0,
		"score": 0.0,
		"lastPerformance": {},
		"stageReplayFeedbackSnapshot": {},
		# Stage pressure telemetry is separate from the established three-axis
		# score. It records only public player actions and is frozen on clear.
		"telemetryAvailable": true,
		"telemetry": default_stage_telemetry(),
		"telemetrySeenIds": [],
		"stageReplayTelemetrySnapshot": {},
		# Completion feedback is an explicit, durable hand-off boundary. In
		# particular, Stage 10 must show its public replay feedback before the
		# already-calculated ending is presented.
		"stageClearAcknowledged": false,
		# Run-authoritative mirror. It is saved atomically with the gameplay action
		# that completed each tutorial step, then copied to the profile.
		"tutorialCompletedSteps": []
	}


func normalize_stage_run_dictionary(target: Dictionary, stage_id: int) -> void:
	var defaults := default_stage_run_state(stage_id)
	merge_missing_dictionary(target, defaults)
	target.stageId = stage_id
	target.status = String(target.get("status", "NOT_STARTED"))
	if not target.status in ["NOT_STARTED", "RUNNING", "CLEARED"]:
		target.status = "NOT_STARTED"
	target.difficultyMultiplier = stage_difficulty_multiplier(stage_id)
	target.caseIds = defaults.caseIds.duplicate()
	target.grandReserveRequired = bool(defaults.grandReserveRequired)
	target.startedAtDay = int(target.get("startedAtDay", 0))
	target.completedAtDay = int(target.get("completedAtDay", 0))
	target.score = maxf(0.0, float(target.get("score", 0.0)))
	target.lastPerformance = normalize_stage_performance_snapshot(target.get("lastPerformance", {}), stage_id)
	target.stageReplayFeedbackSnapshot = normalize_stage_replay_feedback_snapshot(target.get("stageReplayFeedbackSnapshot", {}), stage_id)
	target.telemetryAvailable = bool(target.get("telemetryAvailable", false))
	target.telemetry = normalize_stage_telemetry(target.get("telemetry", {}), money)
	target.telemetrySeenIds = normalize_stage_telemetry_seen_ids(target.get("telemetrySeenIds", []))
	target.stageReplayTelemetrySnapshot = normalize_stage_replay_telemetry_snapshot(target.get("stageReplayTelemetrySnapshot", {}), stage_id)
	target.stageClearAcknowledged = bool(target.get("stageClearAcknowledged", false))
	target.tutorialCompletedSteps = _normalized_tutorial_completed_steps(target.get("tutorialCompletedSteps", [])) if stage_id == int(_tutorial_contract().get("stage_id", 1)) else []


func normalize_stage_telemetry(value: Variant, fallback_budget_basis: int = 1) -> Dictionary:
	var normalized := default_stage_telemetry(fallback_budget_basis)
	if not value is Dictionary:
		return normalized
	var source: Dictionary = value
	for count_key: String in ["repairActions", "investigationActions", "investigationRiskActions", "auctionCount", "noSaleCount", "relistCount", "artifactSalesCount"]:
		var count_value: Variant = source.get(count_key, 0)
		if count_value is int or count_value is float:
			normalized[count_key] = maxi(0, int(count_value))
	var budget_value: Variant = source.get("budgetBasis", fallback_budget_basis)
	if budget_value is int or budget_value is float:
		normalized.budgetBasis = maxi(1, int(budget_value))
	for float_key: String in ["repairCostAccrued", "investigationRiskWeightSum"]:
		var float_value: Variant = source.get(float_key, 0.0)
		if (float_value is int or float_value is float) and is_finite(float(float_value)):
			normalized[float_key] = maxf(0.0, float(float_value))
	var tool_counts_value: Variant = source.get("repairToolUseCounts", {})
	if tool_counts_value is Dictionary:
		var tool_counts := {}
		for tool_value: Variant in tool_counts_value.keys():
			var tool_id := String(tool_value)
			var usage_value: Variant = tool_counts_value.get(tool_value, 0)
			if tool_id.is_empty() or (not usage_value is int and not usage_value is float):
				continue
			var usage_count := maxi(0, int(usage_value))
			if usage_count > 0:
				tool_counts[tool_id] = usage_count
		normalized.repairToolUseCounts = tool_counts
	var strategy_counts_value: Variant = source.get("listingStrategyCounts", {})
	if strategy_counts_value is Dictionary:
		for strategy_id: String in STAGE_TELEMETRY_STRATEGIES:
			var strategy_value: Variant = strategy_counts_value.get(strategy_id, 0)
			if strategy_value is int or strategy_value is float:
				normalized.listingStrategyCounts[strategy_id] = maxi(0, int(strategy_value))
	return normalized


func normalize_stage_telemetry_seen_ids(value: Variant) -> Array:
	var normalized: Array = []
	if not value is Array:
		return normalized
	for id_value: Variant in value:
		if not id_value is String:
			continue
		var action_id := String(id_value)
		if action_id.is_empty() or normalized.has(action_id):
			continue
		normalized.append(action_id)
		if normalized.size() >= 4096:
			break
	return normalized


func _stage_telemetry_event_claim(action_id: String) -> bool:
	if action_id.is_empty() \
		or String(stage_run_state.get("status", "")) != "RUNNING" \
		or int(stage_run_state.get("stageId", 0)) != current_stage \
		or not bool(stage_run_state.get("telemetryAvailable", false)):
		return false
	stage_run_state.telemetry = normalize_stage_telemetry(stage_run_state.get("telemetry", {}), money)
	stage_run_state.telemetrySeenIds = normalize_stage_telemetry_seen_ids(stage_run_state.get("telemetrySeenIds", []))
	var seen_ids: Array = stage_run_state.telemetrySeenIds
	if seen_ids.has(action_id):
		return false
	seen_ids.append(action_id)
	stage_run_state.telemetrySeenIds = seen_ids
	return true


func _record_restoration_telemetry(action_id: String, cost_delta: float, tool_id: String = "") -> bool:
	if not _stage_telemetry_event_claim("RESTORE|%s" % action_id):
		return false
	var telemetry: Dictionary = stage_run_state.telemetry
	telemetry.repairActions = int(telemetry.get("repairActions", 0)) + 1
	telemetry.repairCostAccrued = maxf(0.0, float(telemetry.get("repairCostAccrued", 0.0)) + maxf(0.0, cost_delta))
	if not tool_id.is_empty():
		var tool_counts: Dictionary = telemetry.get("repairToolUseCounts", {})
		tool_counts[tool_id] = int(tool_counts.get(tool_id, 0)) + 1
		telemetry.repairToolUseCounts = tool_counts
	stage_run_state.telemetry = telemetry
	return true


func _record_investigation_telemetry(case_id: String, evidence_id: String, risk_penalty: float) -> bool:
	if not _stage_telemetry_event_claim("INVESTIGATE|%s|%s" % [case_id, evidence_id]):
		return false
	var telemetry: Dictionary = stage_run_state.telemetry
	telemetry.investigationActions = int(telemetry.get("investigationActions", 0)) + 1
	if risk_penalty > 0.0:
		telemetry.investigationRiskActions = int(telemetry.get("investigationRiskActions", 0)) + 1
		telemetry.investigationRiskWeightSum = maxf(0.0, float(telemetry.get("investigationRiskWeightSum", 0.0)) + risk_penalty)
	stage_run_state.telemetry = telemetry
	return true


func listing_strategy_id_from_decisions(decisions: Dictionary, grand_reserve: bool = false) -> String:
	if grand_reserve or bool(decisions.get("grandReserve", false)):
		return "AUTO_GRAND_RESERVE"
	var appraisal := int(decisions.get("publicAppraisal", 0))
	if appraisal <= 0:
		return "LEGACY_UNKNOWN"
	var starting := int(decisions.get("starting", 0))
	var reserve := int(decisions.get("reserve", 0))
	var presets := {
		"FAST": Vector2(0.50, 0.60),
		"BALANCED": Vector2(0.60, 0.72),
		"HIGH": Vector2(0.68, 0.82)
	}
	for strategy_id: String in ["FAST", "BALANCED", "HIGH"]:
		var ratios: Vector2 = presets[strategy_id]
		if starting == int(float(appraisal) * ratios.x) and reserve == int(float(appraisal) * ratios.y):
			return strategy_id
	return "CUSTOM"


func _artifact_has_prior_no_sale(instance_id: String) -> bool:
	if instance_id.is_empty():
		return false
	for history_value: Variant in auction_history:
		if not history_value is Dictionary:
			continue
		var history: Dictionary = history_value
		if String(history.get("instanceId", "")) == instance_id and String(history.get("status", "")) == "NO_SALE":
			return true
	return false


func _record_listing_telemetry(pending_state: Dictionary) -> bool:
	var transaction_id := String(pending_state.get("transactionId", ""))
	if not _stage_telemetry_event_claim("LISTING|%s" % transaction_id):
		return false
	var telemetry: Dictionary = stage_run_state.telemetry
	var decisions: Dictionary = pending_state.get("decisions", {}) if pending_state.get("decisions", {}) is Dictionary else {}
	var strategy_id := listing_strategy_id_from_decisions(decisions, bool(pending_state.get("grandReserve", false)))
	var strategy_counts: Dictionary = telemetry.get("listingStrategyCounts", {})
	strategy_counts[strategy_id] = int(strategy_counts.get(strategy_id, 0)) + 1
	telemetry.listingStrategyCounts = strategy_counts
	if _artifact_has_prior_no_sale(String(pending_state.get("artifactId", ""))):
		telemetry.relistCount = int(telemetry.get("relistCount", 0)) + 1
	stage_run_state.telemetry = telemetry
	return true


func _record_auction_telemetry(result: Dictionary) -> bool:
	var transaction_id := String(result.get("transactionId", ""))
	if not _stage_telemetry_event_claim("AUCTION|%s" % transaction_id):
		return false
	var telemetry: Dictionary = stage_run_state.telemetry
	telemetry.auctionCount = int(telemetry.get("auctionCount", 0)) + 1
	if bool(result.get("reserve_met", false)):
		telemetry.artifactSalesCount = int(telemetry.get("artifactSalesCount", 0)) + 1
	else:
		telemetry.noSaleCount = int(telemetry.get("noSaleCount", 0)) + 1
	stage_run_state.telemetry = telemetry
	return true


func normalize_stage_performance_snapshot(value: Variant, stage_id: int) -> Dictionary:
	if not value is Dictionary or value.is_empty():
		return {}
	var definition: Dictionary = RuntimeRegistry.get_stage_definition(stage_id)
	if definition.is_empty():
		return {}
	var target_definition: Dictionary = definition.get("performance_target", {})
	var bounds := _stage_public_score_bounds()
	var current_value: Variant = value.get("current", 0.0)
	var target_value: Variant = value.get("target", target_definition.get("target_score", bounds.x))
	var best_value: Variant = value.get("best", 0.0)
	if (not current_value is int and not current_value is float) or (not target_value is int and not target_value is float) or (not best_value is int and not best_value is float):
		return {}
	var current_score := clampf(float(current_value), bounds.x, bounds.y)
	var target_score := clampf(float(target_value), bounds.x, bounds.y)
	return {
		"current": current_score,
		"target": target_score,
		"gradeId": _stage_grade_id_for_score(definition, current_score),
		"metTarget": _stage_performance_target_met(target_definition, current_score, target_score),
		"isNewBest": bool(value.get("isNewBest", false)),
		"best": maxf(0.0, float(best_value))
	}


func normalize_stage_replay_feedback_snapshot(value: Variant, stage_id: int) -> Dictionary:
	if not value is Dictionary or value.is_empty():
		return {}
	var source: Dictionary = value
	var source_axes_value: Variant = source.get("axes", {})
	if not source_axes_value is Dictionary:
		return {}
	var source_axes: Dictionary = source_axes_value
	var normalized_axes := {}
	for axis_id: String in ["investigation", "preservation", "sale"]:
		var source_axis_value: Variant = source_axes.get(axis_id, {})
		if not source_axis_value is Dictionary:
			return {}
		var source_axis: Dictionary = source_axis_value
		var available := bool(source_axis.get("available", false))
		var score_value: Variant = source_axis.get("value", null)
		var normalized_value: Variant = null
		if available:
			if not score_value is int and not score_value is float:
				return {}
			normalized_value = clampf(float(score_value), 0.0, 100.0)
		elif axis_id != "sale":
			normalized_value = clampf(float(score_value), 0.0, 100.0) if score_value is int or score_value is float else 0.0
		var unavailable_code := "NO_ATTEMPTS" if axis_id == "sale" else "UNAVAILABLE"
		normalized_axes[axis_id] = {
			"value": normalized_value,
			"available": available,
			"statusCode": _stage_replay_status_code(float(normalized_value) if available else 0.0, available, unavailable_code)
		}
	var weakest := String(source.get("weakest", ""))
	if not normalized_axes.has(weakest) or not bool(normalized_axes.get(weakest, {}).get("available", false)):
		weakest = ""
	var advice_code: String = String({
		"investigation": "STRENGTHEN_EVIDENCE",
		"preservation": "PROTECT_CONDITION",
		"sale": "IMPROVE_SALE"
	}.get(weakest, "NONE"))
	return {
		"stage": clampi(stage_id, 1, 10),
		"axes": normalized_axes,
		"weakest": weakest,
		"adviceCode": advice_code
	}


func normalize_stage_replay_telemetry_snapshot(value: Variant, stage_id: int) -> Dictionary:
	if not value is Dictionary or value.is_empty() or not bool(value.get("available", false)):
		return {}
	var source: Dictionary = value
	var numeric_keys := [
		"repairResourcePressure", "investigationRiskRate", "investigationRiskWeightSum",
		"noSaleRate", "toolConcentration", "repairCostAccrued"
	]
	var normalized := {"stage": clampi(stage_id, 1, 10), "available": true}
	for numeric_key: String in numeric_keys:
		var numeric_value: Variant = source.get(numeric_key, null)
		if (not numeric_value is int and not numeric_value is float) or not is_finite(float(numeric_value)) or float(numeric_value) < 0.0:
			return {}
		normalized[numeric_key] = float(numeric_value)
	for count_key: String in ["investigationActions", "investigationRiskActions", "listingCount", "auctionCount", "noSaleCount", "relistCount", "artifactSalesCount", "repairActions"]:
		var count_value: Variant = source.get(count_key, null)
		if (not count_value is int and not count_value is float) or int(count_value) < 0:
			return {}
		normalized[count_key] = int(count_value)
	var distribution_value: Variant = source.get("listingStrategyDistribution", null)
	if not distribution_value is Dictionary:
		return {}
	var distribution := {}
	for strategy_id: String in STAGE_TELEMETRY_STRATEGIES:
		var share_value: Variant = distribution_value.get(strategy_id, null)
		if (not share_value is int and not share_value is float) or not is_finite(float(share_value)) or float(share_value) < 0.0 or float(share_value) > 1.0:
			return {}
		distribution[strategy_id] = float(share_value)
	normalized.listingStrategyDistribution = distribution
	var tool_ids_value: Variant = source.get("repairToolIdsUsed", null)
	if not tool_ids_value is Array:
		return {}
	var tool_ids: Array = []
	for tool_value: Variant in tool_ids_value:
		if not tool_value is String or String(tool_value).is_empty() or tool_ids.has(String(tool_value)):
			return {}
		tool_ids.append(String(tool_value))
	normalized.repairToolIdsUsed = tool_ids
	normalized.dominantToolId = String(source.get("dominantToolId", ""))
	if not normalized.dominantToolId.is_empty() and not tool_ids.has(normalized.dominantToolId):
		return {}
	var summary_codes_value: Variant = source.get("summaryCodes", null)
	if not summary_codes_value is Array:
		return {}
	var summary_codes: Array = []
	for code_value: Variant in summary_codes_value:
		if not code_value is String or String(code_value).is_empty() or summary_codes.has(String(code_value)):
			return {}
		summary_codes.append(String(code_value))
		if summary_codes.size() >= 2:
			break
	normalized.summaryCodes = summary_codes
	return normalized


func default_campaign_state() -> Dictionary:
	var relationships := {}
	for npc_id: String in RuntimeRegistry.npcs.keys():
		var npc: Dictionary = RuntimeRegistry.npcs[npc_id]
		relationships[npc_id] = {
			"relationship": int(npc.get("startingRelationship", 0)),
			"trust": int(npc.get("startingTrust", 0))
		}
	return {
		"schemaVersion": 2,
		"currentAct": "PROLOGUE",
		"activeCaseId": "",
		"caseStates": {},
		"caseArtifactLedger": {},
		"completedCommissionIds": [],
		"commissionArtifactUses": {},
		"storyFlags": {},
		"completedCases": {},
		"caseOutcomes": {},
		"completedActs": {},
		"relationships": relationships,
		"workshopGrade": 1,
		"unlockedModules": ["basic_bench"],
		"mastery": {"MECHANICAL": 0, "OPTICAL": 0, "ELECTRICAL": 0, "DECORATIVE": 0, "SCIENTIFIC": 0, "DOCUMENTARY": 0},
		"museumTrust": 0,
		"collectorNetwork": 0,
		"historicalIntegrity": 50,
		"ethics": 60,
		"grandReserve": {"invited": false, "selectedLotIds": [], "results": [], "score": {}, "completed": false},
		"endingMetrics": {},
		"endingUnlocked": [],
		"currentEnding": "",
		"epilogueSeen": false,
		"postGame": false
	}


func default_pending_auction() -> Dictionary:
	return {
		"schemaVersion": 1,
		"status": "NONE",
		"transactionId": "",
		"artifactId": "",
		"publicFingerprint": "",
		"decisions": {},
		"result": {},
		"receipt": {},
		"cueQueue": [],
		"cueIndex": 0,
		"createdDay": 0,
		"grandReserve": false
	}


func default_grand_reserve_session() -> Dictionary:
	return {
		"schemaVersion": 1,
		"reserveRunId": "",
		"phase": "IDLE",
		"lotUids": [],
		"receipts": [],
		"currentLotIndex": -1,
		"activeTransactionId": "",
		"activeArtifact": {},
		"finalizationReceiptId": ""
	}


func canonicalize_json_numeric_tree(value: Variant) -> Variant:
	# Godot's JSON reader materializes authored integers as floats in nested
	# Variants. Canonicalizing integral floats makes a saved/restored public cue
	# byte-for-byte equivalent to the in-memory cue shown before the save.
	if value is Dictionary:
		var normalized_dictionary := {}
		for key_value: Variant in value.keys():
			normalized_dictionary[key_value] = canonicalize_json_numeric_tree(value[key_value])
		return normalized_dictionary
	if value is Array:
		var normalized_array: Array = []
		for child_value: Variant in value:
			normalized_array.append(canonicalize_json_numeric_tree(child_value))
		return normalized_array
	if value is float and is_finite(float(value)) and float(value) == floorf(float(value)):
		return int(value)
	return value


func canonical_json_values_equal(left: Variant, right: Variant) -> bool:
	# JSON is the persistence boundary. Comparing its canonical serialization
	# tolerates harmless binary float round-trip differences that stringify to
	# the same authored value, while still rejecting any player-visible change.
	return JSON.stringify(canonicalize_json_numeric_tree(left)) == JSON.stringify(canonicalize_json_numeric_tree(right))


func grand_reserve_score_valid(value: Variant) -> bool:
	if not value is Dictionary or value.is_empty():
		return false
	var score: Dictionary = value
	for key: String in [
		"authenticationAccuracy", "authentication", "restoration", "integrity",
		"financial", "museumTrust", "collectorReputation", "grandReserveRevenue",
		"collectionQuality", "balancedScore", "ethics", "collectorTrust"
	]:
		var score_value: Variant = score.get(key, null)
		if (not score_value is int and not score_value is float) or not is_finite(float(score_value)):
			return false
	return true


func grand_reserve_artifact_snapshot_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var artifact: Dictionary = value
	var instance_id := String(artifact.get("instanceId", ""))
	var unique_id := String(artifact.get("uniqueId", ""))
	var spec_id := String(artifact.get("specId", ""))
	var artifact_spec_id := String(artifact.get("artifactSpecId", ""))
	if instance_id.is_empty() or instance_id != unique_id \
		or spec_id.is_empty() or spec_id != artifact_spec_id \
		or String(artifact.get("displayName", "")).is_empty() \
		or String(artifact.get("category", "")).is_empty() \
		or not artifact.get("visualSignature", null) is Dictionary \
		or not artifact.get("damageInstances", null) is Array \
		or not artifact.get("partStates", null) is Dictionary:
		return false
	for damage_value: Variant in artifact.get("damageInstances", []):
		if not damage_value is String or String(damage_value).is_empty():
			return false
	return true


func serialized_artifact_runtime_shape_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var saved: Dictionary = value
	if not saved.get("uniqueId", null) is String or String(saved.get("uniqueId", "")).is_empty() \
		or not saved.get("artifactSpecId", null) is String or String(saved.get("artifactSpecId", "")).is_empty():
		return false
	var seed_value: Variant = saved.get("seed", null)
	if (not seed_value is int and not seed_value is float) or not is_finite(float(seed_value)):
		return false
	for numeric_key: String in [
		"originalParts", "replacementParts", "confidence", "cleanliness",
		"surfaceCondition", "structuralCondition", "mechanicalCondition",
		"historicalIntegrity", "restorationQuality", "acquisitionPrice",
		"restorationCost", "estimatedValue", "rotation", "zoom"
	]:
		if not saved.has(numeric_key):
			continue
		var numeric_value: Variant = saved[numeric_key]
		if (not numeric_value is int and not numeric_value is float) or not is_finite(float(numeric_value)):
			return false
	for string_key: String in ["authenticityTruth", "playerHypothesis", "caseId", "storyArtifactId"]:
		if saved.has(string_key) and not saved[string_key] is String:
			return false
	for boolean_key: String in ["inspected", "repaired", "sold", "caseResolved"]:
		if saved.has(boolean_key) and not saved[boolean_key] is bool:
			return false
	for array_key: String in ["damageInstances", "knownClues", "evidence", "possibleClues"]:
		if saved.has(array_key) and not saved[array_key] is Array:
			return false
	for string_array_key: String in ["damageInstances", "knownClues", "possibleClues"]:
		for entry_value: Variant in saved.get(string_array_key, []):
			if not entry_value is String:
				return false
	if saved.has("partStates"):
		if not saved.partStates is Dictionary:
			return false
		for part_state_value: Variant in saved.partStates.values():
			if not part_state_value is bool:
				return false
	if saved.has("listing"):
		if not saved.listing is Dictionary:
			return false
		var listing: Dictionary = saved.listing
		for listing_numeric_key: String in ["starting", "reserve", "confidence", "publicAppraisal"]:
			if not listing.has(listing_numeric_key):
				continue
			var listing_numeric_value: Variant = listing[listing_numeric_key]
			if (not listing_numeric_value is int and not listing_numeric_value is float) or not is_finite(float(listing_numeric_value)):
				return false
		if listing.has("disclosure") and not listing.disclosure is String:
			return false
	return true


func public_auction_result_shape_valid(value: Variant, expected_transaction_id: String = "", expected_fingerprint: String = "") -> bool:
	if not value is Dictionary:
		return false
	var result: Dictionary = value
	for numeric_key: String in ["opening", "reserve", "hammer", "fee", "net"]:
		var numeric_value: Variant = result.get(numeric_key, null)
		if (not numeric_value is int and not numeric_value is float) \
			or not is_finite(float(numeric_value)) \
			or float(numeric_value) < 0.0:
			return false
	if not result.get("reserve_met", null) is bool \
		or not result.get("winnerId", null) is String \
		or not result.get("bids", null) is Array \
		or not result.get("participants", null) is Array \
		or result.get("participants", []).is_empty() \
		or not result.get("dropouts", null) is Array \
		or not result.get("reasonTags", null) is Array:
		return false
	var sale_status := String(result.get("sale_status", ""))
	if sale_status != ("SOLD" if bool(result.get("reserve_met", false)) else "NO_SALE"):
		return false
	var transaction_id := String(result.get("transactionId", ""))
	var public_fingerprint := String(result.get("publicFingerprint", ""))
	if transaction_id.is_empty() or public_fingerprint.is_empty() \
		or (not expected_transaction_id.is_empty() and transaction_id != expected_transaction_id) \
		or (not expected_fingerprint.is_empty() and public_fingerprint != expected_fingerprint):
		return false
	for bid_value: Variant in result.get("bids", []):
		if not bid_value is Dictionary:
			return false
		var bid: Dictionary = bid_value
		var amount_value: Variant = bid.get("amount", null)
		if String(bid.get("bidderId", "")).is_empty() \
			or (not amount_value is int and not amount_value is float) \
			or not is_finite(float(amount_value)) \
			or float(amount_value) < 0.0:
			return false
	for participant_value: Variant in result.get("participants", []):
		if not participant_value is Dictionary or String(participant_value.get("id", "")).is_empty():
			return false
	for dropout_value: Variant in result.get("dropouts", []):
		if not dropout_value is Dictionary \
			or String(dropout_value.get("bidderId", "")).is_empty() \
			or String(dropout_value.get("reason", "")).is_empty():
			return false
	for reason_value: Variant in result.get("reasonTags", []):
		if not reason_value is Dictionary \
			or String(reason_value.get("category", "")).is_empty() \
			or String(reason_value.get("code", "")).is_empty() \
			or not String(reason_value.get("polarity", "")) in ["POSITIVE", "NEGATIVE", "NEUTRAL"]:
			return false
	return true


func pending_auction_contract_valid(authored: Dictionary, normalized: Dictionary) -> bool:
	var status := String(normalized.get("status", "NONE"))
	if status == "NONE":
		return true
	if not authored.get("cueIndex", null) is int and not authored.get("cueIndex", null) is float:
		return false
	if not authored.get("createdDay", null) is int and not authored.get("createdDay", null) is float:
		return false
	if not authored.get("grandReserve", null) is bool \
		or not authored.get("decisions", null) is Dictionary \
		or authored.get("decisions", {}).is_empty():
		return false
	var transaction_id := String(normalized.get("transactionId", ""))
	var public_fingerprint := String(normalized.get("publicFingerprint", ""))
	if public_fingerprint != auction_public_fingerprint(normalized.get("decisions", {})):
		return false
	var result: Dictionary = normalized.get("result", {})
	if not public_auction_result_shape_valid(result, transaction_id, public_fingerprint):
		return false
	for result_numeric_key: String in ["stageDifficulty", "reservePressureFactor"]:
		var result_numeric_value: Variant = result.get(result_numeric_key, null)
		if (not result_numeric_value is int and not result_numeric_value is float) \
			or not is_finite(float(result_numeric_value)) \
			or float(result_numeric_value) <= 0.0:
			return false
	var expected_queue: Variant = canonicalize_json_numeric_tree(build_pending_auction_cue_queue(result))
	var cue_queue: Array = normalized.get("cueQueue", [])
	var authored_cue_index := int(authored.get("cueIndex", -1))
	if not canonical_json_values_equal(cue_queue, expected_queue) \
		or authored_cue_index < 0 \
		or authored_cue_index >= cue_queue.size():
		return false
	var receipt: Dictionary = normalized.get("receipt", {})
	if status == "PENDING" and not receipt.is_empty():
		return false
	if status == "COMMITTED" and (
		receipt.is_empty() \
		or authored_cue_index != cue_queue.size() - 1 \
		or not canonical_json_values_equal(receipt, public_pending_auction_result(result))
	):
		return false
	return true


func grand_reserve_receipts_valid(receipts: Array, lot_uids: Array) -> bool:
	var seen_transactions := {}
	for receipt_index in range(receipts.size()):
		var receipt_value: Variant = receipts[receipt_index]
		if not receipt_value is Dictionary or receipt_index >= lot_uids.size():
			return false
		var receipt: Dictionary = receipt_value
		var artifact_value: Variant = receipt.get("artifact", {})
		var auction_value: Variant = receipt.get("auction", {})
		if not artifact_value is Dictionary or not auction_value is Dictionary:
			return false
		var artifact: Dictionary = artifact_value
		var auction_receipt: Dictionary = auction_value
		var artifact_uid := String(artifact.get("instanceId", artifact.get("uniqueId", "")))
		var transaction_id := String(auction_receipt.get("transactionId", ""))
		if not grand_reserve_artifact_snapshot_valid(artifact) \
			or not public_auction_result_shape_valid(auction_receipt) \
			or artifact_uid != String(lot_uids[receipt_index]) \
			or transaction_id.is_empty() \
			or seen_transactions.has(transaction_id) \
			or String(auction_receipt.get("publicFingerprint", "")).is_empty() \
			or not String(auction_receipt.get("sale_status", "")) in ["SOLD", "NO_SALE"]:
			return false
		seen_transactions[transaction_id] = true
	return true


func normalize_grand_reserve_session(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return default_grand_reserve_session()
	var normalized: Dictionary = value.duplicate(true)
	if not normalized.get("phase", null) is String \
		or not normalized.get("reserveRunId", null) is String \
		or not normalized.get("currentLotIndex", null) is int and not normalized.get("currentLotIndex", null) is float \
		or not normalized.get("activeTransactionId", null) is String \
		or not normalized.get("finalizationReceiptId", null) is String:
		return default_grand_reserve_session()
	if not is_finite(float(normalized.get("currentLotIndex", -1))):
		return default_grand_reserve_session()
	var phase := String(normalized.get("phase", "IDLE"))
	if not phase in ["IDLE", "AUCTION_PENDING", "BETWEEN_LOTS", "FINALIZED"]:
		return default_grand_reserve_session()
	normalized["schemaVersion"] = 1
	normalized["reserveRunId"] = String(normalized.get("reserveRunId", ""))
	normalized["phase"] = phase
	normalized["lotUids"] = normalized.get("lotUids", []).duplicate(true) if normalized.get("lotUids", []) is Array else []
	normalized["receipts"] = canonicalize_json_numeric_tree(normalized.get("receipts", [])) if normalized.get("receipts", []) is Array else []
	normalized["currentLotIndex"] = int(normalized.get("currentLotIndex", -1))
	normalized["activeTransactionId"] = String(normalized.get("activeTransactionId", ""))
	normalized["activeArtifact"] = canonicalize_json_numeric_tree(normalized.get("activeArtifact", {})) if normalized.get("activeArtifact", {}) is Dictionary else {}
	normalized["finalizationReceiptId"] = String(normalized.get("finalizationReceiptId", ""))
	if phase == "IDLE":
		return default_grand_reserve_session()
	var unique := {}
	for uid_value: Variant in normalized.lotUids:
		if not uid_value is String:
			return default_grand_reserve_session()
		var uid := String(uid_value)
		if uid.is_empty() or unique.has(uid):
			return default_grand_reserve_session()
		unique[uid] = true
	if normalized.reserveRunId.is_empty() \
		or normalized.lotUids.size() != 3 \
		or normalized.currentLotIndex < 0 \
		or normalized.currentLotIndex > 2 \
		or normalized.receipts.size() > 3 \
		or not grand_reserve_receipts_valid(normalized.receipts, normalized.lotUids):
		return default_grand_reserve_session()
	var active_artifact_uid := String(normalized.activeArtifact.get("instanceId", normalized.activeArtifact.get("uniqueId", "")))
	if not grand_reserve_artifact_snapshot_valid(normalized.activeArtifact) \
		or active_artifact_uid != String(normalized.lotUids[normalized.currentLotIndex]):
		return default_grand_reserve_session()
	if phase == "AUCTION_PENDING" and (
		normalized.activeTransactionId.is_empty() \
		or normalized.receipts.size() != normalized.currentLotIndex \
		or not normalized.finalizationReceiptId.is_empty()
	):
		return default_grand_reserve_session()
	if phase == "BETWEEN_LOTS" and (
		normalized.currentLotIndex >= 2 \
		or normalized.activeTransactionId.is_empty() \
		or normalized.receipts.size() != normalized.currentLotIndex + 1 \
		or String(normalized.receipts[-1].get("auction", {}).get("transactionId", "")) != normalized.activeTransactionId \
		or not normalized.finalizationReceiptId.is_empty()
	):
		return default_grand_reserve_session()
	if phase == "FINALIZED" and (
		normalized.currentLotIndex != 2 \
		or normalized.receipts.size() != 3 \
		or not normalized.activeTransactionId.is_empty() \
		or normalized.finalizationReceiptId.is_empty()
	):
		return default_grand_reserve_session()
	return normalized


func normalize_pending_auction(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return default_pending_auction()
	var normalized: Dictionary = value.duplicate(true)
	if not normalized.get("status", null) is String \
		or not normalized.get("transactionId", null) is String \
		or not normalized.get("artifactId", null) is String \
		or not normalized.get("publicFingerprint", null) is String \
		or (not normalized.get("cueIndex", null) is int and not normalized.get("cueIndex", null) is float) \
		or (not normalized.get("createdDay", null) is int and not normalized.get("createdDay", null) is float) \
		or not normalized.get("grandReserve", null) is bool:
		return default_pending_auction()
	if not is_finite(float(normalized.get("cueIndex", 0))) or not is_finite(float(normalized.get("createdDay", 0))):
		return default_pending_auction()
	var status: String = String(normalized.get("status", "NONE"))
	if not status in ["NONE", "PENDING", "COMMITTED"]:
		return default_pending_auction()
	normalized["schemaVersion"] = 1
	normalized["status"] = status
	normalized["transactionId"] = String(normalized.get("transactionId", ""))
	normalized["artifactId"] = String(normalized.get("artifactId", ""))
	normalized["publicFingerprint"] = String(normalized.get("publicFingerprint", ""))
	normalized["decisions"] = canonicalize_json_numeric_tree(normalized.get("decisions", {})) if normalized.get("decisions", {}) is Dictionary else {}
	normalized["result"] = canonicalize_json_numeric_tree(normalized.get("result", {})) if normalized.get("result", {}) is Dictionary else {}
	normalized["receipt"] = canonicalize_json_numeric_tree(normalized.get("receipt", {})) if normalized.get("receipt", {}) is Dictionary else {}
	normalized["cueQueue"] = canonicalize_json_numeric_tree(normalized.get("cueQueue", [])) if normalized.get("cueQueue", []) is Array else []
	normalized["cueIndex"] = clampi(int(normalized.get("cueIndex", 0)), 0, maxi(0, normalized.cueQueue.size() - 1))
	normalized["createdDay"] = maxi(0, int(normalized.get("createdDay", 0)))
	normalized["grandReserve"] = bool(normalized.get("grandReserve", false))
	if status in ["PENDING", "COMMITTED"] and (normalized.transactionId.is_empty() or normalized.artifactId.is_empty() or normalized.publicFingerprint.is_empty() or normalized.result.is_empty() or normalized.cueQueue.is_empty()):
		return default_pending_auction()
	return normalized


func pending_auction_active() -> bool:
	return String(pending_auction.get("status", "NONE")) == "PENDING"


func grand_reserve_active() -> bool:
	return String(grand_reserve_session.get("phase", "IDLE")) in ["AUCTION_PENDING", "BETWEEN_LOTS"]


func gameplay_mutation_locked() -> bool:
	return pending_auction_active() or grand_reserve_active()


func grand_reserve_public_state() -> Dictionary:
	var normalized := normalize_grand_reserve_session(grand_reserve_session)
	return {
		"ok": true,
		"code": "OK",
		"schemaVersion": int(normalized.get("schemaVersion", 1)),
		"reserveRunId": String(normalized.get("reserveRunId", "")),
		"phase": String(normalized.get("phase", "IDLE")),
		"lotUids": normalized.get("lotUids", []).duplicate(true),
		"receipts": normalized.get("receipts", []).duplicate(true),
		"currentLotIndex": int(normalized.get("currentLotIndex", -1)),
		"activeTransactionId": String(normalized.get("activeTransactionId", "")),
		"activeArtifact": normalized.get("activeArtifact", {}).duplicate(true),
		"finalizationReceiptId": String(normalized.get("finalizationReceiptId", ""))
	}


func reset_game() -> void:
	# Player profile intentionally lives outside the run. NEW GAME/reset only
	# clears transient campaign state and can never relock earned stages.
	# Locale is also a player preference: preserve a valid active selection while
	# a first launch still uses the declared English default above.
	var preserved_language := language if language in ["en", "ko"] else "en"
	money = 1200
	reputation = 12
	day = 1
	inventory = []
	active_workpiece = {}
	transactions = []
	auction_history = []
	statistics = default_statistics()
	market_state = default_market_state()
	market_roster = []
	market_roster_day = 0
	owned_upgrades = []
	selected_tool = "soft_brush"
	language = preserved_language
	current_event_id = ""
	event_history = []
	daily_modifiers = {}
	pending_auction = default_pending_auction()
	grand_reserve_session = default_grand_reserve_session()
	last_action_error = ""
	campaign_state = default_campaign_state()
	current_stage = 1
	stage_run_state = default_stage_run_state(current_stage)
	instance_counter = 0
	rng.seed = master_seed
	generate_market_roster()
	state_changed.emit()
	campaign_changed.emit()
	stage_changed.emit()


func new_game(stage_id: int = 1) -> Dictionary:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return {"ok": false, "code": last_action_error, "stage": current_stage}
	if stage_clear_pending():
		last_action_error = "STAGE_CLEAR_ACK_REQUIRED"
		return {"ok": false, "code": last_action_error, "stage": current_stage}
	reset_game()
	_reset_incomplete_tutorial_for_new_run(stage_id)
	return start_stage(stage_id)


func can_select_stage(stage_id: int) -> bool:
	if RuntimeRegistry.get_stage_definition(stage_id).is_empty():
		return false
	if stage_id == 1:
		return true
	return stage_id <= clampi(int(player_profile.get("highestUnlockedStage", 1)), 1, 10)


func start_stage(stage_id: int) -> Dictionary:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return {"ok": false, "code": last_action_error, "stage": current_stage}
	if stage_clear_pending():
		last_action_error = "STAGE_CLEAR_ACK_REQUIRED"
		return {"ok": false, "code": last_action_error, "stage": current_stage}
	if not can_select_stage(stage_id):
		return {"ok": false, "code": "STAGE_LOCKED", "stage": stage_id}
	current_stage = stage_id
	stage_run_state = default_stage_run_state(stage_id)
	stage_run_state.status = "RUNNING"
	stage_run_state.startedAtDay = day
	_seed_tutorial_run_mirror_from_profile()
	prime_stage_checkpoint(stage_id)
	# The checkpoint may raise the visible starting money for later stages.
	# Capture the post-checkpoint public budget before any player action.
	stage_run_state.telemetry = default_stage_telemetry(money)
	market_roster = []
	market_roster_day = 0
	generate_market_roster(true, true)
	save_game()
	state_changed.emit()
	stage_changed.emit()
	return {
		"ok": true,
		"code": "OK",
		"stage": stage_id,
		"difficultyMultiplier": stage_difficulty_multiplier()
	}


func complete_stage(stage_id: int, score: float, persist: bool = true, allow_grand_reserve_finalize: bool = false) -> Dictionary:
	if gameplay_mutation_locked() and not allow_grand_reserve_finalize:
		last_action_error = "PENDING_AUCTION_LOCKED"
		return {"ok": false, "code": last_action_error, "stage": current_stage}
	if stage_id < 1 or stage_id > 10 or RuntimeRegistry.get_stage_definition(stage_id).is_empty():
		return {"ok": false, "code": "INVALID_STAGE", "stage": stage_id}
	if stage_id != current_stage or not String(stage_run_state.get("status", "")) in ["RUNNING", "CLEARED"]:
		return {"ok": false, "code": "STAGE_NOT_RUNNING", "stage": stage_id}
	var was_already_cleared := String(stage_run_state.get("status", "")) == "CLEARED"
	if String(stage_run_state.get("status", "")) != "CLEARED" and not stage_objectives_complete(stage_id):
		return {"ok": false, "code": "STAGE_OBJECTIVES_INCOMPLETE", "stage": stage_id}
	var normalized_score := maxf(0.0, score)
	var updated := player_profile.duplicate(true)
	normalize_profile_dictionary(updated)
	var best_key := str(stage_id)
	var previous_best := float(updated.stageBest.get(best_key, 0.0))
	var cleared: Array = updated.clearedStages
	if not cleared.has(stage_id):
		cleared.append(stage_id)
		cleared.sort()
	var completion_contract: Dictionary = RuntimeRegistry.get_stage_definition(stage_id).get("completion_contract", {})
	if bool(completion_contract.get("unlock_on_completion", true)):
		updated.highestUnlockedStage = maxi(int(updated.highestUnlockedStage), mini(10, stage_id + 1))
	updated.stageBest[best_key] = maxf(previous_best, normalized_score)
	player_profile = updated
	stage_run_state.status = "CLEARED"
	stage_run_state.stageClearAcknowledged = false
	stage_run_state.completedAtDay = day
	stage_run_state.score = maxf(float(stage_run_state.get("score", 0.0)), normalized_score)
	var performance := stage_public_summary(stage_id, normalized_score)
	performance.isNewBest = normalized_score > previous_best
	performance.best = float(player_profile.stageBest.get(best_key, 0.0))
	stage_run_state.lastPerformance = normalize_stage_performance_snapshot({
		"current": performance.get("current", 0.0),
		"target": performance.get("target", 0.0),
		"metTarget": performance.get("metTarget", false),
		"isNewBest": performance.get("isNewBest", false),
		"best": performance.get("best", 0.0)
	}, stage_id)
	# Freeze public replay feedback at the same completion boundary as the score.
	# Locale-specific copy is derived later; only public numeric/status keys persist.
	stage_run_state.stageReplayFeedbackSnapshot = normalize_stage_replay_feedback_snapshot(stage_replay_feedback(stage_id), stage_id)
	if not was_already_cleared and bool(stage_run_state.get("telemetryAvailable", false)):
		stage_run_state.stageReplayTelemetrySnapshot = normalize_stage_replay_telemetry_snapshot(stage_public_telemetry(stage_id), stage_id)
	var profile_saved := true
	var run_saved := true
	if persist:
		profile_saved = save_profile()
		run_saved = save_game()
		profile_changed.emit()
		stage_changed.emit()
	return {
		"ok": profile_saved and run_saved,
		"code": "OK" if profile_saved and run_saved else "PERSISTENCE_FAILED",
		"stage": stage_id,
		"highestUnlockedStage": int(player_profile.highestUnlockedStage),
		"best": float(player_profile.stageBest.get(best_key, 0.0)),
		"performance": performance
	}


func stage_clear_pending() -> bool:
	return String(stage_run_state.get("status", "")) == "CLEARED" \
		and not bool(stage_run_state.get("stageClearAcknowledged", false)) \
		and not bool(campaign_state.get("postGame", false))


func reconcile_profile_from_cleared_run() -> bool:
	if String(stage_run_state.get("status", "")) != "CLEARED":
		return false
	var updated := player_profile.duplicate(true)
	normalize_profile_dictionary(updated)
	var cleared: Array = updated.get("clearedStages", [])
	if not cleared.has(current_stage):
		cleared.append(current_stage)
		cleared.sort()
	updated.clearedStages = cleared
	var completion_contract: Dictionary = RuntimeRegistry.get_stage_definition(current_stage).get("completion_contract", {})
	if bool(completion_contract.get("unlock_on_completion", true)):
		updated.highestUnlockedStage = maxi(int(updated.get("highestUnlockedStage", 1)), mini(10, current_stage + 1))
	var best_key := str(current_stage)
	updated.stageBest[best_key] = maxf(float(updated.stageBest.get(best_key, 0.0)), float(stage_run_state.get("score", 0.0)))
	if updated == player_profile:
		return false
	player_profile = updated
	return true


func acknowledge_stage_clear() -> Dictionary:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return {"ok": false, "code": last_action_error, "stage": current_stage}
	if String(stage_run_state.get("status", "")) != "CLEARED":
		return {"ok": false, "code": "STAGE_NOT_CLEARED", "stage": current_stage}
	if bool(stage_run_state.get("stageClearAcknowledged", false)):
		return {"ok": true, "code": "ALREADY_ACKNOWLEDGED", "stage": current_stage}
	stage_run_state.stageClearAcknowledged = true
	if not save_game():
		stage_run_state.stageClearAcknowledged = false
		return {"ok": false, "code": "PERSISTENCE_FAILED", "stage": current_stage}
	stage_changed.emit()
	return {"ok": true, "code": "OK", "stage": current_stage}


func stage_difficulty_multiplier(stage_id: int = -1) -> float:
	var resolved_stage := current_stage if stage_id < 1 else stage_id
	return RuntimeRegistry.stage_difficulty_multiplier(clampi(resolved_stage, 1, 10))


func get_current_stage_case_ids() -> Array:
	return RuntimeRegistry.get_stage_definition(current_stage).get("case_ids", []).duplicate()


func _tutorial_contract() -> Dictionary:
	var contract_value: Variant = RuntimeRegistry.stage_config.get("tutorial_contract", {})
	return contract_value if contract_value is Dictionary else {}


func _tutorial_steps() -> Array:
	var contract := _tutorial_contract()
	var authored_value: Variant = contract.get("steps", [])
	if not authored_value is Array:
		return []
	var ordered: Array = []
	for step_value: Variant in authored_value:
		if step_value is Dictionary:
			ordered.append(step_value)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("order", 0)) < int(right.get("order", 0))
	)
	return ordered


func _normalized_tutorial_completed_steps(raw_value: Variant) -> Array:
	if not raw_value is Array:
		return []
	var raw_steps: Array = raw_value
	var normalized: Array = []
	# A valid tutorial history is always a contiguous authored prefix. This
	# prevents a malformed or hand-edited profile/run mirror from skipping
	# guidance. Order is authoritative; merely containing a later ID is not.
	for step_index in range(_tutorial_steps().size()):
		var step: Dictionary = _tutorial_steps()[step_index]
		var step_id := String(step.get("step_id", ""))
		if step_id.is_empty() or step_index >= raw_steps.size() or String(raw_steps[step_index]) != step_id:
			break
		normalized.append(step_id)
	return normalized


func _tutorial_run_completed_steps() -> Array:
	if current_stage != int(_tutorial_contract().get("stage_id", 1)):
		return []
	return _normalized_tutorial_completed_steps(stage_run_state.get("tutorialCompletedSteps", []))


func _seed_tutorial_run_mirror_from_profile() -> void:
	if current_stage != int(_tutorial_contract().get("stage_id", 1)):
		stage_run_state.tutorialCompletedSteps = []
		return
	stage_run_state.tutorialCompletedSteps = _normalized_tutorial_completed_steps(player_profile.get("tutorialCompletedSteps", []))


func _reconcile_profile_to_tutorial_run(persist_profile: bool = true) -> bool:
	# For an active/restorable Stage 1 run, the run mirror owns the exact prefix.
	# This both advances an older profile after an interrupted profile write and
	# prevents a stale longer profile from skipping an action in the loaded run.
	if current_stage != int(_tutorial_contract().get("stage_id", 1)) or not String(stage_run_state.get("status", "")) in ["RUNNING", "CLEARED"]:
		return false
	var run_prefix := _tutorial_run_completed_steps()
	stage_run_state.tutorialCompletedSteps = run_prefix.duplicate()
	var profile_prefix := _normalized_tutorial_completed_steps(player_profile.get("tutorialCompletedSteps", []))
	if profile_prefix == run_prefix:
		return false
	var updated := player_profile.duplicate(true)
	normalize_profile_dictionary(updated)
	updated.tutorialCompletedSteps = run_prefix.duplicate()
	player_profile = updated
	if persist_profile:
		save_profile()
	profile_changed.emit()
	return true


func _tutorial_is_active() -> bool:
	var contract := _tutorial_contract()
	return not contract.is_empty() \
		and current_stage == int(contract.get("stage_id", 1)) \
		and String(stage_run_state.get("status", "")) == "RUNNING"


func _reset_incomplete_tutorial_for_new_run(stage_id: int) -> void:
	var contract := _tutorial_contract()
	if stage_id != int(contract.get("stage_id", 1)):
		return
	var steps := _tutorial_steps()
	var completed := _normalized_tutorial_completed_steps(player_profile.get("tutorialCompletedSteps", []))
	if completed.is_empty() or completed.size() >= steps.size():
		return
	# A partial prefix refers to transient case/artifact state from the abandoned
	# run. A fresh Stage 1 run restarts that guidance, while a full 6/6 remains a
	# durable player preference until Help explicitly requests a replay.
	var updated := player_profile.duplicate(true)
	normalize_profile_dictionary(updated)
	updated.tutorialCompletedSteps = []
	player_profile = updated
	save_profile()
	profile_changed.emit()


## Returns only compact player-facing guidance. Internal step IDs, event names,
## trigger tokens and completion codes never leave this presentation boundary.
func tutorial_public_state() -> Dictionary:
	var steps := _tutorial_steps()
	var completed := _tutorial_run_completed_steps() if _tutorial_is_active() else _normalized_tutorial_completed_steps(player_profile.get("tutorialCompletedSteps", []))
	var total := steps.size()
	var current_index := mini(completed.size(), total)
	var visible := _tutorial_is_active() and current_index < total
	var public_state := {
		"visible": visible,
		"step": current_index + 1 if visible else mini(current_index, total),
		"total": total,
		"title": "",
		"text": "",
		"icon": "",
		"target": "",
		"targets": []
	}
	if visible:
		var current_step: Dictionary = steps[current_index]
		public_state.title = _localized_stage_copy(current_step.get("title", {}))
		public_state.text = _localized_stage_copy(current_step.get("text", {}))
		public_state.icon = String(current_step.get("icon", ""))
		public_state.target = String(current_step.get("target_ui_id", ""))
		var route_targets: Array = []
		if not public_state.target.is_empty():
			route_targets.append(public_state.target)
		var authored_routes: Variant = current_step.get("route_ui_ids", [])
		if authored_routes is Array:
			for route_value: Variant in authored_routes:
				var route_id := String(route_value)
				if not route_id.is_empty() and not route_targets.has(route_id):
					route_targets.append(route_id)
		public_state.targets = route_targets
	return public_state


func _advance_tutorial_run_event(event_name: String) -> bool:
	if not _tutorial_is_active() or event_name.is_empty():
		return false
	var steps := _tutorial_steps()
	var completed := _tutorial_run_completed_steps()
	if completed.size() >= steps.size():
		return false
	var current_step: Dictionary = steps[completed.size()]
	if event_name != String(current_step.get("complete_when", "")):
		return false
	var step_id := String(current_step.get("step_id", ""))
	if step_id.is_empty() or completed.has(step_id):
		return false
	completed.append(step_id)
	stage_run_state.tutorialCompletedSteps = completed
	return true


func _persist_authoritative_tutorial_action(event_name: String, persist_run: bool = true) -> bool:
	# The caller has already mutated the authoritative gameplay state. Append the
	# matching run prefix before the one run-save boundary. Only after that run
	# generation commits may the profile mirror be advanced.
	var advanced := _advance_tutorial_run_event(event_name)
	var run_saved := true
	# A Stage 1 step cannot be safely batched behind `persist_run = false`: its
	# authoritative action may be irreversible (notably SOLD). If it advanced the
	# mirror, force this single atomic run boundary. Other non-tutorial batch paths
	# (such as Grand Reserve) retain their existing no-save behavior.
	if persist_run or advanced:
		run_saved = save_game()
	else:
		run_saved = false
	if advanced and run_saved:
		_reconcile_profile_to_tutorial_run(true)
	return advanced


## Marks exactly the currently expected authored event. It is deliberately
## advisory: rejected/out-of-order events never alter gameplay results. Direct
## test/help calls still use the same run-before-profile transaction boundary.
func complete_tutorial_event(event_name: String) -> bool:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return false
	return _persist_authoritative_tutorial_action(event_name, true)


## The only operation allowed to replay completed contextual guidance.
func reset_tutorial_guidance() -> bool:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return false
	var updated := player_profile.duplicate(true)
	normalize_profile_dictionary(updated)
	var run_active := _tutorial_is_active()
	var changed: bool = not updated.get("tutorialCompletedSteps", []).is_empty() or (run_active and not _tutorial_run_completed_steps().is_empty())
	updated.tutorialCompletedSteps = []
	player_profile = updated
	if run_active:
		stage_run_state.tutorialCompletedSteps = []
	if changed:
		# Help replay follows the same ordering: save the active run reset first,
		# then durably clear the profile preference.
		if not run_active or save_game():
			save_profile()
		profile_changed.emit()
	return changed


func current_stage_first_pending_case() -> String:
	for case_id_value: Variant in get_current_stage_case_ids():
		var case_id := String(case_id_value)
		if not campaign_state.get("completedCases", {}).has(case_id):
			return case_id
	return ""


func case_is_in_current_stage(case_id: String) -> bool:
	return get_current_stage_case_ids().has(case_id)


func stage_objectives_complete(stage_id: int = -1) -> bool:
	var resolved_stage := current_stage if stage_id < 1 else stage_id
	var definition: Dictionary = RuntimeRegistry.get_stage_definition(resolved_stage)
	if definition.is_empty():
		return false
	var completion_contract: Dictionary = definition.get("completion_contract", {})
	if String(completion_contract.get("case_scope", "ALL_STAGE_CASES")) != "ALL_STAGE_CASES":
		return false
	for case_id_value: Variant in definition.get("case_ids", []):
		if not campaign_state.get("completedCases", {}).has(String(case_id_value)):
			return false
	var follows_stage_flag := String(completion_contract.get("grand_reserve_rule", "FOLLOW_STAGE_FLAG")) == "FOLLOW_STAGE_FLAG"
	if follows_stage_flag and bool(definition.get("includes_grand_reserve", false)) and not bool(campaign_state.get("grandReserve", {}).get("completed", false)):
		return false
	return true


func stage_score_from_run(stage_id: int = -1) -> float:
	var resolved_stage := current_stage if stage_id < 1 else stage_id
	var definition: Dictionary = RuntimeRegistry.get_stage_definition(resolved_stage)
	if bool(definition.get("includes_grand_reserve", false)):
		return clampf(float(campaign_state.get("grandReserve", {}).get("score", {}).get("balancedScore", 0.0)), 0.0, 100.0)
	var score_total := 0.0
	var counted := 0
	for case_id_value: Variant in definition.get("case_ids", []):
		var case_id := String(case_id_value)
		var outcome: String = campaign_state.get("caseOutcomes", {}).get(case_id, "")
		score_total += {"masterful": 100.0, "credible": 78.0, "reviewed_with_mentor": 55.0, "mistaken": 30.0}.get(outcome, 0.0)
		counted += 1
	return 0.0 if counted == 0 else score_total / float(counted)


func _stage_replay_status_code(value: float, available: bool, unavailable_code: String = "UNAVAILABLE") -> String:
	if not available:
		return unavailable_code
	if value >= 75.0:
		return "STRONG"
	if value >= 50.0:
		return "STEADY"
	return "FRAGILE"


func _public_condition_snapshot(artifact: Dictionary) -> Dictionary:
	if artifact.is_empty():
		return {}
	return {
		"historicalIntegrity": clampf(float(artifact.get("historicalIntegrity", 0.0)), 0.0, 100.0),
		"surfaceCondition": clampf(float(artifact.get("surfaceCondition", 0.0)), 0.0, 100.0),
		"structuralCondition": clampf(float(artifact.get("structuralCondition", 0.0)), 0.0, 100.0),
		"mechanicalCondition": clampf(float(artifact.get("mechanicalCondition", 0.0)), 0.0, 100.0)
	}


func _cached_public_appraisal(artifact: Dictionary) -> int:
	# Never calculate a fresh appraisal here: appraise() consumes canonical truth.
	# Only a value already shown/cached for the player is a legal denominator.
	var listing_value: Variant = artifact.get("listing", {}).get("publicAppraisal", null)
	if listing_value is int or listing_value is float:
		var listing_cached := maxi(0, int(listing_value))
		if listing_cached > 0:
			return listing_cached
	var estimated_value: Variant = artifact.get("estimatedValue", null)
	if estimated_value is int or estimated_value is float:
		return maxi(0, int(estimated_value))
	return 0


## Dynamic, presentation-safe replay feedback for the selected stage. This API
## is advisory only and never participates in clear/unlock/score authority.
func stage_replay_feedback(stage_id: int = -1) -> Dictionary:
	var resolved_stage := current_stage if stage_id < 1 else stage_id
	var definition: Dictionary = RuntimeRegistry.get_stage_definition(resolved_stage)
	if definition.is_empty():
		return {}
	var case_ids: Array = definition.get("case_ids", [])

	var investigation_total := 0.0
	var investigation_valid := not case_ids.is_empty()
	for case_id_value: Variant in case_ids:
		var case_id := String(case_id_value)
		var case_definition_value: Dictionary = case_definition(case_id)
		var evidence_rows: Array = case_definition_value.get("evidence", [])
		var required_independent := int(case_definition_value.get("resolution", {}).get("strong_min_independent_support", 0))
		if evidence_rows.is_empty() or required_independent <= 0:
			investigation_valid = false
			continue
		var runtime_state: Dictionary = campaign_state.get("caseStates", {}).get(case_id, {})
		var discovered_ids: Array = runtime_state.get("discoveredEvidenceIds", []) if runtime_state.get("discoveredEvidenceIds", []) is Array else []
		var cited_ids: Array = runtime_state.get("citedEvidenceIds", []) if runtime_state.get("citedEvidenceIds", []) is Array else []
		var valid_evidence_ids := {}
		var cited_independence := {}
		for evidence: Dictionary in evidence_rows:
			var evidence_id := String(evidence.get("id", ""))
			if evidence_id.is_empty():
				continue
			valid_evidence_ids[evidence_id] = true
			if cited_ids.has(evidence_id):
				var independence_key := String(evidence.get("independence_key", ""))
				if not independence_key.is_empty():
					cited_independence[independence_key] = true
		var discovered_valid_ids := {}
		for discovered_value: Variant in discovered_ids:
			var discovered_id := String(discovered_value)
			if valid_evidence_ids.has(discovered_id):
				discovered_valid_ids[discovered_id] = true
		var discovery_coverage := clampf(float(discovered_valid_ids.size()) / float(evidence_rows.size()), 0.0, 1.0)
		var citation_coverage := clampf(float(cited_independence.size()) / float(required_independent), 0.0, 1.0)
		investigation_total += 0.35 * discovery_coverage + 0.65 * citation_coverage
	var investigation_available := investigation_valid and not case_ids.is_empty()
	var investigation_value := clampf(100.0 * investigation_total / float(case_ids.size()), 0.0, 100.0) if investigation_available else 0.0

	var ledger_rows: Dictionary = campaign_state.get("caseArtifactLedger", {})
	var preservation_total := 0.0
	var preservation_count := 0
	var stage_artifact_ids := {}
	var ledger_by_uid := {}
	for case_id_value: Variant in case_ids:
		var case_id := String(case_id_value)
		var ledger: Dictionary = ledger_rows.get(case_id, {})
		var artifact_uid := String(ledger.get("artifactUid", ""))
		if not artifact_uid.is_empty():
			stage_artifact_ids[artifact_uid] = true
			ledger_by_uid[artifact_uid] = ledger
		var condition_snapshot: Dictionary = {}
		var live_artifact := find_inventory_instance(artifact_uid)
		if not live_artifact.is_empty():
			condition_snapshot = _public_condition_snapshot(live_artifact)
		elif ledger.get("publicConditionSnapshot", {}) is Dictionary:
			condition_snapshot = ledger.get("publicConditionSnapshot", {}).duplicate(true)
		if condition_snapshot.is_empty():
			continue
		var integrity := clampf(float(condition_snapshot.get("historicalIntegrity", 0.0)), 0.0, 100.0) / 100.0
		var visible_condition := (clampf(float(condition_snapshot.get("surfaceCondition", 0.0)), 0.0, 100.0) + clampf(float(condition_snapshot.get("structuralCondition", 0.0)), 0.0, 100.0) + clampf(float(condition_snapshot.get("mechanicalCondition", 0.0)), 0.0, 100.0)) / 300.0
		preservation_total += 0.65 * integrity + 0.35 * visible_condition
		preservation_count += 1
	# Stage 10 culminates in a three-lot Grand Reserve. Those run-scoped lots may
	# include checkpoint/market artifacts with no case ledger, so admit only the
	# explicitly selected/result snapshot UIDs for that authored stage.
	if bool(definition.get("includes_grand_reserve", false)):
		for selected_value: Variant in campaign_state.get("grandReserve", {}).get("selectedLotIds", []):
			var selected_uid := String(selected_value)
			if not selected_uid.is_empty():
				stage_artifact_ids[selected_uid] = true
		for reserve_result_value: Variant in campaign_state.get("grandReserve", {}).get("results", []):
			if not reserve_result_value is Dictionary:
				continue
			var reserve_result: Dictionary = reserve_result_value
			var reserve_artifact: Dictionary = reserve_result.get("artifact", {}) if reserve_result.get("artifact", {}) is Dictionary else {}
			var reserve_uid := String(reserve_artifact.get("instanceId", ""))
			if not reserve_uid.is_empty():
				stage_artifact_ids[reserve_uid] = true
	var preservation_available := preservation_count == case_ids.size() and preservation_count > 0
	var preservation_value := clampf(100.0 * preservation_total / float(preservation_count), 0.0, 100.0) if preservation_available else 0.0

	var attempts := 0
	var sales := 0
	var sold_realization_total := 0.0
	for history_value: Variant in auction_history:
		if not history_value is Dictionary:
			continue
		var history: Dictionary = history_value
		var artifact_uid := String(history.get("instanceId", ""))
		if not stage_artifact_ids.has(artifact_uid):
			continue
		attempts += 1
		var result: Dictionary = history.get("result", {}) if history.get("result", {}) is Dictionary else {}
		var sold := String(history.get("status", "")) == "SOLD" or bool(result.get("reserve_met", false))
		if not sold:
			continue
		sales += 1
		var appraisal_snapshot := 0
		var history_appraisal: Variant = history.get("publicAppraisal", null)
		if history_appraisal is int or history_appraisal is float:
			appraisal_snapshot = maxi(0, int(history_appraisal))
		if appraisal_snapshot <= 0:
			var ledger: Dictionary = ledger_by_uid.get(artifact_uid, {})
			var ledger_appraisal: Variant = ledger.get("publicAppraisalSnapshot", null)
			if ledger_appraisal is int or ledger_appraisal is float:
				appraisal_snapshot = maxi(0, int(ledger_appraisal))
		if appraisal_snapshot <= 0:
			var live_artifact := find_inventory_instance(artifact_uid)
			if not live_artifact.is_empty():
				appraisal_snapshot = _cached_public_appraisal(live_artifact)
		var realization := 0.0
		if appraisal_snapshot > 0:
			realization = clampf(float(result.get("net", 0)) / float(appraisal_snapshot), 0.0, 1.15) / 1.15
		sold_realization_total += realization
	var sale_available := attempts > 0
	var sale_value: Variant = null
	if sale_available:
		var conversion := float(sales) / float(attempts)
		var mean_sold_realization := sold_realization_total / float(sales) if sales > 0 else 0.0
		sale_value = clampf(100.0 * (0.65 * conversion + 0.35 * mean_sold_realization), 0.0, 100.0)

	var axes := {
		"investigation": {"value": investigation_value, "available": investigation_available, "statusCode": _stage_replay_status_code(investigation_value, investigation_available)},
		"preservation": {"value": preservation_value, "available": preservation_available, "statusCode": _stage_replay_status_code(preservation_value, preservation_available)},
		"sale": {"value": sale_value, "available": sale_available, "statusCode": _stage_replay_status_code(float(sale_value) if sale_available else 0.0, sale_available, "NO_ATTEMPTS")}
	}
	var weakest := ""
	var weakest_value := INF
	for axis_id: String in ["investigation", "preservation", "sale"]:
		var axis: Dictionary = axes[axis_id]
		if not bool(axis.available):
			continue
		var axis_value := float(axis.value)
		if axis_value < weakest_value:
			weakest = axis_id
			weakest_value = axis_value
	var advice_code: String = String({"investigation": "STRENGTHEN_EVIDENCE", "preservation": "PROTECT_CONDITION", "sale": "IMPROVE_SALE"}.get(weakest, "NONE"))
	return {"stage": resolved_stage, "axes": axes, "weakest": weakest, "adviceCode": advice_code}


func _stage_telemetry_public_view(telemetry_value: Variant, stage_id: int) -> Dictionary:
	var telemetry := normalize_stage_telemetry(telemetry_value, money)
	var repair_actions := int(telemetry.get("repairActions", 0))
	var investigation_actions := int(telemetry.get("investigationActions", 0))
	var risk_actions := int(telemetry.get("investigationRiskActions", 0))
	var auction_count := int(telemetry.get("auctionCount", 0))
	var strategy_counts: Dictionary = telemetry.get("listingStrategyCounts", {})
	var listing_count := 0
	for strategy_id: String in STAGE_TELEMETRY_STRATEGIES:
		listing_count += int(strategy_counts.get(strategy_id, 0))
	var distribution := {}
	for strategy_id: String in STAGE_TELEMETRY_STRATEGIES:
		distribution[strategy_id] = float(strategy_counts.get(strategy_id, 0)) / float(listing_count) if listing_count > 0 else 0.0

	var tool_counts: Dictionary = telemetry.get("repairToolUseCounts", {})
	var tool_ids: Array = tool_counts.keys()
	tool_ids.sort()
	var dominant_tool_id := ""
	var dominant_tool_uses := 0
	for tool_value: Variant in tool_ids:
		var tool_id := String(tool_value)
		var tool_uses := int(tool_counts.get(tool_id, 0))
		if tool_uses > dominant_tool_uses:
			dominant_tool_id = tool_id
			dominant_tool_uses = tool_uses
	var tool_concentration := float(dominant_tool_uses) / float(repair_actions) if repair_actions > 0 else 0.0
	var summary_codes: Array = ["NO_INVESTIGATION" if investigation_actions <= 0 else ("RISK_TAKEN" if risk_actions > 0 else "RISK_NONE")]
	if int(telemetry.get("relistCount", 0)) > 0:
		summary_codes.append("RELIST_USED")
	elif repair_actions > 0:
		summary_codes.append("TOOL_FOCUS_HIGH" if tool_concentration >= 0.75 else "TOOL_VARIETY")
	return {
		"stage": clampi(stage_id, 1, 10),
		"available": true,
		"repairResourcePressure": float(telemetry.get("repairCostAccrued", 0.0)) / float(maxi(1, int(telemetry.get("budgetBasis", 1)))),
		"repairCostAccrued": float(telemetry.get("repairCostAccrued", 0.0)),
		"repairActions": repair_actions,
		"repairToolIdsUsed": tool_ids,
		"dominantToolId": dominant_tool_id,
		"toolConcentration": tool_concentration,
		"investigationActions": investigation_actions,
		"investigationRiskActions": risk_actions,
		"investigationRiskRate": float(risk_actions) / float(investigation_actions) if investigation_actions > 0 else 0.0,
		"investigationRiskWeightSum": float(telemetry.get("investigationRiskWeightSum", 0.0)),
		"listingCount": listing_count,
		"listingStrategyDistribution": distribution,
		"auctionCount": auction_count,
		"noSaleCount": int(telemetry.get("noSaleCount", 0)),
		"noSaleRate": float(telemetry.get("noSaleCount", 0)) / float(auction_count) if auction_count > 0 else 0.0,
		"relistCount": int(telemetry.get("relistCount", 0)),
		"artifactSalesCount": int(telemetry.get("artifactSalesCount", 0)),
		"summaryCodes": summary_codes
	}


## Public-only, diagnostic stage pressure. It never participates in completion,
## scoring, bidder resolution or RNG. Cleared runs return their frozen snapshot.
func stage_public_telemetry(stage_id: int = -1) -> Dictionary:
	var resolved_stage := current_stage if stage_id < 1 else stage_id
	if resolved_stage != current_stage:
		return {"stage": clampi(resolved_stage, 1, 10), "available": false}
	var frozen_value: Variant = stage_run_state.get("stageReplayTelemetrySnapshot", {})
	if String(stage_run_state.get("status", "")) == "CLEARED" and frozen_value is Dictionary and not frozen_value.is_empty():
		return frozen_value.duplicate(true)
	if not bool(stage_run_state.get("telemetryAvailable", false)):
		return {"stage": clampi(resolved_stage, 1, 10), "available": false}
	return _stage_telemetry_public_view(stage_run_state.get("telemetry", {}), resolved_stage)


func _stage_public_score_bounds() -> Vector2:
	var performance_contract: Dictionary = RuntimeRegistry.stage_config.get("performance_contract", {})
	var authored_range: Variant = performance_contract.get("score_range", [0.0, 100.0])
	if not authored_range is Array or authored_range.size() != 2:
		return Vector2(0.0, 100.0)
	var minimum_value: Variant = authored_range[0]
	var maximum_value: Variant = authored_range[1]
	if (not minimum_value is int and not minimum_value is float) or (not maximum_value is int and not maximum_value is float):
		return Vector2(0.0, 100.0)
	var minimum_score := float(minimum_value)
	var maximum_score := float(maximum_value)
	if maximum_score <= minimum_score:
		return Vector2(0.0, 100.0)
	return Vector2(minimum_score, maximum_score)


func _stage_grade_id_for_score(definition: Dictionary, score: float) -> String:
	var selected_id := ""
	var selected_minimum := -INF
	for threshold_value: Variant in definition.get("performance_target", {}).get("grade_thresholds", []):
		if not threshold_value is Dictionary:
			continue
		var threshold: Dictionary = threshold_value
		var minimum_value: Variant = threshold.get("min_score", null)
		if not minimum_value is int and not minimum_value is float:
			continue
		var minimum_score := float(minimum_value)
		if minimum_score <= score and minimum_score >= selected_minimum:
			selected_minimum = minimum_score
			selected_id = String(threshold.get("grade_id", ""))
	return selected_id


func _stage_performance_target_met(performance_target: Dictionary, current_score: float, target_score: float) -> bool:
	match String(performance_target.get("operator", "GTE")):
		"GTE":
			return current_score >= target_score
		_:
			return false


func _localized_stage_copy(value: Variant) -> String:
	if not value is Dictionary:
		return String(value) if value is String else ""
	var authored: Dictionary = value
	var locale := language if language in ["en", "ko"] else "en"
	var localized := String(authored.get(locale, ""))
	if localized.is_empty():
		localized = String(authored.get("en", authored.get("ko", "")))
	return localized


func _localized_stage_grade(grade_id: String) -> String:
	var performance_contract: Dictionary = RuntimeRegistry.stage_config.get("performance_contract", {})
	var labels: Dictionary = performance_contract.get("grade_labels", {})
	return _localized_stage_copy(labels.get(grade_id, {}))


## Returns presentation-safe stage progress only. Authored case/artifact IDs,
## private truth, metric tokens and internal grade IDs never leave this API.
func stage_public_summary(stage_id: int = -1, score: Variant = null) -> Dictionary:
	var resolved_stage := current_stage if stage_id < 1 else stage_id
	var definition: Dictionary = RuntimeRegistry.get_stage_definition(resolved_stage)
	if definition.is_empty():
		return {}
	var completion_contract: Dictionary = definition.get("completion_contract", {})
	var performance_target: Dictionary = definition.get("performance_target", {})
	var performance_contract: Dictionary = RuntimeRegistry.stage_config.get("performance_contract", {})
	var bounds := _stage_public_score_bounds()
	var supplied_score := (score is int or score is float)
	var stored_snapshot: Dictionary = {}
	if resolved_stage == current_stage and stage_run_state.get("lastPerformance", {}) is Dictionary:
		stored_snapshot = stage_run_state.get("lastPerformance", {})
	var reused_snapshot := false
	var raw_score := 0.0
	if supplied_score:
		raw_score = maxf(0.0, float(score))
	elif resolved_stage == current_stage and String(stage_run_state.get("status", "")) == "CLEARED":
		if not stored_snapshot.is_empty():
			raw_score = float(stored_snapshot.get("current", 0.0))
			reused_snapshot = true
		else:
			raw_score = maxf(0.0, float(stage_run_state.get("score", 0.0)))
	elif player_profile.get("clearedStages", []).has(resolved_stage):
		raw_score = maxf(0.0, float(player_profile.get("stageBest", {}).get(str(resolved_stage), 0.0)))
	else:
		raw_score = stage_score_from_run(resolved_stage)
	var current_score := clampf(raw_score, bounds.x, bounds.y)
	var target_score := clampf(float(performance_target.get("target_score", bounds.x)), bounds.x, bounds.y)
	var met_target := _stage_performance_target_met(performance_target, current_score, target_score)
	var grade_id := _stage_grade_id_for_score(definition, current_score)
	var best_score := maxf(0.0, float(player_profile.get("stageBest", {}).get(str(resolved_stage), 0.0)))
	var is_new_best := raw_score > best_score
	if reused_snapshot:
		is_new_best = bool(stored_snapshot.get("isNewBest", false))

	var cleared: bool = player_profile.get("clearedStages", []).has(resolved_stage)
	var completed_units := 0
	var total_units: int = definition.get("case_ids", []).size()
	for case_id_value: Variant in definition.get("case_ids", []):
		if campaign_state.get("completedCases", {}).has(String(case_id_value)):
			completed_units += 1
	if bool(definition.get("includes_grand_reserve", false)):
		total_units += 1
		if bool(campaign_state.get("grandReserve", {}).get("completed", false)):
			completed_units += 1
	if cleared:
		completed_units = total_units
	var completion_met: bool = cleared or (resolved_stage == current_stage and stage_objectives_complete(resolved_stage))
	var completion_progress := 1.0 if total_units <= 0 else clampf(float(completed_units) / float(total_units), 0.0, 1.0)
	var target_span := target_score - bounds.x
	var performance_progress := 1.0 if target_span <= 0.0 else clampf((current_score - bounds.x) / target_span, 0.0, 1.0)
	var advisory_only := String(performance_contract.get("completion_relation", "")) == "ADVISORY_ONLY" and not bool(completion_contract.get("performance_affects_unlock", true))
	var goal_label := _localized_stage_copy(performance_target.get("goal_label", {}))
	var result_label := _localized_stage_copy({
		"en": "Performance target met.",
		"ko": "성과 목표를 달성했습니다."
	}) if met_target else _localized_stage_copy(performance_target.get("failure_label", {}))
	return {
		"stage": resolved_stage,
		"completionLabel": _localized_stage_copy(completion_contract.get("completion_label", {})),
		"goalLabel": goal_label,
		"failureOrSuccess": result_label,
		"advice": _localized_stage_copy(performance_target.get("advice_label", {})),
		"target": target_score,
		"current": current_score,
		"progress": performance_progress,
		"completionProgress": completion_progress,
		"completionMet": completion_met,
		"grade": _localized_stage_grade(grade_id),
		"metTarget": met_target,
		"advisoryOnly": advisory_only,
		"hasNextStage": resolved_stage < 10,
		"nextStageUnlocked": resolved_stage < 10 and int(player_profile.get("highestUnlockedStage", 1)) >= resolved_stage + 1,
		"best": best_score,
		"isNewBest": is_new_best
	}


func prior_stage_case_count(stage_id: int) -> int:
	var total := 0
	for prior_id in range(1, stage_id):
		total += RuntimeRegistry.get_stage_definition(prior_id).get("case_ids", []).size()
	return total


func prime_stage_checkpoint(stage_id: int) -> void:
	var definition: Dictionary = RuntimeRegistry.get_stage_definition(stage_id)
	var first_case_id: String = String(definition.get("case_ids", [""])[0]) if not definition.get("case_ids", []).is_empty() else ""
	if not first_case_id.is_empty():
		campaign_state.currentAct = RuntimeRegistry.get_case(first_case_id).get("act", "PROLOGUE")
	campaign_state.storyFlags.stageReplay = stage_id
	var previous_cases := prior_stage_case_count(stage_id)
	# A selected checkpoint starts with deterministic, non-decreasing workshop
	# resources representing already-cleared chapters. It does not fabricate
	# completed cases or alter any authored truth/evidence relation.
	money = maxi(money, 1200 + previous_cases * 45)
	reputation = maxi(reputation, 12 + previous_cases * 2)
	campaign_state.museumTrust = maxi(int(campaign_state.museumTrust), roundi(float(previous_cases) * 1.25))
	campaign_state.workshopGrade = maxi(int(campaign_state.workshopGrade), clampi(1 + floori(float(previous_cases) / 6.0), 1, 5))
	statistics.authentication_attempts = maxi(int(statistics.authentication_attempts), previous_cases)
	statistics.authentication_correct = maxi(int(statistics.authentication_correct), roundi(float(previous_cases) * 0.78))
	var target_mastery := previous_cases * 2
	var mastery_keys: Array = campaign_state.mastery.keys()
	for index in range(mastery_keys.size()):
		var mastery_key: String = mastery_keys[index]
		var target_for_domain: int = floori(float(target_mastery) / float(mastery_keys.size())) + (1 if index < target_mastery % mastery_keys.size() else 0)
		campaign_state.mastery[mastery_key] = maxi(int(campaign_state.mastery.get(mastery_key, 0)), target_for_domain)
	if bool(definition.get("includes_grand_reserve", false)):
		seed_grand_reserve_checkpoint_lots(stage_id, 3)


func seed_grand_reserve_checkpoint_lots(stage_id: int, count: int) -> void:
	var candidate_ids: Array = []
	for prior_id in range(stage_id - 1, 0, -1):
		var introduced: Array = RuntimeRegistry.get_stage_definition(prior_id).get("introduced_artifact_ids", [])
		for spec_id_value: Variant in introduced:
			candidate_ids.append(String(spec_id_value))
			if candidate_ids.size() >= count:
				break
		if candidate_ids.size() >= count:
			break
	for index in range(mini(count, candidate_ids.size())):
		var spec_id: String = candidate_ids[index]
		var checkpoint_id := "stage_%02d_checkpoint_%02d" % [stage_id, index + 1]
		if not find_inventory_instance(checkpoint_id).is_empty():
			continue
		var artifact := new_artifact(spec_id, stable_hash("stage-checkpoint|%d|%s" % [stage_id, spec_id]), checkpoint_id)
		artifact.playerHypothesis = truth_to_hypothesis(artifact.authenticityTruth)
		artifact.confidence = 0.82
		artifact.knownClues = ["PROVENANCE", "MATERIAL", "CONSTRUCTION_METHOD"]
		artifact.inspected = true
		inventory.append(artifact)


func maybe_case_complete_and_unlock() -> Dictionary:
	if String(stage_run_state.get("status", "")) != "RUNNING":
		return {"ok": false, "code": "STAGE_NOT_RUNNING"}
	var definition: Dictionary = RuntimeRegistry.get_stage_definition(current_stage)
	for case_id_value: Variant in definition.get("case_ids", []):
		if not campaign_state.completedCases.has(String(case_id_value)):
			return {"ok": false, "code": "STAGE_CASES_REMAIN"}
	if bool(definition.get("includes_grand_reserve", false)) and not bool(campaign_state.grandReserve.completed):
		campaign_state.currentAct = "GRAND_RESERVE"
		campaign_state.grandReserve.invited = true
		return {"ok": true, "code": "GRAND_RESERVE_READY", "stage": current_stage}
	return complete_stage(current_stage, stage_score_from_run(current_stage))


func stable_hash(text: String) -> int:
	var value: int = 2166136261
	for byte: int in text.to_utf8_buffer():
		value = int((value ^ byte) * 16777619) & 0x7fffffff
	return value


func truth_to_hypothesis(truth: String) -> String:
	if truth == "ASSEMBLED_FROM_PERIOD_PARTS":
		return "GENUINE_WITH_PERIOD_REPAIR"
	return truth if truth in HYPOTHESES else "UNKNOWN"


func new_artifact(spec_ref: Variant = -1, seed_override: int = -1, unique_id_override: String = "") -> Dictionary:
	var resolved_ref: Variant = spec_ref
	if spec_ref is int and int(spec_ref) == -1:
		resolved_ref = rng.randi_range(0, RuntimeRegistry.spec_order.size() - 1)
	var spec: Dictionary = RuntimeRegistry.get_spec(resolved_ref)
	if spec.is_empty():
		return {}
	var seed_value := seed_override
	if seed_value < 0:
		seed_value = rng.randi()
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed_value
	var truths := ["GENUINE", "GENUINE_WITH_PERIOD_REPAIR", "GENUINE_WITH_MODERN_REPAIR", "ASSEMBLED_FROM_PERIOD_PARTS", "REPRODUCTION", "FORGERY"]
	var truth: String = truths[local_rng.randi_range(0, truths.size() - 1)]
	var compatible: Array = spec.get("compatibleDamages", []).duplicate()
	var damages: Array = []
	var damage_count := mini(3, compatible.size())
	var damage_indices: Array = range(compatible.size())
	for index in range(damage_indices.size() - 1, 0, -1):
		var swap_index := local_rng.randi_range(0, index)
		var temp: Variant = damage_indices[index]
		damage_indices[index] = damage_indices[swap_index]
		damage_indices[swap_index] = temp
	for index in range(damage_count):
		damages.append(compatible[damage_indices[index]])
	var rarity_multiplier: float = RARITY_MULTIPLIERS.get(spec.get("rarity", "common"), 1.0)
	var historical_significance := 1.0 + float(RuntimeRegistry.makers.get(spec.maker, {}).get("rarityBias", 0.3)) * 0.35
	var unique_id := unique_id_override
	if unique_id.is_empty():
		instance_counter += 1
		unique_id = "inst_%d_%d_%04d" % [day, seed_value, instance_counter]
	var operations := RuntimeRegistry.supported_operations(spec.id)
	var part_states := {}
	for part: String in operations.get("parts", []):
		part_states[part] = true
	var base_value := int(spec.baseValue)
	var acquisition_variance := local_rng.randf_range(0.36, 0.52)
	return {
		"uniqueId": unique_id,
		"artifactSpecId": spec.id,
		"seed": seed_value,
		"displayName": spec.displayName,
		"category": spec.category,
		"maker": spec.maker,
		"modelName": spec.modelName,
		"actualEra": spec.era,
		"baseValue": base_value,
		"rarity": spec.rarity,
		"materialSet": spec.materialSet.duplicate(true),
		"compatibleDamages": compatible,
		"possibleFaults": spec.possibleFaults.duplicate(true),
		"possibleClues": spec.possibleClues.duplicate(true),
		"restorationProfile": spec.restorationProfile.duplicate(true),
		"collectorTags": spec.collectorTags.duplicate(true),
		"inspectionObservable": spec.get("inspectionObservable", {}).duplicate(true),
		"repairProfile": spec.get("repairProfile", {}).duplicate(true),
		"auctionProfile": spec.get("auctionProfile", {}).duplicate(true),
		"visualVariant": spec.visualVariant,
		"baseModel": spec.baseModel,
		"visualSignature": RuntimeRegistry.visual_signature(spec.id),
		"supportedOperations": operations,
		"authenticityTruth": truth,
		"originalParts": local_rng.randi_range(1, 3),
		"replacementParts": local_rng.randi_range(0, 2),
		"trueRarity": rarity_multiplier * (1.0 + float(daily_modifiers.get("rarity_bonus", 0.0))),
		"trueHistoricalSignificance": historical_significance,
		"trueMarketBaseline": base_value,
		"damageInstances": damages,
		"knownClues": [],
		"evidence": [],
		"playerHypothesis": "UNKNOWN",
		"confidence": 0.12,
		"cleanliness": 18.0,
		"surfaceCondition": 55.0,
		"structuralCondition": 70.0,
		"mechanicalCondition": 42.0,
		"historicalIntegrity": 78.0,
		"restorationQuality": 0.0,
		"acquisitionPrice": maxi(20, int(base_value * rarity_multiplier * acquisition_variance)),
		"restorationCost": 0.0,
		"estimatedValue": base_value,
		"rotation": 0.0,
		"zoom": 1.0,
		"inspected": false,
		"repaired": false,
		"partStates": part_states,
		"listing": {"starting": 0, "reserve": 0, "confidence": 0.0, "disclosure": "UNCERTAIN"},
		"sold": false,
		"caseId": "",
		"storyArtifactId": "",
		"caseResolved": false
	}


func hydrate_instance(saved: Dictionary) -> Dictionary:
	var artifact := new_artifact(saved.get("artifactSpecId", "artifact_001"), int(saved.get("seed", 1)), saved.get("uniqueId", ""))
	for key: String in saved.keys():
		artifact[key] = saved[key]
	return artifact


func serialize_instance(artifact: Dictionary) -> Dictionary:
	var saved := {}
	for key: String in MUTABLE_INSTANCE_KEYS:
		if artifact.has(key):
			saved[key] = artifact[key]
	return saved


func market_slot_count() -> int:
	return clampi(5 + int(upgrade_effect_total("market_slots")) + int(daily_modifiers.get("market_slots", 0)), 3, 10)


func generate_market_roster(force: bool = false, include_stage_spotlight: bool = false) -> Array:
	if not force and market_roster_day == day and not market_roster.is_empty():
		return market_roster
	market_roster = []
	var count := market_slot_count()
	var available_specs: Array = RuntimeRegistry.available_spec_ids_for_stage(current_stage)
	if available_specs.is_empty():
		return market_roster
	var selected_spec_ids: Array = []
	if include_stage_spotlight:
		var introduced: Array = RuntimeRegistry.get_stage_definition(current_stage).get("introduced_artifact_ids", [])
		for spec_id_value: Variant in introduced:
			var spotlight_id := String(spec_id_value)
			if spotlight_id in available_specs and not selected_spec_ids.has(spotlight_id) and selected_spec_ids.size() < count:
				selected_spec_ids.append(spotlight_id)
	var start := posmod(master_seed + day * 7, available_specs.size())
	var stride_offset := 0
	while selected_spec_ids.size() < count and stride_offset < available_specs.size() * 2:
		var spec_index := posmod(start + stride_offset * 13, available_specs.size())
		var spec_id := String(available_specs[spec_index])
		if not selected_spec_ids.has(spec_id):
			selected_spec_ids.append(spec_id)
		stride_offset += 1
	# A sequential deterministic fallback covers pool sizes that share a factor
	# with the legacy stride without changing its ordinary first choices.
	var fallback_offset := 0
	while selected_spec_ids.size() < count and fallback_offset < available_specs.size():
		var fallback_id := String(available_specs[posmod(start + fallback_offset, available_specs.size())])
		if not selected_spec_ids.has(fallback_id):
			selected_spec_ids.append(fallback_id)
		fallback_offset += 1
	for slot in range(selected_spec_ids.size()):
		var spec_id: String = selected_spec_ids[slot]
		var lot_seed := stable_hash("%d|%d|%d|%s" % [master_seed, day, slot, spec_id])
		var artifact := new_artifact(spec_id, lot_seed, "market_%d_%02d" % [day, slot])
		var discount := float(daily_modifiers.get("acquisition_discount", 0.0)) + upgrade_effect_total("transport_discount") + upgrade_effect_total("market_forecast") * 0.01
		market_roster.append({
			"lotId": "day_%d_lot_%02d" % [day, slot],
			"specId": spec_id,
			"seed": lot_seed,
			"price": maxi(20, int(float(artifact.acquisitionPrice) * (1.0 - discount))),
			"sold": false
		})
	market_roster_day = day
	return market_roster


func market_spec_ids() -> Array:
	var ids: Array = []
	for lot: Dictionary in market_roster:
		ids.append(lot.specId)
	return ids


func buy_market_lot(lot_id: String) -> bool:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return false
	if inventory.size() >= storage_capacity():
		return false
	for lot: Dictionary in market_roster:
		if lot.lotId != lot_id or bool(lot.sold):
			continue
		var price := int(lot.price)
		if money < price:
			return false
		var artifact := new_artifact(lot.specId, int(lot.seed), "owned_%s" % lot.lotId)
		if int(daily_modifiers.get("pending_damage", 0)) > 0:
			if not artifact.damageInstances.has("SCRATCH"):
				artifact.damageInstances.append("SCRATCH")
			daily_modifiers.pending_damage = maxi(0, int(daily_modifiers.pending_damage) - 1)
		artifact.acquisitionPrice = price
		money -= price
		lot.sold = true
		inventory.append(artifact)
		statistics.purchases += 1
		append_money_transaction("purchase", artifact.displayName, -price, artifact.uniqueId, "market_lot")
		save_game()
		state_changed.emit()
		return true
	return false


func buy_artifact(index: int) -> bool:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return false
	if inventory.size() >= storage_capacity():
		return false
	var artifact := new_artifact(index)
	if artifact.is_empty() or money < int(artifact.acquisitionPrice):
		return false
	money -= int(artifact.acquisitionPrice)
	inventory.append(artifact)
	statistics.purchases += 1
	append_money_transaction("purchase", artifact.displayName, -int(artifact.acquisitionPrice), artifact.uniqueId, "catalog")
	save_game()
	state_changed.emit()
	return true


func storage_capacity() -> int:
	return 8 + int(upgrade_effect_total("storage_capacity")) + int(upgrade_effect_total("workbench_slots"))


func advance_day() -> Dictionary:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return {"ok": false, "code": last_action_error}
	day += 1
	statistics.days_operated = day
	daily_modifiers = {}
	market_roster_day = 0
	current_event_id = deterministic_event_id(day)
	var event_result := execute_event(current_event_id, false)
	generate_market_roster()
	refresh_campaign_progress()
	save_game()
	state_changed.emit()
	return event_result


func deterministic_event_id(for_day: int) -> String:
	if RuntimeRegistry.events.is_empty():
		return ""
	var index := posmod(stable_hash("event|%d|%d" % [master_seed, for_day]), RuntimeRegistry.events.size())
	return RuntimeRegistry.events[index].id


func select_tool(tool_id: String) -> bool:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return false
	if RuntimeRegistry.tools.has(tool_id):
		selected_tool = tool_id
		return true
	return false


func repair_requirements(artifact: Dictionary) -> Dictionary:
	var profile: Dictionary = artifact.get("repairProfile", {})
	var base_tolerance := maxf(0.01, float(profile.get("toleranceMm", 1.0)))
	var profile_cost_pressure := maxf(0.1, float(profile.get("costPressure", 1.0)))
	var difficulty := stage_difficulty_multiplier()
	return {
		"requiredTools": profile.get("requiredTools", []).duplicate(),
		"baseToleranceMm": base_tolerance,
		"effectiveToleranceMm": base_tolerance / difficulty,
		"costPressure": profile_cost_pressure,
		"stageDifficulty": difficulty,
		# The stage multiplier appears once in each derived channel.
		"effectiveCostFactor": profile_cost_pressure * difficulty,
		"effectivePenaltyFactor": difficulty
	}


func repair_tool_is_allowed(artifact: Dictionary) -> bool:
	var required: Array = repair_requirements(artifact).requiredTools
	return required.is_empty() or required.has(selected_tool)


func repairable_damage_types(artifact: Dictionary) -> Array:
	var profile: Dictionary = artifact.get("repairProfile", {})
	var explicit_types: Array = profile.get("repairableDamages", [])
	if not explicit_types.is_empty():
		return explicit_types.duplicate()
	# Legacy specifications predate the authored repair profile and retain the
	# original three mechanism categories. Expansion specifications author their
	# intervention contract through possibleFaults; those public fault types must
	# therefore be reachable by the same data-driven Repair action.
	if not profile.is_empty():
		return artifact.get("possibleFaults", []).duplicate()
	return ["MECHANICAL_WEAR", "CRACK", "BROKEN_PART"]


func repair_tolerance_penalty(artifact: Dictionary) -> float:
	var requirements := repair_requirements(artifact)
	var base_tolerance := float(requirements.baseToleranceMm)
	var tolerance_pressure := clampf(0.15 / base_tolerance, 0.5, 2.0)
	return tolerance_pressure * float(requirements.effectivePenaltyFactor)


func clean(artifact: Dictionary, tool_id: String = "") -> String:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return "Auction result is pending."
	last_action_error = ""
	if not tool_id.is_empty():
		selected_tool = tool_id
	var tool := RuntimeRegistry.get_tool(selected_tool)
	if tool.is_empty():
		return "Unknown tool."
	var cost_before := float(artifact.get("restorationCost", 0.0))
	var effective: Array = tool.get("effectiveDamage", [])
	var effective_damage_found := false
	for damage_value: Variant in artifact.damageInstances:
		if String(damage_value) in effective:
			effective_damage_found = true
			break
	var planned_cost := restoration_cost_units(12.0 * maxf(0.1, 1.0 - (upgrade_effect_total("restoration_cost_reduction") + float(daily_modifiers.get("restoration_discount", 0.0)))) * float(repair_requirements(artifact).effectiveCostFactor)) if effective_damage_found else 0
	if not can_pay_restoration_cost(planned_cost):
		return "Insufficient funds."
	var found := false
	for index in range(artifact.damageInstances.size() - 1, -1, -1):
		var damage: String = artifact.damageInstances[index]
		if damage in effective:
			artifact.damageInstances.remove_at(index)
			var efficiency := 1.0 + upgrade_effect_total("workflow_efficiency")
			artifact.cleanliness = minf(100.0, float(artifact.cleanliness) + float(tool.get("strength", 12)) * efficiency)
			artifact.restorationQuality = minf(100.0, float(artifact.restorationQuality) + 4.0 * efficiency)
			artifact.restorationCost += planned_cost
			charge_restoration_cost(artifact, planned_cost, "clean")
			var clue := "PATINA" if damage == "TARNISH" else "MATERIAL"
			if not artifact.knownClues.has(clue):
				artifact.knownClues.append(clue)
			found = true
			statistics.restorations += 1
			break
	if not found:
		var protection := upgrade_effect_total("tool_risk_reduction") + upgrade_effect_total("integrity_protection")
		var risk := float(tool.get("risk", 0.1)) * maxf(0.2, 1.0 - protection) * stage_difficulty_multiplier()
		artifact.historicalIntegrity = maxf(0.0, float(artifact.historicalIntegrity) - risk * 12.0)
		artifact.surfaceCondition = maxf(0.0, float(artifact.surfaceCondition) - risk * 10.0)
		if not artifact.damageInstances.has("SCRATCH"):
			artifact.damageInstances.append("SCRATCH")
	artifact.inspected = true
	statistics.discoveries += 1
	_record_restoration_telemetry(
		"%s|CLEAN|%s|%d" % [String(artifact.get("uniqueId", "")), selected_tool, roundi(cost_before * 1000.0)],
		float(artifact.get("restorationCost", 0.0)) - cost_before,
		selected_tool
	)
	save_game()
	state_changed.emit()
	return "Effective restoration." if found else "Wrong tool: finish and historical integrity suffered."


func repair(artifact: Dictionary) -> String:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return "Auction result is pending."
	last_action_error = ""
	var cost_before := float(artifact.get("restorationCost", 0.0))
	var authored_repair_types := repairable_damage_types(artifact)
	var present_repair_types: Array = []
	for damage_value: Variant in authored_repair_types:
		var damage_type := String(damage_value)
		if artifact.damageInstances.has(damage_type):
			present_repair_types.append(damage_type)
	var repairable := not present_repair_types.is_empty()
	var efficiency := 1.0 + upgrade_effect_total("repair_efficiency")
	var tool_allowed := repair_tool_is_allowed(artifact)
	var planned_cost := 0
	if repairable and not tool_allowed:
		planned_cost = restoration_cost_units(10.0 * float(repair_requirements(artifact).effectiveCostFactor))
	elif repairable:
		var restoration_discount := upgrade_effect_total("restoration_cost_reduction") + float(daily_modifiers.get("restoration_discount", 0.0))
		planned_cost = restoration_cost_units(48.0 * maxf(0.1, 1.0 - restoration_discount) * float(repair_requirements(artifact).effectiveCostFactor))
	else:
		planned_cost = restoration_cost_units(18.0 * maxf(0.1, 1.0 - float(daily_modifiers.get("restoration_discount", 0.0))) * float(repair_requirements(artifact).effectiveCostFactor))
	if not can_pay_restoration_cost(planned_cost):
		return "Insufficient funds."
	if repairable and not tool_allowed:
		var mismatch_penalty := repair_tolerance_penalty(artifact)
		artifact.mechanicalCondition = maxf(0.0, float(artifact.mechanicalCondition) - 3.0 * mismatch_penalty)
		artifact.historicalIntegrity = maxf(0.0, float(artifact.historicalIntegrity) - 2.0 * mismatch_penalty)
		artifact.restorationCost += planned_cost
		charge_restoration_cost(artifact, planned_cost, "repair_mismatch")
		if not artifact.damageInstances.has("SCRATCH"):
			artifact.damageInstances.append("SCRATCH")
		_record_restoration_telemetry(
			"%s|REPAIR_MISMATCH|%s|%d" % [String(artifact.get("uniqueId", "")), selected_tool, roundi(cost_before * 1000.0)],
			float(artifact.get("restorationCost", 0.0)) - cost_before,
			selected_tool
		)
		save_game()
		state_changed.emit()
		return "Required precision tool is not selected."
	if repairable:
		for damage: String in present_repair_types:
			artifact.damageInstances.erase(damage)
		artifact.mechanicalCondition = minf(100.0, float(artifact.mechanicalCondition) + 24.0 * efficiency)
		artifact.repaired = true
		artifact.restorationQuality = minf(100.0, float(artifact.restorationQuality) + 12.0 * efficiency)
		artifact.restorationCost += planned_cost
		charge_restoration_cost(artifact, planned_cost, "repair")
		if not artifact.knownClues.has("REPAIR_TRACE"):
			artifact.knownClues.append("REPAIR_TRACE")
		statistics.restorations += 1
		_record_restoration_telemetry(
			"%s|REPAIR|%s|%d" % [String(artifact.get("uniqueId", "")), selected_tool, roundi(cost_before * 1000.0)],
			float(artifact.get("restorationCost", 0.0)) - cost_before,
			selected_tool
		)
		_persist_authoritative_tutorial_action("REPAIR_COMPLETED")
		state_changed.emit()
		return "Mechanism repaired."
	var repair_protection := clampf(upgrade_effect_total("repair_risk_reduction"), 0.0, 0.8)
	artifact.mechanicalCondition = minf(100.0, float(artifact.mechanicalCondition) + 5.0)
	artifact.historicalIntegrity = maxf(0.0, float(artifact.historicalIntegrity) - 2.0 * (1.0 - repair_protection) * repair_tolerance_penalty(artifact))
	artifact.restorationCost += planned_cost
	charge_restoration_cost(artifact, planned_cost, "adjust")
	_record_restoration_telemetry(
		"%s|ADJUST|%s|%d" % [String(artifact.get("uniqueId", "")), selected_tool, roundi(cost_before * 1000.0)],
		float(artifact.get("restorationCost", 0.0)) - cost_before,
		selected_tool
	)
	save_game()
	state_changed.emit()
	return "Light adjustment completed."


func disassemble(artifact: Dictionary, part: String) -> bool:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return false
	var operations := RuntimeRegistry.supported_operations(artifact.artifactSpecId)
	if not bool(operations.get("disassembly", false)) or not part in operations.get("parts", []):
		return false
	if not artifact.partStates.has(part):
		return false
	var planned_cost := restoration_cost_units(8.0 * float(repair_requirements(artifact).effectiveCostFactor))
	if not can_pay_restoration_cost(planned_cost):
		return false
	var cost_before := float(artifact.get("restorationCost", 0.0))
	artifact.partStates[part] = false
	if not artifact.knownClues.has("CONSTRUCTION_METHOD"):
		artifact.knownClues.append("CONSTRUCTION_METHOD")
	artifact.restorationCost += planned_cost
	charge_restoration_cost(artifact, planned_cost, "disassemble")
	_record_restoration_telemetry(
		"%s|DISASSEMBLE|%s" % [String(artifact.get("uniqueId", "")), part],
		float(artifact.get("restorationCost", 0.0)) - cost_before
	)
	save_game()
	state_changed.emit()
	return true


func reassemble(artifact: Dictionary, part: String) -> bool:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return false
	if not artifact.partStates.has(part):
		return false
	artifact.partStates[part] = true
	save_game()
	state_changed.emit()
	return true


func inspect_clue(artifact: Dictionary, clue: String) -> Dictionary:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return {"ok": false, "code": last_action_error}
	if not clue in artifact.get("possibleClues", []):
		return {}
	var table := {
		"MAKER_MARK": {"observation": "maker mark appears period-consistent", "supports": [artifact.maker], "contradicts": [], "confidenceWeight": 0.16},
		"SERIAL_PATTERN": {"observation": "fictional serial sequence narrows era", "supports": [artifact.actualEra], "contradicts": [], "confidenceWeight": 0.18},
		"MATERIAL": {"observation": "material composition recorded", "supports": ["material"], "contradicts": ["modern_material"], "confidenceWeight": 0.18},
		"CONSTRUCTION_METHOD": {"observation": "fastener and joinery class inspected", "supports": ["period_method"], "contradicts": ["modern_method"], "confidenceWeight": 0.14},
		"COMPONENT_STYLE": {"observation": "component style cross-referenced", "supports": ["period_component"], "contradicts": [], "confidenceWeight": 0.12},
		"REPAIR_TRACE": {"observation": "repair trace logged", "supports": ["repair_history"], "contradicts": [], "confidenceWeight": 0.10},
		"PATINA": {"observation": "patina preserved and compared", "supports": ["age"], "contradicts": ["overcleaned"], "confidenceWeight": 0.12},
		"PROVENANCE": {"observation": "claim compared with fictional archive record", "supports": ["document_match"], "contradicts": ["document_mismatch"], "confidenceWeight": 0.15}
	}
	var evidence: Dictionary = table.get(clue, {"observation": "inspection recorded", "supports": [], "contradicts": [], "confidenceWeight": 0.08})
	if not artifact.knownClues.has(clue):
		artifact.knownClues.append(clue)
	var duplicate := false
	for existing: Dictionary in artifact.evidence:
		if existing.clueType == clue:
			duplicate = true
	if not duplicate:
		artifact.evidence.append({
			"clueType": clue,
			"observation": evidence.observation,
			"supports": evidence.supports,
			"contradicts": evidence.contradicts,
			"confidenceWeight": float(evidence.confidenceWeight) + upgrade_effect_total("clue_quality") + float(daily_modifiers.get("clue_bonus", 0.0))
		})
	artifact.confidence = clampf(0.12 + artifact.knownClues.size() * (0.08 + upgrade_effect_total("inspection_confidence") + float(daily_modifiers.get("inspection_bonus", 0.0))), 0.0, 0.92)
	statistics.discoveries += 1
	save_game()
	state_changed.emit()
	return evidence


func choose_hypothesis(artifact: Dictionary, hypothesis: String) -> bool:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return false
	if not hypothesis in HYPOTHESES:
		return false
	artifact.playerHypothesis = hypothesis
	return true


func authenticate(artifact: Dictionary) -> String:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return "Auction result is pending."
	var support := 0.0
	var contradict := 0.0
	for evidence: Dictionary in artifact.evidence:
		support += float(evidence.confidenceWeight)
		if not evidence.contradicts.is_empty() and truth_to_hypothesis(artifact.authenticityTruth) in ["FORGERY", "REPRODUCTION"]:
			contradict += 0.08
	artifact.confidence = clampf(0.12 + support - contradict + upgrade_effect_total("provenance_confidence"), 0.02, 0.97)
	artifact.estimatedValue = appraise(artifact)
	save_game()
	state_changed.emit()
	return "Evidence confidence %d%% — choose your hypothesis." % int(artifact.confidence * 100.0)


func accept_hypothesis(artifact: Dictionary) -> bool:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return false
	if artifact.playerHypothesis == "UNKNOWN":
		return false
	statistics.authentication_attempts += 1
	if artifact.playerHypothesis == truth_to_hypothesis(artifact.authenticityTruth):
		statistics.authentication_correct += 1
		if artifact.playerHypothesis == "FORGERY":
			statistics.forgeries_detected += 1
	artifact.estimatedValue = appraise(artifact)
	save_game()
	state_changed.emit()
	return true


func authentication_accuracy() -> float:
	var attempts := int(statistics.get("authentication_attempts", 0))
	return 0.0 if attempts == 0 else float(statistics.get("authentication_correct", 0)) / float(attempts)


func public_appraisal_quote(artifact: Dictionary) -> int:
	var hypothesis: String = artifact.get("playerHypothesis", "UNKNOWN")
	var claim_multiplier: float = {
		"GENUINE": 1.10,
		"GENUINE_WITH_PERIOD_REPAIR": 1.02,
		"GENUINE_WITH_MODERN_REPAIR": 0.88,
		"REPRODUCTION": 0.62,
		"FORGERY": 0.38,
		"UNKNOWN": 0.78
	}.get(hypothesis, 0.78)
	var confidence_factor := 0.86 + clampf(float(artifact.get("confidence", 0.0)), 0.0, 1.0) * 0.14
	var condition := (float(artifact.cleanliness) * 0.18 + float(artifact.mechanicalCondition) * 0.24 + float(artifact.historicalIntegrity) * 0.30 + float(artifact.restorationQuality) * 0.12) / 84.0
	var trend := 1.0 + float(market_state.get(artifact.category, 0)) / 100.0 + float(daily_modifiers.get("market_all", 0)) / 100.0
	var listing_bonus := 1.0 + upgrade_effect_total("display_bonus") + upgrade_effect_total("appraisal_precision") * float(artifact.confidence)
	return maxi(20, int(float(artifact.baseValue) * float(artifact.trueRarity) * float(artifact.trueHistoricalSignificance) * claim_multiplier * confidence_factor * condition * trend * listing_bonus))


func appraise(artifact: Dictionary) -> int:
	return public_appraisal_quote(artifact)


func list_auction(artifact: Dictionary, starting: int, reserve: int, confidence: float, disclosure: String = "UNCERTAIN", displayed_appraisal: int = -1) -> bool:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return false
	if starting < 0 or reserve < 0:
		return false
	# Freeze the public appraisal already shown to the player at the listing
	# boundary. Replay feedback must never reconstruct this from hidden truth.
	var estimated_value: Variant = artifact.get("estimatedValue", null)
	var public_appraisal := 0
	if displayed_appraisal >= 0:
		public_appraisal = displayed_appraisal
	elif estimated_value is int or estimated_value is float:
		public_appraisal = maxi(0, int(estimated_value))
	artifact.listing = {"starting": starting, "reserve": reserve, "confidence": confidence, "disclosure": disclosure, "publicAppraisal": public_appraisal}
	_persist_authoritative_tutorial_action("AUCTION_LISTED")
	state_changed.emit()
	return true


func selected_bidders(artifact: Dictionary, grand_reserve: bool = false) -> Array:
	var available := RuntimeRegistry.bidders.size()
	var wanted := mini(available, (8 if grand_reserve else 6) + int(upgrade_effect_total("bidder_reach")) + int(daily_modifiers.get("bidder_reach", 0)))
	if grand_reserve:
		wanted = maxi(8, wanted)
	var start := posmod(stable_hash("bidders|%d|%d|%s" % [master_seed, day, artifact.uniqueId]), available)
	var selected_profiles: Array = []
	for offset in range(wanted):
		selected_profiles.append(RuntimeRegistry.get_bidder(start + offset))
	return selected_profiles


func bidder_matches_profile_tags(artifact: Dictionary, bidder: Dictionary) -> bool:
	var preferred_tags: Array = artifact.get("auctionProfile", {}).get("preferredBidderTags", [])
	if preferred_tags.is_empty():
		return false
	var bidder_tokens: Array = [String(bidder.get("id", "")).to_lower(), String(bidder.get("name", "")).to_lower().replace(" ", "_")]
	for category_value: Variant in bidder.get("preferredCategories", []):
		bidder_tokens.append(String(category_value).to_lower())
	for tag_value: Variant in preferred_tags:
		var tag := String(tag_value).to_lower().replace(" ", "_")
		if bidder_tokens.has(tag) or String(bidder.get("name", "")).to_lower().contains(tag.replace("_", " ")):
			return true
	return false


func _listing_public_support_score(artifact: Dictionary) -> float:
	# This score is deliberately limited to facts already shown to the player.
	# Do not add authenticityTruth, rarity, value, originality, auction-profile
	# tuning, or any other canonical/hidden field here.
	# `artifact.confidence` is the authoritative, currently displayed report
	# confidence. New artifacts carry a zeroed listing stub, so that stub must not
	# override the pre-listing public state shown by the UI.
	var reported_confidence := clampf(float(artifact.get("confidence", 0.0)), 0.0, 1.0)
	var provenance_known: bool = artifact.get("knownClues", []).has("PROVENANCE")
	var condition_score := clampf((float(artifact.get("cleanliness", 0.0)) + float(artifact.get("surfaceCondition", 0.0)) + float(artifact.get("mechanicalCondition", 0.0))) / 300.0, 0.0, 1.0)
	return reported_confidence * 0.65 + (0.20 if provenance_known else 0.0) + condition_score * 0.15


func listing_public_support(artifact: Dictionary, selected_disclosure: String = "") -> Dictionary:
	# Presentation-safe calibration for the listing UI. Disclosure values describe
	# claim strength; they never stand in for the evidence/support state itself.
	var score := _listing_public_support_score(artifact)
	var band := "LOW"
	if score >= 0.84:
		band = "HIGH"
	elif score >= 0.52:
		band = "MEDIUM"
	var disclosure := selected_disclosure.to_upper()
	if disclosure.is_empty():
		disclosure = String(artifact.get("listing", {}).get("disclosure", "")).to_upper()
	var support_strength: int = {"LOW": 0, "MEDIUM": 1, "HIGH": 2}.get(band, 0)
	var claim_strength: int = {"UNCERTAIN": 0, "LIKELY": 1, "CERTAIN": 2}.get(disclosure, support_strength)
	var risk := "BALANCED"
	if not disclosure.is_empty():
		if claim_strength > support_strength:
			risk = "OVERCLAIM"
		elif claim_strength < support_strength:
			risk = "UNDERCLAIM"
	return {"band": band, "risk": risk}


func listing_public_status_tags(artifact: Dictionary, selected_disclosure: String = "") -> Array:
	# A compact, display-only bridge from the exact public facts available while
	# listing to the same causal vocabulary used by auction reactions. This never
	# reads authenticity truth, rarity, hidden value, bidder thresholds or tuning.
	var condition_score: float = clampf(
		(float(artifact.get("cleanliness", 0.0)) + float(artifact.get("surfaceCondition", 0.0)) + float(artifact.get("mechanicalCondition", 0.0))) / 300.0,
		0.0,
		1.0
	)
	var provenance_known: bool = artifact.get("knownClues", []) is Array and artifact.get("knownClues", []).has("PROVENANCE")
	var disclosure: String = selected_disclosure.to_upper()
	if disclosure.is_empty():
		disclosure = String(artifact.get("listing", {}).get("disclosure", "UNCERTAIN")).to_upper()
	var disclosure_balanced := String(listing_public_support(artifact, disclosure).get("risk", "BALANCED")) == "BALANCED"
	return [
		{"code": "CONDITION_GOOD" if condition_score >= 0.72 else "CONDITION_RISK", "category": "CONDITION", "polarity": "POSITIVE" if condition_score >= 0.72 else "NEGATIVE"},
		{"code": "PROVENANCE_STRONG" if provenance_known else "PROVENANCE_UNCERTAIN", "category": "PROVENANCE", "polarity": "POSITIVE" if provenance_known else "NEGATIVE"},
		{"code": "DISCLOSURE_CLEAR" if disclosure_balanced else "DISCLOSURE_UNCLEAR", "category": "DISCLOSURE", "polarity": "POSITIVE" if disclosure_balanced else "NEGATIVE"}
	]


func auction_disclosure_factor(artifact: Dictionary) -> float:
	# One calibrated factor replaces the old certainty bonus plus separate
	# uncertainty penalty. Matching the public support band is strongest; an
	# unsupported stronger claim is deliberately the costliest choice.
	var listing: Dictionary = artifact.get("listing", {})
	var disclosure := String(listing.get("disclosure", "UNCERTAIN")).to_upper()
	var support: Dictionary = listing_public_support(artifact, disclosure)
	var band := String(support.get("band", "LOW"))
	var calibrated := {
		"LOW": {"UNCERTAIN": 1.015, "LIKELY": 0.94, "CERTAIN": 0.78},
		"MEDIUM": {"UNCERTAIN": 0.97, "LIKELY": 1.025, "CERTAIN": 0.93},
		"HIGH": {"UNCERTAIN": 0.92, "LIKELY": 0.985, "CERTAIN": 1.04}
	}
	var base_factor := float(calibrated.get(band, calibrated.LOW).get(disclosure, 0.78))
	# Authored scrutiny controls how strongly the public support/claim mismatch is
	# priced, but it never participates in the support-band derivation itself.
	# Legacy specs without the field retain the calibrated default intensity.
	var profile: Dictionary = artifact.get("auctionProfile", {})
	var authored_scrutiny := clampf(maxf(0.0, float(profile.get("disclosureScrutiny", 1.0))), 0.0, 1.50)
	# Stage difficulty magnifies unsupported-claim pressure exactly once, while a
	# well-supported disclosure keeps the same earned bonus at every Stage.
	var stage_pressure := 1.0 if base_factor >= 1.0 else stage_difficulty_multiplier()
	return clampf(1.0 + (base_factor - 1.0) * authored_scrutiny * stage_pressure, 0.45, 1.12)


func auction_scrutiny_factors(artifact: Dictionary, bidder: Dictionary) -> Dictionary:
	var profile: Dictionary = artifact.get("auctionProfile", {})
	var difficulty := stage_difficulty_multiplier()
	var gap_difficulty := minf(difficulty, 1.66)
	var condition_score := clampf((float(artifact.cleanliness) + float(artifact.surfaceCondition) + float(artifact.mechanicalCondition)) / 300.0, 0.0, 1.0)
	var condition_sensitivity := maxf(0.0, float(profile.get("conditionSensitivity", 0.0)))
	var provenance_scrutiny := maxf(0.0, float(profile.get("provenanceScrutiny", 0.0)))
	var provenance_gap := 0.0 if artifact.get("knownClues", []).has("PROVENANCE") else 1.0
	return {
		"preference": 1.08 if bidder_matches_profile_tags(artifact, bidder) else 1.0,
		# Each channel consumes the canonical stage multiplier once. These are
		# player-visible condition/disclosure/provenance facts, never truth data.
		"condition": clampf(1.0 - (1.0 - condition_score) * condition_sensitivity * 0.18 * gap_difficulty, 0.35, 1.0),
		"disclosure": auction_disclosure_factor(artifact),
		"provenance": clampf(1.0 - provenance_gap * provenance_scrutiny * 0.08 * gap_difficulty, 0.50, 1.0),
		"stageDifficulty": difficulty
	}


func auction_reserve_pressure_factor(artifact: Dictionary, reserve: int, base_value: int) -> float:
	var strategy_value: Variant = artifact.get("auctionProfile", {}).get("reserveStrategy", "")
	var pressure := 0.0
	if strategy_value is Dictionary:
		pressure = clampf(float(strategy_value.get("appraisalRatio", 0.0)), 0.0, 1.0)
	elif strategy_value is int or strategy_value is float:
		pressure = maxf(0.0, float(strategy_value))
	else:
		pressure = {
			"CONSERVATIVE": 0.35,
			"BALANCED": 0.55,
			"ASSERTIVE": 0.80,
			"PRESTIGE": 1.00
		}.get(String(strategy_value).to_upper(), 0.0)
	if pressure <= 0.0 or base_value <= 0:
		return 1.0
	var reserve_ratio := float(reserve) / float(base_value)
	var excess := maxf(0.0, reserve_ratio - 0.68)
	return clampf(1.0 - excess * pressure * 0.16 * stage_difficulty_multiplier(), 0.55, 1.0)


func auction_public_reason_tags(artifact: Dictionary, bidder: Dictionary = {}, action: String = "BID", outcome: Dictionary = {}) -> Array:
	# These compact reasons deliberately consume player-visible state only. They
	# explain an auction result without revealing authenticity, rarity, original
	# parts, historical significance, bidder maximums, or any other truth field.
	var normalized_action := action.to_upper()
	var negative_action := normalized_action in ["DROPOUT", "NO_BID", "NO_SALE"]
	var condition_score := clampf((float(artifact.get("cleanliness", 0.0)) + float(artifact.get("surfaceCondition", 0.0)) + float(artifact.get("mechanicalCondition", 0.0))) / 300.0, 0.0, 1.0)
	var known_clues: Array = artifact.get("knownClues", [])
	var provenance_known := known_clues.has("PROVENANCE")
	var listing: Dictionary = artifact.get("listing", {})
	var disclosure := String(listing.get("disclosure", "UNCERTAIN")).to_upper()
	var support: Dictionary = listing_public_support(artifact, disclosure)
	var disclosure_balanced := String(support.get("risk", "BALANCED")) == "BALANCED"
	var public_support_score := _listing_public_support_score(artifact)
	var candidates: Array = []
	if negative_action:
		var outcome_reserve := int(outcome.get("reserve", listing.get("reserve", 0)))
		var outcome_hammer := int(outcome.get("hammer", 0))
		var reserve_met := bool(outcome.get("reserve_met", false))
		if not reserve_met and outcome_reserve > outcome_hammer:
			candidates.append({"code": "RESERVE_TOO_HIGH", "category": "PRICE", "polarity": "NEGATIVE"})
		if not provenance_known:
			candidates.append({"code": "PROVENANCE_UNCERTAIN", "category": "PROVENANCE", "polarity": "NEGATIVE"})
		if condition_score < 0.68:
			candidates.append({"code": "CONDITION_RISK", "category": "CONDITION", "polarity": "NEGATIVE"})
		if not disclosure_balanced:
			candidates.append({"code": "DISCLOSURE_UNCLEAR", "category": "DISCLOSURE", "polarity": "NEGATIVE"})
	else:
		if provenance_known:
			candidates.append({"code": "PROVENANCE_STRONG", "category": "PROVENANCE", "polarity": "POSITIVE"})
		if condition_score >= 0.72:
			candidates.append({"code": "CONDITION_GOOD", "category": "CONDITION", "polarity": "POSITIVE"})
		if disclosure_balanced and public_support_score >= 0.30:
			candidates.append({"code": "DISCLOSURE_CLEAR", "category": "DISCLOSURE", "polarity": "POSITIVE"})
	# The bidder argument is accepted for a stable generic renderer contract, but
	# intentionally does not affect reasons unless a future public bidder trait is
	# explicitly surfaced to the player. No candidate is a valid legacy-safe
	# result; auction outcomes are not retroactively presented as decision inputs.
	return candidates.slice(0, mini(2, candidates.size()))


func bidder_maximum(artifact: Dictionary, bidder: Dictionary, base_value: int, variance: float) -> int:
	var preferred := 1.18 if artifact.category in bidder.get("preferredCategories", []) else 0.84
	var rarity_factor := 1.0 + (float(artifact.trueRarity) - 1.0) * (float(bidder.get("rarityBias", 1.0)) - 0.6) * 0.32
	var condition_score := (float(artifact.cleanliness) + float(artifact.surfaceCondition) + float(artifact.mechanicalCondition)) / 300.0
	var condition_factor := 0.72 + condition_score * float(bidder.get("conditionBias", 1.0)) * 0.42
	var originality_score := clampf(float(artifact.originalParts) / maxf(1.0, float(artifact.originalParts + artifact.replacementParts)), 0.0, 1.0)
	var originality_factor := 0.72 + originality_score * float(bidder.get("originalityBias", 1.0)) * 0.35
	var reported_confidence := clampf(float(artifact.get("listing", {}).get("confidence", artifact.get("confidence", 0.0))), 0.0, 1.0)
	var authenticity_factor := (0.75 + reported_confidence * 0.35) * float(bidder.get("authenticityBias", 1.0))
	var risk_factor := 0.82 + float(bidder.get("riskTolerance", 0.5)) * (0.24 if reported_confidence < 0.6 else 0.10)
	var listing_factor := 1.0 + upgrade_effect_total("listing_bonus") + float(daily_modifiers.get("listing_bonus", 0.0))
	var scrutiny := auction_scrutiny_factors(artifact, bidder)
	var willingness := float(base_value) * preferred * rarity_factor * condition_factor * originality_factor * authenticity_factor * risk_factor * listing_factor * variance
	willingness *= float(scrutiny.preference) * float(scrutiny.condition) * float(scrutiny.disclosure) * float(scrutiny.provenance)
	return mini(int(bidder.get("budget", 0)), maxi(0, int(willingness)))


func upgrade_effect_total_for_ids(effect_type: String, upgrade_ids: Array) -> float:
	var total := 0.0
	for upgrade_value: Variant in upgrade_ids:
		var upgrade := RuntimeRegistry.get_upgrade(String(upgrade_value))
		if upgrade.get("effect", {}).get("type", "") == effect_type:
			total += float(upgrade.effect.get("value", 0.0))
	return total


func finite_dictionary_number(source: Dictionary, key: String, fallback: float = 0.0) -> float:
	var value: Variant = source.get(key, fallback)
	if (value is int or value is float) and is_finite(float(value)):
		return float(value)
	return fallback


func finite_numeric_dictionary_valid(source: Variant) -> bool:
	if not source is Dictionary:
		return false
	for value: Variant in source.values():
		if (not value is int and not value is float) or not is_finite(float(value)):
			return false
	return true


func saved_upgrade_ids_valid(source: Variant) -> bool:
	if not source is Array:
		return false
	var seen := {}
	for value: Variant in source:
		if not value is String:
			return false
		var upgrade_id := String(value)
		if upgrade_id.is_empty() or seen.has(upgrade_id) or RuntimeRegistry.get_upgrade(upgrade_id).is_empty():
			return false
		seen[upgrade_id] = true
	return true


func auction_public_substantiation_for_campaign(artifact: Dictionary, campaign: Dictionary) -> String:
	var case_id := String(artifact.get("caseId", ""))
	var case_states_value: Variant = campaign.get("caseStates", {})
	if case_id.is_empty() or not case_states_value is Dictionary or not case_states_value.has(case_id):
		return "NO_CASE"
	var case_state_value: Variant = case_states_value.get(case_id, {})
	if not case_state_value is Dictionary:
		return "INCONCLUSIVE"
	var case_state: Dictionary = case_state_value
	if not bool(case_state.get("resolved", false)):
		return "PENDING"
	var resolution_value: Variant = case_state.get("resolutionResult", {})
	if not resolution_value is Dictionary:
		return "INCONCLUSIVE"
	var substantiation := String(resolution_value.get("substantiation", "INCONCLUSIVE"))
	return substantiation if substantiation in ["STRONG", "PLAUSIBLE", "INCONCLUSIVE"] else "INCONCLUSIVE"


func auction_public_substantiation(artifact: Dictionary) -> String:
	return auction_public_substantiation_for_campaign(artifact, campaign_state)


func auction_public_decisions_with_context(artifact: Dictionary, grand_reserve: bool, context: Dictionary) -> Dictionary:
	var listing: Dictionary = artifact.get("listing", {})
	var public_appraisal: int = maxi(0, _cached_public_appraisal(artifact))
	var appraisal_divisor: float = maxf(1.0, float(public_appraisal))
	var provenance_known: bool = artifact.get("knownClues", []).has("PROVENANCE")
	var resolved_stage := clampi(int(context.get("stage", 1)), 1, 10)
	var context_day := maxi(0, int(context.get("day", 0)))
	var context_market: Dictionary = context.get("marketState", default_market_state()) if context.get("marketState", {}) is Dictionary else default_market_state()
	var context_daily: Dictionary = context.get("dailyModifiers", {}) if context.get("dailyModifiers", {}) is Dictionary else {}
	var context_upgrades: Array = context.get("upgrades", []) if context.get("upgrades", []) is Array else []
	var context_campaign: Dictionary = context.get("campaign", default_campaign_state()) if context.get("campaign", {}) is Dictionary else default_campaign_state()
	var difficulty := RuntimeRegistry.stage_difficulty_multiplier(resolved_stage)
	return {
		"listingUid": String(artifact.get("uniqueId", "")),
		"specId": String(artifact.get("artifactSpecId", "")),
		"stage": resolved_stage,
		"day": context_day,
		"grandReserve": grand_reserve,
		"publicAppraisal": public_appraisal,
		"reportedConfidence": clampf(float(listing.get("confidence", artifact.get("confidence", 0.0))), 0.0, 1.0),
		"starting": int(listing.get("starting", 0)),
		"reserve": int(listing.get("reserve", 0)),
		"startingRatio": snappedf(float(listing.get("starting", 0)) / appraisal_divisor, 0.0001),
		"reserveRatio": snappedf(float(listing.get("reserve", 0)) / appraisal_divisor, 0.0001),
		"disclosure": String(listing.get("disclosure", "UNCERTAIN")),
		"condition": {
			"cleanliness": snappedf(float(artifact.get("cleanliness", 0.0)), 0.01),
			"surface": snappedf(float(artifact.get("surfaceCondition", 0.0)), 0.01),
			"mechanical": snappedf(float(artifact.get("mechanicalCondition", 0.0)), 0.01)
		},
		"provenanceKnown": provenance_known,
		"substantiation": auction_public_substantiation_for_campaign(artifact, context_campaign),
		"activeModifiers": {
			"stageDifficulty": snappedf(difficulty, 0.000001),
			"marketCategory": int(finite_dictionary_number(context_market, String(artifact.get("category", "")), 0.0)),
			"marketAll": int(finite_dictionary_number(context_daily, "market_all", 0.0)),
			"displayBonus": snappedf(upgrade_effect_total_for_ids("display_bonus", context_upgrades), 0.000001),
			"appraisalPrecision": snappedf(upgrade_effect_total_for_ids("appraisal_precision", context_upgrades), 0.000001),
			"listingBonus": snappedf(upgrade_effect_total_for_ids("listing_bonus", context_upgrades) + finite_dictionary_number(context_daily, "listing_bonus", 0.0), 0.000001),
			"bidderReach": int(upgrade_effect_total_for_ids("bidder_reach", context_upgrades)) + int(finite_dictionary_number(context_daily, "bidder_reach", 0.0)),
			"auctionFeeReduction": snappedf(upgrade_effect_total_for_ids("auction_fee_reduction", context_upgrades) + finite_dictionary_number(context_daily, "auction_fee_discount", 0.0), 0.000001)
		}
	}


func auction_public_decisions(artifact: Dictionary, grand_reserve: bool = false) -> Dictionary:
	return auction_public_decisions_with_context(artifact, grand_reserve, {
		"stage": current_stage,
		"day": day,
		"marketState": market_state,
		"dailyModifiers": daily_modifiers,
		"upgrades": owned_upgrades,
		"campaign": campaign_state
	})


func auction_public_fingerprint(decisions: Dictionary) -> String:
	return "AUC-%d" % absi(stable_hash(JSON.stringify(canonicalize_json_numeric_tree(decisions))))


func auction_public_bid(bid: Dictionary) -> Dictionary:
	return {"bidderId": String(bid.get("bidderId", "")), "amount": int(bid.get("amount", 0))}


func build_pending_auction_cue_queue(result: Dictionary) -> Array:
	var queue: Array = []
	var first_bidder_id := ""
	if not result.get("participants", []).is_empty():
		first_bidder_id = String(result.get("participants", [])[0].get("id", ""))
	queue.append({"phase": "ENTRY", "bidderId": first_bidder_id, "visibleBids": []})
	queue.append({"phase": "CALL", "bidderId": first_bidder_id, "amount": int(result.get("opening", 0)), "visibleBids": []})
	var bids: Array = result.get("bids", [])
	var visible_bids: Array = []
	for bid: Dictionary in bids.slice(maxi(0, bids.size() - 3)):
		var public_bid := auction_public_bid(bid)
		visible_bids.append(public_bid)
		queue.append({"phase": "BID", "bidderId": public_bid.bidderId, "amount": public_bid.amount, "visibleBids": visible_bids.duplicate(true)})
	var public_dropout: Dictionary = {}
	if not result.get("dropouts", []).is_empty():
		var dropout: Dictionary = result.get("dropouts", [])[-1]
		public_dropout = {"bidderId": String(dropout.get("bidderId", "")), "reason": String(dropout.get("reason", ""))}
		queue.append({"phase": "DROPOUT", "bidderId": public_dropout.bidderId, "dropoutReason": public_dropout.reason, "visibleBids": visible_bids.duplicate(true)})
	var final_bidder_id := String(result.get("winnerId", ""))
	if final_bidder_id.is_empty() and not public_dropout.is_empty():
		final_bidder_id = String(public_dropout.get("bidderId", ""))
	if final_bidder_id.is_empty():
		final_bidder_id = first_bidder_id
	var final_bids: Array = []
	for bid: Dictionary in bids.slice(maxi(0, bids.size() - 4)):
		final_bids.append(auction_public_bid(bid))
	queue.append({
		"phase": "SOLD" if bool(result.get("reserve_met", false)) else "NO_SALE",
		"bidderId": final_bidder_id,
		"amount": int(result.get("hammer", 0)),
		"dropoutReason": String(public_dropout.get("reason", "")),
		"visibleBids": final_bids
	})
	return queue


func sanitized_public_reason_tags(value: Variant, maximum: int = 2) -> Array:
	var public_tags: Array = []
	if not value is Array or maximum <= 0:
		return public_tags
	for reason_value: Variant in value:
		if not reason_value is Dictionary:
			continue
		var reason: Dictionary = reason_value
		var code := String(reason.get("code", ""))
		var category := String(reason.get("category", ""))
		var polarity := String(reason.get("polarity", ""))
		if code.is_empty() or category.is_empty() or not polarity in ["POSITIVE", "NEGATIVE", "NEUTRAL"]:
			continue
		public_tags.append({"code": code, "category": category, "polarity": polarity})
		if public_tags.size() >= maximum:
			break
	return public_tags


func pending_cue_public_reason_tags(cue: Dictionary, frozen_result: Dictionary) -> Array:
	# The canonical persisted cue queue remains byte-for-byte unchanged. Public
	# reasons are projected only when the renderer asks for the frozen snapshot.
	var phase := String(cue.get("phase", ""))
	if phase in ["SOLD", "NO_SALE"]:
		return sanitized_public_reason_tags(frozen_result.get("reasonTags", []), 2)
	var bidder_id := String(cue.get("bidderId", ""))
	if bidder_id.is_empty():
		return []
	if phase == "DROPOUT":
		for dropout_value: Variant in frozen_result.get("dropouts", []):
			if dropout_value is Dictionary and String(dropout_value.get("bidderId", "")) == bidder_id:
				return sanitized_public_reason_tags(dropout_value.get("reasonTags", []), 2)
	elif phase == "BID":
		for participant_value: Variant in frozen_result.get("participants", []):
			if participant_value is Dictionary and String(participant_value.get("id", "")) == bidder_id:
				return sanitized_public_reason_tags(participant_value.get("reasonTags", []), 2)
	return []


func public_pending_auction_cue_queue(cue_queue: Array, frozen_result: Dictionary) -> Array:
	var public_queue: Array = []
	for cue_value: Variant in cue_queue:
		if not cue_value is Dictionary:
			continue
		var public_cue: Dictionary = cue_value.duplicate(true)
		public_cue["reasonTags"] = pending_cue_public_reason_tags(public_cue, frozen_result)
		public_queue.append(public_cue)
	return public_queue


func public_pending_auction_result(result: Dictionary) -> Dictionary:
	var public_bids: Array = []
	for bid: Dictionary in result.get("bids", []):
		public_bids.append(auction_public_bid(bid))
	var public_dropouts: Array = []
	for dropout: Dictionary in result.get("dropouts", []):
		public_dropouts.append({"bidderId": String(dropout.get("bidderId", "")), "reason": String(dropout.get("reason", ""))})
	var public_participants: Array = []
	for participant: Dictionary in result.get("participants", []):
		public_participants.append({"id": String(participant.get("id", ""))})
	return {
		"opening": int(result.get("opening", 0)),
		"reserve": int(result.get("reserve", 0)),
		"bids": public_bids,
		"participants": public_participants,
		"dropouts": public_dropouts,
		"hammer": int(result.get("hammer", 0)),
		"fee": int(result.get("fee", 0)),
		"net": int(result.get("net", 0)),
		"winnerId": String(result.get("winnerId", "")),
		"reserve_met": bool(result.get("reserve_met", false)),
		"sale_status": String(result.get("sale_status", "NO_SALE")),
		"reasonTags": result.get("reasonTags", []).duplicate(true),
		"publicFingerprint": String(result.get("publicFingerprint", "")),
		"transactionId": String(result.get("transactionId", ""))
	}


func pending_auction_public_state(transaction_id: String = "") -> Dictionary:
	var normalized: Dictionary = normalize_pending_auction(pending_auction)
	if String(normalized.get("status", "NONE")) == "NONE":
		return {"ok": false, "code": "NO_PENDING_AUCTION", "status": "NONE"}
	if not transaction_id.is_empty() and transaction_id != String(normalized.get("transactionId", "")):
		return {"ok": false, "code": "PENDING_AUCTION_ID_MISMATCH", "status": normalized.status}
	return {
		"ok": true,
		"code": "OK",
		"status": String(normalized.status),
		"transactionId": String(normalized.transactionId),
		"artifactId": String(normalized.artifactId),
		"publicFingerprint": String(normalized.publicFingerprint),
		"decisions": normalized.decisions.duplicate(true),
		"result": public_pending_auction_result(normalized.result),
		"receipt": normalized.receipt.duplicate(true),
		"cueQueue": public_pending_auction_cue_queue(normalized.cueQueue, normalized.result),
		"cueIndex": int(normalized.cueIndex),
		"createdDay": int(normalized.createdDay),
		"grandReserve": bool(normalized.grandReserve)
	}


func _build_pending_auction_state(artifact: Dictionary, grand_reserve: bool) -> Dictionary:
	if artifact.is_empty() or artifact.get("listing", {}).is_empty() or artifact.get("sold", false) or not inventory.has(artifact):
		return {"ok": false, "code": "AUCTION_LOT_UNAVAILABLE"}
	if not String(artifact.get("caseId", "")).is_empty() and not bool(artifact.get("caseResolved", false)):
		return {"ok": false, "code": "UNRESOLVED_CASE_ARTIFACT"}
	var decisions: Dictionary = auction_public_decisions(artifact, grand_reserve)
	var public_fingerprint: String = auction_public_fingerprint(decisions)
	var result: Dictionary = auction_with_bidders(artifact, selected_bidders(artifact, grand_reserve), grand_reserve)
	var transaction_id: String = "auction_%d_%d_%d" % [day, absi(stable_hash(public_fingerprint)), auction_history.size()]
	result["publicFingerprint"] = public_fingerprint
	result["transactionId"] = transaction_id
	return {
		"ok": true,
		"code": "OK",
		"state": {
			"schemaVersion": 1,
			"status": "PENDING",
			"transactionId": transaction_id,
			"artifactId": String(artifact.get("uniqueId", "")),
			"publicFingerprint": public_fingerprint,
			"decisions": decisions,
			"result": result,
			"receipt": {},
			"cueQueue": build_pending_auction_cue_queue(result),
			"cueIndex": 0,
			"createdDay": day,
			"grandReserve": grand_reserve
		}
	}


func create_pending_auction(artifact: Dictionary, grand_reserve: bool = false, save_path: String = "") -> Dictionary:
	last_action_error = ""
	if grand_reserve_active():
		if grand_reserve and String(grand_reserve_session.get("phase", "")) == "AUCTION_PENDING" \
			and String(pending_auction.get("artifactId", "")) == String(artifact.get("uniqueId", "")):
			return pending_auction_public_state()
		last_action_error = "PENDING_AUCTION_LOCKED"
		return {"ok": false, "code": last_action_error}
	if grand_reserve:
		# Reserve-labelled snapshots are created only by BEGIN/NEXT so a public
		# caller cannot bypass the three-lot receipt/finalization coordinator.
		last_action_error = "GRAND_RESERVE_SESSION_REQUIRED"
		return {"ok": false, "code": last_action_error}
	var built := _build_pending_auction_state(artifact, grand_reserve)
	if not bool(built.get("ok", false)):
		last_action_error = String(built.get("code", "AUCTION_LOT_UNAVAILABLE"))
		return {"ok": false, "code": last_action_error}
	var created: Dictionary = built.get("state", {})
	var public_fingerprint := String(created.get("publicFingerprint", ""))
	if pending_auction_active():
		if String(pending_auction.get("artifactId", "")) != String(artifact.get("uniqueId", "")):
			last_action_error = "PENDING_AUCTION_LOCKED"
			return {"ok": false, "code": last_action_error, "transactionId": String(pending_auction.get("transactionId", ""))}
		if String(pending_auction.get("publicFingerprint", "")) != public_fingerprint:
			last_action_error = "STALE_PENDING_AUCTION"
			return {"ok": false, "code": last_action_error, "transactionId": String(pending_auction.get("transactionId", ""))}
		return pending_auction_public_state()
	var previous: Dictionary = pending_auction.duplicate(true)
	var previous_stage_run_state: Dictionary = stage_run_state.duplicate(true)
	pending_auction = created
	_record_listing_telemetry(pending_auction)
	var created_saved: bool = save_game() if save_path.is_empty() else save_game(save_path)
	if not created_saved:
		pending_auction = previous
		stage_run_state = previous_stage_run_state
		last_action_error = "PENDING_AUCTION_SAVE_FAILED"
		return {"ok": false, "code": last_action_error}
	state_changed.emit()
	return pending_auction_public_state(String(created.get("transactionId", "")))


func set_pending_auction_cue_index(transaction_id: String, cue_index: int, save_path: String = "") -> Dictionary:
	if not pending_auction_active() or transaction_id != String(pending_auction.get("transactionId", "")):
		return {"ok": false, "code": "PENDING_AUCTION_ID_MISMATCH"}
	var cue_queue: Array = pending_auction.get("cueQueue", [])
	if cue_index < 0 or cue_index >= cue_queue.size():
		return {"ok": false, "code": "INVALID_AUCTION_CUE_INDEX"}
	var previous_index := int(pending_auction.get("cueIndex", 0))
	pending_auction["cueIndex"] = cue_index
	var cue_saved: bool = save_game() if save_path.is_empty() else save_game(save_path)
	if not cue_saved:
		pending_auction["cueIndex"] = previous_index
		return {"ok": false, "code": "PENDING_AUCTION_SAVE_FAILED"}
	state_changed.emit()
	return pending_auction_public_state(transaction_id)


func pending_auction_commit_memory_snapshot() -> Dictionary:
	var artifact_refs: Array = inventory.duplicate()
	var artifact_states: Array = []
	for artifact_value: Variant in artifact_refs:
		artifact_states.append(artifact_value.duplicate(true) if artifact_value is Dictionary else {})
	return {
		"money": money,
		"reputation": reputation,
		"inventoryRefs": artifact_refs,
		"inventoryStates": artifact_states,
		"activeWorkpieceId": String(active_workpiece.get("uniqueId", "")),
		"transactions": transactions.duplicate(true),
		"auctionHistory": auction_history.duplicate(true),
		"statistics": statistics.duplicate(true),
		"campaign": campaign_state.duplicate(true),
		"stageRunState": stage_run_state.duplicate(true),
		"playerProfile": player_profile.duplicate(true),
		"pendingAuction": pending_auction.duplicate(true),
		"grandReserveSession": grand_reserve_session.duplicate(true),
		"rngState": rng.state
	}


func restore_pending_auction_commit_memory(snapshot: Dictionary) -> void:
	var restored_refs: Array = snapshot.get("inventoryRefs", []).duplicate()
	var restored_states: Array = snapshot.get("inventoryStates", [])
	for index in range(mini(restored_refs.size(), restored_states.size())):
		if restored_refs[index] is Dictionary and restored_states[index] is Dictionary:
			var artifact_ref: Dictionary = restored_refs[index]
			artifact_ref.clear()
			artifact_ref.merge(restored_states[index].duplicate(true), true)
	money = int(snapshot.get("money", money))
	reputation = int(snapshot.get("reputation", reputation))
	inventory = restored_refs
	transactions = snapshot.get("transactions", []).duplicate(true)
	auction_history = snapshot.get("auctionHistory", []).duplicate(true)
	statistics = snapshot.get("statistics", default_statistics()).duplicate(true)
	campaign_state = snapshot.get("campaign", default_campaign_state()).duplicate(true)
	stage_run_state = snapshot.get("stageRunState", default_stage_run_state(current_stage)).duplicate(true)
	player_profile = snapshot.get("playerProfile", default_player_profile()).duplicate(true)
	pending_auction = snapshot.get("pendingAuction", default_pending_auction()).duplicate(true)
	grand_reserve_session = snapshot.get("grandReserveSession", default_grand_reserve_session()).duplicate(true)
	rng.state = int(snapshot.get("rngState", rng.state))
	active_workpiece = find_inventory_instance(String(snapshot.get("activeWorkpieceId", "")))


func committed_auction_response(transaction_id: String) -> Dictionary:
	var receipt: Dictionary = {}
	if String(pending_auction.get("transactionId", "")) == transaction_id:
		receipt = pending_auction.get("receipt", {}).duplicate(true) if pending_auction.get("receipt", {}) is Dictionary else {}
		if receipt.is_empty():
			receipt = public_pending_auction_result(pending_auction.get("result", {}))
	if receipt.is_empty():
		for history_value: Variant in auction_history:
			if not history_value is Dictionary:
				continue
			var history: Dictionary = history_value
			var history_result: Dictionary = history.get("result", {}) if history.get("result", {}) is Dictionary else {}
			if String(history_result.get("transactionId", "")) == transaction_id:
				receipt = public_pending_auction_result(history_result)
				break
	if receipt.is_empty():
		return {}
	receipt["ok"] = true
	receipt["code"] = "OK"
	receipt["status"] = "COMMITTED"
	receipt["idempotent"] = true
	return receipt


func _apply_pending_auction_commit(transaction_id: String) -> Dictionary:
	if String(pending_auction.get("transactionId", "")) != transaction_id:
		var prior_receipt: Dictionary = committed_auction_response(transaction_id)
		return prior_receipt if not prior_receipt.is_empty() else {"ok": false, "code": "PENDING_AUCTION_ID_MISMATCH"}
	if String(pending_auction.get("status", "NONE")) == "COMMITTED":
		return committed_auction_response(transaction_id)
	if not pending_auction_active():
		return {"ok": false, "code": "NO_PENDING_AUCTION"}
	# Old pre-atomic saves can contain a durable history row with a still-PENDING
	# handoff. Recover that receipt without applying money, inventory, statistics,
	# tutorial, or RNG effects for a second time.
	for history_value: Variant in auction_history:
		if not history_value is Dictionary:
			continue
		var history: Dictionary = history_value
		if String(history.get("result", {}).get("transactionId", "")) != transaction_id:
			continue
		_record_auction_telemetry(history.get("result", {}) if history.get("result", {}) is Dictionary else {})
		pending_auction["status"] = "COMMITTED"
		pending_auction["cueIndex"] = maxi(0, pending_auction.get("cueQueue", []).size() - 1)
		pending_auction["receipt"] = public_pending_auction_result(history.get("result", {}))
		var recovered := committed_auction_response(transaction_id)
		recovered["_mutationApplied"] = true
		return recovered
	var artifact: Dictionary = find_inventory_instance(String(pending_auction.get("artifactId", "")))
	if artifact.is_empty() or artifact.get("sold", false):
		return {"ok": false, "code": "AUCTION_LOT_UNAVAILABLE"}
	if not String(artifact.get("caseId", "")).is_empty() and not bool(artifact.get("caseResolved", false)):
		return {"ok": false, "code": "UNRESOLVED_CASE_ARTIFACT"}
	var current_decisions: Dictionary = auction_public_decisions(artifact, bool(pending_auction.get("grandReserve", false)))
	var current_fingerprint: String = auction_public_fingerprint(current_decisions)
	if current_fingerprint != String(pending_auction.get("publicFingerprint", "")):
		last_action_error = "STALE_PENDING_AUCTION"
		return {"ok": false, "code": last_action_error, "transactionId": transaction_id, "publicFingerprint": String(pending_auction.get("publicFingerprint", ""))}
	var frozen_result: Dictionary = pending_auction.get("result", {}).duplicate(true)
	var committed_result: Dictionary = apply_sale_result(artifact, frozen_result, bool(pending_auction.get("grandReserve", false)), false)
	pending_auction["status"] = "COMMITTED"
	pending_auction["cueIndex"] = maxi(0, pending_auction.get("cueQueue", []).size() - 1)
	pending_auction["committedDay"] = day
	pending_auction["result"] = frozen_result
	pending_auction["receipt"] = public_pending_auction_result(committed_result)
	var response: Dictionary = pending_auction.get("receipt", {}).duplicate(true)
	response["ok"] = true
	response["code"] = "OK"
	response["status"] = "COMMITTED"
	response["idempotent"] = false
	response["_mutationApplied"] = true
	return response


func commit_pending_auction(transaction_id: String, save_path: String = "") -> Dictionary:
	if String(pending_auction.get("transactionId", "")) == transaction_id \
		and bool(pending_auction.get("grandReserve", false)) \
		and grand_reserve_active():
		return commit_grand_reserve_lot(transaction_id, save_path)
	var memory_snapshot: Dictionary = pending_auction_commit_memory_snapshot()
	var response := _apply_pending_auction_commit(transaction_id)
	var mutation_applied := bool(response.get("_mutationApplied", false))
	response.erase("_mutationApplied")
	if not bool(response.get("ok", false)) or not mutation_applied:
		return response
	var commit_saved: bool = save_game() if save_path.is_empty() else save_game(save_path)
	if not commit_saved:
		restore_pending_auction_commit_memory(memory_snapshot)
		last_action_error = "PENDING_AUCTION_SAVE_FAILED"
		return {"ok": false, "code": last_action_error, "transactionId": transaction_id}
	# The run-save is authoritative. The profile mirror is a recoverable second
	# store and may safely catch up on load if this process stops between writes.
	_reconcile_profile_to_tutorial_run(true)
	state_changed.emit()
	return response


func auction(artifact: Dictionary, grand_reserve: bool = false) -> Dictionary:
	if grand_reserve_active():
		if String(grand_reserve_session.get("phase", "")) == "AUCTION_PENDING" \
			and String(pending_auction.get("artifactId", "")) == String(artifact.get("uniqueId", "")):
			return pending_auction.get("result", {}).duplicate(true)
		return {"ok": false, "code": "PENDING_AUCTION_LOCKED"}
	if grand_reserve:
		return {"ok": false, "code": "GRAND_RESERVE_SESSION_REQUIRED"}
	if pending_auction_active():
		if String(pending_auction.get("artifactId", "")) != String(artifact.get("uniqueId", "")):
			return {"ok": false, "code": "PENDING_AUCTION_LOCKED"}
		return pending_auction.get("result", {}).duplicate(true)
	return auction_with_bidders(artifact, selected_bidders(artifact, grand_reserve), grand_reserve)


func auction_bidder_variances(artifact: Dictionary, bidder_rows: Array) -> Array:
	# Listing choices are intentionally absent from this seed. Controlled price
	# and disclosure counterfactuals therefore share identical bidder variance.
	var auction_rng := RandomNumberGenerator.new()
	auction_rng.seed = stable_hash("auction|%d|%d|%s" % [master_seed, day, artifact.get("uniqueId", "")])
	var variances: Array = []
	for bidder: Dictionary in bidder_rows:
		variances.append({
			"bidderId": String(bidder.get("id", "")),
			"variance": auction_rng.randf_range(0.90, 1.10)
		})
	return variances


func auction_with_bidders(artifact: Dictionary, bidder_rows: Array, grand_reserve: bool = false) -> Dictionary:
	var base_value := appraise(artifact)
	var opening := int(artifact.listing.get("starting", int(base_value * 0.62)))
	var reserve := int(artifact.listing.get("reserve", int(base_value * 0.72)))
	var reserve_pressure := auction_reserve_pressure_factor(artifact, reserve, base_value)
	var participants: Array = []
	var bidder_variances := auction_bidder_variances(artifact, bidder_rows)
	for bidder_index in range(bidder_rows.size()):
		var bidder: Dictionary = bidder_rows[bidder_index]
		var variance := float(bidder_variances[bidder_index].get("variance", 1.0))
		var maximum := int(float(bidder_maximum(artifact, bidder, base_value, variance)) * reserve_pressure)
		participants.append({
			"id": bidder.id, "name": bidder.name, "budget": int(bidder.budget),
			"maxBid": maximum, "aggression": float(bidder.get("competitionAggression", 0.5)),
			"dropoutBehavior": bidder.get("dropoutBehavior", "budget_or_value"), "bidCount": 0
		})
	var bids: Array = []
	var dropouts: Array = []
	var dropout_recorded := {}
	var current := opening
	var winner_id := ""
	var active := true
	var rounds := 0
	while active and rounds < 60:
		active = false
		for participant: Dictionary in participants:
			if participant.id == winner_id:
				continue
			var behavior: String = participant.get("dropoutBehavior", "budget_or_value")
			if behavior == "after_first_bid" and int(participant.bidCount) >= 1:
				if not dropout_recorded.has(participant.id):
					dropouts.append({"bidderId": participant.id, "round": rounds, "reason": "AFTER_FIRST_BID"})
					dropout_recorded[participant.id] = true
				continue
			var increment := maxi(5, int(12.0 + current * (0.025 + participant.aggression * 0.02)))
			var proposed := current + increment
			if proposed <= int(participant.maxBid) and proposed <= int(participant.budget):
				current = proposed
				winner_id = participant.id
				participant.bidCount = int(participant.bidCount) + 1
				bids.append({"bidderId": participant.id, "bidder": participant.name, "amount": current, "budget": participant.budget, "round": rounds})
				active = true
			elif not dropout_recorded.has(participant.id):
				var reason := "BUDGET" if proposed > int(participant.budget) else "VALUE"
				dropouts.append({"bidderId": participant.id, "round": rounds, "reason": reason, "behavior": behavior})
				dropout_recorded[participant.id] = true
		rounds += 1
	# Opening is a listing term, not a completed bid. A no-bid auction therefore
	# has an explicit zero hammer while retaining `opening` separately.
	var hammer := current if not winner_id.is_empty() else 0
	var reserve_met := hammer >= reserve and not winner_id.is_empty()
	var public_outcome := {
		"opening": opening,
		"reserve": reserve,
		"hammer": hammer,
		"reserve_met": reserve_met
	}
	var bidder_by_id := {}
	for bidder: Dictionary in bidder_rows:
		bidder_by_id[String(bidder.get("id", ""))] = bidder
	for participant: Dictionary in participants:
		var participant_action := "WON" if reserve_met and String(participant.get("id", "")) == winner_id else ("BID" if int(participant.get("bidCount", 0)) > 0 else "DROPOUT")
		if not reserve_met and String(participant.get("id", "")) == winner_id:
			participant_action = "NO_SALE"
		participant["finalAction"] = participant_action
		participant["reasonTags"] = auction_public_reason_tags(artifact, bidder_by_id.get(String(participant.get("id", "")), {}), participant_action, public_outcome)
	for dropout: Dictionary in dropouts:
		var dropout_id := String(dropout.get("bidderId", ""))
		dropout["reasonTags"] = auction_public_reason_tags(artifact, bidder_by_id.get(dropout_id, {}), "DROPOUT", public_outcome)
	var public_reasons: Array = []
	if reserve_met:
		public_reasons = auction_public_reason_tags(artifact, bidder_by_id.get(winner_id, {}), "WON", public_outcome)
	else:
		public_reasons = auction_public_reason_tags(artifact, bidder_by_id.get(winner_id, {}), "NO_SALE", public_outcome)
	var base_fee_rate := 0.12 - upgrade_effect_total("auction_fee_reduction") - float(daily_modifiers.get("auction_fee_discount", 0.0))
	var fee := int(hammer * maxf(0.02, base_fee_rate)) if reserve_met else 0
	return {
		"opening": opening, "reserve": reserve, "bids": bids, "participants": participants, "dropouts": dropouts,
		"hammer": hammer, "fee": fee, "net": hammer - fee if reserve_met else 0,
		"winnerId": winner_id, "reserve_met": reserve_met,
		"sale_status": "SOLD" if reserve_met else "NO_SALE",
		"stageDifficulty": stage_difficulty_multiplier(), "reservePressureFactor": reserve_pressure,
		"reasonTags": public_reasons
	}


func sell(artifact: Dictionary, grand_reserve: bool = false) -> Dictionary:
	if grand_reserve_active():
		if String(grand_reserve_session.get("phase", "")) == "AUCTION_PENDING" \
			and String(pending_auction.get("artifactId", "")) == String(artifact.get("uniqueId", "")):
			return commit_grand_reserve_lot(String(pending_auction.get("transactionId", "")))
		return {"ok": false, "code": "PENDING_AUCTION_LOCKED", "sale_status": "BLOCKED", "reserve_met": false, "net": 0}
	if grand_reserve:
		return {"ok": false, "code": "GRAND_RESERVE_SESSION_REQUIRED", "sale_status": "BLOCKED", "reserve_met": false, "net": 0}
	if pending_auction_active():
		if String(pending_auction.get("artifactId", "")) != String(artifact.get("uniqueId", "")):
			return {"ok": false, "code": "PENDING_AUCTION_LOCKED", "sale_status": "BLOCKED", "reserve_met": false, "net": 0}
		return commit_pending_auction(String(pending_auction.get("transactionId", "")))
	if artifact.get("sold", false) or not inventory.has(artifact):
		return {"sale_status": "ALREADY_RECORDED", "reserve_met": false, "net": 0}
	var case_id: String = artifact.get("caseId", "")
	if not case_id.is_empty() and not artifact.get("caseResolved", false):
		return {"sale_status": "CASE_LOCKED", "reserve_met": false, "net": 0, "code": "UNRESOLVED_CASE_ARTIFACT"}
	var creation := create_pending_auction(artifact, grand_reserve)
	if not bool(creation.get("ok", false)):
		return {"ok": false, "code": creation.get("code", "AUCTION_CREATE_FAILED"), "sale_status": "BLOCKED", "reserve_met": false, "net": 0}
	return commit_pending_auction(String(creation.get("transactionId", "")))


func apply_sale_result(artifact: Dictionary, result: Dictionary, grand_reserve: bool = false, persist: bool = true) -> Dictionary:
	var case_id: String = artifact.get("caseId", "")
	var public_appraisal := _cached_public_appraisal(artifact)
	var history_entry := {"day": day, "item": artifact.displayName, "instanceId": artifact.uniqueId, "caseId": case_id, "publicAppraisal": public_appraisal, "grandReserve": grand_reserve, "result": result}
	_record_auction_telemetry(result)
	if not result.reserve_met:
		statistics.no_sales += 1
		history_entry.status = "NO_SALE"
		auction_history.append(history_entry)
		var no_sale_tutorial_advanced: bool = _advance_tutorial_run_event("AUCTION_RECORDED")
		if persist:
			var no_sale_saved: bool = save_game()
			if no_sale_tutorial_advanced and no_sale_saved:
				_reconcile_profile_to_tutorial_run(true)
			state_changed.emit()
		return result
	artifact.sold = true
	money += int(result.net)
	var item_profit := int(result.net) - int(artifact.acquisitionPrice) - int(artifact.restorationCost)
	reputation += 2 if item_profit >= 0 else -1
	statistics.sales += 1
	statistics.profit += item_profit
	statistics.total_auction_revenue += int(result.hammer)
	statistics.biggest_profit = maxi(int(statistics.biggest_profit), item_profit)
	statistics.biggest_loss = mini(int(statistics.biggest_loss), item_profit)
	var disclosed_as: String = artifact.listing.get("disclosure", "UNCERTAIN")
	var classification_correct: bool = artifact.playerHypothesis == truth_to_hypothesis(artifact.authenticityTruth)
	var artifact_case_id: String = artifact.get("caseId", "")
	if not artifact_case_id.is_empty() and campaign_state.get("caseStates", {}).has(artifact_case_id):
		classification_correct = bool(campaign_state.caseStates[artifact_case_id].get("resolutionResult", {}).get("conclusionAccurate", false))
	if disclosed_as == "CERTAIN" and not classification_correct:
		campaign_state.ethics = maxi(0, int(campaign_state.ethics) - 8)
		reputation -= 3
		for relation: Dictionary in campaign_state.relationships.values():
			relation.trust -= 1
	elif disclosed_as in ["CERTAIN", "LIKELY"] and classification_correct:
		campaign_state.ethics = mini(100, int(campaign_state.ethics) + 1)
		campaign_state.collectorNetwork = int(campaign_state.collectorNetwork) + 1
	history_entry.status = "SOLD"
	auction_history.append(history_entry)
	var transaction_id := "sale_%d_%s_%d" % [day, artifact.uniqueId, transactions.size()]
	var sale_transaction := append_money_transaction("sale", artifact.displayName, int(result.net), artifact.uniqueId, "auction")
	# Preserve the historical sale id format used by case ledgers and legacy
	# receipts while still exposing the common before/after cash fields.
	sale_transaction["id"] = transaction_id
	if not case_id.is_empty() and campaign_state.get("caseArtifactLedger", {}).has(case_id):
		# SOLD artifacts leave inventory, so preserve only the public condition and
		# displayed appraisal needed for dynamic replay feedback before erasing it.
		campaign_state.caseArtifactLedger[case_id].publicConditionSnapshot = _public_condition_snapshot(artifact)
		campaign_state.caseArtifactLedger[case_id].publicAppraisalSnapshot = public_appraisal
		campaign_state.caseArtifactLedger[case_id].disposition = "SOLD"
		campaign_state.caseArtifactLedger[case_id].saleTransactionId = transaction_id
	inventory.erase(artifact)
	if active_workpiece == artifact:
		active_workpiece = {}
	var sale_tutorial_advanced: bool = _advance_tutorial_run_event("AUCTION_RECORDED")
	if persist:
		var sale_saved: bool = save_game()
		if sale_tutorial_advanced and sale_saved:
			_reconcile_profile_to_tutorial_run(true)
		state_changed.emit()
	return result


func execute_event(event_id: String, persist: bool = true) -> Dictionary:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return {"ok": false, "code": last_action_error}
	var event := RuntimeRegistry.get_event(event_id)
	if event.is_empty():
		return {}
	var effect: Dictionary = event.effect
	var effect_type: String = effect.get("type", "")
	var target: String = effect.get("target", "")
	var amount: float = float(effect.get("amount", 0.0))
	var mitigation := upgrade_effect_total("event_mitigation") if amount < 0.0 else 0.0
	amount *= 1.0 - mitigation
	match effect_type:
		"money", "commission_credit":
			var money_delta := int(amount)
			money += money_delta
			append_money_transaction("event", event.name, money_delta, "", event_id)
		"reputation":
			reputation += int(amount)
		"museum_trust":
			campaign_state.museumTrust = int(campaign_state.museumTrust) + int(amount)
		"integrity_warning":
			campaign_state.historicalIntegrity = clampi(int(campaign_state.historicalIntegrity) + int(amount), 0, 100)
		"market_modifier":
			if target == "all":
				daily_modifiers.market_all = int(daily_modifiers.get("market_all", 0)) + int(amount)
			else:
				market_state[target] = int(market_state.get(target, 0)) + int(amount)
		"storage_damage":
			var prevention := clampf(upgrade_effect_total("damage_prevention"), 0.0, 0.9)
			var prevention_roll := float(posmod(stable_hash("storage|%d|%s" % [day, event_id]), 10000)) / 10000.0
			if prevention_roll < prevention:
				amount = 0.0
			elif inventory.is_empty():
				daily_modifiers.pending_damage = int(daily_modifiers.get("pending_damage", 0)) + int(amount)
			else:
				var target_artifact: Dictionary = inventory[posmod(day, inventory.size())]
				if not target_artifact.damageInstances.has("SCRATCH"):
					target_artifact.damageInstances.append("SCRATCH")
		_:
			daily_modifiers[target] = float(daily_modifiers.get(target, 0.0)) + amount
	var result := {"eventId": event_id, "name": event.name, "effect": effect.duplicate(true), "appliedAmount": amount}
	event_history.append({"day": day, "eventId": event_id, "result": result})
	if persist:
		save_game()
	state_changed.emit()
	return result


func upgrade_effect_total(effect_type: String) -> float:
	return upgrade_effect_total_for_ids(effect_type, owned_upgrades)


func buy_upgrade(upgrade_id: String) -> bool:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return false
	var upgrade := RuntimeRegistry.get_upgrade(upgrade_id)
	if upgrade.is_empty() or owned_upgrades.has(upgrade_id):
		return false
	var cost := int(upgrade.cost)
	if money < cost:
		return false
	money -= cost
	owned_upgrades.append(upgrade_id)
	var effect_type: String = upgrade.effect.get("type", "")
	if effect_type == "reputation_bonus":
		reputation += int(upgrade.effect.value)
	if effect_type == "museum_trust_bonus":
		campaign_state.museumTrust = int(campaign_state.museumTrust) + int(upgrade.effect.value)
	append_money_transaction("upgrade", upgrade.name, -cost, "", upgrade_id)
	save_game()
	state_changed.emit()
	return true


func complete_commission(commission_id: String, _caller_quality: float) -> Dictionary:
	return {"ok": false, "code": "DEPRECATED_CALLER_QUALITY", "commissionId": commission_id, "net": 0}


func commission_requirement_check(commission: Dictionary, artifact: Dictionary) -> Dictionary:
	var requirements: Dictionary = commission.get("requirements", {}) if commission.get("requirements", {}) is Dictionary else {}
	var missing: Array = []
	if artifact.is_empty() or bool(artifact.get("sold", false)) or not inventory.has(artifact):
		missing.append("ARTIFACT_NOT_OWNED")
	if not String(artifact.get("caseId", "")).is_empty() and not bool(artifact.get("caseResolved", false)):
		missing.append("CASE_UNRESOLVED")
	if bool(requirements.get("requiresInspected", false)) and not bool(artifact.get("inspected", false)):
		missing.append("INSPECTION_REQUIRED")
	if bool(requirements.get("requiresRepaired", false)) and not bool(artifact.get("repaired", false)):
		missing.append("REPAIR_REQUIRED")
	var condition_quality := (float(artifact.get("cleanliness", 0.0)) + float(artifact.get("surfaceCondition", 0.0)) + float(artifact.get("structuralCondition", 0.0)) + float(artifact.get("mechanicalCondition", 0.0))) / 400.0
	var minimum_condition := float(requirements.get("minimumCondition", 0.0))
	if condition_quality < minimum_condition:
		missing.append("CONDITION_TOO_LOW")
	var minimum_integrity := float(requirements.get("minimumIntegrity", 0.0))
	var integrity_quality := clampf(float(artifact.get("historicalIntegrity", 0.0)) / 100.0, 0.0, 1.0)
	if integrity_quality < minimum_integrity:
		missing.append("INTEGRITY_TOO_LOW")
	var minimum_clues := int(requirements.get("minimumClues", 0))
	if (artifact.get("knownClues", []) if artifact.get("knownClues", []) is Array else []).size() < minimum_clues:
		missing.append("MORE_CLUES_REQUIRED")
	var minimum_confidence := float(requirements.get("minimumConfidence", 0.0))
	if float(artifact.get("confidence", 0.0)) < minimum_confidence:
		missing.append("CONFIDENCE_TOO_LOW")
	return {
		"ok": missing.is_empty(),
		"missing": missing,
		"conditionQuality": clampf(condition_quality, 0.0, 1.0),
		"integrityQuality": integrity_quality,
		"confidence": clampf(float(artifact.get("confidence", 0.0)), 0.0, 1.0),
		"clueCount": (artifact.get("knownClues", []) if artifact.get("knownClues", []) is Array else []).size()
	}


func get_commission_public_state() -> Array:
	var completed_ids: Array = campaign_state.get("completedCommissionIds", []) if campaign_state.get("completedCommissionIds", []) is Array else []
	var used_artifacts: Dictionary = campaign_state.get("commissionArtifactUses", {}) if campaign_state.get("commissionArtifactUses", {}) is Dictionary else {}
	var rows: Array = []
	for commission: Dictionary in RuntimeRegistry.commissions:
		var eligible: Array = []
		for artifact: Dictionary in inventory:
			var artifact_id := String(artifact.get("uniqueId", ""))
			if artifact_id.is_empty() or used_artifacts.has(artifact_id):
				continue
			var check := commission_requirement_check(commission, artifact)
			if bool(check.get("ok", false)):
				eligible.append({"id": artifact_id, "displayName": artifact.get("displayName", "Artifact"), "specId": artifact.get("artifactSpecId", "")})
		rows.append({
				"id": String(commission.get("id", "")),
				"type": String(commission.get("type", "")),
				"localizedName": commission.get("localizedName", {"en": String(commission.get("type", "")), "ko": String(commission.get("type", ""))}),
				"localizedDescription": commission.get("localizedDescription", {}),
				"baseReward": int(commission.get("baseReward", 0)),
				"risk": float(commission.get("risk", 0.0)),
				"requirements": (commission.get("requirements", {}) as Dictionary).duplicate(true) if commission.get("requirements", {}) is Dictionary else {},
				"completed": completed_ids.has(String(commission.get("id", ""))),
				"eligibleArtifacts": eligible
		})
	return rows


func complete_commission_from_artifact(commission_id: String, artifact_id: String) -> Dictionary:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return {"ok": false, "code": last_action_error, "net": 0}
	var artifact := find_inventory_instance(artifact_id)
	if artifact.is_empty() or artifact.get("sold", false):
		return {"ok": false, "code": "ARTIFACT_NOT_OWNED", "net": 0}
	if not artifact.get("caseId", "").is_empty() and not artifact.get("caseResolved", false):
		return {"ok": false, "code": "CASE_ARTIFACT_LOCKED", "net": 0}
	var commission: Dictionary = {}
	for candidate: Dictionary in RuntimeRegistry.commissions:
		if candidate.id == commission_id:
			commission = candidate
			break
	if commission.is_empty():
		return {"ok": false, "code": "UNKNOWN_COMMISSION", "net": 0}
	var completed_ids: Array = campaign_state.get("completedCommissionIds", [])
	if completed_ids.has(commission_id):
		return {"ok": false, "code": "COMMISSION_ALREADY_COMPLETED", "net": 0}
	var used_artifacts: Dictionary = campaign_state.get("commissionArtifactUses", {}) if campaign_state.get("commissionArtifactUses", {}) is Dictionary else {}
	if used_artifacts.has(artifact_id):
		return {"ok": false, "code": "ARTIFACT_ALREADY_COMMISSIONED", "net": 0, "previousCommissionId": used_artifacts.get(artifact_id, "")}
	var requirement_check := commission_requirement_check(commission, artifact)
	if not bool(requirement_check.get("ok", false)):
		return {"ok": false, "code": "COMMISSION_REQUIREMENTS_NOT_MET", "net": 0, "missing": requirement_check.get("missing", [])}
	var condition_quality := (float(artifact.cleanliness) + float(artifact.surfaceCondition) + float(artifact.structuralCondition) + float(artifact.mechanicalCondition)) / 400.0
	var evidence_quality := clampf(float(artifact.confidence) * 0.7 + mini(1.0, float(artifact.knownClues.size()) / 4.0) * 0.3, 0.0, 1.0)
	var integrity_quality := clampf(float(artifact.historicalIntegrity) / 100.0, 0.0, 1.0)
	var bounded_quality := clampf(condition_quality * 0.45 + evidence_quality * 0.35 + integrity_quality * 0.20, 0.0, 1.0)
	var base_reward := int(commission.baseReward)
	var service_cost := int(base_reward * (0.22 + float(commission.risk) * 0.35))
	var gross_reward := int(base_reward * (0.35 + bounded_quality * 0.85))
	var net := gross_reward - service_cost
	money += net
	reputation += 1 if bounded_quality >= 0.65 else (-1 if bounded_quality < 0.35 else 0)
	statistics.commissions += 1
	completed_ids.append(commission_id)
	campaign_state.completedCommissionIds = completed_ids
	used_artifacts[artifact_id] = commission_id
	campaign_state.commissionArtifactUses = used_artifacts
	append_money_transaction("commission", commission.type, net, artifact_id, commission_id)
	if commission.type == "museum_conservation":
		campaign_state.museumTrust = int(campaign_state.museumTrust) + (2 if bounded_quality >= 0.65 else 0)
	if commission.type == "authentication_only":
		campaign_state.mastery.DOCUMENTARY = int(campaign_state.mastery.DOCUMENTARY) + 1
	save_game()
	state_changed.emit()
	return {"ok": true, "code": "OK", "commissionId": commission_id, "type": commission.type, "quality": bounded_quality, "cost": service_cost, "gross": gross_reward, "net": net}


func default_case_runtime_state() -> Dictionary:
	return {
		"discoveredEvidenceIds": [],
		"selectedHypothesisId": "",
		"citedEvidenceIds": [],
		"resolved": false,
		"resolutionResult": {}
	}


func ensure_case_runtime_state(case_id: String) -> Dictionary:
	if not campaign_state.has("caseStates") or not campaign_state.caseStates is Dictionary:
		campaign_state.caseStates = {}
	if not campaign_state.caseStates.has(case_id):
		campaign_state.caseStates[case_id] = default_case_runtime_state()
	var state: Dictionary = campaign_state.caseStates[case_id]
	for key: String in default_case_runtime_state().keys():
		if not state.has(key):
			state[key] = default_case_runtime_state()[key]
	return state


func find_case_artifact(case_id: String) -> Dictionary:
	for artifact: Dictionary in inventory:
		if artifact.get("caseId", "") == case_id:
			return artifact
	return {}


func case_definition(case_id: String) -> Dictionary:
	var authored: Dictionary = RuntimeRegistry.get_case_v2(case_id)
	if not authored.is_empty():
		return authored
	var story_case: Dictionary = RuntimeRegistry.get_case(case_id)
	if story_case.is_empty():
		return {}
	var story_artifact: Dictionary = RuntimeRegistry.story_artifacts.get(story_case.get("storyArtifactId", ""), {})
	var artifact := find_case_artifact(case_id)
	var canonical_truth: String = story_artifact.get("groundTruth", artifact.get("authenticityTruth", "GENUINE"))
	var canonical := truth_to_hypothesis(canonical_truth)
	var clues: Array = story_artifact.get("clueLayout", [])
	if clues.is_empty():
		clues = RuntimeRegistry.get_spec(story_case.get("rewardSpecId", "artifact_001")).get("possibleClues", []).slice(0, 4)
	var evidence_risks_value: Variant = story_case.get("evidenceRisks", {})
	var evidence_risks: Dictionary = evidence_risks_value if evidence_risks_value is Dictionary else {}
	var evidence_rows: Array = []
	for clue_value: Variant in clues:
		var clue := String(clue_value)
		var risk_definition_value: Variant = evidence_risks.get(clue, {})
		var risk_definition: Dictionary = risk_definition_value if risk_definition_value is Dictionary else {}
		var risk_level := String(risk_definition.get("level", "NONE")).to_upper()
		if not risk_level in ["NONE", "LOW", "HIGH"]:
			risk_level = "NONE"
		evidence_rows.append({
			"id": "%s:%s" % [case_id, clue.to_lower()],
			"source": {"kind": "ARTIFACT", "ref_id": story_case.get("storyArtifactId", story_case.get("rewardSpecId", "")), "entry_id": clue},
			"text": {"en": "%s inspection recorded for the case file." % clue.capitalize(), "ko": "%s 조사 결과를 사건 기록에 남겼습니다." % clue.capitalize()},
			"unlock": {"requires_all": []},
			"risk": {
				"level": risk_level,
				"warning": risk_definition.get("warning", {"en": "", "ko": ""})
			},
			"independence_key": clue.to_lower(),
			"relations": [{"hypothesis_id": canonical, "stance": "SUPPORT", "strength": 1}],
			"citation": {"allowed": true, "label": {"en": clue.capitalize(), "ko": clue.capitalize()}}
		})
	var hypotheses: Array = []
	for hypothesis: String in HYPOTHESES:
		if hypothesis != "UNKNOWN":
			hypotheses.append({"id": hypothesis, "label_key": "HYP_%s" % hypothesis})
	return {
		"schema_version": 1,
		"case_id": case_id,
		"title": story_case.get("title", case_id),
		"artifact_spec_id": story_case.get("rewardSpecId", "artifact_001"),
		"briefing": {"en": story_case.get("summary", ""), "ko": story_case.get("summary", "")},
		"success": {"en": "The report has been entered into the case record.", "ko": "보고서가 사건 기록에 등록되었습니다."},
		"failure": {"en": "The report remains part of the record, including its uncertainty.", "ko": "불확실성을 포함해 보고서가 사건 기록에 남았습니다."},
		"hypotheses": hypotheses,
		"canonical_hypothesis_id": canonical,
		"evidence": evidence_rows,
		"resolution": {"strong_min_independent_support": 2, "strong_min_net_score": 2, "plausible_min_independent_support": 1, "plausible_min_net_score": 1}
	}


func begin_case(case_id: String) -> Dictionary:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return {}
	var story_case := RuntimeRegistry.get_case(case_id)
	if story_case.is_empty() or campaign_state.completedCases.has(case_id):
		return {}
	if String(stage_run_state.get("status", "")) == "RUNNING" and not case_is_in_current_stage(case_id):
		return {}
	if story_case.act != campaign_state.currentAct:
		return {}
	var active_case: String = campaign_state.get("activeCaseId", "")
	if not active_case.is_empty() and active_case != case_id and not campaign_state.completedCases.has(active_case):
		return {}
	if not campaign_state.has("caseArtifactLedger") or not campaign_state.caseArtifactLedger is Dictionary:
		campaign_state.caseArtifactLedger = {}
	if campaign_state.caseArtifactLedger.has(case_id):
		var ledger: Dictionary = campaign_state.caseArtifactLedger[case_id]
		var issued_artifact := find_inventory_instance(ledger.get("artifactUid", ""))
		if ledger.get("disposition", "") == "INVENTORY" and not issued_artifact.is_empty() and issued_artifact.get("caseId", "") == case_id:
			campaign_state.activeCaseId = case_id
			return issued_artifact
		return {}
	if inventory.size() >= storage_capacity():
		return {}
	var artifact := new_artifact(story_case.rewardSpecId, stable_hash("case|%s|%d" % [case_id, master_seed]), "case_%s" % case_id)
	artifact.caseId = case_id
	artifact.storyArtifactId = story_case.get("storyArtifactId", "")
	if not artifact.storyArtifactId.is_empty():
		var story_artifact: Dictionary = RuntimeRegistry.story_artifacts.get(artifact.storyArtifactId, {})
		artifact.authenticityTruth = story_artifact.get("groundTruth", artifact.authenticityTruth)
		artifact.damageInstances = story_artifact.get("damages", artifact.damageInstances).duplicate()
		artifact.possibleClues = story_artifact.get("clueLayout", artifact.possibleClues).duplicate()
	var authored_definition: Dictionary = RuntimeRegistry.get_case_v2(case_id)
	if not authored_definition.is_empty():
		artifact.authenticityTruth = authored_definition.get("canonical_hypothesis_id", artifact.authenticityTruth)
	inventory.append(artifact)
	campaign_state.activeCaseId = case_id
	campaign_state.caseArtifactLedger[case_id] = {
		"issued": true,
		"artifactUid": artifact.uniqueId,
		"disposition": "INVENTORY",
		"saleTransactionId": "",
		"publicConditionSnapshot": {},
		"publicAppraisalSnapshot": 0
	}
	ensure_case_runtime_state(case_id)
	save_game()
	state_changed.emit()
	campaign_changed.emit()
	return artifact


func evidence_by_id(definition: Dictionary, evidence_id: String) -> Dictionary:
	for evidence: Dictionary in definition.get("evidence", []):
		if evidence.get("id", "") == evidence_id:
			return evidence
	return {}


func evidence_is_unlocked(evidence: Dictionary, discovered_ids: Array) -> bool:
	for requirement: String in evidence.get("unlock", {}).get("requires_all", []):
		if not discovered_ids.has(requirement):
			return false
	return true


func investigation_risk_penalty(risk_level: String, stage_id: int = -1) -> float:
	var base_penalty: float = float({"LOW": 1.0, "HIGH": 3.0}.get(risk_level.to_upper(), 0.0))
	if base_penalty <= 0.0:
		return 0.0
	return base_penalty * stage_difficulty_multiplier(stage_id)


func discover_case_evidence(case_id: String, evidence_id: String) -> Dictionary:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return {"ok": false, "code": last_action_error}
	if campaign_state.completedCases.has(case_id):
		return {"ok": false, "code": "CASE_ALREADY_RESOLVED"}
	var definition := case_definition(case_id)
	var artifact := find_case_artifact(case_id)
	if definition.is_empty() or artifact.is_empty() or campaign_state.get("activeCaseId", "") != case_id:
		return {"ok": false, "code": "CASE_NOT_ACTIVE"}
	var evidence := evidence_by_id(definition, evidence_id)
	if evidence.is_empty():
		return {"ok": false, "code": "EVIDENCE_NOT_IN_CASE"}
	var state := ensure_case_runtime_state(case_id)
	var discovered: Array = state.discoveredEvidenceIds
	if discovered.has(evidence_id):
		return {"ok": true, "code": "ALREADY_DISCOVERED", "evidenceId": evidence_id, "sourceId": evidence.get("independence_key", "")}
	if not evidence_is_unlocked(evidence, discovered):
		return {"ok": false, "code": "EVIDENCE_LOCKED", "requires": evidence.get("unlock", {}).get("requires_all", [])}
	var required_tools: Array = evidence.get("unlock", {}).get("requires_tools", [])
	if not required_tools.is_empty() and not required_tools.has(selected_tool):
		return {"ok": false, "code": "TOOL_REQUIRED", "requiredTools": required_tools.duplicate(), "selectedTool": selected_tool}
	discovered.append(evidence_id)
	var risk_level: String = evidence.get("risk", {}).get("level", "NONE")
	var risk_penalty := investigation_risk_penalty(risk_level)
	if risk_penalty > 0.0:
		artifact.historicalIntegrity = maxf(0.0, float(artifact.historicalIntegrity) - risk_penalty)
	var source: Dictionary = evidence.get("source", {})
	# Authored evidence may bridge one explicitly public, allowlisted clue into the
	# existing listing/auction vocabulary. The normalized definition validator
	# rejects every value except PROVENANCE, and duplicate discovery returns above
	# before this authoritative append can run again.
	var public_clue_id := String(evidence.get("public_clue_id", "")).to_upper()
	if not public_clue_id.is_empty() and not artifact.knownClues.has(public_clue_id):
		artifact.knownClues.append(public_clue_id)
	if source.get("kind", "") == "ARTIFACT":
		var clue_id: String = source.get("entry_id", evidence_id)
		if not artifact.knownClues.has(clue_id):
			artifact.knownClues.append(clue_id)
		artifact.evidence.append({"clueType": evidence_id, "observation": evidence.get("text", evidence.get("text_key", evidence_id)), "supports": [], "contradicts": [], "confidenceWeight": 0.12})
	artifact.confidence = clampf(0.12 + float(discovered.size()) * 0.11, 0.0, 0.92)
	statistics.discoveries += 1
	_record_investigation_telemetry(case_id, evidence_id, risk_penalty)
	_persist_authoritative_tutorial_action("EVIDENCE_DISCOVERED")
	state_changed.emit()
	campaign_changed.emit()
	return {"ok": true, "code": "DISCOVERED", "evidenceId": evidence_id, "sourceId": evidence.get("independence_key", ""), "riskLevel": risk_level, "appliedRiskPenalty": risk_penalty}


func get_case_public_state(case_id: String) -> Dictionary:
	var definition := case_definition(case_id)
	if definition.is_empty():
		return {"ok": false, "code": "UNKNOWN_CASE"}
	var state := ensure_case_runtime_state(case_id)
	var discovered_ids: Array = state.discoveredEvidenceIds
	var public_evidence: Array = []
	var available: Array = []
	var discovered_rows: Array = []
	for evidence: Dictionary in definition.get("evidence", []):
		var evidence_id: String = evidence.get("id", "")
		var discovered: bool = discovered_ids.has(evidence_id)
		var unlocked := evidence_is_unlocked(evidence, discovered_ids)
		var source: Dictionary = evidence.get("source", {})
		var risk: Dictionary = evidence.get("risk", {})
		var presentation_value: Variant = evidence.get("presentation", {})
		var presentation: Dictionary = presentation_value if presentation_value is Dictionary else {}
		var source_display_name: Variant = presentation.get(
			"source_display_name",
			evidence.get("citation", {}).get("label", evidence.get("citation", {}).get("label_key", ""))
		)
		var locked_source_name: Variant = RuntimeRegistry.authored_source_kind_presentation(String(source.get("kind", ""))) \
			if not presentation.is_empty() else source_display_name
		var row := {
			"id": evidence_id,
			"sourceId": evidence.get("independence_key", ""),
			"sourceKind": source.get("kind", ""),
			"sourceRef": source.get("ref_id", ""),
			"entryId": source.get("entry_id", ""),
			"text": evidence.get("text", evidence.get("text_key", evidence_id)) if discovered else (source_display_name if unlocked else locked_source_name),
			"sourceDisplayName": source_display_name if unlocked else locked_source_name,
			"unlockActionLabel": presentation.get("unlock_action_label", {"en": "Investigate", "ko": "조사하기"}),
			"unlockTargetLabel": presentation.get("unlock_target_label", locked_source_name),
			"shortObservation": presentation.get("short_observation", source_display_name) if discovered else {},
			"citationLocator": presentation.get("citation_locator", {}) if discovered else {},
			"npcPortrait": presentation.get("npc_portrait", {}).duplicate(true) if unlocked else {},
			"discovered": discovered,
			"unlocked": unlocked,
			"requires": evidence.get("unlock", {}).get("requires_all", []).duplicate(),
			"requiredTools": evidence.get("unlock", {}).get("requires_tools", []).duplicate(),
			"riskLevel": risk.get("level", "NONE"),
			"riskWarning": risk.get("warning", risk.get("warning_key", "")),
			"reliability": evidence.get("reliability", "UNSPECIFIED"),
			"relations": evidence.get("relations", []).duplicate(true) if discovered else [],
			"citationAllowed": bool(evidence.get("citation", {}).get("allowed", true)),
			"cited": state.citedEvidenceIds.has(evidence_id)
		}
		public_evidence.append(row)
		if discovered:
			discovered_rows.append(row)
		elif unlocked:
			available.append(row)
	var story_case: Dictionary = RuntimeRegistry.get_case(case_id)
	var artifact_display_name: Variant = definition.get("presentation", {}).get(
		"artifact_display_name",
		definition.get("artifact_display_name", {})
	)
	return {
		"ok": true,
		"code": "OK",
		"caseId": case_id,
		"title": definition.get("title", story_case.get("title", case_id)),
		"artifactDisplayName": artifact_display_name,
		"briefing": definition.get("briefing", definition.get("briefing_dialogue_id", story_case.get("summary", ""))),
		"centralQuestion": definition.get("central_question", ""),
		"fictionNotice": definition.get("fiction_notice", ""),
		"reportPrompt": definition.get("resolution", {}).get("report_prompt", ""),
		"success": definition.get("success", definition.get("success_dialogue_id", "")),
		"failure": definition.get("failure", definition.get("failure_dialogue_id", "")),
		"hypotheses": definition.get("hypotheses", []).duplicate(true),
		"evidence": public_evidence,
		"availableEvidence": available,
		"discoveredEvidence": discovered_rows,
		"selectedHypothesisId": state.selectedHypothesisId,
		"citedEvidenceIds": state.citedEvidenceIds.duplicate(),
		"resolved": bool(state.resolved),
		"resolutionResult": state.resolutionResult.duplicate(true),
		"artifactId": campaign_state.get("caseArtifactLedger", {}).get(case_id, {}).get("artifactUid", "")
	}


func set_case_hypothesis(case_id: String, hypothesis_id: String) -> bool:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return false
	var definition := case_definition(case_id)
	var valid := false
	for hypothesis: Dictionary in definition.get("hypotheses", []):
		if hypothesis.get("id", "") == hypothesis_id:
			valid = true
	if not valid or campaign_state.completedCases.has(case_id):
		return false
	ensure_case_runtime_state(case_id).selectedHypothesisId = hypothesis_id
	save_game()
	campaign_changed.emit()
	return true


func toggle_case_citation(case_id: String, evidence_id: String) -> bool:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return false
	var state := ensure_case_runtime_state(case_id)
	if not state.discoveredEvidenceIds.has(evidence_id) or campaign_state.completedCases.has(case_id):
		return false
	var evidence := evidence_by_id(case_definition(case_id), evidence_id)
	if evidence.is_empty() or not bool(evidence.get("citation", {}).get("allowed", true)):
		return false
	var citation_added: bool = not state.citedEvidenceIds.has(evidence_id)
	if not citation_added:
		state.citedEvidenceIds.erase(evidence_id)
	else:
		state.citedEvidenceIds.append(evidence_id)
	if citation_added:
		_persist_authoritative_tutorial_action("EVIDENCE_CITED")
	else:
		save_game()
	campaign_changed.emit()
	return true


func evaluate_case_submission(case_id: String, hypothesis_id: String, cited_evidence_ids: Array) -> Dictionary:
	var definition := case_definition(case_id)
	if definition.is_empty():
		return {"ok": false, "code": "UNKNOWN_CASE"}
	var hypothesis_valid := false
	for hypothesis: Dictionary in definition.get("hypotheses", []):
		if hypothesis.get("id", "") == hypothesis_id:
			hypothesis_valid = true
	if not hypothesis_valid:
		return {"ok": false, "code": "INVALID_HYPOTHESIS"}
	# UI prevents an empty report, but the domain boundary must fail closed too.
	# Keep this check after hypothesis validation and leave resolve_case_v2's
	# pending-auction lock as the higher-priority authority gate.
	if cited_evidence_ids.is_empty():
		return {"ok": false, "code": "CITATION_REQUIRED"}
	var state := ensure_case_runtime_state(case_id)
	var unique_citations: Array = []
	for citation_value: Variant in cited_evidence_ids:
		var evidence_id := String(citation_value)
		if unique_citations.has(evidence_id):
			continue
		var evidence := evidence_by_id(definition, evidence_id)
		if evidence.is_empty():
			return {"ok": false, "code": "CROSS_CASE_EVIDENCE", "evidenceId": evidence_id}
		if not state.discoveredEvidenceIds.has(evidence_id):
			return {"ok": false, "code": "EVIDENCE_NOT_DISCOVERED", "evidenceId": evidence_id}
		if not bool(evidence.get("citation", {}).get("allowed", true)):
			return {"ok": false, "code": "EVIDENCE_NOT_CITABLE", "evidenceId": evidence_id}
		unique_citations.append(evidence_id)
	var support_score := 0
	var refute_score := 0
	var independent_support := {}
	for evidence_id: String in unique_citations:
		var evidence := evidence_by_id(definition, evidence_id)
		for relation: Dictionary in evidence.get("relations", []):
			if relation.get("hypothesis_id", "") != hypothesis_id:
				continue
			var strength := int(relation.get("strength", 0))
			if relation.get("stance", "") == "SUPPORT":
				support_score += strength
				independent_support[evidence.get("independence_key", evidence_id)] = true
			elif relation.get("stance", "") == "REFUTE":
				refute_score += strength
	var net_score := support_score - refute_score
	var rules: Dictionary = definition.get("resolution", {})
	var required_sources_met := true
	for required_source: String in rules.get("required_source_refs", []):
		if not unique_citations.has(required_source):
			required_sources_met = false
	var strong := independent_support.size() >= int(rules.get("strong_min_independent_support", 2)) and net_score >= int(rules.get("strong_min_net_score", 2)) and unique_citations.size() >= int(rules.get("strong_min_citations", 2)) and required_sources_met
	var plausible := independent_support.size() >= int(rules.get("plausible_min_independent_support", 1)) and net_score >= int(rules.get("plausible_min_net_score", 1)) and unique_citations.size() >= int(rules.get("plausible_min_citations", 1))
	var accurate: bool = hypothesis_id == String(definition.get("canonical_hypothesis_id", ""))
	var outcome_rules_value: Variant = rules.get("outcome_rules", [])
	var uses_authored_outcome_rules: bool = outcome_rules_value is Array and not (outcome_rules_value as Array).is_empty()
	var outcome: String
	var substantiation: String
	var substantiated: bool
	if uses_authored_outcome_rules:
		# RuntimeRegistry validates that the final rule is unconditional. The
		# defensive default still fails toward mentor review if a live registry is
		# corrupted after startup.
		outcome = "reviewed_with_mentor"
		for rule_value: Variant in outcome_rules_value as Array:
			if not rule_value is Dictionary:
				continue
			var rule: Dictionary = rule_value
			var correctness := String(rule.get("correctness", "ANY"))
			if correctness == "CORRECT" and not accurate:
				continue
			if correctness == "INCORRECT" and accurate:
				continue
			if bool(rule.get("requires_all_required_sources", false)) and not required_sources_met:
				continue
			if independent_support.size() < int(rule.get("minimum_independent_groups", 0)):
				continue
			if unique_citations.size() < int(rule.get("minimum_citations", 0)):
				continue
			var minimum_net_support := int(rule.get("minimum_net_support", 0))
			# Zero means that net support is not a condition. This is essential for
			# an evidence-backed incorrect report whose cited ledger refutes it.
			if minimum_net_support > 0 and net_score < minimum_net_support:
				continue
			outcome = String(rule.get("outcome_id", "reviewed_with_mentor"))
			break
		substantiation = {
			"masterful": "STRONG",
			"credible": "PLAUSIBLE"
		}.get(outcome, "INCONCLUSIVE")
		substantiated = outcome == "masterful"
	else:
		# Ruleless definitions retain the exact pre-authored matcher.
		substantiation = "STRONG" if strong else ("PLAUSIBLE" if plausible else "INCONCLUSIVE")
		outcome = "masterful" if accurate and strong else ("credible" if accurate and plausible else ("reviewed_with_mentor" if accurate else "mistaken"))
		substantiated = strong
	return {
		"ok": true,
		"code": "OK",
		"outcome": outcome,
		"substantiated": substantiated,
		"substantiation": substantiation,
		"independentSourceCount": independent_support.size(),
		"supportScore": support_score,
		"refuteScore": refute_score,
		"netScore": net_score,
		"requiredSourcesMet": required_sources_met,
		"conclusionAccurate": accurate,
		"hypothesisId": hypothesis_id,
		"citedEvidenceIds": unique_citations
	}


func resolve_case_v2(case_id: String, hypothesis_id: String, cited_evidence_ids: Array) -> Dictionary:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return {"ok": false, "code": last_action_error}
	if campaign_state.completedCases.has(case_id):
		return {"ok": false, "code": "CASE_ALREADY_RESOLVED"}
	var artifact := find_case_artifact(case_id)
	if artifact.is_empty() or campaign_state.get("activeCaseId", "") != case_id:
		return {"ok": false, "code": "CASE_NOT_ACTIVE"}
	var result := evaluate_case_submission(case_id, hypothesis_id, cited_evidence_ids)
	if not bool(result.get("ok", false)):
		return result
	artifact.caseResolved = true
	artifact.playerHypothesis = hypothesis_id
	var state := ensure_case_runtime_state(case_id)
	state.selectedHypothesisId = hypothesis_id
	state.citedEvidenceIds = result.citedEvidenceIds.duplicate()
	state.resolved = true
	state.resolutionResult = result.duplicate(true)
	# The submitted case report is the authoritative authentication attempt for
	# case content.  Without this bridge, authored-v2 cases can never contribute
	# to campaign qualification even though their conclusion was resolved.
	statistics.authentication_attempts = int(statistics.get("authentication_attempts", 0)) + 1
	if bool(result.get("conclusionAccurate", false)):
		statistics.authentication_correct = int(statistics.get("authentication_correct", 0)) + 1
		if hypothesis_id == "FORGERY":
			statistics.forgeries_detected = int(statistics.get("forgeries_detected", 0)) + 1
	complete_case_rewards(case_id, result.outcome, "CASE_REPORT_RESOLVED")
	return result


func resolve_case(case_id: String, _legacy_outcome: String = "credible") -> Dictionary:
	return {"ok": false, "code": "DEPRECATED_OUTCOME_ARGUMENT", "caseId": case_id}


func complete_case_rewards(case_id: String, outcome: String, tutorial_event: String = "") -> void:
	if campaign_state.completedCases.has(case_id):
		return
	var story_case := RuntimeRegistry.get_case(case_id)
	campaign_state.completedCases[case_id] = true
	campaign_state.caseOutcomes[case_id] = outcome
	campaign_state.activeCaseId = ""
	var rewards: Dictionary = story_case.get("rewards", {})
	var reward_scale: float = {"masterful": 1.20, "credible": 1.0, "reviewed_with_mentor": 0.65, "mistaken": 0.35}.get(outcome, 0.5)
	var money_reward := roundi(float(rewards.get("money", 0)) * reward_scale)
	money += money_reward
	append_money_transaction("case_reward", case_id, money_reward, String(story_case.get("rewardSpecId", "")), outcome)
	reputation += roundi(float(rewards.get("reputation", 0)) * reward_scale) if outcome != "mistaken" else -1
	campaign_state.museumTrust = int(campaign_state.museumTrust) + roundi(float(rewards.get("museumTrust", 0)) * reward_scale)
	campaign_state.historicalIntegrity = clampi(int(campaign_state.historicalIntegrity) + roundi(float(rewards.get("historicalIntegrity", 0)) * reward_scale), 0, 100)
	campaign_state.collectorNetwork = int(campaign_state.collectorNetwork) + 1
	var domain := mastery_domain_for_spec(story_case.rewardSpecId)
	var mastery_multiplier := 1.0 + upgrade_effect_total("mastery_gain")
	campaign_state.mastery[domain] = int(campaign_state.mastery.get(domain, 0)) + roundi(float(rewards.get("mastery", 0)) * reward_scale * mastery_multiplier)
	var npc_id: String = story_case.get("npcId", "")
	if campaign_state.relationships.has(npc_id):
		campaign_state.relationships[npc_id].relationship += 2
		campaign_state.relationships[npc_id].trust += 2 if outcome in ["masterful", "credible"] else -1
	# Advance while the stage is still RUNNING. The final scoped report can clear
	# the stage below; waiting until after that transition would make the REPORT
	# event appear inactive and strand the run mirror one step behind.
	var tutorial_advanced := _advance_tutorial_run_event(tutorial_event) if not tutorial_event.is_empty() else false
	refresh_campaign_progress()
	var stage_transition := maybe_case_complete_and_unlock()
	# complete_stage already commits the run when it succeeds. All other paths
	# need exactly one save containing both the report and its tutorial mirror.
	var run_saved := bool(stage_transition.get("ok", false)) and String(stage_transition.get("code", "")) == "OK" and String(stage_run_state.get("status", "")) == "CLEARED"
	if not run_saved:
		run_saved = save_game()
	if tutorial_advanced and run_saved:
		_reconcile_profile_to_tutorial_run(true)
	state_changed.emit()
	campaign_changed.emit()


func mastery_domain_for_spec(spec_id: String) -> String:
	var category: String = RuntimeRegistry.get_spec(spec_id).get("category", "mechanical_instruments")
	return {
		"mechanical_instruments": "MECHANICAL", "optical_devices": "OPTICAL",
		"vintage_audio": "ELECTRICAL", "decorative_objects": "DECORATIVE",
		"ceramics": "DECORATIVE", "scientific_instruments": "SCIENTIFIC",
		"office_machines": "MECHANICAL", "telephony": "ELECTRICAL"
	}.get(category, "DOCUMENTARY")


func act_case_ids(act_id: String) -> Array:
	var ids: Array = []
	for story_case: Dictionary in RuntimeRegistry.campaign.get("cases", []):
		if story_case.act == act_id:
			ids.append(story_case.id)
	return ids


func refresh_campaign_progress() -> void:
	for act_id: String in ["PROLOGUE", "ACT_1", "ACT_2", "ACT_3", "ACT_4", "ACT_5"]:
		var required := act_case_ids(act_id)
		var complete: bool = not required.is_empty()
		for case_id: String in required:
			if not campaign_state.completedCases.has(case_id):
				complete = false
		if complete:
			campaign_state.completedActs[act_id] = true
	if campaign_state.completedActs.has("ACT_1"):
		campaign_state.workshopGrade = maxi(int(campaign_state.workshopGrade), 2)
	if campaign_state.completedActs.has("ACT_2"):
		campaign_state.workshopGrade = maxi(int(campaign_state.workshopGrade), 3)
	if campaign_state.completedActs.has("ACT_4"):
		campaign_state.workshopGrade = maxi(int(campaign_state.workshopGrade), 4)
	if campaign_state.completedActs.has("ACT_5"):
		campaign_state.workshopGrade = maxi(int(campaign_state.workshopGrade), 5)
	var latest := "PROLOGUE"
	for act: Dictionary in RuntimeRegistry.campaign.get("acts", []):
		if evaluate_condition(act.unlock):
			latest = act.id
		else:
			break
	campaign_state.currentAct = latest
	if qualifies_for_grand_reserve():
		campaign_state.grandReserve.invited = true
	if String(stage_run_state.get("status", "")) == "RUNNING":
		var pending_stage_case := current_stage_first_pending_case()
		if not pending_stage_case.is_empty():
			campaign_state.currentAct = RuntimeRegistry.get_case(pending_stage_case).get("act", campaign_state.currentAct)
		elif bool(RuntimeRegistry.get_stage_definition(current_stage).get("includes_grand_reserve", false)):
			campaign_state.currentAct = "GRAND_RESERVE"
			campaign_state.grandReserve.invited = true
	if bool(campaign_state.get("postGame", false)):
		campaign_state.currentAct = "POSTGAME"
	elif not String(campaign_state.get("currentEnding", "")).is_empty():
		campaign_state.currentAct = "EPILOGUE"


func condition_metric(metric: String, fixture: Dictionary = {}) -> Variant:
	if fixture.has(metric):
		return fixture[metric]
	if metric.begins_with("case."):
		return campaign_state.completedCases.has(metric.trim_prefix("case."))
	if metric.begins_with("act_completed."):
		return campaign_state.completedActs.has(metric.trim_prefix("act_completed."))
	if metric.begins_with("relationship."):
		return campaign_state.relationships.get(metric.trim_prefix("relationship."), {}).get("trust", 0)
	match metric:
		"eligible_lots": return eligible_final_lots().size()
		"workshopGrade": return int(campaign_state.workshopGrade)
		"reputation": return reputation
		"authenticationAccuracy": return authentication_accuracy()
		"museumTrust": return int(campaign_state.museumTrust)
		"masteryTotal": return mastery_total()
		"historicalIntegrity": return int(campaign_state.historicalIntegrity)
		"ethics": return int(campaign_state.ethics)
		"collectorTrust": return total_collector_trust()
		"grand_reserve.completed": return bool(campaign_state.grandReserve.completed)
		"epilogue_seen": return bool(campaign_state.epilogueSeen)
	return 0


func evaluate_condition(condition: Dictionary, fixture: Dictionary = {}) -> bool:
	var op: String = condition.get("op", "==")
	if op == "always":
		return true
	if op == "all":
		for child: Dictionary in condition.get("conditions", []):
			if not evaluate_condition(child, fixture):
				return false
		return true
	if op == "any":
		for child: Dictionary in condition.get("conditions", []):
			if evaluate_condition(child, fixture):
				return true
		return false
	if op == "not":
		return not evaluate_condition(condition.get("condition", {}), fixture)
	var actual: Variant = condition_metric(condition.get("metric", ""), fixture)
	var expected: Variant = condition.get("value")
	match op:
		"==": return actual == expected
		"!=": return actual != expected
		">=": return float(actual) >= float(expected)
		"<=": return float(actual) <= float(expected)
		">": return float(actual) > float(expected)
		"<": return float(actual) < float(expected)
	return false


func mastery_total() -> int:
	var total := 0
	for value: Variant in campaign_state.mastery.values():
		total += int(value)
	return total


func total_collector_trust() -> int:
	var total := 0
	for relation: Dictionary in campaign_state.relationships.values():
		total += int(relation.get("trust", 0))
	return total


func eligible_final_lots() -> Array:
	var eligible: Array = []
	for artifact: Dictionary in inventory:
		var case_id: String = artifact.get("caseId", "")
		var case_evidence_count: int = int(ensure_case_runtime_state(case_id).discoveredEvidenceIds.size()) if not case_id.is_empty() else 0
		var case_unlocked: bool = case_id.is_empty() or bool(artifact.get("caseResolved", false))
		if case_unlocked and artifact.playerHypothesis != "UNKNOWN" and maxi(artifact.knownClues.size(), case_evidence_count) >= 2 and float(artifact.historicalIntegrity) >= 45.0 and not artifact.get("sold", false):
			eligible.append(artifact)
	return eligible


func qualifies_for_grand_reserve() -> bool:
	var qualification: Dictionary = RuntimeRegistry.campaign.get("qualification", {})
	return int(campaign_state.workshopGrade) >= int(qualification.get("workshopGrade", 5)) \
		and reputation >= int(qualification.get("reputation", 45)) \
		and authentication_accuracy() >= float(qualification.get("authenticationAccuracy", 0.6)) \
		and int(campaign_state.museumTrust) >= int(qualification.get("museumTrust", 24)) \
		and mastery_total() >= int(qualification.get("masteryTotal", 42)) \
		and eligible_final_lots().size() >= int(qualification.get("eligibleLots", 3))


func select_final_lot(instance_id: String) -> bool:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return false
	var selected_ids: Array = campaign_state.grandReserve.selectedLotIds
	if selected_ids.has(instance_id):
		selected_ids.erase(instance_id)
		save_game()
		campaign_changed.emit()
		return true
	if selected_ids.size() >= 3:
		return false
	for artifact: Dictionary in eligible_final_lots():
		if artifact.uniqueId == instance_id:
			selected_ids.append(instance_id)
			save_game()
			campaign_changed.emit()
			return true
	return false


func _grand_reserve_artifact_snapshot(artifact: Dictionary) -> Dictionary:
	return {
		"instanceId": String(artifact.get("uniqueId", "")),
		"uniqueId": String(artifact.get("uniqueId", "")),
		"specId": String(artifact.get("artifactSpecId", "")),
		"artifactSpecId": String(artifact.get("artifactSpecId", "")),
		"displayName": String(artifact.get("displayName", "Final lot")),
		"visualSignature": artifact.get("visualSignature", {}).duplicate(true) if artifact.get("visualSignature", {}) is Dictionary else {},
		"category": String(artifact.get("category", "")),
		"damageInstances": artifact.get("damageInstances", []).duplicate(true) if artifact.get("damageInstances", []) is Array else [],
		"partStates": artifact.get("partStates", {}).duplicate(true) if artifact.get("partStates", {}) is Dictionary else {}
	}


func _ensure_grand_reserve_listing(artifact: Dictionary) -> void:
	var listing_value: Variant = artifact.get("listing", {})
	var listing: Dictionary = listing_value if listing_value is Dictionary else {}
	var public_appraisal := maxi(1, _cached_public_appraisal(artifact))
	if public_appraisal <= 1:
		public_appraisal = maxi(1, int(appraise(artifact)))
	if int(listing.get("starting", 0)) <= 0:
		artifact["listing"] = {
			"starting": maxi(1, int(float(public_appraisal) * 0.58)),
			"reserve": maxi(1, int(float(public_appraisal) * 0.70)),
			"confidence": clampf(float(artifact.get("confidence", 0.5)), 0.0, 1.0),
			"disclosure": "CERTAIN",
			"publicAppraisal": public_appraisal
		}
	elif int(listing.get("publicAppraisal", 0)) <= 0:
		listing["publicAppraisal"] = public_appraisal
		artifact["listing"] = listing


func _grand_reserve_receipt_for_transaction(transaction_id: String) -> Dictionary:
	for receipt_value: Variant in grand_reserve_session.get("receipts", []):
		if not receipt_value is Dictionary:
			continue
		var receipt_entry: Dictionary = receipt_value
		var auction_value: Variant = receipt_entry.get("auction", receipt_entry.get("result", receipt_entry))
		if not auction_value is Dictionary:
			continue
		var auction_receipt: Dictionary = auction_value
		if String(auction_receipt.get("transactionId", "")) != transaction_id:
			continue
		var response := auction_receipt.duplicate(true)
		response["ok"] = true
		response["code"] = "OK"
		response["status"] = "COMMITTED"
		response["idempotent"] = true
		return response
	return {}


func begin_grand_reserve_session(save_path: String = "") -> Dictionary:
	last_action_error = ""
	var phase := String(grand_reserve_session.get("phase", "IDLE"))
	if phase == "FINALIZED" or bool(campaign_state.grandReserve.get("completed", false)):
		return {"ok": false, "code": "ALREADY_COMPLETED"}
	if grand_reserve_active():
		return grand_reserve_public_state()
	if pending_auction_active():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return {"ok": false, "code": last_action_error}
	var memory_snapshot := pending_auction_commit_memory_snapshot()
	var preflight := grand_reserve_preflight()
	if not bool(preflight.get("ok", false)):
		restore_pending_auction_commit_memory(memory_snapshot)
		return {"ok": false, "code": preflight.get("code", "PREFLIGHT_FAILED")}
	var selected_artifacts: Array = preflight.get("artifacts", [])
	for artifact_value: Variant in selected_artifacts:
		if artifact_value is Dictionary:
			_ensure_grand_reserve_listing(artifact_value)
	var first_artifact: Dictionary = selected_artifacts[0]
	var built := _build_pending_auction_state(first_artifact, true)
	if not bool(built.get("ok", false)):
		restore_pending_auction_commit_memory(memory_snapshot)
		return {"ok": false, "code": built.get("code", "AUCTION_CREATE_FAILED")}
	var lot_uids: Array = campaign_state.grandReserve.selectedLotIds.duplicate(true)
	var reserve_run_id := "grand_reserve_%d_%d_%d" % [current_stage, day, absi(stable_hash(JSON.stringify(lot_uids)))]
	pending_auction = built.get("state", {}).duplicate(true)
	_record_listing_telemetry(pending_auction)
	grand_reserve_session = {
		"schemaVersion": 1,
		"reserveRunId": reserve_run_id,
		"phase": "AUCTION_PENDING",
		"lotUids": lot_uids,
		"receipts": [],
		"currentLotIndex": 0,
		"activeTransactionId": String(pending_auction.get("transactionId", "")),
		"activeArtifact": _grand_reserve_artifact_snapshot(first_artifact),
		"finalizationReceiptId": ""
	}
	var begin_saved: bool = save_game() if save_path.is_empty() else save_game(save_path)
	if not begin_saved:
		restore_pending_auction_commit_memory(memory_snapshot)
		last_action_error = "PENDING_AUCTION_SAVE_FAILED"
		return {"ok": false, "code": last_action_error}
	state_changed.emit()
	campaign_changed.emit()
	var response := grand_reserve_public_state()
	response["pending"] = pending_auction_public_state()
	return response


func advance_grand_reserve_lot(save_path: String = "") -> Dictionary:
	if String(grand_reserve_session.get("phase", "IDLE")) != "BETWEEN_LOTS":
		return {"ok": false, "code": "GRAND_RESERVE_NOT_BETWEEN_LOTS"}
	var current_index := int(grand_reserve_session.get("currentLotIndex", -1))
	var receipts: Array = grand_reserve_session.get("receipts", [])
	if current_index < 0 or current_index >= 2 or receipts.size() != current_index + 1:
		return {"ok": false, "code": "GRAND_RESERVE_SEQUENCE_INVALID"}
	var next_index := current_index + 1
	var lot_uids: Array = grand_reserve_session.get("lotUids", [])
	var artifact := find_inventory_instance(String(lot_uids[next_index]))
	if artifact.is_empty() or artifact.get("sold", false):
		return {"ok": false, "code": "LOT_NOT_OWNED"}
	var memory_snapshot := pending_auction_commit_memory_snapshot()
	_ensure_grand_reserve_listing(artifact)
	var built := _build_pending_auction_state(artifact, true)
	if not bool(built.get("ok", false)):
		restore_pending_auction_commit_memory(memory_snapshot)
		return {"ok": false, "code": built.get("code", "AUCTION_CREATE_FAILED")}
	pending_auction = built.get("state", {}).duplicate(true)
	_record_listing_telemetry(pending_auction)
	grand_reserve_session["phase"] = "AUCTION_PENDING"
	grand_reserve_session["currentLotIndex"] = next_index
	grand_reserve_session["activeTransactionId"] = String(pending_auction.get("transactionId", ""))
	grand_reserve_session["activeArtifact"] = _grand_reserve_artifact_snapshot(artifact)
	var advanced_saved: bool = save_game() if save_path.is_empty() else save_game(save_path)
	if not advanced_saved:
		restore_pending_auction_commit_memory(memory_snapshot)
		return {"ok": false, "code": "PENDING_AUCTION_SAVE_FAILED"}
	state_changed.emit()
	campaign_changed.emit()
	var response := grand_reserve_public_state()
	response["pending"] = pending_auction_public_state()
	return response


func commit_grand_reserve_lot(transaction_id: String, save_path: String = "") -> Dictionary:
	var prior_receipt := _grand_reserve_receipt_for_transaction(transaction_id)
	if not prior_receipt.is_empty():
		return prior_receipt
	if String(grand_reserve_session.get("phase", "IDLE")) != "AUCTION_PENDING":
		return {"ok": false, "code": "GRAND_RESERVE_LOT_NOT_PENDING"}
	var current_index := int(grand_reserve_session.get("currentLotIndex", -1))
	var lot_uids: Array = grand_reserve_session.get("lotUids", [])
	if current_index < 0 or current_index >= lot_uids.size() \
		or transaction_id != String(grand_reserve_session.get("activeTransactionId", "")) \
		or transaction_id != String(pending_auction.get("transactionId", "")) \
		or String(pending_auction.get("status", "NONE")) != "PENDING" \
		or not bool(pending_auction.get("grandReserve", false)) \
		or String(pending_auction.get("artifactId", "")) != String(lot_uids[current_index]):
		return {"ok": false, "code": "PENDING_AUCTION_ID_MISMATCH"}
	var artifact := find_inventory_instance(String(lot_uids[current_index]))
	if artifact.is_empty() or artifact.get("sold", false):
		return {"ok": false, "code": "AUCTION_LOT_UNAVAILABLE"}
	var artifact_snapshot := _grand_reserve_artifact_snapshot(artifact)
	var memory_snapshot := pending_auction_commit_memory_snapshot()
	var commit_response := _apply_pending_auction_commit(transaction_id)
	var mutation_applied := bool(commit_response.get("_mutationApplied", false))
	commit_response.erase("_mutationApplied")
	if not bool(commit_response.get("ok", false)):
		return commit_response
	if not mutation_applied:
		return commit_response
	var auction_receipt: Dictionary = pending_auction.get("receipt", {}).duplicate(true)
	var receipt_entry := {"artifact": artifact_snapshot, "auction": auction_receipt}
	var receipts: Array = grand_reserve_session.get("receipts", []).duplicate(true)
	receipts.append(receipt_entry)
	grand_reserve_session["receipts"] = receipts
	grand_reserve_session["activeArtifact"] = artifact_snapshot
	var finalized := receipts.size() == 3
	if not finalized:
		grand_reserve_session["phase"] = "BETWEEN_LOTS"
	else:
		campaign_state.grandReserve.results = receipts.duplicate(true)
		campaign_state.grandReserve.score = calculate_grand_reserve_score(receipts)
		campaign_state.grandReserve.completed = true
		campaign_state.endingMetrics = campaign_state.grandReserve.score.duplicate(true)
		var ending_id := evaluate_ending(campaign_state.endingMetrics)
		campaign_state.currentEnding = ending_id
		if not campaign_state.endingUnlocked.has(ending_id):
			campaign_state.endingUnlocked.append(ending_id)
		grand_reserve_session["phase"] = "FINALIZED"
		grand_reserve_session["activeTransactionId"] = ""
		grand_reserve_session["finalizationReceiptId"] = "gr_final_%d" % absi(stable_hash("%s|%s" % [grand_reserve_session.get("reserveRunId", ""), transaction_id]))
		# Stage runs own the explicit Stage Clear hand-off. Legacy free-campaign
		# saves can legitimately reach the Reserve without a RUNNING stage; they
		# still receive the ending, but must not fabricate a stage completion.
		if String(stage_run_state.get("status", "")) == "RUNNING":
			var completion := complete_stage(current_stage, stage_score_from_run(current_stage), false, true)
			if not bool(completion.get("ok", false)):
				restore_pending_auction_commit_memory(memory_snapshot)
				return {"ok": false, "code": completion.get("code", "STAGE_COMPLETION_FAILED")}
		refresh_campaign_progress()
	var commit_saved: bool = save_game() if save_path.is_empty() else save_game(save_path)
	if not commit_saved:
		restore_pending_auction_commit_memory(memory_snapshot)
		last_action_error = "PENDING_AUCTION_SAVE_FAILED"
		return {"ok": false, "code": last_action_error, "transactionId": transaction_id}
	_reconcile_profile_to_tutorial_run(true)
	if finalized:
		# A custom run path is used by crash/e2e fixtures. Never let such a slot
		# overwrite the player's default profile; production's default run path
		# still mirrors the newly cleared stage normally.
		if save_path.is_empty():
			save_profile()
		profile_changed.emit()
		stage_changed.emit()
	state_changed.emit()
	campaign_changed.emit()
	var response := auction_receipt.duplicate(true)
	response["ok"] = true
	response["code"] = "OK"
	response["status"] = "COMMITTED"
	response["idempotent"] = false
	response["grandReservePhase"] = String(grand_reserve_session.get("phase", ""))
	return response


func run_grand_reserve() -> Dictionary:
	if String(grand_reserve_session.get("phase", "IDLE")) == "FINALIZED":
		return {
			"ok": true,
			"code": "OK",
			"results": campaign_state.grandReserve.results.duplicate(true),
			"score": campaign_state.grandReserve.score.duplicate(true),
			"ending": String(campaign_state.currentEnding),
			"idempotent": true
		}
	if String(grand_reserve_session.get("phase", "IDLE")) == "IDLE":
		var begun := begin_grand_reserve_session()
		if not bool(begun.get("ok", false)):
			return begun
	for _step in range(8):
		var phase := String(grand_reserve_session.get("phase", "IDLE"))
		if phase == "AUCTION_PENDING":
			var final_cue_index := maxi(0, pending_auction.get("cueQueue", []).size() - 1)
			if int(pending_auction.get("cueIndex", 0)) != final_cue_index:
				var cue_advanced := set_pending_auction_cue_index(String(grand_reserve_session.get("activeTransactionId", "")), final_cue_index)
				if not bool(cue_advanced.get("ok", false)):
					return cue_advanced
			var committed := commit_grand_reserve_lot(String(grand_reserve_session.get("activeTransactionId", "")))
			if not bool(committed.get("ok", false)):
				return committed
		elif phase == "BETWEEN_LOTS":
			var advanced := advance_grand_reserve_lot()
			if not bool(advanced.get("ok", false)):
				return advanced
		elif phase == "FINALIZED":
			return {
				"ok": true,
				"code": "OK",
				"results": campaign_state.grandReserve.results.duplicate(true),
				"score": campaign_state.grandReserve.score.duplicate(true),
				"ending": String(campaign_state.currentEnding)
			}
		else:
			return {"ok": false, "code": "GRAND_RESERVE_SEQUENCE_INVALID"}
	return {"ok": false, "code": "GRAND_RESERVE_SEQUENCE_LIMIT"}


func grand_reserve_preflight() -> Dictionary:
	if not bool(campaign_state.grandReserve.invited):
		return {"ok": false, "code": "NOT_INVITED"}
	if bool(campaign_state.grandReserve.completed):
		return {"ok": false, "code": "ALREADY_COMPLETED"}
	var selected_ids: Array = campaign_state.grandReserve.selectedLotIds
	if selected_ids.size() != 3:
		return {"ok": false, "code": "REQUIRES_THREE_LOTS"}
	var unique := {}
	var eligible_ids := {}
	for eligible: Dictionary in eligible_final_lots():
		eligible_ids[eligible.uniqueId] = true
	var artifacts: Array = []
	for instance_id_value: Variant in selected_ids:
		var instance_id := String(instance_id_value)
		if unique.has(instance_id):
			return {"ok": false, "code": "DUPLICATE_LOT"}
		unique[instance_id] = true
		var artifact := find_inventory_instance(instance_id)
		if artifact.is_empty() or artifact.get("sold", false):
			return {"ok": false, "code": "LOT_NOT_OWNED", "instanceId": instance_id}
		if not artifact.get("caseId", "").is_empty() and not artifact.get("caseResolved", false):
			return {"ok": false, "code": "CASE_LOT_LOCKED", "instanceId": instance_id}
		if not eligible_ids.has(instance_id):
			return {"ok": false, "code": "LOT_NOT_ELIGIBLE", "instanceId": instance_id}
		artifacts.append(artifact)
	return {"ok": true, "code": "OK", "artifacts": artifacts}


func find_inventory_instance(instance_id: String) -> Dictionary:
	for artifact: Dictionary in inventory:
		if artifact.uniqueId == instance_id:
			return artifact
	return {}


func calculate_grand_reserve_score(results: Array) -> Dictionary:
	var revenue := 0
	var sold_count := 0
	for result: Dictionary in results:
		revenue += int(result.auction.get("hammer", 0))
		if result.auction.get("reserve_met", false):
			sold_count += 1
	var auth_score := authentication_accuracy() * 100.0
	var restoration_score := clampf(float(statistics.restorations) * 3.0 + float(mastery_total()), 0.0, 100.0)
	var integrity_score := float(campaign_state.historicalIntegrity)
	var financial_score := clampf(float(revenue) / 45.0 + sold_count * 8.0, 0.0, 100.0)
	var museum_score := clampf(float(campaign_state.museumTrust) * 2.5, 0.0, 100.0)
	var collector_score := clampf(float(reputation) + float(total_collector_trust()), 0.0, 100.0)
	var collection_score := clampf(float(results.size()) * 24.0 + float(mastery_total()) * 0.5, 0.0, 100.0)
	var balanced := (auth_score + restoration_score + integrity_score + financial_score + museum_score + collector_score + collection_score) / 7.0
	return {
		"authenticationAccuracy": auth_score / 100.0,
		"authentication": auth_score,
		"restoration": restoration_score,
		"integrity": integrity_score,
		"financial": financial_score,
		"museumTrust": museum_score,
		"collectorReputation": collector_score,
		"grandReserveRevenue": revenue,
		"collectionQuality": collection_score,
		"balancedScore": balanced,
		"ethics": int(campaign_state.ethics),
		"collectorTrust": total_collector_trust()
	}


func evaluate_ending(metrics: Dictionary) -> String:
	var fixtures := metrics.duplicate(true)
	for ending: Dictionary in RuntimeRegistry.campaign.get("endings", []):
		if ending.has("conditions") and evaluate_condition(ending.conditions, fixtures):
			return ending.id
	var pillar_order := ["restoration", "financial", "integrity"]
	var best_pillar := "restoration"
	var best_score := -1.0
	for pillar: String in pillar_order:
		var score := float(fixtures.get(pillar, 0.0))
		if score > best_score:
			best_score = score
			best_pillar = pillar
	for ending: Dictionary in RuntimeRegistry.campaign.get("endings", []):
		if ending.get("pillar", "") == best_pillar:
			return ending.id
	return "ENDING_A"


func acknowledge_epilogue() -> void:
	if gameplay_mutation_locked():
		last_action_error = "PENDING_AUCTION_LOCKED"
		return
	if campaign_state.currentEnding.is_empty():
		return
	campaign_state.epilogueSeen = true
	campaign_state.postGame = true
	refresh_campaign_progress()
	save_game()
	campaign_changed.emit()


func prepare_case_for_test(case_id: String) -> bool:
	if not campaign_test_mode:
		return false
	var artifact := begin_case(case_id)
	if artifact.is_empty():
		return campaign_state.completedCases.has(case_id)
	for _pass in range(12):
		var public_state := get_case_public_state(case_id)
		var progressed := false
		for evidence: Dictionary in public_state.get("availableEvidence", []):
			if not evidence.get("requiredTools", []).is_empty():
				select_tool(String(evidence.requiredTools[0]))
			var discovered := discover_case_evidence(case_id, evidence.id)
			progressed = progressed or bool(discovered.get("ok", false))
		if not progressed:
			break
	var observed := get_case_public_state(case_id)
	var best_hypothesis := ""
	var best_score := -999999
	var citations: Array = []
	for hypothesis: Dictionary in observed.get("hypotheses", []):
		var hypothesis_id: String = hypothesis.get("id", "")
		var score := 0
		var candidate_citations: Array = []
		for evidence: Dictionary in observed.get("discoveredEvidence", []):
			for relation: Dictionary in evidence.get("relations", []):
				if relation.get("hypothesis_id", "") != hypothesis_id:
					continue
				var signed_strength := int(relation.get("strength", 0)) * (1 if relation.get("stance", "") == "SUPPORT" else -1)
				score += signed_strength
				if signed_strength > 0:
					candidate_citations.append(evidence.id)
		if score > best_score:
			best_score = score
			best_hypothesis = hypothesis_id
			citations = candidate_citations
	if best_hypothesis.is_empty() or citations.is_empty():
		return false
	set_case_hypothesis(case_id, best_hypothesis)
	var resolution := resolve_case_v2(case_id, best_hypothesis, citations)
	if not bool(resolution.get("ok", false)):
		return false
	if case_id == "prologue_clock":
		var value := appraise(artifact)
		list_auction(artifact, 1, 1, artifact.confidence, "CERTAIN")
		var result := sell(artifact)
		return bool(result.get("reserve_met", false)) and campaign_state.completedCases.has(case_id)
	var story_case: Dictionary = RuntimeRegistry.get_case(case_id)
	if story_case.get("act", "") != "ACT_5":
		var value := appraise(artifact)
		list_auction(artifact, 1, 1, artifact.confidence, "LIKELY")
		var sale_result := sell(artifact)
		if not bool(sale_result.get("reserve_met", false)):
			return false
	return campaign_state.completedCases.has(case_id)


func fast_forward_campaign_for_test() -> Dictionary:
	if not campaign_test_mode:
		return {"passed": false, "reason": "CAMPAIGN_TEST_MODE disabled"}
	var transitions: Array = []
	for act_id: String in ["PROLOGUE", "ACT_1", "ACT_2", "ACT_3", "ACT_4", "ACT_5"]:
		for case_id: String in act_case_ids(act_id):
			var completed: bool = prepare_case_for_test(case_id)
			transitions.append({"act": act_id, "case": case_id, "completed": completed, "currentAct": campaign_state.currentAct})
			if not completed:
				return {"passed": false, "transitions": transitions}
	refresh_campaign_progress()
	var eligible := eligible_final_lots()
	for index in range(mini(3, eligible.size())):
		select_final_lot(eligible[index].uniqueId)
	var final_result := run_grand_reserve()
	acknowledge_epilogue()
	return {"passed": bool(campaign_state.postGame), "transitions": transitions, "grandReserve": final_result, "ending": campaign_state.currentEnding}


func normalize_profile_dictionary(target: Dictionary) -> void:
	target.schema_version = PROFILE_SCHEMA_VERSION
	target.highestUnlockedStage = clampi(int(target.get("highestUnlockedStage", 1)), 1, 10)
	var cleared: Array = []
	for stage_value: Variant in target.get("clearedStages", []):
		var stage_id := int(stage_value)
		if stage_id >= 1 and stage_id <= 10 and not cleared.has(stage_id):
			cleared.append(stage_id)
	cleared.sort()
	target.clearedStages = cleared
	for stage_id: int in cleared:
		target.highestUnlockedStage = maxi(int(target.highestUnlockedStage), mini(10, stage_id + 1))
	var normalized_best := {}
	var raw_best: Variant = target.get("stageBest", {})
	if raw_best is Dictionary:
		for key_value: Variant in raw_best.keys():
			var stage_id := int(String(key_value))
			var score_value: Variant = raw_best[key_value]
			if stage_id >= 1 and stage_id <= 10 and (score_value is int or score_value is float):
				normalized_best[str(stage_id)] = maxf(0.0, float(score_value))
	target.stageBest = normalized_best
	target.tutorialCompletedSteps = _normalized_tutorial_completed_steps(target.get("tutorialCompletedSteps", []))


func profile_payload() -> Dictionary:
	var payload := player_profile.duplicate(true)
	normalize_profile_dictionary(payload)
	return payload


func validate_profile_payload(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {"ok": false, "code": "EMPTY_OR_INVALID_JSON"}
	var schema_value: Variant = data.get("schema_version", null)
	if not schema_value is int and not schema_value is float:
		return {"ok": false, "code": "INVALID_SCHEMA_VERSION_TYPE"}
	if int(schema_value) != PROFILE_SCHEMA_VERSION:
		return {"ok": false, "code": "UNSUPPORTED_SCHEMA_VERSION"}
	var highest_value: Variant = data.get("highestUnlockedStage", null)
	if (not highest_value is int and not highest_value is float) or int(highest_value) < 1 or int(highest_value) > 10:
		return {"ok": false, "code": "INVALID_HIGHEST_UNLOCKED_STAGE"}
	if not data.get("clearedStages", null) is Array:
		return {"ok": false, "code": "INVALID_CLEARED_STAGES"}
	var seen := {}
	var required_highest := 1
	for stage_value: Variant in data.clearedStages:
		if not stage_value is int and not stage_value is float:
			return {"ok": false, "code": "INVALID_CLEARED_STAGE_TYPE"}
		var stage_id := int(stage_value)
		if stage_id < 1 or stage_id > 10 or seen.has(stage_id):
			return {"ok": false, "code": "INVALID_CLEARED_STAGE"}
		seen[stage_id] = true
		required_highest = maxi(required_highest, mini(10, stage_id + 1))
	if int(highest_value) < required_highest:
		return {"ok": false, "code": "PROFILE_WOULD_RELOCK_CLEARED_STAGE"}
	var best_value: Variant = data.get("stageBest", null)
	if not best_value is Dictionary:
		return {"ok": false, "code": "INVALID_STAGE_BEST"}
	for key_value: Variant in best_value.keys():
		var stage_id := int(String(key_value))
		var score_value: Variant = best_value[key_value]
		if stage_id < 1 or stage_id > 10 or (not score_value is int and not score_value is float) or float(score_value) < 0.0:
			return {"ok": false, "code": "INVALID_STAGE_BEST_ENTRY"}
	# schema v1 profiles shipped before contextual guidance and legitimately lack
	# this additive field. When present it must be the exact authored prefix.
	if data.has("tutorialCompletedSteps"):
		var tutorial_value: Variant = data.get("tutorialCompletedSteps", null)
		if not tutorial_value is Array:
			return {"ok": false, "code": "INVALID_TUTORIAL_COMPLETED_STEPS"}
		var authored_prefix := _normalized_tutorial_completed_steps(tutorial_value)
		if tutorial_value != authored_prefix:
			return {"ok": false, "code": "INVALID_TUTORIAL_STEP_SEQUENCE"}
	return {"ok": true, "code": "OK"}


func configure_profile_crash_injection_for_test(point: String) -> bool:
	if not campaign_test_mode or not SAVE_CRASH_TEST_POINTS.has(point):
		return false
	_profile_crash_injection_for_test = point
	return true


func consume_profile_crash_injection_for_test(point: String) -> bool:
	if not campaign_test_mode or _profile_crash_injection_for_test != point:
		return false
	_profile_crash_injection_for_test = ""
	last_profile_save_error = "TEST_CRASH_INJECTION:%s" % point
	return true


func save_profile(path: String = PROFILE_PATH) -> bool:
	if not persistence_enabled:
		return true
	last_profile_save_error = ""
	var temp_path := path + SAVE_TEMP_SUFFIX
	var backup_path := path + SAVE_BACKUP_SUFFIX
	remove_save_file(temp_path)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		last_profile_save_error = "TEMP_OPEN_FAILED"
		return false
	if consume_profile_crash_injection_for_test("A_TMP_WRITE_INTERRUPTION"):
		file.store_string(JSON.stringify({"schema_version": PROFILE_SCHEMA_VERSION}))
		file.flush()
		file.close()
		return false
	file.store_string(JSON.stringify(profile_payload(), "  "))
	file.flush()
	file.close()
	if consume_profile_crash_injection_for_test("B_TMP_COMPLETE_BEFORE_VALIDATION"):
		return false
	var staged := read_save_dictionary(temp_path)
	var staged_validation := validate_profile_payload(staged)
	if not bool(staged_validation.get("ok", false)):
		last_profile_save_error = "TEMP_VALIDATION_FAILED:%s" % staged_validation.get("code", "INVALID")
		remove_save_file(temp_path)
		return false
	if consume_profile_crash_injection_for_test("C_TMP_VALIDATED_BEFORE_BACKUP"):
		return false
	remove_save_file(backup_path)
	if FileAccess.file_exists(path) and not rename_save_file(path, backup_path):
		last_profile_save_error = "BACKUP_RENAME_FAILED"
		remove_save_file(temp_path)
		return false
	if consume_profile_crash_injection_for_test("D_AFTER_BACKUP_BEFORE_PROMOTE"):
		return false
	if not rename_save_file(temp_path, path):
		last_profile_save_error = "CURRENT_RENAME_FAILED"
		if FileAccess.file_exists(backup_path):
			rename_save_file(backup_path, path)
		return false
	if consume_profile_crash_injection_for_test("E_AFTER_PROMOTE_BEFORE_FINAL_VALIDATION"):
		return false
	if consume_profile_crash_injection_for_test("F_CORRUPT_PROMOTED_CURRENT"):
		var corrupt_current := FileAccess.open(path, FileAccess.WRITE)
		if corrupt_current != null:
			corrupt_current.store_string("[]")
			corrupt_current.flush()
			corrupt_current.close()
		return false
	var committed := read_save_dictionary(path)
	var committed_validation := validate_profile_payload(committed)
	if not bool(committed_validation.get("ok", false)):
		last_profile_save_error = "FINAL_VALIDATION_FAILED:%s" % committed_validation.get("code", "INVALID")
		remove_save_file(path)
		if FileAccess.file_exists(backup_path):
			rename_save_file(backup_path, path)
		return false
	return true


func load_profile(path: String = PROFILE_PATH) -> bool:
	last_profile_load_recovered = false
	last_profile_load_error = ""
	var failures: Array = []
	for candidate_path: String in [path, path + SAVE_BACKUP_SUFFIX]:
		var parsed := read_save_dictionary(candidate_path)
		var validation := validate_profile_payload(parsed)
		if not bool(validation.get("ok", false)):
			failures.append("%s=%s" % [candidate_path, validation.get("code", "INVALID")])
			continue
		var loaded_profile: Dictionary = parsed.duplicate(true)
		normalize_profile_dictionary(loaded_profile)
		player_profile = loaded_profile
		last_profile_load_recovered = candidate_path.ends_with(SAVE_BACKUP_SUFFIX)
		profile_changed.emit()
		return true
	last_profile_load_error = "NO_VALID_PROFILE:%s" % ",".join(failures)
	return false


func save_payload() -> Dictionary:
	var saved_inventory: Array = []
	for artifact: Dictionary in inventory:
		saved_inventory.append(serialize_instance(artifact))
	var payload := {
		"saveVersion": save_version, "gameVersion": game_version, "money": money,
		"reputation": reputation, "day": day, "inventory": saved_inventory,
		"activeWorkpieceId": active_workpiece.get("uniqueId", ""), "transactions": transactions,
		"auctionHistory": auction_history, "statistics": statistics, "marketState": market_state,
		"marketRoster": market_roster, "marketRosterDay": market_roster_day, "masterSeed": master_seed, "rngState": rng.state,
		# JSON numeric values cannot retain every signed 64-bit RNG cursor bit.
		# Keep the numeric field for legacy readers and a decimal string as the
		# authoritative exact cursor for deterministic resume.
		"rngStateExact": str(rng.state),
		"instanceCounter": instance_counter, "selectedTool": selected_tool,
		"upgrades": owned_upgrades, "language": language, "currentEventId": current_event_id,
		"eventHistory": event_history, "dailyModifiers": daily_modifiers,
		"pendingAuction": pending_auction,
		"grandReserveSession": grand_reserve_session,
		"campaign": campaign_state,
		"currentStage": current_stage, "stageRunState": stage_run_state
	}
	return payload.duplicate(true)


## Deterministic crash injection is available only when an explicit test harness
## has enabled campaign_test_mode. No production UI calls or exposes this API.
func configure_save_crash_injection_for_test(point: String) -> bool:
	if not campaign_test_mode or not SAVE_CRASH_TEST_POINTS.has(point):
		return false
	_save_crash_injection_for_test = point
	return true


func consume_save_crash_injection_for_test(point: String) -> bool:
	if not campaign_test_mode or _save_crash_injection_for_test != point:
		return false
	_save_crash_injection_for_test = ""
	last_save_error = "TEST_CRASH_INJECTION:%s" % point
	return true


func save_game(path: String = SAVE_PATH) -> bool:
	if not persistence_enabled:
		return true
	last_save_error = ""
	var temp_path := path + SAVE_TEMP_SUFFIX
	var backup_path := path + SAVE_BACKUP_SUFFIX
	remove_save_file(temp_path)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		last_save_error = "TEMP_OPEN_FAILED"
		return false
	if consume_save_crash_injection_for_test("A_TMP_WRITE_INTERRUPTION"):
		# A syntactically readable header models an interrupted logical payload
		# without turning the expected corruption fixture into an engine error.
		file.store_string(JSON.stringify({"saveVersion": save_version}))
		file.flush()
		file.close()
		return false
	file.store_string(JSON.stringify(save_payload(), "  "))
	file.flush()
	file.close()
	if consume_save_crash_injection_for_test("B_TMP_COMPLETE_BEFORE_VALIDATION"):
		return false
	var staged := read_save_dictionary(temp_path)
	var staged_validation := validate_save_payload(staged)
	if not bool(staged_validation.get("ok", false)):
		last_save_error = "TEMP_VALIDATION_FAILED:%s" % staged_validation.get("code", "INVALID")
		remove_save_file(temp_path)
		return false
	if consume_save_crash_injection_for_test("C_TMP_VALIDATED_BEFORE_BACKUP"):
		return false
	remove_save_file(backup_path)
	if FileAccess.file_exists(path) and not rename_save_file(path, backup_path):
		last_save_error = "BACKUP_RENAME_FAILED"
		remove_save_file(temp_path)
		return false
	if consume_save_crash_injection_for_test("D_AFTER_BACKUP_BEFORE_PROMOTE"):
		return false
	if not rename_save_file(temp_path, path):
		last_save_error = "CURRENT_RENAME_FAILED"
		if FileAccess.file_exists(backup_path):
			rename_save_file(backup_path, path)
		return false
	if consume_save_crash_injection_for_test("E_AFTER_PROMOTE_BEFORE_FINAL_VALIDATION"):
		return false
	if consume_save_crash_injection_for_test("F_CORRUPT_PROMOTED_CURRENT"):
		var corrupt_current := FileAccess.open(path, FileAccess.WRITE)
		if corrupt_current != null:
			corrupt_current.store_string("[]")
			corrupt_current.flush()
			corrupt_current.close()
		return false
	var committed := read_save_dictionary(path)
	var committed_validation := validate_save_payload(committed)
	if not bool(committed_validation.get("ok", false)):
		last_save_error = "FINAL_VALIDATION_FAILED:%s" % committed_validation.get("code", "INVALID")
		remove_save_file(path)
		if FileAccess.file_exists(backup_path):
			rename_save_file(backup_path, path)
		return false
	return true


func load_game(path: String = SAVE_PATH) -> bool:
	last_load_recovered = false
	last_load_error = ""
	var failures: Array = []
	for candidate_path: String in [path, path + SAVE_BACKUP_SUFFIX]:
		var parsed := read_save_dictionary(candidate_path)
		var validation := validate_save_payload(parsed)
		if not bool(validation.get("ok", false)):
			failures.append("%s=%s" % [candidate_path, validation.get("code", "INVALID")])
			continue
		if apply_save_data(parsed):
			last_load_recovered = candidate_path.ends_with(SAVE_BACKUP_SUFFIX)
			# The run save is authoritative for a completed stage. If a process
			# stopped after the run promotion but before its profile mirror, a normal
			# Continue repairs the default profile without coupling custom test slots
			# to player data.
			if last_profile_reconciled_from_run and path == SAVE_PATH:
				save_profile()
			return true
		failures.append("%s=APPLY_FAILED" % candidate_path)
	last_load_error = "NO_VALID_SAVE:%s" % ",".join(failures)
	return false


func read_save_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func stage_telemetry_shape_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var telemetry: Dictionary = value
	var budget_value: Variant = telemetry.get("budgetBasis", null)
	if (not budget_value is int and not budget_value is float) or int(budget_value) < 1:
		return false
	for count_key: String in ["repairActions", "investigationActions", "investigationRiskActions", "auctionCount", "noSaleCount", "relistCount", "artifactSalesCount"]:
		var count_value: Variant = telemetry.get(count_key, null)
		if (not count_value is int and not count_value is float) or int(count_value) < 0:
			return false
	for float_key: String in ["repairCostAccrued", "investigationRiskWeightSum"]:
		var float_value: Variant = telemetry.get(float_key, null)
		if (not float_value is int and not float_value is float) or not is_finite(float(float_value)) or float(float_value) < 0.0:
			return false
	var tool_counts_value: Variant = telemetry.get("repairToolUseCounts", null)
	if not tool_counts_value is Dictionary or tool_counts_value.size() > 64:
		return false
	var tool_use_total := 0
	for tool_value: Variant in tool_counts_value.keys():
		var usage_value: Variant = tool_counts_value.get(tool_value, null)
		if not tool_value is String or String(tool_value).is_empty() \
			or (not usage_value is int and not usage_value is float) or int(usage_value) <= 0:
			return false
		tool_use_total += int(usage_value)
	if tool_use_total > int(telemetry.get("repairActions", 0)):
		return false
	var strategy_counts_value: Variant = telemetry.get("listingStrategyCounts", null)
	if not strategy_counts_value is Dictionary:
		return false
	var listing_total := 0
	for strategy_id: String in STAGE_TELEMETRY_STRATEGIES:
		var strategy_value: Variant = strategy_counts_value.get(strategy_id, null)
		if (not strategy_value is int and not strategy_value is float) or int(strategy_value) < 0:
			return false
		listing_total += int(strategy_value)
	if int(telemetry.get("investigationRiskActions", 0)) > int(telemetry.get("investigationActions", 0)) \
		or int(telemetry.get("noSaleCount", 0)) + int(telemetry.get("artifactSalesCount", 0)) != int(telemetry.get("auctionCount", 0)) \
		or int(telemetry.get("auctionCount", 0)) > listing_total \
		or int(telemetry.get("relistCount", 0)) > listing_total:
		return false
	return true


func stage_telemetry_seen_ids_shape_valid(value: Variant) -> bool:
	if not value is Array or value.size() > 4096:
		return false
	var seen := {}
	for id_value: Variant in value:
		if not id_value is String or String(id_value).is_empty() or seen.has(String(id_value)):
			return false
		seen[String(id_value)] = true
	return true


func stage_replay_telemetry_snapshot_shape_valid(value: Variant, stage_id: int) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	if not value.get("available", null) is bool or not bool(value.get("available", false)) or int(value.get("stage", 0)) != stage_id:
		return false
	return not normalize_stage_replay_telemetry_snapshot(value, stage_id).is_empty()


func remove_save_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


func rename_save_file(from_path: String, to_path: String) -> bool:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(from_path), ProjectSettings.globalize_path(to_path)) == OK


func validate_save_payload(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {"ok": false, "code": "EMPTY_OR_INVALID_JSON"}
	var version_value: Variant = data.get("saveVersion", 2)
	if not version_value is int and not version_value is float:
		return {"ok": false, "code": "INVALID_VERSION_TYPE"}
	var version := int(version_value)
	if version < 2 or version > save_version:
		return {"ok": false, "code": "UNSUPPORTED_VERSION"}
	for numeric_key: String in ["money", "reputation", "day"]:
		if not data.has(numeric_key) or (not data[numeric_key] is int and not data[numeric_key] is float):
			return {"ok": false, "code": "INVALID_%s" % numeric_key.to_upper()}
	if not data.get("inventory", []) is Array:
		return {"ok": false, "code": "INVALID_INVENTORY"}
	var instance_ids := {}
	var inventory_entries := {}
	for saved_value: Variant in data.get("inventory", []):
		if not serialized_artifact_runtime_shape_valid(saved_value):
			return {"ok": false, "code": "INVALID_INVENTORY_ENTRY"}
		var saved: Dictionary = saved_value
		var instance_id: String = saved.get("uniqueId", "")
		var artifact_spec_id := String(saved.get("artifactSpecId", ""))
		if instance_id.is_empty() or instance_ids.has(instance_id) or artifact_spec_id.is_empty():
			return {"ok": false, "code": "INVALID_INSTANCE_ID"}
		if RuntimeRegistry.get_spec(artifact_spec_id).is_empty():
			return {"ok": false, "code": "INVALID_ARTIFACT_SPEC"}
		instance_ids[instance_id] = true
		inventory_entries[instance_id] = saved
	# These dictionaries are consumed by direct float()/int() conversions during
	# ordinary market, repair and auction play. Reject authored non-numeric values
	# here instead of allowing frozen auction decisions to hide them behind a
	# fallback and producing a post-load progression lock.
	if data.has("marketState") and not finite_numeric_dictionary_valid(data.get("marketState")):
		return {"ok": false, "code": "INVALID_MARKET_STATE"}
	if data.has("dailyModifiers") and not finite_numeric_dictionary_valid(data.get("dailyModifiers")):
		return {"ok": false, "code": "INVALID_DAILY_MODIFIERS"}
	if data.has("upgrades") and not saved_upgrade_ids_valid(data.get("upgrades")):
		return {"ok": false, "code": "INVALID_UPGRADES"}
	if version >= 3 and not data.get("campaign", {}) is Dictionary:
		return {"ok": false, "code": "INVALID_CAMPAIGN"}
	var campaign: Dictionary = data.get("campaign", {})
	if version >= 4:
		if not campaign.get("caseStates", {}) is Dictionary or not campaign.get("caseArtifactLedger", {}) is Dictionary:
			return {"ok": false, "code": "INVALID_CASE_STATE"}
		for case_state_value: Variant in campaign.get("caseStates", {}).values():
			if not case_state_value is Dictionary \
				or (case_state_value.has("resolved") and not case_state_value.get("resolved") is bool) \
				or (case_state_value.has("resolutionResult") and not case_state_value.get("resolutionResult") is Dictionary) \
				or (case_state_value.has("discoveredEvidenceIds") and not case_state_value.get("discoveredEvidenceIds") is Array):
				return {"ok": false, "code": "INVALID_CASE_STATE_ENTRY"}
		for ledger_value: Variant in campaign.get("caseArtifactLedger", {}).values():
			if not ledger_value is Dictionary:
				return {"ok": false, "code": "INVALID_CASE_ARTIFACT_LEDGER_ENTRY"}
		var grand_reserve: Variant = campaign.get("grandReserve", {})
		if not grand_reserve is Dictionary \
			or not grand_reserve.get("selectedLotIds", []) is Array \
			or not grand_reserve.get("results", []) is Array \
			or not grand_reserve.get("score", {}) is Dictionary \
			or not grand_reserve.get("invited", false) is bool \
			or not grand_reserve.get("completed", false) is bool:
			return {"ok": false, "code": "INVALID_GRAND_RESERVE"}
		var selected_seen := {}
		for selected_value: Variant in grand_reserve.get("selectedLotIds", []):
			var selected_id := String(selected_value)
			if selected_id.is_empty() or selected_seen.has(selected_id):
				return {"ok": false, "code": "INVALID_GRAND_RESERVE_SELECTION"}
			selected_seen[selected_id] = true
	if version >= 5:
		var stage_value: Variant = data.get("currentStage", null)
		if (not stage_value is int and not stage_value is float) or int(stage_value) < 1 or int(stage_value) > 10:
			return {"ok": false, "code": "INVALID_CURRENT_STAGE"}
		var run_value: Variant = data.get("stageRunState", null)
		if not run_value is Dictionary:
			return {"ok": false, "code": "INVALID_STAGE_RUN_STATE"}
		if int(run_value.get("stageId", 0)) != int(stage_value) or not String(run_value.get("status", "")) in ["NOT_STARTED", "RUNNING", "CLEARED"]:
			return {"ok": false, "code": "INCONSISTENT_STAGE_RUN_STATE"}
		if version >= 6:
			if not run_value.get("telemetryAvailable", null) is bool \
				or not stage_telemetry_shape_valid(run_value.get("telemetry", null)) \
				or not stage_telemetry_seen_ids_shape_valid(run_value.get("telemetrySeenIds", null)) \
				or not stage_replay_telemetry_snapshot_shape_valid(run_value.get("stageReplayTelemetrySnapshot", null), int(stage_value)):
				return {"ok": false, "code": "INVALID_STAGE_TELEMETRY"}
			var telemetry_available := bool(run_value.get("telemetryAvailable", false))
			var telemetry_snapshot: Dictionary = run_value.get("stageReplayTelemetrySnapshot", {})
			if (telemetry_available and String(run_value.get("status", "")) == "CLEARED" and telemetry_snapshot.is_empty()) \
				or (not telemetry_available and not telemetry_snapshot.is_empty()):
				return {"ok": false, "code": "INCONSISTENT_STAGE_TELEMETRY"}
	if data.has("pendingAuction"):
		if not data.get("pendingAuction") is Dictionary:
			return {"ok": false, "code": "INVALID_PENDING_AUCTION"}
		var authored_pending: Dictionary = data.get("pendingAuction", {})
		var pending_value := normalize_pending_auction(authored_pending)
		var authored_status := String(authored_pending.get("status", "NONE"))
		if authored_status in ["PENDING", "COMMITTED"] and (
			String(pending_value.get("status", "NONE")) == "NONE" \
			or not pending_auction_contract_valid(authored_pending, pending_value)
		):
			return {"ok": false, "code": "INVALID_PENDING_AUCTION_CONTRACT"}
		if authored_status == "PENDING":
			var pending_artifact_id := String(pending_value.get("artifactId", ""))
			if not inventory_entries.has(pending_artifact_id) or bool(inventory_entries[pending_artifact_id].get("sold", false)):
				return {"ok": false, "code": "INVALID_PENDING_AUCTION_CONTRACT"}
			var pending_artifact := hydrate_instance(inventory_entries[pending_artifact_id])
			var expected_decisions := auction_public_decisions_with_context(
				pending_artifact,
				bool(pending_value.get("grandReserve", false)),
				{
					"stage": data.get("currentStage", 1),
					"day": data.get("day", 0),
					"marketState": data.get("marketState", default_market_state()),
					"dailyModifiers": data.get("dailyModifiers", {}),
					"upgrades": data.get("upgrades", []),
					"campaign": campaign
				}
			)
			if not canonical_json_values_equal(pending_value.get("decisions", {}), expected_decisions) \
				or String(pending_value.get("publicFingerprint", "")) != auction_public_fingerprint(expected_decisions):
				return {"ok": false, "code": "INVALID_PENDING_AUCTION_CONTRACT"}
	if data.has("grandReserveSession"):
		if not data.get("grandReserveSession") is Dictionary:
			return {"ok": false, "code": "INVALID_GRAND_RESERVE_SESSION"}
		var authored_session: Dictionary = data.get("grandReserveSession", {})
		var normalized_session := normalize_grand_reserve_session(authored_session)
		var authored_phase := String(authored_session.get("phase", "IDLE"))
		if authored_phase != "IDLE" and String(normalized_session.get("phase", "IDLE")) == "IDLE":
			return {"ok": false, "code": "INVALID_GRAND_RESERVE_SESSION_CONTRACT"}
		var authored_pending: Dictionary = data.get("pendingAuction", {}) if data.get("pendingAuction", {}) is Dictionary else {}
		var normalized_pending := normalize_pending_auction(authored_pending)
		var pending_status := String(normalized_pending.get("status", "NONE"))
		var pending_is_reserve := bool(normalized_pending.get("grandReserve", false))
		if authored_phase == "IDLE":
			if pending_is_reserve and pending_status in ["PENDING", "COMMITTED"]:
				return {"ok": false, "code": "ORPHANED_GRAND_RESERVE_PENDING"}
		else:
			var lot_index := int(normalized_session.get("currentLotIndex", -1))
			var lot_uids: Array = normalized_session.get("lotUids", [])
			var expected_artifact_id := String(lot_uids[lot_index])
			# BEGIN freezes all three owned lots. A save that loses or pre-sells any
			# unprocessed lot would otherwise load into a globally locked session
			# whose NEXT LOT can never succeed.
			var required_inventory_start := lot_index if authored_phase == "AUCTION_PENDING" else lot_index + 1
			if authored_phase in ["AUCTION_PENDING", "BETWEEN_LOTS"]:
				for required_index in range(required_inventory_start, lot_uids.size()):
					var required_uid := String(lot_uids[required_index])
					if not inventory_entries.has(required_uid) or bool(inventory_entries[required_uid].get("sold", false)):
						return {"ok": false, "code": "INCONSISTENT_GRAND_RESERVE_INVENTORY"}
			if not pending_is_reserve or String(normalized_pending.get("artifactId", "")) != expected_artifact_id:
				return {"ok": false, "code": "INCONSISTENT_GRAND_RESERVE_ARTIFACT"}
			if authored_phase == "AUCTION_PENDING":
				if pending_status != "PENDING" \
					or String(normalized_pending.get("transactionId", "")) != String(normalized_session.get("activeTransactionId", "")) \
					or not instance_ids.has(expected_artifact_id) \
					or not canonical_json_values_equal(
						normalized_session.get("activeArtifact", {}),
						_grand_reserve_artifact_snapshot(hydrate_instance(inventory_entries.get(expected_artifact_id, {})))
					):
					return {"ok": false, "code": "INCONSISTENT_GRAND_RESERVE_PENDING"}
			elif authored_phase == "BETWEEN_LOTS":
				var between_artifact: Variant = normalized_session.get("receipts", [])[-1].get("artifact", {})
				var between_auction: Variant = normalized_session.get("receipts", [])[-1].get("auction", {})
				if pending_status != "COMMITTED" \
					or String(normalized_pending.get("transactionId", "")) != String(normalized_session.get("activeTransactionId", "")) \
					or not canonical_json_values_equal(normalized_session.get("activeArtifact", {}), between_artifact) \
					or not canonical_json_values_equal(normalized_pending.get("receipt", {}), between_auction):
					return {"ok": false, "code": "INCONSISTENT_GRAND_RESERVE_BETWEEN"}
			elif authored_phase == "FINALIZED":
				var final_receipts: Array = normalized_session.get("receipts", [])
				var final_transaction_id := String(final_receipts[-1].get("auction", {}).get("transactionId", ""))
				var saved_grand_reserve: Dictionary = campaign.get("grandReserve", {}) if campaign.get("grandReserve", {}) is Dictionary else {}
				if pending_status != "COMMITTED" \
					or String(normalized_pending.get("transactionId", "")) != final_transaction_id \
					or not canonical_json_values_equal(normalized_session.get("activeArtifact", {}), final_receipts[-1].get("artifact", {})) \
					or not canonical_json_values_equal(normalized_pending.get("receipt", {}), final_receipts[-1].get("auction", {})) \
					or not bool(saved_grand_reserve.get("completed", false)) \
					or not saved_grand_reserve.get("results", []) is Array \
					or not canonical_json_values_equal(saved_grand_reserve.get("results", []), final_receipts) \
					or not grand_reserve_score_valid(saved_grand_reserve.get("score", {})) \
					or String(campaign.get("currentEnding", "")).is_empty():
					return {"ok": false, "code": "INCONSISTENT_GRAND_RESERVE_FINAL"}
			if authored_phase != "IDLE" \
				and campaign.get("grandReserve", {}).get("selectedLotIds", []) != lot_uids:
				return {"ok": false, "code": "INCONSISTENT_GRAND_RESERVE_SELECTION"}
	elif data.get("pendingAuction", {}) is Dictionary \
		and bool(data.get("pendingAuction", {}).get("grandReserve", false)) \
		and String(data.get("pendingAuction", {}).get("status", "NONE")) in ["PENDING", "COMMITTED"]:
		# No released save schema ever authored a standalone live Reserve pending
		# transaction. Treat it as an orphan rather than committing outside the
		# three-lot coordinator.
		return {"ok": false, "code": "MISSING_GRAND_RESERVE_SESSION"}
	if data.has("rngStateExact") and (not data.get("rngStateExact") is String or String(data.get("rngStateExact", "")).is_empty()):
		return {"ok": false, "code": "INVALID_EXACT_RNG_STATE"}
	return {"ok": true, "code": "OK"}


func merge_missing_dictionary(target: Dictionary, defaults: Dictionary) -> void:
	for key: String in defaults.keys():
		if not target.has(key):
			target[key] = defaults[key].duplicate(true) if defaults[key] is Dictionary or defaults[key] is Array else defaults[key]
		elif target[key] is Dictionary and defaults[key] is Dictionary:
			merge_missing_dictionary(target[key], defaults[key])


func canonicalize_unresolved_authored_case_states() -> void:
	var case_states_value: Variant = campaign_state.get("caseStates", {})
	if not case_states_value is Dictionary:
		return
	var case_states: Dictionary = case_states_value
	var completed_cases_value: Variant = campaign_state.get("completedCases", {})
	var completed_cases: Dictionary = completed_cases_value if completed_cases_value is Dictionary else {}
	for case_id_value: Variant in case_states.keys():
		var case_id := String(case_id_value)
		if not RuntimeRegistry.has_authored_case_v2(case_id):
			continue
		var state_value: Variant = case_states.get(case_id_value, {})
		if not state_value is Dictionary:
			continue
		var state: Dictionary = state_value
		# Completed or resolved rows are historical records. Their original IDs,
		# selected conclusion and result must never be rewritten when authored
		# content is added after the save was created.
		if bool(state.get("resolved", false)) or completed_cases.has(case_id):
			continue
		var definition: Dictionary = RuntimeRegistry.get_case_v2(case_id)
		if definition.is_empty():
			continue

		var valid_hypotheses := {}
		for hypothesis_value: Variant in definition.get("hypotheses", []):
			if hypothesis_value is Dictionary:
				var hypothesis_id := String((hypothesis_value as Dictionary).get("id", ""))
				if not hypothesis_id.is_empty():
					valid_hypotheses[hypothesis_id] = true
		var selected_value: Variant = state.get("selectedHypothesisId", "")
		if not selected_value is String or not valid_hypotheses.has(String(selected_value)):
			state["selectedHypothesisId"] = ""

		var valid_evidence := {}
		for evidence_value: Variant in definition.get("evidence", []):
			if evidence_value is Dictionary:
				var evidence_id := String((evidence_value as Dictionary).get("id", ""))
				if not evidence_id.is_empty():
					valid_evidence[evidence_id] = true
		var discovered: Array = []
		var discovered_set := {}
		var saved_discovered_value: Variant = state.get("discoveredEvidenceIds", [])
		if saved_discovered_value is Array:
			for evidence_id_value: Variant in saved_discovered_value as Array:
				if not evidence_id_value is String:
					continue
				var evidence_id := String(evidence_id_value)
				if valid_evidence.has(evidence_id) and not discovered_set.has(evidence_id):
					discovered.append(evidence_id)
					discovered_set[evidence_id] = true
		state["discoveredEvidenceIds"] = discovered

		var cited: Array = []
		var cited_set := {}
		var saved_cited_value: Variant = state.get("citedEvidenceIds", [])
		if saved_cited_value is Array:
			for evidence_id_value: Variant in saved_cited_value as Array:
				if not evidence_id_value is String:
					continue
				var evidence_id := String(evidence_id_value)
				if discovered_set.has(evidence_id) and not cited_set.has(evidence_id):
					cited.append(evidence_id)
					cited_set[evidence_id] = true
		state["citedEvidenceIds"] = cited
		# An unresolved case cannot own a historical resolution receipt. Clear only
		# that contradictory field; all unrelated run, artifact and ledger data stay
		# byte-for-byte semantically owned by the loaded save.
		state["resolutionResult"] = {}


func normalize_campaign_state() -> void:
	var defaults := default_campaign_state()
	merge_missing_dictionary(campaign_state, defaults)
	campaign_state.schemaVersion = 2
	for artifact: Dictionary in inventory:
		var case_id: String = artifact.get("caseId", "")
		if case_id.is_empty():
			continue
		if not campaign_state.caseArtifactLedger.has(case_id):
			campaign_state.caseArtifactLedger[case_id] = {"issued": true, "artifactUid": artifact.uniqueId, "disposition": "INVENTORY", "saleTransactionId": "", "publicConditionSnapshot": {}, "publicAppraisalSnapshot": 0}
		if campaign_state.completedCases.has(case_id):
			artifact.caseResolved = true
		ensure_case_runtime_state(case_id)
	canonicalize_unresolved_authored_case_states()
	if grand_reserve_active():
		# A live session freezes all three identities even after a SOLD lot has
		# legitimately left inventory. The session, not inventory, is authoritative.
		campaign_state.grandReserve.selectedLotIds = grand_reserve_session.get("lotUids", []).duplicate(true)
	elif not bool(campaign_state.grandReserve.get("completed", false)):
		var sanitized: Array = []
		for selected_value: Variant in campaign_state.grandReserve.selectedLotIds:
			var selected_id := String(selected_value)
			if not sanitized.has(selected_id) and not find_inventory_instance(selected_id).is_empty():
				sanitized.append(selected_id)
		campaign_state.grandReserve.selectedLotIds = sanitized


func apply_save_data(data: Dictionary) -> bool:
	last_profile_reconciled_from_run = false
	var validation := validate_save_payload(data)
	if not bool(validation.get("ok", false)):
		return false
	var version := int(data.get("saveVersion", 2))
	if version > save_version:
		return false
	money = int(data.get("money", 1200))
	reputation = int(data.get("reputation", 12))
	day = int(data.get("day", 1))
	master_seed = int(data.get("masterSeed", master_seed))
	inventory = []
	for saved: Dictionary in data.get("inventory", []):
		inventory.append(hydrate_instance(saved))
	transactions = data.get("transactions", []).duplicate(true) if data.get("transactions", []) is Array else []
	auction_history = data.get("auctionHistory", []).duplicate(true) if data.get("auctionHistory", []) is Array else []
	statistics = data.get("statistics", default_statistics()).duplicate(true) if data.get("statistics", {}) is Dictionary else default_statistics()
	for key: String in default_statistics().keys():
		if not statistics.has(key):
			statistics[key] = default_statistics()[key]
	market_state = data.get("marketState", default_market_state()).duplicate(true) if data.get("marketState", {}) is Dictionary else default_market_state()
	market_roster = data.get("marketRoster", []).duplicate(true) if data.get("marketRoster", []) is Array else []
	market_roster_day = int(data.get("marketRosterDay", day if not market_roster.is_empty() else 0))
	instance_counter = int(data.get("instanceCounter", inventory.size()))
	selected_tool = data.get("selectedTool", "soft_brush")
	owned_upgrades = data.get("upgrades", []).duplicate(true) if data.get("upgrades", []) is Array else []
	language = data.get("language", "en")
	current_event_id = data.get("currentEventId", "")
	event_history = data.get("eventHistory", []).duplicate(true) if data.get("eventHistory", []) is Array else []
	daily_modifiers = data.get("dailyModifiers", {}).duplicate(true) if data.get("dailyModifiers", {}) is Dictionary else {}
	pending_auction = normalize_pending_auction(data.get("pendingAuction", default_pending_auction()))
	grand_reserve_session = normalize_grand_reserve_session(data.get("grandReserveSession", default_grand_reserve_session()))
	campaign_state = data.get("campaign", default_campaign_state()).duplicate(true) if version >= 3 else default_campaign_state()
	current_stage = clampi(int(data.get("currentStage", 1)), 1, 10) if version >= 5 else 1
	var loaded_stage_run: Dictionary = data.get("stageRunState", default_stage_run_state(current_stage)).duplicate(true) if version >= 5 else default_stage_run_state(current_stage)
	# Absence means a legitimate pre-mirror v5 save. Presence, even malformed,
	# means the run attempted to author the mirror and must normalize safely rather
	# than inheriting a possibly stale longer profile prefix.
	var loaded_run_had_tutorial_mirror := version >= 5 and loaded_stage_run.has("tutorialCompletedSteps")
	var loaded_run_had_clear_ack := version >= 5 and loaded_stage_run.has("stageClearAcknowledged")
	var loaded_run_had_telemetry := version >= 6 \
		and loaded_stage_run.has("telemetryAvailable") \
		and loaded_stage_run.has("telemetry") \
		and loaded_stage_run.has("telemetrySeenIds") \
		and loaded_stage_run.has("stageReplayTelemetrySnapshot")
	stage_run_state = loaded_stage_run
	normalize_stage_run_dictionary(stage_run_state, current_stage)
	if not loaded_run_had_telemetry:
		# A partial legacy run cannot be reconstructed without inventing actions.
		# It remains playable, but its diagnostic card stays explicitly unavailable.
		stage_run_state.telemetryAvailable = false
		stage_run_state.telemetry = default_stage_telemetry(money)
		stage_run_state.telemetrySeenIds = []
		stage_run_state.stageReplayTelemetrySnapshot = {}
	last_profile_reconciled_from_run = reconcile_profile_from_cleared_run()
	if current_stage == int(_tutorial_contract().get("stage_id", 1)) and String(stage_run_state.get("status", "")) in ["RUNNING", "CLEARED"]:
		if loaded_run_had_tutorial_mirror:
			_reconcile_profile_to_tutorial_run(true)
		else:
			# Legacy runs predate the atomic mirror. Seed them from their durable
			# profile once; the next ordinary run save upgrades them in place.
			_seed_tutorial_run_mirror_from_profile()
	normalize_campaign_state()
	# A pre-handoff save that already reached postgame must never be sent
	# backwards to a newly introduced Stage 10 card. A legacy cleared run whose
	# ending has not been acknowledged intentionally gets the one-time card.
	if not loaded_run_had_clear_ack and current_stage == 10 and String(stage_run_state.get("status", "")) == "CLEARED" and bool(campaign_state.get("postGame", false)):
		stage_run_state.stageClearAcknowledged = true
	if market_roster.is_empty():
		generate_market_roster()
	var active_id: String = data.get("activeWorkpieceId", "")
	active_workpiece = find_inventory_instance(active_id)
	if pending_auction_active() and find_inventory_instance(String(pending_auction.get("artifactId", ""))).is_empty():
		pending_auction = default_pending_auction()
	if data.has("rngStateExact"):
		rng.state = int(String(data.get("rngStateExact", "0")))
	elif data.has("rngState"):
		rng.state = int(data.rngState)
	else:
		rng.seed = master_seed
	refresh_campaign_progress()
	state_changed.emit()
	campaign_changed.emit()
	stage_changed.emit()
	if last_profile_reconciled_from_run:
		profile_changed.emit()
	return true
