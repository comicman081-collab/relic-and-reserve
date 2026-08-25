extends SceneTree

## Stage pressure telemetry backend regression.
##
## This suite exercises public gameplay/save APIs, writes only dedicated
## user:// fixtures plus its QA report, and never exports or packages a build.

const TEST_SAVE := "user://r3_stage_telemetry_resume.json"
const HOSTILE_SAVE := "user://r3_stage_telemetry_hostile.json"
const REPORT_PATH := "res://qa/R3_STAGE_TELEMETRY_TESTS.json"
const STRATEGIES := ["FAST", "BALANCED", "HIGH", "AUTO_GRAND_RESERVE", "CUSTOM", "LEGACY_UNKNOWN"]

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func approx_equal(left: float, right: float, epsilon: float = 0.0001) -> bool:
	return absf(left - right) <= epsilon


func cleanup_slot(gs: Node, path: String) -> void:
	for candidate: String in [path, path + String(gs.SAVE_TEMP_SUFFIX), path + String(gs.SAVE_BACKUP_SUFFIX)]:
		gs.remove_save_file(candidate)


func cleanup_all_slots(gs: Node) -> void:
	cleanup_slot(gs, TEST_SAVE)
	cleanup_slot(gs, HOSTILE_SAVE)


func authority_signature(gs: Node) -> String:
	return JSON.stringify({
		"run": gs.save_payload(),
		"profile": gs.profile_payload(),
		"rngStateExact": str(gs.rng.state)
	})


func write_payload(path: String, payload: Dictionary) -> bool:
	var output: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		return false
	output.store_string(JSON.stringify(payload, "  "))
	output.flush()
	output.close()
	return true


func prefix_count(values: Array, prefix: String) -> int:
	var count: int = 0
	for value: Variant in values:
		if value is String and String(value).begins_with(prefix):
			count += 1
	return count


func raw_telemetry(gs: Node) -> Dictionary:
	var value: Variant = gs.stage_run_state.get("telemetry", {})
	return value.duplicate(true) if value is Dictionary else {}


func fresh_stage_one(gs: Node) -> Dictionary:
	gs.persistence_enabled = false
	gs.reset_game()
	gs.player_profile = gs.default_player_profile()
	return gs.new_game(1)


func configured_auction_artifact(gs: Node) -> Dictionary:
	var artifact: Dictionary = gs.new_artifact("artifact_001", 860104, "telemetry_auction_lot")
	artifact.playerHypothesis = gs.truth_to_hypothesis(String(artifact.get("authenticityTruth", "UNKNOWN")))
	artifact.confidence = 0.96
	artifact.cleanliness = 100.0
	artifact.surfaceCondition = 100.0
	artifact.structuralCondition = 100.0
	artifact.mechanicalCondition = 100.0
	artifact.historicalIntegrity = 100.0
	artifact.restorationQuality = 100.0
	artifact.knownClues = ["PROVENANCE", "MATERIAL", "CONSTRUCTION_METHOD"]
	artifact.inspected = true
	gs.inventory.append(artifact)
	return artifact


func commit_at_final_cue(gs: Node, transaction_id: String) -> Dictionary:
	var cue_queue_value: Variant = gs.pending_auction.get("cueQueue", [])
	var cue_queue: Array = cue_queue_value if cue_queue_value is Array else []
	if cue_queue.is_empty():
		return {"ok": false, "code": "EMPTY_CUE_QUEUE"}
	var cue_response: Dictionary = gs.set_pending_auction_cue_index(transaction_id, cue_queue.size() - 1, TEST_SAVE)
	if not bool(cue_response.get("ok", false)):
		return cue_response
	return gs.commit_pending_auction(transaction_id, TEST_SAVE)


func hostile_rejection(gs: Node, case_id: String, payload: Dictionary, expected_code: String) -> Dictionary:
	var before: String = authority_signature(gs)
	var validation: Dictionary = gs.validate_save_payload(payload)
	var applied: bool = bool(gs.apply_save_data(payload))
	cleanup_slot(gs, HOSTILE_SAVE)
	var written: bool = write_payload(HOSTILE_SAVE, payload)
	var loaded: bool = bool(gs.load_game(HOSTILE_SAVE)) if written else false
	var load_error: String = String(gs.last_load_error)
	var mutation0: bool = authority_signature(gs) == before
	var passed: bool = not bool(validation.get("ok", true)) \
		and String(validation.get("code", "")) == expected_code \
		and not applied \
		and written \
		and not loaded \
		and load_error.contains(expected_code) \
		and mutation0
	cleanup_slot(gs, HOSTILE_SAVE)
	return {
		"case": case_id,
		"expected": expected_code,
		"validation": validation,
		"applied": applied,
		"written": written,
		"loaded": loaded,
		"loadError": load_error,
		"mutation0": mutation0,
		"passed": passed
	}


