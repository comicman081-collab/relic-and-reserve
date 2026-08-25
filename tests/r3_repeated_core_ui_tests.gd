extends SceneTree

## Repeated core-screen compact UI contract.
##
## The suite drives only public Button signals. Card presses may change local UI
## selection; gameplay authority remains on Inspect, Accept and Buy.

const HYPOTHESES := [
	"GENUINE", "GENUINE_WITH_PERIOD_REPAIR", "GENUINE_WITH_MODERN_REPAIR",
	"REPRODUCTION", "FORGERY", "UNKNOWN"
]
const EVIDENCE_IDS := [
	"MAKER_MARK", "SERIAL_PATTERN", "MATERIAL", "CONSTRUCTION_METHOD",
	"COMPONENT_STYLE", "REPAIR_TRACE", "PATINA", "PROVENANCE"
]
const TUTORIAL_STEPS := ["INVESTIGATE", "CITE", "REPORT", "REPAIR", "LIST", "AUCTION"]
const EXPECTED_TEST_COUNT := 10
const REPORT_PATH := "res://qa/R3_REPEATED_CORE_UI_TESTS.json"

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func settle_ui(frame_count: int = 5) -> void:
	for _frame: int in range(frame_count):
		await process_frame


func visible_nodes_named(root: Node, pattern: String, type_name: String = "") -> Array:
	var visible: Array = []
	if root == null or not is_instance_valid(root):
		return visible
	for candidate: Node in root.find_children(pattern, type_name, true, false):
		if candidate is CanvasItem and not (candidate as CanvasItem).is_visible_in_tree():
			continue
		visible.append(candidate)
	return visible


func visible_named(root: Node, node_name: String, type_name: String = "") -> Node:
	var matches: Array = visible_nodes_named(root, node_name, type_name)
	return matches[0] as Node if not matches.is_empty() else null


func visible_copy(root: Node) -> String:
	var copy: String = ""
	if root == null or not is_instance_valid(root):
		return copy
	for label: Node in root.find_children("*", "Label", true, false):
		if (label as Label).is_visible_in_tree():
			copy += String((label as Label).text) + "\n"
	for button: Node in root.find_children("*", "Button", true, false):
		if (button as Button).is_visible_in_tree():
			copy += String((button as Button).text) + "\n"
	return copy


func normalized_progress(copy: String) -> String:
	return copy.replace(" ", "").replace("\n", "")


func contains_hangul(copy: String) -> bool:
	for index: int in range(copy.length()):
		var codepoint: int = copy.unicode_at(index)
		if codepoint >= 0xAC00 and codepoint <= 0xD7A3:
			return true
	return false


func button_has_icon(button: Node) -> bool:
	if not button is Button:
		return false
	if (button as Button).icon != null:
		return true
	for icon_value: Node in button.find_children("*", "TextureRect", true, false):
		if (icon_value as TextureRect).texture != null:
			return true
	return false


func rect_evidence(node: Node) -> Dictionary:
	if node == null or not is_instance_valid(node) or not node is Control:
		return {"present": false, "inside1280x720": false, "rect": []}
	var rect: Rect2 = (node as Control).get_global_rect()
	return {
		"present": true,
		"inside1280x720": rect.size.x > 0.0 and rect.size.y > 0.0 \
			and rect.position.x >= 0.0 and rect.position.y >= 0.0 \
			and rect.end.x <= 1280.0 and rect.end.y <= 720.0,
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	}


func pager_label_contract(node: Node, current_page: int, page_count: int, minimum_width: float) -> Dictionary:
	var expected_text: String = "%d/%d" % [current_page, page_count]
	if not node is Label:
		return {
			"ok": false, "present": false, "expected": expected_text,
			"minimumWidth": minimum_width
		}
	var label: Label = node as Label
	var rect: Rect2 = label.get_global_rect()
	var text_lines: int = label.text.split("\n").size()
	var rendered_lines: int = label.get_line_count()
	var normalized_text: String = normalized_progress(label.text)
	var width_ok: bool = rect.size.x >= minimum_width
	var height_ok: bool = rect.size.y > 0.0
	var single_line: bool = text_lines == 1 and rendered_lines == 1 and label.max_lines_visible == 1
	var wrap_off: bool = label.autowrap_mode == TextServer.AUTOWRAP_OFF
	var centered: bool = label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER \
		and label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER
	var text_exact: bool = normalized_text == expected_text
	return {
		"ok": width_ok and height_ok and single_line and wrap_off and centered and text_exact,
		"present": true,
		"text": label.text,
		"normalizedText": normalized_text,
		"expected": expected_text,
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"minimumWidth": minimum_width,
		"widthOk": width_ok,
		"heightOk": height_ok,
		"textLineCount": text_lines,
		"renderedLineCount": rendered_lines,
		"maxLinesVisible": label.max_lines_visible,
		"autowrapOff": wrap_off,
		"horizontalCentered": label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"verticalCentered": label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER,
		"textExact": text_exact
	}


func controls_geometry(nodes: Array, forbidden: Array = []) -> Dictionary:
	var evidence_rows: Array = []
	var inside: bool = true
	var separate: bool = true
	var avoids_forbidden: bool = true
	for node_value: Variant in nodes:
		var node: Node = node_value as Node if node_value is Node else null
		var evidence: Dictionary = rect_evidence(node)
		evidence_rows.append(evidence)
		inside = inside and bool(evidence.get("inside1280x720", false))
	for left_index: int in range(nodes.size()):
		if not nodes[left_index] is Control:
			separate = false
			continue
		for right_index: int in range(left_index + 1, nodes.size()):
			if not nodes[right_index] is Control:
				separate = false
				continue
			separate = separate and not (nodes[left_index] as Control).get_global_rect().intersects((nodes[right_index] as Control).get_global_rect())
	for node_value: Variant in nodes:
		if not node_value is Control:
			avoids_forbidden = false
			continue
		var node_rect: Rect2 = (node_value as Control).get_global_rect()
		for forbidden_value: Variant in forbidden:
			if forbidden_value is Control and is_instance_valid(forbidden_value) and (forbidden_value as Control).is_visible_in_tree():
				avoids_forbidden = avoids_forbidden and not node_rect.intersects((forbidden_value as Control).get_global_rect())
	return {
		"ok": inside and separate and avoids_forbidden,
		"inside": inside,
		"separate": separate,
		"avoidsForbidden": avoids_forbidden,
		"rects": evidence_rows
	}


func density_evidence(root: Node, max_labels: int, max_buttons: int, max_characters: int) -> Dictionary:
	var labels: Array = visible_nodes_named(root, "*", "Label")
	var buttons: Array = visible_nodes_named(root, "*", "Button")
	var characters: int = 0
	for label_value: Variant in labels:
		characters += String((label_value as Label).text).length()
	for button_value: Variant in buttons:
		characters += String((button_value as Button).text).length()
	return {
		"ok": labels.size() <= max_labels and buttons.size() <= max_buttons and characters <= max_characters,
		"labels": labels.size(),
		"buttons": buttons.size(),
		"characters": characters,
		"caps": [max_labels, max_buttons, max_characters]
	}


