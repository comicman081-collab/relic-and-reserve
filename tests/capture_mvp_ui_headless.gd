extends SceneTree

const OUTPUT_DIR := "res://qa/mvp_ui_headless"
const ICON_ROOT := "res://assets/ui/case_icons/"

var captures: Array = []
var data_uri_cache := {}


func _init() -> void:
	call_deferred("run")


func esc(value: Variant) -> String:
	return String(value).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")


func localized(value: Variant) -> String:
	if value is Dictionary:
		return String(value.get("ko", value.get("en", "")))
	return String(value)


func data_uri(path: String) -> String:
	if data_uri_cache.has(path):
		return data_uri_cache[path]
	var uri := "data:image/svg+xml;base64," + Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path))
	data_uri_cache[path] = uri
	return uri


func image_node(path: String, x: float, y: float, width: float, height: float) -> String:
	return '<image href="%s" x="%.1f" y="%.1f" width="%.1f" height="%.1f" preserveAspectRatio="xMidYMid meet"/>' % [data_uri(path), x, y, width, height]


func regex_value(source: String, pattern: String, fallback: String = "") -> String:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return fallback
	var matched := regex.search(source)
	return matched.get_string(1) if matched != null else fallback


func number_list(value: String) -> Array:
	var numbers: Array = []
	for token: String in value.replace(",", " ").split(" ", false):
		if token.is_valid_float():
			numbers.append(float(token))
	return numbers


func ellipse_node(center: Vector2, radius: Vector2, fill: String, stroke: String = "none", stroke_width: float = 0.0) -> String:
	return '<ellipse cx="%.2f" cy="%.2f" rx="%.2f" ry="%.2f" fill="%s" stroke="%s" stroke-width="%.2f"/>' % [center.x, center.y, radius.x, radius.y, fill, stroke, stroke_width]


func expression_face_nodes(profile_data: Dictionary, box: Rect2, expression: String, geometry_contract: Dictionary) -> Array:
	var nodes: Array = []
	var portrait_path: String = profile_data.get("portraitAssetId", "")
	var source := FileAccess.get_file_as_string(portrait_path)
	var anchor_values := number_list(regex_value(source, "data-expression-anchor=\"([^\"]+)\"", "128,136"))
	var anchor := Vector2(float(anchor_values[0]), float(anchor_values[1])) if anchor_values.size() == 2 else Vector2(128, 136)
	var skin := regex_value(source, "data-part=\"face-shape\"[^>]*fill=\"(#[0-9A-Fa-f]{6})\"", "#efb287")
	var ink := regex_value(source, "data-part=\"brows\"[^>]*stroke=\"(#[0-9A-Fa-f]{6})\"", "#69404a")
	var sclera := regex_value(source, "data-part=\"sclera\"[^>]*fill=\"(#[0-9A-Fa-f]{6})\"", "#fff9f1")
	var iris := regex_value(source, "data-part=\"iris\"[^>]*fill=\"(#[0-9A-Fa-f]{6})\"", "#8a5c68")
	var pupil := regex_value(source, "data-part=\"pupil\"[^>]*fill=\"(#[0-9A-Fa-f]{6})\"", "#352a2d")
	var eyes: Array = []
	var eye_regex := RegEx.new()
	if eye_regex.compile("data-part=\"sclera\"[^>]*cx=\"([^\"]+)\"[^>]*cy=\"([^\"]+)\"") == OK:
		for matched: RegExMatch in eye_regex.search_all(source).slice(0, 2):
			eyes.append(Vector2(float(matched.get_string(1)), float(matched.get_string(2))))
	if eyes.size() < 2:
		eyes = [anchor + Vector2(-22, -13), anchor + Vector2(22, -13)]
	var scale_value := minf(box.size.x / 256.0, box.size.y / 320.0)
	var origin := box.position + (box.size - Vector2(256, 320) * scale_value) * 0.5
	var point := func(svg_point: Vector2) -> Vector2: return origin + svg_point * scale_value
	var radius := func(svg_radius: Vector2) -> Vector2: return svg_radius * scale_value
	var geometry: Dictionary = geometry_contract.get(expression, {})
	var brow_shift := float(geometry.get("browShiftSvg", 0.0))
	var eye_shift := float(geometry.get("eyeHeightShiftSvg", 0.0))
	var mouth_shift := float(geometry.get("mouthCornerShiftSvg", 0.0))
	for eye: Vector2 in eyes:
		nodes.append(ellipse_node(point.call(eye + Vector2(0, -18)), radius.call(Vector2(20, 10)), skin))
		nodes.append(ellipse_node(point.call(eye), radius.call(Vector2(18.5, 12.5)), skin))
	nodes.append(ellipse_node(point.call(anchor + Vector2(0, 33)), radius.call(Vector2(20, 16)), skin))
	var brow_y := float(eyes[0].y) - 18.0 + brow_shift
	var brow_tilt := clampf(mouth_shift * 0.4, -2.5, 2.5)
	for eye_index in range(2):
		var eye: Vector2 = eyes[eye_index]
		var tilt_sign := 1.0 if eye_index == 0 else -1.0
		var p0: Vector2 = point.call(Vector2(eye.x - 15, brow_y - brow_tilt * tilt_sign))
		var pc: Vector2 = point.call(Vector2(eye.x, brow_y - 2))
		var p1: Vector2 = point.call(Vector2(eye.x + 15, brow_y + brow_tilt * tilt_sign))
		nodes.append('<path d="M %.2f %.2f Q %.2f %.2f %.2f %.2f" fill="none" stroke="%s" stroke-width="%.2f" stroke-linecap="round"/>' % [p0.x, p0.y, pc.x, pc.y, p1.x, p1.y, ink, 3.5 * scale_value])
	var eye_radius_y := maxf(5.5, 10.0 + eye_shift)
	for eye: Vector2 in eyes:
		nodes.append(ellipse_node(point.call(eye), radius.call(Vector2(15, eye_radius_y)), sclera, ink, 1.2 * scale_value))
		nodes.append(ellipse_node(point.call(eye + Vector2(0, 1)), radius.call(Vector2(8, minf(8.0, eye_radius_y - 1.0))), iris))
		nodes.append(ellipse_node(point.call(eye + Vector2(0, 1)), radius.call(Vector2(4.2, 4.2)), pupil))
		nodes.append(ellipse_node(point.call(eye + Vector2(-3, -3)), radius.call(Vector2(2.4, 2.4)), "#FFFFFF"))
	var mouth_y := anchor.y + 33.0
	var center_curve := 7.0 if expression == "POSITIVE" else (-7.0 if expression == "NEGATIVE" else 0.0)
	var mouth_left: Vector2 = point.call(Vector2(anchor.x - 14, mouth_y + mouth_shift))
	var mouth_center: Vector2 = point.call(Vector2(anchor.x, mouth_y + center_curve))
	var mouth_right: Vector2 = point.call(Vector2(anchor.x + 14, mouth_y + mouth_shift))
	nodes.append('<path d="M %.2f %.2f Q %.2f %.2f %.2f %.2f" fill="none" stroke="%s" stroke-width="%.2f" stroke-linecap="round"/>' % [mouth_left.x, mouth_left.y, mouth_center.x, mouth_center.y, mouth_right.x, mouth_right.y, ink, 3.5 * scale_value])
	return nodes


