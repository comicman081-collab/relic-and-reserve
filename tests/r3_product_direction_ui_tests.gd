extends SceneTree

## Product-direction regression for the compact journey, player settings,
## sequential Stage replay, causal auction recap and relationship continuity.
## The suite is headless-only and writes no production save or build artifact.

const REPORT_PATH := "res://qa/R3_PRODUCT_DIRECTION_UI_TESTS.json"
const SETTINGS_PATH := "user://relic_reserve_settings.cfg"
const RUN_SAVE_PATH := "user://relic_reserve_save.json"
const PROFILE_PATH := "user://relic_reserve_profile.json"
const TUTORIAL_STEPS := ["INVESTIGATE", "CITE", "REPORT", "REPAIR", "LIST", "AUCTION"]
const WORKFLOW_KEYS := [
	"artifactPresent", "auctionStatus", "caseBound", "caseResolved",
	"hypothesisPrepared", "investigated", "listed", "repairCompleted",
	"repairRequired", "sold", "transactionId"
]

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func settle_ui(frame_count: int = 5) -> void:
	for _frame: int in range(frame_count):
		await process_frame


func sorted_keys(dictionary: Dictionary) -> Array:
	var keys: Array = dictionary.keys()
	keys.sort()
	return keys


func visible_copy(root: Node) -> String:
	var fragments: Array = []
	for label: Node in root.find_children("*", "Label", true, false):
		if label is Label and (label as Label).is_visible_in_tree():
			fragments.append((label as Label).text)
	for button: Node in root.find_children("*", "Button", true, false):
		if button is Button and (button as Button).is_visible_in_tree():
			fragments.append((button as Button).text)
	return "\n".join(fragments)


func visible_named(root: Node, node_name: String, type_name: String = "") -> Node:
	for candidate: Node in root.find_children(node_name, type_name, true, false):
		if candidate is CanvasItem and not (candidate as CanvasItem).is_visible_in_tree():
			continue
		return candidate
	return null


func authority_signature(gs: Node) -> String:
	return JSON.stringify({"run": gs.save_payload(), "profile": gs.profile_payload()})


func schema_shape(value: Variant) -> Variant:
	if value is Dictionary:
		var shape: Dictionary = {}
		for key_value: Variant in (value as Dictionary).keys():
			shape[String(key_value)] = schema_shape((value as Dictionary).get(key_value))
		return shape
	if value is Array:
		return "Array"
	return type_string(typeof(value))


func schema_signature(gs: Node) -> String:
	return JSON.stringify({"run": schema_shape(gs.save_payload()), "profile": schema_shape(gs.profile_payload())})


func read_only_call(gs: Node, callback: Callable) -> Dictionary:
	var authority_before := authority_signature(gs)
	var schema_before := schema_signature(gs)
	var game_rng_before := int(gs.rng.state)
	seed(912367)
	var expected_first := randi()
	var expected_second := randi()
	seed(912367)
	var actual_first := randi()
	var value: Variant = callback.call()
	var actual_second := randi()
	var authority_after := authority_signature(gs)
	var schema_after := schema_signature(gs)
	var game_rng_after := int(gs.rng.state)
	return {
		"value": value,
		"ok": authority_before == authority_after and schema_before == schema_after \
			and game_rng_before == game_rng_after \
			and actual_first == expected_first and actual_second == expected_second,
		"authorityUnchanged": authority_before == authority_after,
		"schemaUnchanged": schema_before == schema_after,
		"gameRngBefore": str(game_rng_before),
		"gameRngAfter": str(game_rng_after),
		"globalRngExpected": [expected_first, expected_second],
		"globalRngActual": [actual_first, actual_second]
	}


func file_snapshot(path: String) -> Dictionary:
	return {
		"path": path,
		"exists": FileAccess.file_exists(path),
		"text": FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	}


func snapshot_matches(snapshot: Dictionary) -> bool:
	var exists_now := FileAccess.file_exists(String(snapshot.path))
	return exists_now == bool(snapshot.exists) \
		and (not exists_now or FileAccess.get_file_as_string(String(snapshot.path)) == String(snapshot.text))


func restore_file_snapshot(snapshot: Dictionary) -> bool:
	var path := String(snapshot.path)
	if bool(snapshot.exists):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return false
		file.store_string(String(snapshot.text))
		file.close()
		return FileAccess.file_exists(path) and FileAccess.get_file_as_string(path) == String(snapshot.text)
	if FileAccess.file_exists(path):
		var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return remove_error == OK and not FileAccess.file_exists(path)
	return true


func rect_evidence(control: Control) -> Dictionary:
	if control == null or not control.is_visible_in_tree():
		return {"ok": false, "rect": []}
	var rect := control.get_global_rect()
	var inside := rect.size.x > 0.0 and rect.size.y > 0.0 \
		and rect.position.x >= -0.5 and rect.position.y >= -0.5 \
		and rect.end.x <= 1280.5 and rect.end.y <= 720.5
	return {"ok": inside, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]}


func non_overlapping_geometry(controls: Array) -> Dictionary:
	var rows: Array = []
	var inside := true
	var separate := true
	for control_value: Variant in controls:
		var control: Control = control_value as Control
		var evidence := rect_evidence(control)
		rows.append(evidence)
		inside = inside and bool(evidence.ok)
	for left_index: int in range(controls.size()):
		for right_index: int in range(left_index + 1, controls.size()):
			var left: Control = controls[left_index] as Control
			var right: Control = controls[right_index] as Control
			if left == null or right == null:
				separate = false
			else:
				separate = separate and not left.get_global_rect().intersects(right.get_global_rect())
	return {"ok": inside and separate, "inside": inside, "separate": separate, "rects": rows}


func contained_geometry(control: Control, container: Control) -> Dictionary:
	if control == null or container == null or not control.is_visible_in_tree() or not container.is_visible_in_tree():
		return {"ok": false, "control": [], "container": []}
	var control_rect := control.get_global_rect()
	var container_rect := container.get_global_rect()
	var contained := control_rect.size.x > 0.0 and control_rect.size.y > 0.0 \
		and control_rect.position.x >= container_rect.position.x - 0.5 \
		and control_rect.position.y >= container_rect.position.y - 0.5 \
		and control_rect.end.x <= container_rect.end.x + 0.5 \
		and control_rect.end.y <= container_rect.end.y + 0.5
	return {
		"ok": contained,
		"control": [control_rect.position.x, control_rect.position.y, control_rect.size.x, control_rect.size.y],
		"container": [container_rect.position.x, container_rect.position.y, container_rect.size.x, container_rect.size.y]
	}


func primary_button_names(root: Node) -> Array:
	var names: Array = []
	for candidate: Node in root.find_children("*", "Button", true, false):
		if candidate is Button and (candidate as Button).is_visible_in_tree() \
				and String((candidate as Button).get_meta("ui_role", "")) == "primary":
			names.append(String(candidate.name))
	names.sort()
	return names


func configure_stage_run(gs: Node, stage_id: int, tutorial_steps: Array = TUTORIAL_STEPS) -> void:
	gs.reset_game()
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	gs.current_stage = stage_id
	gs.stage_run_state = gs.default_stage_run_state(stage_id)
	gs.stage_run_state.status = "RUNNING"
	gs.stage_run_state.tutorialCompletedSteps = tutorial_steps.duplicate()
	gs.player_profile = gs.default_player_profile()
	gs.player_profile.tutorialCompletedSteps = tutorial_steps.duplicate()


func listed_artifact(gs: Node, unique_id: String, opening: int, reserve: int) -> Dictionary:
	var artifact: Dictionary = gs.new_artifact("artifact_001", 88101, unique_id)
	artifact.playerHypothesis = gs.truth_to_hypothesis(String(artifact.authenticityTruth))
	artifact.confidence = 0.94
	artifact.cleanliness = 100.0
	artifact.surfaceCondition = 100.0
	artifact.mechanicalCondition = 100.0
	artifact.knownClues = ["PROVENANCE"]
	gs.inventory.append(artifact)
	var appraisal := int(gs.appraise(artifact))
	gs.list_auction(artifact, opening, reserve, float(artifact.confidence), "CERTAIN", appraisal)
	return artifact


func advance_to_terminal(main: Node) -> Array:
	var phases: Array = []
	for _step: int in range(20):
		var cue_value: Variant = main.call("auction_public_cue_state")
		var cue: Dictionary = cue_value if cue_value is Dictionary else {}
		if cue.is_empty():
			break
		phases.append(String(cue.get("phase", "")))
		if bool(cue.get("isFinal", false)):
			break
		main.call("advance_auction_cue")
		await settle_ui(3)
	return phases


func discover_all_case_evidence(gs: Node, case_id: String) -> void:
	for _pass: int in range(16):
		var progressed := false
		for evidence_value: Variant in gs.get_case_public_state(case_id).get("availableEvidence", []):
			if not evidence_value is Dictionary:
				continue
			var evidence: Dictionary = evidence_value
			var required_tools: Array = evidence.get("requiredTools", []) if evidence.get("requiredTools", []) is Array else []
			if not required_tools.is_empty():
				gs.select_tool(String(required_tools[0]))
			var discovery: Dictionary = gs.discover_case_evidence(case_id, String(evidence.get("id", "")))
			if bool(discovery.get("ok", false)):
				progressed = true
		if not progressed:
			break


