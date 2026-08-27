extends SceneTree

const VIEWPORT_SIZE := Vector2i(1280, 720)
const CASE_ID := "prologue_clock"
const TUTORIAL_STEPS := ["INVESTIGATE", "CITE", "REPORT", "REPAIR", "LIST", "AUCTION"]
const AUTH_HYPOTHESES := [
	"GENUINE", "GENUINE_WITH_PERIOD_REPAIR", "GENUINE_WITH_MODERN_REPAIR",
	"REPRODUCTION", "FORGERY", "UNKNOWN"
]
const AUTH_EVIDENCE_IDS := [
	"MAKER_MARK", "SERIAL_PATTERN", "MATERIAL", "CONSTRUCTION_METHOD",
	"COMPONENT_STYLE", "REPAIR_TRACE", "PATINA", "PROVENANCE"
]
const OUTPUT_DIR := "res://qa/latest_runtime_viewport"
const VISUAL_REVIEW_PATH := "res://qa/latest_runtime_viewport/manual_visual_review.json"
const FINAL_JOURNEY_RAW_TOKENS := [
	"selectedLotIds", "uniqueId", "specId", "artifactSpecId", "publicFingerprint",
	"reasonTags", "sale_status", "currentEnding", "stageRunState", "ENDING_",
	"GRAND_RESERVE", "AUCTION_PENDING", "BETWEEN_LOTS", "FINALIZED", "NO_CASE",
	"PROVENANCE_STRONG", "PROVENANCE_UNCERTAIN", "CONDITION_GOOD", "CONDITION_RISK",
	"DISCLOSURE_CLEAR", "DISCLOSURE_UNCLEAR", "RESERVE_TOO_HIGH", "RESERVE_MET",
	"NO_PUBLIC_BID"
]

var captures: Array = []
var layout_failures: Array = []
var framebuffer_capture_enabled := false


func _init() -> void:
	call_deferred("run")


func settle_ui(frame_count: int = 4) -> void:
	for _frame in range(frame_count):
		await process_frame


func rect_array(rect: Rect2) -> Array:
	return [
		roundf(rect.position.x * 10.0) / 10.0,
		roundf(rect.position.y * 10.0) / 10.0,
		roundf(rect.size.x * 10.0) / 10.0,
		roundf(rect.size.y * 10.0) / 10.0
	]


func rect_contains_rect(outer: Rect2, inner: Rect2, tolerance: float = 1.0) -> bool:
	return inner.position.x >= outer.position.x - tolerance \
		and inner.position.y >= outer.position.y - tolerance \
		and inner.end.x <= outer.end.x + tolerance \
		and inner.end.y <= outer.end.y + tolerance


func control_rect(control: Control) -> Rect2:
	return control.get_global_rect() if control != null else Rect2()


func effective_visible_rect(control: Control, viewport_rect: Rect2) -> Rect2:
	if control == null or not control.is_visible_in_tree():
		return Rect2()
	var visible_rect := control.get_global_rect().intersection(viewport_rect)
	var ancestor := control.get_parent()
	while ancestor != null and visible_rect.size.x > 0.0 and visible_rect.size.y > 0.0:
		if ancestor is Control and (ancestor as Control).clip_contents:
			visible_rect = visible_rect.intersection((ancestor as Control).get_global_rect())
		ancestor = ancestor.get_parent()
	return visible_rect


func visible_geometry_snapshot(root: Node, patterns: Array) -> Dictionary:
	var snapshot: Dictionary = {}
	for pattern_value: Variant in patterns:
		var pattern := String(pattern_value)
		for candidate: Node in root.find_children(pattern, "Control", true, false):
			if candidate is Control and candidate.is_visible_in_tree():
				var relative_path := String(root.get_path_to(candidate))
				snapshot[relative_path] = rect_array((candidate as Control).get_global_rect())
	return snapshot


func stable_geometry_failures(before: Dictionary, after: Dictionary, tolerance: float = 0.5) -> Array:
	var failures: Array = []
	for path_value: Variant in before.keys():
		var path := String(path_value)
		if not after.has(path):
			failures.append("animation_geometry_missing_after:%s" % path)
			continue
		var before_rect: Array = before[path]
		var after_rect: Array = after[path]
		if before_rect.size() != after_rect.size():
			failures.append("animation_geometry_shape:%s" % path)
			continue
		for component in range(before_rect.size()):
			if absf(float(before_rect[component]) - float(after_rect[component])) > tolerance:
				failures.append("animation_geometry_changed:%s" % path)
				break
	for path_value: Variant in after.keys():
		var path := String(path_value)
		if not before.has(path):
			failures.append("animation_geometry_missing_before:%s" % path)
	return failures


func portrait_reaction_snapshot(root: Node) -> Dictionary:
	var snapshot: Dictionary = {}
	for candidate: Node in root.find_children("PortraitReactionAnchor", "Control", true, false):
		if not candidate is Control or not candidate.is_visible_in_tree():
			continue
		var anchor := candidate as Control
		var contract: Dictionary = anchor.get_meta("reaction_contract") if anchor.has_meta("reaction_contract") else {}
		var running := bool(anchor.get_meta("reaction_running")) if anchor.has_meta("reaction_running") else false
		var anchor_modulate := anchor.modulate
		snapshot[String(root.get_path_to(anchor))] = {
			"contract": contract.duplicate(true),
			"running": running,
			"scale": [anchor.scale.x, anchor.scale.y],
			"rotationDegrees": anchor.rotation_degrees,
			"modulate": [anchor_modulate.r, anchor_modulate.g, anchor_modulate.b, anchor_modulate.a]
		}
	return snapshot


func portrait_reaction_failures(before: Dictionary, after: Dictionary, expected_count: int, tolerance: float = 0.01) -> Array:
	var failures: Array = []
	if before.size() != expected_count:
		failures.append("portrait_reaction_before_count:%d_expected_%d" % [before.size(), expected_count])
	if after.size() != expected_count:
		failures.append("portrait_reaction_after_count:%d_expected_%d" % [after.size(), expected_count])
	for path_value: Variant in before.keys():
		var path := String(path_value)
		var before_state: Dictionary = before[path]
		if not bool(before_state.get("running", false)):
			failures.append("portrait_reaction_not_running_before:%s" % path)
		var contract: Dictionary = before_state.get("contract", {})
		var duration_ms := int(contract.get("durationMs", 0))
		if duration_ms < 100 or duration_ms > 180:
			failures.append("portrait_reaction_duration:%s=%d" % [path, duration_ms])
		var final_transform: Dictionary = contract.get("finalTransform", {})
		if final_transform.get("scale", []) != [1.0, 1.0] or absf(float(final_transform.get("rotationDegrees", 999.0))) > tolerance or absf(float(final_transform.get("alpha", -1.0)) - 1.0) > tolerance or final_transform.get("positionOffset", []) != [0.0, 0.0]:
			failures.append("portrait_reaction_final_contract:%s" % path)
		if not after.has(path):
			continue
		var after_state: Dictionary = after[path]
		if bool(after_state.get("running", true)):
			failures.append("portrait_reaction_still_running_after:%s" % path)
		var after_scale: Array = after_state.get("scale", [])
		var after_modulate: Array = after_state.get("modulate", [])
		if after_scale.size() != 2 or absf(float(after_scale[0]) - 1.0) > tolerance or absf(float(after_scale[1]) - 1.0) > tolerance:
			failures.append("portrait_reaction_scale_not_reset:%s" % path)
		if absf(float(after_state.get("rotationDegrees", 999.0))) > tolerance:
			failures.append("portrait_reaction_rotation_not_reset:%s" % path)
		if after_modulate.size() != 4 or after_modulate.any(func(component: Variant): return absf(float(component) - 1.0) > tolerance):
			failures.append("portrait_reaction_modulate_not_reset:%s" % path)
	return failures


func visible_copy(root: Node) -> String:
	var copy := ""
	for label: Label in root.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			copy += label.text + "\n"
	for button: Button in root.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			copy += button.text + "\n"
	return copy


func stable_save_authority_signature(gs: Node) -> String:
	var run_payload: Dictionary = gs.save_payload().duplicate(true)
	# Locale is the one intentional saved field changed by the KO/EN refresh.
	run_payload["language"] = "<locale>"
	return JSON.stringify({"run": run_payload, "profile": gs.profile_payload()})


func locale_toggle_with_authority_evidence(gs: Node, main: Node3D, expected_locale: String) -> Dictionary:
	# Normalize the persisted presentation mirror before the comparison. The
	# language action performs this same sync internally; it is UI resume state,
	# not a gameplay mutation, and must not appear as a one-sided first write.
	main.sync_public_interaction_state()
	var screen_before := String(main.screen)
	var authority_before := stable_save_authority_signature(gs)
	var rng_before := int(gs.rng.state)
	var selected_before: Array = gs.campaign_state.get("grandReserve", {}).get("selectedLotIds", []).duplicate()
	var ending_before := String(gs.campaign_state.get("currentEnding", ""))
	var stage_status_before := String(gs.stage_run_state.get("status", ""))
	var language_button := find_visible_control(main, "Nav_LANGUAGE")
	var public_button_pressed := language_button is Button and not (language_button as Button).disabled
	if public_button_pressed:
		(language_button as Button).pressed.emit()
	await settle_ui(8)
	var authority_after := stable_save_authority_signature(gs)
	var rng_after := int(gs.rng.state)
	var selected_after: Array = gs.campaign_state.get("grandReserve", {}).get("selectedLotIds", []).duplicate()
	var evidence := {
		"publicButton": "Nav_LANGUAGE",
		"publicButtonPressed": public_button_pressed,
		"expectedLocale": expected_locale,
		"gameLocale": String(gs.language),
		"uiLocale": String(main.language),
		"screenBefore": screen_before,
		"screenAfter": String(main.screen),
		"authorityMutation0": authority_before == authority_after,
		"authorityBeforeHash": authority_before.sha256_text(),
		"authorityAfterHash": authority_after.sha256_text(),
		"rngBefore": str(rng_before),
		"rngAfter": str(rng_after),
		"rngMutation0": rng_before == rng_after,
		"selectionMutation0": selected_before == selected_after,
		"endingMutation0": ending_before == String(gs.campaign_state.get("currentEnding", "")),
		"stageStatusMutation0": stage_status_before == String(gs.stage_run_state.get("status", ""))
	}
	evidence["valid"] = public_button_pressed \
		and String(gs.language) == expected_locale \
		and String(main.language) == expected_locale \
		and String(main.screen) == screen_before \
		and bool(evidence.authorityMutation0) \
		and bool(evidence.rngMutation0) \
		and bool(evidence.selectionMutation0) \
		and bool(evidence.endingMutation0) \
		and bool(evidence.stageStatusMutation0)
	return evidence


func final_journey_forbidden_tokens(extra_values: Array = []) -> Array:
	var tokens: Array = FINAL_JOURNEY_RAW_TOKENS.duplicate()
	for extra_value: Variant in extra_values:
		var token := String(extra_value)
		if not token.is_empty() and not tokens.has(token):
			tokens.append(token)
	return tokens


func artifact_internal_tokens(artifacts: Array) -> Array:
	var tokens: Array = []
	for artifact_value: Variant in artifacts:
		if not artifact_value is Dictionary:
			continue
		var artifact: Dictionary = artifact_value
		for key_value: String in ["uniqueId", "instanceId", "specId", "artifactSpecId"]:
			var token := String(artifact.get(key_value, ""))
			if not token.is_empty() and not tokens.has(token):
				tokens.append(token)
	return tokens


func find_visible_control(root: Node, node_name: String) -> Control:
	var candidate := root.find_child(node_name, true, false)
	if candidate is Control and candidate.is_visible_in_tree():
		return candidate as Control
	return null


func count_visible(root: Node, pattern: String, type_name: String) -> int:
	var count := 0
	for candidate: Node in root.find_children(pattern, type_name, true, false):
		if candidate is CanvasItem and candidate.is_visible_in_tree():
			count += 1
	return count


func collapsed_public_labels(root: Node, content_rect: Rect2) -> Array:
	# Semantic copy tests cannot detect a long label collapsed to one glyph.
	# Audit only the portion that can actually be drawn inside the content clip.
	var collapsed: Array = []
	for label: Label in root.find_children("*", "Label", true, false):
		if not label.is_visible_in_tree():
			continue
		var normalized := label.text.replace("\n", " ").strip_edges()
		if normalized.length() < 4:
			continue
		var label_rect := label.get_global_rect()
		var visible_part := label_rect.intersection(content_rect)
		if visible_part.size.x <= 0.0 or visible_part.size.y <= 0.0:
			continue
		if visible_part.size.x < 64.0:
			collapsed.append({
				"name": String(label.name),
				"text": normalized.left(80),
				"rect": rect_array(label_rect),
				"visibleRect": rect_array(visible_part)
			})
	return collapsed


