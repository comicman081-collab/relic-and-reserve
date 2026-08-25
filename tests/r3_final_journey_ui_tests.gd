extends SceneTree

## Final-lot selection -> Grand Reserve -> Ending -> Postgame UI contract.
##
## The suite intentionally uses visible controls and public UI handlers. It
## writes only its QA JSON report and never exports or packages a build.

const AXIS_IDS := ["investigation", "preservation", "sale"]
const TUTORIAL_STEPS := ["INVESTIGATE", "CITE", "REPORT", "REPAIR", "LIST", "AUCTION"]
const EXPECTED_TEST_COUNT := 10
const RAW_TOKENS := [
	"selectedLotIds", "uniqueId", "specId", "artifactSpecId", "publicFingerprint",
	"reasonTags", "sale_status", "currentEnding", "stageRunState", "ENDING_",
	"GRAND_RESERVE", "AUCTION_PENDING", "BETWEEN_LOTS", "FINALIZED", "NO_CASE",
	"PROVENANCE_STRONG", "PROVENANCE_UNCERTAIN", "CONDITION_GOOD", "CONDITION_RISK",
	"DISCLOSURE_CLEAR", "DISCLOSURE_UNCLEAR", "RESERVE_TOO_HIGH", "RESERVE_MET",
	"NO_PUBLIC_BID"
]

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func settle_ui(frame_count: int = 5) -> void:
	for _frame: int in range(frame_count):
		await process_frame


func visible_nodes_named(root: Node, node_name: String, type_name: String = "") -> Array:
	var visible: Array = []
	for candidate: Node in root.find_children(node_name, type_name, true, false):
		if candidate is CanvasItem and not (candidate as CanvasItem).is_visible_in_tree():
			continue
		visible.append(candidate)
	return visible


func visible_named(root: Node, node_name: String, type_name: String = "") -> Node:
	var matches: Array = visible_nodes_named(root, node_name, type_name)
	return matches[0] if not matches.is_empty() else null


func visible_copy(root: Node) -> String:
	var copy: String = ""
	for label: Node in root.find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree():
			copy += String((label as Label).text) + "\n"
	for button: Node in root.find_children("*", "Button", true, false):
		if (button as Button).is_visible_in_tree():
			copy += String((button as Button).text) + "\n"
	return copy


func normalized_progress(copy: String) -> String:
	return copy.replace(" ", "").replace("\n", "")


func sorted_string_keys(value: Dictionary) -> Array:
	var keys: Array = []
	for key_value: Variant in value.keys():
		keys.append(String(key_value))
	keys.sort()
	return keys


func schema_shape(value: Variant) -> Variant:
	if value is Dictionary:
		var shape: Dictionary = {}
		var dictionary: Dictionary = value
		for key_value: Variant in dictionary.keys():
			shape[String(key_value)] = schema_shape(dictionary.get(key_value))
		return shape
	if value is Array:
		# Array population is gameplay value mutation (for example selecting the
		# first lot), not a save-schema mutation. Dictionary keys, scalar types and
		# every declared schemaVersion remain covered without treating [] -> [uid]
		# as a structural migration.
		return "Array"
	return type_string(typeof(value))


func save_schema_signature(gs: Node) -> String:
	return JSON.stringify({
		"run": schema_shape(gs.save_payload()),
		"profile": schema_shape(gs.profile_payload())
	})


func stable_authority_signature(gs: Node) -> String:
	var run_payload: Dictionary = gs.save_payload().duplicate(true)
	# Locale is the one intentional persisted value changed by KO/EN refresh.
	run_payload["language"] = "<locale>"
	return JSON.stringify({"run": run_payload, "profile": gs.profile_payload()})


func selection_neutral_signature(gs: Node) -> String:
	var run_payload: Dictionary = gs.save_payload().duplicate(true)
	run_payload["language"] = "<locale>"
	var campaign: Dictionary = run_payload.get("campaign", {}).duplicate(true)
	var reserve: Dictionary = campaign.get("grandReserve", {}).duplicate(true)
	reserve["selectedLotIds"] = []
	campaign["grandReserve"] = reserve
	run_payload["campaign"] = campaign
	return JSON.stringify({"run": run_payload, "profile": gs.profile_payload()})


func rect_evidence(node: Node) -> Dictionary:
	if not node is Control:
		return {"present": false, "inside1280x720": false, "rect": []}
	var rect: Rect2 = (node as Control).get_global_rect()
	return {
		"present": true,
		"inside1280x720": rect.size.x > 0.0 and rect.size.y > 0.0 \
			and rect.position.x >= 0.0 and rect.position.y >= 0.0 \
			and rect.end.x <= 1280.0 and rect.end.y <= 720.0,
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	}


func controls_geometry(nodes: Array, forbidden: Array = []) -> Dictionary:
	var rects: Array = []
	var inside: bool = true
	for node_value: Variant in nodes:
		var evidence: Dictionary = rect_evidence(node_value as Node if node_value is Node else null)
		rects.append(evidence)
		inside = inside and bool(evidence.get("inside1280x720", false))
	var separate: bool = true
	for left_index: int in range(nodes.size()):
		if not nodes[left_index] is Control:
			separate = false
			continue
		for right_index: int in range(left_index + 1, nodes.size()):
			if not nodes[right_index] is Control:
				separate = false
				continue
			separate = separate and not (nodes[left_index] as Control).get_global_rect().intersects((nodes[right_index] as Control).get_global_rect())
	var avoids_forbidden: bool = true
	for node_value: Variant in nodes:
		if not node_value is Control:
			avoids_forbidden = false
			continue
		var node_rect: Rect2 = (node_value as Control).get_global_rect()
		for forbidden_value: Variant in forbidden:
			if forbidden_value is Control and (forbidden_value as Control).is_visible_in_tree():
				avoids_forbidden = avoids_forbidden and not node_rect.intersects((forbidden_value as Control).get_global_rect())
	return {
		"ok": inside and separate and avoids_forbidden,
		"inside": inside,
		"separate": separate,
		"avoidsForbidden": avoids_forbidden,
		"rects": rects
	}


