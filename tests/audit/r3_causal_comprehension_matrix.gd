extends SceneTree

## Audit-only Stage 1/5/8/10 causal presentation matrix.
##
## This deliberately does not tune auction numbers or mutate production data.
## It records whether the public listing facts, frozen auction result, terminal
## reason chip, and compact action surface agree at representative stages. The
## final human-comprehension gate remains explicitly unobserved here.

const REPORT_PATH := "res://qa/R3_CAUSAL_COMPREHENSION_MATRIX.json"
const STAGE_FIXTURES := {
	1: "artifact_061",
	5: "artifact_069",
	8: "artifact_075",
	10: "artifact_079"
}
const PUBLIC_REASON_CODES := [
	"RESERVE_TOO_HIGH", "PROVENANCE_UNCERTAIN", "PROVENANCE_STRONG",
	"CONDITION_RISK", "CONDITION_GOOD", "DISCLOSURE_UNCLEAR",
	"DISCLOSURE_CLEAR", "RESERVE_MET", "NO_PUBLIC_BID"
]
const PRIVATE_TOKENS := ["authenticityTruth", "trueRarity", "trueMarketBaseline", "maxBid", "variance", "bidderId", "reasonTags"]

var rows: Array = []


func _init() -> void:
	call_deferred("run")


func visible_copy(root: Node) -> String:
	var fragments: Array[String] = []
	for label: Label in root.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			fragments.append(label.text)
	for button: Button in root.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			fragments.append(button.text)
	return "\n".join(fragments)


func reason_tags_valid(tags_value: Variant) -> bool:
	if not tags_value is Array:
		return false
	var tags: Array = tags_value
	if tags.size() > 2:
		return false
	for tag_value: Variant in tags:
		if not tag_value is Dictionary:
			return false
		var tag: Dictionary = tag_value
		var keys: Array = tag.keys()
		keys.sort()
		if keys != ["category", "code", "polarity"]:
			return false
		if not PUBLIC_REASON_CODES.has(String(tag.get("code", ""))):
			return false
		if not ["PRICE", "PROVENANCE", "CONDITION", "DISCLOSURE"].has(String(tag.get("category", ""))):
			return false
		if not ["POSITIVE", "NEGATIVE", "NEUTRAL"].has(String(tag.get("polarity", ""))):
			return false
	return true


func first_reason_code(tags_value: Variant) -> String:
	if not tags_value is Array:
		return ""
	for tag_value: Variant in tags_value:
		if tag_value is Dictionary and PUBLIC_REASON_CODES.has(String(tag_value.get("code", ""))):
			return String(tag_value.get("code", ""))
	return ""


func action_hint_for_reason(code: String) -> String:
	match code:
		"RESERVE_TOO_HIGH", "NO_PUBLIC_BID":
			return "PRICE_OR_DISCLOSURE"
		"PROVENANCE_UNCERTAIN":
			return "INVESTIGATE_OR_CITE"
		"PROVENANCE_STRONG":
			return "KEEP_CITATION"
		"CONDITION_RISK":
			return "REPAIR_OR_PRESERVE"
		"CONDITION_GOOD":
			return "PRESERVE"
		"DISCLOSURE_UNCLEAR":
			return "ADJUST_DISCLOSURE"
		"DISCLOSURE_CLEAR":
			return "KEEP_DISCLOSURE"
		"RESERVE_MET":
			return "KEEP_PRICE"
	return "UNMAPPED"


func vocabulary_alignment_probe(main: Node3D) -> Dictionary:
	var feedback := {
		"weakest": "sale",
		"adviceCode": "IMPROVE_SALE",
		"axes": {"sale": {"available": true, "value": 50.0}}
	}
	main.language = "ko"
	var ko_advice: String = main.stage_replay_advice(feedback)
	main.language = "en"
	var en_advice: String = main.stage_replay_advice(feedback)
	main.language = "ko"
	var ko_uses_reason_term: bool = ko_advice.contains("예약가")
	var ko_uses_legacy_term: bool = ko_advice.contains("보류가")
	return {
		"koAdvice": ko_advice,
		"enAdvice": en_advice,
		"auctionChipKo": main.auction_reason_label("RESERVE_TOO_HIGH"),
		"koUsesSameReserveTerm": ko_uses_reason_term,
		"koUsesLegacyReserveTerm": ko_uses_legacy_term,
		"status": "P1_DESIGN_DEBT" if ko_uses_legacy_term or not ko_uses_reason_term else "ALIGNED"
	}