func chrome_nodes(main: Node) -> Array:
	var nodes: Array = []
	for node_name: String in ["Navigation", "StatusMessage"]:
		var node: Node = visible_named(main, node_name)
		if node != null:
			nodes.append(node)
	return nodes


func has_visible_scroll(main: Node) -> bool:
	return not visible_nodes_named(main, "*", "ScrollContainer").is_empty()


func localized_state_signature(gs: Node, draft_uid: String = "") -> String:
	var payload: Dictionary = gs.save_payload().duplicate(true)
	payload["language"] = "<locale>"
	if not draft_uid.is_empty():
		var inventory_value: Variant = payload.get("inventory", [])
		if inventory_value is Array:
			for artifact_value: Variant in inventory_value:
				if artifact_value is Dictionary and String((artifact_value as Dictionary).get("uniqueId", "")) == draft_uid:
					(artifact_value as Dictionary)["playerHypothesis"] = "<allowed-draft>"
	return JSON.stringify({"run": payload, "profile": gs.profile_payload()})


func inspect_neutral_state_signature(gs: Node) -> String:
	var payload: Dictionary = gs.save_payload().duplicate(true)
	payload["language"] = "<locale>"
	# Inspect is the one authorized inventory action and therefore may select the
	# persisted workpiece. Everything else in the run/profile must stay exact.
	payload["activeWorkpieceId"] = "<allowed-inspect-selection>"
	return JSON.stringify({"run": payload, "profile": gs.profile_payload()})


func raw_token_leaks(copy: String, tokens: Array) -> Array:
	var leaks: Array = []
	for token_value: Variant in tokens:
		var token: String = String(token_value)
		if not token.is_empty() and copy.contains(token) and not leaks.has(token):
			leaks.append(token)
	return leaks


func completed_tutorial_profile(gs: Node) -> Dictionary:
	var profile: Dictionary = gs.default_player_profile()
	profile["tutorialCompletedSteps"] = TUTORIAL_STEPS.duplicate()
	return profile


func fixture_artifact(gs: Node, registry: Node, spec_index: int, unique_id: String) -> Dictionary:
	var spec_id := String(registry.spec_order[posmod(spec_index, registry.spec_order.size())])
	var artifact: Dictionary = gs.new_artifact(spec_id, 810000 + spec_index, unique_id)
	artifact["damageInstances"] = ["DUST", "RUST"] if spec_index % 2 == 0 else ["CRACK"]
	artifact["knownClues"] = ["MATERIAL", "PROVENANCE"] if spec_index % 3 == 0 else ["SERIAL_PATTERN"]
	artifact["evidence"] = []
	artifact["sold"] = false
	return artifact


func prepare_inventory_fixture(gs: Node, registry: Node) -> Array:
	gs.player_profile = completed_tutorial_profile(gs)
	gs.reset_game()
	gs.persistence_enabled = false
	gs.inventory = []
	for index: int in range(11):
		var artifact: Dictionary = fixture_artifact(gs, registry, index, "repeated_inventory_%02d" % index)
		if index == 8:
			artifact["caseId"] = "prologue_clock"
			artifact["caseResolved"] = true
		gs.inventory.append(artifact)
	return gs.inventory


func inventory_cards(main: Node) -> Array:
	var cards: Array = []
	for index: int in range(8):
		var card: Node = visible_named(main, "InventoryCard_%d" % index, "Button")
		if card != null:
			cards.append(card)
	return cards


func inventory_contract(main: Node, inventory: Array, page_index: int) -> Dictionary:
	var progress: Node = visible_named(main, "InventoryProgress", "Label")
	var grid: Node = visible_named(main, "InventoryGrid", "GridContainer")
	var previous: Node = visible_named(main, "InventoryPrev", "Button")
	var page: Node = visible_named(main, "InventoryPage", "Label")
	var next: Node = visible_named(main, "InventoryNext", "Button")
	var detail: Node = visible_named(main, "InventoryDetailPanel")
	var detail_name: Node = visible_named(main, "InventoryDetailName", "Label")
	var detail_case: Node = visible_named(main, "InventoryDetailCase", "Label")
	var detail_stats: Node = visible_named(main, "InventoryDetailStats", "Label")
	var cards: Array = inventory_cards(main)
	var page_count: int = maxi(1, ceili(float(inventory.size()) / 8.0))
	var page_start: int = page_index * 8
	var expected_count: int = mini(8, maxi(0, inventory.size() - page_start))
	var card_rows: Array = []
	var cards_ok: bool = cards.size() == expected_count and visible_named(main, "InventoryCard_8") == null
	for local_index: int in range(cards.size()):
		var global_index: int = page_start + local_index
		var artifact: Dictionary = inventory[global_index] if global_index < inventory.size() and inventory[global_index] is Dictionary else {}
		var card: Button = cards[local_index] as Button
		var lines: PackedStringArray = card.text.split("\n")
		var row_ok: bool = lines.size() == 3 and button_has_icon(card) \
			and card.text.contains(String(artifact.get("displayName", ""))) \
			and card.text.contains("¤%d" % int(artifact.get("estimatedValue", 0))) \
			and String(lines[2]).contains(str(artifact.get("damageInstances", []).size())) \
			and String(lines[2]).contains(str(artifact.get("knownClues", []).size()))
		cards_ok = cards_ok and row_ok
		card_rows.append({"local": local_index, "global": global_index, "lines": Array(lines), "icon": button_has_icon(card), "ok": row_ok})
	var expected_page_copy := "%d/%d" % [page_index + 1, page_count]
	var page_label_contract: Dictionary = pager_label_contract(page, page_index + 1, page_count, 54.0)
	var pager_ok: bool = previous is Button and page is Label and next is Button \
		and normalized_progress(String((page as Label).text)) == expected_page_copy \
		and bool(page_label_contract.get("ok", false)) \
		and bool((previous as Button).disabled) == (page_index == 0) \
		and bool((next as Button).disabled) == (page_index == page_count - 1)
	var primary_buttons: Array = visible_nodes_named(main, "InspectLot_*", "Button")
	var detail_ok: bool = detail is Control and detail_name is Label and detail_case is Label and detail_stats is Label \
		and not String((detail_name as Label).text).is_empty() and not String((detail_case as Label).text).is_empty() \
		and not String((detail_stats as Label).text).is_empty() \
		and (detail_name as Label).max_lines_visible == 1 and (detail_case as Label).max_lines_visible == 1 \
		and (detail_stats as Label).max_lines_visible > 0 and (detail_stats as Label).max_lines_visible <= 2 \
		and primary_buttons.size() == 1
	var geometry: Dictionary = controls_geometry(cards, chrome_nodes(main) + primary_buttons)
	var density: Dictionary = density_evidence(main, 20, 24, 1100)
	return {
		"ok": progress is Label and grid is GridContainer and int((grid as GridContainer).columns) == 2 \
			and cards_ok and pager_ok and detail_ok and not has_visible_scroll(main) \
			and bool(geometry.get("ok", false)) and bool(density.get("ok", false)),
		"page": String((page as Label).text) if page is Label else "",
		"pageIndex": page_index,
		"pageCount": page_count,
		"progress": String((progress as Label).text) if progress is Label else "",
		"cards": card_rows,
		"cardCount": cards.size(),
		"expectedCardCount": expected_count,
		"primary": String(primary_buttons[0].name) if primary_buttons.size() == 1 else "",
		"detail": {
			"name": String((detail_name as Label).text) if detail_name is Label else "",
			"case": String((detail_case as Label).text) if detail_case is Label else "",
			"stats": String((detail_stats as Label).text) if detail_stats is Label else ""
		},
		"pagerOk": pager_ok,
		"pagerLabel": page_label_contract,
		"noScroll": not has_visible_scroll(main),
		"geometry": geometry,
		"density": density
	}


