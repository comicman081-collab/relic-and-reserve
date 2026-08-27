extends SceneTree

# Regression gate for the real Android portrait failure mode: authored case copy
# must be readable without hover tooltips, the dossier must become a one-column
# touch flow, and beginner tutorial teaching must remain readable.

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("MOBILE_READABILITY_QA: " + message)


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(390, 700))
	root.size = Vector2i(390, 700)
	await process_frame

	var packed := load("res://scenes/Main.tscn") as PackedScene
	_check(packed != null, "Main scene must load")
	if packed == null:
		quit(1)
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await _wait_frames(12)

	var game_state := root.get_node_or_null("GameState")
	_check(game_state != null, "GameState autoload must exist")
	_check(root.get_node_or_null("MobileWebLayout") != null, "MobileWebLayout autoload must exist")
	_check(root.get_node_or_null("MobileUXAssistant") != null, "MobileUXAssistant compatibility autoload must exist")
	_check(root.get_node_or_null("MobileFullTextRestore") != null, "MobileFullTextRestore autoload must exist")
	_check(root.get_node_or_null("MobileCaseTutorialUX") != null, "MobileCaseTutorialUX autoload must exist")
	_check(root.get_node_or_null("TutorialSpotlightDirector") != null, "TutorialSpotlightDirector autoload must exist")
	_check(root.get_node_or_null("TutorialSpotlightLayoutGuard") != null, "TutorialSpotlightLayoutGuard autoload must exist")
	if game_state == null:
		quit(1)
		return

	game_state.set("persistence_enabled", false)
	game_state.call("reset_game")
	game_state.set("player_profile", game_state.call("default_player_profile"))
	game_state.set("language", "ko")
	var new_game_result: Variant = game_state.call("new_game", 1)
	_check(new_game_result is Dictionary and bool((new_game_result as Dictionary).get("ok", false)), "Stage 1 new game must start")
	game_state.call("begin_case", "prologue_clock")
	scene.call("show_case_dossier", "prologue_clock")
	await _wait_frames(24)

	var ui := scene.find_child("R3Interface", true, false) as Control
	_check(ui != null, "R3Interface must exist")
	if ui == null:
		quit(1)
		return

	var action_panel := ui.find_child("MobileNextActionPanel", true, false) as PanelContainer
	var action_text := ui.find_child("MobileNextActionText", true, false) as Label
	_check(action_panel != null, "portrait dossier must expose a persistent next-action panel")
	_check(action_text != null, "next-action panel must contain explanatory copy")
	if action_text != null:
		_check(action_text.text.length() >= 35, "next-action copy must be explanatory, not a label-only hint")
		_check(not action_text.text.contains("…"), "next-action copy must not be ellipsized")

	var rail := ui.find_child("TutorialGuidanceRail", true, false) as PanelContainer
	var rail_title := ui.find_child("TutorialStepTitle", true, false) as Label
	var rail_text := ui.find_child("TutorialStepText", true, false) as Label
	_check(rail != null, "active Stage 1 tutorial rail must be visible")
	_check(rail != null and rail.custom_minimum_size.y >= 170.0, "tutorial rail must be tall enough for full mobile copy")
	_check(rail_title != null and rail_title.max_lines_visible == -1, "tutorial title must allow full wrapping")
	_check(rail_text != null and rail_text.max_lines_visible == -1, "tutorial instruction must allow full wrapping")
	if rail_text != null:
		_check(not rail_text.text.contains("…"), "tutorial instruction must not be ellipsized")

	var briefing_tile := ui.find_child("CaseTile_briefing", true, false) as PanelContainer
	var briefing_summary := ui.find_child("CaseTileSummary_briefing", true, false) as Label
	_check(briefing_tile != null, "case briefing tile must exist")
	_check(briefing_tile != null and briefing_tile.get_parent() is GridContainer and (briefing_tile.get_parent() as GridContainer).columns == 1, "overview cards must be one column in portrait")
	if briefing_tile != null and briefing_summary != null:
		_check(briefing_summary.text == briefing_tile.tooltip_text, "portrait briefing must restore the authored full text from its desktop tooltip")
		_check(not briefing_summary.text.contains("…"), "portrait briefing must not contain truncation ellipsis")
		_check(briefing_summary.max_lines_visible == -1, "portrait briefing must wrap to all needed lines")

	var evidence_cards := ui.find_children("CaseEvidenceCard_*", "Button", true, false)
	_check(not evidence_cards.is_empty(), "case dossier must expose clue cards")
	var first_card: Button = null
	if not evidence_cards.is_empty():
		first_card = evidence_cards[0] as Button
		_check(first_card != null and first_card.get_parent() is GridContainer, "clue cards must stay inside a grid")
		if first_card != null and first_card.get_parent() is GridContainer:
			_check((first_card.get_parent() as GridContainer).columns == 1, "portrait clue cards must use one full-width column")
			_check(not first_card.clip_text, "portrait clue card text must not be clipped")
			_check(first_card.custom_minimum_size.y >= 140.0, "portrait clue cards must be tall readable touch targets")

	var evidence_stack := ui.find_child("MobileCaseEvidenceStack", true, false) as VBoxContainer
	_check(evidence_stack != null, "clue list and selected clue detail must be stacked vertically")
	if evidence_stack != null:
		_check(evidence_stack.get_child_count() >= 2, "portrait evidence stack must contain clue ledger and detail panel")
		for child: Node in evidence_stack.get_children():
			if child is Control and evidence_stack.size.x > 0.0:
				_check((child as Control).size.x >= evidence_stack.size.x * 0.82, "evidence stack children must use most of the mobile width")

	var hypotheses := ui.find_children("CaseHypothesis_*", "Button", true, false)
	_check(not hypotheses.is_empty(), "case dossier must expose hypotheses")
	if not hypotheses.is_empty():
		var first_hypothesis := hypotheses[0] as Button
		_check(first_hypothesis.get_parent() is GridContainer and (first_hypothesis.get_parent() as GridContainer).columns == 1, "portrait hypotheses must use one column")
		_check(not first_hypothesis.clip_text, "portrait hypothesis label must not be clipped")

	# The beginner tutorial now starts with a teaching intro instead of the old
	# blocking generic coach modal. Its full copy must be readable before input.
	var tutorial_overlay := ui.find_child("TutorialSpotlightOverlay", true, false) as Control
	var intro_body := ui.find_child("TutorialIntroBody", true, false) as Label
	_check(tutorial_overlay != null, "fresh Stage 1 must expose the spotlight tutorial layer")
	_check(intro_body != null, "spotlight tutorial must expose readable beginner teaching copy")
	if intro_body != null:
		_check(intro_body.text.contains("단서 조사") and intro_body.text.contains("경매"), "tutorial introduction must explain the game loop")
		_check(intro_body.text.length() >= 140, "tutorial introduction must explain the game, not show a one-line hint")

	# A clue-card tap must rebuild the selected detail and then open a touch
	# modal containing the full readable detail plus the actual next action.
	if first_card != null and is_instance_valid(first_card):
		first_card.pressed.emit()
		await _wait_frames(10)
		var detail_modal := ui.find_child("MobileUXModal", true, false) as Control
		_check(detail_modal != null, "tapping a clue card must open its full-text touch detail")
		if detail_modal != null:
			var detail_body := detail_modal.find_child("ModalBody", true, false) as Label
			_check(detail_body != null and detail_body.text.length() >= 30, "clue detail modal must contain readable explanatory text")
			var primary_action := detail_modal.find_child("ModalPrimaryAction", true, false) as Button
			_check(primary_action != null, "an actionable ready clue must expose its investigate/cite action inside the detail modal")
			if primary_action != null:
				_check(not primary_action.clip_text and primary_action.custom_minimum_size.y >= 120.0, "modal primary action must be a large readable touch target")

	if failures.is_empty():
		print("MOBILE_READABILITY_RUNTIME_QA: PASS")
		quit(0)
	else:
		print("MOBILE_READABILITY_RUNTIME_QA: FAIL count=", failures.size(), " failures=", failures)
		quit(1)
