extends SceneTree

## Ten-stage MVP runtime/profile regression suite. Runs headlessly and never
## creates a Windows export or archive.

const CRASH_CASES := [
	{"id": "STAGE-PROFILE-CRASH-A", "point": "A_TMP_WRITE_INTERRUPTION", "expected": "OLD", "recovered": false},
	{"id": "STAGE-PROFILE-CRASH-B", "point": "B_TMP_COMPLETE_BEFORE_VALIDATION", "expected": "OLD", "recovered": false},
	{"id": "STAGE-PROFILE-CRASH-C", "point": "C_TMP_VALIDATED_BEFORE_BACKUP", "expected": "OLD", "recovered": false},
	{"id": "STAGE-PROFILE-CRASH-D", "point": "D_AFTER_BACKUP_BEFORE_PROMOTE", "expected": "OLD", "recovered": true},
	{"id": "STAGE-PROFILE-CRASH-E", "point": "E_AFTER_PROMOTE_BEFORE_FINAL_VALIDATION", "expected": "NEW", "recovered": false},
	{"id": "STAGE-PROFILE-CRASH-F", "point": "F_CORRUPT_PROMOTED_CURRENT", "expected": "OLD", "recovered": true}
]

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, condition: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": condition, "evidence": evidence})


func approx_equal(left: float, right: float, epsilon: float = 0.000001) -> bool:
	return absf(left - right) <= epsilon


func cleanup_slots(gs: Node, path: String) -> void:
	gs.remove_save_file(path)
	gs.remove_save_file(path + gs.SAVE_TEMP_SUFFIX)
	gs.remove_save_file(path + gs.SAVE_BACKUP_SUFFIX)


