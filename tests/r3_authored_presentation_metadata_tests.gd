extends SceneTree

## Player-safe authored presentation metadata bridge acceptance.
##
## This suite verifies every authored-v2 case currently locked into the registry, schema fallbacks, hostile
## identifier inputs, locked-card redaction, citation-locator timing, legacy
## portrait rejection and gameplay-authority invariance. It uses isolated
## in-memory fixtures and writes only its QA JSON report.

const REPORT_PATH := "res://qa/R3_AUTHORED_PRESENTATION_METADATA_TESTS.json"
const EXPECTED_TEST_COUNT := 11
const AUTHORED_CASE_IDS := [
	"prologue_clock", "leave_patina", "estate_compass", "pawn_watch",
	"garage_lamp", "telephone_trace", "early_camera",
	"false_invoice", "mislabelled_collection", "observatory_instrument",
	"collector_promise", "three_cameras",
	"shadow_camera", "shadow_gauge", "shadow_clock", "shadow_music_box",
	"shadow_optic", "composite_prototype", "master_chronometer", "master_optical",
	"master_recorder", "master_gauge"
]

var results: Array = []


func _init() -> void:
	call_deferred("run")


func record(test_id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({"id": test_id, "name": name, "executed": true, "passed": passed, "evidence": evidence})


func localized(value: Variant, locale: String) -> String:
	if value is Dictionary:
		return String(value.get(locale, value.get("en", ""))).strip_edges()
	return String(value).strip_edges()


func localized_complete(value: Variant) -> bool:
	return value is Dictionary \
		and not String((value as Dictionary).get("en", "")).strip_edges().is_empty() \
		and not String((value as Dictionary).get("ko", "")).strip_edges().is_empty()


func settle_ui(frame_count: int = 4) -> void:
	for _frame: int in range(frame_count):
		await process_frame


func visible_surface_copy(root: Node) -> String:
	var copy := ""
	for label: Label in root.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			copy += label.text + "\n" + label.tooltip_text + "\n"
	for button: Button in root.find_children("*", "Button", true, false):
		if button.is_visible_in_tree():
			copy += button.text + "\n" + button.tooltip_text + "\n"
	for texture: TextureRect in root.find_children("*", "TextureRect", true, false):
		if texture.is_visible_in_tree():
			copy += texture.tooltip_text + "\n"
	return copy


func raw_case_paths() -> Dictionary:
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/cases/authored_v2.lock.json"))
	var paths := {}
	if not payload is Dictionary:
		return paths
	for entry_value: Variant in payload.get("files", []):
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			paths[String(entry.get("case_id", ""))] = "res://" + String(entry.get("path", ""))
	return paths


func raw_case(case_id: String, paths: Dictionary) -> Dictionary:
	var path := String(paths.get(case_id, ""))
	if path.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func citation_for_source(raw: Dictionary, source_ref: String) -> Dictionary:
	for citation_value: Variant in raw.get("citations", []):
		if citation_value is Dictionary and citation_value.get("source_ref", "") == source_ref:
			return citation_value
	return {}


func normalized_evidence(definition: Dictionary, evidence_id: String) -> Dictionary:
	for evidence_value: Variant in definition.get("evidence", []):
		if evidence_value is Dictionary and evidence_value.get("id", "") == evidence_id:
			return evidence_value
	return {}


func public_evidence(public_state: Dictionary, evidence_id: String) -> Dictionary:
	for evidence_value: Variant in public_state.get("evidence", []):
		if evidence_value is Dictionary and evidence_value.get("id", "") == evidence_id:
			return evidence_value
	return {}


func first_locked_evidence(public_state: Dictionary) -> Dictionary:
	for evidence_value: Variant in public_state.get("evidence", []):
		if evidence_value is Dictionary and not bool(evidence_value.get("unlocked", false)):
			return evidence_value
	return {}


func first_open_evidence(public_state: Dictionary) -> Dictionary:
	for evidence_value: Variant in public_state.get("evidence", []):
		if evidence_value is Dictionary and bool(evidence_value.get("unlocked", false)) \
				and not bool(evidence_value.get("discovered", false)):
			return evidence_value
	return {}


func discover_all(gs: Node, case_id: String) -> Array:
	var discovered: Array = []
	for _pass: int in range(20):
		var progress := false
		for row_value: Variant in gs.get_case_public_state(case_id).get("evidence", []):
			if not row_value is Dictionary:
				continue
			var row: Dictionary = row_value
			if bool(row.get("discovered", false)) or not bool(row.get("unlocked", false)):
				continue
			var tools: Array = row.get("requiredTools", [])
			if not tools.is_empty():
				gs.selected_tool = String(tools[0])
			var result: Dictionary = gs.discover_case_evidence(case_id, String(row.get("id", "")))
			if bool(result.get("ok", false)):
				discovered.append(String(row.get("id", "")))
				progress = true
		if not progress:
			break
	return discovered


func authority_signature(gs: Node) -> String:
	return JSON.stringify({
		"save": gs.save_payload(),
		"profile": gs.profile_payload(),
		"rng": int(gs.rng.state),
		"money": int(gs.money),
		"day": int(gs.day),
		"auction": gs.pending_auction.duplicate(true)
	})


func start_prologue(gs: Node) -> Dictionary:
	gs.persistence_enabled = false
	gs.player_profile = gs.default_player_profile()
	gs.reset_game()
	gs.persistence_enabled = false
	gs.language = "en"
	gs.new_game(1)
	return gs.begin_case("prologue_clock")


func finish(gs: Node, main: Node) -> void:
	var passed: int = results.filter(func(row: Dictionary): return bool(row.get("passed", false))).size()
	var report := {
		"suite": "R3 Authored Presentation Metadata",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"skipped": 0,
		"expectedCount": EXPECTED_TEST_COUNT,
		"authoredCases": AUTHORED_CASE_IDS.size(),
		"tests": results
	}
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report, "  "))
		output.close()
	print(JSON.stringify(report))
	if is_instance_valid(main):
		main.queue_free()
	await process_frame
	gs.persistence_enabled = false
	quit(0 if passed == EXPECTED_TEST_COUNT and results.size() == EXPECTED_TEST_COUNT else 1)


