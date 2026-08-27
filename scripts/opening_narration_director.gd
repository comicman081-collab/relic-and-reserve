extends Node

# Web onboarding shown before the hands-on spotlight tutorial.
# This layer is presentation-only: it does not change campaign/RNG/save authority.
# It temporarily pauses TutorialSpotlightDirector, teaches the story premise and
# the nine main navigation tabs, then hands control back to the real-action guide.

const OVERLAY_NAME := "OpeningNarrationOverlay"
const SPOTLIGHT_OVERLAY_NAME := "TutorialSpotlightOverlay"

var interface: Control
var active := false
var page_index := 0
var session_completed := false
var force_enabled_for_test := false
var queued := false
var last_tutorial_visible := false
var completed_tutorial_cycle := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_discover.call_deferred()


func _process(_delta: float) -> void:
	if not _feature_enabled():
		return
	var state: Dictionary = GameState.tutorial_public_state()
	var visible := bool(state.get("visible", false))
	if session_completed and last_tutorial_visible and not visible:
		completed_tutorial_cycle = true
	last_tutorial_visible = visible
	if active:
		_pause_spotlight_director()
		_remove_competing_spotlight()
	if interface == null or not is_instance_valid(interface):
		return
	if not active and not session_completed and _should_start(state):
		_start_onboarding()


func _feature_enabled() -> bool:
	return force_enabled_for_test or OS.has_feature("web")


func _discover() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var candidate := scene.find_child("R3Interface", true, false)
	if candidate is Control:
		interface = candidate
		_queue_check()


func _on_node_added(node: Node) -> void:
	if node is Control and node.name == "R3Interface":
		interface = node
		_queue_check()
		return
	if active and interface != null and is_instance_valid(interface) and interface.is_ancestor_of(node):
		_remove_competing_spotlight.call_deferred()


func _queue_check() -> void:
	if queued:
		return
	queued = true
	_check_deferred.call_deferred()


func _check_deferred() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	queued = false
	if interface == null or not is_instance_valid(interface):
		_discover()
		return
	if not _feature_enabled():
		return
	var state: Dictionary = GameState.tutorial_public_state()
	if not active and not session_completed and _should_start(state):
		_start_onboarding()


func _should_start(state: Dictionary) -> bool:
	if not bool(state.get("visible", false)):
		return false
	if int(state.get("step", 0)) != 1 or int(GameState.current_stage) != 1:
		return false
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var screen_value: Variant = scene.get("screen")
	var screen_name := "" if screen_value == null else str(screen_value)
	return screen_name in ["campaign", "workshop"]


func _start_onboarding() -> void:
	active = true
	page_index = 0
	_pause_spotlight_director()
	_remove_competing_spotlight()
	_hide_legacy_skip(true)
	_show_page()


func _pause_spotlight_director() -> void:
	var director := get_tree().root.get_node_or_null("TutorialSpotlightDirector")
	if director != null:
		director.process_mode = Node.PROCESS_MODE_DISABLED


func _resume_spotlight_director(skip_intro: bool) -> void:
	var director := get_tree().root.get_node_or_null("TutorialSpotlightDirector")
	if director == null:
		return
	if skip_intro:
		director.set("tutorial_was_visible", true)
		director.set("intro_done", true)
		director.set("intro_page", 0)
		director.set("last_target_signature", "")
		director.set("pending_signature", "")
	director.process_mode = Node.PROCESS_MODE_ALWAYS
	if director.has_method("_queue_apply"):
		director.call_deferred("_queue_apply")


func _remove_competing_spotlight() -> void:
	if interface == null or not is_instance_valid(interface):
		return
	var old := interface.find_child(SPOTLIGHT_OVERLAY_NAME, true, false)
	if old != null:
		old.queue_free()


func _hide_legacy_skip(hidden: bool) -> void:
	if interface == null or not is_instance_valid(interface):
		return
	var skip := interface.find_child("TutorialSkipButton", true, false) as BaseButton
	if skip != null:
		skip.visible = not hidden