func density_audit(main: Node3D, capture_id: String, specification: Dictionary) -> Dictionary:
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE))
	var content := find_visible_control(main, "ContentMargin")
	var navigation := find_visible_control(main, "Navigation")
	var status := find_visible_control(main, "StatusMessage")
	var failures: Array = []
	var required_rects := {}
	var no_overlap_evidence: Array = []
	var horizontal_gap_evidence: Array = []
	var vertical_gap_evidence: Array = []
	if content == null:
		failures.append("missing:ContentMargin")
	if navigation == null:
		failures.append("missing:Navigation")
	if status == null:
		failures.append("missing:StatusMessage")
	var content_rect := control_rect(content)
	var navigation_rect := control_rect(navigation)
	var status_rect := control_rect(status)
	var allow_clipped: Array = specification.get("allowClipped", [])
	var strict_required_clip := bool(specification.get("strictRequiredClip", false))
	var minimum_widths: Dictionary = specification.get("minimumWidths", {})
	var minimum_heights: Dictionary = specification.get("minimumHeights", {})
	for required_name_value: Variant in specification.get("required", []):
		var required_name := String(required_name_value)
		var required_control := find_visible_control(main, required_name)
		if required_control == null:
			failures.append("missing:%s" % required_name)
			continue
		var required_rect := control_rect(required_control)
		required_rects[required_name] = rect_array(required_rect)
		if required_rect.size.x <= 0.0 or required_rect.size.y <= 0.0:
			failures.append("zero_size:%s" % required_name)
		elif content != null and not allow_clipped.has(required_name) and not rect_contains_rect(content_rect, required_rect):
			failures.append("outside_content:%s" % required_name)
		if strict_required_clip and not allow_clipped.has(required_name):
			var required_visible_rect := effective_visible_rect(required_control, viewport_rect)
			if not rect_contains_rect(required_visible_rect, required_rect):
				failures.append("clipped_required:%s" % required_name)
		var minimum_width := float(minimum_widths.get(required_name, 0.0))
		if minimum_width > 0.0 and required_rect.size.x < minimum_width:
			failures.append("narrow:%s=%.1f_expected_%.1f" % [required_name, required_rect.size.x, minimum_width])
		var minimum_height := float(minimum_heights.get(required_name, 0.0))
		if minimum_height > 0.0 and required_rect.size.y < minimum_height:
			failures.append("short:%s=%.1f_expected_%.1f" % [required_name, required_rect.size.y, minimum_height])
	for count_rule_value: Variant in specification.get("counts", []):
		var count_rule: Dictionary = count_rule_value
		var actual := count_visible(main, String(count_rule.get("pattern", "")), String(count_rule.get("type", "Control")))
		var minimum := int(count_rule.get("minimum", count_rule.get("exact", 0)))
		var maximum := int(count_rule.get("maximum", count_rule.get("exact", 999999)))
		if actual < minimum or actual > maximum:
			failures.append("count:%s=%d_expected_%d..%d" % [count_rule.get("pattern", ""), actual, minimum, maximum])
	for line_rule_value: Variant in specification.get("maxLines", []):
		var line_rule: Dictionary = line_rule_value
		var line_name := String(line_rule.get("name", ""))
		var line_label := find_visible_control(main, line_name)
		var expected_lines := int(line_rule.get("maximum", 2))
		if not line_label is Label:
			failures.append("missing_line_label:%s" % line_name)
		elif (line_label as Label).max_lines_visible < 1 or (line_label as Label).max_lines_visible > expected_lines:
			failures.append("line_cap:%s=%d_expected_1..%d" % [line_name, (line_label as Label).max_lines_visible, expected_lines])
	for pair_value: Variant in specification.get("noOverlapPairs", []):
		var pair: Array = pair_value
		if pair.size() != 2:
			continue
		var first := find_visible_control(main, String(pair[0]))
		var second := find_visible_control(main, String(pair[1]))
		var intersects := first != null and second != null and first.get_global_rect().intersects(second.get_global_rect())
		no_overlap_evidence.append({"first": String(pair[0]), "second": String(pair[1]), "present": first != null and second != null, "intersects": intersects})
		if intersects:
			failures.append("overlap:%s:%s" % [pair[0], pair[1]])
	for gap_rule_value: Variant in specification.get("horizontalGaps", []):
		var gap_rule: Dictionary = gap_rule_value
		var left_name := String(gap_rule.get("left", ""))
		var right_name := String(gap_rule.get("right", ""))
		var left_control := find_visible_control(main, left_name)
		var right_control := find_visible_control(main, right_name)
		var minimum_gap := float(gap_rule.get("minimum", 12.0))
		if left_control == null or right_control == null:
			horizontal_gap_evidence.append({"left": left_name, "right": right_name, "present": false, "minimum": minimum_gap})
			failures.append("missing_gap_control:%s:%s" % [left_name, right_name])
		else:
			var actual_gap := right_control.get_global_rect().position.x - left_control.get_global_rect().end.x
			horizontal_gap_evidence.append({"left": left_name, "right": right_name, "present": true, "actual": actual_gap, "minimum": minimum_gap, "passed": actual_gap >= minimum_gap})
			if actual_gap < minimum_gap:
				failures.append("horizontal_gap:%s:%s=%.1f_expected_%.1f" % [left_name, right_name, actual_gap, minimum_gap])
	for gap_rule_value: Variant in specification.get("verticalGaps", []):
		var gap_rule: Dictionary = gap_rule_value
		var above_name := String(gap_rule.get("above", ""))
		var below_name := String(gap_rule.get("below", ""))
		var above_control := find_visible_control(main, above_name)
		var below_control := find_visible_control(main, below_name)
		var minimum_gap := float(gap_rule.get("minimum", 0.0))
		var maximum_gap := float(gap_rule.get("maximum", 999999.0))
		if above_control == null or below_control == null:
			vertical_gap_evidence.append({"above": above_name, "below": below_name, "present": false, "minimum": minimum_gap, "maximum": maximum_gap})
			failures.append("missing_vertical_gap_control:%s:%s" % [above_name, below_name])
		else:
			var actual_gap := below_control.get_global_rect().position.y - above_control.get_global_rect().end.y
			vertical_gap_evidence.append({"above": above_name, "below": below_name, "present": true, "actual": actual_gap, "minimum": minimum_gap, "maximum": maximum_gap, "passed": actual_gap >= minimum_gap and actual_gap <= maximum_gap})
			if actual_gap < minimum_gap or actual_gap > maximum_gap:
				failures.append("vertical_gap:%s:%s=%.1f_expected_%.1f..%.1f" % [above_name, below_name, actual_gap, minimum_gap, maximum_gap])
	var primary_name := String(specification.get("primary", ""))
	if primary_name == "@tutorial_target":
		primary_name = String(main.tutorial_target_control.name) if main.tutorial_target_control != null else ""
	var primary_rect := Rect2()
	if not primary_name.is_empty():
		var primary := find_visible_control(main, primary_name)
		if primary == null:
			failures.append("missing_primary:%s" % primary_name)
		else:
			primary_rect = control_rect(primary)
			if primary is BaseButton and (primary as BaseButton).disabled:
				failures.append("disabled_primary:%s" % primary_name)
			if navigation != null and primary_rect.intersects(navigation_rect):
				failures.append("primary_overlaps_navigation:%s" % primary_name)
			if status != null and primary_rect.intersects(status_rect):
				failures.append("primary_overlaps_status:%s" % primary_name)
	if content != null and not rect_contains_rect(viewport_rect, content_rect):
		failures.append("content_outside_viewport")
	if navigation != null and not rect_contains_rect(viewport_rect, navigation_rect):
		failures.append("navigation_outside_viewport")
	if status != null and not rect_contains_rect(viewport_rect, status_rect):
		failures.append("status_outside_viewport")
	if content != null and navigation != null and content_rect.intersects(navigation_rect):
		failures.append("content_overlaps_navigation")
	if content != null and status != null and content_rect.intersects(status_rect):
		failures.append("content_overlaps_status")
	if navigation != null and status != null and navigation_rect.intersects(status_rect):
		failures.append("navigation_overlaps_status")
	var copy := visible_copy(main)
	for required_copy_value: Variant in specification.get("requiredCopy", []):
		var required_copy := String(required_copy_value)
		if not required_copy.is_empty() and not copy.contains(required_copy):
			failures.append("missing_copy:%s" % required_copy)
	var exposed_tokens: Array = []
	for token_value: Variant in specification.get("forbidden", []):
		var token := String(token_value)
		if not token.is_empty() and copy.contains(token):
			exposed_tokens.append(token)
			failures.append("forbidden_copy:%s" % token)
	var text_fit_evidence: Array = []
	for pattern_value: Variant in specification.get("singleLineTextFitPatterns", []):
		var pattern := String(pattern_value)
		var matched_visible := 0
		for candidate: Node in main.find_children(pattern, "Label", true, false):
			if not candidate is Label or not candidate.is_visible_in_tree():
				continue
			matched_visible += 1
			var label := candidate as Label
			var font := label.get_theme_font("font")
			var font_size := label.get_theme_font_size("font_size")
			var required_width := font.get_string_size(label.text.replace("\n", " "), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
			var label_rect := label.get_global_rect()
			var visible_width := label_rect.intersection(content_rect).size.x if content != null else label_rect.size.x
			var fits := required_width <= visible_width + 1.0
			text_fit_evidence.append({"name": String(label.name), "text": label.text, "requiredWidth": required_width, "visibleWidth": visible_width, "fits": fits})
			if not fits:
				failures.append("single_line_text_clipped:%s=%.1f_available_%.1f" % [String(label.name), required_width, visible_width])
		if matched_visible == 0:
			failures.append("missing_text_fit_pattern:%s" % pattern)
	var allowed_collapsed: Array = specification.get("allowCollapsed", [])
	var collapsed_labels: Array = []
	var collapsed_candidates: Array = collapsed_public_labels(main, content_rect) if content != null else []
	for collapsed: Dictionary in collapsed_candidates:
		if not allowed_collapsed.has(String(collapsed.get("name", ""))):
			collapsed_labels.append(collapsed)
	for collapsed: Dictionary in collapsed_labels:
		failures.append("collapsed_label:%s" % String(collapsed.get("name", "Label")))
	for texture_name_value: Variant in specification.get("textureRequirements", []):
		var texture_name := String(texture_name_value)
		var texture_control := find_visible_control(main, texture_name)
		if not texture_control is TextureRect or (texture_control as TextureRect).texture == null:
			failures.append("missing_texture:%s" % texture_name)
	var button_icon_evidence: Array = []
	for button_pattern_value: Variant in specification.get("buttonIconRequirements", []):
		var button_pattern := String(button_pattern_value)
		var matched_buttons := 0
		for candidate: Node in main.find_children(button_pattern, "Button", true, false):
			if not candidate is Button or not candidate.is_visible_in_tree():
				continue
			matched_buttons += 1
			var has_icon := (candidate as Button).icon != null
			button_icon_evidence.append({"name": String(candidate.name), "hasIcon": has_icon})
			if not has_icon:
				failures.append("missing_button_icon:%s" % String(candidate.name))
		if matched_buttons == 0:
			failures.append("missing_button_icon_pattern:%s" % button_pattern)
	var button_line_evidence: Array = []
	for button_line_rule_value: Variant in specification.get("buttonLineCounts", []):
		var button_line_rule: Dictionary = button_line_rule_value
		var button_line_pattern := String(button_line_rule.get("pattern", ""))
		var expected_minimum := int(button_line_rule.get("minimum", button_line_rule.get("exact", 1)))
		var expected_maximum := int(button_line_rule.get("maximum", button_line_rule.get("exact", 999999)))
		var matched_line_buttons := 0
		for candidate: Node in main.find_children(button_line_pattern, "Button", true, false):
			if not candidate is Button or not candidate.is_visible_in_tree():
				continue
			matched_line_buttons += 1
			var line_count := (candidate as Button).text.split("\n").size()
			var line_ok := line_count >= expected_minimum and line_count <= expected_maximum
			button_line_evidence.append({"name": String(candidate.name), "lines": line_count, "minimum": expected_minimum, "maximum": expected_maximum, "passed": line_ok})
			if not line_ok:
				failures.append("button_lines:%s=%d_expected_%d..%d" % [String(candidate.name), line_count, expected_minimum, expected_maximum])
		if matched_line_buttons == 0:
			failures.append("missing_button_line_pattern:%s" % button_line_pattern)
	var visible_scroll_count := count_visible(main, "*", "ScrollContainer")
	if bool(specification.get("noVisibleScroll", false)) and visible_scroll_count > 0:
		failures.append("visible_scroll_count:%d_expected_0" % visible_scroll_count)
	var viewport_scrolls: Array = []
	var collapsed_detail_scrolls: Array = []
	var collapsed_detail_max_visible_height := float(specification.get("collapsedDetailScrollMaxVisibleHeight", 0.0))
	var collapsed_detail_parent_name := String(specification.get("collapsedDetailScrollParent", ""))
	var collapsed_detail_protected: Array = specification.get("collapsedDetailProtect", [])
	for scroll_candidate: Node in main.find_children("*", "ScrollContainer", true, false):
		if not scroll_candidate is ScrollContainer or not scroll_candidate.is_visible_in_tree():
			continue
		var scroll_control := scroll_candidate as ScrollContainer
		var scroll_visible_rect := effective_visible_rect(scroll_control, viewport_rect)
		if content != null:
			scroll_visible_rect = scroll_visible_rect.intersection(content_rect)
		if scroll_visible_rect.size.x <= 0.0 or scroll_visible_rect.size.y <= 0.0:
			continue
		var inside_collapsed_parent := collapsed_detail_parent_name.is_empty()
		var scroll_ancestor := scroll_control.get_parent()
		while scroll_ancestor != null and not inside_collapsed_parent:
			if String(scroll_ancestor.name) == collapsed_detail_parent_name:
				inside_collapsed_parent = true
				break
			scroll_ancestor = scroll_ancestor.get_parent()
		var is_collapsed_detail := collapsed_detail_max_visible_height > 0.0 \
			and String(scroll_control.name) != collapsed_detail_parent_name \
			and inside_collapsed_parent \
			and scroll_visible_rect.size.y <= collapsed_detail_max_visible_height + 0.5
		if is_collapsed_detail:
			var collapsed_overlaps: Array = []
			for protected_name_value: Variant in collapsed_detail_protected:
				var protected_name := String(protected_name_value)
				var protected := find_visible_control(main, protected_name)
				var overlaps := protected != null and scroll_visible_rect.intersects(protected.get_global_rect())
				collapsed_overlaps.append({"name": protected_name, "present": protected != null, "overlaps": overlaps})
				if protected == null:
					failures.append("missing_collapsed_detail_protected:%s" % protected_name)
				elif overlaps:
					failures.append("collapsed_detail_overlap:%s:%s" % [String(scroll_control.name), protected_name])
			if scroll_control.scroll_horizontal != 0:
				failures.append("collapsed_detail_horizontal:%s=%d_expected_0" % [String(scroll_control.name), scroll_control.scroll_horizontal])
			collapsed_detail_scrolls.append({
				"name": String(scroll_control.name),
				"rect": rect_array(scroll_control.get_global_rect()),
				"visibleRect": rect_array(scroll_visible_rect),
				"visibleHeight": scroll_visible_rect.size.y,
				"maximumAllowedVisibleHeight": collapsed_detail_max_visible_height,
				"inside": collapsed_detail_parent_name,
				"horizontal": scroll_control.scroll_horizontal,
				"protectedOverlaps": collapsed_overlaps
			})
			continue
		viewport_scrolls.append({
			"name": String(scroll_control.name),
			"rect": rect_array(scroll_control.get_global_rect()),
			"visibleRect": rect_array(scroll_visible_rect),
			"horizontal": scroll_control.scroll_horizontal,
			"vertical": scroll_control.scroll_vertical
		})
	var expected_viewport_scrolls := int(specification.get("viewportVisibleScrollExact", -1))
	if expected_viewport_scrolls >= 0 and viewport_scrolls.size() != expected_viewport_scrolls:
		failures.append("viewport_visible_scroll_count:%d_expected_%d" % [viewport_scrolls.size(), expected_viewport_scrolls])
	var allowed_viewport_scrolls: Array = specification.get("allowedViewportScrolls", [])
	if not allowed_viewport_scrolls.is_empty():
		for viewport_scroll: Dictionary in viewport_scrolls:
			if not allowed_viewport_scrolls.has(String(viewport_scroll.get("name", ""))):
				failures.append("unexpected_viewport_scroll:%s" % String(viewport_scroll.get("name", "ScrollContainer")))
	var expected_collapsed_detail_scrolls := int(specification.get("collapsedDetailScrollExact", -1))
	if expected_collapsed_detail_scrolls >= 0 and collapsed_detail_scrolls.size() != expected_collapsed_detail_scrolls:
		failures.append("collapsed_detail_scroll_count:%d_expected_%d" % [collapsed_detail_scrolls.size(), expected_collapsed_detail_scrolls])
	var minimum_collapsed_detail_scrolls := int(specification.get("collapsedDetailScrollMinimum", -1))
	var maximum_collapsed_detail_scrolls := int(specification.get("collapsedDetailScrollMaximum", -1))
	if expected_collapsed_detail_scrolls < 0 and minimum_collapsed_detail_scrolls >= 0 \
			and (collapsed_detail_scrolls.size() < minimum_collapsed_detail_scrolls \
			or (maximum_collapsed_detail_scrolls >= 0 and collapsed_detail_scrolls.size() > maximum_collapsed_detail_scrolls)):
		failures.append("collapsed_detail_scroll_count:%d_expected_%d..%d" % [collapsed_detail_scrolls.size(), minimum_collapsed_detail_scrolls, maximum_collapsed_detail_scrolls])
	var scroll_contract_evidence: Array = []
	for scroll_contract_value: Variant in specification.get("scrollContracts", []):
		var scroll_contract: Dictionary = scroll_contract_value
		var scroll_name := String(scroll_contract.get("name", ""))
		var scroll := find_visible_control(main, scroll_name)
		if not scroll is ScrollContainer:
			failures.append("missing_scroll_contract:%s" % scroll_name)
			continue
		var scroll_container := scroll as ScrollContainer
		var horizontal_value := int(scroll_container.scroll_horizontal)
		var vertical_value := int(scroll_container.scroll_vertical)
		var horizontal_expected := int(scroll_contract.get("horizontal", 0))
		var minimum_vertical := int(scroll_contract.get("minimumVertical", 0))
		var vertical_bar := scroll_container.get_v_scroll_bar()
		var horizontal_bar := scroll_container.get_h_scroll_bar()
		var maximum_vertical := maxi(0, ceili(vertical_bar.max_value - vertical_bar.page))
		var protected_overlaps: Array = []
		if horizontal_value != horizontal_expected:
			failures.append("scroll_horizontal:%s=%d_expected_%d" % [scroll_name, horizontal_value, horizontal_expected])
		if vertical_value < minimum_vertical:
			failures.append("scroll_vertical:%s=%d_expected_at_least_%d" % [scroll_name, vertical_value, minimum_vertical])
		if bool(scroll_contract.get("requireVerticalScrollable", false)) and maximum_vertical <= 0:
			failures.append("scroll_not_vertically_scrollable:%s" % scroll_name)
		for protected_name_value: Variant in scroll_contract.get("protectFromBars", []):
			var protected_name := String(protected_name_value)
			var protected := find_visible_control(main, protected_name)
			if protected == null:
				protected_overlaps.append({"name": protected_name, "present": false})
				failures.append("missing_scrollbar_protected:%s:%s" % [scroll_name, protected_name])
				continue
			var vertical_overlap := vertical_bar.is_visible_in_tree() and vertical_bar.get_global_rect().intersects(protected.get_global_rect())
			var horizontal_overlap := horizontal_bar.is_visible_in_tree() and horizontal_bar.get_global_rect().intersects(protected.get_global_rect())
			protected_overlaps.append({"name": protected_name, "present": true, "verticalBarOverlap": vertical_overlap, "horizontalBarOverlap": horizontal_overlap})
			if vertical_overlap or horizontal_overlap:
				failures.append("scrollbar_overlap:%s:%s" % [scroll_name, protected_name])
		scroll_contract_evidence.append({
			"name": scroll_name,
			"rect": rect_array(scroll_container.get_global_rect()),
			"horizontal": horizontal_value,
			"vertical": vertical_value,
			"maximumVertical": maximum_vertical,
			"verticalBarVisible": vertical_bar.is_visible_in_tree(),
			"verticalBarRect": rect_array(vertical_bar.get_global_rect()),
			"horizontalBarVisible": horizontal_bar.is_visible_in_tree(),
			"horizontalBarRect": rect_array(horizontal_bar.get_global_rect()),
			"protectedOverlaps": protected_overlaps
		})
	var result := {
		"captureId": capture_id,
		"screen": main.screen,
		"passed": failures.is_empty(),
		"viewport": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"contentRect": rect_array(content_rect),
		"navigationRect": rect_array(navigation_rect),
		"statusRect": rect_array(status_rect),
		"primary": primary_name,
		"primaryRect": rect_array(primary_rect),
		"requiredRects": required_rects,
		"noOverlapEvidence": no_overlap_evidence,
		"horizontalGapEvidence": horizontal_gap_evidence,
		"verticalGapEvidence": vertical_gap_evidence,
		"exposedTokens": exposed_tokens,
		"singleLineTextFit": text_fit_evidence,
		"buttonIconEvidence": button_icon_evidence,
		"buttonLineEvidence": button_line_evidence,
		"visibleScrollCount": visible_scroll_count,
		"viewportVisibleScrolls": viewport_scrolls,
		"collapsedDetailScrolls": collapsed_detail_scrolls,
		"scrollContracts": scroll_contract_evidence,
		"collapsedLabels": collapsed_labels,
		"failures": failures
	}
	if specification.has("publicActionEvidence"):
		result["publicActionEvidence"] = specification.get("publicActionEvidence", {}).duplicate(true)
	if not failures.is_empty():
		layout_failures.append(result)
	return result


func capture_frame(main: Node3D, capture_id: String, locale: String, note: String, specification: Dictionary) -> void:
	var reaction_settle_milliseconds := int(specification.get("reactionSettleMilliseconds", 0))
	var post_reaction_frames := int(specification.get("postReactionFrames", 2))
	var stable_geometry_patterns: Array = specification.get("stableGeometryPatterns", [])
	var geometry_before: Dictionary = {}
	var geometry_after: Dictionary = {}
	var geometry_failures: Array = []
	var reaction_before: Dictionary = {}
	var reaction_after: Dictionary = {}
	var reaction_failures: Array = []
	var expected_reaction_count := int(specification.get("portraitReactionCount", 0))
	if reaction_settle_milliseconds > 0:
		# The authored reaction starts after its own first process-frame await.
		# Sample on that same first frame so even the 120 ms variant is observed
		# before a slow initial OpenGL frame can finish it. Then wait the maximum
		# authored duration plus two more frames before the actual framebuffer.
		await settle_ui(1)
		geometry_before = visible_geometry_snapshot(main, stable_geometry_patterns)
		reaction_before = portrait_reaction_snapshot(main)
		await create_timer(float(reaction_settle_milliseconds) / 1000.0).timeout
		await settle_ui(post_reaction_frames)
		geometry_after = visible_geometry_snapshot(main, stable_geometry_patterns)
		reaction_after = portrait_reaction_snapshot(main)
		geometry_failures = stable_geometry_failures(geometry_before, geometry_after)
		reaction_failures = portrait_reaction_failures(reaction_before, reaction_after, expected_reaction_count)
	else:
		await settle_ui()
	var viewport := get_root().get_viewport()
	var actual_size := viewport.get_visible_rect().size
	var layout := density_audit(main, capture_id, specification)
	if reaction_settle_milliseconds > 0:
		layout["animationGeometry"] = {
			"passed": geometry_failures.is_empty(),
			"reactionSettleMilliseconds": reaction_settle_milliseconds,
			"postReactionFrames": post_reaction_frames,
			"stablePatterns": stable_geometry_patterns,
			"before": geometry_before,
			"after": geometry_after,
			"failures": geometry_failures
		}
		layout["portraitReaction"] = {
			"passed": reaction_failures.is_empty(),
			"expectedCount": expected_reaction_count,
			"before": reaction_before,
			"after": reaction_after,
			"failures": reaction_failures
		}
		var animation_failures: Array = geometry_failures.duplicate()
		animation_failures.append_array(reaction_failures)
		if not animation_failures.is_empty():
			var density_was_passing := bool(layout.passed)
			layout.passed = false
			layout.failures.append_array(animation_failures)
			if density_was_passing:
				layout_failures.append(layout)
	if Vector2i(roundi(actual_size.x), roundi(actual_size.y)) != VIEWPORT_SIZE:
		layout.passed = false
		layout.failures.append("viewport_size:%sx%s" % [actual_size.x, actual_size.y])
		layout_failures.append(layout)
	if not framebuffer_capture_enabled:
		captures.append({
			"id": capture_id,
			"path": "",
			"locale": locale,
			"screen": main.screen,
			"resolution": "%dx%d" % [roundi(actual_size.x), roundi(actual_size.y)],
			"source": "actual res://scenes/Main.tscn control tree under Godot --headless",
			"framebufferCaptured": false,
			"status": "PASS" if bool(layout.passed) else "FAIL",
			"note": note,
			"density": layout
		})
		return
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("No rendered framebuffer for %s" % capture_id)
		layout.passed = false
		layout.failures.append("missing_framebuffer")
		layout_failures.append(layout)
		return
	var output_path := "%s/%s.png" % [OUTPUT_DIR, capture_id]
	var save_error := image.save_png(output_path)
	if save_error != OK:
		push_error("Could not save %s: %s" % [output_path, error_string(save_error)])
		layout.passed = false
		layout.failures.append("png_save:%s" % error_string(save_error))
		layout_failures.append(layout)
	captures.append({
		"id": capture_id,
		"path": output_path,
		"locale": locale,
		"screen": main.screen,
		"resolution": "%dx%d" % [image.get_width(), image.get_height()],
		"source": "actual res://scenes/Main.tscn framebuffer",
		"framebufferCaptured": true,
		"status": "PASS" if bool(layout.passed) else "FAIL",
		"note": note,
		"density": layout
	})


func count_workpiece_nodes(main: Node3D, pattern: String) -> int:
	if main.workpiece_root == null:
		return 0
	return main.workpiece_root.find_children(pattern, "", true, false).size()


func capture_workpiece_visual(main: Node3D, registry: Node, capture_id: String, locale: String, spec_id: String, expected_recipe: String, expected_mesh_suffix: String, expected_node_counts: Dictionary, forbidden_node_patterns: Array, note: String) -> void:
	await settle_ui(4)
	var render_dto: Dictionary = registry.get_artifact_render_dto(spec_id)
	var failures: Array = []
	var node_counts: Dictionary = {}
	if String(main.screen) != "inspection":
		failures.append("screen:%s_expected_inspection" % String(main.screen))
	if String(render_dto.get("recipe", "")) != expected_recipe:
		failures.append("recipe:%s_expected_%s" % [String(render_dto.get("recipe", "")), expected_recipe])
	var mesh_path := String(render_dto.get("meshPath", ""))
	if not mesh_path.ends_with(expected_mesh_suffix):
		failures.append("mesh:%s_expected_suffix_%s" % [mesh_path, expected_mesh_suffix])
	for pattern_value: Variant in expected_node_counts.keys():
		var pattern := String(pattern_value)
		var actual_count := count_workpiece_nodes(main, pattern)
		var expected_count := int(expected_node_counts.get(pattern, 0))
		node_counts[pattern] = actual_count
		if actual_count != expected_count:
			failures.append("node_count:%s=%d_expected_%d" % [pattern, actual_count, expected_count])
	for pattern_value: Variant in forbidden_node_patterns:
		var pattern := String(pattern_value)
		var actual_count := count_workpiece_nodes(main, pattern)
		node_counts[pattern] = actual_count
		if actual_count != 0:
			failures.append("forbidden_node:%s=%d" % [pattern, actual_count])
	var viewport := get_root().get_viewport()
	var actual_size := viewport.get_visible_rect().size
	if Vector2i(roundi(actual_size.x), roundi(actual_size.y)) != VIEWPORT_SIZE:
		failures.append("viewport_size:%sx%s" % [actual_size.x, actual_size.y])
	var ui_was_visible: bool = bool(main.ui.visible)
	var workshop_was_visible: bool = bool(main.workshop_set.visible)
	var reserve_was_visible: bool = bool(main.grand_reserve_set.visible)
	main.ui.visible = false
	main.workshop_set.visible = false
	main.grand_reserve_set.visible = false
	await settle_ui(3)
	var output_path := "%s/%s.png" % [OUTPUT_DIR, capture_id]
	if framebuffer_capture_enabled:
		var image := viewport.get_texture().get_image()
		if image == null or image.is_empty():
			failures.append("missing_framebuffer")
		else:
			var save_error := image.save_png(output_path)
			if save_error != OK:
				failures.append("png_save:%s" % error_string(save_error))
	main.ui.visible = ui_was_visible
	main.workshop_set.visible = workshop_was_visible
	main.grand_reserve_set.visible = reserve_was_visible
	await settle_ui(2)
	var contract := {
		"captureId": capture_id,
		"screen": main.screen,
		"passed": failures.is_empty(),
		"viewport": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"specId": spec_id,
		"recipe": String(render_dto.get("recipe", "")),
		"meshPath": mesh_path,
		"nodeCounts": node_counts,
		"uiHiddenForUnobstructedArtifactReview": true,
		"failures": failures
	}
	if not failures.is_empty():
		layout_failures.append(contract)
	captures.append({
		"id": capture_id,
		"path": output_path if framebuffer_capture_enabled else "",
		"locale": locale,
		"screen": main.screen,
		"resolution": "%dx%d" % [roundi(actual_size.x), roundi(actual_size.y)],
		"source": "actual res://scenes/Main.tscn unobstructed 3D framebuffer" if framebuffer_capture_enabled else "actual workpiece node tree under Godot --headless",
		"framebufferCaptured": framebuffer_capture_enabled,
		"status": "PASS" if failures.is_empty() else "FAIL",
		"note": note,
		"density": contract
	})


func capture_story_artifact_workpiece_visual(main: Node3D, registry: Node, capture_id: String, locale: String, story_artifact_id: String, spec_id: String, expected_recipe: String, expected_mesh_path: String, expected_node_counts: Dictionary, forbidden_node_patterns: Array, note: String, expected_base_visible: bool = true) -> void:
	await settle_ui(4)
	var selected_instance: Dictionary = main.selected
	var render_dto: Dictionary = registry.get_artifact_instance_render_dto(selected_instance)
	var failures: Array = []
	var node_counts: Dictionary = {}
	if String(main.screen) != "inspection":
		failures.append("screen:%s_expected_inspection" % String(main.screen))
	if String(selected_instance.get("storyArtifactId", "")) != story_artifact_id:
		failures.append("story_pair:%s_expected_%s" % [String(selected_instance.get("storyArtifactId", "")), story_artifact_id])
	if String(selected_instance.get("artifactSpecId", "")) != spec_id:
		failures.append("spec_pair:%s_expected_%s" % [String(selected_instance.get("artifactSpecId", "")), spec_id])
	if String(render_dto.get("specId", "")) != spec_id:
		failures.append("dto_spec:%s_expected_%s" % [String(render_dto.get("specId", "")), spec_id])
	if String(render_dto.get("recipe", "")) != expected_recipe:
		failures.append("recipe:%s_expected_%s" % [String(render_dto.get("recipe", "")), expected_recipe])
	var dto_mesh_path := String(render_dto.get("meshPath", ""))
	if dto_mesh_path != expected_mesh_path:
		failures.append("dto_mesh:%s_expected_%s" % [dto_mesh_path, expected_mesh_path])
	var live_mesh_path := ""
	var base_mesh_visible := false
	var base_mesh_aabb := AABB()
	if main.model is MeshInstance3D and main.model.mesh != null:
		live_mesh_path = String(main.model.mesh.resource_path)
		base_mesh_visible = main.model.is_visible_in_tree()
		base_mesh_aabb = main.model.mesh.get_aabb()
	else:
		failures.append("missing_live_artifact_mesh")
	if live_mesh_path != expected_mesh_path:
		failures.append("live_mesh:%s_expected_%s" % [live_mesh_path, expected_mesh_path])
	if base_mesh_visible != expected_base_visible:
		failures.append("artifact_mesh_visibility:%s_expected_%s" % [base_mesh_visible, expected_base_visible])
	if base_mesh_aabb.size.x <= 0.0 or base_mesh_aabb.size.y <= 0.0 or base_mesh_aabb.size.z <= 0.0:
		failures.append("artifact_mesh_zero_aabb")
	for pattern_value: Variant in expected_node_counts.keys():
		var pattern := String(pattern_value)
		var actual_count := count_workpiece_nodes(main, pattern)
		var expected_count := int(expected_node_counts.get(pattern, 0))
		node_counts[pattern] = actual_count
		if actual_count != expected_count:
			failures.append("node_count:%s=%d_expected_%d" % [pattern, actual_count, expected_count])
	for pattern_value: Variant in forbidden_node_patterns:
		var pattern := String(pattern_value)
		var actual_count := count_workpiece_nodes(main, pattern)
		node_counts[pattern] = actual_count
		if actual_count != 0:
			failures.append("forbidden_node:%s=%d" % [pattern, actual_count])
	var viewport := get_root().get_viewport()
	var actual_size := viewport.get_visible_rect().size
	if Vector2i(roundi(actual_size.x), roundi(actual_size.y)) != VIEWPORT_SIZE:
		failures.append("viewport_size:%sx%s" % [actual_size.x, actual_size.y])
	var ui_was_visible: bool = bool(main.ui.visible)
	var workshop_was_visible: bool = bool(main.workshop_set.visible)
	var reserve_was_visible: bool = bool(main.grand_reserve_set.visible)
	main.ui.visible = false
	main.workshop_set.visible = false
	main.grand_reserve_set.visible = false
	await settle_ui(3)
	var output_path := "%s/%s.png" % [OUTPUT_DIR, capture_id]
	if framebuffer_capture_enabled:
		var image := viewport.get_texture().get_image()
		if image == null or image.is_empty():
			failures.append("missing_framebuffer")
		else:
			var save_error := image.save_png(output_path)
			if save_error != OK:
				failures.append("png_save:%s" % error_string(save_error))
	main.ui.visible = ui_was_visible
	main.workshop_set.visible = workshop_was_visible
	main.grand_reserve_set.visible = reserve_was_visible
	await settle_ui(2)
	var base_aabb_size := [base_mesh_aabb.size.x, base_mesh_aabb.size.y, base_mesh_aabb.size.z]
	var contract := {
		"captureId": capture_id,
		"screen": main.screen,
		"passed": failures.is_empty(),
		"viewport": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"storyArtifactId": story_artifact_id,
		"specId": spec_id,
		"instanceRenderDtoMethod": "RuntimeRegistry.get_artifact_instance_render_dto(main.selected)",
		"instancePairConsumed": String(selected_instance.get("storyArtifactId", "")) == story_artifact_id and String(selected_instance.get("artifactSpecId", "")) == spec_id,
		"recipe": String(render_dto.get("recipe", "")),
		"dtoMeshPath": dto_mesh_path,
		"dominantBaseMesh": {
			"node": "ArtifactMesh",
			"liveMeshPath": live_mesh_path,
			"matchesInstanceDto": live_mesh_path == dto_mesh_path,
			"visible": base_mesh_visible,
			"expectedVisible": expected_base_visible,
			"visibilityMatchesExpected": base_mesh_visible == expected_base_visible,
			"nonZeroAabb": base_mesh_aabb.size.x > 0.0 and base_mesh_aabb.size.y > 0.0 and base_mesh_aabb.size.z > 0.0,
			"aabbSize": base_aabb_size
		},
		"nodeCounts": node_counts,
		"genericTrimCount": int(node_counts.get("VariantTrim_*", 0)),
		"uiHiddenForUnobstructedArtifactReview": true,
		"failures": failures
	}
	if not failures.is_empty():
		layout_failures.append(contract)
	captures.append({
		"id": capture_id,
		"path": output_path if framebuffer_capture_enabled else "",
		"locale": locale,
		"screen": main.screen,
		"resolution": "%dx%d" % [roundi(actual_size.x), roundi(actual_size.y)],
		"source": "actual paired story-artifact instance rendered through res://scenes/Main.tscn in an unobstructed 3D framebuffer" if framebuffer_capture_enabled else "actual paired story-artifact workpiece node tree under Godot --headless",
		"framebufferCaptured": framebuffer_capture_enabled,
		"status": "PASS" if failures.is_empty() else "FAIL",
		"note": note,
		"density": contract
	})


func capture_stage5_case_npc_portraits_2up(main: Node3D, capture_id: String) -> void:
	var portrait_rows := [
		{"name": "Victor Hale", "path": "res://assets/portraits/victor_hale_neutral.svg", "x": 100.0, "accent": Color("#6bc8bd")},
		{"name": "Lena Falk", "path": "res://assets/portraits/lena_falk_concerned.svg", "x": 680.0, "accent": Color("#db765f")}
	]
	var failures: Array = []
	var layer := CanvasLayer.new()
	layer.name = "Stage5CaseNpcPortraits2Up"
	layer.layer = 120
	main.add_child(layer)
	var background := ColorRect.new()
	background.position = Vector2.ZERO
	background.size = Vector2(VIEWPORT_SIZE)
	background.color = Color("#101820")
	layer.add_child(background)
	var title := Label.new()
	title.position = Vector2(80, 22)
	title.size = Vector2(1120, 70)
	title.text = "STAGE 5 · CASE WITNESSES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f4d685"))
	layer.add_child(title)
	var portrait_contracts: Array = []
	for row_value: Variant in portrait_rows:
		var row: Dictionary = row_value
		var asset_path := String(row.get("path", ""))
		var texture: Texture2D = load(asset_path) if ResourceLoader.exists(asset_path) else null
		if texture == null:
			failures.append("missing_portrait_texture:%s" % asset_path)
		var card := Panel.new()
		card.position = Vector2(float(row.get("x", 0.0)), 104)
		card.size = Vector2(500, 560)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("#1b2632")
		card_style.border_color = row.get("accent", Color.WHITE)
		card_style.set_border_width_all(3)
		card_style.set_corner_radius_all(18)
		card.add_theme_stylebox_override("panel", card_style)
		layer.add_child(card)
		var large_portrait := TextureRect.new()
		large_portrait.name = "Portrait2Up%sLarge" % String(row.get("name", "")).replace(" ", "")
		large_portrait.position = Vector2(float(row.get("x", 0.0)) + 38, 126)
		large_portrait.size = Vector2(330, 412)
		large_portrait.texture = texture
		large_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		large_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		layer.add_child(large_portrait)
		var name_label := Label.new()
		name_label.position = Vector2(float(row.get("x", 0.0)) + 34, 548)
		name_label.size = Vector2(330, 72)
		name_label.text = String(row.get("name", ""))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 27)
		name_label.add_theme_color_override("font_color", row.get("accent", Color.WHITE))
		layer.add_child(name_label)
		var actual_portrait := TextureRect.new()
		actual_portrait.name = "Portrait2Up%sActualSize" % String(row.get("name", "")).replace(" ", "")
		actual_portrait.position = Vector2(float(row.get("x", 0.0)) + 388, 504)
		actual_portrait.size = Vector2(96, 120)
		actual_portrait.texture = texture
		actual_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		actual_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		layer.add_child(actual_portrait)
		var size_label := Label.new()
		size_label.position = Vector2(float(row.get("x", 0.0)) + 386, 626)
		size_label.size = Vector2(100, 25)
		size_label.text = "96 × 120"
		size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		size_label.add_theme_font_size_override("font_size", 13)
		size_label.add_theme_color_override("font_color", Color("#aebdc8"))
		layer.add_child(size_label)
		portrait_contracts.append({
			"name": String(row.get("name", "")),
			"assetPath": asset_path,
			"largeRect": rect_array(Rect2(large_portrait.position, large_portrait.size)),
			"actualInFlowRect": rect_array(Rect2(actual_portrait.position, actual_portrait.size)),
			"renderedBy": "Godot TextureRect"
		})
	var ui_was_visible: bool = bool(main.ui.visible)
	main.ui.visible = false
	await settle_ui(4)
	var viewport := get_root().get_viewport()
	var image := viewport.get_texture().get_image() if framebuffer_capture_enabled else null
	var output_path := "%s/%s.png" % [OUTPUT_DIR, capture_id]
	if framebuffer_capture_enabled:
		if image == null or image.is_empty():
			failures.append("missing_framebuffer")
		else:
			var save_error := image.save_png(output_path)
			if save_error != OK:
				failures.append("png_save:%s" % error_string(save_error))
	main.ui.visible = ui_was_visible
	layer.queue_free()
	await settle_ui(2)
	var contract := {
		"captureId": capture_id,
		"screen": "stage5_case_npc_portraits_2up",
		"passed": failures.is_empty(),
		"viewport": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"portraitCount": portrait_contracts.size(),
		"portraits": portrait_contracts,
		"largeDetailAndActualInFlowSizeShownTogether": true,
		"failures": failures
	}
	if not failures.is_empty():
		layout_failures.append(contract)
	captures.append({
		"id": capture_id,
		"path": output_path if framebuffer_capture_enabled else "",
		"locale": "neutral",
		"screen": "stage5_case_npc_portraits_2up",
		"resolution": "%dx%d" % [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"source": "actual Godot TextureRect rendering of the approved Stage 5 case-NPC SVG assets",
		"framebufferCaptured": framebuffer_capture_enabled,
		"status": "PASS" if failures.is_empty() else "FAIL",
		"note": "Victor and Lena are shown as large 2-up review portraits with matching 96x120 in-flow-size insets.",
		"density": contract
	})


func capture_stage6_case_npc_portraits_3up(main: Node3D, capture_id: String) -> void:
	var portrait_rows := [
		{"name": "Dr. Hana Mire", "role": "CURATOR · CONCERNED", "path": "res://assets/portraits/hana_mire_concerned.svg", "x": 28.0, "accent": "#72c6bd"},
		{"name": "Mara Venn", "role": "AUCTIONEER · CONCERNED", "path": "res://assets/portraits/mara_venn_concerned.svg", "x": 426.0, "accent": "#efb45f"},
		{"name": "Iris Bell", "role": "CONSERVATOR · CONCERNED", "path": "res://assets/portraits/iris_bell_concerned.svg", "x": 824.0, "accent": "#d782ab"}
	]
	var failures: Array = []
	var layer := CanvasLayer.new()
	layer.name = "Stage6CaseNpcPortraits3Up"
	layer.layer = 120
	main.add_child(layer)
	var background := ColorRect.new()
	background.position = Vector2.ZERO
	background.size = Vector2(VIEWPORT_SIZE)
	background.color = Color("#101820")
	layer.add_child(background)
	var title := Label.new()
	title.position = Vector2(70, 16)
	title.size = Vector2(1140, 66)
	title.text = "STAGE 6 · SHADOW MARK WITNESSES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#f4d685"))
	layer.add_child(title)
	var portrait_contracts: Array = []
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE))
	for row_value: Variant in portrait_rows:
		var row: Dictionary = row_value
		var asset_path := String(row.get("path", ""))
		var accent := Color(String(row.get("accent", "#ffffff")))
		var card_x := float(row.get("x", 0.0))
		var texture: Texture2D = load(asset_path) if ResourceLoader.exists(asset_path) else null
		if texture == null:
			failures.append("missing_portrait_texture:%s" % asset_path)
		var card := Panel.new()
		card.position = Vector2(card_x, 92)
		card.size = Vector2(372, 588)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("#1b2632")
		card_style.border_color = accent
		card_style.set_border_width_all(3)
		card_style.set_corner_radius_all(16)
		card.add_theme_stylebox_override("panel", card_style)
		layer.add_child(card)
		var large_portrait := TextureRect.new()
		large_portrait.name = "Portrait3Up%sLarge" % String(row.get("name", "")).replace(" ", "")
		large_portrait.position = Vector2(card_x + 18, 112)
		large_portrait.size = Vector2(248, 310)
		large_portrait.texture = texture
		large_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		large_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		layer.add_child(large_portrait)
		var actual_frame := Panel.new()
		actual_frame.position = Vector2(card_x + 254, 110)
		actual_frame.size = Vector2(108, 132)
		var actual_style := StyleBoxFlat.new()
		actual_style.bg_color = Color("#0b1118")
		actual_style.border_color = Color("#dbe7ee")
		actual_style.set_border_width_all(2)
		actual_style.set_corner_radius_all(8)
		actual_frame.add_theme_stylebox_override("panel", actual_style)
		layer.add_child(actual_frame)
		var actual_portrait := TextureRect.new()
		actual_portrait.name = "Portrait3Up%sActualSize" % String(row.get("name", "")).replace(" ", "")
		actual_portrait.position = Vector2(card_x + 260, 116)
		actual_portrait.size = Vector2(96, 120)
		actual_portrait.texture = texture
		actual_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		actual_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		layer.add_child(actual_portrait)
		var size_label := Label.new()
		size_label.position = Vector2(card_x + 256, 246)
		size_label.size = Vector2(104, 28)
		size_label.text = "96 × 120"
		size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		size_label.add_theme_font_size_override("font_size", 14)
		size_label.add_theme_color_override("font_color", Color("#b9c8d2"))
		layer.add_child(size_label)
		var name_label := Label.new()
		name_label.position = Vector2(card_x + 20, 438)
		name_label.size = Vector2(332, 48)
		name_label.text = String(row.get("name", ""))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 25)
		name_label.add_theme_color_override("font_color", accent)
		layer.add_child(name_label)
		var role_label := Label.new()
		role_label.position = Vector2(card_x + 20, 488)
		role_label.size = Vector2(332, 36)
		role_label.text = String(row.get("role", ""))
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		role_label.add_theme_font_size_override("font_size", 14)
		role_label.add_theme_color_override("font_color", Color("#dbe7ee"))
		layer.add_child(role_label)
		var review_label := Label.new()
		review_label.position = Vector2(card_x + 24, 540)
		review_label.size = Vector2(324, 92)
		review_label.text = "BIG-EYE FACE LEGIBILITY\nLARGE DETAIL + ACTUAL IN-FLOW"
		review_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		review_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		review_label.add_theme_font_size_override("font_size", 15)
		review_label.add_theme_color_override("font_color", Color("#aebdc8"))
		layer.add_child(review_label)
		var large_rect := Rect2(large_portrait.position, large_portrait.size)
		var actual_rect := Rect2(actual_portrait.position, actual_portrait.size)
		if not rect_contains_rect(viewport_rect, large_rect) or not rect_contains_rect(viewport_rect, actual_rect):
			failures.append("portrait_outside_viewport:%s" % String(row.get("name", "")))
		if actual_portrait.size != Vector2(96, 120):
			failures.append("actual_portrait_size:%s" % String(row.get("name", "")))
		portrait_contracts.append({
			"name": String(row.get("name", "")),
			"assetPath": asset_path,
			"largeRect": rect_array(large_rect),
			"actualInFlowRect": rect_array(actual_rect),
			"renderedBy": "Godot TextureRect"
		})
	if portrait_contracts.size() != 3:
		failures.append("portrait_count:%d_expected_3" % portrait_contracts.size())
	var ui_was_visible: bool = bool(main.ui.visible)
	main.ui.visible = false
	await settle_ui(4)
	var viewport := get_root().get_viewport()
	var image := viewport.get_texture().get_image() if framebuffer_capture_enabled else null
	var output_path := "%s/%s.png" % [OUTPUT_DIR, capture_id]
	if framebuffer_capture_enabled:
		if image == null or image.is_empty():
			failures.append("missing_framebuffer")
		else:
			var save_error := image.save_png(output_path)
			if save_error != OK:
				failures.append("png_save:%s" % error_string(save_error))
	main.ui.visible = ui_was_visible
	layer.queue_free()
	await settle_ui(2)
	var contract := {
		"captureId": capture_id,
		"screen": "stage6_case_npc_portraits_3up",
		"passed": failures.is_empty(),
		"viewport": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"portraitCount": portrait_contracts.size(),
		"portraits": portrait_contracts,
		"largeDetailAndActualInFlowSizeShownTogether": true,
		"failures": failures
	}
	if not failures.is_empty():
		layout_failures.append(contract)
	captures.append({
		"id": capture_id,
		"path": output_path if framebuffer_capture_enabled else "",
		"locale": "neutral",
		"screen": "stage6_case_npc_portraits_3up",
		"resolution": "%dx%d" % [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"source": "actual Godot TextureRect rendering of the approved Stage 6 case-NPC SVG assets",
		"framebufferCaptured": framebuffer_capture_enabled,
		"status": "PASS" if failures.is_empty() else "FAIL",
		"note": "Hana, Mara and Iris are shown as large three-up review portraits with matching 96x120 in-flow-size insets.",
		"density": contract
	})


func capture_stage7_case_npc_portraits_2up(main: Node3D, capture_id: String) -> void:
	var portrait_rows := [
		{"name": "Victor Hale", "role": "COLLECTOR · NEUTRAL", "path": "res://assets/portraits/victor_hale_neutral.svg", "x": 100.0, "accent": "#6bc8bd"},
		{"name": "Noah Stern", "role": "ARCHIVIST · CONCERNED", "path": "res://assets/portraits/noah_stern_concerned.svg", "x": 680.0, "accent": "#8ea9e8"}
	]
	var failures: Array = []
	var layer := CanvasLayer.new()
	layer.name = "Stage7CaseNpcPortraits2Up"
	layer.layer = 120
	main.add_child(layer)
	var background := ColorRect.new()
	background.position = Vector2.ZERO
	background.size = Vector2(VIEWPORT_SIZE)
	background.color = Color("#101820")
	layer.add_child(background)
	var title := Label.new()
	title.position = Vector2(80, 20)
	title.size = Vector2(1120, 68)
	title.text = "STAGE 7 · OPTIC & COMPOSITE WITNESSES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#f4d685"))
	layer.add_child(title)
	var portrait_contracts: Array = []
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE))
	for row_value: Variant in portrait_rows:
		var row: Dictionary = row_value
		var asset_path := String(row.get("path", ""))
		var accent := Color(String(row.get("accent", "#ffffff")))
		var card_x := float(row.get("x", 0.0))
		var texture: Texture2D = load(asset_path) if ResourceLoader.exists(asset_path) else null
		if texture == null:
			failures.append("missing_portrait_texture:%s" % asset_path)
		var card := Panel.new()
		card.position = Vector2(card_x, 104)
		card.size = Vector2(500, 560)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color("#1b2632")
		card_style.border_color = accent
		card_style.set_border_width_all(3)
		card_style.set_corner_radius_all(18)
		card.add_theme_stylebox_override("panel", card_style)
		layer.add_child(card)
		var large_portrait := TextureRect.new()
		large_portrait.name = "Stage7Portrait2Up%sLarge" % String(row.get("name", "")).replace(" ", "")
		large_portrait.position = Vector2(card_x + 30, 126)
		large_portrait.size = Vector2(330, 412)
		large_portrait.texture = texture
		large_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		large_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		layer.add_child(large_portrait)
		var actual_frame := Panel.new()
		actual_frame.position = Vector2(card_x + 382, 456)
		actual_frame.size = Vector2(108, 132)
		var actual_style := StyleBoxFlat.new()
		actual_style.bg_color = Color("#0b1118")
		actual_style.border_color = Color("#dbe7ee")
		actual_style.set_border_width_all(2)
		actual_style.set_corner_radius_all(8)
		actual_frame.add_theme_stylebox_override("panel", actual_style)
		layer.add_child(actual_frame)
		var actual_portrait := TextureRect.new()
		actual_portrait.name = "Stage7Portrait2Up%sActualSize" % String(row.get("name", "")).replace(" ", "")
		actual_portrait.position = Vector2(card_x + 388, 462)
		actual_portrait.size = Vector2(96, 120)
		actual_portrait.texture = texture
		actual_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		actual_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		layer.add_child(actual_portrait)
		var size_label := Label.new()
		size_label.position = Vector2(card_x + 384, 590)
		size_label.size = Vector2(104, 26)
		size_label.text = "96 × 120"
		size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		size_label.add_theme_font_size_override("font_size", 13)
		size_label.add_theme_color_override("font_color", Color("#b9c8d2"))
		layer.add_child(size_label)
		var name_label := Label.new()
		name_label.position = Vector2(card_x + 30, 540)
		name_label.size = Vector2(330, 42)
		name_label.text = String(row.get("name", ""))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 26)
		name_label.add_theme_color_override("font_color", accent)
		layer.add_child(name_label)
		var role_label := Label.new()
		role_label.position = Vector2(card_x + 30, 584)
		role_label.size = Vector2(330, 32)
		role_label.text = String(row.get("role", ""))
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		role_label.add_theme_font_size_override("font_size", 14)
		role_label.add_theme_color_override("font_color", Color("#dbe7ee"))
		layer.add_child(role_label)
		var review_label := Label.new()
		review_label.position = Vector2(card_x + 30, 620)
		review_label.size = Vector2(330, 28)
		review_label.text = "BIG-EYE FACE · ACTUAL IN-FLOW INSET"
		review_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		review_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		review_label.add_theme_font_size_override("font_size", 13)
		review_label.add_theme_color_override("font_color", Color("#aebdc8"))
		layer.add_child(review_label)
		var large_rect := Rect2(large_portrait.position, large_portrait.size)
		var actual_rect := Rect2(actual_portrait.position, actual_portrait.size)
		if not rect_contains_rect(viewport_rect, large_rect) or not rect_contains_rect(viewport_rect, actual_rect):
			failures.append("portrait_outside_viewport:%s" % String(row.get("name", "")))
		if actual_portrait.size != Vector2(96, 120):
			failures.append("actual_portrait_size:%s" % String(row.get("name", "")))
		portrait_contracts.append({
			"name": String(row.get("name", "")),
			"expression": String(row.get("role", "")).get_slice(" · ", 1).to_lower(),
			"assetPath": asset_path,
			"largeRect": rect_array(large_rect),
			"actualInFlowRect": rect_array(actual_rect),
			"renderedBy": "Godot TextureRect"
		})
	if portrait_contracts.size() != 2:
		failures.append("portrait_count:%d_expected_2" % portrait_contracts.size())
	var ui_was_visible: bool = bool(main.ui.visible)
	main.ui.visible = false
	await settle_ui(4)
	var viewport := get_root().get_viewport()
	var image := viewport.get_texture().get_image() if framebuffer_capture_enabled else null
	var output_path := "%s/%s.png" % [OUTPUT_DIR, capture_id]
	if framebuffer_capture_enabled:
		if image == null or image.is_empty():
			failures.append("missing_framebuffer")
		else:
			var save_error := image.save_png(output_path)
			if save_error != OK:
				failures.append("png_save:%s" % error_string(save_error))
	main.ui.visible = ui_was_visible
	layer.queue_free()
	await settle_ui(2)
	var contract := {
		"captureId": capture_id,
		"screen": "stage7_case_npc_portraits_2up",
		"passed": failures.is_empty(),
		"viewport": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"portraitCount": portrait_contracts.size(),
		"portraits": portrait_contracts,
		"largeDetailAndActualInFlowSizeShownTogether": true,
		"failures": failures
	}
	if not failures.is_empty():
		layout_failures.append(contract)
	captures.append({
		"id": capture_id,
		"path": output_path if framebuffer_capture_enabled else "",
		"locale": "neutral",
		"screen": "stage7_case_npc_portraits_2up",
		"resolution": "%dx%d" % [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"source": "actual Godot TextureRect rendering of the approved Stage 7 case-NPC SVG assets",
		"framebufferCaptured": framebuffer_capture_enabled,
		"status": "PASS" if failures.is_empty() else "FAIL",
		"note": "Victor neutral and Noah concerned are shown as large two-up review portraits with matching 96x120 in-flow-size insets.",
		"density": contract
	})


func configure_clean_fixture(gs: Node, main: Node3D, locale: String, tutorial_complete: bool = true) -> void:
	gs.persistence_enabled = false
	gs.campaign_test_mode = true
	gs.language = locale
	gs.player_profile = gs.default_player_profile()
	if tutorial_complete:
		gs.player_profile.tutorialCompletedSteps = TUTORIAL_STEPS.duplicate()
	gs.reset_game()
	main.language = locale
	main.selected = {}
	main.listing_artifact_id = ""
	main.listing_step = "PRICE"
	main.listing_price_preset = ""
	main.listing_disclosure = ""
	main.market_character_state = "WELCOME"
	main.market_character_dialogue = ""
	main.market_character_fact = ""
	main.last_event_result = {}
	main.event_cue_state = "REQUEST"


func first_open_evidence_id(gs: Node) -> String:
	for evidence_value: Variant in gs.case_definition(CASE_ID).get("evidence", []):
		var evidence: Dictionary = evidence_value
		var unlock: Dictionary = evidence.get("unlock", {})
		if unlock.get("requires_all", []).is_empty() and unlock.get("requires_tools", []).is_empty():
			return String(evidence.get("id", ""))
	return ""


func show_stage_select_fixture(gs: Node, main: Node3D, locale: String) -> void:
	configure_clean_fixture(gs, main, locale)
	gs.player_profile.highestUnlockedStage = 5
	gs.player_profile.clearedStages = [1, 2, 3, 4]
	gs.player_profile.stageBest = {"1": 57.0, "2": 59.0, "3": 61.0, "4": 62.0}
	main.show_stage_select()


func show_tutorial_investigation_fixture(gs: Node, main: Node3D, locale: String) -> void:
	configure_clean_fixture(gs, main, locale, false)
	gs.new_game(1)
	var artifact: Dictionary = gs.begin_case(CASE_ID)
	main.selected = artifact
	main.load_artifact(artifact)
	main.case_detail_evidence_id = first_open_evidence_id(gs)
	main.show_case_dossier(CASE_ID)


func listing_artifact(gs: Node) -> Dictionary:
	var artifact: Dictionary = gs.new_artifact("artifact_001", 915151, "latest_runtime_listing")
	artifact.playerHypothesis = gs.truth_to_hypothesis(artifact.authenticityTruth)
	artifact.confidence = 0.92
	artifact.cleanliness = 100.0
	artifact.surfaceCondition = 100.0
	artifact.mechanicalCondition = 100.0
	artifact.knownClues = []
	return artifact


func show_listing_price_fixture(gs: Node, main: Node3D, locale: String) -> Dictionary:
	configure_clean_fixture(gs, main, locale)
	var artifact := listing_artifact(gs)
	main.selected = artifact
	main.load_artifact(artifact)
	main.show_appraisal()
	return artifact


func show_listing_disclosure_fixture(gs: Node, main: Node3D, locale: String) -> Dictionary:
	var artifact := show_listing_price_fixture(gs, main, locale)
	main.select_listing_price_preset("BALANCED")
	main.select_listing_disclosure("LIKELY")
	return artifact


func listing_causal_summary_evidence(gs: Node, main: Node3D, artifact: Dictionary) -> Dictionary:
	var public_tags: Array = gs.listing_public_status_tags(artifact, String(main.listing_disclosure))
	var expected_codes: Array = []
	var expected_labels: Array = []
	var rendered_labels: Array = []
	var sibling_indices: Array = []
	var same_parent := true
	var ordered := true
	var parent_path := ""
	for chip_index in range(3):
		var tag: Dictionary = public_tags[chip_index] if chip_index < public_tags.size() and public_tags[chip_index] is Dictionary else {}
		var code := String(tag.get("code", ""))
		var expected_label := String(main.auction_reason_label(code))
		expected_codes.append(code)
		expected_labels.append(expected_label)
		var chip := find_visible_control(main, "ListingCausalChip_%d" % chip_index)
		var label: Node = chip.find_child("ListingCausalLabel", true, false) if chip != null else null
		rendered_labels.append((label as Label).text if label is Label else "")
		sibling_indices.append(chip.get_index() if chip != null else -1)
		var current_parent_path := String(main.get_path_to(chip.get_parent())) if chip != null and chip.get_parent() != null else ""
		if chip_index == 0:
			parent_path = current_parent_path
		elif current_parent_path != parent_path:
			same_parent = false
		if chip_index > 0:
			var previous := find_visible_control(main, "ListingCausalChip_%d" % (chip_index - 1))
			if previous == null or chip == null or previous.get_parent() != chip.get_parent() or chip.get_index() <= previous.get_index():
				ordered = false
	var category_order: Array = []
	for tag_index in range(mini(3, public_tags.size())):
		var tag_value: Variant = public_tags[tag_index]
		category_order.append(String((tag_value as Dictionary).get("category", "")) if tag_value is Dictionary else "")
	var valid := public_tags.size() == 3 \
		and expected_codes.size() == 3 \
		and not expected_codes.has("") \
		and rendered_labels == expected_labels \
		and category_order == ["CONDITION", "PROVENANCE", "DISCLOSURE"] \
		and same_parent \
		and ordered
	var semantic_payload := {
		"categoryOrder": category_order,
		"codes": expected_codes,
		"labels": rendered_labels,
		"siblingIndices": sibling_indices,
		"sameParent": same_parent,
		"ordered": ordered
	}
	return {
		"valid": valid,
		"categoryOrder": category_order,
		"codes": expected_codes,
		"expectedLabels": expected_labels,
		"renderedLabels": rendered_labels,
		"siblingIndices": sibling_indices,
		"sameParent": same_parent,
		"ordered": ordered,
		"semanticHash": JSON.stringify(semantic_payload).sha256_text()
	}


func public_auction_cue_summary(main: Node3D, cue: Dictionary) -> Dictionary:
	var phase_label := find_visible_control(main, "AuctionCuePhase")
	var progress_label := find_visible_control(main, "AuctionCueProgress")
	var primary_state := find_visible_control(main, "AuctionPrimaryState")
	var primary_text := find_visible_control(main, "AuctionPrimaryText")
	var primary_action := find_visible_control(main, "AuctionPrimaryAction")
	var terminal := bool(cue.get("isFinal", false))
	var cta_name := "HammerButton" if terminal else "AuctionCueNext"
	var primary_cta := find_visible_control(main, cta_name)
	var state_rect := primary_state.get_global_rect() if primary_state != null else Rect2()
	var action_rect := primary_action.get_global_rect() if primary_action != null else Rect2()
	var cta_rect := primary_cta.get_global_rect() if primary_cta != null else Rect2()
	var action_gap := action_rect.position.y - state_rect.end.y if primary_state != null and primary_action != null else -999.0
	var horizontal_overlap := minf(state_rect.end.x, action_rect.end.x) - maxf(state_rect.position.x, action_rect.position.x)
	var primary_tree_adjacent := primary_state != null \
		and primary_action != null \
		and primary_state.get_parent() == primary_action.get_parent() \
		and primary_action.get_index() == primary_state.get_index() + 1
	var primary_cta_in_action_tree := primary_action != null \
		and primary_cta != null \
		and primary_action.is_ancestor_of(primary_cta)
	# Container sorting is deferred. The cue chain is sampled immediately after
	# each public transition, so tree adjacency is the deterministic intermediate
	# contract; settled terminal captures below enforce the actual pixel gap.
	var geometry_ready := state_rect.size.x > 0.0 \
		and state_rect.size.y > 0.0 \
		and action_rect.size.x > 0.0 \
		and action_rect.size.y > 0.0 \
		and cta_rect.size.x > 0.0 \
		and cta_rect.size.y > 0.0
	var primary_action_near_geometry := geometry_ready \
		and action_gap >= 0.0 \
		and action_gap <= 16.0 \
		and horizontal_overlap > 0.0
	var primary_cta_inside_geometry := geometry_ready and rect_contains_rect(action_rect, cta_rect)
	var expected_primary: Dictionary = main.auction_primary_public_state(cue) if main.has_method("auction_primary_public_state") else {}
	return {
		"phase": String(cue.get("phase", "")),
		"index": int(cue.get("index", -1)),
		"total": int(cue.get("total", 0)),
		"isFinal": bool(cue.get("isFinal", false)),
		"visibleBidCount": cue.get("visibleBids", []).size(),
		"renderedPhase": (phase_label as Label).text if phase_label is Label else "",
		"renderedProgress": (progress_label as Label).text if progress_label is Label else "",
		"nextVisible": find_visible_control(main, "AuctionCueNext") != null,
		"resultVisible": find_visible_control(main, "AuctionResultFact") != null,
		"hammerVisible": find_visible_control(main, "HammerButton") != null,
		"portraitCount": count_visible(main, "CharacterPortrait", "TextureRect"),
		"primaryStateVisible": primary_state != null,
		"primaryTextVisible": primary_text != null,
		"primaryActionVisible": primary_action != null,
		"renderedPrimaryText": (primary_text as Label).text if primary_text is Label else "",
		"expectedPrimaryText": String(expected_primary.get("text", "")),
		"primaryStateRect": rect_array(state_rect),
		"primaryActionRect": rect_array(action_rect),
		"primaryCtaName": cta_name,
		"primaryCtaRect": rect_array(cta_rect),
		"primaryActionGap": action_gap,
		"primaryTreeAdjacent": primary_tree_adjacent,
		"primaryCtaInActionTree": primary_cta_in_action_tree,
		"geometryReady": geometry_ready,
		"primaryActionNearGeometry": primary_action_near_geometry,
		"primaryCtaInsideGeometry": primary_cta_inside_geometry,
		"reasonChipCount": count_visible(main, "AuctionReasonChip_*", "PanelContainer")
	}


func auction_cue_chain_failures(states: Array, result: Dictionary) -> Array:
	var failures: Array = []
	if states.is_empty():
		return ["auction_cue_chain_empty"]
	var phases: Array = states.map(func(state: Dictionary): return String(state.get("phase", "")))
	if phases[0] != "ENTRY":
		failures.append("auction_cue_first:%s" % phases[0])
	if phases.size() < 2 or phases[1] != "CALL":
		failures.append("auction_cue_second:%s" % (phases[1] if phases.size() > 1 else "MISSING"))
	var expected_final := "SOLD" if bool(result.get("reserve_met", false)) else "NO_SALE"
	if phases[-1] != expected_final:
		failures.append("auction_cue_final:%s_expected_%s" % [phases[-1], expected_final])
	var bid_count := phases.count("BID")
	if not result.get("bids", []).is_empty() and (bid_count < 1 or bid_count > 3):
		failures.append("auction_cue_bid_count:%d" % bid_count)
	var seen_dropout := false
	for state_index in range(states.size()):
		var state: Dictionary = states[state_index]
		if int(state.get("index", -1)) != state_index or int(state.get("total", 0)) != states.size():
			failures.append("auction_cue_progress:%d" % state_index)
		if String(state.get("renderedPhase", "")).is_empty() or String(state.get("renderedProgress", "")) != "%d / %d" % [state_index + 1, states.size()]:
			failures.append("auction_cue_rendered_copy:%d" % state_index)
		var final_state := state_index == states.size() - 1
		if bool(state.get("nextVisible", false)) == final_state or bool(state.get("resultVisible", false)) != final_state or bool(state.get("hammerVisible", false)) != final_state:
			failures.append("auction_cue_actions:%d" % state_index)
		if not bool(state.get("primaryStateVisible", false)) \
			or not bool(state.get("primaryTextVisible", false)) \
			or not bool(state.get("primaryActionVisible", false)):
			failures.append("auction_primary_contract_missing:%d" % state_index)
		if String(state.get("renderedPrimaryText", "")).is_empty() or String(state.get("renderedPrimaryText", "")) != String(state.get("expectedPrimaryText", "")):
			failures.append("auction_primary_copy:%d" % state_index)
		if not bool(state.get("primaryTreeAdjacent", false)) or not bool(state.get("primaryCtaInActionTree", false)):
			failures.append("auction_primary_cta_proximity:%d" % state_index)
		if bool(state.get("geometryReady", false)) and (not bool(state.get("primaryActionNearGeometry", false)) or not bool(state.get("primaryCtaInsideGeometry", false))):
			failures.append("auction_primary_cta_geometry:%d" % state_index)
		var reason_chip_count := int(state.get("reasonChipCount", -1))
		if final_state and reason_chip_count != 1:
			failures.append("auction_terminal_reason_count:%d=%d_expected_1" % [state_index, reason_chip_count])
		elif not final_state and (reason_chip_count < 0 or reason_chip_count > 2):
			failures.append("auction_intermediate_reason_count:%d=%d_expected_0..2" % [state_index, reason_chip_count])
		if int(state.get("portraitCount", 0)) != 2:
			failures.append("auction_cue_portraits:%d" % state_index)
		if String(state.get("phase", "")) == "DROPOUT":
			seen_dropout = true
		if seen_dropout and String(state.get("phase", "")) == "BID":
			failures.append("auction_cue_bid_after_dropout")
		if bool(state.get("isFinal", false)) != (state_index == states.size() - 1):
			failures.append("auction_cue_final_flag:%d" % state_index)
	return failures


func stage_pressure_evidence(gs: Node, main: Node3D) -> Dictionary:
	var run_state: Dictionary = gs.stage_run_state
	var snapshot: Dictionary = {}
	var snapshot_value: Variant = run_state.get("stageReplayTelemetrySnapshot", {})
	if snapshot_value is Dictionary:
		snapshot = (snapshot_value as Dictionary).duplicate(true)
	var telemetry_available := bool(run_state.get("telemetryAvailable", false))
	var cleared := String(run_state.get("status", "")) == "CLEARED"
	var should_render := not snapshot.is_empty() and bool(snapshot.get("available", false))
	var pressure_row := find_visible_control(main, "StagePressureSummary")
	var pressure_icon := find_visible_control(main, "StagePressureIcon")
	var pressure_text := find_visible_control(main, "StagePressureText")
	var replay_axes := find_visible_control(main, "StageReplayAxes")
	var advice := find_visible_control(main, "StageClearAdvice")
	var rendered_text := (pressure_text as Label).text if pressure_text is Label else ""
	var expected_text := String(main.stage_pressure_summary(snapshot)) if main.has_method("stage_pressure_summary") and should_render else ""
	var row_ordered := pressure_row != null \
		and replay_axes != null \
		and advice != null \
		and pressure_row.get_parent() == replay_axes.get_parent() \
		and pressure_row.get_parent() == advice.get_parent() \
		and replay_axes.get_index() < pressure_row.get_index() \
		and pressure_row.get_index() < advice.get_index()
	var contents_ordered := pressure_icon != null \
		and pressure_text != null \
		and pressure_icon.get_parent() == pressure_row \
		and pressure_text.get_parent() == pressure_row \
		and pressure_icon.get_index() < pressure_text.get_index()
	var visible_contract := pressure_row != null and pressure_icon != null and pressure_text != null
	var any_visible := pressure_row != null or pressure_icon != null or pressure_text != null
	var valid := true
	if cleared and telemetry_available and not should_render:
		valid = false
	if should_render:
		valid = valid \
			and visible_contract \
			and not expected_text.is_empty() \
			and rendered_text == expected_text \
			and row_ordered \
			and contents_ordered
	elif any_visible:
		valid = false
	var semantic_payload := {
		"stage": int(run_state.get("stageId", 0)),
		"cleared": cleared,
		"telemetryAvailable": telemetry_available,
		"shouldRender": should_render,
		"expectedText": expected_text,
		"renderedText": rendered_text,
		"rowOrdered": row_ordered,
		"contentsOrdered": contents_ordered
	}
	var evidence := semantic_payload.duplicate(true)
	evidence["valid"] = valid
	evidence["snapshot"] = snapshot
	evidence["semanticHash"] = JSON.stringify(semantic_payload).sha256_text()
	return evidence


func with_stage_pressure_contract(specification: Dictionary, evidence: Dictionary, cta_name: String) -> Dictionary:
	var enriched := specification.duplicate(true)
	var public_evidence: Dictionary = {}
	var public_evidence_value: Variant = enriched.get("publicActionEvidence", {})
	if public_evidence_value is Dictionary:
		public_evidence = (public_evidence_value as Dictionary).duplicate(true)
	public_evidence["stagePressure"] = evidence.duplicate(true)
	enriched["publicActionEvidence"] = public_evidence
	if not bool(evidence.get("shouldRender", false)):
		return enriched
	var required: Array = enriched.get("required", [])
	required.append_array(["StagePressureSummary", "StagePressureIcon", "StagePressureText"])
	enriched["required"] = required
	var counts: Array = enriched.get("counts", [])
	counts.append_array([
		{"pattern": "StagePressureSummary", "type": "HBoxContainer", "exact": 1},
		{"pattern": "StagePressureIcon", "type": "TextureRect", "exact": 1},
		{"pattern": "StagePressureText", "type": "Label", "exact": 1}
	])
	enriched["counts"] = counts
	var minimum_widths: Dictionary = enriched.get("minimumWidths", {})
	minimum_widths["StagePressureIcon"] = 24.0
	enriched["minimumWidths"] = minimum_widths
	var minimum_heights: Dictionary = enriched.get("minimumHeights", {})
	minimum_heights["StagePressureSummary"] = 24.0
	minimum_heights["StagePressureIcon"] = 24.0
	enriched["minimumHeights"] = minimum_heights
	var vertical_gaps: Array = enriched.get("verticalGaps", [])
	vertical_gaps.append_array([
		{"above": "StageReplayAxes", "below": "StagePressureSummary", "minimum": 0.0, "maximum": 12.0},
		{"above": "StagePressureSummary", "below": "StageClearAdvice", "minimum": 0.0, "maximum": 12.0}
	])
	enriched["verticalGaps"] = vertical_gaps
	var no_overlap_pairs: Array = enriched.get("noOverlapPairs", [])
	no_overlap_pairs.append_array([
		["StageReplayAxes", "StagePressureSummary"],
		["StagePressureIcon", "StagePressureText"],
		["StagePressureSummary", "StageClearAdvice"],
		["StagePressureSummary", cta_name]
	])
	enriched["noOverlapPairs"] = no_overlap_pairs
	var text_fit_patterns: Array = enriched.get("singleLineTextFitPatterns", [])
	text_fit_patterns.append("StagePressureText")
	enriched["singleLineTextFitPatterns"] = text_fit_patterns
	var texture_requirements: Array = enriched.get("textureRequirements", [])
	texture_requirements.append("StagePressureIcon")
	enriched["textureRequirements"] = texture_requirements
	var required_copy: Array = enriched.get("requiredCopy", [])
	required_copy.append(String(evidence.get("expectedText", "")))
	enriched["requiredCopy"] = required_copy
	return enriched


func show_sold_auction_fixture(gs: Node, main: Node3D, locale: String) -> Dictionary:
	configure_clean_fixture(gs, main, locale)
	var artifact := listing_artifact(gs)
	artifact.knownClues = ["PROVENANCE"]
	gs.inventory.append(artifact)
	gs.list_auction(artifact, 1, 5, float(artifact.confidence), "CERTAIN")
	main.selected = artifact
	main.load_artifact(artifact)
	main.show_auction()
	var states: Array = []
	for _step in range(12):
		var cue: Dictionary = main.auction_public_cue_state()
		if cue.is_empty():
			break
		states.append(public_auction_cue_summary(main, cue))
		if bool(cue.get("isFinal", false)):
			break
		main.advance_auction_cue()
	var chain_failures := auction_cue_chain_failures(states, main.last_auction_result)
	return {
		"artifactId": String(artifact.get("uniqueId", "")),
		"states": states,
		"final": states[-1] if not states.is_empty() else {},
		"valid": chain_failures.is_empty(),
		"failures": chain_failures
	}


func discover_all_public_evidence(gs: Node, case_id: String) -> Array:
	var discovered: Array = []
	for _pass in range(12):
		var progressed := false
		var public_state: Dictionary = gs.get_case_public_state(case_id)
		for evidence_value: Variant in public_state.get("availableEvidence", []):
			var evidence: Dictionary = evidence_value
			var required_tools: Array = evidence.get("requiredTools", [])
			if not required_tools.is_empty():
				gs.select_tool(String(required_tools[0]))
			var result: Dictionary = gs.discover_case_evidence(case_id, String(evidence.get("id", "")))
			if bool(result.get("ok", false)) and String(result.get("code", "")) == "DISCOVERED":
				discovered.append(String(evidence.get("id", "")))
				progressed = true
		if not progressed:
			break
	return discovered


func strongest_public_report(gs: Node, case_id: String) -> Dictionary:
	var public_state: Dictionary = gs.get_case_public_state(case_id)
	var best_hypothesis := ""
	var best_score := -999999
	var best_citations: Array = []
	for hypothesis_value: Variant in public_state.get("hypotheses", []):
		var hypothesis: Dictionary = hypothesis_value
		var hypothesis_id := String(hypothesis.get("id", ""))
		var score := 0
		var citations: Array = []
		var independent := {}
		for evidence_value: Variant in public_state.get("discoveredEvidence", []):
			var evidence: Dictionary = evidence_value
			for relation_value: Variant in evidence.get("relations", []):
				var relation: Dictionary = relation_value
				if String(relation.get("hypothesis_id", "")) != hypothesis_id:
					continue
				var signed_strength := int(relation.get("strength", 0)) * (1 if String(relation.get("stance", "")) == "SUPPORT" else -1)
				score += signed_strength
				var independence_key := String(evidence.get("sourceId", evidence.get("id", "")))
				if signed_strength > 0 and not independent.has(independence_key):
					citations.append(String(evidence.get("id", "")))
					independent[independence_key] = true
		if score > best_score:
			best_score = score
			best_hypothesis = hypothesis_id
			best_citations = citations
	return {"hypothesisId": best_hypothesis, "citationIds": best_citations, "score": best_score}


func show_stage_clear_fixture(gs: Node, main: Node3D, locale: String) -> Dictionary:
	# Build the capture from the same public actions used by play: start Stage 1,
	# discover/cite/report, choose the recommended repair tool, list with a claim
	# calibrated to public support, record the deterministic auction, then finish
	# the two remaining scoped cases through the public integration helper.
	configure_clean_fixture(gs, main, locale, false)
	var started: Dictionary = gs.new_game(1)
	var artifact: Dictionary = gs.begin_case(CASE_ID)
	var discovered := discover_all_public_evidence(gs, CASE_ID)
	var report := strongest_public_report(gs, CASE_ID)
	for citation_id_value: Variant in report.get("citationIds", []):
		gs.toggle_case_citation(CASE_ID, String(citation_id_value))
	gs.set_case_hypothesis(CASE_ID, String(report.get("hypothesisId", "")))
	var resolution: Dictionary = gs.resolve_case_v2(CASE_ID, String(report.get("hypothesisId", "")), report.get("citationIds", []))
	var required_tools: Array = gs.repair_requirements(artifact).get("requiredTools", [])
	var repair_result := ""
	if not required_tools.is_empty() and gs.select_tool(String(required_tools[0])):
		repair_result = String(gs.repair(artifact))
	gs.authenticate(artifact)
	var support: Dictionary = gs.listing_public_support(artifact)
	var disclosure := String({"LOW": "UNCERTAIN", "MEDIUM": "LIKELY", "HIGH": "CERTAIN"}.get(String(support.get("band", "LOW")), "UNCERTAIN"))
	var appraisal := int(gs.appraise(artifact))
	var listed := bool(gs.list_auction(artifact, maxi(1, int(appraisal * 0.50)), maxi(1, int(appraisal * 0.60)), float(artifact.get("confidence", 0.0)), disclosure))
	var first_sale: Dictionary = gs.sell(artifact) if listed else {}
	var remaining_cases: Array = []
	for case_id_value: Variant in gs.get_current_stage_case_ids():
		var case_id := String(case_id_value)
		if case_id != CASE_ID:
			remaining_cases.append({"caseId": case_id, "completed": bool(gs.prepare_case_for_test(case_id))})
	main.show_campaign()
	var feedback: Dictionary = gs.stage_replay_feedback() if gs.has_method("stage_replay_feedback") else {}
	return {
		"ready": bool(started.get("ok", false)) and not artifact.is_empty() and discovered.size() >= 3 and bool(resolution.get("ok", false)) and not repair_result.is_empty() and listed and not first_sale.is_empty() and remaining_cases.all(func(row: Dictionary): return bool(row.completed)) and String(gs.stage_run_state.get("status", "")) == "CLEARED",
		"discovered": discovered.size(),
		"report": report,
		"resolution": resolution,
		"repair": repair_result,
		"listingSupport": support,
		"disclosure": disclosure,
		"firstSale": first_sale,
		"remainingCases": remaining_cases,
		"feedback": feedback
	}


func show_report_ready_fixture(gs: Node, main: Node3D, locale: String) -> Dictionary:
	configure_clean_fixture(gs, main, locale, false)
	gs.new_game(1)
	var artifact: Dictionary = gs.begin_case(CASE_ID)
	var evidence_id := first_open_evidence_id(gs)
	var discovery: Dictionary = gs.discover_case_evidence(CASE_ID, evidence_id)
	var cited := bool(gs.toggle_case_citation(CASE_ID, evidence_id))
	var definition: Dictionary = gs.case_definition(CASE_ID)
	var hypothesis_id := String(definition.get("canonical_hypothesis_id", ""))
	var selected_hypothesis := bool(gs.set_case_hypothesis(CASE_ID, hypothesis_id))
	main.selected = artifact
	main.load_artifact(artifact)
	main.case_detail_evidence_id = evidence_id
	main.show_case_dossier(CASE_ID)
	return {
		"artifact": artifact,
		"evidenceId": evidence_id,
		"hypothesisId": hypothesis_id,
		"ready": bool(discovery.get("ok", false)) and cited and selected_hypothesis
	}


func append_private_token(tokens: Array, value: Variant) -> void:
	var token := String(value).strip_edges()
	if token.length() >= 4 and not tokens.has(token):
		tokens.append(token)


func authored_case_private_tokens(gs: Node, case_id: String, artifact: Dictionary) -> Array:
	var definition: Dictionary = gs.case_definition(case_id)
	var tokens: Array = [
		"public_clue_id", "authoring_truth_hypothesis_id", "canonical_hypothesis_id",
		"artifact_spec_id", "source_ref", "runtime_ref_id", "AUTHORED_V2",
		"PROVENANCE", "required_source_refs"
	]
	append_private_token(tokens, case_id)
	append_private_token(tokens, definition.get("artifact_spec_id", ""))
	append_private_token(tokens, definition.get("canonical_hypothesis_id", ""))
	append_private_token(tokens, artifact.get("uniqueId", ""))
	for hypothesis_value: Variant in definition.get("hypotheses", []):
		var hypothesis: Dictionary = hypothesis_value
		append_private_token(tokens, hypothesis.get("id", ""))
	for evidence_value: Variant in definition.get("evidence", []):
		var evidence: Dictionary = evidence_value
		var source: Dictionary = evidence.get("source", {})
		var citation: Dictionary = evidence.get("citation", {})
		append_private_token(tokens, evidence.get("id", ""))
		append_private_token(tokens, source.get("ref_id", ""))
		append_private_token(tokens, source.get("entry_id", ""))
		append_private_token(tokens, citation.get("id", ""))
	return tokens


func append_locale_leak_token(tokens: Array, value: Variant, locale: String) -> void:
	if not value is Dictionary:
		return
	var opposite_locale := "en" if locale == "ko" else "ko"
	var opposite_copy := String((value as Dictionary).get(opposite_locale, "")).replace("\n", " ").strip_edges()
	append_private_token(tokens, opposite_copy)
	if opposite_copy.length() > 28:
		append_private_token(tokens, opposite_copy.left(28).strip_edges())


func authored_case_forbidden_tokens(gs: Node, case_id: String, artifact: Dictionary, locale: String) -> Array:
	var definition: Dictionary = gs.case_definition(case_id)
	var tokens := authored_case_private_tokens(gs, case_id, artifact)
	for value: Variant in [
		definition.get("title", {}), definition.get("briefing", {}),
		definition.get("central_question", {}), definition.get("resolution", {}).get("report_prompt", {})
	]:
		append_locale_leak_token(tokens, value, locale)
	for hypothesis_value: Variant in definition.get("hypotheses", []):
		var hypothesis: Dictionary = hypothesis_value
		append_locale_leak_token(tokens, hypothesis.get("label", {}), locale)
	for evidence_value: Variant in definition.get("evidence", []):
		var evidence: Dictionary = evidence_value
		append_locale_leak_token(tokens, evidence.get("citation", {}).get("label", {}), locale)
	for generic_template: String in [
		"Inspect, conserve, authenticate, and disclose the fictional evidence",
		"A disputed workshop record connected to"
	]:
		append_private_token(tokens, generic_template)
	if locale == "ko":
		for english_ui_template: String in [
			"CASE DOSSIER", "BRIEF", "QUESTION", "GOAL", "CLUE CARDS",
			"SELECTED CLUE", "CHOOSE A HYPOTHESIS", "REPORT SUMMARY",
			"SUBMIT EVIDENCE-BACKED REPORT"
		]:
			append_private_token(tokens, english_ui_template)
	else:
		for korean_ui_template: String in [
			"사건 서류", "상황", "핵심 질문", "목표", "단서 카드",
			"선택한 단서", "가설 선택", "보고서 요약", "증거 기반 보고서 제출"
		]:
			append_private_token(tokens, korean_ui_template)
	return tokens


func show_authored_report_ready_fixture(gs: Node, main: Node3D, locale: String, stage_id: int, case_id: String, minimum_capture_citations: int = 4, required_citations_only: bool = false, include_npc_citation: bool = false) -> Dictionary:
	configure_clean_fixture(gs, main, locale, false)
	gs.player_profile.highestUnlockedStage = stage_id
	var started: Dictionary = gs.new_game(stage_id)
	var artifact: Dictionary = gs.begin_case(case_id)
	var definition: Dictionary = gs.case_definition(case_id)
	var discovered := discover_all_public_evidence(gs, case_id)
	var report := strongest_public_report(gs, case_id)
	var citation_ids: Array = report.get("citationIds", [])
	if required_citations_only:
		var required_ids: Array = definition.get("resolution", {}).get("required_source_refs", [])
		var required_capture_ids: Array = []
		for required_id_value: Variant in required_ids:
			var required_id := String(required_id_value)
			if citation_ids.has(required_id) and not required_capture_ids.has(required_id):
				required_capture_ids.append(required_id)
		if include_npc_citation:
			for evidence_value: Variant in definition.get("evidence", []):
				if evidence_value is Dictionary and evidence_value.get("source", {}).get("kind", "") == "NPC":
					var npc_source_id := String(evidence_value.get("id", ""))
					if citation_ids.has(npc_source_id) and not required_capture_ids.has(npc_source_id):
						required_capture_ids.append(npc_source_id)
					break
		citation_ids = required_capture_ids
	var cited_count := 0
	for citation_id_value: Variant in citation_ids:
		if bool(gs.toggle_case_citation(case_id, String(citation_id_value))):
			cited_count += 1
	var hypothesis_id := String(report.get("hypothesisId", ""))
	var selected_hypothesis := bool(gs.set_case_hypothesis(case_id, hypothesis_id))
	var preview: Dictionary = gs.evaluate_case_submission(case_id, hypothesis_id, citation_ids)
	var npc_evidence_id := ""
	for evidence_value: Variant in definition.get("evidence", []):
		var evidence: Dictionary = evidence_value
		if String(evidence.get("source", {}).get("kind", "")) == "NPC":
			npc_evidence_id = String(evidence.get("id", ""))
			break
	main.selected = artifact
	main.load_artifact(artifact)
	main.case_detail_evidence_id = npc_evidence_id if not npc_evidence_id.is_empty() else (String(citation_ids[0]) if not citation_ids.is_empty() else "")
	main.show_case_dossier(case_id)
	var evidence_count: int = int(definition.get("evidence", []).size())
	var citation_count: int = citation_ids.size()
	var ready: bool = bool(started.get("ok", false)) \
		and not artifact.is_empty() \
		and int(definition.get("schema_version", 0)) == 2 \
		and discovered.size() == evidence_count \
		and cited_count == citation_count \
		and citation_count >= minimum_capture_citations \
		and selected_hypothesis \
		and bool(preview.get("ok", false)) \
		and String(preview.get("substantiation", "")) == "STRONG" \
		and bool(preview.get("requiredSourcesMet", false))
	return {
		"ready": ready,
		"stageId": stage_id,
		"artifact": artifact,
		"hypothesisId": hypothesis_id,
		"citationIds": citation_ids.duplicate(),
		"npcEvidenceId": npc_evidence_id,
		"evidenceCount": evidence_count,
		"hypothesisCount": definition.get("hypotheses", []).size(),
		"citationCount": citation_count,
		"minimumCaptureCitations": minimum_capture_citations,
		"requiredCitationsOnly": required_citations_only,
		"includesNpcCitation": include_npc_citation,
		"discoveredCount": discovered.size(),
		"independentSourceCount": int(preview.get("independentSourceCount", 0)),
		"requiredSourcesMet": bool(preview.get("requiredSourcesMet", false)),
		"strong": String(preview.get("substantiation", "")) == "STRONG"
	}


func position_authored_report_view(main: Node3D) -> Dictionary:
	await settle_ui(3)
	var scroll := find_visible_control(main, "CaseDossierScroll")
	var submit := find_visible_control(main, "ResolveCaseReport")
	if not scroll is ScrollContainer or submit == null:
		return {"valid": false, "reason": "missing_report_scroll_or_submit"}
	var dossier_scroll := scroll as ScrollContainer
	var vertical_bar := dossier_scroll.get_v_scroll_bar()
	var maximum_vertical := maxi(0, ceili(vertical_bar.max_value - vertical_bar.page))
	dossier_scroll.scroll_horizontal = 0
	dossier_scroll.scroll_vertical = maximum_vertical
	await settle_ui(2)
	var submit_rect := submit.get_global_rect()
	var submit_visible_rect := effective_visible_rect(submit, Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)))
	return {
		"valid": maximum_vertical > 0 \
			and dossier_scroll.scroll_horizontal == 0 \
			and dossier_scroll.scroll_vertical == maximum_vertical \
			and rect_contains_rect(submit_visible_rect, submit_rect),
		"horizontal": dossier_scroll.scroll_horizontal,
		"vertical": dossier_scroll.scroll_vertical,
		"maximumVertical": maximum_vertical,
		"submitVisible": rect_contains_rect(submit_visible_rect, submit_rect)
	}


