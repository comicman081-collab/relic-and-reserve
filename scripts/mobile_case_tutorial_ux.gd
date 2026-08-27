extends Node

# Focused portrait UX for the investigation loop. It never mutates gameplay,
# RNG, save schema, or case authority; it only rearranges Controls and exposes
# full authored copy that desktop can otherwise leave in tooltips.

const MODAL_NAME := "MobileUXModal"
const ACTION_PANEL_NAME := "MobileNextActionPanel"
const EVIDENCE_STACK_NAME := "MobileCaseEvidenceStack"
const META_BOUND := &"mobile_case_ux_bound"
const META_TILE_BOUND := &"mobile_case_tile_bound"

var interface: Control
var queued := false
var last_tutorial_signature := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_discover.call_deferred()


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
	if not _is_portrait():
		return
	_expand_tutorial_rail()
	_reflow_case_dossier()
	_bind_touch_details()
	_add_next_action_panel()
	_maybe_show_tutorial_coach()


func _is_portrait() -> bool:
	var bridge := get_tree().root.get_node_or_null("MobileWebLayout")
	if bridge != null and bridge.has_method("is_portrait_layout"):
		return bool(bridge.call("is_portrait_layout"))
	return interface != null and interface.size.y > interface.size.x * 1.08


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


func _full_label(label: Label) -> void:
	if label == null:
		return
	label.max_lines_visible = -1
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.clip_text = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _full_button(button: Button, min_height: float) -> void:
	if button == null:
		return
	button.clip_text = false
	button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, min_height)


func _expand_tutorial_rail() -> void:
	var rail := interface.find_child("TutorialGuidanceRail", true, false) as PanelContainer
	if rail == null:
		return
	var state: Dictionary = GameState.tutorial_public_state()
	if not bool(state.get("visible", false)):
		return
	rail.custom_minimum_size.y = maxf(rail.custom_minimum_size.y, 174.0)
	var title_text := str(state.get("title", ""))
	var instruction_text := str(state.get("text", ""))
	if int(state.get("step", 0)) == 1 and _screen_name() == "campaign":
		title_text = _copy("START THE FIRST CASE", "첫 사건 시작")
		instruction_text = _copy(
			"Open the first case below. The guide continues on the clue screen one action at a time.",
			"아래 첫 사건의 시작 버튼을 누르세요. 사건 서류가 열리면 단서 화면부터 한 단계씩 계속 설명합니다."
		)
	var title := rail.find_child("TutorialStepTitle", true, false) as Label
	var instruction := rail.find_child("TutorialStepText", true, false) as Label
	if title != null:
		title.text = title_text
		_full_label(title)
	if instruction != null:
		instruction.text = instruction_text
		_full_label(instruction)


func _reflow_case_dossier() -> void:
	var rows := interface.find_child("CaseDossierRows", true, false) as VBoxContainer
	if rows == null:
		return
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 18)

	var briefing_tile := interface.find_child("CaseTile_briefing", true, false) as Control
	if briefing_tile != null and briefing_tile.get_parent() is GridContainer:
		(briefing_tile.get_parent() as GridContainer).columns = 1

	for summary_node: Node in interface.find_children("CaseTileSummary_*", "Label", true, false):
		var summary := summary_node as Label
		if summary != null:
			_full_label(summary)

	var evidence_cards := interface.find_children("CaseEvidenceCard_*", "Button", true, false)
	if not evidence_cards.is_empty():
		var first_card := evidence_cards[0] as Button
		if first_card != null and first_card.get_parent() is GridContainer:
			var evidence_grid := first_card.get_parent() as GridContainer
			evidence_grid.columns = 1
			if rows.find_child(EVIDENCE_STACK_NAME, true, false) == null:
				var ledger := evidence_grid.get_parent() as Control
				var section: Node = ledger.get_parent() if ledger != null else null
				if section is HBoxContainer:
					_stack_evidence_section(section as HBoxContainer)
		for card_node: Node in evidence_cards:
			_full_button(card_node as Button, 144.0)

	var hypotheses := interface.find_children("CaseHypothesis_*", "Button", true, false)
	if not hypotheses.is_empty():
		var first_hypothesis := hypotheses[0] as Button
		if first_hypothesis != null and first_hypothesis.get_parent() is GridContainer:
			(first_hypothesis.get_parent() as GridContainer).columns = 1
		for hypothesis_node: Node in hypotheses:
			_full_button(hypothesis_node as Button, 128.0)

	for citation_node: Node in interface.find_children("CaseCitation_*", "Button", true, false):
		var citation := citation_node as Button
		_full_button(citation, 118.0)
		if citation != null and citation.get_parent() is GridContainer:
			(citation.get_parent() as GridContainer).columns = 1

	for label_name in ["CaseEvidenceDisplayTitle", "CaseLockedActionTarget", "CaseReportPrompt", "CaseCitationLocator"]:
		_full_label(interface.find_child(label_name, true, false) as Label)

	var resolve := interface.find_child("ResolveCaseReport", true, false) as Button
	_full_button(resolve, 142.0)


