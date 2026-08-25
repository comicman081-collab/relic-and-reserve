extends SceneTree

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func visible_copy(root: Node) -> String:
	var copy := ""
	for label: Label in root.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			copy += label.text + "\n"
	for button: Button in root.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			copy += button.text + "\n"
	return copy


func result_fingerprint(result: Dictionary) -> Dictionary:
	return {
		"hammer": int(result.get("hammer", 0)),
		"reserveMet": bool(result.get("reserve_met", false)),
		"bids": result.get("bids", []).map(func(bid: Dictionary): return int(bid.get("amount", 0))),
		"reasons": result.get("reasonTags", []).map(func(tag: Dictionary): return tag.get("code", ""))
	}


func begin_listing(main: Node3D, artifact: Dictionary) -> void:
	var gs: Node = main.get_tree().root.get_node("GameState")
	if not gs.inventory.has(artifact):
		gs.inventory.append(artifact)
	main.selected = artifact
	main.load_artifact(artifact)
	main.listing_artifact_id = ""
	main.listing_step = "PRICE"
	main.listing_price_preset = ""
	main.listing_disclosure = ""
	main.show_appraisal()


func choose_and_confirm(main: Node3D, preset_id: String, disclosure_id: String) -> Dictionary:
	var price_button: Button = main.find_child("ListingPrice_%s" % preset_id, true, false)
	price_button.pressed.emit()
	await process_frame
	var disclosure_button: Button = main.find_child("ListingDisclosure_%s" % disclosure_id, true, false)
	disclosure_button.pressed.emit()
	await process_frame
	var confirm_button: Button = main.find_child("ListingConfirmButton", true, false)
	confirm_button.pressed.emit()
	await process_frame
	return main.last_auction_result.duplicate(true)


func commit_and_remove_fixture(gs: Node, artifact: Dictionary) -> void:
	var pending: Dictionary = gs.pending_auction_public_state()
	if bool(pending.get("ok", false)) and String(pending.get("status", "")) == "PENDING":
		gs.commit_pending_auction(String(pending.get("transactionId", "")))
	if gs.inventory.has(artifact):
		gs.inventory.erase(artifact)


