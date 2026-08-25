extends SceneTree

const RUNS := 1000
const DAYS := 30
const COMMISSION_IDS := [
	"commission_01",
	"commission_02",
	"commission_03",
	"commission_04",
	"commission_05"
]


func _init() -> void:
	call_deferred("run")


func choose_hypothesis_from_public_evidence(gs: Node, artifact: Dictionary, campaign_day: int) -> String:
	# This policy deliberately hashes only fields exposed to the player. It models an
	# imperfect appraisal decision without consulting canonical or private fields.
	var observations: Array = []
	for evidence: Dictionary in artifact.get("evidence", []):
		observations.append({
			"clueType": evidence.get("clueType", ""),
			"observation": evidence.get("observation", ""),
			"supports": evidence.get("supports", []),
			"contradicts": evidence.get("contradicts", [])
		})
	var public_snapshot := {
		"day": campaign_day,
		"displayName": artifact.get("displayName", ""),
		"knownClues": artifact.get("knownClues", []),
		"observations": observations,
		"damageInstances": artifact.get("damageInstances", []),
		"cleanliness": artifact.get("cleanliness", 0.0),
		"mechanicalCondition": artifact.get("mechanicalCondition", 0.0),
		"restorationCost": artifact.get("restorationCost", 0.0)
	}
	var policy_roll := posmod(gs.stable_hash(JSON.stringify(public_snapshot)), 100)
	if artifact.get("knownClues", []).has("REPAIR_TRACE"):
		return "GENUINE_WITH_PERIOD_REPAIR" if policy_roll < 70 else "GENUINE_WITH_MODERN_REPAIR"
	if float(artifact.get("restorationCost", 0.0)) > 0.0:
		return "GENUINE_WITH_MODERN_REPAIR"
	if policy_roll < 48:
		return "GENUINE"
	if policy_roll < 65:
		return "GENUINE_WITH_PERIOD_REPAIR"
	if policy_roll < 78:
		return "GENUINE_WITH_MODERN_REPAIR"
	if policy_roll < 87:
		return "ASSEMBLED_FROM_PERIOD_PARTS"
	if policy_roll < 95:
		return "REPRODUCTION"
	return "FORGERY"


