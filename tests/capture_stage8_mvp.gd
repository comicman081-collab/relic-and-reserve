extends SceneTree

## Off-screen 1280x720 MVP capture for Stage 8 dossier, auction, shop, and event
## portrait/dialogue flows. This never opens an editor or creates a package.

const OUTPUT_DIR := "res://qa/renders"

func _init() -> void:
	call_deferred("capture")

func snap(main: Node, name: String) -> void:
	await process_frame
	await process_frame
	var image := get_root().get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [OUTPUT_DIR, name])

func capture() -> void:
	# Use the project autoloads so Main3D and the fixture mutate the same
	# authoritative state. A second node with the same name would leave the
	# UI reading a different GameState and falsely capture the inventory shell.
	var registry: Node = get_root().get_node("RuntimeRegistry")
	var gs: Node = get_root().get_node("GameState")
	await process_frame
	gs.persistence_enabled = false
	gs.player_profile = gs.default_player_profile()
	gs.player_profile.highestUnlockedStage = 8
	gs.new_game(8)
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	var chronometer: Dictionary = gs.begin_case("master_chronometer")
	print("STAGE8_CAPTURE_AFTER_BEGIN inventory=", gs.inventory.size(), " uid=", chronometer.get("uniqueId", ""))
	main.load_artifact(chronometer)
	main.show_case_dossier("master_chronometer")
	await snap(main, "stage8_ko_chronometer_dossier")
	gs.language = "en"
	main.refresh_current_screen()
	await snap(main, "stage8_en_chronometer_dossier")
	# The market is the authoritative purchase/shop flow and renders the
	# shopkeeper portrait beside the compact lot cards.
	main.show_market()
	if not gs.market_roster.is_empty():
		main.preview_market_offer(String(gs.market_roster[0].get("lotId", "")))
	await snap(main, "stage8_en_shop_portrait")
	var event_id := String(registry.events[0].get("id", "")) if not registry.events.is_empty() else ""
	if not event_id.is_empty():
		var event_result: Dictionary = gs.execute_event(event_id, false)
		print("STAGE8_CAPTURE_AFTER_EVENT inventory=", gs.inventory.size())
		main.show_event_dialogue(event_result)
		await snap(main, "stage8_en_event_portrait")
	var auction_artifact: Dictionary = gs.find_inventory_instance("case_master_chronometer")
	print("STAGE8_CAPTURE_AUCTION_ARTIFACT empty=", auction_artifact.is_empty(), " inventory=", gs.inventory.size())
	# Capture-only fixture: the auction presentation requires a resolved case
	# artifact, while the dossier capture above intentionally remains unresolved.
	for inventory_index in range(gs.inventory.size()):
		if String(gs.inventory[inventory_index].get("uniqueId", "")) == "case_master_chronometer":
			gs.inventory[inventory_index].caseResolved = true
			auction_artifact = gs.inventory[inventory_index]
			break
	main.load_artifact(auction_artifact)
	var listed: bool = gs.list_auction(auction_artifact, 320, 420, auction_artifact.confidence)
	var direct_pending: Dictionary = gs.create_pending_auction(auction_artifact)
	print("STAGE8_CAPTURE_LISTED=", listed, " selected_case_resolved=", main.selected.get("caseResolved", false), " inventory_case_resolved=", gs.inventory[0].get("caseResolved", false), " listing=", auction_artifact.get("listing", {}), " direct_pending_ok=", direct_pending.get("ok", false), " pending_status=", gs.pending_auction_public_state().get("status", ""))
	main.load_artifact(gs.find_inventory_instance("case_master_chronometer"))
	var pending_before_show: Dictionary = gs.pending_auction_public_state()
	var ensured_pending: Dictionary = main.ensure_pending_auction_snapshot()
	print("STAGE8_CAPTURE_BEFORE_SHOW uid=", main.selected.get("uniqueId", ""), " pending_ok=", pending_before_show.get("ok", false), " same_uid=", String(pending_before_show.get("artifactId", "")) == String(main.selected.get("uniqueId", "")), " ensure_ok=", ensured_pending.get("ok", false), " ensure_status=", ensured_pending.get("status", ""))
	main.show_auction()
	print("STAGE8_CAPTURE_AFTER_SHOW screen=", main.screen, " cue_count=", main.auction_cue_queue.size(), " selected_uid=", main.selected.get("uniqueId", ""), " pending=", gs.pending_auction_public_state().get("status", ""))
	await snap(main, "stage8_en_auction_portraits")
	print("STAGE8_MVP_CAPTURES_CREATED")
	main.queue_free()
	gs.persistence_enabled = false
	quit(0)