func finish_suite(gs: Node) -> void:
	var passed: int = results.filter(func(result: Dictionary) -> bool: return bool(result.get("passed", false))).size()
	var report: Dictionary = {
		"suite": "R3 Stage Pressure Telemetry Backend",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"skipped": 0,
		"tests": results
	}
	var output: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print(JSON.stringify(report))
	cleanup_all_slots(gs)
	gs.persistence_enabled = false
	quit(0 if passed == results.size() else 1)


func run() -> void:
	var gs: Node = get_root().get_node_or_null("GameState")
	if gs == null:
		results.append({"id": "STAGE-TELEMETRY-API-01", "name": "GameState autoload is present", "executed": true, "passed": false, "evidence": {"missing": ["GameState"]}})
		quit(1)
		return

	cleanup_all_slots(gs)
	var required_methods: Array = [
		"default_stage_run_state", "default_stage_telemetry", "new_game", "clean", "repair", "disassemble",
		"begin_case", "get_case_public_state", "discover_case_evidence", "select_tool", "list_auction",
		"create_pending_auction", "pending_auction_public_state", "set_pending_auction_cue_index",
		"commit_pending_auction", "stage_public_telemetry", "stage_replay_feedback", "stage_score_from_run",
		"stage_public_summary", "stage_objectives_complete", "complete_stage", "save_payload",
		"validate_save_payload", "apply_save_data", "save_game", "load_game", "read_save_dictionary",
		"remove_save_file", "profile_payload"
	]
	var missing_methods: Array = []
	for method_value: Variant in required_methods:
		var method_name: String = String(method_value)
		if not gs.has_method(method_name):
			missing_methods.append(method_name)
	var default_run: Dictionary = gs.default_stage_run_state(1) if missing_methods.is_empty() else {}
	var required_keys: Array = ["telemetryAvailable", "telemetry", "telemetrySeenIds", "stageReplayTelemetrySnapshot"]
	var missing_keys: Array = []
	for key_value: Variant in required_keys:
		var key_name: String = String(key_value)
		if not default_run.has(key_name):
			missing_keys.append(key_name)
	var api_ready: bool = missing_methods.is_empty() and missing_keys.is_empty()
	record(
		"STAGE-TELEMETRY-API-01",
		"Telemetry public actions, query, persistence and frozen-snapshot contracts are callable",
		api_ready,
		{"missingMethods": missing_methods, "missingRunKeys": missing_keys}
	)
	if not api_ready:
		finish_suite(gs)
		return

	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	gs.player_profile = gs.default_player_profile()
	var started: Dictionary = gs.new_game(1)
	var initial_public: Dictionary = gs.stage_public_telemetry()
	var initial_raw: Dictionary = raw_telemetry(gs)
	var initial_before: String = authority_signature(gs)
	var initial_rng_before: int = int(gs.rng.state)
	var initial_repeat: Dictionary = gs.stage_public_telemetry()
	var initial_after: String = authority_signature(gs)
	var initial_rng_after: int = int(gs.rng.state)
	var initial_counts_zero: bool = true
	for count_key: String in ["repairActions", "investigationActions", "investigationRiskActions", "auctionCount", "noSaleCount", "relistCount", "artifactSalesCount"]:
		initial_counts_zero = initial_counts_zero and int(initial_raw.get(count_key, -1)) == 0
	var initial_distribution_zero: bool = true
	var initial_distribution: Dictionary = initial_public.get("listingStrategyDistribution", {}) if initial_public.get("listingStrategyDistribution", {}) is Dictionary else {}
	for strategy_id: String in STRATEGIES:
		initial_distribution_zero = initial_distribution_zero and approx_equal(float(initial_distribution.get(strategy_id, -1.0)), 0.0)
	record(
		"STAGE-TELEMETRY-DEFAULT-01",
		"A new RUNNING stage starts with available zero telemetry and advisory queries mutate no state or RNG",
		bool(started.get("ok", false)) \
			and String(gs.stage_run_state.get("status", "")) == "RUNNING" \
			and bool(gs.stage_run_state.get("telemetryAvailable", false)) \
			and gs.stage_run_state.get("telemetrySeenIds", []) == [] \
			and gs.stage_run_state.get("stageReplayTelemetrySnapshot", {}) == {} \
			and int(initial_raw.get("budgetBasis", 0)) == 1200 \
			and initial_counts_zero \
			and bool(initial_public.get("available", false)) \
			and int(initial_public.get("stage", 0)) == 1 \
			and initial_distribution_zero \
			and initial_repeat == initial_public \
			and initial_before == initial_after \
			and initial_rng_before == initial_rng_after,
		{"started": started, "raw": initial_raw, "public": initial_public, "mutation0": initial_before == initial_after, "rng": [str(initial_rng_before), str(initial_rng_after)]}
	)

	# One workpiece covers the three public restoration paths. Its authored repair
	# profile requires the precision screwdriver; disassembly deliberately has no
	# tool attribution, so concentration uses all three successful actions.
	var workpiece: Dictionary = gs.new_artifact("artifact_001", 860101, "telemetry_workpiece")
	workpiece.damageInstances = ["DUST", "CRACK"]
	workpiece.restorationCost = 0.0
	gs.inventory.append(workpiece)
	var cost_start: float = float(workpiece.restorationCost)
	var clean_result: String = gs.clean(workpiece, "soft_brush")
	var cost_after_clean: float = float(workpiece.restorationCost)
	var after_clean: Dictionary = raw_telemetry(gs)
	var selected_repair_tool: bool = bool(gs.select_tool("precision_screwdriver"))
	var repair_result: String = gs.repair(workpiece)
	var cost_after_repair: float = float(workpiece.restorationCost)
	var after_repair: Dictionary = raw_telemetry(gs)
	var disassembled: bool = bool(gs.disassemble(workpiece, "body"))
	var cost_after_disassembly: float = float(workpiece.restorationCost)
	var after_disassembly: Dictionary = raw_telemetry(gs)
	var restoration_public_first: Dictionary = gs.stage_public_telemetry()
	var restoration_public_second: Dictionary = gs.stage_public_telemetry()
	var tool_counts: Dictionary = after_disassembly.get("repairToolUseCounts", {}) if after_disassembly.get("repairToolUseCounts", {}) is Dictionary else {}
	var restore_seen: Array = gs.stage_run_state.get("telemetrySeenIds", []) if gs.stage_run_state.get("telemetrySeenIds", []) is Array else []
	var clean_delta: float = cost_after_clean - cost_start
	var repair_delta: float = cost_after_repair - cost_after_clean
	var disassembly_delta: float = cost_after_disassembly - cost_after_repair
	record(
		"STAGE-TELEMETRY-RESTORE-01",
		"Clean, repair and disassemble accrue their actual cost once and attribute only the two selected tools once",
		clean_result == "Effective restoration." \
			and selected_repair_tool \
			and repair_result == "Mechanism repaired." \
			and disassembled \
			and not bool(workpiece.get("partStates", {}).get("body", true)) \
			and approx_equal(clean_delta, 12.0) \
			and approx_equal(repair_delta, 48.0) \
			and approx_equal(disassembly_delta, 8.0) \
			and int(after_clean.get("repairActions", -1)) == 1 \
			and int(after_repair.get("repairActions", -1)) == 2 \
			and int(after_disassembly.get("repairActions", -1)) == 3 \
			and approx_equal(float(after_disassembly.get("repairCostAccrued", -1.0)), cost_after_disassembly - cost_start) \
			and int(tool_counts.get("soft_brush", 0)) == 1 \
			and int(tool_counts.get("precision_screwdriver", 0)) == 1 \
			and tool_counts.size() == 2 \
			and prefix_count(restore_seen, "RESTORE|") == 3 \
			and restoration_public_first == restoration_public_second \
			and int(restoration_public_first.get("repairActions", -1)) == 3,
		{"results": [clean_result, repair_result, disassembled], "deltas": [clean_delta, repair_delta, disassembly_delta], "raw": after_disassembly, "public": restoration_public_first, "restoreSeen": prefix_count(restore_seen, "RESTORE|")}
	)

	var case_artifact: Dictionary = gs.begin_case("prologue_clock")
	var case_public: Dictionary = gs.get_case_public_state("prologue_clock")
	var high_risk_id: String = ""
	var high_risk_tools: Array = []
	for row_value: Variant in case_public.get("availableEvidence", []):
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value
		if String(row.get("riskLevel", "NONE")) == "HIGH":
			high_risk_id = String(row.get("id", ""))
			high_risk_tools = row.get("requiredTools", []).duplicate() if row.get("requiredTools", []) is Array else []
			break
	if not high_risk_tools.is_empty():
		gs.select_tool(String(high_risk_tools[0]))
	var integrity_before: float = float(case_artifact.get("historicalIntegrity", 0.0))
	var discovered: Dictionary = gs.discover_case_evidence("prologue_clock", high_risk_id) if not high_risk_id.is_empty() else {}
	var after_discovery: Dictionary = raw_telemetry(gs)
	var integrity_after: float = float(case_artifact.get("historicalIntegrity", 0.0))
	var duplicate: Dictionary = gs.discover_case_evidence("prologue_clock", high_risk_id) if not high_risk_id.is_empty() else {}
	var after_duplicate: Dictionary = raw_telemetry(gs)
	var investigation_seen: Array = gs.stage_run_state.get("telemetrySeenIds", []) if gs.stage_run_state.get("telemetrySeenIds", []) is Array else []
	var expected_risk: float = float(gs.investigation_risk_penalty("HIGH"))
	record(
		"STAGE-TELEMETRY-INVESTIGATION-01",
		"A discovered high-risk clue records one risk event while ALREADY_DISCOVERED records no duplicate",
		not case_artifact.is_empty() \
			and not high_risk_id.is_empty() \
			and bool(discovered.get("ok", false)) \
			and String(discovered.get("code", "")) == "DISCOVERED" \
			and approx_equal(float(discovered.get("appliedRiskPenalty", -1.0)), expected_risk) \
			and approx_equal(integrity_before - integrity_after, expected_risk) \
			and bool(duplicate.get("ok", false)) \
			and String(duplicate.get("code", "")) == "ALREADY_DISCOVERED" \
			and after_duplicate == after_discovery \
			and int(after_duplicate.get("investigationActions", -1)) == 1 \
			and int(after_duplicate.get("investigationRiskActions", -1)) == 1 \
			and approx_equal(float(after_duplicate.get("investigationRiskWeightSum", -1.0)), expected_risk) \
			and prefix_count(investigation_seen, "INVESTIGATE|") == 1,
		{"evidenceId": high_risk_id, "first": discovered, "duplicate": duplicate, "integrity": [integrity_before, integrity_after], "telemetry": after_duplicate}
	)

	# First create a certain NO_SALE, persist/reload it, and retry the same pending
	# creation. Then relist the same lot on the exact FAST ratios and repeat the
	# resume/idempotence path before a low-reserve SOLD commit.
	var auction_artifact: Dictionary = configured_auction_artifact(gs)
	var first_listed: bool = bool(gs.list_auction(auction_artifact, 999999, 1000000, 0.96, "CERTAIN", 100))
	gs.persistence_enabled = true
	var first_created: Dictionary = gs.create_pending_auction(auction_artifact, false, TEST_SAVE)
	var first_transaction: String = String(first_created.get("transactionId", ""))
	var first_listing_raw: Dictionary = raw_telemetry(gs)
	var first_retry: Dictionary = gs.create_pending_auction(auction_artifact, false, TEST_SAVE) if bool(first_created.get("ok", false)) else {}
	var first_retry_raw: Dictionary = raw_telemetry(gs)
	var first_saved: Dictionary = gs.read_save_dictionary(TEST_SAVE)
	gs.reset_game()
	var first_loaded: bool = bool(gs.load_game(TEST_SAVE))
	var first_loaded_artifact: Dictionary = gs.find_inventory_instance("telemetry_auction_lot")
	var first_resume_raw: Dictionary = raw_telemetry(gs)
	var first_resume_retry: Dictionary = gs.create_pending_auction(first_loaded_artifact, false, TEST_SAVE) if first_loaded and not first_loaded_artifact.is_empty() else {}
	var first_resume_retry_raw: Dictionary = raw_telemetry(gs)
	var first_commit: Dictionary = commit_at_final_cue(gs, first_transaction) if first_loaded else {}
	var first_commit_raw: Dictionary = raw_telemetry(gs)
	var first_commit_signature: String = authority_signature(gs)
	var first_commit_repeat: Dictionary = gs.commit_pending_auction(first_transaction, TEST_SAVE) if bool(first_commit.get("ok", false)) else {}
	var first_repeat_signature: String = authority_signature(gs)

	var relist_artifact: Dictionary = gs.find_inventory_instance("telemetry_auction_lot")
	var second_listed: bool = bool(gs.list_auction(relist_artifact, 10, 12, 0.96, "CERTAIN", 20)) if not relist_artifact.is_empty() else false
	var second_created: Dictionary = gs.create_pending_auction(relist_artifact, false, TEST_SAVE) if second_listed else {}
	var second_transaction: String = String(second_created.get("transactionId", ""))
	var second_listing_raw: Dictionary = raw_telemetry(gs)
	var second_retry: Dictionary = gs.create_pending_auction(relist_artifact, false, TEST_SAVE) if bool(second_created.get("ok", false)) else {}
	var second_retry_raw: Dictionary = raw_telemetry(gs)
	gs.reset_game()
	var second_loaded: bool = bool(gs.load_game(TEST_SAVE))
	var second_loaded_artifact: Dictionary = gs.find_inventory_instance("telemetry_auction_lot")
	var second_resume_raw: Dictionary = raw_telemetry(gs)
	var second_resume_retry: Dictionary = gs.create_pending_auction(second_loaded_artifact, false, TEST_SAVE) if second_loaded and not second_loaded_artifact.is_empty() else {}
	var second_resume_retry_raw: Dictionary = raw_telemetry(gs)
	var second_commit: Dictionary = commit_at_final_cue(gs, second_transaction) if second_loaded else {}
	var second_commit_raw: Dictionary = raw_telemetry(gs)
	var second_commit_signature: String = authority_signature(gs)
	var second_commit_repeat: Dictionary = gs.commit_pending_auction(second_transaction, TEST_SAVE) if bool(second_commit.get("ok", false)) else {}
	var second_repeat_signature: String = authority_signature(gs)
	gs.persistence_enabled = false

	var first_strategy_counts: Dictionary = first_listing_raw.get("listingStrategyCounts", {}) if first_listing_raw.get("listingStrategyCounts", {}) is Dictionary else {}
	var second_strategy_counts: Dictionary = second_listing_raw.get("listingStrategyCounts", {}) if second_listing_raw.get("listingStrategyCounts", {}) is Dictionary else {}
	var listing_resume_exact: bool = first_listing_raw == first_retry_raw \
		and first_listing_raw == first_resume_raw \
		and first_listing_raw == first_resume_retry_raw \
		and second_listing_raw == second_retry_raw \
		and second_listing_raw == second_resume_raw \
		and second_listing_raw == second_resume_retry_raw
	record(
		"STAGE-TELEMETRY-LISTING-01",
		"Pending creation records its strategy once, survives resume exactly, and a post-NO_SALE relist increments once",
		first_listed \
			and bool(first_created.get("ok", false)) \
			and bool(first_retry.get("ok", false)) \
			and not first_saved.is_empty() \
			and first_loaded \
			and bool(first_resume_retry.get("ok", false)) \
			and int(first_strategy_counts.get("CUSTOM", 0)) == 1 \
			and int(first_listing_raw.get("relistCount", -1)) == 0 \
			and second_listed \
			and bool(second_created.get("ok", false)) \
			and bool(second_retry.get("ok", false)) \
			and second_loaded \
			and bool(second_resume_retry.get("ok", false)) \
			and int(second_strategy_counts.get("CUSTOM", 0)) == 1 \
			and int(second_strategy_counts.get("FAST", 0)) == 1 \
			and int(second_listing_raw.get("relistCount", -1)) == 1 \
			and listing_resume_exact,
		{"first": {"created": first_created, "retry": first_retry, "resumeRetry": first_resume_retry, "raw": first_listing_raw}, "second": {"created": second_created, "retry": second_retry, "resumeRetry": second_resume_retry, "raw": second_listing_raw}, "exactAcrossResume": listing_resume_exact}
	)

	record(
		"STAGE-TELEMETRY-AUCTION-01",
		"NO_SALE and SOLD receipts each record once and repeated commits are authoritative mutation-zero receipts",
		bool(first_commit.get("ok", false)) \
			and String(first_commit.get("sale_status", "")) == "NO_SALE" \
			and bool(first_commit_repeat.get("ok", false)) \
			and bool(first_commit_repeat.get("idempotent", false)) \
			and first_commit_signature == first_repeat_signature \
			and int(first_commit_raw.get("auctionCount", -1)) == 1 \
			and int(first_commit_raw.get("noSaleCount", -1)) == 1 \
			and int(first_commit_raw.get("artifactSalesCount", -1)) == 0 \
			and bool(second_commit.get("ok", false)) \
			and String(second_commit.get("sale_status", "")) == "SOLD" \
			and bool(second_commit_repeat.get("ok", false)) \
			and bool(second_commit_repeat.get("idempotent", false)) \
			and second_commit_signature == second_repeat_signature \
			and int(second_commit_raw.get("auctionCount", -1)) == 2 \
			and int(second_commit_raw.get("noSaleCount", -1)) == 1 \
			and int(second_commit_raw.get("artifactSalesCount", -1)) == 1,
		{"first": first_commit, "firstRepeat": first_commit_repeat, "firstRaw": first_commit_raw, "second": second_commit, "secondRepeat": second_commit_repeat, "secondRaw": second_commit_raw, "mutation0": [first_commit_signature == first_repeat_signature, second_commit_signature == second_repeat_signature]}
	)

	var derived: Dictionary = gs.stage_public_telemetry()
	var derived_distribution: Dictionary = derived.get("listingStrategyDistribution", {}) if derived.get("listingStrategyDistribution", {}) is Dictionary else {}
	var tool_ids: Array = derived.get("repairToolIdsUsed", []) if derived.get("repairToolIdsUsed", []) is Array else []
	var expected_pressure: float = 68.0 / 1200.0
	var distribution_ok: bool = true
	for strategy_id: String in STRATEGIES:
		var expected_share: float = 0.5 if strategy_id in ["FAST", "CUSTOM"] else 0.0
		distribution_ok = distribution_ok and approx_equal(float(derived_distribution.get(strategy_id, -1.0)), expected_share)
	record(
		"STAGE-TELEMETRY-DERIVED-01",
		"Public pressure, risk, listing distribution, no-sale rate and tool concentration derive exactly from the action ledger",
		bool(derived.get("available", false)) \
			and int(derived.get("stage", 0)) == 1 \
			and approx_equal(float(derived.get("repairCostAccrued", -1.0)), 68.0) \
			and approx_equal(float(derived.get("repairResourcePressure", -1.0)), expected_pressure) \
			and int(derived.get("repairActions", -1)) == 3 \
			and tool_ids == ["precision_screwdriver", "soft_brush"] \
			and String(derived.get("dominantToolId", "")) == "precision_screwdriver" \
			and approx_equal(float(derived.get("toolConcentration", -1.0)), 1.0 / 3.0) \
			and int(derived.get("investigationActions", -1)) == 1 \
			and int(derived.get("investigationRiskActions", -1)) == 1 \
			and approx_equal(float(derived.get("investigationRiskRate", -1.0)), 1.0) \
			and approx_equal(float(derived.get("investigationRiskWeightSum", -1.0)), 3.0) \
			and int(derived.get("listingCount", -1)) == 2 \
			and distribution_ok \
			and int(derived.get("auctionCount", -1)) == 2 \
			and int(derived.get("noSaleCount", -1)) == 1 \
			and approx_equal(float(derived.get("noSaleRate", -1.0)), 0.5) \
			and int(derived.get("relistCount", -1)) == 1 \
			and int(derived.get("artifactSalesCount", -1)) == 1 \
			and derived.get("summaryCodes", []) == ["RISK_TAKEN", "RELIST_USED"],
		{"public": derived, "expectedPressure": expected_pressure, "distributionOk": distribution_ok}
	)

	var replay_before: Dictionary = gs.stage_replay_feedback()
	var score_before: float = float(gs.stage_score_from_run())
	var summary_before: Dictionary = gs.stage_public_summary(1, score_before)
	var query_rng_before: int = int(gs.rng.state)
	var query_authority_before: String = authority_signature(gs)
	var query_first: Dictionary = gs.stage_public_telemetry()
	var query_second: Dictionary = gs.stage_public_telemetry()
	var query_authority_after: String = authority_signature(gs)
	var query_rng_after: int = int(gs.rng.state)
	var replay_after: Dictionary = gs.stage_replay_feedback()
	var score_after: float = float(gs.stage_score_from_run())
	var summary_after: Dictionary = gs.stage_public_summary(1, score_after)
	record(
		"STAGE-TELEMETRY-ADVISORY-01",
		"Telemetry reads leave the established three-axis replay result, score, stage summary, authority and RNG unchanged",
		query_first == query_second \
			and replay_before == replay_after \
			and approx_equal(score_before, score_after) \
			and summary_before == summary_after \
			and query_authority_before == query_authority_after \
			and query_rng_before == query_rng_after,
		{"telemetry": query_first, "replayBefore": replay_before, "replayAfter": replay_after, "score": [score_before, score_after], "summaryEqual": summary_before == summary_after, "authorityMutation0": query_authority_before == query_authority_after, "rng": [str(query_rng_before), str(query_rng_after)]}
	)

	for case_value: Variant in gs.get_current_stage_case_ids():
		var completed_case_id: String = String(case_value)
		gs.campaign_state.completedCases[completed_case_id] = true
		gs.campaign_state.caseOutcomes[completed_case_id] = "credible"
	var completion_score: float = float(gs.stage_score_from_run())
	var telemetry_before_clear: Dictionary = gs.stage_public_telemetry()
	var completion: Dictionary = gs.complete_stage(1, completion_score, false)
	var frozen_snapshot: Dictionary = gs.stage_run_state.get("stageReplayTelemetrySnapshot", {}).duplicate(true) if gs.stage_run_state.get("stageReplayTelemetrySnapshot", {}) is Dictionary else {}
	var frozen_public_before: Dictionary = gs.stage_public_telemetry()
	var live_telemetry_after_clear: Dictionary = gs.stage_run_state.get("telemetry", {})
	live_telemetry_after_clear["repairCostAccrued"] = float(live_telemetry_after_clear.get("repairCostAccrued", 0.0)) + 999.0
	var live_strategy_counts: Dictionary = live_telemetry_after_clear.get("listingStrategyCounts", {})
	live_strategy_counts["FAST"] = int(live_strategy_counts.get("FAST", 0)) + 99
	live_telemetry_after_clear["listingStrategyCounts"] = live_strategy_counts
	gs.stage_run_state.telemetry = live_telemetry_after_clear
	var frozen_public_after_mutation: Dictionary = gs.stage_public_telemetry()
	var repeated_completion: Dictionary = gs.complete_stage(1, completion_score, false)
	var frozen_snapshot_after_repeat: Dictionary = gs.stage_run_state.get("stageReplayTelemetrySnapshot", {}).duplicate(true) if gs.stage_run_state.get("stageReplayTelemetrySnapshot", {}) is Dictionary else {}
	var frozen_replay_before: Dictionary = gs.stage_replay_feedback()
	var frozen_score_before: float = float(gs.stage_score_from_run())
	var frozen_summary_before: Dictionary = gs.stage_public_summary(1, frozen_score_before)
	var frozen_rng_before: int = int(gs.rng.state)
	var frozen_query: Dictionary = gs.stage_public_telemetry()
	var frozen_rng_after: int = int(gs.rng.state)
	var frozen_replay_after: Dictionary = gs.stage_replay_feedback()
	var frozen_score_after: float = float(gs.stage_score_from_run())
	var frozen_summary_after: Dictionary = gs.stage_public_summary(1, frozen_score_after)
	record(
		"STAGE-TELEMETRY-FREEZE-01",
		"complete_stage freezes telemetry once; later backing-ledger changes, repeated completion and reads cannot change it or established results",
		bool(completion.get("ok", false)) \
			and String(gs.stage_run_state.get("status", "")) == "CLEARED" \
			and not frozen_snapshot.is_empty() \
			and frozen_snapshot == telemetry_before_clear \
			and frozen_public_before == frozen_snapshot \
			and frozen_public_after_mutation == frozen_snapshot \
			and bool(repeated_completion.get("ok", false)) \
			and frozen_snapshot_after_repeat == frozen_snapshot \
			and frozen_query == frozen_snapshot \
			and frozen_replay_before == frozen_replay_after \
			and approx_equal(frozen_score_before, frozen_score_after) \
			and frozen_summary_before == frozen_summary_after \
			and frozen_rng_before == frozen_rng_after,
		{"completion": completion, "repeat": repeated_completion, "snapshot": frozen_snapshot, "afterBackingMutation": frozen_public_after_mutation, "snapshotStable": frozen_snapshot_after_repeat == frozen_snapshot, "replayStable": frozen_replay_before == frozen_replay_after, "score": [frozen_score_before, frozen_score_after], "rng": [str(frozen_rng_before), str(frozen_rng_after)]}
	)

	var legacy_started: Dictionary = fresh_stage_one(gs)
	var legacy_payload: Dictionary = gs.save_payload().duplicate(true)
	legacy_payload["saveVersion"] = 5
	var legacy_run: Dictionary = legacy_payload.get("stageRunState", {}).duplicate(true)
	for telemetry_key: String in ["telemetryAvailable", "telemetry", "telemetrySeenIds", "stageReplayTelemetrySnapshot"]:
		legacy_run.erase(telemetry_key)
	legacy_payload["stageRunState"] = legacy_run
	var legacy_validation: Dictionary = gs.validate_save_payload(legacy_payload)
	var legacy_applied: bool = bool(gs.apply_save_data(legacy_payload))
	var legacy_query_before_signature: String = authority_signature(gs)
	var legacy_rng_before: int = int(gs.rng.state)
	var legacy_public: Dictionary = gs.stage_public_telemetry()
	var legacy_public_repeat: Dictionary = gs.stage_public_telemetry()
	var legacy_rng_after: int = int(gs.rng.state)
	var legacy_query_after_signature: String = authority_signature(gs)
	record(
		"STAGE-TELEMETRY-LEGACY-01",
		"A valid v5 run loads without invented telemetry and remains explicitly unavailable",
		bool(legacy_started.get("ok", false)) \
			and bool(legacy_validation.get("ok", false)) \
			and legacy_applied \
			and not bool(gs.stage_run_state.get("telemetryAvailable", true)) \
			and gs.stage_run_state.get("telemetrySeenIds", []) == [] \
			and gs.stage_run_state.get("stageReplayTelemetrySnapshot", {}) == {} \
			and legacy_public == {"stage": 1, "available": false} \
			and legacy_public_repeat == legacy_public \
			and legacy_query_before_signature == legacy_query_after_signature \
			and legacy_rng_before == legacy_rng_after,
		{"validation": legacy_validation, "applied": legacy_applied, "run": gs.stage_run_state, "public": legacy_public, "mutation0": legacy_query_before_signature == legacy_query_after_signature, "rng": [str(legacy_rng_before), str(legacy_rng_after)]}
	)

	var hostile_started: Dictionary = fresh_stage_one(gs)
	var base_payload: Dictionary = gs.save_payload().duplicate(true)
	var hostile_cases: Array = []

	var wrong_available: Dictionary = base_payload.duplicate(true)
	wrong_available.stageRunState.telemetryAvailable = "true"
	hostile_cases.append({"id": "available_type", "payload": wrong_available, "code": "INVALID_STAGE_TELEMETRY"})

	var wrong_telemetry_type: Dictionary = base_payload.duplicate(true)
	wrong_telemetry_type.stageRunState.telemetry = []
	hostile_cases.append({"id": "telemetry_type", "payload": wrong_telemetry_type, "code": "INVALID_STAGE_TELEMETRY"})

	var negative_count: Dictionary = base_payload.duplicate(true)
	negative_count.stageRunState.telemetry.repairActions = -1
	hostile_cases.append({"id": "negative_count", "payload": negative_count, "code": "INVALID_STAGE_TELEMETRY"})

	var excessive_tool_total: Dictionary = base_payload.duplicate(true)
	excessive_tool_total.stageRunState.telemetry.repairToolUseCounts = {"soft_brush": 1}
	hostile_cases.append({"id": "tool_total_exceeds_actions", "payload": excessive_tool_total, "code": "INVALID_STAGE_TELEMETRY"})

	var duplicate_seen: Dictionary = base_payload.duplicate(true)
	duplicate_seen.stageRunState.telemetrySeenIds = ["RESTORE|duplicate", "RESTORE|duplicate"]
	hostile_cases.append({"id": "duplicate_seen_id", "payload": duplicate_seen, "code": "INVALID_STAGE_TELEMETRY"})

	var malformed_snapshot: Dictionary = base_payload.duplicate(true)
	malformed_snapshot.stageRunState.stageReplayTelemetrySnapshot = {"stage": 1, "available": true}
	hostile_cases.append({"id": "malformed_snapshot", "payload": malformed_snapshot, "code": "INVALID_STAGE_TELEMETRY"})

	var cleared_without_snapshot: Dictionary = base_payload.duplicate(true)
	cleared_without_snapshot.stageRunState.status = "CLEARED"
	cleared_without_snapshot.stageRunState.stageReplayTelemetrySnapshot = {}
	hostile_cases.append({"id": "cleared_without_snapshot", "payload": cleared_without_snapshot, "code": "INCONSISTENT_STAGE_TELEMETRY"})

	var unavailable_with_snapshot: Dictionary = base_payload.duplicate(true)
	unavailable_with_snapshot.stageRunState.telemetryAvailable = false
	unavailable_with_snapshot.stageRunState.stageReplayTelemetrySnapshot = gs.stage_public_telemetry().duplicate(true)
	hostile_cases.append({"id": "unavailable_with_snapshot", "payload": unavailable_with_snapshot, "code": "INCONSISTENT_STAGE_TELEMETRY"})

	var hostile_evidence: Array = []
	var hostile_passed: bool = bool(hostile_started.get("ok", false))
	for hostile_value: Variant in hostile_cases:
		var hostile: Dictionary = hostile_value
		var rejection: Dictionary = hostile_rejection(gs, String(hostile.get("id", "")), hostile.get("payload", {}), String(hostile.get("code", "")))
		hostile_evidence.append(rejection)
		hostile_passed = hostile_passed and bool(rejection.get("passed", false))
	record(
		"STAGE-TELEMETRY-VALIDATION-01",
		"Malformed v6 telemetry and inconsistent availability/snapshot pairs fail closed with mutation zero",
		hostile_passed,
		hostile_evidence
	)

	finish_suite(gs)