func simulate_run(gs: Node, seed_value: int, total_days: int) -> Dictionary:
	gs.reset_game()
	gs.persistence_enabled = false
	gs.master_seed = seed_value
	gs.rng.seed = seed_value
	gs.market_roster_day = 0
	var seen := {}
	var bidder_participation := {}
	var bidder_wins := {}
	var budget_violations := 0
	var duplicate_sales := 0
	var reserve_met := 0
	var no_sale := 0
	var stalls := 0
	var commission_attempts := 0
	var commission_failures := 0
	var commission_requirement_blocks := 0
	for campaign_day in range(1, total_days + 1):
		gs.day = campaign_day
		gs.market_roster_day = 0
		gs.generate_market_roster(true)
		var chosen_lot: Dictionary = {}
		for lot: Dictionary in gs.market_roster:
			seen[lot.specId] = true
			if not lot.sold and int(lot.price) <= gs.money and (chosen_lot.is_empty() or int(lot.price) < int(chosen_lot.price)):
				chosen_lot = lot
		if not chosen_lot.is_empty():
			gs.buy_market_lot(chosen_lot.lotId)
		elif gs.inventory.is_empty():
			stalls += 1
		if gs.inventory.is_empty():
			continue
		var artifact: Dictionary = gs.inventory[0]
		for clue_index in range(mini(3, artifact.possibleClues.size())):
			gs.inspect_clue(artifact, artifact.possibleClues[clue_index])
		if not artifact.damageInstances.is_empty():
			gs.clean(artifact, "soft_brush")
		gs.authenticate(artifact)
		var public_hypothesis := choose_hypothesis_from_public_evidence(gs, artifact, campaign_day)
		gs.choose_hypothesis(artifact, public_hypothesis)
		gs.accept_hypothesis(artifact)
		if campaign_day % 6 == 0:
			var completed_commissions: int = int(gs.statistics.get("commissions", 0))
			if completed_commissions < COMMISSION_IDS.size():
				commission_attempts += 1
				var commission_result: Dictionary = gs.complete_commission_from_artifact(
					COMMISSION_IDS[completed_commissions], artifact.get("uniqueId", "")
				)
				if not commission_result.get("ok", false):
					if String(commission_result.get("code", "")) in ["COMMISSION_REQUIREMENTS_NOT_MET", "ARTIFACT_ALREADY_COMMISSIONED", "COMMISSION_ALREADY_COMPLETED", "ARTIFACT_NOT_OWNED", "CASE_ARTIFACT_LOCKED"]:
						commission_requirement_blocks += 1
					else:
						commission_failures += 1
		var value: int = gs.appraise(artifact)
		var reserve_factor := 0.58 + float(posmod(gs.stable_hash("reserve|%d|%d" % [seed_value, campaign_day]), 37)) / 100.0
		var disclosure := "LIKELY" if artifact.get("knownClues", []).size() >= 3 else "UNCERTAIN"
		gs.list_auction(artifact, maxi(1, int(value * 0.48)), maxi(1, int(value * reserve_factor)), artifact.confidence, disclosure)
		var pending_creation: Dictionary = gs.create_pending_auction(artifact)
		var frozen_result: Dictionary = gs.pending_auction.get("result", {}).duplicate(true)
		var result: Dictionary = gs.commit_pending_auction(String(pending_creation.get("transactionId", "")))
		for participant: Dictionary in result.get("participants", []):
			bidder_participation[participant.id] = int(bidder_participation.get(participant.id, 0)) + 1
		for participant: Dictionary in frozen_result.get("participants", []):
			if int(participant.maxBid) > int(participant.budget):
				budget_violations += 1
		for bid: Dictionary in frozen_result.get("bids", []):
			if int(bid.amount) > int(bid.budget):
				budget_violations += 1
		if result.get("reserve_met", false):
			reserve_met += 1
			var winner: String = result.get("winnerId", "")
			bidder_wins[winner] = int(bidder_wins.get(winner, 0)) + 1
			var duplicate: Dictionary = gs.sell(artifact)
			if duplicate.get("sale_status", "") != "ALREADY_RECORDED":
				duplicate_sales += 1
		else:
			no_sale += 1
		gs.current_event_id = gs.deterministic_event_id(campaign_day)
		gs.execute_event(gs.current_event_id, false)
	var finite := not is_nan(float(gs.money)) and not is_inf(float(gs.money)) and not is_nan(float(gs.statistics.profit)) and not is_inf(float(gs.statistics.profit))
	return {
		"seed": seed_value, "days": total_days, "cash": gs.money, "reputation": gs.reputation,
		"purchases": int(gs.statistics.purchases), "sales": int(gs.statistics.sales),
		"noSales": no_sale, "profit": int(gs.statistics.profit), "commissions": int(gs.statistics.commissions),
		"uniqueArtifacts": seen.size(), "reserveMet": reserve_met, "stalls": stalls,
		"commissionAttempts": commission_attempts, "commissionFailures": commission_failures, "commissionRequirementBlocks": commission_requirement_blocks,
		"budgetViolations": budget_violations, "duplicateSales": duplicate_sales, "finite": finite,
		"bidderParticipation": bidder_participation, "bidderWins": bidder_wins
	}


