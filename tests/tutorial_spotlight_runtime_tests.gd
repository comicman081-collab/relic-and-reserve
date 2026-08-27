extends SceneTree

# Regression gate for the beginner-facing tutorial contract.
# It verifies that a fresh Stage 1 run teaches the game before asking for input,
# then exposes exactly one spotlighted gameplay target with explanatory copy.

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("TUTORIAL_SPOTLIGHT_QA: " + message)


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
	await _wait_frames(14)

	var gs := root.get_node_or_null("GameState")
	var director := root.get_node_or_null("TutorialSpotlightDirector")
	_check(gs != null, "GameState autoload must exist")
	_check(director != null, "TutorialSpotlightDirector autoload must exist")
	if gs == null or director == null:
		quit(1)
		return

	gs.set("persistence_enabled", false)
	gs.call("reset_game")
	gs.set("player_profile", gs.call("default_player_profile"))
	gs.set("language", "ko")
	var start_result: Dictionary = gs.call("new_game", 1)
	_check(bool(start_result.get("ok", false)), "fresh Stage 1 must start")
	scene.call("show_campaign")
	await _wait_frames(16)

	var ui := scene.find_child("R3Interface", true, false) as Control
	_check(ui != null, "R3Interface must exist")
	if ui == null:
		quit(1)
		return

	# Validate all authored beginner lessons directly so the test verifies the
	# actual teaching content without depending on one frame's counter animation.
	var intro_pages: Array = director.call("_intro_pages")
	_check(intro_pages.size() == 3, "beginner onboarding must contain three explanation pages")
	if intro_pages.size() == 3:
		var page1 := str((intro_pages[0] as Dictionary).get("body", ""))
		var page2 := str((intro_pages[1] as Dictionary).get("body", ""))
		var page3 := str((intro_pages[2] as Dictionary).get("body", ""))
		_check(page1.contains("단서 조사") and page1.contains("경매"), "intro page 1 must teach the whole investigation-to-auction loop")
		_check(page2.contains("근거") and page2.contains("보존") and page2.contains("판매"), "intro page 2 must teach evidence, preservation and sale goals")
		_check(page3.contains("강조") and page3.contains("실제 게임 행동"), "intro page 3 must explain spotlight controls and real-action progression")

	# Fresh players must see the teaching intro before any action spotlight.
	var intro := ui.find_child("TutorialIntroPanel", true, false) as PanelContainer
	var intro_title := ui.find_child("TutorialIntroTitle", true, false) as Label
	var intro_body := ui.find_child("TutorialIntroBody", true, false) as Label
	var intro_next := ui.find_child("TutorialIntroNext", true, false) as Button
	var expert_skip := ui.find_child("TutorialExpertSkip", true, false) as Button
	_check(intro != null, "fresh Stage 1 must open the game-introduction tutorial")
	_check(intro_title != null and intro_title.text.contains("무엇을 하는 게임"), "intro must explain what kind of game this is")
	_check(intro_body != null and intro_body.text.contains("단서 조사") and intro_body.text.contains("경매"), "visible intro must teach the whole investigation-to-auction loop")
	_check(intro_body != null and intro_body.text.length() >= 140, "intro must contain real teaching copy, not a label-only hint")
	_check(expert_skip != null and expert_skip.text.contains("이미 아는"), "skip must be explicitly framed for players who already know the game")
	var old_skip := ui.find_child("TutorialSkipButton", true, false) as BaseButton
	_check(old_skip == null or not old_skip.visible, "the old prominent skip button must be hidden during teaching")

	# Advance through all three explanation pages. The content contract above
	# proves each page; the important runtime contract is that three presses lead
	# to the first real-action spotlight.
	for _page_index in range(3):
		intro_next = ui.find_child("TutorialIntroNext", true, false) as Button
		_check(intro_next != null, "each intro page must have a next/start button")
		if intro_next == null:
			break
		intro_next.pressed.emit()
		await _wait_frames(8)

	await _wait_frames(10)
	var overlay := ui.find_child("TutorialSpotlightOverlay", true, false) as Control
	var bubble := ui.find_child("TutorialSpeechBubble", true, false) as PanelContainer
	var outline := ui.find_child("TutorialTargetOutlineSpotlight", true, false) as PanelContainer
	var bubble_body := ui.find_child("TutorialSpotlightBody", true, false) as Label
	var action_hint := ui.find_child("TutorialSpotlightActionHint", true, false) as Label
	_check(overlay != null, "after intro, an action spotlight must appear")
	_check(overlay != null and overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "spotlight root must leave only its cutout target clickable")
	_check(bubble != null, "spotlight must include a speech bubble")
	_check(outline != null, "spotlight must draw a visible target outline")
	_check(bubble_body != null and bubble_body.text.length() >= 90, "speech bubble must explain what and why, not only name the button")
	_check(action_hint != null and action_hint.text.contains("강조된 곳만"), "speech bubble must explicitly tell the player to use only the highlighted control")

	var dim_count := 0
	for dim_name in ["TutorialDimTop", "TutorialDimBottom", "TutorialDimLeft", "TutorialDimRight"]:
		var dim := ui.find_child(dim_name, true, false) as ColorRect
		if dim != null:
			dim_count += 1
			_check(dim.mouse_filter == Control.MOUSE_FILTER_STOP, dim_name + " must block unrelated touches")
	_check(dim_count >= 2, "spotlight must dim and block the non-target area around the cutout")

	var case_id := str(gs.call("current_stage_first_pending_case"))
	var first_case := ui.find_child("Case_%s" % case_id.validate_node_name(), true, false) as BaseButton
	_check(first_case != null and first_case.is_visible_in_tree(), "first case start control must be the reachable tutorial route")
	if first_case != null and outline != null:
		var target_rect := first_case.get_global_rect()
		var outline_rect := outline.get_global_rect()
		_check(outline_rect.intersects(target_rect), "spotlight outline must overlap the actual first-case target")

	# The highlighted real action should remain usable through the cutout.
	if first_case != null:
		first_case.pressed.emit()
		await _wait_frames(18)

	var public_state: Dictionary = gs.call("tutorial_public_state")
	_check(bool(public_state.get("visible", false)) and int(public_state.get("step", 0)) == 1, "opening the case should keep tutorial on investigate step until a clue is actually recorded")
	bubble_body = ui.find_child("TutorialSpotlightBody", true, false) as Label
	var teaches_source := bubble_body != null and (bubble_body.text.contains("출처") or bubble_body.text.contains("어디서 나온"))
	var teaches_reliability := bubble_body != null and (bubble_body.text.contains("신뢰") or bubble_body.text.contains("믿을 만"))
	_check(teaches_source and teaches_reliability, "investigate spotlight must teach source and reliability before the action")
	_check(bubble_body != null and bubble_body.text.contains("손상"), "investigate spotlight must teach damage risk before the action")

	var investigate_targets := ui.find_children("CaseEvidence_*", "Button", true, false)
	var investigate: Button = null
	for candidate_node: Node in investigate_targets:
		var candidate := candidate_node as Button
		if candidate != null and candidate.is_visible_in_tree() and not candidate.disabled:
			investigate = candidate
			break
	_check(investigate != null, "investigate tutorial step must expose one real enabled investigation action")
	if investigate != null:
		investigate.pressed.emit()
		await _wait_frames(18)

	public_state = gs.call("tutorial_public_state")
	_check(int(public_state.get("step", 0)) == 2, "successful investigation must advance tutorial to evidence citation")
	bubble_body = ui.find_child("TutorialSpotlightBody", true, false) as Label
	_check(bubble_body != null and bubble_body.text.contains("보고서") and bubble_body.text.contains("근거"), "step 2 speech bubble must teach why evidence is cited into a report")

	# The later authored steps must also carry explanatory learning copy, not only
	# button names. This checks the full loop without mutating the campaign ahead.
	var dummy := Button.new()
	dummy.name = "Tool_repair"
	var repair_copy := str(director.call("_spotlight_explanation", 4, dummy))
	dummy.name = "ListingDisclosure_BALANCED"
	var listing_copy := str(director.call("_spotlight_explanation", 5, dummy))
	dummy.name = "HammerButton"
	var auction_copy := str(director.call("_spotlight_explanation", 6, dummy))
	dummy.queue_free()
	_check(repair_copy.contains("과한 복원") or repair_copy.contains("필요한 만큼"), "repair tutorial must teach preservation, not just tool clicking")
	_check(listing_copy.contains("공개") and listing_copy.contains("근거"), "listing tutorial must teach honest disclosure from evidence")
	_check(auction_copy.contains("전체 루프") or auction_copy.contains("시장 반응"), "auction tutorial must explain how the sale closes the game loop")

	if failures.is_empty():
		print("TUTORIAL_SPOTLIGHT_RUNTIME_QA: PASS")
		quit(0)
	else:
		print("TUTORIAL_SPOTLIGHT_RUNTIME_QA: FAIL count=", failures.size(), " failures=", failures)
		quit(1)
