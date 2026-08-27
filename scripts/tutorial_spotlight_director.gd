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
				"RELIC & RESERVE is an investigation, restoration and auction game. You examine old objects, compare clues and sources, decide what probably happened to the object, preserve or repair it with restraint, then present it honestly to the market.\n\nThe basic loop is: INVESTIGATE → CITE EVIDENCE → CHOOSE A HYPOTHESIS → REPORT → REPAIR → AUTHENTICATE/LIST → AUCTION.",
				"RELIC & RESERVE는 유물을 조사하고 추리한 뒤, 필요한 만큼만 복원해서 시장에 내놓는 조사·복원·경매 게임입니다. 오래된 물건의 단서와 출처를 비교해 무엇이 진실에 가까운지 판단하고, 역사적 가치를 해치지 않게 수리한 뒤 근거에 맞게 출품합니다.\n\n기본 흐름은 [단서 조사 → 근거 인용 → 가설 선택 → 보고서 → 수리 → 인증/출품 → 경매]입니다."
			)
		},
		{
			"title": _copy("WHAT COUNTS AS GOOD PLAY?", "무엇을 잘해야 하나요?"),
			"body": _copy(
				"Money is only one result. Good play balances three ideas: EVIDENCE — conclusions should be supported by trustworthy, preferably independent sources; PRESERVATION — do not erase authentic age or history by over-repairing; SALE — price and disclosure should match what you can actually prove.\n\nWhen the game asks you to make a choice, ask: What do I know? How reliable is it? What could this action damage? What can I honestly claim to a buyer?",
				"돈만 많이 버는 것이 전부가 아닙니다. 좋은 플레이는 세 가지를 함께 봅니다. [근거]는 신뢰할 만하고 가능하면 서로 독립된 출처로 결론을 뒷받침해야 하고, [보존]은 과한 수리로 진짜 세월과 역사를 지우지 않아야 하며, [판매]는 실제로 입증한 만큼만 가격과 공개 수준에 반영해야 합니다.\n\n선택할 때마다 ‘내가 지금 확실히 아는 것은 무엇인가? 이 출처는 믿을 만한가? 이 행동이 유물을 손상시킬 수 있는가? 구매자에게 어디까지 정직하게 말할 수 있는가?’를 생각하면 됩니다."
			)
		},
		{
			"title": _copy("HOW THIS TUTORIAL WORKS", "튜토리얼은 이렇게 진행됩니다"),
			"body": _copy(
				"From now on the screen will dim and only the control you should use next will stay highlighted. A speech bubble beside it explains what the control means, why you are using it and what to look for.\n\nDuring an action step, do not hunt through the whole screen. Read the bubble, then tap the highlighted control. The tutorial advances only after the real gameplay action succeeds.",
				"이제부터 화면이 어두워지고, 지금 눌러야 할 곳만 밝은 테두리로 강조됩니다. 옆 말풍선에서 ‘이 버튼이 무엇인지, 왜 지금 눌러야 하는지, 무엇을 확인해야 하는지’를 설명합니다.\n\n행동 단계에서는 화면 전체를 뒤질 필요가 없습니다. 말풍선을 읽고 강조된 곳만 누르세요. 실제 게임 행동이 성공했을 때만 다음 단계로 넘어갑니다."
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

	var panel_width := minf(920.0, maxf(560.0, interface.size.x - 120.0))
	var panel_height := minf(980.0, maxf(620.0, interface.size.y * 0.62))
	var panel := PanelContainer.new()
	panel.name = "TutorialIntroPanel"
	panel.position = Vector2((interface.size.x - panel_width) * 0.5, (interface.size.y - panel_height) * 0.42)
	panel.size = Vector2(panel_width, panel_height)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#11191dfb"), Color("#e3c681"), 4))
	overlay.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	panel.add_child(column)

	var progress := _label("%s %d / %d" % [_copy("WELCOME", "게임 안내"), intro_page + 1, pages.size()], 18, Color("#9fd6bd"))
	progress.name = "TutorialIntroProgress"
	column.add_child(progress)
	var title := _label(str(page.get("title", "")), 30, Color("#e3c681"))
	title.name = "TutorialIntroTitle"
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := _label(str(page.get("body", "")), 23, Color("#f2e8cf"))
	body.name = "TutorialIntroBody"
	body.custom_minimum_size.x = panel_width - 70.0
	scroll.add_child(body)

	var next := Button.new()
	next.name = "TutorialIntroNext"
	next.text = _copy("NEXT", "다음") if intro_page < pages.size() - 1 else _copy("START LEARNING", "튜토리얼 시작")
	next.custom_minimum_size.y = 104.0
	next.add_theme_font_size_override("font_size", 22)
	next.pressed.connect(_advance_intro)
	column.add_child(next)

	var skip := Button.new()
	skip.name = "TutorialExpertSkip"
	skip.text = _copy("I ALREADY KNOW THE GAME — SKIP TUTORIAL", "게임 방법을 이미 아는 경우에만 · 튜토리얼 건너뛰기")
	skip.custom_minimum_size.y = 74.0
	skip.add_theme_font_size_override("font_size", 16)
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

	var interface_rect := interface.get_global_rect()
	var target_rect := target.get_global_rect()
	var local_rect := Rect2(target_rect.position - interface_rect.position, target_rect.size)
	var hole := local_rect.grow(14.0)
	hole.position.x = clampf(hole.position.x, 4.0, interface.size.x - 8.0)
	hole.position.y = clampf(hole.position.y, 4.0, interface.size.y - 8.0)
	hole.size.x = minf(hole.size.x, interface.size.x - hole.position.x - 4.0)
	hole.size.y = minf(hole.size.y, interface.size.y - hole.position.y - 4.0)

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

	var bubble_width := minf(900.0, maxf(520.0, interface.size.x - 96.0))
	var bubble_height := 390.0 if interface.size.y < 1100.0 else 470.0
	var bubble_x := clampf(hole.position.x + hole.size.x * 0.5 - bubble_width * 0.5, 36.0, interface.size.x - bubble_width - 36.0)
	var below_y := hole.end.y + 26.0
	var above_y := hole.position.y - bubble_height - 26.0
	var bubble_y := below_y if below_y + bubble_height <= interface.size.y - 30.0 else above_y
	bubble_y = clampf(bubble_y, 30.0, maxf(30.0, interface.size.y - bubble_height - 30.0))

	var bubble := PanelContainer.new()
	bubble.name = BUBBLE_NAME
	bubble.position = Vector2(bubble_x, bubble_y)
	bubble.size = Vector2(bubble_width, bubble_height)
	bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	bubble.z_index = 1803
	bubble.add_theme_stylebox_override("panel", _panel_style(Color("#11191dfb"), Color("#e3c681"), 4))
	overlay.add_child(bubble)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	bubble.add_child(column)
	var step := int(state.get("step", 0))
	var total := int(state.get("total", 0))
	var counter := _label("%s %d/%d" % [_copy("TUTORIAL", "튜토리얼"), step, total], 16, Color("#9fd6bd"))
	counter.name = "TutorialSpotlightCounter"
	column.add_child(counter)
	var heading := _label(str(state.get("title", "")), 25, Color("#e3c681"))
	heading.name = "TutorialSpotlightTitle"
	column.add_child(heading)
	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(body_scroll)
	var body := _label(_spotlight_explanation(step, target), 19, Color("#f2e8cf"))
	body.name = "TutorialSpotlightBody"
	body.custom_minimum_size.x = bubble_width - 70.0
	body_scroll.add_child(body)
	var action_hint := _label(
		_copy("NOW TAP ONLY THE HIGHLIGHTED CONTROL ABOVE/BELOW.", "지금은 노란 테두리로 강조된 곳만 누르세요."),
		18,
		Color("#9fd6bd")
	)
	action_hint.name = "TutorialSpotlightActionHint"
	column.add_child(action_hint)
	var skip := Button.new()
	skip.name = "TutorialExpertSkip"
	skip.text = _copy("Already know this game? Skip tutorial", "게임 방법을 이미 안다면 · 튜토리얼 건너뛰기")
	skip.custom_minimum_size.y = 58.0
	skip.add_theme_font_size_override("font_size", 14)
	skip.modulate = Color(0.76, 0.80, 0.80, 0.82)
	skip.pressed.connect(_skip_tutorial)
	column.add_child(skip)

	# Audit and off-screen harnesses can construct the production UI without
	# attaching its root to a SceneTree. Focus is presentation-only, so skip it
	# until the target is actually live instead of emitting a runtime error.
	if target.focus_mode != Control.FOCUS_NONE and target.is_inside_tree():
		target.grab_focus()


func _spotlight_explanation(step: int, target: Control) -> String:
	var target_name := str(target.name)
	if step == 1 and _screen_name() == "campaign":
		return _copy(
			"This is the first real case. Opening it starts the investigation loop you just learned about. You do not need the market, upgrades or other menus yet — first learn how a case works.",
			"여기가 첫 실제 사건입니다. 이 사건을 열면 방금 설명한 ‘조사 → 추리’ 흐름이 시작됩니다. 지금은 시장이나 업그레이드 같은 다른 메뉴를 볼 필요가 없습니다. 먼저 사건 하나를 어떻게 푸는지 익히면 됩니다."
		)
	match step:
		1:
			return _copy(
				"A clue is an information source, not an automatic answer. Open this READY clue and read three things before acting: where the information comes from, how trustworthy it is, and whether investigating it can damage the object. Then run the investigation to record what you actually found.",
				"단서는 자동으로 정답을 주는 버튼이 아니라 ‘정보의 출처’입니다. 이 [조사 가능] 단서를 열고 행동하기 전에 세 가지를 읽으세요. 어디서 나온 정보인지, 얼마나 믿을 만한지, 조사 과정이 유물을 손상시킬 위험이 있는지입니다. 확인한 뒤 [조사 실행]으로 실제 발견 내용을 기록합니다."
			)
		2:
			return _copy(
				"Finding a clue and using it as evidence are different decisions. Read the result again, then cite it only if it helps explain or challenge your hypothesis. A strong report uses relevant evidence from more than one independent source when possible.",
				"단서를 ‘발견하는 것’과 그 단서를 ‘보고서의 근거로 쓰는 것’은 다른 판단입니다. 결과를 다시 읽고, 가설을 설명하거나 반박하는 데 도움이 되는 단서라면 인용하세요. 가능하면 서로 다른 독립 출처의 관련 근거를 함께 쓰는 보고서가 더 강합니다."
			)
		3:
			if target_name.begins_with("CaseHypothesis_"):
				return _copy(
					"A hypothesis is your proposed explanation of what happened to the object. Do not pick the most dramatic answer. Compare it with the clues you cited and choose the claim that those sources actually support best.",
					"가설은 ‘이 유물에 실제로 무슨 일이 있었는가’에 대한 당신의 설명입니다. 가장 그럴듯해 보이거나 극적인 답을 찍는 것이 아닙니다. 인용한 단서와 하나씩 비교해서, 실제 근거가 가장 잘 뒷받침하는 주장을 고르세요."
				)
			return _copy(
				"This submits your investigation report. Before pressing it, make sure you selected a hypothesis and cited evidence that genuinely supports or tests it. The game evaluates the quality of the reasoning, not just whether you pressed every available clue.",
				"이 버튼은 조사 보고서를 제출합니다. 누르기 전에 가설을 선택했고, 그 가설을 실제로 지지하거나 검증하는 근거를 인용했는지 확인하세요. 이 게임은 단서를 전부 눌렀는지가 아니라 ‘어떤 근거로 어떤 결론을 냈는지’를 봅니다."
			)
		4:
			if target_name.begins_with("RepairTool_"):
				return _copy(
					"Repairs are not automatically good. Equip one of the recommended tools because the tool changes what kind of intervention you can safely make. Preserve original material whenever possible.",
					"수리는 많이 할수록 좋은 것이 아닙니다. 권장 도구 하나를 장착하세요. 어떤 도구를 쓰느냐에 따라 안전하게 할 수 있는 개입이 달라지고, 가능하면 원래 재료와 세월의 흔적을 보존해야 합니다."
				)
			if target_name == "Tool_repair":
				return _copy(
					"Now make only the repair the object actually needs. Over-restoration can erase authentic wear and reduce historical integrity even when the object looks cleaner afterward.",
					"이제 유물에 실제로 필요한 만큼만 수리하세요. 겉보기에는 깨끗해져도 과한 복원은 진짜 마모와 역사적 흔적을 지워 역사적 가치를 낮출 수 있습니다."
				)
			return _copy(
				"The investigation report is finished. Return to the physical relic so you can decide what should — and should not — be repaired before sale.",
				"추리 보고서는 끝났습니다. 이제 실제 유물로 돌아가 판매 전에 무엇을 수리해야 하고 무엇은 그대로 보존해야 하는지 판단합니다."
			)
		5:
			if target_name == "AuthenticateButton":
				return _copy(
					"Authentication turns your investigation into a market-facing conclusion. It should reflect the evidence you collected, not a guess made for a higher price.",
					"인증은 지금까지의 조사 결과를 시장에 제시할 결론으로 바꾸는 단계입니다. 더 비싸게 팔기 위한 추측이 아니라, 실제로 확보한 근거 수준을 반영해야 합니다."
				)
			if target_name.begins_with("ListingPrice_"):
				return _copy(
					"Choose how aggressively to price the lot. A higher target can pay more, but it also raises the chance that bidders walk away. Price is a strategy, not proof of authenticity.",
					"출품 가격 전략을 고릅니다. 높은 가격을 노리면 수익 가능성은 커지지만 입찰자가 떠날 위험도 커집니다. 가격이 높다고 진품이 되는 것은 아니며, 가격은 어디까지나 판매 전략입니다."
				)
			if target_name.begins_with("ListingDisclosure_"):
				return _copy(
					"Disclosure tells buyers how confidently you present the object's history and condition. Match it to what your evidence can honestly support; hiding uncertainty may hurt trust and future reputation.",
					"공개 수준은 구매자에게 이 유물의 이력과 상태를 얼마나 확신 있게 말할지 정합니다. 실제 근거가 뒷받침하는 만큼만 정직하게 공개하세요. 불확실성을 숨기면 신뢰와 이후 평판에 손해가 될 수 있습니다."
				)
			return _copy(
				"Confirm the listing only after price and disclosure match the evidence, condition and risk you observed. Once listed, bidders react to the public information you chose to present.",
				"가격 전략과 공개 수준이 조사 근거·유물 상태·위험에 맞는지 확인한 뒤 출품을 확정하세요. 출품이 시작되면 입찰자들은 당신이 공개한 정보와 유물 상태에 반응합니다."
			)
		6:
			if target_name == "AuctionCueNext":
				return _copy(
					"Do not rush to the hammer. Advance the auction scene and read the bids and bidder reasons. They show how the market interpreted your price, disclosure, restoration and confidence.",
					"망치를 바로 누르지 마세요. 경매 장면을 진행하면서 호가와 입찰 이유를 읽으세요. 입찰자 반응은 당신의 가격·공개 수준·복원 상태·신뢰도를 시장이 어떻게 받아들였는지 보여줍니다."
				)
			return _copy(
				"This records the final sale or no-sale result. After recording it, one complete relic loop is finished: investigate, reason, preserve, present and let the market respond.",
				"이 버튼으로 최종 낙찰 또는 유찰 결과를 기록합니다. 기록이 끝나면 ‘조사 → 추리 → 보존/수리 → 출품 → 시장 반응’이라는 유물 한 개의 전체 루프를 한 번 완주한 것입니다."
			)
	return _copy(
		"Read the explanation, then use only the highlighted control. The tutorial advances when the real gameplay action succeeds.",
		"설명을 읽고 강조된 곳만 누르세요. 실제 게임 행동이 성공하면 다음 단계로 넘어갑니다."
	)


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