func percentile(sorted_values: Array, fraction: float) -> int:
	if sorted_values.is_empty():
		return 0
	var index := clampi(int(round((sorted_values.size() - 1) * fraction)), 0, sorted_values.size() - 1)
	return int(sorted_values[index])


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var runs: Array = []
	var cash_values: Array = []
	var total_purchases := 0
	var total_sales := 0
	var total_no_sales := 0
	var total_profit := 0
	var total_unique := 0
	var total_reserve_met := 0
	var total_stalls := 0
	var total_commission_attempts := 0
	var total_commission_failures := 0
	var total_commission_requirement_blocks := 0
	var total_budget_violations := 0
	var total_duplicate_sales := 0
	var non_finite := 0
	var bankrupt_or_stalled := 0
	var participation := {}
	var wins := {}
	for run_index in range(RUNS):
		var result: Dictionary = simulate_run(gs, 510000 + run_index * 101, DAYS)
		runs.append(result)
		cash_values.append(result.cash)
		total_purchases += int(result.purchases)
		total_sales += int(result.sales)
		total_no_sales += int(result.noSales)
		total_profit += int(result.profit)
		total_unique += int(result.uniqueArtifacts)
		total_reserve_met += int(result.reserveMet)
		total_stalls += int(result.stalls)
		total_commission_attempts += int(result.commissionAttempts)
		total_commission_failures += int(result.commissionFailures)
		total_commission_requirement_blocks += int(result.commissionRequirementBlocks)
		total_budget_violations += int(result.budgetViolations)
		total_duplicate_sales += int(result.duplicateSales)
		if not result.finite:
			non_finite += 1
		if int(result.cash) <= 0 or int(result.sales) == 0:
			bankrupt_or_stalled += 1
		for bidder_id: String in result.bidderParticipation.keys():
			participation[bidder_id] = int(participation.get(bidder_id, 0)) + int(result.bidderParticipation[bidder_id])
		for bidder_id: String in result.bidderWins.keys():
			wins[bidder_id] = int(wins.get(bidder_id, 0)) + int(result.bidderWins[bidder_id])
	cash_values.sort()
	var hundred_day_samples: Array = []
	for sample_index in range(10):
		hundred_day_samples.append(simulate_run(gs, 810000 + sample_index * 313, 100))
	var total_listings := total_sales + total_no_sales
	var summary := {
		"runs": RUNS, "daysPerRun": DAYS,
		"bankruptcyOrNoSaleStallRate": float(bankrupt_or_stalled) / float(RUNS),
		"cash": {"p10": percentile(cash_values, 0.10), "median": percentile(cash_values, 0.50), "p90": percentile(cash_values, 0.90)},
		"averages": {"purchases": float(total_purchases) / RUNS, "sales": float(total_sales) / RUNS, "noSales": float(total_no_sales) / RUNS, "profit": float(total_profit) / RUNS, "uniqueArtifactsSeen": float(total_unique) / RUNS, "stalls": float(total_stalls) / RUNS},
		"reserveMetRate": 0.0 if total_listings == 0 else float(total_reserve_met) / float(total_listings),
		"bidderParticipation": participation, "bidderWins": wins,
		"commissionAttempts": total_commission_attempts,
		"commissionRequirementBlocks": total_commission_requirement_blocks,
		"invariants": {"nonFinite": non_finite, "budgetViolations": total_budget_violations, "duplicateSales": total_duplicate_sales, "commissionFailures": total_commission_failures},
		"thresholds": {"bankruptcyOrNoSaleStallRateMax": 0.20, "budgetViolations": 0, "duplicateSales": 0, "commissionFailures": 0, "nonFinite": 0, "minimumMedianCash": 100},
		"hundredDaySamples": hundred_day_samples,
		"sampleRuns": runs.slice(0, 10)
	}
	var passed := non_finite == 0 and total_budget_violations == 0 and total_duplicate_sales == 0 and total_commission_failures == 0 and total_commission_attempts > 0 and float(summary.bankruptcyOrNoSaleStallRate) <= 0.20 and int(summary.cash.median) >= 100
	summary["passed"] = passed
	var file := FileAccess.open("res://qa/R3_ECONOMY_SIMULATION.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "  "))
	file.close()
	print(JSON.stringify(summary))
	gs.persistence_enabled = true
	quit(0 if passed else 1)
