extends SceneTree

const AUCTION_STATES := ["INTRO", "CALL", "SOLD", "NO_SALE"]
const BIDDER_STATES := ["WATCH", "BID", "DROPOUT", "WON"]
const SHOP_STATES := ["WELCOME", "OFFER", "PURCHASE_OK", "PURCHASE_FAIL"]
const EVENT_STATES := ["REQUEST", "REACTION_POS", "REACTION_NEG"]

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func labels_named(root: Node, node_name: String) -> Array:
	return root.find_children(node_name, "Label", true, false)


func panels(root: Node) -> Array:
	return root.find_children("PortraitDialoguePanel*", "PanelContainer", true, false)


func visible_copy(root: Node) -> String:
	var copy := ""
	for label: Label in root.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			copy += label.text + "\n"
	for button: Button in root.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			copy += button.text + "\n"
	return copy


func unique_count(values: Array) -> int:
	var seen := {}
	for value: Variant in values:
		seen[value] = true
	return seen.size()


func advance_auction_to_final(main: Node3D) -> void:
	for _step in range(16):
		var cue: Dictionary = main.auction_public_cue_state()
		if cue.is_empty() or bool(cue.get("isFinal", false)):
			return
		main.advance_auction_cue()
		await process_frame


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.reset_game()
	gs.persistence_enabled = false
	gs.language = "ko"
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.language = "ko"
	var catalog: Dictionary = main.load_character_catalog()
	var profiles: Array = catalog.get("profiles", [])
	var character_ids: Array = profiles.map(func(profile: Dictionary): return profile.get("characterId", ""))
	var portrait_paths: Array = profiles.map(func(profile: Dictionary): return profile.get("portraitAssetId", ""))
	var portraits_load := portrait_paths.all(func(path: String): return ResourceLoader.exists(path) and load(path) is Texture2D)
	record(
		"MVP-PORTRAIT-UI-01",
		"CharacterProfile catalog exposes exactly 18 unique loadable base bust portraits",
		profiles.size() == 18 and unique_count(character_ids) == 18 and portraits_load,
		{"profiles": profiles.size(), "characters": character_ids, "loadable": portraits_load}
	)

	var cue_checks: Array = []
	for cue_state: String in AUCTION_STATES:
		cue_checks.append(main.character_cue("auctioneer", cue_state))
	for cue_state: String in BIDDER_STATES:
		cue_checks.append(main.character_cue("bidder_01", cue_state))
	for cue_state: String in SHOP_STATES:
		cue_checks.append(main.character_cue("shopkeeper", cue_state))
	var event_character := ""
	for profile: Dictionary in profiles:
		if String(profile.get("characterId", "")).begins_with("event_"):
			event_character = profile.characterId
			break
	for cue_state: String in EVENT_STATES:
		cue_checks.append(main.character_cue(event_character, cue_state))
	var all_cues_valid := cue_checks.size() == 15 and cue_checks.all(func(cue: Dictionary): return not cue.is_empty() and cue.get("expression", "") in ["NEUTRAL", "POSITIVE", "NEGATIVE"] and String(cue.get("dialogue", "")).length() <= 44)
	record(
		"MVP-PORTRAIT-UI-02",
		"CharacterCue normalizes all 15 semantic states to three expressions with a 44-character dialogue hard cap",
		all_cues_valid,
		{"cueCount": cue_checks.size(), "valid": all_cues_valid, "states": AUCTION_STATES + BIDDER_STATES + SHOP_STATES + EVENT_STATES}
	)

	var profile_identity: Dictionary = main.character_profile("bidder_01")
	var stage_samples: Array = []
	for stage_id: int in [1, 5, 9]:
		gs.current_stage = stage_id
		stage_samples.append(main.character_cue("bidder_01", "WATCH"))
	var identity_fixed := stage_samples.all(func(cue: Dictionary): return cue.get("profile", {}).get("portraitAssetId", "") == profile_identity.get("portraitAssetId", ""))
	var bands := stage_samples.map(func(cue: Dictionary): return cue.get("stageBand", ""))
	var accents := stage_samples.map(func(cue: Dictionary): return cue.get("accent", Color.BLACK).to_html())
	record(
		"MVP-PORTRAIT-UI-03",
		"EARLY, MID, and LATE stage bands vary deterministic accent/accessory metadata without changing identity",
		identity_fixed and bands == ["EARLY", "MID", "LATE"] and unique_count(accents) == 3,
		{"bands": bands, "accents": accents, "identityFixed": identity_fixed}
	)

	gs.player_profile.highestUnlockedStage = 2
	gs.player_profile.clearedStages = [1]
	main.show_stage_select()
	await process_frame
	var stage_buttons: Array = []
	for candidate: Node in main.find_children("StageSelect_*", "Button", true, false):
		stage_buttons.append(candidate)
	var enabled_stages := stage_buttons.filter(func(button: Button): return not button.disabled).size()
	var stage_tooltips_valid := stage_buttons.all(func(button: Button): return button.tooltip_text.contains("권장 기준이며 클리어·해금을 막지 않습니다.") and not button.tooltip_text.contains("public_stage_score"))
	record(
		"MVP-STAGE-UI-01",
		"New Game stage selector enables cleared replays only, keeps future stages in the main journey, and shows advisory recommendations",
		stage_buttons.size() == 10 and enabled_stages == 1 and stage_buttons[0].text.contains("스테이지 1 · 클리어") and stage_buttons[0].text.contains("권장 55 · BEST 성장 중 0") and stage_buttons[1].text.contains("스테이지 2 · 본편 잠김") and stage_buttons[1].text.contains("권장 56 · 첫 도전") and stage_buttons[9].text.contains("스테이지 10 · 본편 잠김") and stage_buttons[9].text.contains("권장 64 · 첫 도전") and stage_tooltips_valid,
		{"buttons": stage_buttons.size(), "enabled": enabled_stages, "first": stage_buttons[0].text, "second": stage_buttons[1].text, "tenth": stage_buttons[9].text, "tooltipsValid": stage_tooltips_valid}
	)

	main.start_stage_from_ui(2)
	await process_frame
	var stage_two_definition: Dictionary = registry.get_stage_definition(2)
	var case_buttons: Array = main.find_children("Case_*", "Button", true, false)
	var enabled_case_buttons := case_buttons.filter(func(button: Button): return not button.disabled)
	var stage_progress_score: PanelContainer = main.find_child("StageProgressScore", true, false)
	var stage_progress_cases: PanelContainer = main.find_child("StageProgressCases", true, false)
	var stage_progress_score_labels: Array = stage_progress_score.find_children("CaseTileSummary_*", "Label", true, false) if stage_progress_score != null else []
	var stage_progress_case_labels: Array = stage_progress_cases.find_children("CaseTileSummary_*", "Label", true, false) if stage_progress_cases != null else []
	record(
		"MVP-STAGE-UI-02",
		"Selecting Stage 2 starts its checkpoint and shows only current/recommended score and scoped case progress without grade or advice clutter",
		gs.current_stage == 2 and gs.stage_run_state.get("status", "") == "RUNNING" and case_buttons.size() == stage_two_definition.get("case_ids", []).size() and enabled_case_buttons.size() == 1 and String(enabled_case_buttons[0].name) == "Case_%s" % gs.current_stage_first_pending_case() and stage_progress_score_labels.size() == 1 and stage_progress_score_labels[0].text == "현재 0 · 권장 56" and stage_progress_case_labels.size() == 1 and stage_progress_case_labels[0].text == "0 / 3" and not visible_copy(main).contains("개선 포인트"),
		{"stage": gs.current_stage, "status": gs.stage_run_state.get("status", ""), "expectedCases": stage_two_definition.get("case_ids", []), "caseButtons": case_buttons.map(func(button: Button): return String(button.name)), "enabled": enabled_case_buttons.map(func(button: Button): return String(button.name)), "score": stage_progress_score_labels.map(func(label: Label): return label.text), "cases": stage_progress_case_labels.map(func(label: Label): return label.text)}
	)

	var korean_stage_payload: Dictionary = gs.save_payload()
	gs.language = "en"
	gs.reset_game()
	var korean_stage_reloaded: bool = gs.apply_save_data(korean_stage_payload)
	var game_state_source := FileAccess.get_file_as_string("res://scripts/game_state.gd")
	record(
		"MVP-STAGE-UI-03",
		"Korean locale survives Stage 2 new-game reset and save/load while a fresh installation keeps English as its declared default",
		korean_stage_payload.get("language", "") == "ko" and korean_stage_reloaded and gs.language == "ko" and gs.current_stage == 2 and game_state_source.contains('var language := "en"'),
		{"payloadLanguage": korean_stage_payload.get("language", ""), "reloaded": korean_stage_reloaded, "loadedLanguage": gs.language, "stage": gs.current_stage, "defaultDeclaredEnglish": game_state_source.contains('var language := "en"')}
	)
	for stage_case_id: String in gs.get_current_stage_case_ids():
		gs.campaign_state.completedCases[stage_case_id] = true
		gs.campaign_state.caseOutcomes[stage_case_id] = "mistaken"
	var below_target_clear: Dictionary = gs.complete_stage(2, 40.0)
	main.show_campaign()
	await process_frame
	var below_clear_copy := visible_copy(main)
	var below_heading := main.find_child("StageClearHeading", true, false)
	var below_advice := main.find_child("StageClearAdvice", true, false)
	var below_axes: Array = main.find_children("StageReplayAxis_*", "PanelContainer", true, false)
	var below_advice_text := String(below_advice.text) if below_advice != null else ""
	var below_clear_valid: bool = bool(below_target_clear.get("ok", false)) and below_heading != null and below_heading.text == "STAGE CLEAR" and below_clear_copy.contains("성장 중 · 점수 40") and below_clear_copy.contains("권장 목표까지 16점") and below_clear_copy.contains("다음 스테이지 해금") and below_clear_copy.contains("신기록 · BEST 40") and below_axes.size() == 3 and below_advice != null and String(below_advice.text).begins_with("재도전 팁 · ") and below_advice.max_lines_visible == 1 and not below_clear_copy.contains("실패") and not below_clear_copy.contains("FAILED") and not below_clear_copy.contains("불합격")
	var above_target_clear: Dictionary = gs.complete_stage(2, 80.0)
	main.show_campaign()
	await process_frame
	var above_clear_copy := visible_copy(main)
	var above_advice := main.find_child("StageClearAdvice", true, false)
	var above_axes: Array = main.find_children("StageReplayAxis_*", "PanelContainer", true, false)
	record(
		"MVP-STAGE-UI-06",
		"Cleared-stage card always leads with STAGE CLEAR, preserves advisory unlock facts, and adds exactly three replay axes plus one actionable one-line tip",
		below_clear_valid and bool(above_target_clear.get("ok", false)) and above_clear_copy.contains("STAGE CLEAR") and above_clear_copy.contains("전문가 · 점수 80") and above_clear_copy.contains("권장 목표 달성") and above_clear_copy.contains("신기록 · BEST 80") and above_axes.size() == 3 and above_advice != null and String(above_advice.text).begins_with("재도전 팁 · ") and above_advice.max_lines_visible == 1 and not above_clear_copy.contains("실패") and not above_clear_copy.contains("FAILED") and not above_clear_copy.contains("불합격"),
		{"below": {"result": below_target_clear, "copy": below_clear_copy, "advice": below_advice_text, "axes": below_axes.size()}, "above": {"result": above_target_clear, "copy": above_clear_copy, "advice": String(above_advice.text) if above_advice != null else "", "axes": above_axes.size()}}
	)

	# A cleared stage is now a durable player-facing handoff. Tests that move on
	# must acknowledge that card through the same public boundary as the UI.
	var stage_two_clear_ack: Dictionary = gs.acknowledge_stage_clear()
	gs.player_profile.highestUnlockedStage = 10
	main.start_stage_from_ui(10)
	await process_frame
	var stage_ten_cases: Array = gs.get_current_stage_case_ids()
	var seeded_showcase_count: int = gs.inventory.filter(func(artifact: Dictionary): return String(artifact.get("uniqueId", "")).begins_with("stage_10_checkpoint_")).size()
	for case_id: String in stage_ten_cases:
		gs.campaign_state.completedCases[case_id] = true
		gs.campaign_state.caseOutcomes[case_id] = "credible"
	var reserve_route: Dictionary = gs.maybe_case_complete_and_unlock()
	main.show_campaign()
	await process_frame
	var reserve_button := main.find_child("GrandReserveSelect", true, false)
	record(
		"MVP-STAGE-UI-04",
		"Stage 10 starts with scoped final cases and showcase lots, then its completion hook opens the existing Grand Reserve UI",
		bool(stage_two_clear_ack.get("ok", false)) and gs.current_stage == 10 and stage_ten_cases.size() == 2 and seeded_showcase_count >= 3 and reserve_route.get("code", "") == "GRAND_RESERVE_READY" and gs.campaign_state.currentAct == "GRAND_RESERVE" and reserve_button != null,
		{"ack": stage_two_clear_ack, "stage": gs.current_stage, "cases": stage_ten_cases, "showcaseLots": seeded_showcase_count, "route": reserve_route, "act": gs.campaign_state.currentAct, "reserveButton": reserve_button != null}
	)

	gs.reset_game()
	gs.persistence_enabled = false
	main.language = "ko"
	main.show_grand_reserve()
	await process_frame
	var grand_reserve_screen_before: String = main.screen
	main.run_grand_reserve_from_ui()
	await process_frame
	var grand_reserve_error_status := String(main.status.text)
	record(
		"MVP-STAGE-UI-05",
		"Failed Grand Reserve preflight stays on the current selection screen and shows a friendly localized error",
		grand_reserve_screen_before == "final_selection" and main.screen == grand_reserve_screen_before and grand_reserve_error_status.contains("초대가 필요합니다") and not grand_reserve_error_status.contains("NOT_INVITED") and gs.campaign_state.currentEnding.is_empty(),
		{"before": grand_reserve_screen_before, "after": main.screen, "status": grand_reserve_error_status, "ending": gs.campaign_state.currentEnding}
	)

	gs.reset_game()
	gs.persistence_enabled = false
	main.character_catalog = {}
	main.market_character_state = "WELCOME"
	main.market_character_dialogue = ""
	main.market_character_fact = ""
	main.show_market()
	await process_frame
	var market_panels := panels(main)
	var market_portraits: Array = main.find_children("CharacterPortrait", "TextureRect", true, false)
	var market_dialogues := labels_named(main, "CharacterDialogue")
	var market_panel_count := market_panels.size()
	var market_portrait_count := market_portraits.size()
	var market_portrait_loaded := market_portrait_count == 1 and market_portraits[0].texture != null
	var market_dialogue_caps_ok := market_dialogues.all(func(label: Label): return label.text.length() <= 44 and label.max_lines_visible == 2)
	var first_lot: Dictionary = gs.market_roster[0] if not gs.market_roster.is_empty() else {}
	if not first_lot.is_empty():
		main.preview_market_offer(first_lot.lotId)
	await process_frame
	var offer_states := labels_named(main, "CharacterSemanticState")
	var offer_facts := labels_named(main, "CharacterFactLabel")
	record(
		"MVP-PORTRAIT-UI-04",
		"Market uses a left shopkeeper portrait and short OFFER dialogue beside the lot list with price retained",
		market_panel_count == 1 and market_portrait_count == 1 and market_portrait_loaded and market_dialogue_caps_ok and offer_states.any(func(label: Label): return label.text.contains("오늘의 제안")) and offer_facts.any(func(label: Label): return label.text.contains("¤")),
		{"panels": market_panel_count, "portrait": market_portrait_count, "portraitLoaded": market_portrait_loaded, "dialogueCaps": market_dialogue_caps_ok, "offerStates": offer_states.map(func(label: Label): return label.text), "facts": offer_facts.map(func(label: Label): return label.text)}
	)

	gs.money = 0
	if not first_lot.is_empty():
		main.buy_market_from_ui(first_lot.lotId)
	await process_frame
	var failure_states := labels_named(main, "CharacterSemanticState")
	var failure_facts := labels_named(main, "CharacterFactLabel")
	var negative_overlay := main.find_children("ExpressionOverlay_NEGATIVE", "Control", true, false)
	record(
		"MVP-PORTRAIT-UI-05",
		"Failed purchase keeps a visible PURCHASE_FAIL label, unavailable fact, and negative expression overlay",
		failure_states.any(func(label: Label): return label.text.contains("구매 불가")) and failure_facts.any(func(label: Label): return label.text.contains("구매 불가")) and negative_overlay.size() == 1,
		{"states": failure_states.map(func(label: Label): return label.text), "facts": failure_facts.map(func(label: Label): return label.text), "negativeOverlays": negative_overlay.size()}
	)

	gs.reset_game()
	gs.persistence_enabled = false
	gs.current_stage = 4
	var artifact: Dictionary = gs.new_artifact(registry.spec_order[0], 30101, "portrait_ui_auction")
	gs.inventory.append(artifact)
	gs.list_auction(artifact, 60, 75, 0.72, "LIKELY")
	main.selected = artifact
	main.load_artifact(artifact)
	main.show_auction()
	await process_frame
	await advance_auction_to_final(main)
	var auction_panels := panels(main)
	var auction_names := labels_named(main, "CharacterDisplayName")
	var auction_states := labels_named(main, "CharacterSemanticState")
	var auction_dialogues := labels_named(main, "CharacterDialogue")
	var auction_facts := labels_named(main, "CharacterFactLabel")
	var auction_result := labels_named(main, "AuctionResultFact")
	var no_sale_reason_chips: Array = main.find_children("AuctionReasonChip_*", "PanelContainer", true, false)
	var no_sale_reason_labels := labels_named(main, "AuctionReasonLabel")
	var no_sale_reason_label_texts: Array = no_sale_reason_labels.map(func(label: Label): return label.text)
	var no_sale_reason_codes: Array = main.last_auction_result.get("reasonTags", []).map(func(tag: Dictionary): return tag.get("code", ""))
	var no_sale_primary_reason: Dictionary = main.auction_terminal_primary_reason(main.last_auction_result)
	var no_sale_primary_reason_code := String(no_sale_primary_reason.get("code", ""))
	var no_sale_expected_reason_label: String = main.auction_reason_label(no_sale_primary_reason_code)
	var no_sale_primary_state: PanelContainer = main.find_child("AuctionPrimaryState", true, false)
	var no_sale_primary_text: Label = main.find_child("AuctionPrimaryText", true, false)
	var no_sale_primary_action: VBoxContainer = main.find_child("AuctionPrimaryAction", true, false)
	var no_sale_hammer_action: Button = main.find_child("HammerButton", true, false)
	var no_sale_copy := visible_copy(main)
	var no_sale_reasons_friendly := not no_sale_reason_codes.is_empty() \
		and no_sale_primary_reason_code == String(no_sale_reason_codes[0]) \
		and no_sale_reason_chips.size() == 1 \
		and no_sale_reason_labels.size() == 1 \
		and no_sale_reason_label_texts == [no_sale_expected_reason_label] \
		and no_sale_reason_codes.all(func(code: Variant): return not no_sale_copy.contains(String(code)))
	var auctioneer_panel: Variant = auction_panels[0] if not auction_panels.is_empty() else null
	var no_sale_overlays: Array = auctioneer_panel.find_children("ExpressionOverlay_NEGATIVE", "Control", true, false) if auctioneer_panel != null else []
	var no_sale_face_centered := false
	if not no_sale_overlays.is_empty():
		var no_sale_overlay: Variant = no_sale_overlays[0]
		var no_sale_face_rect: Rect2 = no_sale_overlay.face_rect_for_size(no_sale_overlay.size)
		var no_sale_face_anchor: Vector2 = no_sale_overlay.svg_to_control(no_sale_overlay.face_anchor_svg, no_sale_overlay.size)
		no_sale_face_centered = no_sale_overlay.drawing_mode == "PORTRAIT_FACE_GEOMETRY" and no_sale_face_rect.has_point(no_sale_face_anchor)
	record(
		"MVP-PORTRAIT-UI-06",
		"A no-sale auction gives the authoritative result/action primary hierarchy, one aggregate reason, and negative character reactions",
		auction_panels.size() == 2 and auction_names.size() == 2 and auction_states.any(func(label: Label): return label.text == "유찰") and auction_facts.any(func(label: Label): return label.text.contains("예약가 미달")) and auction_facts.any(func(label: Label): return label.text.contains("결과 기록 대기")) and auction_dialogues.any(func(label: Label): return label.text.contains("유찰")) and not auction_dialogues.any(func(label: Label): return label.text.contains("다음 호가")) and no_sale_primary_state != null and no_sale_primary_text != null and no_sale_primary_text.text.contains("유찰") and no_sale_primary_action != null and no_sale_hammer_action != null and no_sale_hammer_action.get_parent() == no_sale_primary_action and no_sale_overlays.size() == 1 and no_sale_face_centered and auction_result.size() == 1 and auction_result[0].text.contains("유찰") and auction_result[0].text.contains("정산액") and no_sale_reasons_friendly,
		{"panels": auction_panels.size(), "names": auction_names.map(func(label: Label): return label.text), "states": auction_states.map(func(label: Label): return label.text), "dialogues": auction_dialogues.map(func(label: Label): return label.text), "facts": auction_facts.map(func(label: Label): return label.text), "primaryText": no_sale_primary_text.text if no_sale_primary_text != null else "", "primaryState": no_sale_primary_state != null, "primaryAction": no_sale_primary_action != null, "negativeFaceOverlays": no_sale_overlays.size(), "faceCentered": no_sale_face_centered, "result": auction_result.map(func(label: Label): return label.text), "reasonCodes": no_sale_reason_codes, "aggregateReason": no_sale_primary_reason_code, "reasonLabels": no_sale_reason_label_texts}
	)
	var no_sale_transaction: String = String(gs.pending_auction_public_state().get("transactionId", ""))
	if not no_sale_transaction.is_empty():
		gs.commit_pending_auction(no_sale_transaction)
	artifact.knownClues = ["PROVENANCE"]
	artifact.cleanliness = 100.0
	artifact.surfaceCondition = 100.0
	artifact.mechanicalCondition = 100.0
	gs.list_auction(artifact, 1, 5, 0.92, "CERTAIN")
	main.reset_auction_cue_sequence()
	main.show_auction()
	await process_frame
	await advance_auction_to_final(main)
	var korean_bid_copy := visible_copy(main)
	var sold_reason_codes: Array = main.last_auction_result.get("reasonTags", []).map(func(tag: Dictionary): return tag.get("code", ""))
	var sold_reason_labels := labels_named(main, "AuctionReasonLabel")
	var sold_reason_label_texts: Array = sold_reason_labels.map(func(label: Label): return label.text)
	var sold_reason_copy := visible_copy(main)
	var korean_recent_bids: Array = main.last_auction_result.get("bids", []).slice(maxi(0, main.last_auction_result.get("bids", []).size() - 4))
	var korean_bid_names: Array = []
	var bidder_name_failures: Array = []
	for bid: Dictionary in korean_recent_bids:
		var bidder_profile: Dictionary = main.character_profile(String(bid.get("bidderId", "")))
		var expected_korean := String(bidder_profile.get("displayName", {}).get("ko", ""))
		korean_bid_names.append(expected_korean)
		if expected_korean.is_empty() or not korean_bid_copy.contains(expected_korean):
			bidder_name_failures.append("ko:%s" % bid.get("bidderId", ""))
		if String(bid.get("bidder", "")) != expected_korean and korean_bid_copy.contains(String(bid.get("bidder", ""))):
			bidder_name_failures.append("ko_legacy:%s" % bid.get("bidderId", ""))
	main.language = "en"
	main.show_auction()
	await process_frame
	var english_bid_copy := visible_copy(main)
	var english_reason_labels := labels_named(main, "AuctionReasonLabel")
	var english_reason_label_texts: Array = english_reason_labels.map(func(label: Label): return label.text)
	var sold_primary_reason: Dictionary = main.auction_terminal_primary_reason(main.last_auction_result)
	var sold_primary_reason_code := String(sold_primary_reason.get("code", ""))
	var english_reason_labels_expected: Array = [main.auction_reason_label(sold_primary_reason_code)]
	var english_recent_bids: Array = main.last_auction_result.get("bids", []).slice(maxi(0, main.last_auction_result.get("bids", []).size() - 4))
	var english_bid_names: Array = []
	for bid: Dictionary in english_recent_bids:
		var bidder_profile: Dictionary = main.character_profile(String(bid.get("bidderId", "")))
		var expected_english := String(bidder_profile.get("displayName", {}).get("en", ""))
		english_bid_names.append(expected_english)
		if expected_english.is_empty() or not english_bid_copy.contains(expected_english):
			bidder_name_failures.append("en:%s" % bid.get("bidderId", ""))
	main.language = "ko"
	record(
		"MVP-PORTRAIT-UI-10",
		"Recent bid rows derive Korean and English bidder names from CharacterProfile displayName instead of the English-only auction payload",
		not korean_recent_bids.is_empty() and not english_recent_bids.is_empty() and bidder_name_failures.is_empty(),
		{"koreanRecentBidCount": korean_recent_bids.size(), "koreanNames": korean_bid_names, "englishRecentBidCount": english_recent_bids.size(), "englishNames": english_bid_names, "failures": bidder_name_failures}
	)
	var reason_source := FileAccess.get_file_as_string("res://scripts/main3d.gd")
	var sold_reason_labels_expected: Array = [main.auction_reason_label(sold_primary_reason_code)]
	main.language = "ko"
	record(
		"MVP-PORTRAIT-UI-12",
		"Sold and no-sale terminal results render exactly one localized chip for the first aggregate public reason without raw or hidden tokens",
		bool(main.last_auction_result.get("reserve_met", false)) and not sold_reason_codes.is_empty() and sold_primary_reason_code == String(sold_reason_codes[0]) and sold_reason_labels.size() == 1 and english_reason_labels.size() == 1 and sold_reason_label_texts == sold_reason_labels_expected and english_reason_label_texts == english_reason_labels_expected and sold_reason_codes.all(func(code: Variant): return not sold_reason_copy.contains(String(code)) and not english_bid_copy.contains(String(code))) and no_sale_reasons_friendly and not reason_source.contains('"PRICE_ACCEPTED"') and not sold_reason_copy.contains("authenticityTruth") and not sold_reason_copy.contains("trueRarity") and not sold_reason_copy.contains("maxBid"),
		{"soldCodes": sold_reason_codes, "soldAggregateReason": sold_primary_reason_code, "soldKorean": sold_reason_label_texts, "soldEnglish": english_reason_label_texts, "noSaleCodes": no_sale_reason_codes, "noSaleAggregateReason": no_sale_primary_reason_code, "noSaleKorean": no_sale_reason_label_texts}
	)

	gs.reset_game()
	gs.persistence_enabled = false
	gs.current_stage = 8
	var event_result: Dictionary = gs.advance_day()
	main.last_event_result = event_result
	main.event_cue_state = "REQUEST"
	main.show_event_dialogue(event_result)
	await process_frame
	var request_button := main.find_child("EventRevealResult", true, false)
	var request_panels := panels(main)
	var request_button_present := request_button != null
	var request_panel_count := request_panels.size()
	main.reveal_event_reaction()
	await process_frame
	var reaction_states := labels_named(main, "CharacterSemanticState")
	var reaction_facts := labels_named(main, "CharacterFactLabel")
	var event_continue := main.find_child("EventContinueMarket", true, false)
	record(
		"MVP-PORTRAIT-UI-07",
		"Daily event activation shows mapped NPC REQUEST, then a labelled positive/negative reaction and market choice",
		request_panel_count == 1 and request_button_present and reaction_states.any(func(label: Label): return label.text in ["좋은 결과", "주의 결과"]) and reaction_facts.size() == 1 and event_continue != null,
		{"eventId": event_result.get("eventId", ""), "requestPanels": request_panel_count, "requestButton": request_button_present, "reactionStates": reaction_states.map(func(label: Label): return label.text), "facts": reaction_facts.map(func(label: Label): return label.text), "continue": event_continue != null}
	)

	var negative_mapping: Dictionary = {}
	for mapping: Dictionary in catalog.get("eventCharacterMap", []):
		if mapping.get("outcomePolarity", "") == "NEGATIVE" and mapping.get("effectType", "") == "storage_damage":
			negative_mapping = mapping
			break
	if not negative_mapping.is_empty():
		main.last_event_result = {"eventId": negative_mapping.eventId, "name": "Storage incident", "effect": {"type": "storage_damage"}, "appliedAmount": 1}
		main.event_cue_state = "REQUEST"
		main.reveal_event_reaction()
	await process_frame
	var damage_reaction_states := labels_named(main, "CharacterSemanticState")
	var damage_facts := labels_named(main, "CharacterFactLabel")
	var expression_overlays: Array = main.find_children("ExpressionOverlay_NEGATIVE", "Control", true, false)
	var mood_tooltip := String(expression_overlays[0].tooltip_text) if not expression_overlays.is_empty() else ""
	var geometry_contract: Dictionary = catalog.get("expressionGeometry", {})
	var negative_geometry: Dictionary = expression_overlays[0].expression_geometry if not expression_overlays.is_empty() else {}
	var overlay_size: Vector2 = expression_overlays[0].size if not expression_overlays.is_empty() else Vector2.ZERO
	var face_rect: Rect2 = expression_overlays[0].face_rect_for_size(overlay_size) if not expression_overlays.is_empty() else Rect2()
	var face_anchor: Vector2 = expression_overlays[0].svg_to_control(expression_overlays[0].face_anchor_svg, overlay_size) if not expression_overlays.is_empty() else Vector2.ZERO
	var face_overlay_centered: bool = not expression_overlays.is_empty() and expression_overlays[0].drawing_mode == "PORTRAIT_FACE_GEOMETRY" and face_rect.has_point(face_anchor) and face_anchor.x < overlay_size.x * 0.75 and face_anchor.y < overlay_size.y * 0.75
	record(
		"MVP-PORTRAIT-UI-08",
		"Authoritative event polarity keeps positive-count storage damage negative; overlay consumes three-axis expression geometry and uses a state-label tooltip",
		not negative_mapping.is_empty() and damage_reaction_states.any(func(label: Label): return label.text == "주의 결과") and damage_facts.any(func(label: Label): return label.text.contains("+1")) and not mood_tooltip.is_empty() and not mood_tooltip.begins_with("#") and negative_geometry.get("browShiftSvg", 0) == geometry_contract.get("NEGATIVE", {}).get("browShiftSvg", -1) and negative_geometry.get("eyeHeightShiftSvg", 0) == geometry_contract.get("NEGATIVE", {}).get("eyeHeightShiftSvg", -1) and negative_geometry.get("mouthCornerShiftSvg", 0) == geometry_contract.get("NEGATIVE", {}).get("mouthCornerShiftSvg", -1) and face_overlay_centered,
		{"mapping": negative_mapping, "states": damage_reaction_states.map(func(label: Label): return label.text), "facts": damage_facts.map(func(label: Label): return label.text), "moodTooltip": mood_tooltip, "geometry": negative_geometry, "drawingMode": expression_overlays[0].drawing_mode if not expression_overlays.is_empty() else "", "overlaySize": [overlay_size.x, overlay_size.y], "faceRect": [face_rect.position.x, face_rect.position.y, face_rect.size.x, face_rect.size.y], "faceAnchor": [face_anchor.x, face_anchor.y], "centered": face_overlay_centered}
	)

	var event_ui_failures: Array = []
	var fractional_event_ids: Array = []
	for source_event: Dictionary in registry.events:
		var source_event_id := String(source_event.get("id", ""))
		var localized_name: Dictionary = source_event.get("localizedName", {})
		var localized_description: Dictionary = source_event.get("localizedDescription", {})
		var event_effect: Dictionary = source_event.get("effect", {})
		var applied_amount := float(event_effect.get("amount", 0.0))
		main.event_cue_state = "REQUEST"
		main.show_event_dialogue({"eventId": source_event_id, "name": source_event.get("name", ""), "effect": event_effect.duplicate(true), "appliedAmount": applied_amount})
		await process_frame
		var request_copy := visible_copy(main)
		var korean_name := String(localized_name.get("ko", ""))
		var korean_description := String(localized_description.get("ko", ""))
		if korean_name.is_empty() or korean_description.is_empty() or not request_copy.contains(korean_name) or not request_copy.contains(korean_description):
			event_ui_failures.append("localized_request:%s" % source_event_id)
		if request_copy.contains(source_event_id) or request_copy.contains(String(source_event.get("description", ""))):
			event_ui_failures.append("raw_request:%s" % source_event_id)
		var legacy_name := String(source_event.get("name", ""))
		if legacy_name != korean_name and request_copy.contains(legacy_name):
			event_ui_failures.append("english_name:%s" % source_event_id)
		main.reveal_event_reaction()
		await process_frame
		var reaction_copy := visible_copy(main)
		var event_facts := labels_named(main, "CharacterFactLabel")
		var expected_fact: String = main.event_effect_fact(event_effect, applied_amount)
		if event_facts.size() != 1 or event_facts[0].text != expected_fact or not reaction_copy.contains(expected_fact):
			event_ui_failures.append("effect_fact:%s" % source_event_id)
		var effect_type := String(event_effect.get("type", ""))
		var effect_target := String(event_effect.get("target", ""))
		if (effect_type.contains("_") and reaction_copy.contains(effect_type)) or (effect_target.contains("_") and reaction_copy.contains(effect_target)):
			event_ui_failures.append("raw_effect:%s" % source_event_id)
		if absf(applied_amount) > 0.0 and absf(applied_amount) < 1.0:
			fractional_event_ids.append(source_event_id)
			if not expected_fact.contains("%") or expected_fact.contains("+0") or expected_fact.contains("-0"):
				event_ui_failures.append("fractional_zero:%s=%s" % [source_event_id, expected_fact])
	var event_source := FileAccess.get_file_as_string("res://scripts/main3d.gd")
	record(
		"MVP-PORTRAIT-UI-11",
		"All 25 event screens use data-driven Korean public copy and friendly effect facts; all eight fractional modifiers render as nonzero percentages",
		registry.events.size() == 25 and fractional_event_ids.size() == 8 and event_ui_failures.is_empty() and not event_source.contains("EVENT_PUBLIC_COPY") and event_source.contains("roundi(applied_amount * 100.0)"),
		{"events": registry.events.size(), "fractionalEvents": fractional_event_ids, "failures": event_ui_failures, "dataDriven": not event_source.contains("EVENT_PUBLIC_COPY")}
	)

	var main_source := FileAccess.get_file_as_string("res://scripts/main3d.gd")
	var no_id_renderer_branch := not main_source.contains("if character_id ==") and not main_source.contains("match character_id")
	record(
		"MVP-PORTRAIT-UI-09",
		"PortraitDialoguePanel renderer is profile-driven with no character-id rendering branch",
		no_id_renderer_branch and main_source.contains("func make_portrait_dialogue_panel") and main_source.contains("expressionMetadata"),
		{"noIdRendererBranch": no_id_renderer_branch}
	)

	var passed := results.filter(func(result: Dictionary): return bool(result.passed)).size()
	var report := {"suite": "R3 Portrait Dialogue UI", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "skipped": 0, "tests": results}
	var output := FileAccess.open("res://qa/R3_PORTRAIT_DIALOGUE_UI_TESTS.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	main.queue_free()
	quit(0 if passed == results.size() else 1)