func inventory_raw_tokens(inventory: Array) -> Array:
	var tokens: Array = ["uniqueId", "artifactSpecId", "estimatedValue", "damageInstances", "knownClues", "prologue_clock", "DUST", "RUST", "CRACK", "MATERIAL", "PROVENANCE", "SERIAL_PATTERN"]
	for artifact_value: Variant in inventory:
		if artifact_value is Dictionary:
			for key: String in ["uniqueId", "artifactSpecId", "specId"]:
				var token: String = String((artifact_value as Dictionary).get(key, ""))
				if not token.is_empty():
					tokens.append(token)
	return tokens


func prepare_authentication_fixture(gs: Node, registry: Node, main: Node) -> Dictionary:
	gs.player_profile = completed_tutorial_profile(gs)
	gs.reset_game()
	gs.persistence_enabled = false
	var artifact: Dictionary = fixture_artifact(gs, registry, 12, "repeated_authentication")
	artifact["damageInstances"] = []
	artifact["knownClues"] = EVIDENCE_IDS.duplicate()
	artifact["evidence"] = []
	artifact["confidence"] = 0.78
	artifact["playerHypothesis"] = "UNKNOWN"
	for index: int in range(EVIDENCE_IDS.size()):
		var clue_id: String = EVIDENCE_IDS[index]
		artifact.evidence.append({
			"clueType": clue_id,
			"observation": {
				"en": "Public observation %d records a period-consistent surface detail." % (index + 1),
				"ko": "공개 관찰 %d에서 시대와 맞는 표면 특징을 기록했습니다." % (index + 1)
			},
			"supports": [],
			"contradicts": [],
			"confidenceWeight": 0.1
		})
	gs.inventory = [artifact]
	main.call("load_artifact", artifact)
	return artifact


func authentication_evidence_cards(main: Node) -> Array:
	var cards: Array = []
	for index: int in range(6):
		var card: Node = visible_named(main, "AuthenticationEvidenceCard_%d" % index, "Button")
		if card != null:
			cards.append(card)
	return cards


func authentication_contract(main: Node, artifact: Dictionary) -> Dictionary:
	var confidence: Node = visible_named(main, "AuthenticationConfidence", "Label")
	var evidence_grid: Node = visible_named(main, "AuthenticationEvidenceGrid", "GridContainer")
	var evidence_cards: Array = authentication_evidence_cards(main)
	var evidence_detail: Node = visible_named(main, "AuthenticationEvidenceDetail")
	var observation: Node = visible_named(main, "AuthenticationEvidenceObservation", "Label")
	var evidence_page: Node = visible_named(main, "AuthenticationEvidencePage", "Label")
	var hypothesis_grid: Node = visible_named(main, "HypothesisGrid", "GridContainer")
	var hypothesis_detail: Node = visible_named(main, "AuthenticationHypothesisDetail")
	var accept_nodes: Array = visible_nodes_named(main, "AcceptHypothesisButton", "Button")
	var hypotheses: Array = []
	var hypothesis_rows: Array = []
	var hypotheses_ok: bool = true
	for hypothesis_id: String in HYPOTHESES:
		var button: Node = visible_named(main, "Hypothesis_%s" % hypothesis_id, "Button")
		if button != null:
			hypotheses.append(button)
		# GENUINE / REPRODUCTION / FORGERY are legitimate English-facing labels.
		# Only compound/internal identifiers must remain hidden from public copy.
		var private_id_leak: bool = hypothesis_id in ["GENUINE_WITH_PERIOD_REPAIR", "GENUINE_WITH_MODERN_REPAIR", "UNKNOWN"] \
			and button is Button and String((button as Button).text).contains(hypothesis_id)
		var row_ok: bool = button is Button and button_has_icon(button) \
			and not String((button as Button).text).is_empty() and not private_id_leak
		hypotheses_ok = hypotheses_ok and row_ok
		hypothesis_rows.append({"id": hypothesis_id, "text": String((button as Button).text) if button is Button else "", "icon": button_has_icon(button), "ok": row_ok})
	var evidence_rows: Array = []
	var evidence_ok: bool = evidence_cards.size() == mini(6, artifact.get("evidence", []).size()) and visible_named(main, "AuthenticationEvidenceCard_6") == null
	for index: int in range(evidence_cards.size()):
		var card: Button = evidence_cards[index] as Button
		var row_ok: bool = not card.text.is_empty() and not card.text.contains(String(EVIDENCE_IDS[index]))
		evidence_ok = evidence_ok and row_ok
		evidence_rows.append({"index": index, "text": card.text, "ok": row_ok})
	var observation_ok: bool = observation is Label and not String((observation as Label).text).is_empty() \
		and (observation as Label).max_lines_visible > 0 and (observation as Label).max_lines_visible <= 2
	var evidence_page_count: int = maxi(1, ceili(float(artifact.get("evidence", []).size()) / 6.0))
	var evidence_current_page: int = int(main.get("authentication_evidence_page")) + 1
	var evidence_pager: Dictionary = pager_label_contract(evidence_page, evidence_current_page, evidence_page_count, 48.0)
	var evidence_geometry: Dictionary = controls_geometry(evidence_cards, chrome_nodes(main))
	var hypothesis_geometry: Dictionary = controls_geometry(hypotheses, chrome_nodes(main) + accept_nodes)
	var density: Dictionary = density_evidence(main, 18, 24, 1300)
	return {
		"ok": confidence is Label and String((confidence as Label).text).contains("78") \
			and evidence_grid is GridContainer and int((evidence_grid as GridContainer).columns) == 2 \
			and evidence_ok and evidence_detail is Control and observation_ok and bool(evidence_pager.get("ok", false)) \
			and hypothesis_grid is GridContainer and int((hypothesis_grid as GridContainer).columns) == 3 \
			and hypotheses.size() == 6 and hypotheses_ok and hypothesis_detail is Control and accept_nodes.size() == 1 \
			and not has_visible_scroll(main) and bool(evidence_geometry.get("ok", false)) \
			and bool(hypothesis_geometry.get("ok", false)) and bool(density.get("ok", false)),
		"confidence": String((confidence as Label).text) if confidence is Label else "",
		"evidenceCards": evidence_rows,
		"evidenceCount": evidence_cards.size(),
		"observation": String((observation as Label).text) if observation is Label else "",
		"observationMaxLines": int((observation as Label).max_lines_visible) if observation is Label else -1,
		"evidencePager": evidence_pager,
		"hypotheses": hypothesis_rows,
		"hypothesisCount": hypotheses.size(),
		"acceptCount": accept_nodes.size(),
		"acceptDisabled": bool((accept_nodes[0] as Button).disabled) if accept_nodes.size() == 1 else null,
		"noScroll": not has_visible_scroll(main),
		"evidenceGeometry": evidence_geometry,
		"hypothesisGeometry": hypothesis_geometry,
		"density": density
	}


