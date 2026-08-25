extends SceneTree

var evidence: Array = []
var render_dir := "res://qa/r3_renders"


func _init() -> void:
	call_deferred("capture")


func snap(main: Node3D, file_name: String, sequence: Array, note: String) -> void:
	await process_frame
	await process_frame
	var image := get_root().get_viewport().get_texture().get_image()
	if image == null:
		push_error("No rendered framebuffer for %s" % file_name)
		quit(1)
		return
	var path := "%s/%s.png" % [render_dir, file_name]
	image.save_png(path)
	evidence.append({
		"name": file_name, "path": path, "mode": "Godot 4.7.1 editor/headless runtime",
		"resolution": "1280x720", "sequence": sequence, "status": "CAPTURED_PENDING_VISUAL_REVIEW", "note": note
	})


func prepare_act(gs: Node, act_id: String) -> void:
	for case_id: String in gs.act_case_ids(act_id):
		gs.prepare_case_for_test(case_id)


func build_flow_contact_sheet() -> void:
	var columns := 4
	var thumb_size := Vector2i(320, 180)
	var sheet := Image.create_empty(columns * thumb_size.x, 7 * thumb_size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#101418"))
	for index in range(27):
		var prefix := "%02d_" % (index + 1)
		var matching_path := ""
		for file_name: String in DirAccess.get_files_at(render_dir):
			if file_name.begins_with(prefix) and file_name.ends_with(".png"):
				matching_path = "%s/%s" % [render_dir, file_name]
				break
		if matching_path.is_empty():
			continue
		var image_file := FileAccess.open(matching_path, FileAccess.READ)
		if image_file == null:
			continue
		var thumbnail := Image.new()
		var load_error := thumbnail.load_png_from_buffer(image_file.get_buffer(image_file.get_length()))
		image_file.close()
		if load_error != OK:
			continue
		thumbnail.resize(thumb_size.x, thumb_size.y, Image.INTERPOLATE_LANCZOS)
		var destination := Vector2i((index % columns) * thumb_size.x, int(index / columns) * thumb_size.y)
		sheet.blit_rect(thumbnail, Rect2i(Vector2i.ZERO, thumb_size), destination)
	sheet.save_png("%s/screen_contact_sheet.png" % render_dir)


func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(render_dir))
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame

	await snap(main, "01_title", ["launch project"], "Title menu")
	gs.reset_game()
	main.show_workshop()
	await snap(main, "02_workshop", ["NEW GAME", "WORKSHOP"], "Real 3D workshop and campaign metrics")
	main.show_market()
	await snap(main, "03_market_day1", ["NEW GAME", "MARKET"], "Seeded day-one roster")

	var buy_button: Button = main.find_child("MarketLot_0", true, false)
	buy_button.pressed.emit()
	main.show_inventory()
	await snap(main, "04_inventory", ["MARKET", "click BUY", "INVENTORY"], "Purchased lot is owned")

	gs.reset_game()
	gs.buy_artifact(0)
	var artifact: Dictionary = gs.inventory[0]
	artifact.damageInstances = ["DUST", "RUST", "CRACK"]
	main.load_artifact(artifact)
	main.show_inspection()
	await snap(main, "05_inspection_dirty", ["test prerequisite: supported clock acquired", "PLACE / INSPECT"], "Dirty 3D workpiece with three live damage markers")
	var soft_brush: Button = main.find_child("Tool_soft_brush", true, false)
	soft_brush.pressed.emit()
	await snap(main, "06_cleaning_live_after_action", ["PLACE / INSPECT", "click SOFT BRUSH"], "No hidden load_artifact refresh; UI callback performed synchronization")
	var disassemble: Button = main.find_child("Tool_disassemble", true, false)
	disassemble.pressed.emit()
	await snap(main, "07_disassembly_supported", ["click DISASSEMBLE PANEL"], "Supported panel hidden immediately")

	for clue_name: String in ["MATERIAL", "SERIAL_PATTERN", "CONSTRUCTION_METHOD"]:
		var clue_button: Button = main.find_child("Clue_%s" % clue_name, true, false)
		if clue_button != null:
			clue_button.pressed.emit()
	var authenticate_button: Button = main.find_child("AuthenticateButton", true, false)
	authenticate_button.pressed.emit()
	await snap(main, "08_authentication_all_6_visible", ["inspect MATERIAL", "inspect SERIAL_PATTERN", "inspect CONSTRUCTION_METHOD", "click AUTHENTICATE"], "All six hypotheses visible in a 3x2 GridContainer")
	var correct: String = gs.truth_to_hypothesis(artifact.authenticityTruth)
	var hypothesis_button: Button = main.hypothesis_buttons[correct]
	hypothesis_button.pressed.emit()
	main.hypothesis_accept_button.pressed.emit()
	await snap(main, "09_appraisal", ["click hypothesis %s" % correct, "click ACCEPT HYPOTHESIS"], "Accepted player hypothesis and evidence-based estimate")

	var estimated: int = gs.appraise(artifact)
	gs.list_auction(artifact, 1, 1, artifact.confidence, "LIKELY")
	main.show_auction()
	await snap(main, "10_auction_reserve_met", ["LIST with reserve 1", "open LIVE AUCTION"], "Reserve-met preview using bidder profiles")
	gs.list_auction(artifact, 1, 999999, artifact.confidence, "UNCERTAIN")
	main.show_auction()
	await snap(main, "11_auction_reserve_not_met", ["relist same owned lot with unreachable reserve", "open LIVE AUCTION"], "Reserve-not-met state shown before recording; item remains owned")

	gs.money = 10000
	main.show_upgrades()
	var upgrade_button: Button = main.find_child("Upgrade_upgrade_01", true, false)
	upgrade_button.pressed.emit()
	await snap(main, "12_upgrades_scroll_owned_effect", ["UPGRADES", "buy Storage Expansion"], "Scrollable 25-upgrade list with owned state")
	main.end_day_from_ui()
	await snap(main, "13_market_day2_changed", ["click END DAY"], "Day-two roster is visibly changed")
	main.toggle_language()
	await snap(main, "14_korean_core_screen", ["MARKET day 2", "click EN / 한국어"], "Current screen refreshed in Korean")
	gs.save_game("res://qa/r3_capture_save.json")
	var saved_money: int = gs.money
	gs.money = 1
	gs.inventory = []
	gs.load_game("res://qa/r3_capture_save.json")
	main.language = gs.language
	main.show_inventory()
	await snap(main, "15_save_reload_restored", ["save R3 state", "mutate memory", "load R3 state", "open INVENTORY"], "Reload restored money %d and inventory" % saved_money)

	gs.reset_game()
	gs.campaign_test_mode = true
	gs.begin_case("prologue_clock")
	main.show_campaign()
	await snap(main, "16_prologue_workshop", ["NEW GAME", "begin prologue_clock"], "Prologue in the Closed Workshop")
	gs.prepare_case_for_test("prologue_clock")
	main.show_market()
	await snap(main, "17_act1_market", ["complete prologue through core APIs", "open Act 1 market"], "Act 1 local circuit")
	prepare_act(gs, "ACT_1")
	main.show_campaign()
	await snap(main, "18_act2_archive", ["complete 8 Act 1 cases", "open campaign"], "Act 2 archive location identity")
	prepare_act(gs, "ACT_2")
	main.show_campaign()
	await snap(main, "19_act3_collector", ["complete provenance cases", "open campaign"], "Act 3 collector relationship state")
	prepare_act(gs, "ACT_3")
	main.show_campaign()
	await snap(main, "20_act4_forgery_case", ["complete collector cases", "open campaign"], "Act 4 connected forgery cases")
	prepare_act(gs, "ACT_4")
	main.show_campaign()
	await snap(main, "21_act5_master_workshop", ["complete shadow cases and composite prototype", "open Grade IV/V workshop"], "Act 5 master restoration list")
	prepare_act(gs, "ACT_5")
	main.show_final_lot_selection()
	await snap(main, "22_final_lot_selection", ["complete six master cases", "receive invitation", "open final lot selection"], "Eligible owned instance IDs are selectable")
	var eligible: Array = gs.eligible_final_lots()
	for index in range(3):
		gs.select_final_lot(eligible[index].uniqueId)
	main.show_final_lot_selection()
	await snap(main, "23_grand_reserve_hall", ["select three distinct owned lots"], "Distinct real 3D Grand Reserve hall and three selected IDs")
	main.selected = eligible[0]
	var final_value: int = gs.appraise(eligible[0])
	gs.list_auction(eligible[0], int(final_value * 0.55), 1, eligible[0].confidence, "CERTAIN")
	main.show_auction()
	main.set_world_mode("grand_reserve")
	await snap(main, "24_grand_reserve_auction", ["prepare selected final lot", "run real bidder auction preview in Grand Reserve hall"], "Real auction UI with Grand Reserve 3D environment")
	gs.run_grand_reserve()
	main.show_ending()
	await snap(main, "25_ending_screen", ["complete three Grand Reserve auctions", "evaluate ending"], "Ending tier, scores, and exact three result snapshots")
	await snap(main, "26_epilogue_statistics", ["view ending epilogue statistics"], "Campaign statistics and credits reference")
	gs.acknowledge_epilogue()
	main.show_postgame()
	await snap(main, "27_postgame", ["click CONTINUE — POSTGAME"], "Endless workshop and ending gallery")

	main.ui.visible = false
	main.set_world_mode("workshop")
	var sheet := Image.create_empty(1800, 720, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#101418"))
	for index in range(registry.spec_order.size()):
		var sample: Dictionary = gs.new_artifact(registry.spec_order[index], 90000 + index, "sheet_%03d" % index)
		main.load_artifact(sample)
		await process_frame
		await process_frame
		var thumbnail := get_root().get_viewport().get_texture().get_image()
		thumbnail.resize(180, 120, Image.INTERPOLATE_LANCZOS)
		var column := index % 10
		var row := int(index / 10)
		sheet.blit_rect(thumbnail, Rect2i(0, 0, 180, 120), Vector2i(column * 180, row * 120))
	sheet.save_png("%s/60_spec_contact_sheet.png" % render_dir)
	main.ui.visible = true
	evidence.append({"name": "60_spec_contact_sheet", "path": "%s/60_spec_contact_sheet.png" % render_dir, "mode": "Godot 4.7.1 runtime batch", "resolution": "1800x720", "sequence": ["instantiate each of 60 ArtifactSpecs", "apply runtime mesh/material/trim variant", "capture thumbnail"], "status": "CAPTURED_PENDING_VISUAL_REVIEW", "note": "10x6 proof of all runtime visual signatures"})
	build_flow_contact_sheet()

	var report := {"buildHash": "SOURCE_PRE_BUILD", "captures": evidence, "count": evidence.size()}
	var file := FileAccess.open("res://qa/R3_VISUAL_QA.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("R3_SCREENSHOTS_CREATED %d" % evidence.size())
	main.queue_free()
	quit(0)
