extends SceneTree

## R3 M1 integrity regression suite.
##
## This suite deliberately targets public contracts and adversarial transitions that
## count/reachability tests do not cover. Missing v2 APIs are reported as ordinary
## failed assertions so the suite remains parseable and runnable during TDD.

const SILENT_RADIO_CANONICAL := "hyp.silent_radio.genuine_with_period_condenser_repair"
const PERFECT_FAKE_FOREIGN_EVIDENCE := "src.perfect_fake.artifact.casting_serial_continuity"

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, condition: bool, evidence: Variant) -> void:
	results.append({
		"id": id,
		"name": name,
		"executed": true,
		"passed": condition,
		"evidence": evidence
	})


func payload_fingerprint(gs: Node) -> String:
	return JSON.stringify(gs.save_payload())


func call_dictionary(target: Object, method_name: String, arguments: Array = []) -> Dictionary:
	if not target.has_method(method_name):
		return {
			"ok": false,
			"code": "MISSING_METHOD",
			"method": method_name,
			"contractMissing": true
		}
	var value: Variant = target.callv(method_name, arguments)
	if value is Dictionary:
		return value
	return {
		"ok": false,
		"code": "INVALID_RETURN_TYPE",
		"method": method_name,
		"actualType": type_string(typeof(value)),
		"actualValue": str(value)
	}


func unlock_act_one(gs: Node) -> void:
	gs.campaign_state.completedCases["prologue_clock"] = true
	gs.refresh_campaign_progress()


func begin_act_one_case(gs: Node, case_id: String = "silent_radio") -> Dictionary:
	gs.reset_game()
	gs.persistence_enabled = false
	unlock_act_one(gs)
	return gs.begin_case(case_id)


func evidence_rows(public_state: Dictionary) -> Array:
	for key: String in ["evidence", "availableEvidence", "discoveredEvidence"]:
		var candidate: Variant = public_state.get(key, [])
		if candidate is Array and not candidate.is_empty() and candidate[0] is Dictionary:
			return candidate
	return []


func discovered_rows(public_state: Dictionary) -> Array:
	var discovered: Array = []
	for row: Dictionary in evidence_rows(public_state):
		if bool(row.get("discovered", false)):
			discovered.append(row)
	return discovered


func find_substantiation_pairs(rows: Array) -> Dictionary:
	var by_source := {}
	for row: Dictionary in rows:
		var source_id: String = String(row.get("sourceId", ""))
		if source_id.is_empty():
			continue
		if not by_source.has(source_id):
			by_source[source_id] = []
		by_source[source_id].append(String(row.get("id", "")))

	var same_source: Array = []
	for ids: Array in by_source.values():
		if ids.size() >= 2:
			same_source = [ids[0], ids[1]]
			break
	# A duplicated citation is the minimal same-source adversarial fixture. The
	# evaluator must deduplicate it and must not mistake two array entries for two
	# independent sources even when authored data has one evidence row per source.
	if same_source.is_empty() and not by_source.is_empty():
		var first_ids: Array = by_source[by_source.keys()[0]]
		same_source = [first_ids[0], first_ids[0]]

	var independent: Array = []
	var source_ids: Array = by_source.keys()
	if source_ids.size() >= 2:
		independent = [by_source[source_ids[0]][0], by_source[source_ids[1]][0]]
	return {
		"sameSource": same_source,
		"independent": independent,
		"sources": by_source
	}


func make_eligible_lot(gs: Node, spec_id: String, seed_value: int, instance_id: String) -> Dictionary:
	var artifact: Dictionary = gs.new_artifact(spec_id, seed_value, instance_id)
	for clue: String in artifact.get("possibleClues", []).slice(0, 2):
		gs.inspect_clue(artifact, clue)
	gs.choose_hypothesis(artifact, gs.truth_to_hypothesis(artifact.authenticityTruth))
	gs.authenticate(artifact)
	gs.accept_hypothesis(artifact)
	artifact.knownClues = artifact.knownClues.slice(0, maxi(2, artifact.knownClues.size()))
	if artifact.knownClues.size() < 2:
		artifact.knownClues = ["MATERIAL", "SERIAL_PATTERN"]
	artifact.historicalIntegrity = maxf(60.0, float(artifact.historicalIntegrity))
	gs.list_auction(artifact, 1, 1, float(artifact.confidence), "LIKELY")
	gs.inventory.append(artifact)
	return artifact