func icon_node(name: String, x: float, y: float, size: float = 48.0) -> String:
	return image_node(ICON_ROOT + name + ".svg", x, y, size, size)


func rect_node(x: float, y: float, width: float, height: float, fill := "#151b1f", stroke := "#665f51", radius: float = 10.0, stroke_width: float = 2.0) -> String:
	return '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="%s" stroke="%s" stroke-width="%.1f"/>' % [x, y, width, height, radius, fill, stroke, stroke_width]


func text_node(value: Variant, x: float, y: float, size: int = 16, color := "#f2e8cf", weight := "normal", anchor := "start") -> String:
	return '<text x="%.1f" y="%.1f" fill="%s" font-family="Arial, sans-serif" font-size="%d" font-weight="%s" text-anchor="%s">%s</text>' % [x, y, color, size, weight, anchor, esc(value)]


func base_screen(title: String, stats := "STAGE 1   DAY 1   ¤1200   REP 12") -> Array:
	return [
		'<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="720" viewBox="0 0 1280 720">',
		rect_node(0, 0, 1280, 720, "#0a0e11", "#0a0e11", 0, 0),
		rect_node(20, 14, 1240, 56, "#11171b", "#3e4949", 10, 1),
		text_node(title, 38, 50, 27, "#e3c681", "bold"),
		text_node(stats, 1238, 47, 13, "#b7c4c8", "normal", "end")
	]


func finish_screen(svg: Array) -> String:
	svg.append(rect_node(20, 650, 1240, 54, "#11171b", "#3e4949", 8, 1))
	var nav := ["공방", "시장", "보관함", "업그레이드", "캠페인", "하루 마치기", "저장", "EN / 한국어"]
	for index in range(nav.size()):
		var x := 28.0 + index * 154.0
		svg.append(rect_node(x, 657, 146, 40, "#171d21", "#5d625f", 7, 1))
		svg.append(text_node(nav[index], x + 73, 682, 13, "#f2e8cf", "normal", "middle"))
	svg.append("</svg>")
	return "".join(svg)


func tile(svg: Array, x: float, y: float, width: float, icon: String, heading: String, value: String) -> void:
	svg.append(rect_node(x, y, width, 82, "#171d21", "#75664b"))
	svg.append(icon_node(icon, x + 10, y + 16, 48))
	svg.append(text_node(heading, x + 68, y + 28, 12, "#e3c681", "bold"))
	svg.append(text_node(value, x + 68, y + 53, 14, "#e8e0cf"))