func authentication_raw_tokens(artifact: Dictionary) -> Array:
	var tokens: Array = ["clueType", "confidenceWeight", "authenticityTruth", "playerHypothesis", "repeated_authentication"] \
		+ EVIDENCE_IDS + ["GENUINE_WITH_PERIOD_REPAIR", "GENUINE_WITH_MODERN_REPAIR", "UNKNOWN"]
	for key: String in ["uniqueId", "artifactSpecId", "specId"]:
		tokens.append(String(artifact.get(key, "")))
	return tokens


func prepare_upgrades_fixture(gs: Node) -> void:
	gs.player_profile = completed_tutorial_profile(gs)
	gs.reset_game()
	gs.persistence_enabled = false
	gs.money = 100000
	gs.owned_upgrades = []


func upgrade_cards(main: Node) -> Array:
	var cards: Array = []
	for index: int in range(6):
		var card: Node = visible_named(main, "UpgradeCard_%d" % index, "Button")
		if card != null:
			cards.append(card)
	return cards


func upgrade_page_contract(main: Node, upgrades: Array, page_index: int) -> Dictionary:
	var progress: Node = visible_named(main, "UpgradeProgress", "Label")
	var grid: Node = visible_named(main, "UpgradeGrid", "GridContainer")
	var previous: Node = visible_named(main, "UpgradePrev", "Button")
	var page: Node = visible_named(main, "UpgradePage", "Label")
	var next: Node = visible_named(main, "UpgradeNext", "Button")
	var detail: Node = visible_named(main, "UpgradeDetailPanel")
	var detail_name: Node = visible_named(main, "UpgradeDetailName", "Label")
	var detail_effect: Node = visible_named(main, "UpgradeDetailEffect", "Label")
	var cards: Array = upgrade_cards(main)
	var page_count: int = maxi(1, ceili(float(upgrades.size()) / 6.0))
	var page_start: int = page_index * 6
	var expected_count: int = mini(6, maxi(0, upgrades.size() - page_start))
	var cards_ok: bool = cards.size() == expected_count and visible_named(main, "UpgradeCard_6") == null
	var rows: Array = []
	for local_index: int in range(cards.size()):
		var global_index: int = page_start + local_index
		var upgrade: Dictionary = upgrades[global_index] if global_index < upgrades.size() and upgrades[global_index] is Dictionary else {}
		var card: Button = cards[local_index] as Button
		var lines: PackedStringArray = card.text.split("\n")
		var effect_type := String(upgrade.get("effect", {}).get("type", ""))
		var row_ok: bool = button_has_icon(card) and lines.size() == 3 \
			and not String(lines[0]).strip_edges().is_empty() and not String(lines[2]).strip_edges().is_empty() \
			and card.text.contains("¤%d" % int(upgrade.get("cost", 0))) \
			and not card.text.contains(String(upgrade.get("id", ""))) and not card.text.contains(effect_type)
		cards_ok = cards_ok and row_ok
		rows.append({"local": local_index, "global": global_index, "id": upgrade.get("id", ""), "text": card.text, "icon": button_has_icon(card), "ok": row_ok})
	var expected_page_copy := "%d/%d" % [page_index + 1, page_count]
	var page_label_contract: Dictionary = pager_label_contract(page, page_index + 1, page_count, 54.0)
	var pager_ok: bool = previous is Button and page is Label and next is Button \
		and normalized_progress(String((page as Label).text)) == expected_page_copy \
		and bool(page_label_contract.get("ok", false)) \
		and bool((previous as Button).disabled) == (page_index == 0) \
		and bool((next as Button).disabled) == (page_index == page_count - 1)
	var primary_buttons: Array = visible_nodes_named(main, "Upgrade_upgrade_*", "Button")
	var detail_ok: bool = detail is Control and detail_name is Label and detail_effect is Label \
		and not String((detail_name as Label).text).is_empty() and not String((detail_effect as Label).text).is_empty() \
		and (detail_name as Label).max_lines_visible == 1 \
		and (detail_effect as Label).max_lines_visible > 0 and (detail_effect as Label).max_lines_visible <= 2 \
		and primary_buttons.size() == 1
	var geometry: Dictionary = controls_geometry(cards, chrome_nodes(main) + primary_buttons)
	var density: Dictionary = density_evidence(main, 18, 22, 1000)
	return {
		"ok": progress is Label and grid is GridContainer and int((grid as GridContainer).columns) == 2 \
			and cards_ok and pager_ok and detail_ok and not has_visible_scroll(main) \
			and bool(geometry.get("ok", false)) and bool(density.get("ok", false)),
		"page": String((page as Label).text) if page is Label else "",
		"pageIndex": page_index,
		"pageCount": page_count,
		"progress": String((progress as Label).text) if progress is Label else "",
		"cards": rows,
		"cardCount": cards.size(),
		"expectedCardCount": expected_count,
		"primary": String(primary_buttons[0].name) if primary_buttons.size() == 1 else "",
		"detail": {
			"name": String((detail_name as Label).text) if detail_name is Label else "",
			"effect": String((detail_effect as Label).text) if detail_effect is Label else "",
			"effectMaxLines": int((detail_effect as Label).max_lines_visible) if detail_effect is Label else -1
		},
		"pagerOk": pager_ok,
		"pagerLabel": page_label_contract,
		"noScroll": not has_visible_scroll(main),
		"geometry": geometry,
		"density": density
	}


func press_visible(main: Node, node_name: String) -> bool:
	var button: Node = visible_named(main, node_name, "Button")
	if not button is Button:
		return false
	(button as Button).pressed.emit()
	return true


func navigate_to_first_upgrade_page(main: Node) -> Dictionary:
	var presses: int = 0
	for _step: int in range(8):
		var previous: Node = visible_named(main, "UpgradePrev", "Button")
		if not previous is Button:
			return {"ok": false, "presses": presses, "code": "MISSING_PREV"}
		if (previous as Button).disabled:
			return {"ok": true, "presses": presses, "code": "OK"}
		(previous as Button).pressed.emit()
		presses += 1
		await settle_ui(5)
	return {"ok": false, "presses": presses, "code": "PAGE_LOOP_LIMIT"}