func fixture(gs: Node, stage_id: int, mode: String) -> Dictionary:
	var spec_id: String = String(STAGE_FIXTURES.get(stage_id, "artifact_001"))
	var unique_id := "causal_stage_%02d_%s" % [stage_id, mode]
	var artifact: Dictionary = gs.new_artifact(spec_id, 930000 + stage_id * 10 + (1 if mode == "sold" else 2), unique_id)
	if artifact.is_empty():
		return {}
	artifact.playerHypothesis = gs.truth_to_hypothesis(String(artifact.get("authenticityTruth", "UNKNOWN")))
	if mode == "sold":
		artifact.confidence = 0.92
		artifact.cleanliness = 100.0
		artifact.surfaceCondition = 100.0
		artifact.mechanicalCondition = 100.0
		artifact.knownClues = ["PROVENANCE"]
		artifact.listing = {"starting": 1, "reserve": 1, "confidence": 0.92, "disclosure": "LIKELY"}
	else:
		artifact.confidence = 0.28
		artifact.cleanliness = 30.0
		artifact.surfaceCondition = 38.0
		artifact.mechanicalCondition = 34.0
		artifact.knownClues = []
		artifact.listing = {"starting": 999999, "reserve": 1000000, "confidence": 0.28, "disclosure": "CERTAIN"}
	gs.inventory.append(artifact)
	var appraisal: int = int(gs.appraise(artifact))
	var listed: bool = gs.list_auction(artifact, int(artifact.listing.starting), int(artifact.listing.reserve), float(artifact.listing.confidence), String(artifact.listing.disclosure), appraisal)
	if not listed:
		return {}
	return artifact


func prepare_stage(gs: Node, stage_id: int) -> Dictionary:
	gs.player_profile = gs.default_player_profile()
	gs.player_profile.highestUnlockedStage = 10
	gs.player_profile.clearedStages = range(1, 10)
	var started: Dictionary = gs.new_game(stage_id)
	return {"started": bool(started.get("ok", false)), "actualStage": int(gs.current_stage), "difficulty": float(gs.stage_difficulty_multiplier())}


func capture_listing(main: Node3D, artifact: Dictionary) -> Dictionary:
	main.selected = artifact
	main.load_artifact(artifact)
	main.listing_artifact_id = ""
	main.listing_step = "PRICE"
	main.listing_price_preset = "BALANCED"
	main.listing_disclosure = ""
	main.show_appraisal()
	await process_frame
	# Use the same two public selection transitions as the player. This keeps
	# the causal chips in the disclosure step rather than forcing a hidden state.
	main.select_listing_price_preset("BALANCED")
	await process_frame
	main.select_listing_disclosure("LIKELY")
	await process_frame
	var copy := visible_copy(main)
	var causal_chips: Array = main.find_children("ListingCausalChip_*", "PanelContainer", true, false)
	var labels: Array[String] = []
	for chip_value: Variant in causal_chips:
		var chip: PanelContainer = chip_value
		var label: Label = chip.find_child("ListingCausalLabel", true, false)
		if label != null:
			labels.append(label.text)
	var raw_hidden := true
	for token: String in PRIVATE_TOKENS:
		raw_hidden = raw_hidden and not copy.contains(token)
	return {
		"chipCount": causal_chips.size(),
		"labels": labels,
		"publicSummaryPresent": causal_chips.size() == 3,
		"rawPrivateFieldsHidden": raw_hidden,
		"visibleCopy": copy
	}


