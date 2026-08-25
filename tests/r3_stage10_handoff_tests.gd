extends SceneTree

## Stage 10 clear -> replay feedback -> ending hand-off contract.
##
## This suite drives the Grand Reserve through the public UI handler and checks
## save/load routing. It only writes user:// test saves and one JSON QA report;
## it never exports or packages a Windows build.

const AXIS_IDS := ["investigation", "preservation", "sale"]
const TUTORIAL_STEPS := ["INVESTIGATE", "CITE", "REPORT", "REPAIR", "LIST", "AUCTION"]
const BEFORE_ACK_PATH := "user://r3_stage10_handoff_before_ack.json"
const AFTER_ACK_PATH := "user://r3_stage10_handoff_after_ack.json"
const POSTGAME_PATH := "user://r3_stage10_handoff_postgame.json"
const LEGACY_PENDING_PATH := "user://r3_stage10_handoff_legacy_pending.json"
const LEGACY_POSTGAME_PATH := "user://r3_stage10_handoff_legacy_postgame.json"

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func settle_ui(frame_count: int = 4) -> void:
	for _frame in range(frame_count):
		await process_frame


func grand_reserve_session_state(gs: Node) -> Dictionary:
	var value: Variant = gs.call("grand_reserve_public_state")
	return value.duplicate(true) if value is Dictionary else {}


func advance_ui_to_hammer(main: Node) -> Dictionary:
	var phases: Array = []
	for _step in range(24):
		var cue_value: Variant = main.call("auction_public_cue_state")
		var cue: Dictionary = cue_value if cue_value is Dictionary else {}
		if cue.is_empty():
			return {"ok": false, "code": "MISSING_CUE", "phases": phases}
		phases.append(String(cue.get("phase", "")))
		if bool(cue.get("isFinal", false)):
			var hammer: Node = visible_named(main, "HammerButton")
			return {
				"ok": hammer is Button,
				"code": "OK" if hammer is Button else "MISSING_HAMMER",
				"phases": phases,
				"hammer": hammer,
			}
		var next_cue: Node = visible_named(main, "AuctionCueNext")
		if not next_cue is Button:
			return {"ok": false, "code": "MISSING_NEXT_CUE", "phases": phases}
		(next_cue as Button).pressed.emit()
		await settle_ui(3)
	return {"ok": false, "code": "CUE_LOOP_LIMIT", "phases": phases}