func density_evidence(root: Node, max_labels: int, max_buttons: int, max_characters: int) -> Dictionary:
	var labels: Array = []
	var buttons: Array = []
	var character_count: int = 0
	for label: Node in root.find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree():
			labels.append(label)
			character_count += String((label as Label).text).length()
	for button: Node in root.find_children("*", "Button", true, false):
		if (button as Button).is_visible_in_tree():
			buttons.append(button)
			character_count += String((button as Button).text).length()
	return {
		"ok": labels.size() <= max_labels and buttons.size() <= max_buttons and character_count <= max_characters,
		"labels": labels.size(),
		"buttons": buttons.size(),
		"characters": character_count,
		"caps": [max_labels, max_buttons, max_characters]
	}


func leaked_raw_tokens(copy: String, extra_tokens: Array = []) -> Array:
	var tokens: Array = RAW_TOKENS.duplicate()
	for extra_value: Variant in extra_tokens:
		var extra: String = String(extra_value)
		if not extra.is_empty() and not tokens.has(extra):
			tokens.append(extra)
	return tokens.filter(func(token_value: Variant): return copy.contains(String(token_value)))


func fully_unlocked_profile(gs: Node) -> Dictionary:
	var profile: Dictionary = gs.default_player_profile()
	var cleared: Array = []
	for stage_id: int in range(1, 10):
		cleared.append(stage_id)
	profile["highestUnlockedStage"] = 10
	profile["clearedStages"] = cleared
	profile["tutorialCompletedSteps"] = TUTORIAL_STEPS.duplicate()
	return profile


func prepare_stage_ten(gs: Node, registry: Node) -> Dictionary:
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	gs.player_profile = fully_unlocked_profile(gs)
	var started_value: Variant = gs.call("new_game", 10)
	var started: Dictionary = started_value if started_value is Dictionary else {}
	var failed_cases: Array = []
	var prepared_cases: Array = []
	for case_id_value: Variant in registry.get_stage_definition(10).get("case_ids", []):
		var case_id: String = String(case_id_value)
		var prepared: bool = bool(gs.call("prepare_case_for_test", case_id))
		prepared_cases.append({"case": case_id, "prepared": prepared})
		if not prepared:
			failed_cases.append(case_id)
	var eligible_value: Variant = gs.call("eligible_final_lots")
	var eligible: Array = eligible_value if eligible_value is Array else []
	return {
		"ok": bool(started.get("ok", false)) and failed_cases.is_empty() and eligible.size() >= 3 \
			and String(gs.stage_run_state.get("status", "")) == "RUNNING" \
			and String(gs.campaign_state.get("currentAct", "")) == "GRAND_RESERVE" \
			and bool(gs.campaign_state.get("grandReserve", {}).get("invited", false)),
		"started": started,
		"preparedCases": prepared_cases,
		"failedCases": failed_cases,
		"eligible": eligible
	}


func dynamic_artifact_tokens(artifacts: Array) -> Array:
	var tokens: Array = []
	for artifact_value: Variant in artifacts:
		if not artifact_value is Dictionary:
			continue
		var artifact: Dictionary = artifact_value
		for key: String in ["uniqueId", "instanceId", "specId", "artifactSpecId"]:
			var token: String = String(artifact.get(key, ""))
			if not token.is_empty() and not tokens.has(token):
				tokens.append(token)
	return tokens


func final_cards(main: Node) -> Array:
	var cards: Array = []
	for index: int in range(6):
		var card: Node = visible_named(main, "FinalLotCard_%d" % index)
		if card != null:
			cards.append(card)
	return cards


func final_selection_contract(main: Node, eligible: Array) -> Dictionary:
	var progress: Node = visible_named(main, "FinalSelectionProgress", "Label")
	var grid: Node = visible_named(main, "FinalLotGrid")
	var requirement: Node = visible_named(main, "FinalSelectionRequirement", "Label")
	var begin: Node = visible_named(main, "BeginGrandReserve", "Button")
	var cards: Array = final_cards(main)
	var expected_count: int = mini(6, eligible.size())
	var card_rows: Array = []
	var child_contract: bool = cards.size() == expected_count and expected_count >= 3 \
		and visible_named(main, "FinalLotCard_6") == null
	for index: int in range(cards.size()):
		var card: Node = cards[index]
		var name_nodes: Array = visible_nodes_named(card, "FinalLotName", "Label")
		var value_nodes: Array = visible_nodes_named(card, "FinalLotValue", "Label")
		var badge_rows: Array = visible_nodes_named(card, "FinalLotBadgeRow")
		var toggles: Array = visible_nodes_named(card, "FinalLotToggle", "Button")
		var expected: Dictionary = eligible[index] if index < eligible.size() and eligible[index] is Dictionary else {}
		var expected_name: String = String(expected.get("displayName", ""))
		var expected_value: int = int(expected.get("estimatedValue", -1))
		var name_copy: String = String((name_nodes[0] as Label).text) if name_nodes.size() == 1 else ""
		var value_copy: String = String((value_nodes[0] as Label).text) if value_nodes.size() == 1 else ""
		var row_ok: bool = name_nodes.size() == 1 and value_nodes.size() == 1 and badge_rows.size() == 1 and toggles.size() == 1 \
			and not expected_name.is_empty() and name_copy.contains(expected_name) \
			and value_copy.contains("¤%d" % expected_value) \
			and (badge_rows[0] as Node).get_child_count() >= 1
		child_contract = child_contract and row_ok
		card_rows.append({
			"index": index,
			"expectedName": expected_name,
			"expectedValue": expected_value,
			"name": name_copy,
			"value": value_copy,
			"badges": (badge_rows[0] as Node).get_child_count() if badge_rows.size() == 1 else -1,
			"toggles": toggles.size(),
			"ok": row_ok
		})
	var forbidden: Array = []
	for node_name: String in ["Navigation", "StatusMessage", "BeginGrandReserve"]:
		var forbidden_node: Node = visible_named(main, node_name)
		if forbidden_node != null:
			forbidden.append(forbidden_node)
	var geometry: Dictionary = controls_geometry(cards, forbidden)
	var density: Dictionary = density_evidence(main, 48, 24, 1400)
	return {
		"ok": progress is Label and grid is Control and requirement is Label and begin is Button \
			and child_contract and bool(geometry.get("ok", false)) and bool(density.get("ok", false)),
		"progress": String((progress as Label).text) if progress is Label else "",
		"requirement": String((requirement as Label).text) if requirement is Label else "",
		"beginPresent": begin is Button,
		"beginDisabled": bool((begin as Button).disabled) if begin is Button else null,
		"cardCount": cards.size(),
		"expectedCardCount": expected_count,
		"cards": card_rows,
		"geometry": geometry,
		"density": density
	}