func advance_auction_to_final(main: Node3D) -> void:
	for _step in range(16):
		var cue: Dictionary = main.auction_public_cue_state()
		if cue.is_empty() or bool(cue.get("isFinal", false)):
			return
		main.advance_auction_cue()
		await process_frame


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	gs.reset_game()
	gs.persistence_enabled = false
	gs.language = "ko"
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.language = "ko"

	var base_artifact: Dictionary = gs.new_artifact("artifact_001", 515151, "listing_ui_same_seed")
	base_artifact.playerHypothesis = gs.truth_to_hypothesis(base_artifact.authenticityTruth)
	base_artifact.confidence = 0.92
	base_artifact.cleanliness = 100.0
	base_artifact.surfaceCondition = 100.0
	base_artifact.mechanicalCondition = 100.0
	base_artifact.knownClues = []
	begin_listing(main, base_artifact)
	await process_frame
	var appraised_value: int = int(gs.appraise(base_artifact))
	var price_buttons: Array = main.find_children("ListingPrice_*", "Button", true, false)
	var material_badges: Array = main.find_children("ListingMaterialBadge_*", "PanelContainer", true, false)
	var first_copy := visible_copy(main)
	var expected_fast: Dictionary = main.listing_prices(appraised_value, "FAST")
	var expected_balanced: Dictionary = main.listing_prices(appraised_value, "BALANCED")
	var expected_high: Dictionary = main.listing_prices(appraised_value, "HIGH")
	record(
		"MVP-LISTING-UI-01",
		"Step 1 shows exactly three illustrated fixed-ratio price cards and only public condition, investigation and provenance badges",
		price_buttons.size() == 3 and material_badges.size() == 3 and main.find_child("ListAuctionButton", true, false) == null and first_copy.contains("빠른 판매") and first_copy.contains("시작 ¤%d · 예약 ¤%d" % [int(expected_fast.starting), int(expected_fast.reserve)]) and first_copy.contains("균형 판매") and first_copy.contains("시작 ¤%d · 예약 ¤%d" % [int(expected_balanced.starting), int(expected_balanced.reserve)]) and first_copy.contains("높은 목표") and first_copy.contains("시작 ¤%d · 예약 ¤%d" % [int(expected_high.starting), int(expected_high.reserve)]) and first_copy.contains("상태 정보 충분") and first_copy.contains("조사 정보 충분") and first_copy.contains("출처 불확실") and not first_copy.contains("auctionProfile") and not first_copy.contains("reserveStrategy"),
		{"appraisal": appraised_value, "buttons": price_buttons.map(func(button: Button): return button.text), "badges": material_badges.size(), "expected": {"fast": expected_fast, "balanced": expected_balanced, "high": expected_high}}
	)

	var fast_button: Button = main.find_child("ListingPrice_FAST", true, false)
	fast_button.pressed.emit()
	await process_frame
	var disclosure_buttons: Array = main.find_children("ListingDisclosure_*", "Button", true, false)
	var support_badges: Array = main.find_children("ListingPublicSupportBadge", "PanelContainer", true, false)
	var support_label: Label = main.find_child("ListingPublicSupportLabel", true, false)
	var initial_confirm: Button = main.find_child("ListingConfirmButton", true, false)
	var back_button: Button = main.find_child("ListingBackToPrice", true, false)
	var disclosure_copy := visible_copy(main)
	var disclosure_button_texts: Array = disclosure_buttons.map(func(button: Button): return button.text)
	var initial_confirm_disabled: bool = initial_confirm != null and initial_confirm.disabled
	var public_support: Dictionary = gs.listing_public_support(base_artifact)
	var expected_support_copy := "공개 근거 · %s" % main.listing_support_band_label(String(public_support.get("band", "LOW")))
	var support_label_copy := support_label.text if support_label != null else ""
	var expected_disclosure_copy: Array = []
	for disclosure_id: String in ["CERTAIN", "LIKELY", "UNCERTAIN"]:
		var disclosure_support: Dictionary = gs.listing_public_support(base_artifact, disclosure_id)
		expected_disclosure_copy.append("%s\n%s" % [main.listing_disclosure_label(disclosure_id), main.listing_disclosure_risk_label(String(disclosure_support.get("risk", "BALANCED")))])
	var misleading_evidence_labels_hidden := ["Evidence confirmed", "Evidence available", "Information limited", "확인 자료 충분", "확인 자료 있음", "정보 제한적"].all(func(copy: String): return not disclosure_copy.contains(copy))
	var raw_calibration_hidden := ["CERTAIN", "LIKELY", "UNCERTAIN", "OVERCLAIM", "UNDERCLAIM", "MEDIUM", "auctionProfile", "authenticityTruth"].all(func(copy: String): return not disclosure_copy.contains(copy))
	var step_two_initial_valid: bool = main.find_children("ListingPrice_*", "Button", true, false).is_empty() \
		and disclosure_buttons.size() == 3 \
		and support_badges.size() == 1 \
		and support_label != null \
		and support_label_copy == expected_support_copy \
		and initial_confirm != null \
		and initial_confirm.disabled \
		and back_button != null \
		and disclosure_button_texts == expected_disclosure_copy \
		and disclosure_button_texts.all(func(copy: String): return copy.count("\n") == 1) \
		and misleading_evidence_labels_hidden \
		and raw_calibration_hidden
	var certain_button: Button = main.find_child("ListingDisclosure_CERTAIN", true, false)
	certain_button.pressed.emit()
	await process_frame
	var ready_confirm: Button = main.find_child("ListingConfirmButton", true, false)
	var summary_tile: PanelContainer = main.find_child("ListingSummaryTile", true, false)
	var summary_copy := visible_copy(main)
	record(
		"MVP-LISTING-UI-02",
		"Step 2 separates one public support band from three claim-strength choices, gives each a calibrated risk hint, and keeps one final confirmation action",
		step_two_initial_valid and ready_confirm != null and not ready_confirm.disabled and summary_tile != null and summary_copy.contains("빠른 판매") and summary_copy.contains("단정적 주장") and summary_copy.contains(main.listing_disclosure_risk_label(String(gs.listing_public_support(base_artifact, "CERTAIN").get("risk", "BALANCED")))) and summary_copy.contains("출품 확정") and summary_copy.contains("← 가격 변경"),
		{"support": public_support, "supportCopy": support_label_copy, "disclosures": disclosure_button_texts, "expectedDisclosures": expected_disclosure_copy, "misleadingEvidenceLabelsHidden": misleading_evidence_labels_hidden, "rawCalibrationHidden": raw_calibration_hidden, "initialConfirmDisabled": initial_confirm_disabled, "summary": summary_copy}
	)

	ready_confirm.pressed.emit()
	await process_frame
	var fast_certain_listing: Dictionary = base_artifact.listing.duplicate(true)
	var fast_certain_result: Dictionary = main.last_auction_result.duplicate(true)
	var fast_exact: bool = int(fast_certain_listing.get("starting", -1)) == int(float(appraised_value) * 0.50) and int(fast_certain_listing.get("reserve", -1)) == int(float(appraised_value) * 0.60) and int(fast_certain_listing.get("publicAppraisal", -1)) == appraised_value and float(fast_certain_listing.get("confidence", -1.0)) == float(base_artifact.confidence) and fast_certain_listing.get("disclosure", "") == "CERTAIN"
	commit_and_remove_fixture(gs, base_artifact)

	var high_artifact: Dictionary = base_artifact.duplicate(true)
	high_artifact.erase("listing")
	high_artifact.sold = false
	begin_listing(main, high_artifact)
	await process_frame
	var high_certain_result: Dictionary = await choose_and_confirm(main, "HIGH", "CERTAIN")
	var high_certain_listing: Dictionary = high_artifact.listing.duplicate(true)
	var high_exact: bool = int(high_certain_listing.get("starting", -1)) == int(float(appraised_value) * 0.68) and int(high_certain_listing.get("reserve", -1)) == int(float(appraised_value) * 0.82) and int(high_certain_listing.get("publicAppraisal", -1)) == appraised_value and high_certain_listing.get("disclosure", "") == "CERTAIN"
	commit_and_remove_fixture(gs, high_artifact)

	var fast_uncertain_artifact: Dictionary = base_artifact.duplicate(true)
	fast_uncertain_artifact.erase("listing")
	fast_uncertain_artifact.sold = false
	begin_listing(main, fast_uncertain_artifact)
	await process_frame
	var fast_uncertain_result: Dictionary = await choose_and_confirm(main, "FAST", "UNCERTAIN")
	var fast_uncertain_listing: Dictionary = fast_uncertain_artifact.listing.duplicate(true)
	var disclosure_exact: bool = int(fast_uncertain_listing.get("starting", -1)) == int(float(appraised_value) * 0.50) and int(fast_uncertain_listing.get("reserve", -1)) == int(float(appraised_value) * 0.60) and int(fast_uncertain_listing.get("publicAppraisal", -1)) == appraised_value and fast_uncertain_listing.get("disclosure", "") == "UNCERTAIN"
	commit_and_remove_fixture(gs, fast_uncertain_artifact)

	var fast_fingerprint := result_fingerprint(fast_certain_result)
	var high_fingerprint := result_fingerprint(high_certain_result)
	var uncertain_fingerprint := result_fingerprint(fast_uncertain_result)
	record(
		"MVP-LISTING-UI-03",
		"Confirmation freezes the appraisal shown on the price cards, passes exact preset prices and disclosure to GameState, and produces visible auction changes for FAST versus HIGH and CERTAIN versus UNCERTAIN",
		fast_exact and high_exact and disclosure_exact and fast_fingerprint != high_fingerprint and fast_fingerprint != uncertain_fingerprint and base_artifact.uniqueId == high_artifact.uniqueId and base_artifact.uniqueId == fast_uncertain_artifact.uniqueId,
		{"sameUniqueId": base_artifact.uniqueId, "appraisal": appraised_value, "fastCertain": {"listing": fast_certain_listing, "result": fast_fingerprint}, "highCertain": {"listing": high_certain_listing, "result": high_fingerprint}, "fastUncertain": {"listing": fast_uncertain_listing, "result": uncertain_fingerprint}}
	)

	var no_bid_artifact: Dictionary = base_artifact.duplicate(true)
	no_bid_artifact.uniqueId = "listing_ui_no_bid"
	no_bid_artifact.sold = false
	no_bid_artifact.listing = {"starting": 999999, "reserve": 1000000, "confidence": float(no_bid_artifact.confidence), "disclosure": "LIKELY"}
	gs.inventory.append(no_bid_artifact)
	main.selected = no_bid_artifact
	main.load_artifact(no_bid_artifact)
	main.reset_auction_cue_sequence()
	main.show_auction()
	await process_frame
	await advance_auction_to_final(main)
	var opening_tile: Label = main.find_child("CaseTileSummary_objective", true, false)
	var bid_count_tile: Label = main.find_child("CaseTileSummary_report", true, false)
	var primary_state: PanelContainer = main.find_child("AuctionPrimaryState", true, false)
	var primary_text: Label = main.find_child("AuctionPrimaryText", true, false)
	var primary_action: VBoxContainer = main.find_child("AuctionPrimaryAction", true, false)
	var hammer_action: Button = main.find_child("HammerButton", true, false)
	var no_bid_fact: Label = main.find_child("AuctionResultFact", true, false)
	var no_bid_copy := visible_copy(main)
	var final_cue: Dictionary = main.auction_public_cue_state()
	var primary_public: Dictionary = main.auction_primary_public_state(final_cue)
	var no_bid_contract: bool = main.last_auction_result.get("bids", []).is_empty() \
		and String(main.last_auction_result.get("winnerId", "")).is_empty() \
		and int(main.last_auction_result.get("opening", 0)) == 999999 \
		and int(main.last_auction_result.get("hammer", -1)) == 0 \
		and main.last_auction_result.get("sale_status", "") == "NO_SALE"
	var authoritative_primary: bool = String(final_cue.get("phase", "")) == "NO_SALE" \
		and bool(final_cue.get("isFinal", false)) \
		and bool(primary_public.get("terminal", false)) \
		and String(primary_public.get("phase", "")) == "NO_SALE" \
		and int(primary_public.get("amount", -1)) == int(main.last_auction_result.get("hammer", -2)) \
		and primary_text != null \
		and primary_text.text == String(primary_public.get("text", "")) \
		and primary_text.text.contains("유찰") \
		and primary_text.text.contains("공개 입찰 없음")
	record(
		"MVP-LISTING-UI-04",
		"A no-bid auction preserves the opening term and renders its authoritative no-sale amount through the primary state and action",
		no_bid_contract and authoritative_primary and primary_state != null and primary_action != null and hammer_action != null and hammer_action.get_parent() == primary_action and opening_tile != null and opening_tile.text == "¤999999" and bid_count_tile != null and bid_count_tile.text == "0" and no_bid_fact != null and no_bid_fact.text.contains("유찰") and no_bid_fact.text.contains("정산액 ¤0") and no_bid_copy.contains("유찰") and not no_bid_copy.contains("NO_SALE"),
		{"result": result_fingerprint(main.last_auction_result), "opening": main.last_auction_result.get("opening", -1), "winner": main.last_auction_result.get("winnerId", ""), "cue": final_cue, "primary": primary_public, "primaryText": primary_text.text if primary_text != null else "", "primaryState": primary_state != null, "primaryAction": primary_action != null, "action": String(hammer_action.name) if hammer_action != null else "", "openingTile": opening_tile.text if opening_tile != null else "", "bidCountTile": bid_count_tile.text if bid_count_tile != null else "", "fact": no_bid_fact.text if no_bid_fact != null else ""}
	)

	var passed := results.filter(func(result: Dictionary): return bool(result.passed)).size()
	var report := {"suite": "R3 Two-Step Listing UI", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "skipped": 0, "tests": results}
	var output := FileAccess.open("res://qa/R3_LISTING_UI_TESTS.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	main.queue_free()
	quit(0 if passed == results.size() else 1)
