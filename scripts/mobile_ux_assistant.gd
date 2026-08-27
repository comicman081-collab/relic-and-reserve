extends Node

# Portrait-only usability bridge for the authored R3 UI.
# Gameplay/save authority stays in GameState/main3d. This layer only changes
# presentation: readable one-column dossier geometry, full-text touch details,
# a persistent next-action card, and step-by-step tutorial coaching.

const META_BOUND := &"mobile_ux_bound"
const META_TILE_BOUND := &"mobile_ux_tile_bound"
const META_BASE_FONT := &"mobile_base_font_size"
const MODAL_NAME := "MobileUXModal"
const ACTION_PANEL_NAME := "MobileNextActionPanel"
const EVIDENCE_STACK_NAME := "MobileCaseEvidenceStack"

var interface: Control
var enhance_queued := false
var last_tutorial_signature := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_discover_interface.call_deferred()


func _discover_interface() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var candidate := scene.find_child("R3Interface", true, false)
	if candidate is Control:
		_attach_interface(candidate)


func _on_node_added(node: Node) -> void:
	if node is Control and node.name == "R3Interface":
		_attach_interface(node)
		return
	if interface != null and is_instance_valid(interface) and interface.is_ancestor_of(node):
		_queue_enhance()


func _attach_interface(candidate: Control) -> void:
	interface = candidate
	_queue_enhance()


func _queue_enhance() -> void:
	if enhance_queued:
		return
	enhance_queued = true
	_enhance_deferred.call_deferred()


func _enhance_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	enhance_queued = false
	if interface == null or not is_instance_valid(interface) or not interface.is_inside_tree():
		_discover_interface()
		return
	if not _is_portrait():
		return
	_tune_tutorial_rail()
	_tune_case_dossier()
	_bind_full_text_controls()
	_add_next_action_panel()
	_maybe_show_tutorial_coach()


func _is_portrait() -> bool:
	var bridge := get_tree().root.get_node_or_null("MobileWebLayout")
	if bridge != null and bridge.has_method("is_portrait_layout"):
		return bool(bridge.call("is_portrait_layout"))
	return interface != null and interface.size.y > interface.size.x * 1.08


func _scene_screen() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	var value: Variant = scene.get("screen")
	return String(value) if value != null else ""


func _is_korean() -> bool:
	return String(GameState.language) == "ko"


func _copy(en_text: String, ko_text: String) -> String:
	return ko_text if _is_korean() else en_text


func _set_target_font(control: Control, logical_size: int, is_button: bool = false) -> void:
	var mobile_scale := 3.0 if is_button else 2.4
	control.set_meta(META_BASE_FONT, maxi(1, roundi(float(logical_size) / mobile_scale)))
	control.add_theme_font_size_override("font_size", logical_size)


func _untrim_label(label: Label, logical_size: int = 25) -> void:
	label.max_lines_visible = -1
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.clip_text = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_target_font(label, logical_size, false)


func _untrim_button(button: Button, logical_size: int = 27) -> void:
	button.clip_text = false
	button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_target_font(button, logical_size, true)


func _tune_tutorial_rail() -> void:
	var rail := interface.find_child("TutorialGuidanceRail", true, false) as PanelContainer
	if rail == null:
		return
	rail.custom_minimum_size = Vector2(0, 174)
	var state: Dictionary = GameState.tutorial_public_state()
	var screen_name := _scene_screen()
	var title_text := String(state.get("title", ""))
	var instruction_text := String(state.get("text", ""))
	if int(state.get("step", 0)) == 1 and screen_name == "campaign":
		title_text = _copy("START THE FIRST CASE", "첫 사건 시작")
		instruction_text = _copy("Open the first case below. The guide will then explain the clue screen one action at a time.", "아래 첫 사건의 시작 버튼을 누르세요. 사건 서류가 열리면 단서 화면부터 한 단계씩 계속 설명합니다.")
	var title := rail.find_child("TutorialStepTitle", true, false) as Label
	var instruction := rail.find_child("TutorialStepText", true, false) as Label
	var counter := rail.find_child("TutorialStepCounter", true, false) as Label
	if title != null:
		title.text = title_text
		_untrim_label(title, 30)
	if instruction != null:
		instruction.text = instruction_text
		_untrim_label(instruction, 25)
	if counter != null:
		counter.custom_minimum_size = Vector2(150, 0)
		_untrim_label(counter, 23)