func scan_upgrade_pages(main: Node, gs: Node, upgrades: Array, require_korean: bool) -> Dictionary:
	var first_page: Dictionary = await navigate_to_first_upgrade_page(main)
	var page_count: int = maxi(1, ceili(float(upgrades.size()) / 6.0))
	var seen_ids: Array = []
	var details: Dictionary = {}
	var failures: Array = []
	var page_evidence: Array = []
	var authority_before: String = localized_state_signature(gs)
	var rng_before: int = int(gs.rng.state)
	for page_index: int in range(page_count):
		var page_contract: Dictionary = upgrade_page_contract(main, upgrades, page_index)
		page_evidence.append({"page": page_index + 1, "contract": page_contract})
		if not bool(page_contract.get("ok", false)):
			failures.append({"page": page_index + 1, "code": "PAGE_CONTRACT"})
		var expected_count: int = mini(6, upgrades.size() - page_index * 6)
		for local_index: int in range(expected_count):
			var global_index: int = page_index * 6 + local_index
			var upgrade: Dictionary = upgrades[global_index]
			var card: Node = visible_named(main, "UpgradeCard_%d" % local_index, "Button")
			var card_was_button: bool = card is Button
			var card_lines: PackedStringArray = (card as Button).text.split("\n") if card_was_button else PackedStringArray()
			var card_public_name: String = String(card_lines[0]).strip_edges() if card_lines.size() >= 1 else ""
			var card_effect_copy: String = String(card_lines[2]).strip_edges() if card_lines.size() == 3 else ""
			if card_was_button:
				(card as Button).pressed.emit()
				await settle_ui(4)
			var effect_label: Node = visible_named(main, "UpgradeDetailEffect", "Label")
			var name_label: Node = visible_named(main, "UpgradeDetailName", "Label")
			var primary: Node = visible_named(main, "Upgrade_%s" % String(upgrade.get("id", "")), "Button")
			var effect_copy := String((effect_label as Label).text) if effect_label is Label else ""
			var expected_id := String(upgrade.get("id", ""))
			var raw_effect_type := String(upgrade.get("effect", {}).get("type", ""))
			var detail_ok: bool = card_was_button and effect_label is Label and name_label is Label and primary is Button \
				and not card_public_name.is_empty() and String((name_label as Label).text).contains(card_public_name) \
				and not card_effect_copy.is_empty() \
				and (contains_hangul(card_effect_copy) if require_korean else not contains_hangul(card_effect_copy)) \
				and not effect_copy.is_empty() and (effect_label as Label).max_lines_visible > 0 and (effect_label as Label).max_lines_visible <= 2 \
				and not effect_copy.contains(expected_id) and not effect_copy.contains(raw_effect_type) \
				and (contains_hangul(effect_copy) if require_korean else not contains_hangul(effect_copy))
			if not detail_ok:
				failures.append({"page": page_index + 1, "index": local_index, "id": expected_id, "code": "DETAIL_CONTRACT", "effect": effect_copy})
			if not seen_ids.has(expected_id):
				seen_ids.append(expected_id)
			details[expected_id] = effect_copy
		if page_index < page_count - 1:
			var next_button: Node = visible_named(main, "UpgradeNext", "Button")
			if next_button is Button and not (next_button as Button).disabled:
				(next_button as Button).pressed.emit()
				await settle_ui(5)
			else:
				failures.append({"page": page_index + 1, "code": "NEXT_UNAVAILABLE"})
	return {
		"ok": bool(first_page.get("ok", false)) and failures.is_empty() and seen_ids.size() == upgrades.size() \
			and localized_state_signature(gs) == authority_before and int(gs.rng.state) == rng_before,
		"firstPage": first_page,
		"seenIds": seen_ids,
		"details": details,
		"failures": failures,
		"pages": page_evidence,
		"stateMutation0": localized_state_signature(gs) == authority_before,
		"rngMutation0": int(gs.rng.state) == rng_before
	}


func record_blocked_remaining(rows: Array, code: String) -> void:
	for row_value: Variant in rows:
		var row: Dictionary = row_value if row_value is Dictionary else {}
		record(String(row.get("id", "REPEATED-CORE-BLOCKED")), String(row.get("name", "Blocked by prior gate")), false, {"code": code})


func write_report_and_quit(main: Node = null) -> void:
	var passed: int = results.filter(func(result: Dictionary): return bool(result.get("passed", false))).size()
	var report: Dictionary = {
		"suite": "R3 Repeated Core Compact UI",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"skipped": 0,
		"expectedCount": EXPECTED_TEST_COUNT,
		"tests": results
	}
	var output: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print(JSON.stringify(report))
	if main != null and is_instance_valid(main):
		main.queue_free()
	quit(0 if passed == results.size() and results.size() == EXPECTED_TEST_COUNT else 1)


