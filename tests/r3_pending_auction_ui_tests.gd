extends SceneTree

## Authoritative pending-auction and public cue-chain regression. This suite
## runs headlessly, writes only its dedicated user:// fixture and QA report,
## and never exports or packages the project.

const TEST_SAVE := "user://r3_pending_auction_ui_test.json"

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func remove_test_save() -> void:
	for path: String in [TEST_SAVE, TEST_SAVE + ".tmp", TEST_SAVE + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func visible_copy(root: Node) -> String:
	var fragments: Array = []
	for label: Label in root.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			fragments.append(label.text)
	for button: Button in root.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			fragments.append(button.text)
	return "\n".join(fragments)


func configure_runtime(gs: Node, main: Node3D, locale: String = "ko") -> void:
	gs.reset_game()
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	gs.language = locale
	gs.current_stage = 2
	gs.stage_run_state = gs.default_stage_run_state(2)
	gs.stage_run_state.status = "RUNNING"
	main.language = locale
	main.reset_auction_cue_sequence()
	main.selected = {}


func listed_artifact(gs: Node, unique_id: String, opening: int, reserve: int, seed: int = 70101) -> Dictionary:
	var artifact: Dictionary = gs.new_artifact("artifact_001", seed, unique_id)
	artifact.playerHypothesis = gs.truth_to_hypothesis(artifact.authenticityTruth)
	artifact.confidence = 0.92
	artifact.cleanliness = 100.0
	artifact.surfaceCondition = 100.0
	artifact.mechanicalCondition = 100.0
	artifact.knownClues = ["PROVENANCE"]
	gs.inventory.append(artifact)
	var appraisal: int = int(gs.appraise(artifact))
	gs.list_auction(artifact, opening, reserve, float(artifact.confidence), "CERTAIN", appraisal)
	return artifact


func reaction_contracts_valid(main: Node3D) -> bool:
	var anchors: Array = main.find_children("PortraitReactionAnchor", "Control", true, false)
	if anchors.size() != 2:
		return false
	for anchor_value: Variant in anchors:
		var anchor: Control = anchor_value
		var contract: Variant = anchor.get_meta("reaction_contract") if anchor.has_meta("reaction_contract") else {}
		if not contract is Dictionary or not String(contract.get("kind", "")) in ["alpha_settle", "gentle_pop", "soft_tilt"]:
			return false
		if int(contract.get("durationMs", 0)) < 100 or int(contract.get("durationMs", 0)) > 180:
			return false
	return true


func advance_to_final(main: Node3D) -> Array:
	var states: Array = []
	for _step in range(16):
		var cue: Dictionary = main.auction_public_cue_state()
		if cue.is_empty():
			break
		states.append(cue.duplicate(true))
		if bool(cue.get("isFinal", false)):
			break
		main.advance_auction_cue()
		await process_frame
	return states


func economic_public_result(result: Dictionary) -> Dictionary:
	return {
		"opening": int(result.get("opening", 0)),
		"reserve": int(result.get("reserve", 0)),
		"bids": result.get("bids", []).duplicate(true),
		"dropouts": result.get("dropouts", []).duplicate(true),
		"hammer": int(result.get("hammer", 0)),
		"fee": int(result.get("fee", 0)),
		"net": int(result.get("net", 0)),
		"winnerId": String(result.get("winnerId", "")),
		"saleStatus": String(result.get("sale_status", "")),
		"publicFingerprint": String(result.get("publicFingerprint", "")),
		"transactionId": String(result.get("transactionId", ""))
	}


func payload_fingerprint(gs: Node) -> String:
	return JSON.stringify(gs.save_payload())


func public_reason_tags_valid(value: Variant, maximum: int, require_nonempty: bool = false) -> bool:
	if not value is Array:
		return false
	var tags: Array = value
	if tags.size() > maximum or (require_nonempty and tags.is_empty()):
		return false
	for tag_value: Variant in tags:
		if not tag_value is Dictionary:
			return false
		var tag: Dictionary = tag_value
		var keys: Array = tag.keys()
		keys.sort()
		if keys != ["category", "code", "polarity"] \
			or String(tag.get("category", "")).is_empty() \
			or String(tag.get("code", "")).is_empty() \
			or not String(tag.get("polarity", "")) in ["POSITIVE", "NEGATIVE", "NEUTRAL"]:
			return false
	return true


func public_reason_codes(tags: Array) -> Array:
	return tags.map(func(tag_value: Variant): return String(tag_value.get("code", "")) if tag_value is Dictionary else "")


func public_reason_categories(tags: Array) -> Array:
	return tags.map(func(tag_value: Variant): return String(tag_value.get("category", "")) if tag_value is Dictionary else "")


func run() -> void:
	remove_test_save()
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame

	# Real public cue calls: ENTRY -> CALL -> BID* -> DROPOUT? -> SOLD.
	configure_runtime(gs, main, "ko")
	var sold_artifact: Dictionary = listed_artifact(gs, "pending_ui_sold", 1, 5, 70101)
	var sold_pending: Dictionary = gs.create_pending_auction(sold_artifact)
	main.load_artifact(sold_artifact)
	main.show_auction()
	await process_frame
	var sold_render_checks: Array = []
	var sold_states: Array = []
	for _step in range(16):
		var cue: Dictionary = main.auction_public_cue_state()
		if cue.is_empty():
			break
		var copy: String = visible_copy(main)
		sold_states.append(cue.duplicate(true))
		sold_render_checks.append({
			"phase": String(cue.get("phase", "")),
			"portraits": main.find_children("CharacterPortrait", "TextureRect", true, false).size(),
			"dialogues": main.find_children("CharacterDialogue", "Label", true, false).size(),
			"reaction": reaction_contracts_valid(main),
			"next": main.find_child("AuctionCueNext", true, false) != null,
			"hammer": main.find_child("HammerButton", true, false) != null,
			"rawHidden": ["ENTRY", "CALL", "DROPOUT", "winnerId", "maxBid"].all(func(token: String): return not copy.contains(token))
		})
		if bool(cue.get("isFinal", false)):
			break
		main.advance_auction_cue()
		await process_frame
	var sold_phases: Array = sold_states.map(func(state: Dictionary): return String(state.get("phase", "")))
	var sold_order_valid: bool = sold_phases.size() >= 4 and sold_phases[0] == "ENTRY" and sold_phases[1] == "CALL" and sold_phases[-1] == "SOLD"
	var dropout_index: int = sold_phases.find("DROPOUT")
	var last_bid_index: int = sold_phases.rfind("BID")
	sold_order_valid = sold_order_valid and (dropout_index < 0 or last_bid_index < dropout_index)
	var sold_actions_valid: bool = true
	for state_index in range(sold_render_checks.size()):
		var render: Dictionary = sold_render_checks[state_index]
		var final_state: bool = state_index == sold_render_checks.size() - 1
		sold_actions_valid = sold_actions_valid and int(render.portraits) == 2 and int(render.dialogues) == 2 and bool(render.reaction) and bool(render.rawHidden) and bool(render.next) != final_state and bool(render.hammer) == final_state
	record(
		"PENDING-AUCTION-UI-01",
		"Actual UI calls reconstruct a localized two-portrait ENTRY, CALL, BID, optional DROPOUT and SOLD sequence with bounded child reactions",
		bool(sold_pending.get("ok", false)) and sold_order_valid and sold_phases.count("BID") >= 1 and sold_phases.count("BID") <= 3 and sold_actions_valid,
		{"transactionId": sold_pending.get("transactionId", ""), "phases": sold_phases, "renders": sold_render_checks}
	)

	# No-bid/no-sale retains opening and reaches a distinct final state with zero hammer.
	configure_runtime(gs, main, "ko")
	var no_sale_artifact: Dictionary = listed_artifact(gs, "pending_ui_no_sale", 999999, 1000000, 70202)
	var no_sale_pending: Dictionary = gs.create_pending_auction(no_sale_artifact)
	main.load_artifact(no_sale_artifact)
	main.show_auction()
	await process_frame
	var no_sale_states: Array = await advance_to_final(main)
	var no_sale_copy: String = visible_copy(main)
	var no_sale_result: Dictionary = gs.pending_auction_public_state().get("result", {})
	record(
		"PENDING-AUCTION-UI-02",
		"A no-bid queue preserves the opening term, records zero hammer and ends in a friendly NO_SALE portrait state",
		bool(no_sale_pending.get("ok", false)) and not no_sale_states.is_empty() and String(no_sale_states[-1].get("phase", "")) == "NO_SALE" and no_sale_result.get("bids", []).is_empty() and int(no_sale_result.get("opening", 0)) == 999999 and int(no_sale_result.get("hammer", -1)) == 0 and no_sale_copy.contains("유찰") and no_sale_copy.contains("¤0") and not no_sale_copy.contains("NO_SALE"),
		{"phases": no_sale_states.map(func(state: Dictionary): return state.get("phase", "")), "result": economic_public_result(no_sale_result), "copy": no_sale_copy}
	)

	# The pending boundary rejects every gameplay mutation while SAVE, locale and
	# the explicit return-to-auction route remain available.
	configure_runtime(gs, main, "ko")
	var locked_artifact: Dictionary = listed_artifact(gs, "pending_ui_locked", 1, 5, 70303)
	var other_artifact: Dictionary = gs.new_artifact("artifact_002", 70304, "pending_ui_other")
	gs.inventory.append(other_artifact)
	var lock_pending: Dictionary = gs.create_pending_auction(locked_artifact)
	var before_lock: String = payload_fingerprint(gs)
	var event_id: String = String(registry.events[0].get("id", "")) if not registry.events.is_empty() else ""
	var upgrade_id: String = String(registry.upgrades[0].get("id", "")) if not registry.upgrades.is_empty() else ""
	var alternate_tool: String = ""
	for tool_id_value: Variant in registry.tools.keys():
		if String(tool_id_value) != gs.selected_tool:
			alternate_tool = String(tool_id_value)
			break
	var lock_responses := {
		"day": gs.advance_day(),
		"event": gs.execute_event(event_id),
		"upgrade": gs.buy_upgrade(upgrade_id),
		"market": gs.buy_market_lot(String(gs.market_roster[0].get("lotId", ""))) if not gs.market_roster.is_empty() else false,
		"clean": gs.clean(locked_artifact, "soft_brush"),
		"repair": gs.repair(locked_artifact),
		"relist": gs.list_auction(locked_artifact, 2, 6, 0.9, "LIKELY", 10),
		"otherAuction": gs.auction(other_artifact),
		"otherCreate": gs.create_pending_auction(other_artifact),
		"otherSell": gs.sell(other_artifact),
		"grandReserve": gs.run_grand_reserve(),
		"newGame": gs.new_game(1),
		"startStage": gs.start_stage(1),
		"tool": gs.select_tool(alternate_tool),
		"beginCase": gs.begin_case("prologue_dusty_clock"),
		"discover": gs.discover_case_evidence("prologue_dusty_clock", "missing"),
		"hypothesis": gs.set_case_hypothesis("prologue_dusty_clock", "GENUINE"),
		"citation": gs.toggle_case_citation("prologue_dusty_clock", "missing"),
		"report": gs.resolve_case_v2("prologue_dusty_clock", "GENUINE", [])
	}
	var after_lock: String = payload_fingerprint(gs)
	main.show_market()
	await process_frame
	var auction_nav: Button = main.find_child("Nav_AUCTION", true, false)
	var save_nav: Button = main.find_child("Nav_SAVE", true, false)
	var language_nav: Button = main.find_child("Nav_LANGUAGE", true, false)
	var disabled_gameplay_navs: Array = []
	var disabled_gameplay_nav_names: Array = []
	for nav_value: Variant in main.find_children("Nav_*", "Button", true, false):
		var nav_button: Button = nav_value
		if String(nav_button.name) not in ["Nav_AUCTION", "Nav_SAVE", "Nav_LANGUAGE"] and nav_button.disabled:
			disabled_gameplay_navs.append(nav_button)
			disabled_gameplay_nav_names.append(String(nav_button.name))
	var market_buttons_locked: bool = main.find_children("MarketLot_*", "Button", true, false).all(func(button: Button): return button.disabled) and main.find_children("MarketOffer_*", "Button", true, false).all(func(button: Button): return button.disabled)
	# R3 exposes six gameplay destinations while a pending auction is frozen:
	# Market, Inventory, Upgrades, Commissions, Campaign and End Day. Only the
	# resume-auction, Save and locale controls remain actionable.
	var nav_contract_valid: bool = auction_nav != null and not auction_nav.disabled and save_nav != null and not save_nav.disabled and language_nav != null and not language_nav.disabled and disabled_gameplay_navs.size() == 6
	main.resume_pending_auction_from_ui()
	await process_frame
	record(
		"PENDING-AUCTION-UI-03",
		"PENDING freezes day, event, market, upgrade, restoration, relist, other sale, Grand Reserve, new game, stage, tool and case mutations while global navigation exposes only resume, save and locale",
		bool(lock_pending.get("ok", false)) and before_lock == after_lock and nav_contract_valid and market_buttons_locked and main.screen == "auction" and String(gs.pending_auction.get("transactionId", "")) == String(lock_pending.get("transactionId", "")),
		{"mutation0": before_lock == after_lock, "responses": lock_responses, "navContract": nav_contract_valid, "disabledGameplayNavs": disabled_gameplay_nav_names, "marketLocked": market_buttons_locked, "resumedScreen": main.screen}
	)

	# Stale public terms fail closed. A crash-injected commit rolls every in-memory
	# effect back; the subsequent atomic save commits once and retries return the
	# same public receipt with no mutation.
	configure_runtime(gs, main, "en")
	gs.persistence_enabled = true
	var atomic_artifact: Dictionary = listed_artifact(gs, "pending_ui_atomic", 1, 5, 70404)
	var atomic_pending: Dictionary = gs.create_pending_auction(atomic_artifact, false, TEST_SAVE)
	var transaction_id: String = String(atomic_pending.get("transactionId", ""))
	var original_reserve: int = int(atomic_artifact.listing.reserve)
	atomic_artifact.listing.reserve = original_reserve + 1
	var stale_before: String = payload_fingerprint(gs)
	var stale_commit: Dictionary = gs.commit_pending_auction(transaction_id, TEST_SAVE)
	var stale_after: String = payload_fingerprint(gs)
	atomic_artifact.listing.reserve = original_reserve
	var rollback_before: String = payload_fingerprint(gs)
	gs.configure_save_crash_injection_for_test("B_TMP_COMPLETE_BEFORE_VALIDATION")
	var failed_commit: Dictionary = gs.commit_pending_auction(transaction_id, TEST_SAVE)
	var rollback_after: String = payload_fingerprint(gs)
	var first_commit: Dictionary = gs.commit_pending_auction(transaction_id, TEST_SAVE)
	var after_first_commit: String = payload_fingerprint(gs)
	var history_count_after_first: int = gs.auction_history.size()
	var money_after_first: int = gs.money
	var second_commit: Dictionary = gs.commit_pending_auction(transaction_id, TEST_SAVE)
	var after_second_commit: String = payload_fingerprint(gs)
	var first_public: Dictionary = economic_public_result(first_commit)
	var second_public: Dictionary = economic_public_result(second_commit)
	var history_fingerprint: String = String(gs.auction_history[-1].get("result", {}).get("publicFingerprint", "")) if not gs.auction_history.is_empty() else ""
	record(
		"PENDING-AUCTION-UI-04",
		"Commit revalidates public fingerprint, rolls back a failed atomic save, then returns one identical idempotent receipt without duplicate history or money",
		bool(atomic_pending.get("ok", false)) and not bool(stale_commit.get("ok", true)) and stale_commit.get("code", "") == "STALE_PENDING_AUCTION" and stale_before == stale_after and not bool(failed_commit.get("ok", true)) and failed_commit.get("code", "") == "PENDING_AUCTION_SAVE_FAILED" and rollback_before == rollback_after and bool(first_commit.get("ok", false)) and not bool(first_commit.get("idempotent", true)) and bool(second_commit.get("ok", false)) and bool(second_commit.get("idempotent", false)) and first_public == second_public and after_first_commit == after_second_commit and gs.auction_history.size() == history_count_after_first and gs.money == money_after_first and history_fingerprint == String(atomic_pending.get("publicFingerprint", "")),
		{"stale": stale_commit, "staleMutation0": stale_before == stale_after, "failed": failed_commit, "rollbackMutation0": rollback_before == rollback_after, "first": first_commit, "second": second_commit, "receiptEqual": first_public == second_public, "commitMutation0": after_first_commit == after_second_commit, "historyFingerprint": history_fingerprint}
	)

	# Save/load and locale rebuild preserve the authoritative auction identity,
	# cue index and focus. Continue prioritizes PENDING over a stale screen mirror.
	configure_runtime(gs, main, "ko")
	gs.persistence_enabled = true
	var resume_artifact: Dictionary = listed_artifact(gs, "pending_ui_resume", 1, 5, 70505)
	var resume_pending: Dictionary = gs.create_pending_auction(resume_artifact, false, TEST_SAVE)
	gs.persistence_enabled = false
	main.load_artifact(resume_artifact)
	main.show_auction()
	await process_frame
	main.advance_auction_cue()
	await process_frame
	main.advance_auction_cue()
	await process_frame
	var resume_index: int = int(gs.pending_auction.get("cueIndex", -1))
	var resume_phase: String = String(main.auction_public_cue_state().get("phase", ""))
	var cue_button: Button = main.find_child("AuctionCueNext", true, false)
	if cue_button != null:
		cue_button.grab_focus()
	var focus_before_locale: String = main.current_focus_control_name()
	main.toggle_language()
	await process_frame
	await process_frame
	await process_frame
	var focus_after_locale: String = main.current_focus_control_name()
	var locale_preserved: bool = main.screen == "auction" and int(gs.pending_auction.get("cueIndex", -1)) == resume_index and String(main.auction_public_cue_state().get("phase", "")) == resume_phase and focus_before_locale == focus_after_locale
	gs.persistence_enabled = true
	main.save_from_ui(TEST_SAVE)
	var expected_transaction: String = String(gs.pending_auction.get("transactionId", ""))
	var expected_fingerprint: String = String(gs.pending_auction.get("publicFingerprint", ""))
	gs.reset_game()
	var continued: bool = main.continue_from_ui(TEST_SAVE)
	await process_frame
	await process_frame
	await process_frame
	var loaded_pending: Dictionary = gs.pending_auction_public_state()
	var auction_restored: bool = continued and main.screen == "auction" and int(loaded_pending.get("cueIndex", -1)) == resume_index and String(loaded_pending.get("transactionId", "")) == expected_transaction and String(loaded_pending.get("publicFingerprint", "")) == expected_fingerprint and String(main.selected.get("uniqueId", "")) == "pending_ui_resume" and main.current_focus_control_name() == focus_after_locale
	record(
		"PENDING-AUCTION-UI-05",
		"Locale rebuild and Continue restore the exact pending transaction, public fingerprint, cue, selected lot and keyboard focus",
		bool(resume_pending.get("ok", false)) and locale_preserved and auction_restored,
		{"localePreserved": locale_preserved, "focusBefore": focus_before_locale, "focusAfter": focus_after_locale, "cueIndex": resume_index, "phase": resume_phase, "continued": continued, "loaded": loaded_pending, "screen": main.screen, "selected": main.selected.get("uniqueId", "")}
	)

	# Market and event interaction cues are presentation state, but their current
	# semantic step and focus also survive locale rebuild plus explicit save/load.
	configure_runtime(gs, main, "ko")
	gs.persistence_enabled = false
	var first_lot: Dictionary = gs.market_roster[0] if not gs.market_roster.is_empty() else {}
	main.show_market()
	main.preview_market_offer(String(first_lot.get("lotId", "")))
	await process_frame
	var market_focus_control: Button = main.find_child("MarketOffer_0", true, false)
	if market_focus_control != null:
		market_focus_control.grab_focus()
	var market_focus_before: String = main.current_focus_control_name()
	main.toggle_language()
	await process_frame
	await process_frame
	await process_frame
	var market_locale_preserved: bool = main.screen == "market" and main.market_character_state == "OFFER" and main.market_active_lot_id == String(first_lot.get("lotId", "")) and main.current_focus_control_name() == market_focus_before
	gs.persistence_enabled = true
	main.save_from_ui(TEST_SAVE)
	gs.reset_game()
	var market_continued: bool = main.continue_from_ui(TEST_SAVE)
	await process_frame
	await process_frame
	await process_frame
	var market_restored: bool = market_continued and main.screen == "market" and main.market_character_state == "OFFER" and main.market_active_lot_id == String(first_lot.get("lotId", "")) and main.current_focus_control_name() == market_focus_before

	gs.persistence_enabled = false
	var event_result: Dictionary = gs.advance_day()
	main.event_cue_state = "REQUEST"
	main.show_event_dialogue(event_result)
	main.reveal_event_reaction()
	await process_frame
	var event_focus_control: Button = main.find_child("EventContinueMarket", true, false)
	if event_focus_control != null:
		event_focus_control.grab_focus()
	var event_focus_before: String = main.current_focus_control_name()
	var event_state_before: String = main.event_cue_state
	main.toggle_language()
	await process_frame
	await process_frame
	await process_frame
	var event_locale_preserved: bool = main.screen == "event" and main.event_cue_state == event_state_before and main.current_focus_control_name() == event_focus_before
	gs.persistence_enabled = true
	main.save_from_ui(TEST_SAVE)
	gs.reset_game()
	var event_continued: bool = main.continue_from_ui(TEST_SAVE)
	await process_frame
	await process_frame
	await process_frame
	var event_restored: bool = event_continued and main.screen == "event" and main.event_cue_state == event_state_before and main.current_focus_control_name() == event_focus_before
	record(
		"PENDING-AUCTION-UI-06",
		"Market OFFER and event reaction cues preserve semantic state and keyboard focus across locale rebuild and save-load Continue",
		market_locale_preserved and market_restored and event_locale_preserved and event_restored,
		{"market": {"locale": market_locale_preserved, "restored": market_restored, "focus": market_focus_before}, "event": {"state": event_state_before, "locale": event_locale_preserved, "restored": event_restored, "focus": event_focus_before}}
	)

	# Public fingerprints/results never expose the truth, valuation, bidder budget,
	# maximum bid, or RNG cursor used only inside the frozen generation boundary.
	configure_runtime(gs, main, "en")
	var privacy_artifact: Dictionary = listed_artifact(gs, "pending_ui_privacy", 10, 20, 70606)
	var privacy_pending: Dictionary = gs.create_pending_auction(privacy_artifact)
	var privacy_blob: String = JSON.stringify({"decisions": privacy_pending.get("decisions", {}), "result": privacy_pending.get("result", {})})
	var privacy_forbidden := ["authenticityTruth", "trueRarity", "trueHistoricalSignificance", "baseValue", "originalParts", "replacementParts", "budget", "maxBid", "rngState", "rngCursor"]
	record(
		"PENDING-AUCTION-UI-07",
		"The persisted public fingerprint contract and renderer result exclude hidden truth, value, originality, bidder secret and RNG fields",
		bool(privacy_pending.get("ok", false)) and not String(privacy_pending.get("publicFingerprint", "")).is_empty() and privacy_forbidden.all(func(token: String): return not privacy_blob.contains(token)),
		{"fingerprint": privacy_pending.get("publicFingerprint", ""), "decisionKeys": privacy_pending.get("decisions", {}).keys(), "resultKeys": privacy_pending.get("result", {}).keys(), "forbidden": privacy_forbidden}
	)

	# The listing bridge is an exact three-slot public contract. Hidden canonical
	# truth and value fields must not change either listing or auction cause tags.
	configure_runtime(gs, main, "en")
	var adapter_artifact: Dictionary = listed_artifact(gs, "pending_ui_public_adapter", 1, 999999, 70707)
	var listing_tags: Array = gs.listing_public_status_tags(adapter_artifact, "CERTAIN")
	var hidden_flip: Dictionary = adapter_artifact.duplicate(true)
	hidden_flip["authenticityTruth"] = "FORGERY" if String(adapter_artifact.get("authenticityTruth", "")) != "FORGERY" else "GENUINE"
	hidden_flip["trueRarity"] = float(adapter_artifact.get("trueRarity", 1.0)) + 17.0
	hidden_flip["trueHistoricalSignificance"] = float(adapter_artifact.get("trueHistoricalSignificance", 1.0)) + 23.0
	hidden_flip["baseValue"] = int(adapter_artifact.get("baseValue", 1)) + 900000
	hidden_flip["originalParts"] = int(adapter_artifact.get("originalParts", 0)) + 41
	hidden_flip["replacementParts"] = int(adapter_artifact.get("replacementParts", 0)) + 37
	var flipped_listing_tags: Array = gs.listing_public_status_tags(hidden_flip, "CERTAIN")
	var fixed_public_outcome := {"opening": 1, "reserve": 999999, "hammer": 100, "reserve_met": false}
	var bid_tags: Array = gs.auction_public_reason_tags(adapter_artifact, {}, "BID", fixed_public_outcome)
	var flipped_bid_tags: Array = gs.auction_public_reason_tags(hidden_flip, {}, "BID", fixed_public_outcome)
	var no_sale_tags: Array = gs.auction_public_reason_tags(adapter_artifact, {}, "NO_SALE", fixed_public_outcome)
	var flipped_no_sale_tags: Array = gs.auction_public_reason_tags(hidden_flip, {}, "NO_SALE", fixed_public_outcome)
	var adapter_privacy_blob := JSON.stringify({"listing": listing_tags, "bid": bid_tags, "noSale": no_sale_tags})
	var adapter_forbidden := ["authenticityTruth", "trueRarity", "trueHistoricalSignificance", "baseValue", "originalParts", "replacementParts", "maxBid", "budget"]
	var listing_contract: bool = public_reason_tags_valid(listing_tags, 3, true) \
		and listing_tags.size() == 3 \
		and public_reason_categories(listing_tags) == ["CONDITION", "PROVENANCE", "DISCLOSURE"] \
		and public_reason_codes(listing_tags) == ["CONDITION_GOOD", "PROVENANCE_STRONG", "DISCLOSURE_CLEAR"]
	var hidden_flip_invariant: bool = gs.canonical_json_values_equal(listing_tags, flipped_listing_tags) \
		and gs.canonical_json_values_equal(bid_tags, flipped_bid_tags) \
		and gs.canonical_json_values_equal(no_sale_tags, flipped_no_sale_tags) \
		and adapter_forbidden.all(func(token: String): return not adapter_privacy_blob.contains(token))
	record(
		"PENDING-AUCTION-UI-08",
		"The listing adapter emits exactly condition, provenance and disclosure status tags in order and ignores hidden truth/value flips",
		listing_contract and hidden_flip_invariant,
		{"listingTags": listing_tags, "flippedListingTags": flipped_listing_tags, "bidTags": bid_tags, "flippedBidTags": flipped_bid_tags, "noSaleTags": no_sale_tags, "flippedNoSaleTags": flipped_no_sale_tags, "forbidden": adapter_forbidden}
	)

	# Persist a real pending snapshot, then obtain its display projection through
	# both public adapter entry points. BID/DROPOUT tags are bounded to two and the
	# terminal projection preserves the aggregate reason order without testing UI.
	remove_test_save()
	gs.persistence_enabled = true
	var adapter_pending: Dictionary = gs.create_pending_auction(adapter_artifact, false, TEST_SAVE)
	var raw_queue_before: Array = gs.pending_auction.get("cueQueue", []).duplicate(true)
	var raw_result_before: Dictionary = gs.pending_auction.get("result", {}).duplicate(true)
	var payload_pending_before: Dictionary = gs.save_payload().get("pendingAuction", {}).duplicate(true)
	var disk_payload_before: Dictionary = gs.read_save_dictionary(TEST_SAVE)
	var disk_text_before: String = FileAccess.get_file_as_string(TEST_SAVE)
	var game_rng_before: int = int(gs.rng.state)
	seed(8675309)
	var expected_global_first: int = randi()
	var expected_global_second: int = randi()
	seed(8675309)
	var actual_global_first: int = randi()
	var public_pending: Dictionary = gs.pending_auction_public_state(String(adapter_pending.get("transactionId", "")))
	var direct_public_queue: Array = gs.public_pending_auction_cue_queue(raw_queue_before, raw_result_before)
	# Exercise every public cause adapter inside the same mutation boundary.
	var repeated_listing_tags: Array = gs.listing_public_status_tags(adapter_artifact, "CERTAIN")
	var repeated_bid_tags: Array = gs.auction_public_reason_tags(adapter_artifact, {}, "BID", fixed_public_outcome)
	var actual_global_second: int = randi()
	var public_queue: Array = public_pending.get("cueQueue", [])
	var public_bid_cues: Array = public_queue.filter(func(cue_value: Variant): return cue_value is Dictionary and String(cue_value.get("phase", "")) == "BID")
	var public_dropout_cues: Array = public_queue.filter(func(cue_value: Variant): return cue_value is Dictionary and String(cue_value.get("phase", "")) == "DROPOUT")
	var terminal_cues: Array = public_queue.filter(func(cue_value: Variant): return cue_value is Dictionary and String(cue_value.get("phase", "")) in ["SOLD", "NO_SALE"])
	var bid_cue_contract: bool = not public_bid_cues.is_empty() and public_bid_cues.all(func(cue_value: Variant): return public_reason_tags_valid(cue_value.get("reasonTags", null), 2, true))
	var dropout_cue_contract: bool = not public_dropout_cues.is_empty() and public_dropout_cues.all(func(cue_value: Variant): return public_reason_tags_valid(cue_value.get("reasonTags", null), 2, true))
	var terminal_tags: Array = terminal_cues[0].get("reasonTags", []) if terminal_cues.size() == 1 else []
	var aggregate_tags: Array = public_pending.get("result", {}).get("reasonTags", [])
	var expected_terminal_tags: Array = gs.sanitized_public_reason_tags(aggregate_tags, 2)
	var terminal_contract: bool = terminal_cues.size() == 1 \
		and public_reason_tags_valid(terminal_tags, 2) \
		and gs.canonical_json_values_equal(terminal_tags, expected_terminal_tags) \
		and (terminal_tags.is_empty() or aggregate_tags.is_empty() or String(terminal_tags[0].get("code", "")) == String(aggregate_tags[0].get("code", "")))
	var raw_queue_is_display_free: bool = raw_queue_before.all(func(cue_value: Variant): return cue_value is Dictionary and not cue_value.has("reasonTags"))
	var projection_shape_ok: bool = bool(adapter_pending.get("ok", false)) \
		and bool(public_pending.get("ok", false)) \
		and gs.canonical_json_values_equal(public_queue, direct_public_queue) \
		and raw_queue_is_display_free \
		and bid_cue_contract \
		and dropout_cue_contract \
		and terminal_contract
	record(
		"PENDING-AUCTION-UI-09",
		"The public adapter alone projects sanitized maximum-two BID/DROPOUT reasons and preserves terminal aggregate ordering",
		projection_shape_ok,
		{"rawPhases": raw_queue_before.map(func(cue_value: Variant): return cue_value.get("phase", "") if cue_value is Dictionary else "INVALID"), "bidCues": public_bid_cues, "dropoutCues": public_dropout_cues, "terminalTags": terminal_tags, "aggregateTags": aggregate_tags, "rawQueueDisplayFree": raw_queue_is_display_free}
	)

	var raw_queue_after: Array = gs.pending_auction.get("cueQueue", []).duplicate(true)
	var raw_result_after: Dictionary = gs.pending_auction.get("result", {}).duplicate(true)
	var payload_pending_after: Dictionary = gs.save_payload().get("pendingAuction", {}).duplicate(true)
	var disk_payload_after: Dictionary = gs.read_save_dictionary(TEST_SAVE)
	var disk_text_after: String = FileAccess.get_file_as_string(TEST_SAVE)
	var game_rng_after: int = int(gs.rng.state)
	var disk_pending_before: Dictionary = disk_payload_before.get("pendingAuction", {})
	var disk_pending_after: Dictionary = disk_payload_after.get("pendingAuction", {})
	var persisted_unchanged: bool = gs.canonical_json_values_equal(raw_queue_before, raw_queue_after) \
		and gs.canonical_json_values_equal(raw_result_before, raw_result_after) \
		and gs.canonical_json_values_equal(payload_pending_before.get("cueQueue", []), payload_pending_after.get("cueQueue", [])) \
		and gs.canonical_json_values_equal(payload_pending_before.get("result", {}), payload_pending_after.get("result", {})) \
		and gs.canonical_json_values_equal(disk_pending_before.get("cueQueue", []), disk_pending_after.get("cueQueue", [])) \
		and gs.canonical_json_values_equal(disk_pending_before.get("result", {}), disk_pending_after.get("result", {})) \
		and gs.canonical_json_values_equal(raw_queue_before, disk_pending_before.get("cueQueue", [])) \
		and gs.canonical_json_values_equal(raw_result_before, disk_pending_before.get("result", {})) \
		and disk_text_before == disk_text_after
	var rng_unchanged: bool = game_rng_before == game_rng_after \
		and actual_global_first == expected_global_first \
		and actual_global_second == expected_global_second
	record(
		"PENDING-AUCTION-UI-10",
		"Public cause adapters leave the canonical in-memory and on-disk cue/result snapshots plus game/global RNG cursors unchanged",
		persisted_unchanged and rng_unchanged \
			and gs.canonical_json_values_equal(listing_tags, repeated_listing_tags) \
			and gs.canonical_json_values_equal(bid_tags, repeated_bid_tags),
		{"memoryQueueUnchanged": gs.canonical_json_values_equal(raw_queue_before, raw_queue_after), "memoryResultUnchanged": gs.canonical_json_values_equal(raw_result_before, raw_result_after), "payloadUnchanged": gs.canonical_json_values_equal(payload_pending_before, payload_pending_after), "diskTextUnchanged": disk_text_before == disk_text_after, "gameRngBefore": str(game_rng_before), "gameRngAfter": str(game_rng_after), "globalRng": {"expected": [expected_global_first, expected_global_second], "actual": [actual_global_first, actual_global_second]}}
	)

	var passed: int = results.filter(func(result: Dictionary): return bool(result.passed)).size()
	var report := {"suite": "R3 Authoritative Pending Auction and Cue UI", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "skipped": 0, "tests": results}
	var output := FileAccess.open("res://qa/R3_PENDING_AUCTION_UI_TESTS.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	remove_test_save()
	gs.persistence_enabled = false
	await create_timer(0.22).timeout
	main.queue_free()
	await process_frame
	await process_frame
	quit(0 if passed == results.size() else 1)