func _tune_case_dossier() -> void:
	var rows := interface.find_child("CaseDossierRows", true, false) as VBoxContainer
	if rows == null:
		return
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 18)

	var overview_tile := interface.find_child("CaseTile_briefing", true, false) as Control
	if overview_tile != null and overview_tile.get_parent() is GridContainer:
		(overview_tile.get_parent() as GridContainer).columns = 1

	for summary_node: Node in interface.find_children("CaseTileSummary_*", "Label", true, false):
		var summary := summary_node as Label
		if summary != null:
			_untrim_label(summary, 25)
			var tile := summary.get_parent()
			while tile != null and tile != interface and not tile is PanelContainer:
				tile = tile.get_parent()
			if tile is PanelContainer:
				(tile as PanelContainer).custom_minimum_size.y = maxf((tile as PanelContainer).custom_minimum_size.y, 126.0)

	var evidence_cards := interface.find_children("CaseEvidenceCard_*", "Button", true, false)
	if not evidence_cards.is_empty():
		var first_card := evidence_cards[0] as Button
		if first_card != null and first_card.get_parent() is GridContainer:
			var evidence_grid := first_card.get_parent() as GridContainer
			evidence_grid.columns = 1
			var ledger := evidence_grid.get_parent() as Control
			var section := ledger.get_parent() if ledger != null else null
			if section is HBoxContainer and section.name != EVIDENCE_STACK_NAME:
				_stack_evidence_section(section as HBoxContainer)
		for card_node: Node in evidence_cards:
			var card := card_node as Button
			if card != null:
				_untrim_button(card, 27)
				card.custom_minimum_size.y = maxf(card.custom_minimum_size.y, 144.0)

	var hypothesis_buttons := interface.find_children("CaseHypothesis_*", "Button", true, false)
	if not hypothesis_buttons.is_empty():
		var hypothesis_grid := (hypothesis_buttons[0] as Control).get_parent()
		if hypothesis_grid is GridContainer:
			(hypothesis_grid as GridContainer).columns = 1
		for hypothesis_node: Node in hypothesis_buttons:
			var hypothesis := hypothesis_node as Button
			if hypothesis != null:
				_untrim_button(hypothesis, 27)
				hypothesis.custom_minimum_size.y = maxf(hypothesis.custom_minimum_size.y, 128.0)

	for citation_node: Node in interface.find_children("CaseCitation_*", "Button", true, false):
		var citation := citation_node as Button
		if citation != null:
			_untrim_button(citation, 27)
			if citation.get_parent() is GridContainer:
				(citation.get_parent() as GridContainer).columns = 1

	for label_name in ["CaseEvidenceDisplayTitle", "CaseLockedActionTarget", "CaseReportPrompt", "CaseCitationLocator"]:
		var label := interface.find_child(label_name, true, false) as Label
		if label != null:
			_untrim_label(label, 25 if label_name != "CaseEvidenceDisplayTitle" else 29)

	var resolve_button := interface.find_child("ResolveCaseReport", true, false) as Button
	if resolve_button != null:
		_untrim_button(resolve_button, 29)
		resolve_button.custom_minimum_size.y = maxf(resolve_button.custom_minimum_size.y, 142.0)