func authored_report_capture_specification(gs: Node, main: Node3D, case_id: String, locale: String, fixture: Dictionary, npc_name: String) -> Dictionary:
	var hypothesis_node := "CaseHypothesis_%s" % String(fixture.get("hypothesisId", "")).validate_node_name()
	var citation_nodes: Array = []
	for citation_id_value: Variant in fixture.get("citationIds", []):
		citation_nodes.append("ReportCitationRemove_%s" % String(citation_id_value).validate_node_name())
	var required: Array = [
		"CaseDossierScroll", "CaseReportPrompt",
		hypothesis_node, "ResolveCaseReport"
	]
	required.append_array(citation_nodes)
	var minimum_widths := {
		"CaseDossierScroll": 1180.0,
		"CaseReportPrompt": 900.0,
		hypothesis_node: 350.0,
		"ResolveCaseReport": 1100.0
	}
	var minimum_heights := {
		hypothesis_node: 54.0,
		"ResolveCaseReport": 48.0
	}
	var no_overlap_pairs: Array = [[hypothesis_node, "CaseReportPrompt"], [hypothesis_node, "ResolveCaseReport"], ["CaseReportPrompt", "ResolveCaseReport"]]
	for citation_index in range(citation_nodes.size()):
		var citation_node := String(citation_nodes[citation_index])
		minimum_widths[citation_node] = 340.0
		minimum_heights[citation_node] = 40.0
		no_overlap_pairs.append([hypothesis_node, citation_node])
		no_overlap_pairs.append(["CaseReportPrompt", citation_node])
		no_overlap_pairs.append([citation_node, "ResolveCaseReport"])
		for later_index in range(citation_index + 1, citation_nodes.size()):
			no_overlap_pairs.append([citation_node, String(citation_nodes[later_index])])
	var public_state: Dictionary = gs.get_case_public_state(case_id)
	var localized_title := String(main.localized_value(public_state.get("title", "")))
	var localized_submit := "증거 기반 보고서 제출" if locale == "ko" else "SUBMIT EVIDENCE-BACKED REPORT"
	var protected_from_bars: Array = ["CaseReportPrompt", hypothesis_node, "ResolveCaseReport"]
	protected_from_bars.append_array(citation_nodes)
	return {
		"required": required,
		"strictRequiredClip": true,
		"minimumWidths": minimum_widths,
		"minimumHeights": minimum_heights,
		"counts": [
			{"pattern": "CaseEvidenceCard_*", "type": "Button", "exact": int(fixture.get("evidenceCount", 0))},
			{"pattern": "CaseHypothesis_*", "type": "Button", "exact": int(fixture.get("hypothesisCount", 0))},
			{"pattern": "ReportCitationRemove_*", "type": "Button", "exact": int(fixture.get("citationCount", 0))},
			{"pattern": "ResolveCaseReport", "type": "Button", "exact": 1}
		],
		"maxLines": [{"name": "CaseReportPrompt", "maximum": 2}],
		"buttonIconRequirements": ["CaseEvidenceCard_*", "CaseHypothesis_*", "ReportCitationRemove_*", "ResolveCaseReport"],
		"buttonLineCounts": [
			{"pattern": "CaseEvidenceCard_*", "exact": 2},
			{"pattern": "CaseHypothesis_*", "exact": 1},
			{"pattern": "ReportCitationRemove_*", "exact": 1},
			{"pattern": "ResolveCaseReport", "exact": 1}
		],
		"noOverlapPairs": no_overlap_pairs,
		"singleLineTextFitPatterns": [],
		"viewportVisibleScrollExact": 1,
		"allowedViewportScrolls": ["CaseDossierScroll"],
		"collapsedDetailScrollExact": -1 if bool(fixture.get("collapsedDetailMayBeOutsideViewport", false)) else 1,
		"collapsedDetailScrollMinimum": 0 if bool(fixture.get("collapsedDetailMayBeOutsideViewport", false)) else -1,
		"collapsedDetailScrollMaximum": 1 if bool(fixture.get("collapsedDetailMayBeOutsideViewport", false)) else -1,
		"collapsedDetailScrollMaxVisibleHeight": 40.0,
		"collapsedDetailScrollParent": "CaseDossierScroll",
		"collapsedDetailProtect": protected_from_bars,
		"scrollContracts": [{
			"name": "CaseDossierScroll",
			"horizontal": 0,
			"minimumVertical": 1,
			"requireVerticalScrollable": true,
			"protectFromBars": protected_from_bars
		}],
		"requiredCopy": [localized_title, npc_name, localized_submit],
		"publicActionEvidence": {
			"method": "new_game(%d) + begin_case + public evidence discovery/citation + hypothesis selection" % int(fixture.get("stageId", 0)),
			"authoredSchemaV2": true,
			"actualInFlow": true,
			"sourceCardCount": int(fixture.get("evidenceCount", 0)),
			"hypothesisCount": int(fixture.get("hypothesisCount", 0)),
			"submitCta": "ResolveCaseReport",
			"minimumCaptureCitations": int(fixture.get("minimumCaptureCitations", 4)),
			"requiredCitationsOnly": bool(fixture.get("requiredCitationsOnly", false)),
			"includesNpcCitation": bool(fixture.get("includesNpcCitation", false)),
			"discoveredCount": int(fixture.get("discoveredCount", 0)),
			"citationCount": int(fixture.get("citationCount", 0)),
			"independentSourceCount": int(fixture.get("independentSourceCount", 0)),
			"requiredSourcesMet": bool(fixture.get("requiredSourcesMet", false)),
			"strongWithoutSubmission": bool(fixture.get("strong", false)),
			"reportScroll": fixture.get("reportScroll", {}).duplicate(true),
			"npcPresentedAsAuthoredCitationCard": not String(fixture.get("npcEvidenceId", "")).is_empty(),
			"portraitApplicableOnDossierRenderer": false,
			"onlyIntendedViewportScroll": "CaseDossierScroll",
			"longBodyOutsideCollapsedDetail": 0,
			"collapsedDetailScrollException": "The renderer-owned 88px selected-clue detail remains inside CaseDossierScroll; at the report-ready bottom position it may be fully outside the viewport or expose at most a 40px clipped edge, with horizontal offset and report-control overlaps both zero."
		},
		"primary": "ResolveCaseReport",
		"forbidden": authored_case_forbidden_tokens(gs, case_id, fixture.get("artifact", {}), locale)
	}


