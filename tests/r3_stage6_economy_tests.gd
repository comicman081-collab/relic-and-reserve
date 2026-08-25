extends SceneTree

## Deterministic Stage 6A report-reward and auction settlement simulation.
## It uses a fixed seed, public runtime actions, finite loop bounds, and no saves.

const CASE_IDS := ["shadow_gauge", "shadow_clock", "shadow_music_box"]
const EXPECTED_TEST_COUNT := 4
const REPORT_PATH := "res://qa/R3_STAGE6_ECONOMY_TESTS.json"
const EXPECTED_REWARDS := {
	"shadow_gauge": {"money": 270, "reputation": 2, "mastery": 3, "museumTrust": 1, "historicalIntegrity": 1},
	"shadow_clock": {"money": 282, "reputation": 2, "mastery": 3, "museumTrust": 1, "historicalIntegrity": 1},
	"shadow_music_box": {"money": 294, "reputation": 2, "mastery": 3, "museumTrust": 1, "historicalIntegrity": 1}
}

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(test_id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": test_id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func semantic_equal(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))


func numeric_tree_finite(value: Variant) -> bool:
	if value is float:
		return is_finite(float(value))
	if value is Dictionary:
		for child: Variant in value.values():
			if not numeric_tree_finite(child):
				return false
	elif value is Array:
		for child: Variant in value:
			if not numeric_tree_finite(child):
				return false
	return true


func stage_six_profile(gs: Node) -> Dictionary:
	var profile: Dictionary = gs.default_player_profile()
	profile["highestUnlockedStage"] = 6
	profile["clearedStages"] = [1, 2, 3, 4, 5]
	profile["stageBest"] = {"1": 55.0, "2": 58.0, "3": 61.0, "4": 64.0, "5": 67.0}
	return profile


func start_stage_six(gs: Node, seed_value: int) -> Dictionary:
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	# A prior simulated clear may still await its presentation acknowledgement;
	# reset the transient run before constructing the next deterministic fixture.
	gs.reset_game()
	gs.master_seed = seed_value
	gs.rng.seed = seed_value
	gs.player_profile = stage_six_profile(gs)
	var started: Dictionary = gs.new_game(6)
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	return started


func discover_all(gs: Node, case_id: String) -> Array:
	var discovered: Array = []
	for _pass: int in range(20):
		var progressed := false
		for value: Variant in gs.get_case_public_state(case_id).get("availableEvidence", []):
			if not value is Dictionary:
				continue
			var tools: Array = value.get("requiredTools", [])
			if not tools.is_empty():
				gs.select_tool(String(tools[0]))
			var result: Dictionary = gs.discover_case_evidence(case_id, String(value.get("id", "")))
			if bool(result.get("ok", false)) and String(result.get("code", "")) == "DISCOVERED":
				discovered.append(String(value.get("id", "")))
				progressed = true
		if not progressed:
			break
	return discovered


func reward_before(gs: Node, case_id: String, domain: String, npc_id: String) -> Dictionary:
	var relationship: Dictionary = gs.campaign_state.get("relationships", {}).get(npc_id, {}).duplicate(true)
	return {
		"money": int(gs.money), "reputation": int(gs.reputation),
		"museumTrust": int(gs.campaign_state.get("museumTrust", 0)),
		"historicalIntegrity": int(gs.campaign_state.get("historicalIntegrity", 0)),
		"collectorNetwork": int(gs.campaign_state.get("collectorNetwork", 0)),
		"mastery": int(gs.campaign_state.get("mastery", {}).get(domain, 0)),
		"relationship": relationship,
		"authAttempts": int(gs.statistics.get("authentication_attempts", 0)),
		"authCorrect": int(gs.statistics.get("authentication_correct", 0)),
		"completed": bool(gs.campaign_state.get("completedCases", {}).get(case_id, false))
	}


func reward_delta_exact(gs: Node, case_id: String, domain: String, npc_id: String, before: Dictionary, rewards: Dictionary) -> Dictionary:
	var relationship: Dictionary = gs.campaign_state.get("relationships", {}).get(npc_id, {})
	var expected_money := roundi(float(rewards.get("money", 0)) * 1.20)
	var expected_reputation := roundi(float(rewards.get("reputation", 0)) * 1.20)
	var expected_mastery := roundi(float(rewards.get("mastery", 0)) * 1.20)
	var expected_trust := roundi(float(rewards.get("museumTrust", 0)) * 1.20)
	var expected_integrity := clampi(int(before.historicalIntegrity) + roundi(float(rewards.get("historicalIntegrity", 0)) * 1.20), 0, 100)
	var passed: bool = int(gs.money) == int(before.money) + expected_money \
		and int(gs.reputation) == int(before.reputation) + expected_reputation \
		and int(gs.campaign_state.get("museumTrust", 0)) == int(before.museumTrust) + expected_trust \
		and int(gs.campaign_state.get("historicalIntegrity", 0)) == expected_integrity \
		and int(gs.campaign_state.get("collectorNetwork", 0)) == int(before.collectorNetwork) + 1 \
		and int(gs.campaign_state.get("mastery", {}).get(domain, 0)) == int(before.mastery) + expected_mastery \
		and int(relationship.get("relationship", 0)) == int(before.relationship.get("relationship", 0)) + 2 \
		and int(relationship.get("trust", 0)) == int(before.relationship.get("trust", 0)) + 2 \
		and int(gs.statistics.get("authentication_attempts", 0)) == int(before.authAttempts) + 1 \
		and int(gs.statistics.get("authentication_correct", 0)) == int(before.authCorrect) + 1 \
		and bool(gs.campaign_state.get("completedCases", {}).get(case_id, false))
	return {
		"passed": passed,
		"expected": {"money": expected_money, "reputation": expected_reputation, "mastery": expected_mastery, "museumTrust": expected_trust, "historicalIntegrity": expected_integrity},
		"actual": {"money": int(gs.money) - int(before.money), "reputation": int(gs.reputation) - int(before.reputation), "mastery": int(gs.campaign_state.get("mastery", {}).get(domain, 0)) - int(before.mastery), "museumTrust": int(gs.campaign_state.get("museumTrust", 0)) - int(before.museumTrust), "historicalIntegrity": int(gs.campaign_state.get("historicalIntegrity", 0))}
	}


func settlement_signature(gs: Node) -> String:
	return JSON.stringify({
		"money": int(gs.money), "reputation": int(gs.reputation), "inventory": gs.save_payload().get("inventory", []),
		"transactions": gs.transactions, "auctionHistory": gs.auction_history, "statistics": gs.statistics,
		"ledger": gs.campaign_state.get("caseArtifactLedger", {}), "pending": gs.pending_auction,
		"telemetry": gs.stage_run_state.get("telemetry", {}), "rng": str(gs.rng.state)
	})


func simulate(gs: Node, registry: Node, seed_value: int) -> Dictionary:
	var started := start_stage_six(gs, seed_value)
	var rows: Array = []
	var terminal_count := 0
	var sold_count := 0
	var duplicate_sales := 0
	var budget_violations := 0
	var reward_failures := 0
	var action_count := 0
	for case_id: String in CASE_IDS:
		action_count += 1
		var story_case: Dictionary = registry.get_case(case_id)
		var definition: Dictionary = registry.get_case_v2(case_id)
		var artifact: Dictionary = gs.begin_case(case_id)
		var discovered := discover_all(gs, case_id) if not artifact.is_empty() else []
		action_count += discovered.size()
		var domain := String(gs.mastery_domain_for_spec(String(story_case.get("rewardSpecId", ""))))
		var before_reward := reward_before(gs, case_id, domain, String(story_case.get("npcId", "")))
		var resolution: Dictionary = gs.resolve_case_v2(
			case_id,
			String(definition.get("canonical_hypothesis_id", "")),
			definition.get("resolution", {}).get("required_source_refs", [])
		) if discovered.size() == 6 else {"ok": false, "code": "DISCOVERY_INCOMPLETE"}
		action_count += 1
		var reward_check := reward_delta_exact(gs, case_id, domain, String(story_case.get("npcId", "")), before_reward, story_case.get("rewards", {})) if bool(resolution.get("ok", false)) else {"passed": false}
		if not bool(reward_check.get("passed", false)):
			reward_failures += 1
		var appraisal: int = int(gs.appraise(artifact)) if not artifact.is_empty() else 0
		var listed := bool(gs.list_auction(artifact, 1, 1, float(artifact.get("confidence", 0.0)), "CERTAIN", appraisal)) if bool(resolution.get("ok", false)) else false
		action_count += 1
		var pending: Dictionary = gs.create_pending_auction(artifact) if listed else {"ok": false, "code": "LISTING_FAILED"}
		action_count += 1
		var frozen: Dictionary = gs.pending_auction.get("result", {}).duplicate(true) if bool(pending.get("ok", false)) else {}
		for participant_value: Variant in frozen.get("participants", []):
			if participant_value is Dictionary and int(participant_value.get("maxBid", 0)) > int(participant_value.get("budget", 0)):
				budget_violations += 1
		for bid_value: Variant in frozen.get("bids", []):
			if bid_value is Dictionary and int(bid_value.get("amount", 0)) > int(bid_value.get("budget", 0)):
				budget_violations += 1
		var transaction_id := String(pending.get("transactionId", ""))
		var committed: Dictionary = gs.commit_pending_auction(transaction_id) if not transaction_id.is_empty() else {"ok": false, "code": "MISSING_TRANSACTION"}
		action_count += 1
		var terminal := bool(committed.get("ok", false)) and String(committed.get("status", "")) == "COMMITTED"
		if terminal:
			terminal_count += 1
		if bool(committed.get("reserve_met", false)):
			sold_count += 1
		var history_count: int = gs.auction_history.size()
		var transaction_count: int = gs.transactions.size()
		var before_duplicate := settlement_signature(gs)
		var duplicate: Dictionary = gs.commit_pending_auction(transaction_id) if terminal else {"ok": false, "code": "NOT_TERMINAL"}
		action_count += 1
		var duplicate_zero: bool = before_duplicate == settlement_signature(gs) \
			and gs.auction_history.size() == history_count and gs.transactions.size() == transaction_count \
			and bool(duplicate.get("ok", false)) and bool(duplicate.get("idempotent", false))
		if not duplicate_zero:
			duplicate_sales += 1
		var bounded: bool = frozen.get("bids", []).size() <= 60 * maxi(1, frozen.get("participants", []).size())
		rows.append({
			"caseId": case_id, "artifactSpecId": artifact.get("artifactSpecId", ""),
			"discovered": discovered.size(), "resolution": resolution, "reward": reward_check,
			"listed": listed, "pending": pending, "frozen": frozen, "commit": committed,
			"duplicate": duplicate, "duplicateMutation0": duplicate_zero, "bounded": bounded,
			"terminal": terminal, "sold": bool(committed.get("reserve_met", false))
		})
	var finite := numeric_tree_finite({"money": gs.money, "statistics": gs.statistics, "rows": rows})
	return {
		"seed": seed_value, "started": started, "rows": rows, "terminalCount": terminal_count,
		"soldCount": sold_count, "terminalRate": float(terminal_count) / float(CASE_IDS.size()),
		"budgetViolations": budget_violations, "duplicateSales": duplicate_sales,
		"rewardFailures": reward_failures, "finite": finite, "actionCount": action_count,
		"stageStatus": gs.stage_run_state.get("status", ""), "highestUnlockedStage": gs.player_profile.get("highestUnlockedStage", 0),
		"finalMoney": gs.money, "finalReputation": gs.reputation
	}


func finish(gs: Node) -> void:
	gs.persistence_enabled = false
	var passed := results.filter(func(row: Dictionary): return bool(row.get("passed", false))).size()
	var report := {
		"suite": "R3 Stage 6 Economy",
		"executed": results.size(), "passed": passed, "failed": results.size() - passed,
		"skipped": 0, "expectedCount": EXPECTED_TEST_COUNT, "tests": results
	}
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print(JSON.stringify(report))
	quit(0 if passed == EXPECTED_TEST_COUNT and results.size() == EXPECTED_TEST_COUNT else 1)


func run() -> void:
	var registry: Node = get_root().get_node("RuntimeRegistry")
	var gs: Node = get_root().get_node("GameState")
	gs.persistence_enabled = false
	var reward_snapshot: Dictionary = {}
	for case_id: String in CASE_IDS:
		reward_snapshot[case_id] = registry.get_case(case_id).get("rewards", {}).duplicate(true)
	var reward_data_exact := true
	for case_id: String in CASE_IDS:
		reward_data_exact = reward_data_exact and semantic_equal(reward_snapshot[case_id], EXPECTED_REWARDS[case_id])
	record(
		"S6-ECON-REWARD-DATA-01",
		"Stage 6 authored reward values remain exact before simulation",
		reward_data_exact,
		reward_snapshot
	)

	var first := simulate(gs, registry, 660606)
	var rewards_after: Dictionary = {}
	for case_id: String in CASE_IDS:
		rewards_after[case_id] = registry.get_case(case_id).get("rewards", {}).duplicate(true)
	var terminal_ok: bool = bool(first.started.get("ok", false)) \
		and int(first.terminalCount) == 3 and is_equal_approx(float(first.terminalRate), 1.0) \
		and int(first.soldCount) == 3 and int(first.rewardFailures) == 0 \
		and String(first.stageStatus) == "CLEARED" and int(first.highestUnlockedStage) == 7 \
		and (first.rows as Array).all(func(row: Dictionary): return bool(row.get("terminal", false)) and bool(row.get("sold", false)) and bool(row.get("bounded", false)))
	record(
		"S6-ECON-TERMINAL-02",
		"The fixed-seed Stage 6 report-and-auction run reaches three of three terminal SOLD settlements and clears Stage 6",
		terminal_ok,
		first
	)

	var safety_ok: bool = bool(first.finite) and int(first.budgetViolations) == 0 \
		and int(first.duplicateSales) == 0 and int(first.actionCount) > 0 and int(first.actionCount) <= 60 \
		and semantic_equal(reward_snapshot, rewards_after)
	record(
		"S6-ECON-SAFETY-03",
		"Stage 6 simulation is finite and bounded with zero bidder-budget violations, duplicate sales or reward-data mutation",
		safety_ok,
		{"finite": first.finite, "actionCount": first.actionCount, "budgetViolations": first.budgetViolations, "duplicateSales": first.duplicateSales, "rewardDataMutation0": semantic_equal(reward_snapshot, rewards_after), "rewardsAfter": rewards_after}
	)

	var second := simulate(gs, registry, 660606)
	var deterministic_ok := semantic_equal(first, second)
	record(
		"S6-ECON-DETERMINISM-04",
		"Repeating the complete Stage 6 economy and auction scenario at the same seed returns the exact same terminal receipts",
		deterministic_ok,
		{"same": deterministic_ok, "first": first, "second": second}
	)

	finish(gs)
