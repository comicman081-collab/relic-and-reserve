extends SceneTree

## Persistent three-lot Grand Reserve live-auction contract.
##
## The suite is intentionally fail-closed: until the session API exists, its
## first gate reports every missing method/property/save field and exits without
## calling the absent implementation. It writes only dedicated user:// fixtures
## and qa/R3_GRAND_RESERVE_LIVE_AUCTION_TESTS.json. It never exports a build.

const PHASES := ["IDLE", "AUCTION_PENDING", "BETWEEN_LOTS", "FINALIZED"]
const AXIS_IDS := ["investigation", "preservation", "sale"]
const TUTORIAL_STEPS := ["INVESTIGATE", "CITE", "REPORT", "REPAIR", "LIST", "AUCTION"]
const BEGIN_ATOMIC_PATH := "user://r3_grand_reserve_begin_atomic.json"
const LOT2_RESUME_PATH := "user://r3_grand_reserve_lot2_resume.json"
const FINAL_ATOMIC_PATH := "user://r3_grand_reserve_final_atomic.json"
const HOSTILE_VALIDATION_PATH := "user://r3_grand_reserve_hostile_validation.json"

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func settle_ui(frame_count: int = 4) -> void:
	for _frame in range(frame_count):
		await process_frame


func cleanup_slots(gs: Node, path: String) -> void:
	gs.remove_save_file(path)
	gs.remove_save_file(path + gs.SAVE_TEMP_SUFFIX)
	gs.remove_save_file(path + gs.SAVE_BACKUP_SUFFIX)


func cleanup_all_slots(gs: Node) -> void:
	for path: String in [BEGIN_ATOMIC_PATH, LOT2_RESUME_PATH, FINAL_ATOMIC_PATH, HOSTILE_VALIDATION_PATH]:
		cleanup_slots(gs, path)


func has_property(target: Object, property_name: String) -> bool:
	for property_value: Variant in target.get_property_list():
		if property_value is Dictionary and String((property_value as Dictionary).get("name", "")) == property_name:
			return true
	return false


func visible_named(root: Node, node_name: String) -> Node:
	var candidate := root.find_child(node_name, true, false)
	if candidate == null:
		return null
	if candidate is CanvasItem and not (candidate as CanvasItem).is_visible_in_tree():
		return null
	return candidate


func control_rect_evidence(node: Node) -> Dictionary:
	if not node is Control:
		return {"present": false, "inside1280x720": false, "rect": []}
	var rect := (node as Control).get_global_rect()
	return {
		"present": true,
		"inside1280x720": rect.size.x > 0.0 and rect.size.y > 0.0 \
			and rect.position.x >= 0.0 and rect.position.y >= 0.0 \
			and rect.end.x <= 1280.0 and rect.end.y <= 720.0,
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	}


func replay_snapshot_shape_ok(snapshot: Dictionary) -> bool:
	var axes_value: Variant = snapshot.get("axes", null)
	if not axes_value is Dictionary:
		return false
	var axes: Dictionary = axes_value
	if axes.size() != 3:
		return false
	for axis_id: String in AXIS_IDS:
		var axis_value: Variant = axes.get(axis_id, null)
		if not axis_value is Dictionary or not (axis_value as Dictionary).has_all(["value", "available", "statusCode"]):
			return false
	return int(snapshot.get("stage", 0)) == 10 and snapshot.has_all(["weakest", "adviceCode"])


func profile_fixture(gs: Node) -> Dictionary:
	var profile: Dictionary = gs.default_player_profile()
	var cleared: Array = []
	for stage_id in range(1, 10):
		cleared.append(stage_id)
	profile.highestUnlockedStage = 10
	profile.clearedStages = cleared
	profile.tutorialCompletedSteps = TUTORIAL_STEPS.duplicate()
	return profile


func authoritative_signature(gs: Node) -> String:
	return JSON.stringify({"run": gs.save_payload(), "profile": gs.profile_payload()})


func write_payload(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "  "))
	file.flush()
	file.close()
	return true


func validation_rejection(gs: Node, case_id: String, payload: Dictionary, expected_code: String) -> Dictionary:
	var run_before: Dictionary = gs.save_payload().duplicate(true)
	var profile_before: Dictionary = gs.profile_payload().duplicate(true)
	var before: String = authoritative_signature(gs)
	var response_value: Variant = gs.call("validate_save_payload", payload)
	var response: Dictionary = response_value if response_value is Dictionary else {}
	cleanup_slots(gs, HOSTILE_VALIDATION_PATH)
	var written: bool = write_payload(HOSTILE_VALIDATION_PATH, payload)
	var loaded: bool = bool(gs.load_game(HOSTILE_VALIDATION_PATH)) if written else false
	var load_error: String = String(gs.last_load_error)
	var mutation0: bool = authoritative_signature(gs) == before
	var passed: bool = not bool(response.get("ok", true)) \
		and String(response.get("code", "")) == expected_code \
		and written \
		and not loaded \
		and load_error.contains(expected_code) \
		and mutation0
	if not mutation0:
		gs.apply_save_data(run_before)
		gs.player_profile = profile_before.duplicate(true)
	cleanup_slots(gs, HOSTILE_VALIDATION_PATH)
	return {
		"case": case_id,
		"expected": expected_code,
		"response": response,
		"written": written,
		"loaded": loaded,
		"loadError": load_error,
		"mutation0": mutation0,
		"passed": passed,
	}


func inventory_hostile_payload(source: Dictionary, target_uid: String, remove_entry: bool, mark_sold: bool) -> Dictionary:
	var payload: Dictionary = source.duplicate(true)
	var inventory_value: Variant = payload.get("inventory", [])
	var inventory_rows: Array = inventory_value if inventory_value is Array else []
	var rewritten: Array = []
	for artifact_value: Variant in inventory_rows:
		if not artifact_value is Dictionary:
			rewritten.append(artifact_value)
			continue
		var artifact: Dictionary = (artifact_value as Dictionary).duplicate(true)
		var matches: bool = String(artifact.get("uniqueId", "")) == target_uid
		if matches and remove_entry:
			continue
		if matches and mark_sold:
			artifact["sold"] = true
		rewritten.append(artifact)
	payload["inventory"] = rewritten
	return payload


func pending_receipt_mismatch_payload(source: Dictionary) -> Dictionary:
	var payload: Dictionary = source.duplicate(true)
	var pending_value: Variant = payload.get("pendingAuction", {})
	var pending: Dictionary = pending_value if pending_value is Dictionary else {}
	var receipt_value: Variant = pending.get("receipt", {})
	var receipt: Dictionary = receipt_value if receipt_value is Dictionary else {}
	receipt["hammer"] = int(receipt.get("hammer", 0)) + 1
	pending["receipt"] = receipt
	payload["pendingAuction"] = pending
	return payload


func campaign_results_mismatch_payload(source: Dictionary) -> Dictionary:
	var payload: Dictionary = source.duplicate(true)
	var campaign_value: Variant = payload.get("campaign", {})
	var campaign: Dictionary = campaign_value if campaign_value is Dictionary else {}
	var reserve_value: Variant = campaign.get("grandReserve", {})
	var reserve: Dictionary = reserve_value if reserve_value is Dictionary else {}
	var results_value: Variant = reserve.get("results", [])
	var campaign_results: Array = results_value if results_value is Array else []
	if not campaign_results.is_empty() and campaign_results[0] is Dictionary:
		var first_result: Dictionary = (campaign_results[0] as Dictionary).duplicate(true)
		var auction_value: Variant = first_result.get("auction", {})
		var auction: Dictionary = auction_value if auction_value is Dictionary else {}
		auction["hammer"] = int(auction.get("hammer", 0)) + 1
		first_result["auction"] = auction
		campaign_results[0] = first_result
	reserve["results"] = campaign_results
	campaign["grandReserve"] = reserve
	payload["campaign"] = campaign
	return payload


func campaign_score_payload(source: Dictionary, score: Variant) -> Dictionary:
	var payload: Dictionary = source.duplicate(true)
	var campaign_value: Variant = payload.get("campaign", {})
	var campaign: Dictionary = campaign_value if campaign_value is Dictionary else {}
	var reserve_value: Variant = campaign.get("grandReserve", {})
	var reserve: Dictionary = reserve_value if reserve_value is Dictionary else {}
	reserve["score"] = score.duplicate(true) if score is Dictionary else score
	campaign["grandReserve"] = reserve
	payload["campaign"] = campaign
	return payload


func selected_lots_mismatch_payload(source: Dictionary) -> Dictionary:
	var payload: Dictionary = source.duplicate(true)
	var campaign_value: Variant = payload.get("campaign", {})
	var campaign: Dictionary = campaign_value if campaign_value is Dictionary else {}
	var reserve_value: Variant = campaign.get("grandReserve", {})
	var reserve: Dictionary = reserve_value if reserve_value is Dictionary else {}
	var selected_value: Variant = reserve.get("selectedLotIds", [])
	var selected: Array = selected_value if selected_value is Array else []
	if not selected.is_empty():
		selected.resize(maxi(0, selected.size() - 1))
	reserve["selectedLotIds"] = selected
	campaign["grandReserve"] = reserve
	payload["campaign"] = campaign
	return payload


func pending_outer_field_payload(source: Dictionary, field_name: String, field_value: Variant) -> Dictionary:
	var payload: Dictionary = source.duplicate(true)
	var pending_value: Variant = payload.get("pendingAuction", {})
	var pending: Dictionary = pending_value if pending_value is Dictionary else {}
	pending[field_name] = field_value.duplicate(true) if field_value is Dictionary or field_value is Array else field_value
	payload["pendingAuction"] = pending
	return payload


func pending_result_field_payload(source: Dictionary, field_name: String, field_value: Variant) -> Dictionary:
	var payload: Dictionary = source.duplicate(true)
	var pending_value: Variant = payload.get("pendingAuction", {})
	var pending: Dictionary = pending_value if pending_value is Dictionary else {}
	var result_value: Variant = pending.get("result", {})
	var auction_result: Dictionary = result_value if result_value is Dictionary else {}
	auction_result[field_name] = field_value.duplicate(true) if field_value is Dictionary or field_value is Array else field_value
	pending["result"] = auction_result
	payload["pendingAuction"] = pending
	return payload


