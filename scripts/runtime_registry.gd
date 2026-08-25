extends Node

const AUTHORED_OUTCOME_ORDER := {
	"masterful": 0,
	"credible": 1,
	"mistaken": 2,
	"reviewed_with_mentor": 3
}
const AUTHORED_RULE_CORRECTNESS := ["CORRECT", "INCORRECT", "ANY"]
const AUTHORED_SOURCE_PRESENTATION := {
	"ARTIFACT": {"en": "Object clue", "ko": "실물 단서"},
	"DOCUMENT": {"en": "Document clue", "ko": "문서 단서"},
	"NPC": {"en": "Witness clue", "ko": "인물 단서"},
	"REFERENCE": {"en": "Reference clue", "ko": "참고 단서"}
}
const AUTHORED_UNLOCK_ACTION_PRESENTATION := {
	"inspect": {"en": "Inspect", "ko": "살펴보기"},
	"disassemble": {"en": "Open carefully", "ko": "조심히 열기"},
	"read_document": {"en": "Read", "ko": "읽기"},
	"turn_document": {"en": "Turn over", "ko": "뒤집어 보기"},
	"ask_npc": {"en": "Ask", "ko": "물어보기"},
	"query_reference": {"en": "Compare", "ko": "대조하기"},
	"inspect_uv": {"en": "Check under UV", "ko": "자외선 확인"},
	"uv_inspect": {"en": "Check under UV", "ko": "자외선 확인"},
	"surface_test": {"en": "Test a small area", "ko": "작은 부위 시험"},
	"measure": {"en": "Measure", "ko": "측정하기"},
	"search": {"en": "Search", "ko": "찾아보기"}
}
const AUTHORED_UNLOCK_TARGET_PRESENTATION := {
	"ARTIFACT": {"en": "the object area", "ko": "유물 부위"},
	"DOCUMENT": {"en": "the document", "ko": "문서"},
	"NPC": {"en": "the witness", "ko": "인물"},
	"REFERENCE": {"en": "the reference catalogue", "ko": "참고 자료"}
}
const AUTHORED_INTERNAL_PREFIXES := [
	"src.", "cite.", "hyp.", "doc.", "res://", "user://",
	"artifact_", "document_", "story_artifact_", "period_ref_",
	"material_note_", "maker_history_"
]
const ARTIFACT_RENDER_RECIPES := ["DEFAULT", "TYPEWRITER_CIPHER", "SEXTANT", "GAUGE", "MUSIC_BOX", "OPTIC", "COMPOSITE", "CHRONOMETER", "MICROSCOPE", "WIRE_RECORDER", "SIGNAL_LANTERN", "SPECTROSCOPE", "ASTRONOMICAL_REGULATOR"]
const ARTIFACT_RENDER_DTO_KEYS := [
	"specId", "meshPath", "scale", "materialPath", "palette",
	"metallic", "roughness", "trim", "detail", "recipe"
]
const STORY_ARTIFACT_RENDER_OVERRIDES := {
	"story_artifact_16|artifact_050": {
		"recipe": "GAUGE",
		"meshPath": "res://assets/artifacts/gauge.obj"
	},
	"story_artifact_18|artifact_035": {
		"recipe": "MUSIC_BOX",
		"meshPath": "res://assets/artifacts/music_box.obj"
	},
	"story_artifact_19|artifact_057": {
		"recipe": "OPTIC",
		"meshPath": "res://assets/artifacts/model_12.obj"
	},
	"story_artifact_20|artifact_059": {
		"recipe": "COMPOSITE",
		"meshPath": "res://assets/artifacts/model_14.obj"
	},
	"story_artifact_21|artifact_061": {
		"recipe": "CHRONOMETER",
		"meshPath": "res://assets/artifacts/clock.obj"
	},
	"story_artifact_22|artifact_075": {
		"recipe": "MICROSCOPE",
		"meshPath": "res://assets/artifacts/binoculars.obj"
	},
	"story_artifact_23|artifact_078": {
		"recipe": "WIRE_RECORDER",
		"meshPath": "res://assets/artifacts/model_02.obj"
	},
	"story_artifact_24|artifact_077": {
		"recipe": "SIGNAL_LANTERN",
		"meshPath": "res://assets/artifacts/telephone.obj"
	},
	"story_artifact_25|artifact_079": {
		"recipe": "SPECTROSCOPE",
		"meshPath": "res://assets/artifacts/model_05.obj"
	},
	"story_artifact_26|artifact_080": {
		"recipe": "ASTRONOMICAL_REGULATOR",
		"meshPath": "res://assets/artifacts/watch.obj"
	}
}

var specs: Dictionary = {}
var spec_order: Array = []
var baseline_spec_ids: Array = []
var expansion_spec_ids: Array = []
var stage_definitions: Dictionary = {}
var stage_order: Array = []
var stage_definition_errors: Array = []
var artifact_unlock_stage: Dictionary = {}
var stage_config: Dictionary = {}
var makers: Dictionary = {}
var tools: Dictionary = {}
var bidders: Array = []
var bidder_by_id: Dictionary = {}
var events: Array = []
var event_by_id: Dictionary = {}
var upgrades: Array = []
var upgrade_by_id: Dictionary = {}
var localization: Dictionary = {}
var materials: Dictionary = {}
var material_data: Dictionary = {}
var runtime_model_paths: Dictionary = {}
var visual_variants: Dictionary = {}
var campaign: Dictionary = {}
var campaign_acts: Dictionary = {}
var campaign_cases: Dictionary = {}
var authored_cases_v2: Dictionary = {}
var authored_case_errors: Array = []
var document_to_cases: Dictionary = {}
var npc_to_cases: Dictionary = {}
var reference_to_cases: Dictionary = {}
var npcs: Dictionary = {}
var story_artifacts: Dictionary = {}
var documents: Dictionary = {}
var reference_database: Dictionary = {}
var commissions: Array = []


func _ready() -> void:
	load_all()


