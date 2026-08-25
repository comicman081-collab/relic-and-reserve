extends SceneTree

## Diagnostic-only audit of whether the canonical stage multiplier materially
## changes actual auction decisions. Production source/data is never mutated;
## the harness writes only its QA report.

const REPORT_PATH := "res://qa/R3_AUCTION_STAGE_SENSITIVITY_AUDIT.json"
const AUDITED_STAGES := [1, 5, 10]
const STRATEGY_ORDER := ["FAST", "BALANCED", "HIGH"]
const STRATEGIES := {
	"FAST": {"startingRatio": 0.50, "reserveRatio": 0.60},
	"BALANCED": {"startingRatio": 0.60, "reserveRatio": 0.72},
	"HIGH": {"startingRatio": 0.68, "reserveRatio": 0.82}
}
const SUPPORT_ORDER := ["LOW", "MEDIUM", "HIGH"]
const SUPPORT_FIXTURES := {
	"LOW": {
		"confidence": 0.24,
		"condition": 42.0,
		"provenanceKnown": false,
		"disclosure": "UNCERTAIN"
	},
	"MEDIUM": {
		"confidence": 0.66,
		"condition": 72.0,
		"provenanceKnown": true,
		"disclosure": "LIKELY"
	},
	"HIGH": {
		"confidence": 0.94,
		"condition": 100.0,
		"provenanceKnown": true,
		"disclosure": "CERTAIN"
	}
}
const ARTIFACT_ROWS := [
	{"specId": "artifact_061", "eraBand": "EARLY", "introducedStage": 1},
	{"specId": "artifact_062", "eraBand": "EARLY", "introducedStage": 1},
	{"specId": "artifact_069", "eraBand": "MID", "introducedStage": 5},
	{"specId": "artifact_070", "eraBand": "MID", "introducedStage": 5},
	{"specId": "artifact_079", "eraBand": "LATE", "introducedStage": 10},
	{"specId": "artifact_080", "eraBand": "LATE", "introducedStage": 10}
]
const PAIRED_SEED_COUNT := 48
const MASTER_SEED_BASE := 970003
const MASTER_SEED_STRIDE := 104729
const ARTIFACT_SEED_BASE := 840061
const FIXED_DAY := 4
const PAIR_IDS := ["1_TO_5", "5_TO_10", "1_TO_10"]
const PAIR_STAGES := {
	"1_TO_5": [1, 5],
	"5_TO_10": [5, 10],
	"1_TO_10": [1, 10]
}

var execution_errors: Array = []
var support_contract_failures: Array = []
var control_failures: Array = []
var availability_invariance_failures: Array = []
var deterministic_failures: Array = []
var cell_buckets: Dictionary = {}
var stage_buckets: Dictionary = {}
var normal_stage_buckets: Dictionary = {}
var normal_stage_preset_buckets: Dictionary = {}
var normal_stage_support_buckets: Dictionary = {}
var availability_preset_buckets: Dictionary = {}
var observations: Dictionary = {}
var expected_controls: Dictionary = {}
var completed_trials := 0
var deterministic_checks := 0


func _init() -> void:
	call_deferred("run")


func rounded(value: float) -> float:
	return snappedf(value, 0.000001)


func ratio(numerator: float, denominator: float) -> float:
	return numerator / denominator if denominator != 0.0 else 0.0


func mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value: Variant in values:
		total += float(value)
	return total / float(values.size())


func numeric_distribution(values: Array) -> Dictionary:
	if values.is_empty():
		return {"count": 0, "min": 0.0, "p50": 0.0, "p90": 0.0, "max": 0.0, "mean": 0.0}
	var ordered: Array = values.duplicate()
	ordered.sort()
	var p50_index := clampi(int(ceil(float(ordered.size()) * 0.50)) - 1, 0, ordered.size() - 1)
	var p90_index := clampi(int(ceil(float(ordered.size()) * 0.90)) - 1, 0, ordered.size() - 1)
	return {
		"count": ordered.size(),
		"min": rounded(float(ordered[0])),
		"p50": rounded(float(ordered[p50_index])),
		"p90": rounded(float(ordered[p90_index])),
		"max": rounded(float(ordered[-1])),
		"mean": rounded(mean(ordered))
	}


func empty_metric_bucket() -> Dictionary:
	return {
		"trials": 0,
		"soldCount": 0,
		"noSaleCount": 0,
		"noBidCount": 0,
		"reserveMissCount": 0,
		"hammer": [],
		"hammerToAppraisal": [],
		"soldHammerToAppraisal": [],
		"noSaleHammerToAppraisal": [],
		"offeredParticipants": [],
		"activeParticipants": [],
		"bidCount": [],
		"dropoutCount": [],
		"dropoutReasons": {"BUDGET": 0, "VALUE": 0, "AFTER_FIRST_BID": 0, "OTHER": 0},
		"reservePressureFactor": [],
		"meanMaxBidToAppraisal": [],
		"publicReasonCodes": {},
		"budgetAvailability": empty_availability_bucket()
	}


func empty_availability_bucket() -> Dictionary:
	return {
		"observations": 0,
		"budgetCapableCount": [],
		"baseEligibleBidderCount": [],
		"exclusiveClassCounts": {
			"IMPOSSIBLE": 0,
			"THIN": 0,
			"FEASIBLE": 0,
			"NORMAL_AVAILABILITY": 0
		},
		"feasibleInclusiveCount": 0,
		"normalAvailabilityCount": 0
	}


func add_availability_to_bucket(bucket: Dictionary, availability: Dictionary) -> void:
	bucket.observations = int(bucket.observations) + 1
	bucket.budgetCapableCount.append(int(availability.get("budgetCapableCount", 0)))
	bucket.baseEligibleBidderCount.append(int(availability.get("baseEligibleBidderCount", 0)))
	var exclusive_counts: Dictionary = bucket.exclusiveClassCounts
	var class_id := String(availability.get("exclusiveClass", "IMPOSSIBLE"))
	exclusive_counts[class_id] = int(exclusive_counts.get(class_id, 0)) + 1
	bucket.exclusiveClassCounts = exclusive_counts
	if bool(availability.get("feasible", false)):
		bucket.feasibleInclusiveCount = int(bucket.feasibleInclusiveCount) + 1
	if bool(availability.get("normalAvailability", false)):
		bucket.normalAvailabilityCount = int(bucket.normalAvailabilityCount) + 1


func finalize_availability_bucket(bucket: Dictionary) -> Dictionary:
	var observations_count := int(bucket.get("observations", 0))
	var exclusive_counts: Dictionary = bucket.get("exclusiveClassCounts", {})
	var exclusive_shares := {}
	for class_id: String in ["IMPOSSIBLE", "THIN", "FEASIBLE", "NORMAL_AVAILABILITY"]:
		exclusive_shares[class_id] = rounded(ratio(float(exclusive_counts.get(class_id, 0)), float(observations_count)))
	var feasible_count := int(bucket.get("feasibleInclusiveCount", 0))
	var normal_count := int(bucket.get("normalAvailabilityCount", 0))
	return {
		"observations": observations_count,
		"budgetCapableCount": numeric_distribution(bucket.get("budgetCapableCount", [])),
		"baseEligibleBidderCount": numeric_distribution(bucket.get("baseEligibleBidderCount", [])),
		"exclusiveClassCounts": exclusive_counts.duplicate(true),
		"exclusiveClassShares": exclusive_shares,
		"requestedInclusiveCounts": {
			"IMPOSSIBLE": int(exclusive_counts.get("IMPOSSIBLE", 0)),
			"THIN": int(exclusive_counts.get("THIN", 0)),
			"FEASIBLE": feasible_count,
			"NORMAL_AVAILABILITY": normal_count
		},
		"requestedInclusiveShares": {
			"IMPOSSIBLE": rounded(ratio(float(exclusive_counts.get("IMPOSSIBLE", 0)), float(observations_count))),
			"THIN": rounded(ratio(float(exclusive_counts.get("THIN", 0)), float(observations_count))),
			"FEASIBLE": rounded(ratio(float(feasible_count), float(observations_count))),
			"NORMAL_AVAILABILITY": rounded(ratio(float(normal_count), float(observations_count)))
		}
	}


func add_trial_to_bucket(bucket: Dictionary, trial: Dictionary) -> void:
	bucket.trials = int(bucket.trials) + 1
	if bool(trial.sold):
		bucket.soldCount = int(bucket.soldCount) + 1
		bucket.soldHammerToAppraisal.append(float(trial.hammerToAppraisal))
	else:
		bucket.noSaleCount = int(bucket.noSaleCount) + 1
		bucket.noSaleHammerToAppraisal.append(float(trial.hammerToAppraisal))
		if int(trial.hammer) <= 0:
			bucket.noBidCount = int(bucket.noBidCount) + 1
		else:
			bucket.reserveMissCount = int(bucket.reserveMissCount) + 1
	bucket.hammer.append(int(trial.hammer))
	bucket.hammerToAppraisal.append(float(trial.hammerToAppraisal))
	bucket.offeredParticipants.append(int(trial.offeredParticipants))
	bucket.activeParticipants.append(int(trial.activeParticipants))
	bucket.bidCount.append(int(trial.bidCount))
	bucket.dropoutCount.append(int(trial.dropoutCount))
	bucket.reservePressureFactor.append(float(trial.reservePressureFactor))
	bucket.meanMaxBidToAppraisal.append(float(trial.meanMaxBidToAppraisal))
	var reason_counts: Dictionary = bucket.dropoutReasons
	for reason_id: String in ["BUDGET", "VALUE", "AFTER_FIRST_BID", "OTHER"]:
		reason_counts[reason_id] = int(reason_counts.get(reason_id, 0)) + int(trial.dropoutReasons.get(reason_id, 0))
	bucket.dropoutReasons = reason_counts
	var public_codes: Dictionary = bucket.publicReasonCodes
	for code_value: Variant in trial.publicReasonCodes:
		var code := String(code_value)
		public_codes[code] = int(public_codes.get(code, 0)) + 1
	bucket.publicReasonCodes = public_codes
	add_availability_to_bucket(bucket.budgetAvailability, trial.budgetAvailability)