func bidder_fixture(id: String, dropout_behavior: String, aggression: float = 0.6) -> Dictionary:
	return {
		"id": id,
		"name": id,
		"budget": 5000,
		"preferredCategories": ["mechanical_instruments", "vintage_audio", "optical_devices", "decorative_objects", "ceramics", "scientific_instruments", "office_machines", "telephony"],
		"rarityBias": 1.0,
		"conditionBias": 1.0,
		"originalityBias": 1.0,
		"authenticityBias": 1.0,
		"riskTolerance": 0.7,
		"competitionAggression": aggression,
		"dropoutBehavior": dropout_behavior
	}


func has_consecutive_self_bid(bids: Array) -> bool:
	for index in range(1, bids.size()):
		if String(bids[index - 1].get("bidderId", "")) == String(bids[index].get("bidderId", "")):
			return true
	return false


func count_bids_for(bids: Array, bidder_id: String) -> int:
	var count := 0
	for bid: Dictionary in bids:
		if String(bid.get("bidderId", "")) == bidder_id:
			count += 1
	return count


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	gs.persistence_enabled = false

	# Deprecated caller-selected outcomes must fail closed even when the old
	# implementation would otherwise have enough state to complete the case.
	var legacy_artifact: Dictionary = begin_act_one_case(gs)
	for clue: String in ["MATERIAL", "SERIAL_PATTERN"]:
		gs.inspect_clue(legacy_artifact, clue)
	gs.choose_hypothesis(legacy_artifact, "GENUINE_WITH_PERIOD_REPAIR")
	var legacy_before := payload_fingerprint(gs)
	var legacy_result := call_dictionary(gs, "resolve_case", ["silent_radio", "masterful"])
	var legacy_after := payload_fingerprint(gs)
	record(
		"M1-CASE-LEGACY-01",
		"Deprecated caller outcome fails closed with zero state delta",
		not bool(legacy_result.get("ok", true))
			and String(legacy_result.get("code", "")) == "DEPRECATED_OUTCOME_ARGUMENT"
			and legacy_before == legacy_after,
		{"result": legacy_result, "stateDelta": legacy_before != legacy_after}
	)

	# Public evidence citations: undiscovered and cross-case references are both
	# rejected without mutating the campaign or artifact.
	var evidence_artifact: Dictionary = begin_act_one_case(gs)
	var public_state := call_dictionary(gs, "get_case_public_state", ["silent_radio"])
	var initial_rows := evidence_rows(public_state)
	var undiscovered_id := "MATERIAL"
	if not initial_rows.is_empty():
		undiscovered_id = String(initial_rows[0].get("id", undiscovered_id))
	var evidence_before := payload_fingerprint(gs)
	var undiscovered_result := call_dictionary(gs, "evaluate_case_submission", [
		"silent_radio", SILENT_RADIO_CANONICAL, [undiscovered_id]
	])
	var evidence_after := payload_fingerprint(gs)
	record(
		"M1-EVIDENCE-01",
		"Undiscovered evidence citation is rejected with zero state delta",
		not bool(undiscovered_result.get("ok", true)) and evidence_before == evidence_after,
		{"evidenceId": undiscovered_id, "result": undiscovered_result, "stateDelta": evidence_before != evidence_after}
	)

	var cross_case_id := PERFECT_FAKE_FOREIGN_EVIDENCE
	var cross_before := payload_fingerprint(gs)
	var cross_result := call_dictionary(gs, "evaluate_case_submission", [
		"silent_radio", SILENT_RADIO_CANONICAL, [cross_case_id]
	])
	var cross_after := payload_fingerprint(gs)
	record(
		"M1-EVIDENCE-02",
		"Cross-case evidence citation is rejected with zero state delta",
		not bool(cross_result.get("ok", true)) and cross_before == cross_after,
		{"evidenceId": cross_case_id, "result": cross_result, "stateDelta": cross_before != cross_after}
	)

	# Discover the authored dependency graph through public APIs, proving tool
	# requirements instead of bypassing them. Duplicate citations must dedupe,
	# three independent required sources are credible, and all four are masterful.
	var discovery_results: Array = []
	for _pass in range(16):
		var progressed := false
		for row_value: Variant in call_dictionary(gs, "get_case_public_state", ["silent_radio"]).get("evidence", []):
			if not row_value is Dictionary:
				continue
			var row: Dictionary = row_value
			if bool(row.get("discovered", false)) or not bool(row.get("unlocked", false)):
				continue
			var required_tools: Array = row.get("requiredTools", [])
			if not required_tools.is_empty():
				gs.select_tool(String(required_tools[0]))
			var evidence_id: String = String(row.get("id", ""))
			var discovery := call_dictionary(gs, "discover_case_evidence", ["silent_radio", evidence_id])
			discovery_results.append(discovery)
			progressed = progressed or bool(discovery.get("ok", false))
		if not progressed:
			break
	public_state = call_dictionary(gs, "get_case_public_state", ["silent_radio"])
	var found_rows := discovered_rows(public_state)
	var required_ids: Array = gs.case_definition("silent_radio").get("resolution", {}).get("required_source_refs", []).duplicate()
	var duplicate_ids: Array = [required_ids[0], required_ids[0]] if not required_ids.is_empty() else []
	var credible_ids: Array = required_ids.slice(0, 3)
	var duplicate_result: Dictionary = {"ok": false, "code": "REQUIRED_NOT_AVAILABLE", "substantiated": false, "independentSourceCount": 0}
	var credible_result: Dictionary = {"ok": false, "code": "REQUIRED_NOT_AVAILABLE", "substantiated": false, "independentSourceCount": 0}
	var masterful_result: Dictionary = {"ok": false, "code": "REQUIRED_NOT_AVAILABLE", "substantiated": false, "independentSourceCount": 0}
	var substantiation_before := payload_fingerprint(gs)
	if duplicate_ids.size() == 2:
		duplicate_result = call_dictionary(gs, "evaluate_case_submission", ["silent_radio", SILENT_RADIO_CANONICAL, duplicate_ids])
	if credible_ids.size() == 3:
		credible_result = call_dictionary(gs, "evaluate_case_submission", ["silent_radio", SILENT_RADIO_CANONICAL, credible_ids])
	if required_ids.size() == 4:
		masterful_result = call_dictionary(gs, "evaluate_case_submission", ["silent_radio", SILENT_RADIO_CANONICAL, required_ids])
	var substantiation_after := payload_fingerprint(gs)
	record(
		"M1-EVIDENCE-03",
		"Authored citation thresholds dedupe duplicates and require three/four independent sources for credible/masterful",
		required_ids.size() == 4
			and found_rows.size() == 6
			and String(duplicate_result.get("outcome", "")) == "reviewed_with_mentor"
			and duplicate_result.get("citedEvidenceIds", []).size() == 1
			and String(credible_result.get("outcome", "")) == "credible"
			and int(credible_result.get("independentSourceCount", 0)) == 3
			and not bool(credible_result.get("substantiated", true))
			and String(masterful_result.get("outcome", "")) == "masterful"
			and int(masterful_result.get("independentSourceCount", 0)) == 4
			and bool(masterful_result.get("substantiated", false))
			and substantiation_before == substantiation_after,
		{
			"discovery": discovery_results,
			"requiredIds": required_ids,
			"duplicateResult": duplicate_result,
			"credibleResult": credible_result,
			"masterfulResult": masterful_result,
			"stateDelta": substantiation_before != substantiation_after
		}
	)

	var v2_before := payload_fingerprint(gs)
	var v2_result: Dictionary = {"ok": false, "code": "REQUIRED_NOT_AVAILABLE"}
	if required_ids.size() == 4:
		v2_result = call_dictionary(gs, "resolve_case_v2", [
			"silent_radio", SILENT_RADIO_CANONICAL, required_ids
		])
	record(
		"M1-CASE-V2-01",
		"Masterful authored evidence resolves through the v2 contract",
		required_ids.size() == 4
			and bool(v2_result.get("ok", false))
			and String(v2_result.get("outcome", "")) == "masterful"
			and gs.campaign_state.completedCases.has("silent_radio")
			and payload_fingerprint(gs) != v2_before,
		{"result": v2_result, "completed": gs.campaign_state.completedCases.has("silent_radio")}
	)

	# An unresolved campaign artifact is a single persistent obligation, not a
	# free market lot that can be sold, reissued, and sold again.
	var case_artifact := begin_act_one_case(gs)
	var first_case_id: String = String(case_artifact.get("uniqueId", ""))
	var inventory_before_reissue: int = gs.inventory.size()
	var second_issue: Dictionary = gs.begin_case("silent_radio")
	var stable_issue: bool = not second_issue.is_empty() \
		and String(second_issue.get("uniqueId", "")) == first_case_id \
		and gs.inventory.size() == inventory_before_reissue
	gs.choose_hypothesis(case_artifact, "GENUINE_WITH_PERIOD_REPAIR")
	gs.list_auction(case_artifact, 1, 1, 0.9, "CERTAIN")
	var case_sale_before := payload_fingerprint(gs)
	var first_case_sale: Dictionary = gs.sell(case_artifact)
	var after_first_case_sale := payload_fingerprint(gs)
	var reissue_after_sale: Dictionary = gs.begin_case("silent_radio")
	var second_case_sale: Dictionary = gs.sell(case_artifact)
	var after_second_case_sale := payload_fingerprint(gs)
	var case_sale_blocked := not bool(first_case_sale.get("reserve_met", false)) \
		and String(first_case_sale.get("sale_status", "")).contains("CASE")
	record(
		"M1-CASE-ARTIFACT-01",
		"Case artifact cannot be duplicated, sold while unresolved, reissued, or resold",
		stable_issue
			and case_sale_blocked
			and case_sale_before == after_first_case_sale
			and not reissue_after_sale.is_empty()
			and String(reissue_after_sale.get("uniqueId", "")) == first_case_id
			and not bool(second_case_sale.get("reserve_met", false))
			and after_first_case_sale == after_second_case_sale,
		{
			"stableIssue": stable_issue,
			"firstSale": first_case_sale,
			"secondSale": second_case_sale,
			"inventory": gs.inventory.size(),
			"stateDeltaFirst": case_sale_before != after_first_case_sale,
			"stateDeltaSecond": after_first_case_sale != after_second_case_sale
		}
	)

	# Grand Reserve must preflight all selected IDs before committing any sale.
	gs.reset_game()
	gs.persistence_enabled = false
	gs.money = 100000
	gs.reputation = 100
	gs.campaign_state.workshopGrade = 5
	gs.campaign_state.museumTrust = 100
	for domain: String in gs.campaign_state.mastery.keys():
		gs.campaign_state.mastery[domain] = 20
	var lot_one := make_eligible_lot(gs, "artifact_001", 7101, "m1_gr_valid_1")
	var lot_two := make_eligible_lot(gs, "artifact_002", 7102, "m1_gr_valid_2")
	var spare_eligible := make_eligible_lot(gs, "artifact_003", 7103, "m1_gr_spare")
	gs.campaign_state.grandReserve.invited = true
	gs.campaign_state.grandReserve.selectedLotIds = [lot_one.uniqueId, lot_two.uniqueId, "m1_gr_missing_third"]
	var gr_precondition: bool = gs.eligible_final_lots().size() >= 3 and gs.inventory.has(spare_eligible)
	var gr_before := payload_fingerprint(gs)
	var gr_result: Dictionary = gs.run_grand_reserve()
	var gr_after := payload_fingerprint(gs)
	var gr_failed: bool = gr_result.is_empty() or not bool(gr_result.get("ok", true))
	record(
		"M1-GR-ATOMIC-01",
		"Invalid third Grand Reserve lot produces zero state delta",
		gr_precondition and gr_failed and gr_before == gr_after,
		{
			"precondition": gr_precondition,
			"result": gr_result,
			"stateDelta": gr_before != gr_after,
			"inventory": gs.inventory.map(func(item: Dictionary): return item.uniqueId)
		}
	)

	# Deterministic bidder-fixture helper makes self-bidding, solo-bidder stop,
	# and dropout policy consumption observable without mutating production data.
	var auction_artifact: Dictionary = gs.new_artifact("artifact_001", 8101, "m1_auction_fixture")
	gs.choose_hypothesis(auction_artifact, "GENUINE")
	gs.list_auction(auction_artifact, 1, 1, 0.8, "LIKELY")
	var competitive_profiles := [
		bidder_fixture("fixture_alpha", "budget_or_value", 0.55),
		bidder_fixture("fixture_beta", "budget_or_value", 0.75),
		bidder_fixture("fixture_gamma", "budget_or_value", 0.65)
	]
	var competitive_result := call_dictionary(gs, "auction_with_bidders", [auction_artifact, competitive_profiles, false])
	var competitive_bids: Array = competitive_result.get("bids", [])
	record(
		"M1-AUCTION-01",
		"Auction transcript never contains consecutive self-bids",
		bool(competitive_result.get("ok", true))
			and not competitive_bids.is_empty()
			and not has_consecutive_self_bid(competitive_bids),
		{"result": competitive_result, "consecutiveSelfBid": has_consecutive_self_bid(competitive_bids)}
	)

	var solo_profiles := [bidder_fixture("fixture_solo", "budget_or_value", 0.8)]
	var solo_result := call_dictionary(gs, "auction_with_bidders", [auction_artifact, solo_profiles, false])
	var solo_bids: Array = solo_result.get("bids", [])
	record(
		"M1-AUCTION-02",
		"Auction stops after at most one bid when no competitor exists",
		bool(solo_result.get("ok", true)) and solo_bids.size() <= 1,
		{"result": solo_result, "bidCount": solo_bids.size()}
	)

	var dropout_profiles := [
		bidder_fixture("fixture_once", "after_first_bid", 0.9),
		bidder_fixture("fixture_challenger", "budget_or_value", 0.6)
	]
	var dropout_result := call_dictionary(gs, "auction_with_bidders", [auction_artifact, dropout_profiles, false])
	var dropout_bids: Array = dropout_result.get("bids", [])
	var sentinel_bid_count := count_bids_for(dropout_bids, "fixture_once")
	record(
		"M1-AUCTION-03",
		"after_first_bid dropout behavior is consumed by the auction state machine",
		bool(dropout_result.get("ok", true)) and sentinel_bid_count == 1,
		{"result": dropout_result, "sentinelBidCount": sentinel_bid_count}
	)

	# A public quote may use the player's public evidence and hypothesis, never the
	# hidden ground truth. Flipping only truth must produce zero price leakage.
	var quote_artifact: Dictionary = gs.new_artifact("artifact_003", 9101, "m1_quote_fixture")
	quote_artifact.playerHypothesis = "GENUINE"
	quote_artifact.confidence = 0.66
	var quote_method_present := gs.has_method("public_appraisal_quote")
	var original_truth: String = quote_artifact.authenticityTruth
	var quote_before := -1
	var quote_after := -2
	if quote_method_present:
		quote_before = int(gs.callv("public_appraisal_quote", [quote_artifact]))
		quote_artifact.authenticityTruth = "FORGERY" if original_truth != "FORGERY" else "GENUINE"
		quote_after = int(gs.callv("public_appraisal_quote", [quote_artifact]))
	record(
		"M1-PRICE-PRIVACY-01",
		"Public appraisal quote has zero hidden-truth flip leakage",
		quote_method_present and quote_before >= 0 and quote_before == quote_after,
		{"methodPresent": quote_method_present, "truthBefore": original_truth, "quoteBefore": quote_before, "quoteAfter": quote_after}
	)

	# Existing save/load API must read the current file and recover the immediately
	# previous valid save when the current file is corrupt.
	gs.reset_game()
	gs.persistence_enabled = true
	var recovery_path := "user://r3_integrity_recovery_test.json"
	gs.money = 1357
	var saved_first: bool = gs.save_game(recovery_path)
	gs.money = 0
	var loaded_current: bool = gs.load_game(recovery_path)
	var current_value_ok: bool = loaded_current and gs.money == 1357
	gs.money = 2468
	var saved_second: bool = gs.save_game(recovery_path)
	var corrupt_file := FileAccess.open(recovery_path, FileAccess.WRITE)
	var corrupt_written := corrupt_file != null
	if corrupt_file != null:
		# Syntactically valid JSON with an invalid save root exercises fallback
		# without turning the expected corruption fixture into an engine error log.
		corrupt_file.store_string("[]")
		corrupt_file.close()
	gs.money = 0
	var loaded_backup: bool = gs.load_game(recovery_path)
	var recovered_value: int = gs.money
	record(
		"M1-SAVE-RECOVERY-01",
		"Current save loads and corrupt current recovers the previous valid backup",
		saved_first and current_value_ok and saved_second and corrupt_written and loaded_backup and recovered_value == 1357,
		{
			"savedFirst": saved_first,
			"loadedCurrent": loaded_current,
			"currentValueOk": current_value_ok,
			"savedSecond": saved_second,
			"corruptWritten": corrupt_written,
			"loadedBackup": loaded_backup,
			"recoveredValue": recovered_value
		}
	)
	# Leave the dedicated test slot valid for the next run.
	gs.money = recovered_value if loaded_backup else 1357
	gs.save_game(recovery_path)
	gs.persistence_enabled = false

	var passed := 0
	for result: Dictionary in results:
		if bool(result.passed):
			passed += 1
	var report := {
		"suite": "R3 M1 integrity",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"skipped": 0,
		"tests": results
	}
	var output := FileAccess.open("res://qa/R3_INTEGRITY_TESTS.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print(JSON.stringify(report))
	quit(0 if passed == results.size() else 1)