func _opening_pages() -> Array:
	return [
		{
			"phase": "OPENING",
			"phase_index": 1,
			"title": _copy("THE KEY TO A CLOSED WORKSHOP", "문 닫힌 공방의 열쇠"),
			"body": _copy(
				"For a while, the small conservation workshop RELIC & RESERVE stood closed at the edge of town. Veteran restorer Mara Venn decided to reopen it, but the shelves were already full of unidentified objects, unfinished records and old promises. She handed you the workshop key and asked you to take charge of the work that could no longer be solved by polishing an object and attaching a price tag.",
				"도시 변두리의 작은 보존 공방 RELIC & RESERVE는 한동안 문이 닫혀 있었습니다. 베테랑 복원가 마라 벤은 공방을 다시 열기로 했지만, 선반에는 정체가 불분명한 유물과 미완성 기록, 오래된 약속들이 이미 가득했습니다. 마라는 단순히 물건을 닦고 가격표를 붙이는 것만으로는 해결할 수 없는 일을 맡아 달라며 당신에게 공방의 열쇠를 건넸습니다."
			)
		},
		{
			"phase": "OPENING",
			"phase_index": 2,
			"title": _copy("NOT EVERY OLD OBJECT TELLS THE TRUTH", "오래된 물건이 항상 진실을 말하는 것은 아닙니다"),
			"body": _copy(
				"Some pieces are genuine. Some were repaired decades ago. Others were rebuilt recently, mislabelled, or deliberately forged. Documents can disagree with the object in front of you, and an aggressive repair can erase the very trace that would have proven what happened. If the workshop sells a claim it cannot support, money may come in today, but reputation, museum trust and historical integrity suffer tomorrow.",
				"공방에 들어오는 물건 중에는 진품도 있고, 수십 년 전 수리를 받은 것도 있으며, 최근에 다시 조립됐거나 잘못 분류됐거나 의도적으로 위조된 것도 있습니다. 서류와 눈앞의 실물이 서로 모순되기도 하고, 성급한 수리는 무슨 일이 있었는지 증명해 줄 흔적 자체를 지워 버릴 수도 있습니다. 근거 없는 주장을 붙여 팔면 오늘은 돈을 벌 수 있어도 내일의 평판과 박물관 신뢰, 역사적 가치는 무너집니다."
			)
		},
		{
			"phase": "OPENING",
			"phase_index": 3,
			"title": _copy("WHY YOU ARE HERE", "당신이 이 공방에서 해야 할 일"),
			"body": _copy(
				"Your job is to make this workshop trustworthy again. Investigate clues, compare independent sources, decide which hypothesis the evidence really supports, preserve or repair only what is necessary, authenticate what can be proven, and disclose the truth before a sale. The first file waiting on the bench is The Closed Workshop — an old desk clock whose repair history does not quite add up.",
				"당신의 목표는 이 공방을 다시 신뢰받는 곳으로 만드는 것입니다. 단서를 조사하고 서로 독립된 출처를 비교하고, 실제 근거가 지지하는 가설을 고르고, 필요한 만큼만 보존·수리하고, 입증할 수 있는 범위에서 진위를 판단한 뒤 판매 전에 사실을 제대로 공개해야 합니다. 작업대에 놓인 첫 사건은 ‘닫힌 공방’. 수리 이력이 어딘가 맞지 않는 오래된 탁상시계에서 시작합니다."
			)
		}
	]