func finalize_metric_bucket(bucket: Dictionary) -> Dictionary:
	var trials := int(bucket.get("trials", 0))
	var sold_count := int(bucket.get("soldCount", 0))
	var no_sale_count := int(bucket.get("noSaleCount", 0))
	var dropout_reasons: Dictionary = bucket.get("dropoutReasons", {})
	var dropout_total := 0
	for reason_id: String in ["BUDGET", "VALUE", "AFTER_FIRST_BID", "OTHER"]:
		dropout_total += int(dropout_reasons.get(reason_id, 0))
	var dropout_shares := {}
	var dropout_per_trial := {}
	for reason_id: String in ["BUDGET", "VALUE", "AFTER_FIRST_BID", "OTHER"]:
		dropout_shares[reason_id] = rounded(ratio(float(dropout_reasons.get(reason_id, 0)), float(dropout_total)))
		dropout_per_trial[reason_id] = rounded(ratio(float(dropout_reasons.get(reason_id, 0)), float(trials)))
	return {
		"trials": trials,
		"soldCount": sold_count,
		"noSaleCount": no_sale_count,
		"soldRate": rounded(ratio(float(sold_count), float(trials))),
		"noSaleRate": rounded(ratio(float(no_sale_count), float(trials))),
		"noSaleTypes": {
			"NO_BID": int(bucket.get("noBidCount", 0)),
			"RESERVE_MISS": int(bucket.get("reserveMissCount", 0))
		},
		"hammer": numeric_distribution(bucket.get("hammer", [])),
		"hammerToAppraisal": numeric_distribution(bucket.get("hammerToAppraisal", [])),
		"soldHammerToAppraisal": numeric_distribution(bucket.get("soldHammerToAppraisal", [])),
		"noSaleHammerToAppraisal": numeric_distribution(bucket.get("noSaleHammerToAppraisal", [])),
		"participants": {
			"offered": numeric_distribution(bucket.get("offeredParticipants", [])),
			"active": numeric_distribution(bucket.get("activeParticipants", [])),
			"bidCount": numeric_distribution(bucket.get("bidCount", []))
		},
		"dropouts": {
			"total": dropout_total,
			"countPerTrial": numeric_distribution(bucket.get("dropoutCount", [])),
			"reasonCounts": dropout_reasons.duplicate(true),
			"reasonShares": dropout_shares,
			"reasonCountPerTrial": dropout_per_trial
		},
		"reservePressureFactor": numeric_distribution(bucket.get("reservePressureFactor", [])),
		"meanMaxBidToAppraisal": numeric_distribution(bucket.get("meanMaxBidToAppraisal", [])),
		"publicReasonCodeCounts": bucket.get("publicReasonCodes", {}).duplicate(true),
		"budgetAvailability": finalize_availability_bucket(bucket.get("budgetAvailability", empty_availability_bucket()))
	}


func artifact_seed(spec_id: String) -> int:
	return ARTIFACT_SEED_BASE + int(spec_id.trim_prefix("artifact_"))


func master_seed_for(sample_index: int) -> int:
	return MASTER_SEED_BASE + sample_index * MASTER_SEED_STRIDE


func unique_id_for(spec_id: String) -> String:
	return "stage_sensitivity_%s" % spec_id


func controlled_fixture(gs: Node, artifact_row: Dictionary, support_id: String) -> Dictionary:
	var spec_id := String(artifact_row.specId)
	var source: Dictionary = SUPPORT_FIXTURES[support_id]
	var artifact: Dictionary = gs.new_artifact(spec_id, artifact_seed(spec_id), unique_id_for(spec_id))
	if artifact.is_empty():
		return {}
	var condition := float(source.condition)
	artifact.playerHypothesis = gs.truth_to_hypothesis(String(artifact.get("authenticityTruth", "UNKNOWN")))
	artifact.confidence = float(source.confidence)
	artifact.cleanliness = condition
	artifact.surfaceCondition = condition
	artifact.structuralCondition = condition
	artifact.mechanicalCondition = condition
	artifact.historicalIntegrity = condition
	artifact.restorationQuality = condition
	artifact.knownClues = ["PROVENANCE"] if bool(source.provenanceKnown) else []
	artifact.inspected = true
	artifact.caseId = ""
	artifact.caseResolved = false
	artifact.listing = {
		"starting": 0,
		"reserve": 0,
		"confidence": float(source.confidence),
		"disclosure": String(source.disclosure),
		"publicAppraisal": 0
	}
	return artifact


func bidder_ids(bidder_rows: Array) -> Array:
	var ids: Array = []
	for bidder_value: Variant in bidder_rows:
		if bidder_value is Dictionary:
			ids.append(String(bidder_value.get("id", "")))
	return ids


func pre_scrutiny_budget_availability(gs: Node, artifact: Dictionary, bidder_rows: Array, reserve: int) -> Dictionary:
	# Reuse the exact production willingness formula while neutralizing only the
	# stage-amplified public scrutiny channels. An artificially uncapped bidder
	# exposes base willingness; the authored budget is then tested separately.
	# Reserve pressure is applied after bidder_maximum in production and is not
	# part of this pre-scrutiny eligibility count.
	var neutral_artifact: Dictionary = artifact.duplicate(true)
	var neutral_profile: Dictionary = neutral_artifact.get("auctionProfile", {}).duplicate(true)
	neutral_profile.conditionSensitivity = 0.0
	neutral_profile.disclosureScrutiny = 0.0
	neutral_profile.provenanceScrutiny = 0.0
	neutral_artifact.auctionProfile = neutral_profile
	var variances: Array = gs.auction_bidder_variances(neutral_artifact, bidder_rows)
	var base_eligible_count := 0
	var budget_capable_count := 0
	var bidder_rows_report: Array = []
	for bidder_index in range(bidder_rows.size()):
		var authored_bidder: Dictionary = bidder_rows[bidder_index]
		var uncapped_bidder: Dictionary = authored_bidder.duplicate(true)
		uncapped_bidder.budget = 2000000000
		var variance := float(variances[bidder_index].get("variance", 1.0))
		var base_willingness := int(gs.bidder_maximum(neutral_artifact, uncapped_bidder, int(gs.appraise(neutral_artifact)), variance))
		var base_eligible := base_willingness >= reserve
		var authored_budget_capable := int(authored_bidder.get("budget", 0)) >= reserve
		if base_eligible:
			base_eligible_count += 1
			if authored_budget_capable:
				budget_capable_count += 1
		bidder_rows_report.append({
			"bidderId": String(authored_bidder.get("id", "")),
			"baseWillingness": base_willingness,
			"authoredBudget": int(authored_bidder.get("budget", 0)),
			"baseEligible": base_eligible,
			"authoredBudgetCapable": base_eligible and authored_budget_capable
		})
	var feasible := budget_capable_count >= 2
	var normal_availability := feasible and base_eligible_count >= 3
	var exclusive_class := "IMPOSSIBLE"
	if budget_capable_count == 1:
		exclusive_class = "THIN"
	elif normal_availability:
		exclusive_class = "NORMAL_AVAILABILITY"
	elif feasible:
		exclusive_class = "FEASIBLE"
	return {
		"reserve": reserve,
		"baseEligibleBidderCount": base_eligible_count,
		"budgetCapableCount": budget_capable_count,
		"feasible": feasible,
		"normalAvailability": normal_availability,
		"exclusiveClass": exclusive_class,
		"bidderAudit": bidder_rows_report
	}


func canonical_equal(gs: Node, left: Variant, right: Variant) -> bool:
	return bool(gs.canonical_json_values_equal(left, right))


func validate_paired_control(gs: Node, spec_id: String, support_id: String, sample_index: int, appraisal: int, bidders: Array, variances: Array) -> void:
	var cross_band_key := "%s|%02d" % [spec_id, sample_index]
	var band_key := "%s|%s|%02d" % [spec_id, support_id, sample_index]
	var ids := bidder_ids(bidders)
	if not expected_controls.has(cross_band_key):
		expected_controls[cross_band_key] = {"bidderIds": ids.duplicate(), "variances": variances.duplicate(true)}
	else:
		var cross_expected: Dictionary = expected_controls[cross_band_key]
		if not canonical_equal(gs, cross_expected.get("bidderIds", []), ids) or not canonical_equal(gs, cross_expected.get("variances", []), variances):
			control_failures.append({"type": "CROSS_STAGE_OR_SUPPORT_BIDDER_CONTROL", "key": cross_band_key})
	if not expected_controls.has(band_key):
		expected_controls[band_key] = {"appraisal": appraisal}
	elif int(expected_controls[band_key].get("appraisal", -1)) != appraisal:
		control_failures.append({"type": "CROSS_STAGE_APPRAISAL_CONTROL", "key": band_key, "expected": expected_controls[band_key].get("appraisal", -1), "actual": appraisal})


