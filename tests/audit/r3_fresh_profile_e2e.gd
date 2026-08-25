extends SceneTree

## Audit-only fresh-profile journey. This intentionally exercises the public
## campaign/stage APIs in order; it never changes production data or exports.

var checks: Array = []
var stage_rows: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	checks.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func route_probe(main: Node, route: String) -> Dictionary:
	match route:
		"title": main.show_title()
		"stage_select": main.show_stage_select()
		"campaign": main.show_campaign()
		"market": main.show_market()
		"event": main.show_event_dialogue({})
		"workshop": main.show_workshop()
		"ending": main.show_ending()
		"postgame": main.show_postgame()
		_:
			return {"route": route, "actual": main.screen, "ok": false, "error": "UNKNOWN_ROUTE"}
	return {"route": route, "actual": main.screen, "ok": String(main.screen) == route}


func snapshot(gs: Node) -> Dictionary:
	return {
		"stage": int(gs.current_stage),
		"stageStatus": String(gs.stage_run_state.get("status", "")),
		"clearAcknowledged": bool(gs.stage_run_state.get("stageClearAcknowledged", false)),
		"highestUnlockedStage": int(gs.player_profile.get("highestUnlockedStage", 1)),
		"clearedStages": gs.player_profile.get("clearedStages", []).duplicate(),
		"currentAct": String(gs.campaign_state.get("currentAct", "")),
		"ending": String(gs.campaign_state.get("currentEnding", "")),
		"postGame": bool(gs.campaign_state.get("postGame", false)),
		"inventory": gs.inventory.size(),
		"sales": int(gs.statistics.get("sales", 0)),
		"noSales": int(gs.statistics.get("no_sales", 0)),
		"transactions": gs.transactions.size()
	}


func persistent_progression(profile: Dictionary) -> Dictionary:
	var normalized := profile.duplicate(true)
	# Tutorial guidance is an explicitly replayable run aid; NEW GAME may reset
	# its incomplete prefix while stage unlocks/bests remain persistent.
	normalized.erase("tutorialCompletedSteps")
	return normalized


func complete_current_stage(gs: Node, registry: Node, stage_id: int) -> Dictionary:
	var definition: Dictionary = registry.get_stage_definition(stage_id)
	var rows: Array = []
	for case_value: Variant in definition.get("case_ids", []):
		var case_id := String(case_value)
		var first: Dictionary = gs.begin_case(case_id)
		var first_uid := String(first.get("uniqueId", ""))
		var completed: bool = gs.prepare_case_for_test(case_id)
		var second: Dictionary = gs.begin_case(case_id)
		var stable_uid: bool = second.is_empty() or String(second.get("uniqueId", "")) == first_uid
		rows.append({
			"case": case_id,
			"issued": not first.is_empty(),
			"uid": first_uid,
			"completed": completed,
			"repeatUidStable": stable_uid,
			"outcome": String(gs.campaign_state.get("caseOutcomes", {}).get(case_id, "")),
			"currentAct": String(gs.campaign_state.get("currentAct", ""))
		})
		if not completed:
			return {"ok": false, "cases": rows, "reason": "CASE_CHAIN_FAILED"}
	var reserve_result: Dictionary = {}
	if bool(definition.get("includes_grand_reserve", false)):
		var eligible: Array = gs.eligible_final_lots()
		var selected: Array = []
		for lot: Dictionary in eligible:
			if selected.size() >= 3:
				break
			var uid := String(lot.get("uniqueId", ""))
			if not uid.is_empty() and not selected.has(uid):
				var selection: Variant = gs.select_final_lot(uid)
				if bool(selection):
					selected.append(uid)
		reserve_result = gs.run_grand_reserve()
	var stage_status := String(gs.stage_run_state.get("status", ""))
	var cleared := stage_status == "CLEARED"
	var acknowledged := false
	if cleared:
		var ack: Dictionary = gs.acknowledge_stage_clear()
		acknowledged = bool(ack.get("ok", false))
	var expected_unlocked := mini(10, stage_id + 1)
	var profile_ok := int(gs.player_profile.get("highestUnlockedStage", 1)) >= expected_unlocked if stage_id < 10 else int(gs.player_profile.get("highestUnlockedStage", 1)) == 10
	var all_case_rows_ok: bool = rows.size() == definition.get("case_ids", []).size()
	for row: Dictionary in rows:
		all_case_rows_ok = all_case_rows_ok and bool(row.get("issued", false)) and bool(row.get("completed", false)) and bool(row.get("repeatUidStable", false))
	var reserve_ok := true
	if bool(definition.get("includes_grand_reserve", false)):
		reserve_ok = bool(reserve_result.get("ok", false)) and reserve_result.get("results", []).size() == 3 and bool(gs.campaign_state.get("grandReserve", {}).get("completed", false))
	return {
		"ok": all_case_rows_ok and cleared and acknowledged and profile_ok and reserve_ok,
		"stage": stage_id,
		"difficulty": gs.stage_difficulty_multiplier(stage_id),
		"cases": rows,
		"reserve": reserve_result,
		"snapshot": snapshot(gs),
		"expectedNextUnlock": expected_unlocked,
		"profileOk": profile_ok,
		"allCaseRowsOk": all_case_rows_ok,
		"cleared": cleared,
		"acknowledged": acknowledged,
		"reserveOk": reserve_ok
	}