func _tab_guide_pages() -> Array:
	return [
		{
			"phase": "TABS",
			"phase_index": 1,
			"title": _copy("YOUR DAILY WORKSPACE", "매일 가장 많이 쓰게 될 세 곳"),
			"tabs": [
				[_copy("WORKSHOP", "공방"), _copy("Your home base. Check the current workpiece, money, reputation and the state of the workshop before deciding what to do next.", "하루의 중심 허브입니다. 현재 작업 중인 유물, 보유금, 평판과 공방 상태를 확인하고 다음 행동을 정합니다.")],
				[_copy("MARKET", "시장"), _copy("Browse new lots and opportunities. Compare what is available before spending the workshop's limited cash.", "새 유물과 거래 기회를 확인하는 곳입니다. 한정된 공방 자금을 쓰기 전에 어떤 물건을 들일지 비교합니다.")],
				[_copy("INVENTORY", "보관함"), _copy("Everything the workshop owns lives here. Reopen an item to inspect, restore, authenticate or prepare it for sale.", "공방이 보유한 유물을 모아 보는 곳입니다. 유물을 다시 열어 조사·수리·인증하거나 판매 준비를 이어갑니다.")]
			]
		},
		{
			"phase": "TABS",
			"phase_index": 2,
			"title": _copy("GROWTH, JOBS AND STORY", "성장·의뢰·스토리 진행"),
			"tabs": [
				[_copy("UPGRADES", "업그레이드"), _copy("Improve the workshop and its capabilities. Better facilities expand what you can safely handle, but upgrades cost resources.", "공방과 작업 능력을 강화합니다. 더 좋은 설비는 안전하게 다룰 수 있는 작업을 늘리지만 자원이 필요합니다.")],
				[_copy("COMMISSIONS", "의뢰"), _copy("Optional work from clients. Commissions are another way to earn money and reputation while practicing the same careful judgement.", "고객에게서 들어오는 선택형 작업입니다. 같은 판단 원칙을 연습하면서 돈과 평판을 얻는 보조 진행입니다.")],
				[_copy("CAMPAIGN", "캠페인"), _copy("The main story and stage route. Open the current case here, solve every required file, and unlock the next stage in order.", "메인 스토리와 스테이지 진행 화면입니다. 현재 사건을 열고 필요한 사건을 해결해 순서대로 다음 스테이지를 해금합니다.")]
			]
		},
		{
			"phase": "TABS",
			"phase_index": 3,
			"title": _copy("ENDING A DAY AND SYSTEM CONTROLS", "하루 진행과 기본 시스템"),
			"tabs": [
				[_copy("END DAY", "하루 마치기"), _copy("Advance the calendar when today's work is done. A new day can change market opportunities and daily conditions, so do not press it casually.", "오늘 할 일을 끝냈을 때 날짜를 진행합니다. 새 날에는 시장 기회와 하루 조건이 달라질 수 있으니 의미 없이 누르지 않는 편이 좋습니다.")],
				[_copy("SAVE", "저장"), _copy("Write the current run to storage. Use it whenever you want an explicit checkpoint before leaving the game.", "현재 진행 상황을 저장합니다. 게임을 나가기 전 확실한 체크포인트를 남기고 싶을 때 사용합니다.")],
				[_copy("EN / KOREAN", "EN / 한국어"), _copy("Switch the interface language. It changes presentation only and does not alter gameplay or saved progress.", "화면 언어를 전환합니다. 표시 언어만 바뀌며 게임 진행이나 저장 내용에는 영향을 주지 않습니다.")]
			]
		}
	]


func onboarding_pages() -> Array:
	return _opening_pages() + _tab_guide_pages()