func case_capture(gs: Node) -> String:
	gs.new_game(1)
	gs.begin_case("prologue_clock")
	var state: Dictionary = gs.get_case_public_state("prologue_clock")
	var svg := base_screen("사건 서류 — %s" % localized(state.title))
	tile(svg, 28, 84, 398, "briefing", "상황", "닫힌 공방에 남겨진 탁상시계를 조사한다")
	tile(svg, 440, 84, 398, "core_question", "핵심 질문", "당대 수리인가, 후대 재조립인가?")
	tile(svg, 852, 84, 398, "objective", "목표", "독립 출처 3개로 가설을 입증한다")
	svg.append(text_node("단서 카드", 30, 192, 17, "#e3c681", "bold"))
	var evidence_rows: Array = state.get("evidence", [])
	for index in range(evidence_rows.size()):
		var evidence: Dictionary = evidence_rows[index]
		var x := 28.0 + (index % 2) * 365.0
		var y := 205.0 + floori(float(index) / 2.0) * 78.0
		svg.append(rect_node(x, y, 352, 68, "#151b1f", "#9fd6bd" if index == 0 else "#5d625f"))
		var source_icon: String = {"ARTIFACT": "artifact", "DOCUMENT": "document", "NPC": "npc", "REFERENCE": "reference"}.get(evidence.get("sourceKind", ""), "clue_generic")
		if not bool(evidence.get("unlocked", false)):
			source_icon = "locked"
		svg.append(icon_node(source_icon, x + 7, y + 10, 46))
		var title: String = localized(evidence.get("text", "단서"))
		svg.append(text_node(("조사 가능" if bool(evidence.get("unlocked", false)) else "잠김") + " · " + title.left(24), x + 61, y + 27, 13, "#f2e8cf", "bold"))
		var source_label: String = {"ARTIFACT": "실물", "DOCUMENT": "문서", "NPC": "인물", "REFERENCE": "참고자료"}.get(evidence.get("sourceKind", ""), "단서")
		svg.append(text_node("출처 %s · %s" % [source_label, "위험 확인" if bool(evidence.get("unlocked", false)) else "선행 단서 필요"], x + 61, y + 51, 11, "#9aa8aa"))
	svg.append(rect_node(770, 182, 480, 257, "#11171b", "#75664b"))
	svg.append(icon_node("artifact", 790, 202, 54))
	svg.append(text_node("선택한 단서", 858, 220, 12, "#8fa5aa"))
	svg.append(text_node("후면판 나사의 불일치", 858, 246, 18, "#e3c681", "bold"))
	svg.append(icon_node("risk", 792, 273, 36))
	svg.append(text_node("위험 높음 — 연마 전에 산화 경계를 기록하세요", 840, 298, 14, "#e59b7a", "bold"))
	svg.append(rect_node(794, 335, 432, 55, "#222b2f", "#e3c681"))
	svg.append(icon_node("clue_generic", 806, 345, 34))
	svg.append(text_node("조사 실행", 862, 370, 15, "#fff5d9", "bold"))
	svg.append(text_node("가설 선택", 30, 460, 17, "#e3c681", "bold"))
	var hypotheses := ["출고 상태 그대로", "당대 수리를 거친 진품", "후대 재조립품"]
	for index in range(3):
		var x := 28.0 + index * 407.0
		svg.append(rect_node(x, 474, 392, 55, "#151b1f", "#5d625f"))
		svg.append(icon_node("hypothesis", x + 8, 482, 38))
		svg.append(text_node(hypotheses[index], x + 58, 508, 14))
	svg.append(rect_node(28, 543, 1222, 91, "#171d21", "#75664b"))
	svg.append(icon_node("report", 42, 558, 48))
	svg.append(text_node("보고서 요약", 104, 572, 17, "#e3c681", "bold"))
	svg.append(text_node("인용 0 · 독립 출처 0", 104, 598, 13, "#9fd6bd"))
	svg.append(rect_node(955, 558, 275, 55, "#20282c", "#9fd6bd"))
	svg.append(text_node("증거 기반 보고서 제출", 1092, 591, 14, "#fff5d9", "bold", "middle"))
	return finish_screen(svg)


func portrait_block(svg: Array, profile: Dictionary, x: float, y: float, width: float, height: float, state: String, dialogue: String, fact: String, expression: String, geometry_contract: Dictionary) -> void:
	svg.append(rect_node(x, y, width, height + 100, "#11171b", profile.get("stageVariants", {}).get("EARLY", {}).get("accentColor", "#e3c681"), 12, 2))
	var portrait_box := Rect2(x + 8, y + 8, width - 16, height - 12)
	svg.append(image_node(profile.portraitAssetId, portrait_box.position.x, portrait_box.position.y, portrait_box.size.x, portrait_box.size.y))
	svg.append_array(expression_face_nodes(profile, portrait_box, expression, geometry_contract))
	svg.append(text_node(localized(profile.displayName), x + 14, y + height + 22, 17, "#e3c681", "bold"))
	svg.append(text_node(state, x + 14, y + height + 43, 12, "#9fd6bd", "bold"))
	svg.append(text_node(dialogue, x + 14, y + height + 65, 13))
	svg.append(text_node(fact, x + 14, y + height + 87, 12, "#f0bd71", "bold"))


func profile(catalog: Dictionary, character_id: String) -> Dictionary:
	for row: Dictionary in catalog.get("profiles", []):
		if row.get("characterId", "") == character_id:
			return row
	return {}


