extends SceneTree

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func fixture(gs: Node, spec_id: String, seed: int, context: String, confidence: float, condition: float, provenance_known: bool) -> Dictionary:
	var artifact: Dictionary = gs.new_artifact(spec_id, seed, context)
	artifact.confidence = confidence
	artifact.cleanliness = condition
	artifact.surfaceCondition = condition
	artifact.mechanicalCondition = condition
	artifact.knownClues = ["PROVENANCE"] if provenance_known else []
	artifact.listing = {"starting": 1, "reserve": 1, "confidence": confidence, "disclosure": "UNCERTAIN"}
	return artifact


func disclosure_factors(gs: Node, artifact: Dictionary, bidder: Dictionary) -> Dictionary:
	var factors := {}
	for disclosure in ["UNCERTAIN", "LIKELY", "CERTAIN"]:
		artifact.listing.disclosure = disclosure
		factors[disclosure] = float(gs.auction_scrutiny_factors(artifact, bidder).disclosure)
	return factors


func localized_reason_shape_ok(result: Dictionary) -> bool:
	var allowed := ["RESERVE_TOO_HIGH", "PROVENANCE_UNCERTAIN", "PROVENANCE_STRONG", "CONDITION_RISK", "CONDITION_GOOD", "DISCLOSURE_UNCLEAR", "DISCLOSURE_CLEAR"]
	var tags: Array = result.get("reasonTags", [])
	if tags.size() > 2:
		return false
	var categories := {}
	for tag: Dictionary in tags:
		if not allowed.has(String(tag.get("code", ""))):
			return false
		categories[String(tag.get("category", ""))] = true
	return categories.size() == tags.size()


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.reset_game()
	gs.persistence_enabled = false
	gs.current_stage = 1
	var bidder: Dictionary = registry.get_bidder(3).duplicate(true)
	bidder.budget = 999999999

	# The three support fixtures differ only in public report confidence,
	# provenance-known state and visible condition.
	var low := fixture(gs, "artifact_061", 610001, "disclosure_low", 0.24, 42.0, false)
	var medium := fixture(gs, "artifact_061", 610002, "disclosure_medium", 0.66, 72.0, true)
	var high := fixture(gs, "artifact_061", 610003, "disclosure_high", 0.94, 100.0, true)
	var support_evidence := {}
	var support_contract_ok := true
	for row: Dictionary in [
		{"artifact": low, "band": "LOW", "balanced": "UNCERTAIN", "over": ["LIKELY", "CERTAIN"], "under": []},
		{"artifact": medium, "band": "MEDIUM", "balanced": "LIKELY", "over": ["CERTAIN"], "under": ["UNCERTAIN"]},
		{"artifact": high, "band": "HIGH", "balanced": "CERTAIN", "over": [], "under": ["UNCERTAIN", "LIKELY"]}
	]:
		var artifact: Dictionary = row.artifact
		var band := String(row.band)
		var balanced := String(row.balanced)
		var balanced_state: Dictionary = gs.listing_public_support(artifact, balanced)
		support_contract_ok = support_contract_ok and balanced_state == {"band": band, "risk": "BALANCED"}
		for disclosure: String in row.over:
			support_contract_ok = support_contract_ok and gs.listing_public_support(artifact, disclosure) == {"band": band, "risk": "OVERCLAIM"}
		for disclosure: String in row.under:
			support_contract_ok = support_contract_ok and gs.listing_public_support(artifact, disclosure) == {"band": band, "risk": "UNDERCLAIM"}
		support_evidence[band] = {
			"uncertain": gs.listing_public_support(artifact, "UNCERTAIN"),
			"likely": gs.listing_public_support(artifact, "LIKELY"),
			"certain": gs.listing_public_support(artifact, "CERTAIN")
		}
	record(
		"AUCTION-BALANCE-SUPPORT-01",
		"Public confidence, known provenance and visible condition produce presentation-safe low, medium and high support bands with calibrated claim risk",
		support_contract_ok,
		support_evidence
	)

	var low_factors := disclosure_factors(gs, low, bidder)
	var medium_factors := disclosure_factors(gs, medium, bidder)
	var high_factors := disclosure_factors(gs, high, bidder)
	var factor_order_ok: bool = float(low_factors.UNCERTAIN) > float(low_factors.LIKELY) and float(low_factors.LIKELY) > float(low_factors.CERTAIN) \
		and float(medium_factors.LIKELY) > float(medium_factors.UNCERTAIN) and float(medium_factors.LIKELY) > float(medium_factors.CERTAIN) \
		and float(high_factors.CERTAIN) > float(high_factors.LIKELY) and float(high_factors.LIKELY) > float(high_factors.UNCERTAIN)
	var low_scrutiny: Dictionary = medium.duplicate(true)
	low_scrutiny.listing.disclosure = "CERTAIN"
	low_scrutiny.auctionProfile = low_scrutiny.get("auctionProfile", {}).duplicate(true)
	low_scrutiny.auctionProfile.disclosureScrutiny = 0.25
	var high_scrutiny: Dictionary = low_scrutiny.duplicate(true)
	high_scrutiny.auctionProfile.disclosureScrutiny = 1.0
	var authored_scrutiny_active: bool = gs.auction_disclosure_factor(low_scrutiny) > gs.auction_disclosure_factor(high_scrutiny) and gs.listing_public_support(low_scrutiny, "CERTAIN") == gs.listing_public_support(high_scrutiny, "CERTAIN")
	record(
		"AUCTION-BALANCE-DISCLOSURE-01",
		"Uncertain, likely and certain are claim strengths: low support favors caution, medium support favors likely, and high support favors certain without a double multiplier",
		factor_order_ok and authored_scrutiny_active,
		{"low": low_factors, "medium": medium_factors, "high": high_factors, "authoredScrutiny": {"quarter": gs.auction_disclosure_factor(low_scrutiny), "full": gs.auction_disclosure_factor(high_scrutiny)}}
	)

	# A later Stage must never amplify an earned positive disclosure bonus. Only
	# unsupported claim pressure consumes the canonical Stage multiplier.
	var positive_stage_factors := {}
	var negative_stage_factors := {}
	high.listing.disclosure = "CERTAIN"
	low.listing.disclosure = "CERTAIN"
	for stage_id: int in [1, 5, 10]:
		gs.current_stage = stage_id
		positive_stage_factors[str(stage_id)] = gs.auction_disclosure_factor(high)
		negative_stage_factors[str(stage_id)] = gs.auction_disclosure_factor(low)
	var positive_stage_invariant: bool = is_equal_approx(float(positive_stage_factors["1"]), float(positive_stage_factors["5"])) \
		and is_equal_approx(float(positive_stage_factors["5"]), float(positive_stage_factors["10"]))
	var negative_stage_scaled: bool = float(negative_stage_factors["1"]) > float(negative_stage_factors["5"]) \
		and float(negative_stage_factors["5"]) > float(negative_stage_factors["10"])
	gs.current_stage = 1
	record(
		"AUCTION-BALANCE-DISCLOSURE-02",
		"Supported disclosure bonuses stay Stage-independent while unsupported claims alone receive the 7-percent Stage pressure",
		positive_stage_invariant and negative_stage_scaled,
		{"supportedCertain": positive_stage_factors, "unsupportedCertain": negative_stage_factors}
	)

	# Mutating every sensitive hidden field must leave support, disclosure pressure,
	# compact causes and the listing-independent variance schedule unchanged.
	medium.listing.disclosure = "CERTAIN"
	var hidden_variant: Dictionary = medium.duplicate(true)
	hidden_variant.authenticityTruth = "FORGERY"
	hidden_variant.trueRarity = 99.0
	hidden_variant.trueHistoricalSignificance = 0.01
	hidden_variant.trueMarketBaseline = 1
	hidden_variant.baseValue = 999999
	hidden_variant.originalParts = 0
	hidden_variant.replacementParts = 99
	var reason_outcome := {"opening": 1, "reserve": 1, "hammer": 500, "reserve_met": true}
	var reasons_original: Array = gs.auction_public_reason_tags(medium, bidder, "DROPOUT", reason_outcome)
	var reasons_hidden: Array = gs.auction_public_reason_tags(hidden_variant, bidder, "DROPOUT", reason_outcome)
	var public_invariant: bool = gs.listing_public_support(medium, "CERTAIN") == gs.listing_public_support(hidden_variant, "CERTAIN") \
		and is_equal_approx(gs.auction_disclosure_factor(medium), gs.auction_disclosure_factor(hidden_variant)) \
		and reasons_original == reasons_hidden \
		and reasons_original.map(func(tag: Dictionary): return tag.get("code", "")).has("DISCLOSURE_UNCLEAR")
	record(
		"AUCTION-BALANCE-PRIVACY-01",
		"Disclosure support, calibration and causal reasons are invariant to hidden truth, rarity, value and originality changes",
		public_invariant and localized_reason_shape_ok({"reasonTags": reasons_original}),
		{"support": gs.listing_public_support(medium, "CERTAIN"), "factor": gs.auction_disclosure_factor(medium), "reasons": reasons_original}
	)

	var bidder_rows: Array = []
	for bidder_index in range(6):
		bidder_rows.append(registry.get_bidder(bidder_index).duplicate(true))
	var rng_artifact := fixture(gs, "artifact_067", 670067, "same_variance", 0.72, 82.0, true)
	var rng_variants: Array = []
	for listing in [
		{"starting": 10, "reserve": 20, "confidence": 0.72, "disclosure": "UNCERTAIN"},
		{"starting": 30, "reserve": 40, "confidence": 0.72, "disclosure": "LIKELY"},
		{"starting": 50, "reserve": 60, "confidence": 0.72, "disclosure": "CERTAIN"}
	]:
		var variant: Dictionary = rng_artifact.duplicate(true)
		variant.listing = listing
		rng_variants.append(gs.auction_bidder_variances(variant, bidder_rows))
	var rng_invariant: bool = rng_variants[0] == rng_variants[1] and rng_variants[1] == rng_variants[2]
	var global_rng_before: int = gs.rng.state
	var deterministic_a: Dictionary = gs.auction_with_bidders(rng_artifact, bidder_rows)
	var deterministic_b: Dictionary = gs.auction_with_bidders(rng_artifact, bidder_rows)
	var global_rng_after: int = gs.rng.state
	record(
		"AUCTION-BALANCE-RNG-01",
		"Price and disclosure counterfactuals share bidder variance while repeated auctions remain deterministic and do not consume the global RNG",
		rng_invariant and deterministic_a == deterministic_b and global_rng_before == global_rng_after,
		{"variance": rng_variants[0], "repeatEqual": deterministic_a == deterministic_b, "globalRngUnchanged": global_rng_before == global_rng_after}
	)

	var no_bid: Dictionary = rng_artifact.duplicate(true)
	no_bid.listing = {"starting": 100, "reserve": 200, "confidence": 0.72, "disclosure": "LIKELY"}
	var zero_budget_bidders: Array = []
	for bidder_index in range(2):
		var zero_bidder: Dictionary = bidder_rows[bidder_index].duplicate(true)
		zero_bidder.budget = 0
		zero_budget_bidders.append(zero_bidder)
	var no_bid_result: Dictionary = gs.auction_with_bidders(no_bid, zero_budget_bidders)
	var no_bid_ok: bool = int(no_bid_result.opening) == 100 and int(no_bid_result.hammer) == 0 and no_bid_result.bids.is_empty() and String(no_bid_result.winnerId).is_empty() and not bool(no_bid_result.reserve_met) and no_bid_result.sale_status == "NO_SALE"
	record(
		"AUCTION-BALANCE-HAMMER-01",
		"An opening term is not a bid: a no-bid auction reports hammer zero and remains a no-sale",
		no_bid_ok and localized_reason_shape_ok(no_bid_result),
		{"opening": no_bid_result.opening, "hammer": no_bid_result.hammer, "sale": no_bid_result.sale_status, "bids": no_bid_result.bids, "reasons": no_bid_result.reasonTags}
	)

	# Exercise all three fixed price policies over diverse specs and seeds. Each
	# controlled triple shares artifact truth, bidders and variance.
	var policies := {
		"FAST": {"starting": 0.50, "reserve": 0.60},
		"BALANCED": {"starting": 0.60, "reserve": 0.72},
		"HIGH": {"starting": 0.68, "reserve": 0.82}
	}
	var price_stats := {
		"FAST": {"sales": 0, "hammerTotal": 0, "hammerRatioTotal": 0.0, "soldHammers": []},
		"BALANCED": {"sales": 0, "hammerTotal": 0, "hammerRatioTotal": 0.0, "soldHammers": []},
		"HIGH": {"sales": 0, "hammerTotal": 0, "hammerRatioTotal": 0.0, "soldHammers": []}
	}
	var deterministic_all := true
	var variance_all := true
	var matched_upside_cases := 0
	var matched_upside_failures: Array = []
	var fixture_count := 0
	var spec_ids := ["artifact_001", "artifact_017", "artifact_061", "artifact_064", "artifact_067", "artifact_070", "artifact_073", "artifact_076", "artifact_079", "artifact_080"]
	var legacy_pressure_neutral := true
	for spec_index in range(spec_ids.size()):
		for seed_offset in range(6):
			fixture_count += 1
			var seed := 810000 + spec_index * 100 + seed_offset
			var base: Dictionary = fixture(gs, String(spec_ids[spec_index]), seed, "price_%02d_%02d" % [spec_index, seed_offset], 0.72, 82.0, true)
			base.playerHypothesis = gs.truth_to_hypothesis(base.authenticityTruth)
			var appraisal: int = int(gs.appraise(base))
			if not base.get("auctionProfile", {}).has("reserveStrategy"):
				legacy_pressure_neutral = legacy_pressure_neutral and is_equal_approx(gs.auction_reserve_pressure_factor(base, int(float(appraisal) * 0.82), appraisal), 1.0)
			var controlled_bidders: Array = []
			for bidder_index in range(2):
				var controlled: Dictionary = registry.get_bidder((bidder_index + spec_index) % registry.bidders.size()).duplicate(true)
				controlled.budget = int(float(appraisal) * (0.82 + float(bidder_index) * 0.18))
				controlled_bidders.append(controlled)
			var policy_results := {}
			var first_variance: Array = []
			for policy_id in ["FAST", "BALANCED", "HIGH"]:
				var policy: Dictionary = policies[policy_id]
				var listed: Dictionary = base.duplicate(true)
				listed.listing = {
					"starting": int(float(appraisal) * float(policy.starting)),
					"reserve": int(float(appraisal) * float(policy.reserve)),
					"confidence": 0.72,
					"disclosure": "LIKELY"
				}
				var variances: Array = gs.auction_bidder_variances(listed, controlled_bidders)
				if first_variance.is_empty():
					first_variance = variances
				else:
					variance_all = variance_all and variances == first_variance
				var auction_result: Dictionary = gs.auction_with_bidders(listed, controlled_bidders)
				deterministic_all = deterministic_all and auction_result == gs.auction_with_bidders(listed, controlled_bidders)
				policy_results[policy_id] = auction_result
				if bool(auction_result.reserve_met):
					price_stats[policy_id].sales = int(price_stats[policy_id].sales) + 1
					price_stats[policy_id].hammerTotal = int(price_stats[policy_id].hammerTotal) + int(auction_result.hammer)
					price_stats[policy_id].hammerRatioTotal = float(price_stats[policy_id].hammerRatioTotal) + float(auction_result.hammer) / float(appraisal)
					price_stats[policy_id].soldHammers.append(int(auction_result.hammer))
			if bool(policy_results.FAST.reserve_met) and bool(policy_results.BALANCED.reserve_met) and bool(policy_results.HIGH.reserve_met):
				matched_upside_cases += 1
				var this_upside_ok: bool = int(policy_results.FAST.hammer) <= int(policy_results.BALANCED.hammer) and int(policy_results.BALANCED.hammer) <= int(policy_results.HIGH.hammer)
				if not this_upside_ok:
					matched_upside_failures.append({"appraisal": appraisal, "fast": policy_results.FAST.hammer, "balanced": policy_results.BALANCED.hammer, "high": policy_results.HIGH.hammer})
	var fast_sales := int(price_stats.FAST.sales)
	var balanced_sales := int(price_stats.BALANCED.sales)
	var high_sales := int(price_stats.HIGH.sales)
	var sale_order_ok := fast_sales >= balanced_sales and balanced_sales >= high_sales
	var averages := {}
	var average_ratios := {}
	for policy_id in ["FAST", "BALANCED", "HIGH"]:
		var sales := int(price_stats[policy_id].sales)
		averages[policy_id] = 0.0 if sales == 0 else float(price_stats[policy_id].hammerTotal) / float(sales)
		average_ratios[policy_id] = 0.0 if sales == 0 else float(price_stats[policy_id].hammerRatioTotal) / float(sales)
	var aggregate_upside_ok: bool = high_sales > 0 and fast_sales > 0 and float(average_ratios.FAST) < float(average_ratios.BALANCED) and float(average_ratios.BALANCED) < float(average_ratios.HIGH)
	record(
		"AUCTION-BALANCE-PRICE-01",
		"Across diverse artifacts and seeds, fast sale rate is at least balanced, balanced is at least high, and higher reserves provide sold-hammer upside under shared bidder variance",
		fixture_count == 60 and deterministic_all and variance_all and legacy_pressure_neutral and sale_order_ok and matched_upside_cases > 0 and aggregate_upside_ok,
		{"fixtures": fixture_count, "sales": {"fast": fast_sales, "balanced": balanced_sales, "high": high_sales}, "averageSoldHammer": averages, "averageSoldHammerRatio": average_ratios, "matchedUpsideCases": matched_upside_cases, "matchedFailures": matched_upside_failures, "deterministic": deterministic_all, "sharedVariance": variance_all, "legacyReservePressureNeutral": legacy_pressure_neutral}
	)

	var passed := results.filter(func(result: Dictionary): return bool(result.passed)).size()
	var report := {"suite": "R3 Auction Listing Balance", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "skipped": 0, "tests": results}
	var output := FileAccess.open("res://qa/R3_AUCTION_BALANCE_TESTS.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	quit(0 if passed == results.size() else 1)