func _stack_evidence_section(section: HBoxContainer) -> void:
	var parent := section.get_parent()
	if parent == null:
		return
	var insertion_index := section.get_index()
	var stack := VBoxContainer.new()
	stack.name = EVIDENCE_STACK_NAME
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 16)
	parent.add_child(stack)
	parent.move_child(stack, insertion_index)
	var children := section.get_children()
	for child: Node in children:
		section.remove_child(child)
		stack.add_child(child)
		if child is Control:
			var control := child as Control
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			control.custom_minimum_size.x = 0.0
			if control is PanelContainer:
				control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, 330.0)
	parent.remove_child(section)
	section.queue_free()


func _bind_touch_details() -> void:
	for tile_node: Node in interface.find_children("CaseTile_*", "PanelContainer", true, false):
		_bind_tile(tile_node as PanelContainer)
	for clue_node: Node in interface.find_children("CaseEvidenceCard_*", "Button", true, false):
		_bind_clue(clue_node as Button)
	for hypothesis_node: Node in interface.find_children("CaseHypothesis_*", "Button", true, false):
		_bind_hypothesis(hypothesis_node as Button)
	for label_name in ["CaseReportPrompt", "CaseCitationLocator"]:
		_bind_tooltip_label(interface.find_child(label_name, true, false) as Label)