func _show_page() -> void:
	if interface == null or not is_instance_valid(interface):
		return
	_remove_overlay()
	_pause_spotlight_director()
	_remove_competing_spotlight()
	var pages := onboarding_pages()
	page_index = clampi(page_index, 0, pages.size() - 1)
	var page: Dictionary = pages[page_index]

	var overlay := Control.new()
	overlay.name = OVERLAY_NAME
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 2300
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	interface.add_child(overlay)

	var dim := ColorRect.new()
	dim.name = "OpeningNarrationDim"
	dim.color = Color(0.0, 0.0, 0.0, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_advance_input)
	overlay.add_child(dim)

	var panel_width := minf(1020.0, maxf(620.0, interface.size.x - 96.0))
	var panel_height := minf(1380.0, maxf(760.0, interface.size.y * 0.60))
	var panel := PanelContainer.new()
	panel.name = "OpeningNarrationPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2((interface.size.x - panel_width) * 0.5, maxf(110.0, (interface.size.y - panel_height) * 0.40))
	panel.size = Vector2(panel_width, panel_height)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#10171cfb"), Color("#e3c681"), 4))
	overlay.add_child(panel)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 20)
	panel.add_child(column)

	var phase_name := _copy("OPENING", "오프닝") if str(page.get("phase", "")) == "OPENING" else _copy("WORKSHOP GUIDE", "공방 메뉴 안내")
	var phase_total := 3
	var progress := _label("%s  %d / %d" % [phase_name, int(page.get("phase_index", 1)), phase_total], 19, Color("#9fd6bd"))
	progress.name = "OpeningNarrationProgress"
	column.add_child(progress)
	var title := _label(str(page.get("title", "")), 32, Color("#e3c681"))
	title.name = "OpeningNarrationTitle"
	column.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "OpeningNarrationContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	scroll.add_child(content)

	if str(page.get("phase", "")) == "OPENING":
		var body := _label(str(page.get("body", "")), 24, Color("#f2e8cf"))
		body.name = "OpeningNarrationBody"
		body.custom_minimum_size.x = panel_width - 80.0
		content.add_child(body)
	else:
		var tabs_value: Variant = page.get("tabs", [])
		var tabs: Array = tabs_value if tabs_value is Array else []
		for tab_index in range(tabs.size()):
			var entry: Array = tabs[tab_index]
			var card := PanelContainer.new()
			card.name = "OpeningTabCard_%d" % (tab_index + 1)
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.custom_minimum_size.y = 210.0
			card.add_theme_stylebox_override("panel", _panel_style(Color("#172126f4"), Color("#657579"), 2))
			content.add_child(card)
			var card_column := VBoxContainer.new()
			card_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_column.add_theme_constant_override("separation", 8)
			card.add_child(card_column)
			var tab_title := _label(str(entry[0]), 27, Color("#e3c681"))
			tab_title.name = "OpeningTabTitle_%d" % (tab_index + 1)
			card_column.add_child(tab_title)
			var tab_body := _label(str(entry[1]), 21, Color("#f2e8cf"))
			tab_body.name = "OpeningTabBody_%d" % (tab_index + 1)
			card_column.add_child(tab_body)

	var hint := _label(_copy("TAP OR CLICK ANYWHERE TO CONTINUE", "화면 아무 곳이나 터치하거나 클릭하면 계속됩니다"), 19, Color("#9fd6bd"))
	hint.name = "OpeningNarrationTapHint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)

	var overall := _label("%d / %d" % [page_index + 1, pages.size()], 16, Color("#8fa5aa"))
	overall.name = "OpeningNarrationOverallProgress"
	overall.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(overall)

	var skip := Button.new()
	skip.name = "OpeningExpertSkip"
	skip.text = _copy("I ALREADY KNOW THE GAME AND MENUS — SKIP ALL TUTORIAL", "게임과 메뉴 구성을 이미 아는 경우에만 · 전체 튜토리얼 건너뛰기")
	skip.custom_minimum_size = Vector2(0, 72)
	skip.add_theme_font_size_override("font_size", 16)
	skip.modulate = Color(0.78, 0.82, 0.82, 0.85)
	skip.pressed.connect(_skip_all_tutorial)
	column.add_child(skip)


func _on_advance_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_advance_page()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_page()


func _advance_page() -> void:
	if not active:
		return
	var pages := onboarding_pages()
	if page_index < pages.size() - 1:
		page_index += 1
		_show_page()
		return
	_finish_onboarding()


func _finish_onboarding() -> void:
	active = false
	session_completed = true
	page_index = 0
	_remove_overlay()
	_hide_legacy_skip(true)
	_resume_spotlight_director(true)


func _skip_all_tutorial() -> void:
	_remove_overlay()
	active = false
	session_completed = true
	page_index = 0
	var result: Dictionary = GameState.skip_tutorial_guidance()
	_hide_legacy_skip(false)
	_resume_spotlight_director(false)
	if not bool(result.get("ok", false)):
		session_completed = false
		_queue_check()


func _remove_overlay() -> void:
	if interface == null or not is_instance_valid(interface):
		return
	var overlay := interface.find_child(OVERLAY_NAME, true, false)
	if overlay != null:
		overlay.queue_free()


func _label(text_value: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	label.max_lines_visible = -1
	label.clip_text = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	return label


func _copy(en_text: String, ko_text: String) -> String:
	return ko_text if str(GameState.language) == "ko" else en_text


func _panel_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	return style