func show_authored_npc_detail_fixture(gs: Node, registry: Node, main: Node3D, locale: String, stage_id: int, case_id: String, expected_portrait_path: String) -> Dictionary:
	configure_clean_fixture(gs, main, locale, false)
	gs.current_stage = stage_id
	gs.stage_run_state = gs.default_stage_run_state(stage_id)
	gs.stage_run_state["status"] = "RUNNING"
	var story_case: Dictionary = registry.get_case(case_id)
	gs.campaign_state["currentAct"] = String(story_case.get("act", ""))
	var artifact: Dictionary = gs.begin_case(case_id)
	var discovered := discover_all_public_evidence(gs, case_id)
	var public_state: Dictionary = gs.get_case_public_state(case_id)
	var npc_row: Dictionary = {}
	for evidence_value: Variant in public_state.get("evidence", []):
		if evidence_value is Dictionary and String((evidence_value as Dictionary).get("sourceKind", "")) == "NPC":
			npc_row = evidence_value
			break
	main.selected = artifact
	main.load_artifact(artifact)
	main.case_dossier_case_id = case_id
	main.case_detail_evidence_id = String(npc_row.get("id", ""))
	main.show_case_dossier(case_id)
	var portrait: Dictionary = npc_row.get("npcPortrait", {}) if npc_row.get("npcPortrait", {}) is Dictionary else {}
	return {
		"ready": not artifact.is_empty() \
			and not npc_row.is_empty() \
			and bool(npc_row.get("unlocked", false)) \
			and bool(npc_row.get("discovered", false)) \
			and String(portrait.get("asset_path", "")) == expected_portrait_path,
		"stageId": stage_id,
		"caseId": case_id,
		"artifact": artifact,
		"discoveredCount": discovered.size(),
		"npcEvidenceId": String(npc_row.get("id", "")),
		"npcDisplayTitle": main.case_evidence_title(case_id, npc_row) if not npc_row.is_empty() else "",
		"portraitPath": String(portrait.get("asset_path", "")),
		"expectedPortraitPath": expected_portrait_path
	}


func position_authored_npc_detail(main: Node3D) -> Dictionary:
	await settle_ui(3)
	var scroll := find_visible_control(main, "CaseDossierScroll")
	var portrait := find_visible_control(main, "CaseNpcSourcePortrait")
	if not scroll is ScrollContainer or not portrait is TextureRect:
		return {"valid": false, "reason": "missing_dossier_scroll_or_npc_portrait"}
	var dossier_scroll := scroll as ScrollContainer
	var portrait_rect := portrait.get_global_rect()
	var scroll_rect := dossier_scroll.get_global_rect()
	var vertical_bar := dossier_scroll.get_v_scroll_bar()
	var maximum_vertical := maxi(0, ceili(vertical_bar.max_value - vertical_bar.page))
	var desired_y := scroll_rect.position.y + 92.0
	var requested_vertical := dossier_scroll.scroll_vertical + roundi(portrait_rect.position.y - desired_y)
	dossier_scroll.scroll_horizontal = 0
	dossier_scroll.scroll_vertical = clampi(requested_vertical, 0, maximum_vertical)
	await settle_ui(3)
	portrait_rect = portrait.get_global_rect()
	var portrait_visible_rect := effective_visible_rect(portrait, Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)))
	return {
		"valid": dossier_scroll.scroll_horizontal == 0 \
			and dossier_scroll.scroll_vertical > 0 \
			and portrait_rect.size.x >= 96.0 \
			and portrait_rect.size.y >= 120.0 \
			and rect_contains_rect(portrait_visible_rect, portrait_rect),
		"horizontal": dossier_scroll.scroll_horizontal,
		"vertical": dossier_scroll.scroll_vertical,
		"maximumVertical": maximum_vertical,
		"portraitRect": rect_array(portrait_rect),
		"portraitVisibleRect": rect_array(portrait_visible_rect)
	}


func authored_npc_detail_capture_specification(gs: Node, case_id: String, locale: String, fixture: Dictionary, npc_name: String) -> Dictionary:
	return {
		"required": ["CaseDossierScroll", "CaseNpcSourcePortrait", "CaseEvidenceDisplayTitle", "CaseEvidenceSourceMeta"],
		"strictRequiredClip": true,
		"minimumWidths": {"CaseDossierScroll": 1180.0, "CaseNpcSourcePortrait": 96.0, "CaseEvidenceDisplayTitle": 260.0},
		"minimumHeights": {"CaseNpcSourcePortrait": 120.0},
		"counts": [
			{"pattern": "CaseNpcSourcePortrait", "type": "TextureRect", "exact": 1},
			{"pattern": "CaseLockedSourceIcon", "type": "TextureRect", "exact": 0}
		],
		"textureRequirements": ["CaseNpcSourcePortrait"],
		"noOverlapPairs": [["CaseNpcSourcePortrait", "CaseEvidenceDisplayTitle"], ["CaseNpcSourcePortrait", "CaseEvidenceSourceMeta"]],
		"scrollContracts": [{
			"name": "CaseDossierScroll",
			"horizontal": 0,
			"minimumVertical": 1,
			"requireVerticalScrollable": true,
			"protectFromBars": ["CaseNpcSourcePortrait", "CaseEvidenceDisplayTitle", "CaseEvidenceSourceMeta"]
		}],
		"requiredCopy": [npc_name, String(fixture.get("npcDisplayTitle", ""))],
		"publicActionEvidence": {
			"method": "Stage %d RUNNING state + authored act context + begin_case + discover NPC source + select clue detail" % int(fixture.get("stageId", 0)),
			"caseId": case_id,
			"npcEvidenceId": String(fixture.get("npcEvidenceId", "")),
			"portraitPath": String(fixture.get("portraitPath", "")),
			"portraitMinimum": [96, 120],
			"portraitPosition": fixture.get("portraitPosition", {}).duplicate(true),
			"unlocked": true,
			"discovered": true
		},
		"forbidden": authored_case_forbidden_tokens(gs, case_id, fixture.get("artifact", {}), locale)
	}


func show_artifact_visual_fixture(gs: Node, main: Node3D, locale: String, spec_id: String, seed_value: int) -> Dictionary:
	configure_clean_fixture(gs, main, locale)
	var artifact: Dictionary = gs.new_artifact(spec_id, seed_value, "viewport_visual_%s" % spec_id)
	artifact["damageInstances"] = []
	artifact["knownClues"] = []
	artifact["evidence"] = []
	main.load_artifact(artifact)
	main.orbit = Vector2(-0.08, 0.02)
	main.distance = 3.6 if spec_id == "artifact_069" else 3.2
	main.update_camera()
	main.show_inspection()
	return artifact


func show_story_artifact_visual_fixture(gs: Node, main: Node3D, locale: String, story_artifact_id: String, spec_id: String, seed_value: int, camera_distance: float) -> Dictionary:
	configure_clean_fixture(gs, main, locale)
	var artifact: Dictionary = gs.new_artifact(spec_id, seed_value, "viewport_visual_%s_%s" % [story_artifact_id, spec_id])
	artifact["storyArtifactId"] = story_artifact_id
	artifact["damageInstances"] = []
	artifact["knownClues"] = []
	artifact["evidence"] = []
	main.load_artifact(artifact)
	main.orbit = Vector2(-0.08, 0.02)
	main.distance = camera_distance
	main.update_camera()
	main.show_inspection()
	return artifact


func show_repair_ready_fixture(gs: Node, main: Node3D, locale: String) -> Dictionary:
	var context := show_report_ready_fixture(gs, main, locale)
	var resolution: Dictionary = gs.resolve_case_v2(CASE_ID, String(context.hypothesisId), [String(context.evidenceId)])
	var artifact: Dictionary = context.artifact
	var required_tools: Array = gs.repair_requirements(artifact).get("requiredTools", [])
	var required_tool := String(required_tools[0]) if not required_tools.is_empty() else ""
	var selected_tool := not required_tool.is_empty() and bool(gs.select_tool(required_tool))
	main.selected = artifact
	main.load_artifact(artifact)
	main.show_inspection()
	context.resolution = resolution
	context.requiredTool = required_tool
	context.ready = bool(context.ready) and bool(resolution.get("ok", false)) and selected_tool
	return context


func show_market_offer_fixture(gs: Node, main: Node3D, locale: String) -> Dictionary:
	configure_clean_fixture(gs, main, locale)
	main.show_market()
	var lot: Dictionary = gs.market_roster[0] if not gs.market_roster.is_empty() else {}
	if not lot.is_empty():
		main.preview_market_offer(String(lot.get("lotId", "")))
	return lot


func show_event_result_fixture(gs: Node, main: Node3D, locale: String) -> Dictionary:
	configure_clean_fixture(gs, main, locale)
	gs.current_stage = 8
	var event_result: Dictionary = gs.advance_day()
	main.last_event_result = event_result
	main.event_cue_state = "REQUEST"
	main.show_event_dialogue(event_result)
	main.reveal_event_reaction()
	return event_result


func repeated_core_artifact(gs: Node, registry: Node, spec_index: int, unique_id: String) -> Dictionary:
	var spec_id := String(registry.spec_order[posmod(spec_index, registry.spec_order.size())])
	var artifact: Dictionary = gs.new_artifact(spec_id, 810000 + spec_index, unique_id)
	artifact["damageInstances"] = ["DUST", "RUST"] if spec_index % 2 == 0 else ["CRACK"]
	artifact["knownClues"] = ["MATERIAL", "PROVENANCE"] if spec_index % 3 == 0 else ["SERIAL_PATTERN"]
	artifact["evidence"] = []
	artifact["sold"] = false
	return artifact


func prepare_inventory_capture_fixture(gs: Node, main: Node3D, registry: Node) -> Dictionary:
	configure_clean_fixture(gs, main, "ko")
	gs.inventory = []
	for artifact_index in range(11):
		var artifact := repeated_core_artifact(gs, registry, artifact_index, "viewport_inventory_%02d" % artifact_index)
		if artifact_index == 8:
			artifact["caseId"] = CASE_ID
			artifact["caseResolved"] = true
		gs.inventory.append(artifact)
	main.inventory_page = 0
	main.inventory_selected_uid = ""
	var route_pressed := press_visible_button(main, "Nav_INVENTORY")
	return {
		"ok": route_pressed and String(main.screen) == "inventory" and gs.inventory.size() == 11,
		"routeButton": "Nav_INVENTORY",
		"routePressed": route_pressed,
		"inventory": gs.inventory
	}


func inventory_capture_tokens(inventory: Array) -> Array:
	var tokens: Array = ["uniqueId", "artifactSpecId", "estimatedValue", "damageInstances", "knownClues", CASE_ID, "DUST", "RUST", "CRACK", "MATERIAL", "PROVENANCE", "SERIAL_PATTERN"]
	for artifact_value: Variant in inventory:
		if artifact_value is Dictionary:
			for key_value: String in ["uniqueId", "artifactSpecId", "specId"]:
				var token := String((artifact_value as Dictionary).get(key_value, ""))
				if not token.is_empty() and not tokens.has(token):
					tokens.append(token)
	return tokens


func prepare_authentication_capture_fixture(gs: Node, main: Node3D, registry: Node) -> Dictionary:
	configure_clean_fixture(gs, main, "ko")
	var artifact := repeated_core_artifact(gs, registry, 12, "viewport_authentication")
	artifact["damageInstances"] = []
	artifact["knownClues"] = AUTH_EVIDENCE_IDS.duplicate()
	artifact["evidence"] = []
	artifact["confidence"] = 0.78
	artifact["playerHypothesis"] = "UNKNOWN"
	for evidence_index in range(AUTH_EVIDENCE_IDS.size()):
		artifact.evidence.append({
			"clueType": String(AUTH_EVIDENCE_IDS[evidence_index]),
			"observation": {
				"en": "Public observation %d records a period-consistent surface detail." % (evidence_index + 1),
				"ko": "공개 관찰 %d에서 시대와 맞는 표면 특징을 기록했습니다." % (evidence_index + 1)
			},
			"supports": [],
			"contradicts": [],
			"confidenceWeight": 0.0825
		})
	gs.inventory = [artifact]
	main.authentication_evidence_page = 0
	main.authentication_evidence_index = 0
	main.load_artifact(artifact)
	main.show_inspection()
	var route_pressed := press_visible_button(main, "AuthenticateButton")
	return {
		"ok": route_pressed and String(main.screen) == "authentication",
		"routeButton": "AuthenticateButton",
		"routePressed": route_pressed,
		"artifact": artifact
	}


func authentication_capture_tokens(artifact: Dictionary) -> Array:
	var tokens: Array = ["clueType", "confidenceWeight", "authenticityTruth", "playerHypothesis", "viewport_authentication"]
	tokens.append_array(AUTH_EVIDENCE_IDS)
	tokens.append_array(["GENUINE_WITH_PERIOD_REPAIR", "GENUINE_WITH_MODERN_REPAIR", "UNKNOWN"])
	for key_value: String in ["uniqueId", "artifactSpecId", "specId"]:
		var token := String(artifact.get(key_value, ""))
		if not token.is_empty() and not tokens.has(token):
			tokens.append(token)
	return tokens


func prepare_upgrades_capture_fixture(gs: Node, main: Node3D, registry: Node) -> Dictionary:
	configure_clean_fixture(gs, main, "ko")
	gs.money = 100000
	gs.owned_upgrades = []
	main.upgrade_page = 0
	main.selected_upgrade_id = ""
	var route_pressed := press_visible_button(main, "Nav_UPGRADES")
	return {
		"ok": route_pressed and String(main.screen) == "upgrades" and registry.upgrades.size() == 25,
		"routeButton": "Nav_UPGRADES",
		"routePressed": route_pressed,
		"upgradeCount": registry.upgrades.size()
	}


func upgrade_capture_tokens(registry: Node) -> Array:
	var tokens: Array = ["effect.type", "effect.value"]
	for upgrade_value: Variant in registry.upgrades:
		if not upgrade_value is Dictionary:
			continue
		var upgrade: Dictionary = upgrade_value
		for token_value: Variant in [upgrade.get("id", ""), upgrade.get("effect", {}).get("type", "")]:
			var token := String(token_value)
			if not token.is_empty() and not tokens.has(token):
				tokens.append(token)
	return tokens


func authority_rng_evidence(gs: Node, authority_before: String, rng_before: int) -> Dictionary:
	var authority_after := stable_save_authority_signature(gs)
	var rng_after := int(gs.rng.state)
	return {
		"authorityMutation0": authority_before == authority_after,
		"authorityBeforeHash": authority_before.sha256_text(),
		"authorityAfterHash": authority_after.sha256_text(),
		"rngMutation0": rng_before == rng_after,
		"rngBefore": str(rng_before),
		"rngAfter": str(rng_after),
		"valid": authority_before == authority_after and rng_before == rng_after
	}


func authentication_draft_neutral_signature(gs: Node, artifact_uid: String) -> String:
	var payload: Dictionary = gs.save_payload().duplicate(true)
	payload["language"] = "<locale>"
	var inventory_value: Variant = payload.get("inventory", [])
	if inventory_value is Array:
		for artifact_value: Variant in inventory_value:
			if artifact_value is Dictionary and String((artifact_value as Dictionary).get("uniqueId", "")) == artifact_uid:
				(artifact_value as Dictionary)["playerHypothesis"] = "<allowed-draft>"
	return JSON.stringify({"run": payload, "profile": gs.profile_payload()})


func grand_reserve_profile_fixture(gs: Node) -> Dictionary:
	var profile: Dictionary = gs.default_player_profile()
	var cleared: Array = []
	for stage_id in range(1, 10):
		cleared.append(stage_id)
	profile.highestUnlockedStage = 10
	profile.clearedStages = cleared
	profile.tutorialCompletedSteps = TUTORIAL_STEPS.duplicate()
	return profile


func prepare_grand_reserve_fixture(gs: Node, main: Node3D, registry: Node, locale: String) -> Dictionary:
	# Enter Stage 10 and stop at the real public final-lot selection screen. The
	# capture flow itself presses the three card toggles and BEGIN GRAND RESERVE;
	# no direct selection/session helper bypasses the visible UI boundary.
	configure_clean_fixture(gs, main, locale)
	gs.master_seed = 481516
	gs.player_profile = grand_reserve_profile_fixture(gs)
	var started: Dictionary = gs.new_game(10)
	var failed_cases: Array = []
	for case_id_value: Variant in registry.get_stage_definition(10).get("case_ids", []):
		var case_id := String(case_id_value)
		if not bool(gs.prepare_case_for_test(case_id)):
			failed_cases.append(case_id)
	var eligible: Array = gs.eligible_final_lots()
	var lot_uids: Array = []
	for lot_index in range(mini(3, eligible.size())):
		var artifact: Dictionary = eligible[lot_index]
		var appraisal := maxi(1, int(gs.appraise(artifact)))
		artifact.listing = {
			"starting": 999999 if lot_index == 1 else 1,
			"reserve": 1000000 if lot_index == 1 else 1,
			"confidence": float(artifact.get("confidence", 0.8)),
			"disclosure": "CERTAIN",
			"publicAppraisal": appraisal
		}
		var lot_uid := String(artifact.get("uniqueId", ""))
		lot_uids.append(lot_uid)
	main.show_final_lot_selection()
	var selected_ids: Array = gs.campaign_state.get("grandReserve", {}).get("selectedLotIds", [])
	return {
		"ok": bool(started.get("ok", false)) \
			and failed_cases.is_empty() \
			and lot_uids.size() == 3 \
			and eligible.size() >= 3 \
			and selected_ids.is_empty() \
			and String(gs.stage_run_state.get("status", "")) == "RUNNING" \
			and String(gs.campaign_state.get("currentAct", "")) == "GRAND_RESERVE" \
			and bool(gs.campaign_state.get("grandReserve", {}).get("invited", false)) \
			and String(main.screen) == "final_selection",
		"started": started,
		"failedCases": failed_cases,
		"lotUids": lot_uids,
		"eligible": eligible,
		"selectedLotIds": selected_ids.duplicate(),
		"screen": String(main.screen)
	}


func select_three_final_lots_from_ui(gs: Node, main: Node3D, lot_uids: Array) -> Dictionary:
	var steps: Array = []
	var expected: Array = []
	var valid := lot_uids.size() == 3
	for lot_index in range(mini(3, lot_uids.size())):
		var card := find_visible_control(main, "FinalLotCard_%d" % lot_index)
		var toggle: Node = card.find_child("FinalLotToggle", true, false) if card != null else null
		var pressed := toggle is Button and (toggle as Button).is_visible_in_tree() and not (toggle as Button).disabled
		if pressed:
			(toggle as Button).pressed.emit()
			await settle_ui(6)
			expected.append(String(lot_uids[lot_index]))
		var selected_value: Variant = gs.campaign_state.get("grandReserve", {}).get("selectedLotIds", [])
		var selected_ids: Array = selected_value.duplicate() if selected_value is Array else []
		var begin := find_visible_control(main, "BeginGrandReserve")
		var expected_disabled := lot_index < 2
		var step_ok := pressed \
			and selected_ids == expected \
			and begin is Button \
			and bool((begin as Button).disabled) == expected_disabled
		valid = valid and step_ok
		steps.append({
			"index": lot_index,
			"pressed": pressed,
			"selectedCount": selected_ids.size(),
			"beginDisabled": bool((begin as Button).disabled) if begin is Button else null,
			"ok": step_ok
		})
	var final_selected_value: Variant = gs.campaign_state.get("grandReserve", {}).get("selectedLotIds", [])
	var final_selected: Array = final_selected_value.duplicate() if final_selected_value is Array else []
	return {"valid": valid and final_selected == lot_uids, "steps": steps, "selectedLotIds": final_selected}


func final_selection_semantic_evidence(gs: Node, main: Node3D) -> Dictionary:
	var progress := find_visible_control(main, "FinalSelectionProgress")
	var begin := find_visible_control(main, "BeginGrandReserve")
	var selected_value: Variant = gs.campaign_state.get("grandReserve", {}).get("selectedLotIds", [])
	var selected_ids: Array = selected_value.duplicate() if selected_value is Array else []
	return {
		"screen": String(main.screen),
		"selectedCount": selected_ids.size(),
		"selectedLotIds": selected_ids,
		"progressText": (progress as Label).text if progress is Label else "",
		"cardCount": count_visible(main, "FinalLotCard_*", "PanelContainer"),
		"nameCount": count_visible(main, "FinalLotName", "Label"),
		"valueCount": count_visible(main, "FinalLotValue", "Label"),
		"badgeRowCount": count_visible(main, "FinalLotBadgeRow", "HBoxContainer"),
		"toggleCount": count_visible(main, "FinalLotToggle", "Button"),
		"beginPresent": begin is Button,
		"beginDisabled": bool((begin as Button).disabled) if begin is Button else null
	}


func ending_internal_tokens(gs: Node) -> Array:
	var tokens: Array = [String(gs.campaign_state.get("currentEnding", ""))]
	var results_value: Variant = gs.campaign_state.get("grandReserve", {}).get("results", [])
	var results: Array = results_value if results_value is Array else []
	for result_value: Variant in results:
		if not result_value is Dictionary:
			continue
		var result: Dictionary = result_value
		var artifact_value: Variant = result.get("artifact", {})
		if artifact_value is Dictionary:
			tokens.append_array(artifact_internal_tokens([artifact_value]))
		var auction_value: Variant = result.get("auction", {})
		if auction_value is Dictionary:
			for reason_value: Variant in (auction_value as Dictionary).get("reasonTags", []):
				if reason_value is Dictionary:
					tokens.append(String((reason_value as Dictionary).get("code", "")))
	return final_journey_forbidden_tokens(tokens)


func campaign_ending_tokens(registry: Node, gs: Node) -> Array:
	var tokens := ending_internal_tokens(gs)
	for ending_value: Variant in registry.campaign.get("endings", []):
		if ending_value is Dictionary:
			var ending_id := String((ending_value as Dictionary).get("id", ""))
			if not ending_id.is_empty() and not tokens.has(ending_id):
				tokens.append(ending_id)
	return tokens


func drive_current_public_auction_to_final(main: Node3D) -> Dictionary:
	var states: Array = []
	for _step in range(24):
		var cue: Dictionary = main.auction_public_cue_state()
		if cue.is_empty():
			break
		states.append(public_auction_cue_summary(main, cue))
		if bool(cue.get("isFinal", false)):
			break
		main.advance_auction_cue()
	var chain_failures := auction_cue_chain_failures(states, main.last_auction_result)
	return {
		"states": states,
		"final": states[-1] if not states.is_empty() else {},
		"result": main.last_auction_result.duplicate(true),
		"valid": chain_failures.is_empty(),
		"failures": chain_failures
	}


func press_visible_button(main: Node3D, node_name: String) -> bool:
	var button := find_visible_control(main, node_name)
	if not button is Button or (button as Button).disabled:
		return false
	(button as Button).pressed.emit()
	return true


func grand_reserve_semantic_evidence(gs: Node, main: Node3D) -> Dictionary:
	var session: Dictionary = gs.grand_reserve_public_state()
	var cue: Dictionary = main.auction_public_cue_state() if main.has_method("auction_public_cue_state") else {}
	var pending: Dictionary = gs.pending_auction_public_state()
	var progress_control := find_visible_control(main, "GrandReserveProgress")
	var result_control := find_visible_control(main, "AuctionResultFact")
	var receipts: Array = session.get("receipts", []) if session.get("receipts", []) is Array else []
	var receipt_statuses: Array = []
	for receipt_value: Variant in receipts:
		var receipt: Dictionary = receipt_value if receipt_value is Dictionary else {}
		receipt_statuses.append(String(receipt.get("auction", {}).get("sale_status", "")))
	var semantic_payload := {
		"screen": String(main.screen),
		"phase": String(session.get("phase", "")),
		"currentLotIndex": int(session.get("currentLotIndex", -1)),
		"receiptCount": receipts.size(),
		"receiptStatuses": receipt_statuses,
		"pendingStatus": String(pending.get("status", "NONE")),
		"activeTransactionId": String(session.get("activeTransactionId", "")),
		"cuePhase": String(cue.get("phase", "")),
		"cueIndex": int(cue.get("index", -1)),
		"cueTotal": int(cue.get("total", 0)),
		"cueFinal": bool(cue.get("isFinal", false)),
		"progressText": (progress_control as Label).text if progress_control is Label else "",
		"resultText": (result_control as Label).text if result_control is Label else "",
		"stage": int(gs.current_stage),
		"stageStatus": String(gs.stage_run_state.get("status", "")),
		"stageClearPending": bool(gs.stage_clear_pending()),
		"ending": String(gs.campaign_state.get("currentEnding", ""))
	}
	var evidence := semantic_payload.duplicate(true)
	evidence["semanticHash"] = JSON.stringify(semantic_payload).sha256_text()
	return evidence


func grand_reserve_state_failures(evidence: Dictionary, expected_phase: String, expected_lot_index: int, expected_receipts: int, expected_screen: String) -> Array:
	var failures: Array = []
	if String(evidence.get("phase", "")) != expected_phase:
		failures.append("grand_reserve_phase:%s_expected_%s" % [evidence.get("phase", ""), expected_phase])
	if int(evidence.get("currentLotIndex", -1)) != expected_lot_index:
		failures.append("grand_reserve_lot:%d_expected_%d" % [int(evidence.get("currentLotIndex", -1)), expected_lot_index])
	if int(evidence.get("receiptCount", -1)) != expected_receipts:
		failures.append("grand_reserve_receipts:%d_expected_%d" % [int(evidence.get("receiptCount", -1)), expected_receipts])
	if String(evidence.get("screen", "")) != expected_screen:
		failures.append("grand_reserve_screen:%s_expected_%s" % [evidence.get("screen", ""), expected_screen])
	if String(evidence.get("semanticHash", "")).length() != 64:
		failures.append("grand_reserve_semantic_hash_missing")
	return failures


func append_fixture_failures(capture_id: String, failures: Array, evidence: Dictionary) -> void:
	if not failures.is_empty():
		layout_failures.append({"captureId": capture_id, "failures": failures, "fixture": evidence})


func build_artifact_spec_contact_sheets(gs: Node, main: Node3D, registry: Node) -> Array:
	if not framebuffer_capture_enabled:
		return []
	const SHEET_COLUMNS := 10
	const SHEET_ROWS := 4
	const TILE_SIZE := Vector2i(180, 120)
	const SPECS_PER_SHEET := SHEET_COLUMNS * SHEET_ROWS
	var sheet_images: Array = []
	for _sheet_index in range(2):
		var sheet := Image.create_empty(SHEET_COLUMNS * TILE_SIZE.x, SHEET_ROWS * TILE_SIZE.y, false, Image.FORMAT_RGBA8)
		sheet.fill(Color("#101418"))
		sheet_images.append(sheet)

	var legend_layer := CanvasLayer.new()
	legend_layer.name = "ArtifactSpecSheetLegend"
	legend_layer.layer = 100
	main.add_child(legend_layer)
	var legend_background := ColorRect.new()
	legend_background.position = Vector2(0, 608)
	legend_background.size = Vector2(1280, 112)
	legend_background.color = Color("#081015e8")
	legend_layer.add_child(legend_background)
	var legend := Label.new()
	legend.name = "ArtifactSpecSheetLabel"
	legend.position = Vector2(24, 610)
	legend.size = Vector2(1232, 100)
	legend.add_theme_font_size_override("font_size", 64)
	legend.add_theme_constant_override("outline_size", 8)
	legend.add_theme_color_override("font_color", Color("#f4d685"))
	legend.add_theme_color_override("font_outline_color", Color("#081015"))
	legend.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	legend_layer.add_child(legend)

	var ui_was_visible: bool = bool(main.ui.visible)
	main.ui.visible = false
	main.set_world_mode("workshop")
	var workshop_was_visible: bool = bool(main.workshop_set.visible)
	var reserve_was_visible: bool = bool(main.grand_reserve_set.visible)
	main.workshop_set.visible = false
	main.grand_reserve_set.visible = false
	main.orbit = Vector2(-0.08, 0.02)
	main.distance = 4.0
	main.update_camera()
	var covered_spec_ids: Array = []
	for spec_index in range(registry.spec_order.size()):
		var spec_id := String(registry.spec_order[spec_index])
		var sample: Dictionary = gs.new_artifact(spec_id, 990000 + spec_index, "viewport_sheet_%03d" % (spec_index + 1))
		sample["damageInstances"] = []
		sample["knownClues"] = []
		sample["evidence"] = []
		main.load_artifact(sample)
		legend.text = "%02d / 80  ·  %s" % [spec_index + 1, spec_id]
		await settle_ui(2)
		var thumbnail := get_root().get_viewport().get_texture().get_image()
		if thumbnail == null or thumbnail.is_empty():
			continue
		thumbnail.resize(TILE_SIZE.x, TILE_SIZE.y, Image.INTERPOLATE_LANCZOS)
		var sheet_index := int(spec_index / SPECS_PER_SHEET)
		if sheet_index >= sheet_images.size():
			continue
		var local_index := spec_index % SPECS_PER_SHEET
		var destination := Vector2i((local_index % SHEET_COLUMNS) * TILE_SIZE.x, int(local_index / SHEET_COLUMNS) * TILE_SIZE.y)
		(sheet_images[sheet_index] as Image).blit_rect(thumbnail, Rect2i(Vector2i.ZERO, TILE_SIZE), destination)
		covered_spec_ids.append(spec_id)

	main.ui.visible = ui_was_visible
	main.workshop_set.visible = workshop_was_visible
	main.grand_reserve_set.visible = reserve_was_visible
	legend_layer.queue_free()
	await settle_ui(2)
	var unique_spec_ids := {}
	for spec_id_value: Variant in covered_spec_ids:
		unique_spec_ids[String(spec_id_value)] = true
	var global_failures: Array = []
	if registry.spec_order.size() != 80:
		global_failures.append("registry_spec_count:%d_expected_80" % registry.spec_order.size())
	if covered_spec_ids.size() != registry.spec_order.size():
		global_failures.append("captured_spec_count:%d_expected_%d" % [covered_spec_ids.size(), registry.spec_order.size()])
	if unique_spec_ids.size() != registry.spec_order.size():
		global_failures.append("unique_spec_count:%d_expected_%d" % [unique_spec_ids.size(), registry.spec_order.size()])

	var sheet_results: Array = []
	for sheet_index in range(sheet_images.size()):
		var range_start := sheet_index * SPECS_PER_SHEET
		var range_end := mini(range_start + SPECS_PER_SHEET, registry.spec_order.size())
		var capture_id := "57_artifact_specs_01_40_contact_sheet" if sheet_index == 0 else "58_artifact_specs_41_80_contact_sheet"
		var output_path := "%s/%s.png" % [OUTPUT_DIR, capture_id]
		var sheet_failures: Array = global_failures.duplicate()
		var save_error := (sheet_images[sheet_index] as Image).save_png(output_path)
		if save_error != OK:
			sheet_failures.append("png_save:%s" % error_string(save_error))
		var range_spec_ids: Array = covered_spec_ids.slice(range_start, range_end)
		if range_spec_ids.size() != SPECS_PER_SHEET:
			sheet_failures.append("sheet_coverage:%d_expected_%d" % [range_spec_ids.size(), SPECS_PER_SHEET])
		var contract := {
			"captureId": capture_id,
			"screen": "artifact_spec_contact_sheet",
			"passed": sheet_failures.is_empty(),
			"resolution": [SHEET_COLUMNS * TILE_SIZE.x, SHEET_ROWS * TILE_SIZE.y],
			"columns": SHEET_COLUMNS,
			"rows": SHEET_ROWS,
			"tileResolution": [TILE_SIZE.x, TILE_SIZE.y],
			"firstOrdinal": range_start + 1,
			"lastOrdinal": range_end,
			"specCount": range_spec_ids.size(),
			"specIds": range_spec_ids,
			"allEightyCoveredAcrossTwoSheets": global_failures.is_empty(),
			"tileLabelsRendered": true,
			"failures": sheet_failures
		}
		if not sheet_failures.is_empty():
			layout_failures.append(contract)
		captures.append({
			"id": capture_id,
			"path": output_path,
			"locale": "neutral",
			"screen": "artifact_spec_contact_sheet",
			"resolution": "%dx%d" % [SHEET_COLUMNS * TILE_SIZE.x, SHEET_ROWS * TILE_SIZE.y],
			"source": "80 actual RuntimeRegistry ArtifactSpecs rendered through res://scenes/Main.tscn in two labeled framebuffer sheets",
			"framebufferCaptured": true,
			"status": "PASS" if sheet_failures.is_empty() else "FAIL",
			"note": "Readable 10x4 sheet covers ArtifactSpecs %02d-%02d without off-canvas rows." % [range_start + 1, range_end],
			"density": contract
		})
		sheet_results.append(contract)
	return sheet_results


func build_contact_sheet() -> String:
	var columns := 5 if captures.size() > 16 else 4
	var rows := maxi(1, ceili(float(captures.size()) / float(columns)))
	var thumbnail_size := Vector2i(int(VIEWPORT_SIZE.x / columns), int(VIEWPORT_SIZE.y / rows))
	var sheet := Image.create_empty(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#101418"))
	for capture_index in range(mini(captures.size(), columns * rows)):
		var capture: Dictionary = captures[capture_index]
		var image := Image.load_from_file(ProjectSettings.globalize_path(String(capture.path)))
		if image == null or image.is_empty():
			continue
		image.resize(thumbnail_size.x, thumbnail_size.y, Image.INTERPOLATE_LANCZOS)
		var destination := Vector2i((capture_index % columns) * thumbnail_size.x, int(capture_index / columns) * thumbnail_size.y)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, thumbnail_size), destination)
	var contact_path := "%s/latest_runtime_contact_sheet.png" % OUTPUT_DIR
	sheet.save_png(contact_path)
	return contact_path


func capture_hashes() -> Dictionary:
	var hashes := {}
	for capture: Dictionary in captures:
		var capture_path := String(capture.get("path", ""))
		if not capture_path.is_empty() and FileAccess.file_exists(capture_path):
			hashes[String(capture.get("id", ""))] = FileAccess.get_sha256(capture_path)
	return hashes