func market_capture(gs: Node, registry: Node, catalog: Dictionary) -> String:
	gs.reset_game()
	var svg := base_screen("시장 — 오늘의 유물")
	portrait_block(svg, profile(catalog, "shopkeeper"), 28, 90, 250, 300, "오늘의 제안", "찬찬히 살펴보고 결정하세요.", "오늘 5점 입고", "NEUTRAL", catalog.get("expressionGeometry", {}))
	svg.append(text_node("오늘의 목록", 310, 114, 20, "#e3c681", "bold"))
	for index in range(mini(5, gs.market_roster.size())):
		var lot: Dictionary = gs.market_roster[index]
		var spec: Dictionary = registry.get_spec(lot.specId)
		var y := 132.0 + index * 88.0
		svg.append(rect_node(306, y, 940, 74, "#151b1f", "#5d625f"))
		svg.append(icon_node("artifact", 320, y + 10, 52))
		svg.append(text_node(String(spec.displayName).left(45), 388, y + 27, 16, "#f2e8cf", "bold"))
		svg.append(text_node("유물 분류 · %s" % spec.era, 388, y + 52, 12, "#8fa5aa"))
		svg.append(text_node("¤%d" % int(lot.price), 1030, y + 43, 17, "#f0bd71", "bold", "end"))
		svg.append(rect_node(1060, y + 16, 80, 42, "#222b2f", "#e3c681"))
		svg.append(text_node("제안", 1100, y + 43, 13, "#fff5d9", "bold", "middle"))
		svg.append(rect_node(1150, y + 16, 80, 42, "#22342e", "#9fd6bd"))
		svg.append(text_node("구매", 1190, y + 43, 13, "#fff5d9", "bold", "middle"))
	return finish_screen(svg)


func auction_capture(catalog: Dictionary) -> String:
	var svg := base_screen("경매 — 실시간 입찰", "STAGE 4   DAY 8   ¤1840   REP 28")
	portrait_block(svg, profile(catalog, "auctioneer"), 24, 88, 220, 268, "낙찰", "낙찰되었습니다.", "낙찰 · 예약가 ¤420 · 최종가 ¤510", "POSITIVE", catalog.get("expressionGeometry", {}))
	portrait_block(svg, profile(catalog, "bidder_03"), 996, 88, 260, 268, "낙찰자", "좋은 유물을 얻었군요.", "낙찰가 ¤510", "POSITIVE", catalog.get("expressionGeometry", {}))
	svg.append(text_node("판단 근거", 1008, 475, 12, "#8fa5aa", "bold"))
	svg.append(rect_node(1004, 486, 112, 38, "#19241f", "#9fd6bd", 8, 1))
	svg.append(text_node("출처 확인", 1060, 510, 12, "#bfe4d2", "bold", "middle"))
	svg.append(rect_node(1122, 486, 122, 38, "#19241f", "#9fd6bd", 8, 1))
	svg.append(text_node("상태 양호", 1183, 510, 12, "#bfe4d2", "bold", "middle"))
	svg.append(rect_node(260, 88, 720, 520, "#151b1f", "#75664b"))
	svg.append(text_node("Arclight Mantel Clock", 282, 125, 22, "#e3c681", "bold"))
	tile(svg, 282, 145, 210, "objective", "시작가", "¤280")
	tile(svg, 506, 145, 210, "risk", "예약가", "¤420")
	tile(svg, 730, 145, 224, "report", "최종가", "¤510")
	svg.append(text_node("최근 호가", 282, 258, 16, "#8fa5aa", "bold"))
	var bids := [["개인 수집가", 380], ["전문 딜러", 425], ["박물관 구매 담당자", 470], ["박물관 구매 담당자", 510]]
	for index in range(bids.size()):
		var y := 280.0 + index * 48.0
		svg.append(rect_node(282, y, 672, 38, "#11171b", "#3e4949", 6, 1))
		svg.append(text_node(bids[index][0], 300, y + 25, 14))
		svg.append(text_node("¤%d" % bids[index][1], 930, y + 25, 14, "#f0bd71", "bold", "end"))
	svg.append(text_node("낙찰 · 수수료 ¤61 · 정산액 ¤449", 282, 514, 18, "#9fd6bd", "bold"))
	svg.append(rect_node(282, 535, 672, 54, "#22342e", "#9fd6bd"))
	svg.append(text_node("낙찰 기록", 618, 569, 15, "#fff5d9", "bold", "middle"))
	return finish_screen(svg)