func advance_ui_to_hammer(main: Node) -> Dictionary:
	var phases: Array = []
	for _step: int in range(24):
		var cue_value: Variant = main.call("auction_public_cue_state")
		var cue: Dictionary = cue_value if cue_value is Dictionary else {}
		if cue.is_empty():
			return {"ok": false, "code": "MISSING_CUE", "phases": phases}
		phases.append(String(cue.get("phase", "")))
		if bool(cue.get("isFinal", false)):
			var hammer: Node = visible_named(main, "HammerButton", "Button")
			return {"ok": hammer is Button, "code": "OK" if hammer is Button else "MISSING_HAMMER", "phases": phases, "hammer": hammer}
		var next_cue: Node = visible_named(main, "AuctionCueNext", "Button")
		if not next_cue is Button:
			return {"ok": false, "code": "MISSING_NEXT_CUE", "phases": phases}
		(next_cue as Button).pressed.emit()
		await settle_ui(3)
	return {"ok": false, "code": "CUE_LOOP_LIMIT", "phases": phases}


func drive_live_grand_reserve_ui(main: Node, gs: Node) -> Dictionary:
	var rows: Array = []
	for lot_index: int in range(3):
		var session_before_value: Variant = gs.call("grand_reserve_public_state")
		var session_before: Dictionary = session_before_value if session_before_value is Dictionary else {}
		if String(session_before.get("phase", "")) != "AUCTION_PENDING" or int(session_before.get("currentLotIndex", -1)) != lot_index:
			return {"ok": false, "code": "LOT_NOT_PENDING", "lot": lot_index, "session": session_before, "rows": rows}
		var cue_run: Dictionary = await advance_ui_to_hammer(main)
		var hammer_value: Variant = cue_run.get("hammer", null)
		if not bool(cue_run.get("ok", false)) or not hammer_value is Button:
			return {"ok": false, "code": String(cue_run.get("code", "HAMMER_UNAVAILABLE")), "lot": lot_index, "cue": cue_run, "rows": rows}
		(hammer_value as Button).pressed.emit()
		await settle_ui(8)
		var session_after_value: Variant = gs.call("grand_reserve_public_state")
		var session_after: Dictionary = session_after_value if session_after_value is Dictionary else {}
		var receipts_value: Variant = session_after.get("receipts", [])
		var receipts: Array = receipts_value if receipts_value is Array else []
		var expected_phase: String = "FINALIZED" if lot_index == 2 else "BETWEEN_LOTS"
		var lot_ok: bool = String(session_after.get("phase", "")) == expected_phase and receipts.size() == lot_index + 1
		rows.append({"lot": lot_index + 1, "phase": session_after.get("phase", ""), "receipts": receipts.size(), "cuePhases": cue_run.get("phases", []), "ok": lot_ok})
		if not lot_ok:
			return {"ok": false, "code": "HAMMER_BOUNDARY_INVALID", "lot": lot_index, "session": session_after, "rows": rows}
		if lot_index < 2:
			var next_lot: Node = visible_named(main, "GrandReserveNextLot", "Button")
			if not next_lot is Button:
				return {"ok": false, "code": "MISSING_NEXT_LOT", "lot": lot_index, "rows": rows}
			(next_lot as Button).pressed.emit()
			await settle_ui(8)
	var final_session_value: Variant = gs.call("grand_reserve_public_state")
	var final_session: Dictionary = final_session_value if final_session_value is Dictionary else {}
	var final_receipts_value: Variant = final_session.get("receipts", [])
	var final_receipts: Array = final_receipts_value if final_receipts_value is Array else []
	return {
		"ok": String(final_session.get("phase", "")) == "FINALIZED" and final_receipts.size() == 3,
		"code": "OK" if String(final_session.get("phase", "")) == "FINALIZED" and final_receipts.size() == 3 else "FINAL_SESSION_INVALID",
		"rows": rows,
		"session": final_session
	}


func ending_result_rows(main: Node, gs: Node) -> Dictionary:
	var reserve: Dictionary = gs.campaign_state.get("grandReserve", {})
	var results_value: Variant = reserve.get("results", [])
	var authoritative_results: Array = results_value if results_value is Array else []
	var cards: Array = []
	var rows: Array = []
	var authority_ok: bool = authoritative_results.size() == 3
	for index: int in range(3):
		var card: Node = visible_named(main, "EndingLotCard_%d" % index)
		if card != null:
			cards.append(card)
		var result: Dictionary = authoritative_results[index] if index < authoritative_results.size() and authoritative_results[index] is Dictionary else {}
		var artifact: Dictionary = result.get("artifact", {}) if result.get("artifact", {}) is Dictionary else {}
		var auction: Dictionary = result.get("auction", {}) if result.get("auction", {}) is Dictionary else {}
		var name_nodes: Array = visible_nodes_named(card, "EndingLotName", "Label") if card != null else []
		var result_nodes: Array = visible_nodes_named(card, "EndingLotResult", "Label") if card != null else []
		var chips: Array = visible_nodes_named(card, "EndingLotReasonChip", "PanelContainer") if card != null else []
		var name_copy: String = String((name_nodes[0] as Label).text) if name_nodes.size() == 1 else ""
		var result_copy: String = String((result_nodes[0] as Label).text) if result_nodes.size() == 1 else ""
		var chip_copy: String = visible_copy(chips[0]) if chips.size() == 1 else ""
		var primary_value: Variant = main.call("auction_terminal_primary_reason", auction) if main.has_method("auction_terminal_primary_reason") else {}
		var primary: Dictionary = primary_value if primary_value is Dictionary else {}
		var expected_reason: String = String(main.call("auction_reason_label", String(primary.get("code", "")))) if main.has_method("auction_reason_label") else ""
		var expected_status: String = String(main.call("friendly_auction_status", String(auction.get("sale_status", "")))) if main.has_method("friendly_auction_status") else ""
		var expected_name: String = String(artifact.get("displayName", ""))
		var expected_hammer: int = int(auction.get("hammer", 0))
		var amount_required: bool = String(auction.get("sale_status", "")) == "SOLD"
		var amount_ok: bool = not amount_required or result_copy.contains("¤%d" % expected_hammer)
		var row_ok: bool = card is Control and name_nodes.size() == 1 and result_nodes.size() == 1 and chips.size() == 1 \
			and not expected_name.is_empty() and name_copy.contains(expected_name) \
			and not expected_status.is_empty() and result_copy.contains(expected_status) \
			and amount_ok \
			and not expected_reason.is_empty() and chip_copy.contains(expected_reason)
		authority_ok = authority_ok and row_ok
		rows.append({
			"index": index,
			"expectedName": expected_name,
			"name": name_copy,
			"expectedStatus": expected_status,
			"expectedHammer": expected_hammer,
			"amountRequired": amount_required,
			"amountOk": amount_ok,
			"result": result_copy,
			"expectedReason": expected_reason,
			"reason": chip_copy,
			"chipCount": chips.size(),
			"ok": row_ok
		})
	return {"ok": authority_ok and cards.size() == 3 and visible_named(main, "EndingLotCard_3") == null, "cards": cards, "rows": rows}


