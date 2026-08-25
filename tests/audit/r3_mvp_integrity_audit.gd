extends SceneTree

## Read-only R3 MVP audit harness.
##
## This script uses the real autoloads with an isolated user:// home supplied by
## the runner. It does not modify source/data, create release artifacts, alter
## player saves, or use a generator. A successful process means that the audit
## scenarios executed; discovered design or ledger gaps are written as findings,
## not hidden behind a test failure.

const REPORT_PATH := "res://qa/audit/R3_MVP_INTEGRITY_AUDIT.json"

var checks: Array = []
var findings: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Dictionary) -> void:
	checks.append({
		"id": id,
		"name": name,
		"executed": true,
		"passed": passed,
		"evidence": evidence
	})


func finding(severity: String, area: String, code: String, evidence: Dictionary) -> void:
	findings.append({
		"severity": severity,
		"area": area,
		"code": code,
		"evidence": evidence
	})


func configure_isolated_runtime(gs: Node, stage_id: int = 1) -> void:
	gs.reset_game()
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	gs.current_stage = stage_id
	gs.stage_run_state = gs.default_stage_run_state(stage_id)
	gs.stage_run_state.status = "RUNNING"
	gs.stage_run_state.startedAtDay = gs.day


func transaction_types(gs: Node) -> Array:
	var values: Array = []
	for transaction_value: Variant in gs.transactions:
		if transaction_value is Dictionary:
			values.append(String((transaction_value as Dictionary).get("type", "")))
	return values


func count_sale_transactions(gs: Node, unique_id: String) -> int:
	var count := 0
	for transaction_value: Variant in gs.transactions:
		if transaction_value is Dictionary:
			var transaction: Dictionary = transaction_value
			if String(transaction.get("type", "")) == "sale" and String(transaction.get("instanceId", "")) == unique_id:
				count += 1
	return count


func make_sale_ready_artifact(gs: Node, unique_id: String) -> Dictionary:
	var artifact: Dictionary = gs.new_artifact("artifact_001", 900101, unique_id)
	artifact.acquisitionPrice = 50
	artifact.cleanliness = 100.0
	artifact.surfaceCondition = 100.0
	artifact.mechanicalCondition = 100.0
	artifact.historicalIntegrity = 100.0
	artifact.confidence = 0.92
	artifact.inspected = true
	artifact.playerHypothesis = gs.truth_to_hypothesis(artifact.authenticityTruth)
	artifact.knownClues = ["MATERIAL"]
	gs.inventory.append(artifact)
	return artifact


func audit_repair_cash_and_sale_ledger(gs: Node) -> void:
	configure_isolated_runtime(gs, 10)
	var artifact := make_sale_ready_artifact(gs, "audit_repair_cash")
	var repair_types: Array = gs.repairable_damage_types(artifact)
	artifact.damageInstances = [String(repair_types[0])] if not repair_types.is_empty() else ["BROKEN_PART"]
	var required_tools: Array = gs.repair_requirements(artifact).get("requiredTools", [])
	if not required_tools.is_empty():
		gs.select_tool(String(required_tools[0]))
	var money_before_repair: int = gs.money
	var repair_message: String = gs.repair(artifact)
	var money_after_repair: int = gs.money
	var accrued_cost: int = int(round(float(artifact.restorationCost)))
	var repair_transaction_types := transaction_types(gs)
	var appraisal: int = int(gs.appraise(artifact))
	var listed: bool = gs.list_auction(artifact, 1, 1, 0.92, "LIKELY", appraisal)
	var created: Dictionary = gs.create_pending_auction(artifact)
	var committed: Dictionary = gs.commit_pending_auction(String(created.get("transactionId", ""))) if bool(created.get("ok", false)) else {}
	var money_after_sale: int = gs.money
	var expected_profit: int = int(committed.get("net", 0)) - int(artifact.get("acquisitionPrice", 0)) - int(artifact.get("restorationCost", 0))
	var observed_profit: int = int(gs.statistics.get("profit", 0))
	var cash_delta: int = money_after_sale - money_after_repair
	var net: int = int(committed.get("net", 0))
	var exact_sale: bool = bool(committed.get("ok", false)) and String(committed.get("sale_status", "")) == "SOLD" \
		and cash_delta == net and observed_profit == expected_profit and count_sale_transactions(gs, "audit_repair_cash") == 1
	var repair_cash_exact := money_after_repair - money_before_repair == -accrued_cost and repair_transaction_types.has("restoration")
	record(
		"AUDIT-ECON-01",
		"Repair cash debit, restoration ledger, actual SOLD settlement, profit accounting, and receipt count execute against the same artifact",
		repair_message == "Mechanism repaired." and accrued_cost > 0 and repair_cash_exact and listed and exact_sale,
		{
			"moneyBeforeRepair": money_before_repair,
			"moneyAfterRepair": money_after_repair,
			"repairCashDelta": money_after_repair - money_before_repair,
			"restorationCostAccrued": accrued_cost,
			"repairTransactionTypes": repair_transaction_types,
			"saleNet": net,
			"saleCashDelta": cash_delta,
			"expectedProfit": expected_profit,
			"observedProfit": observed_profit,
			"saleReceiptCount": count_sale_transactions(gs, "audit_repair_cash")
		}
	)
	if accrued_cost > 0 and not repair_cash_exact:
		finding(
			"P1",
			"ECONOMY",
			"REPAIR_COST_ACCRUES_ONLY_IN_PROFIT",
			{
				"moneyDeltaAtRepair": 0,
				"restorationCost": accrued_cost,
				"saleCashDelta": cash_delta,
				"profitIncludesRestorationCost": observed_profit == expected_profit
			}
		)