func capture_auction(main: Node3D) -> Dictionary:
	main.reset_auction_cue_sequence()
	main.show_auction()
	await process_frame
	var initial_copy := visible_copy(main)
	var phases: Array[String] = []
	var max_inflight_chips := 0
	for _step in range(20):
		var cue: Dictionary = main.auction_public_cue_state()
		if cue.is_empty():
			break
		var phase := String(cue.get("phase", ""))
		phases.append(phase)
		var inflight: int = main.find_children("AuctionReasonChip_*", "PanelContainer", true, false).size()
		max_inflight_chips = maxi(max_inflight_chips, inflight)
		if bool(cue.get("isFinal", false)):
			break
		main.advance_auction_cue()
		await process_frame
	var final_copy := visible_copy(main)
	var final_cue: Dictionary = main.auction_public_cue_state()
	var result: Dictionary = main.last_auction_result.duplicate(true)
	var tags: Array = result.get("reasonTags", []).duplicate(true)
	var terminal_reason: Dictionary = main.auction_terminal_primary_reason(result)
	var terminal_code := String(terminal_reason.get("code", ""))
	var terminal_label: String = main.auction_reason_label(terminal_code)
	var terminal_chips: int = main.find_children("AuctionReasonChip_*", "PanelContainer", true, false).size()
	var primary_state: Node = main.find_child("AuctionPrimaryState", true, false)
	var primary_action: Node = main.find_child("AuctionPrimaryAction", true, false)
	var bidder_column: Node = main.find_child("AuctionBidderColumn", true, false)
	var auctioneer_panel: Node = main.find_child("PortraitDialoguePanel_auctioneer", true, false)
	var hierarchy_ok := primary_state != null and primary_action != null and bidder_column != null and auctioneer_panel != null and terminal_chips == 1
	var label_present: bool = not terminal_label.is_empty() and final_copy.contains(terminal_label)
	var raw_hidden := true
	for token: String in PRIVATE_TOKENS:
		raw_hidden = raw_hidden and not final_copy.contains(token)
	return {
		"phases": phases,
		"finalPhase": String(final_cue.get("phase", "")),
		"saleStatus": String(result.get("sale_status", "")),
		"reasonTags": tags,
		"reasonTagsValid": reason_tags_valid(tags),
		"terminalReason": terminal_reason,
		"terminalCode": terminal_code,
		"terminalLabel": terminal_label,
		"terminalChipCount": terminal_chips,
		"maxInflightChipCount": max_inflight_chips,
		"terminalLabelPresent": label_present,
		"hierarchyPresent": hierarchy_ok,
		"primaryStateText": String(main.find_child("AuctionPrimaryText", true, false).text) if main.find_child("AuctionPrimaryText", true, false) != null else "",
		"rawPrivateFieldsHidden": raw_hidden,
		"initialVisibleCopy": initial_copy,
		"finalVisibleCopy": final_copy,
		"actionHint": action_hint_for_reason(terminal_code)
	}


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	gs.campaign_test_mode = true
	gs.persistence_enabled = false
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	var stage_order: Array[int] = [1, 5, 8, 10]
	for stage_id: int in stage_order:
		var stage_setup: Dictionary = prepare_stage(gs, stage_id)
		for mode: String in ["sold", "no_sale"]:
			var artifact: Dictionary = fixture(gs, stage_id, mode)
			var listing: Dictionary = {}
			if not artifact.is_empty():
				listing = await capture_listing(main, artifact)
				main.selected = artifact
				main.load_artifact(artifact)
			var auction: Dictionary = await capture_auction(main) if not artifact.is_empty() else {}
			var expected_status := "SOLD" if mode == "sold" else "NO_SALE"
			var first_code := first_reason_code(auction.get("reasonTags", []))
			var row_passed: bool = bool(stage_setup.get("started", false)) \
				and int(stage_setup.get("actualStage", 0)) == stage_id \
				and not artifact.is_empty() \
				and bool(listing.get("publicSummaryPresent", false)) \
				and bool(listing.get("rawPrivateFieldsHidden", false)) \
				and String(auction.get("saleStatus", "")) == expected_status \
				and bool(auction.get("reasonTagsValid", false)) \
				and not first_code.is_empty() \
				and String(auction.get("terminalCode", "")) == first_code \
				and bool(auction.get("terminalLabelPresent", false)) \
				and bool(auction.get("hierarchyPresent", false)) \
				and int(auction.get("maxInflightChipCount", 0)) <= 2 \
				and bool(auction.get("rawPrivateFieldsHidden", false))
			rows.append({
				"stage": stage_id,
				"fixture": mode,
				"passed": row_passed,
				"stageSetup": stage_setup,
				"artifactSpec": String(artifact.get("artifactSpecId", "")),
				"listing": listing,
				"auction": auction,
				"humanObserved": false,
				"humanPass": false,
				"requiresHumanCausalQuestions": [
					"Why did the bidder enter or drop?",
					"What was the biggest reason for SOLD/NO_SALE?",
					"What will you change next: investigation, repair, disclosure, or price?"
				]
			})
			# The next stage setup resets transient inventory/pending state. No sale
			# is intentionally left uncommitted: this is presentation-only audit data.
			gs.pending_auction = gs.default_pending_auction()
			gs.inventory.clear()
	var structural_passed := rows.all(func(row: Dictionary): return bool(row.get("passed", false)))
	var structural_passed_count: int = 0
	for row: Dictionary in rows:
		if bool(row.get("passed", false)):
			structural_passed_count += 1
	var report := {
		"suite": "R3 Stage 1/5/8/10 causal comprehension matrix",
		"executed": rows.size(),
		"passed": structural_passed_count,
		"failed": rows.size() - structural_passed_count,
		"structuralPass": structural_passed,
		"humanObserved": false,
		"humanPass": false,
		"humanGate": "REQUIRED",
		"vocabularyAudit": vocabulary_alignment_probe(main),
		"target": "At least 70% of human participants match the frozen primary reason category and next-action category at Stages 1/5/8/10.",
		"frozenDesignInputs": ["pow(1.07, stage-1)", "auction coefficients", "bidder AI", "listing presets"],
		"rows": rows
	}
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print(JSON.stringify(report))
	main.queue_free()
	quit(0 if structural_passed else 1)