func verified_original_resolution_review(current_hashes: Dictionary) -> Dictionary:
	var pending := {
		"status": "PENDING_OR_STALE",
		"reviewedAtOriginalResolution": false,
		"automatedPassIsNotVisualApproval": true,
		"reviewFile": VISUAL_REVIEW_PATH
	}
	if not framebuffer_capture_enabled or not FileAccess.file_exists(VISUAL_REVIEW_PATH):
		return pending
	var review_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(VISUAL_REVIEW_PATH))
	if not review_value is Dictionary:
		return pending
	var review: Dictionary = review_value
	var reviewed_hashes: Dictionary = review.get("captureHashes", {})
	if reviewed_hashes != current_hashes:
		pending["reason"] = "Capture hashes changed after the recorded visual review."
		return pending
	if review.get("status", "") != "PASS_ORIGINAL_RESOLUTION" or not bool(review.get("reviewedAtOriginalResolution", false)):
		return pending
	return review.duplicate(true)


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	framebuffer_capture_enabled = DisplayServer.get_name().to_lower() != "headless"
	get_root().size = VIEWPORT_SIZE
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.persistence_enabled = false
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await settle_ui()

	show_stage_select_fixture(gs, main, "ko")
	await capture_frame(main, "01_stage_select_ko", "ko", "Four cleared stages, Stage 5 open, and later stages locked remain readable in one 1280x720 frame.", {
		"required": ["StageSelect_01", "StageSelect_05", "StageSelect_10", "TutorialReplayButton"],
		"counts": [{"pattern": "StageSelect_*", "type": "Button", "exact": 10}],
		"forbidden": ["performance_target", "stageBest", "authenticityTruth"]
	})

	show_tutorial_investigation_fixture(gs, main, "ko")
	await capture_frame(main, "02_stage1_investigation_tutorial_ko", "ko", "Stage 1 begins with one compact illustrated guidance rail and a highlighted actionable evidence card.", {
		"required": ["TutorialGuidanceRail", "TutorialStepCounter", "TutorialStepTitle", "TutorialStepText", "TutorialTargetOutline"],
		"counts": [{"pattern": "TutorialGuidanceRail", "type": "PanelContainer", "exact": 1}, {"pattern": "TutorialTargetOutline", "type": "PanelContainer", "exact": 1}],
		"primary": "@tutorial_target",
		"forbidden": ["target_ui_id", "route_ui_ids", "EVIDENCE_DISCOVERED", "INVESTIGATE"]
	})

	show_listing_price_fixture(gs, main, "ko")
	await capture_frame(main, "03_listing_price_ko", "ko", "The first listing step shows three illustrated strategies and three public material badges without an early final-submit action.", {
		"required": ["ListingPriceHeading", "ListingPrice_FAST", "ListingPrice_BALANCED", "ListingPrice_HIGH", "ListingMaterialBadge_0", "ListingMaterialBadge_1", "ListingMaterialBadge_2"],
		"counts": [{"pattern": "ListingPrice_*", "type": "Button", "exact": 3}, {"pattern": "ListingMaterialBadge_*", "type": "PanelContainer", "exact": 3}, {"pattern": "ListingConfirmButton", "type": "Button", "exact": 0}],
		"forbidden": ["auctionProfile", "reserveStrategy", "authenticityTruth"]
	})

	var listing_disclosure_ko := show_listing_disclosure_fixture(gs, main, "ko")
	var listing_causal_ko := listing_causal_summary_evidence(gs, main, listing_disclosure_ko)
	append_fixture_failures("04_listing_disclosure_ko", [] if bool(listing_causal_ko.get("valid", false)) else ["listing_causal_order_invalid"], listing_causal_ko)
	await capture_frame(main, "04_listing_disclosure_ko", "ko", "The second listing step separates public support, exactly three ordered causal facts, three calibrated claim choices and one final confirmation.", {
		"required": ["ListingPublicSupportBadge", "ListingPublicSupportLabel", "ListingDisclosure_CERTAIN", "ListingDisclosure_LIKELY", "ListingDisclosure_UNCERTAIN", "ListingCausalSummary", "ListingCausalChip_0", "ListingCausalChip_1", "ListingCausalChip_2", "ListingSummaryTile", "ListingBackToPrice", "ListingConfirmButton"],
		"minimumWidths": {"ListingCausalChip_0": 190.0, "ListingCausalChip_1": 190.0, "ListingCausalChip_2": 190.0},
		"counts": [{"pattern": "ListingDisclosure_*", "type": "Button", "exact": 3}, {"pattern": "ListingCausalChip_*", "type": "PanelContainer", "exact": 3}, {"pattern": "ListingCausalLabel", "type": "Label", "exact": 3}, {"pattern": "ListingConfirmButton", "type": "Button", "exact": 1}],
		"horizontalGaps": [{"left": "ListingCausalChip_0", "right": "ListingCausalChip_1", "minimum": 7.0}, {"left": "ListingCausalChip_1", "right": "ListingCausalChip_2", "minimum": 7.0}],
		"requiredCopy": listing_causal_ko.get("expectedLabels", []),
		"singleLineTextFitPatterns": ["ListingCausalLabel"],
		"publicActionEvidence": {"method": "listing_public_status_tags -> ListingCausalChip_0..2", "causal": listing_causal_ko},
		"primary": "ListingConfirmButton",
		"forbidden": ["CERTAIN", "LIKELY", "UNCERTAIN", "OVERCLAIM", "UNDERCLAIM", "CONDITION_GOOD", "PROVENANCE_STRONG", "DISCLOSURE_CLEAR", "authenticityTruth"]
	})

	var auction_ko := show_sold_auction_fixture(gs, main, "ko")
	var sold_ko := bool(main.last_auction_result.get("reserve_met", false))
	await capture_frame(main, "05_auction_sold_reasons_ko", "ko", "A deterministic public ENTRY-to-SOLD cue chain keeps one dominant primary state with a nearby action, at most two intermediate reasons and exactly one terminal key reason.", {
		"required": ["AuctionPrimaryState", "AuctionPrimaryText", "AuctionPrimaryAction", "AuctionCuePanel", "AuctionCuePhase", "AuctionCueProgress", "AuctionBidderColumn", "PortraitDialoguePanel_auctioneer", "AuctionResultFact", "AuctionReasonHeading", "AuctionReasonChips", "AuctionReasonLabel", "HammerButton"],
		"allowCollapsed": ["AuctionCueProgress"],
		"minimumWidths": {"AuctionPrimaryState": 400.0, "AuctionPrimaryAction": 400.0},
		"minimumHeights": {"AuctionPrimaryState": 58.0, "AuctionPrimaryAction": 40.0},
		"counts": [{"pattern": "CharacterPortrait", "type": "TextureRect", "exact": 2}, {"pattern": "AuctionPrimaryState", "type": "PanelContainer", "exact": 1}, {"pattern": "AuctionPrimaryText", "type": "Label", "exact": 1}, {"pattern": "AuctionPrimaryAction", "type": "VBoxContainer", "exact": 1}, {"pattern": "AuctionCuePanel", "type": "PanelContainer", "exact": 1}, {"pattern": "AuctionCueNext", "type": "Button", "exact": 0}, {"pattern": "AuctionReasonChip_*", "type": "PanelContainer", "exact": 1}, {"pattern": "AuctionReasonLabel", "type": "Label", "exact": 1}, {"pattern": "HammerButton", "type": "Button", "exact": 1}],
		"reactionSettleMilliseconds": 180,
		"postReactionFrames": 2,
		"portraitReactionCount": 2,
		"stableGeometryPatterns": ["ContentMargin", "Navigation", "StatusMessage", "PortraitDialoguePanel_*", "PortraitStack", "CharacterDialogue", "CharacterFactLabel", "CharacterSemanticState", "AuctionPrimaryState", "AuctionPrimaryText", "AuctionPrimaryAction", "AuctionCuePanel", "AuctionCuePhase", "AuctionCueProgress", "AuctionBidderColumn", "AuctionResultFact", "AuctionReasonChips", "HammerButton"],
		"verticalGaps": [{"above": "AuctionPrimaryState", "below": "AuctionPrimaryAction", "minimum": 0.0, "maximum": 16.0}, {"above": "AuctionPrimaryAction", "below": "AuctionCuePanel", "minimum": 0.0, "maximum": 16.0}],
		"horizontalGaps": [{"left": "AuctionPrimaryState", "right": "AuctionBidderColumn", "minimum": 12.0}, {"left": "AuctionBidderColumn", "right": "PortraitDialoguePanel_auctioneer", "minimum": 12.0}],
		"noOverlapPairs": [["AuctionPrimaryState", "AuctionPrimaryAction"], ["AuctionPrimaryAction", "AuctionCuePanel"], ["HammerButton", "AuctionBidderColumn"], ["AuctionPrimaryAction", "PortraitDialoguePanel_auctioneer"], ["AuctionBidderColumn", "PortraitDialoguePanel_auctioneer"]],
		"singleLineTextFitPatterns": ["AuctionPrimaryText", "AuctionReasonLabel"],
		"requiredCopy": [main.auction_phase_label(String(auction_ko.get("final", {}).get("phase", ""))), "%d / %d" % [int(auction_ko.get("final", {}).get("index", -1)) + 1, int(auction_ko.get("final", {}).get("total", 0))]],
		"publicActionEvidence": {"method": "auction_public_cue_state + advance_auction_cue", "states": auction_ko.get("states", []), "valid": auction_ko.get("valid", false)},
		"primary": "HammerButton",
		"forbidden": ["ENTRY", "CALL", "BID", "DROPOUT", "PROVENANCE_STRONG", "CONDITION_GOOD", "DISCLOSURE_CLEAR", "winnerId", "maxBid"]
	})
	if not sold_ko or not bool(auction_ko.get("valid", false)):
		layout_failures.append({"captureId": "05_auction_sold_reasons_ko", "failures": ["fixture_not_sold_or_public_chain_invalid"], "fixture": auction_ko})

	var stage_clear_ko := show_stage_clear_fixture(gs, main, "ko")
	var stage_pressure_ko := stage_pressure_evidence(gs, main)
	append_fixture_failures("06_stage_clear_ko", [] if bool(stage_pressure_ko.get("valid", false)) else ["stage_pressure_contract_invalid"], stage_pressure_ko)
	var stage_clear_ko_specification := with_stage_pressure_contract({
		"required": ["StageProgressScore", "StageProgressCases", "StageClearCard", "StageClearHeading", "StageClearScore", "StageClearTarget", "StageClearUnlock", "StageClearBest", "StageReplayAxes", "StageReplayAxis_investigation", "StageReplayAxis_preservation", "StageReplayAxis_sale", "StageReplayAxisScore_investigation", "StageReplayAxisScore_preservation", "StageReplayAxisScore_sale", "StageClearAdvice", "CampaignStageSelect"],
		"counts": [{"pattern": "StageClearCard", "type": "PanelContainer", "exact": 1}, {"pattern": "StageReplayAxis_*", "type": "PanelContainer", "exact": 3}, {"pattern": "StageClearAdvice", "type": "Label", "exact": 1}, {"pattern": "CampaignStageSelect", "type": "Button", "exact": 1}],
		"primary": "CampaignStageSelect",
		"forbidden": ["FAILED", "실패", "불합격", "performance_target", "STRENGTHEN_EVIDENCE", "PROTECT_CONDITION", "IMPROVE_SALE"]
	}, stage_pressure_ko, "CampaignStageSelect")
	await capture_frame(main, "06_stage_clear_ko", "ko", "A real Stage 1 public action chain ends in an affirmative clear with three meaningful replay axes, a one-line pressure summary, one actionable tip and the next/replay action.", stage_clear_ko_specification)
	if not bool(stage_clear_ko.ready):
		layout_failures.append({"captureId": "06_stage_clear_ko", "failures": ["fixture_stage_action_chain_incomplete"], "fixture": stage_clear_ko})

	show_tutorial_investigation_fixture(gs, main, "en")
	await capture_frame(main, "07_stage1_investigation_tutorial_en", "en", "English tutorial copy preserves the same compact rail, highlighted target, navigation and status spacing.", {
		"required": ["TutorialGuidanceRail", "TutorialStepCounter", "TutorialStepTitle", "TutorialStepText", "TutorialTargetOutline"],
		"counts": [{"pattern": "TutorialGuidanceRail", "type": "PanelContainer", "exact": 1}, {"pattern": "TutorialTargetOutline", "type": "PanelContainer", "exact": 1}],
		"primary": "@tutorial_target",
		"forbidden": ["target_ui_id", "route_ui_ids", "EVIDENCE_DISCOVERED"]
	})

	var listing_disclosure_en := show_listing_disclosure_fixture(gs, main, "en")
	var listing_causal_en := listing_causal_summary_evidence(gs, main, listing_disclosure_en)
	append_fixture_failures("08_listing_disclosure_en", [] if bool(listing_causal_en.get("valid", false)) else ["listing_causal_order_invalid"], listing_causal_en)
	await capture_frame(main, "08_listing_disclosure_en", "en", "English disclosure cards, exactly three ordered causal facts, calibrated hints, summary and confirmation fit inside the content region.", {
		"required": ["ListingPublicSupportBadge", "ListingDisclosure_CERTAIN", "ListingDisclosure_LIKELY", "ListingDisclosure_UNCERTAIN", "ListingCausalSummary", "ListingCausalChip_0", "ListingCausalChip_1", "ListingCausalChip_2", "ListingSummaryTile", "ListingBackToPrice", "ListingConfirmButton"],
		"minimumWidths": {"ListingCausalChip_0": 190.0, "ListingCausalChip_1": 190.0, "ListingCausalChip_2": 190.0},
		"counts": [{"pattern": "ListingDisclosure_*", "type": "Button", "exact": 3}, {"pattern": "ListingCausalChip_*", "type": "PanelContainer", "exact": 3}, {"pattern": "ListingCausalLabel", "type": "Label", "exact": 3}, {"pattern": "ListingConfirmButton", "type": "Button", "exact": 1}],
		"horizontalGaps": [{"left": "ListingCausalChip_0", "right": "ListingCausalChip_1", "minimum": 7.0}, {"left": "ListingCausalChip_1", "right": "ListingCausalChip_2", "minimum": 7.0}],
		"requiredCopy": listing_causal_en.get("expectedLabels", []),
		"singleLineTextFitPatterns": ["ListingCausalLabel"],
		"publicActionEvidence": {"method": "listing_public_status_tags -> ListingCausalChip_0..2", "causal": listing_causal_en},
		"primary": "ListingConfirmButton",
		"forbidden": ["CERTAIN", "LIKELY", "UNCERTAIN", "OVERCLAIM", "UNDERCLAIM", "CONDITION_GOOD", "PROVENANCE_STRONG", "DISCLOSURE_CLEAR", "authenticityTruth"]
	})

	var auction_en := show_sold_auction_fixture(gs, main, "en")
	var sold_en := bool(main.last_auction_result.get("reserve_met", false))
	await capture_frame(main, "09_auction_sold_reasons_en", "en", "The English cue chain preserves the same dominant primary state/action hierarchy, intermediate reason cap and one complete terminal key reason.", {
		"required": ["AuctionPrimaryState", "AuctionPrimaryText", "AuctionPrimaryAction", "AuctionCuePanel", "AuctionCuePhase", "AuctionCueProgress", "AuctionBidderColumn", "PortraitDialoguePanel_auctioneer", "AuctionResultFact", "AuctionReasonHeading", "AuctionReasonChips", "AuctionReasonLabel", "HammerButton"],
		"allowCollapsed": ["AuctionCueProgress"],
		"minimumWidths": {"AuctionPrimaryState": 400.0, "AuctionPrimaryAction": 400.0},
		"minimumHeights": {"AuctionPrimaryState": 58.0, "AuctionPrimaryAction": 40.0},
		"counts": [{"pattern": "CharacterPortrait", "type": "TextureRect", "exact": 2}, {"pattern": "AuctionPrimaryState", "type": "PanelContainer", "exact": 1}, {"pattern": "AuctionPrimaryText", "type": "Label", "exact": 1}, {"pattern": "AuctionPrimaryAction", "type": "VBoxContainer", "exact": 1}, {"pattern": "AuctionCuePanel", "type": "PanelContainer", "exact": 1}, {"pattern": "AuctionCueNext", "type": "Button", "exact": 0}, {"pattern": "AuctionReasonChip_*", "type": "PanelContainer", "exact": 1}, {"pattern": "AuctionReasonLabel", "type": "Label", "exact": 1}, {"pattern": "HammerButton", "type": "Button", "exact": 1}],
		"reactionSettleMilliseconds": 180,
		"postReactionFrames": 2,
		"portraitReactionCount": 2,
		"stableGeometryPatterns": ["ContentMargin", "Navigation", "StatusMessage", "PortraitDialoguePanel_*", "PortraitStack", "CharacterDialogue", "CharacterFactLabel", "CharacterSemanticState", "AuctionPrimaryState", "AuctionPrimaryText", "AuctionPrimaryAction", "AuctionCuePanel", "AuctionCuePhase", "AuctionCueProgress", "AuctionBidderColumn", "AuctionResultFact", "AuctionReasonChips", "HammerButton"],
		"verticalGaps": [{"above": "AuctionPrimaryState", "below": "AuctionPrimaryAction", "minimum": 0.0, "maximum": 16.0}, {"above": "AuctionPrimaryAction", "below": "AuctionCuePanel", "minimum": 0.0, "maximum": 16.0}],
		"horizontalGaps": [{"left": "AuctionPrimaryState", "right": "AuctionBidderColumn", "minimum": 12.0}, {"left": "AuctionBidderColumn", "right": "PortraitDialoguePanel_auctioneer", "minimum": 12.0}],
		"noOverlapPairs": [["AuctionPrimaryState", "AuctionPrimaryAction"], ["AuctionPrimaryAction", "AuctionCuePanel"], ["HammerButton", "AuctionBidderColumn"], ["AuctionPrimaryAction", "PortraitDialoguePanel_auctioneer"], ["AuctionBidderColumn", "PortraitDialoguePanel_auctioneer"]],
		"singleLineTextFitPatterns": ["AuctionPrimaryText", "AuctionReasonLabel"],
		"requiredCopy": [main.auction_phase_label(String(auction_en.get("final", {}).get("phase", ""))), "%d / %d" % [int(auction_en.get("final", {}).get("index", -1)) + 1, int(auction_en.get("final", {}).get("total", 0))]],
		"publicActionEvidence": {"method": "auction_public_cue_state + advance_auction_cue", "states": auction_en.get("states", []), "valid": auction_en.get("valid", false)},
		"primary": "HammerButton",
		"forbidden": ["PROVENANCE_STRONG", "CONDITION_GOOD", "DISCLOSURE_CLEAR", "winnerId", "maxBid"]
	})
	if not sold_en or not bool(auction_en.get("valid", false)):
		layout_failures.append({"captureId": "09_auction_sold_reasons_en", "failures": ["fixture_not_sold_or_public_chain_invalid"], "fixture": auction_en})

	var report_ko := show_report_ready_fixture(gs, main, "ko")
	await capture_frame(main, "10_stage1_report_ready_ko", "ko", "Korean Stage 1 report guidance keeps the selected hypothesis, citation, full-width prompt and enabled report CTA in one frame.", {
		"required": ["CaseDossierScroll", "CaseDossierRows", "TutorialGuidanceRail", "CaseReportPrompt", "CaseHypothesis_%s" % String(report_ko.hypothesisId).validate_node_name(), "ReportCitationRemove_%s" % String(report_ko.evidenceId).validate_node_name(), "ResolveCaseReport"],
		"allowClipped": ["CaseDossierRows"],
		"minimumWidths": {"CaseDossierRows": 1180.0, "CaseReportPrompt": 900.0},
		"counts": [{"pattern": "TutorialGuidanceRail", "type": "PanelContainer", "exact": 1}, {"pattern": "CaseReportPrompt", "type": "Label", "exact": 1}, {"pattern": "ResolveCaseReport", "type": "Button", "exact": 1}],
		"primary": "@tutorial_target",
		"forbidden": ["target_ui_id", "route_ui_ids", "hyp.period_repair", "src.prologue"]
	})
	if not bool(report_ko.ready):
		layout_failures.append({"captureId": "10_stage1_report_ready_ko", "failures": ["fixture_not_report_ready"]})

	var report_en := show_report_ready_fixture(gs, main, "en")
	await capture_frame(main, "11_stage1_report_ready_en", "en", "English Stage 1 report guidance keeps the selected hypothesis, citation, wrapped prompt and enabled report CTA in one frame.", {
		"required": ["CaseDossierScroll", "CaseDossierRows", "TutorialGuidanceRail", "CaseReportPrompt", "CaseHypothesis_%s" % String(report_en.hypothesisId).validate_node_name(), "ReportCitationRemove_%s" % String(report_en.evidenceId).validate_node_name(), "ResolveCaseReport"],
		"allowClipped": ["CaseDossierRows"],
		"minimumWidths": {"CaseDossierRows": 1180.0, "CaseReportPrompt": 900.0},
		"counts": [{"pattern": "TutorialGuidanceRail", "type": "PanelContainer", "exact": 1}, {"pattern": "CaseReportPrompt", "type": "Label", "exact": 1}, {"pattern": "ResolveCaseReport", "type": "Button", "exact": 1}],
		"primary": "@tutorial_target",
		"forbidden": ["target_ui_id", "route_ui_ids", "hyp.period_repair", "src.prologue"]
	})
	if not bool(report_en.ready):
		layout_failures.append({"captureId": "11_stage1_report_ready_en", "failures": ["fixture_not_report_ready"]})

	var repair_ko := show_repair_ready_fixture(gs, main, "ko")
	await capture_frame(main, "12_stage1_repair_ready_ko", "ko", "Korean Stage 1 repair guidance shows the selected recommended tool, repair trade-off and highlighted repair action together.", {
		"required": ["TutorialGuidanceRail", "InspectionInfoColumn", "InspectionControlsColumn", "InspectionClueGrid", "RepairToolAnyOneHint", "RepairToolGrid", "RepairTool_%s" % String(repair_ko.requiredTool), "RepairTradeoffTile", "Tool_repair", "AuthenticateButton", "OpenCaseDossier"],
		"counts": [{"pattern": "TutorialGuidanceRail", "type": "PanelContainer", "exact": 1}, {"pattern": "RepairTool_*", "type": "Button", "minimum": 1, "maximum": 3}, {"pattern": "Tool_repair", "type": "Button", "exact": 1}],
		"primary": "@tutorial_target",
		"horizontalGaps": [{"left": "InspectionInfoColumn", "right": "InspectionControlsColumn", "minimum": 12.0}],
		"forbidden": ["REPAIR_COMPLETED", "requiredTools", "repairProfile"]
	})
	if not bool(repair_ko.ready):
		layout_failures.append({"captureId": "12_stage1_repair_ready_ko", "failures": ["fixture_not_repair_ready"]})

	var repair_en := show_repair_ready_fixture(gs, main, "en")
	await capture_frame(main, "13_stage1_repair_ready_en", "en", "English Stage 1 repair guidance preserves the same selected-tool and highlighted repair-action density contract.", {
		"required": ["TutorialGuidanceRail", "InspectionInfoColumn", "InspectionControlsColumn", "InspectionClueGrid", "RepairToolAnyOneHint", "RepairToolGrid", "RepairTool_%s" % String(repair_en.requiredTool), "RepairTradeoffTile", "Tool_repair", "AuthenticateButton", "OpenCaseDossier"],
		"counts": [{"pattern": "TutorialGuidanceRail", "type": "PanelContainer", "exact": 1}, {"pattern": "RepairTool_*", "type": "Button", "minimum": 1, "maximum": 3}, {"pattern": "Tool_repair", "type": "Button", "exact": 1}],
		"primary": "@tutorial_target",
		"horizontalGaps": [{"left": "InspectionInfoColumn", "right": "InspectionControlsColumn", "minimum": 12.0}],
		"forbidden": ["REPAIR_COMPLETED", "requiredTools", "repairProfile"]
	})
	if not bool(repair_en.ready):
		layout_failures.append({"captureId": "13_stage1_repair_ready_en", "failures": ["fixture_not_repair_ready"]})

	var market_lot := show_market_offer_fixture(gs, main, "ko")
	await capture_frame(main, "14_market_shopkeeper_offer_ko", "ko", "A Korean shop offer shows the big-eyed shopkeeper bust, two-line speech, lot price and separate offer/purchase actions without overlap.", {
		"required": ["CharacterPortrait", "CharacterDialogue", "CharacterFactLabel", "CharacterSemanticState", "MarketOffer_0", "MarketLot_0"],
		"minimumWidths": {"CharacterPortrait": 180.0, "CharacterDialogue": 180.0, "CharacterFactLabel": 180.0},
		"minimumHeights": {"CharacterPortrait": 180.0},
		"counts": [{"pattern": "CharacterPortrait", "type": "TextureRect", "exact": 1}, {"pattern": "CharacterDialogue", "type": "Label", "exact": 1}, {"pattern": "CharacterFactLabel", "type": "Label", "exact": 1}],
		"reactionSettleMilliseconds": 180,
		"postReactionFrames": 2,
		"portraitReactionCount": 1,
		"stableGeometryPatterns": ["ContentMargin", "Navigation", "StatusMessage", "PortraitDialoguePanel_*", "PortraitStack", "CharacterDialogue", "CharacterFactLabel", "CharacterSemanticState", "MarketOffer_*", "MarketLot_*"],
		"maxLines": [{"name": "CharacterDialogue", "maximum": 2}],
		"noOverlapPairs": [["CharacterPortrait", "MarketOffer_0"], ["CharacterPortrait", "MarketLot_0"]],
		"requiredCopy": ["¤%d" % int(market_lot.get("price", -1))],
		"textureRequirements": ["CharacterPortrait"],
		"forbidden": ["shopkeeper", "auctionProfile", "lotId"]
	})
	if market_lot.is_empty():
		layout_failures.append({"captureId": "14_market_shopkeeper_offer_ko", "failures": ["fixture_missing_market_lot"]})

	var event_result := show_event_result_fixture(gs, main, "ko")
	var event_fact: String = String(main.event_effect_fact(event_result.get("effect", {}), float(event_result.get("appliedAmount", 0.0)))) if not event_result.is_empty() else ""
	await capture_frame(main, "15_event_npc_result_ko", "ko", "A Korean activated event result shows the mapped big-eyed event NPC, two-line reaction, localized effect fact and one market continuation action.", {
		"required": ["CharacterPortrait", "CharacterDialogue", "CharacterFactLabel", "CharacterSemanticState", "EventContinueMarket"],
		"minimumWidths": {"CharacterPortrait": 220.0, "CharacterDialogue": 220.0, "CharacterFactLabel": 220.0},
		"minimumHeights": {"CharacterPortrait": 210.0},
		"counts": [{"pattern": "CharacterPortrait", "type": "TextureRect", "exact": 1}, {"pattern": "CharacterDialogue", "type": "Label", "exact": 1}, {"pattern": "CharacterFactLabel", "type": "Label", "exact": 1}, {"pattern": "EventContinueMarket", "type": "Button", "exact": 1}],
		"reactionSettleMilliseconds": 180,
		"postReactionFrames": 2,
		"portraitReactionCount": 1,
		"stableGeometryPatterns": ["ContentMargin", "Navigation", "StatusMessage", "PortraitDialoguePanel_*", "PortraitStack", "CharacterDialogue", "CharacterFactLabel", "CharacterSemanticState", "EventContinueMarket"],
		"maxLines": [{"name": "CharacterDialogue", "maximum": 2}],
		"noOverlapPairs": [["CharacterPortrait", "EventContinueMarket"]],
		"primary": "EventContinueMarket",
		"requiredCopy": [event_fact],
		"textureRequirements": ["CharacterPortrait"],
		"forbidden": ["storage_damage", "market_modifier", "eventId", "outcomePolarity"]
	})
	if event_result.is_empty():
		layout_failures.append({"captureId": "15_event_npc_result_ko", "failures": ["fixture_missing_event"]})

	var stage_clear_en := show_stage_clear_fixture(gs, main, "en")
	var stage_pressure_en := stage_pressure_evidence(gs, main)
	append_fixture_failures("16_stage_clear_replay_en", [] if bool(stage_pressure_en.get("valid", false)) else ["stage_pressure_contract_invalid"], stage_pressure_en)
	var stage_clear_en_specification := with_stage_pressure_contract({
		"required": ["StageProgressScore", "StageProgressCases", "StageClearCard", "StageClearHeading", "StageClearScore", "StageClearTarget", "StageClearUnlock", "StageClearBest", "StageReplayAxes", "StageReplayAxis_investigation", "StageReplayAxis_preservation", "StageReplayAxis_sale", "StageReplayAxisScore_investigation", "StageReplayAxisScore_preservation", "StageReplayAxisScore_sale", "StageClearAdvice", "CampaignStageSelect"],
		"counts": [{"pattern": "StageClearCard", "type": "PanelContainer", "exact": 1}, {"pattern": "StageReplayAxis_*", "type": "PanelContainer", "exact": 3}, {"pattern": "StageClearAdvice", "type": "Label", "exact": 1}, {"pattern": "CampaignStageSelect", "type": "Button", "exact": 1}],
		"primary": "CampaignStageSelect",
		"forbidden": ["FAILED", "FAILURE", "performance_target", "STRENGTHEN_EVIDENCE", "PROTECT_CONDITION", "IMPROVE_SALE"]
	}, stage_pressure_en, "CampaignStageSelect")
	await capture_frame(main, "16_stage_clear_replay_en", "en", "The same real Stage 1 public action chain shows three localized replay axes, a one-line pressure summary, one actionable tip and the replay/next action in English.", stage_clear_en_specification)
	if not bool(stage_clear_en.ready):
		layout_failures.append({"captureId": "16_stage_clear_replay_en", "failures": ["fixture_stage_action_chain_incomplete"], "fixture": stage_clear_en})

	var grand_reserve_fixture := prepare_grand_reserve_fixture(gs, main, registry, "ko")
	var eligible_final_value: Variant = grand_reserve_fixture.get("eligible", [])
	var eligible_final: Array = eligible_final_value if eligible_final_value is Array else []
	var final_selection_tokens := final_journey_forbidden_tokens(artifact_internal_tokens(eligible_final))
	var final_selection_ko := final_selection_semantic_evidence(gs, main)
	var final_selection_ko_failures: Array = []
	if not bool(grand_reserve_fixture.get("ok", false)):
		final_selection_ko_failures.append("final_selection_fixture_not_ready")
	if String(final_selection_ko.get("screen", "")) != "final_selection":
		final_selection_ko_failures.append("final_selection_screen_missing")
	if int(final_selection_ko.get("cardCount", 0)) < 3 or int(final_selection_ko.get("cardCount", 0)) > 6:
		final_selection_ko_failures.append("final_selection_card_count_invalid")
	if int(final_selection_ko.get("nameCount", -1)) != int(final_selection_ko.get("cardCount", 0)) \
		or int(final_selection_ko.get("valueCount", -1)) != int(final_selection_ko.get("cardCount", 0)) \
		or int(final_selection_ko.get("badgeRowCount", -1)) != int(final_selection_ko.get("cardCount", 0)) \
		or int(final_selection_ko.get("toggleCount", -1)) != int(final_selection_ko.get("cardCount", 0)):
		final_selection_ko_failures.append("final_selection_card_child_contract_invalid")
	if int(final_selection_ko.get("selectedCount", -1)) != 0 or not bool(final_selection_ko.get("beginDisabled", false)):
		final_selection_ko_failures.append("final_selection_initial_authority_invalid")
	if not String(final_selection_ko.get("progressText", "")).replace(" ", "").contains("0/3"):
		final_selection_ko_failures.append("final_selection_initial_progress_invalid")
	append_fixture_failures("20_final_selection_ko", final_selection_ko_failures, {
		"fixture": grand_reserve_fixture,
		"semantic": final_selection_ko
	})
	var final_selection_ko_copy := visible_copy(main)
	await capture_frame(main, "20_final_selection_ko", "ko", "The Korean Grand Reserve selection gate shows zero of three selected, three to six compact illustrated lot cards, one short requirement and a visible disabled Begin action before any auction starts.", {
		"required": ["FinalSelectionProgress", "FinalLotGrid", "FinalLotCard_0", "FinalLotCard_1", "FinalLotCard_2", "FinalLotName", "FinalLotValue", "FinalLotBadgeRow", "FinalLotToggle", "FinalSelectionRequirement", "BeginGrandReserve"],
		"minimumWidths": {"FinalSelectionProgress": 420.0, "FinalLotGrid": 1100.0, "FinalLotCard_0": 360.0, "FinalLotCard_1": 360.0, "FinalLotCard_2": 360.0, "FinalSelectionRequirement": 500.0, "BeginGrandReserve": 360.0},
		"minimumHeights": {"FinalLotGrid": 280.0, "FinalLotCard_0": 130.0, "FinalLotCard_1": 130.0, "FinalLotCard_2": 130.0, "BeginGrandReserve": 48.0},
		"counts": [{"pattern": "FinalLotCard_*", "type": "PanelContainer", "minimum": 3, "maximum": 6}, {"pattern": "FinalLotName", "type": "Label", "minimum": 3, "maximum": 6}, {"pattern": "FinalLotValue", "type": "Label", "minimum": 3, "maximum": 6}, {"pattern": "FinalLotBadgeRow", "type": "HBoxContainer", "minimum": 3, "maximum": 6}, {"pattern": "FinalLotToggle", "type": "Button", "minimum": 3, "maximum": 6}, {"pattern": "FinalLotBadge_*", "type": "PanelContainer", "minimum": 6, "maximum": 12}, {"pattern": "BeginGrandReserve", "type": "Button", "exact": 1}],
		"maxLines": [{"name": "FinalSelectionProgress", "maximum": 1}, {"name": "FinalLotName", "maximum": 1}, {"name": "FinalLotValue", "maximum": 1}, {"name": "FinalSelectionRequirement", "maximum": 1}],
		"noOverlapPairs": [["FinalSelectionProgress", "FinalLotGrid"], ["FinalLotCard_0", "FinalLotCard_1"], ["FinalLotCard_1", "FinalLotCard_2"], ["FinalLotGrid", "FinalSelectionRequirement"], ["FinalSelectionRequirement", "BeginGrandReserve"]],
		"singleLineTextFitPatterns": ["FinalSelectionProgress", "FinalLotName", "FinalLotValue", "FinalSelectionRequirement"],
		"requiredCopy": [String(final_selection_ko.get("progressText", ""))],
		"textureRequirements": ["FinalLotIcon"],
		"publicActionEvidence": {"method": "show_final_lot_selection after the real Stage 10 case path", "semantic": final_selection_ko},
		"forbidden": final_selection_tokens
	})

	var selection_chain: Dictionary = await select_three_final_lots_from_ui(gs, main, grand_reserve_fixture.get("lotUids", []))
	var final_selection_to_en: Dictionary = await locale_toggle_with_authority_evidence(gs, main, "en")
	var final_selection_en := final_selection_semantic_evidence(gs, main)
	var final_selection_en_copy := visible_copy(main)
	var final_selection_en_failures: Array = []
	if not bool(selection_chain.get("valid", false)):
		final_selection_en_failures.append("final_selection_public_toggle_chain_invalid")
	if not bool(final_selection_to_en.get("valid", false)):
		final_selection_en_failures.append("final_selection_locale_authority_mutated")
	if int(final_selection_en.get("selectedCount", -1)) != 3 or bool(final_selection_en.get("beginDisabled", true)):
		final_selection_en_failures.append("final_selection_ready_authority_invalid")
	if not String(final_selection_en.get("progressText", "")).replace(" ", "").contains("3/3"):
		final_selection_en_failures.append("final_selection_ready_progress_invalid")
	if final_selection_ko_copy == final_selection_en_copy:
		final_selection_en_failures.append("final_selection_locale_copy_unchanged")
	append_fixture_failures("21_final_selection_en", final_selection_en_failures, {
		"selectionChain": selection_chain,
		"localeToggle": final_selection_to_en,
		"semantic": final_selection_en
	})
	await capture_frame(main, "21_final_selection_en", "en", "The English refresh keeps the same exact three selected lots and enabled Begin action while all gameplay/profile/save authority remains mutation-zero apart from locale.", {
		"required": ["FinalSelectionProgress", "FinalLotGrid", "FinalLotCard_0", "FinalLotCard_1", "FinalLotCard_2", "FinalLotName", "FinalLotValue", "FinalLotBadgeRow", "FinalLotToggle", "FinalSelectionRequirement", "BeginGrandReserve"],
		"minimumWidths": {"FinalSelectionProgress": 420.0, "FinalLotGrid": 1100.0, "FinalLotCard_0": 360.0, "FinalLotCard_1": 360.0, "FinalLotCard_2": 360.0, "FinalSelectionRequirement": 500.0, "BeginGrandReserve": 360.0},
		"minimumHeights": {"FinalLotGrid": 280.0, "FinalLotCard_0": 130.0, "FinalLotCard_1": 130.0, "FinalLotCard_2": 130.0, "BeginGrandReserve": 48.0},
		"counts": [{"pattern": "FinalLotCard_*", "type": "PanelContainer", "minimum": 3, "maximum": 6}, {"pattern": "FinalLotName", "type": "Label", "minimum": 3, "maximum": 6}, {"pattern": "FinalLotValue", "type": "Label", "minimum": 3, "maximum": 6}, {"pattern": "FinalLotBadgeRow", "type": "HBoxContainer", "minimum": 3, "maximum": 6}, {"pattern": "FinalLotToggle", "type": "Button", "minimum": 3, "maximum": 6}, {"pattern": "FinalLotBadge_*", "type": "PanelContainer", "minimum": 6, "maximum": 12}, {"pattern": "BeginGrandReserve", "type": "Button", "exact": 1}],
		"maxLines": [{"name": "FinalSelectionProgress", "maximum": 1}, {"name": "FinalLotName", "maximum": 1}, {"name": "FinalLotValue", "maximum": 1}, {"name": "FinalSelectionRequirement", "maximum": 1}],
		"noOverlapPairs": [["FinalSelectionProgress", "FinalLotGrid"], ["FinalLotCard_0", "FinalLotCard_1"], ["FinalLotCard_1", "FinalLotCard_2"], ["FinalLotGrid", "FinalSelectionRequirement"], ["FinalSelectionRequirement", "BeginGrandReserve"]],
		"singleLineTextFitPatterns": ["FinalSelectionProgress", "FinalLotName", "FinalLotValue", "FinalSelectionRequirement"],
		"requiredCopy": [String(final_selection_en.get("progressText", ""))],
		"textureRequirements": ["FinalLotIcon"],
		"publicActionEvidence": {"method": "3 x FinalLotToggle.pressed + LANGUAGE", "selectionChain": selection_chain, "localeToggle": final_selection_to_en, "semantic": final_selection_en},
		"primary": "BeginGrandReserve",
		"forbidden": final_selection_tokens
	})

	var final_selection_to_ko: Dictionary = await locale_toggle_with_authority_evidence(gs, main, "ko")
	var begin_grand_reserve := press_visible_button(main, "BeginGrandReserve")
	await settle_ui(8)
	var started_session: Dictionary = gs.grand_reserve_public_state()
	grand_reserve_fixture["selectionChain"] = selection_chain
	grand_reserve_fixture["returnToKorean"] = final_selection_to_ko
	grand_reserve_fixture["beginPressed"] = begin_grand_reserve
	grand_reserve_fixture["session"] = started_session
	grand_reserve_fixture["ok"] = bool(grand_reserve_fixture.get("ok", false)) \
		and bool(selection_chain.get("valid", false)) \
		and bool(final_selection_to_ko.get("valid", false)) \
		and begin_grand_reserve \
		and String(started_session.get("phase", "")) == "AUCTION_PENDING" \
		and int(started_session.get("currentLotIndex", -1)) == 0 \
		and String(main.screen) == "auction"
	var grand_reserve_lot1_chain := drive_current_public_auction_to_final(main)
	var grand_reserve_pending := grand_reserve_semantic_evidence(gs, main)
	var grand_reserve_pending_failures := grand_reserve_state_failures(grand_reserve_pending, "AUCTION_PENDING", 0, 0, "auction")
	if not bool(grand_reserve_fixture.get("ok", false)):
		grand_reserve_pending_failures.append("grand_reserve_fixture_not_ready")
	if not bool(grand_reserve_lot1_chain.get("valid", false)):
		grand_reserve_pending_failures.append("grand_reserve_lot1_public_cue_chain_invalid")
	if not bool(grand_reserve_pending.get("cueFinal", false)) or String(grand_reserve_pending.get("pendingStatus", "")) != "PENDING":
		grand_reserve_pending_failures.append("grand_reserve_lot1_not_pending_at_final_cue")
	if not bool(grand_reserve_lot1_chain.get("result", {}).get("reserve_met", false)):
		grand_reserve_pending_failures.append("grand_reserve_lot1_expected_sold")
	append_fixture_failures("17_grand_reserve_lot1_pending_ko", grand_reserve_pending_failures, {
		"fixture": grand_reserve_fixture,
		"chain": grand_reserve_lot1_chain,
		"semantic": grand_reserve_pending
	})
	await capture_frame(main, "17_grand_reserve_lot1_pending_ko", "ko", "Grand Reserve lot 1 stays AUCTION_PENDING at its final cue with one dominant SOLD state, nearby Hammer action, exactly one terminal key reason, active bidder and auctioneer.", {
		"required": ["GrandReserveProgress", "AuctionPrimaryState", "AuctionPrimaryText", "AuctionPrimaryAction", "AuctionCuePanel", "AuctionCuePhase", "AuctionCueProgress", "PortraitDialoguePanel_auctioneer", "AuctionBidderColumn", "AuctionResultFact", "AuctionReasonHeading", "AuctionReasonChips", "AuctionReasonLabel", "HammerButton"],
		"allowCollapsed": ["AuctionCueProgress"],
		"minimumWidths": {"GrandReserveProgress": 700.0, "AuctionPrimaryState": 400.0, "AuctionPrimaryAction": 400.0, "PortraitDialoguePanel_auctioneer": 220.0, "AuctionBidderColumn": 260.0, "CharacterPortrait": 190.0},
		"minimumHeights": {"AuctionPrimaryState": 58.0, "AuctionPrimaryAction": 40.0, "CharacterPortrait": 220.0, "HammerButton": 40.0},
		"counts": [{"pattern": "CharacterPortrait", "type": "TextureRect", "exact": 2}, {"pattern": "PortraitDialoguePanel_*", "type": "PanelContainer", "exact": 2}, {"pattern": "AuctionPrimaryState", "type": "PanelContainer", "exact": 1}, {"pattern": "AuctionPrimaryText", "type": "Label", "exact": 1}, {"pattern": "AuctionPrimaryAction", "type": "VBoxContainer", "exact": 1}, {"pattern": "AuctionReasonChip_*", "type": "PanelContainer", "exact": 1}, {"pattern": "AuctionReasonLabel", "type": "Label", "exact": 1}, {"pattern": "AuctionCueNext", "type": "Button", "exact": 0}, {"pattern": "GrandReserveNextLot", "type": "Button", "exact": 0}, {"pattern": "HammerButton", "type": "Button", "exact": 1}],
		"reactionSettleMilliseconds": 180,
		"postReactionFrames": 2,
		"portraitReactionCount": 2,
		"stableGeometryPatterns": ["ContentMargin", "Navigation", "StatusMessage", "GrandReserveProgress", "PortraitDialoguePanel_*", "PortraitStack", "CharacterDialogue", "CharacterFactLabel", "CharacterSemanticState", "AuctionPrimaryState", "AuctionPrimaryText", "AuctionPrimaryAction", "AuctionCuePanel", "AuctionCuePhase", "AuctionCueProgress", "AuctionBidderColumn", "AuctionResultFact", "AuctionReasonChips", "HammerButton"],
		"maxLines": [{"name": "CharacterDialogue", "maximum": 2}],
		"verticalGaps": [{"above": "AuctionPrimaryState", "below": "AuctionPrimaryAction", "minimum": 0.0, "maximum": 16.0}, {"above": "AuctionPrimaryAction", "below": "AuctionCuePanel", "minimum": 0.0, "maximum": 16.0}],
		"horizontalGaps": [{"left": "AuctionPrimaryState", "right": "AuctionBidderColumn", "minimum": 12.0}, {"left": "AuctionBidderColumn", "right": "PortraitDialoguePanel_auctioneer", "minimum": 12.0}],
		"noOverlapPairs": [["AuctionPrimaryState", "AuctionPrimaryAction"], ["AuctionPrimaryAction", "AuctionCuePanel"], ["HammerButton", "PortraitDialoguePanel_auctioneer"], ["HammerButton", "AuctionBidderColumn"], ["AuctionPrimaryAction", "PortraitDialoguePanel_auctioneer"], ["AuctionBidderColumn", "PortraitDialoguePanel_auctioneer"], ["GrandReserveProgress", "AuctionCuePanel"]],
		"singleLineTextFitPatterns": ["AuctionPrimaryText", "AuctionReasonLabel"],
		"requiredCopy": [String(grand_reserve_pending.get("progressText", "")), String(grand_reserve_pending.get("resultText", ""))],
		"textureRequirements": ["CharacterPortrait"],
		"publicActionEvidence": {"method": "run_grand_reserve_from_ui + auction_public_cue_state + advance_auction_cue", "chain": grand_reserve_lot1_chain, "semantic": grand_reserve_pending},
		"primary": "HammerButton",
		"forbidden": ["AUCTION_PENDING", "BETWEEN_LOTS", "FINALIZED", "winnerId", "maxBid", "PROVENANCE_STRONG", "CONDITION_GOOD", "DISCLOSURE_CLEAR"]
	})

	var grand_reserve_lot1_hammer := press_visible_button(main, "HammerButton")
	var grand_reserve_between := grand_reserve_semantic_evidence(gs, main)
	var grand_reserve_between_failures := grand_reserve_state_failures(grand_reserve_between, "BETWEEN_LOTS", 0, 1, "auction")
	if not grand_reserve_lot1_hammer:
		grand_reserve_between_failures.append("grand_reserve_lot1_hammer_unavailable")
	if String(grand_reserve_between.get("pendingStatus", "")) != "COMMITTED" or grand_reserve_between.get("receiptStatuses", []) != ["SOLD"]:
		grand_reserve_between_failures.append("grand_reserve_lot1_commit_semantics_invalid")
	append_fixture_failures("18_grand_reserve_between_lots_ko", grand_reserve_between_failures, grand_reserve_between)
	await capture_frame(main, "18_grand_reserve_between_lots_ko", "ko", "After lot 1 Hammer, the committed SOLD primary state remains beside one nearby NEXT LOT action and exactly one terminal key reason while progress advances to lot 2.", {
		"required": ["GrandReserveProgress", "AuctionPrimaryState", "AuctionPrimaryText", "AuctionPrimaryAction", "AuctionCuePanel", "AuctionCuePhase", "AuctionCueProgress", "PortraitDialoguePanel_auctioneer", "AuctionBidderColumn", "AuctionResultFact", "AuctionReasonHeading", "AuctionReasonChips", "AuctionReasonLabel", "GrandReserveNextLot"],
		"allowCollapsed": ["AuctionCueProgress"],
		"minimumWidths": {"GrandReserveProgress": 700.0, "AuctionPrimaryState": 400.0, "AuctionPrimaryAction": 400.0, "PortraitDialoguePanel_auctioneer": 220.0, "AuctionBidderColumn": 260.0, "CharacterPortrait": 190.0},
		"minimumHeights": {"AuctionPrimaryState": 58.0, "AuctionPrimaryAction": 40.0, "CharacterPortrait": 220.0, "GrandReserveNextLot": 40.0},
		"counts": [{"pattern": "CharacterPortrait", "type": "TextureRect", "exact": 2}, {"pattern": "PortraitDialoguePanel_*", "type": "PanelContainer", "exact": 2}, {"pattern": "AuctionPrimaryState", "type": "PanelContainer", "exact": 1}, {"pattern": "AuctionPrimaryText", "type": "Label", "exact": 1}, {"pattern": "AuctionPrimaryAction", "type": "VBoxContainer", "exact": 1}, {"pattern": "AuctionReasonChip_*", "type": "PanelContainer", "exact": 1}, {"pattern": "AuctionReasonLabel", "type": "Label", "exact": 1}, {"pattern": "AuctionCueNext", "type": "Button", "exact": 0}, {"pattern": "HammerButton", "type": "Button", "exact": 0}, {"pattern": "GrandReserveNextLot", "type": "Button", "exact": 1}],
		"reactionSettleMilliseconds": 180,
		"postReactionFrames": 2,
		"portraitReactionCount": 2,
		"stableGeometryPatterns": ["ContentMargin", "Navigation", "StatusMessage", "GrandReserveProgress", "PortraitDialoguePanel_*", "PortraitStack", "CharacterDialogue", "CharacterFactLabel", "CharacterSemanticState", "AuctionPrimaryState", "AuctionPrimaryText", "AuctionPrimaryAction", "AuctionCuePanel", "AuctionCuePhase", "AuctionCueProgress", "AuctionBidderColumn", "AuctionResultFact", "AuctionReasonChips", "GrandReserveNextLot"],
		"maxLines": [{"name": "CharacterDialogue", "maximum": 2}],
		"verticalGaps": [{"above": "AuctionPrimaryState", "below": "AuctionPrimaryAction", "minimum": 0.0, "maximum": 16.0}, {"above": "AuctionPrimaryAction", "below": "AuctionCuePanel", "minimum": 0.0, "maximum": 16.0}],
		"horizontalGaps": [{"left": "AuctionPrimaryState", "right": "AuctionBidderColumn", "minimum": 12.0}, {"left": "AuctionBidderColumn", "right": "PortraitDialoguePanel_auctioneer", "minimum": 12.0}],
		"noOverlapPairs": [["AuctionPrimaryState", "AuctionPrimaryAction"], ["AuctionPrimaryAction", "AuctionCuePanel"], ["GrandReserveNextLot", "PortraitDialoguePanel_auctioneer"], ["GrandReserveNextLot", "AuctionBidderColumn"], ["AuctionPrimaryAction", "PortraitDialoguePanel_auctioneer"], ["AuctionBidderColumn", "PortraitDialoguePanel_auctioneer"], ["GrandReserveProgress", "AuctionCuePanel"]],
		"singleLineTextFitPatterns": ["AuctionPrimaryText", "AuctionReasonLabel"],
		"requiredCopy": [String(grand_reserve_between.get("progressText", "")), String(grand_reserve_between.get("resultText", ""))],
		"textureRequirements": ["CharacterPortrait"],
		"publicActionEvidence": {"method": "HammerButton.pressed -> commit_grand_reserve_lot", "semantic": grand_reserve_between},
		"primary": "GrandReserveNextLot",
		"forbidden": ["AUCTION_PENDING", "BETWEEN_LOTS", "FINALIZED", "winnerId", "maxBid", "PROVENANCE_STRONG", "CONDITION_GOOD", "DISCLOSURE_CLEAR"]
	})

	var grand_reserve_next1 := press_visible_button(main, "GrandReserveNextLot")
	var grand_reserve_lot2_chain := drive_current_public_auction_to_final(main)
	var grand_reserve_lot2_hammer := press_visible_button(main, "HammerButton")
	var grand_reserve_between2 := grand_reserve_semantic_evidence(gs, main)
	var grand_reserve_next2 := press_visible_button(main, "GrandReserveNextLot")
	var grand_reserve_lot3_chain := drive_current_public_auction_to_final(main)
	var grand_reserve_lot3_hammer := press_visible_button(main, "HammerButton")
	var grand_reserve_final := grand_reserve_semantic_evidence(gs, main)
	var grand_reserve_final_failures := grand_reserve_state_failures(grand_reserve_final, "FINALIZED", 2, 3, "campaign")
	if not grand_reserve_next1 or not grand_reserve_lot2_hammer or not grand_reserve_next2 or not grand_reserve_lot3_hammer:
		grand_reserve_final_failures.append("grand_reserve_public_button_chain_incomplete")
	if not bool(grand_reserve_lot2_chain.get("valid", false)) or not bool(grand_reserve_lot3_chain.get("valid", false)):
		grand_reserve_final_failures.append("grand_reserve_later_public_cue_chain_invalid")
	if bool(grand_reserve_lot2_chain.get("result", {}).get("reserve_met", true)) or not bool(grand_reserve_lot3_chain.get("result", {}).get("reserve_met", false)):
		grand_reserve_final_failures.append("grand_reserve_expected_sold_no_sale_sold_pattern_missing")
	if String(grand_reserve_between2.get("phase", "")) != "BETWEEN_LOTS" or int(grand_reserve_between2.get("currentLotIndex", -1)) != 1 or int(grand_reserve_between2.get("receiptCount", -1)) != 2:
		grand_reserve_final_failures.append("grand_reserve_lot2_between_boundary_missing")
	if String(grand_reserve_final.get("stageStatus", "")) != "CLEARED" or not bool(grand_reserve_final.get("stageClearPending", false)) or String(grand_reserve_final.get("ending", "")).is_empty():
		grand_reserve_final_failures.append("grand_reserve_stage10_handoff_incomplete")
	var stage_pressure_10 := stage_pressure_evidence(gs, main)
	if not bool(stage_pressure_10.get("valid", false)):
		grand_reserve_final_failures.append("stage_pressure_contract_invalid")
	append_fixture_failures("19_stage10_clear_view_ending_ko", grand_reserve_final_failures, {
		"semantic": grand_reserve_final,
		"lot2Between": grand_reserve_between2,
		"lot2Chain": grand_reserve_lot2_chain,
		"lot3Chain": grand_reserve_lot3_chain,
		"stagePressure": stage_pressure_10
	})
	var stage_clear_10_specification := with_stage_pressure_contract({
		"required": ["StageProgressScore", "StageProgressCases", "StageClearCard", "StageClearHeading", "StageClearScore", "StageClearTarget", "StageClearUnlock", "StageClearBest", "StageReplayAxes", "StageReplayAxis_investigation", "StageReplayAxis_preservation", "StageReplayAxis_sale", "StageReplayAxisScore_investigation", "StageReplayAxisScore_preservation", "StageReplayAxisScore_sale", "StageClearAdvice", "StageClearViewEnding"],
		"minimumWidths": {"StageClearCard": 900.0, "StageClearViewEnding": 300.0},
		"minimumHeights": {"StageClearViewEnding": 52.0},
		"counts": [{"pattern": "StageClearCard", "type": "PanelContainer", "exact": 1}, {"pattern": "StageReplayAxis_*", "type": "PanelContainer", "exact": 3}, {"pattern": "StageClearAdvice", "type": "Label", "exact": 1}, {"pattern": "StageClearViewEnding", "type": "Button", "exact": 1}, {"pattern": "GrandReserveProgress", "type": "Label", "exact": 0}, {"pattern": "GrandReserveNextLot", "type": "Button", "exact": 0}],
		"noOverlapPairs": [["StageClearViewEnding", "StageClearCard"]],
		"publicActionEvidence": {"method": "3 x HammerButton.pressed + 2 x GrandReserveNextLot.pressed", "lot1": grand_reserve_lot1_chain, "lot2": grand_reserve_lot2_chain, "lot3": grand_reserve_lot3_chain, "semantic": grand_reserve_final},
		"primary": "StageClearViewEnding",
		"forbidden": ["FAILED", "실패", "불합격", "FINALIZED", "performance_target", "adviceCode", "STRENGTHEN_EVIDENCE", "PROTECT_CONDITION", "IMPROVE_SALE"]
	}, stage_pressure_10, "StageClearViewEnding")
	await capture_frame(main, "19_stage10_clear_view_ending_ko", "ko", "The third public Hammer finalizes all three Grand Reserve receipts and hands Stage 10 to one frozen replay-feedback card, one-line pressure summary and visible VIEW ENDING CTA without acknowledging the clear early.", stage_clear_10_specification)

	var stage_clear_view_ending := press_visible_button(main, "StageClearViewEnding")
	await settle_ui(8)
	var reserve_results_value: Variant = gs.campaign_state.get("grandReserve", {}).get("results", [])
	var reserve_results: Array = reserve_results_value if reserve_results_value is Array else []
	var ending_transition := {
		"buttonPressed": stage_clear_view_ending,
		"screen": String(main.screen),
		"stageClearAcknowledged": bool(gs.stage_run_state.get("stageClearAcknowledged", false)),
		"stageClearPending": bool(gs.stage_clear_pending()),
		"resultCount": reserve_results.size(),
		"endingPresent": not String(gs.campaign_state.get("currentEnding", "")).is_empty()
	}
	var ending_ko_failures: Array = []
	if not stage_clear_view_ending or String(main.screen) != "ending":
		ending_ko_failures.append("ending_public_transition_failed")
	if not bool(ending_transition.stageClearAcknowledged) or bool(ending_transition.stageClearPending):
		ending_ko_failures.append("ending_acknowledgement_boundary_invalid")
	if reserve_results.size() != 3 or not bool(ending_transition.endingPresent):
		ending_ko_failures.append("ending_authoritative_results_missing")
	append_fixture_failures("22_ending_ko", ending_ko_failures, ending_transition)
	var ending_tokens := ending_internal_tokens(gs)
	var ending_title_ko := String(main.friendly_ending_title(String(gs.campaign_state.get("currentEnding", ""))))
	var ending_ko_copy := visible_copy(main)
	await capture_frame(main, "22_ending_ko", "ko", "StageClearViewEnding opens a compact Korean ending hero, the three frozen public replay axes, three authoritative result cards with one terminal reason each, and one Epilogue action.", {
		"required": ["EndingHeroCard", "EndingHeroIcon", "EndingTitle", "EndingSummary", "EndingAxes", "EndingAxis_investigation", "EndingAxis_preservation", "EndingAxis_sale", "EndingLotGrid", "EndingLotCard_0", "EndingLotCard_1", "EndingLotCard_2", "EndingLotName", "EndingLotResult", "EndingLotReasonChip", "PostgameButton"],
		"minimumWidths": {"EndingHeroCard": 1100.0, "EndingSummary": 900.0, "EndingAxes": 1100.0, "EndingLotGrid": 1100.0, "EndingLotCard_0": 360.0, "EndingLotCard_1": 360.0, "EndingLotCard_2": 360.0, "PostgameButton": 500.0},
		"minimumHeights": {"EndingHeroCard": 80.0, "EndingAxes": 68.0, "EndingLotCard_0": 110.0, "EndingLotCard_1": 110.0, "EndingLotCard_2": 110.0, "PostgameButton": 50.0},
		"counts": [{"pattern": "EndingHeroCard", "type": "PanelContainer", "exact": 1}, {"pattern": "EndingAxis_*", "type": "PanelContainer", "exact": 3}, {"pattern": "EndingLotCard_*", "type": "PanelContainer", "exact": 3}, {"pattern": "EndingLotName", "type": "Label", "exact": 3}, {"pattern": "EndingLotResult", "type": "Label", "exact": 3}, {"pattern": "EndingLotReasonChip", "type": "PanelContainer", "exact": 3}, {"pattern": "PostgameButton", "type": "Button", "exact": 1}],
		"maxLines": [{"name": "EndingTitle", "maximum": 1}, {"name": "EndingSummary", "maximum": 2}, {"name": "EndingLotName", "maximum": 1}, {"name": "EndingLotResult", "maximum": 1}],
		"noOverlapPairs": [["EndingHeroCard", "EndingAxes"], ["EndingAxes", "EndingLotGrid"], ["EndingLotCard_0", "EndingLotCard_1"], ["EndingLotCard_1", "EndingLotCard_2"], ["EndingLotGrid", "PostgameButton"]],
		"singleLineTextFitPatterns": ["EndingTitle", "EndingLotName", "EndingLotResult", "EndingLotReasonLabel"],
		"requiredCopy": [ending_title_ko],
		"textureRequirements": ["EndingHeroIcon", "EndingLotIcon"],
		"publicActionEvidence": {"method": "StageClearViewEnding.pressed", "transition": ending_transition, "results": reserve_results.size()},
		"primary": "PostgameButton",
		"forbidden": ending_tokens
	})

	var ending_to_en: Dictionary = await locale_toggle_with_authority_evidence(gs, main, "en")
	var ending_title_en := String(main.friendly_ending_title(String(gs.campaign_state.get("currentEnding", ""))))
	var ending_en_copy := visible_copy(main)
	var ending_en_failures: Array = []
	if not bool(ending_to_en.get("valid", false)):
		ending_en_failures.append("ending_locale_authority_mutated")
	if ending_ko_copy == ending_en_copy:
		ending_en_failures.append("ending_locale_copy_unchanged")
	append_fixture_failures("23_ending_en", ending_en_failures, ending_to_en)
	await capture_frame(main, "23_ending_en", "en", "The English ending refresh preserves the exact selected lots, three receipts, ending, frozen Stage 10 feedback, profile and save authority with localized compact copy only.", {
		"required": ["EndingHeroCard", "EndingHeroIcon", "EndingTitle", "EndingSummary", "EndingAxes", "EndingAxis_investigation", "EndingAxis_preservation", "EndingAxis_sale", "EndingLotGrid", "EndingLotCard_0", "EndingLotCard_1", "EndingLotCard_2", "EndingLotName", "EndingLotResult", "EndingLotReasonChip", "PostgameButton"],
		"minimumWidths": {"EndingHeroCard": 1100.0, "EndingSummary": 900.0, "EndingAxes": 1100.0, "EndingLotGrid": 1100.0, "EndingLotCard_0": 360.0, "EndingLotCard_1": 360.0, "EndingLotCard_2": 360.0, "PostgameButton": 500.0},
		"minimumHeights": {"EndingHeroCard": 80.0, "EndingAxes": 68.0, "EndingLotCard_0": 110.0, "EndingLotCard_1": 110.0, "EndingLotCard_2": 110.0, "PostgameButton": 50.0},
		"counts": [{"pattern": "EndingHeroCard", "type": "PanelContainer", "exact": 1}, {"pattern": "EndingAxis_*", "type": "PanelContainer", "exact": 3}, {"pattern": "EndingLotCard_*", "type": "PanelContainer", "exact": 3}, {"pattern": "EndingLotName", "type": "Label", "exact": 3}, {"pattern": "EndingLotResult", "type": "Label", "exact": 3}, {"pattern": "EndingLotReasonChip", "type": "PanelContainer", "exact": 3}, {"pattern": "PostgameButton", "type": "Button", "exact": 1}],
		"maxLines": [{"name": "EndingTitle", "maximum": 1}, {"name": "EndingSummary", "maximum": 2}, {"name": "EndingLotName", "maximum": 1}, {"name": "EndingLotResult", "maximum": 1}],
		"noOverlapPairs": [["EndingHeroCard", "EndingAxes"], ["EndingAxes", "EndingLotGrid"], ["EndingLotCard_0", "EndingLotCard_1"], ["EndingLotCard_1", "EndingLotCard_2"], ["EndingLotGrid", "PostgameButton"]],
		"singleLineTextFitPatterns": ["EndingTitle", "EndingLotName", "EndingLotResult", "EndingLotReasonLabel"],
		"requiredCopy": [ending_title_en],
		"textureRequirements": ["EndingHeroIcon", "EndingLotIcon"],
		"publicActionEvidence": {"method": "LANGUAGE on ending", "localeToggle": ending_to_en, "results": reserve_results.size()},
		"primary": "PostgameButton",
		"forbidden": ending_tokens
	})

	var ending_to_ko: Dictionary = await locale_toggle_with_authority_evidence(gs, main, "ko")
	var postgame_button_pressed := press_visible_button(main, "PostgameButton")
	await settle_ui(8)
	var postgame_transition := {
		"buttonPressed": postgame_button_pressed,
		"returnToKorean": ending_to_ko,
		"screen": String(main.screen),
		"epilogueSeen": bool(gs.campaign_state.get("epilogueSeen", false)),
		"postGame": bool(gs.campaign_state.get("postGame", false)),
		"ending": String(gs.campaign_state.get("currentEnding", ""))
	}
	var postgame_ko_failures: Array = []
	if not bool(ending_to_ko.get("valid", false)):
		postgame_ko_failures.append("postgame_return_locale_authority_mutated")
	if not postgame_button_pressed or String(main.screen) != "postgame":
		postgame_ko_failures.append("postgame_public_transition_failed")
	if not bool(postgame_transition.epilogueSeen) or not bool(postgame_transition.postGame):
		postgame_ko_failures.append("postgame_authority_boundary_invalid")
	append_fixture_failures("24_postgame_ko", postgame_ko_failures, postgame_transition)
	var postgame_tokens := campaign_ending_tokens(registry, gs)
	var postgame_progress := find_visible_control(main, "PostgameProgress")
	var postgame_progress_ko := (postgame_progress as Label).text if postgame_progress is Label else ""
	var postgame_ko_copy := visible_copy(main)
	await capture_frame(main, "24_postgame_ko", "ko", "PostgameButton opens a compact Korean postgame hero, exact five-card ending gallery, persistent Stage progress and three distinct enabled actions with Credits collapsed.", {
		"required": ["PostgameHeroCard", "PostgameEndingTitle", "PostgameSummary", "PostgameProgress", "EndingGallery", "EndingCard_0", "EndingCard_1", "EndingCard_2", "EndingCard_3", "EndingCard_4", "EndingCardTitle", "EndingCardState", "PostgameActions", "PostgameStageSelect", "PostgameNewGame", "PostgameCredits"],
		"minimumWidths": {"PostgameHeroCard": 1100.0, "PostgameSummary": 900.0, "PostgameProgress": 900.0, "EndingGallery": 1100.0, "EndingCard_0": 210.0, "EndingCard_1": 210.0, "EndingCard_2": 210.0, "EndingCard_3": 210.0, "EndingCard_4": 210.0, "PostgameStageSelect": 360.0, "PostgameNewGame": 360.0, "PostgameCredits": 360.0},
		"minimumHeights": {"PostgameHeroCard": 80.0, "EndingCard_0": 140.0, "EndingCard_1": 140.0, "EndingCard_2": 140.0, "EndingCard_3": 140.0, "EndingCard_4": 140.0, "PostgameStageSelect": 46.0, "PostgameNewGame": 46.0, "PostgameCredits": 46.0},
		"counts": [{"pattern": "PostgameHeroCard", "type": "PanelContainer", "exact": 1}, {"pattern": "EndingCard_*", "type": "PanelContainer", "exact": 5}, {"pattern": "EndingCardTitle", "type": "Label", "exact": 5}, {"pattern": "EndingCardState", "type": "Label", "exact": 5}, {"pattern": "PostgameStageSelect", "type": "Button", "exact": 1}, {"pattern": "PostgameNewGame", "type": "Button", "exact": 1}, {"pattern": "PostgameCredits", "type": "Button", "exact": 1}, {"pattern": "CreditsPanel", "type": "PanelContainer", "exact": 0}],
		"maxLines": [{"name": "PostgameEndingTitle", "maximum": 1}, {"name": "PostgameSummary", "maximum": 2}, {"name": "PostgameProgress", "maximum": 1}, {"name": "EndingCardTitle", "maximum": 2}, {"name": "EndingCardState", "maximum": 1}],
		"noOverlapPairs": [["PostgameHeroCard", "PostgameProgress"], ["PostgameProgress", "EndingGallery"], ["EndingCard_0", "EndingCard_1"], ["EndingCard_1", "EndingCard_2"], ["EndingCard_2", "EndingCard_3"], ["EndingCard_3", "EndingCard_4"], ["EndingGallery", "PostgameActions"], ["PostgameStageSelect", "PostgameNewGame"], ["PostgameNewGame", "PostgameCredits"]],
		"singleLineTextFitPatterns": ["PostgameEndingTitle", "PostgameProgress", "EndingCardState"],
		"requiredCopy": [postgame_progress_ko],
		"textureRequirements": ["EndingHeroIcon", "EndingCardIcon"],
		"publicActionEvidence": {"method": "PostgameButton.pressed", "transition": postgame_transition},
		"primary": "PostgameStageSelect",
		"forbidden": postgame_tokens
	})

	var postgame_to_en: Dictionary = await locale_toggle_with_authority_evidence(gs, main, "en")
	postgame_progress = find_visible_control(main, "PostgameProgress")
	var postgame_progress_en := (postgame_progress as Label).text if postgame_progress is Label else ""
	var postgame_en_copy := visible_copy(main)
	var postgame_en_failures: Array = []
	if not bool(postgame_to_en.get("valid", false)):
		postgame_en_failures.append("postgame_locale_authority_mutated")
	if postgame_ko_copy == postgame_en_copy:
		postgame_en_failures.append("postgame_locale_copy_unchanged")
	append_fixture_failures("25_postgame_en", postgame_en_failures, postgame_to_en)
	await capture_frame(main, "25_postgame_en", "en", "The English postgame refresh keeps the exact five-card gallery, unlocked ending, selected lots, Stage progress, profile and save authority mutation-zero while retaining the three public actions.", {
		"required": ["PostgameHeroCard", "PostgameEndingTitle", "PostgameSummary", "PostgameProgress", "EndingGallery", "EndingCard_0", "EndingCard_1", "EndingCard_2", "EndingCard_3", "EndingCard_4", "EndingCardTitle", "EndingCardState", "PostgameActions", "PostgameStageSelect", "PostgameNewGame", "PostgameCredits"],
		"minimumWidths": {"PostgameHeroCard": 1100.0, "PostgameSummary": 900.0, "PostgameProgress": 900.0, "EndingGallery": 1100.0, "EndingCard_0": 210.0, "EndingCard_1": 210.0, "EndingCard_2": 210.0, "EndingCard_3": 210.0, "EndingCard_4": 210.0, "PostgameStageSelect": 360.0, "PostgameNewGame": 360.0, "PostgameCredits": 360.0},
		"minimumHeights": {"PostgameHeroCard": 80.0, "EndingCard_0": 140.0, "EndingCard_1": 140.0, "EndingCard_2": 140.0, "EndingCard_3": 140.0, "EndingCard_4": 140.0, "PostgameStageSelect": 46.0, "PostgameNewGame": 46.0, "PostgameCredits": 46.0},
		"counts": [{"pattern": "PostgameHeroCard", "type": "PanelContainer", "exact": 1}, {"pattern": "EndingCard_*", "type": "PanelContainer", "exact": 5}, {"pattern": "EndingCardTitle", "type": "Label", "exact": 5}, {"pattern": "EndingCardState", "type": "Label", "exact": 5}, {"pattern": "PostgameStageSelect", "type": "Button", "exact": 1}, {"pattern": "PostgameNewGame", "type": "Button", "exact": 1}, {"pattern": "PostgameCredits", "type": "Button", "exact": 1}, {"pattern": "CreditsPanel", "type": "PanelContainer", "exact": 0}],
		"maxLines": [{"name": "PostgameEndingTitle", "maximum": 1}, {"name": "PostgameSummary", "maximum": 2}, {"name": "PostgameProgress", "maximum": 1}, {"name": "EndingCardTitle", "maximum": 2}, {"name": "EndingCardState", "maximum": 1}],
		"noOverlapPairs": [["PostgameHeroCard", "PostgameProgress"], ["PostgameProgress", "EndingGallery"], ["EndingCard_0", "EndingCard_1"], ["EndingCard_1", "EndingCard_2"], ["EndingCard_2", "EndingCard_3"], ["EndingCard_3", "EndingCard_4"], ["EndingGallery", "PostgameActions"], ["PostgameStageSelect", "PostgameNewGame"], ["PostgameNewGame", "PostgameCredits"]],
		"singleLineTextFitPatterns": ["PostgameEndingTitle", "PostgameProgress", "EndingCardState"],
		"requiredCopy": [postgame_progress_en],
		"textureRequirements": ["EndingHeroIcon", "EndingCardIcon"],
		"publicActionEvidence": {"method": "LANGUAGE on postgame", "localeToggle": postgame_to_en},
		"primary": "PostgameStageSelect",
		"forbidden": postgame_tokens
	})

	# Repeated core screens: enter through their public navigation/action buttons,
	# exercise local card/page state, then capture identical KO/EN authority.
	var inventory_fixture := prepare_inventory_capture_fixture(gs, main, registry)
	await settle_ui(8)
	var inventory_value: Variant = inventory_fixture.get("inventory", [])
	var inventory: Array = inventory_value if inventory_value is Array else []
	var inventory_tokens := inventory_capture_tokens(inventory)
	var inventory_ko_required: Array = ["InventoryProgress", "InventoryPrev", "InventoryPage", "InventoryNext", "InventoryGrid", "InventoryDetailPanel", "InventoryDetailName", "InventoryDetailCase", "InventoryDetailStats", "InspectLot_0"]
	for inventory_card_index in range(8):
		inventory_ko_required.append("InventoryCard_%d" % inventory_card_index)
	var inventory_progress_control := find_visible_control(main, "InventoryProgress")
	var inventory_page_control := find_visible_control(main, "InventoryPage")
	var inventory_detail_name := find_visible_control(main, "InventoryDetailName")
	var inventory_ko_failures: Array = []
	if not bool(inventory_fixture.get("ok", false)):
		inventory_ko_failures.append("inventory_public_route_failed")
	if count_visible(main, "InventoryCard_*", "Button") != 8 or count_visible(main, "InspectLot_*", "Button") != 1:
		inventory_ko_failures.append("inventory_page_one_card_contract_invalid")
	if not inventory_page_control is Label or not (inventory_page_control as Label).text.replace(" ", "").contains("1/2"):
		inventory_ko_failures.append("inventory_page_one_progress_invalid")
	append_fixture_failures("26_inventory_ko", inventory_ko_failures, inventory_fixture)
	var inventory_ko_copy := visible_copy(main)
	await capture_frame(main, "26_inventory_ko", "ko", "The public Inventory route shows eight illustrated three-line relic cards, a compact two-page control, one shared detail and one separate Inspect action in Korean without scrolling.", {
		"required": inventory_ko_required,
		"minimumWidths": {"InventoryProgress": 560.0, "InventoryGrid": 1100.0, "InventoryCard_0": 560.0, "InventoryCard_1": 560.0, "InventoryDetailPanel": 1100.0, "InventoryDetailName": 650.0, "InventoryDetailCase": 650.0, "InventoryDetailStats": 650.0, "InspectLot_0": 250.0},
		"minimumHeights": {"InventoryGrid": 280.0, "InventoryCard_0": 64.0, "InventoryCard_1": 64.0, "InventoryDetailPanel": 80.0, "InspectLot_0": 52.0},
		"counts": [{"pattern": "InventoryCard_*", "type": "Button", "exact": 8}, {"pattern": "InventoryDetailPanel", "type": "PanelContainer", "exact": 1}, {"pattern": "InspectLot_*", "type": "Button", "exact": 1}, {"pattern": "InventoryPrev", "type": "Button", "exact": 1}, {"pattern": "InventoryNext", "type": "Button", "exact": 1}],
		"maxLines": [{"name": "InventoryProgress", "maximum": 1}, {"name": "InventoryPage", "maximum": 1}, {"name": "InventoryDetailName", "maximum": 1}, {"name": "InventoryDetailCase", "maximum": 1}, {"name": "InventoryDetailStats", "maximum": 2}],
		"buttonIconRequirements": ["InventoryCard_*", "InventoryPrev", "InventoryNext", "InspectLot_*"],
		"buttonLineCounts": [{"pattern": "InventoryCard_*", "exact": 3}],
		"noVisibleScroll": true,
		"noOverlapPairs": [["InventoryCard_0", "InventoryCard_1"], ["InventoryCard_0", "InventoryCard_2"], ["InventoryCard_2", "InventoryCard_3"], ["InventoryCard_4", "InventoryCard_5"], ["InventoryCard_6", "InventoryCard_7"], ["InventoryGrid", "InventoryDetailPanel"], ["InventoryDetailName", "InspectLot_0"], ["InventoryDetailCase", "InspectLot_0"], ["InventoryDetailStats", "InspectLot_0"]],
		"singleLineTextFitPatterns": ["InventoryProgress", "InventoryPage", "InventoryDetailName", "InventoryDetailCase", "InventoryDetailStats"],
		"requiredCopy": [(inventory_progress_control as Label).text if inventory_progress_control is Label else "", (inventory_page_control as Label).text if inventory_page_control is Label else "", (inventory_detail_name as Label).text if inventory_detail_name is Label else ""],
		"publicActionEvidence": {"method": "Nav_INVENTORY.pressed", "fixture": inventory_fixture},
		"primary": "InspectLot_0",
		"forbidden": inventory_tokens
	})

	var inventory_action_authority_before := stable_save_authority_signature(gs)
	var inventory_action_rng_before := int(gs.rng.state)
	var inventory_next_pressed := press_visible_button(main, "InventoryNext")
	await settle_ui(6)
	var inventory_page_two_control := find_visible_control(main, "InventoryPage")
	var inventory_page_two_reached := inventory_page_two_control is Label and (inventory_page_two_control as Label).text.replace(" ", "").contains("2/2") and count_visible(main, "InventoryCard_*", "Button") == 3
	var inventory_detail_pressed := press_visible_button(main, "InventoryCard_0")
	await settle_ui(6)
	var inventory_previous_pressed := press_visible_button(main, "InventoryPrev")
	await settle_ui(6)
	var inventory_return_page := find_visible_control(main, "InventoryPage")
	var inventory_returned := inventory_return_page is Label and (inventory_return_page as Label).text.replace(" ", "").contains("1/2") and count_visible(main, "InventoryCard_*", "Button") == 8
	var inventory_action_authority := authority_rng_evidence(gs, inventory_action_authority_before, inventory_action_rng_before)
	inventory_action_authority["nextPressed"] = inventory_next_pressed
	inventory_action_authority["pageTwoReached"] = inventory_page_two_reached
	inventory_action_authority["detailPressed"] = inventory_detail_pressed
	inventory_action_authority["previousPressed"] = inventory_previous_pressed
	inventory_action_authority["returnedToPageOne"] = inventory_returned
	inventory_action_authority["valid"] = bool(inventory_action_authority.get("valid", false)) and inventory_next_pressed and inventory_page_two_reached and inventory_detail_pressed and inventory_previous_pressed and inventory_returned
	var inventory_to_en: Dictionary = await locale_toggle_with_authority_evidence(gs, main, "en")
	var inventory_en_copy := visible_copy(main)
	var inventory_en_failures: Array = []
	if not bool(inventory_action_authority.get("valid", false)):
		inventory_en_failures.append("inventory_page_detail_authority_or_rng_mutated")
	if not bool(inventory_to_en.get("valid", false)):
		inventory_en_failures.append("inventory_locale_authority_or_rng_mutated")
	if inventory_ko_copy == inventory_en_copy:
		inventory_en_failures.append("inventory_locale_copy_unchanged")
	append_fixture_failures("27_inventory_en", inventory_en_failures, {"navigation": inventory_action_authority, "localeToggle": inventory_to_en})
	inventory_progress_control = find_visible_control(main, "InventoryProgress")
	inventory_page_control = find_visible_control(main, "InventoryPage")
	inventory_detail_name = find_visible_control(main, "InventoryDetailName")
	await capture_frame(main, "27_inventory_en", "en", "The English Inventory refresh preserves the same page-one eight-card layout and Inspect authority after a public page-two/detail round trip with save and RNG mutation-zero.", {
		"required": inventory_ko_required,
		"minimumWidths": {"InventoryProgress": 560.0, "InventoryGrid": 1100.0, "InventoryCard_0": 560.0, "InventoryCard_1": 560.0, "InventoryDetailPanel": 1100.0, "InventoryDetailName": 650.0, "InventoryDetailCase": 650.0, "InventoryDetailStats": 650.0, "InspectLot_0": 250.0},
		"minimumHeights": {"InventoryGrid": 280.0, "InventoryCard_0": 64.0, "InventoryCard_1": 64.0, "InventoryDetailPanel": 80.0, "InspectLot_0": 52.0},
		"counts": [{"pattern": "InventoryCard_*", "type": "Button", "exact": 8}, {"pattern": "InventoryDetailPanel", "type": "PanelContainer", "exact": 1}, {"pattern": "InspectLot_*", "type": "Button", "exact": 1}],
		"maxLines": [{"name": "InventoryProgress", "maximum": 1}, {"name": "InventoryPage", "maximum": 1}, {"name": "InventoryDetailName", "maximum": 1}, {"name": "InventoryDetailCase", "maximum": 1}, {"name": "InventoryDetailStats", "maximum": 2}],
		"buttonIconRequirements": ["InventoryCard_*", "InventoryPrev", "InventoryNext", "InspectLot_*"],
		"buttonLineCounts": [{"pattern": "InventoryCard_*", "exact": 3}],
		"noVisibleScroll": true,
		"noOverlapPairs": [["InventoryCard_0", "InventoryCard_1"], ["InventoryCard_0", "InventoryCard_2"], ["InventoryCard_2", "InventoryCard_3"], ["InventoryCard_4", "InventoryCard_5"], ["InventoryCard_6", "InventoryCard_7"], ["InventoryGrid", "InventoryDetailPanel"], ["InventoryDetailName", "InspectLot_0"], ["InventoryDetailCase", "InspectLot_0"], ["InventoryDetailStats", "InspectLot_0"]],
		"singleLineTextFitPatterns": ["InventoryProgress", "InventoryPage", "InventoryDetailName", "InventoryDetailCase", "InventoryDetailStats"],
		"requiredCopy": [(inventory_progress_control as Label).text if inventory_progress_control is Label else "", (inventory_page_control as Label).text if inventory_page_control is Label else "", (inventory_detail_name as Label).text if inventory_detail_name is Label else ""],
		"publicActionEvidence": {"method": "InventoryNext + InventoryCard_0 + InventoryPrev + Nav_LANGUAGE", "navigation": inventory_action_authority, "localeToggle": inventory_to_en},
		"primary": "InspectLot_0",
		"forbidden": inventory_tokens
	})

	var authentication_fixture := prepare_authentication_capture_fixture(gs, main, registry)
	await settle_ui(8)
	var authentication_artifact_value: Variant = authentication_fixture.get("artifact", {})
	var authentication_artifact: Dictionary = authentication_artifact_value if authentication_artifact_value is Dictionary else {}
	var authentication_tokens := authentication_capture_tokens(authentication_artifact)
	var authentication_action_authority_before := stable_save_authority_signature(gs)
	var authentication_action_rng_before := int(gs.rng.state)
	var authentication_evidence_pressed := press_visible_button(main, "AuthenticationEvidenceCard_5")
	await settle_ui(6)
	var authentication_action_authority := authority_rng_evidence(gs, authentication_action_authority_before, authentication_action_rng_before)
	authentication_action_authority["evidencePressed"] = authentication_evidence_pressed
	authentication_action_authority["valid"] = bool(authentication_action_authority.get("valid", false)) and authentication_evidence_pressed
	var authentication_ko_failures: Array = []
	if not bool(authentication_fixture.get("ok", false)):
		authentication_ko_failures.append("authentication_public_route_failed")
	if not bool(authentication_action_authority.get("valid", false)):
		authentication_ko_failures.append("authentication_evidence_authority_or_rng_mutated")
	if count_visible(main, "AuthenticationEvidenceCard_*", "Button") != 6 or count_visible(main, "Hypothesis_*", "Button") != 6 or count_visible(main, "AcceptHypothesisButton", "Button") != 1:
		authentication_ko_failures.append("authentication_card_contract_invalid")
	append_fixture_failures("28_authentication_ko", authentication_ko_failures, {"fixture": authentication_fixture, "evidenceAction": authentication_action_authority})
	var authentication_ko_copy := visible_copy(main)
	await capture_frame(main, "28_authentication_ko", "ko", "AuthenticateButton opens a Korean 2x3 evidence board with one selected two-line observation, a 3x2 icon hypothesis board, one requirement and exactly one separate Accept action.", {
		"required": ["AuthenticationConfidence", "AuthenticationColumns", "AuthenticationEvidencePrev", "AuthenticationEvidencePage", "AuthenticationEvidenceNext", "AuthenticationEvidenceGrid", "AuthenticationEvidenceCard_0", "AuthenticationEvidenceCard_1", "AuthenticationEvidenceCard_2", "AuthenticationEvidenceCard_3", "AuthenticationEvidenceCard_4", "AuthenticationEvidenceCard_5", "AuthenticationEvidenceDetail", "AuthenticationEvidenceDetailTitle", "AuthenticationEvidenceMeta", "AuthenticationEvidenceObservation", "HypothesisGrid", "Hypothesis_GENUINE", "Hypothesis_GENUINE_WITH_PERIOD_REPAIR", "Hypothesis_GENUINE_WITH_MODERN_REPAIR", "Hypothesis_REPRODUCTION", "Hypothesis_FORGERY", "Hypothesis_UNKNOWN", "AuthenticationHypothesisDetail", "AuthenticationRequirement", "AcceptHypothesisButton"],
		"minimumWidths": {"AuthenticationConfidence": 900.0, "AuthenticationColumns": 1100.0, "AuthenticationEvidenceGrid": 550.0, "AuthenticationEvidenceCard_0": 260.0, "AuthenticationEvidenceCard_1": 260.0, "AuthenticationEvidenceDetail": 550.0, "AuthenticationEvidenceObservation": 520.0, "HypothesisGrid": 580.0, "Hypothesis_GENUINE": 180.0, "Hypothesis_GENUINE_WITH_PERIOD_REPAIR": 180.0, "AcceptHypothesisButton": 560.0},
		"minimumHeights": {"AuthenticationEvidenceCard_0": 56.0, "AuthenticationEvidenceCard_1": 56.0, "AuthenticationEvidenceDetail": 90.0, "Hypothesis_GENUINE": 68.0, "Hypothesis_GENUINE_WITH_PERIOD_REPAIR": 68.0, "AcceptHypothesisButton": 46.0},
		"counts": [{"pattern": "AuthenticationEvidenceCard_*", "type": "Button", "exact": 6}, {"pattern": "Hypothesis_*", "type": "Button", "exact": 6}, {"pattern": "AuthenticationEvidenceDetail", "type": "PanelContainer", "exact": 1}, {"pattern": "AcceptHypothesisButton", "type": "Button", "exact": 1}],
		"maxLines": [{"name": "AuthenticationConfidence", "maximum": 1}, {"name": "AuthenticationEvidencePage", "maximum": 1}, {"name": "AuthenticationEvidenceDetailTitle", "maximum": 1}, {"name": "AuthenticationEvidenceMeta", "maximum": 1}, {"name": "AuthenticationEvidenceObservation", "maximum": 2}, {"name": "AuthenticationHypothesisDetail", "maximum": 2}, {"name": "AuthenticationRequirement", "maximum": 1}],
		"buttonIconRequirements": ["AuthenticationEvidenceCard_*", "Hypothesis_*", "AcceptHypothesisButton"],
		"buttonLineCounts": [{"pattern": "AuthenticationEvidenceCard_*", "exact": 2}, {"pattern": "Hypothesis_*", "exact": 2}],
		"noVisibleScroll": true,
		"allowCollapsed": ["AuthenticationEvidencePage"],
		"horizontalGaps": [{"left": "AuthenticationEvidenceGrid", "right": "HypothesisGrid", "minimum": 12.0}],
		"noOverlapPairs": [["AuthenticationEvidenceCard_0", "AuthenticationEvidenceCard_1"], ["AuthenticationEvidenceCard_0", "AuthenticationEvidenceCard_2"], ["AuthenticationEvidenceCard_2", "AuthenticationEvidenceCard_3"], ["AuthenticationEvidenceGrid", "AuthenticationEvidenceDetail"], ["Hypothesis_GENUINE", "Hypothesis_GENUINE_WITH_PERIOD_REPAIR"], ["Hypothesis_GENUINE", "Hypothesis_REPRODUCTION"], ["HypothesisGrid", "AuthenticationHypothesisDetail"], ["AuthenticationHypothesisDetail", "AuthenticationRequirement"], ["AuthenticationRequirement", "AcceptHypothesisButton"]],
		"singleLineTextFitPatterns": ["AuthenticationConfidence", "AuthenticationEvidencePage", "AuthenticationEvidenceDetailTitle", "AuthenticationEvidenceMeta", "AuthenticationRequirement"],
		"requiredCopy": [(find_visible_control(main, "AuthenticationConfidence") as Label).text if find_visible_control(main, "AuthenticationConfidence") is Label else "", (find_visible_control(main, "AuthenticationEvidenceObservation") as Label).text if find_visible_control(main, "AuthenticationEvidenceObservation") is Label else ""],
		"publicActionEvidence": {"method": "AuthenticateButton + AuthenticationEvidenceCard_5", "fixture": authentication_fixture, "evidenceAction": authentication_action_authority},
		"forbidden": authentication_tokens
	})

	var authentication_uid := String(authentication_artifact.get("uniqueId", ""))
	var authentication_draft_before := authentication_draft_neutral_signature(gs, authentication_uid)
	var authentication_draft_rng_before := int(gs.rng.state)
	var authentication_hypothesis_pressed := press_visible_button(main, "Hypothesis_GENUINE")
	await settle_ui(6)
	var authentication_accept := find_visible_control(main, "AcceptHypothesisButton")
	var authentication_draft_after := authentication_draft_neutral_signature(gs, authentication_uid)
	var authentication_draft_action := {
		"button": "Hypothesis_GENUINE",
		"pressed": authentication_hypothesis_pressed,
		"selectedDraft": String(authentication_artifact.get("playerHypothesis", "")),
		"onlyDraftMutation": authentication_draft_before == authentication_draft_after,
		"rngMutation0": int(gs.rng.state) == authentication_draft_rng_before,
		"acceptEnabled": authentication_accept is Button and not (authentication_accept as Button).disabled
	}
	authentication_draft_action["valid"] = authentication_hypothesis_pressed \
		and String(authentication_artifact.get("playerHypothesis", "")) == "GENUINE" \
		and bool(authentication_draft_action.onlyDraftMutation) \
		and bool(authentication_draft_action.rngMutation0) \
		and bool(authentication_draft_action.acceptEnabled)
	var authentication_to_en: Dictionary = await locale_toggle_with_authority_evidence(gs, main, "en")
	var authentication_en_copy := visible_copy(main)
	var authentication_en_failures: Array = []
	if not bool(authentication_draft_action.get("valid", false)):
		authentication_en_failures.append("authentication_draft_boundary_invalid")
	if not bool(authentication_to_en.get("valid", false)):
		authentication_en_failures.append("authentication_locale_authority_or_rng_mutated")
	if authentication_ko_copy == authentication_en_copy:
		authentication_en_failures.append("authentication_locale_copy_unchanged")
	append_fixture_failures("29_authentication_en", authentication_en_failures, {"draftAction": authentication_draft_action, "localeToggle": authentication_to_en})
	await capture_frame(main, "29_authentication_en", "en", "The English Authentication refresh keeps the same selected evidence and six hypotheses after one public draft-only choice enables the separate Accept action; save authority and RNG remain mutation-zero.", {
		"required": ["AuthenticationConfidence", "AuthenticationColumns", "AuthenticationEvidencePrev", "AuthenticationEvidencePage", "AuthenticationEvidenceNext", "AuthenticationEvidenceGrid", "AuthenticationEvidenceCard_0", "AuthenticationEvidenceCard_1", "AuthenticationEvidenceCard_2", "AuthenticationEvidenceCard_3", "AuthenticationEvidenceCard_4", "AuthenticationEvidenceCard_5", "AuthenticationEvidenceDetail", "AuthenticationEvidenceDetailTitle", "AuthenticationEvidenceMeta", "AuthenticationEvidenceObservation", "HypothesisGrid", "Hypothesis_GENUINE", "Hypothesis_GENUINE_WITH_PERIOD_REPAIR", "Hypothesis_GENUINE_WITH_MODERN_REPAIR", "Hypothesis_REPRODUCTION", "Hypothesis_FORGERY", "Hypothesis_UNKNOWN", "AuthenticationHypothesisDetail", "AuthenticationRequirement", "AcceptHypothesisButton"],
		"minimumWidths": {"AuthenticationConfidence": 900.0, "AuthenticationColumns": 1100.0, "AuthenticationEvidenceGrid": 550.0, "AuthenticationEvidenceCard_0": 260.0, "AuthenticationEvidenceCard_1": 260.0, "AuthenticationEvidenceDetail": 550.0, "AuthenticationEvidenceObservation": 520.0, "HypothesisGrid": 580.0, "Hypothesis_GENUINE": 180.0, "Hypothesis_GENUINE_WITH_PERIOD_REPAIR": 180.0, "AcceptHypothesisButton": 560.0},
		"minimumHeights": {"AuthenticationEvidenceCard_0": 56.0, "AuthenticationEvidenceCard_1": 56.0, "AuthenticationEvidenceDetail": 90.0, "Hypothesis_GENUINE": 68.0, "Hypothesis_GENUINE_WITH_PERIOD_REPAIR": 68.0, "AcceptHypothesisButton": 46.0},
		"counts": [{"pattern": "AuthenticationEvidenceCard_*", "type": "Button", "exact": 6}, {"pattern": "Hypothesis_*", "type": "Button", "exact": 6}, {"pattern": "AuthenticationEvidenceDetail", "type": "PanelContainer", "exact": 1}, {"pattern": "AcceptHypothesisButton", "type": "Button", "exact": 1}],
		"maxLines": [{"name": "AuthenticationConfidence", "maximum": 1}, {"name": "AuthenticationEvidencePage", "maximum": 1}, {"name": "AuthenticationEvidenceDetailTitle", "maximum": 1}, {"name": "AuthenticationEvidenceMeta", "maximum": 1}, {"name": "AuthenticationEvidenceObservation", "maximum": 2}, {"name": "AuthenticationHypothesisDetail", "maximum": 2}, {"name": "AuthenticationRequirement", "maximum": 1}],
		"buttonIconRequirements": ["AuthenticationEvidenceCard_*", "Hypothesis_*", "AcceptHypothesisButton"],
		"buttonLineCounts": [{"pattern": "AuthenticationEvidenceCard_*", "exact": 2}, {"pattern": "Hypothesis_*", "exact": 2}],
		"noVisibleScroll": true,
		"allowCollapsed": ["AuthenticationEvidencePage"],
		"horizontalGaps": [{"left": "AuthenticationEvidenceGrid", "right": "HypothesisGrid", "minimum": 12.0}],
		"noOverlapPairs": [["AuthenticationEvidenceCard_0", "AuthenticationEvidenceCard_1"], ["AuthenticationEvidenceCard_0", "AuthenticationEvidenceCard_2"], ["AuthenticationEvidenceCard_2", "AuthenticationEvidenceCard_3"], ["AuthenticationEvidenceGrid", "AuthenticationEvidenceDetail"], ["Hypothesis_GENUINE", "Hypothesis_GENUINE_WITH_PERIOD_REPAIR"], ["Hypothesis_GENUINE", "Hypothesis_REPRODUCTION"], ["HypothesisGrid", "AuthenticationHypothesisDetail"], ["AuthenticationHypothesisDetail", "AuthenticationRequirement"], ["AuthenticationRequirement", "AcceptHypothesisButton"]],
		"singleLineTextFitPatterns": ["AuthenticationConfidence", "AuthenticationEvidencePage", "AuthenticationEvidenceDetailTitle", "AuthenticationEvidenceMeta", "AuthenticationRequirement"],
		"requiredCopy": [(find_visible_control(main, "AuthenticationConfidence") as Label).text if find_visible_control(main, "AuthenticationConfidence") is Label else "", (find_visible_control(main, "AuthenticationEvidenceObservation") as Label).text if find_visible_control(main, "AuthenticationEvidenceObservation") is Label else ""],
		"publicActionEvidence": {"method": "Hypothesis_GENUINE + Nav_LANGUAGE", "draftAction": authentication_draft_action, "localeToggle": authentication_to_en},
		"primary": "AcceptHypothesisButton",
		"forbidden": authentication_tokens
	})

	var upgrades_fixture := prepare_upgrades_capture_fixture(gs, main, registry)
	await settle_ui(8)
	var upgrade_tokens := upgrade_capture_tokens(registry)
	var upgrade_first: Dictionary = registry.upgrades[0] if not registry.upgrades.is_empty() and registry.upgrades[0] is Dictionary else {}
	var upgrade_first_primary := "Upgrade_%s" % String(upgrade_first.get("id", ""))
	var upgrades_required: Array = ["UpgradeProgress", "UpgradePrev", "UpgradePage", "UpgradeNext", "UpgradeGrid", "UpgradeDetailPanel", "UpgradeDetailName", "UpgradeDetailEffect", upgrade_first_primary]
	for upgrade_card_index in range(6):
		upgrades_required.append("UpgradeCard_%d" % upgrade_card_index)
	var upgrades_progress_control := find_visible_control(main, "UpgradeProgress")
	var upgrades_page_control := find_visible_control(main, "UpgradePage")
	var upgrades_detail_name := find_visible_control(main, "UpgradeDetailName")
	var upgrades_ko_failures: Array = []
	if not bool(upgrades_fixture.get("ok", false)):
		upgrades_ko_failures.append("upgrades_public_route_failed")
	if count_visible(main, "UpgradeCard_*", "Button") != 6 or count_visible(main, "Upgrade_upgrade_*", "Button") != 1:
		upgrades_ko_failures.append("upgrade_page_one_card_contract_invalid")
	if not upgrades_page_control is Label or not (upgrades_page_control as Label).text.replace(" ", "").contains("1/5"):
		upgrades_ko_failures.append("upgrade_page_one_progress_invalid")
	append_fixture_failures("30_upgrades_ko", upgrades_ko_failures, upgrades_fixture)
	var upgrades_ko_copy := visible_copy(main)
	await capture_frame(main, "30_upgrades_ko", "ko", "The public Upgrades route shows six illustrated three-line cards, page one of five, one compact localized detail and exactly one separate Buy action in Korean without scrolling.", {
		"required": upgrades_required,
		"minimumWidths": {"UpgradeProgress": 560.0, "UpgradeGrid": 1100.0, "UpgradeCard_0": 560.0, "UpgradeCard_1": 560.0, "UpgradeDetailPanel": 1100.0, "UpgradeDetailName": 650.0, "UpgradeDetailEffect": 650.0},
		"minimumHeights": {"UpgradeGrid": 270.0, "UpgradeCard_0": 84.0, "UpgradeCard_1": 84.0, "UpgradeDetailPanel": 90.0},
		"counts": [{"pattern": "UpgradeCard_*", "type": "Button", "exact": 6}, {"pattern": "UpgradeDetailPanel", "type": "PanelContainer", "exact": 1}, {"pattern": "Upgrade_upgrade_*", "type": "Button", "exact": 1}],
		"maxLines": [{"name": "UpgradeProgress", "maximum": 1}, {"name": "UpgradePage", "maximum": 1}, {"name": "UpgradeDetailName", "maximum": 1}, {"name": "UpgradeDetailEffect", "maximum": 2}],
		"buttonIconRequirements": ["UpgradeCard_*", "UpgradePrev", "UpgradeNext", "Upgrade_upgrade_*"],
		"buttonLineCounts": [{"pattern": "UpgradeCard_*", "exact": 3}],
		"noVisibleScroll": true,
		"noOverlapPairs": [["UpgradeCard_0", "UpgradeCard_1"], ["UpgradeCard_0", "UpgradeCard_2"], ["UpgradeCard_2", "UpgradeCard_3"], ["UpgradeCard_4", "UpgradeCard_5"], ["UpgradeGrid", "UpgradeDetailPanel"], ["UpgradeDetailName", upgrade_first_primary], ["UpgradeDetailEffect", upgrade_first_primary]],
		"singleLineTextFitPatterns": ["UpgradeProgress", "UpgradePage", "UpgradeDetailName"],
		"requiredCopy": [(upgrades_progress_control as Label).text if upgrades_progress_control is Label else "", (upgrades_page_control as Label).text if upgrades_page_control is Label else "", (upgrades_detail_name as Label).text if upgrades_detail_name is Label else ""],
		"publicActionEvidence": {"method": "Nav_UPGRADES.pressed", "fixture": upgrades_fixture},
		"primary": upgrade_first_primary,
		"forbidden": upgrade_tokens
	})

	var upgrades_action_authority_before := stable_save_authority_signature(gs)
	var upgrades_action_rng_before := int(gs.rng.state)
	var upgrades_next_pressed := press_visible_button(main, "UpgradeNext")
	await settle_ui(6)
	var upgrade_page_two_control := find_visible_control(main, "UpgradePage")
	var upgrades_page_two_reached := upgrade_page_two_control is Label and (upgrade_page_two_control as Label).text.replace(" ", "").contains("2/5") and count_visible(main, "UpgradeCard_*", "Button") == 6
	var upgrade_detail_pressed := press_visible_button(main, "UpgradeCard_0")
	await settle_ui(6)
	var upgrades_previous_pressed := press_visible_button(main, "UpgradePrev")
	await settle_ui(6)
	var upgrades_return_page := find_visible_control(main, "UpgradePage")
	var upgrades_returned := upgrades_return_page is Label and (upgrades_return_page as Label).text.replace(" ", "").contains("1/5") and count_visible(main, "UpgradeCard_*", "Button") == 6
	var upgrades_action_authority := authority_rng_evidence(gs, upgrades_action_authority_before, upgrades_action_rng_before)
	upgrades_action_authority["nextPressed"] = upgrades_next_pressed
	upgrades_action_authority["pageTwoReached"] = upgrades_page_two_reached
	upgrades_action_authority["detailPressed"] = upgrade_detail_pressed
	upgrades_action_authority["previousPressed"] = upgrades_previous_pressed
	upgrades_action_authority["returnedToPageOne"] = upgrades_returned
	upgrades_action_authority["valid"] = bool(upgrades_action_authority.get("valid", false)) and upgrades_next_pressed and upgrades_page_two_reached and upgrade_detail_pressed and upgrades_previous_pressed and upgrades_returned
	var upgrades_to_en: Dictionary = await locale_toggle_with_authority_evidence(gs, main, "en")
	var upgrades_en_copy := visible_copy(main)
	var upgrades_en_failures: Array = []
	if not bool(upgrades_action_authority.get("valid", false)):
		upgrades_en_failures.append("upgrade_page_detail_authority_or_rng_mutated")
	if not bool(upgrades_to_en.get("valid", false)):
		upgrades_en_failures.append("upgrade_locale_authority_or_rng_mutated")
	if upgrades_ko_copy == upgrades_en_copy:
		upgrades_en_failures.append("upgrade_locale_copy_unchanged")
	append_fixture_failures("31_upgrades_en", upgrades_en_failures, {"navigation": upgrades_action_authority, "localeToggle": upgrades_to_en})
	upgrades_progress_control = find_visible_control(main, "UpgradeProgress")
	upgrades_page_control = find_visible_control(main, "UpgradePage")
	upgrades_detail_name = find_visible_control(main, "UpgradeDetailName")
	await capture_frame(main, "31_upgrades_en", "en", "The English Upgrades refresh preserves the same six-card page-one layout and Buy boundary after a public page-two/detail round trip with money, ownership, save authority and RNG mutation-zero.", {
		"required": upgrades_required,
		"minimumWidths": {"UpgradeProgress": 560.0, "UpgradeGrid": 1100.0, "UpgradeCard_0": 560.0, "UpgradeCard_1": 560.0, "UpgradeDetailPanel": 1100.0, "UpgradeDetailName": 650.0, "UpgradeDetailEffect": 650.0},
		"minimumHeights": {"UpgradeGrid": 270.0, "UpgradeCard_0": 84.0, "UpgradeCard_1": 84.0, "UpgradeDetailPanel": 90.0},
		"counts": [{"pattern": "UpgradeCard_*", "type": "Button", "exact": 6}, {"pattern": "UpgradeDetailPanel", "type": "PanelContainer", "exact": 1}, {"pattern": "Upgrade_upgrade_*", "type": "Button", "exact": 1}],
		"maxLines": [{"name": "UpgradeProgress", "maximum": 1}, {"name": "UpgradePage", "maximum": 1}, {"name": "UpgradeDetailName", "maximum": 1}, {"name": "UpgradeDetailEffect", "maximum": 2}],
		"buttonIconRequirements": ["UpgradeCard_*", "UpgradePrev", "UpgradeNext", "Upgrade_upgrade_*"],
		"buttonLineCounts": [{"pattern": "UpgradeCard_*", "exact": 3}],
		"noVisibleScroll": true,
		"noOverlapPairs": [["UpgradeCard_0", "UpgradeCard_1"], ["UpgradeCard_0", "UpgradeCard_2"], ["UpgradeCard_2", "UpgradeCard_3"], ["UpgradeCard_4", "UpgradeCard_5"], ["UpgradeGrid", "UpgradeDetailPanel"], ["UpgradeDetailName", upgrade_first_primary], ["UpgradeDetailEffect", upgrade_first_primary]],
		"singleLineTextFitPatterns": ["UpgradeProgress", "UpgradePage", "UpgradeDetailName"],
		"requiredCopy": [(upgrades_progress_control as Label).text if upgrades_progress_control is Label else "", (upgrades_page_control as Label).text if upgrades_page_control is Label else "", (upgrades_detail_name as Label).text if upgrades_detail_name is Label else ""],
		"publicActionEvidence": {"method": "UpgradeNext + UpgradeCard_0 + UpgradePrev + Nav_LANGUAGE", "navigation": upgrades_action_authority, "localeToggle": upgrades_to_en},
		"primary": upgrade_first_primary,
		"forbidden": upgrade_tokens
	})

	var authored_capture_cases := [
		{
			"stageId": 2,
			"caseId": "leave_patina",
			"koCapture": "32_stage2_leave_patina_report_ready_ko",
			"enCapture": "33_stage2_leave_patina_report_ready_en",
			"npcKo": "아이리스 벨",
			"npcEn": "Iris Bell",
			"note": "Leave the Patina"
		},
		{
			"stageId": 2,
			"caseId": "estate_compass",
			"koCapture": "34_stage2_estate_compass_report_ready_ko",
			"enCapture": "35_stage2_estate_compass_report_ready_en",
			"npcKo": "레나 팔크",
			"npcEn": "Lena Falk",
			"note": "The Estate Compass"
		},
		{
			"stageId": 2,
			"caseId": "pawn_watch",
			"koCapture": "36_stage2_pawn_watch_report_ready_ko",
			"enCapture": "37_stage2_pawn_watch_report_ready_en",
			"npcKo": "레나 팔크",
			"npcEn": "Lena Falk",
			"note": "The Pawned Watch"
		},
		{
			"stageId": 3,
			"caseId": "garage_lamp",
			"koCapture": "38_stage3_garage_lamp_report_ready_ko",
			"enCapture": "39_stage3_garage_lamp_report_ready_en",
			"npcKo": "마라 벤",
			"npcEn": "Mara Venn",
			"note": "The Garage Lamp"
		},
		{
			"stageId": 3,
			"caseId": "telephone_trace",
			"koCapture": "40_stage3_telephone_trace_report_ready_ko",
			"enCapture": "41_stage3_telephone_trace_report_ready_en",
			"npcKo": "노아 스턴",
			"npcEn": "Noah Stern",
			"note": "A Voice in Bakelite"
		},
		{
			"stageId": 3,
			"caseId": "early_camera",
			"koCapture": "42_stage3_early_camera_report_ready_ko",
			"enCapture": "43_stage3_early_camera_report_ready_en",
			"npcKo": "하나 미레 박사",
			"npcEn": "Dr. Hana Mire",
			"note": "The Early Mechanical Camera"
		},
		{
			"stageId": 4,
			"caseId": "mislabelled_collection",
			"koCapture": "44_stage4_mislabelled_collection_report_ready_ko",
			"enCapture": "45_stage4_mislabelled_collection_report_ready_en",
			"npcKo": "하나 미레 박사",
			"npcEn": "Dr. Hana Mire",
			"requiredCitationsOnly": true,
			"includeNpcCitation": true,
			"note": "The Borrowed Accession Label"
		},
		{
			"stageId": 4,
			"caseId": "observatory_instrument",
			"koCapture": "46_stage4_observatory_instrument_report_ready_ko",
			"enCapture": "47_stage4_observatory_instrument_report_ready_en",
			"npcKo": "하나 미레 박사",
			"npcEn": "Dr. Hana Mire",
			"requiredCitationsOnly": true,
			"includeNpcCitation": true,
			"note": "Compass on the Meridian"
		},
		{
			"stageId": 5,
			"caseId": "collector_promise",
			"koCapture": "48_stage5_collector_promise_report_ready_ko",
			"enCapture": "49_stage5_collector_promise_report_ready_en",
			"npcKo": "빅터 헤일",
			"npcEn": "Victor Hale",
			"requiredCitationsOnly": true,
			"includeNpcCitation": true,
			"collapsedDetailMayBeOutsideViewport": true,
			"note": "The Promise in the Barometer"
		},
		{
			"stageId": 5,
			"caseId": "three_cameras",
			"koCapture": "50_stage5_three_cameras_report_ready_ko",
			"enCapture": "51_stage5_three_cameras_report_ready_en",
			"npcKo": "빅터 헤일",
			"npcEn": "Victor Hale",
			"requiredCitationsOnly": true,
			"includeNpcCitation": true,
			"collapsedDetailMayBeOutsideViewport": true,
			"note": "The Camera Between Two Pictures"
		}
	]
	for authored_case_value: Variant in authored_capture_cases:
		var authored_case: Dictionary = authored_case_value
		var authored_stage_id := int(authored_case.get("stageId", 0))
		var authored_case_id := String(authored_case.get("caseId", ""))
		var authored_ko_fixture := show_authored_report_ready_fixture(gs, main, "ko", authored_stage_id, authored_case_id, 4, bool(authored_case.get("requiredCitationsOnly", false)), bool(authored_case.get("includeNpcCitation", false)))
		authored_ko_fixture["collapsedDetailMayBeOutsideViewport"] = bool(authored_case.get("collapsedDetailMayBeOutsideViewport", true))
		authored_ko_fixture["reportScroll"] = await position_authored_report_view(main)
		var authored_ko_capture_id := String(authored_case.get("koCapture", ""))
		var authored_ko_fixture_failures: Array = []
		if not bool(authored_ko_fixture.get("ready", false)):
			authored_ko_fixture_failures.append("authored_report_ready_fixture_invalid")
		if not bool(authored_ko_fixture.get("reportScroll", {}).get("valid", false)):
			authored_ko_fixture_failures.append("authored_report_scroll_position_invalid")
		append_fixture_failures(authored_ko_capture_id, authored_ko_fixture_failures, {
			"ready": bool(authored_ko_fixture.get("ready", false)),
			"discoveredCount": int(authored_ko_fixture.get("discoveredCount", 0)),
			"citationCount": int(authored_ko_fixture.get("citationCount", 0)),
			"independentSourceCount": int(authored_ko_fixture.get("independentSourceCount", 0)),
			"requiredSourcesMet": bool(authored_ko_fixture.get("requiredSourcesMet", false)),
			"strongWithoutSubmission": bool(authored_ko_fixture.get("strong", false))
		})
		var authored_ko_specification := authored_report_capture_specification(gs, main, authored_case_id, "ko", authored_ko_fixture, String(authored_case.get("npcKo", "")))
		await capture_frame(main, authored_ko_capture_id, "ko", "The Korean Stage %d %s authored-v2 dossier shows a fully discovered, independently cited report-ready state through the real illustrated card renderer; the one intentional vertical dossier scroll stays horizontal-zero and clear of the report CTA." % [authored_stage_id, String(authored_case.get("note", "case"))], authored_ko_specification)
		var authored_ko_copy := visible_copy(main)

		var authored_en_fixture := show_authored_report_ready_fixture(gs, main, "en", authored_stage_id, authored_case_id, 4, bool(authored_case.get("requiredCitationsOnly", false)), bool(authored_case.get("includeNpcCitation", false)))
		authored_en_fixture["collapsedDetailMayBeOutsideViewport"] = bool(authored_case.get("collapsedDetailMayBeOutsideViewport", true))
		authored_en_fixture["reportScroll"] = await position_authored_report_view(main)
		var authored_en_capture_id := String(authored_case.get("enCapture", ""))
		var authored_en_copy := visible_copy(main)
		var authored_en_fixture_failures: Array = []
		if not bool(authored_en_fixture.get("ready", false)):
			authored_en_fixture_failures.append("authored_report_ready_fixture_invalid")
		if not bool(authored_en_fixture.get("reportScroll", {}).get("valid", false)):
			authored_en_fixture_failures.append("authored_report_scroll_position_invalid")
		if authored_en_copy == authored_ko_copy:
			authored_en_fixture_failures.append("authored_locale_copy_unchanged")
		append_fixture_failures(authored_en_capture_id, authored_en_fixture_failures, {
			"ready": bool(authored_en_fixture.get("ready", false)),
			"localeCopyChanged": authored_en_copy != authored_ko_copy,
			"discoveredCount": int(authored_en_fixture.get("discoveredCount", 0)),
			"citationCount": int(authored_en_fixture.get("citationCount", 0)),
			"independentSourceCount": int(authored_en_fixture.get("independentSourceCount", 0)),
			"requiredSourcesMet": bool(authored_en_fixture.get("requiredSourcesMet", false)),
			"strongWithoutSubmission": bool(authored_en_fixture.get("strong", false))
		})
		var authored_en_specification := authored_report_capture_specification(gs, main, authored_case_id, "en", authored_en_fixture, String(authored_case.get("npcEn", "")))
		await capture_frame(main, authored_en_capture_id, "en", "The English Stage %d %s authored-v2 dossier preserves the same real report-ready card state with localized authored copy, one intentional horizontal-zero dossier scroll, and no raw/private authority text in the viewport." % [authored_stage_id, String(authored_case.get("note", "case"))], authored_en_specification)

	var victor_detail_fixture := show_authored_npc_detail_fixture(gs, registry, main, "ko", 5, "collector_promise", "res://assets/portraits/victor_hale_neutral.svg")
	victor_detail_fixture["portraitPosition"] = await position_authored_npc_detail(main)
	var victor_detail_failures: Array = []
	if not bool(victor_detail_fixture.get("ready", false)):
		victor_detail_failures.append("victor_authored_npc_detail_fixture_invalid")
	if not bool(victor_detail_fixture.get("portraitPosition", {}).get("valid", false)):
		victor_detail_failures.append("victor_portrait_not_fully_visible_at_96x120")
	append_fixture_failures("52_stage5_victor_hale_npc_detail_ko", victor_detail_failures, victor_detail_fixture)
	await capture_frame(main, "52_stage5_victor_hale_npc_detail_ko", "ko", "Victor Hale's actual unlocked and discovered collector-promise clue detail shows the approved big-eyed neutral bust fully visible at the in-flow 96x120 size.", authored_npc_detail_capture_specification(gs, "collector_promise", "ko", victor_detail_fixture, "빅터 헤일"))

	var lena_detail_fixture := show_authored_npc_detail_fixture(gs, registry, main, "ko", 5, "shadow_camera", "res://assets/portraits/lena_falk_concerned.svg")
	lena_detail_fixture["portraitPosition"] = await position_authored_npc_detail(main)
	var lena_detail_failures: Array = []
	if not bool(lena_detail_fixture.get("ready", false)):
		lena_detail_failures.append("lena_authored_npc_detail_fixture_invalid")
	if not bool(lena_detail_fixture.get("portraitPosition", {}).get("valid", false)):
		lena_detail_failures.append("lena_portrait_not_fully_visible_at_96x120")
	append_fixture_failures("53_stage5_lena_falk_npc_detail_ko", lena_detail_failures, lena_detail_fixture)
	await capture_frame(main, "53_stage5_lena_falk_npc_detail_ko", "ko", "Lena Falk's actual unlocked and discovered shadow-camera clue detail shows the approved big-eyed concerned bust fully visible at the in-flow 96x120 size.", authored_npc_detail_capture_specification(gs, "shadow_camera", "ko", lena_detail_fixture, "레나 포크"))

	await capture_stage5_case_npc_portraits_2up(main, "54_stage5_case_npc_portraits_2up")

	var cipher_artifact := show_artifact_visual_fixture(gs, main, "en", "artifact_069", 990069)
	append_fixture_failures("55_artifact_069_typewriter_cipher_visual", ["artifact_069_fixture_missing"] if cipher_artifact.is_empty() else [], {"specId": "artifact_069"})
	await capture_workpiece_visual(main, registry, "55_artifact_069_typewriter_cipher_visual", "en", "artifact_069", "TYPEWRITER_CIPHER", "typewriter.obj", {
		"ArtifactMesh": 1,
		"CipherKeyline": 1,
		"CipherThirdRowKey_*": 9,
		"CipherPairedGlyph_*": 2,
		"CipherFiledStop_*": 2
	}, ["VariantTrim_*", "Sextant*"], "The unobstructed artifact_069 workpiece makes its cipher keyline, paired glyphs, distinct third key row, and filed stops directly reviewable on the existing typewriter silhouette.")

	var sextant_artifact := show_artifact_visual_fixture(gs, main, "en", "artifact_070", 990070)
	append_fixture_failures("56_artifact_070_sextant_visual", ["artifact_070_fixture_missing"] if sextant_artifact.is_empty() else [], {"specId": "artifact_070"})
	await capture_workpiece_visual(main, registry, "56_artifact_070_sextant_visual", "en", "artifact_070", "SEXTANT", "sextant.obj", {
		"ArtifactMesh": 1,
		"SextantArcDegree_*": 11,
		"SextantDegreeVernier": 1,
		"SextantIndexMirror": 1,
		"SextantThirtyDegreeWear": 1
	}, ["VariantTrim_*", "Cipher*", "*Compass*"], "The unobstructed artifact_070 workpiece shows a recognizable sextant frame, graduated arc, vernier and mirror without reusing the compass silhouette.")

	var artifact_spec_sheets := await build_artifact_spec_contact_sheets(gs, main, registry)

	var stage6_capture_cases := [
		{
			"stageId": 6,
			"caseId": "shadow_gauge",
			"koCapture": "59_stage6_shadow_gauge_report_ready_ko",
			"enCapture": "60_stage6_shadow_gauge_report_ready_en",
			"npcKo": "하나 미레 박사",
			"npcEn": "Dr. Hana Mire",
			"note": "Shadow Mark: Gauge"
		},
		{
			"stageId": 6,
			"caseId": "shadow_clock",
			"koCapture": "61_stage6_shadow_clock_report_ready_ko",
			"enCapture": "62_stage6_shadow_clock_report_ready_en",
			"npcKo": "마라 벤",
			"npcEn": "Mara Venn",
			"note": "Shadow Mark: Clock"
		},
		{
			"stageId": 6,
			"caseId": "shadow_music_box",
			"koCapture": "63_stage6_shadow_music_box_report_ready_ko",
			"enCapture": "64_stage6_shadow_music_box_report_ready_en",
			"npcKo": "아이리스 벨",
			"npcEn": "Iris Bell",
			"note": "Shadow Mark: Music Box"
		}
	]
	for stage6_case_value: Variant in stage6_capture_cases:
		var stage6_case: Dictionary = stage6_case_value
		var stage6_stage_id := int(stage6_case.get("stageId", 6))
		var stage6_case_id := String(stage6_case.get("caseId", ""))
		var stage6_ko_fixture := show_authored_report_ready_fixture(gs, main, "ko", stage6_stage_id, stage6_case_id, 4, true, true)
		stage6_ko_fixture["collapsedDetailMayBeOutsideViewport"] = true
		stage6_ko_fixture["reportScroll"] = await position_authored_report_view(main)
		var stage6_ko_capture_id := String(stage6_case.get("koCapture", ""))
		var stage6_ko_fixture_failures: Array = []
		if not bool(stage6_ko_fixture.get("ready", false)):
			stage6_ko_fixture_failures.append("stage6_authored_report_ready_fixture_invalid")
		if int(stage6_ko_fixture.get("evidenceCount", 0)) != 6:
			stage6_ko_fixture_failures.append("stage6_source_count:%d_expected_6" % int(stage6_ko_fixture.get("evidenceCount", 0)))
		if int(stage6_ko_fixture.get("hypothesisCount", 0)) != 3:
			stage6_ko_fixture_failures.append("stage6_hypothesis_count:%d_expected_3" % int(stage6_ko_fixture.get("hypothesisCount", 0)))
		if not bool(stage6_ko_fixture.get("reportScroll", {}).get("valid", false)):
			stage6_ko_fixture_failures.append("stage6_authored_report_scroll_position_invalid")
		append_fixture_failures(stage6_ko_capture_id, stage6_ko_fixture_failures, {
			"ready": bool(stage6_ko_fixture.get("ready", false)),
			"sourceCardCount": int(stage6_ko_fixture.get("evidenceCount", 0)),
			"hypothesisCount": int(stage6_ko_fixture.get("hypothesisCount", 0)),
			"citationCount": int(stage6_ko_fixture.get("citationCount", 0)),
			"independentSourceCount": int(stage6_ko_fixture.get("independentSourceCount", 0)),
			"requiredSourcesMet": bool(stage6_ko_fixture.get("requiredSourcesMet", false)),
			"strongWithoutSubmission": bool(stage6_ko_fixture.get("strong", false)),
			"actualInFlow": true,
			"submitCta": "ResolveCaseReport"
		})
		var stage6_ko_specification := authored_report_capture_specification(gs, main, stage6_case_id, "ko", stage6_ko_fixture, String(stage6_case.get("npcKo", "")))
		await capture_frame(main, stage6_ko_capture_id, "ko", "The Korean Stage 6 %s authored-v2 dossier shows all six source cards, all three hypotheses and the real report CTA in a strongly substantiated in-flow state." % String(stage6_case.get("note", "case")), stage6_ko_specification)
		var stage6_ko_copy := visible_copy(main)

		var stage6_en_fixture := show_authored_report_ready_fixture(gs, main, "en", stage6_stage_id, stage6_case_id, 4, true, true)
		stage6_en_fixture["collapsedDetailMayBeOutsideViewport"] = true
		stage6_en_fixture["reportScroll"] = await position_authored_report_view(main)
		var stage6_en_capture_id := String(stage6_case.get("enCapture", ""))
		var stage6_en_copy := visible_copy(main)
		var stage6_en_fixture_failures: Array = []
		if not bool(stage6_en_fixture.get("ready", false)):
			stage6_en_fixture_failures.append("stage6_authored_report_ready_fixture_invalid")
		if int(stage6_en_fixture.get("evidenceCount", 0)) != 6:
			stage6_en_fixture_failures.append("stage6_source_count:%d_expected_6" % int(stage6_en_fixture.get("evidenceCount", 0)))
		if int(stage6_en_fixture.get("hypothesisCount", 0)) != 3:
			stage6_en_fixture_failures.append("stage6_hypothesis_count:%d_expected_3" % int(stage6_en_fixture.get("hypothesisCount", 0)))
		if not bool(stage6_en_fixture.get("reportScroll", {}).get("valid", false)):
			stage6_en_fixture_failures.append("stage6_authored_report_scroll_position_invalid")
		if stage6_en_copy == stage6_ko_copy:
			stage6_en_fixture_failures.append("stage6_authored_locale_copy_unchanged")
		append_fixture_failures(stage6_en_capture_id, stage6_en_fixture_failures, {
			"ready": bool(stage6_en_fixture.get("ready", false)),
			"localeCopyChanged": stage6_en_copy != stage6_ko_copy,
			"sourceCardCount": int(stage6_en_fixture.get("evidenceCount", 0)),
			"hypothesisCount": int(stage6_en_fixture.get("hypothesisCount", 0)),
			"citationCount": int(stage6_en_fixture.get("citationCount", 0)),
			"independentSourceCount": int(stage6_en_fixture.get("independentSourceCount", 0)),
			"requiredSourcesMet": bool(stage6_en_fixture.get("requiredSourcesMet", false)),
			"strongWithoutSubmission": bool(stage6_en_fixture.get("strong", false)),
			"actualInFlow": true,
			"submitCta": "ResolveCaseReport"
		})
		var stage6_en_specification := authored_report_capture_specification(gs, main, stage6_case_id, "en", stage6_en_fixture, String(stage6_case.get("npcEn", "")))
		await capture_frame(main, stage6_en_capture_id, "en", "The English Stage 6 %s authored-v2 dossier preserves the same six-source, three-hypothesis, report-ready in-flow state with localized public copy." % String(stage6_case.get("note", "case")), stage6_en_specification)

	var hana_detail_fixture := show_authored_npc_detail_fixture(gs, registry, main, "ko", 6, "shadow_gauge", "res://assets/portraits/hana_mire_concerned.svg")
	hana_detail_fixture["portraitPosition"] = await position_authored_npc_detail(main)
	var hana_detail_failures: Array = []
	if not bool(hana_detail_fixture.get("ready", false)):
		hana_detail_failures.append("hana_authored_npc_detail_fixture_invalid")
	if not bool(hana_detail_fixture.get("portraitPosition", {}).get("valid", false)):
		hana_detail_failures.append("hana_portrait_not_fully_visible_at_96x120")
	append_fixture_failures("65_stage6_hana_mire_npc_detail_ko", hana_detail_failures, hana_detail_fixture)
	await capture_frame(main, "65_stage6_hana_mire_npc_detail_ko", "ko", "Dr. Hana Mire's actual unlocked and discovered shadow-gauge clue detail shows the approved big-eyed concerned bust fully visible at the in-flow 96x120 size.", authored_npc_detail_capture_specification(gs, "shadow_gauge", "ko", hana_detail_fixture, "하나 미레 박사"))

	var mara_detail_fixture := show_authored_npc_detail_fixture(gs, registry, main, "ko", 6, "shadow_clock", "res://assets/portraits/mara_venn_concerned.svg")
	mara_detail_fixture["portraitPosition"] = await position_authored_npc_detail(main)
	var mara_detail_failures: Array = []
	if not bool(mara_detail_fixture.get("ready", false)):
		mara_detail_failures.append("mara_authored_npc_detail_fixture_invalid")
	if not bool(mara_detail_fixture.get("portraitPosition", {}).get("valid", false)):
		mara_detail_failures.append("mara_portrait_not_fully_visible_at_96x120")
	append_fixture_failures("66_stage6_mara_venn_npc_detail_ko", mara_detail_failures, mara_detail_fixture)
	await capture_frame(main, "66_stage6_mara_venn_npc_detail_ko", "ko", "Mara Venn's actual unlocked and discovered shadow-clock clue detail shows the approved big-eyed concerned bust fully visible at the in-flow 96x120 size.", authored_npc_detail_capture_specification(gs, "shadow_clock", "ko", mara_detail_fixture, "마라 벤"))

	var iris_detail_fixture := show_authored_npc_detail_fixture(gs, registry, main, "ko", 6, "shadow_music_box", "res://assets/portraits/iris_bell_concerned.svg")
	iris_detail_fixture["portraitPosition"] = await position_authored_npc_detail(main)
	var iris_detail_failures: Array = []
	if not bool(iris_detail_fixture.get("ready", false)):
		iris_detail_failures.append("iris_authored_npc_detail_fixture_invalid")
	if not bool(iris_detail_fixture.get("portraitPosition", {}).get("valid", false)):
		iris_detail_failures.append("iris_portrait_not_fully_visible_at_96x120")
	append_fixture_failures("67_stage6_iris_bell_npc_detail_ko", iris_detail_failures, iris_detail_fixture)
	await capture_frame(main, "67_stage6_iris_bell_npc_detail_ko", "ko", "Iris Bell's actual unlocked and discovered shadow-music-box clue detail shows the approved big-eyed concerned bust fully visible at the in-flow 96x120 size.", authored_npc_detail_capture_specification(gs, "shadow_music_box", "ko", iris_detail_fixture, "아이리스 벨"))

	await capture_stage6_case_npc_portraits_3up(main, "68_stage6_case_npc_portraits_3up")

	var gauge_story_artifact := show_story_artifact_visual_fixture(gs, main, "en", "story_artifact_16", "artifact_050", 996050, 2.65)
	append_fixture_failures("69_story_artifact_16_artifact_050_gauge_visual", ["story_artifact_16_artifact_050_fixture_missing"] if gauge_story_artifact.is_empty() else [], {"storyArtifactId": "story_artifact_16", "artifactSpecId": "artifact_050"})
	await capture_story_artifact_workpiece_visual(main, registry, "69_story_artifact_16_artifact_050_gauge_visual", "en", "story_artifact_16", "artifact_050", "GAUGE", "res://assets/artifacts/gauge.obj", {
		"ArtifactMesh": 1,
		"GaugeScaleTick_*": 13,
		"GaugePressureNeedle": 1,
		"GaugePressureHub": 1,
		"GaugeCalibrationPlate": 1,
		"GaugeCalibrationSeal": 1
	}, ["VariantTrim_*", "MusicBox*", "Cipher*", "Sextant*", "*Compass*"], "The fresh story_artifact_16 + artifact_050 pair consumes the instance render DTO and shows the gauge's dominant base mesh, calibrated scale, pressure needle, hub, plate and seal without generic trim.")

	var music_story_artifact := show_story_artifact_visual_fixture(gs, main, "en", "story_artifact_18", "artifact_035", 996035, 3.75)
	append_fixture_failures("70_story_artifact_18_artifact_035_music_box_visual", ["story_artifact_18_artifact_035_fixture_missing"] if music_story_artifact.is_empty() else [], {"storyArtifactId": "story_artifact_18", "artifactSpecId": "artifact_035"})
	await capture_story_artifact_workpiece_visual(main, registry, "70_story_artifact_18_artifact_035_music_box_visual", "en", "story_artifact_18", "artifact_035", "MUSIC_BOX", "res://assets/artifacts/music_box.obj", {
		"ArtifactMesh": 1,
		"MusicBoxPinnedCylinder": 1,
		"MusicBoxCylinderPin_*": 8,
		"MusicBoxComb": 1,
		"MusicBoxCombTooth_*": 7,
		"MusicBoxWindingStem": 1,
		"MusicBoxWindingKey": 1,
		"MusicBoxLidInlay": 1
	}, ["VariantTrim_*", "Gauge*", "Cipher*", "Sextant*", "*Compass*"], "The fresh story_artifact_18 + artifact_035 pair consumes the instance render DTO and shows the music box's dominant base mesh, pinned cylinder, comb, teeth, winding key and lid inlay without generic trim.")

	var stage7_capture_cases := [
		{
			"stageId": 7,
			"caseId": "shadow_optic",
			"koCapture": "71_stage7_shadow_optic_report_ready_ko",
			"enCapture": "72_stage7_shadow_optic_report_ready_en",
			"npcKo": "빅터 헤일",
			"npcEn": "Victor Hale",
			"note": "Shadow Mark: Optic"
		},
		{
			"stageId": 7,
			"caseId": "composite_prototype",
			"koCapture": "73_stage7_composite_prototype_report_ready_ko",
			"enCapture": "74_stage7_composite_prototype_report_ready_en",
			"npcKo": "노아 스턴",
			"npcEn": "Noah Stern",
			"note": "The Composite Prototype"
		}
	]
	for stage7_case_value: Variant in stage7_capture_cases:
		var stage7_case: Dictionary = stage7_case_value
		var stage7_stage_id := int(stage7_case.get("stageId", 7))
		var stage7_case_id := String(stage7_case.get("caseId", ""))
		var stage7_ko_fixture := show_authored_report_ready_fixture(gs, main, "ko", stage7_stage_id, stage7_case_id, 4, true, true)
		var stage7_ko_citation_ids: Array = stage7_ko_fixture.get("citationIds", [])
		if not stage7_ko_citation_ids.is_empty():
			# Keep the bottom-of-dossier report capture free of a second, nested
			# portrait-detail scroller. The first cited object source still shows
			# the same real resolved report draft and keeps the NPC citation card.
			main.case_detail_evidence_id = String(stage7_ko_citation_ids[0])
			main.show_case_dossier(stage7_case_id)
		stage7_ko_fixture["collapsedDetailMayBeOutsideViewport"] = true
		stage7_ko_fixture["reportScroll"] = await position_authored_report_view(main)
		var stage7_ko_capture_id := String(stage7_case.get("koCapture", ""))
		var stage7_ko_fixture_failures: Array = []
		if not bool(stage7_ko_fixture.get("ready", false)):
			stage7_ko_fixture_failures.append("stage7_authored_report_ready_fixture_invalid")
		if int(stage7_ko_fixture.get("evidenceCount", 0)) != 6:
			stage7_ko_fixture_failures.append("stage7_source_count:%d_expected_6" % int(stage7_ko_fixture.get("evidenceCount", 0)))
		if int(stage7_ko_fixture.get("hypothesisCount", 0)) != 3:
			stage7_ko_fixture_failures.append("stage7_hypothesis_count:%d_expected_3" % int(stage7_ko_fixture.get("hypothesisCount", 0)))
		if not bool(stage7_ko_fixture.get("reportScroll", {}).get("valid", false)):
			stage7_ko_fixture_failures.append("stage7_authored_report_scroll_position_invalid")
		append_fixture_failures(stage7_ko_capture_id, stage7_ko_fixture_failures, {
			"ready": bool(stage7_ko_fixture.get("ready", false)),
			"sourceCardCount": int(stage7_ko_fixture.get("evidenceCount", 0)),
			"hypothesisCount": int(stage7_ko_fixture.get("hypothesisCount", 0)),
			"citationCount": int(stage7_ko_fixture.get("citationCount", 0)),
			"independentSourceCount": int(stage7_ko_fixture.get("independentSourceCount", 0)),
			"requiredSourcesMet": bool(stage7_ko_fixture.get("requiredSourcesMet", false)),
			"strongWithoutSubmission": bool(stage7_ko_fixture.get("strong", false)),
			"actualInFlow": true,
			"submitCta": "ResolveCaseReport"
		})
		var stage7_ko_specification := authored_report_capture_specification(gs, main, stage7_case_id, "ko", stage7_ko_fixture, String(stage7_case.get("npcKo", "")))
		await capture_frame(main, stage7_ko_capture_id, "ko", "The Korean Stage 7 %s authored-v2 dossier shows all six source cards, all three hypotheses and the real report CTA in a strongly substantiated in-flow state." % String(stage7_case.get("note", "case")), stage7_ko_specification)
		var stage7_ko_copy := visible_copy(main)

		var stage7_en_fixture := show_authored_report_ready_fixture(gs, main, "en", stage7_stage_id, stage7_case_id, 4, true, true)
		var stage7_en_citation_ids: Array = stage7_en_fixture.get("citationIds", [])
		if not stage7_en_citation_ids.is_empty():
			main.case_detail_evidence_id = String(stage7_en_citation_ids[0])
			main.show_case_dossier(stage7_case_id)
		stage7_en_fixture["collapsedDetailMayBeOutsideViewport"] = true
		stage7_en_fixture["reportScroll"] = await position_authored_report_view(main)
		var stage7_en_capture_id := String(stage7_case.get("enCapture", ""))
		var stage7_en_copy := visible_copy(main)
		var stage7_en_fixture_failures: Array = []
		if not bool(stage7_en_fixture.get("ready", false)):
			stage7_en_fixture_failures.append("stage7_authored_report_ready_fixture_invalid")
		if int(stage7_en_fixture.get("evidenceCount", 0)) != 6:
			stage7_en_fixture_failures.append("stage7_source_count:%d_expected_6" % int(stage7_en_fixture.get("evidenceCount", 0)))
		if int(stage7_en_fixture.get("hypothesisCount", 0)) != 3:
			stage7_en_fixture_failures.append("stage7_hypothesis_count:%d_expected_3" % int(stage7_en_fixture.get("hypothesisCount", 0)))
		if not bool(stage7_en_fixture.get("reportScroll", {}).get("valid", false)):
			stage7_en_fixture_failures.append("stage7_authored_report_scroll_position_invalid")
		if stage7_en_copy == stage7_ko_copy:
			stage7_en_fixture_failures.append("stage7_authored_locale_copy_unchanged")
		append_fixture_failures(stage7_en_capture_id, stage7_en_fixture_failures, {
			"ready": bool(stage7_en_fixture.get("ready", false)),
			"localeCopyChanged": stage7_en_copy != stage7_ko_copy,
			"sourceCardCount": int(stage7_en_fixture.get("evidenceCount", 0)),
			"hypothesisCount": int(stage7_en_fixture.get("hypothesisCount", 0)),
			"citationCount": int(stage7_en_fixture.get("citationCount", 0)),
			"independentSourceCount": int(stage7_en_fixture.get("independentSourceCount", 0)),
			"requiredSourcesMet": bool(stage7_en_fixture.get("requiredSourcesMet", false)),
			"strongWithoutSubmission": bool(stage7_en_fixture.get("strong", false)),
			"actualInFlow": true,
			"submitCta": "ResolveCaseReport"
		})
		var stage7_en_specification := authored_report_capture_specification(gs, main, stage7_case_id, "en", stage7_en_fixture, String(stage7_case.get("npcEn", "")))
		await capture_frame(main, stage7_en_capture_id, "en", "The English Stage 7 %s authored-v2 dossier preserves the same six-source, three-hypothesis, report-ready in-flow state with localized public copy." % String(stage7_case.get("note", "case")), stage7_en_specification)

	var stage7_victor_detail_fixture := show_authored_npc_detail_fixture(gs, registry, main, "ko", 7, "shadow_optic", "res://assets/portraits/victor_hale_neutral.svg")
	stage7_victor_detail_fixture["portraitPosition"] = await position_authored_npc_detail(main)
	var stage7_victor_detail_failures: Array = []
	if not bool(stage7_victor_detail_fixture.get("ready", false)):
		stage7_victor_detail_failures.append("stage7_victor_authored_npc_detail_fixture_invalid")
	if not bool(stage7_victor_detail_fixture.get("portraitPosition", {}).get("valid", false)):
		stage7_victor_detail_failures.append("stage7_victor_portrait_not_fully_visible_at_96x120")
	append_fixture_failures("75_stage7_victor_hale_neutral_npc_detail_ko", stage7_victor_detail_failures, stage7_victor_detail_fixture)
	await capture_frame(main, "75_stage7_victor_hale_neutral_npc_detail_ko", "ko", "Victor Hale's actual unlocked and discovered shadow-optic clue detail shows the approved big-eyed neutral bust fully visible at the in-flow 96x120 size.", authored_npc_detail_capture_specification(gs, "shadow_optic", "ko", stage7_victor_detail_fixture, "빅터 헤일"))

	var stage7_noah_detail_fixture := show_authored_npc_detail_fixture(gs, registry, main, "ko", 7, "composite_prototype", "res://assets/portraits/noah_stern_concerned.svg")
	stage7_noah_detail_fixture["portraitPosition"] = await position_authored_npc_detail(main)
	var stage7_noah_detail_failures: Array = []
	if not bool(stage7_noah_detail_fixture.get("ready", false)):
		stage7_noah_detail_failures.append("stage7_noah_authored_npc_detail_fixture_invalid")
	if not bool(stage7_noah_detail_fixture.get("portraitPosition", {}).get("valid", false)):
		stage7_noah_detail_failures.append("stage7_noah_portrait_not_fully_visible_at_96x120")
	append_fixture_failures("76_stage7_noah_stern_concerned_npc_detail_ko", stage7_noah_detail_failures, stage7_noah_detail_fixture)
	await capture_frame(main, "76_stage7_noah_stern_concerned_npc_detail_ko", "ko", "Noah Stern's actual unlocked and discovered composite-prototype clue detail shows the approved big-eyed concerned bust fully visible at the in-flow 96x120 size.", authored_npc_detail_capture_specification(gs, "composite_prototype", "ko", stage7_noah_detail_fixture, "노아 스턴"))

	await capture_stage7_case_npc_portraits_2up(main, "77_stage7_victor_noah_case_npc_portraits_2up")

	var optic_story_artifact := show_story_artifact_visual_fixture(gs, main, "en", "story_artifact_19", "artifact_057", 997057, 3.45)
	append_fixture_failures("78_story_artifact_19_artifact_057_optic_visual", ["story_artifact_19_artifact_057_fixture_missing"] if optic_story_artifact.is_empty() else [], {"storyArtifactId": "story_artifact_19", "artifactSpecId": "artifact_057"})
	await capture_story_artifact_workpiece_visual(main, registry, "78_story_artifact_19_artifact_057_optic_visual", "en", "story_artifact_19", "artifact_057", "OPTIC", "res://assets/artifacts/model_12.obj", {
		"ArtifactMesh": 1,
		"Optic*": 10,
		"OpticTelescopeBarrel": 1,
		"OpticObjectiveHousing": 1,
		"OpticObjectiveLens": 1,
		"OpticEyepiece": 1,
		"OpticFocusCollar": 1,
		"OpticMountingYoke": 1,
		"OpticYokeSupport_*": 2,
		"OpticSupportFoot": 1,
		"OpticOpticalAxis": 1
	}, ["VariantTrim_*", "Gauge*", "MusicBox*", "Cipher*", "Sextant*", "Composite*", "*Compass*"], "The fresh story_artifact_19 + artifact_057 pair consumes the instance render DTO and shows a recognizable ten-node OPTIC telescope silhouette while the unrelated legacy gauge base remains present with non-zero geometry but intentionally hidden.", false)

	var composite_story_artifact := show_story_artifact_visual_fixture(gs, main, "en", "story_artifact_20", "artifact_059", 997059, 3.45)
	append_fixture_failures("79_story_artifact_20_artifact_059_composite_visual", ["story_artifact_20_artifact_059_fixture_missing"] if composite_story_artifact.is_empty() else [], {"storyArtifactId": "story_artifact_20", "artifactSpecId": "artifact_059"})
	await capture_story_artifact_workpiece_visual(main, registry, "79_story_artifact_20_artifact_059_composite_visual", "en", "story_artifact_20", "artifact_059", "COMPOSITE", "res://assets/artifacts/model_14.obj", {
		"ArtifactMesh": 1,
		"Composite*": 21,
		"CompositeMainMeasuringBody": 1,
		"CompositeGraduatedDial": 1,
		"CompositeScaleTick_*": 11,
		"CompositeMeasurementNeedle": 1,
		"CompositeSecondaryComponent": 1,
		"CompositeSecondaryComponentCap": 1,
		"CompositeAdapterInterfaceJoint": 1,
		"CompositeMismatchedConnector": 1,
		"CompositeMismatchedFastener_*": 3
	}, ["VariantTrim_*", "Gauge*", "MusicBox*", "Cipher*", "Sextant*", "Optic*", "*Compass*"], "The fresh story_artifact_20 + artifact_059 pair consumes the instance render DTO and shows a recognizable twenty-one-node COMPOSITE measuring assembly while the unrelated legacy camera base remains present with non-zero geometry but intentionally hidden.", false)

	var contact_sheet_path := build_contact_sheet() if framebuffer_capture_enabled else ""
	var hashes := capture_hashes() if framebuffer_capture_enabled else {}
	var passed_count := captures.filter(func(capture: Dictionary): return capture.get("status", "FAIL") == "PASS").size()
	var report := {
		"suite": "R3 Latest Actual Runtime Viewport QA" if framebuffer_capture_enabled else "R3 Headless Runtime Viewport Density",
		"renderMode": "Godot 4.7.1 CLI in a hidden off-screen background process using OpenGL compatibility" if framebuffer_capture_enabled else "Godot 4.7.1 --headless control-tree layout",
		"backgroundOnly": true,
		"headlessDummyLimitation": "On Windows, Godot --headless selects the dummy renderer and exposes no framebuffer; the supplied runner keeps the real-render process hidden and off-screen.",
		"mainScene": "res://scenes/Main.tscn",
		"syntheticReconstruction": false,
		"framebufferCaptured": framebuffer_capture_enabled,
		"resolution": [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"outputDirectory": OUTPUT_DIR,
		"contactSheet": contact_sheet_path,
		"artifactSpecContactSheets": artifact_spec_sheets,
		"captureHashes": hashes,
		"originalResolutionVisualReview": verified_original_resolution_review(hashes),
		"persistenceEnabled": false,
		"heldArtifactsCreated": false,
		"executed": captures.size(),
		"passed": passed_count,
		"failed": captures.size() - passed_count + layout_failures.filter(func(failure: Dictionary): return not captures.any(func(capture: Dictionary): return capture.id == failure.get("captureId", "") and capture.status == "FAIL")).size(),
		"captures": captures,
		"layoutFailures": layout_failures
	}
	var report_path := "res://qa/R3_LATEST_RUNTIME_VIEWPORT_QA.json" if framebuffer_capture_enabled else "res://qa/R3_VIEWPORT_DENSITY_TESTS.json"
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file == null:
		push_error("Could not write viewport QA report")
		main.queue_free()
		quit(1)
		return
	report_file.store_string(JSON.stringify(report, "  "))
	report_file.close()
	print(JSON.stringify({"suite": report.suite, "executed": report.executed, "passed": report.passed, "failed": report.failed, "contactSheet": contact_sheet_path}))
	# Live auction screens own short portrait tweens and SVG textures. Free the
	# instantiated scene synchronously so teardown cannot race SceneTree.quit().
	# The three public Hammer actions also start a WAV. Explicitly stop and detach
	# that stream because the QA tree intentionally exits before the SFX duration.
	if main.audio is AudioStreamPlayer:
		main.audio.stop()
		main.audio.stream = null
	main.free()
	await process_frame
	quit(0 if layout_failures.is_empty() and passed_count == captures.size() else 1)