func settings_geometry(main: Node) -> Dictionary:
	var grid := visible_named(main, "SettingsGrid", "GridContainer") as GridContainer
	var back := visible_named(main, "SettingsBack", "Button") as Button
	var required_names := [
		"SettingsMaster_0", "SettingsMusic_2", "SettingsEffects_3",
		"SettingsText_116", "SettingsMotionReduced", "SettingsDisplayToggle"
	]
	var required_controls: Array = []
	for node_name: String in required_names:
		var control := visible_named(main, node_name, "Button") as Button
		if control != null:
			required_controls.append(control)
	var panels: Array = []
	if grid != null:
		for child: Node in grid.get_children():
			if child is Control:
				panels.append(child)
	var panel_geometry := non_overlapping_geometry(panels)
	var required_geometry := non_overlapping_geometry(required_controls)
	return {
		"ok": grid != null and back != null and grid.columns == 2 and panels.size() == 6 \
			and required_controls.size() == required_names.size() \
			and bool(rect_evidence(grid).ok) and bool(rect_evidence(back).ok) \
			and bool(panel_geometry.ok) and bool(required_geometry.inside),
		"grid": rect_evidence(grid),
		"back": rect_evidence(back),
		"panelCount": panels.size(),
		"requiredCount": required_controls.size(),
		"panels": panel_geometry,
		"required": required_geometry
	}


func dense_inventory_geometry(main: Node) -> Dictionary:
	var content := visible_named(main, "ContentMargin", "MarginContainer") as MarginContainer
	var journey := visible_named(main, "JourneyRail", "PanelContainer") as PanelContainer
	var receipt_heading := visible_named(main, "InventoryAuctionReceiptHeading", "Label") as Label
	var receipt := visible_named(main, "InventoryAuctionReceiptRecap", "GridContainer") as GridContainer
	var progress := visible_named(main, "InventoryProgress", "Label") as Label
	var grid := visible_named(main, "InventoryGrid", "GridContainer") as GridContainer
	var detail := visible_named(main, "InventoryDetailPanel", "PanelContainer") as PanelContainer
	var inspect := visible_named(main, "InspectLot_*", "Button") as Button
	var navigation := visible_named(main, "Navigation", "Control") as Control
	var content_sequence: Array = [receipt, progress, grid, detail]
	var bounded_sequence: Array = content_sequence.duplicate()
	bounded_sequence.append(navigation)
	var sequence_geometry := non_overlapping_geometry(bounded_sequence)
	var containment: Array = []
	var all_contained := content != null
	for control_value: Variant in content_sequence:
		var control := control_value as Control
		var row := contained_geometry(control, content)
		containment.append(row)
		all_contained = all_contained and bool(row.ok)
	var card_geometry: Array = []
	var cards_ok := grid != null
	for card_index: int in range(8):
		var card := visible_named(main, "InventoryCard_%d" % card_index, "Button") as Button
		var card_row := contained_geometry(card, grid)
		card_geometry.append(card_row)
		cards_ok = cards_ok and card != null and bool(card_row.ok)
	var inspect_in_detail := contained_geometry(inspect, detail)
	var dense_chrome_suppressed := journey == null and receipt_heading == null
	var present := content_sequence.all(func(control_value: Variant): return control_value != null) \
		and navigation != null and inspect != null and dense_chrome_suppressed
	return {
		"ok": present and receipt.get_child_count() == 3 and grid.get_child_count() == 8 \
			and cards_ok and bool(inspect_in_detail.ok) and all_contained \
			and bool(sequence_geometry.ok) and bool(rect_evidence(navigation).ok),
		"sequence": sequence_geometry,
		"containment": containment,
		"cards": card_geometry,
		"cardCount": grid.get_child_count() if grid != null else -1,
		"receiptChildren": receipt.get_child_count() if receipt != null else -1,
		"journeySuppressed": journey == null,
		"receiptHeadingSuppressed": receipt_heading == null,
		"inspectInDetail": inspect_in_detail,
		"navigation": rect_evidence(navigation)
	}


func visible_auction_price_grid(main: Node) -> GridContainer:
	for candidate_value: Variant in main.find_children("*", "GridContainer", true, false):
		var candidate := candidate_value as GridContainer
		if candidate != null and candidate.is_visible_in_tree() \
				and String(candidate.name) != "AuctionCausalRecap" \
				and candidate.columns == 3 and candidate.get_child_count() == 3:
			return candidate
	return null


func terminal_auction_geometry(main: Node, expected_cta_name: String) -> Dictionary:
	var content := visible_named(main, "ContentMargin", "MarginContainer") as MarginContainer
	var journey := visible_named(main, "JourneyRail", "PanelContainer") as PanelContainer
	var primary_state := visible_named(main, "AuctionPrimaryState", "PanelContainer") as PanelContainer
	var primary_action := visible_named(main, "AuctionPrimaryAction", "VBoxContainer") as VBoxContainer
	var cta := visible_named(main, expected_cta_name, "Button") as Button
	var cue := visible_named(main, "AuctionCuePanel", "PanelContainer") as PanelContainer
	var price := visible_auction_price_grid(main)
	var reason := visible_named(main, "AuctionReasonChips", "HFlowContainer") as HFlowContainer
	var result := visible_named(main, "AuctionResultFact", "Label") as Label
	var recap := visible_named(main, "AuctionCausalRecap", "GridContainer") as GridContainer
	var navigation := visible_named(main, "Navigation", "Control") as Control
	var content_controls: Array = [primary_state, primary_action, cue, price, reason, result, recap]
	var bounded_controls: Array = content_controls.duplicate()
	bounded_controls.append(navigation)
	var non_overlap := non_overlapping_geometry(bounded_controls)
	var containment: Array = []
	var all_contained := content != null
	for control_value: Variant in content_controls:
		var control := control_value as Control
		var row := contained_geometry(control, content)
		containment.append(row)
		all_contained = all_contained and bool(row.ok)
	var cta_containment := contained_geometry(cta, primary_action)
	var cue_state: Dictionary = main.auction_public_cue_state()
	var visible_bids_value: Variant = cue_state.get("visibleBids", [])
	var visible_bids: Array = visible_bids_value if visible_bids_value is Array else []
	var primary_copy := visible_named(main, "AuctionPrimaryText", "Label") as Label
	var present := content_controls.all(func(control_value: Variant): return control_value != null) \
		and navigation != null and cta != null and primary_copy != null and journey == null
	return {
		"ok": present and String(cue_state.get("phase", "")) in ["SOLD", "NO_SALE"] \
			and recap.get_child_count() == 3 and String(cta.get_meta("ui_role", "")) == "primary" \
			and bool(cta_containment.ok) and all_contained and bool(non_overlap.ok) \
			and bool(rect_evidence(navigation).ok),
		"phase": cue_state.get("phase", ""),
		"visibleBidCount": visible_bids.size(),
		"journeySuppressed": journey == null,
		"primaryCopy": primary_copy.text if primary_copy != null else "",
		"cta": expected_cta_name,
		"nonOverlap": non_overlap,
		"containment": containment,
		"ctaContainment": cta_containment,
		"recapChildren": recap.get_child_count() if recap != null else -1,
		"navigation": rect_evidence(navigation)
	}