func auction_no_sale_capture(catalog: Dictionary) -> String:
	var svg := base_screen("경매 — 유찰 결과", "STAGE 4   DAY 8   ¤1840   REP 28")
	portrait_block(svg, profile(catalog, "auctioneer"), 24, 88, 220, 268, "유찰", "예약가에 닿지 못해 유찰입니다.", "유찰 · 예약가 ¤620 · 최종가 ¤410", "NEGATIVE", catalog.get("expressionGeometry", {}))
	portrait_block(svg, profile(catalog, "bidder_04"), 996, 88, 260, 268, "입찰 포기", "이번에는 물러납니다.", "입찰 포기 · 가치 판단", "NEGATIVE", catalog.get("expressionGeometry", {}))
	svg.append(text_node("판단 근거", 1008, 475, 12, "#8fa5aa", "bold"))
	svg.append(rect_node(1004, 486, 112, 38, "#281c1a", "#e59b7a", 8, 1))
	svg.append(text_node("예약가 부담", 1060, 510, 12, "#f0b29a", "bold", "middle"))
	svg.append(rect_node(1122, 486, 122, 38, "#281c1a", "#e59b7a", 8, 1))
	svg.append(text_node("출처 불확실", 1183, 510, 12, "#f0b29a", "bold", "middle"))
	svg.append(rect_node(260, 88, 720, 520, "#151b1f", "#75664b"))
	svg.append(text_node("Arclight Mantel Clock", 282, 125, 22, "#e3c681", "bold"))
	tile(svg, 282, 145, 210, "objective", "시작가", "¤280")
	tile(svg, 506, 145, 210, "risk", "예약가", "¤620")
	tile(svg, 730, 145, 224, "report", "최종가", "¤410")
	svg.append(text_node("최근 호가", 282, 258, 16, "#8fa5aa", "bold"))
	var bids := [["개인 수집가", 340], ["전문 딜러", 375], ["인테리어 장식가", 410]]
	for index in range(bids.size()):
		var y := 280.0 + index * 48.0
		svg.append(rect_node(282, y, 672, 38, "#11171b", "#3e4949", 6, 1))
		svg.append(text_node(bids[index][0], 300, y + 25, 14))
		svg.append(text_node("¤%d" % bids[index][1], 930, y + 25, 14, "#f0bd71", "bold", "end"))
	svg.append(text_node("유찰 · 수수료 ¤0 · 정산액 ¤0", 282, 514, 18, "#e59b7a", "bold"))
	svg.append(rect_node(282, 535, 672, 54, "#2a2020", "#e59b7a"))
	svg.append(text_node("유찰 기록", 618, 569, 15, "#fff5d9", "bold", "middle"))
	return finish_screen(svg)


func event_capture(catalog: Dictionary) -> String:
	var svg := base_screen("오늘의 사건 — 보관실 배송 문제", "STAGE 8   DAY 18   ¤3280   REP 57")
	portrait_block(svg, profile(catalog, "event_courier"), 28, 92, 300, 330, "주의 결과", "주의가 필요한 소식이에요.", "보관 위험 · +1", "NEGATIVE", catalog.get("expressionGeometry", {}))
	svg.append(rect_node(350, 92, 900, 520, "#151b1f", "#75664b"))
	tile(svg, 374, 116, 852, "briefing", "사건", "습기로 인해 배송 상자의 완충재가 젖었습니다")
	svg.append(icon_node("risk", 390, 230, 86))
	svg.append(text_node("주의 결과", 500, 258, 22, "#e59b7a", "bold"))
	svg.append(text_node("보관 위험이 1 증가했습니다. 다음 작업 전에 확인하세요.", 500, 289, 15))
	svg.append(rect_node(374, 335, 852, 92, "#11171b", "#e59b7a"))
	svg.append(text_node("선택", 398, 365, 13, "#8fa5aa", "bold"))
	svg.append(text_node("시장에서 필요한 보존 도구를 확인한다", 398, 397, 17, "#f2e8cf"))
	svg.append(rect_node(374, 468, 852, 70, "#22342e", "#9fd6bd"))
	svg.append(icon_node("objective", 392, 478, 48))
	svg.append(text_node("시장으로 이동", 800, 512, 17, "#fff5d9", "bold", "middle"))
	return finish_screen(svg)


func expression_triplet_capture(catalog: Dictionary) -> String:
	var svg := base_screen("RUNTIME FACE EXPRESSION TRIPLET", "220×250 · FACE ANCHOR · 3 AXES")
	var courier := profile(catalog, "event_courier")
	var geometry: Dictionary = catalog.get("expressionGeometry", {})
	portrait_block(svg, courier, 115, 100, 220, 250, "NEUTRAL", "brow 0 · eye 0 · mouth 0", "FACE GEOMETRY", "NEUTRAL", geometry)
	portrait_block(svg, courier, 530, 100, 220, 250, "POSITIVE", "brow -5 · eye -3 · mouth -5", "FACE GEOMETRY", "POSITIVE", geometry)
	portrait_block(svg, courier, 945, 100, 220, 250, "NEGATIVE", "brow +5 · eye -3 · mouth +5", "FACE GEOMETRY", "NEGATIVE", geometry)
	return finish_screen(svg)