func dropout_reason_counts(result: Dictionary) -> Dictionary:
	var counts := {"BUDGET": 0, "VALUE": 0, "AFTER_FIRST_BID": 0, "OTHER": 0}
	for dropout_value: Variant in result.get("dropouts", []):
		if not dropout_value is Dictionary:
			continue
		var reason := String(dropout_value.get("reason", "OTHER"))
		if not counts.has(reason):
			reason = "OTHER"
		counts[reason] = int(counts[reason]) + 1
	return counts


func public_reason_codes(result: Dictionary) -> Array:
	var codes: Array = []
	for reason_value: Variant in result.get("reasonTags", []):
		if reason_value is Dictionary:
			codes.append(String(reason_value.get("code", "")))
	return codes


func summarize_trial(gs: Node, artifact: Dictionary, result: Dictionary, appraisal: int, bidder_rows: Array) -> Dictionary:
	var participants_value: Variant = result.get("participants", [])
	var participants: Array = participants_value if participants_value is Array else []
	var active_count := 0
	var max_bid_ratio_total := 0.0
	for participant_value: Variant in participants:
		if not participant_value is Dictionary:
			continue
		if int(participant_value.get("bidCount", 0)) > 0:
			active_count += 1
		max_bid_ratio_total += ratio(float(participant_value.get("maxBid", 0)), float(appraisal))
	var bids_value: Variant = result.get("bids", [])
	var bids: Array = bids_value if bids_value is Array else []
	var dropouts_value: Variant = result.get("dropouts", [])
	var dropouts: Array = dropouts_value if dropouts_value is Array else []
	var hammer := int(result.get("hammer", 0))
	var availability := pre_scrutiny_budget_availability(gs, artifact, bidder_rows, int(artifact.get("listing", {}).get("reserve", 0)))
	return {
		"sold": bool(result.get("reserve_met", false)) and String(result.get("sale_status", "")) == "SOLD",
		"hammer": hammer,
		"hammerToAppraisal": ratio(float(hammer), float(appraisal)),
		"offeredParticipants": participants.size(),
		"activeParticipants": active_count,
		"bidCount": bids.size(),
		"dropoutCount": dropouts.size(),
		"dropoutReasons": dropout_reason_counts(result),
		"reservePressureFactor": float(result.get("reservePressureFactor", 1.0)),
		"meanMaxBidToAppraisal": ratio(max_bid_ratio_total, float(participants.size())),
		"publicReasonCodes": public_reason_codes(result),
		"bidderIds": bidder_ids(bidder_rows),
		"budgetAvailability": availability
	}


func cell_key(stage_id: int, spec_id: String, support_id: String, strategy_id: String) -> String:
	return "%02d|%s|%s|%s" % [stage_id, spec_id, support_id, strategy_id]


func observation_key(spec_id: String, support_id: String, strategy_id: String, sample_index: int) -> String:
	return "%s|%s|%s|%02d" % [spec_id, support_id, strategy_id, sample_index]


func register_trial(stage_id: int, artifact_row: Dictionary, support_id: String, strategy_id: String, sample_index: int, trial: Dictionary) -> void:
	var key := cell_key(stage_id, String(artifact_row.specId), support_id, strategy_id)
	if not cell_buckets.has(key):
		cell_buckets[key] = empty_metric_bucket()
	add_trial_to_bucket(cell_buckets[key], trial)
	var stage_key := str(stage_id)
	if not stage_buckets.has(stage_key):
		stage_buckets[stage_key] = empty_metric_bucket()
	add_trial_to_bucket(stage_buckets[stage_key], trial)
	if bool(trial.get("budgetAvailability", {}).get("normalAvailability", false)):
		if not normal_stage_buckets.has(stage_key):
			normal_stage_buckets[stage_key] = empty_metric_bucket()
		add_trial_to_bucket(normal_stage_buckets[stage_key], trial)
		var normal_preset_key := "%s|%s" % [stage_key, strategy_id]
		if not normal_stage_preset_buckets.has(normal_preset_key):
			normal_stage_preset_buckets[normal_preset_key] = empty_metric_bucket()
		add_trial_to_bucket(normal_stage_preset_buckets[normal_preset_key], trial)
		var normal_support_key := "%s|%s" % [stage_key, support_id]
		if not normal_stage_support_buckets.has(normal_support_key):
			normal_stage_support_buckets[normal_support_key] = empty_metric_bucket()
		add_trial_to_bucket(normal_stage_support_buckets[normal_support_key], trial)
	# Availability is stage-invariant by definition. Count Stage 1 only so the
	# preset shares describe 2,592 unique counterfactual observations, not three
	# repeated copies of the same roster/reserve classification.
	if stage_id == 1:
		if not availability_preset_buckets.has(strategy_id):
			availability_preset_buckets[strategy_id] = empty_availability_bucket()
		add_availability_to_bucket(availability_preset_buckets[strategy_id], trial.budgetAvailability)
	var obs_key := observation_key(String(artifact_row.specId), support_id, strategy_id, sample_index)
	if not observations.has(obs_key):
		observations[obs_key] = {}
	observations[obs_key][stage_key] = trial.duplicate(true)


func new_pair_bucket() -> Dictionary:
	return {
		"observations": 0,
		"transitions": {"SOLD_TO_SOLD": 0, "SOLD_TO_NO_SALE": 0, "NO_SALE_TO_SOLD": 0, "NO_SALE_TO_NO_SALE": 0},
		"outcomeChanged": 0,
		"hammerChanged": 0,
		"activeParticipantsChanged": 0,
		"dropoutVectorChanged": 0,
		"anyAuctionDecisionChanged": 0,
		"hammerToAppraisalDelta": [],
		"offeredParticipantDelta": [],
		"activeParticipantDelta": [],
		"bidCountDelta": [],
		"dropoutReasonDelta": {"BUDGET": [], "VALUE": [], "AFTER_FIRST_BID": [], "OTHER": []},
		"bidderRosterMismatch": 0,
		"budgetAvailabilityMismatch": 0
	}


func add_pair_observation(bucket: Dictionary, earlier: Dictionary, later: Dictionary) -> void:
	bucket.observations = int(bucket.observations) + 1
	var earlier_sold := bool(earlier.sold)
	var later_sold := bool(later.sold)
	var transition := ("SOLD" if earlier_sold else "NO_SALE") + "_TO_" + ("SOLD" if later_sold else "NO_SALE")
	var transitions: Dictionary = bucket.transitions
	transitions[transition] = int(transitions.get(transition, 0)) + 1
	bucket.transitions = transitions
	if earlier_sold != later_sold:
		bucket.outcomeChanged = int(bucket.outcomeChanged) + 1
	var hammer_delta := float(later.hammerToAppraisal) - float(earlier.hammerToAppraisal)
	var offered_delta := int(later.offeredParticipants) - int(earlier.offeredParticipants)
	var active_delta := int(later.activeParticipants) - int(earlier.activeParticipants)
	var bid_delta := int(later.bidCount) - int(earlier.bidCount)
	bucket.hammerToAppraisalDelta.append(hammer_delta)
	bucket.offeredParticipantDelta.append(offered_delta)
	bucket.activeParticipantDelta.append(active_delta)
	bucket.bidCountDelta.append(bid_delta)
	if absf(hammer_delta) > 0.0000001:
		bucket.hammerChanged = int(bucket.hammerChanged) + 1
	if active_delta != 0:
		bucket.activeParticipantsChanged = int(bucket.activeParticipantsChanged) + 1
	if not canonical_arrays_equal(earlier.bidderIds, later.bidderIds):
		bucket.bidderRosterMismatch = int(bucket.bidderRosterMismatch) + 1
	var earlier_availability: Dictionary = earlier.get("budgetAvailability", {})
	var later_availability: Dictionary = later.get("budgetAvailability", {})
	if int(earlier_availability.get("budgetCapableCount", -1)) != int(later_availability.get("budgetCapableCount", -1)) \
		or int(earlier_availability.get("baseEligibleBidderCount", -1)) != int(later_availability.get("baseEligibleBidderCount", -1)) \
		or String(earlier_availability.get("exclusiveClass", "")) != String(later_availability.get("exclusiveClass", "")):
		bucket.budgetAvailabilityMismatch = int(bucket.budgetAvailabilityMismatch) + 1
	var dropout_changed := false
	var dropout_delta: Dictionary = bucket.dropoutReasonDelta
	for reason_id: String in ["BUDGET", "VALUE", "AFTER_FIRST_BID", "OTHER"]:
		var reason_delta := int(later.dropoutReasons.get(reason_id, 0)) - int(earlier.dropoutReasons.get(reason_id, 0))
		dropout_delta[reason_id].append(reason_delta)
		if reason_delta != 0:
			dropout_changed = true
	bucket.dropoutReasonDelta = dropout_delta
	if dropout_changed:
		bucket.dropoutVectorChanged = int(bucket.dropoutVectorChanged) + 1
	if earlier_sold != later_sold or absf(hammer_delta) > 0.0000001 or active_delta != 0 or dropout_changed:
		bucket.anyAuctionDecisionChanged = int(bucket.anyAuctionDecisionChanged) + 1


func canonical_arrays_equal(left: Variant, right: Variant) -> bool:
	return left is Array and right is Array and left == right


