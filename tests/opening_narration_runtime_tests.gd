extends SceneTree

# Gate for the first-run story + navigation onboarding requested for NEW GAME.
# It also reproduces mobile Web's touch + synthesized mouse pair to ensure one
# physical tap advances exactly one page and a normal final tap closes 6/6.

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("OPENING_ONBOARDING_QA: " + message)


func _wait_frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _page_text(ui: Control, node_name: String) -> String:
	var label := ui.find_child(node_name, true, false) as Label
	return "" if label == null else label.text


func _tab_titles(ui: Control) -> Array[String]:
	var titles: Array[String] = []
	for index in range(1, 4):
		var label := ui.find_child("OpeningTabTitle_%d" % index, true, false) as Label
		if label != null:
			titles.append(label.text)
	return titles


func _check_tab_page_geometry(ui: Control, context: String) -> void:
	var panel := ui.find_child("OpeningNarrationPanel", true, false) as Control
	_check(panel != null, context + ": onboarding panel must exist")
	if panel == null:
		return
	var ui_rect := ui.get_global_rect()
	var panel_rect := panel.get_global_rect()
	_check(panel_rect.position.x >= ui_rect.position.x - 1.0, context + ": panel left edge must stay on-screen")
	_check(panel_rect.end.x <= ui_rect.end.x + 1.0, context + ": panel right edge must stay on-screen")
	for index in range(1, 4):
		var card := ui.find_child("OpeningTabCard_%d" % index, true, false) as Control
		var body := ui.find_child("OpeningTabBody_%d" % index, true, false) as Label
		var title := ui.find_child("OpeningTabTitle_%d" % index, true, false) as Label
		_check(card != null and body != null and title != null, "%s: card %d controls must exist" % [context, index])
		if card == null or body == null or title == null:
			continue
		var card_rect := card.get_global_rect()
		var body_rect := body.get_global_rect()
		var title_rect := title.get_global_rect()
		_check(card_rect.end.x <= panel_rect.end.x + 1.0, "%s: card %d must not overflow panel right edge" % [context, index])
		_check(body_rect.end.x <= card_rect.end.x + 1.0, "%s: card %d body must wrap inside card instead of clipping right" % [context, index])
		_check(title_rect.end.x <= card_rect.end.x + 1.0, "%s: card %d title must stay inside card" % [context, index])
		_check(body.autowrap_mode != TextServer.AUTOWRAP_OFF and body.max_lines_visible == -1 and not body.clip_text, "%s: card %d body must allow unlimited wrapped text" % [context, index])


func _rect_inside(inner: Rect2, outer: Rect2, tolerance := 1.0) -> bool:
	return (
		inner.position.x >= outer.position.x - tolerance
		and inner.position.y >= outer.position.y - tolerance
		and inner.end.x <= outer.end.x + tolerance
		and inner.end.y <= outer.end.y + tolerance
	)