func read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("R3 registry could not open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null:
		push_error("R3 registry could not parse %s" % path)
		return {}
	return parsed


func load_all() -> void:
	specs.clear()
	spec_order.clear()
	baseline_spec_ids.clear()
	expansion_spec_ids.clear()
	stage_definitions.clear()
	stage_order.clear()
	stage_definition_errors.clear()
	artifact_unlock_stage.clear()
	stage_config.clear()
	makers.clear()
	tools.clear()
	runtime_model_paths.clear()
	visual_variants.clear()
	event_by_id.clear()
	upgrade_by_id.clear()
	campaign_acts.clear()
	campaign_cases.clear()
	authored_cases_v2.clear()
	authored_case_errors.clear()
	document_to_cases.clear()
	npc_to_cases.clear()
	reference_to_cases.clear()
	npcs.clear()
	story_artifacts.clear()
	documents.clear()

	var artifact_index: Variant = read_json("res://data/artifacts/index.json")
	if artifact_index is Array:
		for spec: Dictionary in artifact_index:
			register_artifact_spec(spec, false)

	var expansion_path := "res://data/artifacts/stage_expansion.json"
	if FileAccess.file_exists(expansion_path):
		var expansion_rows: Variant = read_json(expansion_path)
		if expansion_rows is Array:
			for spec: Dictionary in expansion_rows:
				register_artifact_spec(spec, true)
		else:
			stage_definition_errors.append("STAGE_EXPANSION_NOT_ARRAY")

	var maker_rows: Variant = read_json("res://data/makers/makers.json")
	if maker_rows is Array:
		for maker: Dictionary in maker_rows:
			makers[maker.makerId] = maker

	var tool_rows: Variant = read_json("res://data/tools/tools.json")
	if tool_rows is Array:
		for tool: Dictionary in tool_rows:
			tools[tool.id] = tool

	bidders = read_json("res://data/bidders/bidders.json")
	for bidder: Dictionary in bidders:
		bidder_by_id[bidder.id] = bidder

	events = read_json("res://data/events/events.json")
	for event: Dictionary in events:
		event_by_id[event.id] = event

	upgrades = read_json("res://data/upgrades/upgrades.json")
	for upgrade: Dictionary in upgrades:
		upgrade_by_id[upgrade.id] = upgrade

	var variant_rows: Variant = read_json("res://data/visual_variants.json")
	if variant_rows is Array:
		for variant: Dictionary in variant_rows:
			visual_variants[variant.id] = variant
	var stage_variant_path := "res://data/stage_visual_variants.json"
	if FileAccess.file_exists(stage_variant_path):
		var stage_variant_rows: Variant = read_json(stage_variant_path)
		if stage_variant_rows is Array:
			for variant: Dictionary in stage_variant_rows:
				var variant_id: String = variant.get("id", "")
				if variant_id.is_empty() or visual_variants.has(variant_id):
					stage_definition_errors.append("INVALID_OR_DUPLICATE_STAGE_VARIANT:%s" % variant_id)
					continue
				var render_recipe := normalized_artifact_render_recipe(variant.get("renderRecipe", "DEFAULT"))
				if not ARTIFACT_RENDER_RECIPES.has(render_recipe):
					stage_definition_errors.append("UNKNOWN_ARTIFACT_RENDER_RECIPE:%s:%s" % [variant_id, render_recipe])
				visual_variants[variant_id] = variant
		else:
			stage_definition_errors.append("STAGE_VARIANTS_NOT_ARRAY")

	load_stage_definitions()

	campaign = read_json("res://data/campaign/campaign.json")
	for act: Dictionary in campaign.get("acts", []):
		campaign_acts[act.id] = act
	for story_case: Dictionary in campaign.get("cases", []):
		campaign_cases[story_case.id] = story_case

	var npc_rows: Variant = read_json("res://data/npcs/npcs.json")
	if npc_rows is Array:
		for npc: Dictionary in npc_rows:
			npcs[npc.id] = npc

	var artifact_rows: Variant = read_json("res://data/campaign/story_artifacts.json")
	if artifact_rows is Array:
		for artifact: Dictionary in artifact_rows:
			story_artifacts[artifact.id] = artifact
	validate_story_artifact_render_overrides()

	var document_rows: Variant = read_json("res://data/documents/documents.json")
	if document_rows is Array:
		for document: Dictionary in document_rows:
			documents[document.id] = document

	reference_database = read_json("res://data/reference/reference_database.json")
	commissions = read_json("res://data/campaign/commissions.json")
	load_authored_cases_v2()
	localization.en = read_json("res://localization/en.json")
	localization.ko = read_json("res://localization/ko.json")
	var material_rows: Variant = read_json("res://data/materials/materials.json")
	if material_rows is Array:
		for material: Dictionary in material_rows:
			material_data[material.id] = material
	for file_name: String in DirAccess.get_files_at("res://assets/materials"):
		if file_name.ends_with(".tres"):
			materials[file_name.trim_suffix(".tres")] = "res://assets/materials/" + file_name


func register_artifact_spec(spec: Dictionary, expansion: bool) -> void:
	var spec_id: String = spec.get("id", "")
	if spec_id.is_empty() or specs.has(spec_id):
		stage_definition_errors.append("INVALID_OR_DUPLICATE_ARTIFACT_SPEC:%s" % spec_id)
		return
	specs[spec_id] = spec
	spec_order.append(spec_id)
	if expansion:
		expansion_spec_ids.append(spec_id)
	else:
		baseline_spec_ids.append(spec_id)
	var model_name: String = spec.get("baseModel", spec.get("model", ""))
	if not model_name.is_empty():
		runtime_model_paths[spec_id] = "res://assets/artifacts/%s" % model_name


func load_stage_definitions() -> void:
	var stage_path := "res://data/stages/stages.json"
	if not FileAccess.file_exists(stage_path):
		stage_definition_errors.append("MISSING_STAGE_DEFINITIONS")
		return
	var raw: Variant = read_json(stage_path)
	var rows: Array = raw.get("stages", []) if raw is Dictionary else (raw if raw is Array else [])
	if raw is Dictionary:
		stage_config = raw.duplicate(true)
	if rows.is_empty():
		stage_definition_errors.append("EMPTY_STAGE_DEFINITIONS")
		return
	for row_value: Variant in rows:
		if not row_value is Dictionary:
			stage_definition_errors.append("INVALID_STAGE_ROW")
			continue
		var row: Dictionary = row_value.duplicate(true)
		var stage_id := int(row.get("stage_id", 0))
		if stage_id < 1 or stage_id > 10 or stage_definitions.has(stage_id):
			stage_definition_errors.append("INVALID_OR_DUPLICATE_STAGE:%d" % stage_id)
			continue
		# Runtime owns the exact progression rule. Authored rounding can never
		# compound into gameplay or drift between save generations.
		row["difficulty_multiplier"] = pow(1.07, stage_id - 1)
		if not row.get("case_ids", []) is Array or not row.get("introduced_artifact_ids", []) is Array:
			stage_definition_errors.append("INVALID_STAGE_LISTS:%d" % stage_id)
			continue
		stage_definitions[stage_id] = row
		stage_order.append(stage_id)
	stage_order.sort()
	for stage_id_value: Variant in stage_order:
		var stage_id := int(stage_id_value)
		for spec_id_value: Variant in stage_definitions[stage_id].get("introduced_artifact_ids", []):
			var spec_id := String(spec_id_value)
			if not specs.has(spec_id):
				stage_definition_errors.append("UNKNOWN_STAGE_ARTIFACT:%d:%s" % [stage_id, spec_id])
				continue
			if artifact_unlock_stage.has(spec_id):
				stage_definition_errors.append("DUPLICATE_STAGE_ARTIFACT:%s" % spec_id)
				continue
			artifact_unlock_stage[spec_id] = stage_id
	if stage_definitions.size() != 10:
		stage_definition_errors.append("STAGE_COUNT:%d" % stage_definitions.size())
	for expansion_id_value: Variant in expansion_spec_ids:
		var expansion_id := String(expansion_id_value)
		if not artifact_unlock_stage.has(expansion_id):
			stage_definition_errors.append("UNMAPPED_EXPANSION_ARTIFACT:%s" % expansion_id)


func load_authored_cases_v2() -> void:
	var base_path := "res://data/cases/authored_v2"
	for file_name: String in DirAccess.get_files_at(base_path):
		if not file_name.ends_with(".json"):
			continue
		var definition: Variant = read_json("%s/%s" % [base_path, file_name])
		if not definition is Dictionary:
			authored_case_errors.append("%s:NOT_A_DICTIONARY" % file_name)
			continue
		var normalized := normalize_authored_case_v2(definition)
		var validation := validate_authored_case_v2(normalized)
		if not bool(validation.get("ok", false)):
			authored_case_errors.append("%s:%s" % [file_name, validation.get("code", "INVALID")])
			continue
		var case_id: String = normalized.case_id
		if authored_cases_v2.has(case_id):
			authored_case_errors.append("%s:DUPLICATE_CASE_ID:%s" % [file_name, case_id])
			continue
		authored_cases_v2[case_id] = normalized
		for evidence: Dictionary in normalized.get("evidence", []):
			var source: Dictionary = evidence.get("source", {})
			var source_kind: String = source.get("kind", "")
			var source_ref: String = source.get("ref_id", "")
			if source_ref.is_empty():
				continue
			var index: Dictionary = {}
			match source_kind:
				"DOCUMENT": index = document_to_cases
				"NPC": index = npc_to_cases
				"REFERENCE": index = reference_to_cases
				_: continue
			if not index.has(source_ref):
				index[source_ref] = []
			if not index[source_ref].has(case_id):
				index[source_ref].append(case_id)


func normalize_authored_rule_threshold(value: Variant) -> Variant:
	# Godot's JSON parser represents JSON numbers as floats. Canonicalize only
	# finite whole numbers; booleans, fractions and non-numeric values must reach
	# validation unchanged and fail closed.
	if value is int:
		return value
	if value is float and is_finite(float(value)) and is_equal_approx(float(value), floorf(float(value))):
		return int(value)
	return value


func normalize_authored_outcome_rules(raw_rules: Variant) -> Variant:
	# Keep authored order: the first rule whose conditions all match owns the
	# outcome. Invalid shapes are deliberately preserved for the runtime
	# validator instead of being silently converted into the legacy fallback.
	if not raw_rules is Array:
		return raw_rules
	var normalized_rules: Array = []
	for rule_value: Variant in raw_rules:
		if not rule_value is Dictionary:
			normalized_rules.append(rule_value)
			continue
		var rule: Dictionary = rule_value
		var outcome_id := String(rule.get("outcome_id", rule.get("outcome", "")))
		var correctness := String(rule.get("correctness", "")).to_upper()
		if correctness.is_empty():
			if not rule.has("requires_correct_hypothesis"):
				correctness = "ANY"
			elif rule.get("requires_correct_hypothesis") is bool:
				correctness = "CORRECT" if bool(rule.get("requires_correct_hypothesis")) else "INCORRECT"
			else:
				correctness = "INVALID"
		var minimum_groups: Variant = normalize_authored_rule_threshold(rule.get("minimum_independent_groups", 0))
		var minimum_citations: Variant = normalize_authored_rule_threshold(rule.get("minimum_citations", 0))
		var minimum_net_support: Variant
		if rule.has("minimum_net_support"):
			minimum_net_support = normalize_authored_rule_threshold(rule.get("minimum_net_support"))
		elif outcome_id == "masterful":
			# Preserve the existing STRONG contract for authored rules which
			# predate an explicit net-support threshold.
			minimum_net_support = minimum_groups
		elif outcome_id == "credible":
			minimum_net_support = 1
		else:
			minimum_net_support = 0
		normalized_rules.append({
			"outcome_id": outcome_id,
			"correctness": correctness,
			"requires_all_required_sources": rule.get("requires_all_required_sources", false),
			"minimum_independent_groups": minimum_groups,
			"minimum_citations": minimum_citations,
			"minimum_net_support": minimum_net_support,
			"fallback": rule.get("fallback", false)
		})
	return normalized_rules


func authored_localized_fallback(value: Variant) -> Dictionary:
	if value is Dictionary:
		var localized_value: Dictionary = value
		var en := String(localized_value.get("en", "")).strip_edges()
		var ko := String(localized_value.get("ko", "")).strip_edges()
		if not en.is_empty() and not ko.is_empty():
			return {"en": en, "ko": ko}
		return {"en": "", "ko": ""}
	if value == null:
		return {"en": "", "ko": ""}
	var text := str(value).strip_edges()
	return {"en": text, "ko": text} if not text.is_empty() else {"en": "", "ko": ""}


func authored_presentation_text_is_internal(text: String, forbidden_values: Array = []) -> bool:
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return false
	var lowered := normalized.to_lower()
	for prefix: String in AUTHORED_INTERNAL_PREFIXES:
		if lowered.begins_with(prefix):
			return true
	for forbidden_value: Variant in forbidden_values:
		var forbidden := str(forbidden_value).strip_edges() if forbidden_value != null else ""
		if not forbidden.is_empty() and normalized == forbidden:
			return true
	# A single lower-case snake token is presentation metadata accidentally fed
	# from an action/target/localization key, never authored player copy.
	if not normalized.contains(" ") and normalized.contains("_") and normalized == lowered:
		return true
	return false


func authored_safe_localized(value: Variant, fallback: Variant, forbidden_values: Array = []) -> Dictionary:
	var candidate := authored_localized_fallback(value)
	var valid := not String(candidate.get("en", "")).is_empty() and not String(candidate.get("ko", "")).is_empty()
	if valid:
		for locale: String in ["en", "ko"]:
			if authored_presentation_text_is_internal(String(candidate.get(locale, "")), forbidden_values):
				valid = false
				break
	if valid:
		return candidate
	return authored_localized_fallback(fallback)


func authored_localized_presentation_valid(value: Variant, allow_empty: bool = false) -> bool:
	if not value is Dictionary:
		return false
	var localized_value: Dictionary = value
	var en := String(localized_value.get("en", "")).strip_edges()
	var ko := String(localized_value.get("ko", "")).strip_edges()
	if allow_empty and en.is_empty() and ko.is_empty():
		return true
	return not en.is_empty() and not ko.is_empty() \
		and not authored_presentation_text_is_internal(en) \
		and not authored_presentation_text_is_internal(ko)


func authored_source_kind_presentation(source_kind: String) -> Dictionary:
	return (AUTHORED_SOURCE_PRESENTATION.get(source_kind, {"en": "Clue", "ko": "단서"}) as Dictionary).duplicate(true)


func authored_unlock_action_presentation(action_id: String) -> Dictionary:
	return (AUTHORED_UNLOCK_ACTION_PRESENTATION.get(action_id, {"en": "Investigate", "ko": "조사하기"}) as Dictionary).duplicate(true)


func authored_unlock_target_presentation(source_kind: String) -> Dictionary:
	return (AUTHORED_UNLOCK_TARGET_PRESENTATION.get(source_kind, {"en": "the clue", "ko": "단서"}) as Dictionary).duplicate(true)


func authored_npc_portrait_presentation(source_ref: String, expression_id: String) -> Dictionary:
	var npc: Dictionary = npcs.get(source_ref, {})
	if npc.is_empty():
		return {}
	var expression := expression_id.to_lower().strip_edges()
	if expression.is_empty():
		expression = "neutral"
	var expressions_value: Variant = npc.get("expressions", {})
	if not expressions_value is Dictionary:
		return {}
	var asset_path := String((expressions_value as Dictionary).get(expression, ""))
	if asset_path.is_empty() or not asset_path.begins_with("res://assets/portraits/") or not FileAccess.file_exists(asset_path):
		return {}
	# Campaign NPC art predates the face-legibility contract. Never surface an
	# old dot-eye portrait merely because the registry path exists: an approved
	# mapping must advertise the same sclera/iris/pupil/highlight system used by
	# the current portrait roster. Missing or legacy mappings intentionally fall
	# back to the generic NPC icon without inventing a new character.
	var svg_source := FileAccess.get_file_as_string(asset_path)
	if not svg_source.contains("data-eye-system=\"sclera-iris-pupil-highlight\"") \
			or not svg_source.contains("data-part=\"sclera\"") \
			or not svg_source.contains("data-part=\"iris\"") \
			or not svg_source.contains("data-part=\"pupil\"") \
			or not svg_source.contains("data-part=\"highlight\""):
		return {}
	var display_name := String(npc.get("displayName", "")).strip_edges()
	return {
		"asset_path": asset_path,
		"accessibility_name": {"en": display_name, "ko": display_name},
		"expression": expression
	}


func authored_evidence_presentation(
		source_kind: String,
		source_ref: String,
		runtime_ref_id: String,
		authored_label: Variant,
		unlock_value: Variant,
		citation: Dictionary,
		short_observation: Variant,
		npc_expression: String = ""
) -> Dictionary:
	var unlock: Dictionary = unlock_value if unlock_value is Dictionary else {}
	var action_id := String(unlock.get("action", "inspect"))
	var target_id := String(unlock.get("target", ""))
	var citation_id := String(citation.get("id", ""))
	var forbidden := [source_ref, runtime_ref_id, action_id, target_id, citation_id]
	var kind_fallback := authored_source_kind_presentation(source_kind)
	var display_name := authored_safe_localized(authored_label, kind_fallback, forbidden)
	var action_label := authored_safe_localized(
		unlock.get("action_label", {}),
		authored_unlock_action_presentation(action_id),
		forbidden
	)
	var target_label := authored_safe_localized(
		unlock.get("target_label", {}),
		authored_unlock_target_presentation(source_kind),
		forbidden
	)
	var observation := authored_safe_localized(short_observation, display_name, forbidden)
	var locator: Dictionary = {}
	if citation.has("locator"):
		var sanitized_locator := authored_safe_localized(citation.get("locator", {}), {"en": "", "ko": ""}, forbidden)
		if not String(sanitized_locator.get("en", "")).is_empty() and not String(sanitized_locator.get("ko", "")).is_empty():
			locator = sanitized_locator
	var portrait := authored_npc_portrait_presentation(runtime_ref_id, npc_expression) if source_kind == "NPC" else {}
	return {
		"source_display_name": display_name,
		"unlock_action_label": action_label,
		"unlock_target_label": target_label,
		"short_observation": observation,
		"citation_locator": locator,
		"npc_portrait": portrait
	}


func ensure_normalized_authored_presentation(definition: Dictionary) -> Dictionary:
	var normalized: Dictionary = definition.duplicate(true)
	var spec_id := String(normalized.get("artifact_spec_id", ""))
	var spec_display := String(specs.get(spec_id, {}).get("displayName", "Artifact"))
	var case_forbidden := [spec_id, normalized.get("case_id", "")]
	var artifact_name := authored_safe_localized(
		normalized.get("artifact_display_name", {}),
		{"en": spec_display, "ko": spec_display},
		case_forbidden
	)
	normalized["artifact_display_name"] = artifact_name
	normalized["presentation"] = {"artifact_display_name": artifact_name.duplicate(true)}
	var normalized_evidence: Array = []
	for evidence_value: Variant in normalized.get("evidence", []):
		if not evidence_value is Dictionary:
			normalized_evidence.append(evidence_value)
			continue
		var evidence: Dictionary = (evidence_value as Dictionary).duplicate(true)
		var source: Dictionary = evidence.get("source", {})
		var source_kind := String(source.get("kind", ""))
		var source_ref := String(evidence.get("id", ""))
		var runtime_ref_id := String(source.get("ref_id", ""))
		var citation: Dictionary = evidence.get("citation", {})
		var unlock: Dictionary = {
			"action": evidence.get("discover_action_id", "inspect"),
			"target": ""
		}
		var existing_presentation_value: Variant = evidence.get("presentation", {})
		if existing_presentation_value is Dictionary:
			var existing_presentation: Dictionary = existing_presentation_value
			unlock["action_label"] = existing_presentation.get("unlock_action_label", {})
			unlock["target_label"] = existing_presentation.get("unlock_target_label", {})
		var presentation := authored_evidence_presentation(
			source_kind,
			source_ref,
			runtime_ref_id,
			citation.get("label", {}),
			unlock,
			{"id": citation.get("id", ""), "locator": existing_presentation_value.get("citation_locator", {}) if existing_presentation_value is Dictionary else {}},
			existing_presentation_value.get("short_observation", {}) if existing_presentation_value is Dictionary else {},
			String((existing_presentation_value as Dictionary).get("npc_portrait", {}).get("expression", "")) if existing_presentation_value is Dictionary else ""
		)
		evidence["presentation"] = presentation
		normalized_evidence.append(evidence)
	normalized["evidence"] = normalized_evidence
	return normalized


func normalize_authored_case_v2(raw: Dictionary) -> Dictionary:
	if raw.has("evidence") and raw.has("canonical_hypothesis_id"):
		var normalized: Dictionary = raw.duplicate(true)
		var normalized_resolution_value: Variant = normalized.get("resolution", {})
		if normalized_resolution_value is Dictionary:
			var normalized_resolution: Dictionary = normalized_resolution_value
			normalized_resolution["outcome_rules"] = normalize_authored_outcome_rules(normalized_resolution.get("outcome_rules", []))
			normalized["resolution"] = normalized_resolution
		return ensure_normalized_authored_presentation(normalized)
	var citations_by_source := {}
	for citation: Dictionary in raw.get("citations", []):
		citations_by_source[citation.get("source_ref", "")] = citation
	var links_by_source := {}
	for link: Dictionary in raw.get("evidence_links", []):
		var source_ref: String = link.get("source_ref", "")
		if not links_by_source.has(source_ref):
			links_by_source[source_ref] = []
		links_by_source[source_ref].append({
			"hypothesis_id": link.get("hypothesis_id", ""),
			"stance": link.get("relation", ""),
			"strength": 2 if float(link.get("weight", 0.0)) >= 0.75 else 1
		})
	var evidence_rows: Array = []
	for authored_source: Dictionary in raw.get("sources", []):
		var source_ref: String = authored_source.get("source_ref", "")
		var source_kind: String = {
			"ARTIFACT_OBSERVATION": "ARTIFACT",
			"DOCUMENT": "DOCUMENT",
			"NPC_STATEMENT": "NPC",
			"REFERENCE": "REFERENCE"
		}.get(authored_source.get("kind", ""), authored_source.get("kind", ""))
		var raw_requirements: Array = authored_source.get("unlock", {}).get("requires", [])
		var evidence_requirements: Array = []
		var tool_requirements: Array = []
		for requirement_value: Variant in raw_requirements:
			var requirement := String(requirement_value)
			if requirement.begins_with("src."):
				evidence_requirements.append(requirement)
			else:
				tool_requirements.append(requirement)
		var authored_risk: Dictionary = authored_source.get("risk", {})
		var citation: Dictionary = citations_by_source.get(source_ref, {})
		var runtime_ref_id := String(authored_source.get("runtime_ref_id", authored_source.get("document_id", authored_source.get("npc_id", authored_source.get("reference_id", raw.get("artifact", {}).get("spec_id", ""))))))
		var presentation := authored_evidence_presentation(
			source_kind,
			source_ref,
			runtime_ref_id,
			authored_source.get("label", {}),
			authored_source.get("unlock", {}),
			citation,
			authored_source.get("short_observation", {}),
			String(authored_source.get("expression", ""))
		)
		evidence_rows.append({
			"id": source_ref,
			"source": {
				"kind": source_kind,
				"ref_id": runtime_ref_id,
				"entry_id": source_ref
			},
			"text": authored_source.get("text", source_ref),
			"public_clue_id": String(authored_source.get("public_clue_id", "")).to_upper(),
			"discover_action_id": authored_source.get("unlock", {}).get("action", "inspect"),
			"unlock": {"requires_all": evidence_requirements, "requires_tools": tool_requirements},
			"risk": {
				"level": "HIGH" if not authored_risk.get("destroyed_by", []).is_empty() else ("LOW" if not authored_risk.get("player_warning", {}).is_empty() else "NONE"),
				"warning": authored_risk.get("player_warning", {"en": "", "ko": ""})
			},
			"reliability": authored_source.get("reliability", "UNSPECIFIED"),
			"independence_key": authored_source.get("independence", {}).get("group", source_ref),
			"relations": links_by_source.get(source_ref, []).duplicate(true),
			"citation": {"allowed": true, "id": authored_source.get("citation_id", ""), "label": citation.get("label", authored_source.get("label", {}))},
			"presentation": presentation
		})
	var resolution_raw: Dictionary = raw.get("resolution", {})
	var spec_id := String(raw.get("artifact", {}).get("spec_id", ""))
	var spec_display := String(specs.get(spec_id, {}).get("displayName", "Artifact"))
	var artifact_display_name := authored_safe_localized(
		raw.get("artifact", {}).get("display_name", {}),
		{"en": spec_display, "ko": spec_display},
		[spec_id, raw.get("case_id", "")]
	)
	return {
		"schema_version": int(raw.get("schema_version", 0)),
		"case_id": raw.get("case_id", ""),
		"title": raw.get("title", raw.get("case_id", "")),
		"artifact_spec_id": spec_id,
		"artifact_display_name": artifact_display_name,
		"presentation": {"artifact_display_name": artifact_display_name.duplicate(true)},
		"briefing": raw.get("briefing", {}),
		"central_question": raw.get("central_question", {}),
		"fiction_notice": raw.get("fiction_notice", {}),
		"success": raw.get("success", {"en": "The evidence-backed report is accepted into the case record.", "ko": "증거에 근거한 보고서가 사건 기록에 등록되었다."}),
		"failure": raw.get("failure", raw.get("risk", {}).get("wrong_conclusion", {}).get("warning", {})),
		"hypotheses": raw.get("hypotheses", []).duplicate(true),
		"canonical_hypothesis_id": resolution_raw.get("winning_hypothesis_id", raw.get("artifact", {}).get("authoring_truth_hypothesis_id", "")),
		"evidence": evidence_rows,
		"resolution": {
			"strong_min_independent_support": int(resolution_raw.get("minimum_independent_groups", 2)),
			"strong_min_net_score": int(resolution_raw.get("minimum_independent_groups", 2)),
			"strong_min_citations": int(resolution_raw.get("minimum_citations", 2)),
			"required_source_refs": resolution_raw.get("required_source_refs", []).duplicate(),
			"plausible_min_independent_support": 2,
			"plausible_min_net_score": 1,
			"plausible_min_citations": 2,
			"report_prompt": resolution_raw.get("report_prompt", {}),
			"outcome_rules": normalize_authored_outcome_rules(resolution_raw.get("outcome_rules", []))
		}
	}


func validate_authored_case_v2(definition: Dictionary) -> Dictionary:
	if int(definition.get("schema_version", 0)) != 2:
		return {"ok": false, "code": "SCHEMA_VERSION"}
	var case_id: String = definition.get("case_id", "")
	if case_id.is_empty() or not campaign_cases.has(case_id):
		return {"ok": false, "code": "UNKNOWN_CAMPAIGN_CASE"}
	var case_presentation_value: Variant = definition.get("presentation", {})
	if not case_presentation_value is Dictionary \
			or not authored_localized_presentation_valid((case_presentation_value as Dictionary).get("artifact_display_name", {})):
		return {"ok": false, "code": "INVALID_CASE_PRESENTATION"}
	var hypotheses: Array = definition.get("hypotheses", [])
	var canonical: String = definition.get("canonical_hypothesis_id", "")
	var hypothesis_ids := {}
	for hypothesis: Dictionary in hypotheses:
		var hypothesis_id: String = hypothesis.get("id", "")
		if hypothesis_id.is_empty() or hypothesis_ids.has(hypothesis_id):
			return {"ok": false, "code": "INVALID_HYPOTHESIS"}
		hypothesis_ids[hypothesis_id] = true
	if hypotheses.size() < 2 or not hypothesis_ids.has(canonical):
		return {"ok": false, "code": "INVALID_CANONICAL_HYPOTHESIS"}
	var evidence_ids := {}
	for evidence: Dictionary in definition.get("evidence", []):
		var evidence_id: String = evidence.get("id", "")
		if evidence_id.is_empty() or evidence_ids.has(evidence_id):
			return {"ok": false, "code": "INVALID_EVIDENCE_ID"}
		evidence_ids[evidence_id] = true
		var source: Dictionary = evidence.get("source", {})
		var source_kind: String = source.get("kind", "")
		var source_ref: String = source.get("ref_id", "")
		if not source_kind in ["ARTIFACT", "DOCUMENT", "NPC", "REFERENCE"] or source_ref.is_empty():
			return {"ok": false, "code": "INVALID_EVIDENCE_SOURCE"}
		if source_kind == "ARTIFACT" and not specs.has(source_ref):
			return {"ok": false, "code": "MISSING_ARTIFACT_SOURCE"}
		if source_kind == "DOCUMENT" and not documents.has(source_ref):
			return {"ok": false, "code": "MISSING_DOCUMENT_SOURCE"}
		if source_kind == "NPC" and not npcs.has(source_ref):
			return {"ok": false, "code": "MISSING_NPC_SOURCE"}
		if source_kind == "REFERENCE" and not reference_entry_exists(source_ref, source.get("entry_id", "")):
			return {"ok": false, "code": "MISSING_REFERENCE_SOURCE"}
		var presentation_value: Variant = evidence.get("presentation", {})
		if not presentation_value is Dictionary:
			return {"ok": false, "code": "INVALID_EVIDENCE_PRESENTATION"}
		var presentation: Dictionary = presentation_value
		for localized_key: String in ["source_display_name", "unlock_action_label", "unlock_target_label", "short_observation"]:
			if not authored_localized_presentation_valid(presentation.get(localized_key, {})):
				return {"ok": false, "code": "INVALID_EVIDENCE_PRESENTATION"}
		var locator_value: Variant = presentation.get("citation_locator", {})
		if not locator_value is Dictionary \
				or (not (locator_value as Dictionary).is_empty() and not authored_localized_presentation_valid(locator_value)):
			return {"ok": false, "code": "INVALID_EVIDENCE_PRESENTATION"}
		var portrait_value: Variant = presentation.get("npc_portrait", {})
		if not portrait_value is Dictionary:
			return {"ok": false, "code": "INVALID_EVIDENCE_PRESENTATION"}
		var portrait: Dictionary = portrait_value
		if not portrait.is_empty():
			var expected_portrait := authored_npc_portrait_presentation(source_ref, String(portrait.get("expression", "")))
			if source_kind != "NPC" or expected_portrait.is_empty() \
					or String(portrait.get("asset_path", "")) != String(expected_portrait.get("asset_path", "")):
				return {"ok": false, "code": "INVALID_NPC_PRESENTATION"}
		if String(evidence.get("independence_key", "")).is_empty():
			return {"ok": false, "code": "MISSING_INDEPENDENCE_KEY"}
		var public_clue_id := String(evidence.get("public_clue_id", "")).to_upper()
		if not public_clue_id.is_empty() and public_clue_id != "PROVENANCE":
			return {"ok": false, "code": "INVALID_PUBLIC_CLUE_ID"}
		for relation: Dictionary in evidence.get("relations", []):
			if not hypothesis_ids.has(relation.get("hypothesis_id", "")):
				return {"ok": false, "code": "UNKNOWN_RELATION_HYPOTHESIS"}
			if not relation.get("stance", "") in ["SUPPORT", "REFUTE"] or int(relation.get("strength", 0)) not in [1, 2]:
				return {"ok": false, "code": "INVALID_RELATION"}
	for evidence: Dictionary in definition.get("evidence", []):
		for requirement: String in evidence.get("unlock", {}).get("requires_all", []):
			if not evidence_ids.has(requirement) or requirement == evidence.get("id", ""):
				return {"ok": false, "code": "INVALID_EVIDENCE_REQUIREMENT"}
	var resolution_value: Variant = definition.get("resolution", {})
	if not resolution_value is Dictionary:
		return {"ok": false, "code": "INVALID_RESOLUTION"}
	var outcome_rules_value: Variant = (resolution_value as Dictionary).get("outcome_rules", [])
	if not outcome_rules_value is Array:
		return {"ok": false, "code": "INVALID_OUTCOME_RULES"}
	var outcome_rules: Array = outcome_rules_value
	if not outcome_rules.is_empty():
		var independence_keys: Dictionary = {}
		for evidence: Dictionary in definition.get("evidence", []):
			independence_keys[String(evidence.get("independence_key", ""))] = true
		var seen_outcomes: Dictionary = {}
		var previous_order := -1
		var fallback_count := 0
		for rule_index: int in range(outcome_rules.size()):
			var rule_value: Variant = outcome_rules[rule_index]
			if not rule_value is Dictionary:
				return {"ok": false, "code": "INVALID_OUTCOME_RULE"}
			var rule: Dictionary = rule_value
			var outcome_id := String(rule.get("outcome_id", ""))
			var correctness := String(rule.get("correctness", ""))
			if not AUTHORED_OUTCOME_ORDER.has(outcome_id) or seen_outcomes.has(outcome_id):
				return {"ok": false, "code": "INVALID_OUTCOME_RULE_ORDER"}
			var current_order := int(AUTHORED_OUTCOME_ORDER[outcome_id])
			if current_order < previous_order or not correctness in AUTHORED_RULE_CORRECTNESS:
				return {"ok": false, "code": "INVALID_OUTCOME_RULE_ORDER"}
			previous_order = current_order
			seen_outcomes[outcome_id] = true
			if not rule.get("requires_all_required_sources", false) is bool or not rule.get("fallback", false) is bool:
				return {"ok": false, "code": "INVALID_OUTCOME_RULE"}
			for threshold_key: String in ["minimum_independent_groups", "minimum_citations", "minimum_net_support"]:
				var threshold: Variant = rule.get(threshold_key, null)
				if not threshold is int or int(threshold) < 0:
					return {"ok": false, "code": "INVALID_OUTCOME_RULE_THRESHOLD"}
			if int(rule.get("minimum_independent_groups", 0)) > independence_keys.size() \
					or int(rule.get("minimum_citations", 0)) > evidence_ids.size() \
					or int(rule.get("minimum_net_support", 0)) > evidence_ids.size() * 2:
				return {"ok": false, "code": "INVALID_OUTCOME_RULE_THRESHOLD"}
			var fallback := bool(rule.get("fallback", false))
			if fallback:
				fallback_count += 1
				if rule_index != outcome_rules.size() - 1 or outcome_id != "reviewed_with_mentor" \
						or correctness != "ANY" or bool(rule.get("requires_all_required_sources", false)) \
						or int(rule.get("minimum_independent_groups", 0)) != 0 \
						or int(rule.get("minimum_citations", 0)) != 0 \
						or int(rule.get("minimum_net_support", 0)) != 0:
					return {"ok": false, "code": "INVALID_OUTCOME_RULE_FALLBACK"}
			elif (outcome_id in ["masterful", "credible"] and correctness != "CORRECT") \
					or (outcome_id == "mistaken" and correctness != "INCORRECT") \
					or outcome_id == "reviewed_with_mentor":
				return {"ok": false, "code": "INVALID_OUTCOME_RULE_CORRECTNESS"}
		if fallback_count != 1:
			return {"ok": false, "code": "INVALID_OUTCOME_RULE_FALLBACK"}
	return {"ok": true, "code": "OK"}


func reference_entry_exists(ref_id: String, entry_id: String = "") -> bool:
	for collection_key: String in ["makerModelHistories", "materialConstructionNotes", "periodReferences"]:
		for entry: Dictionary in reference_database.get(collection_key, []):
			if entry.get("id", "") == ref_id or (not entry_id.is_empty() and entry.get("id", "") == entry_id):
				return true
	return false


func get_spec(spec_ref: Variant) -> Dictionary:
	if spec_ref is String:
		return specs.get(spec_ref, {})
	var index := int(spec_ref)
	if index < 0 or index >= spec_order.size():
		return {}
	return specs.get(spec_order[index], {})


func get_stage_definition(stage_id: int) -> Dictionary:
	return stage_definitions.get(stage_id, {})


func stage_difficulty_multiplier(stage_id: int) -> float:
	if stage_id < 1 or stage_id > 10:
		return 1.0
	# Use the single canonical formula even when an authored JSON number was
	# rounded for readability.
	return pow(1.07, stage_id - 1)


func available_spec_ids_for_stage(stage_id: int) -> Array:
	if stage_definitions.is_empty():
		return spec_order.duplicate()
	var available: Array = baseline_spec_ids.duplicate()
	for spec_id_value: Variant in expansion_spec_ids:
		var spec_id := String(spec_id_value)
		if int(artifact_unlock_stage.get(spec_id, 11)) <= clampi(stage_id, 1, 10):
			available.append(spec_id)
	return available


func resolve_model(spec_id: String) -> Resource:
	var path: String = runtime_model_paths.get(spec_id, "")
	return load(path) if not path.is_empty() else null


func get_visual_variant(spec_id: String) -> Dictionary:
	var spec := get_spec(spec_id)
	return visual_variants.get(spec.get("visualVariant", ""), {})


func normalized_artifact_render_recipe(value: Variant) -> String:
	var recipe := String(value).strip_edges().to_upper()
	return "DEFAULT" if recipe.is_empty() else recipe


func story_artifact_render_pair_key(story_artifact_id: String, spec_id: String) -> String:
	return "%s|%s" % [story_artifact_id.strip_edges(), spec_id.strip_edges()]


func get_story_artifact_render_override(story_artifact_id: String, spec_id: String) -> Dictionary:
	if story_artifact_id.is_empty() or spec_id.is_empty():
		return {}
	var pair_key := story_artifact_render_pair_key(story_artifact_id, spec_id)
	var override_value: Variant = STORY_ARTIFACT_RENDER_OVERRIDES.get(pair_key, {})
	return override_value.duplicate(true) if override_value is Dictionary else {}


func validate_story_artifact_render_overrides() -> void:
	for pair_key_value: Variant in STORY_ARTIFACT_RENDER_OVERRIDES.keys():
		var pair_key := String(pair_key_value)
		var pair_parts := pair_key.split("|", false)
		if pair_parts.size() != 2:
			stage_definition_errors.append("INVALID_STORY_RENDER_PAIR:%s" % pair_key)
			continue
		var story_artifact_id := String(pair_parts[0])
		var spec_id := String(pair_parts[1])
		var override_value: Variant = STORY_ARTIFACT_RENDER_OVERRIDES.get(pair_key, {})
		var override_data: Dictionary = override_value if override_value is Dictionary else {}
		var recipe := normalized_artifact_render_recipe(override_data.get("recipe", ""))
		var mesh_path := String(override_data.get("meshPath", ""))
		if not story_artifacts.has(story_artifact_id):
			stage_definition_errors.append("UNKNOWN_STORY_RENDER_ARTIFACT:%s" % pair_key)
			continue
		if not specs.has(spec_id):
			stage_definition_errors.append("UNKNOWN_STORY_RENDER_SPEC:%s" % pair_key)
		if not ARTIFACT_RENDER_RECIPES.has(recipe) or recipe == "DEFAULT":
			stage_definition_errors.append("INVALID_STORY_RENDER_RECIPE:%s:%s" % [pair_key, recipe])
		if mesh_path.is_empty() or not FileAccess.file_exists(mesh_path):
			stage_definition_errors.append("MISSING_STORY_RENDER_MESH:%s:%s" % [pair_key, mesh_path])
		var story_artifact: Dictionary = story_artifacts.get(story_artifact_id, {})
		if String(story_artifact.get("baseSpecId", "")) != spec_id:
			stage_definition_errors.append("STORY_RENDER_BASE_SPEC_MISMATCH:%s" % pair_key)
		var case_id := String(story_artifact.get("caseId", ""))
		var story_case: Dictionary = campaign_cases.get(case_id, {})
		if String(story_case.get("storyArtifactId", "")) != story_artifact_id or String(story_case.get("rewardSpecId", "")) != spec_id:
			stage_definition_errors.append("STORY_RENDER_CAMPAIGN_BINDING_MISMATCH:%s" % pair_key)


func get_artifact_render_dto(spec_id: String, story_artifact_id: String = "") -> Dictionary:
	var spec := get_spec(spec_id)
	var variant := get_visual_variant(spec_id)
	if spec.is_empty() or variant.is_empty():
		return {}
	var recipe := normalized_artifact_render_recipe(variant.get("renderRecipe", "DEFAULT"))
	if not ARTIFACT_RENDER_RECIPES.has(recipe):
		push_error("Unknown artifact render recipe for %s: %s" % [spec_id, recipe])
		return {}
	var scale_value: Variant = variant.get("scale", [1.0, 1.0, 1.0])
	var scale_values: Array = scale_value.duplicate(true) if scale_value is Array else []
	if scale_values.size() != 3:
		push_error("Invalid artifact render scale for %s" % spec_id)
		return {}
	var palette_value: Variant = variant.get("palette", {})
	var palette_source: Dictionary = palette_value if palette_value is Dictionary else {}
	var trim_value: Variant = variant.get("trim", {})
	var trim_source: Dictionary = trim_value if trim_value is Dictionary else {}
	var detail_value: Variant = variant.get("detail", {})
	var detail_source: Dictionary = detail_value if detail_value is Dictionary else {}
	var dto := {
		"specId": spec_id,
		"meshPath": String(runtime_model_paths.get(spec_id, "")),
		"scale": [float(scale_values[0]), float(scale_values[1]), float(scale_values[2])],
		"materialPath": String(variant.get("materialPath", "")),
		"palette": {
			"primary": String(palette_source.get("primary", variant.get("primaryColor", "#b8893f"))),
			"secondary": String(palette_source.get("secondary", variant.get("trimColor", "#705038"))),
			"accent": String(palette_source.get("accent", variant.get("trimColor", "#d0a14d")))
		},
		"metallic": float(variant.get("metallic", 0.2)),
		"roughness": float(variant.get("roughness", 0.55)),
		"trim": {
			"shape": String(trim_source.get("shape", variant.get("trimShape", "band"))),
			"color": String(trim_source.get("color", variant.get("trimColor", "#d0a14d"))),
			"materialPath": String(trim_source.get("materialPath", ""))
		},
		"detail": {
			"motif": String(detail_source.get("motif", "")),
			"placement": String(detail_source.get("placement", "")),
			"wearMask": String(detail_source.get("wearMask", ""))
		},
		"recipe": recipe
	}
	var pair_override := get_story_artifact_render_override(story_artifact_id, spec_id)
	if not pair_override.is_empty():
		var override_recipe := normalized_artifact_render_recipe(pair_override.get("recipe", ""))
		var override_mesh_path := String(pair_override.get("meshPath", ""))
		if not ARTIFACT_RENDER_RECIPES.has(override_recipe) or override_recipe == "DEFAULT" or override_mesh_path.is_empty() or not FileAccess.file_exists(override_mesh_path):
			push_error("Invalid required story artifact render override for %s" % story_artifact_render_pair_key(story_artifact_id, spec_id))
			return {}
		dto["recipe"] = override_recipe
		dto["meshPath"] = override_mesh_path
	return dto.duplicate(true)


func get_artifact_instance_render_dto(artifact: Dictionary) -> Dictionary:
	var spec_id := String(artifact.get("artifactSpecId", ""))
	var story_artifact_id := String(artifact.get("storyArtifactId", ""))
	return get_artifact_render_dto(spec_id, story_artifact_id)


func visual_signature(spec_id: String) -> String:
	var spec := get_spec(spec_id)
	var variant := get_visual_variant(spec_id)
	return "%s|%s|%s" % [spec.get("baseModel", ""), spec.get("visualVariant", ""), variant.get("signature", "")]


func supported_operations(spec_id: String) -> Dictionary:
	var spec := get_spec(spec_id)
	var model_name: String = spec.get("baseModel", "")
	if model_name == "model_01.obj":
		return {"disassembly": true, "part_family": "clock", "parts": ["body", "panel", "mechanism"]}
	if model_name == "model_03.obj":
		return {"disassembly": true, "part_family": "camera", "parts": ["body", "panel", "mechanism"]}
	if model_name == "model_04.obj":
		return {"disassembly": true, "part_family": "radio", "parts": ["body", "panel", "mechanism"]}
	return {"disassembly": false, "part_family": "", "parts": []}


func get_tool(id: String) -> Dictionary:
	return tools.get(id, {})


func get_bidder(index: int) -> Dictionary:
	return bidders[index % bidders.size()] if not bidders.is_empty() else {}


func get_event(id: String) -> Dictionary:
	return event_by_id.get(id, {})


func get_upgrade(id: String) -> Dictionary:
	return upgrade_by_id.get(id, {})


func get_case(id: String) -> Dictionary:
	return campaign_cases.get(id, {})


func get_case_v2(id: String) -> Dictionary:
	return authored_cases_v2.get(id, {})


func has_authored_case_v2(id: String) -> bool:
	return authored_cases_v2.has(id)


func get_act(id: String) -> Dictionary:
	return campaign_acts.get(id, {})


func tr_key(language: String, key: String) -> String:
	return localization.get(language, {}).get(key, key)