func _bind_tile(tile: PanelContainer) -> void:
	if tile == null or tile.has_meta(META_TILE_BOUND):
		return
	tile.set_meta(META_TILE_BOUND, true)
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for child_node: Node in tile.find_children("*", "Control", true, false):
		if child_node is Control:
			(child_node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var labels := tile.find_children("*", "Label", true, false)
	var heading := _copy("DETAIL", "전체 내용")
	if not labels.is_empty() and labels[0] is Label:
		heading = str((labels[0] as Label).text)
	var full_text := tile.tooltip_text
	if full_text.is_empty() and labels.size() > 1 and labels[1] is Label:
		full_text = str((labels[1] as Label).text)
	tile.gui_input.connect(func(event: InputEvent) -> void:
		if _is_primary_press(event):
			_show_modal(heading, full_text)
			tile.accept_event()
	)


func _bind_tooltip_label(label: Label) -> void:
	if label == null or label.has_meta(META_BOUND) or label.tooltip_text.is_empty():
		return
	label.set_meta(META_BOUND, true)
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var snapshot := label.tooltip_text
	label.gui_input.connect(func(event: InputEvent) -> void:
		if _is_primary_press(event):
			_show_modal(_copy("FULL TEXT", "전체 내용"), snapshot)
			label.accept_event()
	)


func _bind_clue(button: Button) -> void:
	if button == null or button.has_meta(META_BOUND):
		return
	button.set_meta(META_BOUND, true)
	var suffix := str(button.name).trim_prefix("CaseEvidenceCard_")
	var fallback := button.text.replace("\n", " · ")
	button.pressed.connect(func() -> void:
		_show_selected_clue_modal.call_deferred(suffix, fallback)
	)


func _bind_hypothesis(button: Button) -> void:
	if button == null or button.has_meta(META_BOUND):
		return
	button.set_meta(META_BOUND, true)
	var caption := button.text.replace("\n", " ")
	var claim := button.tooltip_text
	button.pressed.connect(func() -> void:
		_show_modal.call_deferred(_copy("HYPOTHESIS DETAIL", "가설 상세"), "%s\n\n%s" % [caption, claim])
	)


func _show_selected_clue_modal(suffix: String, fallback: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if interface == null or not is_instance_valid(interface):
		return
	var title_label := interface.find_child("CaseEvidenceDisplayTitle", true, false) as Label
	var detail_panel := _ancestor_panel(title_label)
	var lines: Array = []
	if detail_panel != null:
		for label_node: Node in detail_panel.find_children("*", "Label", true, false):
			var label := label_node as Label
			if label != null:
				var value := label.text.strip_edges()
				if not value.is_empty() and not lines.has(value):
					lines.append(value)
	var heading := fallback
	if title_label != null and not title_label.text.is_empty():
		heading = title_label.text
	var body_text := fallback if lines.is_empty() else "\n\n".join(lines)
	var action_target: Button = null
	var investigate := interface.find_child("CaseEvidence_%s" % suffix, true, false) as Button
	var cite := interface.find_child("CaseCitation_%s" % suffix, true, false) as Button
	if investigate != null and investigate.is_visible_in_tree() and not investigate.disabled:
		action_target = investigate
	elif cite != null and cite.is_visible_in_tree() and not cite.disabled:
		action_target = cite
	_show_modal(heading, body_text, action_target)


func _ancestor_panel(node: Node) -> PanelContainer:
	var current: Node = node
	while current != null and current != interface:
		if current is PanelContainer:
			return current as PanelContainer
		current = current.get_parent()
	return null


func _is_primary_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	return false


func _add_next_action_panel() -> void:
	var rows := interface.find_child("CaseDossierRows", true, false) as VBoxContainer
	if rows == null or rows.find_child(ACTION_PANEL_NAME, true, false) != null:
		return
	var panel := PanelContainer.new()
	panel.name = ACTION_PANEL_NAME
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 168.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#132722f2"), Color("#9fd6bd"), 3))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = _copy("WHAT TO DO NOW", "지금 할 일")
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color("#e3c681"))
	_full_label(heading)
	column.add_child(heading)
	var explanation := Label.new()
	explanation.name = "MobileNextActionText"
	explanation.text = _next_action_text()
	explanation.add_theme_font_size_override("font_size", 15)
	explanation.add_theme_color_override("font_color", Color("#f2e8cf"))
	_full_label(explanation)
	column.add_child(explanation)
	var touch_hint := Label.new()
	touch_hint.text = _copy(
		"Tap a clue, situation, question, goal, or hypothesis card to read the full text.",
		"단서·상황·핵심 질문·목표·가설 카드를 누르면 잘리지 않은 전체 설명이 열립니다."
	)
	touch_hint.add_theme_font_size_override("font_size", 14)
	touch_hint.add_theme_color_override("font_color", Color("#9fd6bd"))
	_full_label(touch_hint)
	column.add_child(touch_hint)
	var tutorial_state: Dictionary = GameState.tutorial_public_state()
	if bool(tutorial_state.get("visible", false)):
		var help := Button.new()
		help.name = "MobileTutorialHelpButton"
		help.text = _copy("SHOW THIS GUIDE AGAIN", "현재 튜토리얼 크게 보기")
		help.custom_minimum_size.y = 94.0
		help.pressed.connect(func() -> void: _show_tutorial_coach(tutorial_state, true))
		column.add_child(help)
	rows.add_child(panel)
	rows.move_child(panel, 0)


func _next_action_text() -> String:
	var state: Dictionary = GameState.tutorial_public_state()
	if bool(state.get("visible", false)):
		return "%s\n%s" % [str(state.get("title", "")), _tutorial_explanation(int(state.get("step", 0)))]
	for node: Node in interface.find_children("CaseEvidence_*", "Button", true, false):
		var button := node as Button
		if button != null and button.is_visible_in_tree() and not button.disabled:
			return _copy(
				"Open a clue card, read its source, trust and risk, then use BEGIN INVESTIGATION.",
				"단서 카드를 눌러 출처·신뢰도·위험을 읽은 뒤 [조사 실행]을 누르세요."
			)
	for node: Node in interface.find_children("CaseCitation_*", "Button", true, false):
		var button := node as Button
		if button != null and button.is_visible_in_tree() and not button.disabled:
			return _copy(
				"Add useful found clues to the report, then compare the hypotheses.",
				"확인한 단서 중 근거로 쓸 것을 [보고서에 인용]한 뒤 가설을 비교하세요."
			)
	return _copy(
		"Read the central question, compare clues, choose a hypothesis, and submit when ready.",
		"핵심 질문을 읽고 단서를 비교한 뒤 가설을 선택하고 준비되면 보고서를 제출하세요."
	)


func _maybe_show_tutorial_coach() -> void:
	var state: Dictionary = GameState.tutorial_public_state()
	if not bool(state.get("visible", false)) or not _tutorial_target_visible(state):
		return
	var signature := "%d|%s|%s" % [int(state.get("step", 0)), _screen_name(), str(GameState.current_stage)]
	if signature == last_tutorial_signature:
		return
	last_tutorial_signature = signature
	_show_tutorial_coach(state, false)


func _tutorial_target_visible(state: Dictionary) -> bool:
	if int(state.get("step", 0)) == 1 and _screen_name() == "campaign":
		return true
	for pattern_value: Variant in state.get("targets", []):
		var pattern := str(pattern_value)
		for candidate: Node in interface.find_children(pattern, "Control", true, false):
			if candidate is Control and (candidate as Control).is_visible_in_tree():
				if candidate is BaseButton and (candidate as BaseButton).disabled:
					continue
				return true
	return false


func _show_tutorial_coach(state: Dictionary, force: bool) -> void:
	if not force and interface.find_child(MODAL_NAME, true, false) != null:
		return
	var step := int(state.get("step", 0))
	var total := int(state.get("total", 0))
	var title := str(state.get("title", ""))
	var authored := str(state.get("text", ""))
	if step == 1 and _screen_name() == "campaign":
		title = _copy("START THE FIRST CASE", "첫 사건 시작")
		authored = _copy(
			"Press the first case START button. The next screen teaches clue reading and investigation.",
			"첫 사건의 [시작] 버튼을 누르세요. 다음 화면에서 단서 읽기와 조사 방법을 바로 이어서 설명합니다."
		)
	var text := "%s\n\n%s\n\n%s" % [_copy("DO THIS", "해야 할 일"), authored, _tutorial_explanation(step)]
	_show_modal(
		"%s %d/%d — %s" % [_copy("TUTORIAL", "튜토리얼"), step, total, title],
		text,
		null,
		_copy("GOT IT — SHOW THE TARGET", "확인하고 따라하기")
	)


func _tutorial_explanation(step: int) -> String:
	if _screen_name() == "campaign" and step == 1:
		return _copy(
			"Only the first case route matters now. Ignore the other menus until the dossier opens.",
			"지금은 다른 메뉴를 볼 필요 없습니다. 첫 사건을 열면 사건 서류에서 실제 조사 순서를 계속 안내합니다."
		)
	match step:
		1:
			return _copy(
				"Tap a READY clue. Read source, trust and damage risk in the full popup. Then use its investigation action. LOCKED clues tell you what must be done first.",
				"[조사 가능] 단서를 누르세요. 전체 설명창에서 출처·신뢰도·손상 위험을 먼저 읽고, 이해했으면 [조사 실행]을 누릅니다. [잠김] 단서는 먼저 해야 할 조건을 알려줍니다."
			)
		2:
			return _copy(
				"A found clue is not automatically in the report. Reopen it, read the result, then ADD TO REPORT. Supporting and refuting clues are both useful.",
				"조사한 단서는 자동으로 보고서에 들어가지 않습니다. 확인한 단서를 다시 열어 내용을 읽고 [보고서에 인용]을 누르세요. 지지 단서와 반박 단서 모두 근거가 됩니다."
			)
		3:
			return _copy(
				"Read the central question again. Tap each hypothesis to read its full claim, choose the one best supported by cited clues, then submit. Independent sources strengthen the conclusion.",
				"핵심 질문을 다시 읽으세요. 가설을 누르면 전체 주장이 열립니다. 인용한 단서에 가장 잘 맞는 가설을 선택해 보고서를 제출하세요. 서로 다른 독립 출처가 많을수록 결론이 탄탄해집니다."
			)
		4:
			return _copy(
				"After the report, return to the relic. Equip one recommended repair tool, read the trade-off, and repair only what is needed. Excess intervention can reduce historical value.",
				"보고서를 마치면 유물 검사로 돌아갑니다. 권장 수리 도구 중 하나를 장착하고 수리 판단 설명을 읽은 뒤 필요한 부분만 수리하세요. 과한 개입은 역사적 가치를 낮출 수 있습니다."
			)
		5:
			return _copy(
				"Authenticate the relic, then choose price strategy and disclosure. Match both to the evidence you actually found, then confirm listing.",
				"유물을 인증한 뒤 가격 전략과 공개 수준을 고릅니다. 실제로 확보한 근거 수준에 맞춰 둘을 선택한 뒤 출품을 확정하세요."
			)
		6:
			return _copy(
				"Read the public bids and bidder reasons. Advance the cues to the final result, then use the hammer/record action to commit the sale result.",
				"공개 호가와 입찰자 이유를 읽으세요. 마지막 결과까지 장면을 진행한 뒤 [망치/결과 기록]을 눌러 판매 결과를 확정합니다."
		_:
			return _copy(
				"Follow the highlighted control. The guide advances only when that gameplay action really succeeds.",
				"강조된 버튼을 따라가세요. 해당 실제 행동이 성공했을 때만 튜토리얼이 다음 단계로 넘어갑니다."
			)


func _show_modal(title_text: String, body_text: String, action_target: Button = null, close_text: String = "") -> void:
	if interface == null or not is_instance_valid(interface):
		return
	var previous := interface.find_child(MODAL_NAME, true, false)
	if previous != null:
		previous.queue_free()
	var overlay := ColorRect.new()
	overlay.name = MODAL_NAME
	overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1000
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interface.add_child(overlay)

	var panel := PanelContainer.new()
	panel.name = "MobileUXModalPanel"
	var side := 72.0
	var panel_width := maxf(720.0, interface.size.x - side * 2.0)
	var panel_height := minf(1320.0, maxf(760.0, interface.size.y * 0.64))
	panel.position = Vector2((interface.size.x - panel_width) * 0.5, maxf(160.0, (interface.size.y - panel_height) * 0.36))
	panel.size = Vector2(panel_width, panel_height)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#11191df8"), Color("#e3c681"), 3))
	overlay.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	var heading := Label.new()
	heading.name = "ModalTitle"
	heading.text = title_text
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color("#e3c681"))
	_full_label(heading)
	column.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.name = "ModalScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := Label.new()
	body.name = "ModalBody"
	body.text = body_text
	body.custom_minimum_size.x = panel_width - 70.0
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color("#f2e8cf"))
	_full_label(body)
	scroll.add_child(body)

	if action_target != null and is_instance_valid(action_target) and action_target.is_visible_in_tree() and not action_target.disabled:
		var action := Button.new()
		action.name = "ModalPrimaryAction"
		action.text = action_target.text
		action.custom_minimum_size.y = 132.0
		_full_button(action, 132.0)
		action.pressed.connect(func() -> void:
			if is_instance_valid(overlay):
				overlay.queue_free()
			if is_instance_valid(action_target) and not action_target.disabled:
				action_target.pressed.emit()
		)
		column.add_child(action)

	var close_button := Button.new()
	close_button.name = "ModalClose"
	close_button.text = close_text if not close_text.is_empty() else _copy("CLOSE", "닫기")
	close_button.custom_minimum_size.y = 118.0
	_full_button(close_button, 118.0)
	close_button.pressed.connect(func() -> void:
		if is_instance_valid(overlay):
			overlay.queue_free()
	)
	column.add_child(close_button)


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