func drive_live_grand_reserve_ui(main: Node, gs: Node) -> Dictionary:
	var lots: Array = []
	var hammer_count: int = 0
	var next_lot_count: int = 0
	for lot_index in range(3):
		var session_before: Dictionary = grand_reserve_session_state(gs)
		var before_ok: bool = String(session_before.get("phase", "")) == "AUCTION_PENDING" \
			and int(session_before.get("currentLotIndex", -1)) == lot_index
		if not before_ok:
			return {
				"ok": false,
				"code": "LOT_NOT_PENDING",
				"lots": lots,
				"hammerCount": hammer_count,
				"nextLotCount": next_lot_count,
				"session": session_before,
			}
		var cue_run: Dictionary = await advance_ui_to_hammer(main)
		var hammer_value: Variant = cue_run.get("hammer", null)
		if not bool(cue_run.get("ok", false)) or not hammer_value is Button:
			return {
				"ok": false,
				"code": String(cue_run.get("code", "HAMMER_UNAVAILABLE")),
				"lots": lots,
				"hammerCount": hammer_count,
				"nextLotCount": next_lot_count,
				"cue": cue_run,
			}
		(hammer_value as Button).pressed.emit()
		hammer_count += 1
		await settle_ui(8)
		var session_after: Dictionary = grand_reserve_session_state(gs)
		var receipts_value: Variant = session_after.get("receipts", [])
		var receipts: Array = receipts_value if receipts_value is Array else []
		var expected_phase: String = "FINALIZED" if lot_index == 2 else "BETWEEN_LOTS"
		var lot_ok: bool = String(session_after.get("phase", "")) == expected_phase \
			and receipts.size() == lot_index + 1
		lots.append({
			"lot": lot_index + 1,
			"transactionId": session_before.get("activeTransactionId", ""),
			"cuePhases": cue_run.get("phases", []),
			"phaseAfterHammer": session_after.get("phase", ""),
			"receiptCount": receipts.size(),
			"ok": lot_ok,
		})
		if not lot_ok:
			return {
				"ok": false,
				"code": "HAMMER_BOUNDARY_INVALID",
				"lots": lots,
				"hammerCount": hammer_count,
				"nextLotCount": next_lot_count,
				"session": session_after,
			}
		if lot_index < 2:
			var next_lot: Node = visible_named(main, "GrandReserveNextLot")
			if not next_lot is Button:
				return {
					"ok": false,
					"code": "MISSING_NEXT_LOT",
					"lots": lots,
					"hammerCount": hammer_count,
					"nextLotCount": next_lot_count,
				}
			(next_lot as Button).pressed.emit()
			next_lot_count += 1
			await settle_ui(8)
			var advanced: Dictionary = grand_reserve_session_state(gs)
			var advanced_ok: bool = String(advanced.get("phase", "")) == "AUCTION_PENDING" \
				and int(advanced.get("currentLotIndex", -1)) == lot_index + 1
			if not advanced_ok:
				return {
					"ok": false,
					"code": "NEXT_LOT_DID_NOT_ADVANCE",
					"lots": lots,
					"hammerCount": hammer_count,
					"nextLotCount": next_lot_count,
					"session": advanced,
				}
	var final_session: Dictionary = grand_reserve_session_state(gs)
	var final_receipts_value: Variant = final_session.get("receipts", [])
	var final_receipts: Array = final_receipts_value if final_receipts_value is Array else []
	var complete: bool = hammer_count == 3 \
		and next_lot_count == 2 \
		and String(final_session.get("phase", "")) == "FINALIZED" \
		and final_receipts.size() == 3
	return {
		"ok": complete,
		"code": "OK" if complete else "FINAL_SESSION_INVALID",
		"lots": lots,
		"hammerCount": hammer_count,
		"nextLotCount": next_lot_count,
		"session": final_session,
	}


func cleanup_slots(gs: Node, path: String) -> void:
	gs.remove_save_file(path)
	gs.remove_save_file(path + gs.SAVE_TEMP_SUFFIX)
	gs.remove_save_file(path + gs.SAVE_BACKUP_SUFFIX)


func cleanup_all_slots(gs: Node) -> void:
	for path: String in [BEFORE_ACK_PATH, AFTER_ACK_PATH, POSTGAME_PATH, LEGACY_PENDING_PATH, LEGACY_POSTGAME_PATH]:
		cleanup_slots(gs, path)


func write_payload(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "  "))
	file.flush()
	file.close()
	return true


func visible_named(root: Node, node_name: String) -> Node:
	var candidate := root.find_child(node_name, true, false)
	if candidate == null:
		return null
	if candidate is CanvasItem and not (candidate as CanvasItem).is_visible_in_tree():
		return null
	return candidate


func replay_snapshot_shape_ok(snapshot: Dictionary) -> bool:
	var axes_value: Variant = snapshot.get("axes", null)
	if not axes_value is Dictionary:
		return false
	var axes: Dictionary = axes_value
	if axes.size() != AXIS_IDS.size():
		return false
	for axis_id: String in AXIS_IDS:
		var axis_value: Variant = axes.get(axis_id, null)
		if not axis_value is Dictionary:
			return false
		var axis: Dictionary = axis_value
		if not axis.has_all(["value", "available", "statusCode"]):
			return false
	return snapshot.has_all(["stage", "weakest", "adviceCode"])


func rendered_axis_scores(main: Node) -> Array:
	var scores: Array = []
	for axis_id: String in AXIS_IDS:
		var score := visible_named(main, "StageReplayAxisScore_%s" % axis_id)
		scores.append(String(score.text) if score is Label else "<missing>")
	return scores


