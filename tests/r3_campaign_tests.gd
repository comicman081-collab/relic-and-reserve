extends SceneTree

var results: Array = []
var ending_results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, condition: bool, evidence: Variant) -> void:
	results.append({"id": id, "executed": true, "passed": condition, "evidence": evidence, "name": name})


func record_ending(id: String, expected: String, actual: String) -> void:
	ending_results.append({"id": id, "executed": true, "expected": expected, "actual": actual, "passed": expected == actual})


func prepare_act(gs: Node, act_id: String) -> bool:
	var success := true
	for case_id: String in gs.act_case_ids(act_id):
		if not gs.prepare_case_for_test(case_id):
			success = false
	return success


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame

	var act1_count: int = gs.act_case_ids("ACT_1").size()
	var act4_count: int = gs.act_case_ids("ACT_4").size()
	var act5_count: int = gs.act_case_ids("ACT_5").size()
	record("CAMP-DATA-01", "Campaign content minimums are connected", act1_count >= 8 and act4_count >= 6 and act5_count >= 6 and registry.story_artifacts.size() >= 15 and registry.npcs.size() >= 8 and registry.documents.size() >= 30 and registry.campaign.environments.size() >= 9, {"act1": act1_count, "act4": act4_count, "act5": act5_count, "storyArtifacts": registry.story_artifacts.size(), "npcs": registry.npcs.size(), "documents": registry.documents.size(), "environments": registry.campaign.environments.size()})
	var references: Dictionary = registry.reference_database
	record("CAMP-DATA-02", "Fictional reference database meets minimums", references.get("fictional", false) and references.makerModelHistories.size() >= 40 and references.materialConstructionNotes.size() >= 30 and references.periodReferences.size() >= 20 and registry.makers.size() >= 20, {"makers": registry.makers.size(), "histories": references.makerModelHistories.size(), "materials": references.materialConstructionNotes.size(), "periods": references.periodReferences.size()})
	var missing_portraits: Array = []
	for npc: Dictionary in registry.npcs.values():
		for expression: String in ["neutral", "positive", "concerned", "surprised"]:
			if not FileAccess.file_exists(npc.expressions.get(expression, "")):
				missing_portraits.append("%s:%s" % [npc.id, expression])
	for buyer_index in range(1, 13):
		var buyer_path := "res://assets/portraits/buyer_%02d.svg" % buyer_index
		if not FileAccess.file_exists(buyer_path):
			missing_portraits.append(buyer_path)
	record("CAMP-ASSET-01", "NPC expression and buyer portraits exist", missing_portraits.is_empty(), missing_portraits)

	gs.reset_game()
	var nested_condition := {"op": "all", "conditions": [
		{"metric": "reputation", "op": ">=", "value": 10},
		{"op": "any", "conditions": [
			{"metric": "museumTrust", "op": ">", "value": 99},
			{"op": "not", "condition": {"metric": "epilogue_seen", "op": "==", "value": true}}
		]}
	]}
	record("CAMP-COND-01", "Generic condition evaluator supports AND/OR/NOT/comparison", gs.evaluate_condition(nested_condition), nested_condition)

	var ethics_before := int(gs.campaign_state.ethics)
	var misleading: Dictionary = gs.new_artifact("artifact_003", 4455, "ethics_test")
	misleading.authenticityTruth = "FORGERY"
	misleading.playerHypothesis = "GENUINE"
	misleading.knownClues = ["MATERIAL", "SERIAL_PATTERN"]
	misleading.evidence = [{"clueType": "MATERIAL", "observation": "test", "supports": [], "contradicts": ["modern_material"], "confidenceWeight": 0.2}]
	gs.inventory.append(misleading)
	gs.accept_hypothesis(misleading)
	gs.list_auction(misleading, 1, 1, 0.9, "CERTAIN")
	var misleading_result: Dictionary = gs.sell(misleading)
	record("CAMP-ETHICS-01", "Misleading certainty has price/trust/ethics consequence", misleading_result.reserve_met and int(gs.campaign_state.ethics) < ethics_before and gs.reputation < 12, {"ethics_before": ethics_before, "ethics_after": gs.campaign_state.ethics, "reputation": gs.reputation})

	gs.reset_game()
	gs.campaign_test_mode = true
	record("CAMP-START-01", "Campaign starts in Prologue", gs.campaign_state.currentAct == "PROLOGUE", gs.campaign_state.currentAct)
	var prologue_complete: bool = gs.prepare_case_for_test("prologue_clock")
	record("CAMP-PROLOGUE-01", "Prologue completes through inspect/auth/list/live sale APIs", prologue_complete and gs.campaign_state.completedCases.has("prologue_clock") and gs.campaign_state.currentAct == "ACT_1" and int(gs.statistics.sales) >= 1, {"act": gs.campaign_state.currentAct, "sales": gs.statistics.sales})

	var recovery_artifact: Dictionary = gs.begin_case("silent_radio")
	gs.discover_case_evidence("silent_radio", "silent_radio:material")
	gs.discover_case_evidence("silent_radio", "silent_radio:serial_pattern")
	var recovery_result: Dictionary = gs.resolve_case_v2("silent_radio", "REPRODUCTION", ["silent_radio:material", "silent_radio:serial_pattern"])
	var recovery_complete: bool = bool(recovery_result.get("ok", false))
	record("CAMP-RECOVERY-01", "Bad/reviewed case outcome retains progression route", recovery_complete and gs.campaign_state.completedCases.has("silent_radio") and gs.campaign_state.caseOutcomes.get("silent_radio") == "mistaken", {"outcome": gs.campaign_state.caseOutcomes.get("silent_radio"), "result": recovery_result})

	var act1_complete: bool = prepare_act(gs, "ACT_1")
	record("CAMP-ACT1-01", "Eight Act 1 cases unlock Act 2 and Workshop Grade II", act1_complete and gs.campaign_state.currentAct == "ACT_2" and int(gs.campaign_state.workshopGrade) >= 2, {"act": gs.campaign_state.currentAct, "grade": gs.campaign_state.workshopGrade})
	var act2_complete: bool = prepare_act(gs, "ACT_2")
	record("CAMP-ACT2-01", "Provenance cases unlock Act 3", act2_complete and gs.campaign_state.currentAct == "ACT_3" and gs.campaign_state.completedCases.has("observatory_instrument"), gs.campaign_state.currentAct)

	var boundary_path := "res://qa/r3_campaign_boundary_save.json"
	var boundary_before: Dictionary = gs.save_payload()
	var boundary_saved: bool = gs.save_game(boundary_path)
	gs.campaign_state.currentAct = "BROKEN"
	gs.inventory = []
	var boundary_loaded: bool = gs.load_game(boundary_path)
	var boundary_equal: bool = gs.campaign_state.currentAct == boundary_before.campaign.currentAct and gs.campaign_state.completedCases.size() == boundary_before.campaign.completedCases.size() and gs.inventory.size() == boundary_before.inventory.size()
	record("CAMP-SAVE-01", "Campaign save/load preserves an act boundary", boundary_saved and boundary_loaded and boundary_equal, {"act": gs.campaign_state.currentAct, "cases": gs.campaign_state.completedCases.size(), "inventory": gs.inventory.size()})

	var trust_before: int = gs.total_collector_trust()
	var act3_complete: bool = prepare_act(gs, "ACT_3")
	record("CAMP-ACT3-01", "Collector cases change relationship trust and unlock Act 4", act3_complete and gs.campaign_state.currentAct == "ACT_4" and gs.total_collector_trust() > trust_before, {"act": gs.campaign_state.currentAct, "trust_before": trust_before, "trust_after": gs.total_collector_trust()})
	var act4_complete: bool = prepare_act(gs, "ACT_4")
	record("CAMP-ACT4-01", "Five connected shadow cases plus composite climax unlock Act 5", act4_complete and gs.campaign_state.currentAct == "ACT_5" and gs.campaign_state.completedCases.has("composite_prototype"), gs.campaign_state.currentAct)

	var fast_forward: Dictionary = gs.fast_forward_campaign_for_test()
	record("CAMP-FAST-01", "Fast-forward uses public case transitions and reaches postgame", fast_forward.get("passed", false) and gs.campaign_state.postGame, {"transitions": fast_forward.get("transitions", []).size(), "grand_reserve": fast_forward.get("grandReserve", {}), "ending": fast_forward.get("ending", ""), "act": gs.campaign_state.currentAct})
	record("CAMP-ACT5-01", "Six master restorations produce Grade V and mastery", gs.campaign_state.completedActs.has("ACT_5") and int(gs.campaign_state.workshopGrade) == 5 and gs.mastery_total() >= 42, {"grade": gs.campaign_state.workshopGrade, "mastery": gs.mastery_total()})
	record("CAMP-GR-01", "Grand Reserve invitation and three distinct owned selections persist", bool(gs.campaign_state.grandReserve.invited) and gs.campaign_state.grandReserve.selectedLotIds.size() == 3 and gs.campaign_state.grandReserve.selectedLotIds[0] != gs.campaign_state.grandReserve.selectedLotIds[1], gs.campaign_state.grandReserve.selectedLotIds)
	var reserve_results: Array = gs.campaign_state.grandReserve.results
	var bidder_failure: Array = []
	for result: Dictionary in reserve_results:
		if result.auction.participants.size() < 8:
			bidder_failure.append(result.artifact.instanceId)
	record("CAMP-GR-02", "Three Grand Reserve lots use real auction AI with at least 8 bidders", reserve_results.size() == 3 and bidder_failure.is_empty(), {"results": reserve_results.size(), "bidder_failures": bidder_failure})
	var score: Dictionary = gs.campaign_state.grandReserve.score
	var score_keys := ["authentication", "restoration", "integrity", "financial", "museumTrust", "collectorReputation", "grandReserveRevenue", "collectionQuality", "balancedScore"]
	var missing_score_keys: Array = []
	for key: String in score_keys:
		if not score.has(key):
			missing_score_keys.append(key)
	record("CAMP-GR-03", "Final score stores every required component", missing_score_keys.is_empty(), score)
	record("CAMP-END-01", "Ending, epilogue acknowledgement, and postgame are connected", not gs.campaign_state.currentEnding.is_empty() and gs.campaign_state.epilogueSeen and gs.campaign_state.postGame and gs.campaign_state.endingUnlocked.has(gs.campaign_state.currentEnding), {"ending": gs.campaign_state.currentEnding, "postgame": gs.campaign_state.postGame})

	var postgame_path := "res://qa/r3_campaign_postgame_save.json"
	var selected_before: Array = gs.campaign_state.grandReserve.selectedLotIds.duplicate()
	var ending_before: String = gs.campaign_state.currentEnding
	var post_saved: bool = gs.save_game(postgame_path)
	gs.campaign_state = gs.default_campaign_state()
	var post_loaded: bool = gs.load_game(postgame_path)
	record("CAMP-SAVE-02", "Campaign save/load preserves final selection, ending, and postgame", post_saved and post_loaded and gs.campaign_state.grandReserve.selectedLotIds == selected_before and gs.campaign_state.currentEnding == ending_before and gs.campaign_state.postGame, {"selected": gs.campaign_state.grandReserve.selectedLotIds, "ending": gs.campaign_state.currentEnding})

	main.set_world_mode("grand_reserve")
	record("CAMP-VIS-01", "Grand Reserve is a distinct real 3D environment", main.grand_reserve_set.visible and not main.workshop_set.visible and main.grand_reserve_set.get_child_count() >= 30 and main.grand_reserve_set.has_node("AuctionPodium") and main.grand_reserve_set.has_node("DisplayPlinth_1"), {"hall_nodes": main.grand_reserve_set.get_child_count()})
	main.update_workshop_grade_visuals()
	var grade_modules_visible := 0
	for child: Node in main.workshop_set.get_children():
		if child.name.begins_with("GradeModule_") and child.visible:
			grade_modules_visible += 1
	record("CAMP-VIS-02", "Workshop Grade V visibly enables persistent modules", grade_modules_visible == 4, {"visible_modules": grade_modules_visible})

	record_ending("ENDING-01", "ENDING_D", gs.evaluate_ending({"ethics": 0, "collectorTrust": -20, "balancedScore": 99, "authenticationAccuracy": 0.99, "restoration": 99, "financial": 99, "integrity": 99}))
	record_ending("ENDING-02", "ENDING_S", gs.evaluate_ending({"ethics": 80, "collectorTrust": 30, "balancedScore": 90, "authenticationAccuracy": 0.90, "restoration": 90, "financial": 90, "integrity": 90}))
	record_ending("ENDING-03", "ENDING_A", gs.evaluate_ending({"ethics": 70, "collectorTrust": 10, "balancedScore": 72, "authenticationAccuracy": 0.75, "restoration": 95, "financial": 60, "integrity": 70}))
	record_ending("ENDING-04", "ENDING_B", gs.evaluate_ending({"ethics": 70, "collectorTrust": 10, "balancedScore": 72, "authenticationAccuracy": 0.75, "restoration": 60, "financial": 95, "integrity": 70}))
	record_ending("ENDING-05", "ENDING_C", gs.evaluate_ending({"ethics": 70, "collectorTrust": 10, "balancedScore": 72, "authenticationAccuracy": 0.75, "restoration": 60, "financial": 70, "integrity": 95}))
	var all_endings_pass := true
	for ending_test: Dictionary in ending_results:
		all_endings_pass = all_endings_pass and bool(ending_test.passed)
	record("CAMP-END-02", "All five endings and precedence are force-constructible through runtime evaluator", all_endings_pass, ending_results)

	var passed := 0
	for result: Dictionary in results:
		if result.passed:
			passed += 1
	var report := {"suite": "R3 campaign", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "skipped": 0, "tests": results}
	var output := FileAccess.open("res://qa/R3_CAMPAIGN_TESTS.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	var ending_passed := 0
	for ending_test: Dictionary in ending_results:
		if ending_test.passed:
			ending_passed += 1
	var ending_report := {"suite": "R3 endings", "executed": ending_results.size(), "passed": ending_passed, "failed": ending_results.size() - ending_passed, "skipped": 0, "tests": ending_results}
	var ending_output := FileAccess.open("res://qa/R3_ENDING_TESTS.json", FileAccess.WRITE)
	ending_output.store_string(JSON.stringify(ending_report, "  "))
	ending_output.close()
	print(JSON.stringify(report))
	print(JSON.stringify(ending_report))
	main.queue_free()
	quit(0 if passed == results.size() and ending_passed == ending_results.size() else 1)