func _check_landscape_page_geometry(ui: Control, opening: Node, context: String, tab_page: bool) -> void:
	var ui_rect := ui.get_global_rect()
	var panel := ui.find_child("OpeningNarrationPanel", true, false) as Control
	var skip := ui.find_child("OpeningExpertSkip", true, false) as Button
	var scroll := ui.find_child("OpeningNarrationScroll", true, false) as ScrollContainer
	_check(panel != null, context + ": onboarding panel must exist")
	_check(skip != null, context + ": top-right skip must exist")
	_check(scroll != null, context + ": narration scroll region must exist")
	if panel == null or skip == null or scroll == null:
		return

	var panel_rect := panel.get_global_rect()
	var skip_rect := skip.get_global_rect()
	_check(_rect_inside(panel_rect, ui_rect), context + ": panel must stay fully inside the 1280x720 viewport")
	_check(panel_rect.end.y <= ui_rect.end.y - 20.0, context + ": panel must preserve a visible bottom safety margin")
	_check(_rect_inside(skip_rect, ui_rect), context + ": skip control must stay fully inside the viewport")
	_check(skip_rect.position.y <= ui_rect.position.y + 20.0, context + ": skip control must remain in the upper-right lane")
	_check(absf((ui_rect.end.x - skip_rect.end.x) - 24.0) <= 1.0, context + ": skip control must keep the 24px right margin")
	_check(skip.visible and skip.is_visible_in_tree() and not skip.disabled, context + ": skip control must be visible and enabled")
	_check(skip.focus_mode == Control.FOCUS_ALL, context + ": skip control must remain keyboard focusable")
	_check(skip.mouse_filter == Control.MOUSE_FILTER_STOP, context + ": skip control must accept pointer input")
	_check(skip.pressed.is_connected(Callable(opening, "_skip_all_tutorial")), context + ": skip control must invoke the authoritative skip path")

	for node_name in ["OpeningNarrationProgress", "OpeningNarrationTitle", "OpeningNarrationTapHint", "OpeningNarrationOverallProgress"]:
		var control := ui.find_child(node_name, true, false) as Control
		_check(control != null, "%s: %s must exist" % [context, node_name])
		if control != null:
			_check(_rect_inside(control.get_global_rect(), panel_rect), "%s: %s must remain inside the panel" % [context, node_name])

	var title := ui.find_child("OpeningNarrationTitle", true, false) as Label
	if title != null:
		_check(title.size.x >= 800.0, context + ": title needs a usable horizontal measure, not a vertical letter stack")

	if not tab_page:
		return
	var content := ui.find_child("OpeningNarrationContent", true, false) as GridContainer
	_check(content != null and content.columns == 3, context + ": desktop tab guide must use one three-column grid")
	var scroll_rect := scroll.get_global_rect()
	var card_rects: Array[Rect2] = []
	for index in range(1, 4):
		var card := ui.find_child("OpeningTabCard_%d" % index, true, false) as Control
		var body := ui.find_child("OpeningTabBody_%d" % index, true, false) as Label
		var tab_title := ui.find_child("OpeningTabTitle_%d" % index, true, false) as Label
		_check(card != null and body != null and tab_title != null, "%s: card %d controls must exist" % [context, index])
		if card == null or body == null or tab_title == null:
			continue
		var card_rect := card.get_global_rect()
		card_rects.append(card_rect)
		_check(_rect_inside(card_rect, scroll_rect), "%s: card %d must fit in the visible scroll region" % [context, index])
		_check(body.size.x >= 200.0, "%s: card %d body must not collapse into vertical text" % [context, index])
		_check(tab_title.size.x >= 200.0, "%s: card %d title must not collapse into vertical text" % [context, index])
	for left_index in range(card_rects.size()):
		for right_index in range(left_index + 1, card_rects.size()):
			_check(not card_rects[left_index].intersects(card_rects[right_index]), "%s: desktop cards must never overlap" % context)
	_check(not scroll.get_h_scroll_bar().visible, context + ": desktop tab guide must not require horizontal scrolling")
	_check(not scroll.get_v_scroll_bar().visible, context + ": all three desktop cards must be visible without vertical scrolling")


func _check_landscape_locales(ui: Control, opening: Node, gs: Node) -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	await _wait_frames(12)
	_check(absf(ui.size.x - 1280.0) <= 1.0 and absf(ui.size.y - 720.0) <= 1.0, "desktop QA must exercise the real 1280x720 interface geometry")

	for language in ["ko", "en"]:
		gs.set("language", language)
		opening.set("session_completed", false)
		opening.set("active", true)
		for page in range(6):
			opening.set("page_index", page)
			opening.call("_show_page")
			await _wait_frames(4)
			_check_landscape_page_geometry(ui, opening, "%s landscape page %d/6" % [language.to_upper(), page + 1], page >= 3)

	opening.call("_remove_overlay")
	opening.set("active", false)
	opening.set("session_completed", true)
	await _wait_frames(2)