func audit_non_sale_money_ledger(gs: Node) -> void:
	configure_isolated_runtime(gs)
	var event_money_before: int = gs.money
	var event_transactions_before: int = gs.transactions.size()
	var event_result: Dictionary = gs.execute_event("event_01", false)
	var event_money_delta: int = gs.money - event_money_before
	var event_transaction_delta: int = gs.transactions.size() - event_transactions_before
	var event_history_count: int = gs.event_history.size()

	configure_isolated_runtime(gs)
	var reward_money_before: int = gs.money
	var reward_transactions_before: int = gs.transactions.size()
	gs.complete_case_rewards("prologue_clock", "credible")
	var reward_money_delta: int = gs.money - reward_money_before
	var reward_transaction_delta: int = gs.transactions.size() - reward_transactions_before
	record(
		"AUDIT-ECON-02",
		"Authoritative event and case-reward money paths expose a traceable ledger delta",
		not String(event_result.get("eventId", "")).is_empty() and event_money_delta == 120 and event_transaction_delta == 1 and reward_money_delta > 0 and reward_transaction_delta == 1,
		{
			"event": {"id": event_result.get("eventId", ""), "moneyDelta": event_money_delta, "transactionDelta": event_transaction_delta, "eventHistoryCount": event_history_count},
			"caseReward": {"moneyDelta": reward_money_delta, "transactionDelta": reward_transaction_delta}
		}
	)
	if event_money_delta != 0 and event_transaction_delta == 0 or reward_money_delta != 0 and reward_transaction_delta == 0:
		finding(
			"P1",
			"ECONOMY",
			"NON_SALE_MONEY_MISSING_FROM_LEDGER",
			{"eventMoneyDelta": event_money_delta, "eventTransactionDelta": event_transaction_delta, "caseRewardMoneyDelta": reward_money_delta, "caseRewardTransactionDelta": reward_transaction_delta}
		)


func audit_commission_contract(gs: Node, registry: Node) -> void:
	configure_isolated_runtime(gs)
	var artifact := make_sale_ready_artifact(gs, "audit_commission_reuse")
	var accepted: Array = []
	var money_before: int = gs.money
	for commission_value: Variant in registry.commissions:
		if not commission_value is Dictionary:
			continue
		var commission: Dictionary = commission_value
		var response: Dictionary = gs.complete_commission_from_artifact(String(commission.get("id", "")), artifact.uniqueId)
		accepted.append({"id": commission.get("id", ""), "ok": response.get("ok", false), "net": response.get("net", 0), "quality": response.get("quality", 0.0)})
	var duplicate: Dictionary = gs.complete_commission_from_artifact("commission_01", artifact.uniqueId)
	var accepted_count := accepted.filter(func(entry: Dictionary): return bool(entry.get("ok", false))).size()
	var blocked_count := accepted.filter(func(entry: Dictionary): return not bool(entry.get("ok", false))).size()
	var main_file := FileAccess.open("res://scripts/main3d.gd", FileAccess.READ)
	var main_source := main_file.get_as_text() if main_file != null else ""
	if main_file != null:
		main_file.close()
	var ui_route_present: bool = main_source.contains("complete_commission_from_artifact")
	record(
		"AUDIT-COMMISSION-01",
		"Commission authority accepts one eligible unsold artifact once, rejects reuse and unmet contracts, and exposes a main3d route",
		accepted_count == 1 and blocked_count == registry.commissions.size() - 1 and duplicate.get("ok", true) != true and ui_route_present,
		{"accepted": accepted, "acceptedCount": accepted_count, "blockedCount": blocked_count, "moneyDelta": gs.money - money_before, "duplicate": duplicate, "uiRoutePresent": ui_route_present}
	)
	if accepted_count > 1:
		finding(
			"P1",
			"COMMISSION",
			"ONE_ARTIFACT_SATISFIES_ALL_COMMISSION_TYPES",
			{"acceptedCommissionCount": accepted.size(), "moneyDelta": gs.money - money_before, "uiRoutePresent": ui_route_present}
		)
	if not ui_route_present:
		finding(
			"P1",
			"COMMISSION",
			"COMMISSION_AUTHORITY_HAS_NO_MAIN3D_UI_ROUTE",
			{"searchedMethod": "complete_commission_from_artifact", "main3dContainsMethod": false}
		)


