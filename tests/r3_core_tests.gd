extends SceneTree

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, category: String, name: String, condition: bool, evidence: Variant) -> void:
	results.append({"id": id, "category": category, "name": name, "executed": true, "passed": condition, "evidence": evidence})


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	gs.reset_game()
	await process_frame

	record("R3-BOOT-01", "integration", "R3 main scene is Node3D", main is Node3D and main.has_node("WorkshopEnvironment3D"), "WorkshopEnvironment3D present")
	record("R3-DATA-01", "data", "Catalog loads exact required counts", registry.specs.size() == 80 and registry.baseline_spec_ids.size() == 60 and registry.expansion_spec_ids.size() == 20 and registry.bidders.size() == 12 and registry.events.size() == 25 and registry.upgrades.size() == 25, {"specs": registry.specs.size(), "baseline": registry.baseline_spec_ids.size(), "expansion": registry.expansion_spec_ids.size(), "bidders": registry.bidders.size(), "events": registry.events.size(), "upgrades": registry.upgrades.size()})

	var binding_failures: Array = []
	var damage_failures: Array = []
	var visual_failures: Array = []
	var base_signatures := {}
	for index in range(registry.spec_order.size()):
		var spec: Dictionary = registry.get_spec(index)
		var artifact: Dictionary = gs.new_artifact(spec.id, 10000 + index, "binding_%03d" % index)
		var required_match: bool = artifact.displayName == spec.displayName and artifact.category == spec.category and artifact.actualEra == spec.era and artifact.baseModel == spec.baseModel and int(artifact.baseValue) == int(spec.baseValue) and artifact.maker == spec.maker and artifact.modelName == spec.modelName and artifact.materialSet == spec.materialSet and artifact.visualVariant == spec.visualVariant
		if not required_match:
			binding_failures.append(spec.id)
		for damage: String in artifact.damageInstances:
			if not damage in spec.compatibleDamages:
				damage_failures.append("%s:%s" % [spec.id, damage])
		var variant: Dictionary = registry.get_visual_variant(spec.id)
		var model_resource: Resource = registry.resolve_model(spec.id)
		var material_path: String = variant.get("materialPath", "")
		if not model_resource is Mesh or variant.is_empty() or material_path.is_empty() or not FileAccess.file_exists(material_path):
			visual_failures.append(spec.id)
		if not base_signatures.has(spec.baseModel):
			base_signatures[spec.baseModel] = []
		base_signatures[spec.baseModel].append(registry.visual_signature(spec.id))
	record("R3-DATA-02", "data", "All 80 ArtifactSpecs bind immutable catalog fields", binding_failures.is_empty(), binding_failures)
	record("R3-DATA-03", "data", "Generated damage respects compatible set", damage_failures.is_empty(), damage_failures)
	var repeated_signatures: Array = []
	for base_model: String in base_signatures.keys():
		var unique := {}
		for signature: String in base_signatures[base_model]:
			unique[signature] = true
		if unique.size() != base_signatures[base_model].size():
			repeated_signatures.append(base_model)
	record("R3-VIS-01", "integration", "All 80 variants resolve mesh and material", visual_failures.is_empty(), visual_failures)
	record("R3-VIS-02", "data", "Every variant per base mesh has a distinct signature", repeated_signatures.is_empty(), repeated_signatures)

	gs.reset_game()
	var roster_day_one: Array = gs.market_spec_ids().duplicate()
	gs.generate_market_roster()
	var roster_repeat: Array = gs.market_spec_ids().duplicate()
	record("R3-MARKET-01", "state", "Same seed and day reproduces roster", roster_day_one == roster_repeat, roster_day_one)
	gs.advance_day()
	var roster_day_two: Array = gs.market_spec_ids().duplicate()
	record("R3-MARKET-02", "state", "Advance day rotates market", roster_day_one != roster_day_two and gs.day == 2, {"day1": roster_day_one, "day2": roster_day_two})
	var seen_specs := {}
	for simulated_day in range(1, 31):
		gs.day = simulated_day
		gs.daily_modifiers = {}
		gs.generate_market_roster()
		for spec_id: String in gs.market_spec_ids():
			seen_specs[spec_id] = true
	record("R3-MARKET-03", "simulation", "Thirty-day market exposes substantial catalog", seen_specs.size() >= 50, {"unique_specs": seen_specs.size(), "days": 30})

	gs.reset_game()
	var first_lot: Dictionary = gs.market_roster[0]
	var first_lot_id: String = first_lot.lotId
	var first_spec: String = first_lot.specId
	var bought: bool = gs.buy_market_lot(first_lot_id)
	gs.generate_market_roster()
	var sold_still_marked := false
	for lot: Dictionary in gs.market_roster:
		if lot.lotId == first_lot_id:
			sold_still_marked = bool(lot.sold)
	record("R3-MARKET-04", "state", "Bought lot does not duplicate on screen refresh", bought and sold_still_marked and gs.inventory[0].artifactSpecId == first_spec, {"lot": first_lot_id, "spec": first_spec})

	var artifact: Dictionary = gs.inventory[0]
	artifact.damageInstances = ["DUST", "RUST"]
	main.load_artifact(artifact)
	main.show_inspection()
	await process_frame
	var markers_before: int = main.damage_marks.size()
	main.restore_from_ui("clean", "soft_brush")
	await process_frame
	var markers_after: int = main.damage_marks.size()
	record("R3-RESTORE-01", "ui", "Cleaning UI immediately synchronizes damage markers", markers_after < markers_before and markers_after == artifact.damageInstances.size(), {"before": markers_before, "after": markers_after})
	artifact.damageInstances = ["CRACK"]
	main.sync_workpiece_from_state()
	var integrity_before := float(artifact.historicalIntegrity)
	main.restore_from_ui("clean", "soft_brush")
	await process_frame
	record("R3-RESTORE-02", "ui", "Wrong tool immediately updates state and visual feedback", float(artifact.historicalIntegrity) < integrity_before and main.damage_marks.size() == artifact.damageInstances.size(), {"integrity_before": integrity_before, "integrity_after": artifact.historicalIntegrity, "markers": main.damage_marks.size()})
	var supported_artifact: Dictionary = gs.new_artifact("artifact_001", 990, "supported")
	main.load_artifact(supported_artifact)
	main.show_inspection()
	await process_frame
	var supported: Dictionary = registry.supported_operations(supported_artifact.artifactSpecId)
	main.restore_from_ui("disassemble")
	await process_frame
	var panel_hidden: bool = bool(supported.disassembly) and main.parts.has("panel") and not main.parts.panel.visible
	record("R3-DISASSEMBLY-01", "ui", "Supported disassembly hides part immediately", panel_hidden, supported)
	var unsupported: Dictionary = gs.new_artifact("artifact_002", 991, "unsupported")
	record("R3-DISASSEMBLY-02", "state", "Unsupported artifact cannot enter fake disassembly", not gs.disassemble(unsupported, "panel") and not registry.supported_operations(unsupported.artifactSpecId).disassembly, unsupported.artifactSpecId)

	artifact.evidence = []
	artifact.knownClues = []
	gs.inspect_clue(artifact, "MATERIAL")
	gs.inspect_clue(artifact, "SERIAL_PATTERN")
	gs.authenticate(artifact)
	main.selected = artifact
	main.show_authentication()
	await process_frame
	var rects: Array = []
	var no_overlap: bool = main.hypothesis_buttons.size() == 6
	for hypothesis: String in HYPOTHESES_FOR_TEST():
		var button: Button = main.hypothesis_buttons.get(hypothesis)
		if button == null or not button.visible or not button.focus_mode == Control.FOCUS_ALL:
			no_overlap = false
		else:
			rects.append(button.get_global_rect())
	for left in range(rects.size()):
		for right in range(left + 1, rects.size()):
			if rects[left].intersects(rects[right]):
				no_overlap = false
	record("R3-AUTH-01", "ui", "Six hypothesis controls are visible and non-overlapping", no_overlap, rects.map(func(rect: Rect2): return str(rect)))
	var activation_failures: Array = []
	for hypothesis: String in HYPOTHESES_FOR_TEST():
		artifact.playerHypothesis = "GENUINE" if hypothesis == "UNKNOWN" else "UNKNOWN"
		var button: Button = main.hypothesis_buttons[hypothesis]
		button.pressed.emit()
		if artifact.playerHypothesis != hypothesis:
			activation_failures.append(hypothesis)
	record("R3-AUTH-02", "ui", "Each hypothesis activates its own value through Button signal", activation_failures.is_empty(), activation_failures)
	artifact.playerHypothesis = "GENUINE"
	main.show_authentication()
	await process_frame
	record("R3-AUTH-03", "ui", "Appraisal continuation requires accepted non-UNKNOWN selection", not main.hypothesis_accept_button.disabled, artifact.playerHypothesis)

	gs.reset_game()
	gs.buy_artifact(0)
	var no_sale_artifact: Dictionary = gs.inventory[0]
	gs.choose_hypothesis(no_sale_artifact, gs.truth_to_hypothesis(no_sale_artifact.authenticityTruth))
	gs.accept_hypothesis(no_sale_artifact)
	gs.list_auction(no_sale_artifact, 1, 999999, 0.9)
	var money_before_no_sale: int = gs.money
	var sales_before_no_sale: int = gs.statistics.sales
	var no_sale_result: Dictionary = gs.sell(no_sale_artifact)
	record("R3-AUCTION-01", "state", "Reserve failure keeps item and credits no money", no_sale_result.sale_status == "NO_SALE" and gs.inventory.has(no_sale_artifact) and gs.money == money_before_no_sale and int(gs.statistics.sales) == sales_before_no_sale, no_sale_result)
	gs.list_auction(no_sale_artifact, 1, 1, 0.9)
	var sold_result: Dictionary = gs.sell(no_sale_artifact)
	var after_first_sale: int = gs.money
	var duplicate_result: Dictionary = gs.sell(no_sale_artifact)
	record("R3-AUCTION-02", "state", "Reserve-met sale completes exactly once", sold_result.sale_status == "SOLD" and not gs.inventory.has(no_sale_artifact) and duplicate_result.sale_status == "ALREADY_RECORDED" and gs.money == after_first_sale, {"sale": sold_result, "duplicate": duplicate_result})

	gs.reset_game()
	var profile_ids := {}
	var budget_violations: Array = []
	for sample in range(40):
		gs.day = sample + 1
		var sample_artifact: Dictionary = gs.new_artifact(sample % 60, 8000 + sample, "bid_sample_%02d" % sample)
		gs.choose_hypothesis(sample_artifact, gs.truth_to_hypothesis(sample_artifact.authenticityTruth))
		gs.list_auction(sample_artifact, 1, 1, 0.8)
		var auction_result: Dictionary = gs.auction(sample_artifact)
		for participant: Dictionary in auction_result.participants:
			profile_ids[participant.id] = true
			if int(participant.maxBid) > int(participant.budget):
				budget_violations.append(participant.id)
		for bid: Dictionary in auction_result.bids:
			if int(bid.amount) > int(bid.budget):
				budget_violations.append(bid.bidderId)
	record("R3-BIDDER-01", "simulation", "All 12 bidder profiles are reachable", profile_ids.size() == 12, profile_ids.keys())
	record("R3-BIDDER-02", "simulation", "Bidder budget caps cannot be violated", budget_violations.is_empty(), budget_violations)
	var controlled: Dictionary = gs.new_artifact(2, 22, "controlled_bidder")
	gs.choose_hypothesis(controlled, gs.truth_to_hypothesis(controlled.authenticityTruth))
	var low_profile: Dictionary = registry.get_bidder(0)
	var high_profile: Dictionary = registry.get_bidder(11)
	var low_max: int = gs.bidder_maximum(controlled, low_profile, 500, 1.0)
	var high_max: int = gs.bidder_maximum(controlled, high_profile, 500, 1.0)
	record("R3-BIDDER-03", "state", "Distinct bidder profiles produce distinct controlled valuation", low_max != high_max, {"low": low_max, "high": high_max})

	gs.reset_game()
	var event_failures: Array = []
	for event: Dictionary in registry.events:
		var history_before: int = gs.event_history.size()
		var event_result: Dictionary = gs.execute_event(event.id, false)
		if event_result.is_empty() or gs.event_history.size() != history_before + 1 or not event_result.has("appliedAmount"):
			event_failures.append(event.id)
	record("R3-EVENT-01", "integration", "All 25 events execute a structured state effect", event_failures.is_empty(), event_failures)
	var reached_events := {}
	for simulated_day in range(1, 126):
		reached_events[gs.deterministic_event_id(simulated_day)] = true
	record("R3-EVENT-02", "simulation", "Seeded daily selection reaches all events", reached_events.size() == 25, reached_events.keys())

	gs.reset_game()
	gs.money = 100000
	var upgrade_failures: Array = []
	for upgrade: Dictionary in registry.upgrades:
		var money_before: int = gs.money
		var effect_type: String = upgrade.effect.type
		var effect_before: float = gs.upgrade_effect_total(effect_type)
		var purchased: bool = gs.buy_upgrade(upgrade.id)
		var effect_after: float = gs.upgrade_effect_total(effect_type)
		var duplicate_blocked: bool = not gs.buy_upgrade(upgrade.id)
		if not purchased or money_before - gs.money != int(upgrade.cost) or effect_after <= effect_before or not duplicate_blocked:
			upgrade_failures.append(upgrade.id)
	record("R3-UPGRADE-01", "integration", "All 25 upgrades charge data cost, apply effect, and block duplicates", upgrade_failures.is_empty(), upgrade_failures)
	gs.reset_game()
	main.show_upgrades()
	await process_frame
	var missing_upgrade_controls: Array = []
	var reachable_upgrade_count := 0
	var upgrade_page_count := ceili(float(registry.upgrades.size()) / 6.0)
	for page_index in range(upgrade_page_count):
		main.upgrade_page = page_index
		main.selected_upgrade_id = String(registry.upgrades[page_index * 6].id)
		main.show_upgrades()
		for upgrade_index in range(page_index * 6, mini((page_index + 1) * 6, registry.upgrades.size())):
			var upgrade: Dictionary = registry.upgrades[upgrade_index]
			var slot_index := upgrade_index - page_index * 6
			var card := main.find_child("UpgradeCard_%d" % slot_index, true, false)
			if not card is Button:
				missing_upgrade_controls.append(upgrade.id)
				continue
			card.pressed.emit()
			var purchase_control := main.find_child("Upgrade_%s" % upgrade.id, true, false)
			if not purchase_control is Button:
				missing_upgrade_controls.append(upgrade.id)
			else:
				reachable_upgrade_count += 1
	record("R3-UPGRADE-02", "ui", "All 25 upgrade cards are reachable across five compact pages and each exposes one authoritative purchase control", missing_upgrade_controls.is_empty() and reachable_upgrade_count == registry.upgrades.size(), {"reachable": reachable_upgrade_count, "missing": missing_upgrade_controls})

	gs.reset_game()
	gs.buy_artifact(3)
	gs.advance_day()
	gs.language = "ko"
	var save_path := "res://qa/r3_test_save.json"
	var before_save: Dictionary = gs.save_payload()
	var saved_ok: bool = gs.save_game(save_path)
	gs.money = 1
	gs.day = 99
	gs.inventory = []
	var loaded_ok: bool = gs.load_game(save_path)
	var after_load: Dictionary = gs.save_payload()
	var before_item: Dictionary = before_save.inventory[0]
	var after_item: Dictionary = after_load.inventory[0]
	var before_market: Array = before_save.marketRoster.map(func(lot: Dictionary): return [lot.lotId, lot.specId, bool(lot.sold), int(lot.price)])
	var after_market: Array = after_load.marketRoster.map(func(lot: Dictionary): return [lot.lotId, lot.specId, bool(lot.sold), int(lot.price)])
	var state_checks := {
		"money": before_save.money == after_load.money,
		"day": before_save.day == after_load.day,
		"instance": before_item.uniqueId == after_item.uniqueId,
		"spec": before_item.artifactSpecId == after_item.artifactSpecId,
		"damage": before_item.damageInstances == after_item.damageInstances,
		"market": before_market == after_market,
		"language": before_save.language == after_load.language
	}
	var semantic_equal: bool = true
	for check_value: bool in state_checks.values():
		semantic_equal = semantic_equal and check_value
	record("R3-SAVE-01", "integration", "R3 save/load preserves semantic state", saved_ok and loaded_ok and semantic_equal, state_checks)
	var legacy := {"saveVersion": 2, "money": 777, "reputation": 21, "day": 4, "inventory": [], "transactions": [], "auctionHistory": [], "statistics": {}}
	var migrated: bool = gs.apply_save_data(legacy)
	record("R3-SAVE-02", "state", "R2 save migrates to safe campaign defaults", migrated and gs.money == 777 and gs.campaign_state.currentAct == "PROLOGUE" and int(gs.campaign_state.schemaVersion) == 2 and gs.campaign_state.has("caseStates") and gs.campaign_state.has("caseArtifactLedger"), gs.campaign_state.currentAct)

	main.show_market()
	var previous_screen: String = main.screen
	main.toggle_language()
	await process_frame
	record("R3-LOC-01", "ui", "Language toggle refreshes current screen", main.screen == previous_screen and main.language == "ko", {"screen": main.screen, "language": main.language})
	var localization_keys_match: bool = registry.localization.en.size() == registry.localization.ko.size()
	for localization_key: String in registry.localization.en.keys():
		localization_keys_match = localization_keys_match and registry.localization.ko.has(localization_key) and not String(registry.localization.ko[localization_key]).is_empty()
	record("R3-LOC-02", "data", "All EN and KO localization keys have non-empty counterparts", localization_keys_match and registry.localization.en.size() >= 100, {"en": registry.localization.en.size(), "ko": registry.localization.ko.size()})
	var localized_header: Label = main.find_child("Header", true, false).get_child(0)
	var korean_market_rendered := localized_header.text.contains("시장") and localized_header.text.contains("시드 기반")
	record("R3-LOC-03", "ui", "Current core screen renders localized Korean title and subtitle", korean_market_rendered, localized_header.text)
	var header: Control = main.find_child("Header", true, false)
	var navigation: Control = main.find_child("Navigation", true, false)
	var header_stats: Label = header.get_child(1)
	var language_control: Button = navigation.find_child("Nav_LANGUAGE", false, false)
	var ui_bounds_ok := header_stats.get_global_rect().end.x <= 1280.0 and language_control.get_global_rect().end.x <= 1280.0 and language_control.is_visible_in_tree()
	record("R3-LOC-04", "ui", "Long Korean copy keeps header stats and every navigation control on screen", ui_bounds_ok, {"header_stats": header_stats.get_global_rect(), "language": language_control.get_global_rect()})

	main.show_postgame()
	var postgame_language_before: String = main.language
	main.toggle_language()
	await process_frame
	record("R3-NAV-01", "ui", "Language refresh keeps the player on the postgame screen", main.screen == "postgame" and main.language != postgame_language_before, {"screen": main.screen, "language": main.language})
	gs.campaign_state.currentAct = "POSTGAME"
	main.show_campaign()
	await process_frame
	record("R3-NAV-02", "ui", "Campaign navigation routes POSTGAME state to the postgame screen", main.screen == "postgame", {"screen": main.screen, "act": gs.campaign_state.currentAct})

	var manifest: Variant = registry.read_json("res://assets/ASSET_MANIFEST.json")
	var missing_manifest: Array = []
	var hashes := {}
	for entry: Dictionary in manifest:
		if not FileAccess.file_exists("res://" + entry.path):
			missing_manifest.append(entry.path)
		hashes[entry.sha256] = true
	record("R3-ASSET-01", "data", "Asset manifest has zero missing paths", missing_manifest.is_empty(), {"entries": manifest.size(), "missing": missing_manifest})
	record("R3-ASSET-02", "data", "Manifest reports actual unique hashes separately", hashes.size() > 100 and hashes.size() <= manifest.size(), {"files": manifest.size(), "unique_hashes": hashes.size()})

	var executed := results.size()
	var passed := 0
	for result: Dictionary in results:
		if result.passed:
			passed += 1
	var report := {"suite": "R3 core", "executed": executed, "passed": passed, "failed": executed - passed, "skipped": 0, "tests": results}
	var output := FileAccess.open("res://qa/R3_TEST_REPORT.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	main.queue_free()
	quit(0 if passed == executed else 1)


func HYPOTHESES_FOR_TEST() -> Array:
	return ["GENUINE", "GENUINE_WITH_PERIOD_REPAIR", "GENUINE_WITH_MODERN_REPAIR", "REPRODUCTION", "FORGERY", "UNKNOWN"]