func stage_capture(registry: Node) -> String:
	var svg := base_screen("새 게임 — 스테이지 선택", "PROFILE   HIGHEST 4 / 10")
	svg.append(text_node("클리어한 단계는 다시 선택할 수 있으며 난이도는 단계마다 약 7% 상승합니다.", 36, 102, 15, "#b7c4c8"))
	for stage_id in range(1, 11):
		var definition: Dictionary = registry.get_stage_definition(stage_id)
		var column := (stage_id - 1) % 5
		var row := floori(float(stage_id - 1) / 5.0)
		var x := 28.0 + column * 245.0
		var y := 128.0 + row * 196.0
		var unlocked := stage_id <= 4
		var completed := stage_id <= 3
		var accent := "#9fd6bd" if completed else ("#e3c681" if unlocked else "#5d625f")
		svg.append(rect_node(x, y, 232, 174, "#151b1f", accent, 12, 2))
		svg.append(icon_node("support" if completed else ("objective" if unlocked else "locked"), x + 82, y + 12, 68))
		var state := "클리어" if completed else ("선택 가능" if unlocked else "잠김")
		var target := 54 + stage_id
		var attempt := "BEST 목표 달성 %d" % (72 + stage_id) if completed else "첫 도전"
		svg.append(text_node("스테이지 %d · %s" % [stage_id, state], x + 116, y + 112, 15, "#e3c681", "bold", "middle"))
		svg.append(text_node("권장 %d · %s" % [target, attempt], x + 116, y + 145, 12, accent, "bold", "middle"))
	return finish_screen(svg)


func stage_clear_capture() -> String:
	var svg := base_screen("캠페인 — 지역 경매 순회", "STAGE 2   DAY 4   ¤1335   REP 18")
	tile(svg, 28, 88, 382, "objective", "스테이지 2", "세월의 흔적과 약속")
	tile(svg, 424, 88, 382, "support", "성과", "현재 40 · 권장 56")
	tile(svg, 820, 88, 430, "report", "사건", "3 / 3")
	svg.append(rect_node(28, 194, 1222, 306, "#17231f", "#9fd6bd", 12, 2))
	svg.append(icon_node("support", 48, 207, 52))
	svg.append(text_node("STAGE CLEAR", 118, 239, 26, "#9fd6bd", "bold"))
	svg.append(text_node("성장 중 · 점수 40", 930, 239, 19, "#f2e8cf", "bold"))
	svg.append(text_node("권장 목표까지 16점", 52, 278, 14, "#e3c681", "bold"))
	svg.append(text_node("다음 스테이지 해금", 494, 278, 14, "#9fd6bd", "bold"))
	svg.append(text_node("신기록 · BEST 40", 1010, 278, 14, "#b7c4c8", "bold"))
	var axis_rows := [
		[48.0, "citation", "근거", "78", "좋음"],
		[449.0, "tool", "보존", "92", "좋음"],
		[850.0, "report", "판매", "—", "기록 없음"]
	]
	for axis_row: Array in axis_rows:
		var axis_x := float(axis_row[0])
		svg.append(rect_node(axis_x, 300, 382, 104, "#111a1b", "#75664b", 10, 1))
		svg.append(icon_node(String(axis_row[1]), axis_x + 14, 320, 56))
		svg.append(text_node(String(axis_row[2]), axis_x + 84, 328, 13, "#e3c681", "bold"))
		svg.append(text_node(String(axis_row[3]), axis_x + 84, 375, 28, "#f2e8cf", "bold"))
		svg.append(text_node(String(axis_row[4]), axis_x + 205, 372, 12, "#9fd6bd" if String(axis_row[3]) != "—" else "#e59b7a", "bold"))
	svg.append(text_node("재도전 팁 · 독립 근거를 더 인용해 보세요", 52, 456, 15, "#e59b7a", "bold"))
	svg.append(rect_node(28, 516, 1222, 62, "#22342e", "#9fd6bd"))
	svg.append(text_node("다음 스테이지 또는 재도전", 639, 554, 16, "#fff5d9", "bold", "middle"))
	return finish_screen(svg)


func listing_price_capture() -> String:
	var svg := base_screen("가치 평가 — 출품과 정보 공개", "STAGE 3   DAY 6   ¤1520   REP 23")
	svg.append(text_node("Aurelian Mechanical Clock A", 34, 108, 22, "#e3c681", "bold"))
	svg.append(text_node("선택한 가설 · 증거 신뢰도 92% · 추정 가치 ¤640", 34, 140, 15, "#b7c4c8"))
	for badge_index in range(3):
		var badge_x := 34.0 + badge_index * 190.0
		svg.append(rect_node(badge_x, 158, 176, 40, "#19241f" if badge_index < 2 else "#281c1a", "#9fd6bd" if badge_index < 2 else "#e59b7a", 8, 1))
	var badge_texts := ["상태 정보 충분", "조사 정보 충분", "출처 불확실"]
	for badge_index in range(3):
		svg.append(text_node(badge_texts[badge_index], 122 + badge_index * 190, 184, 13, "#bfe4d2" if badge_index < 2 else "#f0b29a", "bold", "middle"))
	svg.append(text_node("1 / 2 · 가격 전략 선택", 34, 236, 20, "#e3c681", "bold"))
	var plans := [["objective", "빠른 판매", 320, 384], ["report", "균형 판매", 384, 460], ["risk", "높은 목표", 435, 524]]
	for plan_index in range(plans.size()):
		var x := 28.0 + plan_index * 407.0
		svg.append(rect_node(x, 258, 392, 190, "#151b1f", "#75664b", 12, 2))
		svg.append(icon_node(plans[plan_index][0], x + 156, 278, 80))
		svg.append(text_node(plans[plan_index][1], x + 196, 382, 19, "#e3c681", "bold", "middle"))
		svg.append(text_node("시작 ¤%d · 예약 ¤%d" % [plans[plan_index][2], plans[plan_index][3]], x + 196, 416, 15, "#f2e8cf", "bold", "middle"))
	svg.append(text_node("표시된 고정 가격 비율 중 하나를 선택하세요.", 34, 490, 14, "#8fa5aa"))
	return finish_screen(svg)


