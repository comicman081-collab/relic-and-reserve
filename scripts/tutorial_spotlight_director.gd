extends Node

# Presentation-only tutorial director.
# It keeps GameState's authoritative six-step tutorial contract intact, but
# teaches the game with an intro, a spotlight cutout and a speech bubble beside
# the one control the player should use next. Everything outside the spotlight
# is temporarily blocked so a new player can learn the loop one action at a time.

const OVERLAY_NAME := "TutorialSpotlightOverlay"
const LEGACY_MODAL_NAME := "MobileUXModal"
const BUBBLE_NAME := "TutorialSpeechBubble"
const OUTLINE_NAME := "TutorialTargetOutlineSpotlight"

var interface: Control
var queued := false
var tutorial_was_visible := false
var intro_page := 0
var intro_done := false
var last_target_signature := ""
var pending_signature := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_discover.call_deferred()


func _process(_delta: float) -> void:
	# The older mobile helper can briefly create its large tutorial modal. The
	# spotlight director owns tutorial coaching now, so remove only tutorial
	# modals while leaving clue/hypothesis detail modals untouched.
	_remove_legacy_tutorial_modal()
	_reserve_portrait_intro_copy_space()


func _discover() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var candidate := scene.find_child("R3Interface", true, false)
	if candidate is Control:
		interface = candidate
		_queue_apply()


func _on_node_added(node: Node) -> void:
	if node is Control and node.name == "R3Interface":
		interface = node
		_queue_apply()
		return
	if interface != null and is_instance_valid(interface) and interface.is_ancestor_of(node):
		_queue_apply()


func _queue_apply() -> void:
	if queued:
		return
	queued = true
	_apply_deferred.call_deferred()


func _apply_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	queued = false
	if interface == null or not is_instance_valid(interface) or not interface.is_inside_tree():
		_discover()
		return

	var state: Dictionary = GameState.tutorial_public_state()
	var visible := bool(state.get("visible", false))
	_configure_legacy_skip(visible)
	_remove_legacy_tutorial_modal()

	if not visible:
		if tutorial_was_visible:
			intro_page = 0
			intro_done = false
			last_target_signature = ""
			pending_signature = ""
		tutorial_was_visible = false
		_remove_overlay()
		return

	if not tutorial_was_visible:
		intro_page = 0
		intro_done = false
		last_target_signature = ""
		pending_signature = ""
	tutorial_was_visible = true

	if int(state.get("step", 0)) == 1 and not intro_done:
		_show_intro_page()
		return

	_maybe_show_target_spotlight(state)


func _configure_legacy_skip(tutorial_visible: bool) -> void:
	var skip := interface.find_child("TutorialSkipButton", true, false) as BaseButton
	if skip != null:
		# Skipping is intentionally available only as a small secondary choice in
		# the teaching bubble, labelled for players who already know the game.
		skip.visible = not tutorial_visible


func _remove_legacy_tutorial_modal() -> void:
	if interface == null or not is_instance_valid(interface):
		return
	var modal := interface.find_child(LEGACY_MODAL_NAME, true, false)
	if modal == null:
		return
	var title := modal.find_child("ModalTitle", true, false) as Label
	if title == null:
		return
	var rendered := title.text.to_upper()
	if rendered.begins_with("TUTORIAL") or title.text.begins_with("튜토리얼"):
		modal.queue_free()