func pending_result_replacement_payload(source: Dictionary, replacement: Dictionary) -> Dictionary:
	var payload: Dictionary = source.duplicate(true)
	var pending_value: Variant = payload.get("pendingAuction", {})
	var pending: Dictionary = pending_value if pending_value is Dictionary else {}
	pending["result"] = replacement.duplicate(true)
	payload["pendingAuction"] = pending
	return payload


func pending_cue_queue_payload(source: Dictionary, queue: Array) -> Dictionary:
	var payload: Dictionary = source.duplicate(true)
	var pending_value: Variant = payload.get("pendingAuction", {})
	var pending: Dictionary = pending_value if pending_value is Dictionary else {}
	pending["cueQueue"] = queue.duplicate(true)
	payload["pendingAuction"] = pending
	return payload


func pending_cue_index_payload(source: Dictionary, cue_index: int) -> Dictionary:
	var payload: Dictionary = source.duplicate(true)
	var pending_value: Variant = payload.get("pendingAuction", {})
	var pending: Dictionary = pending_value if pending_value is Dictionary else {}
	pending["cueIndex"] = cue_index
	payload["pendingAuction"] = pending
	return payload


func session_active_artifact_id_only_payload(source: Dictionary) -> Dictionary:
	var payload: Dictionary = source.duplicate(true)
	var session_value: Variant = payload.get("grandReserveSession", {})
	var session: Dictionary = session_value if session_value is Dictionary else {}
	var active_value: Variant = session.get("activeArtifact", {})
	var active: Dictionary = active_value if active_value is Dictionary else {}
	var instance_id: String = String(active.get("instanceId", active.get("uniqueId", "")))
	session["activeArtifact"] = {"instanceId": instance_id, "uniqueId": instance_id}
	payload["grandReserveSession"] = session
	return payload


func session_active_artifact_field_payload(source: Dictionary, field_name: String, field_value: Variant) -> Dictionary:
	var payload: Dictionary = source.duplicate(true)
	var session_value: Variant = payload.get("grandReserveSession", {})
	var session: Dictionary = session_value if session_value is Dictionary else {}
	var active_value: Variant = session.get("activeArtifact", {})
	var active: Dictionary = active_value if active_value is Dictionary else {}
	active[field_name] = field_value.duplicate(true) if field_value is Dictionary or field_value is Array else field_value
	session["activeArtifact"] = active
	payload["grandReserveSession"] = session
	return payload


func last_receipt_artifact_field_payload(source: Dictionary, field_name: String, field_value: Variant) -> Dictionary:
	var payload: Dictionary = source.duplicate(true)
	var session_value: Variant = payload.get("grandReserveSession", {})
	var session: Dictionary = session_value if session_value is Dictionary else {}
	var receipts_value: Variant = session.get("receipts", [])
	var receipts: Array = receipts_value if receipts_value is Array else []
	if not receipts.is_empty() and receipts[-1] is Dictionary:
		var receipt: Dictionary = (receipts[-1] as Dictionary).duplicate(true)
		var artifact_value: Variant = receipt.get("artifact", {})
		var artifact: Dictionary = artifact_value if artifact_value is Dictionary else {}
		artifact[field_name] = field_value.duplicate(true) if field_value is Dictionary or field_value is Array else field_value
		receipt["artifact"] = artifact
		receipts[-1] = receipt
	session["receipts"] = receipts
	payload["grandReserveSession"] = session
	return payload


func persisted_file_state(path: String) -> Dictionary:
	var exists: bool = FileAccess.file_exists(path)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path) if exists else PackedByteArray()
	return {
		"exists": exists,
		"bytes": bytes,
		"modifiedTime": int(FileAccess.get_modified_time(path)) if exists else -1,
	}


func persisted_file_state_equal(before: Dictionary, after: Dictionary) -> bool:
	return bool(before.get("exists", false)) == bool(after.get("exists", false)) \
		and int(before.get("modifiedTime", -1)) == int(after.get("modifiedTime", -1)) \
		and before.get("bytes", PackedByteArray()) == after.get("bytes", PackedByteArray())


func persisted_file_evidence(state: Dictionary) -> Dictionary:
	var bytes_value: Variant = state.get("bytes", PackedByteArray())
	var bytes: PackedByteArray = bytes_value if bytes_value is PackedByteArray else PackedByteArray()
	# HashingContext.update rejects a zero-length buffer with an engine ERROR.
	# Use the canonical SHA-256 of empty bytes for absent/empty profile evidence.
	var digest: String = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
	if not bytes.is_empty():
		var context := HashingContext.new()
		var start_error: Error = context.start(HashingContext.HASH_SHA256)
		if start_error == OK:
			context.update(bytes)
			digest = context.finish().hex_encode()
	return {
		"exists": bool(state.get("exists", false)),
		"size": bytes.size(),
		"modifiedTime": int(state.get("modifiedTime", -1)),
		"sha256": digest,
	}


func canonical_persisted_value(value: Variant) -> Variant:
	# JSON has one number type, so an authored int can hydrate as an equal float.
	# Normalize only that serialization detail; keys, order-sensitive arrays,
	# strings, booleans and all public values remain exact.
	if value is Dictionary:
		var normalized_dictionary: Dictionary = {}
		for key_value: Variant in (value as Dictionary).keys():
			normalized_dictionary[key_value] = canonical_persisted_value((value as Dictionary)[key_value])
		return normalized_dictionary
	if value is Array:
		var normalized_array: Array = []
		for item_value: Variant in value:
			normalized_array.append(canonical_persisted_value(item_value))
		return normalized_array
	if value is int or value is float:
		return snappedf(float(value), 0.000001)
	return value


func session_state(gs: Node) -> Dictionary:
	var value: Variant = gs.call("grand_reserve_public_state")
	return value.duplicate(true) if value is Dictionary else {}


func raw_session_state(gs: Node) -> Dictionary:
	var value: Variant = gs.get("grand_reserve_session")
	return value.duplicate(true) if value is Dictionary else {}


func pending_state(gs: Node) -> Dictionary:
	var value: Variant = gs.call("pending_auction_public_state")
	return value.duplicate(true) if value is Dictionary else {}


func session_receipts(session: Dictionary) -> Array:
	var value: Variant = session.get("receipts", [])
	return value.duplicate(true) if value is Array else []