func audit_profile_new_game_and_difficulty(gs: Node) -> void:
	configure_isolated_runtime(gs)
	gs.player_profile.highestUnlockedStage = 4
	gs.player_profile.clearedStages = [1, 2, 3]
	gs.player_profile.stageBest = {"1": 35.0, "2": 52.0, "3": 0.0}
	var profile_before: Dictionary = gs.profile_payload()
	var new_game: Dictionary = gs.new_game(3)
	var profile_after: Dictionary = gs.profile_payload()
	var difficulty_errors: Array = []
	for stage_id in range(1, 11):
		var actual: float = gs.stage_difficulty_multiplier(stage_id)
		var expected: float = pow(1.07, stage_id - 1)
		if not is_equal_approx(actual, expected):
			difficulty_errors.append({"stage": stage_id, "actual": actual, "expected": expected})
	record(
		"AUDIT-PROFILE-01",
		"NEW GAME resets the run but preserves unlocked stages, stageBest, and the data-driven 7-percent Stage curve",
		new_game.get("ok", false) == true and profile_before == profile_after and difficulty_errors.is_empty(),
		{"newGame": new_game, "profilePreserved": profile_before == profile_after, "difficultyErrors": difficulty_errors}
	)


func audit_authored_provenance_and_rules(gs: Node, registry: Node) -> void:
	var provenance_errors: Array = []
	var rule_errors: Array = []
	var authored_count := 0
	for case_id_value: Variant in registry.authored_cases_v2.keys():
		var case_id := String(case_id_value)
		var definition: Dictionary = registry.get_case_v2(case_id)
		authored_count += 1
		var provenance_sources: Array = []
		for evidence_value: Variant in definition.get("evidence", []):
			if not evidence_value is Dictionary:
				continue
			var evidence: Dictionary = evidence_value
			if String(evidence.get("public_clue_id", "")) == "PROVENANCE":
				provenance_sources.append(String(evidence.get("source", {}).get("kind", "")))
		for kind: String in provenance_sources:
			if kind != "DOCUMENT":
				provenance_errors.append({"caseId": case_id, "kind": kind})
		var rules: Array = definition.get("resolution", {}).get("outcome_rules", [])
		if rules.is_empty() or String(rules[-1].get("outcome_id", "")) != "reviewed_with_mentor" or not bool(rules[-1].get("fallback", false)):
			rule_errors.append({"caseId": case_id, "ruleCount": rules.size()})
	record(
		"AUDIT-AUTH-01",
		"Every authored PROVENANCE bridge is a DOCUMENT and every authored matcher ends in a mentor fallback",
		authored_count > 0 and provenance_errors.is_empty() and rule_errors.is_empty(),
		{"authoredCases": authored_count, "provenanceErrors": provenance_errors, "outcomeRuleErrors": rule_errors}
	)


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	audit_repair_cash_and_sale_ledger(gs)
	audit_non_sale_money_ledger(gs)
	audit_commission_contract(gs, registry)
	audit_profile_new_game_and_difficulty(gs)
	audit_authored_provenance_and_rules(gs, registry)
	var passed := checks.all(func(check: Dictionary): return check.get("passed", false) == true)
	var passed_count := 0
	for check_value: Variant in checks:
		if check_value is Dictionary and (check_value as Dictionary).get("passed", false) == true:
			passed_count += 1
	var report := {
		"suite": "R3 MVP Integrity Audit",
		"executed": checks.size(),
		"passed": passed_count,
		"failed": checks.size() - passed_count,
		"auditFindings": findings,
		"checks": checks
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify(report))
	gs.persistence_enabled = true
	quit(0 if passed else 1)
