extends SceneTree

const AXIS_IDS := ["investigation", "preservation", "sale"]
const TUTORIAL_STEPS := ["INVESTIGATE", "CITE", "REPORT", "REPAIR", "LIST", "AUCTION"]

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func settle_ui(frame_count: int = 4) -> void:
	for _frame in range(frame_count):
		await process_frame


func visible_copy(root: Node) -> String:
	var copy := ""
	for label: Label in root.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			copy += label.text + "\n"
	for button: Button in root.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			copy += button.text + "\n"
	return copy


func public_summary(main: Node, met_target: bool = false) -> Dictionary:
	return {
		"grade": main.bilingual("GROWING", "성장 중"),
		"current": 53.0,
		"target": 55.0,
		"metTarget": met_target,
		"hasNextStage": true,
		"nextStageUnlocked": true,
		"best": 53.0,
		"isNewBest": true,
		"advice": main.bilingual("Legacy advice must be replaced.", "기존 조언은 대체되어야 합니다.")
	}


func replay_fixture() -> Dictionary:
	return {
		"axes": {
			"investigation": {"value": 78.4, "available": true, "statusCode": "STRONG"},
			"preservation": {"value": 91.6, "available": true, "statusCode": "STRONG"},
			"sale": {"value": null, "available": false, "statusCode": "NO_ATTEMPTS"}
		},
		"weakest": "sale",
		"adviceCode": "SALE_NO_ATTEMPT"
	}


func build_campaign_clear_fixture(main: Node, locale: String, replay_feedback: Dictionary) -> Dictionary:
	main.language = locale
	var body: VBoxContainer = main.screen_shell(main.bilingual("CAMPAIGN — THE CLOSED WORKSHOP", "캠페인 — 닫힌 공방"))
	var stage_header := HBoxContainer.new()
	stage_header.add_theme_constant_override("separation", 8)
	body.add_child(stage_header)
	stage_header.add_child(main.make_case_tile("objective", "%s 1" % main.bilingual("STAGE", "스테이지"), main.bilingual("First lot", "첫 번째 출품")))
	stage_header.add_child(main.make_case_tile("support", main.bilingual("PERFORMANCE", "성과"), main.bilingual("CURRENT 53 · RECOMMENDED 55", "현재 53 · 권장 55")))
	stage_header.add_child(main.make_case_tile("report", main.bilingual("CASES", "사건"), "3 / 3"))
	body.add_child(main.make_label(main.bilingual("TRUST 0 · NETWORK 0 · MASTERY 0 · INTEGRITY 50", "박물관 신뢰 0 · 인맥 0 · 숙련도 0 · 온전성 50"), 16, Color("#a8b0ad")))
	var card: PanelContainer = main.make_stage_clear_card(public_summary(main), replay_feedback)
	body.add_child(card)
	var cta: Button = main.make_case_icon_button("support", main.bilingual("CHOOSE NEXT OR REPLAY", "다음 스테이지 또는 재도전"), func(): pass, "CampaignStageSelect", Vector2(0, 58))
	body.add_child(cta)
	await settle_ui()
	return {"card": card, "cta": cta}