func receipt_result(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var receipt: Dictionary = value
	if receipt.get("auction", null) is Dictionary:
		return receipt.get("auction", {}).duplicate(true)
	if receipt.get("result", null) is Dictionary:
		return receipt.get("result", {}).duplicate(true)
	return receipt.duplicate(true)


func receipt_signature(value: Variant) -> Dictionary:
	var receipt := receipt_result(value)
	return {
		"transactionId": String(receipt.get("transactionId", "")),
		"publicFingerprint": String(receipt.get("publicFingerprint", "")),
		"sale_status": String(receipt.get("sale_status", "")),
		"reserve_met": bool(receipt.get("reserve_met", false)),
		"hammer": int(receipt.get("hammer", 0)),
		"fee": int(receipt.get("fee", 0)),
		"net": int(receipt.get("net", 0))
	}


func pending_aligned_with_session(session: Dictionary, pending: Dictionary) -> bool:
	var lot_uids: Array = session.get("lotUids", []) if session.get("lotUids", []) is Array else []
	var lot_index := int(session.get("currentLotIndex", -1))
	return String(session.get("phase", "")) == "AUCTION_PENDING" \
		and lot_uids.size() == 3 \
		and lot_index >= 0 and lot_index < lot_uids.size() \
		and String(pending.get("status", "")) == "PENDING" \
		and bool(pending.get("grandReserve", false)) \
		and String(pending.get("artifactId", "")) == String(lot_uids[lot_index]) \
		and not String(pending.get("transactionId", "")).is_empty() \
		and not String(pending.get("publicFingerprint", "")).is_empty()


func session_shape_ok(session: Dictionary) -> bool:
	if not String(session.get("phase", "")) in PHASES:
		return false
	if not session.get("lotUids", null) is Array or not session.get("receipts", null) is Array:
		return false
	var lot_uids: Array = session.get("lotUids", [])
	var unique := {}
	for uid_value: Variant in lot_uids:
		var uid := String(uid_value)
		if uid.is_empty() or unique.has(uid):
			return false
		unique[uid] = true
	if String(session.get("phase", "")) == "IDLE":
		return lot_uids.is_empty() and session_receipts(session).is_empty()
	return lot_uids.size() == 3 and int(session.get("currentLotIndex", -1)) in [0, 1, 2]


func final_state_complete(gs: Node) -> bool:
	var session := session_state(gs)
	var replay: Dictionary = gs.stage_run_state.get("stageReplayFeedbackSnapshot", {})
	return String(session.get("phase", "")) == "FINALIZED" \
		and session_receipts(session).size() == 3 \
		and bool(gs.campaign_state.get("grandReserve", {}).get("completed", false)) \
		and gs.campaign_state.get("grandReserve", {}).get("results", []).size() == 3 \
		and not gs.campaign_state.get("grandReserve", {}).get("score", {}).is_empty() \
		and not String(gs.campaign_state.get("currentEnding", "")).is_empty() \
		and String(gs.stage_run_state.get("status", "")) == "CLEARED" \
		and replay_snapshot_shape_ok(replay) \
		and not bool(gs.stage_run_state.get("stageClearAcknowledged", true)) \
		and bool(gs.stage_clear_pending())


func idle_boundary_complete(gs: Node) -> bool:
	var session := session_state(gs)
	var pending := pending_state(gs)
	return String(session.get("phase", "")) == "IDLE" \
		and String(pending.get("status", "NONE")) != "PENDING" \
		and not bool(gs.campaign_state.get("grandReserve", {}).get("completed", false))


func final_equivalence_signature(gs: Node) -> Dictionary:
	var session := session_state(gs)
	var history_receipts: Array = []
	for history_value: Variant in gs.auction_history:
		if history_value is Dictionary and bool((history_value as Dictionary).get("grandReserve", false)):
			history_receipts.append(receipt_signature((history_value as Dictionary).get("result", {})))
	return {
		"session": session,
		"campaignResults": gs.campaign_state.get("grandReserve", {}).get("results", []).duplicate(true),
		"campaignScore": gs.campaign_state.get("grandReserve", {}).get("score", {}).duplicate(true),
		"ending": String(gs.campaign_state.get("currentEnding", "")),
		"stageStatus": String(gs.stage_run_state.get("status", "")),
		"feedback": gs.stage_run_state.get("stageReplayFeedbackSnapshot", {}).duplicate(true),
		"clearAcknowledged": bool(gs.stage_run_state.get("stageClearAcknowledged", true)),
		"historyReceipts": history_receipts,
		"money": int(gs.money),
		"statistics": gs.statistics.duplicate(true)
	}


func prepare_fixture(gs: Node, registry: Node) -> Dictionary:
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	gs.player_profile = profile_fixture(gs)
	var started: Dictionary = gs.new_game(10)
	var failed_cases: Array = []
	for case_id_value: Variant in registry.get_stage_definition(10).get("case_ids", []):
		var case_id := String(case_id_value)
		if not bool(gs.prepare_case_for_test(case_id)):
			failed_cases.append(case_id)
	var eligible: Array = gs.eligible_final_lots()
	var lot_uids: Array = []
	for index in range(mini(3, eligible.size())):
		var artifact: Dictionary = eligible[index]
		var appraisal := maxi(1, int(gs.appraise(artifact)))
		artifact.listing = {
			"starting": 999999 if index == 1 else 1,
			"reserve": 1000000 if index == 1 else 1,
			"confidence": float(artifact.get("confidence", 0.8)),
			"disclosure": "CERTAIN",
			"publicAppraisal": appraisal
		}
		lot_uids.append(String(artifact.get("uniqueId", "")))
		gs.select_final_lot(String(artifact.get("uniqueId", "")))
	var outsider: Dictionary = gs.new_artifact("artifact_080", 808080, "grand_reserve_outside_lot")
	outsider.playerHypothesis = gs.truth_to_hypothesis(outsider.authenticityTruth)
	outsider.confidence = 0.9
	outsider.knownClues = ["PROVENANCE", "MATERIAL"]
	outsider.inspected = true
	outsider.listing = {"starting": 1, "reserve": 1, "confidence": 0.9, "disclosure": "CERTAIN", "publicAppraisal": maxi(1, int(gs.appraise(outsider)))}
	gs.inventory.append(outsider)
	return {
		"ok": bool(started.get("ok", false)) \
			and failed_cases.is_empty() \
			and lot_uids.size() == 3 \
			and gs.campaign_state.get("grandReserve", {}).get("selectedLotIds", []) == lot_uids \
			and String(gs.stage_run_state.get("status", "")) == "RUNNING" \
			and String(gs.campaign_state.get("currentAct", "")) == "GRAND_RESERVE",
		"started": started,
		"failedCases": failed_cases,
		"lotUids": lot_uids,
		"outsiderUid": String(outsider.get("uniqueId", ""))
	}


func finish(gs: Node, main: Node = null) -> void:
	var passed := results.filter(func(result: Dictionary): return bool(result.get("passed", false))).size()
	var report := {
		"suite": "R3 Grand Reserve Persistent Live Auction",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"skipped": 0,
		"tests": results
	}
	var output := FileAccess.open("res://qa/R3_GRAND_RESERVE_LIVE_AUCTION_TESTS.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print(JSON.stringify(report))
	cleanup_all_slots(gs)
	gs.persistence_enabled = false
	gs.campaign_test_mode = false
	if main != null and is_instance_valid(main):
		# The live-auction UI creates short portrait tweens. Free synchronously so
		# they and their textures are released before SceneTree quits and the
		# hardened runner scans the log for teardown diagnostics.
		main.free()
	quit(0 if passed == results.size() else 1)


func advance_ui_to_hammer(main: Node) -> Dictionary:
	var phases: Array = []
	for _step in range(24):
		var cue_value: Variant = main.call("auction_public_cue_state")
		var cue: Dictionary = cue_value if cue_value is Dictionary else {}
		if cue.is_empty():
			return {"ok": false, "code": "MISSING_CUE", "phases": phases}
		phases.append(String(cue.get("phase", "")))
		if bool(cue.get("isFinal", false)):
			var hammer := visible_named(main, "HammerButton")
			return {"ok": hammer is Button, "code": "OK" if hammer is Button else "MISSING_HAMMER", "phases": phases, "hammer": hammer}
		var next_cue := visible_named(main, "AuctionCueNext")
		if not next_cue is Button:
			return {"ok": false, "code": "MISSING_NEXT_CUE", "phases": phases}
		(next_cue as Button).pressed.emit()
		await settle_ui(3)
	return {"ok": false, "code": "CUE_LOOP_LIMIT", "phases": phases}


func drive_ui_session(main: Node, gs: Node) -> Dictionary:
	main.call("run_grand_reserve_from_ui")
	await settle_ui(8)
	var lot_evidence: Array = []
	var layout_evidence: Array = []
	for lot_index in range(3):
		var session_before := session_state(gs)
		var progress := visible_named(main, "GrandReserveProgress")
		layout_evidence.append({"lot": lot_index + 1, "phase": "AUCTION_PENDING", "progress": control_rect_evidence(progress)})
		var cue_run: Dictionary = await advance_ui_to_hammer(main)
		var hammer: Variant = cue_run.get("hammer", null)
		if not bool(cue_run.get("ok", false)) or not hammer is Button:
			return {"ok": false, "code": cue_run.get("code", "HAMMER_UNAVAILABLE"), "lots": lot_evidence, "layout": layout_evidence}
		(hammer as Button).pressed.emit()
		await settle_ui(8)
		var session_after := session_state(gs)
		lot_evidence.append({
			"lot": lot_index + 1,
			"before": session_before,
			"afterPhase": session_after.get("phase", ""),
			"receiptCount": session_receipts(session_after).size(),
			"cuePhases": cue_run.get("phases", [])
		})
		if lot_index < 2:
			var progress_between := visible_named(main, "GrandReserveProgress")
			var next_lot := visible_named(main, "GrandReserveNextLot")
			layout_evidence.append({
				"lot": lot_index + 1,
				"phase": "BETWEEN_LOTS",
				"progress": control_rect_evidence(progress_between),
				"nextLot": control_rect_evidence(next_lot)
			})
			if String(session_after.get("phase", "")) != "BETWEEN_LOTS" or not next_lot is Button:
				return {"ok": false, "code": "MISSING_BETWEEN_LOTS", "lots": lot_evidence, "layout": layout_evidence}
			(next_lot as Button).pressed.emit()
			await settle_ui(8)
			var advanced_session := session_state(gs)
			if String(advanced_session.get("phase", "")) != "AUCTION_PENDING" or int(advanced_session.get("currentLotIndex", -1)) != lot_index + 1:
				return {"ok": false, "code": "NEXT_LOT_DID_NOT_ADVANCE", "lots": lot_evidence, "layout": layout_evidence}
	var clear_cta := visible_named(main, "StageClearViewEnding")
	layout_evidence.append({"phase": "FINALIZED", "clearCta": control_rect_evidence(clear_cta)})
	var layouts_ok := layout_evidence.all(func(row: Dictionary):
		var progress_ok := not row.has("progress") or bool(row.get("progress", {}).get("inside1280x720", false))
		var next_ok := not row.has("nextLot") or bool(row.get("nextLot", {}).get("inside1280x720", false))
		var clear_ok := not row.has("clearCta") or bool(row.get("clearCta", {}).get("inside1280x720", false))
		return progress_ok and next_ok and clear_ok
	)
	return {
		"ok": final_state_complete(gs) \
			and String(main.screen) == "campaign" \
			and visible_named(main, "StageClearCard") != null \
			and clear_cta is Button \
			and layouts_ok,
		"code": "OK",
		"lots": lot_evidence,
		"layout": layout_evidence,
		"layoutsOk": layouts_ok,
		"screen": main.screen
	}


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	cleanup_all_slots(gs)
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await settle_ui()

	var required_game_state_methods := [
		"default_grand_reserve_session", "grand_reserve_public_state",
		"begin_grand_reserve_session", "commit_grand_reserve_lot",
		"advance_grand_reserve_lot", "run_grand_reserve",
		"create_pending_auction", "auction", "sell", "commit_pending_auction",
		"committed_auction_response", "pending_auction_public_state",
		"set_pending_auction_cue_index", "stage_clear_pending",
		"configure_save_crash_injection_for_test", "save_game", "load_game",
		"validate_save_payload"
	]
	var required_main_methods := [
		"run_grand_reserve_from_ui", "auction_public_cue_state",
		"advance_auction_cue", "finalize_sale_from_ui"
	]
	var missing_methods: Array = []
	for method_name: String in required_game_state_methods:
		if not gs.has_method(method_name):
			missing_methods.append("GameState.%s" % method_name)
	for method_name: String in required_main_methods:
		if not main.has_method(method_name):
			missing_methods.append("Main.%s" % method_name)
	var has_session_property := has_property(gs, "grand_reserve_session")
	var payload_has_session: bool = bool(gs.save_payload().has("grandReserveSession"))
	var default_session: Dictionary = {}
	if missing_methods.is_empty() and has_session_property and payload_has_session:
		default_session = session_state(gs)
	var api_gate_ok: bool = missing_methods.is_empty() \
		and has_session_property \
		and payload_has_session \
		and session_shape_ok(default_session) \
		and String(default_session.get("phase", "")) == "IDLE"
	record(
		"GRAND-RESERVE-LIVE-API-01",
		"Persistent GrandReserveSession API, property and save field expose the four-phase contract",
		api_gate_ok,
		{
			"requiredPhases": PHASES,
			"missingMethods": missing_methods,
			"hasProperty": has_session_property,
			"payloadHasGrandReserveSession": payload_has_session,
			"defaultSession": default_session
		}
	)
	if not api_gate_ok:
		finish(gs, main)
		return

	var fixture: Dictionary = prepare_fixture(gs, registry)
	var lot_uids: Array = fixture.get("lotUids", []).duplicate()
	var initial_payload: Dictionary = gs.save_payload().duplicate(true)
	var initial_profile: Dictionary = gs.profile_payload().duplicate(true)
	var outsider_uid := String(fixture.get("outsiderUid", ""))
	if not bool(fixture.get("ok", false)):
		record(
			"GRAND-RESERVE-LIVE-FIXTURE-01",
			"The real Stage 10 public test route reaches three selected Grand Reserve lots",
			false,
			{"started": fixture.get("started", {}), "failedCases": fixture.get("failedCases", []), "lotUids": lot_uids}
		)
		finish(gs, main)
		return

	# A reserve-labelled auction can only be born through BEGIN/NEXT. All three
	# legacy/direct entry points must reject an IDLE-session bypass before they
	# calculate or commit anything, leaving the authoritative run/profile intact.
	var idle_guard_artifact: Dictionary = gs.find_inventory_instance(String(lot_uids[0]))
	var idle_guard_before: String = authoritative_signature(gs)
	var idle_create_value: Variant = gs.call("create_pending_auction", idle_guard_artifact, true)
	var idle_create: Dictionary = idle_create_value if idle_create_value is Dictionary else {}
	var idle_create_mutation0: bool = authoritative_signature(gs) == idle_guard_before
	var idle_auction_value: Variant = gs.call("auction", idle_guard_artifact, true)
	var idle_auction: Dictionary = idle_auction_value if idle_auction_value is Dictionary else {}
	var idle_auction_mutation0: bool = authoritative_signature(gs) == idle_guard_before
	var idle_sell_value: Variant = gs.call("sell", idle_guard_artifact, true)
	var idle_sell: Dictionary = idle_sell_value if idle_sell_value is Dictionary else {}
	var idle_sell_mutation0: bool = authoritative_signature(gs) == idle_guard_before
	var idle_guard_ok: bool = not idle_guard_artifact.is_empty() \
		and String(session_state(gs).get("phase", "")) == "IDLE" \
		and String(pending_state(gs).get("status", "NONE")) != "PENDING" \
		and not bool(idle_create.get("ok", true)) \
		and String(idle_create.get("code", "")) == "GRAND_RESERVE_SESSION_REQUIRED" \
		and not bool(idle_auction.get("ok", true)) \
		and String(idle_auction.get("code", "")) == "GRAND_RESERVE_SESSION_REQUIRED" \
		and not bool(idle_sell.get("ok", true)) \
		and String(idle_sell.get("code", "")) == "GRAND_RESERVE_SESSION_REQUIRED" \
		and idle_create_mutation0 \
		and idle_auction_mutation0 \
		and idle_sell_mutation0
	record(
		"GRAND-RESERVE-LIVE-IDLE-GUARD-01",
		"IDLE rejects every direct grand_reserve-labelled auction entry point with authoritative mutation0",
		idle_guard_ok,
		{
			"createPendingAuction": {"response": idle_create, "mutation0": idle_create_mutation0},
			"auction": {"response": idle_auction, "mutation0": idle_auction_mutation0},
			"sell": {"response": idle_sell, "mutation0": idle_sell_mutation0},
			"session": session_state(gs),
			"pending": pending_state(gs),
		}
	)
	if not idle_guard_ok:
		gs.apply_save_data(initial_payload)
		gs.player_profile = initial_profile.duplicate(true)

	# BEGIN is a single durable generation. Crash point E promotes either the old
	# IDLE generation or the complete first AUCTION_PENDING generation; a save may
	# never contain a generic pending auction without its matching live session.
	gs.persistence_enabled = true
	var begin_baseline_saved := bool(gs.save_game(BEGIN_ATOMIC_PATH))
	var begin_memory_before := authoritative_signature(gs)
	var begin_rng_before: int = gs.rng.state
	var begin_crash_configured: bool = bool(gs.configure_save_crash_injection_for_test("E_AFTER_PROMOTE_BEFORE_FINAL_VALIDATION"))
	var interrupted_begin_value: Variant = gs.call("begin_grand_reserve_session", BEGIN_ATOMIC_PATH)
	var interrupted_begin: Dictionary = interrupted_begin_value if interrupted_begin_value is Dictionary else {}
	var begin_memory_rolled_back := authoritative_signature(gs) == begin_memory_before
	gs.reset_game()
	var begin_disk_loaded := bool(gs.load_game(BEGIN_ATOMIC_PATH)) if begin_baseline_saved else false
	var begin_disk_session := session_state(gs)
	var begin_disk_pending := pending_state(gs)
	var begin_disk_idle := idle_boundary_complete(gs)
	var begin_disk_full: bool = pending_aligned_with_session(begin_disk_session, begin_disk_pending) \
		and int(begin_disk_session.get("currentLotIndex", -1)) == 0 \
		and begin_disk_session.get("lotUids", []) == lot_uids \
		and session_receipts(begin_disk_session).is_empty()
	var begin_no_partial: bool = begin_disk_loaded and (begin_disk_idle or begin_disk_full)
	gs.apply_save_data(initial_payload)
	gs.player_profile = initial_profile.duplicate(true)
	cleanup_slots(gs, BEGIN_ATOMIC_PATH)
	var begin_retry_baseline := bool(gs.save_game(BEGIN_ATOMIC_PATH))
	var retry_rng_before: int = gs.rng.state
	var begin_value: Variant = gs.call("begin_grand_reserve_session", BEGIN_ATOMIC_PATH)
	var begin_result: Dictionary = begin_value if begin_value is Dictionary else {}
	var session_after_begin := session_state(gs)
	var pending_after_begin := pending_state(gs)
	var begin_rng_after: int = gs.rng.state
	var selected_before_immutable: Array = session_after_begin.get("lotUids", []).duplicate()
	var begin_state_payload: Dictionary = gs.save_payload().duplicate(true)
	var immutable_attempt: bool = bool(gs.select_final_lot(String(lot_uids[0]))) if lot_uids.size() == 3 else false
	var selected_after_immutable: Array = session_state(gs).get("lotUids", []).duplicate()
	if selected_before_immutable != selected_after_immutable:
		gs.apply_save_data(begin_state_payload)
	var begin_success_ok: bool = bool(begin_result.get("ok", false)) \
		and pending_aligned_with_session(session_after_begin, pending_after_begin) \
		and session_after_begin.get("lotUids", []) == lot_uids \
		and session_receipts(session_after_begin).is_empty() \
		and retry_rng_before == begin_rng_after \
		and not immutable_attempt \
		and selected_before_immutable == selected_after_immutable
	var begin_contract_ok: bool = bool(fixture.get("ok", false)) \
		and begin_baseline_saved \
		and begin_crash_configured \
		and not bool(interrupted_begin.get("ok", true)) \
		and begin_memory_rolled_back \
		and begin_no_partial \
		and begin_retry_baseline \
		and begin_success_ok \
		and begin_rng_before == retry_rng_before
	record(
		"GRAND-RESERVE-LIVE-BEGIN-01",
		"Begin atomically freezes three immutable lot UIDs and the first pending snapshot without consuming global RNG",
		begin_contract_ok,
		{
			"fixture": {"ok": fixture.get("ok", false), "failedCases": fixture.get("failedCases", []), "lotUids": lot_uids},
			"interrupted": interrupted_begin,
			"memoryRollback": begin_memory_rolled_back,
			"diskIdle": begin_disk_idle,
			"diskFull": begin_disk_full,
			"diskNoPartial": begin_no_partial,
			"begin": begin_result,
			"session": session_after_begin,
			"pending": pending_after_begin,
			"rng0": retry_rng_before == begin_rng_after,
			"immutableAttempt": immutable_attempt
		}
	)
	if not begin_contract_ok:
		finish(gs, main)
		return

	# Lot 1 is committed through the session coordinator but must be byte-for-byte
	# equivalent to the generic pending-auction receipt/history. A second Hammer
	# is idempotent and cannot append a receipt or create lot 2.
	gs.persistence_enabled = false
	var tx1 := String(pending_state(gs).get("transactionId", ""))
	var history_before_lot1: int = int(gs.auction_history.size())
	var commit1_value: Variant = gs.call("commit_grand_reserve_lot", tx1)
	var commit1: Dictionary = commit1_value if commit1_value is Dictionary else {}
	var session_after_lot1 := session_state(gs)
	var receipts_after_lot1 := session_receipts(session_after_lot1)
	var generic_receipt1: Dictionary = gs.committed_auction_response(tx1)
	var lot1_payload_after := authoritative_signature(gs)
	var commit1_duplicate_value: Variant = gs.call("commit_grand_reserve_lot", tx1)
	var commit1_duplicate: Dictionary = commit1_duplicate_value if commit1_duplicate_value is Dictionary else {}
	var duplicate1_mutation0 := authoritative_signature(gs) == lot1_payload_after
	var session_after_duplicate1 := session_state(gs)
	var between_lots_payload: Dictionary = gs.save_payload().duplicate(true)
	var receipt1_signature := receipt_signature(receipts_after_lot1[0]) if receipts_after_lot1.size() == 1 else {}
	var commit1_signature := receipt_signature(commit1)
	var generic1_signature := receipt_signature(generic_receipt1)
	var lot1_exactly_once: bool = bool(commit1.get("ok", false)) \
		and String(session_after_lot1.get("phase", "")) == "BETWEEN_LOTS" \
		and int(session_after_lot1.get("currentLotIndex", -1)) == 0 \
		and receipts_after_lot1.size() == 1 \
		and String(receipt1_signature.get("sale_status", "")) == "SOLD" \
		and receipt1_signature == commit1_signature \
		and receipt1_signature == generic1_signature \
		and gs.auction_history.size() == history_before_lot1 + 1 \
		and bool(commit1_duplicate.get("ok", false)) \
		and receipt_signature(commit1_duplicate) == receipt1_signature \
		and duplicate1_mutation0 \
		and session_receipts(session_after_duplicate1).size() == 1 \
		and String(session_after_duplicate1.get("phase", "")) == "BETWEEN_LOTS"
	record(
		"GRAND-RESERVE-LIVE-LOT1-01",
		"Lot 1 SOLD uses the generic pending receipt exactly once and stops at BETWEEN_LOTS until NEXT LOT",
		lot1_exactly_once,
		{
			"transactionId": tx1,
			"sessionReceipt": receipt1_signature,
			"commitReceipt": commit1_signature,
			"genericReceipt": generic1_signature,
			"phase": session_after_lot1.get("phase", ""),
			"duplicate": commit1_duplicate,
			"duplicateMutation0": duplicate1_mutation0
		}
	)
	if not lot1_exactly_once:
		finish(gs, main)
		return

	# BETWEEN_LOTS is a real lock even though the generic pending auction has
	# already committed. Normal auction creation, selection, day and other mutable
	# gameplay actions all leave the authoritative payload unchanged.
	var outsider: Dictionary = gs.find_inventory_instance(outsider_uid)
	var lock_payload: Dictionary = gs.save_payload().duplicate(true)
	var lock_before := authoritative_signature(gs)
	var event_id := String(registry.events[0].get("id", "")) if not registry.events.is_empty() else ""
	var upgrade_id := String(registry.upgrades[0].get("id", "")) if not registry.upgrades.is_empty() else ""
	var lock_responses := {
		"day": gs.advance_day(),
		"event": gs.execute_event(event_id),
		"upgrade": gs.buy_upgrade(upgrade_id),
		"market": gs.buy_market_lot(String(gs.market_roster[0].get("lotId", ""))) if not gs.market_roster.is_empty() else false,
		"clean": gs.clean(outsider, "soft_brush"),
		"repair": gs.repair(outsider),
		"relist": gs.list_auction(outsider, 2, 3, 0.9, "CERTAIN", 10),
		"normalPending": gs.create_pending_auction(outsider, false),
		"selection": gs.select_final_lot(String(lot_uids[0])),
		"newGame": gs.new_game(1),
		"startStage": gs.start_stage(1)
	}
	var lock_after := authoritative_signature(gs)
	var lock_mutation0 := lock_before == lock_after
	if not lock_mutation0:
		gs.apply_save_data(lock_payload)
		gs.player_profile = initial_profile.duplicate(true)
	var normal_pending_response: Dictionary = lock_responses.get("normalPending", {}) if lock_responses.get("normalPending", {}) is Dictionary else {}
	record(
		"GRAND-RESERVE-LIVE-LOCK-01",
		"An active session locks mutable gameplay and blocks a non-Grand-Reserve pending auction during BETWEEN_LOTS",
		lock_mutation0 \
			and not bool(normal_pending_response.get("ok", true)) \
			and String(session_state(gs).get("phase", "")) == "BETWEEN_LOTS" \
			and session_state(gs).get("lotUids", []) == lot_uids \
			and session_receipts(session_state(gs)).size() == 1,
		{"mutation0": lock_mutation0, "normalPending": normal_pending_response, "responses": lock_responses}
	)

	# Only NEXT LOT creates lot 2. Its snapshot/cue/fingerprint and global RNG
	# cursor survive an exact save/restart, then NO_SALE appends once after SOLD.
	var before_next1 := session_state(gs)
	var next1_rng_before: int = gs.rng.state
	var next1_value: Variant = gs.call("advance_grand_reserve_lot")
	var next1: Dictionary = next1_value if next1_value is Dictionary else {}
	var next1_rng_after: int = gs.rng.state
	var lot2_session := session_state(gs)
	var lot2_pending := pending_state(gs)
	var tx2 := String(lot2_pending.get("transactionId", ""))
	var next_lot_only := bool(next1.get("ok", false)) \
		and String(before_next1.get("phase", "")) == "BETWEEN_LOTS" \
		and int(before_next1.get("currentLotIndex", -1)) == 0 \
		and pending_aligned_with_session(lot2_session, lot2_pending) \
		and int(lot2_session.get("currentLotIndex", -1)) == 1 \
		and String(lot2_pending.get("artifactId", "")) == String(lot_uids[1]) \
		and tx2 != tx1 \
		and session_receipts(lot2_session).size() == 1 \
		and next1_rng_before == next1_rng_after
	if not next_lot_only:
		record(
			"GRAND-RESERVE-LIVE-LOT2-01",
			"NEXT LOT alone creates lot 2; its middle cue restarts exactly with RNG0 and NO_SALE appends once after SOLD",
			false,
			{"next": next1, "session": lot2_session, "pending": lot2_pending, "rng0": next1_rng_before == next1_rng_after}
		)
		finish(gs, main)
		return

	gs.persistence_enabled = true
	var lot2_queue: Array = lot2_pending.get("cueQueue", []) if lot2_pending.get("cueQueue", []) is Array else []
	var lot2_middle_index := clampi(2, 1, maxi(1, lot2_queue.size() - 2))
	var cue2_value: Variant = gs.call("set_pending_auction_cue_index", tx2, lot2_middle_index, LOT2_RESUME_PATH)
	var cue2: Dictionary = cue2_value if cue2_value is Dictionary else {}
	var lot2_session_before_restart := session_state(gs)
	var lot2_pending_before_restart := pending_state(gs)
	var lot2_rng_before_restart: int = gs.rng.state
	gs.reset_game()
	var lot2_loaded := bool(gs.load_game(LOT2_RESUME_PATH))
	var lot2_session_after_restart := session_state(gs)
	var lot2_pending_after_restart := pending_state(gs)
	var lot2_session_exact: bool = canonical_persisted_value(lot2_session_after_restart) == canonical_persisted_value(lot2_session_before_restart)
	var lot2_pending_exact: bool = canonical_persisted_value(lot2_pending_after_restart) == canonical_persisted_value(lot2_pending_before_restart)
	var lot2_rng_after_restart: int = gs.rng.state
	var lot2_rng_exact: bool = lot2_rng_after_restart == lot2_rng_before_restart
	var lot2_cue_exact: bool = int(lot2_pending_after_restart.get("cueIndex", -1)) == lot2_middle_index
	var lot2_resume_exact: bool = lot2_loaded \
		and lot2_session_exact \
		and lot2_pending_exact \
		and lot2_rng_exact \
		and lot2_cue_exact
	if not bool(cue2.get("ok", false)) or not lot2_resume_exact:
		record(
			"GRAND-RESERVE-LIVE-LOT2-01",
			"NEXT LOT alone creates lot 2; its middle cue restarts exactly with RNG0 and NO_SALE appends once after SOLD",
			false,
			{
				"next": next1,
				"cue": cue2,
				"resumeExact": lot2_resume_exact,
				"loaded": lot2_loaded,
				"sessionExact": lot2_session_exact,
				"pendingExact": lot2_pending_exact,
				"rngExact": lot2_rng_exact,
				"rngBefore": lot2_rng_before_restart,
				"rngAfter": lot2_rng_after_restart,
				"cueExact": lot2_cue_exact,
				"sessionBefore": lot2_session_before_restart,
				"sessionAfter": lot2_session_after_restart,
				"pendingBefore": lot2_pending_before_restart,
				"pendingAfter": lot2_pending_after_restart,
			}
		)
		finish(gs, main)
		return
	var lot2_final_index := maxi(0, lot2_pending_after_restart.get("cueQueue", []).size() - 1)
	gs.call("set_pending_auction_cue_index", tx2, lot2_final_index, LOT2_RESUME_PATH)
	var receipt1_before_lot2 := receipt_signature(session_receipts(session_state(gs))[0])
	var history_before_lot2: int = int(gs.auction_history.size())
	var commit2_value: Variant = gs.call("commit_grand_reserve_lot", tx2, LOT2_RESUME_PATH)
	var commit2: Dictionary = commit2_value if commit2_value is Dictionary else {}
	var session_after_lot2 := session_state(gs)
	var receipts_after_lot2 := session_receipts(session_after_lot2)
	var lot2_payload_after := authoritative_signature(gs)
	var commit2_duplicate_value: Variant = gs.call("commit_grand_reserve_lot", tx2, LOT2_RESUME_PATH)
	var commit2_duplicate: Dictionary = commit2_duplicate_value if commit2_duplicate_value is Dictionary else {}
	var lot2_exactly_once: bool = bool(commit2.get("ok", false)) \
		and String(session_after_lot2.get("phase", "")) == "BETWEEN_LOTS" \
		and int(session_after_lot2.get("currentLotIndex", -1)) == 1 \
		and receipts_after_lot2.size() == 2 \
		and receipt_signature(receipts_after_lot2[0]) == receipt1_before_lot2 \
		and String(receipt_signature(receipts_after_lot2[1]).get("sale_status", "")) == "NO_SALE" \
		and receipt_signature(commit2) == receipt_signature(receipts_after_lot2[1]) \
		and receipt_signature(gs.committed_auction_response(tx2)) == receipt_signature(receipts_after_lot2[1]) \
		and gs.auction_history.size() == history_before_lot2 + 1 \
		and bool(commit2_duplicate.get("ok", false)) \
		and receipt_signature(commit2_duplicate) == receipt_signature(receipts_after_lot2[1]) \
		and authoritative_signature(gs) == lot2_payload_after
	var lot2_contract_ok: bool = next_lot_only and bool(cue2.get("ok", false)) and lot2_resume_exact and lot2_exactly_once
	record(
		"GRAND-RESERVE-LIVE-LOT2-01",
		"NEXT LOT alone creates lot 2; its middle cue restarts exactly with RNG0 and NO_SALE appends once after SOLD",
		lot2_contract_ok,
		{
			"next": next1,
			"nextOnly": next_lot_only,
			"cue": cue2,
			"resumeExact": lot2_resume_exact,
			"transactionId": tx2,
			"receipts": receipts_after_lot2.map(func(receipt: Variant): return receipt_signature(receipt)),
			"duplicateMutation0": authoritative_signature(gs) == lot2_payload_after
		}
	)
	if not lot2_contract_ok:
		finish(gs, main)
		return

	# Lot 3 first rejects stale public terms with mutation0. Crash point E then
	# proves the last Hammer persists either the old two-receipt boundary or the
	# entire third receipt/results/score/ending/Stage Clear/FINALIZED boundary --
	# never a generic committed auction stranded between those generations.
	gs.persistence_enabled = false
	var next2_value: Variant = gs.call("advance_grand_reserve_lot")
	var next2: Dictionary = next2_value if next2_value is Dictionary else {}
	var lot3_session := session_state(gs)
	var lot3_pending := pending_state(gs)
	var tx3 := String(lot3_pending.get("transactionId", ""))
	var lot3_artifact: Dictionary = gs.find_inventory_instance(String(lot3_pending.get("artifactId", "")))
	if not bool(next2.get("ok", false)) or not pending_aligned_with_session(lot3_session, lot3_pending) or lot3_artifact.is_empty():
		record(
			"GRAND-RESERVE-LIVE-FINAL-01",
			"Stale lot 3 fails closed and the last Hammer atomically finalizes its third receipt, campaign result, ending and frozen Stage Clear exactly once",
			false,
			{"next": next2, "session": lot3_session, "pending": lot3_pending, "artifactPresent": not lot3_artifact.is_empty()}
		)
		finish(gs, main)
		return
	var original_lot3_reserve := int(lot3_artifact.get("listing", {}).get("reserve", 0))
	lot3_artifact.listing.reserve = original_lot3_reserve + 1
	var stale_before := authoritative_signature(gs)
	var stale3_value: Variant = gs.call("commit_grand_reserve_lot", tx3)
	var stale3: Dictionary = stale3_value if stale3_value is Dictionary else {}
	var stale_mutation0 := authoritative_signature(gs) == stale_before
	lot3_artifact.listing.reserve = original_lot3_reserve
	var lot3_final_index := maxi(0, pending_state(gs).get("cueQueue", []).size() - 1)
	gs.call("set_pending_auction_cue_index", tx3, lot3_final_index)
	var pre_final_payload: Dictionary = gs.save_payload().duplicate(true)
	var pre_final_profile: Dictionary = gs.profile_payload().duplicate(true)
	var pre_final_signature := authoritative_signature(gs)
	var default_profile_path: String = String(gs.PROFILE_PATH)
	var default_profile_backup_path: String = default_profile_path + String(gs.SAVE_BACKUP_SUFFIX)
	var default_profile_before: Dictionary = persisted_file_state(default_profile_path)
	var default_profile_backup_before: Dictionary = persisted_file_state(default_profile_backup_path)
	gs.persistence_enabled = true
	cleanup_slots(gs, FINAL_ATOMIC_PATH)
	var final_baseline_saved := bool(gs.save_game(FINAL_ATOMIC_PATH))
	var final_crash_configured: bool = bool(gs.configure_save_crash_injection_for_test("E_AFTER_PROMOTE_BEFORE_FINAL_VALIDATION"))
	var interrupted_final_value: Variant = gs.call("commit_grand_reserve_lot", tx3, FINAL_ATOMIC_PATH)
	var interrupted_final: Dictionary = interrupted_final_value if interrupted_final_value is Dictionary else {}
	var final_memory_rolled_back := authoritative_signature(gs) == pre_final_signature
	gs.reset_game()
	var final_disk_loaded := bool(gs.load_game(FINAL_ATOMIC_PATH)) if final_baseline_saved else false
	var final_disk_old := String(session_state(gs).get("phase", "")) == "AUCTION_PENDING" \
		and int(session_state(gs).get("currentLotIndex", -1)) == 2 \
		and session_receipts(session_state(gs)).size() == 2 \
		and not bool(gs.campaign_state.get("grandReserve", {}).get("completed", false)) \
		and String(gs.stage_run_state.get("status", "")) == "RUNNING"
	var final_disk_complete := final_state_complete(gs)
	var final_no_partial := final_disk_loaded and (final_disk_old or final_disk_complete)
	gs.apply_save_data(pre_final_payload)
	gs.player_profile = pre_final_profile.duplicate(true)
	cleanup_slots(gs, FINAL_ATOMIC_PATH)
	var final_retry_baseline := bool(gs.save_game(FINAL_ATOMIC_PATH))
	var history_before_final: int = int(gs.auction_history.size())
	var final_commit_value: Variant = gs.call("commit_grand_reserve_lot", tx3, FINAL_ATOMIC_PATH)
	var final_commit: Dictionary = final_commit_value if final_commit_value is Dictionary else {}
	var final_session := session_state(gs)
	var final_receipts := session_receipts(final_session)
	var final_saved_payload: Dictionary = gs.read_save_dictionary(FINAL_ATOMIC_PATH)
	var final_saved_valid := bool(gs.validate_save_payload(final_saved_payload).get("ok", false))
	var final_saved_session: Dictionary = final_saved_payload.get("grandReserveSession", {}) if final_saved_payload.get("grandReserveSession", {}) is Dictionary else {}
	var final_payload_after := authoritative_signature(gs)
	var final_duplicate_value: Variant = gs.call("commit_grand_reserve_lot", tx3, FINAL_ATOMIC_PATH)
	var final_duplicate: Dictionary = final_duplicate_value if final_duplicate_value is Dictionary else {}
	var default_profile_after: Dictionary = persisted_file_state(default_profile_path)
	var default_profile_backup_after: Dictionary = persisted_file_state(default_profile_backup_path)
	var custom_path_profile_untouched: bool = persisted_file_state_equal(default_profile_before, default_profile_after) \
		and persisted_file_state_equal(default_profile_backup_before, default_profile_backup_after)
	var unique_transactions := {}
	for receipt_value: Variant in final_receipts:
		unique_transactions[String(receipt_signature(receipt_value).get("transactionId", ""))] = true
	var final_exactly_once: bool = bool(final_commit.get("ok", false)) \
		and final_state_complete(gs) \
		and final_receipts.size() == 3 \
		and unique_transactions.size() == 3 \
		and receipt_signature(final_receipts[0]).get("sale_status", "") == "SOLD" \
		and receipt_signature(final_receipts[1]).get("sale_status", "") == "NO_SALE" \
		and receipt_signature(final_receipts[2]).get("sale_status", "") == "SOLD" \
		and receipt_signature(final_commit) == receipt_signature(final_receipts[2]) \
		and receipt_signature(gs.committed_auction_response(tx3)) == receipt_signature(final_receipts[2]) \
		and gs.auction_history.size() == history_before_final + 1 \
		and final_saved_valid \
		and String(final_saved_session.get("phase", "")) == "FINALIZED" \
		and final_saved_session.get("receipts", []).size() == 3 \
		and final_saved_payload.get("campaign", {}).get("grandReserve", {}).get("results", []).size() == 3 \
		and not String(final_saved_payload.get("campaign", {}).get("currentEnding", "")).is_empty() \
		and String(final_saved_payload.get("stageRunState", {}).get("status", "")) == "CLEARED" \
		and not bool(final_saved_payload.get("stageRunState", {}).get("stageClearAcknowledged", true)) \
		and bool(final_duplicate.get("ok", false)) \
		and receipt_signature(final_duplicate) == receipt_signature(final_receipts[2]) \
		and authoritative_signature(gs) == final_payload_after
	record(
		"GRAND-RESERVE-LIVE-FINAL-01",
		"Stale lot 3 fails closed and the last Hammer atomically finalizes its third receipt, campaign result, ending and frozen Stage Clear exactly once",
		bool(next2.get("ok", false)) \
			and pending_aligned_with_session(lot3_session, lot3_pending) \
			and int(lot3_session.get("currentLotIndex", -1)) == 2 \
			and not bool(stale3.get("ok", true)) \
			and String(stale3.get("code", "")) == "STALE_PENDING_AUCTION" \
			and stale_mutation0 \
			and final_baseline_saved \
			and final_crash_configured \
			and not bool(interrupted_final.get("ok", true)) \
			and final_memory_rolled_back \
			and final_no_partial \
			and final_retry_baseline \
			and final_exactly_once,
		{
			"next": next2,
			"stale": stale3,
			"staleMutation0": stale_mutation0,
			"interrupted": interrupted_final,
			"memoryRollback": final_memory_rolled_back,
			"diskOld": final_disk_old,
			"diskComplete": final_disk_complete,
			"diskNoPartial": final_no_partial,
			"finalCommit": final_commit,
			"session": final_session,
			"savedSession": final_saved_session,
			"duplicateMutation0": authoritative_signature(gs) == final_payload_after
		}
	)
	record(
		"GRAND-RESERVE-LIVE-CUSTOM-PROFILE-01",
		"A custom-path final Hammer never rewrites the default profile or its backup",
		bool(final_commit.get("ok", false)) \
			and FINAL_ATOMIC_PATH != default_profile_path \
			and custom_path_profile_untouched,
		{
			"customRunPath": FINAL_ATOMIC_PATH,
			"defaultProfilePath": default_profile_path,
			"defaultProfileBackupPath": default_profile_backup_path,
			"current": {
				"before": persisted_file_evidence(default_profile_before),
				"after": persisted_file_evidence(default_profile_after),
				"unchanged": persisted_file_state_equal(default_profile_before, default_profile_after),
			},
			"backup": {
				"before": persisted_file_evidence(default_profile_backup_before),
				"after": persisted_file_evidence(default_profile_backup_after),
				"unchanged": persisted_file_state_equal(default_profile_backup_before, default_profile_backup_after),
			},
		}
	)

	# Every authored live-session phase is cross-checked against its pending
	# checkpoint, active inventory identity and append-only ordered receipts. These
	# are pure validation calls: hostile payloads must fail without mutating memory.
	var initial_validation_value: Variant = gs.call("validate_save_payload", initial_payload)
	var initial_validation: Dictionary = initial_validation_value if initial_validation_value is Dictionary else {}
	var begin_validation_value: Variant = gs.call("validate_save_payload", begin_state_payload)
	var begin_validation: Dictionary = begin_validation_value if begin_validation_value is Dictionary else {}
	var between_validation_value: Variant = gs.call("validate_save_payload", between_lots_payload)
	var between_validation: Dictionary = between_validation_value if between_validation_value is Dictionary else {}
	var final_validation_value: Variant = gs.call("validate_save_payload", final_saved_payload)
	var final_validation: Dictionary = final_validation_value if final_validation_value is Dictionary else {}

	var begin_pending_value: Variant = begin_state_payload.get("pendingAuction", {})
	var begin_pending: Dictionary = begin_pending_value.duplicate(true) if begin_pending_value is Dictionary else {}
	var begin_pending_transaction_id: String = String(begin_pending.get("transactionId", ""))
	var begin_pending_fingerprint: String = String(begin_pending.get("publicFingerprint", ""))
	var orphan_idle_payload: Dictionary = initial_payload.duplicate(true)
	orphan_idle_payload["pendingAuction"] = begin_pending.duplicate(true)
	var pending_malformed_nonempty_result: Dictionary = pending_result_replacement_payload(
		begin_state_payload,
		{"transactionId": begin_pending_transaction_id, "publicFingerprint": begin_pending_fingerprint}
	)
	var pending_numeric_type_result: Dictionary = pending_result_field_payload(begin_state_payload, "hammer", "not_numeric")
	var pending_fingerprint_mismatch: Dictionary = pending_outer_field_payload(
		begin_state_payload,
		"publicFingerprint",
		"%s_mismatch" % begin_pending_fingerprint
	)
	var pending_scalar_cue_queue: Dictionary = pending_cue_queue_payload(begin_state_payload, [1])
	var begin_queue_value: Variant = begin_pending.get("cueQueue", [])
	var begin_queue: Array = begin_queue_value.duplicate(true) if begin_queue_value is Array else []
	if not begin_queue.is_empty() and begin_queue[0] is Dictionary:
		var mismatched_first_cue: Dictionary = (begin_queue[0] as Dictionary).duplicate(true)
		mismatched_first_cue["phase"] = "CALL"
		begin_queue[0] = mismatched_first_cue
	var pending_derived_cue_mismatch: Dictionary = pending_cue_queue_payload(begin_state_payload, begin_queue)

	var pending_artifact_mismatch: Dictionary = begin_state_payload.duplicate(true)
	var artifact_mismatch_pending_value: Variant = pending_artifact_mismatch.get("pendingAuction", {})
	var artifact_mismatch_pending: Dictionary = artifact_mismatch_pending_value if artifact_mismatch_pending_value is Dictionary else {}
	artifact_mismatch_pending["artifactId"] = String(lot_uids[1])
	pending_artifact_mismatch["pendingAuction"] = artifact_mismatch_pending

	var pending_transaction_mismatch: Dictionary = begin_state_payload.duplicate(true)
	var transaction_mismatch_pending_value: Variant = pending_transaction_mismatch.get("pendingAuction", {})
	var transaction_mismatch_pending: Dictionary = transaction_mismatch_pending_value if transaction_mismatch_pending_value is Dictionary else {}
	transaction_mismatch_pending["transactionId"] = "%s_mismatch" % String(transaction_mismatch_pending.get("transactionId", ""))
	pending_transaction_mismatch["pendingAuction"] = transaction_mismatch_pending

	var pending_missing_inventory: Dictionary = begin_state_payload.duplicate(true)
	var begin_session_value: Variant = begin_state_payload.get("grandReserveSession", {})
	var begin_session: Dictionary = begin_session_value if begin_session_value is Dictionary else {}
	var begin_lot_uids_value: Variant = begin_session.get("lotUids", [])
	var begin_lot_uids: Array = begin_lot_uids_value if begin_lot_uids_value is Array else []
	var missing_active_uid: String = String(begin_lot_uids[0]) if not begin_lot_uids.is_empty() else ""
	var future_lot_uid: String = String(begin_lot_uids[1]) if begin_lot_uids.size() >= 2 else ""
	var retained_inventory: Array = []
	var authored_inventory_value: Variant = pending_missing_inventory.get("inventory", [])
	var authored_inventory: Array = authored_inventory_value if authored_inventory_value is Array else []
	for artifact_value: Variant in authored_inventory:
		if artifact_value is Dictionary and String((artifact_value as Dictionary).get("uniqueId", "")) != missing_active_uid:
			retained_inventory.append((artifact_value as Dictionary).duplicate(true))
	pending_missing_inventory["inventory"] = retained_inventory
	var pending_future_missing: Dictionary = inventory_hostile_payload(begin_state_payload, future_lot_uid, true, false)
	var pending_future_sold: Dictionary = inventory_hostile_payload(begin_state_payload, future_lot_uid, false, true)

	var between_missing_committed: Dictionary = between_lots_payload.duplicate(true)
	var missing_committed_value: Variant = between_missing_committed.get("pendingAuction", {})
	var missing_committed: Dictionary = missing_committed_value if missing_committed_value is Dictionary else {}
	missing_committed["status"] = "PENDING"
	missing_committed["receipt"] = {}
	between_missing_committed["pendingAuction"] = missing_committed

	var between_transaction_mismatch: Dictionary = between_lots_payload.duplicate(true)
	var between_mismatch_value: Variant = between_transaction_mismatch.get("pendingAuction", {})
	var between_mismatch: Dictionary = between_mismatch_value if between_mismatch_value is Dictionary else {}
	between_mismatch["transactionId"] = "%s_mismatch" % String(between_mismatch.get("transactionId", ""))
	between_transaction_mismatch["pendingAuction"] = between_mismatch
	var between_next_missing: Dictionary = inventory_hostile_payload(between_lots_payload, future_lot_uid, true, false)
	var between_next_sold: Dictionary = inventory_hostile_payload(between_lots_payload, future_lot_uid, false, true)
	var between_receipt_mismatch: Dictionary = pending_receipt_mismatch_payload(between_lots_payload)
	var between_committed_nonfinal_cue: Dictionary = pending_cue_index_payload(between_lots_payload, 0)
	var between_active_artifact_id_only: Dictionary = session_active_artifact_id_only_payload(between_lots_payload)
	var between_last_receipt_artifact_mismatch: Dictionary = last_receipt_artifact_field_payload(
		between_lots_payload,
		"displayName",
		"Tampered Receipt Artifact"
	)

	var malformed_receipt_payload: Dictionary = between_lots_payload.duplicate(true)
	var malformed_session_value: Variant = malformed_receipt_payload.get("grandReserveSession", {})
	var malformed_session: Dictionary = malformed_session_value if malformed_session_value is Dictionary else {}
	var malformed_receipts_value: Variant = malformed_session.get("receipts", [])
	var malformed_receipts: Array = malformed_receipts_value if malformed_receipts_value is Array else []
	if not malformed_receipts.is_empty():
		malformed_receipts[0] = {"artifact": {}, "auction": {}}
	malformed_session["receipts"] = malformed_receipts
	malformed_receipt_payload["grandReserveSession"] = malformed_session

	var duplicate_receipt_payload: Dictionary = final_saved_payload.duplicate(true)
	var duplicate_session_value: Variant = duplicate_receipt_payload.get("grandReserveSession", {})
	var duplicate_session: Dictionary = duplicate_session_value if duplicate_session_value is Dictionary else {}
	var duplicate_receipts_value: Variant = duplicate_session.get("receipts", [])
	var duplicate_receipts: Array = duplicate_receipts_value if duplicate_receipts_value is Array else []
	if duplicate_receipts.size() >= 2 and duplicate_receipts[0] is Dictionary and duplicate_receipts[1] is Dictionary:
		var first_receipt: Dictionary = duplicate_receipts[0]
		var first_auction_value: Variant = first_receipt.get("auction", {})
		var first_auction: Dictionary = first_auction_value if first_auction_value is Dictionary else {}
		var second_receipt: Dictionary = (duplicate_receipts[1] as Dictionary).duplicate(true)
		var second_auction_value: Variant = second_receipt.get("auction", {})
		var second_auction: Dictionary = second_auction_value if second_auction_value is Dictionary else {}
		second_auction["transactionId"] = String(first_auction.get("transactionId", ""))
		second_receipt["auction"] = second_auction
		duplicate_receipts[1] = second_receipt
	duplicate_session["receipts"] = duplicate_receipts
	duplicate_receipt_payload["grandReserveSession"] = duplicate_session

	var misaligned_receipt_payload: Dictionary = final_saved_payload.duplicate(true)
	var misaligned_session_value: Variant = misaligned_receipt_payload.get("grandReserveSession", {})
	var misaligned_session: Dictionary = misaligned_session_value if misaligned_session_value is Dictionary else {}
	var misaligned_receipts_value: Variant = misaligned_session.get("receipts", [])
	var misaligned_receipts: Array = misaligned_receipts_value if misaligned_receipts_value is Array else []
	if not misaligned_receipts.is_empty() and misaligned_receipts[0] is Dictionary:
		var misaligned_receipt: Dictionary = (misaligned_receipts[0] as Dictionary).duplicate(true)
		var misaligned_artifact_value: Variant = misaligned_receipt.get("artifact", {})
		var misaligned_artifact: Dictionary = misaligned_artifact_value if misaligned_artifact_value is Dictionary else {}
		misaligned_artifact["instanceId"] = String(lot_uids[1])
		misaligned_artifact["uniqueId"] = String(lot_uids[1])
		misaligned_receipt["artifact"] = misaligned_artifact
		misaligned_receipts[0] = misaligned_receipt
	misaligned_session["receipts"] = misaligned_receipts
	misaligned_receipt_payload["grandReserveSession"] = misaligned_session

	var final_pending_receipt_mismatch: Dictionary = pending_receipt_mismatch_payload(final_saved_payload)
	var final_campaign_results_mismatch: Dictionary = campaign_results_mismatch_payload(final_saved_payload)
	var final_empty_score: Dictionary = campaign_score_payload(final_saved_payload, {})
	var final_malformed_score: Dictionary = campaign_score_payload(final_saved_payload, {"balancedScore": "not_numeric"})
	var final_selected_lots_mismatch: Dictionary = selected_lots_mismatch_payload(final_saved_payload)
	var final_active_artifact_mismatch: Dictionary = session_active_artifact_field_payload(
		final_saved_payload,
		"displayName",
		"Tampered Final Active Artifact"
	)

	var market_state_not_dictionary: Dictionary = initial_payload.duplicate(true)
	market_state_not_dictionary["marketState"] = []
	var market_state_bad_value: Dictionary = initial_payload.duplicate(true)
	var market_dictionary_value: Variant = market_state_bad_value.get("marketState", {})
	var market_dictionary: Dictionary = market_dictionary_value if market_dictionary_value is Dictionary else {}
	var market_key: String = String(market_dictionary.keys()[0]) if not market_dictionary.is_empty() else "all"
	market_dictionary[market_key] = {}
	market_state_bad_value["marketState"] = market_dictionary

	var daily_modifiers_not_dictionary: Dictionary = initial_payload.duplicate(true)
	daily_modifiers_not_dictionary["dailyModifiers"] = []
	var daily_modifiers_bad_market_all: Dictionary = initial_payload.duplicate(true)
	var daily_market_all_value: Variant = daily_modifiers_bad_market_all.get("dailyModifiers", {})
	var daily_market_all: Dictionary = daily_market_all_value if daily_market_all_value is Dictionary else {}
	daily_market_all["market_all"] = {}
	daily_modifiers_bad_market_all["dailyModifiers"] = daily_market_all
	var daily_modifiers_bad_listing_bonus: Dictionary = initial_payload.duplicate(true)
	var daily_listing_value: Variant = daily_modifiers_bad_listing_bonus.get("dailyModifiers", {})
	var daily_listing: Dictionary = daily_listing_value if daily_listing_value is Dictionary else {}
	daily_listing["listing_bonus"] = "not_numeric"
	daily_modifiers_bad_listing_bonus["dailyModifiers"] = daily_listing

	var upgrades_not_array: Dictionary = initial_payload.duplicate(true)
	upgrades_not_array["upgrades"] = {}
	var upgrades_object_entry: Dictionary = initial_payload.duplicate(true)
	upgrades_object_entry["upgrades"] = [{}]
	var upgrades_unknown_id: Dictionary = initial_payload.duplicate(true)
	upgrades_unknown_id["upgrades"] = ["__unknown_upgrade_hostile_save__"]
	var known_upgrade_id: String = String(registry.upgrades[0].get("id", "")) if not registry.upgrades.is_empty() else ""
	var upgrades_duplicate_id: Dictionary = initial_payload.duplicate(true)
	upgrades_duplicate_id["upgrades"] = [known_upgrade_id, known_upgrade_id]

	var rejection_rows: Array = [
		validation_rejection(gs, "market_state_not_dictionary", market_state_not_dictionary, "INVALID_MARKET_STATE"),
		validation_rejection(gs, "market_state_nonnumeric_value", market_state_bad_value, "INVALID_MARKET_STATE"),
		validation_rejection(gs, "daily_modifiers_not_dictionary", daily_modifiers_not_dictionary, "INVALID_DAILY_MODIFIERS"),
		validation_rejection(gs, "daily_modifiers_market_all_object", daily_modifiers_bad_market_all, "INVALID_DAILY_MODIFIERS"),
		validation_rejection(gs, "daily_modifiers_listing_bonus_nonnumeric", daily_modifiers_bad_listing_bonus, "INVALID_DAILY_MODIFIERS"),
		validation_rejection(gs, "upgrades_not_array", upgrades_not_array, "INVALID_UPGRADES"),
		validation_rejection(gs, "upgrades_object_entry", upgrades_object_entry, "INVALID_UPGRADES"),
		validation_rejection(gs, "upgrades_unknown_id", upgrades_unknown_id, "INVALID_UPGRADES"),
		validation_rejection(gs, "upgrades_duplicate_id", upgrades_duplicate_id, "INVALID_UPGRADES"),
		validation_rejection(gs, "orphan_idle_pending", orphan_idle_payload, "ORPHANED_GRAND_RESERVE_PENDING"),
		validation_rejection(gs, "auction_pending_artifact_mismatch", pending_artifact_mismatch, "INVALID_PENDING_AUCTION_CONTRACT"),
		validation_rejection(gs, "auction_pending_transaction_mismatch", pending_transaction_mismatch, "INVALID_PENDING_AUCTION_CONTRACT"),
		validation_rejection(gs, "auction_pending_outer_fingerprint_mismatch", pending_fingerprint_mismatch, "INVALID_PENDING_AUCTION_CONTRACT"),
		validation_rejection(gs, "auction_pending_malformed_nonempty_result", pending_malformed_nonempty_result, "INVALID_PENDING_AUCTION_CONTRACT"),
		validation_rejection(gs, "auction_pending_numeric_result_type", pending_numeric_type_result, "INVALID_PENDING_AUCTION_CONTRACT"),
		validation_rejection(gs, "auction_pending_scalar_cue_queue", pending_scalar_cue_queue, "INVALID_PENDING_AUCTION_CONTRACT"),
		validation_rejection(gs, "auction_pending_derived_cue_queue_mismatch", pending_derived_cue_mismatch, "INVALID_PENDING_AUCTION_CONTRACT"),
		validation_rejection(gs, "auction_pending_missing_active_inventory", pending_missing_inventory, "INVALID_PENDING_AUCTION_CONTRACT"),
		validation_rejection(gs, "auction_pending_missing_future_lot", pending_future_missing, "INCONSISTENT_GRAND_RESERVE_INVENTORY"),
		validation_rejection(gs, "auction_pending_sold_future_lot", pending_future_sold, "INCONSISTENT_GRAND_RESERVE_INVENTORY"),
		validation_rejection(gs, "between_lots_missing_committed_pending", between_missing_committed, "INVALID_PENDING_AUCTION_CONTRACT"),
		validation_rejection(gs, "between_lots_transaction_mismatch", between_transaction_mismatch, "INVALID_PENDING_AUCTION_CONTRACT"),
		validation_rejection(gs, "between_lots_missing_next_lot", between_next_missing, "INCONSISTENT_GRAND_RESERVE_INVENTORY"),
		validation_rejection(gs, "between_lots_sold_next_lot", between_next_sold, "INCONSISTENT_GRAND_RESERVE_INVENTORY"),
		validation_rejection(gs, "between_lots_active_artifact_id_only", between_active_artifact_id_only, "INVALID_GRAND_RESERVE_SESSION_CONTRACT"),
		validation_rejection(gs, "between_lots_last_receipt_artifact_mismatch", between_last_receipt_artifact_mismatch, "INCONSISTENT_GRAND_RESERVE_BETWEEN"),
		validation_rejection(gs, "between_lots_committed_nonfinal_cue", between_committed_nonfinal_cue, "INVALID_PENDING_AUCTION_CONTRACT"),
		validation_rejection(gs, "between_lots_pending_receipt_mismatch", between_receipt_mismatch, "INVALID_PENDING_AUCTION_CONTRACT"),
		validation_rejection(gs, "malformed_receipt", malformed_receipt_payload, "INVALID_GRAND_RESERVE_SESSION_CONTRACT"),
		validation_rejection(gs, "duplicate_receipt_transaction", duplicate_receipt_payload, "INVALID_GRAND_RESERVE_SESSION_CONTRACT"),
		validation_rejection(gs, "misaligned_receipt_artifact", misaligned_receipt_payload, "INVALID_GRAND_RESERVE_SESSION_CONTRACT"),
		validation_rejection(gs, "final_pending_receipt_mismatch", final_pending_receipt_mismatch, "INVALID_PENDING_AUCTION_CONTRACT"),
		validation_rejection(gs, "final_campaign_results_mismatch", final_campaign_results_mismatch, "INCONSISTENT_GRAND_RESERVE_FINAL"),
		validation_rejection(gs, "final_empty_score", final_empty_score, "INCONSISTENT_GRAND_RESERVE_FINAL"),
		validation_rejection(gs, "final_malformed_score", final_malformed_score, "INCONSISTENT_GRAND_RESERVE_FINAL"),
		validation_rejection(gs, "final_active_artifact_mismatch", final_active_artifact_mismatch, "INCONSISTENT_GRAND_RESERVE_FINAL"),
		validation_rejection(gs, "final_selected_lots_mismatch", final_selected_lots_mismatch, "INCONSISTENT_GRAND_RESERVE_SELECTION"),
	]
	var rejection_rows_ok: bool = true
	for rejection_value: Variant in rejection_rows:
		if not rejection_value is Dictionary or not bool((rejection_value as Dictionary).get("passed", false)):
			rejection_rows_ok = false
	var valid_baselines: bool = bool(initial_validation.get("ok", false)) \
		and bool(begin_validation.get("ok", false)) \
		and bool(between_validation.get("ok", false)) \
		and bool(final_validation.get("ok", false))
	record(
		"GRAND-RESERVE-LIVE-SAVE-VALIDATION-01",
		"Save validation rejects orphan, phase mismatch, missing inventory and corrupt append-only receipt contracts",
		valid_baselines and rejection_rows_ok,
		{
			"validBaselines": {
				"idle": initial_validation,
				"auctionPending": begin_validation,
				"betweenLots": between_validation,
				"finalized": final_validation,
			},
			"rejections": rejection_rows,
		}
	)

	# The synchronous helper and the visible UI sequence must be two front ends to
	# the same session coordinator. The UI additionally exposes stable identifiers
	# for 1/3..3/3 progress, NEXT LOT and the final Stage Clear CTA at 1280x720.
	gs.persistence_enabled = false
	gs.apply_save_data(initial_payload)
	gs.player_profile = initial_profile.duplicate(true)
	var helper_value: Variant = gs.run_grand_reserve()
	var helper_result: Dictionary = helper_value if helper_value is Dictionary else {}
	var helper_complete := bool(helper_result.get("ok", false)) and final_state_complete(gs)
	var helper_signature := final_equivalence_signature(gs)
	gs.apply_save_data(initial_payload)
	gs.player_profile = initial_profile.duplicate(true)
	main.language = gs.language
	main.show_final_lot_selection()
	await settle_ui(6)
	var ui_drive: Dictionary = await drive_ui_session(main, gs)
	var ui_signature := final_equivalence_signature(gs)
	var viewport_is_1280x720 := int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) == 1280 \
		and int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) == 720
	record(
		"GRAND-RESERVE-LIVE-UI-01",
		"UI and run_grand_reserve share identical results while 1280x720 exposes progress, NEXT LOT and Stage Clear identifiers",
		helper_complete \
			and bool(ui_drive.get("ok", false)) \
			and helper_signature == ui_signature \
			and viewport_is_1280x720,
		{
			"helper": helper_result,
			"helperComplete": helper_complete,
			"ui": ui_drive,
			"equivalent": helper_signature == ui_signature,
			"viewport1280x720": viewport_is_1280x720,
			"requiredIds": ["GrandReserveProgress", "GrandReserveNextLot", "StageClearViewEnding"]
		}
	)

	finish(gs, main)
