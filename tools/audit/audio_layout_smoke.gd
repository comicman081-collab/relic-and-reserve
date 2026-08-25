extends SceneTree

## Audit-only smoke for the audio routing and the commission-card width fix.
## It does not create a save or mutate production state.

var failures: Array[String] = []


func _init() -> void:
	call_deferred("run")


func settle(frames: int = 4) -> void:
	for _frame: int in range(frames):
		await process_frame


func check(condition: bool, code: String) -> void:
	if not condition:
		failures.append(code)


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	gs.persistence_enabled = false
	gs.reset_game()
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await settle()

	check(String(main.bgm_track_key) == "title", "title_bgm_not_selected")
	check(main.bgm != null and main.bgm.stream is AudioStream, "title_bgm_stream_missing")
	check(main.bgm != null and String(main.bgm.stream.resource_path).ends_with("01_first_bell_sunshine.mp3"), "title_bgm_wrong_track")

	main.show_commissions()
	await settle()
	var icon: Control = main.find_child("CommissionIcon_commission_01", true, false)
	var card: Control = main.find_child("CommissionCard_commission_01", true, false)
	var title: Label = null
	var no_match: Label = null
	for label_value: Label in card.find_children("*", "Label", true, false):
		if title == null and (label_value.text.contains("수집가") or label_value.text.contains("Collector")):
			title = label_value
		if label_value.text.contains("조건에 맞는") or label_value.text.contains("No matching"):
			no_match = label_value
	check(icon != null and not icon is Button, "commission_icon_is_button")
	check(title != null and title.get_global_rect().size.x >= 100.0, "commission_title_collapsed_width")
	check(no_match != null and no_match.get_global_rect().size.x >= 100.0 and no_match.autowrap_mode == TextServer.AUTOWRAP_OFF, "commission_status_collapsed_width")
	check(String(main.bgm_track_key) == "market", "market_bgm_not_selected")
	check(main.bgm != null and String(main.bgm.stream.resource_path).ends_with("002_lunch_break_laughs.mp3"), "market_bgm_wrong_track")
	var commission_card_rect := card.get_global_rect() if card != null else Rect2()
	var commission_title_rect := title.get_global_rect() if title != null else Rect2()
	var commission_status_rect := no_match.get_global_rect() if no_match != null else Rect2()

	var ending_tracks := {
		"ENDING_S": "01_see_you_tomorrow.mp3",
		"ENDING_A": "02_the_memory_we_keep.mp3",
		"ENDING_B": "03_after_the_final_bell.mp3",
		"ENDING_C": "04_summer_never_ends.mp3",
		"ENDING_D": "05_our_next_adventure.mp3"
	}
	for ending_id: String in ending_tracks:
		gs.campaign_state.currentEnding = ending_id
		main.show_ending()
		await settle()
		check(String(main.bgm_track_key) == ending_id, "ending_track_key:%s" % ending_id)
		check(main.bgm != null and String(main.bgm.stream.resource_path).ends_with(String(ending_tracks[ending_id])), "ending_track_path:%s" % ending_id)
	gs.campaign_state.currentEnding = "ENDING_D"
	main.show_postgame()
	await settle()
	check(String(main.bgm_track_key) == "POSTGAME", "postgame_track_key")
	check(main.bgm != null and String(main.bgm.stream.resource_path).ends_with("06_the_sky_is_still_blue.mp3"), "postgame_track_path")
	check(FileAccess.file_exists("res://audio/title/relic_reserve_title/01_first_bell_sunshine.mp3"), "title_track_not_kept")
	check(FileAccess.file_exists("res://audio/bgm/relic_reserve_bgm/001_morning_hallway.mp3"), "bgm_track_not_kept")
	check(FileAccess.file_exists("res://audio/endings/relic_reserve_endings/01_see_you_tomorrow.mp3"), "ending_track_not_kept")
	check(not FileAccess.file_exists("res://BGM/youth_academy_audio_pack/01_title_songs/01_first_bell_sunshine.mp3"), "used_title_not_removed_from_source")
	check(FileAccess.file_exists("res://BGM/youth_academy_audio_pack/01_title_songs/02_after_school_sky.mp3"), "unused_title_not_restored")

	var button: Button = main.make_button("AUDIT", main.show_stage_select, "AudioAuditButton")
	main.ui.add_child(button)
	button.pressed.emit()
	await settle(1)
	check(String(main.screen) == "stage_select", "button_callback_not_called")
	check(main.audio != null and main.audio.stream is AudioStream and String(main.audio.stream.resource_path).ends_with("ui_click.wav"), "button_click_sfx_not_routed")
	var click_stream := String(main.audio.stream.resource_path) if main.audio != null and main.audio.stream != null else ""
	var button_callback_screen := String(main.screen)

	main.queue_free()
	await process_frame
	var report := {
		"suite": "R3 Audio/Layout Smoke",
		"passed": failures.is_empty(),
		"failed": failures.size(),
		"failures": failures,
		"musicRoots": {
			"bgm": "res://audio/bgm/relic_reserve_bgm",
			"title": "res://audio/title/relic_reserve_title",
			"endings": "res://audio/endings/relic_reserve_endings"
		},
		"sourceUsedTitleAbsent": not FileAccess.file_exists("D:/AI 종합 폴더/Games/유물경매 게임/RELIC_AND_RESERVE_R3/BGM/youth_academy_audio_pack/01_title_songs/01_first_bell_sunshine.mp3"),
		"sourceUnusedTitleRestored": FileAccess.file_exists("D:/AI 종합 폴더/Games/유물경매 게임/RELIC_AND_RESERVE_R3/BGM/youth_academy_audio_pack/01_title_songs/02_after_school_sky.mp3"),
		"commissionCardRect": commission_card_rect,
		"commissionTitleRect": commission_title_rect,
		"commissionStatusRect": commission_status_rect,
		"clickStream": click_stream,
		"buttonCallbackScreen": button_callback_screen
	}
	var file := FileAccess.open("res://qa/R3_AUDIO_LAYOUT_SMOKE.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print(JSON.stringify(report))
	gs.persistence_enabled = true
	quit(0 if failures.is_empty() else 1)