func _intro_pages() -> Array:
	return [
		{
			"title": _copy("WHAT KIND OF GAME IS THIS?", "이 게임은 무엇을 하는 게임인가요?"),
			"body": _copy(
				"Examine a relic, compare its clues and sources, then restore only what it truly needs before taking it to market.\n\nLoop: INVESTIGATE → CITE EVIDENCE → HYPOTHESIS → REPORT → REPAIR → LIST → AUCTION.",
				"유물을 조사해 단서와 출처를 비교하고, 필요한 만큼만 수리해 시장에 내놓습니다.\n\n흐름: [단서 조사 → 근거 인용 → 가설 → 보고서 → 수리 → 출품 → 경매]"
			)
		},
		{
			"title": _copy("WHAT COUNTS AS GOOD PLAY?", "무엇을 잘해야 하나요?"),
			"body": _copy(
				"A good result balances three things: EVIDENCE — use trustworthy sources; PRESERVATION — avoid erasing real history; SALE — disclose and price only what you can support.\n\nAsk: What do I know, and what could this action damage?",
				"좋은 플레이는 세 가지를 함께 봅니다. [근거]는 믿을 만한 출처로 결론을 뒷받침하고, [보존]은 실제 역사를 지우지 않으며, [판매]는 입증한 만큼만 공개·가격을 정합니다.\n\n선택할 때는 ‘무엇을 알고 있고, 무엇을 손상시킬 수 있나?’만 확인하세요."
			)
		},
		{
			"title": _copy("HOW THIS TUTORIAL WORKS", "튜토리얼은 이렇게 진행됩니다"),
			"body": _copy(
				"The next control will be highlighted while the rest of the screen dims. Read the short bubble, then use only that control.\n\nThe tutorial moves on after the real gameplay action succeeds.",
				"다음에 눌러야 할 곳만 밝게 강조됩니다. 짧은 말풍선을 읽고 강조된 곳만 누르세요.\n\n실제 게임 행동이 성공하면 다음 단계로 넘어갑니다."
			)
		}
	]