func finalize_pair_bucket(bucket: Dictionary) -> Dictionary:
	var count := int(bucket.observations)
	var transitions: Dictionary = bucket.transitions
	var hammer_delta := numeric_distribution(bucket.hammerToAppraisalDelta)
	var active_delta := numeric_distribution(bucket.activeParticipantDelta)
	var offered_delta := numeric_distribution(bucket.offeredParticipantDelta)
	var bid_delta := numeric_distribution(bucket.bidCountDelta)
	var reason_delta := {}
	for reason_id: String in ["BUDGET", "VALUE", "AFTER_FIRST_BID", "OTHER"]:
		reason_delta[reason_id] = numeric_distribution(bucket.dropoutReasonDelta[reason_id])
	var outcome_changed := int(bucket.outcomeChanged)
	var hammer_changed := int(bucket.hammerChanged)
	var active_changed := int(bucket.activeParticipantsChanged)
	var dropout_changed := int(bucket.dropoutVectorChanged)
	var any_changed := int(bucket.anyAuctionDecisionChanged)
	return {
		"observations": count,
		"outcomeTransitions": transitions.duplicate(true),
		"outcomeTransitionRate": rounded(ratio(float(outcome_changed), float(count))),
		"soldToNoSaleRate": rounded(ratio(float(transitions.get("SOLD_TO_NO_SALE", 0)), float(count))),
		"noSaleToSoldRate": rounded(ratio(float(transitions.get("NO_SALE_TO_SOLD", 0)), float(count))),
		"hammerToAppraisalDelta": hammer_delta,
		"hammerChangedRate": rounded(ratio(float(hammer_changed), float(count))),
		"participants": {
			"offeredDelta": offered_delta,
			"activeDelta": active_delta,
			"bidCountDelta": bid_delta,
			"activeChangedRate": rounded(ratio(float(active_changed), float(count))),
			"bidderRosterMismatchCount": int(bucket.bidderRosterMismatch)
		},
		"budgetAvailabilityMismatchCount": int(bucket.budgetAvailabilityMismatch),
		"dropoutReasonDelta": reason_delta,
		"dropoutVectorChangedRate": rounded(ratio(float(dropout_changed), float(count))),
		"anyAuctionDecisionChangedRate": rounded(ratio(float(any_changed), float(count))),
		"direction": {
			"outcomeHasNoFavorableReversal": int(transitions.get("NO_SALE_TO_SOLD", 0)) == 0,
			"meanHammerNonIncreasing": float(hammer_delta.mean) <= 0.000001,
			"meanActiveParticipantsNonIncreasing": float(active_delta.mean) <= 0.000001,
			"meanValueDropoutsNonDecreasing": float(reason_delta.VALUE.mean) >= -0.000001,
			"offeredRosterInvariant": int(bucket.bidderRosterMismatch) == 0 and absf(float(offered_delta.min)) <= 0.000001 and absf(float(offered_delta.max)) <= 0.000001,
			"budgetAvailabilityInvariant": int(bucket.budgetAvailabilityMismatch) == 0
		},
		"materialAdverseEffect": int(transitions.get("SOLD_TO_NO_SALE", 0)) > 0 \
			or float(hammer_delta.mean) <= -0.01 \
			or float(active_delta.mean) <= -0.10 \
			or float(reason_delta.VALUE.mean) >= 0.10
	}


func subgroup_keys(spec_id: String, era_band: String, support_id: String, strategy_id: String) -> Dictionary:
	return {
		"overall": "ALL",
		"byArtifact": spec_id,
		"byEraBand": era_band,
		"bySupport": support_id,
		"byStrategy": strategy_id,
		"byCell": "%s|%s|%s" % [spec_id, support_id, strategy_id]
	}


func paired_comparison_reports(normal_only: bool = false) -> Dictionary:
	var pair_reports := {}
	for pair_id: String in PAIR_IDS:
		var stage_pair: Array = PAIR_STAGES[pair_id]
		var early_key := str(int(stage_pair[0]))
		var late_key := str(int(stage_pair[1]))
		var buckets := {
			"overall": {"ALL": new_pair_bucket()},
			"byArtifact": {},
			"byEraBand": {},
			"bySupport": {},
			"byStrategy": {},
			"byCell": {}
		}
		for artifact_row_value: Variant in ARTIFACT_ROWS:
			var artifact_row: Dictionary = artifact_row_value
			var spec_id := String(artifact_row.specId)
			var era_band := String(artifact_row.eraBand)
			for support_id: String in SUPPORT_ORDER:
				for strategy_id: String in STRATEGY_ORDER:
					for sample_index in range(PAIRED_SEED_COUNT):
						var obs_key := observation_key(spec_id, support_id, strategy_id, sample_index)
						var stage_values: Dictionary = observations.get(obs_key, {})
						if not stage_values.has(early_key) or not stage_values.has(late_key):
							execution_errors.append("MISSING_PAIRED_OBSERVATION:%s:%s" % [pair_id, obs_key])
							continue
						if normal_only:
							var early_availability: Dictionary = stage_values[early_key].get("budgetAvailability", {})
							var late_availability: Dictionary = stage_values[late_key].get("budgetAvailability", {})
							if not bool(early_availability.get("normalAvailability", false)) or not bool(late_availability.get("normalAvailability", false)):
								continue
						var groups := subgroup_keys(spec_id, era_band, support_id, strategy_id)
						for group_id: String in groups.keys():
							var member_id := String(groups[group_id])
							if not buckets[group_id].has(member_id):
								buckets[group_id][member_id] = new_pair_bucket()
							add_pair_observation(buckets[group_id][member_id], stage_values[early_key], stage_values[late_key])
		var finalized_groups := {}
		for group_id: String in buckets.keys():
			var finalized_members := {}
			for member_id: String in buckets[group_id].keys():
				finalized_members[member_id] = finalize_pair_bucket(buckets[group_id][member_id])
			finalized_groups[group_id] = finalized_members
		pair_reports[pair_id] = {
			"earlierStage": int(stage_pair[0]),
			"laterStage": int(stage_pair[1]),
			"normalAvailabilityOnly": normal_only,
			"metrics": finalized_groups
		}
	return pair_reports


func finalized_cell_metrics(registry: Node) -> Array:
	var rows: Array = []
	for stage_id: int in AUDITED_STAGES:
		for artifact_row_value: Variant in ARTIFACT_ROWS:
			var artifact_row: Dictionary = artifact_row_value
			var spec_id := String(artifact_row.specId)
			var spec: Dictionary = registry.get_spec(spec_id)
			for support_id: String in SUPPORT_ORDER:
				var support: Dictionary = SUPPORT_FIXTURES[support_id]
				for strategy_id: String in STRATEGY_ORDER:
					var key := cell_key(stage_id, spec_id, support_id, strategy_id)
					rows.append({
						"stage": stage_id,
						"difficultyMultiplier": rounded(float(registry.stage_difficulty_multiplier(stage_id))),
						"artifactSpecId": spec_id,
						"artifactName": String(spec.get("displayName", "")),
						"eraBand": String(artifact_row.eraBand),
						"introducedStage": int(artifact_row.introducedStage),
						"support": support_id,
						"publicFixture": {
							"condition": float(support.condition),
							"reportedConfidence": float(support.confidence),
							"provenanceKnown": bool(support.provenanceKnown),
							"calibratedDisclosure": String(support.disclosure)
						},
						"strategy": strategy_id,
						"priceRatios": STRATEGIES[strategy_id].duplicate(true),
						"metrics": finalize_metric_bucket(cell_buckets.get(key, empty_metric_bucket()))
					})
	return rows


func find_cell(cells: Array, stage_id: int, spec_id: String, support_id: String, strategy_id: String) -> Dictionary:
	for cell_value: Variant in cells:
		if not cell_value is Dictionary:
			continue
		if int(cell_value.get("stage", 0)) == stage_id \
			and String(cell_value.get("artifactSpecId", "")) == spec_id \
			and String(cell_value.get("support", "")) == support_id \
			and String(cell_value.get("strategy", "")) == strategy_id:
			return cell_value
	return {}