func listing_disclosure_capture() -> String:
	var svg := base_screen("가치 평가 — 출품과 정보 공개", "STAGE 3   DAY 6   ¤1520   REP 23")
	svg.append(text_node("Aurelian Mechanical Clock A", 34, 108, 22, "#e3c681", "bold"))
	svg.append(text_node("빠른 판매 · 시작 ¤320 · 예약 ¤384", 34, 140, 15, "#b7c4c8"))
	svg.append(rect_node(28, 160, 1222, 46, "#19241f", "#9fd6bd", 9, 1))
	svg.append(icon_node("citation", 40, 166, 34))
	svg.append(text_node("공개 근거 · 근거 보통", 88, 190, 14, "#bfe4d2", "bold"))
	svg.append(text_node("2 / 2 · 주장 강도 선택", 34, 238, 20, "#e3c681", "bold"))
	var disclosures := [["risk", "단정적 주장", "과장 위험"], ["support", "유력한 주장", "균형"], ["citation", "제한적 주장", "과소공개 · 관심 저하"]]
	for disclosure_index in range(disclosures.size()):
		var x := 28.0 + disclosure_index * 407.0
		svg.append(rect_node(x, 255, 392, 120, "#151b1f", "#9fd6bd" if disclosure_index == 0 else "#75664b", 12, 2))
		svg.append(icon_node(disclosures[disclosure_index][0], x + 18, 282, 58))
		svg.append(text_node(("선택됨 · " if disclosure_index == 0 else "") + disclosures[disclosure_index][1], x + 94, 300, 17, "#e3c681", "bold"))
		svg.append(text_node(disclosures[disclosure_index][2], x + 94, 336, 14, "#f2e8cf"))
	svg.append(rect_node(28, 400, 1222, 78, "#171d21", "#75664b"))
	svg.append(icon_node("report", 44, 411, 52))
	svg.append(text_node("최종 출품", 112, 425, 13, "#e3c681", "bold"))
	svg.append(text_node("빠른 판매 · 시작 ¤320 · 예약 ¤384 · 단정적 주장 · 과장 위험", 112, 458, 17, "#f2e8cf"))
	svg.append(rect_node(28, 500, 300, 64, "#171d21", "#75664b"))
	svg.append(text_node("← 가격 변경", 178, 540, 15, "#f2e8cf", "bold", "middle"))
	svg.append(rect_node(342, 500, 908, 64, "#22342e", "#9fd6bd"))
	svg.append(text_node("출품 확정", 796, 540, 17, "#fff5d9", "bold", "middle"))
	return finish_screen(svg)


func tutorial_guidance_capture() -> String:
	var svg := base_screen("사건 서류 — 닫힌 공방", "STAGE 1   DAY 1   ¤1200   REP 12")
	svg.append(rect_node(28, 82, 1222, 58, "#18231f", "#e3c681", 10, 2))
	svg.append(icon_node("clue_generic", 40, 92, 38))
	svg.append(text_node("안내 1/6", 94, 116, 13, "#9fd6bd", "bold"))
	svg.append(text_node("단서 하나 조사", 200, 106, 15, "#e3c681", "bold"))
	svg.append(text_node("위험을 보고 단서 하나를 기록하세요.", 200, 128, 13, "#f2e8cf"))
	tile(svg, 28, 152, 398, "briefing", "상황", "닫힌 공방의 탁상시계를 조사한다")
	tile(svg, 440, 152, 398, "core_question", "핵심 질문", "당대 수리인가, 후대 재조립인가?")
	tile(svg, 852, 152, 398, "objective", "목표", "독립 출처로 가설을 입증한다")
	svg.append(text_node("단서 카드", 30, 258, 17, "#e3c681", "bold"))
	var cards := [
		[28, 274, "artifact", "조사 가능 · 후면판 나사 불일치", "실물 · 위험 높음"],
		[393, 274, "artifact", "조사 가능 · 브리지 각인", "실물 · 도구 필요"],
		[28, 350, "locked", "잠김 · 1937년 수리표", "문서 · 선행 단서 필요"],
		[393, 350, "locked", "잠김 · 마라의 기억", "인물 · 선행 단서 필요"],
	]
	for card: Array in cards:
		svg.append(rect_node(card[0], card[1], 352, 66, "#151b1f", "#5d625f"))
		svg.append(icon_node(card[2], card[0] + 8, card[1] + 10, 44))
		svg.append(text_node(card[3], card[0] + 60, card[1] + 26, 13, "#f2e8cf", "bold"))
		svg.append(text_node(card[4], card[0] + 60, card[1] + 49, 11, "#9aa8aa"))
	svg.append(rect_node(770, 258, 480, 286, "#11171b", "#75664b"))
	svg.append(icon_node("artifact", 790, 278, 54))
	svg.append(text_node("선택한 단서", 858, 296, 12, "#8fa5aa"))
	svg.append(text_node("후면판 나사의 불일치", 858, 322, 18, "#e3c681", "bold"))
	svg.append(icon_node("risk", 792, 354, 36))
	svg.append(text_node("위험 높음", 840, 378, 14, "#e59b7a", "bold"))
	svg.append(text_node("연마 전에 산화 경계를 기록하세요.", 792, 416, 14, "#d9c4ac"))
	svg.append(rect_node(786, 454, 448, 64, "#222b2f", "#f0bd71", 10, 4))
	svg.append(icon_node("clue_generic", 800, 466, 38))
	svg.append(text_node("조사 실행", 858, 493, 15, "#fff5d9", "bold"))
	svg.append(text_node("가설 선택", 30, 566, 17, "#e3c681", "bold"))
	for hypothesis_index in range(3):
		var x := 164.0 + hypothesis_index * 365.0
		svg.append(rect_node(x, 550, 340, 65, "#151b1f", "#5d625f"))
		svg.append(icon_node("hypothesis", x + 10, 560, 42))
		svg.append(text_node(["출고 상태 그대로", "당대 수리를 거친 진품", "후대 재조립품"][hypothesis_index], x + 66, 590, 14, "#f2e8cf"))
	return finish_screen(svg)