func run() -> void:
	var gs: Node = get_root().get_node("GameState")
	var registry: Node = get_root().get_node("RuntimeRegistry")
	gs.persistence_enabled = false
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await settle_ui(5)
	var required_main_methods: Array = [
		"show_inventory", "show_authentication", "show_upgrades", "toggle_language",
		"sync_public_interaction_state", "load_artifact", "friendly_case_name"
	]
	var required_game_state_methods: Array = [
		"save_payload", "profile_payload", "new_artifact", "truth_to_hypothesis", "upgrade_effect_total"
	]
	var missing_main: Array = []
	var missing_game_state: Array = []
	for method_name: String in required_main_methods:
		if not main.has_method(method_name):
			missing_main.append(method_name)
	for method_name: String in required_game_state_methods:
		if not gs.has_method(method_name):
			missing_game_state.append(method_name)
	var viewport_ok: bool = int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) == 1280 \
		and int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) == 720
	var api_ok: bool = missing_main.is_empty() and missing_game_state.is_empty() and viewport_ok
	record(
		"REPEATED-CORE-API-01",
		"Repeated core screens expose the required public routes and the 1280x720 target",
		api_ok,
		{"missingMain": missing_main, "missingGameState": missing_game_state, "viewport1280x720": viewport_ok}
	)
	if not api_ok:
		record_blocked_remaining([
			{"id": "REPEATED-INVENTORY-KO-01", "name": "Korean inventory contract"},
			{"id": "REPEATED-INVENTORY-AUTHORITY-01", "name": "Inventory page/detail authority"},
			{"id": "REPEATED-INVENTORY-EN-01", "name": "English inventory refresh"},
			{"id": "REPEATED-AUTH-KO-01", "name": "Korean authentication contract"},
			{"id": "REPEATED-AUTH-DRAFT-01", "name": "Authentication evidence and draft authority"},
			{"id": "REPEATED-AUTH-ACCEPT-01", "name": "Authentication accept authority"},
			{"id": "REPEATED-UPGRADES-KO-01", "name": "Korean upgrades five-page contract"},
			{"id": "REPEATED-UPGRADES-EN-01", "name": "English upgrades refresh"},
			{"id": "REPEATED-UPGRADES-BUY-01", "name": "Upgrade exact purchase authority"}
		], "BLOCKED_BY_API_GATE")
		write_report_and_quit(main)
		return

	# Inventory: ten-plus artifacts force a two-page public route.
	var inventory: Array = prepare_inventory_fixture(gs, registry)
	gs.language = "ko"
	main.language = "ko"
	main.call("show_inventory")
	await settle_ui(7)
	var inventory_ko_contract: Dictionary = inventory_contract(main, inventory, 0)
	var inventory_ko_copy: String = visible_copy(main)
	var inventory_ko_leaks: Array = raw_token_leaks(inventory_ko_copy, inventory_raw_tokens(inventory))
	record(
		"REPEATED-INVENTORY-KO-01",
		"Korean Inventory shows at most eight icon cards in a 2x4 grid, exactly three public lines, one shared detail and one Inspect action without scrolling",
		bool(inventory_ko_contract.get("ok", false)) and inventory_ko_leaks.is_empty(),
		{"contract": inventory_ko_contract, "rawTokenLeaks": inventory_ko_leaks}
	)

	var inventory_state_before: String = localized_state_signature(gs)
	var inventory_rng_before: int = int(gs.rng.state)
	var inventory_next: Node = visible_named(main, "InventoryNext", "Button")
	var inventory_next_was_button: bool = inventory_next is Button and not (inventory_next as Button).disabled
	if inventory_next_was_button:
		(inventory_next as Button).pressed.emit()
		await settle_ui(6)
	var inventory_page_two: Dictionary = inventory_contract(main, inventory, 1)
	var inventory_card_zero: Node = visible_named(main, "InventoryCard_0", "Button")
	var inventory_card_was_button: bool = inventory_card_zero is Button
	if inventory_card_was_button:
		(inventory_card_zero as Button).pressed.emit()
		await settle_ui(6)
	var linked_detail_name: Node = visible_named(main, "InventoryDetailName", "Label")
	var linked_detail_case: Node = visible_named(main, "InventoryDetailCase", "Label")
	var linked_primary: Node = visible_named(main, "InspectLot_8", "Button")
	var linked_artifact: Dictionary = inventory[8]
	var friendly_case := String(main.call("friendly_case_name", "prologue_clock"))
	var linked_detail_ok: bool = linked_detail_name is Label and String((linked_detail_name as Label).text).contains(String(linked_artifact.get("displayName", ""))) \
		and linked_detail_case is Label and not friendly_case.is_empty() and String((linked_detail_case as Label).text).contains(friendly_case) \
		and not String((linked_detail_case as Label).text).contains("prologue_clock") and linked_primary is Button
	var navigation_state_mutation_zero: bool = localized_state_signature(gs) == inventory_state_before
	var navigation_rng_mutation_zero: bool = int(gs.rng.state) == inventory_rng_before
	var before_inspect_state: String = inspect_neutral_state_signature(gs)
	var before_inspect_rng: int = int(gs.rng.state)
	var inspect_was_button: bool = linked_primary is Button
	if inspect_was_button:
		(linked_primary as Button).pressed.emit()
		await settle_ui(6)
	var inspected_uid: String = String(linked_artifact.get("uniqueId", ""))
	var inspect_route_ok: bool = inspect_was_button and String(main.screen) == "inspection" \
		and String(main.selected.get("uniqueId", "")) == inspected_uid \
		and String(gs.active_workpiece.get("uniqueId", "")) == inspected_uid \
		and inspect_neutral_state_signature(gs) == before_inspect_state and int(gs.rng.state) == before_inspect_rng
	var inventory_authority_ok: bool = inventory_next_was_button and bool(inventory_page_two.get("ok", false)) and inventory_card_was_button \
		and linked_detail_ok and navigation_state_mutation_zero and navigation_rng_mutation_zero and inspect_route_ok
	record(
		"REPEATED-INVENTORY-AUTHORITY-01",
		"Inventory pagination and card detail selection mutate no game state or RNG, while only the global Inspect primary opens the selected artifact",
		inventory_authority_ok,
		{"pageTwo": inventory_page_two, "linkedDetailOk": linked_detail_ok, "inspectRouteOk": inspect_route_ok, "selectedUid": String(main.selected.get("uniqueId", "")), "activeWorkpieceId": String(gs.active_workpiece.get("uniqueId", "")), "pageDetailStateMutation0": navigation_state_mutation_zero, "pageDetailRngMutation0": navigation_rng_mutation_zero, "inspectOtherStateMutation0": inspect_neutral_state_signature(gs) == before_inspect_state, "inspectRngMutation0": int(gs.rng.state) == before_inspect_rng}
	)

	main.call("show_inventory")
	await settle_ui(6)
	# Page selection remains UI-local; explicitly move to page two again if the
	# screen chooses to reset its presentation on route entry.
	var current_inventory_page: Node = visible_named(main, "InventoryPage", "Label")
	if current_inventory_page is Label and not normalized_progress(String((current_inventory_page as Label).text)).contains("2/2"):
		var next_again: Node = visible_named(main, "InventoryNext", "Button")
		if next_again is Button and not (next_again as Button).disabled:
			(next_again as Button).pressed.emit()
			await settle_ui(5)
	main.call("sync_public_interaction_state")
	var inventory_locale_before: String = localized_state_signature(gs)
	var inventory_locale_rng_before: int = int(gs.rng.state)
	main.call("toggle_language")
	await settle_ui(7)
	var inventory_en_contract: Dictionary = inventory_contract(main, inventory, 1)
	var inventory_en_copy: String = visible_copy(main)
	var inventory_en_leaks: Array = raw_token_leaks(inventory_en_copy, inventory_raw_tokens(inventory))
	record(
		"REPEATED-INVENTORY-EN-01",
		"English Inventory refresh preserves page, detail, bounds and authoritative state while changing only localized copy",
		String(gs.language) == "en" and String(main.language) == "en" and bool(inventory_en_contract.get("ok", false)) \
			and inventory_en_copy != inventory_ko_copy and inventory_en_leaks.is_empty() \
			and localized_state_signature(gs) == inventory_locale_before and int(gs.rng.state) == inventory_locale_rng_before,
		{"contract": inventory_en_contract, "copyChanged": inventory_en_copy != inventory_ko_copy, "rawTokenLeaks": inventory_en_leaks, "stateMutation0": localized_state_signature(gs) == inventory_locale_before, "rngMutation0": int(gs.rng.state) == inventory_locale_rng_before}
	)

	# Authentication: eight evidence rows prove the six-card cap while the six
	# hypotheses retain the established immediate draft behavior.
	var auth_artifact: Dictionary = prepare_authentication_fixture(gs, registry, main)
	gs.language = "ko"
	main.language = "ko"
	main.call("show_authentication")
	await settle_ui(7)
	var auth_ko_contract: Dictionary = authentication_contract(main, auth_artifact)
	var auth_ko_copy: String = visible_copy(main)
	var auth_ko_leaks: Array = raw_token_leaks(auth_ko_copy, authentication_raw_tokens(auth_artifact))
	record(
		"REPEATED-AUTH-KO-01",
		"Korean Authentication shows six evidence cards in 2x3, one two-line observation detail, six icon hypotheses in 3x2 and exactly one Accept",
		bool(auth_ko_contract.get("ok", false)) and auth_ko_leaks.is_empty(),
		{"contract": auth_ko_contract, "rawTokenLeaks": auth_ko_leaks}
	)

	var draft_uid := String(auth_artifact.get("uniqueId", ""))
	var auth_state_before: String = localized_state_signature(gs, draft_uid)
	var auth_rng_before: int = int(gs.rng.state)
	var auth_stats_before: Dictionary = gs.statistics.duplicate(true)
	var evidence_card: Node = visible_named(main, "AuthenticationEvidenceCard_5", "Button")
	var evidence_card_was_button: bool = evidence_card is Button
	if evidence_card_was_button:
		(evidence_card as Button).pressed.emit()
		await settle_ui(5)
	var ko_observation: Node = visible_named(main, "AuthenticationEvidenceObservation", "Label")
	var ko_expected_observation := String((auth_artifact.evidence[5] as Dictionary).get("observation", {}).get("ko", ""))
	var evidence_detail_ok: bool = ko_observation is Label and String((ko_observation as Label).text).contains(ko_expected_observation)
	var correct_hypothesis := String(gs.call("truth_to_hypothesis", String(auth_artifact.get("authenticityTruth", "UNKNOWN"))))
	var hypothesis_button: Node = visible_named(main, "Hypothesis_%s" % correct_hypothesis, "Button")
	var hypothesis_was_button: bool = hypothesis_button is Button
	if hypothesis_was_button:
		(hypothesis_button as Button).pressed.emit()
		await settle_ui(5)
	var draft_exact: bool = String(auth_artifact.get("playerHypothesis", "")) == correct_hypothesis
	var accept_after_draft: Node = visible_named(main, "AcceptHypothesisButton", "Button")
	var draft_boundary_ok: bool = evidence_card_was_button and evidence_detail_ok and hypothesis_was_button and draft_exact \
		and accept_after_draft is Button and not (accept_after_draft as Button).disabled \
		and localized_state_signature(gs, draft_uid) == auth_state_before and int(gs.rng.state) == auth_rng_before \
		and gs.statistics == auth_stats_before
	main.call("sync_public_interaction_state")
	var auth_locale_before: String = localized_state_signature(gs, draft_uid)
	var auth_locale_rng_before: int = int(gs.rng.state)
	main.call("toggle_language")
	await settle_ui(7)
	var auth_en_contract: Dictionary = authentication_contract(main, auth_artifact)
	var auth_en_copy: String = visible_copy(main)
	var auth_en_leaks: Array = raw_token_leaks(auth_en_copy, authentication_raw_tokens(auth_artifact))
	var en_observation: Node = visible_named(main, "AuthenticationEvidenceObservation", "Label")
	var en_observation_copy := String((en_observation as Label).text) if en_observation is Label else ""
	var auth_refresh_ok: bool = String(gs.language) == "en" and String(main.language) == "en" and bool(auth_en_contract.get("ok", false)) \
		and auth_en_copy != auth_ko_copy and en_observation_copy != ko_expected_observation and auth_en_leaks.is_empty() \
		and String(auth_artifact.get("playerHypothesis", "")) == correct_hypothesis \
		and localized_state_signature(gs, draft_uid) == auth_locale_before and int(gs.rng.state) == auth_locale_rng_before
	record(
		"REPEATED-AUTH-DRAFT-01",
		"Evidence/detail selection and KO/EN refresh are mutation-zero, while a hypothesis card changes only the established immediate draft field before Accept",
		draft_boundary_ok and auth_refresh_ok,
		{"evidenceDetailOk": evidence_detail_ok, "draft": auth_artifact.get("playerHypothesis", ""), "draftBoundaryOk": draft_boundary_ok, "enContract": auth_en_contract, "rawTokenLeaks": auth_en_leaks, "localeStateMutation0": localized_state_signature(gs, draft_uid) == auth_locale_before, "rngMutation0": int(gs.rng.state) == auth_locale_rng_before}
	)

	var accept_button: Node = visible_named(main, "AcceptHypothesisButton", "Button")
	var accept_count_before: int = int(gs.statistics.get("authentication_attempts", 0))
	var correct_count_before: int = int(gs.statistics.get("authentication_correct", 0))
	var forgery_count_before: int = int(gs.statistics.get("forgeries_detected", 0))
	var accept_money_before: int = int(gs.money)
	var accept_transactions_before: int = gs.transactions.size()
	var accept_inventory_before: int = gs.inventory.size()
	var accept_upgrades_before: Array = gs.owned_upgrades.duplicate()
	var accept_rng_before: int = int(gs.rng.state)
	var accept_was_button: bool = accept_button is Button and not (accept_button as Button).disabled \
		and visible_nodes_named(main, "AcceptHypothesisButton", "Button").size() == 1
	if accept_was_button:
		(accept_button as Button).pressed.emit()
		await settle_ui(7)
	var expected_forgery_delta: int = 1 if correct_hypothesis == "FORGERY" else 0
	var accept_exact: bool = accept_was_button and String(main.screen) == "appraisal" \
		and int(gs.statistics.get("authentication_attempts", 0)) == accept_count_before + 1 \
		and int(gs.statistics.get("authentication_correct", 0)) == correct_count_before + 1 \
		and int(gs.statistics.get("forgeries_detected", 0)) == forgery_count_before + expected_forgery_delta \
		and int(gs.money) == accept_money_before and gs.transactions.size() == accept_transactions_before \
		and gs.inventory.size() == accept_inventory_before and gs.owned_upgrades == accept_upgrades_before \
		and int(gs.rng.state) == accept_rng_before
	record(
		"REPEATED-AUTH-ACCEPT-01",
		"Exactly one enabled Accept commits the existing draft once, updates only authentication authority, and routes to appraisal with RNG0",
		accept_exact,
		{"screen": main.screen, "attempts": [accept_count_before, gs.statistics.get("authentication_attempts", 0)], "correct": [correct_count_before, gs.statistics.get("authentication_correct", 0)], "forgeries": [forgery_count_before, gs.statistics.get("forgeries_detected", 0)], "moneyUnchanged": int(gs.money) == accept_money_before, "transactionsUnchanged": gs.transactions.size() == accept_transactions_before, "inventoryUnchanged": gs.inventory.size() == accept_inventory_before, "rngMutation0": int(gs.rng.state) == accept_rng_before}
	)

	# Upgrades: five pages expose all 25 without scrolling. Card selection and
	# pagination are read-only; only the detail primary buys.
	prepare_upgrades_fixture(gs)
	var upgrades_value: Variant = registry.upgrades
	var upgrades: Array = upgrades_value if upgrades_value is Array else []
	gs.language = "ko"
	main.language = "ko"
	main.call("show_upgrades")
	await settle_ui(7)
	var upgrade_ko_scan: Dictionary = await scan_upgrade_pages(main, gs, upgrades, true)
	var upgrade_ko_copy: String = visible_copy(main)
	var upgrade_tokens: Array = ["effect.type", "effect.value"]
	for upgrade_value: Variant in upgrades:
		if upgrade_value is Dictionary:
			upgrade_tokens.append(String((upgrade_value as Dictionary).get("id", "")))
			upgrade_tokens.append(String((upgrade_value as Dictionary).get("effect", {}).get("type", "")))
	var upgrade_ko_leaks: Array = raw_token_leaks(upgrade_ko_copy, upgrade_tokens)
	record(
		"REPEATED-UPGRADES-KO-01",
		"Korean Upgrades traverses five no-scroll 2x3 pages and exposes all 25 icon cards with localized one-line effects and two-line-maximum detail",
		upgrades.size() == 25 and bool(upgrade_ko_scan.get("ok", false)) and upgrade_ko_leaks.is_empty(),
		{"seen": upgrade_ko_scan.get("seenIds", []), "failures": upgrade_ko_scan.get("failures", []), "pages": upgrade_ko_scan.get("pages", []), "rawTokenLeaks": upgrade_ko_leaks, "stateMutation0": upgrade_ko_scan.get("stateMutation0", false), "rngMutation0": upgrade_ko_scan.get("rngMutation0", false)}
	)

	main.call("sync_public_interaction_state")
	var upgrades_locale_before: String = localized_state_signature(gs)
	var upgrades_locale_rng_before: int = int(gs.rng.state)
	main.call("toggle_language")
	await settle_ui(7)
	var upgrade_en_scan: Dictionary = await scan_upgrade_pages(main, gs, upgrades, false)
	var upgrade_en_copy: String = visible_copy(main)
	var upgrade_en_leaks: Array = raw_token_leaks(upgrade_en_copy, upgrade_tokens)
	var ko_details: Dictionary = upgrade_ko_scan.get("details", {}) if upgrade_ko_scan.get("details", {}) is Dictionary else {}
	var en_details: Dictionary = upgrade_en_scan.get("details", {}) if upgrade_en_scan.get("details", {}) is Dictionary else {}
	var all_effects_localized: bool = ko_details.size() == 25 and en_details.size() == 25
	for upgrade_id_value: Variant in ko_details.keys():
		var upgrade_id: String = String(upgrade_id_value)
		all_effects_localized = all_effects_localized and en_details.has(upgrade_id) \
			and String(ko_details.get(upgrade_id, "")) != String(en_details.get(upgrade_id, ""))
	var upgrade_en_ok: bool = String(gs.language) == "en" and String(main.language) == "en" \
		and bool(upgrade_en_scan.get("ok", false)) and all_effects_localized and upgrade_en_leaks.is_empty() \
		and localized_state_signature(gs) == upgrades_locale_before and int(gs.rng.state) == upgrades_locale_rng_before
	record(
		"REPEATED-UPGRADES-EN-01",
		"English refresh and five-page detail navigation localize every upgrade while preserving money, ownership, profile, save state and RNG",
		upgrade_en_ok,
		{"seen": upgrade_en_scan.get("seenIds", []), "failures": upgrade_en_scan.get("failures", []), "allEffectsLocalized": all_effects_localized, "rawTokenLeaks": upgrade_en_leaks, "stateMutation0": localized_state_signature(gs) == upgrades_locale_before, "rngMutation0": int(gs.rng.state) == upgrades_locale_rng_before, "copyChanged": upgrade_en_copy != upgrade_ko_copy}
	)

	var first_page_result: Dictionary = await navigate_to_first_upgrade_page(main)
	var first_upgrade: Dictionary = upgrades[0] if not upgrades.is_empty() and upgrades[0] is Dictionary else {}
	var first_upgrade_id := String(first_upgrade.get("id", ""))
	var first_card: Node = visible_named(main, "UpgradeCard_0", "Button")
	var first_card_was_button: bool = first_card is Button
	if first_card_was_button:
		(first_card as Button).pressed.emit()
		await settle_ui(5)
	var buy_button: Node = visible_named(main, "Upgrade_%s" % first_upgrade_id, "Button")
	var buy_was_button: bool = buy_button is Button and not (buy_button as Button).disabled \
		and visible_nodes_named(main, "Upgrade_upgrade_*", "Button").size() == 1
	var money_before_buy: int = int(gs.money)
	var transactions_before_buy: int = gs.transactions.size()
	var owned_before_buy: Array = gs.owned_upgrades.duplicate()
	var effect_type := String(first_upgrade.get("effect", {}).get("type", ""))
	var effect_before: float = float(gs.call("upgrade_effect_total", effect_type))
	var buy_rng_before: int = int(gs.rng.state)
	if buy_was_button:
		(buy_button as Button).pressed.emit()
		await settle_ui(7)
	var effect_after: float = float(gs.call("upgrade_effect_total", effect_type))
	var purchase_exact: bool = bool(first_page_result.get("ok", false)) and first_card_was_button and buy_was_button \
		and int(gs.money) == money_before_buy - int(first_upgrade.get("cost", 0)) \
		and gs.owned_upgrades.size() == owned_before_buy.size() + 1 and gs.owned_upgrades.count(first_upgrade_id) == 1 \
		and gs.transactions.size() == transactions_before_buy + 1 \
		and is_equal_approx(effect_after - effect_before, float(first_upgrade.get("effect", {}).get("value", 0.0))) \
		and int(gs.rng.state) == buy_rng_before
	# The same detail primary must now be disabled; emitting its signal directly
	# still exercises GameState's duplicate guard without inventing another path.
	var duplicate_button: Node = visible_named(main, "Upgrade_%s" % first_upgrade_id, "Button")
	var duplicate_disabled: bool = duplicate_button is Button and (duplicate_button as Button).disabled
	var duplicate_signature_before: String = localized_state_signature(gs)
	var duplicate_rng_before: int = int(gs.rng.state)
	if duplicate_button is Button:
		(duplicate_button as Button).pressed.emit()
		await settle_ui(5)
	var duplicate_blocked: bool = duplicate_disabled and localized_state_signature(gs) == duplicate_signature_before \
		and int(gs.rng.state) == duplicate_rng_before and gs.owned_upgrades.count(first_upgrade_id) == 1
	record(
		"REPEATED-UPGRADES-BUY-01",
		"Upgrade card selection never buys; its single detail primary charges and applies exactly once, then the same purchase is disabled and duplicate-blocked",
		purchase_exact and duplicate_blocked,
		{"upgrade": first_upgrade_id, "purchaseExact": purchase_exact, "money": [money_before_buy, gs.money], "transactions": [transactions_before_buy, gs.transactions.size()], "effect": [effect_before, effect_after], "owned": gs.owned_upgrades, "duplicateDisabled": duplicate_disabled, "duplicateBlocked": duplicate_blocked, "rngMutation0": int(gs.rng.state) == duplicate_rng_before}
	)

	gs.persistence_enabled = false
	write_report_and_quit(main)