func monotonicity_rows(cells: Array, pair_reports: Dictionary) -> Array:
	var rows: Array = []
	for artifact_row_value: Variant in ARTIFACT_ROWS:
		var artifact_row: Dictionary = artifact_row_value
		var spec_id := String(artifact_row.specId)
		for support_id: String in SUPPORT_ORDER:
			for strategy_id: String in STRATEGY_ORDER:
				var stage_metrics := {}
				for stage_id: int in AUDITED_STAGES:
					var cell := find_cell(cells, stage_id, spec_id, support_id, strategy_id)
					stage_metrics[str(stage_id)] = cell.get("metrics", {})
				var sold_1 := float(stage_metrics["1"].get("soldRate", 0.0))
				var sold_5 := float(stage_metrics["5"].get("soldRate", 0.0))
				var sold_10 := float(stage_metrics["10"].get("soldRate", 0.0))
				var hammer_1 := float(stage_metrics["1"].get("hammerToAppraisal", {}).get("mean", 0.0))
				var hammer_5 := float(stage_metrics["5"].get("hammerToAppraisal", {}).get("mean", 0.0))
				var hammer_10 := float(stage_metrics["10"].get("hammerToAppraisal", {}).get("mean", 0.0))
				var active_1 := float(stage_metrics["1"].get("participants", {}).get("active", {}).get("mean", 0.0))
				var active_5 := float(stage_metrics["5"].get("participants", {}).get("active", {}).get("mean", 0.0))
				var active_10 := float(stage_metrics["10"].get("participants", {}).get("active", {}).get("mean", 0.0))
				var value_1 := float(stage_metrics["1"].get("dropouts", {}).get("reasonCountPerTrial", {}).get("VALUE", 0.0))
				var value_5 := float(stage_metrics["5"].get("dropouts", {}).get("reasonCountPerTrial", {}).get("VALUE", 0.0))
				var value_10 := float(stage_metrics["10"].get("dropouts", {}).get("reasonCountPerTrial", {}).get("VALUE", 0.0))
				var sold_monotonic := sold_1 + 0.000001 >= sold_5 and sold_5 + 0.000001 >= sold_10
				var hammer_monotonic := hammer_1 + 0.000001 >= hammer_5 and hammer_5 + 0.000001 >= hammer_10
				var active_monotonic := active_1 + 0.000001 >= active_5 and active_5 + 0.000001 >= active_10
				var value_monotonic := value_1 <= value_5 + 0.000001 and value_5 <= value_10 + 0.000001
				var pair_cell_id := "%s|%s|%s" % [spec_id, support_id, strategy_id]
				var pair_1_to_10: Dictionary = pair_reports.get("1_TO_10", {}).get("metrics", {}).get("byCell", {}).get(pair_cell_id, {})
				var material_adverse := sold_1 - sold_10 >= 0.02 \
					or hammer_10 - hammer_1 <= -0.01 \
					or active_10 - active_1 <= -0.10 \
					or value_10 - value_1 >= 0.10
				rows.append({
					"artifactSpecId": spec_id,
					"eraBand": String(artifact_row.eraBand),
					"support": support_id,
					"strategy": strategy_id,
					"stageValues": {
						"soldRate": {"stage1": rounded(sold_1), "stage5": rounded(sold_5), "stage10": rounded(sold_10)},
						"meanHammerToAppraisal": {"stage1": rounded(hammer_1), "stage5": rounded(hammer_5), "stage10": rounded(hammer_10)},
						"meanActiveParticipants": {"stage1": rounded(active_1), "stage5": rounded(active_5), "stage10": rounded(active_10)},
						"valueDropoutsPerTrial": {"stage1": rounded(value_1), "stage5": rounded(value_5), "stage10": rounded(value_10)}
					},
					"monotonic": {
						"soldRateNonIncreasing": sold_monotonic,
						"hammerNonIncreasing": hammer_monotonic,
						"activeParticipantsNonIncreasing": active_monotonic,
						"valueDropoutsNonDecreasing": value_monotonic,
						"allFour": sold_monotonic and hammer_monotonic and active_monotonic and value_monotonic
					},
					"materialAdverseStage1To10": material_adverse,
					"materialThresholds": {
						"soldRateDrop": 0.02,
						"meanHammerToAppraisalDrop": 0.01,
						"meanActiveParticipantDrop": 0.10,
						"meanValueDropoutIncrease": 0.10
					},
					"pairedStage1To10": {
						"observations": int(pair_1_to_10.get("observations", 0)),
						"outcomeTransitions": pair_1_to_10.get("outcomeTransitions", {}).duplicate(true),
						"outcomeTransitionRate": float(pair_1_to_10.get("outcomeTransitionRate", 0.0)),
						"anyAuctionDecisionChangedRate": float(pair_1_to_10.get("anyAuctionDecisionChangedRate", 0.0)),
						"meanHammerToAppraisalDelta": float(pair_1_to_10.get("hammerToAppraisalDelta", {}).get("mean", 0.0)),
						"meanActiveParticipantDelta": float(pair_1_to_10.get("participants", {}).get("activeDelta", {}).get("mean", 0.0)),
						"meanValueDropoutDelta": float(pair_1_to_10.get("dropoutReasonDelta", {}).get("VALUE", {}).get("mean", 0.0))
					}
				})
	return rows


func monotonicity_summary(rows: Array) -> Dictionary:
	var total := rows.size()
	var counts := {
		"soldRateNonIncreasing": 0,
		"hammerNonIncreasing": 0,
		"activeParticipantsNonIncreasing": 0,
		"valueDropoutsNonDecreasing": 0,
		"allFour": 0,
		"materialAdverseStage1To10": 0
	}
	var reversal_examples: Array = []
	for row_value: Variant in rows:
		var row: Dictionary = row_value
		var monotonic: Dictionary = row.monotonic
		for key: String in ["soldRateNonIncreasing", "hammerNonIncreasing", "activeParticipantsNonIncreasing", "valueDropoutsNonDecreasing", "allFour"]:
			if bool(monotonic.get(key, false)):
				counts[key] = int(counts[key]) + 1
		if bool(row.materialAdverseStage1To10):
			counts.materialAdverseStage1To10 = int(counts.materialAdverseStage1To10) + 1
		if not bool(monotonic.allFour) and reversal_examples.size() < 12:
			reversal_examples.append({
				"artifactSpecId": row.artifactSpecId,
				"support": row.support,
				"strategy": row.strategy,
				"failedDirections": ["soldRateNonIncreasing", "hammerNonIncreasing", "activeParticipantsNonIncreasing", "valueDropoutsNonDecreasing"].filter(func(key: String): return not bool(monotonic.get(key, false))),
				"stageValues": row.stageValues
			})
	var rates := {}
	for key: String in counts.keys():
		rates[key] = rounded(ratio(float(counts[key]), float(total)))
	return {
		"cellCount": total,
		"passingCellCounts": counts,
		"passingCellRates": rates,
		"reversalExamples": reversal_examples
	}


func outcome_masking_summary(rows: Array) -> Dictionary:
	var identical_sale_rate_cells := 0
	var identical_sale_rate_but_decision_changed := 0
	var zero_paired_decision_change_cells := 0
	var masked_examples: Array = []
	var insensitive_cells: Array = []
	for row_value: Variant in rows:
		var row: Dictionary = row_value
		var sold_values: Dictionary = row.get("stageValues", {}).get("soldRate", {})
		var sold_1 := float(sold_values.get("stage1", 0.0))
		var sold_5 := float(sold_values.get("stage5", 0.0))
		var sold_10 := float(sold_values.get("stage10", 0.0))
		var identical_sale_rate := is_equal_approx(sold_1, sold_5) and is_equal_approx(sold_5, sold_10)
		var pair: Dictionary = row.get("pairedStage1To10", {})
		var decision_change_rate := float(pair.get("anyAuctionDecisionChangedRate", 0.0))
		if identical_sale_rate:
			identical_sale_rate_cells += 1
			if decision_change_rate > 0.0:
				identical_sale_rate_but_decision_changed += 1
				if masked_examples.size() < 12:
					masked_examples.append({
						"artifactSpecId": row.artifactSpecId,
						"support": row.support,
						"strategy": row.strategy,
						"soldRate": sold_1,
						"pairedStage1To10": pair
					})
		if decision_change_rate == 0.0:
			zero_paired_decision_change_cells += 1
			insensitive_cells.append({
				"artifactSpecId": row.artifactSpecId,
				"support": row.support,
				"strategy": row.strategy,
				"soldRates": sold_values
			})
	return {
		"cellCount": rows.size(),
		"identicalSoldRateAcrossStagesCells": identical_sale_rate_cells,
		"identicalSoldRateButOtherDecisionChangedCells": identical_sale_rate_but_decision_changed,
		"zeroPairedStage1To10DecisionChangeCells": zero_paired_decision_change_cells,
		"sameSaleOutcomeCanMaskStageSensitivity": identical_sale_rate_but_decision_changed > 0,
		"maskedSensitivityExamples": masked_examples,
		"fullyInsensitiveCells": insensitive_cells
	}


func budget_stratification_report(cells: Array) -> Dictionary:
	var stage_one_cells: Array = []
	for cell_value: Variant in cells:
		if not cell_value is Dictionary or int(cell_value.get("stage", 0)) != 1:
			continue
		stage_one_cells.append({
			"artifactSpecId": String(cell_value.get("artifactSpecId", "")),
			"eraBand": String(cell_value.get("eraBand", "")),
			"support": String(cell_value.get("support", "")),
			"preset": String(cell_value.get("strategy", "")),
			"priceRatios": cell_value.get("priceRatios", {}).duplicate(true),
			"availability": cell_value.get("metrics", {}).get("budgetAvailability", {}).duplicate(true)
		})
	var overall_bucket := empty_availability_bucket()
	for observation_value: Variant in observations.values():
		if not observation_value is Dictionary or not observation_value.has("1"):
			continue
		var stage_one_trial: Dictionary = observation_value["1"]
		add_availability_to_bucket(overall_bucket, stage_one_trial.get("budgetAvailability", {}))
		for later_stage_key: String in ["5", "10"]:
			if not observation_value.has(later_stage_key):
				availability_invariance_failures.append({"type": "MISSING_STAGE", "stage": later_stage_key})
				continue
			var early: Dictionary = stage_one_trial.get("budgetAvailability", {})
			var later: Dictionary = observation_value[later_stage_key].get("budgetAvailability", {})
			if int(early.get("budgetCapableCount", -1)) != int(later.get("budgetCapableCount", -1)) \
				or int(early.get("baseEligibleBidderCount", -1)) != int(later.get("baseEligibleBidderCount", -1)) \
				or String(early.get("exclusiveClass", "")) != String(later.get("exclusiveClass", "")):
				availability_invariance_failures.append({
					"type": "STAGE_VARIANT_PRE_SCRUTINY_CLASS",
					"stage": later_stage_key,
					"early": {
						"budgetCapableCount": early.get("budgetCapableCount", -1),
						"baseEligibleBidderCount": early.get("baseEligibleBidderCount", -1),
						"exclusiveClass": early.get("exclusiveClass", "")
					},
					"later": {
						"budgetCapableCount": later.get("budgetCapableCount", -1),
						"baseEligibleBidderCount": later.get("baseEligibleBidderCount", -1),
						"exclusiveClass": later.get("exclusiveClass", "")
					}
				})
	var by_preset := {}
	for preset_id: String in STRATEGY_ORDER:
		by_preset[preset_id] = finalize_availability_bucket(availability_preset_buckets.get(preset_id, empty_availability_bucket()))
	return {
		"definition": {
			"baseEligibleBidderCount": "Count in the same selected production roster whose uncapped bidder_maximum reaches reserve after condition/disclosure/provenance stage scrutiny is neutralized; preferred-bidder fit and every other production willingness input remain active.",
			"budgetCapableCount": "Count among base-eligible bidders whose authored production budget is also greater than or equal to reserve.",
			"IMPOSSIBLE": "budgetCapableCount == 0",
			"THIN": "budgetCapableCount == 1",
			"FEASIBLE": "budgetCapableCount >= 2 (inclusive flag)",
			"NORMAL_AVAILABILITY": "FEASIBLE and baseEligibleBidderCount >= 3 (inclusive subset)",
			"exclusiveClasses": "IMPOSSIBLE, THIN, FEASIBLE (feasible but baseEligible < 3), NORMAL_AVAILABILITY; these four exclusive shares sum to 1.",
			"reservePressure": "Excluded because production applies it after bidder_maximum; this is deliberately a pre-stage-scrutiny availability stratum."
		},
		"stageInvariant": availability_invariance_failures.is_empty(),
		"invarianceFailures": availability_invariance_failures,
		"uniqueObservationBasis": "Stage 1 copy only; the identical Stage 5/10 classifications are control checks, not duplicate denominator entries.",
		"overall": finalize_availability_bucket(overall_bucket),
		"byPreset": by_preset,
		"byArtifactSupportPresetCell": stage_one_cells
	}