func cleanup(gs: Node, path: String) -> void:
	gs.remove_save_file(path)
	gs.remove_save_file(path + gs.SAVE_TEMP_SUFFIX)
	gs.remove_save_file(path + gs.SAVE_BACKUP_SUFFIX)


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	gs.campaign_test_mode = true
	gs.persistence_enabled = false
	gs.language = "en"
	gs.player_profile = gs.default_player_profile()
	gs.reset_game()

	var initial: Dictionary = gs.new_game(1)
	var initial_routes: Array = []
	for route: String in ["title", "stage_select", "campaign", "market", "event", "workshop"]:
		initial_routes.append(route_probe(main, route))
	var routes_ok := bool(initial.get("ok", false))
	for route_row: Dictionary in initial_routes:
		routes_ok = routes_ok and bool(route_row.get("ok", false))
	record("E2E-BOOT-ROUTES", "Fresh profile starts a Stage 1 run and all core non-terminal routes construct", routes_ok, {"start": initial, "routes": initial_routes})

	# Exercise the same Stage 1 artifact through dossier and inspection UI before
	# the public helper completes its report/repair/list/sale chain.
	var prologue_artifact: Dictionary = gs.begin_case("prologue_clock")
	main.selected = prologue_artifact
	main.load_artifact(prologue_artifact)
	main.show_case_dossier("prologue_clock")
	var dossier_ok: bool = main.screen == "case_dossier"
	main.show_inspection()
	var inspection_ok: bool = main.screen == "inspection" and not main.selected.is_empty()
	var observable_visible: bool = main.find_children("InspectionObservableTile", "PanelContainer", true, false).size() == 1
	var prologue_complete: bool = gs.prepare_case_for_test("prologue_clock")
	record("E2E-UI-CHAIN", "First lot exposes dossier/inspection before the complete public case chain", dossier_ok and inspection_ok and prologue_complete, {"dossier": dossier_ok, "inspection": inspection_ok, "observableTile": observable_visible, "completed": prologue_complete, "artifact": prologue_artifact.get("uniqueId", "")})

	var stage1_remaining := true
	for case_value: Variant in registry.get_stage_definition(1).get("case_ids", []):
		var case_id := String(case_value)
		if case_id == "prologue_clock":
			continue
		stage1_remaining = stage1_remaining and gs.prepare_case_for_test(case_id)
	var stage1_snapshot := snapshot(gs)
	var stage1_ack: Dictionary = gs.acknowledge_stage_clear() if stage1_snapshot.stageStatus == "CLEARED" else {"ok": false, "code": "NOT_CLEARED"}
	stage1_snapshot = snapshot(gs)
	record("E2E-STAGE1", "Stage 1 completes every scoped case and clears without target-score gating", stage1_remaining and stage1_snapshot.stageStatus == "CLEARED" and stage1_snapshot.highestUnlockedStage >= 2 and stage1_snapshot.clearAcknowledged, {"remaining": stage1_remaining, "ack": stage1_ack, "snapshot": stage1_snapshot})

	for stage_id in range(2, 11):
		var started: Dictionary = gs.new_game(stage_id)
		var row := complete_current_stage(gs, registry, stage_id)
		row["start"] = started
		stage_rows.append(row)
		record("E2E-STAGE-%02d" % stage_id, "Fresh-run replay completes Stage %d and preserves the next unlock" % stage_id, bool(started.get("ok", false)) and bool(row.get("ok", false)), row)

	# The stage-clear handoff and the epilogue acknowledgement are separate
	# public boundaries; follow both before asserting postgame.
	if not String(gs.campaign_state.get("currentEnding", "")).is_empty() and not bool(gs.campaign_state.get("postGame", false)):
		gs.acknowledge_epilogue()
	var final_routes: Array = []
	if not String(gs.campaign_state.get("currentEnding", "")).is_empty():
		for route: String in ["ending", "postgame"]:
			final_routes.append(route_probe(main, route))
	var final_route_ok := final_routes.size() == 2
	for route_row: Dictionary in final_routes:
		final_route_ok = final_route_ok and bool(route_row.get("ok", false))
	record("E2E-ENDINGS", "Stage 10 reaches ending/postgame routes after Grand Reserve", final_route_ok and bool(gs.campaign_state.get("postGame", false)), {"routes": final_routes, "snapshot": snapshot(gs)})

	# Simulate process restart with isolated audit slots. The default player save
	# and run save are never touched by this script.
	var profile_path := "user://r3_fresh_profile_e2e_profile.json"
	var save_path := "user://r3_fresh_profile_e2e_save.json"
	cleanup(gs, profile_path)
	cleanup(gs, save_path)
	gs.persistence_enabled = true
	var before_restart := snapshot(gs)
	var saved_profile: bool = gs.save_profile(profile_path)
	var saved_run: bool = gs.save_game(save_path)
	gs.player_profile = gs.default_player_profile()
	gs.current_stage = 1
	gs.stage_run_state = gs.default_stage_run_state(1)
	gs.campaign_state = gs.default_campaign_state()
	var loaded_profile: bool = gs.load_profile(profile_path)
	var loaded_run: bool = gs.load_game(save_path)
	var after_restart := snapshot(gs)
	var restart_ok := saved_profile and saved_run and loaded_profile and loaded_run and before_restart == after_restart
	record("E2E-RESTART", "Profile/run save reload restores Stage 10 postgame state exactly", restart_ok, {"savedProfile": saved_profile, "savedRun": saved_run, "loadedProfile": loaded_profile, "loadedRun": loaded_run, "before": before_restart, "after": after_restart})
	cleanup(gs, profile_path)
	cleanup(gs, save_path)
	gs.persistence_enabled = false

	# NEW GAME is allowed after completion, but must not relock the stage select.
	var preserved_profile: Dictionary = gs.profile_payload()
	var replay_start: Dictionary = gs.new_game(1)
	main.show_stage_select()
	var stage10_button := main.find_child("StageSelect_10", true, false)
	var profile_preserved_ok: bool = persistent_progression(gs.profile_payload()) == persistent_progression(preserved_profile)
	var stage10_selectable: bool = stage10_button != null and not bool(stage10_button.disabled)
	var replay_ok: bool = bool(replay_start.get("ok", false)) and profile_preserved_ok and stage10_selectable
	record("E2E-REPLAY", "NEW GAME resets only the run and keeps all ten stages selectable", replay_ok, {"start": replay_start, "profileBefore": preserved_profile, "profile": gs.profile_payload(), "profilePreserved": profile_preserved_ok, "stage10Button": stage10_button != null, "stage10Selectable": stage10_selectable, "stage10Disabled": stage10_button.disabled if stage10_button != null else null})

	var passed := 0
	for check: Dictionary in checks:
		if bool(check.get("passed", false)):
			passed += 1
	var report := {
		"suite": "R3 fresh profile 1-10 E2E audit",
		"mode": "audit-only",
		"productionMutations": 0,
		"executed": checks.size(),
		"passed": passed,
		"failed": checks.size() - passed,
		"stages": stage_rows,
		"checks": checks,
		"humanPlaytestRequired": true,
		"humanPlaytestUnverified": ["first-time comprehension", "auction cause recall", "portrait legibility at native display", "felt difficulty curve"]
	}
	var output := FileAccess.open("res://qa/R3_FRESH_PROFILE_E2E.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	main.queue_free()
	quit(0 if passed == checks.size() else 1)