func ending_axes_authority(main: Node, gs: Node) -> Dictionary:
	var snapshot: Dictionary = gs.stage_run_state.get("stageReplayFeedbackSnapshot", {})
	var axes_value: Variant = snapshot.get("axes", {})
	var axes: Dictionary = axes_value if axes_value is Dictionary else {}
	var panels: Array = []
	var rows: Array = []
	var authority_ok: bool = axes.size() == 3
	for axis_id: String in AXIS_IDS:
		var panel: Node = visible_named(main, "EndingAxis_%s" % axis_id)
		if panel != null:
			panels.append(panel)
		var axis_state: Dictionary = axes.get(axis_id, {}) if axes.get(axis_id, {}) is Dictionary else {}
		var label_method: String = "ending_axis_label" if main.has_method("ending_axis_label") else "stage_replay_axis_label"
		var expected_label: String = String(main.call(label_method, axis_id)) if main.has_method(label_method) else ""
		var expected_score: String = String(main.call("stage_replay_axis_score", axis_state)) if main.has_method("stage_replay_axis_score") else ""
		var copy: String = visible_copy(panel) if panel != null else ""
		var row_ok: bool = panel is Control and not expected_label.is_empty() and copy.contains(expected_label) and not expected_score.is_empty() and copy.contains(expected_score)
		authority_ok = authority_ok and row_ok
		rows.append({"axis": axis_id, "labelMethod": label_method, "label": expected_label, "score": expected_score, "copy": copy, "ok": row_ok})
	return {"ok": authority_ok and panels.size() == 3, "panels": panels, "rows": rows}


func ending_contract(main: Node, gs: Node) -> Dictionary:
	var hero: Node = visible_named(main, "EndingHeroCard")
	var summary: Node = visible_named(main, "EndingSummary", "Label")
	var axes_root: Node = visible_named(main, "EndingAxes")
	var lot_grid: Node = visible_named(main, "EndingLotGrid")
	var postgame: Node = visible_named(main, "PostgameButton", "Button")
	var result_evidence: Dictionary = ending_result_rows(main, gs)
	var axes_evidence: Dictionary = ending_axes_authority(main, gs)
	var cards: Array = result_evidence.get("cards", []) if result_evidence.get("cards", []) is Array else []
	var axes: Array = axes_evidence.get("panels", []) if axes_evidence.get("panels", []) is Array else []
	var forbidden: Array = []
	for node_name: String in ["Navigation", "StatusMessage", "PostgameButton"]:
		var forbidden_node: Node = visible_named(main, node_name)
		if forbidden_node != null:
			forbidden.append(forbidden_node)
	var card_geometry: Dictionary = controls_geometry(cards, forbidden)
	var axis_geometry: Dictionary = controls_geometry(axes, cards + forbidden)
	var all_bounds: Array = [hero, summary, axes_root, lot_grid, postgame]
	var bounds_ok: bool = all_bounds.all(func(node_value: Variant): return bool(rect_evidence(node_value as Node if node_value is Node else null).get("inside1280x720", false)))
	var density: Dictionary = density_evidence(main, 42, 18, 1300)
	var screen_copy: String = visible_copy(main)
	var ending_title: String = String(main.call("friendly_ending_title", String(gs.campaign_state.get("currentEnding", "")))) if main.has_method("friendly_ending_title") else ""
	return {
		"ok": hero is Control and summary is Label and axes_root is Control and lot_grid is Control and postgame is Button \
			and not String((summary as Label).text).is_empty() and not ending_title.is_empty() and screen_copy.contains(ending_title) \
			and bool(result_evidence.get("ok", false)) and bool(axes_evidence.get("ok", false)) \
			and bool(card_geometry.get("ok", false)) and bool(axis_geometry.get("ok", false)) and bounds_ok and bool(density.get("ok", false)),
		"ending": gs.campaign_state.get("currentEnding", ""),
		"endingTitle": ending_title,
		"summary": String((summary as Label).text) if summary is Label else "",
		"results": result_evidence,
		"axes": axes_evidence,
		"cardGeometry": card_geometry,
		"axisGeometry": axis_geometry,
		"bounds": all_bounds.map(func(node_value: Variant): return rect_evidence(node_value as Node if node_value is Node else null)),
		"density": density
	}


func campaign_ending_ids(registry: Node) -> Array:
	var ids: Array = []
	for ending_value: Variant in registry.campaign.get("endings", []):
		if ending_value is Dictionary:
			ids.append(String((ending_value as Dictionary).get("id", "")))
	return ids