func normal_availability_slice_report(normal_pair_reports: Dictionary) -> Dictionary:
	var stage_summaries := {}
	var by_stage_preset := {}
	var by_stage_support := {}
	for stage_id: int in AUDITED_STAGES:
		var stage_key := str(stage_id)
		stage_summaries[stage_key] = finalize_metric_bucket(normal_stage_buckets.get(stage_key, empty_metric_bucket()))
		var preset_rows := {}
		for preset_id: String in STRATEGY_ORDER:
			preset_rows[preset_id] = finalize_metric_bucket(normal_stage_preset_buckets.get("%s|%s" % [stage_key, preset_id], empty_metric_bucket()))
		by_stage_preset[stage_key] = preset_rows
		var support_rows := {}
		for support_id: String in SUPPORT_ORDER:
			support_rows[support_id] = finalize_metric_bucket(normal_stage_support_buckets.get("%s|%s" % [stage_key, support_id], empty_metric_bucket()))
		by_stage_support[stage_key] = support_rows
	return {
		"definition": "Only paired observations classified NORMAL_AVAILABILITY before stage scrutiny: budgetCapableCount >= 2 and baseEligibleBidderCount >= 3.",
		"stageSummaries": stage_summaries,
		"byStagePreset": by_stage_preset,
		"byStageSupport": by_stage_support,
		"pairedComparisons": normal_pair_reports
	}


func normal_availability_acceptance(normal_slice: Dictionary, strict_controls: Dictionary) -> Dictionary:
	var stage_summaries: Dictionary = normal_slice.get("stageSummaries", {})
	var by_stage_preset: Dictionary = normal_slice.get("byStagePreset", {})
	var by_stage_support: Dictionary = normal_slice.get("byStageSupport", {})
	var paired: Dictionary = normal_slice.get("pairedComparisons", {})
	var stage_ten_presets: Dictionary = by_stage_preset.get("10", {})
	var stage_ten_preset_rates := {}
	var stage_ten_viable_presets := 0
	for preset_id: String in STRATEGY_ORDER:
		var preset_metrics: Dictionary = stage_ten_presets.get(preset_id, {})
		var preset_trials := int(preset_metrics.get("trials", 0))
		var sold_rate := float(preset_metrics.get("soldRate", 0.0))
		stage_ten_preset_rates[preset_id] = {"trials": preset_trials, "soldRate": sold_rate}
		if preset_trials > 0 and sold_rate >= 0.30:
			stage_ten_viable_presets += 1
	var stage_ten_overall: Dictionary = stage_summaries.get("10", {})
	var stage_ten_sold_rate := float(stage_ten_overall.get("soldRate", 0.0))
	var low_stage_one: Dictionary = by_stage_support.get("1", {}).get("LOW", {})
	var low_stage_ten: Dictionary = by_stage_support.get("10", {}).get("LOW", {})
	var low_sold_drop := float(low_stage_one.get("soldRate", 0.0)) - float(low_stage_ten.get("soldRate", 0.0))
	var high_stage_one: Dictionary = by_stage_support.get("1", {}).get("HIGH", {})
	var high_stage_ten: Dictionary = by_stage_support.get("10", {}).get("HIGH", {})
	var high_sold_drop := float(high_stage_one.get("soldRate", 0.0)) - float(high_stage_ten.get("soldRate", 0.0))
	var normal_pair_1_to_10: Dictionary = paired.get("1_TO_10", {}).get("metrics", {}).get("overall", {}).get("ALL", {})
	var favorable_transition_rate := float(normal_pair_1_to_10.get("noSaleToSoldRate", 1.0))
	var high_deterioration := maxf(0.0, high_sold_drop)
	var high_favorable_drift := maxf(0.0, -high_sold_drop)
	var aggregate_sold_rates := {
		"stage1": float(stage_summaries.get("1", {}).get("soldRate", 0.0)),
		"stage5": float(stage_summaries.get("5", {}).get("soldRate", 0.0)),
		"stage10": stage_ten_sold_rate
	}
	var aggregate_sold_monotonic := float(aggregate_sold_rates.stage1) + 0.000001 >= float(aggregate_sold_rates.stage5) \
		and float(aggregate_sold_rates.stage5) + 0.000001 >= float(aggregate_sold_rates.stage10)
	var invariants_passed := bool(strict_controls.get("pairedSeedInvariant", false)) \
		and bool(strict_controls.get("rngInvariant", false)) \
		and bool(strict_controls.get("budgetClassificationInvariant", false)) \
		and bool(strict_controls.get("determinismPassed", false)) \
		and int(strict_controls.get("preflightFatalDiagnosticCount", -1)) == 0
	var checks: Array = [
		{
			"id": "NORMAL-ACCEPT-01",
			"name": "LOW support Stage 1 to 10 SOLD deterioration is 15-30 percentage points",
			"passed": int(low_stage_one.get("trials", 0)) > 0 and int(low_stage_ten.get("trials", 0)) > 0 and low_sold_drop >= 0.15 and low_sold_drop <= 0.30,
			"evidence": {"stage1SoldRate": low_stage_one.get("soldRate", 0.0), "stage10SoldRate": low_stage_ten.get("soldRate", 0.0), "deterioration": rounded(low_sold_drop), "allowedRange": [0.15, 0.30]}
		},
		{
			"id": "NORMAL-ACCEPT-02",
			"name": "HIGH support deterioration is <= 2 percentage points and favorable sold-rate drift is <= 0.5 percentage points",
			"passed": int(high_stage_one.get("trials", 0)) > 0 and int(high_stage_ten.get("trials", 0)) > 0 \
				and high_deterioration <= 0.020001 and high_favorable_drift <= 0.005001,
			"evidence": {"stage1SoldRate": high_stage_one.get("soldRate", 0.0), "stage10SoldRate": high_stage_ten.get("soldRate", 0.0), "signedStage1MinusStage10": rounded(high_sold_drop), "deterioration": rounded(high_deterioration), "maximumDeterioration": 0.02, "favorableDrift": rounded(high_favorable_drift), "maximumFavorableDrift": 0.005}
		},
		{
			"id": "NORMAL-ACCEPT-03",
			"name": "Stage 10 overall SOLD is >= 40% and at least two presets are >= 30%",
			"passed": int(stage_ten_overall.get("trials", 0)) > 0 and stage_ten_sold_rate >= 0.40 and stage_ten_viable_presets >= 2,
			"evidence": {"trials": int(stage_ten_overall.get("trials", 0)), "overallSoldRate": rounded(stage_ten_sold_rate), "minimumOverall": 0.40, "qualifyingPresetCount": stage_ten_viable_presets, "requiredPresets": 2, "presetMinimum": 0.30, "presets": stage_ten_preset_rates}
		},
		{
			"id": "NORMAL-ACCEPT-04",
			"name": "NO_SALE to SOLD reversals are <= 0.5% and aggregate SOLD is Stage 1 >= Stage 5 >= Stage 10",
			"passed": int(normal_pair_1_to_10.get("observations", 0)) > 0 and favorable_transition_rate <= 0.005 and aggregate_sold_monotonic,
			"evidence": {"observations": int(normal_pair_1_to_10.get("observations", 0)), "noSaleToSoldRate": rounded(favorable_transition_rate), "maximumReversalRate": 0.005, "transitions": normal_pair_1_to_10.get("outcomeTransitions", {}).duplicate(true), "aggregateSoldRates": aggregate_sold_rates, "monotonic": aggregate_sold_monotonic}
		},
		{
			"id": "NORMAL-ACCEPT-05",
			"name": "Paired seed, RNG and budget classification are invariant with fatal diagnostics 0 and determinism PASS",
			"passed": invariants_passed,
			"evidence": strict_controls.duplicate(true)
		}
	]
	var passed_count := checks.filter(func(check_value: Variant): return check_value is Dictionary and bool(check_value.get("passed", false))).size()
	return {
		"acceptanceCount": checks.size(),
		"passed": passed_count,
		"failed": checks.size() - passed_count,
		"allPassed": passed_count == checks.size(),
		"tests": checks
	}


