extends SceneTree

## R3 MVP save crash-injection suite.
##
## Each injected point leaves the files exactly as a process interruption would.
## The subsequent load is performed only after replacing all in-memory markers,
## so a pass proves recovery came from a complete persisted generation.

const CRASH_CASES := [
	{
		"id": "MVP-SAVE-CRASH-A",
		"point": "A_TMP_WRITE_INTERRUPTION",
		"expected": "OLD",
		"recovered": false
	},
	{
		"id": "MVP-SAVE-CRASH-B",
		"point": "B_TMP_COMPLETE_BEFORE_VALIDATION",
		"expected": "OLD",
		"recovered": false
	},
	{
		"id": "MVP-SAVE-CRASH-C",
		"point": "C_TMP_VALIDATED_BEFORE_BACKUP",
		"expected": "OLD",
		"recovered": false
	},
	{
		"id": "MVP-SAVE-CRASH-D",
		"point": "D_AFTER_BACKUP_BEFORE_PROMOTE",
		"expected": "OLD",
		"recovered": true
	},
	{
		"id": "MVP-SAVE-CRASH-E",
		"point": "E_AFTER_PROMOTE_BEFORE_FINAL_VALIDATION",
		"expected": "NEW",
		"recovered": false
	},
	{
		"id": "MVP-SAVE-CRASH-F",
		"point": "F_CORRUPT_PROMOTED_CURRENT",
		"expected": "OLD",
		"recovered": true
	}
]

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


func apply_generation(gs: Node, generation: String) -> Dictionary:
	var generation_index: int = int({"OLD": 1, "NEW": 2, "MEMORY": 3}.get(generation, 9))
	gs.reset_game()
	gs.money = 1000 + generation_index * 111
	gs.reputation = 10 + generation_index * 7
	gs.day = generation_index * 3
	gs.language = "ko" if generation_index % 2 == 0 else "en"
	gs.selected_tool = "uv_light" if generation_index == 2 else "soft_brush"
	# Use real catalog IDs so the crash fixture remains a production-valid save;
	# the generation marker itself lives in storyFlags below.
	gs.owned_upgrades = ["upgrade_%02d" % generation_index]
	gs.transactions = [{"id": "generation_%s_transaction" % generation, "amount": generation_index * 101}]
	gs.statistics.profit = generation_index * 1001
	gs.market_state.mechanical_instruments = generation_index * 13
	gs.campaign_state.storyFlags.saveCrashGeneration = generation
	gs.campaign_state.ethics = 50 + generation_index * 5
	gs.campaign_state.mastery.MECHANICAL = generation_index * 2
	gs.inventory = []
	var spec_id := "artifact_%03d" % generation_index
	var artifact: Dictionary = gs.new_artifact(spec_id, 12000 + generation_index, "save_%s_artifact" % generation.to_lower())
	gs.inventory.append(artifact)
	gs.active_workpiece = artifact
	return state_signature(gs)


func state_signature(gs: Node) -> Dictionary:
	var inventory_signature: Array = []
	for artifact: Dictionary in gs.inventory:
		inventory_signature.append({
			"uniqueId": artifact.get("uniqueId", ""),
			"artifactSpecId": artifact.get("artifactSpecId", ""),
			"seed": int(artifact.get("seed", -1))
		})
	var transaction_signature: Array = []
	for transaction: Dictionary in gs.transactions:
		transaction_signature.append({
			"id": String(transaction.get("id", "")),
			"amount": int(transaction.get("amount", 0))
		})
	return {
		"money": gs.money,
		"reputation": gs.reputation,
		"day": gs.day,
		"language": gs.language,
		"selectedTool": gs.selected_tool,
		"ownedUpgrades": gs.owned_upgrades.duplicate(true),
		"transactions": transaction_signature,
		"profit": int(gs.statistics.get("profit", 0)),
		"marketMechanical": int(gs.market_state.get("mechanical_instruments", 0)),
		"generation": String(gs.campaign_state.get("storyFlags", {}).get("saveCrashGeneration", "")),
		"ethics": int(gs.campaign_state.get("ethics", 0)),
		"mechanicalMastery": int(gs.campaign_state.get("mastery", {}).get("MECHANICAL", 0)),
		"inventory": inventory_signature,
		"activeWorkpieceId": String(gs.active_workpiece.get("uniqueId", ""))
	}


func slot_status(gs: Node, path: String) -> Dictionary:
	var status := {}
	for slot: Dictionary in [
		{"name": "current", "path": path},
		{"name": "temp", "path": path + gs.SAVE_TEMP_SUFFIX},
		{"name": "backup", "path": path + gs.SAVE_BACKUP_SUFFIX}
	]:
		var slot_path: String = slot.path
		var parsed: Dictionary = gs.read_save_dictionary(slot_path)
		var validation: Dictionary = gs.validate_save_payload(parsed)
		status[slot.name] = {
			"exists": FileAccess.file_exists(slot_path),
			"valid": bool(validation.get("ok", false)),
			"validation": validation.get("code", "INVALID"),
			"generation": String(parsed.get("campaign", {}).get("storyFlags", {}).get("saveCrashGeneration", ""))
		}
	return status