func postgame_contract(main: Node, gs: Node, registry: Node) -> Dictionary:
	var hero: Node = visible_named(main, "PostgameHeroCard")
	var progress: Node = visible_named(main, "PostgameProgress", "Label")
	var gallery: Node = visible_named(main, "EndingGallery")
	var stage_select: Node = visible_named(main, "PostgameStageSelect", "Button")
	var new_game: Node = visible_named(main, "PostgameNewGame", "Button")
	var credits: Node = visible_named(main, "PostgameCredits", "Button")
	var cards: Array = []
	var rows: Array = []
	var ending_ids: Array = campaign_ending_ids(registry)
	var unlocked_value: Variant = gs.campaign_state.get("endingUnlocked", [])
	var unlocked: Array = unlocked_value if unlocked_value is Array else []
	var authority_ok: bool = ending_ids.size() == 5
	for index: int in range(5):
		var card: Node = visible_named(main, "EndingCard_%d" % index)
		if card != null:
			cards.append(card)
		var ending_id: String = String(ending_ids[index]) if index < ending_ids.size() else ""
		var title: String = String(main.call("friendly_ending_title", ending_id)) if main.has_method("friendly_ending_title") else ""
		var copy: String = visible_copy(card) if card != null else ""
		var is_unlocked: bool = unlocked.has(ending_id)
		var row_ok: bool = card is Control and not copy.is_empty() and not copy.contains(ending_id) and (not is_unlocked or copy.contains(title))
		authority_ok = authority_ok and row_ok
		rows.append({"index": index, "ending": ending_id, "title": title, "unlocked": is_unlocked, "copy": copy, "ok": row_ok})
	var ctas: Array = [stage_select, new_game, credits]
	var forbidden: Array = []
	for node_name: String in ["Navigation", "StatusMessage"]:
		var forbidden_node: Node = visible_named(main, node_name)
		if forbidden_node != null:
			forbidden.append(forbidden_node)
	var card_geometry: Dictionary = controls_geometry(cards, ctas + forbidden)
	var cta_geometry: Dictionary = controls_geometry(ctas, forbidden)
	var all_bounds: Array = [hero, progress, gallery] + ctas
	var bounds_ok: bool = all_bounds.all(func(node_value: Variant): return bool(rect_evidence(node_value as Node if node_value is Node else null).get("inside1280x720", false)))
	var density: Dictionary = density_evidence(main, 38, 18, 1100)
	var progress_copy: String = String((progress as Label).text) if progress is Label else ""
	var expected_progress: String = "%d/5" % unlocked.size()
	return {
		"ok": hero is Control and progress is Label and gallery is Control and stage_select is Button and new_game is Button and credits is Button \
			and cards.size() == 5 and visible_named(main, "EndingCard_5") == null and authority_ok \
			and normalized_progress(progress_copy).contains(expected_progress) \
			and ctas.all(func(node_value: Variant): return node_value is Button and not (node_value as Button).disabled and not String((node_value as Button).text).is_empty()) \
			and bool(card_geometry.get("ok", false)) and bool(cta_geometry.get("ok", false)) and bounds_ok and bool(density.get("ok", false)),
		"progress": progress_copy,
		"expectedProgress": expected_progress,
		"endingIds": ending_ids,
		"unlocked": unlocked,
		"cards": rows,
		"cardGeometry": card_geometry,
		"ctaGeometry": cta_geometry,
		"bounds": all_bounds.map(func(node_value: Variant): return rect_evidence(node_value as Node if node_value is Node else null)),
		"density": density,
		"creditsOpen": visible_named(main, "CreditsPanel") != null
	}


func record_blocked_remaining(rows: Array, evidence: Dictionary) -> void:
	for row_value: Variant in rows:
		var row: Dictionary = row_value if row_value is Dictionary else {}
		record(String(row.get("id", "FINAL-JOURNEY-BLOCKED")), String(row.get("name", "Blocked by prior public journey gate")), false, evidence)


