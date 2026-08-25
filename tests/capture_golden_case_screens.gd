extends SceneTree

const CASE_ID := "prologue_clock"

var render_dir := "res://qa/golden_case_renders"
var captures: Array = []


func _init() -> void:
	call_deferred("capture")


func dossier_scroll(main: Node3D) -> ScrollContainer:
	for candidate: Node in main.find_children("*", "ScrollContainer", true, false):
		if candidate is ScrollContainer:
			return candidate
	return null


func position_dossier(main: Node3D, fraction: float) -> void:
	await process_frame
	await process_frame
	var scroll := dossier_scroll(main)
	if scroll == null:
		return
	var bar := scroll.get_v_scroll_bar()
	var available := maxf(0.0, bar.max_value - bar.page)
	scroll.scroll_vertical = int(round(available * clampf(fraction, 0.0, 1.0)))
	await process_frame
	await process_frame


func snap(file_name: String, sequence: Array, note: String) -> void:
	await process_frame
	await process_frame
	var image := get_root().get_viewport().get_texture().get_image()
	if image == null:
		push_error("No rendered framebuffer for %s" % file_name)
		quit(1)
		return
	var path := "%s/%s.png" % [render_dir, file_name]
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save %s: %s" % [path, error_string(error)])
		quit(1)
		return
	captures.append({
		"name": file_name,
		"path": path,
		"resolution": "1280x720",
		"sequence": sequence,
		"status": "CAPTURED_PENDING_VISUAL_REVIEW",
		"note": note
	})


func discover_all(gs: Node) -> Array:
	var discovered: Array = []
	for _pass in range(12):
		var public_state: Dictionary = gs.get_case_public_state(CASE_ID)
		var progressed := false
		for evidence: Dictionary in public_state.get("availableEvidence", []):
			var required_tools: Array = evidence.get("requiredTools", [])
			if not required_tools.is_empty():
				gs.select_tool(String(required_tools[0]))
			var result: Dictionary = gs.discover_case_evidence(CASE_ID, evidence.id)
			if bool(result.get("ok", false)) and result.get("code", "") == "DISCOVERED":
				discovered.append(evidence.id)
				progressed = true
		if not progressed:
			break
	return discovered


func build_contact_sheet() -> void:
	var thumb_size := Vector2i(640, 360)
	var sheet := Image.create_empty(thumb_size.x * 2, thumb_size.y * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#101418"))
	for index in range(captures.size()):
		var capture: Dictionary = captures[index]
		var image := Image.load_from_file(capture.path)
		if image == null or image.is_empty():
			continue
		image.resize(thumb_size.x, thumb_size.y, Image.INTERPOLATE_LANCZOS)
		var destination := Vector2i((index % 2) * thumb_size.x, int(index / 2) * thumb_size.y)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, thumb_size), destination)
	sheet.save_png("%s/prologue_dossier_contact_sheet.png" % render_dir)


func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(render_dir))
	var gs: Node = get_root().get_node("GameState")
	gs.reset_game()
	gs.persistence_enabled = false
	gs.language = "ko"
	var artifact: Dictionary = gs.begin_case(CASE_ID)
	if artifact.is_empty():
		push_error("Could not begin authored-v2 Prologue case")
		quit(1)
		return

	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.language = "ko"
	main.selected = artifact
	main.load_artifact(artifact)
	main.show_case_dossier(CASE_ID)
	await position_dossier(main, 0.12)
	await snap(
		"01_prologue_dossier_risk_ko",
		["새 게임", "프롤로그 시작", "사건 서류 열기"],
		"조사 전에 노출되는 위험 등급과 손상 방지 지침"
	)

	var discovered := discover_all(gs)
	main.show_case_dossier(CASE_ID)
	await position_dossier(main, 0.48)
	await snap(
		"02_prologue_dossier_evidence_ko",
		["도구 장착", "독립 출처 5개 조사", "증거 원장 중단 보기"],
		"발견된 실물·문서·NPC·참고자료와 가설 지지/반박 관계"
	)

	gs.set_case_hypothesis(CASE_ID, "hyp.period_repair")
	for evidence_id: String in [
		"src.prologue.artifact.backplate_screws",
		"src.prologue.artifact.bridge_stamp",
		"src.prologue.document.service_card"
	]:
		gs.toggle_case_citation(CASE_ID, evidence_id)
	main.show_case_dossier(CASE_ID)
	await position_dossier(main, 1.0)
	await snap(
		"03_prologue_dossier_report_ko",
		["가설 선택", "서로 독립된 증거 3개 인용", "보고서 영역으로 스크롤"],
		"세 가설, 보고서 요구사항, 인용 수와 제출 가능 상태"
	)

	var result: Dictionary = gs.resolve_case_v2(
		CASE_ID,
		"hyp.period_repair",
		[
			"src.prologue.artifact.backplate_screws",
			"src.prologue.artifact.bridge_stamp",
			"src.prologue.document.service_card"
		]
	)
	main.show_case_dossier(CASE_ID)
	await position_dossier(main, 0.0)
	await snap(
		"04_prologue_dossier_result_ko",
		["증거 기반 보고서 제출"],
		"결론 정확도와 입증 수준을 분리해 보여 주는 결과 화면"
	)

	build_contact_sheet()
	var report := {
		"suite": "R3 Authored-v2 Prologue Dossier Visual QA",
		"caseId": CASE_ID,
		"locale": "ko",
		"discoveredEvidenceCount": discovered.size(),
		"resolution": result,
		"captures": captures,
		"count": captures.size(),
		"heldArtifactsCreated": false
	}
	var report_file := FileAccess.open("res://qa/R3_GOLDEN_CASE_VISUAL_QA.json", FileAccess.WRITE)
	if report_file == null:
		push_error("Could not open Golden Case visual QA report")
		quit(1)
		return
	report_file.store_string(JSON.stringify(report, "  "))
	report_file.close()
	print("R3_GOLDEN_CASE_SCREENSHOTS_CREATED %d" % captures.size())
	main.queue_free()
	quit(0)