func _show_intro_page() -> void:
	_remove_overlay()
	var pages := _intro_pages()
	intro_page = clampi(intro_page, 0, pages.size() - 1)
	var page: Dictionary = pages[intro_page]
	var overlay := Control.new()
	overlay.name = OVERLAY_NAME
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 1800
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interface.add_child(overlay)

	var dim := ColorRect.new()
	dim.name = "TutorialIntroDim"
	dim.color = Color(0.0, 0.0, 0.0, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	# The welcome needs to orient a first-time player, not become a reading
	# checkpoint. Keep the card within compact desktop and portrait-safe bounds;
	# the authored copy above is intentionally short enough to avoid scrolling at
	# the default desktop viewport.
	var panel_width := minf(860.0, maxf(280.0, interface.size.x - 32.0))
	var panel_height := minf(560.0, maxf(360.0, interface.size.y * 0.58))
	var panel := PanelContainer.new()
	panel.name = "TutorialIntroPanel"
	panel.position = Vector2((interface.size.x - panel_width) * 0.5, (interface.size.y - panel_height) * 0.42)
	panel.size = Vector2(panel_width, panel_height)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#11191dfb"), Color("#e3c681"), 4))
	overlay.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var progress := _label("%s %d / %d" % [_copy("WELCOME", "게임 안내"), intro_page + 1, pages.size()], 18, Color("#9fd6bd"))
	progress.name = "TutorialIntroProgress"
	column.add_child(progress)
	var title := _label(str(page.get("title", "")), 28, Color("#e3c681"))
	title.name = "TutorialIntroTitle"
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.name = "TutorialIntroScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# ScrollContainer does not contribute its child's wrapped height to its
	# parent on the first mobile layout pass. Give portrait onboarding a compact
	# but explicit reading lane *before* the panel is first drawn, so text is
	# never painted underneath its buttons while the responsive font pass runs.
	var physical_size := DisplayServer.window_get_size()
	if physical_size.x > 0 and physical_size.y > physical_size.x * 1.08:
		scroll.custom_minimum_size.y = 480.0
	column.add_child(scroll)
	var body := _label(str(page.get("body", "")), 20, Color("#f2e8cf"))
	body.name = "TutorialIntroBody"
	body.custom_minimum_size.x = panel_width - 70.0
	scroll.add_child(body)

	var next := Button.new()
	next.name = "TutorialIntroNext"
	next.text = _copy("NEXT", "다음") if intro_page < pages.size() - 1 else _copy("START LEARNING", "튜토리얼 시작")
	next.custom_minimum_size.y = 64.0
	next.add_theme_font_size_override("font_size", 20)
	next.pressed.connect(_advance_intro)
	column.add_child(next)

	var skip := Button.new()
	skip.name = "TutorialExpertSkip"
	skip.text = _copy("I ALREADY KNOW THE GAME — SKIP TUTORIAL", "게임 방법을 이미 아는 경우에만 · 튜토리얼 건너뛰기")
	skip.custom_minimum_size.y = 42.0
	skip.add_theme_font_size_override("font_size", 14)
	skip.modulate = Color(0.78, 0.82, 0.82, 0.86)
	skip.pressed.connect(_skip_tutorial)
	column.add_child(skip)


func _advance_intro() -> void:
	var pages := _intro_pages()
	if intro_page < pages.size() - 1:
		intro_page += 1
		_show_intro_page()
		return
	intro_done = true
	intro_page = 0
	_remove_overlay()
	last_target_signature = ""
	pending_signature = ""
	_queue_apply()


func _skip_tutorial() -> void:
	_remove_overlay()
	var result: Dictionary = GameState.skip_tutorial_guidance()
	if not bool(result.get("ok", false)):
		_queue_apply()
		return
	tutorial_was_visible = false
	intro_done = false
	intro_page = 0
	last_target_signature = ""
	pending_signature = ""
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("refresh_current_screen"):
		scene.call_deferred("refresh_current_screen")


func _maybe_show_target_spotlight(state: Dictionary) -> void:
	var target := _find_tutorial_target(state)
	if target == null:
		_remove_overlay()
		return
	var signature := "%d|%s|%s|%d" % [
		int(state.get("step", 0)),
		_screen_name(),
		str(target.name),
		target.get_instance_id()
	]
	if signature == last_target_signature and interface.find_child(OVERLAY_NAME, true, false) != null:
		return
	if signature == pending_signature:
		return
	pending_signature = signature
	_show_target_spotlight_deferred.call_deferred(state.duplicate(true), target, signature)


func _show_target_spotlight_deferred(state: Dictionary, target: Control, signature: String) -> void:
	await get_tree().process_frame
	if target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		pending_signature = ""
		return
	var scroll := _ancestor_scroll(target)
	if scroll != null:
		scroll.ensure_control_visible(target)
		scroll.scroll_horizontal = 0
		await get_tree().process_frame
	if signature != pending_signature or target == null or not is_instance_valid(target):
		return
	pending_signature = ""
	last_target_signature = signature
	_remove_overlay()
	_build_target_spotlight(state, target)


func _ancestor_scroll(target: Control) -> ScrollContainer:
	var current: Node = target.get_parent()
	while current != null and current != interface:
		if current is ScrollContainer:
			return current as ScrollContainer
		current = current.get_parent()
	return null


func _find_tutorial_target(state: Dictionary) -> Control:
	var patterns: Array = []
	var step := int(state.get("step", 0))
	var screen_name := _screen_name()

	if step == 1 and screen_name == "campaign":
		var pending_case := str(GameState.current_stage_first_pending_case())
		if not pending_case.is_empty():
			patterns.append("Case_%s" % pending_case.validate_node_name())

	if step == 6 and screen_name == "auction":
		var hammer := interface.find_child("HammerButton", true, false) as BaseButton
		if hammer == null or not hammer.is_visible_in_tree():
			patterns.append("AuctionCueNext")

	for route_value: Variant in state.get("targets", []):
		var pattern := str(route_value)
		if not pattern.is_empty() and not patterns.has(pattern):
			patterns.append(pattern)

	# Prefer a local action over a global navigation button when both are visible.
	var direct: Array = []
	var nav: Array = []
	for pattern_value: Variant in patterns:
		var pattern := str(pattern_value)
		if pattern.begins_with("Nav_"):
			nav.append(pattern)
		else:
			direct.append(pattern)
	patterns = direct + nav

	for pattern_value: Variant in patterns:
		var pattern := str(pattern_value)
		for candidate: Node in interface.find_children(pattern, "Control", true, false):
			if not candidate is Control:
				continue
			var control := candidate as Control
			if not control.is_visible_in_tree() or control.size.x <= 0.0 or control.size.y <= 0.0:
				continue
			if control is BaseButton and (control as BaseButton).disabled:
				continue
			return control
	return null


func _build_target_spotlight(state: Dictionary, target: Control) -> void:
	if interface == null or not is_instance_valid(interface) or target == null or not is_instance_valid(target):
		return
	var overlay := Control.new()
	overlay.name = OVERLAY_NAME
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 1800
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interface.add_child(overlay)

	# get_global_rect() is expressed in the stretched canvas. The tutorial
	# overlay itself is laid out in R3Interface's local coordinates, so convert
	# through its inverse transform instead of subtracting two scaled positions.
	# Mixing those spaces was what let the bubble sit over the highlighted button
	# on browser/desktop canvas scales.
	var hole := _tutorial_hole_for_target(target)

	_add_dim_rect(overlay, "TutorialDimTop", Rect2(0, 0, interface.size.x, maxf(0.0, hole.position.y)))
	_add_dim_rect(overlay, "TutorialDimBottom", Rect2(0, hole.end.y, interface.size.x, maxf(0.0, interface.size.y - hole.end.y)))
	_add_dim_rect(overlay, "TutorialDimLeft", Rect2(0, hole.position.y, maxf(0.0, hole.position.x), hole.size.y))
	_add_dim_rect(overlay, "TutorialDimRight", Rect2(hole.end.x, hole.position.y, maxf(0.0, interface.size.x - hole.end.x), hole.size.y))

	var outline := PanelContainer.new()
	outline.name = OUTLINE_NAME
	outline.position = hole.position
	outline.size = hole.size
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.z_index = 1802
	outline.add_theme_stylebox_override("panel", _outline_style())
	overlay.add_child(outline)

	# A teaching bubble must explain the next action without becoming a second
	# hit target over it. The older centered/above fallback could be clamped back
	# onto a lower-right case button when the viewport had no vertical room.
	# Choose a compact, fully in-bounds side first and only use a smaller fallback
	# when a very small viewport makes the preferred card impossible.
	var bubble_rect := _tutorial_bubble_rect(hole)

	var bubble := PanelContainer.new()
	bubble.name = BUBBLE_NAME
	bubble.position = bubble_rect.position
	bubble.size = bubble_rect.size
	bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	bubble.z_index = 1803
	bubble.add_theme_stylebox_override("panel", _panel_style(Color("#11191dfb"), Color("#e3c681"), 4))
	overlay.add_child(bubble)
	# Portrait layout intentionally enlarges tutorial text and buttons after this
	# panel is created. Re-place it after that responsive pass using its final
	# size, otherwise a valid initial placement can grow across the target.
	bubble.resized.connect(func() -> void: _queue_bubble_reposition(bubble, target))

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	bubble.add_child(column)
	var step := int(state.get("step", 0))
	var total := int(state.get("total", 0))
	var counter := _label("%s %d/%d" % [_copy("TUTORIAL", "튜토리얼"), step, total], 16, Color("#9fd6bd"))
	counter.name = "TutorialSpotlightCounter"
	column.add_child(counter)
	var heading := _label(str(state.get("title", "")), 22, Color("#e3c681"))
	heading.name = "TutorialSpotlightTitle"
	column.add_child(heading)
	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(body_scroll)
	var body := _label(_spotlight_explanation(step, target), 17, Color("#f2e8cf"))
	body.name = "TutorialSpotlightBody"
	body.custom_minimum_size.x = bubble_rect.size.x - 70.0
	body_scroll.add_child(body)
	var action_hint := _label(
		_copy("NOW TAP ONLY THE HIGHLIGHTED CONTROL.", "지금은 노란 테두리로 강조된 곳만 누르세요."),
		16,
		Color("#9fd6bd")
	)
	action_hint.name = "TutorialSpotlightActionHint"
	column.add_child(action_hint)
	var skip := Button.new()
	skip.name = "TutorialExpertSkip"
	skip.text = _copy("Already know this game? Skip tutorial", "게임 방법을 이미 안다면 · 튜토리얼 건너뛰기")
	skip.custom_minimum_size.y = 42.0
	skip.add_theme_font_size_override("font_size", 14)
	skip.modulate = Color(0.76, 0.80, 0.80, 0.82)
	skip.pressed.connect(_skip_tutorial)
	column.add_child(skip)

	# Audit and off-screen harnesses can construct the production UI without
	# attaching its root to a SceneTree. Focus is presentation-only, so skip it
	# until the target is actually live instead of emitting a runtime error.
	if target.focus_mode != Control.FOCUS_NONE and target.is_inside_tree():
		target.grab_focus()
	_queue_bubble_reposition(bubble, target)


func _tutorial_hole_for_target(target: Control) -> Rect2:
	var local_rect := _control_rect_in_interface_space(target)
	var hole := local_rect.grow(14.0)
	hole.position.x = clampf(hole.position.x, 4.0, interface.size.x - 8.0)
	hole.position.y = clampf(hole.position.y, 4.0, interface.size.y - 8.0)
	hole.size.x = minf(hole.size.x, interface.size.x - hole.position.x - 4.0)
	hole.size.y = minf(hole.size.y, interface.size.y - hole.position.y - 4.0)
	return hole


func _queue_bubble_reposition(bubble: PanelContainer, target: Control) -> void:
	_reposition_bubble_after_layout.call_deferred(bubble, target)


func _reposition_bubble_after_layout(bubble: PanelContainer, target: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if interface == null or not is_instance_valid(interface) or bubble == null or not is_instance_valid(bubble) or target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		return
	bubble.position = _tutorial_bubble_rect(_tutorial_hole_for_target(target), Vector2.ZERO, bubble.size).position


func _tutorial_bubble_rect(hole: Rect2, bounds: Vector2 = Vector2.ZERO, requested_size: Vector2 = Vector2.ZERO) -> Rect2:
	var viewport := bounds if bounds.x > 0.0 and bounds.y > 0.0 else interface.size
	var margin := 28.0
	var gap := 18.0
	var usable_width := maxf(220.0, viewport.x - margin * 2.0)
	var usable_height := maxf(190.0, viewport.y - margin * 2.0)
	var wide_view := viewport.x >= 800.0
	var preferred_size := requested_size if requested_size.x > 0.0 and requested_size.y > 0.0 else Vector2(
		minf(560.0, usable_width),
		minf(320.0 if wide_view else 250.0, maxf(280.0 if wide_view else 210.0, viewport.y * (0.42 if wide_view else 0.34)))
	)
	preferred_size.x = minf(preferred_size.x, usable_width)
	preferred_size.y = minf(preferred_size.y, usable_height)
	var protected_hole := hole.grow(gap)
	# Try the conventional vertical relationship first, then move beside the
	# target. A lower-right primary button therefore gets a left-side explanation
	# instead of a panel that is force-clamped across it.
	for scale_value: float in [1.0, 0.82, 0.66, 0.5]:
		var size := Vector2(
			maxf(minf(260.0, usable_width), preferred_size.x * scale_value),
			maxf(minf(190.0, usable_height), preferred_size.y * scale_value)
		)
		var centered_x := hole.get_center().x - size.x * 0.5
		var centered_y := hole.get_center().y - size.y * 0.5
		var candidates: Array[Rect2] = [
			Rect2(Vector2(centered_x, hole.end.y + gap), size),
			Rect2(Vector2(centered_x, hole.position.y - size.y - gap), size),
			Rect2(Vector2(hole.position.x - size.x - gap, centered_y), size),
			Rect2(Vector2(hole.end.x + gap, centered_y), size)
		]
		for candidate: Rect2 in candidates:
			if _tutorial_bubble_fits(candidate, protected_hole, viewport, margin):
				return candidate

	# Targets are ordinary compact controls, so one of the candidates above is
	# expected. Keep an explicit final fallback for unusual custom layouts and
	# bias it toward the least-overlapping corner rather than silently covering a
	# button.
	var fallback_size := Vector2(minf(preferred_size.x, usable_width), minf(preferred_size.y, usable_height))
	var fallback_candidates: Array[Rect2] = [
		Rect2(Vector2(margin, margin), fallback_size),
		Rect2(Vector2(viewport.x - margin - fallback_size.x, margin), fallback_size),
		Rect2(Vector2(margin, viewport.y - margin - fallback_size.y), fallback_size),
		Rect2(Vector2(viewport.x - margin - fallback_size.x, viewport.y - margin - fallback_size.y), fallback_size)
	]
	var best := fallback_candidates[0]
	var least_overlap := INF
	for candidate: Rect2 in fallback_candidates:
		var overlap := _tutorial_rect_overlap_area(candidate, protected_hole)
		if overlap < least_overlap:
			least_overlap = overlap
			best = candidate
	return best


func _control_rect_in_interface_space(control: Control) -> Rect2:
	var global_rect := control.get_global_rect()
	var inverse_transform := interface.get_global_transform().affine_inverse()
	var local_start := inverse_transform * global_rect.position
	var local_end := inverse_transform * global_rect.end
	return Rect2(local_start, local_end - local_start)


func _tutorial_bubble_fits(candidate: Rect2, protected_hole: Rect2, viewport: Vector2, margin: float) -> bool:
	return candidate.position.x >= margin \
		and candidate.position.y >= margin \
		and candidate.end.x <= viewport.x - margin \
		and candidate.end.y <= viewport.y - margin \
		and not candidate.intersects(protected_hole)


func _tutorial_rect_overlap_area(first: Rect2, second: Rect2) -> float:
	var overlap := first.intersection(second)
	return maxf(0.0, overlap.size.x) * maxf(0.0, overlap.size.y)


func _spotlight_explanation(step: int, target: Control) -> String:
	var target_name := str(target.name)
	if step == 1 and _screen_name() == "campaign":
		return _copy(
			"This is the first case. Open it to begin the investigation loop; the other menus can wait.",
			"첫 실제 사건입니다. 열어서 조사 흐름을 시작하세요. 다른 메뉴는 지금 볼 필요가 없습니다."
		)
	match step:
		1:
			return _copy(
				"A clue is a source, not an answer. Check its source, trust and damage risk, then investigate it to record the finding.",
				"단서는 정답이 아니라 정보의 출처입니다. 출처·신뢰도·손상 위험을 확인한 뒤 조사해서 발견을 기록하세요."
			)
		2:
			return _copy(
				"Discovering a clue is not the same as citing it. Cite only clues that support or test your hypothesis in the report; independent sources make stronger evidence.",
				"단서를 발견했다고 자동으로 인용되지는 않습니다. 가설을 지지하거나 검증하는 단서만 인용해 보고서에 담으세요. 서로 다른 출처면 더 강한 근거가 됩니다."
			)
		3:
			if target_name.begins_with("CaseHypothesis_"):
				return _copy(
					"A hypothesis explains what happened to the relic. Choose the claim your cited clues support best, not the most dramatic one.",
					"가설은 유물에 무슨 일이 있었는지에 대한 설명입니다. 가장 극적인 답이 아니라, 인용한 근거가 가장 잘 뒷받침하는 것을 고르세요."
				)
			return _copy(
				"Submit after choosing a hypothesis and citing relevant evidence. The report is judged by the connection between evidence and conclusion, not by how many clues you opened.",
				"가설과 관련 근거를 고른 뒤 제출하세요. 단서를 많이 누른 것보다, 근거와 결론의 연결이 더 중요합니다."
			)
		4:
			if target_name.begins_with("RepairTool_"):
				return _copy(
					"Repair is not automatically good. Equip a recommended tool and preserve original material whenever possible.",
					"수리는 많이 할수록 좋지 않습니다. 권장 도구를 장착하고 가능한 한 원래 재료를 보존하세요."
				)
			if target_name == "Tool_repair":
				return _copy(
					"Make only the repair the relic needs. Over-restoration can erase authentic wear and historical value.",
					"유물에 필요한 만큼만 수리하세요. 과한 복원은 진짜 마모와 역사적 가치를 지울 수 있습니다."
				)
			return _copy(
				"The report is finished. Return to the relic and decide what to repair — and what to preserve — before sale.",
				"보고서는 끝났습니다. 유물로 돌아가 판매 전에 무엇을 수리하고 보존할지 정하세요."
			)
		5:
			if target_name == "AuthenticateButton":
				return _copy(
					"Authentication turns your investigation into a market conclusion. It must reflect evidence, not a higher-price guess.",
					"인증은 조사 결과를 시장용 결론으로 정리합니다. 더 비싸게 팔기 위한 추측이 아니라 근거를 반영해야 합니다."
				)
			if target_name.begins_with("ListingPrice_"):
				return _copy(
					"Choose a price strategy. Higher targets can earn more but make a no-sale more likely; price is not proof.",
					"가격 전략을 고르세요. 높게 부르면 더 벌 수 있지만 유찰 위험도 커집니다. 가격은 진위의 증거가 아닙니다."
				)
			if target_name.begins_with("ListingDisclosure_"):
				return _copy(
					"Disclosure tells buyers how certain you are. Match it to your evidence; hiding uncertainty can cost trust.",
					"공개 수준은 구매자에게 얼마나 확신 있게 말할지 정합니다. 근거에 맞추고, 불확실성은 숨기지 마세요."
				)
			return _copy(
				"Confirm only when price and disclosure match the evidence, condition and risk you observed. Buyers react to that public information.",
				"가격과 공개 수준이 조사 근거·상태·위험에 맞을 때만 확정하세요. 구매자는 그 공개 정보에 반응합니다."
			)
		6:
			if target_name == "AuctionCueNext":
				return _copy(
					"Advance the auction and read the bids and reasons. They show how the market read your price, disclosure and restoration.",
					"경매를 진행하며 호가와 이유를 읽으세요. 가격·공개·수리를 시장이 어떻게 받아들였는지 보여줍니다."
				)
			return _copy(
				"Record the sale or no-sale result to finish one complete loop: investigate, reason, preserve, present and let the market respond.",
				"낙찰 또는 유찰을 기록하면 한 번의 전체 흐름이 끝납니다: 조사 → 추리 → 보존 → 출품 → 시장 반응."
			)
	return _copy(
		"Read the short explanation, then use only the highlighted control. The tutorial advances when the real action succeeds.",
		"짧은 설명을 읽고 강조된 곳만 누르세요. 실제 행동이 성공하면 다음 단계로 넘어갑니다."
	)


func _reserve_portrait_intro_copy_space() -> void:
	# ScrollContainer does not automatically include its child's wrapped height
	# in a VBox minimum-size calculation. On a portrait canvas that left the
	# welcome copy behind the Next/Skip buttons even though the text existed.
	# Reserve exactly the post-responsive wrapped height; this is presentation
	# only and gives each short page a fully readable first view.
	if interface == null or not is_instance_valid(interface):
		return
	var physical_size := DisplayServer.window_get_size()
	if physical_size.x <= 0 or physical_size.y <= physical_size.x * 1.08:
		return
	var panel := interface.find_child("TutorialIntroPanel", true, false) as PanelContainer
	var scroll := interface.find_child("TutorialIntroScroll", true, false) as ScrollContainer
	var body := interface.find_child("TutorialIntroBody", true, false) as Label
	if panel == null or scroll == null or body == null:
		return
	var required_height := body.get_combined_minimum_size().y
	if required_height <= scroll.custom_minimum_size.y + 1.0:
		return
	scroll.custom_minimum_size.y = required_height
	_fit_portrait_intro_panel.call_deferred(panel)


func _fit_portrait_intro_panel(panel: PanelContainer) -> void:
	await get_tree().process_frame
	if interface == null or not is_instance_valid(interface) or panel == null or not is_instance_valid(panel):
		return
	var required := panel.get_combined_minimum_size()
	panel.size = Vector2(maxf(panel.size.x, required.x), maxf(panel.size.y, required.y))
	panel.position.x = clampf(panel.position.x, 20.0, maxf(20.0, interface.size.x - panel.size.x - 20.0))
	panel.position.y = clampf(panel.position.y, 20.0, maxf(20.0, interface.size.y - panel.size.y - 20.0))


func _add_dim_rect(parent: Control, node_name: String, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var dim := ColorRect.new()
	dim.name = node_name
	dim.position = rect.position
	dim.size = rect.size
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 1801
	parent.add_child(dim)


func _remove_overlay() -> void:
	if interface == null or not is_instance_valid(interface):
		return
	var overlay := interface.find_child(OVERLAY_NAME, true, false)
	if overlay != null:
		overlay.queue_free()


func _screen_name() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	var value: Variant = scene.get("screen")
	return "" if value == null else str(value)


func _ko() -> bool:
	return str(GameState.language) == "ko"


func _copy(en_text: String, ko_text: String) -> String:
	return ko_text if _ko() else en_text


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = -1
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _panel_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style


func _outline_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color("#ffd27a")
	style.set_border_width_all(6)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	return style