func axis_layout(main: Node, fixture: Dictionary) -> Dictionary:
	var row: HBoxContainer = main.find_child("StageReplayAxes", true, false)
	var card: Control = fixture.get("card")
	var cta: Control = fixture.get("cta")
	var nav: Control = main.find_child("Navigation", true, false)
	var status: Control = main.find_child("StatusMessage", true, false)
	var tiles: Array = []
	var labels: Array = []
	var scores: Array = []
	var states: Array = []
	var icons: Array = []
	for axis_id: String in AXIS_IDS:
		var tile: Control = main.find_child("StageReplayAxis_%s" % axis_id, true, false)
		var label: Label = main.find_child("StageReplayAxisLabel_%s" % axis_id, true, false)
		var score: Label = main.find_child("StageReplayAxisScore_%s" % axis_id, true, false)
		var state: Label = main.find_child("StageReplayAxisStatus_%s" % axis_id, true, false)
		var icon: TextureRect = main.find_child("StageReplayAxisIcon_%s" % axis_id, true, false)
		if tile != null:
			tiles.append(tile)
		if label != null:
			labels.append(label)
		if score != null:
			scores.append(score)
		if state != null:
			states.append(state)
		if icon != null:
			icons.append(icon)
	var within_bounds := tiles.size() == 3 and tiles.all(func(tile: Control):
		var rect := tile.get_global_rect()
		return rect.position.x >= 34.0 and rect.position.y >= 82.0 and rect.end.x <= 1246.0 and rect.end.y <= 608.0
	)
	var mutually_separate := true
	for left_index in range(tiles.size()):
		for right_index in range(left_index + 1, tiles.size()):
			mutually_separate = mutually_separate and not (tiles[left_index] as Control).get_global_rect().intersects((tiles[right_index] as Control).get_global_rect())
	var avoids_chrome := tiles.all(func(tile: Control):
		var rect := tile.get_global_rect()
		return (cta == null or not rect.intersects(cta.get_global_rect())) \
			and (nav == null or not rect.intersects(nav.get_global_rect())) \
			and (status == null or not rect.intersects(status.get_global_rect()))
	)
	var card_rect := card.get_global_rect() if card != null else Rect2()
	var cta_rect := cta.get_global_rect() if cta != null else Rect2()
	var compact_card := card != null and card_rect.size.y <= 250.0
	var cta_clear := cta != null and cta_rect.position.x >= 34.0 and cta_rect.position.y >= 82.0 and cta_rect.end.x <= 1246.0 and cta_rect.end.y <= 608.0 \
		and (nav == null or not cta_rect.intersects(nav.get_global_rect())) and (status == null or not cta_rect.intersects(status.get_global_rect()))
	return {
		"ok": row != null and row.get_child_count() == 3 and tiles.size() == 3 and labels.size() == 3 and scores.size() == 3 and states.size() == 3 and icons.size() == 3 \
			and icons.all(func(icon: TextureRect): return icon.texture != null) \
			and (labels + scores + states).all(func(label: Label): return label.max_lines_visible == 1 and label.size.y <= 30.0) \
			and within_bounds and mutually_separate and avoids_chrome and compact_card and cta_clear,
		"rowChildren": row.get_child_count() if row != null else -1,
		"tileRects": tiles.map(func(tile: Control): var rect := tile.get_global_rect(); return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]),
		"withinBounds": within_bounds,
		"mutuallySeparate": mutually_separate,
		"avoidsChrome": avoids_chrome,
		"cardRect": [card_rect.position.x, card_rect.position.y, card_rect.size.x, card_rect.size.y],
		"compactCard": compact_card,
		"ctaRect": [cta_rect.position.x, cta_rect.position.y, cta_rect.size.x, cta_rect.size.y],
		"ctaClear": cta_clear,
		"labels": labels.map(func(label: Label): return label.text),
		"scores": scores.map(func(label: Label): return label.text),
		"states": states.map(func(label: Label): return label.text)
	}


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	gs.persistence_enabled = false
	gs.player_profile = gs.default_player_profile()
	gs.player_profile.tutorialCompletedSteps = TUTORIAL_STEPS.duplicate()
	gs.reset_game()
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await settle_ui()

	var ko_fixture := await build_campaign_clear_fixture(main, "ko", replay_fixture())
	var ko_copy := visible_copy(ko_fixture.card)
	var ko_axis_layout := axis_layout(main, ko_fixture)
	var ko_advice: Label = main.find_child("StageClearAdvice", true, false)
	var ko_axis_copy_ok: bool = ko_axis_layout.get("labels", []) == ["근거", "보존", "판매"] and ko_axis_layout.get("scores", []) == ["78", "92", "—"] and ko_axis_layout.get("states", []) == ["좋음", "좋음", "기록 없음"] and not ko_copy.contains("판매 · 0")
	record(
		"MVP-STAGE-REPLAY-UI-01",
		"Korean Stage Clear renders exactly three illustrated axes with rounded large scores and an explicit no-record sale instead of zero",
		ko_axis_copy_ok and bool(ko_axis_layout.get("ok", false)) and ko_advice != null and ko_advice.text == "재도전 팁 · 준비한 유물을 경매에 올려 보세요" and ko_advice.max_lines_visible == 1,
		{"copy": ko_copy, "layout": ko_axis_layout, "advice": ko_advice.text if ko_advice != null else ""}
	)

	var hints_ko := []
	var hints_en := []
	var hint_fixtures := [
		{"axes": replay_fixture().axes, "weakest": "investigation", "adviceCode": "INVESTIGATION_LOW"},
		{"axes": replay_fixture().axes, "weakest": "preservation", "adviceCode": "PRESERVATION_LOW"},
		{"axes": replay_fixture().axes, "weakest": "sale", "adviceCode": "SALE_NO_ATTEMPT"},
		{"axes": {"sale": {"value": 0.0, "available": true}}, "weakest": "sale", "adviceCode": "SALE_NO_SALE"}
	]
	main.language = "ko"
	for hint_fixture: Dictionary in hint_fixtures:
		hints_ko.append(main.stage_replay_advice(hint_fixture))
	main.language = "en"
	for hint_fixture: Dictionary in hint_fixtures:
		hints_en.append(main.stage_replay_advice(hint_fixture))
	var expected_ko := ["독립 근거를 더 인용해 보세요", "개입을 줄이고 상태를 보존해 보세요", "준비한 유물을 경매에 올려 보세요", "예약가와 공개 주장을 조정해 보세요"]
	var expected_en := ["Cite more independent evidence.", "Use fewer interventions and preserve condition.", "List a prepared relic at auction.", "Adjust the reserve and public claim."]
	record(
		"MVP-STAGE-REPLAY-UI-02",
		"Each weakest-axis state maps to one localized actionable sentence without exposing axis or advice enums",
		hints_ko == expected_ko and hints_en == expected_en and AXIS_IDS.all(func(raw_id: String): return not " ".join(hints_ko + hints_en).contains(raw_id)),
		{"ko": hints_ko, "en": hints_en}
	)

	var en_fixture := await build_campaign_clear_fixture(main, "en", replay_fixture())
	var en_copy := visible_copy(en_fixture.card)
	var en_axis_layout := axis_layout(main, en_fixture)
	var en_advice: Label = main.find_child("StageClearAdvice", true, false)
	var card_column: VBoxContainer = (en_fixture.card as PanelContainer).get_child(0)
	var first_child_name := String(card_column.get_child(0).name) if card_column != null and card_column.get_child_count() > 0 else ""
	var public_semantics_ok := first_child_name == "StageClearPrimaryRow" and en_copy.begins_with("STAGE CLEAR") and en_copy.contains("NEXT STAGE UNLOCKED") and not en_copy.contains("FAILED") and not en_copy.contains("FAILURE")
	record(
		"MVP-STAGE-REPLAY-UI-03",
		"English 1280x720 layout keeps all three tiles, one replay hint and the advisory-only next-stage action above navigation with STAGE CLEAR first",
		bool(en_axis_layout.get("ok", false)) and en_axis_layout.get("labels", []) == ["EVIDENCE", "PRESERVE", "SALE"] and en_axis_layout.get("scores", []) == ["78", "92", "—"] and en_axis_layout.get("states", []) == ["GOOD", "GOOD", "NO RECORD"] and en_advice != null and en_advice.text == "REPLAY TIP · List a prepared relic at auction." and public_semantics_ok,
		{"copy": en_copy, "layout": en_axis_layout, "firstChild": first_child_name, "publicSemantics": public_semantics_ok}
	)

	var api_available := gs.has_method("stage_replay_feedback")
	var api_feedback: Dictionary = {}
	if api_available:
		var api_value: Variant = gs.call("stage_replay_feedback")
		if api_value is Dictionary:
			api_feedback = api_value
	var api_axes: Dictionary = api_feedback.get("axes", {})
	var api_shape_ok := api_available and AXIS_IDS.all(func(axis_id: String):
		var axis_value: Variant = api_axes.get(axis_id, null)
		return axis_value is Dictionary and (axis_value as Dictionary).has("available") and (axis_value as Dictionary).has("value")
	) and api_feedback.has("weakest") and api_feedback.has("adviceCode")
	gs.language = "ko"
	main.language = "ko"
	gs.current_stage = 1
	gs.stage_run_state = gs.default_stage_run_state(1)
	gs.stage_run_state.status = "CLEARED"
	gs.stage_run_state.score = 53.0
	gs.player_profile.highestUnlockedStage = maxi(2, int(gs.player_profile.get("highestUnlockedStage", 1)))
	if not gs.player_profile.get("clearedStages", []).has(1):
		gs.player_profile.clearedStages.append(1)
	main.show_campaign()
	await settle_ui()
	var integrated_tiles: Array = main.find_children("StageReplayAxis_*", "PanelContainer", true, false)
	var integrated_copy := visible_copy(main)
	var raw_feedback_tokens := ["investigation", "preservation", "sale", "STRONG", "STEADY", "FRAGILE", "UNAVAILABLE", "NO_ATTEMPTS", "STRENGTHEN_EVIDENCE", "PROTECT_CONDITION", "IMPROVE_SALE"]
	var integrated_public := integrated_tiles.size() == 3 and integrated_copy.contains("근거") and integrated_copy.contains("보존") and integrated_copy.contains("판매") and integrated_copy.contains("독립 근거를 더 인용해 보세요") and raw_feedback_tokens.all(func(token: String): return not integrated_copy.contains(token))
	record(
		"MVP-STAGE-REPLAY-UI-04",
		"Cleared Campaign consumes the public GameState replay contract and renders three localized axes without runtime identifiers",
		api_shape_ok and integrated_public,
		{"apiAvailable": api_available, "feedback": api_feedback, "integratedTiles": integrated_tiles.size(), "integratedPublic": integrated_public, "integratedCopy": integrated_copy}
	)

	var passed := results.filter(func(result: Dictionary): return bool(result.passed)).size()
	var report := {"suite": "R3 Stage Replay Illustrated UI", "executed": results.size(), "passed": passed, "failed": results.size() - passed, "skipped": 0, "tests": results}
	var output := FileAccess.open("res://qa/R3_STAGE_REPLAY_UI_TESTS.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	main.queue_free()
	await process_frame
	quit(0 if passed == results.size() else 1)