func fully_unlocked_profile(gs: Node) -> Dictionary:
	var profile: Dictionary = gs.default_player_profile()
	var cleared: Array = []
	for stage_id in range(1, 10):
		cleared.append(stage_id)
	profile.highestUnlockedStage = 10
	profile.clearedStages = cleared
	profile.tutorialCompletedSteps = TUTORIAL_STEPS.duplicate()
	return profile


func satisfy_stage_cases(gs: Node, registry: Node, stage_id: int) -> void:
	for case_id_value: Variant in registry.get_stage_definition(stage_id).get("case_ids", []):
		var case_id := String(case_id_value)
		gs.campaign_state.completedCases[case_id] = true
		gs.campaign_state.caseOutcomes[case_id] = "credible"


func prepare_stage_ten(gs: Node, registry: Node) -> Dictionary:
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	gs.player_profile = fully_unlocked_profile(gs)
	var started: Dictionary = gs.new_game(10)
	var prepared_cases: Array = []
	var failed_cases: Array = []
	for case_id_value: Variant in registry.get_stage_definition(10).get("case_ids", []):
		var case_id := String(case_id_value)
		var prepared: bool = bool(gs.prepare_case_for_test(case_id))
		prepared_cases.append({"case": case_id, "prepared": prepared})
		if not prepared:
			failed_cases.append(case_id)
	var eligible: Array = gs.eligible_final_lots()
	return {
		"ok": bool(started.get("ok", false))
			and failed_cases.is_empty()
			and String(gs.stage_run_state.get("status", "")) == "RUNNING"
			and String(gs.campaign_state.get("currentAct", "")) == "GRAND_RESERVE"
			and bool(gs.campaign_state.get("grandReserve", {}).get("invited", false))
			and eligible.size() >= 3,
		"started": started,
		"preparedCases": prepared_cases,
		"failedCases": failed_cases,
		"eligible": eligible
	}