func write_report_and_quit(main: Node = null) -> void:
	var passed: int = results.filter(func(result: Dictionary): return bool(result.get("passed", false))).size()
	var report: Dictionary = {
		"suite": "R3 Final Journey Illustrated UI",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"skipped": 0,
		"expectedCount": EXPECTED_TEST_COUNT,
		"tests": results
	}
	var output: FileAccess = FileAccess.open("res://qa/R3_FINAL_JOURNEY_UI_TESTS.json", FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print(JSON.stringify(report))
	if main != null and is_instance_valid(main):
		main.queue_free()
	quit(0 if passed == results.size() and results.size() == EXPECTED_TEST_COUNT else 1)


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.persistence_enabled = false
	gs.campaign_test_mode = true

	var required_game_state_methods: Array = [
		"new_game", "prepare_case_for_test", "eligible_final_lots", "grand_reserve_public_state",
		"save_payload", "profile_payload", "stage_clear_pending"
	]
	var missing_game_state: Array = []
	for method_name: String in required_game_state_methods:
		if not gs.has_method(method_name):
			missing_game_state.append(method_name)

	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await settle_ui()
	var required_main_methods: Array = [
		"show_final_lot_selection", "toggle_language", "auction_public_cue_state",
		"auction_terminal_primary_reason", "auction_reason_label", "friendly_auction_status",
		"friendly_ending_title", "stage_replay_axis_label", "stage_replay_axis_score",
		"show_postgame", "sync_public_interaction_state"
	]
	var missing_main: Array = []
	for method_name: String in required_main_methods:
		if not main.has_method(method_name):
			missing_main.append(method_name)
	var viewport_ok: bool = int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) == 1280 \
		and int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) == 720
	var api_ok: bool = missing_game_state.is_empty() and missing_main.is_empty() and viewport_ok
	record(
		"FINAL-JOURNEY-API-01",
		"Final journey exposes the required public APIs and declares the 1280x720 target",
		api_ok,
		{"missingGameState": missing_game_state, "missingMain": missing_main, "viewport1280x720": viewport_ok}
	)
	if not api_ok:
		record_blocked_remaining([
			{"id": "FINAL-JOURNEY-FINAL-KO-01", "name": "Korean final selection contract"},
			{"id": "FINAL-JOURNEY-FINAL-AUTHORITY-01", "name": "Final selection authority"},
			{"id": "FINAL-JOURNEY-FINAL-EN-01", "name": "English final selection refresh"},
			{"id": "FINAL-JOURNEY-LIVE-01", "name": "Public three-lot journey"},
			{"id": "FINAL-JOURNEY-ENDING-KO-01", "name": "Korean ending contract"},
			{"id": "FINAL-JOURNEY-ENDING-EN-01", "name": "English ending refresh"},
			{"id": "FINAL-JOURNEY-POSTGAME-KO-01", "name": "Korean postgame contract"},
			{"id": "FINAL-JOURNEY-POSTGAME-EN-01", "name": "English postgame refresh"},
			{"id": "FINAL-JOURNEY-CREDITS-01", "name": "Credits toggle authority"}
		], {"code": "BLOCKED_BY_API_GATE"})
		write_report_and_quit(main)
		return

	var fixture: Dictionary = prepare_stage_ten(gs, registry)
	var eligible_value: Variant = fixture.get("eligible", [])
	var eligible: Array = eligible_value if eligible_value is Array else []
	gs.language = "ko"
	main.language = "ko"
	main.call("show_final_lot_selection")
	await settle_ui(8)
	var initial_contract: Dictionary = final_selection_contract(main, eligible)
	var initial_copy: String = visible_copy(main)
	var initial_leaks: Array = leaked_raw_tokens(initial_copy, dynamic_artifact_tokens(eligible))
	var initial_progress_ok: bool = normalized_progress(String(initial_contract.get("progress", ""))).contains("0/3")
	record(
		"FINAL-JOURNEY-FINAL-KO-01",
		"Korean final selection is a compact six-card-maximum grid with public badges, requirement and disabled authoritative CTA",
		bool(fixture.get("ok", false)) and bool(initial_contract.get("ok", false)) and initial_progress_ok \
			and bool(initial_contract.get("beginDisabled", false)) and not String(initial_contract.get("requirement", "")).is_empty() and initial_leaks.is_empty(),
		{"fixture": fixture, "contract": initial_contract, "rawTokenLeaks": initial_leaks}
	)

	var selected_before_value: Variant = gs.campaign_state.get("grandReserve", {}).get("selectedLotIds", [])
	var selected_before: Array = selected_before_value.duplicate() if selected_before_value is Array else []
	var neutral_before: String = selection_neutral_signature(gs)
	var profile_before: String = JSON.stringify(gs.profile_payload())
	var schema_before: String = save_schema_signature(gs)
	var selection_steps: Array = []
	var expected_selected: Array = selected_before.duplicate()
	var selection_ok: bool = selected_before.is_empty()
	for index: int in range(mini(3, eligible.size())):
		var card: Node = visible_named(main, "FinalLotCard_%d" % index)
		var toggle: Node = visible_named(card, "FinalLotToggle", "Button") if card != null else null
		var toggle_was_button: bool = toggle is Button
		var expected_artifact: Dictionary = eligible[index] if eligible[index] is Dictionary else {}
		var expected_uid: String = String(expected_artifact.get("uniqueId", ""))
		if toggle_was_button:
			(toggle as Button).pressed.emit()
			await settle_ui(6)
			expected_selected.append(expected_uid)
		var actual_value: Variant = gs.campaign_state.get("grandReserve", {}).get("selectedLotIds", [])
		var actual: Array = actual_value.duplicate() if actual_value is Array else []
		var begin_step: Node = visible_named(main, "BeginGrandReserve", "Button")
		var expected_disabled: bool = index < 2
		var step_ok: bool = toggle_was_button and actual == expected_selected and begin_step is Button and bool((begin_step as Button).disabled) == expected_disabled
		selection_ok = selection_ok and step_ok
		selection_steps.append({"index": index, "expected": expected_selected.duplicate(), "actual": actual, "beginDisabled": bool((begin_step as Button).disabled) if begin_step is Button else null, "ok": step_ok})
	# Toggle the third lot off and on through the same visible card control.
	var third_card: Node = visible_named(main, "FinalLotCard_2")
	var third_toggle: Node = visible_named(third_card, "FinalLotToggle", "Button") if third_card != null else null
	var deselect_ok: bool = false
	var reselect_ok: bool = false
	if third_toggle is Button:
		(third_toggle as Button).pressed.emit()
		await settle_ui(6)
		var after_remove_value: Variant = gs.campaign_state.get("grandReserve", {}).get("selectedLotIds", [])
		var after_remove: Array = after_remove_value.duplicate() if after_remove_value is Array else []
		var begin_after_remove: Node = visible_named(main, "BeginGrandReserve", "Button")
		deselect_ok = after_remove == expected_selected.slice(0, 2) and begin_after_remove is Button and (begin_after_remove as Button).disabled
		third_card = visible_named(main, "FinalLotCard_2")
		third_toggle = visible_named(third_card, "FinalLotToggle", "Button") if third_card != null else null
		if third_toggle is Button:
			(third_toggle as Button).pressed.emit()
			await settle_ui(6)
			var after_reselect_value: Variant = gs.campaign_state.get("grandReserve", {}).get("selectedLotIds", [])
			var after_reselect: Array = after_reselect_value.duplicate() if after_reselect_value is Array else []
			var begin_after_reselect: Node = visible_named(main, "BeginGrandReserve", "Button")
			reselect_ok = after_reselect == expected_selected and begin_after_reselect is Button and not (begin_after_reselect as Button).disabled
	var selected_after_value: Variant = gs.campaign_state.get("grandReserve", {}).get("selectedLotIds", [])
	var selected_after: Array = selected_after_value.duplicate() if selected_after_value is Array else []
	var authority_ok: bool = selection_ok and deselect_ok and reselect_ok and selected_after == expected_selected \
		and selection_neutral_signature(gs) == neutral_before and JSON.stringify(gs.profile_payload()) == profile_before \
		and save_schema_signature(gs) == schema_before
	record(
		"FINAL-JOURNEY-FINAL-AUTHORITY-01",
		"Visible lot toggles mutate only the exact ordered selection, enforce three lots, and make Begin authoritative without profile or schema drift",
		authority_ok,
		{"steps": selection_steps, "deselectOk": deselect_ok, "reselectOk": reselect_ok, "selected": selected_after, "neutralMutation0": selection_neutral_signature(gs) == neutral_before, "profileMutation0": JSON.stringify(gs.profile_payload()) == profile_before, "schemaMutation0": save_schema_signature(gs) == schema_before}
	)

	main.call("sync_public_interaction_state")
	var final_refresh_before: String = stable_authority_signature(gs)
	var final_schema_before: String = save_schema_signature(gs)
	var ko_final_copy: String = visible_copy(main)
	main.call("toggle_language")
	await settle_ui(8)
	var en_contract: Dictionary = final_selection_contract(main, eligible)
	var en_final_copy: String = visible_copy(main)
	var en_final_leaks: Array = leaked_raw_tokens(en_final_copy, dynamic_artifact_tokens(eligible))
	var en_selected_value: Variant = gs.campaign_state.get("grandReserve", {}).get("selectedLotIds", [])
	var en_selected: Array = en_selected_value.duplicate() if en_selected_value is Array else []
	var final_refresh_ok: bool = String(gs.language) == "en" and String(main.language) == "en" and bool(en_contract.get("ok", false)) \
		and normalized_progress(String(en_contract.get("progress", ""))).contains("3/3") \
		and not bool(en_contract.get("beginDisabled", true)) and en_selected == expected_selected \
		and ko_final_copy != en_final_copy and en_final_leaks.is_empty() \
		and stable_authority_signature(gs) == final_refresh_before and save_schema_signature(gs) == final_schema_before
	record(
		"FINAL-JOURNEY-FINAL-EN-01",
		"English refresh preserves final-lot authority and geometry while changing only localized copy",
		final_refresh_ok,
		{"contract": en_contract, "selected": en_selected, "copyChanged": ko_final_copy != en_final_copy, "rawTokenLeaks": en_final_leaks, "stateMutation0": stable_authority_signature(gs) == final_refresh_before, "schemaMutation0": save_schema_signature(gs) == final_schema_before}
	)

	var begin_button: Node = visible_named(main, "BeginGrandReserve", "Button")
	var begin_ready: bool = begin_button is Button and not (begin_button as Button).disabled and en_selected.size() == 3
	if begin_ready:
		(begin_button as Button).pressed.emit()
		await settle_ui(8)
	var live_flow: Dictionary = await drive_live_grand_reserve_ui(main, gs) if begin_ready else {"ok": false, "code": "BEGIN_NOT_READY"}
	var ending_id: String = String(gs.campaign_state.get("currentEnding", ""))
	var journey_ok: bool = begin_ready and bool(live_flow.get("ok", false)) and String(gs.stage_run_state.get("status", "")) == "CLEARED" \
		and not ending_id.is_empty() and not bool(gs.stage_run_state.get("stageClearAcknowledged", true)) \
		and bool(gs.call("stage_clear_pending")) and String(main.screen) == "campaign" \
		and visible_named(main, "StageClearViewEnding", "Button") is Button
	record(
		"FINAL-JOURNEY-LIVE-01",
		"The visible Begin, cue, Hammer, and Next Lot controls complete exactly three lots and stop at the Stage Clear ending handoff",
		journey_ok,
		{"beginReady": begin_ready, "flow": live_flow, "stageStatus": gs.stage_run_state.get("status", ""), "ending": ending_id, "acknowledged": gs.stage_run_state.get("stageClearAcknowledged", null), "screen": main.screen}
	)
	if not journey_ok:
		record_blocked_remaining([
			{"id": "FINAL-JOURNEY-ENDING-KO-01", "name": "Korean ending contract"},
			{"id": "FINAL-JOURNEY-ENDING-EN-01", "name": "English ending refresh"},
			{"id": "FINAL-JOURNEY-POSTGAME-KO-01", "name": "Korean postgame contract"},
			{"id": "FINAL-JOURNEY-POSTGAME-EN-01", "name": "English postgame refresh"},
			{"id": "FINAL-JOURNEY-CREDITS-01", "name": "Credits toggle authority"}
		], {"code": "BLOCKED_BY_PUBLIC_JOURNEY", "journey": live_flow})
		gs.campaign_test_mode = false
		write_report_and_quit(main)
		return

	# Return to Korean while the one-time clear card is still pending, then use
	# the visible CTA so acknowledgement and ending routing share the public path.
	if String(gs.language) != "ko":
		main.call("toggle_language")
		await settle_ui(8)
	var ending_cta: Node = visible_named(main, "StageClearViewEnding", "Button")
	var ending_cta_was_button: bool = ending_cta is Button
	if ending_cta_was_button:
		(ending_cta as Button).pressed.emit()
		await settle_ui(8)
	var ending_transition_ok: bool = ending_cta_was_button and String(main.screen) == "ending" \
		and bool(gs.stage_run_state.get("stageClearAcknowledged", false)) and not bool(gs.call("stage_clear_pending"))
	var ko_ending_contract: Dictionary = ending_contract(main, gs)
	var ko_ending_copy: String = visible_copy(main)
	var ending_extra_tokens: Array = [ending_id]
	var reserve_results_value: Variant = gs.campaign_state.get("grandReserve", {}).get("results", [])
	var reserve_results: Array = reserve_results_value if reserve_results_value is Array else []
	for result_value: Variant in reserve_results:
		if result_value is Dictionary:
			var auction_value: Variant = (result_value as Dictionary).get("auction", {})
			if auction_value is Dictionary:
				for reason_value: Variant in (auction_value as Dictionary).get("reasonTags", []):
					if reason_value is Dictionary:
						ending_extra_tokens.append(String((reason_value as Dictionary).get("code", "")))
	var ko_ending_leaks: Array = leaked_raw_tokens(ko_ending_copy, ending_extra_tokens)
	record(
		"FINAL-JOURNEY-ENDING-KO-01",
		"Korean ending renders one hero, frozen three-axis summary and three authoritative lot result cards with one causal chip each",
		ending_transition_ok and bool(ko_ending_contract.get("ok", false)) and ko_ending_leaks.is_empty(),
		{"transitionOk": ending_transition_ok, "contract": ko_ending_contract, "rawTokenLeaks": ko_ending_leaks}
	)

	main.call("sync_public_interaction_state")
	var ending_refresh_before: String = stable_authority_signature(gs)
	var ending_schema_before: String = save_schema_signature(gs)
	main.call("toggle_language")
	await settle_ui(8)
	var en_ending_contract: Dictionary = ending_contract(main, gs)
	var en_ending_copy: String = visible_copy(main)
	var en_ending_leaks: Array = leaked_raw_tokens(en_ending_copy, ending_extra_tokens)
	var ending_refresh_ok: bool = String(gs.language) == "en" and String(main.language) == "en" and bool(en_ending_contract.get("ok", false)) \
		and ko_ending_copy != en_ending_copy and en_ending_leaks.is_empty() \
		and stable_authority_signature(gs) == ending_refresh_before and save_schema_signature(gs) == ending_schema_before
	record(
		"FINAL-JOURNEY-ENDING-EN-01",
		"English ending refresh keeps selected lots, ending, frozen state, profile and save schema byte-equivalent apart from locale",
		ending_refresh_ok,
		{"contract": en_ending_contract, "copyChanged": ko_ending_copy != en_ending_copy, "rawTokenLeaks": en_ending_leaks, "stateMutation0": stable_authority_signature(gs) == ending_refresh_before, "schemaMutation0": save_schema_signature(gs) == ending_schema_before}
	)

	if String(gs.language) != "ko":
		main.call("toggle_language")
		await settle_ui(8)
	var postgame_button: Node = visible_named(main, "PostgameButton", "Button")
	var postgame_button_was_button: bool = postgame_button is Button
	if postgame_button_was_button:
		(postgame_button as Button).pressed.emit()
		await settle_ui(8)
	var postgame_transition_ok: bool = postgame_button_was_button and String(main.screen) == "postgame" \
		and bool(gs.campaign_state.get("epilogueSeen", false)) and bool(gs.campaign_state.get("postGame", false))
	var ko_postgame_contract: Dictionary = postgame_contract(main, gs, registry)
	var ko_postgame_copy: String = visible_copy(main)
	var gallery_tokens: Array = campaign_ending_ids(registry)
	var ko_postgame_leaks: Array = leaked_raw_tokens(ko_postgame_copy, gallery_tokens)
	record(
		"FINAL-JOURNEY-POSTGAME-KO-01",
		"Korean postgame shows one compact hero, exact five-card ending gallery and three distinct enabled actions",
		postgame_transition_ok and bool(ko_postgame_contract.get("ok", false)) and ko_postgame_leaks.is_empty(),
		{"transitionOk": postgame_transition_ok, "contract": ko_postgame_contract, "rawTokenLeaks": ko_postgame_leaks}
	)

	main.call("sync_public_interaction_state")
	var postgame_refresh_before: String = stable_authority_signature(gs)
	var postgame_schema_before: String = save_schema_signature(gs)
	main.call("toggle_language")
	await settle_ui(8)
	var en_postgame_contract: Dictionary = postgame_contract(main, gs, registry)
	var en_postgame_copy: String = visible_copy(main)
	var en_postgame_leaks: Array = leaked_raw_tokens(en_postgame_copy, gallery_tokens)
	var postgame_refresh_ok: bool = String(gs.language) == "en" and String(main.language) == "en" and bool(en_postgame_contract.get("ok", false)) \
		and ko_postgame_copy != en_postgame_copy and en_postgame_leaks.is_empty() \
		and stable_authority_signature(gs) == postgame_refresh_before and save_schema_signature(gs) == postgame_schema_before
	record(
		"FINAL-JOURNEY-POSTGAME-EN-01",
		"English postgame refresh preserves the five-card gallery authority and all saved journey state",
		postgame_refresh_ok,
		{"contract": en_postgame_contract, "copyChanged": ko_postgame_copy != en_postgame_copy, "rawTokenLeaks": en_postgame_leaks, "stateMutation0": stable_authority_signature(gs) == postgame_refresh_before, "schemaMutation0": save_schema_signature(gs) == postgame_schema_before}
	)

	main.call("sync_public_interaction_state")
	var credits_before: String = stable_authority_signature(gs)
	var credits_schema_before: String = save_schema_signature(gs)
	var credits_initially_closed: bool = visible_named(main, "CreditsPanel") == null
	var credits_button: Node = visible_named(main, "PostgameCredits", "Button")
	var credits_button_was_button: bool = credits_button is Button
	if credits_button_was_button:
		(credits_button as Button).pressed.emit()
		await settle_ui(6)
	var credits_panel: Node = visible_named(main, "CreditsPanel")
	var credits_rect: Dictionary = rect_evidence(credits_panel)
	var credits_open_ok: bool = credits_panel is Control and bool(credits_rect.get("inside1280x720", false)) and not visible_copy(credits_panel).strip_edges().is_empty()
	credits_button = visible_named(main, "PostgameCredits", "Button")
	var credits_close_button_was_button: bool = credits_button is Button
	if credits_close_button_was_button:
		(credits_button as Button).pressed.emit()
		await settle_ui(6)
	var credits_closed_again: bool = visible_named(main, "CreditsPanel") == null
	var selected_final_value: Variant = gs.campaign_state.get("grandReserve", {}).get("selectedLotIds", [])
	var selected_final: Array = selected_final_value.duplicate() if selected_final_value is Array else []
	var credits_mutation0: bool = stable_authority_signature(gs) == credits_before and save_schema_signature(gs) == credits_schema_before \
		and selected_final == expected_selected and String(gs.campaign_state.get("currentEnding", "")) == ending_id \
		and bool(gs.campaign_state.get("postGame", false)) and bool(gs.stage_run_state.get("stageClearAcknowledged", false))
	record(
		"FINAL-JOURNEY-CREDITS-01",
		"Credits toggles one bounded panel twice while postgame CTAs and selected-lot, ending, state, profile and save-schema authority remain unchanged",
		credits_initially_closed and credits_button_was_button and credits_close_button_was_button and credits_open_ok and credits_closed_again and credits_mutation0 \
			and visible_named(main, "PostgameStageSelect", "Button") is Button and visible_named(main, "PostgameNewGame", "Button") is Button,
		{"initiallyClosed": credits_initially_closed, "openOk": credits_open_ok, "closedAgain": credits_closed_again, "stateMutation0": stable_authority_signature(gs) == credits_before, "schemaMutation0": save_schema_signature(gs) == credits_schema_before, "selected": selected_final, "ending": gs.campaign_state.get("currentEnding", ""), "stageStatus": gs.stage_run_state.get("status", ""), "creditsRect": credits_rect}
	)

	gs.campaign_test_mode = false
	gs.persistence_enabled = false
	write_report_and_quit(main)