func run_trials(gs: Node, registry: Node) -> int:
	var global_rng_before := int(gs.rng.state)
	for stage_id: int in AUDITED_STAGES:
		gs.current_stage = stage_id
		gs.stage_run_state = gs.default_stage_run_state(stage_id)
		gs.stage_run_state.status = "RUNNING"
		gs.day = FIXED_DAY
		gs.market_state = gs.default_market_state()
		gs.daily_modifiers = {}
		gs.owned_upgrades = []
		for artifact_row_value: Variant in ARTIFACT_ROWS:
			var artifact_row: Dictionary = artifact_row_value
			var spec_id := String(artifact_row.specId)
			if registry.get_spec(spec_id).is_empty():
				execution_errors.append("MISSING_ARTIFACT_SPEC:%s" % spec_id)
				continue
			for support_id: String in SUPPORT_ORDER:
				var support: Dictionary = SUPPORT_FIXTURES[support_id]
				for sample_index in range(PAIRED_SEED_COUNT):
					gs.master_seed = master_seed_for(sample_index)
					var fixture := controlled_fixture(gs, artifact_row, support_id)
					if fixture.is_empty():
						execution_errors.append("FIXTURE_CREATION_FAILED:%d:%s:%s:%d" % [stage_id, spec_id, support_id, sample_index])
						continue
					var support_state: Dictionary = gs.listing_public_support(fixture, String(support.disclosure))
					if String(support_state.get("band", "")) != support_id or String(support_state.get("risk", "")) != "BALANCED":
						support_contract_failures.append({"stage": stage_id, "specId": spec_id, "support": support_id, "actual": support_state})
					var appraisal := int(gs.appraise(fixture))
					if appraisal <= 0:
						execution_errors.append("NON_POSITIVE_APPRAISAL:%d:%s:%s" % [stage_id, spec_id, support_id])
						continue
					var bidders: Array = gs.selected_bidders(fixture, false)
					var variances: Array = gs.auction_bidder_variances(fixture, bidders)
					validate_paired_control(gs, spec_id, support_id, sample_index, appraisal, bidders, variances)
					for strategy_id: String in STRATEGY_ORDER:
						var policy: Dictionary = STRATEGIES[strategy_id]
						var artifact: Dictionary = fixture.duplicate(true)
						artifact.listing = {
							"starting": int(float(appraisal) * float(policy.startingRatio)),
							"reserve": int(float(appraisal) * float(policy.reserveRatio)),
							"confidence": float(support.confidence),
							"disclosure": String(support.disclosure),
							"publicAppraisal": appraisal
						}
						var actual_variances: Array = gs.auction_bidder_variances(artifact, bidders)
						if not canonical_equal(gs, variances, actual_variances):
							control_failures.append({"type": "STRATEGY_VARIANCE_MISMATCH", "stage": stage_id, "specId": spec_id, "support": support_id, "strategy": strategy_id, "sample": sample_index})
						var result: Dictionary = gs.auction_with_bidders(artifact, bidders, false)
						if result.is_empty() or not String(result.get("sale_status", "")) in ["SOLD", "NO_SALE"]:
							execution_errors.append("INVALID_AUCTION_RESULT:%d:%s:%s:%s:%d" % [stage_id, spec_id, support_id, strategy_id, sample_index])
							continue
						if sample_index == 0:
							deterministic_checks += 1
							var repeated: Dictionary = gs.auction_with_bidders(artifact, bidders, false)
							if not canonical_equal(gs, result, repeated):
								deterministic_failures.append({"stage": stage_id, "specId": spec_id, "support": support_id, "strategy": strategy_id})
						var trial := summarize_trial(gs, artifact, result, appraisal, bidders)
						register_trial(stage_id, artifact_row, support_id, strategy_id, sample_index, trial)
						completed_trials += 1
	return global_rng_before


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.reset_game()
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	var rng_before := run_trials(gs, registry)
	var rng_after := int(gs.rng.state)
	var cells := finalized_cell_metrics(registry)
	var pair_reports := paired_comparison_reports(false)
	var normal_pair_reports := paired_comparison_reports(true)
	var monotonic_rows := monotonicity_rows(cells, pair_reports)
	var monotonic_summary := monotonicity_summary(monotonic_rows)
	var outcome_masking := outcome_masking_summary(monotonic_rows)
	var budget_stratification := budget_stratification_report(cells)
	var normal_slice := normal_availability_slice_report(normal_pair_reports)
	var expected_cells := AUDITED_STAGES.size() * ARTIFACT_ROWS.size() * SUPPORT_ORDER.size() * STRATEGY_ORDER.size()
	var expected_trials := expected_cells * PAIRED_SEED_COUNT
	var expected_observations := ARTIFACT_ROWS.size() * SUPPORT_ORDER.size() * STRATEGY_ORDER.size() * PAIRED_SEED_COUNT
	var exact_multipliers := is_equal_approx(float(registry.stage_difficulty_multiplier(1)), pow(1.07, 0)) \
		and is_equal_approx(float(registry.stage_difficulty_multiplier(5)), pow(1.07, 4)) \
		and is_equal_approx(float(registry.stage_difficulty_multiplier(10)), pow(1.07, 9))
	var every_cell_complete := cells.size() == expected_cells and cells.all(func(cell_value: Variant): return cell_value is Dictionary and int(cell_value.get("metrics", {}).get("trials", -1)) == PAIRED_SEED_COUNT)
	var each_pair_complete := true
	for pair_id: String in PAIR_IDS:
		var pair_count := int(pair_reports.get(pair_id, {}).get("metrics", {}).get("overall", {}).get("ALL", {}).get("observations", -1))
		each_pair_complete = each_pair_complete and pair_count == expected_observations
	var execution_checks := {
		"allExpectedTrialsCompleted": completed_trials == expected_trials,
		"allExpectedCellsComplete": every_cell_complete,
		"allPairedComparisonsComplete": each_pair_complete,
		"canonicalDifficultyMultipliers": exact_multipliers,
		"publicSupportFixturesCalibrated": support_contract_failures.is_empty(),
		"pairedBidderRosterAppraisalAndVarianceStable": control_failures.is_empty(),
		"preScrutinyBudgetClassificationStageInvariant": availability_invariance_failures.is_empty(),
		"sampledRepeatDeterminism": deterministic_failures.is_empty() and deterministic_checks == expected_cells,
		"globalRngUnchanged": rng_before == rng_after,
		"noExecutionErrors": execution_errors.is_empty()
	}
	var execution_passed: bool = execution_checks.values().all(func(value: Variant): return bool(value))
	var preflight_fatal_text := OS.get_environment("R3_AUCTION_AUDIT_PREFLIGHT_FATAL_COUNT")
	var preflight_fatal_count := int(preflight_fatal_text) if preflight_fatal_text.is_valid_int() else -1
	var strict_controls := {
		"pairedSeedInvariant": control_failures.is_empty() and each_pair_complete,
		"rngInvariant": rng_before == rng_after,
		"budgetClassificationInvariant": availability_invariance_failures.is_empty(),
		"determinismPassed": deterministic_failures.is_empty() and deterministic_checks == expected_cells,
		"determinismChecks": deterministic_checks,
		"expectedDeterminismChecks": expected_cells,
		"preflightFatalDiagnosticCount": preflight_fatal_count,
		"preflightFatalDiagnosticCountSource": "R3_AUCTION_AUDIT_PREFLIGHT_FATAL_COUNT supplied by the isolated outer headless runner; the final run is independently scanned again."
	}
	var normal_acceptance := normal_availability_acceptance(normal_slice, strict_controls)
	var monotonic_rates: Dictionary = monotonic_summary.passingCellRates
	var stage_1_to_10: Dictionary = pair_reports.get("1_TO_10", {}).get("metrics", {}).get("overall", {}).get("ALL", {})
	var high_support_1_to_10: Dictionary = pair_reports.get("1_TO_10", {}).get("metrics", {}).get("bySupport", {}).get("HIGH", {})
	var overall_direction: Dictionary = stage_1_to_10.get("direction", {})
	var global_monotonic := bool(overall_direction.get("outcomeHasNoFavorableReversal", false)) \
		and bool(overall_direction.get("meanHammerNonIncreasing", false)) \
		and bool(overall_direction.get("meanActiveParticipantsNonIncreasing", false)) \
		and bool(overall_direction.get("meanValueDropoutsNonDecreasing", false))
	var cell_monotonic_coverage := float(monotonic_rates.get("allFour", 0.0))
	var material_coverage := float(monotonic_rates.get("materialAdverseStage1To10", 0.0))
	var stage_sensitive_rate := float(stage_1_to_10.get("anyAuctionDecisionChangedRate", 0.0))
	var tuning_flags: Array = []
	if not global_monotonic:
		tuning_flags.append("AGGREGATE_STAGE_1_TO_10_DIRECTION_NOT_MONOTONIC")
	if cell_monotonic_coverage < 0.80:
		tuning_flags.append("MONOTONIC_CELL_COVERAGE_BELOW_80_PERCENT")
	if material_coverage < 0.50:
		tuning_flags.append("MATERIAL_ADVERSE_CELL_COVERAGE_BELOW_50_PERCENT")
	if stage_sensitive_rate < 0.10:
		tuning_flags.append("PAIRED_STAGE_1_TO_10_DECISION_CHANGE_RATE_BELOW_10_PERCENT")
	if float(high_support_1_to_10.get("anyAuctionDecisionChangedRate", 0.0)) < 0.10:
		tuning_flags.append("HIGH_SUPPORT_STAGE_1_TO_10_DECISION_CHANGE_RATE_BELOW_10_PERCENT")
	if float(high_support_1_to_10.get("hammerToAppraisalDelta", {}).get("mean", 0.0)) > 0.000001:
		tuning_flags.append("HIGH_SUPPORT_MEAN_HAMMER_MOVES_FAVORABLY_WITH_STAGE")
	var normal_acceptance_failures: Array = []
	for acceptance_value: Variant in normal_acceptance.get("tests", []):
		if acceptance_value is Dictionary and not bool(acceptance_value.get("passed", false)):
			normal_acceptance_failures.append(String(acceptance_value.get("id", "UNKNOWN")))
	var broad_direction_maintained := global_monotonic \
		and bool(stage_1_to_10.get("direction", {}).get("offeredRosterInvariant", false)) \
		and bool(stage_1_to_10.get("direction", {}).get("budgetAvailabilityInvariant", false))
	var verdict := "AUCTION_TUNING_FREEZE"
	if not execution_passed:
		verdict = "INCONCLUSIVE_EXECUTION_FAILURE"
	elif not bool(normal_acceptance.get("allPassed", false)) or not broad_direction_maintained:
		verdict = "NORMAL_AVAILABILITY_NEEDS_TUNING"
	var stage_summaries := {}
	for stage_id: int in AUDITED_STAGES:
		stage_summaries[str(stage_id)] = {
			"difficultyMultiplier": rounded(float(registry.stage_difficulty_multiplier(stage_id))),
			"metrics": finalize_metric_bucket(stage_buckets.get(str(stage_id), empty_metric_bucket()))
		}
	var caveats := [
		"This is a deterministic counterfactual audit, not a player-behavior forecast or live economy simulation.",
		"Later-stage ArtifactSpecs are intentionally replayed at Stage 1 as common controls; those cross-stage cells are not claims about normal unlock availability.",
		"LOW/MEDIUM/HIGH fixtures use only public confidence, visible condition, provenance-known state and the calibrated disclosure for that support band.",
		"Bidder budgets remain the authored production budgets. High-value artifacts can therefore expose budget ceilings that mask or dominate stage scrutiny.",
		"Budget strata are counterfactual diagnostics only. They do not modify bidder budgets, bidder selection, production eligibility or auction results.",
		"FEASIBLE is reported as the requested inclusive >=2 flag; NORMAL_AVAILABILITY is its baseEligible>=3 subset. A separate exclusive four-class view is also included so class shares sum to one.",
		"Offered participant count is expected to remain fixed because stage difficulty currently changes willingness, not bidder reach; active participants and dropout reasons measure behavioral participation.",
		"Materiality thresholds are audit heuristics: 2 percentage-point sold-rate drop, 1 percentage-point appraisal-normalized hammer drop, 0.10 active-bidder drop, or 0.10 VALUE-dropout increase from Stage 1 to 10.",
		"SceneTree cannot introspect process stderr. Strict acceptance check 5 consumes the isolated preflight fatal count supplied by the outer runner; the final run is independently scanned before a freeze is reported.",
		"Balance findings never change the process exit code; only execution/control failures do. No tuning is performed by this script."
	]
	var report := {
		"schemaVersion": 1,
		"suite": "R3 Auction Stage Sensitivity Audit",
		"diagnosticOnly": true,
		"productionSourceOrDataModifiedByThisAudit": false,
		"auditSubject": "Current production auction implementation after the final minimal correction: positive disclosure support remains stage-independent; negative condition/provenance support-gap pressure is capped at 1.66; negative disclosure and reserve pressure retain canonical difficulty.",
		"scope": {
			"stages": AUDITED_STAGES,
			"difficultyFormula": "pow(1.07, stage - 1)",
			"strategies": STRATEGIES,
			"supportFixtures": SUPPORT_FIXTURES,
			"artifacts": ARTIFACT_ROWS,
			"pairedSeedCount": PAIRED_SEED_COUNT,
			"masterSeedBase": MASTER_SEED_BASE,
			"masterSeedStride": MASTER_SEED_STRIDE,
			"fixedDay": FIXED_DAY,
			"expectedCells": expected_cells,
			"expectedTrials": expected_trials,
			"expectedPairedObservationsPerStagePair": expected_observations
		},
		"methodology": {
			"pairedControl": "Within an artifact/sample pair, every stage, support fixture and price strategy shares uniqueId, authored hidden artifact state, master seed, day, selected bidder roster and per-bidder variance. Stage and the named public/listing dimensions are the only controlled differences.",
			"soldNoSale": "reserve_met and sale_status over 48 common deterministic seeds per cell",
			"hammer": "raw hammer and hammer/public-appraisal, including zero for no-bid outcomes; sold and no-sale distributions are also split",
			"participants": "offered roster count plus active bidders with bidCount > 0 and total public bid count",
			"dropoutReasons": "BUDGET, VALUE, AFTER_FIRST_BID and OTHER counts/shares, plus paired later-minus-earlier deltas",
			"budgetStratification": "For the same selected bidder roster and reserve, neutralize condition/disclosure/provenance stage scrutiny, compute uncapped base willingness with production bidder_maximum, then separately require authored budget >= reserve.",
			"normalAvailabilitySlice": "Filter to FEASIBLE observations with at least three pre-scrutiny base-eligible bidders, then recompute Stage 1/5/10 and paired support/preset metrics without changing production inputs.",
			"monotonicPressure": "sold rate, mean hammer/appraisal and mean active participants must be non-increasing across Stage 1→5→10 while mean VALUE dropouts must be non-decreasing",
			"meaningfulCoverageGate": "at least 80% of cells monotonic on all four dimensions, at least 50% with one material adverse Stage 1→10 effect, and at least 10% paired decision change rate",
			"strictAcceptance": "Exactly five NORMAL_AVAILABILITY checks: LOW SOLD deterioration 15-30pp; HIGH deterioration <=2pp and favorable drift <=0.5pp; Stage 10 overall SOLD >=40% with at least two presets >=30%; reversal <=0.5% plus aggregate SOLD monotonicity; paired/RNG/budget invariance plus fatal-zero preflight and determinism.",
			"executionVsBalance": "executionPassed covers harness completeness, controls and determinism; the exact five-test NORMAL_AVAILABILITY acceptance and broad-direction check drive freeze/needsTuning, while all-availability coverage flags remain diagnostic."
		},
		"execution": {
			"passed": execution_passed,
			"checks": execution_checks,
			"completedTrials": completed_trials,
			"deterministicChecks": deterministic_checks,
			"errors": execution_errors,
			"supportContractFailures": support_contract_failures,
			"pairedControlFailures": control_failures,
			"availabilityInvarianceFailures": availability_invariance_failures,
			"deterministicFailures": deterministic_failures
		},
		"stageSummaries": stage_summaries,
		"cellMetrics": cells,
		"pairedComparisons": pair_reports,
		"budgetStratification": budget_stratification,
		"normalAvailabilitySlice": normal_slice,
		"normalAvailabilityAcceptance": normal_acceptance,
		"monotonicityCells": monotonic_rows,
		"monotonicitySummary": monotonic_summary,
		"outcomeMaskingAnalysis": outcome_masking,
		"balanceFinding": {
			"verdict": verdict,
			"auctionTuningFreeze": execution_passed and bool(normal_acceptance.get("allPassed", false)) and broad_direction_maintained,
			"needsTuning": execution_passed and (not bool(normal_acceptance.get("allPassed", false)) or not broad_direction_maintained),
			"normalAvailabilityAcceptanceFailures": normal_acceptance_failures,
			"broadDirectionMaintained": broad_direction_maintained,
			"allAvailabilityDiagnosticFlags": tuning_flags,
			"aggregateStage1To10Monotonic": global_monotonic,
			"monotonicCellCoverage": rounded(cell_monotonic_coverage),
			"materialAdverseCellCoverage": rounded(material_coverage),
			"pairedStage1To10DecisionChangeRate": rounded(stage_sensitive_rate),
			"broadMatrixRefutesGlobalStageNeutrality": int(stage_1_to_10.get("outcomeTransitions", {}).get("SOLD_TO_NO_SALE", 0)) > 0 and stage_sensitive_rate > 0.0,
			"sameSaleOutcomeCanMaskOtherDecisionSensitivity": bool(outcome_masking.get("sameSaleOutcomeCanMaskStageSensitivity", false)),
			"highSupportStage1To10": {
				"outcomeTransitionRate": float(high_support_1_to_10.get("outcomeTransitionRate", 0.0)),
				"meanHammerToAppraisalDelta": float(high_support_1_to_10.get("hammerToAppraisalDelta", {}).get("mean", 0.0)),
				"meanActiveParticipantDelta": float(high_support_1_to_10.get("participants", {}).get("activeDelta", {}).get("mean", 0.0)),
				"meanValueDropoutDelta": float(high_support_1_to_10.get("dropoutReasonDelta", {}).get("VALUE", {}).get("mean", 0.0)),
				"anyAuctionDecisionChangedRate": float(high_support_1_to_10.get("anyAuctionDecisionChangedRate", 0.0))
			},
			"interpretation": "The broad matrix determines whether a same-outcome fixture is merely sitting in a threshold-insensitive region. A meaningful stage multiplier must change actual bidder decisions often enough while keeping aggregate and most cell directions adverse rather than favorable as stage rises."
		},
		"caveats": caveats
	}
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output == null:
		push_error("Could not open auction stage sensitivity report: %s" % REPORT_PATH)
		quit(1)
		return
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify({
		"suite": report.suite,
		"execution": report.execution,
		"balanceFinding": report.balanceFinding,
		"stageSummaries": report.stageSummaries,
		"monotonicitySummary": report.monotonicitySummary
	}))
	gs.persistence_enabled = false
	quit(0 if execution_passed else 1)