func write_capture(file_name: String, svg_source: String, note: String) -> bool:
	var image := Image.new()
	var load_error := image.load_svg_from_buffer(svg_source.to_utf8_buffer(), 1.0)
	if load_error != OK:
		push_error("Headless SVG rasterization failed for %s: %s" % [file_name, error_string(load_error)])
		return false
	var path := "%s/%s.png" % [OUTPUT_DIR, file_name]
	var save_error := image.save_png(path)
	if save_error != OK:
		push_error("Could not save %s: %s" % [path, error_string(save_error)])
		return false
	captures.append({"name": file_name, "path": path, "resolution": "%dx%d" % [image.get_width(), image.get_height()], "mode": "HEADLESS_SVG_COMPOSITE", "note": note})
	return true


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.persistence_enabled = false
	gs.language = "ko"
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters/characters.json"))
	var all_saved := true
	all_saved = write_capture("01_illustrated_case_dossier_ko", case_capture(gs), "16개 사건 픽토그램, 접힌 단서 카드, 위험 선행 확인, 가설·보고서 요약") and all_saved
	all_saved = write_capture("02_portrait_market_ko", market_capture(gs, registry, catalog), "상점 주인 상반신 초상과 제안/가격 라벨, 우측 유물 목록") and all_saved
	all_saved = write_capture("03_portrait_auction_ko", auction_capture(catalog), "좌측 경매 진행원, 중앙 가격·유물, 우측 낙찰자와 공개 판단 근거 칩") and all_saved
	all_saved = write_capture("04_portrait_event_ko", event_capture(catalog), "이벤트 인물 초상, 부정 결과 라벨, 우측 선택 영역") and all_saved
	all_saved = write_capture("05_stage_select_ko", stage_capture(registry), "1~10 스테이지, 재도전/잠금, 권장 목표와 BEST/첫 도전 요약") and all_saved
	all_saved = write_capture("06_portrait_expression_triplet_runtime", expression_triplet_capture(catalog), "220×250 실제 얼굴 영역에 적용된 NEUTRAL/POSITIVE/NEGATIVE 3축 런타임 오버레이") and all_saved
	all_saved = write_capture("07_portrait_auction_no_sale_reasons_ko", auction_no_sale_capture(catalog), "유찰 결과, 부정 표정, 예약가·출처 판단 근거 칩") and all_saved
	all_saved = write_capture("08_stage_clear_summary_ko", stage_clear_capture(), "STAGE CLEAR, 압축 결과 메타, 근거·보존·판매 3축, 한 줄 재도전 팁") and all_saved
	all_saved = write_capture("09_listing_price_step_ko", listing_price_capture(), "출품 1단계: FAST/BALANCED/HIGH 고정 가격 카드 3개와 공개 재료 배지") and all_saved
	all_saved = write_capture("10_listing_disclosure_step_ko", listing_disclosure_capture(), "출품 2단계: 공개 근거 배지 1개, 주장 강도·보정 위험 카드 3개, 단일 확정 행동") and all_saved
	all_saved = write_capture("11_tutorial_guidance_rail_ko", tutorial_guidance_capture(), "단일 1/6 안내 레일, 한 줄 지시문, 실제 조사 버튼 강조, 내비게이션 비침범") and all_saved
	var report := {"suite": "R3 MVP UI Headless Captures", "captureMode": "HEADLESS_SVG_COMPOSITE", "runtimeFramebufferAvailable": false, "reason": "Godot headless uses the dummy renderer; source SVG assets and runtime data are rasterized offscreen instead.", "captures": captures, "count": captures.size(), "passed": all_saved and captures.size() == 11, "heldArtifactsCreated": false}
	var output := FileAccess.open("res://qa/R3_MVP_UI_HEADLESS_CAPTURES.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	quit(0 if bool(report.passed) else 1)