func write_report_and_quit(main: Node = null) -> void:
	var passed := results.filter(func(result: Dictionary): return bool(result.get("passed", false))).size()
	var report := {
		"suite": "R3 Stage 10 Clear To Ending Handoff",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"skipped": 0,
		"tests": results
	}
	var output := FileAccess.open("res://qa/R3_STAGE10_HANDOFF_TESTS.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print(JSON.stringify(report))
	if main != null and is_instance_valid(main):
		main.queue_free()
	quit(0 if passed == results.size() else 1)


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	cleanup_all_slots(gs)
	gs.persistence_enabled = false
	gs.campaign_test_mode = true

	var required_game_state_methods := [
		"stage_clear_pending", "acknowledge_stage_clear", "stage_replay_feedback",
		"grand_reserve_public_state", "save_game", "load_game", "prepare_case_for_test"
	]
	var missing_game_state_methods: Array = []
	for method_name: String in required_game_state_methods:
		if not gs.has_method(method_name):
			missing_game_state_methods.append(method_name)
	record(
		"STAGE10-HANDOFF-API-01",
		"Stage-clear handoff exposes every required public GameState API",
		missing_game_state_methods.is_empty(),
		{"required": required_game_state_methods, "missing": missing_game_state_methods}
	)
	if not missing_game_state_methods.is_empty():
		write_report_and_quit()
		return

	var fixture: Dictionary = prepare_stage_ten(gs, registry)
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await settle_ui()
	var required_main_methods := [
		"show_campaign", "show_final_lot_selection", "select_final_lot_from_ui",
		"run_grand_reserve_from_ui", "auction_public_cue_state", "continue_from_ui", "toggle_language"
	]
	var missing_main_methods: Array = []
	for method_name: String in required_main_methods:
		if not main.has_method(method_name):
			missing_main_methods.append(method_name)
	record(
		"STAGE10-HANDOFF-API-02",
		"Stage-clear handoff exposes every required public UI route",
		missing_main_methods.is_empty(),
		{"required": required_main_methods, "missing": missing_main_methods}
	)
	if not missing_main_methods.is_empty():
		cleanup_all_slots(gs)
		write_report_and_quit(main)
		return

	# Use the public final-lot UI handlers and the visible Begin control. The
	# Grand Reserve success handler must land on the clear card, not the ending.
	main.show_final_lot_selection()
	await settle_ui()
	var eligible: Array = fixture.get("eligible", [])
	for index in range(mini(3, eligible.size())):
		main.select_final_lot_from_ui(String((eligible[index] as Dictionary).get("uniqueId", "")))
		await settle_ui(2)
	var begin_button := visible_named(main, "BeginGrandReserve")
	var begin_ready: bool = begin_button is Button and not (begin_button as Button).disabled \
		and gs.campaign_state.get("grandReserve", {}).get("selectedLotIds", []).size() == 3
	if begin_ready:
		(begin_button as Button).pressed.emit()
		await settle_ui(8)
	var live_flow: Dictionary = await drive_live_grand_reserve_ui(main, gs) if begin_ready else {
		"ok": false,
		"code": "BEGIN_NOT_READY",
		"lots": [],
		"hammerCount": 0,
		"nextLotCount": 0,
	}

	var frozen_snapshot: Dictionary = gs.stage_run_state.get("stageReplayFeedbackSnapshot", {}).duplicate(true)
	var stage_ten_payload: Dictionary = gs.save_payload().duplicate(true)
	var clear_card := visible_named(main, "StageClearCard")
	var ending_cta := visible_named(main, "StageClearViewEnding")
	var success_contract: bool = bool(fixture.get("ok", false)) \
		and begin_ready \
		and bool(live_flow.get("ok", false)) \
		and int(live_flow.get("hammerCount", 0)) == 3 \
		and int(live_flow.get("nextLotCount", 0)) == 2 \
		and String(gs.stage_run_state.get("status", "")) == "CLEARED" \
		and not String(gs.campaign_state.get("currentEnding", "")).is_empty() \
		and bool(gs.campaign_state.get("grandReserve", {}).get("completed", false)) \
		and replay_snapshot_shape_ok(frozen_snapshot) \
		and int(frozen_snapshot.get("stage", 0)) == 10 \
		and not bool(gs.stage_run_state.get("stageClearAcknowledged", true)) \
		and bool(gs.stage_clear_pending()) \
		and String(main.screen) == "campaign" \
		and clear_card is PanelContainer \
		and ending_cta is Button \
		and visible_named(main, "PostgameButton") == null
	record(
		"STAGE10-HANDOFF-GRAND-RESERVE-01",
		"Grand Reserve UI success freezes three replay axes and shows Stage Clear before the ending",
		success_contract,
		{
			"fixture": fixture,
			"beginReady": begin_ready,
			"liveFlow": live_flow,
			"stageStatus": gs.stage_run_state.get("status", ""),
			"ending": gs.campaign_state.get("currentEnding", ""),
			"snapshot": frozen_snapshot,
			"acknowledged": gs.stage_run_state.get("stageClearAcknowledged", null),
			"pending": gs.stage_clear_pending(),
			"screen": main.screen,
			"card": clear_card != null,
			"cta": ending_cta != null
		}
	)

	# The completion snapshot, not a newly computed live value, is the clear-card
	# authority. Locale refresh may replace copy but not the handoff state.
	var original_language := String(gs.language)
	var rendered_before := rendered_axis_scores(main)
	var auction_history_before: Array = gs.auction_history.duplicate(true)
	var live_before: Dictionary = gs.stage_replay_feedback()
	gs.auction_history = []
	var live_after: Dictionary = gs.stage_replay_feedback()
	main.show_campaign()
	await settle_ui()
	var rendered_after_public_mutation := rendered_axis_scores(main)
	var snapshot_after_public_mutation: Dictionary = gs.stage_run_state.get("stageReplayFeedbackSnapshot", {}).duplicate(true)
	main.toggle_language()
	await settle_ui(6)
	var first_locale_ok: bool = visible_named(main, "StageClearCard") != null \
		and visible_named(main, "StageClearViewEnding") != null \
		and bool(gs.stage_clear_pending()) \
		and gs.stage_run_state.get("stageReplayFeedbackSnapshot", {}) == frozen_snapshot
	main.toggle_language()
	await settle_ui(6)
	var second_locale_ok: bool = String(gs.language) == original_language \
		and String(main.screen) == "campaign" \
		and visible_named(main, "StageClearCard") != null \
		and visible_named(main, "StageClearViewEnding") != null \
		and not bool(gs.stage_run_state.get("stageClearAcknowledged", true)) \
		and gs.stage_run_state.get("stageReplayFeedbackSnapshot", {}) == frozen_snapshot
	gs.auction_history = auction_history_before
	record(
		"STAGE10-HANDOFF-FROZEN-LOCALE-01",
		"Frozen Stage Clear feedback survives public-state mutation and KO/EN refresh without acknowledging the ending",
		live_before != live_after \
			and rendered_before == rendered_after_public_mutation \
			and snapshot_after_public_mutation == frozen_snapshot \
			and first_locale_ok \
			and second_locale_ok,
		{
			"liveChanged": live_before != live_after,
			"renderedBefore": rendered_before,
			"renderedAfterMutation": rendered_after_public_mutation,
			"snapshotStable": snapshot_after_public_mutation == frozen_snapshot,
			"firstLocaleOk": first_locale_ok,
			"secondLocaleOk": second_locale_ok
		}
	)

	# Save before the CTA. Continue must restore the clear card; pressing the CTA
	# acknowledges exactly that boundary and only then reveals the ending.
	gs.persistence_enabled = true
	var saved_before_ack: bool = bool(gs.save_game(BEFORE_ACK_PATH))
	gs.persistence_enabled = false
	gs.reset_game()
	main.show_title()
	await settle_ui()
	var loaded_before_ack: bool = bool(main.continue_from_ui(BEFORE_ACK_PATH)) if saved_before_ack else false
	await settle_ui(8)
	var before_ack_route_ok := loaded_before_ack \
		and String(main.screen) == "campaign" \
		and bool(gs.stage_clear_pending()) \
		and not bool(gs.stage_run_state.get("stageClearAcknowledged", true)) \
		and visible_named(main, "StageClearCard") != null \
		and visible_named(main, "StageClearViewEnding") is Button
	var view_ending_button := visible_named(main, "StageClearViewEnding")
	if view_ending_button is Button:
		(view_ending_button as Button).pressed.emit()
		await settle_ui(8)
	var acknowledged_to_ending := bool(gs.stage_run_state.get("stageClearAcknowledged", false)) \
		and not bool(gs.stage_clear_pending()) \
		and String(main.screen) == "ending" \
		and visible_named(main, "StageClearCard") == null \
		and visible_named(main, "PostgameButton") is Button
	record(
		"STAGE10-HANDOFF-CTA-01",
		"Continue before acknowledgement restores Stage Clear and its CTA acknowledges before showing the ending",
		before_ack_route_ok and acknowledged_to_ending,
		{
			"saved": saved_before_ack,
			"loaded": loaded_before_ack,
			"beforeAckRoute": before_ack_route_ok,
			"acknowledged": gs.stage_run_state.get("stageClearAcknowledged", null),
			"pending": gs.stage_clear_pending(),
			"screenAfterCta": main.screen
		}
	)

	# Persist each side of the acknowledged boundary. Continue after the CTA must
	# show the ending; after epilogue acknowledgement it must show postgame.
	gs.persistence_enabled = true
	var saved_after_ack: bool = bool(gs.save_game(AFTER_ACK_PATH))
	gs.persistence_enabled = false
	gs.reset_game()
	main.show_title()
	await settle_ui()
	var loaded_after_ack: bool = bool(main.continue_from_ui(AFTER_ACK_PATH)) if saved_after_ack else false
	await settle_ui(8)
	var after_ack_route_ok := loaded_after_ack \
		and bool(gs.stage_run_state.get("stageClearAcknowledged", false)) \
		and not bool(gs.stage_clear_pending()) \
		and String(main.screen) == "ending" \
		and visible_named(main, "StageClearCard") == null \
		and visible_named(main, "PostgameButton") is Button
	var postgame_button := visible_named(main, "PostgameButton")
	if postgame_button is Button:
		(postgame_button as Button).pressed.emit()
		await settle_ui(8)
	var epilogue_acknowledged := bool(gs.campaign_state.get("epilogueSeen", false)) \
		and bool(gs.campaign_state.get("postGame", false)) \
		and String(main.screen) == "postgame"
	gs.persistence_enabled = true
	var saved_postgame: bool = bool(gs.save_game(POSTGAME_PATH))
	gs.persistence_enabled = false
	gs.reset_game()
	main.show_title()
	await settle_ui()
	var loaded_postgame: bool = bool(main.continue_from_ui(POSTGAME_PATH)) if saved_postgame else false
	await settle_ui(8)
	var postgame_route_ok := loaded_postgame \
		and bool(gs.campaign_state.get("postGame", false)) \
		and bool(gs.stage_run_state.get("stageClearAcknowledged", false)) \
		and not bool(gs.stage_clear_pending()) \
		and String(main.screen) == "postgame" \
		and visible_named(main, "StageClearCard") == null
	record(
		"STAGE10-HANDOFF-CONTINUE-01",
		"Continue restores ending after the CTA and postgame after epilogue acknowledgement without regressing to Stage Clear",
		after_ack_route_ok and epilogue_acknowledged and saved_postgame and postgame_route_ok,
		{
			"savedAfterAck": saved_after_ack,
			"loadedAfterAck": loaded_after_ack,
			"afterAckRoute": after_ack_route_ok,
			"epilogueAcknowledged": epilogue_acknowledged,
			"savedPostgame": saved_postgame,
			"loadedPostgame": loaded_postgame,
			"postgameRoute": postgame_route_ok,
			"screen": main.screen
		}
	)

	# Legacy v5 saves predate stageClearAcknowledged. A cleared Stage 10 save
	# before postgame gets the one-time card; an already-postgame save is treated
	# as acknowledged and must never be routed backwards.
	var legacy_pending: Dictionary = stage_ten_payload.duplicate(true)
	var legacy_pending_run: Dictionary = legacy_pending.get("stageRunState", {})
	legacy_pending_run.erase("stageClearAcknowledged")
	legacy_pending.stageRunState = legacy_pending_run
	legacy_pending.campaign.postGame = false
	legacy_pending.campaign.epilogueSeen = false
	legacy_pending.campaign.currentAct = "EPILOGUE"
	var legacy_pending_valid := bool(gs.validate_save_payload(legacy_pending).get("ok", false))
	var legacy_pending_written := legacy_pending_valid and write_payload(LEGACY_PENDING_PATH, legacy_pending)
	gs.reset_game()
	main.show_title()
	await settle_ui()
	var legacy_pending_loaded: bool = bool(main.continue_from_ui(LEGACY_PENDING_PATH)) if legacy_pending_written else false
	await settle_ui(8)
	var legacy_pending_ok := legacy_pending_loaded \
		and not bool(gs.stage_run_state.get("stageClearAcknowledged", true)) \
		and bool(gs.stage_clear_pending()) \
		and String(main.screen) == "campaign" \
		and visible_named(main, "StageClearCard") != null \
		and visible_named(main, "StageClearViewEnding") != null

	var legacy_postgame: Dictionary = stage_ten_payload.duplicate(true)
	var legacy_postgame_run: Dictionary = legacy_postgame.get("stageRunState", {})
	legacy_postgame_run.erase("stageClearAcknowledged")
	legacy_postgame.stageRunState = legacy_postgame_run
	legacy_postgame.campaign.postGame = true
	legacy_postgame.campaign.epilogueSeen = true
	legacy_postgame.campaign.currentAct = "POSTGAME"
	var legacy_postgame_valid := bool(gs.validate_save_payload(legacy_postgame).get("ok", false))
	var legacy_postgame_written := legacy_postgame_valid and write_payload(LEGACY_POSTGAME_PATH, legacy_postgame)
	gs.reset_game()
	main.show_title()
	await settle_ui()
	var legacy_postgame_loaded: bool = bool(main.continue_from_ui(LEGACY_POSTGAME_PATH)) if legacy_postgame_written else false
	await settle_ui(8)
	var legacy_postgame_ok := legacy_postgame_loaded \
		and bool(gs.stage_run_state.get("stageClearAcknowledged", false)) \
		and not bool(gs.stage_clear_pending()) \
		and bool(gs.campaign_state.get("postGame", false)) \
		and String(main.screen) == "postgame" \
		and visible_named(main, "StageClearCard") == null
	record(
		"STAGE10-HANDOFF-LEGACY-01",
		"Legacy cleared Stage 10 saves show the one-time card unless they had already reached postgame",
		legacy_pending_ok and legacy_postgame_ok,
		{
			"pending": {"valid": legacy_pending_valid, "written": legacy_pending_written, "loaded": legacy_pending_loaded, "routeOk": legacy_pending_ok},
			"postgame": {"valid": legacy_postgame_valid, "written": legacy_postgame_written, "loaded": legacy_postgame_loaded, "routeOk": legacy_postgame_ok}
		}
	)

	# Stages 1-9 retain their next-stage/replay handoff. Their primary CTA
	# acknowledges the clear and starts the next uncleared stage; replay remains
	# available as a secondary route and the ending CTA stays Stage-10-only.
	gs.persistence_enabled = false
	var earlier_stage_failures: Array = []
	for stage_id in range(1, 10):
		gs.player_profile = {"schema_version": 1, "highestUnlockedStage": stage_id, "clearedStages": range(1, stage_id), "stageBest": {}}
		var started: Dictionary = gs.new_game(stage_id)
		satisfy_stage_cases(gs, registry, stage_id)
		var cleared: Dictionary = gs.complete_stage(stage_id, float(stage_id * 10))
		main.show_campaign()
		await settle_ui(4)
		var next_button := visible_named(main, "CampaignStageSelect")
		var before_route_ok := bool(started.get("ok", false)) \
			and bool(cleared.get("ok", false)) \
			and bool(gs.stage_clear_pending()) \
			and replay_snapshot_shape_ok(gs.stage_run_state.get("stageReplayFeedbackSnapshot", {})) \
			and String(gs.campaign_state.get("currentEnding", "")).is_empty() \
			and visible_named(main, "StageClearCard") != null \
			and next_button is Button \
			and visible_named(main, "StageClearViewEnding") == null
		if next_button is Button:
			(next_button as Button).pressed.emit()
			await settle_ui(4)
		var after_route_ok: bool = not bool(gs.stage_clear_pending()) \
			and String(main.screen) == "campaign" \
			and gs.current_stage == stage_id + 1 \
			and String(gs.stage_run_state.get("status", "")) == "RUNNING"
		if not before_route_ok or not after_route_ok:
			earlier_stage_failures.append({
				"stage": stage_id,
				"started": started,
				"cleared": cleared,
				"beforeRoute": before_route_ok,
				"afterRoute": after_route_ok,
				"acknowledged": gs.stage_run_state.get("stageClearAcknowledged", null),
				"screen": main.screen
			})
	record(
		"STAGE10-HANDOFF-EARLIER-STAGES-01",
		"Stages 1-9 start the next Stage through the primary CTA while retaining replay and never entering the Stage 10 ending handoff",
		earlier_stage_failures.is_empty(),
		earlier_stage_failures
	)

	cleanup_all_slots(gs)
	gs.campaign_test_mode = false
	gs.persistence_enabled = false
	write_report_and_quit(main)