func run() -> void:
	var preserved_files := [
		file_snapshot(SETTINGS_PATH), file_snapshot(SETTINGS_PATH + ".tmp"), file_snapshot(SETTINGS_PATH + ".bak")
	]
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.persistence_enabled = false
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await settle_ui()

	# Representative primary hierarchy begins at the title and is completed by
	# Settings and both pre-terminal/terminal auction states below.
	main.show_title()
	await settle_ui(3)
	var title_primary := primary_button_names(main)

	# Exact whitelist plus one read-only projection boundary.
	configure_stage_run(gs, 2)
	main.selected = {}
	var empty_facts_call := read_only_call(gs, Callable(gs, "workflow_public_facts").bind(""))
	var empty_facts: Dictionary = empty_facts_call.value if empty_facts_call.value is Dictionary else {}
	var forbidden_workflow_keys := [
		"authenticityTruth", "trueRarity", "trueHistoricalSignificance", "trueMarketBaseline",
		"seed", "masterSeed", "rng", "bidders", "maxBid", "winnerId", "estimatedValue"
	]
	var whitelist_ok := sorted_keys(empty_facts) == WORKFLOW_KEYS \
		and forbidden_workflow_keys.all(func(key_value: Variant): return not empty_facts.has(String(key_value)))
	record(
		"PRODUCT-DIRECTION-01",
		"The journey projection has an exact public whitelist and consumes no save, schema, game RNG or global RNG state",
		whitelist_ok and bool(empty_facts_call.ok),
		{"keys": sorted_keys(empty_facts), "expected": WORKFLOW_KEYS, "forbidden": forbidden_workflow_keys, "readOnly": empty_facts_call}
	)

	# State-derived journey: none -> inspect -> decide -> preserve -> list -> auction.
	var phase_rows: Array = []
	var phase_pure := true
	var phase_call := read_only_call(gs, Callable(main, "journey_phase_index").bind("workshop"))
	phase_rows.append({"state": "no artifact", "phase": phase_call.value})
	phase_pure = phase_pure and bool(phase_call.ok)
	var journey_artifact: Dictionary = gs.new_artifact("artifact_001", 88001, "product_direction_journey")
	journey_artifact.damageInstances = ["CRACK"]
	gs.inventory.append(journey_artifact)
	main.selected = journey_artifact
	phase_call = read_only_call(gs, Callable(main, "journey_phase_index").bind("workshop"))
	phase_rows.append({"state": "found", "phase": phase_call.value})
	phase_pure = phase_pure and bool(phase_call.ok)
	journey_artifact.inspected = true
	phase_call = read_only_call(gs, Callable(main, "journey_phase_index").bind("inspection"))
	phase_rows.append({"state": "investigated", "phase": phase_call.value})
	phase_pure = phase_pure and bool(phase_call.ok)
	journey_artifact.playerHypothesis = "GENUINE"
	phase_call = read_only_call(gs, Callable(main, "journey_phase_index").bind("authentication"))
	phase_rows.append({"state": "decision", "phase": phase_call.value})
	phase_pure = phase_pure and bool(phase_call.ok)
	journey_artifact.repaired = true
	journey_artifact.damageInstances = []
	phase_call = read_only_call(gs, Callable(main, "journey_phase_index").bind("inspection"))
	phase_rows.append({"state": "preserved", "phase": phase_call.value})
	phase_pure = phase_pure and bool(phase_call.ok)
	gs.list_auction(journey_artifact, 10, 20, 0.8, "UNCERTAIN", 30)
	phase_call = read_only_call(gs, Callable(main, "journey_phase_index").bind("appraisal"))
	phase_rows.append({"state": "listed", "phase": phase_call.value})
	phase_pure = phase_pure and bool(phase_call.ok)
	var journey_phases := phase_rows.map(func(row_value: Variant): return int((row_value as Dictionary).phase))
	record(
		"PRODUCT-DIRECTION-02",
		"The six-step journey advances from authoritative public facts rather than the current screen name",
		journey_phases == [0, 1, 2, 3, 4, 5] and phase_pure,
		{"rows": phase_rows, "phases": journey_phases, "expected": [0, 1, 2, 3, 4, 5], "readOnly": phase_pure}
	)

	# An active tutorial replaces the journey rail; completing the six authored
	# steps restores exactly one journey rail.
	configure_stage_run(gs, 1, [])
	main.language = "ko"
	main.selected = {}
	main.show_campaign()
	await settle_ui()
	var active_tutorial_count := main.find_children("TutorialGuidanceRail", "PanelContainer", true, false).filter(func(node_value: Variant): return (node_value as CanvasItem).is_visible_in_tree()).size()
	var active_journey_count := main.find_children("JourneyRail", "PanelContainer", true, false).filter(func(node_value: Variant): return (node_value as CanvasItem).is_visible_in_tree()).size()
	gs.stage_run_state.tutorialCompletedSteps = TUTORIAL_STEPS.duplicate()
	gs.player_profile.tutorialCompletedSteps = TUTORIAL_STEPS.duplicate()
	main.show_campaign()
	await settle_ui()
	var completed_tutorial_count := main.find_children("TutorialGuidanceRail", "PanelContainer", true, false).filter(func(node_value: Variant): return (node_value as CanvasItem).is_visible_in_tree()).size()
	var completed_journey_count := main.find_children("JourneyRail", "PanelContainer", true, false).filter(func(node_value: Variant): return (node_value as CanvasItem).is_visible_in_tree()).size()
	record(
		"PRODUCT-DIRECTION-03",
		"Tutorial guidance and the persistent journey rail are mutually exclusive in both active and completed guidance states",
		active_tutorial_count == 1 and active_journey_count == 0 \
			and completed_tutorial_count == 0 and completed_journey_count == 1,
		{"active": {"tutorial": active_tutorial_count, "journey": active_journey_count}, "completed": {"tutorial": completed_tutorial_count, "journey": completed_journey_count}}
	)

	# Settings layout in both locales, including the maximum authored text size.
	main.ui_text_scale = 1.0
	main.reduced_motion = false
	main.language = "ko"
	main.show_settings()
	await settle_ui()
	var ko_settings_geometry := settings_geometry(main)
	var ko_settings_copy := visible_copy(main)
	var ko_exposure := ["전체 음량", "배경 음악", "효과음", "글자 크기", "초상화 움직임"].all(func(copy_value: Variant): return ko_settings_copy.contains(String(copy_value)))
	var settings_primary := primary_button_names(main)
	record(
		"PRODUCT-DIRECTION-04",
		"Korean Settings exposes Master, music, effects, text and reduced-motion controls within 1280x720",
		bool(ko_settings_geometry.ok) and ko_exposure,
		{"geometry": ko_settings_geometry, "copy": ko_settings_copy, "primary": settings_primary}
	)

	main.ui_text_scale = 1.16
	main.language = "en"
	main.show_settings()
	await settle_ui()
	var en_settings_geometry := settings_geometry(main)
	var en_settings_copy := visible_copy(main)
	var en_exposure := ["MASTER", "MUSIC", "EFFECTS", "TEXT SIZE", "PORTRAIT MOTION"].all(func(copy_value: Variant): return en_settings_copy.contains(String(copy_value)))
	record(
		"PRODUCT-DIRECTION-05",
		"English Settings remains inside 1280x720 at the maximum 116 percent text size",
		bool(en_settings_geometry.ok) and en_exposure,
		{"geometry": en_settings_geometry, "copy": en_settings_copy}
	)

	# ConfigFile writes are isolated from authoritative run/profile schema and RNG.
	gs.persistence_enabled = false
	var settings_authority_before := authority_signature(gs)
	var settings_schema_before := schema_signature(gs)
	var settings_rng_before := int(gs.rng.state)
	var run_disk_before := file_snapshot(RUN_SAVE_PATH)
	var profile_disk_before := file_snapshot(PROFILE_PATH)
	main.language = "ko"
	main.set_audio_setting("master", -12.0)
	main.set_audio_setting("music", -20.0)
	main.set_audio_setting("effects", -12.0)
	main.set_text_scale_from_ui(1.16)
	main.set_reduced_motion_from_ui(true)
	await settle_ui()
	var settings_config := ConfigFile.new()
	var settings_load_error := settings_config.load(SETTINGS_PATH)
	var config_contract := settings_load_error == OK \
		and is_equal_approx(float(settings_config.get_value("audio", "master_db", 99.0)), -12.0) \
		and is_equal_approx(float(settings_config.get_value("audio", "music_db", 99.0)), -20.0) \
		and is_equal_approx(float(settings_config.get_value("audio", "effects_db", 99.0)), -12.0) \
		and is_equal_approx(float(settings_config.get_value("accessibility", "text_scale", 0.0)), 1.16) \
		and bool(settings_config.get_value("accessibility", "reduced_motion", false)) \
		and not settings_config.has_section("game") and not settings_config.has_section_key("audio", "schemaVersion")
	var audio_routes_ok := AudioServer.get_bus_index("Master") >= 0 \
		and AudioServer.get_bus_index("BGM") >= 0 and AudioServer.get_bus_index("SFX") >= 0 \
		and String(main.bgm.bus) == "BGM" and String(main.audio.bus) == "SFX"
	var settings_read_only := settings_authority_before == authority_signature(gs) \
		and settings_schema_before == schema_signature(gs) and settings_rng_before == int(gs.rng.state) \
		and snapshot_matches(run_disk_before) and snapshot_matches(profile_disk_before)
	record(
		"PRODUCT-DIRECTION-06",
		"Player settings persist in a separate ConfigFile while run/profile files, save schema and RNG remain untouched",
		config_contract and audio_routes_ok and settings_read_only,
		{"configLoad": settings_load_error, "configContract": config_contract, "audioRoutes": audio_routes_ok, "authorityUnchanged": settings_authority_before == authority_signature(gs), "schemaUnchanged": settings_schema_before == schema_signature(gs), "rngBefore": str(settings_rng_before), "rngAfter": str(int(gs.rng.state)), "runDiskUnchanged": snapshot_matches(run_disk_before), "profileDiskUnchanged": snapshot_matches(profile_disk_before)}
	)

	# Replay selection must never provide a shortcut into a merely unlocked but
	# uncleared Stage.
	configure_stage_run(gs, 1)
	gs.player_profile.highestUnlockedStage = 3
	gs.player_profile.clearedStages = [1]
	gs.player_profile.stageBest = {"1": 72.0}
	main.language = "ko"
	main.show_stage_select()
	await settle_ui()
	var enabled_stage_ids: Array = []
	var stage_rows: Array = []
	for stage_id: int in range(1, 11):
		var stage_button := visible_named(main, "StageSelect_%02d" % stage_id, "Button") as Button
		if stage_button != null and not stage_button.disabled:
			enabled_stage_ids.append(stage_id)
		stage_rows.append({"stage": stage_id, "present": stage_button != null, "disabled": stage_button.disabled if stage_button != null else null, "copy": stage_button.text if stage_button != null else ""})
	var highest_uncleared := visible_named(main, "StageSelect_03", "Button") as Button
	record(
		"PRODUCT-DIRECTION-07",
		"Stage Select enables cleared replay only and keeps the highest unlocked uncleared Stage on the main-story route",
		enabled_stage_ids == [1] and highest_uncleared != null and highest_uncleared.disabled \
			and highest_uncleared.text.contains("본편 잠김"),
		{"enabledStages": enabled_stage_ids, "highestUnlocked": 3, "cleared": [1], "rows": stage_rows}
	)

	# Pre-terminal auction UI exposes only public bids seen so far. The causal
	# three-tile recap appears only after the frozen terminal cue is visible.
	configure_stage_run(gs, 2)
	main.language = "en"
	main.reset_auction_cue_sequence()
	var auction_artifact := listed_artifact(gs, "product_direction_auction", 1, 5)
	var pending: Dictionary = gs.create_pending_auction(auction_artifact)
	main.load_artifact(auction_artifact)
	main.show_auction()
	await settle_ui()
	var entry_cue: Dictionary = main.auction_public_cue_state()
	var visible_bids_value: Variant = entry_cue.get("visibleBids", [])
	var visible_bids: Array = visible_bids_value if visible_bids_value is Array else []
	var entry_tile_nodes: Array = []
	for node_value: Variant in main.find_children("*", "", true, false):
		if node_value is Node and String((node_value as Node).name).contains("CaseTile"):
			entry_tile_nodes.append({
				"name": String((node_value as Node).name),
				"type": (node_value as Node).get_class(),
				"visible": (node_value as CanvasItem).is_visible_in_tree() if node_value is CanvasItem else null,
				"text": String((node_value as Label).text) if node_value is Label else ""
			})
	# Use the exact authored child name. `find_children(..., "Label")` is not
	# reliable for this freshly constructed nested tile on the headless backend,
	# while the same exact lookup is the established listing/auction UI contract.
	var bid_summary := main.find_child("CaseTileSummary_report", true, false) as Label
	# `advance_to_terminal()` rebuilds the whole screen and frees this entry-cue
	# node, so freeze only its public presentation before advancing.
	var entry_bid_summary_present := bid_summary != null
	var entry_bid_summary_visible := bid_summary != null and bid_summary.is_visible_in_tree()
	var entry_bid_summary_text := bid_summary.text if bid_summary != null else ""
	var preterminal_recap := visible_named(main, "AuctionCausalRecap", "GridContainer")
	var full_result_bids: Array = gs.pending_auction_public_state().get("result", {}).get("bids", [])
	var auction_entry_primary := primary_button_names(main)
	var auction_phases := await advance_to_terminal(main)
	var terminal_recap := visible_named(main, "AuctionCausalRecap", "GridContainer") as GridContainer
	var terminal_primary := primary_button_names(main)
	var terminal_read_only_call := read_only_call(gs, Callable(main, "auction_causal_recap_data"))
	var terminal_data: Dictionary = terminal_read_only_call.value if terminal_read_only_call.value is Dictionary else {}
	record(
		"PRODUCT-DIRECTION-08",
		"Before the terminal cue the recap is hidden and bid count equals visibleBids; terminal state adds one read-only three-link causal recap",
		bool(pending.get("ok", false)) and preterminal_recap == null and entry_bid_summary_present and entry_bid_summary_visible \
			and entry_bid_summary_text == str(visible_bids.size()) and full_result_bids.size() >= visible_bids.size() \
			and terminal_recap != null and terminal_recap.get_child_count() == 3 \
			and not terminal_data.is_empty() and bool(terminal_read_only_call.ok),
		{"entryPhase": entry_cue.get("phase", ""), "visibleBidCount": visible_bids.size(), "renderedBidCount": entry_bid_summary_text, "entryTileNodes": entry_tile_nodes, "frozenResultBidCount": full_result_bids.size(), "preterminalRecap": preterminal_recap != null, "phases": auction_phases, "terminalChildren": terminal_recap.get_child_count() if terminal_recap != null else -1, "terminalData": terminal_data, "readOnly": terminal_read_only_call, "primaryEntry": auction_entry_primary, "primaryTerminal": terminal_primary}
	)

	# Resolve an actual authored case, then verify the 96x120 approved portrait and
	# semantic response are presentation-only across KO/EN refreshes.
	configure_stage_run(gs, 1)
	var case_id := "prologue_clock"
	var case_artifact: Dictionary = gs.begin_case(case_id)
	discover_all_case_evidence(gs, case_id)
	var case_definition: Dictionary = gs.case_definition(case_id)
	var canonical_hypothesis := String(case_definition.get("canonical_hypothesis_id", ""))
	gs.set_case_hypothesis(case_id, canonical_hypothesis)
	var citations: Array = []
	for evidence_value: Variant in gs.get_case_public_state(case_id).get("discoveredEvidence", []):
		if evidence_value is Dictionary:
			var evidence_id := String((evidence_value as Dictionary).get("id", ""))
			if not evidence_id.is_empty():
				citations.append(evidence_id)
				gs.toggle_case_citation(case_id, evidence_id)
	var resolution: Dictionary = gs.resolve_case_v2(case_id, canonical_hypothesis, citations)
	main.selected = case_artifact
	main.load_artifact(case_artifact)
	var relationship_authority_before := authority_signature(gs)
	var relationship_rng_before := int(gs.rng.state)
	main.language = "ko"
	main.show_case_dossier(case_id)
	await settle_ui()
	var reaction_panel := visible_named(main, "CaseRelationshipReaction", "PanelContainer") as PanelContainer
	var reaction_portrait := visible_named(main, "CaseRelationshipPortrait", "TextureRect") as TextureRect
	var positive_semantic := visible_named(main, "CaseRelationshipSemantic_POSITIVE", "Label") as Label
	var ko_relationship_copy := visible_copy(reaction_panel) if reaction_panel != null else ""
	var npc_id := String(registry.get_case(case_id).get("npcId", ""))
	var presentation: Dictionary = registry.authored_npc_portrait_presentation(npc_id, "positive")
	var approved_asset_path := String(presentation.get("asset_path", ""))
	var approved_svg := FileAccess.get_file_as_string(approved_asset_path) if not approved_asset_path.is_empty() else ""
	var portrait_minimum := reaction_portrait.custom_minimum_size if reaction_portrait != null else Vector2.ZERO
	var reaction_panel_present := reaction_panel != null
	var positive_semantic_present := positive_semantic != null
	var portrait_approved := reaction_portrait != null and portrait_minimum == Vector2(96, 120) \
		and reaction_portrait.texture != null and not approved_asset_path.is_empty() \
		and String(reaction_portrait.texture.resource_path) == approved_asset_path \
		and approved_svg.contains("data-eye-system=\"sclera-iris-pupil-highlight\"")
	main.language = "en"
	main.show_case_dossier(case_id)
	await settle_ui()
	var en_reaction_panel := visible_named(main, "CaseRelationshipReaction", "PanelContainer") as PanelContainer
	var en_relationship_copy := visible_copy(en_reaction_panel) if en_reaction_panel != null else ""
	var relationship_read_only := relationship_authority_before == authority_signature(gs) and relationship_rng_before == int(gs.rng.state)
	record(
		"PRODUCT-DIRECTION-09",
		"A resolved authored case renders an approved face-legible 96x120 relationship portrait and localized semantic response without mutating authority",
		bool(resolution.get("ok", false)) and String(resolution.get("outcome", "")) in ["masterful", "credible"] \
			and reaction_panel_present and positive_semantic_present and portrait_approved \
			and ko_relationship_copy.contains("꼼꼼한 근거로 신뢰가 깊어졌습니다.") \
			and en_relationship_copy.contains("Trust grew through careful evidence.") \
			and not ko_relationship_copy.contains("POSITIVE") and not en_relationship_copy.contains("POSITIVE") \
			and relationship_read_only,
		{"resolution": resolution, "npcId": npc_id, "asset": approved_asset_path, "portraitApproved": portrait_approved, "minimumSize": [portrait_minimum.x, portrait_minimum.y], "ko": ko_relationship_copy, "en": en_relationship_copy, "readOnly": relationship_read_only}
	)

	# Stage is progression; Act remains a separate story breadcrumb. Primary role
	# metadata must select exactly the commit action on representative screens.
	gs.reset_game()
	gs.persistence_enabled = false
	gs.player_profile = gs.default_player_profile()
	gs.player_profile.highestUnlockedStage = 4
	gs.player_profile.clearedStages = [1, 2, 3]
	gs.player_profile.tutorialCompletedSteps = TUTORIAL_STEPS.duplicate()
	var stage_started: Dictionary = gs.new_game(4)
	main.language = "en"
	main.ui_text_scale = 1.0
	main.reduced_motion = false
	main.show_campaign()
	await settle_ui()
	var header := visible_named(main, "Header", "Control") as Control
	var header_labels: Array = header.find_children("*", "Label", true, false) if header != null else []
	var header_title := String((header_labels[0] as Label).text) if not header_labels.is_empty() else ""
	var story_breadcrumb := visible_named(main, "CampaignStoryBreadcrumb", "Label") as Label
	var act_title := String(main.friendly_act_title(String(gs.campaign_state.get("currentAct", ""))))
	var title_and_breadcrumb_separate := bool(stage_started.get("ok", false)) \
		and header_title.begins_with("STAGE 4 — ") and not header_title.contains("STORY ·") \
		and story_breadcrumb != null and story_breadcrumb.text == "STORY · %s" % act_title \
		and not story_breadcrumb.text.contains("STAGE 4")
	var primary_contract := title_primary == ["NewGameButton"] \
		and settings_primary == ["SettingsBack"] \
		and auction_entry_primary == ["AuctionCueNext"] \
		and terminal_primary == ["HammerButton"]
	record(
		"PRODUCT-DIRECTION-10",
		"Campaign keeps Stage title and Act breadcrumb separate while representative screens mark exactly one authoritative primary action",
		title_and_breadcrumb_separate and primary_contract,
		{"stageStarted": stage_started, "header": header_title, "breadcrumb": story_breadcrumb.text if story_breadcrumb != null else "", "act": act_title, "primaryRoles": {"title": title_primary, "settings": settings_primary, "auctionEntry": auction_entry_primary, "auctionTerminal": terminal_primary}}
	)

	# A durable receipt for a sold relic is history, not the active journey. A
	# newly selected relic must start at INSPECT even while A's COMMITTED receipt
	# remains available for audit and restore.
	configure_stage_run(gs, 2)
	main.language = "en"
	gs.language = "en"
	var committed_artifact := listed_artifact(gs, "product_direction_committed_a", 1, 1)
	var committed_pending: Dictionary = gs.create_pending_auction(committed_artifact)
	var committed_transaction_id: String = String(committed_pending.get("transactionId", ""))
	var committed_receipt: Dictionary = gs.commit_pending_auction(committed_transaction_id)
	var committed_public: Dictionary = gs.pending_auction_public_state()
	var next_artifact: Dictionary = gs.new_artifact("artifact_001", 88112, "product_direction_selected_b")
	gs.inventory.append(next_artifact)
	main.load_artifact(next_artifact)
	var selected_b_facts_call := read_only_call(gs, Callable(gs, "workflow_public_facts").bind(String(next_artifact.get("uniqueId", ""))))
	var selected_b_phase_call := read_only_call(gs, Callable(main, "journey_phase_index").bind("workshop"))
	var selected_b_facts: Dictionary = selected_b_facts_call.value if selected_b_facts_call.value is Dictionary else {}
	var committed_a_sold: bool = bool(committed_receipt.get("ok", false)) \
		and String(committed_receipt.get("status", "")) == "COMMITTED" \
		and String(committed_receipt.get("sale_status", "")) == "SOLD"
	var selected_b_contract: bool = String(committed_public.get("status", "")) == "COMMITTED" \
		and String(committed_public.get("artifactId", "")) == String(committed_artifact.get("uniqueId", "")) \
		and bool(selected_b_facts.get("artifactPresent", false)) \
		and not bool(selected_b_facts.get("investigated", true)) \
		and not bool(selected_b_facts.get("sold", true)) \
		and String(selected_b_facts.get("auctionStatus", "")) == "NONE" \
		and String(selected_b_facts.get("transactionId", "x")).is_empty() \
		and int(selected_b_phase_call.value) == 1
	record(
		"PRODUCT-DIRECTION-11",
		"A COMMITTED sale receipt cannot pin newly selected relic B to A's AUCTION journey phase",
		committed_a_sold and selected_b_contract and bool(selected_b_facts_call.ok) and bool(selected_b_phase_call.ok),
		{"commit": committed_receipt, "durablePending": committed_public, "selectedB": selected_b_facts, "phase": selected_b_phase_call.value, "factsReadOnly": selected_b_facts_call, "phaseReadOnly": selected_b_phase_call}
	)

	# Default zeroed relationship rows are placeholders, not met characters.
	# The compass must explicitly communicate that no recurring contact exists.
	configure_stage_run(gs, 2)
	main.selected = {}
	gs.active_workpiece = {}
	main.language = "en"
	gs.language = "en"
	var all_relationships_zero := true
	for relationship_value: Variant in gs.campaign_state.get("relationships", {}).values():
		var relationship_row: Dictionary = relationship_value if relationship_value is Dictionary else {}
		all_relationships_zero = all_relationships_zero \
			and int(relationship_row.get("trust", 0)) == 0 \
			and int(relationship_row.get("relationship", 0)) == 0
	var fresh_strongest_call := read_only_call(gs, Callable(main, "strongest_relationship_public"))
	var fresh_strongest: Dictionary = fresh_strongest_call.value if fresh_strongest_call.value is Dictionary else {}
	var fresh_ui_authority_before: String = authority_signature(gs)
	var fresh_ui_schema_before: String = schema_signature(gs)
	var fresh_ui_rng_before: int = int(gs.rng.state)
	main.show_campaign()
	await settle_ui()
	var fresh_compass := visible_named(main, "RelationshipCompassText", "Label") as Label
	var fresh_compass_copy: String = fresh_compass.text if fresh_compass != null else ""
	var fresh_ui_read_only: bool = fresh_ui_authority_before == authority_signature(gs) \
		and fresh_ui_schema_before == schema_signature(gs) and fresh_ui_rng_before == int(gs.rng.state)
	record(
		"PRODUCT-DIRECTION-12",
		"A fresh profile has no strongest NPC and its relationship compass says that no recurring contact exists",
		all_relationships_zero and bool(fresh_strongest_call.ok) \
			and String(fresh_strongest.get("npcId", "x")).is_empty() \
			and fresh_compass != null and fresh_compass_copy.contains("No recurring contact yet") \
			and not fresh_compass_copy.contains("Dorian") and fresh_ui_read_only,
		{"allRowsZero": all_relationships_zero, "strongest": fresh_strongest, "compass": fresh_compass_copy, "projectionReadOnly": fresh_strongest_call, "uiReadOnly": fresh_ui_read_only}
	)

	# Settings is a presentation overlay. Enter it from a concrete market OFFER,
	# change locale in both directions and serialize: the resumable public mirror
	# must stay byte-for-byte at the origin interaction.
	configure_stage_run(gs, 2)
	main.selected = {}
	main.language = "en"
	gs.language = "en"
	main.ui_text_scale = 1.0
	main.market_character_state = "WELCOME"
	main.market_active_lot_id = ""
	main.market_character_dialogue = ""
	main.market_character_fact = ""
	main.show_market()
	await settle_ui()
	var offer_lot_id: String = String(gs.market_roster[0].get("lotId", "")) if not gs.market_roster.is_empty() else ""
	if not offer_lot_id.is_empty():
		main.preview_market_offer(offer_lot_id)
		await settle_ui()
	var origin_interaction: Dictionary = gs.campaign_state.get("publicInteraction", {}).duplicate(true)
	var origin_authority: String = authority_signature(gs)
	var origin_schema: String = schema_signature(gs)
	var origin_game_rng: int = int(gs.rng.state)
	seed(712931)
	var expected_overlay_first: int = randi()
	var expected_overlay_second: int = randi()
	seed(712931)
	var actual_overlay_first: int = randi()
	main.open_settings_from_ui()
	await settle_ui()
	main.toggle_language()
	await settle_ui()
	main.toggle_language()
	await settle_ui()
	var overlay_mirror: Dictionary = main.sync_public_interaction_state()
	var overlay_payload: Dictionary = gs.save_payload()
	var payload_interaction: Dictionary = overlay_payload.get("campaign", {}).get("publicInteraction", {}).duplicate(true)
	var actual_overlay_second: int = randi()
	var overlay_authority_unchanged: bool = origin_authority == authority_signature(gs)
	var overlay_schema_unchanged: bool = origin_schema == schema_signature(gs)
	var overlay_rng_unchanged: bool = origin_game_rng == int(gs.rng.state) \
		and actual_overlay_first == expected_overlay_first and actual_overlay_second == expected_overlay_second
	var origin_offer_contract: bool = String(origin_interaction.get("screen", "")) == "market" \
		and String(origin_interaction.get("market", {}).get("state", "")) == "OFFER" \
		and String(origin_interaction.get("market", {}).get("lotId", "")) == offer_lot_id
	var overlay_preserved: bool = overlay_mirror == origin_interaction and payload_interaction == origin_interaction
	main.settings_back_from_ui()
	await settle_ui()
	var restored_interaction: Dictionary = gs.campaign_state.get("publicInteraction", {}).duplicate(true)
	var restored_offer: bool = main.screen == "market" and main.market_character_state == "OFFER" \
		and main.market_active_lot_id == offer_lot_id and restored_interaction == origin_interaction
	record(
		"PRODUCT-DIRECTION-13",
		"Settings and locale refresh preserve a market OFFER publicInteraction mirror without save, schema or RNG drift",
		not offer_lot_id.is_empty() and origin_offer_contract and overlay_preserved and restored_offer \
			and overlay_authority_unchanged and overlay_schema_unchanged and overlay_rng_unchanged \
			and main.language == "en" and gs.language == "en",
		{"lotId": offer_lot_id, "origin": origin_interaction, "overlayMirror": overlay_mirror, "payloadMirror": payload_interaction, "restoredMirror": restored_interaction, "restoredScreen": main.screen, "authorityUnchanged": overlay_authority_unchanged, "schemaUnchanged": overlay_schema_unchanged, "gameRngBefore": str(origin_game_rng), "gameRngAfter": str(int(gs.rng.state)), "globalRngExpected": [expected_overlay_first, expected_overlay_second], "globalRngActual": [actual_overlay_first, actual_overlay_second]}
	)

	# Postgame credits remain an in-flow panel at maximum text scale: gallery,
	# actions, credits and global navigation must occupy disjoint bounded regions.
	configure_stage_run(gs, 10)
	var authored_endings_value: Variant = registry.campaign.get("endings", [])
	var authored_endings: Array = authored_endings_value if authored_endings_value is Array else []
	var postgame_ending_id: String = String(authored_endings[0].get("id", "")) if not authored_endings.is_empty() and authored_endings[0] is Dictionary else ""
	gs.campaign_state.currentEnding = postgame_ending_id
	gs.campaign_state.endingUnlocked = [postgame_ending_id] if not postgame_ending_id.is_empty() else []
	gs.campaign_state.postGame = true
	gs.campaign_state.currentAct = "POSTGAME"
	gs.player_profile.highestUnlockedStage = 10
	gs.player_profile.clearedStages = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	main.language = "ko"
	gs.language = "ko"
	main.ui_text_scale = 1.16
	main.postgame_credits_visible = true
	main.show_postgame()
	await settle_ui()
	var postgame_content := visible_named(main, "ContentMargin", "MarginContainer") as MarginContainer
	var postgame_gallery := visible_named(main, "EndingGallery", "GridContainer") as GridContainer
	var postgame_actions := visible_named(main, "PostgameActions", "HBoxContainer") as HBoxContainer
	var postgame_credits := visible_named(main, "CreditsPanel", "PanelContainer") as PanelContainer
	var postgame_navigation := visible_named(main, "Navigation", "Control") as Control
	var postgame_siblings: Array = [postgame_gallery, postgame_actions, postgame_credits, postgame_navigation]
	var postgame_non_overlap: Dictionary = non_overlapping_geometry(postgame_siblings)
	var postgame_containment: Dictionary = {
		"gallery": contained_geometry(postgame_gallery, postgame_content),
		"actions": contained_geometry(postgame_actions, postgame_content),
		"credits": contained_geometry(postgame_credits, postgame_content),
		"navigation": rect_evidence(postgame_navigation)
	}
	var postgame_geometry_ok: bool = postgame_content != null and postgame_gallery != null \
		and postgame_actions != null and postgame_credits != null and postgame_navigation != null \
		and bool(postgame_non_overlap.ok) and bool(postgame_containment.gallery.ok) \
		and bool(postgame_containment.actions.ok) and bool(postgame_containment.credits.ok) \
		and bool(postgame_containment.navigation.ok)
	record(
		"PRODUCT-DIRECTION-14",
		"Postgame credits, ending gallery, actions and navigation remain bounded and non-overlapping at 116 percent text size",
		postgame_geometry_ok,
		{"ending": postgame_ending_id, "nonOverlap": postgame_non_overlap, "containment": postgame_containment}
	)

	# A fully populated Stage Clear card is the densest Campaign state. Its
	# breadcrumb, progress, focus, relationship, result and actions all stay in
	# the fixed content viewport at the maximum supported text scale.
	configure_stage_run(gs, 5)
	gs.player_profile.highestUnlockedStage = 6
	gs.player_profile.clearedStages = [1, 2, 3, 4, 5]
	gs.player_profile.stageBest = {"5": 64.0}
	gs.stage_run_state.status = "CLEARED"
	gs.stage_run_state.stageClearAcknowledged = false
	gs.stage_run_state.score = 64.0
	gs.stage_run_state.lastPerformance = {"current": 64.0, "target": 78.0, "gradeId": "", "metTarget": false, "isNewBest": true, "best": 64.0}
	gs.stage_run_state.stageReplayFeedbackSnapshot = {
		"stage": 5,
		"axes": {
			"investigation": {"value": 42.0, "available": true, "statusCode": "FRAGILE"},
			"preservation": {"value": 71.0, "available": true, "statusCode": "STEADY"},
			"sale": {"value": 55.0, "available": true, "statusCode": "STEADY"}
		},
		"weakest": "investigation",
		"adviceCode": "STRENGTHEN_EVIDENCE"
	}
	gs.stage_run_state.stageReplayTelemetrySnapshot = {
		"stage": 5, "available": true, "investigationActions": 3,
		"investigationRiskActions": 1, "repairToolIdsUsed": ["soft_brush", "precision_screwdriver"],
		"relistCount": 1, "summaryCodes": ["RISK_TAKEN", "RELIST_USED"]
	}
	main.selected = {}
	main.language = "ko"
	gs.language = "ko"
	main.ui_text_scale = 1.16
	main.postgame_credits_visible = false
	var stage_clear_authority_before: String = authority_signature(gs)
	var stage_clear_schema_before: String = schema_signature(gs)
	var stage_clear_rng_before: int = int(gs.rng.state)
	main.show_campaign()
	await settle_ui()
	var stage_clear_content := visible_named(main, "ContentMargin", "MarginContainer") as MarginContainer
	var stage_clear_breadcrumb := visible_named(main, "CampaignStoryBreadcrumb", "Label") as Label
	var stage_clear_progress := visible_named(main, "StageProgressScore", "PanelContainer") as PanelContainer
	var stage_clear_focus := visible_named(main, "StageFocusBar", "PanelContainer") as PanelContainer
	var stage_clear_relationship := visible_named(main, "RelationshipCompass", "PanelContainer") as PanelContainer
	var stage_clear_card := visible_named(main, "StageClearCard", "PanelContainer") as PanelContainer
	var stage_clear_actions := visible_named(main, "StageClearActions", "HBoxContainer") as HBoxContainer
	var stage_clear_navigation := visible_named(main, "Navigation", "Control") as Control
	var stage_clear_content_controls: Array = [stage_clear_breadcrumb, stage_clear_progress, stage_clear_focus, stage_clear_card, stage_clear_actions]
	var stage_clear_bounded_controls: Array = stage_clear_content_controls.duplicate()
	stage_clear_bounded_controls.append(stage_clear_navigation)
	var stage_clear_non_overlap: Dictionary = non_overlapping_geometry(stage_clear_bounded_controls)
	var stage_clear_containment: Array = []
	var stage_clear_all_contained: bool = stage_clear_content != null
	for stage_control_value: Variant in stage_clear_content_controls:
		var stage_control := stage_control_value as Control
		var stage_containment: Dictionary = contained_geometry(stage_control, stage_clear_content)
		stage_clear_containment.append(stage_containment)
		stage_clear_all_contained = stage_clear_all_contained and bool(stage_containment.ok)
	var stage_clear_read_only: bool = stage_clear_authority_before == authority_signature(gs) \
		and stage_clear_schema_before == schema_signature(gs) and stage_clear_rng_before == int(gs.rng.state)
	var stage_clear_geometry_ok: bool = stage_clear_content_controls.all(func(control_value: Variant): return control_value != null) \
		and stage_clear_relationship == null \
		and stage_clear_navigation != null and bool(rect_evidence(stage_clear_navigation).ok) \
		and bool(stage_clear_non_overlap.ok) and stage_clear_all_contained
	record(
		"PRODUCT-DIRECTION-15",
		"A populated Stage Clear Campaign remains bounded and vertically non-overlapping at 116 percent text size",
		stage_clear_geometry_ok and stage_clear_read_only,
		{"relationshipHidden": stage_clear_relationship == null, "nonOverlap": stage_clear_non_overlap, "containment": stage_clear_containment, "navigation": rect_evidence(stage_clear_navigation), "readOnly": stage_clear_read_only}
	)

	# Save validation must fail closed on malformed presentation mirrors. Work
	# exclusively on deep payload copies so neither the live run nor deterministic
	# cursors can be canonicalized as a side effect of validation.
	configure_stage_run(gs, 2)
	var validation_authority_before: String = authority_signature(gs)
	var validation_schema_before: String = schema_signature(gs)
	var validation_rng_before: int = int(gs.rng.state)
	var validation_run_disk_before := file_snapshot(RUN_SAVE_PATH)
	var validation_profile_disk_before := file_snapshot(PROFILE_PATH)
	var validation_settings_disk_before := file_snapshot(SETTINGS_PATH)
	var validation_base: Dictionary = gs.save_payload()
	var validation_lot_id: String = String(gs.market_roster[0].get("lotId", "")) if not gs.market_roster.is_empty() else "market_fixture"
	var valid_payload: Dictionary = validation_base.duplicate(true)
	var valid_campaign: Dictionary = valid_payload.get("campaign", {})
	valid_campaign["publicInteraction"] = {
		"schemaVersion": 1,
		"screen": "market",
		"focusName": "MarketOffer_0",
		"market": {"state": "OFFER", "lotId": validation_lot_id}
	}
	valid_payload["campaign"] = valid_campaign
	var valid_interaction_result: Dictionary = gs.validate_save_payload(valid_payload)
	var invalid_interaction_fixtures: Array = [
		{"name": "string", "value": "market"},
		{"name": "array", "value": ["market"]},
		{"name": "unknown screen", "value": {"schemaVersion": 1, "screen": "developer_console", "focusName": ""}},
		{"name": "invalid market state", "value": {"schemaVersion": 1, "screen": "market", "focusName": "", "market": {"state": "FREE_PURCHASE", "lotId": validation_lot_id}}},
		{"name": "negative auction cue", "value": {"schemaVersion": 1, "screen": "auction", "focusName": "", "auction": {"artifactId": "fixture_artifact", "cueIndex": -1}}},
		{"name": "nonnumeric auction cue", "value": {"schemaVersion": 1, "screen": "auction", "focusName": "", "auction": {"artifactId": "fixture_artifact", "cueIndex": "0"}}}
	]
	var invalid_interaction_rows: Array = []
	var invalid_interactions_fail_closed: bool = true
	for invalid_fixture_value: Variant in invalid_interaction_fixtures:
		var invalid_fixture: Dictionary = invalid_fixture_value as Dictionary
		var invalid_payload: Dictionary = validation_base.duplicate(true)
		var invalid_campaign: Dictionary = invalid_payload.get("campaign", {})
		invalid_campaign["publicInteraction"] = invalid_fixture.get("value")
		invalid_payload["campaign"] = invalid_campaign
		var invalid_result: Dictionary = gs.validate_save_payload(invalid_payload)
		var failed_closed: bool = not bool(invalid_result.get("ok", false)) \
			and String(invalid_result.get("code", "")) == "INVALID_PUBLIC_INTERACTION"
		invalid_interaction_rows.append({"fixture": invalid_fixture.get("name", ""), "result": invalid_result, "failedClosed": failed_closed})
		invalid_interactions_fail_closed = invalid_interactions_fail_closed and failed_closed
	var validation_read_only: bool = validation_authority_before == authority_signature(gs) \
		and validation_schema_before == schema_signature(gs) and validation_rng_before == int(gs.rng.state) \
		and snapshot_matches(validation_run_disk_before) and snapshot_matches(validation_profile_disk_before) \
		and snapshot_matches(validation_settings_disk_before)
	record(
		"PRODUCT-DIRECTION-16",
		"Save validation accepts a shaped public interaction and rejects malformed mirrors with one fail-closed code",
		bool(valid_interaction_result.get("ok", false)) and String(valid_interaction_result.get("code", "")) == "OK" \
			and invalid_interactions_fail_closed and validation_read_only,
		{"valid": valid_interaction_result, "invalid": invalid_interaction_rows, "authorityUnchanged": validation_authority_before == authority_signature(gs), "schemaUnchanged": validation_schema_before == schema_signature(gs), "rngBefore": str(validation_rng_before), "rngAfter": str(int(gs.rng.state)), "runDiskUnchanged": snapshot_matches(validation_run_disk_before), "profileDiskUnchanged": snapshot_matches(validation_profile_disk_before), "settingsDiskUnchanged": snapshot_matches(validation_settings_disk_before)}
	)

	# `repaired` is historical action metadata, not proof that current repairable
	# damage is gone. The rail stays on PRESERVE until the live damage list clears.
	configure_stage_run(gs, 2)
	var preservation_artifact: Dictionary = gs.new_artifact("artifact_001", 88117, "product_direction_preservation")
	preservation_artifact.inspected = true
	preservation_artifact.playerHypothesis = "GENUINE"
	preservation_artifact.damageInstances = ["CRACK"]
	preservation_artifact.repaired = true
	gs.inventory.append(preservation_artifact)
	main.load_artifact(preservation_artifact)
	var damaged_preservation_facts_call := read_only_call(gs, Callable(gs, "workflow_public_facts").bind(String(preservation_artifact.get("uniqueId", ""))))
	var damaged_preservation_phase_call := read_only_call(gs, Callable(main, "journey_phase_index"))
	var damaged_preservation_facts: Dictionary = damaged_preservation_facts_call.value if damaged_preservation_facts_call.value is Dictionary else {}
	var damaged_preservation_contract: bool = bool(damaged_preservation_facts.get("repairRequired", false)) \
		and not bool(damaged_preservation_facts.get("repairCompleted", true)) \
		and int(damaged_preservation_phase_call.value) == 3
	preservation_artifact.damageInstances = []
	main.load_artifact(preservation_artifact)
	var cleared_preservation_facts_call := read_only_call(gs, Callable(gs, "workflow_public_facts").bind(String(preservation_artifact.get("uniqueId", ""))))
	var cleared_preservation_phase_call := read_only_call(gs, Callable(main, "journey_phase_index"))
	var cleared_preservation_facts: Dictionary = cleared_preservation_facts_call.value if cleared_preservation_facts_call.value is Dictionary else {}
	var cleared_preservation_contract: bool = not bool(cleared_preservation_facts.get("repairRequired", true)) \
		and bool(cleared_preservation_facts.get("repairCompleted", false)) \
		and int(cleared_preservation_phase_call.value) == 4
	record(
		"PRODUCT-DIRECTION-17",
		"Current repairable damage overrides stale repaired metadata until preservation is actually complete",
		damaged_preservation_contract and cleared_preservation_contract \
			and bool(damaged_preservation_facts_call.ok) and bool(damaged_preservation_phase_call.ok) \
			and bool(cleared_preservation_facts_call.ok) and bool(cleared_preservation_phase_call.ok),
		{"damaged": {"facts": damaged_preservation_facts, "phase": damaged_preservation_phase_call.value, "factsReadOnly": damaged_preservation_facts_call, "phaseReadOnly": damaged_preservation_phase_call}, "cleared": {"facts": cleared_preservation_facts, "phase": cleared_preservation_phase_call.value, "factsReadOnly": cleared_preservation_facts_call, "phaseReadOnly": cleared_preservation_phase_call}}
	)

	# The densest inventory combines a durable ordinary NO SALE recap, all eight
	# cards and one selected detail. Redundant journey/receipt-heading chrome is
	# deliberately suppressed in this dense state. Render both locales at 116%
	# so the longer copy is necessarily covered rather than guessed.
	configure_stage_run(gs, 2)
	var receipt_artifact := listed_artifact(gs, "product_direction_inventory_receipt", 1, 1000000)
	var receipt_pending: Dictionary = gs.create_pending_auction(receipt_artifact)
	var receipt_commit: Dictionary = gs.commit_pending_auction(String(receipt_pending.get("transactionId", "")))
	for inventory_fixture_index: int in range(7):
		var inventory_fixture: Dictionary = gs.new_artifact("artifact_001", 88200 + inventory_fixture_index, "product_direction_inventory_%d" % inventory_fixture_index)
		gs.inventory.append(inventory_fixture)
	main.load_artifact(receipt_artifact)
	main.inventory_page = 0
	main.inventory_selected_uid = String(receipt_artifact.get("uniqueId", ""))
	main.ui_text_scale = 1.16
	main.language = "ko"
	gs.language = "ko"
	var dense_inventory_authority_before: String = authority_signature(gs)
	var dense_inventory_schema_before: String = schema_signature(gs)
	var dense_inventory_rng_before: int = int(gs.rng.state)
	main.show_inventory()
	await settle_ui()
	var dense_inventory_ko: Dictionary = dense_inventory_geometry(main)
	main.language = "en"
	gs.language = "en"
	main.show_inventory()
	await settle_ui()
	var dense_inventory_en: Dictionary = dense_inventory_geometry(main)
	main.language = "ko"
	gs.language = "ko"
	var dense_inventory_read_only: bool = dense_inventory_authority_before == authority_signature(gs) \
		and dense_inventory_schema_before == schema_signature(gs) and dense_inventory_rng_before == int(gs.rng.state)
	var receipt_public: Dictionary = gs.pending_auction_public_state()
	record(
		"PRODUCT-DIRECTION-18",
		"An eight-card inventory with a committed NO SALE receipt stays bounded and vertically disjoint in KO and EN at 116 percent",
		bool(receipt_commit.get("ok", false)) and String(receipt_commit.get("sale_status", "")) == "NO_SALE" \
			and String(receipt_public.get("status", "")) == "COMMITTED" and gs.inventory.size() == 8 \
			and bool(dense_inventory_ko.ok) and bool(dense_inventory_en.ok) and dense_inventory_read_only,
		{"receipt": receipt_commit, "inventoryCount": gs.inventory.size(), "ko": dense_inventory_ko, "en": dense_inventory_en, "readOnly": dense_inventory_read_only}
	)

	# Ordinary SOLD and NO SALE terminals, then Grand Reserve terminal/BETWEEN,
	# exercise the complete auction hierarchy at maximum text size. Geometry is
	# sampled only after each authoritative transition boundary, so measurement
	# itself must be projection-only.
	configure_stage_run(gs, 2)
	main.language = "ko"
	gs.language = "ko"
	main.ui_text_scale = 1.16
	main.reset_auction_cue_sequence()
	var terminal_sold_artifact := listed_artifact(gs, "product_direction_terminal_sold", 1, 1)
	var terminal_sold_pending: Dictionary = gs.create_pending_auction(terminal_sold_artifact)
	main.load_artifact(terminal_sold_artifact)
	main.show_auction()
	await settle_ui()
	var terminal_sold_phases: Array = await advance_to_terminal(main)
	await settle_ui()
	var terminal_sold_authority_before: String = authority_signature(gs)
	var terminal_sold_schema_before: String = schema_signature(gs)
	var terminal_sold_rng_before: int = int(gs.rng.state)
	var terminal_sold_geometry: Dictionary = terminal_auction_geometry(main, "HammerButton")
	var terminal_sold_read_only: bool = terminal_sold_authority_before == authority_signature(gs) \
		and terminal_sold_schema_before == schema_signature(gs) and terminal_sold_rng_before == int(gs.rng.state)

	configure_stage_run(gs, 2)
	main.language = "ko"
	gs.language = "ko"
	main.ui_text_scale = 1.16
	main.reset_auction_cue_sequence()
	var terminal_no_sale_artifact := listed_artifact(gs, "product_direction_terminal_no_sale", 1, 1000000)
	var terminal_no_sale_pending: Dictionary = gs.create_pending_auction(terminal_no_sale_artifact)
	main.load_artifact(terminal_no_sale_artifact)
	main.show_auction()
	await settle_ui()
	var terminal_no_sale_phases: Array = await advance_to_terminal(main)
	await settle_ui()
	var terminal_no_sale_authority_before: String = authority_signature(gs)
	var terminal_no_sale_schema_before: String = schema_signature(gs)
	var terminal_no_sale_rng_before: int = int(gs.rng.state)
	var terminal_no_sale_geometry: Dictionary = terminal_auction_geometry(main, "HammerButton")
	var terminal_no_sale_read_only: bool = terminal_no_sale_authority_before == authority_signature(gs) \
		and terminal_no_sale_schema_before == schema_signature(gs) and terminal_no_sale_rng_before == int(gs.rng.state)

	gs.reset_game()
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	gs.player_profile = gs.default_player_profile()
	gs.player_profile.highestUnlockedStage = 10
	gs.player_profile.clearedStages = [1, 2, 3, 4, 5, 6, 7, 8, 9]
	gs.player_profile.tutorialCompletedSteps = TUTORIAL_STEPS.duplicate()
	var reserve_started: Dictionary = gs.new_game(10)
	var reserve_case_failures: Array = []
	for reserve_case_value: Variant in registry.get_stage_definition(10).get("case_ids", []):
		var reserve_case_id := String(reserve_case_value)
		if not bool(gs.prepare_case_for_test(reserve_case_id)):
			reserve_case_failures.append(reserve_case_id)
	var reserve_eligible: Array = gs.eligible_final_lots()
	var reserve_lot_uids: Array = []
	for reserve_lot_index: int in range(mini(3, reserve_eligible.size())):
		var reserve_lot: Dictionary = reserve_eligible[reserve_lot_index]
		var reserve_appraisal := maxi(1, int(gs.appraise(reserve_lot)))
		reserve_lot.listing = {"starting": 1, "reserve": 1, "confidence": 0.9, "disclosure": "CERTAIN", "publicAppraisal": reserve_appraisal}
		reserve_lot_uids.append(String(reserve_lot.get("uniqueId", "")))
		gs.select_final_lot(String(reserve_lot.get("uniqueId", "")))
	var reserve_begin: Dictionary = gs.begin_grand_reserve_session()
	var reserve_pending: Dictionary = gs.pending_auction_public_state()
	var reserve_active_artifact: Dictionary = gs.find_inventory_instance(String(reserve_pending.get("artifactId", "")))
	main.language = "ko"
	gs.language = "ko"
	main.ui_text_scale = 1.16
	main.reset_auction_cue_sequence()
	if not reserve_active_artifact.is_empty():
		main.load_artifact(reserve_active_artifact)
		main.show_auction()
		await settle_ui()
	var reserve_terminal_phases: Array = []
	if not reserve_active_artifact.is_empty():
		reserve_terminal_phases = await advance_to_terminal(main)
	await settle_ui()
	var reserve_terminal_authority_before: String = authority_signature(gs)
	var reserve_terminal_schema_before: String = schema_signature(gs)
	var reserve_terminal_rng_before: int = int(gs.rng.state)
	var reserve_terminal_geometry: Dictionary = terminal_auction_geometry(main, "HammerButton") if not reserve_active_artifact.is_empty() else {"ok": false, "code": "NO_ACTIVE_RESERVE_ARTIFACT"}
	var reserve_terminal_read_only: bool = reserve_terminal_authority_before == authority_signature(gs) \
		and reserve_terminal_schema_before == schema_signature(gs) and reserve_terminal_rng_before == int(gs.rng.state)
	var reserve_commit: Dictionary = gs.commit_grand_reserve_lot(String(reserve_pending.get("transactionId", ""))) if bool(reserve_begin.get("ok", false)) else {"ok": false, "code": "RESERVE_NOT_BEGUN"}
	if bool(reserve_commit.get("ok", false)) and String(gs.grand_reserve_public_state().get("phase", "")) == "BETWEEN_LOTS":
		main.show_auction()
		await settle_ui()
	var reserve_between_authority_before: String = authority_signature(gs)
	var reserve_between_schema_before: String = schema_signature(gs)
	var reserve_between_rng_before: int = int(gs.rng.state)
	var reserve_between_geometry: Dictionary = terminal_auction_geometry(main, "GrandReserveNextLot") if String(gs.grand_reserve_public_state().get("phase", "")) == "BETWEEN_LOTS" else {"ok": false, "code": "NOT_BETWEEN_LOTS"}
	var reserve_between_read_only: bool = reserve_between_authority_before == authority_signature(gs) \
		and reserve_between_schema_before == schema_signature(gs) and reserve_between_rng_before == int(gs.rng.state)

	var ordinary_terminal_contract: bool = bool(terminal_sold_pending.get("ok", false)) \
		and String(terminal_sold_pending.get("result", {}).get("sale_status", "")) == "SOLD" \
		and bool(terminal_no_sale_pending.get("ok", false)) \
		and String(terminal_no_sale_pending.get("result", {}).get("sale_status", "")) == "NO_SALE" \
		and bool(terminal_sold_geometry.ok) and bool(terminal_no_sale_geometry.ok) \
		and int(terminal_sold_geometry.get("visibleBidCount", 0)) >= 4 \
		and terminal_sold_read_only and terminal_no_sale_read_only
	var reserve_terminal_contract: bool = bool(reserve_started.get("ok", false)) and reserve_case_failures.is_empty() \
		and reserve_lot_uids.size() == 3 and bool(reserve_begin.get("ok", false)) \
		and bool(reserve_terminal_geometry.get("ok", false)) and reserve_terminal_read_only \
		and bool(reserve_commit.get("ok", false)) and String(gs.grand_reserve_public_state().get("phase", "")) == "BETWEEN_LOTS" \
		and bool(reserve_between_geometry.get("ok", false)) and reserve_between_read_only
	record(
		"PRODUCT-DIRECTION-19",
		"Ordinary SOLD and NO SALE plus Grand Reserve terminal and BETWEEN auction hierarchies remain bounded at 116 percent",
		ordinary_terminal_contract and reserve_terminal_contract,
		{"ordinarySold": {"pending": terminal_sold_pending, "phases": terminal_sold_phases, "geometry": terminal_sold_geometry, "readOnly": terminal_sold_read_only}, "ordinaryNoSale": {"pending": terminal_no_sale_pending, "phases": terminal_no_sale_phases, "geometry": terminal_no_sale_geometry, "readOnly": terminal_no_sale_read_only}, "grandReserve": {"started": reserve_started, "caseFailures": reserve_case_failures, "lotUids": reserve_lot_uids, "begin": reserve_begin, "terminalPhases": reserve_terminal_phases, "terminalGeometry": reserve_terminal_geometry, "terminalReadOnly": reserve_terminal_read_only, "commit": reserve_commit, "betweenGeometry": reserve_between_geometry, "betweenReadOnly": reserve_between_read_only}}
	)

	var restored_files: Array = []
	for snapshot_value: Variant in preserved_files:
		restored_files.append(restore_file_snapshot(snapshot_value as Dictionary))
	var settings_restored := restored_files.all(func(value: Variant): return bool(value))
	if not settings_restored:
		record("PRODUCT-DIRECTION-CLEANUP", "The pre-test player settings files are restored exactly", false, {"restored": restored_files})

	var passed := results.filter(func(result_value: Variant): return bool((result_value as Dictionary).passed)).size()
	var report := {
		"suite": "R3 Product Direction UI",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"skipped": 0,
		"tests": results
	}
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	# Drop RefCounted test helpers before SceneTree shutdown. Quitting while the
	# coroutine still owns ConfigFile/FileAccess references makes Godot report
	# false-positive ObjectDB/resource leaks even though their handles are closed.
	output = null
	settings_config = null
	print(JSON.stringify(report))
	main.queue_free()
	await settle_ui(6)
	main = null
	await settle_ui(2)
	quit(0 if passed == results.size() else 1)