func _mobile_web_tap(input_guard: Node) -> void:
	# Reproduce the real browser failure: one finger tap may arrive as ScreenTouch
	# followed by a synthesized left MouseButton. The guard must count this once.
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(200.0, 350.0)
	touch.pressed = true
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = Vector2(200.0, 350.0)
	mouse.pressed = true
	input_guard.call("_on_dim_gui_input", touch)
	input_guard.call("_on_dim_gui_input", mouse)
	await _wait_frames(4)


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

	var gs := root.get_node_or_null("GameState")
	var opening := root.get_node_or_null("OpeningNarrationDirector")
	var spotlight := root.get_node_or_null("TutorialSpotlightDirector")
	var input_guard := root.get_node_or_null("OpeningNarrationInputGuard")
	_check(gs != null, "GameState autoload must exist")
	_check(opening != null, "OpeningNarrationDirector autoload must exist")
	_check(spotlight != null, "TutorialSpotlightDirector autoload must exist")
	_check(input_guard != null, "OpeningNarrationInputGuard autoload must exist")
	if gs == null or opening == null or spotlight == null or input_guard == null:
		quit(1)
		return

	gs.set("persistence_enabled", false)
	# The local machine may already have completed the tutorial. This test owns
	# an in-memory fresh-profile fixture and must never depend on user:// state.
	gs.call("reset_tutorial_guidance")
	gs.set("language", "ko")
	opening.set("force_enabled_for_test", true)
	input_guard.set("force_enabled_for_test", true)
	opening.set("session_completed", false)
	var result: Dictionary = gs.call("new_game", 1)
	_check(bool(result.get("ok", false)), "fresh Stage 1 NEW GAME must start")
	scene.call("show_campaign")
	await _wait_frames(20)
	input_guard.call("_configure_current_dim")
	await _wait_frames(2)

	var ui := scene.find_child("R3Interface", true, false) as Control
	_check(ui != null, "R3Interface must exist")
	if ui == null:
		quit(1)
		return

	var overlay := ui.find_child("OpeningNarrationOverlay", true, false) as Control
	_check(overlay != null, "NEW GAME must open the story narration before normal campaign interaction")
	_check(_page_text(ui, "OpeningNarrationProgress").contains("오프닝") and _page_text(ui, "OpeningNarrationProgress").contains("1 / 3"), "opening must be explicitly split into three narration pages")
	var first_body := _page_text(ui, "OpeningNarrationBody")
	_check(first_body.contains("마라 벤") and first_body.contains("공방") and first_body.contains("열쇠"), "opening page 1 must explain why the player is in this workshop and connect Mara Venn")
	_check(_page_text(ui, "OpeningNarrationTapHint").contains("터치") and _page_text(ui, "OpeningNarrationTapHint").contains("클릭"), "opening must teach that touch/click anywhere advances")
	var expert_skip := ui.find_child("OpeningExpertSkip", true, false) as Button
	_check(expert_skip != null and expert_skip.text.contains("이미 아는"), "only experienced players should be invited to skip the whole tutorial")
	_check(int(spotlight.process_mode) == int(Node.PROCESS_MODE_DISABLED), "hands-on spotlight tutorial must pause behind the story onboarding")
	_check(ui.find_child("TutorialSpotlightOverlay", true, false) == null, "story onboarding must not overlap the hands-on spotlight overlay")

	var dim := ui.find_child("OpeningNarrationDim", true, false) as Control
	_check(dim != null, "opening dim input surface must exist")
	if dim != null:
		_check(not dim.gui_input.is_connected(Callable(opening, "_on_advance_input")), "raw director input handler must be disconnected to prevent double-advance")
		_check(dim.gui_input.is_connected(Callable(input_guard, "_on_dim_gui_input")), "guarded single-tap handler must own onboarding input")

	await _mobile_web_tap(input_guard)
	_check(int(opening.get("page_index")) == 1, "one physical mobile tap must advance exactly one page, never two")
	var second_body := _page_text(ui, "OpeningNarrationBody")
	_check(_page_text(ui, "OpeningNarrationProgress").contains("2 / 3"), "opening narration must advance to page 2")
	_check(second_body.contains("평판") and second_body.contains("박물관 신뢰") and second_body.contains("역사적"), "opening page 2 must explain why careless appraisal/restoration matters")

	await _mobile_web_tap(input_guard)
	_check(int(opening.get("page_index")) == 2, "second physical tap must advance only to opening page 3")
	var third_body := _page_text(ui, "OpeningNarrationBody")
	_check(_page_text(ui, "OpeningNarrationProgress").contains("3 / 3"), "opening narration must reach page 3")
	_check(third_body.contains("목표") and third_body.contains("닫힌 공방") and third_body.contains("탁상시계"), "opening page 3 must state the player's goal and lead directly into the first case")

	await _mobile_web_tap(input_guard)
	_check(int(opening.get("page_index")) == 3, "third physical tap must enter menu guide 1/3 only")
	_check(_page_text(ui, "OpeningNarrationProgress").contains("공방 메뉴 안내") and _page_text(ui, "OpeningNarrationProgress").contains("1 / 3"), "after the story, the navigation guide must begin as three pages")
	var group1 := _tab_titles(ui)
	_check(group1 == ["공방", "시장", "보관함"], "menu guide page 1 must explain workshop, market and inventory together")
	for index in range(1, 4):
		_check(_page_text(ui, "OpeningTabBody_%d" % index).length() >= 35, "every menu card must contain a useful explanation")
	_check_tab_page_geometry(ui, "menu guide 1/3")

	await _mobile_web_tap(input_guard)
	_check(int(opening.get("page_index")) == 4, "fourth physical tap must advance only to reported 5/6 page")
	var group2 := _tab_titles(ui)
	_check(group2 == ["업그레이드", "의뢰", "캠페인"], "menu guide page 2 must explain upgrades, commissions and campaign together")
	_check_tab_page_geometry(ui, "menu guide 2/3 — user-reported 5/6 page")

	await _mobile_web_tap(input_guard)
	_check(int(opening.get("page_index")) == 5, "fifth physical tap must land on final 6/6 page and remain active")
	var group3 := _tab_titles(ui)
	_check(group3 == ["하루 마치기", "저장", "EN / 한국어"], "menu guide page 3 must explain end day, save and language together")
	_check(_page_text(ui, "OpeningNarrationOverallProgress").contains("6 / 6"), "story plus menu onboarding must total six tap-through pages")
	_check_tab_page_geometry(ui, "menu guide 3/3")
	_check(bool(opening.get("active")), "6/6 must remain visible until the sixth normal tap")

	await _mobile_web_tap(input_guard)
	await _wait_frames(10)
	_check(not bool(opening.get("active")), "sixth normal tap must finish onboarding without pressing skip")
	_check(ui.find_child("OpeningNarrationOverlay", true, false) == null, "final normal tap must close the opening/menu overlay")
	_check(bool(opening.get("session_completed")), "completed opening must not immediately replay in the same run")
	_check(int(spotlight.process_mode) == int(Node.PROCESS_MODE_ALWAYS), "hands-on tutorial must resume after the opening/menu guide")
	_check(bool(spotlight.get("intro_done")), "the old generic three-page intro must be skipped because the new six-page onboarding replaces it")
	_check(ui.find_child("TutorialIntroPanel", true, false) == null, "player must not see a second redundant generic intro after the new onboarding")
	_check(ui.find_child("TutorialSpotlightOverlay", true, false) != null, "after onboarding, the real-action spotlight tutorial must take over")
	_check(ui.find_child("TutorialSpeechBubble", true, false) != null, "hands-on teaching must continue with the existing speech bubble")

	# The production Web viewport is landscape. Exercise every localized page
	# after the mobile single-tap chain so both responsive layouts stay covered.
	await _check_landscape_locales(ui, opening, gs)

	if failures.is_empty():
		print("OPENING_ONBOARDING_RUNTIME_QA: PASS")
		quit(0)
	else:
		print("OPENING_ONBOARDING_RUNTIME_QA: FAIL count=", failures.size(), " failures=", failures)
		quit(1)