func _stack_evidence_section(section: HBoxContainer) -> void:
	var parent := section.get_parent()
	if parent == null:
		return
	var insertion_index := section.get_index()
	var children := section.get_children()
	var stack := VBoxContainer.new()
	stack.name = EVIDENCE_STACK_NAME
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 16)
	parent.add_child(stack)
	parent.move_child(stack, insertion_index)
	for child: Node in children:
		section.remove_child(child)
		stack.add_child(child)
		if child is Control:
			(child as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			(child as Control).custom_minimum_size.x = 0.0
			if child is PanelContainer:
				(child as PanelContainer).custom_minimum_size.y = maxf((child as PanelContainer).custom_minimum_size.y, 330.0)
	parent.remove_child(section)
	section.queue_free()


func _bind_full_text_controls() -> void:
	for tile_node: Node in interface.find_children("CaseTile_*", "PanelContainer", true, false):
		_bind_case_tile(tile_node as PanelContainer)
	for evidence_node: Node in interface.find_children("CaseEvidenceCard_*", "Button", true, false):
		_bind_evidence_button(evidence_node as Button)
	for hypothesis_node: Node in interface.find_children("CaseHypothesis_*", "Button", true, false):
		_bind_hypothesis_button(hypothesis_node as Button)
	for label_name in ["CaseReportPrompt", "CaseCitationLocator"]:
		var label := interface.find_child(label_name, true, false) as Label
		if label != null:
			_bind_tooltip_label(label)


func _bind_case_tile(tile: PanelContainer) -> void:
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
		heading = String((labels[0] as Label).text)
	var full_text := tile.tooltip_text
	if full_text.is_empty() and labels.size() > 1 and labels[1] is Label:
		full_text = String((labels[1] as Label).text)
	tile.gui_input.connect(func(event: InputEvent) -> void:
		if _is_primary_press(event):
			_show_text_modal(heading, full_text, null)
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
			_show_text_modal(_copy("FULL TEXT", "전체 내용"), snapshot, null)
			label.accept_event()
	)


func _bind_evidence_button(button: Button) -> void:
	if button == null or button.has_meta(META_BOUND):
		return
	button.set_meta(META_BOUND, true)
	var fallback_title := button.text.replace("\n", " · ")
	var suffix := String(button.name).trim_prefix("CaseEvidenceCard_")
	button.pressed.connect(func() -> void:
		_show_selected_evidence_modal_deferred.call_deferred(suffix, fallback_title)
	)


func _bind_hypothesis_button(button: Button) -> void:
	if button == null or button.has_meta(META_BOUND):
		return
	button.set_meta(META_BOUND, true)
	var claim := button.tooltip_text
	var caption := button.text.replace("\n", " ")
	button.pressed.connect(func() -> void:
		_show_text_modal.call_deferred(_copy("HYPOTHESIS DETAIL", "가설 상세"), "%s\n\n%s" % [caption, claim], null)
	)


func _show_selected_evidence_modal_deferred(evidence_suffix: String, fallback_title: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if interface == null or not is_instance_valid(interface):
		return
	var title_label := interface.find_child("CaseEvidenceDisplayTitle", true, false) as Label
	var detail_panel := _ancestor_panel(title_label)
	var lines: Array[String] = []
	if detail_panel != null:
		_collect_readable_text(detail_panel, lines)
	var heading := String(title_label.text) if title_label != null else fallback_title
	var body_text := "\n\n".join(lines)
	if body_text.is_empty():
		body_text = fallback_title
	var action_button: Button = null
	var investigate := interface.find_child("CaseEvidence_%s" % evidence_suffix, true, false) as Button
	var cite := interface.find_child("CaseCitation_%s" % evidence_suffix, true, false) as Button
	if investigate != null and investigate.is_visible_in_tree() and not investigate.disabled:
		action_button = investigate
	elif cite != null and cite.is_visible_in_tree() and not cite.disabled:
		action_button = cite
	_show_text_modal(heading, body_text, action_button)


func _ancestor_panel(node: Node) -> PanelContainer:
	var current := node
	while current != null and current != interface:
		if current is PanelContainer:
			return current as PanelContainer
		current = current.get_parent()
	return null


func _collect_readable_text(root_control: Control, output: Array[String]) -> void:
	for label_node: Node in root_control.find_children("*", "Label", true, false):
		var label := label_node as Label
		if label == null:
			continue
		var value := label.text.strip_edges()
		if not value.is_empty() and not output.has(value):
			output.append(value)
	for button_node: Node in root_control.find_children("*", "Button", true, false):
		var button := button_node as Button
		if button == null or not button.is_visible_in_tree():
			continue
		var action := button.text.strip_edges()
		if not action.is_empty() and not output.has(action):
			output.append("[%s]" % action)


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
	panel.custom_minimum_size = Vector2(0, 168)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#132722f2"), Color("#9fd6bd"), 3))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = _copy("WHAT TO DO NOW", "지금 할 일")
	heading.add_theme_color_override("font_color", Color("#e3c681"))
	_untrim_label(heading, 31)
	column.add_child(heading)
	var instruction := Label.new()
	instruction.name = "MobileNextActionText"
	instruction.text = _next_action_text()
	instruction.add_theme_color_override("font_color", Color("#f2e8cf"))
	_untrim_label(instruction, 25)
	column.add_child(instruction)
	var hint := Label.new()
	hint.text = _copy("Tap a clue, question, goal, or hypothesis card to open its full text.", "단서·상황·핵심 질문·목표·가설 카드를 누르면 잘리지 않은 전체 설명이 열립니다.")
	hint.add_theme_color_override("font_color", Color("#9fd6bd"))
	_untrim_label(hint, 22)
	column.add_child(hint)
	var tutorial_state: Dictionary = GameState.tutorial_public_state()
	if bool(tutorial_state.get("visible", false)):
		var help_button := Button.new()
		help_button.text = _copy("SHOW THIS GUIDE AGAIN", "현재 튜토리얼 크게 보기")
		help_button.name = "MobileTutorialHelpButton"
		help_button.custom_minimum_size = Vector2(0, 94)
		_untrim_button(help_button, 27)
		help_button.pressed.connect(func() -> void: _show_tutorial_coach(tutorial_state, true))
		column.add_child(help_button)
	rows.add_child(panel)
	rows.move_child(panel, 0)


func _next_action_text() -> String:
	var tutorial_state: Dictionary = GameState.tutorial_public_state()
	if bool(tutorial_state.get("visible", false)):
		var step := int(tutorial_state.get("step", 0))
		return "%s\n%s" % [String(tutorial_state.get("title", "")), _tutorial_explanation(step)]
	var investigate_buttons := interface.find_children("CaseEvidence_*", "Button", true, false)
	for button_node: Node in investigate_buttons:
		var button := button_node as Button
		if button != null and button.is_visible_in_tree() and not button.disabled:
			return _copy("Open a clue card, read its source/trust/risk, then use BEGIN INVESTIGATION.", "단서 카드를 눌러 출처·신뢰·위험을 읽은 뒤 [조사 실행]을 누르세요.")
	var citation_buttons := interface.find_children("CaseCitation_*", "Button", true, false)
	for button_node: Node in citation_buttons:
		var button := button_node as Button
		if button != null and button.is_visible_in_tree() and not button.disabled:
			return _copy("Add the useful found clues to the report, then choose a hypothesis.", "확인한 단서 중 근거로 쓸 것을 [보고서에 인용]한 뒤 가설을 선택하세요.")
	return _copy("Read the case question, compare clues, choose a hypothesis, and submit the report when ready.", "핵심 질문을 다시 읽고 단서를 비교한 뒤 가설을 선택하고 준비되면 보고서를 제출하세요.")


func _maybe_show_tutorial_coach() -> void:
	var state: Dictionary = GameState.tutorial_public_state()
	if not bool(state.get("visible", false)):
		return
	if not _tutorial_target_visible(state):
		return
	var signature := "%d|%s|%s" % [int(state.get("step", 0)), _scene_screen(), String(GameState.current_stage)]
	if signature == last_tutorial_signature:
		return
	last_tutorial_signature = signature
	_show_tutorial_coach(state, false)


func _tutorial_target_visible(state: Dictionary) -> bool:
	if int(state.get("step", 0)) == 1 and _scene_screen() == "campaign":
		return true
	for pattern_value: Variant in state.get("targets", []):
		var pattern := String(pattern_value)
		for candidate: Node in interface.find_children(pattern, "Control", true, false):
			if candidate is Control and (candidate as Control).is_visible_in_tree():
				if candidate is BaseButton and (candidate as BaseButton).disabled:
					continue
				return true
	return false


func _show_tutorial_coach(state: Dictionary, force: bool = false) -> void:
	if not force and interface.find_child(MODAL_NAME, true, false) != null:
		return
	var step := int(state.get("step", 0))
	var total := int(state.get("total", 0))
	var title := String(state.get("title", ""))
	var authored := String(state.get("text", ""))
	if step == 1 and _scene_screen() == "campaign":
		title = _copy("START THE FIRST CASE", "첫 사건 시작")
		authored = _copy("Press the first case START button. The next screen will teach clue reading and investigation.", "첫 사건의 [시작] 버튼을 누르세요. 다음 화면에서 단서 읽기와 조사 방법을 바로 이어서 설명합니다.")
	var body_text := "%s\n\n%s\n\n%s" % [
		_copy("DO THIS", "해야 할 일"),
		authored,
		_tutorial_explanation(step)
	]
	_show_text_modal("%s %d/%d — %s" % [_copy("TUTORIAL", "튜토리얼"), step, total, title], body_text, null, _copy("GOT IT — SHOW THE TARGET", "확인하고 따라하기"))


func _tutorial_explanation(step: int) -> String:
	if _scene_screen() == "campaign" and step == 1:
		return _copy("Only the first case route matters now. Ignore the other menus until the dossier opens.", "지금은 다른 메뉴를 볼 필요 없습니다. 첫 사건을 열면 사건 서류에서 실제 조사 순서를 계속 안내합니다.")
	match step:
		1:
			return _copy("Tap a READY clue card. The full detail popup explains source, trust and damage risk. If it makes sense, use the popup action or BEGIN INVESTIGATION to record it. LOCKED cards tell you what must be done first.", "[조사 가능] 단서 카드를 누르세요. 전체 설명창에서 출처·신뢰도·손상 위험을 먼저 읽습니다. 이해했으면 설명창의 행동 버튼 또는 [조사 실행]으로 단서를 기록하세요. [잠김] 카드는 먼저 해야 할 조건을 알려줍니다.")
		2:
			return _copy("A found clue is not automatically part of your report. Open the found clue, read what it says, then ADD TO REPORT. Supporting and refuting clues are both valid evidence.", "조사한 단서가 자동으로 보고서에 들어가지는 않습니다. 확인한 단서를 다시 열어 내용을 읽고 [보고서에 인용]을 누르세요. 가설을 지지하는 단서뿐 아니라 반박하는 단서도 근거로 쓸 수 있습니다.")
		3:
			return _copy("Read the central question again. Tap a hypothesis to see its full claim, choose the claim best supported by your cited clues, then submit the report. More independent sources make the conclusion stronger.", "핵심 질문을 다시 읽으세요. 가설을 누르면 전체 주장이 열립니다. 인용한 단서에 가장 잘 맞는 가설을 고른 뒤 보고서를 제출하세요. 서로 다른 독립 출처가 많을수록 결론이 탄탄해집니다.")
		4:
			return _copy("After the report, return to the relic and repair only what is needed. Equip one recommended repair tool, read the trade-off, then repair. Excess intervention can reduce historical value.", "보고서를 마치면 유물 검사로 돌아가 필요한 부분만 수리합니다. 권장 수리 도구 중 하나를 장착하고 수리 판단 설명을 읽은 뒤 수리하세요. 과한 개입은 역사적 가치를 낮출 수 있습니다.")
		5:
			return _copy("Authenticate the relic, then choose price and disclosure. Price is the reserve strategy; disclosure is how confidently you describe the lot. Match both to the evidence you actually found, then confirm listing.", "유물을 인증한 뒤 출품 가격 전략과 공개 수준을 고릅니다. 가격은 예약가 전략이고, 공개 수준은 유물을 얼마나 확신 있게 설명할지입니다. 실제로 확보한 근거 수준에 맞춰 둘을 고르고 출품을 확정하세요.")
		6:
			return _copy("Watch the public bids and bidder reasons. Advance the auction cues until the final result, then use the hammer/record action. The result becomes the authoritative sale record.", "공개 호가와 입찰자 이유를 읽으세요. 경매 장면을 마지막 결과까지 진행한 뒤 [망치/결과 기록]을 누릅니다. 이때 결과가 실제 판매 기록으로 확정됩니다.")
		_:
			return _copy("Follow the highlighted control. The guide advances only when the matching gameplay action really succeeds.", "강조된 버튼을 따라가세요. 튜토리얼은 해당 실제 행동이 성공했을 때만 다음 단계로 넘어갑니다.")


func _show_text_modal(title_text: String, body_text: String, action_target: Button = null, close_text: String = "") -> void:
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
	heading.add_theme_color_override("font_color", Color("#e3c681"))
	_untrim_label(heading, 34)
	column.add_child(heading)

	var scroll := ScrollContainer.new()
	scroll.name = "ModalScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := Label.new()
	body.name = "ModalBody"
	body.text = body_text
	body.custom_minimum_size = Vector2(panel_width - 70.0, 0)
	body.add_theme_color_override("font_color", Color("#f2e8cf"))
	_untrim_label(body, 27)
	scroll.add_child(body)

	if action_target != null and is_instance_valid(action_target) and action_target.is_visible_in_tree() and not action_target.disabled:
		var action := Button.new()
		action.name = "ModalPrimaryAction"
		action.text = action_target.text
		action.custom_minimum_size = Vector2(0, 132)
		_untrim_button(action, 30)
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
	close_button.custom_minimum_size = Vector2(0, 118)
	_untrim_button(close_button, 29)
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