func write_raw(path: String, contents: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.flush()
	file.close()
	return true


func satisfy_stage_objectives(gs: Node, registry: Node, stage_id: int) -> void:
	var definition: Dictionary = registry.get_stage_definition(stage_id)
	for case_id_value: Variant in definition.get("case_ids", []):
		var case_id := String(case_id_value)
		gs.campaign_state.completedCases[case_id] = true
		gs.campaign_state.caseOutcomes[case_id] = "credible"
	if bool(definition.get("includes_grand_reserve", false)):
		gs.campaign_state.grandReserve.completed = true
		gs.campaign_state.grandReserve.score = {"balancedScore": 80.0}


func profile_fixture(gs: Node, generation: String) -> Dictionary:
	match generation:
		"OLD":
			gs.player_profile = {"schema_version": 1, "highestUnlockedStage": 2, "clearedStages": [1], "stageBest": {"1": 101.0}, "tutorialCompletedSteps": ["INVESTIGATE"]}
		"NEW":
			gs.player_profile = {"schema_version": 1, "highestUnlockedStage": 4, "clearedStages": [1, 2, 3], "stageBest": {"1": 101.0, "2": 202.0, "3": 303.0}, "tutorialCompletedSteps": ["INVESTIGATE", "CITE", "REPORT"]}
		_:
			gs.player_profile = {"schema_version": 1, "highestUnlockedStage": 9, "clearedStages": [1, 2, 3, 4], "stageBest": {"1": 999.0}, "tutorialCompletedSteps": ["INVESTIGATE", "CITE", "REPORT", "REPAIR", "LIST", "AUCTION"]}
	return gs.profile_payload()


func run_profile_crash_case(gs: Node, fixture: Dictionary, index: int) -> void:
	var path := "user://r3_stage_profile_crash_%02d.json" % index
	cleanup_slots(gs, path)
	var old_profile := profile_fixture(gs, "OLD")
	var baseline_saved: bool = gs.save_profile(path)
	var new_profile := profile_fixture(gs, "NEW")
	var configured: bool = gs.configure_profile_crash_injection_for_test(fixture.point)
	var interrupted_saved: bool = gs.save_profile(path)
	var save_error: String = gs.last_profile_save_error
	var memory_profile := profile_fixture(gs, "MEMORY")
	var loaded: bool = gs.load_profile(path)
	var actual: Dictionary = gs.profile_payload()
	var expected: Dictionary = old_profile if fixture.expected == "OLD" else new_profile
	record(
		fixture.id,
		"%s recovers one complete profile generation" % fixture.point,
		baseline_saved
			and configured
			and not interrupted_saved
			and save_error == "TEST_CRASH_INJECTION:%s" % fixture.point
			and loaded
			and actual == expected
			and actual != memory_profile
			and gs.last_profile_load_recovered == bool(fixture.recovered)
			and gs.last_profile_load_error.is_empty(),
		{
			"expected": fixture.expected,
			"actual": actual,
			"saveError": save_error,
			"loadRecovered": gs.last_profile_load_recovered,
			"loadError": gs.last_profile_load_error
		}
	)
	cleanup_slots(gs, path)


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.campaign_test_mode = true
	gs.persistence_enabled = false
	gs.player_profile = gs.default_player_profile()
	gs.reset_game()

	var multiplier_failures: Array = []
	var stage_artifact_failures: Array = []
	var expected_available := 60
	for stage_id in range(1, 11):
		var definition: Dictionary = registry.get_stage_definition(stage_id)
		var expected_multiplier := pow(1.07, stage_id - 1)
		if definition.is_empty() or not approx_equal(float(definition.get("difficulty_multiplier", 0.0)), expected_multiplier):
			multiplier_failures.append({"stage": stage_id, "actual": definition.get("difficulty_multiplier", null), "expected": expected_multiplier})
		var introduced: Array = definition.get("introduced_artifact_ids", [])
		expected_available += 2
		if introduced.size() != 2 or registry.available_spec_ids_for_stage(stage_id).size() != expected_available:
			stage_artifact_failures.append({"stage": stage_id, "introduced": introduced, "available": registry.available_spec_ids_for_stage(stage_id).size()})
	record("STAGE-DATA-01", "Exactly ten data-driven stage definitions load", registry.stage_definitions.size() == 10 and registry.stage_order == range(1, 11) and registry.stage_definition_errors.is_empty(), {"stages": registry.stage_order, "errors": registry.stage_definition_errors})
	record("STAGE-DATA-02", "Difficulty is exactly pow(1.07, stage-1)", multiplier_failures.is_empty() and approx_equal(registry.stage_difficulty_multiplier(10), 1.8384592124201547), multiplier_failures)
	record("STAGE-DATA-03", "Each stage introduces two cumulatively unlocked artifacts", stage_artifact_failures.is_empty(), stage_artifact_failures)

	var tutorial_contract: Dictionary = registry.stage_config.get("tutorial_contract", {})
	var tutorial_steps: Array = tutorial_contract.get("steps", [])
	var tutorial_step_ids: Array = []
	var tutorial_events: Array = []
	var tutorial_private_tokens: Array = ["step_id", "trigger", "complete_when", "route_ui_ids"]
	for tutorial_step_value: Variant in tutorial_steps:
		var tutorial_step: Dictionary = tutorial_step_value
		tutorial_step_ids.append(String(tutorial_step.get("step_id", "")))
		tutorial_events.append(String(tutorial_step.get("complete_when", "")))
		tutorial_private_tokens.append(String(tutorial_step.get("step_id", "")))
		tutorial_private_tokens.append(String(tutorial_step.get("trigger", "")))
		tutorial_private_tokens.append(String(tutorial_step.get("complete_when", "")))
	var tutorial_public_failures: Array = []
	var tutorial_sequence_failures: Array = []
	var expected_tutorial_keys: Array = ["icon", "step", "target", "targets", "text", "title", "total", "visible"]
	gs.player_profile = gs.default_player_profile()
	gs.language = "en"
	var tutorial_start: Dictionary = gs.new_game(1)
	for tutorial_index in range(tutorial_steps.size()):
		var authored_step: Dictionary = tutorial_steps[tutorial_index]
		var expected_targets: Array = []
		var primary_target := String(authored_step.get("target_ui_id", ""))
		if not primary_target.is_empty():
			expected_targets.append(primary_target)
		for route_value: Variant in authored_step.get("route_ui_ids", []):
			var route_id := String(route_value)
			if not route_id.is_empty() and not expected_targets.has(route_id):
				expected_targets.append(route_id)
		for locale: String in ["en", "ko"]:
			gs.language = locale
			var public_step: Dictionary = gs.tutorial_public_state()
			var public_keys: Array = public_step.keys()
			public_keys.sort()
			var public_json := JSON.stringify(public_step)
			var leaked_tokens: Array = []
			for token_value: Variant in tutorial_private_tokens:
				var token := String(token_value)
				if not token.is_empty() and public_json.contains(token):
					leaked_tokens.append(token)
			var public_valid: bool = public_keys == expected_tutorial_keys \
				and bool(public_step.get("visible", false)) \
				and int(public_step.get("step", 0)) == tutorial_index + 1 \
				and int(public_step.get("total", 0)) == tutorial_steps.size() \
				and public_step.get("title", "") == authored_step.get("title", {}).get(locale, "") \
				and public_step.get("text", "") == authored_step.get("text", {}).get(locale, "") \
				and public_step.get("icon", "") == authored_step.get("icon", "") \
				and public_step.get("target", "") == primary_target \
				and public_step.get("targets", []) == expected_targets \
				and leaked_tokens.is_empty()
			if not public_valid:
				tutorial_public_failures.append({"locale": locale, "index": tutorial_index, "state": public_step, "leaks": leaked_tokens, "expectedTargets": expected_targets})
		gs.language = "en"
		var out_of_order_event := String(tutorial_events[tutorial_index + 1]) if tutorial_index + 1 < tutorial_events.size() else String(tutorial_events[0])
		var out_of_order_changed: bool = gs.complete_tutorial_event(out_of_order_event)
		var expected_event := String(tutorial_events[tutorial_index])
		var expected_changed: bool = gs.complete_tutorial_event(expected_event)
		var completed_after: Array = gs.player_profile.get("tutorialCompletedSteps", []).duplicate()
		var duplicate_changed: bool = gs.complete_tutorial_event(expected_event)
		var expected_prefix: Array = tutorial_step_ids.slice(0, tutorial_index + 1)
		if out_of_order_changed or not expected_changed or duplicate_changed or completed_after != expected_prefix or gs.player_profile.get("tutorialCompletedSteps", []) != expected_prefix:
			tutorial_sequence_failures.append({"index": tutorial_index, "outOfOrderChanged": out_of_order_changed, "expectedChanged": expected_changed, "duplicateChanged": duplicate_changed, "completed": completed_after, "expected": expected_prefix})
	var tutorial_done_state: Dictionary = gs.tutorial_public_state()
	var tutorial_contract_ok: bool = int(tutorial_contract.get("stage_id", 0)) == 1 \
		and int(tutorial_contract.get("max_steps", 0)) == 6 \
		and tutorial_steps.size() == 6 \
		and tutorial_step_ids == ["INVESTIGATE", "CITE", "REPORT", "REPAIR", "LIST", "AUCTION"] \
		and bool(tutorial_start.get("ok", false))
	var tutorial_done_safe: bool = not bool(tutorial_done_state.get("visible", true)) \
		and int(tutorial_done_state.get("step", 0)) == 6 \
		and int(tutorial_done_state.get("total", 0)) == 6 \
		and String(tutorial_done_state.get("title", "")).is_empty() \
		and tutorial_done_state.get("targets", ["unexpected"]).is_empty()
	record("STAGE-TUTORIAL-01", "Stage 1 exposes six localized presentation-safe steps and accepts only the next event idempotently", tutorial_contract_ok and tutorial_public_failures.is_empty() and tutorial_sequence_failures.is_empty() and tutorial_done_safe, {"contract": tutorial_contract_ok, "publicFailures": tutorial_public_failures, "sequenceFailures": tutorial_sequence_failures, "done": tutorial_done_state})

	gs.reset_tutorial_guidance()
	var skip_start: Dictionary = gs.new_game(1)
	var skip_result: Dictionary = gs.skip_tutorial_guidance()
	var skip_public: Dictionary = gs.tutorial_public_state()
	var skip_new_game: Dictionary = gs.new_game(1)
	var skip_contract_ok: bool = bool(skip_start.get("ok", false)) \
		and bool(skip_result.get("ok", false)) \
		and String(skip_result.get("code", "")) == "TUTORIAL_SKIPPED" \
		and skip_result.get("completedSteps", []) == tutorial_step_ids \
		and not bool(skip_public.get("visible", true)) \
		and gs.player_profile.get("tutorialCompletedSteps", []) == tutorial_step_ids \
		and bool(skip_new_game.get("ok", false)) \
		and not bool(gs.tutorial_public_state().get("visible", true))
	record("STAGE-TUTORIAL-04", "Active Stage 1 guidance can be skipped once, persists the preference, and remains hidden on later NEW GAME sessions", skip_contract_ok, {"start": skip_start, "skip": skip_result, "publicAfterSkip": skip_public, "newGame": skip_new_game, "profile": gs.player_profile.get("tutorialCompletedSteps", [])})

	gs.player_profile = {"schema_version": 1, "highestUnlockedStage": 3, "clearedStages": [1, 2], "stageBest": {"1": 80.0, "2": 82.0}, "tutorialCompletedSteps": tutorial_step_ids}
	gs.reset_game()
	var progression_start: Dictionary = gs.new_game_progression()
	var progression_ok: bool = gs.next_progression_stage() == 3 and bool(progression_start.get("ok", false)) and int(progression_start.get("stage", 0)) == 3
	gs.stage_run_state.status = "CLEARED"
	gs.stage_run_state.stageClearAcknowledged = true
	gs.player_profile = {"schema_version": 1, "highestUnlockedStage": 10, "clearedStages": range(1, 10), "stageBest": {}, "tutorialCompletedSteps": tutorial_step_ids}
	var final_progression_ok: bool = gs.next_progression_stage() == 10
	record("STAGE-PROGRESSION-01", "NEW GAME progression starts the first uncleared stage while cleared stages remain replayable", progression_ok and final_progression_ok, {"nextStage": 3, "started": progression_start, "finalNextStage": gs.next_progression_stage()})

	var complete_profile: Dictionary = gs.profile_payload()
	var completed_new_game: Dictionary = gs.new_game(1)
	var full_persists_new_game: bool = bool(completed_new_game.get("ok", false)) \
		and gs.profile_payload() == complete_profile \
		and not bool(gs.tutorial_public_state().get("visible", true))
	gs.reset_game()
	var completed_reset_start: Dictionary = gs.start_stage(1)
	var full_persists_reset: bool = bool(completed_reset_start.get("ok", false)) \
		and gs.profile_payload() == complete_profile \
		and not bool(gs.tutorial_public_state().get("visible", true))
	var tutorial_profile_path := "user://r3_stage_tutorial_profile.json"
	cleanup_slots(gs, tutorial_profile_path)
	gs.persistence_enabled = true
	var tutorial_profile_saved: bool = gs.save_profile(tutorial_profile_path)
	gs.player_profile = gs.default_player_profile()
	var tutorial_profile_loaded: bool = gs.load_profile(tutorial_profile_path)
	gs.persistence_enabled = false
	var full_persists_reload: bool = tutorial_profile_saved and tutorial_profile_loaded and gs.profile_payload() == complete_profile
	cleanup_slots(gs, tutorial_profile_path)
	var explicit_replay_reset: bool = gs.reset_tutorial_guidance()
	var explicit_reset_state: Dictionary = gs.tutorial_public_state()
	for completed_index in range(3):
		gs.complete_tutorial_event(String(tutorial_events[completed_index]))
	var partial_before_reset: Array = gs.player_profile.get("tutorialCompletedSteps", []).duplicate()
	var partial_profile_path := "user://r3_stage_tutorial_partial_profile.json"
	cleanup_slots(gs, partial_profile_path)
	gs.persistence_enabled = true
	var partial_profile_saved: bool = gs.save_profile(partial_profile_path)
	gs.player_profile = gs.default_player_profile()
	var partial_profile_loaded: bool = gs.load_profile(partial_profile_path)
	gs.persistence_enabled = false
	var partial_persists_reload: bool = partial_profile_saved \
		and partial_profile_loaded \
		and gs.player_profile.get("tutorialCompletedSteps", []) == partial_before_reset
	cleanup_slots(gs, partial_profile_path)
	gs.reset_game()
	var partial_reset_start: Dictionary = gs.start_stage(1)
	var partial_survives_run_reset: bool = bool(partial_reset_start.get("ok", false)) and gs.player_profile.get("tutorialCompletedSteps", []) == partial_before_reset and int(gs.tutorial_public_state().get("step", 0)) == 4
	var partial_new_game: Dictionary = gs.new_game(1)
	var partial_restarts_fresh_run: bool = bool(partial_new_game.get("ok", false)) and gs.player_profile.get("tutorialCompletedSteps", []).is_empty() and int(gs.tutorial_public_state().get("step", 0)) == 1
	var legacy_profile := {"schema_version": 1, "highestUnlockedStage": 1, "clearedStages": [], "stageBest": {}}
	var legacy_validation: Dictionary = gs.validate_profile_payload(legacy_profile)
	gs.normalize_profile_dictionary(legacy_profile)
	var invalid_tutorial_profile := {"schema_version": 1, "highestUnlockedStage": 1, "clearedStages": [], "stageBest": {}, "tutorialCompletedSteps": ["CITE"]}
	var invalid_tutorial_validation: Dictionary = gs.validate_profile_payload(invalid_tutorial_profile)
	var tutorial_profile_ok: bool = full_persists_new_game \
		and full_persists_reset \
		and full_persists_reload \
		and explicit_replay_reset \
		and bool(explicit_reset_state.get("visible", false)) \
		and int(explicit_reset_state.get("step", 0)) == 1 \
		and partial_before_reset == ["INVESTIGATE", "CITE", "REPORT"] \
		and partial_persists_reload \
		and partial_survives_run_reset \
		and partial_restarts_fresh_run \
		and bool(legacy_validation.get("ok", false)) \
		and legacy_profile.get("tutorialCompletedSteps", ["unexpected"]).is_empty() \
		and not bool(invalid_tutorial_validation.get("ok", true)) \
		and invalid_tutorial_validation.get("code", "") == "INVALID_TUTORIAL_STEP_SEQUENCE"
	record("STAGE-TUTORIAL-02", "Full guidance completion persists across reset, NEW GAME and profile reload while partial guidance survives profile/run reload but restarts with a fresh Stage 1 run", tutorial_profile_ok, {"fullNewGame": full_persists_new_game, "fullReset": full_persists_reset, "fullReload": full_persists_reload, "explicitReset": explicit_reset_state, "partialBefore": partial_before_reset, "partialReload": partial_persists_reload, "partialReset": partial_survives_run_reset, "partialNewGame": partial_new_game, "legacy": legacy_profile, "invalid": invalid_tutorial_validation})

	gs.player_profile = gs.default_player_profile()
	gs.new_game(1)
	for completed_index in range(3):
		gs.complete_tutorial_event(String(tutorial_events[completed_index]))
	var advisory_artifact: Dictionary = gs.new_artifact("artifact_001", 110011, "tutorial_advisory_listing")
	gs.inventory.append(advisory_artifact)
	var advisory_listed: bool = gs.list_auction(advisory_artifact, 1, 1, 0.5, "UNCERTAIN")
	var advisory_prefix_unchanged: bool = gs.player_profile.get("tutorialCompletedSteps", []) == ["INVESTIGATE", "CITE", "REPORT"]
	gs.player_profile.highestUnlockedStage = 2
	var stage_two_tutorial_start: Dictionary = gs.new_game(2)
	var stage_two_public: Dictionary = gs.tutorial_public_state()
	var stage_two_event_ignored: bool = not gs.complete_tutorial_event(String(tutorial_events[3]))
	var stage_two_inactive: bool = bool(stage_two_tutorial_start.get("ok", false)) \
		and not bool(stage_two_public.get("visible", true)) \
		and stage_two_event_ignored \
		and gs.player_profile.get("tutorialCompletedSteps", []) == ["INVESTIGATE", "CITE", "REPORT"]
	record("STAGE-TUTORIAL-03", "Tutorial guidance is advisory, cannot block listing, ignores out-of-order hooks and is inactive outside Stage 1", advisory_listed and advisory_prefix_unchanged and stage_two_inactive, {"listedWithoutRepair": advisory_listed, "prefix": gs.player_profile.get("tutorialCompletedSteps", []), "stage2": stage_two_public, "eventIgnored": stage_two_event_ignored})

	gs.player_profile = gs.default_player_profile()
	gs.language = "en"
	var real_tutorial_start: Dictionary = gs.new_game(1)
	var prologue_artifact: Dictionary = gs.begin_case("prologue_clock")
	var prologue_definition: Dictionary = gs.case_definition("prologue_clock")
	var first_evidence_id := ""
	for evidence_value: Variant in prologue_definition.get("evidence", []):
		var evidence: Dictionary = evidence_value
		if evidence.get("unlock", {}).get("requires_all", []).is_empty() and evidence.get("unlock", {}).get("requires_tools", []).is_empty():
			first_evidence_id = String(evidence.get("id", ""))
			break
	var discovered_result: Dictionary = gs.discover_case_evidence("prologue_clock", first_evidence_id) if not first_evidence_id.is_empty() else {}
	var discover_hooked: bool = bool(discovered_result.get("ok", false)) and gs.player_profile.get("tutorialCompletedSteps", []) == ["INVESTIGATE"]
	var cited_result: bool = gs.toggle_case_citation("prologue_clock", first_evidence_id)
	var cite_hooked: bool = cited_result and gs.player_profile.get("tutorialCompletedSteps", []) == ["INVESTIGATE", "CITE"]
	var canonical_hypothesis := String(prologue_definition.get("canonical_hypothesis_id", ""))
	var resolved_result: Dictionary = gs.resolve_case_v2("prologue_clock", canonical_hypothesis, [first_evidence_id])
	var report_hooked: bool = bool(resolved_result.get("ok", false)) and gs.player_profile.get("tutorialCompletedSteps", []) == ["INVESTIGATE", "CITE", "REPORT"]
	var prologue_profile: Dictionary = prologue_artifact.get("repairProfile", {})
	var real_repair_route_authored: bool = prologue_artifact.get("damageInstances", []).has("CRACK") \
		and prologue_profile.get("requiredTools", []) == ["precision_screwdriver"] \
		and prologue_profile.get("repairableDamages", []) == ["CRACK"] \
		and not String(prologue_profile.get("interventionTradeoff", {}).get("en", "")).is_empty() \
		and not String(prologue_profile.get("interventionTradeoff", {}).get("ko", "")).is_empty()
	var wrong_tool_repair: String = gs.repair(prologue_artifact)
	var wrong_tool_not_completed: bool = wrong_tool_repair == "Required precision tool is not selected." and gs.player_profile.get("tutorialCompletedSteps", []) == ["INVESTIGATE", "CITE", "REPORT"]
	var selected_recommended_tool: bool = gs.select_tool("precision_screwdriver")
	var actual_repair: String = gs.repair(prologue_artifact)
	var repair_hooked: bool = actual_repair == "Mechanism repaired." \
		and selected_recommended_tool \
		and not prologue_artifact.get("damageInstances", []).has("CRACK") \
		and gs.player_profile.get("tutorialCompletedSteps", []) == ["INVESTIGATE", "CITE", "REPORT", "REPAIR"]
	var real_listed: bool = gs.list_auction(prologue_artifact, 1, 1, 0.8, "LIKELY")
	var list_hooked: bool = real_listed and gs.player_profile.get("tutorialCompletedSteps", []) == ["INVESTIGATE", "CITE", "REPORT", "REPAIR", "LIST"]
	var no_sale_result: Dictionary = {"reserve_met": false, "sale_status": "NO_SALE", "net": 0, "hammer": 0}
	gs.apply_sale_result(prologue_artifact, no_sale_result, false, false)
	var no_sale_hooked: bool = gs.stage_run_state.get("tutorialCompletedSteps", []) == tutorial_step_ids \
		and not gs.auction_history.is_empty() \
		and gs.auction_history[-1].get("status", "") == "NO_SALE"

	gs.reset_tutorial_guidance()
	gs.new_game(1)
	for completed_index in range(5):
		gs.complete_tutorial_event(String(tutorial_events[completed_index]))
	var sold_artifact: Dictionary = gs.new_artifact("artifact_001", 110012, "tutorial_sold_result")
	sold_artifact.listing = {"starting": 1, "reserve": 1, "confidence": 0.8, "disclosure": "LIKELY"}
	gs.inventory.append(sold_artifact)
	var sold_result: Dictionary = {"reserve_met": true, "sale_status": "SOLD", "net": 100, "hammer": 120}
	gs.apply_sale_result(sold_artifact, sold_result, false, false)
	var sold_hooked: bool = gs.stage_run_state.get("tutorialCompletedSteps", []) == tutorial_step_ids \
		and not gs.auction_history.is_empty() \
		and gs.auction_history[-1].get("status", "") == "SOLD" \
		and not gs.inventory.has(sold_artifact)
	var real_hook_chain: bool = bool(real_tutorial_start.get("ok", false)) \
		and not prologue_artifact.is_empty() \
		and discover_hooked \
		and cite_hooked \
		and report_hooked \
		and real_repair_route_authored \
		and wrong_tool_not_completed \
		and repair_hooked \
		and list_hooked \
		and no_sale_hooked \
		and sold_hooked
	record("STAGE-TUTORIAL-04", "Real Stage 1 investigate, cite, report, recommended repair, listing and both auction outcomes drive the six hooks without counting a wrong-tool no-op", real_hook_chain, {"evidence": first_evidence_id, "discover": discovered_result, "cite": cited_result, "resolve": resolved_result, "repairProfile": prologue_profile, "wrongTool": wrong_tool_repair, "repair": actual_repair, "listed": real_listed, "noSaleHooked": no_sale_hooked, "soldHooked": sold_hooked, "completed": gs.stage_run_state.get("tutorialCompletedSteps", [])})
	gs.player_profile = gs.default_player_profile()
	gs.language = "en"
	gs.reset_game()

	var spotlight_failures: Array = []
	gs.player_profile = {"schema_version": 1, "highestUnlockedStage": 10, "clearedStages": range(1, 10), "stageBest": {}}
	for stage_id in range(1, 11):
		var start_result: Dictionary = gs.new_game(stage_id)
		var definition: Dictionary = registry.get_stage_definition(stage_id)
		var introduced: Array = definition.get("introduced_artifact_ids", [])
		var available: Array = registry.available_spec_ids_for_stage(stage_id)
		var first_roster: Array = gs.market_roster.duplicate(true)
		var first_ids: Array = gs.market_spec_ids()
		var seen := {}
		var outside_pool: Array = []
		for spec_id_value: Variant in first_ids:
			var spec_id := String(spec_id_value)
			seen[spec_id] = true
			if not available.has(spec_id):
				outside_pool.append(spec_id)
		var cached_roster: Array = gs.generate_market_roster().duplicate(true)
		var repeated_start: Dictionary = gs.new_game(stage_id)
		var repeated_roster: Array = gs.market_roster.duplicate(true)
		var spotlight_ok: bool = bool(start_result.get("ok", false)) \
			and bool(repeated_start.get("ok", false)) \
			and first_ids.size() == 5 \
			and seen.size() == 5 \
			and outside_pool.is_empty() \
			and introduced.size() == 2 \
			and first_ids.slice(0, 2) == introduced \
			and first_ids.count(introduced[0]) == 1 \
			and first_ids.count(introduced[1]) == 1 \
			and cached_roster == first_roster \
			and repeated_roster == first_roster
		if not spotlight_ok:
			spotlight_failures.append({"stage": stage_id, "start": start_result, "introduced": introduced, "ids": first_ids, "unique": seen.size(), "outside": outside_pool, "cachedSame": cached_roster == first_roster, "repeatSame": repeated_roster == first_roster})
	record("STAGE-MARKET-SPOTLIGHT-01", "Every stage starts with both introduced artifacts exactly once in a deterministic five-lot cumulative roster", spotlight_failures.is_empty(), spotlight_failures)

	gs.player_profile = {"schema_version": 1, "highestUnlockedStage": 10, "clearedStages": range(1, 10), "stageBest": {}}
	var reachability_start: Dictionary = gs.new_game(5)
	var target_lot: Dictionary = {}
	for lot: Dictionary in gs.market_roster:
		if lot.get("specId", "") == "artifact_070":
			target_lot = lot
			break
	var roster_ids_before_buy: Array = gs.market_spec_ids()
	var money_before_buy := int(gs.money)
	var naturally_affordable: bool = not target_lot.is_empty() and money_before_buy >= int(target_lot.get("price", money_before_buy + 1))
	var bought_spotlight: bool = not target_lot.is_empty() and gs.buy_market_lot(String(target_lot.get("lotId", "")))
	var cached_after_buy: Array = gs.generate_market_roster()
	var sold_lot_preserved := false
	for lot: Dictionary in cached_after_buy:
		if lot.get("lotId", "") == target_lot.get("lotId", ""):
			sold_lot_preserved = bool(lot.get("sold", false))
	var roster_after_buy_stable: bool = gs.market_spec_ids() == roster_ids_before_buy and sold_lot_preserved
	var run_payload: Dictionary = gs.save_payload()
	var saved_roster: Array = gs.market_roster.duplicate(true)
	gs.market_roster = []
	gs.inventory = []
	var run_reloaded: bool = gs.apply_save_data(run_payload)
	var roster_save_compatible: bool = run_reloaded and gs.market_roster == saved_roster
	var owned_spotlight: Dictionary = {}
	for artifact: Dictionary in gs.inventory:
		if artifact.get("artifactSpecId", "") == "artifact_070":
			owned_spotlight = artifact
			break
	var target_spec: Dictionary = registry.get_spec("artifact_070")
	var observable_bound: bool = not owned_spotlight.is_empty() \
		and owned_spotlight.get("inspectionObservable", {}) == target_spec.get("inspectionObservable", {}) \
		and not String(owned_spotlight.get("inspectionObservable", {}).get("en", "")).is_empty() \
		and not String(owned_spotlight.get("inspectionObservable", {}).get("ko", "")).is_empty()
	var clue_id := String(owned_spotlight.get("possibleClues", [""])[0]) if not owned_spotlight.get("possibleClues", []).is_empty() else ""
	var inspection_result: Dictionary = gs.inspect_clue(owned_spotlight, clue_id) if not clue_id.is_empty() else {}
	var authored_fault := ""
	for fault_value: Variant in target_spec.get("possibleFaults", []):
		var fault := String(fault_value)
		if owned_spotlight.get("damageInstances", []).has(fault):
			authored_fault = fault
			break
	var required_tools: Array = target_spec.get("repairProfile", {}).get("requiredTools", [])
	var selected_required_tool: bool = not required_tools.is_empty() and gs.select_tool(String(required_tools[0]))
	var repair_message: String = gs.repair(owned_spotlight) if not authored_fault.is_empty() and selected_required_tool else ""
	var repaired_authored_fault: bool = not authored_fault.is_empty() \
		and repair_message == "Mechanism repaired." \
		and not owned_spotlight.get("damageInstances", []).has(authored_fault) \
		and bool(owned_spotlight.get("repaired", false))
	var listed: bool = gs.list_auction(owned_spotlight, 1, 1, maxf(0.7, float(owned_spotlight.get("confidence", 0.0))), "LIKELY")
	var spotlight_auction: Dictionary = gs.auction(owned_spotlight) if listed else {}
	var auction_reached: bool = not spotlight_auction.is_empty() \
		and spotlight_auction.get("sale_status", "") in ["SOLD", "NO_SALE"] \
		and spotlight_auction.get("participants", []).size() >= 6 \
		and spotlight_auction.get("reasonTags", []) is Array
	var expansion_chain_ok: bool = bool(reachability_start.get("ok", false)) \
		and not target_lot.is_empty() \
		and naturally_affordable \
		and bought_spotlight \
		and roster_after_buy_stable \
		and roster_save_compatible \
		and observable_bound \
		and not inspection_result.is_empty() \
		and owned_spotlight.get("knownClues", []).has(clue_id) \
		and repaired_authored_fault \
		and listed \
		and auction_reached
	record("STAGE-MARKET-SPOTLIGHT-02", "A naturally affordable spotlight expansion artifact reaches buy, authored inspection, repair, listing and auction while same-day/save roster state remains stable", expansion_chain_ok, {"start": reachability_start, "lot": target_lot, "moneyBeforeBuy": money_before_buy, "naturallyAffordable": naturally_affordable, "bought": bought_spotlight, "rosterStable": roster_after_buy_stable, "saveCompatible": roster_save_compatible, "observableBound": observable_bound, "clue": clue_id, "inspection": inspection_result, "fault": authored_fault, "repair": repair_message, "listed": listed, "auction": {"status": spotlight_auction.get("sale_status", ""), "participants": spotlight_auction.get("participants", []).size(), "reasons": spotlight_auction.get("reasonTags", [])}})
	gs.player_profile = gs.default_player_profile()
	gs.reset_game()

	var baseline_missing: Array = []
	var expansion_missing: Array = []
	for index in range(1, 61):
		var spec_id := "artifact_%03d" % index
		if not registry.specs.has(spec_id) or not registry.baseline_spec_ids.has(spec_id):
			baseline_missing.append(spec_id)
	for index in range(61, 81):
		var spec_id := "artifact_%03d" % index
		if not registry.specs.has(spec_id) or not registry.expansion_spec_ids.has(spec_id):
			expansion_missing.append(spec_id)
	record("STAGE-CATALOG-01", "Baseline 60 identities remain and expansion reaches 80 specs", registry.specs.size() == 80 and registry.spec_order.size() == 80 and baseline_missing.is_empty() and expansion_missing.is_empty(), {"specs": registry.specs.size(), "baselineMissing": baseline_missing, "expansionMissing": expansion_missing})

	var stage_signatures := {}
	var visual_failures: Array = []
	for index in range(61, 81):
		var spec_id := "artifact_%03d" % index
		var variant: Dictionary = registry.get_visual_variant(spec_id)
		var signature: String = registry.visual_signature(spec_id)
		if variant.is_empty() or signature.is_empty() or stage_signatures.has(signature) or not registry.resolve_model(spec_id) is Mesh or not FileAccess.file_exists(String(variant.get("materialPath", ""))):
			visual_failures.append({"spec": spec_id, "variant": variant.get("id", ""), "signature": signature})
		stage_signatures[signature] = true
	record("STAGE-CATALOG-02", "All 20 expansion specs have unique loadable visual variants", visual_failures.is_empty() and stage_signatures.size() == 20, visual_failures)

	var expansion_spec: Dictionary = registry.get_spec("artifact_061")
	var expansion_artifact: Dictionary = gs.new_artifact("artifact_061", 610061, "stage_binding")
	var serialized: Dictionary = gs.serialize_instance(expansion_artifact)
	var hydrated: Dictionary = gs.hydrate_instance(serialized)
	var immutable_bound: bool = expansion_artifact.inspectionObservable == expansion_spec.inspectionObservable and expansion_artifact.repairProfile == expansion_spec.repairProfile and expansion_artifact.auctionProfile == expansion_spec.auctionProfile
	var hydrate_rebound: bool = hydrated.inspectionObservable == expansion_spec.inspectionObservable and hydrated.repairProfile == expansion_spec.repairProfile and hydrated.auctionProfile == expansion_spec.auctionProfile
	record("STAGE-CATALOG-03", "Expansion inspection, repair and auction profiles bind immutably", immutable_bound and hydrate_rebound and not serialized.has("repairProfile") and not serialized.has("auctionProfile") and not serialized.has("inspectionObservable"), {"bound": immutable_bound, "hydrateRebound": hydrate_rebound, "serializedKeys": serialized.keys()})

	var flattened_cases: Array = []
	for stage_id in range(1, 11):
		flattened_cases.append_array(registry.get_stage_definition(stage_id).get("case_ids", []))
	var canonical_cases: Array = []
	for story_case: Dictionary in registry.campaign.get("cases", []):
		canonical_cases.append(story_case.id)
	record("STAGE-CAMPAIGN-01", "Stage layer preserves the canonical 26-case sequence", flattened_cases == canonical_cases and flattened_cases.size() == 26, {"stageCases": flattened_cases, "campaignCases": canonical_cases})

	var public_summary_failures: Array = []
	var private_tokens: Array = ["public_stage_score", "GTE", "ADVISORY_ONLY", "DEVELOPING", "TARGET", "EXPERT", "MASTER"]
	private_tokens.append_array(flattened_cases)
	for spec_id_value: Variant in registry.spec_order:
		private_tokens.append(String(spec_id_value))
	var grade_labels: Dictionary = registry.stage_config.get("performance_contract", {}).get("grade_labels", {})
	for locale: String in ["en", "ko"]:
		gs.language = locale
		for stage_id in range(1, 11):
			var definition: Dictionary = registry.get_stage_definition(stage_id)
			var completion_contract: Dictionary = definition.get("completion_contract", {})
			var performance_target: Dictionary = definition.get("performance_target", {})
			var target_score := float(performance_target.get("target_score", 0.0))
			var summary: Dictionary = gs.stage_public_summary(stage_id, target_score)
			var summary_json := JSON.stringify(summary)
			var leaked_tokens: Array = []
			for token_value: Variant in private_tokens:
				var token := String(token_value)
				if not token.is_empty() and summary_json.contains(token):
					leaked_tokens.append(token)
			var valid: bool = summary.keys().size() == 17 \
				and int(summary.get("stage", 0)) == stage_id \
				and summary.get("completionLabel", "") == completion_contract.get("completion_label", {}).get(locale, "") \
				and summary.get("goalLabel", "") == performance_target.get("goal_label", {}).get(locale, "") \
				and summary.get("advice", "") == performance_target.get("advice_label", {}).get(locale, "") \
				and summary.get("grade", "") == grade_labels.get("TARGET", {}).get(locale, "") \
				and not String(summary.get("failureOrSuccess", "")).is_empty() \
				and approx_equal(float(summary.get("target", -1.0)), target_score) \
				and approx_equal(float(summary.get("current", -1.0)), target_score) \
				and approx_equal(float(summary.get("progress", -1.0)), 1.0) \
				and bool(summary.get("metTarget", false)) \
				and bool(summary.get("advisoryOnly", false)) \
				and leaked_tokens.is_empty()
			if not valid:
				public_summary_failures.append({"locale": locale, "stage": stage_id, "summary": summary, "leaks": leaked_tokens})
	gs.language = "en"
	record("STAGE-PERFORMANCE-01", "All ten stages expose localized data-driven public summaries without private IDs or raw tokens", public_summary_failures.is_empty(), public_summary_failures)

	var grade_failures: Array = []
	for locale: String in ["en", "ko"]:
		gs.language = locale
		for stage_id in range(1, 11):
			var definition: Dictionary = registry.get_stage_definition(stage_id)
			var thresholds: Array = definition.get("performance_target", {}).get("grade_thresholds", [])
			for threshold_index in range(thresholds.size()):
				var threshold: Dictionary = thresholds[threshold_index]
				var threshold_score := float(threshold.get("min_score", 0.0))
				var expected_label: String = grade_labels.get(String(threshold.get("grade_id", "")), {}).get(locale, "")
				var exact_summary: Dictionary = gs.stage_public_summary(stage_id, threshold_score)
				if exact_summary.get("grade", "") != expected_label:
					grade_failures.append({"locale": locale, "stage": stage_id, "score": threshold_score, "expected": expected_label, "actual": exact_summary.get("grade", "")})
				if threshold_index > 0 and threshold_score > 0.0:
					var previous: Dictionary = thresholds[threshold_index - 1]
					var expected_previous: String = grade_labels.get(String(previous.get("grade_id", "")), {}).get(locale, "")
					var below_summary: Dictionary = gs.stage_public_summary(stage_id, threshold_score - 0.01)
					if below_summary.get("grade", "") != expected_previous:
						grade_failures.append({"locale": locale, "stage": stage_id, "score": threshold_score - 0.01, "expected": expected_previous, "actual": below_summary.get("grade", "")})
	gs.language = "en"
	record("STAGE-PERFORMANCE-02", "Every authored grade threshold selects the localized grade at and below its boundary", grade_failures.is_empty(), grade_failures)

	gs.player_profile = gs.default_player_profile()
	gs.reset_game()
	var below_target_start: Dictionary = gs.start_stage(1)
	satisfy_stage_objectives(gs, registry, 1)
	var stage_one_target := float(registry.get_stage_definition(1).get("performance_target", {}).get("target_score", 0.0))
	var below_target_clear: Dictionary = gs.complete_stage(1, stage_one_target - 1.0)
	var below_target_summary: Dictionary = below_target_clear.get("performance", {})
	var below_target_unlocked: bool = below_target_start.ok \
		and below_target_clear.ok \
		and gs.stage_run_state.status == "CLEARED" \
		and int(gs.player_profile.highestUnlockedStage) == 2 \
		and gs.can_select_stage(2) \
		and not bool(below_target_summary.get("metTarget", true)) \
		and bool(below_target_summary.get("advisoryOnly", false)) \
		and bool(below_target_summary.get("completionMet", false)) \
		and bool(below_target_summary.get("nextStageUnlocked", false)) \
		and below_target_summary.get("failureOrSuccess", "") == registry.get_stage_definition(1).get("performance_target", {}).get("failure_label", {}).get("en", "") \
		and gs.stage_run_state.get("lastPerformance", {}) is Dictionary \
		and not gs.stage_run_state.get("lastPerformance", {}).is_empty()
	record("STAGE-PERFORMANCE-03", "Missing an advisory target still clears the stage and persistently unlocks the next stage", below_target_unlocked, {"clear": below_target_clear, "run": gs.stage_run_state, "profile": gs.player_profile})
	gs.acknowledge_stage_clear()

	var legacy_run: Dictionary = gs.default_stage_run_state(1)
	legacy_run.erase("lastPerformance")
	legacy_run.status = "CLEARED"
	legacy_run.score = stage_one_target - 1.0
	gs.normalize_stage_run_dictionary(legacy_run, 1)
	var malformed_run: Dictionary = gs.default_stage_run_state(1)
	malformed_run.lastPerformance = {"current": "artifact_061", "target": stage_one_target, "best": 0.0}
	gs.normalize_stage_run_dictionary(malformed_run, 1)
	record("STAGE-PERFORMANCE-04", "Old or malformed run saves normalize to a safe empty performance snapshot", legacy_run.has("lastPerformance") and legacy_run.lastPerformance.is_empty() and malformed_run.lastPerformance.is_empty(), {"legacy": legacy_run.lastPerformance, "malformed": malformed_run.lastPerformance})

	gs.player_profile = {"schema_version": 1, "highestUnlockedStage": 2, "clearedStages": [1], "stageBest": {"1": 75.0}}
	var stage_two_start: Dictionary = gs.new_game(2)
	var stage_two_ids: Array = gs.get_current_stage_case_ids()
	var outside_stage_blocked: bool = gs.begin_case("prologue_clock").is_empty()
	var first_stage_two: Dictionary = gs.begin_case("leave_patina")
	var stage_two_entry_ok: bool = stage_two_start.ok and gs.campaign_state.currentAct == "ACT_1" and stage_two_ids == ["leave_patina", "estate_compass", "pawn_watch"] and gs.current_stage_first_pending_case() == "leave_patina" and outside_stage_blocked and not first_stage_two.is_empty()
	record("STAGE-SCOPE-01", "NEW GAME Stage 2 enters its first case and blocks out-of-stage cases", stage_two_entry_ok, {"start": stage_two_start, "act": gs.campaign_state.currentAct, "caseIds": stage_two_ids, "firstPending": gs.current_stage_first_pending_case(), "outsideBlocked": outside_stage_blocked})
	var stage_two_cases_completed := true
	for case_id_value: Variant in stage_two_ids:
		stage_two_cases_completed = gs.prepare_case_for_test(String(case_id_value)) and stage_two_cases_completed
	var stage_two_auto_clear: bool = stage_two_cases_completed and gs.stage_run_state.status == "CLEARED" and int(gs.player_profile.highestUnlockedStage) == 3 and gs.player_profile.clearedStages.has(2)
	record("STAGE-SCOPE-02", "The final scoped case authoritatively clears Stage 2 and unlocks Stage 3", stage_two_auto_clear, {"run": gs.stage_run_state, "profile": gs.player_profile, "completedCases": gs.campaign_state.completedCases.keys()})
	gs.acknowledge_stage_clear()

	gs.player_profile = gs.default_player_profile()
	var stage_one_cross_start: Dictionary = gs.new_game(1)
	var stage_one_prologue_done: bool = gs.prepare_case_for_test("prologue_clock")
	var stage_one_cross_ok: bool = bool(stage_one_cross_start.get("ok", false)) \
		and stage_one_prologue_done \
		and gs.stage_run_state.status == "RUNNING" \
		and gs.current_stage_first_pending_case() == "silent_radio" \
		and gs.campaign_state.currentAct == "ACT_1" \
		and not gs.begin_case("silent_radio").is_empty()
	gs.player_profile = {"schema_version": 1, "highestUnlockedStage": 5, "clearedStages": [1, 2, 3, 4], "stageBest": {"1": 55.0, "2": 56.0, "3": 57.0, "4": 58.0}}
	var stage_five_cross_start: Dictionary = gs.new_game(5)
	var stage_five_first_done: bool = gs.prepare_case_for_test("collector_promise")
	var stage_five_second_done: bool = gs.prepare_case_for_test("three_cameras")
	var stage_five_cross_ok: bool = bool(stage_five_cross_start.get("ok", false)) \
		and stage_five_first_done \
		and stage_five_second_done \
		and gs.stage_run_state.status == "RUNNING" \
		and gs.current_stage_first_pending_case() == "shadow_camera" \
		and gs.campaign_state.currentAct == "ACT_4" \
		and not gs.begin_case("shadow_camera").is_empty()
	record("STAGE-CROSS-ACT-01", "Stage-scoped runs bridge Prologue to Act 1 and Act 3 to Act 4 without a progression deadlock", stage_one_cross_ok and stage_five_cross_ok, {"stage1": {"ok": stage_one_cross_ok, "act": "ACT_1", "pending": "silent_radio"}, "stage5": {"ok": stage_five_cross_ok, "act": gs.campaign_state.currentAct, "pending": gs.current_stage_first_pending_case()}})
	gs.player_profile = gs.default_player_profile()
	gs.reset_game()

	var stage_one_open: bool = gs.can_select_stage(1)
	var stage_two_locked: bool = not gs.can_select_stage(2)
	var started_one: Dictionary = gs.start_stage(1)
	satisfy_stage_objectives(gs, registry, 1)
	var cleared_one: Dictionary = gs.complete_stage(1, 100.0)
	var replay_lower: Dictionary = gs.complete_stage(1, 40.0)
	var replay_higher: Dictionary = gs.complete_stage(1, 125.0)
	var monotonic_one: bool = float(gs.player_profile.stageBest.get("1", 0.0)) == 125.0 \
		and int(gs.player_profile.highestUnlockedStage) == 2 \
		and gs.player_profile.clearedStages == [1] \
		and bool(cleared_one.get("performance", {}).get("isNewBest", false)) \
		and not bool(replay_lower.get("performance", {}).get("isNewBest", true)) \
		and bool(replay_higher.get("performance", {}).get("isNewBest", false)) \
		and float(replay_lower.get("performance", {}).get("best", 0.0)) == 100.0 \
		and float(replay_higher.get("performance", {}).get("best", 0.0)) == 125.0 \
		and bool(gs.stage_run_state.get("lastPerformance", {}).get("isNewBest", false)) \
		and float(gs.stage_run_state.get("lastPerformance", {}).get("best", 0.0)) == 125.0
	record("STAGE-PROFILE-01", "Stage 1 clear, replay best and new-best flags are monotonic and idempotent", stage_one_open and stage_two_locked and started_one.ok and cleared_one.ok and replay_lower.ok and replay_higher.ok and monotonic_one and gs.can_select_stage(2), {"cleared": cleared_one.get("performance", {}), "lower": replay_lower.get("performance", {}), "higher": replay_higher.get("performance", {}), "profile": gs.player_profile, "run": gs.stage_run_state})
	gs.acknowledge_stage_clear()

	for stage_id in range(2, 10):
		gs.start_stage(stage_id)
		satisfy_stage_objectives(gs, registry, stage_id)
		gs.complete_stage(stage_id, float(stage_id * 100))
		gs.acknowledge_stage_clear()
	var unlocked_ten: bool = int(gs.player_profile.highestUnlockedStage) == 10 and gs.can_select_stage(10) and gs.player_profile.clearedStages.size() == 9
	var profile_before_reset: Dictionary = gs.profile_payload()
	gs.reset_game()
	var reset_preserved: bool = gs.profile_payload() == profile_before_reset and gs.current_stage == 1 and gs.stage_run_state.status == "NOT_STARTED"
	var new_game_result: Dictionary = gs.new_game(7)
	var new_game_preserved: bool = new_game_result.ok and gs.current_stage == 7 and gs.profile_payload() == profile_before_reset
	record("STAGE-PROFILE-02", "Sequential clears unlock Stage 10 and reset/new-game preserves profile", unlocked_ten and reset_preserved and new_game_preserved, {"profile": gs.player_profile, "currentStage": gs.current_stage, "run": gs.stage_run_state})

	# Run save restores stage state but cannot overwrite the separate profile.
	var run_path := "user://r3_stage_run_save.json"
	cleanup_slots(gs, run_path)
	gs.persistence_enabled = false
	satisfy_stage_objectives(gs, registry, 7)
	var stage_seven_replay: Dictionary = gs.complete_stage(7, float(registry.get_stage_definition(7).get("performance_target", {}).get("target_score", 0.0)) - 1.0)
	var summary_before_run_save: Dictionary = gs.stage_public_summary()
	gs.persistence_enabled = true
	var run_saved: bool = gs.save_game(run_path)
	var saved_run_state: Dictionary = gs.stage_run_state.duplicate(true)
	var profile_before_run_load: Dictionary = gs.profile_payload()
	gs.current_stage = 2
	gs.stage_run_state = gs.default_stage_run_state(2)
	gs.player_profile.stageBest["1"] = 9999.0
	var mutated_profile: Dictionary = gs.profile_payload()
	var run_loaded: bool = gs.load_game(run_path)
	var run_restored: bool = gs.current_stage == 7 and gs.stage_run_state == saved_run_state
	var restored_summary: Dictionary = gs.stage_public_summary()
	var summary_restored: bool = stage_seven_replay.ok and not saved_run_state.get("lastPerformance", {}).is_empty() and restored_summary == summary_before_run_save
	var separate_profile_untouched: bool = gs.profile_payload() == mutated_profile and gs.profile_payload() != profile_before_run_load
	record("STAGE-RUNSAVE-01", "Run save restores the last public summary without owning profile", run_saved and run_loaded and run_restored and summary_restored and separate_profile_untouched, {"currentStage": gs.current_stage, "run": gs.stage_run_state, "summary": restored_summary, "profile": gs.player_profile})
	cleanup_slots(gs, run_path)

	var profile_path := "user://r3_stage_profile_reload.json"
	cleanup_slots(gs, profile_path)
	gs.player_profile = profile_before_reset.duplicate(true)
	var profile_saved: bool = gs.save_profile(profile_path)
	gs.player_profile = gs.default_player_profile()
	var profile_loaded: bool = gs.load_profile(profile_path)
	record("STAGE-PROFILE-03", "Separate profile reload preserves unlocks, clears and best scores", profile_saved and profile_loaded and gs.profile_payload() == profile_before_reset, {"profile": gs.player_profile, "recovered": gs.last_profile_load_recovered})
	cleanup_slots(gs, profile_path)
	var inconsistent_profile := {"schema_version": 1, "highestUnlockedStage": 1, "clearedStages": [5], "stageBest": {"5": 500.0}}
	var consistency_validation: Dictionary = gs.validate_profile_payload(inconsistent_profile)
	var normalized_inconsistent: Dictionary = inconsistent_profile.duplicate(true)
	gs.normalize_profile_dictionary(normalized_inconsistent)
	record("STAGE-PROFILE-04", "Profile validation rejects relocking a cleared stage", not consistency_validation.ok and consistency_validation.code == "PROFILE_WOULD_RELOCK_CLEARED_STAGE" and int(normalized_inconsistent.highestUnlockedStage) == 6, {"validation": consistency_validation, "normalized": normalized_inconsistent})
	record("STAGE-PROFILE-05", "Profile and run stores have separate authoritative paths", gs.PROFILE_PATH != gs.SAVE_PATH and not gs.PROFILE_PATH.begins_with(gs.SAVE_PATH) and not gs.SAVE_PATH.begins_with(gs.PROFILE_PATH), {"profilePath": gs.PROFILE_PATH, "runPath": gs.SAVE_PATH})

	gs.persistence_enabled = false
	gs.acknowledge_stage_clear()
	gs.player_profile = profile_before_reset.duplicate(true)
	var started_ten: Dictionary = gs.new_game(10)
	var ending_before_ten: String = gs.campaign_state.currentEnding
	var postgame_before_ten: bool = bool(gs.campaign_state.postGame)
	satisfy_stage_objectives(gs, registry, 10)
	var cleared_ten: Dictionary = gs.complete_stage(10, 1000.0)
	var stage_ten_capped: bool = started_ten.ok and cleared_ten.ok and int(gs.player_profile.highestUnlockedStage) == 10 and gs.player_profile.clearedStages.has(10) and gs.can_select_stage(10) and not gs.can_select_stage(11)
	var campaign_authority_preserved: bool = gs.campaign_state.currentEnding == ending_before_ten and bool(gs.campaign_state.postGame) == postgame_before_ten
	record("STAGE-PROFILE-06", "Stage 10 clear caps at 10 and leaves ending/postgame to campaign authority", stage_ten_capped and campaign_authority_preserved, {"profile": gs.player_profile, "ending": gs.campaign_state.currentEnding, "postGame": gs.campaign_state.postGame})
	gs.acknowledge_stage_clear()

	gs.player_profile = profile_before_reset.duplicate(true)
	var final_stage_start: Dictionary = gs.new_game(10)
	var final_stage_entry_ok: bool = final_stage_start.ok and gs.current_stage_first_pending_case() == "master_camera" and gs.campaign_state.currentAct == "ACT_5" and gs.inventory.size() == 3
	var final_cases_completed := true
	for case_id_value: Variant in gs.get_current_stage_case_ids():
		final_cases_completed = gs.prepare_case_for_test(String(case_id_value)) and final_cases_completed
	var final_ready: bool = final_cases_completed and gs.stage_run_state.status == "RUNNING" and gs.campaign_state.currentAct == "GRAND_RESERVE" and bool(gs.campaign_state.grandReserve.invited) and gs.eligible_final_lots().size() >= 3
	var final_eligible: Array = gs.eligible_final_lots()
	for index in range(mini(3, final_eligible.size())):
		gs.select_final_lot(final_eligible[index].uniqueId)
	var final_auction: Dictionary = gs.run_grand_reserve()
	var epilogue_reached: bool = final_auction.ok and gs.stage_run_state.status == "CLEARED" and gs.player_profile.clearedStages.has(10) and int(gs.player_profile.highestUnlockedStage) == 10 and gs.campaign_state.currentAct == "EPILOGUE"
	gs.acknowledge_stage_clear()
	gs.acknowledge_epilogue()
	var postgame_reached: bool = gs.campaign_state.postGame and gs.campaign_state.currentAct == "POSTGAME" and not gs.can_select_stage(11)
	record("STAGE-FINAL-01", "Stage 10 flows through Grand Reserve, ending, epilogue and postgame without Stage 11", final_stage_entry_ok and final_ready and epilogue_reached and postgame_reached, {"entry": final_stage_entry_ok, "ready": final_ready, "auction": final_auction.get("code", ""), "ending": gs.campaign_state.currentEnding, "act": gs.campaign_state.currentAct, "profile": gs.player_profile})

	# Difficulty channel tests use the same immutable instance inputs. Ratios
	# prove the 7% multiplier appears once, without truth/value/RNG mutation.
	var artifact_stage_one: Dictionary = gs.new_artifact("artifact_061", 7654321, "difficulty_one")
	var artifact_stage_five: Dictionary = gs.new_artifact("artifact_061", 7654321, "difficulty_five")
	var artifact_stage_ten: Dictionary = gs.new_artifact("artifact_061", 7654321, "difficulty_ten")
	artifact_stage_one.listing.disclosure = "CERTAIN"
	artifact_stage_five.listing.disclosure = "CERTAIN"
	artifact_stage_ten.listing.disclosure = "CERTAIN"
	var definition_snapshot := JSON.stringify(registry.get_case_v2("prologue_clock"))
	gs.current_stage = 1
	var req_one: Dictionary = gs.repair_requirements(artifact_stage_one)
	var scrutiny_one: Dictionary = gs.auction_scrutiny_factors(artifact_stage_one, registry.get_bidder(2))
	var reserve_one: float = gs.auction_reserve_pressure_factor(artifact_stage_one, 1000, 1200)
	var positive_disclosure_one: Dictionary = artifact_stage_one.duplicate(true)
	positive_disclosure_one.listing.disclosure = "UNCERTAIN"
	var positive_factor_one: float = gs.auction_disclosure_factor(positive_disclosure_one)
	gs.current_stage = 5
	var scrutiny_five: Dictionary = gs.auction_scrutiny_factors(artifact_stage_five, registry.get_bidder(2))
	var reserve_five: float = gs.auction_reserve_pressure_factor(artifact_stage_five, 1000, 1200)
	gs.current_stage = 10
	var req_ten: Dictionary = gs.repair_requirements(artifact_stage_ten)
	var scrutiny_ten: Dictionary = gs.auction_scrutiny_factors(artifact_stage_ten, registry.get_bidder(2))
	var reserve_ten: float = gs.auction_reserve_pressure_factor(artifact_stage_ten, 1000, 1200)
	var positive_disclosure_ten: Dictionary = artifact_stage_ten.duplicate(true)
	positive_disclosure_ten.listing.disclosure = "UNCERTAIN"
	var positive_factor_ten: float = gs.auction_disclosure_factor(positive_disclosure_ten)
	var difficulty_five: float = registry.stage_difficulty_multiplier(5)
	var difficulty_ten: float = registry.stage_difficulty_multiplier(10)
	var gap_difficulty_one := minf(registry.stage_difficulty_multiplier(1), 1.66)
	var gap_difficulty_five := minf(difficulty_five, 1.66)
	var gap_difficulty_ten := minf(difficulty_ten, 1.66)
	var repair_once := approx_equal(float(req_ten.effectiveCostFactor) / float(req_one.effectiveCostFactor), difficulty_ten) and approx_equal(float(req_one.effectiveToleranceMm) / float(req_ten.effectiveToleranceMm), difficulty_ten) and approx_equal(float(req_ten.effectivePenaltyFactor) / float(req_one.effectivePenaltyFactor), difficulty_ten)
	var condition_gap_once := approx_equal((1.0 - float(scrutiny_five.condition)) / (1.0 - float(scrutiny_one.condition)), gap_difficulty_five) \
		and approx_equal((1.0 - float(scrutiny_ten.condition)) / (1.0 - float(scrutiny_one.condition)), gap_difficulty_ten)
	var provenance_gap_once := approx_equal((1.0 - float(scrutiny_five.provenance)) / (1.0 - float(scrutiny_one.provenance)), gap_difficulty_five) \
		and approx_equal((1.0 - float(scrutiny_ten.provenance)) / (1.0 - float(scrutiny_one.provenance)), gap_difficulty_ten)
	var disclosure_full_difficulty := approx_equal((1.0 - float(scrutiny_five.disclosure)) / (1.0 - float(scrutiny_one.disclosure)), difficulty_five) \
		and approx_equal((1.0 - float(scrutiny_ten.disclosure)) / (1.0 - float(scrutiny_one.disclosure)), difficulty_ten)
	var reserve_full_difficulty := approx_equal((1.0 - reserve_five) / (1.0 - reserve_one), difficulty_five) \
		and approx_equal((1.0 - reserve_ten) / (1.0 - reserve_one), difficulty_ten)
	var positive_disclosure_stage_independent := approx_equal(positive_factor_one, positive_factor_ten)
	var scrutiny_contract := approx_equal(gap_difficulty_one, 1.0) \
		and approx_equal(gap_difficulty_five, 1.31079601) \
		and approx_equal(gap_difficulty_ten, 1.66) \
		and condition_gap_once and provenance_gap_once \
		and disclosure_full_difficulty and reserve_full_difficulty \
		and positive_disclosure_stage_independent
	record("STAGE-DIFFICULTY-01", "Condition and provenance support gaps use the 1.66 cap exactly once while repair, negative disclosure and reserve retain full difficulty", repair_once and scrutiny_contract, {"difficulty": {"stage1": registry.stage_difficulty_multiplier(1), "stage5": difficulty_five, "stage10": difficulty_ten}, "gapDifficulty": {"stage1": gap_difficulty_one, "stage5": gap_difficulty_five, "stage10": gap_difficulty_ten}, "repair1": req_one, "repair10": req_ten, "scrutiny1": scrutiny_one, "scrutiny5": scrutiny_five, "scrutiny10": scrutiny_ten, "positiveDisclosure": {"stage1": positive_factor_one, "stage10": positive_factor_ten}, "reserve1": reserve_one, "reserve5": reserve_five, "reserve10": reserve_ten})
	var risk_one: float = gs.investigation_risk_penalty("HIGH", 1)
	var risk_ten: float = gs.investigation_risk_penalty("HIGH", 10)
	var investigation_once := approx_equal(risk_ten / risk_one, difficulty_ten) and approx_equal(gs.investigation_risk_penalty("LOW", 1), 1.0) and approx_equal(gs.investigation_risk_penalty("NONE", 10), 0.0)
	record("STAGE-DIFFICULTY-INVESTIGATION", "Risky investigation consequences consume the stage multiplier exactly once", investigation_once, {"stage1HighPenalty": risk_one, "stage10HighPenalty": risk_ten, "difficulty": difficulty_ten})

	artifact_stage_one.damageInstances = ["CRACK"]
	artifact_stage_ten.damageInstances = ["CRACK"]
	gs.selected_tool = String(req_one.requiredTools[0])
	gs.persistence_enabled = false
	gs.current_stage = 1
	gs.repair(artifact_stage_one)
	gs.current_stage = 10
	gs.repair(artifact_stage_ten)
	# Restoration currency is intentionally integer-quantized. Validate the
	# authoritative stage-scaled raw cost before rounding instead of comparing
	# two small integer totals as if they were continuous values.
	var expected_cost_one: int = gs.restoration_cost_units(18.0 * float(req_one.effectiveCostFactor))
	var expected_cost_ten: int = gs.restoration_cost_units(18.0 * float(req_ten.effectiveCostFactor))
	var actual_cost_once: bool = int(artifact_stage_one.restorationCost) == expected_cost_one and int(artifact_stage_ten.restorationCost) == expected_cost_ten
	var auction_fixture: Dictionary = gs.new_artifact("artifact_061", 998877, "deterministic_auction")
	auction_fixture.listing = {"starting": 1, "reserve": 900, "confidence": 0.7, "disclosure": "UNCERTAIN"}
	gs.current_stage = 6
	var global_rng_before_auction: int = gs.rng.state
	var auction_a: Dictionary = gs.auction(auction_fixture)
	var auction_b: Dictionary = gs.auction(auction_fixture)
	var global_rng_after_auction: int = gs.rng.state
	record("STAGE-DIFFICULTY-02", "Stage repair cost and auction effects are deterministic", actual_cost_once and auction_a == auction_b and global_rng_before_auction == global_rng_after_auction, {"cost1": artifact_stage_one.restorationCost, "expectedCost1": expected_cost_one, "cost10": artifact_stage_ten.restorationCost, "expectedCost10": expected_cost_ten, "auctionEqual": auction_a == auction_b, "globalRngUnchanged": global_rng_before_auction == global_rng_after_auction})

	var causal_bidders: Array = []
	for bidder_index in range(6):
		causal_bidders.append(registry.get_bidder(bidder_index))
	var causal_good: Dictionary = gs.new_artifact("artifact_061", 424242, "causal_strategy")
	causal_good.cleanliness = 100.0
	causal_good.surfaceCondition = 100.0
	causal_good.mechanicalCondition = 100.0
	causal_good.knownClues = ["PROVENANCE"]
	causal_good.confidence = 0.92
	causal_good.listing = {"starting": 1, "reserve": 1, "confidence": 0.92, "disclosure": "CERTAIN"}
	var causal_poor: Dictionary = causal_good.duplicate(true)
	causal_poor.cleanliness = 30.0
	causal_poor.surfaceCondition = 35.0
	causal_poor.mechanicalCondition = 25.0
	causal_poor.knownClues = []
	causal_poor.confidence = 0.20
	causal_poor.listing = {"starting": 1, "reserve": 999999, "confidence": 0.20, "disclosure": "UNCERTAIN"}
	var causal_good_result: Dictionary = gs.auction_with_bidders(causal_good, causal_bidders)
	var causal_poor_result: Dictionary = gs.auction_with_bidders(causal_poor, causal_bidders)
	var good_reason_codes: Array = causal_good_result.get("reasonTags", []).map(func(tag: Dictionary): return tag.get("code", ""))
	var poor_reason_codes: Array = causal_poor_result.get("reasonTags", []).map(func(tag: Dictionary): return tag.get("code", ""))
	var reason_shape_ok := true
	for result_row: Dictionary in [causal_good_result, causal_poor_result]:
		var result_tags: Array = result_row.get("reasonTags", [])
		var unique_categories := {}
		for result_tag: Dictionary in result_tags:
			unique_categories[String(result_tag.get("category", ""))] = true
		reason_shape_ok = reason_shape_ok and result_tags.size() >= 1 and result_tags.size() <= 2
		reason_shape_ok = reason_shape_ok and unique_categories.size() == result_tags.size()
	var causal_direction_ok := bool(causal_good_result.get("reserve_met", false)) \
		and not bool(causal_poor_result.get("reserve_met", true)) \
		and good_reason_codes.has("PROVENANCE_STRONG") \
		and good_reason_codes.has("CONDITION_GOOD") \
		and poor_reason_codes.has("RESERVE_TOO_HIGH") \
		and poor_reason_codes.has("PROVENANCE_UNCERTAIN")
	record("STAGE-AUCTION-CAUSE-01", "Visible investigation, condition, disclosure and reserve choices produce compact causal auction reasons", causal_direction_ok and reason_shape_ok, {"good": {"sale": causal_good_result.sale_status, "reasons": causal_good_result.reasonTags, "hammer": causal_good_result.hammer}, "poor": {"sale": causal_poor_result.sale_status, "reasons": causal_poor_result.reasonTags, "hammer": causal_poor_result.hammer}})

	var hidden_variant: Dictionary = causal_good.duplicate(true)
	hidden_variant.authenticityTruth = "FORGERY"
	hidden_variant.trueRarity = 99.0
	hidden_variant.trueHistoricalSignificance = 0.01
	hidden_variant.trueMarketBaseline = 1
	hidden_variant.baseValue = 999999
	hidden_variant.originalParts = 0
	hidden_variant.replacementParts = 99
	var public_outcome_fixture := {"opening": 1, "reserve": 1, "hammer": 500, "reserve_met": true}
	var public_reasons_original: Array = gs.auction_public_reason_tags(causal_good, causal_bidders[0], "WON", public_outcome_fixture)
	var public_reasons_hidden_changed: Array = gs.auction_public_reason_tags(hidden_variant, causal_bidders[0], "WON", public_outcome_fixture)
	var no_input_signal: Dictionary = causal_good.duplicate(true)
	no_input_signal.cleanliness = 0.0
	no_input_signal.surfaceCondition = 0.0
	no_input_signal.mechanicalCondition = 0.0
	no_input_signal.knownClues = []
	no_input_signal.confidence = 0.1
	no_input_signal.listing = {"starting": 1, "reserve": 1, "confidence": 0.1, "disclosure": "UNCERTAIN"}
	var no_input_reasons: Array = gs.auction_public_reason_tags(no_input_signal, causal_bidders[0], "WON", public_outcome_fixture)
	record("STAGE-AUCTION-CAUSE-02", "Auction reasons depend only on visible decision inputs, ignore hidden truth, and allow an empty positive legacy fallback", public_reasons_original == public_reasons_hidden_changed and public_reasons_original.size() == 2 and no_input_reasons.is_empty(), {"original": public_reasons_original, "hiddenChanged": public_reasons_hidden_changed, "noInputFallback": no_input_reasons})

	var sextant: Dictionary = gs.new_artifact("artifact_070", 700070, "repair_reachability_sextant")
	sextant.damageInstances = ["DENT"]
	gs.current_stage = 5
	gs.selected_tool = "repair_toolkit"
	var sextant_repair_message: String = gs.repair(sextant)
	var expansion_repair_reachable: bool = not sextant.damageInstances.has("DENT") and bool(sextant.repaired) and sextant_repair_message == "Mechanism repaired." and gs.repairable_damage_types(sextant).has("DENT")
	record("STAGE-REPAIR-REACHABILITY", "Expansion repair profiles make their authored possible faults reachable through any compatible selected tool", expansion_repair_reachable, {"artifact": sextant.artifactSpecId, "tool": gs.selected_tool, "remainingDamage": sextant.damageInstances, "repairable": gs.repairable_damage_types(sextant), "message": sextant_repair_message})

	var privacy_equal: bool = artifact_stage_one.authenticityTruth == artifact_stage_ten.authenticityTruth and artifact_stage_one.baseValue == artifact_stage_ten.baseValue and artifact_stage_one.trueMarketBaseline == artifact_stage_ten.trueMarketBaseline and artifact_stage_one.trueRarity == artifact_stage_ten.trueRarity and artifact_stage_one.trueHistoricalSignificance == artifact_stage_ten.trueHistoricalSignificance and artifact_stage_one.possibleClues == artifact_stage_ten.possibleClues
	var evidence_unchanged := JSON.stringify(registry.get_case_v2("prologue_clock")) == definition_snapshot
	var ending_fixture := {"authenticationAccuracy": 0.85, "restoration": 80.0, "integrity": 80.0, "financial": 80.0, "museumTrust": 60.0, "collectorReputation": 60.0, "collectionQuality": 70.0, "balancedScore": 75.0, "ethics": 80, "collectorTrust": 30}
	gs.current_stage = 1
	var ending_one: String = gs.evaluate_ending(ending_fixture)
	gs.current_stage = 10
	var ending_ten: String = gs.evaluate_ending(ending_fixture)
	record("STAGE-PRIVACY-01", "Stage difficulty never changes truth, evidence, true base value or endings", privacy_equal and evidence_unchanged and ending_one == ending_ten, {"truth": artifact_stage_one.authenticityTruth, "baseValue": artifact_stage_one.baseValue, "ending1": ending_one, "ending10": ending_ten})

	gs.persistence_enabled = true
	gs.campaign_test_mode = false
	var profile_gate_rejected: bool = not gs.configure_profile_crash_injection_for_test("A_TMP_WRITE_INTERRUPTION")
	record("STAGE-PROFILE-CRASH-GATE", "Profile crash injection is test-mode only", profile_gate_rejected, {"rejected": profile_gate_rejected})
	gs.campaign_test_mode = true
	for index in range(CRASH_CASES.size()):
		run_profile_crash_case(gs, CRASH_CASES[index], index + 1)

	var invalid_path := "user://r3_stage_profile_both_invalid.json"
	cleanup_slots(gs, invalid_path)
	var wrote_current := write_raw(invalid_path, "[]")
	var wrote_backup := write_raw(invalid_path + gs.SAVE_BACKUP_SUFFIX, "{\"schema_version\":\"broken\"}")
	var before_invalid := profile_fixture(gs, "MEMORY")
	var invalid_loaded: bool = gs.load_profile(invalid_path)
	var after_invalid: Dictionary = gs.profile_payload()
	record("STAGE-PROFILE-NO-SILENT-RESET", "Both invalid profile slots fail with zero memory mutation", wrote_current and wrote_backup and not invalid_loaded and not gs.last_profile_load_recovered and not gs.last_profile_load_error.is_empty() and before_invalid == after_invalid, {"loadError": gs.last_profile_load_error, "unchanged": before_invalid == after_invalid})
	cleanup_slots(gs, invalid_path)

	gs.campaign_test_mode = false
	gs.persistence_enabled = false
	var passed := 0
	for result: Dictionary in results:
		if bool(result.passed):
			passed += 1
	var report := {
		"suite": "R3 ten-stage runtime and persistent profile",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"skipped": 0,
		"tests": results
	}
	var output := FileAccess.open("res://qa/R3_STAGE_RUNTIME_TESTS.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print(JSON.stringify(report))
	quit(0 if passed == results.size() else 1)