func run() -> void:
	var registry: Node = get_root().get_node("RuntimeRegistry")
	var gs: Node = get_root().get_node("GameState")
	gs.persistence_enabled = false
	var paths := raw_case_paths()
	var missing_cases: Array = []
	for case_id: String in AUTHORED_CASE_IDS:
		if registry.get_case_v2(case_id).is_empty() or raw_case(case_id, paths).is_empty():
			missing_cases.append(case_id)
	record(
		"PRESENTATION-REGISTRY-01",
		"All locked authored cases load with normalized player-safe presentation metadata",
		registry.authored_case_errors.is_empty() and missing_cases.is_empty() and paths.size() == AUTHORED_CASE_IDS.size(),
		{"registryErrors": registry.authored_case_errors, "missing": missing_cases, "lockCases": paths.keys()}
	)

	var source_count := 0
	var separated_count := 0
	var expected_source_count := 0
	var expected_separated_count := 0
	var metadata_failures: Array = []
	for case_id: String in AUTHORED_CASE_IDS:
		var raw := raw_case(case_id, paths)
		var definition: Dictionary = registry.get_case_v2(case_id)
		var raw_artifact_name: Variant = raw.get("artifact", {}).get("display_name", {})
		if definition.get("presentation", {}).get("artifact_display_name", {}) != raw_artifact_name:
			metadata_failures.append("%s:artifact_name" % case_id)
		for source_value: Variant in raw.get("sources", []):
			if not source_value is Dictionary:
				continue
			var source: Dictionary = source_value
			expected_source_count += 1
			var source_ref := String(source.get("source_ref", ""))
			var evidence := normalized_evidence(definition, source_ref)
			var presentation: Dictionary = evidence.get("presentation", {})
			var citation := citation_for_source(raw, source_ref)
			var expected_observation: Variant = source.get("short_observation", source.get("label", {}))
			source_count += 1
			if source.get("label", {}) != citation.get("label", {}):
				separated_count += 1
				expected_separated_count += 1
			if presentation.get("source_display_name", {}) != source.get("label", {}) \
					or evidence.get("citation", {}).get("label", {}) != citation.get("label", {}) \
					or presentation.get("short_observation", {}) != expected_observation \
					or presentation.get("citation_locator", {}) != citation.get("locator", {}) \
					or not localized_complete(presentation.get("unlock_action_label", {})) \
					or not localized_complete(presentation.get("unlock_target_label", {})):
				metadata_failures.append("%s:%s" % [case_id, source_ref])
	record(
		"PRESENTATION-SOURCE-02",
		"All authored source display names preserve authored citation-label distinctions and localized locators",
		source_count == expected_source_count and separated_count == expected_separated_count and metadata_failures.is_empty(),
		{"sources": source_count, "expectedSources": expected_source_count, "sourceCitationDifferences": separated_count, "expectedDifferences": expected_separated_count, "failures": metadata_failures}
	)

	var fallback_raw := raw_case("prologue_clock", paths).duplicate(true)
	fallback_raw["artifact"].erase("display_name")
	var fallback_source: Dictionary = fallback_raw["sources"][0]
	fallback_source.erase("label")
	var fallback_normalized: Dictionary = registry.normalize_authored_case_v2(fallback_raw)
	var fallback_evidence := normalized_evidence(fallback_normalized, String(fallback_source.get("source_ref", "")))
	var fallback_presentation: Dictionary = fallback_evidence.get("presentation", {})
	var spec_display := String(registry.get_spec(String(fallback_raw.get("artifact", {}).get("spec_id", ""))).get("displayName", ""))
	record(
		"PRESENTATION-FALLBACK-03",
		"Missing optional artifact and source copy falls back to ArtifactSpec name, localized kind, and title-based short observation",
		fallback_normalized.get("artifact_display_name", {}) == {"en": spec_display, "ko": spec_display} \
			and fallback_presentation.get("source_display_name", {}) == {"en": "Object clue", "ko": "실물 단서"} \
			and fallback_presentation.get("short_observation", {}) == fallback_presentation.get("source_display_name", {}) \
			and registry.validate_authored_case_v2(fallback_normalized).get("code", "") == "OK",
		{"artifact": fallback_normalized.get("artifact_display_name", {}), "source": fallback_presentation, "spec": spec_display}
	)

	var optional_raw := raw_case("prologue_clock", paths).duplicate(true)
	var optional_source: Dictionary = optional_raw["sources"][0]
	optional_source["short_observation"] = {"en": "Oxidation boundary recorded", "ko": "산화 경계 기록 완료"}
	optional_source["unlock"]["action_label"] = {"en": "Photograph", "ko": "촬영하기"}
	optional_source["unlock"]["target_label"] = {"en": "the rear plate", "ko": "후면판"}
	var optional_normalized: Dictionary = registry.normalize_authored_case_v2(optional_raw)
	var optional_presentation: Dictionary = normalized_evidence(optional_normalized, String(optional_source.get("source_ref", ""))).get("presentation", {})
	record(
		"PRESENTATION-OPTIONAL-04",
		"Optional localized short observation and unlock action/target overrides survive normalization without affecting evidence authority",
		optional_presentation.get("short_observation", {}) == optional_source.get("short_observation", {}) \
			and optional_presentation.get("unlock_action_label", {}) == optional_source.get("unlock", {}).get("action_label", {}) \
			and optional_presentation.get("unlock_target_label", {}) == optional_source.get("unlock", {}).get("target_label", {}) \
			and registry.validate_authored_case_v2(optional_normalized).get("code", "") == "OK",
		optional_presentation
	)

	var hostile_raw := raw_case("prologue_clock", paths).duplicate(true)
	var hostile_source: Dictionary = hostile_raw["sources"][0]
	var hostile_ref := String(hostile_source.get("source_ref", ""))
	var hostile_citation_id := String(hostile_source.get("citation_id", ""))
	hostile_raw["artifact"]["display_name"] = {"en": "artifact_001", "ko": "artifact_001"}
	hostile_source["label"] = {"en": hostile_ref, "ko": hostile_ref}
	hostile_source["short_observation"] = {"en": hostile_citation_id, "ko": hostile_citation_id}
	hostile_source["unlock"]["action_label"] = {"en": hostile_source.unlock.action, "ko": hostile_source.unlock.action}
	hostile_source["unlock"]["target_label"] = {"en": hostile_source.unlock.target, "ko": hostile_source.unlock.target}
	for citation_value: Variant in hostile_raw.get("citations", []):
		if citation_value is Dictionary and citation_value.get("id", "") == hostile_citation_id:
			citation_value["locator"] = {"en": hostile_ref, "ko": hostile_ref}
	var hostile_normalized: Dictionary = registry.normalize_authored_case_v2(hostile_raw)
	var hostile_presentation: Dictionary = normalized_evidence(hostile_normalized, hostile_ref).get("presentation", {})
	var hostile_surface := JSON.stringify({"artifact": hostile_normalized.get("artifact_display_name", {}), "source": hostile_presentation})
	var hostile_tokens := ["artifact_001", hostile_ref, hostile_citation_id, String(hostile_source.unlock.action), String(hostile_source.unlock.target)]
	var hostile_leaks: Array = hostile_tokens.filter(func(token: String): return hostile_surface.contains(token))
	record(
		"PRESENTATION-HOSTILE-05",
		"Identifier-shaped localized inputs fail closed to safe generic presentation copy",
		hostile_leaks.is_empty() and hostile_presentation.get("citation_locator", {}).is_empty() \
			and registry.validate_authored_case_v2(hostile_normalized).get("code", "") == "OK",
		{"leaks": hostile_leaks, "surface": hostile_surface}
	)

	var npc_sources := 0
	var npc_portraits := 0
	var expected_npc_portraits := 0
	var npc_fallback_failures: Array = []
	for case_id: String in AUTHORED_CASE_IDS:
		for evidence_value: Variant in registry.get_case_v2(case_id).get("evidence", []):
			if evidence_value is Dictionary and evidence_value.get("source", {}).get("kind", "") == "NPC":
				npc_sources += 1
				var portrait: Dictionary = evidence_value.get("presentation", {}).get("npc_portrait", {})
				var expected_portrait: Dictionary = registry.authored_npc_portrait_presentation(String(evidence_value.get("source", {}).get("ref_id", "")), String(portrait.get("expression", "neutral")))
				var expected_path := String(expected_portrait.get("asset_path", ""))
				if not expected_path.is_empty():
					expected_npc_portraits += 1
				if not portrait.is_empty() and String(portrait.get("asset_path", "")) == expected_path:
					npc_portraits += 1
				elif not portrait.is_empty() or not expected_path.is_empty():
					npc_fallback_failures.append({"case": case_id, "expected": expected_path, "actual": portrait})
	var artifact: Dictionary = start_prologue(gs)
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await settle_ui()
	main.language = "en"
	main.selected = artifact
	main.load_artifact(artifact)
	var all_discovered := discover_all(gs, "prologue_clock")
	var npc_public_row: Dictionary = {}
	for row_value: Variant in gs.get_case_public_state("prologue_clock").get("evidence", []):
		if row_value is Dictionary and row_value.get("sourceKind", "") == "NPC":
			npc_public_row = row_value
			break
	main.case_dossier_case_id = "prologue_clock"
	main.case_detail_evidence_id = String(npc_public_row.get("id", ""))
	main.show_case_dossier("prologue_clock")
	await settle_ui()
	var generic_npc_icon: TextureRect = main.find_child("CaseSourceIcon", true, false)
	record(
		"PRESENTATION-NPC-06",
		"Every authored case-NPC witness resolves to a repo-native portrait and unmapped witnesses retain the generic NPC icon",
		npc_sources > 0 and npc_portraits == expected_npc_portraits and npc_fallback_failures.is_empty() \
			and not npc_public_row.is_empty() and bool(npc_public_row.get("unlocked", false)) \
			and (main.find_child("CaseNpcSourcePortrait", true, false) != null or (generic_npc_icon != null and generic_npc_icon.texture != null)),
		{"npcSources": npc_sources, "approvedPortraits": npc_portraits, "expectedPortraits": expected_npc_portraits, "failures": npc_fallback_failures, "discovered": all_discovered.size(), "genericIcon": generic_npc_icon != null}
	)

	artifact = start_prologue(gs)
	main.selected = artifact
	main.load_artifact(artifact)
	var prologue_public: Dictionary = gs.get_case_public_state("prologue_clock")
	var locked_row := first_locked_evidence(prologue_public)
	main.case_dossier_case_id = "prologue_clock"
	main.case_detail_evidence_id = String(locked_row.get("id", ""))
	main.show_case_dossier("prologue_clock")
	await settle_ui()
	var locked_card: Button = main.find_child("CaseEvidenceCard_%s" % String(locked_row.get("id", "")).validate_node_name(), true, false)
	var locked_detail: Label = main.find_child("CaseLockedActionTarget", true, false)
	var locked_copy := visible_surface_copy(main)
	var locked_definition := normalized_evidence(registry.get_case_v2("prologue_clock"), String(locked_row.get("id", "")))
	var locked_hidden_tokens := [
		String(locked_row.get("id", "")), String(locked_row.get("sourceRef", "")), String(locked_row.get("entryId", "")),
		localized(locked_definition.get("presentation", {}).get("source_display_name", {}), "en"),
		localized(locked_definition.get("text", {}), "en")
	]
	for requirement_value: Variant in locked_row.get("requires", []):
		locked_hidden_tokens.append(String(requirement_value))
	for tool_value: Variant in locked_row.get("requiredTools", []):
		locked_hidden_tokens.append(String(tool_value))
	var locked_leaks: Array = locked_hidden_tokens.filter(func(token: String): return not token.is_empty() and locked_copy.contains(token))
	var expected_locked := "%s · %s" % [localized(locked_row.get("unlockActionLabel", {}), "en"), localized(locked_row.get("unlockTargetLabel", {}), "en")]
	record(
		"PRESENTATION-LOCKED-07",
		"A locked clue card and detail show only localized action/target guidance and reveal no hidden evidence, source, target, prerequisite or tool identifier",
		not artifact.is_empty() and not locked_row.is_empty() and locked_card != null and locked_detail != null \
			and locked_card.text == "LOCKED\n%s" % expected_locked and locked_detail.text == expected_locked \
			and locked_leaks.is_empty() and main.find_children("CaseNpcSourcePortrait", "TextureRect", true, false).is_empty(),
		{"card": locked_card.text if locked_card != null else "", "detail": locked_detail.text if locked_detail != null else "", "hiddenLeaks": locked_leaks}
	)

	var locale_failures: Array = []
	for locale: String in ["en", "ko"]:
		gs.language = locale
		main.language = locale
		for case_id: String in AUTHORED_CASE_IDS:
			main.case_detail_evidence_id = ""
			main.show_case_dossier(case_id)
			await settle_ui(2)
			var definition: Dictionary = registry.get_case_v2(case_id)
			var public_state: Dictionary = gs.get_case_public_state(case_id)
			var copy := visible_surface_copy(main)
			var artifact_name := localized(public_state.get("artifactDisplayName", {}), locale)
			var internal_tokens: Array = [case_id, String(definition.get("artifact_spec_id", ""))]
			for row_value: Variant in public_state.get("evidence", []):
				if not row_value is Dictionary:
					continue
				var row: Dictionary = row_value
				internal_tokens.append(String(row.get("id", "")))
				internal_tokens.append(String(row.get("sourceRef", "")))
				internal_tokens.append(String(row.get("entryId", "")))
				var raw_target := String(raw_case(case_id, paths).get("sources", []).filter(func(source_value: Variant): return source_value is Dictionary and source_value.get("source_ref", "") == row.get("id", ""))[0].get("unlock", {}).get("target", ""))
				internal_tokens.append(raw_target)
				if bool(row.get("unlocked", false)) and not copy.contains(localized(row.get("sourceDisplayName", {}), locale)):
					locale_failures.append("%s:%s:source" % [locale, row.get("id", "")])
				if not bool(row.get("unlocked", false)):
					var locale_locked_card: Button = main.find_child(
						"CaseEvidenceCard_%s" % String(row.get("id", "")).validate_node_name(),
						true,
						false
					)
					var expected_action_target := "%s · %s" % [
						localized(row.get("unlockActionLabel", {}), locale),
						localized(row.get("unlockTargetLabel", {}), locale)
					]
					var expected_locked_card := "%s\n%s" % ["LOCKED" if locale == "en" else "잠김", expected_action_target]
					# Inspect the specific locked surface. A page-wide source-name search can
					# false-positive when the same localized phrase appears in briefing copy
					# or is intentionally reused as the public unlock target.
					if locale_locked_card == null or locale_locked_card.text != expected_locked_card:
						locale_failures.append({"case": case_id, "locale": locale, "evidence": row.get("id", ""), "expectedLockedCard": expected_locked_card, "actualLockedCard": locale_locked_card.text if locale_locked_card != null else "<missing>"})
			var leaks: Array = internal_tokens.filter(func(token: String): return not token.is_empty() and copy.contains(token))
			if artifact_name.is_empty() or not copy.contains(artifact_name) or not leaks.is_empty():
				locale_failures.append({"case": case_id, "locale": locale, "artifact": artifact_name, "leaks": leaks})
	record(
		"PRESENTATION-UI-08",
		"All thirteen authored dossiers render artifact/source presentation in Korean and English with zero raw case, spec, source, registry or target ids",
		locale_failures.is_empty(),
		{"screensChecked": AUTHORED_CASE_IDS.size() * 2, "failures": locale_failures}
	)

	artifact = start_prologue(gs)
	main.language = "en"
	main.selected = artifact
	main.load_artifact(artifact)
	var before_discovery: Dictionary = gs.get_case_public_state("prologue_clock")
	var open_row := first_open_evidence(before_discovery)
	main.case_dossier_case_id = "prologue_clock"
	main.case_detail_evidence_id = String(open_row.get("id", ""))
	main.show_case_dossier("prologue_clock")
	await settle_ui()
	var locator_before_nodes := main.find_children("CaseCitationLocator", "Label", true, false).size()
	var discovery: Dictionary = gs.discover_case_evidence("prologue_clock", String(open_row.get("id", "")))
	var after_discovery: Dictionary = gs.get_case_public_state("prologue_clock")
	var discovered_row := public_evidence(after_discovery, String(open_row.get("id", "")))
	var locator_text := localized(discovered_row.get("citationLocator", {}), "en")
	main.case_detail_evidence_id = String(open_row.get("id", ""))
	main.show_case_dossier("prologue_clock")
	await settle_ui()
	var locator_label: Label = main.find_child("CaseCitationLocator", true, false)
	var locator_detail_text := locator_label.text if locator_label != null else ""
	var cited: bool = gs.toggle_case_citation("prologue_clock", String(open_row.get("id", "")))
	main.show_case_dossier("prologue_clock")
	await settle_ui()
	var citation_button: Button = main.find_child("ReportCitationRemove_%s" % String(open_row.get("id", "")).validate_node_name(), true, false)
	var undiscovered_locator_leaks: Array = []
	var visible_after := visible_surface_copy(main)
	for row_value: Variant in after_discovery.get("evidence", []):
		if row_value is Dictionary and not bool(row_value.get("discovered", false)):
			var hidden_locator := localized(normalized_evidence(registry.get_case_v2("prologue_clock"), String(row_value.get("id", ""))).get("presentation", {}).get("citation_locator", {}), "en")
			if not hidden_locator.is_empty() and visible_after.contains(hidden_locator):
				undiscovered_locator_leaks.append(hidden_locator)
	record(
		"PRESENTATION-LOCATOR-09",
		"Citation locator stays absent before discovery, then appears only in discovered detail and the cited report tooltip",
		locator_before_nodes == 0 and bool(discovery.get("ok", false)) and cited and not locator_text.is_empty() \
			and locator_detail_text.contains(locator_text) \
			and citation_button != null and citation_button.tooltip_text.contains(locator_text) \
			and undiscovered_locator_leaks.is_empty(),
		{"beforeNodes": locator_before_nodes, "locator": locator_text, "detail": locator_detail_text, "citationTooltip": citation_button.tooltip_text if citation_button != null else "", "undiscoveredLeaks": undiscovered_locator_leaks}
	)

	artifact = start_prologue(gs)
	main.language = "ko"
	main.selected = artifact
	main.load_artifact(artifact)
	var authority_before := authority_signature(gs)
	var definition_before := JSON.stringify(registry.get_case_v2("prologue_clock"))
	main.show_case_dossier("prologue_clock")
	await settle_ui()
	var authority_after := authority_signature(gs)
	var definition_after := JSON.stringify(registry.get_case_v2("prologue_clock"))
	record(
		"PRESENTATION-AUTHORITY-10",
		"Locale and dossier rendering are presentation-only: save, profile, economy, auction, RNG and authored definition remain byte-exact",
		authority_before == authority_after and definition_before == definition_after,
		{"authorityExact": authority_before == authority_after, "definitionExact": definition_before == definition_after, "rng": int(gs.rng.state)}
	)

	var legacy_case_id := ""
	for story_case_value: Variant in registry.campaign.get("cases", []):
		if story_case_value is Dictionary and not registry.has_authored_case_v2(String(story_case_value.get("id", ""))):
			legacy_case_id = String(story_case_value.get("id", ""))
			break
	var legacy_definition: Dictionary = gs.case_definition(legacy_case_id)
	var legacy_public: Dictionary = gs.get_case_public_state(legacy_case_id)
	var legacy_expected: Variant = legacy_definition.get("evidence", [])[0].get("citation", {}).get("label", {}) if not legacy_definition.get("evidence", []).is_empty() else {}
	var legacy_row: Dictionary = legacy_public.get("evidence", [])[0] if not legacy_public.get("evidence", []).is_empty() else {}
	record(
		"PRESENTATION-LEGACY-11",
		"Definitions without authored presentation fields retain the existing citation-label UI fallback",
		not legacy_case_id.is_empty() and not legacy_row.is_empty() \
			and legacy_row.get("sourceDisplayName", {}) == legacy_expected \
			and legacy_row.get("text", {}) == legacy_expected,
		{"caseId": legacy_case_id, "expected": legacy_expected, "public": {"sourceDisplayName": legacy_row.get("sourceDisplayName", {}), "text": legacy_row.get("text", {})}}
	)

	await finish(gs, main)