func run_crash_case(gs: Node, fixture: Dictionary, case_index: int) -> void:
	var point: String = fixture.point
	var path := "user://r3_save_crash_%02d.json" % case_index
	cleanup_slots(gs, path)

	var old_signature := apply_generation(gs, "OLD")
	var baseline_saved: bool = gs.save_game(path)
	var new_signature := apply_generation(gs, "NEW")
	var hook_configured: bool = gs.configure_save_crash_injection_for_test(point)
	var interrupted_save: bool = gs.save_game(path)
	var save_error: String = gs.last_save_error
	var layout_before_load := slot_status(gs, path)

	var memory_signature := apply_generation(gs, "MEMORY")
	var loaded: bool = gs.load_game(path)
	var actual_signature := state_signature(gs)
	var expected_signature: Dictionary = old_signature if fixture.expected == "OLD" else new_signature
	var exact_generation: bool = actual_signature == expected_signature
	var complete_known_generation: bool = actual_signature == old_signature or actual_signature == new_signature
	var avoided_memory_fallback: bool = actual_signature != memory_signature
	var recovery_flag_ok: bool = gs.last_load_recovered == bool(fixture.recovered)
	record(
		fixture.id,
		"%s recovers exactly one complete valid generation" % point,
		baseline_saved
			and hook_configured
			and not interrupted_save
			and save_error == "TEST_CRASH_INJECTION:%s" % point
			and loaded
			and exact_generation
			and complete_known_generation
			and avoided_memory_fallback
			and recovery_flag_ok
			and gs.last_load_error.is_empty(),
		{
			"point": point,
			"expectedGeneration": fixture.expected,
			"layoutBeforeLoad": layout_before_load,
			"saveReturned": interrupted_save,
			"saveError": save_error,
			"loadReturned": loaded,
			"lastLoadRecovered": gs.last_load_recovered,
			"lastLoadError": gs.last_load_error,
			"exactGeneration": exact_generation,
			"completeKnownGeneration": complete_known_generation,
			"avoidedMemoryFallback": avoided_memory_fallback,
			"actual": actual_signature
		}
	)
	cleanup_slots(gs, path)


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	gs.persistence_enabled = true
	gs.campaign_test_mode = false
	var production_gate_rejected: bool = not gs.configure_save_crash_injection_for_test("A_TMP_WRITE_INTERRUPTION")
	record(
		"MVP-SAVE-CRASH-GATE",
		"Crash injection cannot be configured outside explicit test mode",
		production_gate_rejected,
		{"productionGateRejected": production_gate_rejected}
	)

	gs.campaign_test_mode = true
	for index in range(CRASH_CASES.size()):
		run_crash_case(gs, CRASH_CASES[index], index + 1)

	# With both authoritative slots corrupt, load must fail explicitly and leave
	# the running state untouched. It must never manufacture a new-game state.
	var invalid_path := "user://r3_save_crash_both_invalid.json"
	cleanup_slots(gs, invalid_path)
	var invalid_current_written := write_raw(invalid_path, "[]")
	var invalid_backup_written := write_raw(invalid_path + gs.SAVE_BACKUP_SUFFIX, "{\"saveVersion\":\"broken\"}")
	var before_invalid_load := apply_generation(gs, "MEMORY")
	var invalid_loaded: bool = gs.load_game(invalid_path)
	var after_invalid_load := state_signature(gs)
	record(
		"MVP-SAVE-NO-SILENT-NEW-GAME",
		"Both invalid authoritative slots fail explicitly with zero in-memory mutation",
		invalid_current_written
			and invalid_backup_written
			and not invalid_loaded
			and not gs.last_load_recovered
			and not gs.last_load_error.is_empty()
			and before_invalid_load == after_invalid_load,
		{
			"currentWritten": invalid_current_written,
			"backupWritten": invalid_backup_written,
			"loadReturned": invalid_loaded,
			"lastLoadRecovered": gs.last_load_recovered,
			"lastLoadError": gs.last_load_error,
			"stateUnchanged": before_invalid_load == after_invalid_load
		}
	)
	cleanup_slots(gs, invalid_path)
	gs.campaign_test_mode = false
	gs.persistence_enabled = false

	var passed := 0
	for result: Dictionary in results:
		if bool(result.passed):
			passed += 1
	var report := {
		"suite": "R3 MVP save crash injection",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"skipped": 0,
		"tests": results
	}
	var output := FileAccess.open("res://qa/R3_SAVE_CRASH_TESTS.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print(JSON.stringify(report))
	quit(0 if passed == results.size() else 1)
