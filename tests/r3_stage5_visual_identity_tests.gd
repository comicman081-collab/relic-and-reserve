extends SceneTree

## Stage 5B artifact-render and authored-NPC visual identity acceptance.
##
## The suite consumes only the canonical public render DTO, uses fresh runtime
## instances for renderer checks, and runs the deliberately invalid recipe
## probe in an isolated child process so its expected engine diagnostic cannot
## be confused with a fatal diagnostic from this parent suite.

const REPORT_PATH := "res://qa/R3_STAGE5_VISUAL_IDENTITY_TESTS.json"
const EXPECTED_TEST_COUNT := 10
const TEST_SCRIPT_PATH := "res://tests/r3_stage5_visual_identity_tests.gd"
const UNKNOWN_PROBE_ARG := "--stage5b-unknown-recipe-probe"
const UNKNOWN_RECIPE := "FUTURE_PRIVATE_RECIPE"
const TOP_LEVEL_DTO_KEYS := [
	"detail", "materialPath", "meshPath", "metallic", "palette",
	"recipe", "roughness", "scale", "specId", "trim"
]
const PALETTE_DTO_KEYS := ["accent", "primary", "secondary"]
const TRIM_DTO_KEYS := ["color", "materialPath", "shape"]
const DETAIL_DTO_KEYS := ["motif", "placement", "wearMask"]
const APPROVED_RECIPES := ["ASTRONOMICAL_REGULATOR", "CHRONOMETER", "COMPOSITE", "DEFAULT", "GAUGE", "MICROSCOPE", "MUSIC_BOX", "OPTIC", "SEXTANT", "SIGNAL_LANTERN", "SPECTROSCOPE", "TYPEWRITER_CIPHER", "WIRE_RECORDER"]
const PRIVATE_RENDER_TOKENS := [
	"authenticity", "auction", "basevalue", "bidder", "conditionsensitivity",
	"damages", "disclosurescrutiny", "economy", "fault", "hidden", "money",
	"possibleclues", "price", "provenancescrutiny", "rarity", "reserve",
	"truehistorical", "truemarket", "truerarity", "truth"
]
const PORTRAIT_FIXTURES := [
	{
		"case_id": "collector_promise",
		"npc_id": "victor_hale",
		"expression": "neutral",
		"path": "res://assets/portraits/victor_hale_neutral.svg"
	},
	{
		"case_id": "shadow_camera",
		"npc_id": "lena_falk",
		"expression": "concerned",
		"path": "res://assets/portraits/lena_falk_concerned.svg"
	}
]

var results: Array = []


func _init() -> void:
	if OS.get_cmdline_user_args().has(UNKNOWN_PROBE_ARG):
		call_deferred("run_unknown_recipe_probe")
	else:
		call_deferred("run")


func record(test_id: String, name: String, passed: bool, evidence: Variant) -> void:
	results.append({
		"id": test_id,
		"name": name,
		"executed": true,
		"passed": passed,
		"evidence": evidence
	})


func sorted_string_keys(value: Dictionary) -> Array:
	var output: Array = []
	for key_value: Variant in value.keys():
		output.append(String(key_value))
	output.sort()
	return output


func exact_dto_shape(dto: Dictionary) -> bool:
	return sorted_string_keys(dto) == TOP_LEVEL_DTO_KEYS \
		and dto.get("palette", null) is Dictionary \
		and sorted_string_keys(dto.get("palette", {})) == PALETTE_DTO_KEYS \
		and dto.get("trim", null) is Dictionary \
		and sorted_string_keys(dto.get("trim", {})) == TRIM_DTO_KEYS \
		and dto.get("detail", null) is Dictionary \
		and sorted_string_keys(dto.get("detail", {})) == DETAIL_DTO_KEYS \
		and dto.get("scale", null) is Array \
		and dto.get("scale", []).size() == 3


func private_render_tokens(dto: Dictionary) -> Array:
	var serialized := JSON.stringify(dto).to_lower()
	var leaks: Array = []
	for token: String in PRIVATE_RENDER_TOKENS:
		var token_pattern := RegEx.new()
		token_pattern.compile("\\b%s\\b" % token)
		if token_pattern.search(serialized) != null:
			leaks.append(token)
	return leaks


func settle_ui(frame_count: int = 4) -> void:
	for _frame: int in range(frame_count):
		await process_frame


func visible_named_nodes(root: Node, pattern: String, type_name: String) -> Array:
	var visible_nodes: Array = []
	for node_value: Node in root.find_children(pattern, type_name, true, false):
		if node_value.is_inside_tree() and node_value.is_visible_in_tree():
			visible_nodes.append(node_value)
	return visible_nodes


func discover_all_case_evidence(gs: Node, case_id: String) -> Array:
	var discovered: Array = []
	for _pass: int in range(20):
		var progress := false
		for evidence_value: Variant in gs.get_case_public_state(case_id).get("evidence", []):
			if not evidence_value is Dictionary:
				continue
			var evidence: Dictionary = evidence_value
			if bool(evidence.get("discovered", false)) or not bool(evidence.get("unlocked", false)):
				continue
			var required_tools: Array = evidence.get("requiredTools", [])
			if not required_tools.is_empty():
				gs.selected_tool = String(required_tools[0])
			var discovery: Dictionary = gs.discover_case_evidence(case_id, String(evidence.get("id", "")))
			if bool(discovery.get("ok", false)):
				discovered.append(String(evidence.get("id", "")))
				progress = true
		if not progress:
			break
	return discovered


func actual_dossier_portrait(gs: Node, registry: Node, main: Node, fixture: Dictionary) -> Dictionary:
	gs.persistence_enabled = false
	gs.reset_game()
	gs.persistence_enabled = false
	gs.current_stage = 5
	gs.stage_run_state = gs.default_stage_run_state(5)
	gs.stage_run_state["status"] = "RUNNING"
	var story_case: Dictionary = registry.get_case(String(fixture.get("case_id", "")))
	gs.campaign_state["currentAct"] = String(story_case.get("act", ""))
	var artifact: Dictionary = gs.begin_case(String(fixture.get("case_id", "")))
	var discovered := discover_all_case_evidence(gs, String(fixture.get("case_id", "")))
	var npc_row: Dictionary = {}
	for evidence_value: Variant in gs.get_case_public_state(String(fixture.get("case_id", ""))).get("evidence", []):
		if evidence_value is Dictionary \
				and String(evidence_value.get("sourceKind", "")) == "NPC" \
				and String(evidence_value.get("npcPortrait", {}).get("asset_path", "")) == String(fixture.get("path", "")):
			npc_row = evidence_value
			break
	if not artifact.is_empty():
		main.selected = artifact
		main.load_artifact(artifact)
	main.language = "en"
	main.case_dossier_case_id = String(fixture.get("case_id", ""))
	main.case_detail_evidence_id = String(npc_row.get("id", ""))
	main.show_case_dossier(String(fixture.get("case_id", "")))
	await settle_ui()
	var portrait_nodes := visible_named_nodes(main, "CaseNpcSourcePortrait", "TextureRect")
	var portrait: TextureRect = portrait_nodes[0] if portrait_nodes.size() == 1 else null
	return {
		"case": fixture.get("case_id", ""),
		"artifactCreated": not artifact.is_empty(),
		"discoveredCount": discovered.size(),
		"npcRow": not npc_row.is_empty(),
		"npcPath": npc_row.get("npcPortrait", {}).get("asset_path", ""),
		"portraitCount": portrait_nodes.size(),
		"minimumSize": [portrait.custom_minimum_size.x, portrait.custom_minimum_size.y] if portrait != null else [],
		"hasTexture": portrait != null and portrait.texture != null,
		"passed": not artifact.is_empty() and not npc_row.is_empty() \
			and portrait != null and portrait.texture != null \
			and portrait.custom_minimum_size == Vector2(96, 120)
	}


func finish(gs: Node, main: Node) -> void:
	var passed: int = results.filter(func(row: Dictionary): return bool(row.get("passed", false))).size()
	var report := {
		"suite": "R3 Stage 5B Visual Identity",
		"executed": results.size(),
		"passed": passed,
		"failed": results.size() - passed,
		"skipped": 0,
		"expectedCount": EXPECTED_TEST_COUNT,
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


func run_unknown_recipe_probe() -> void:
	var registry: Node = get_root().get_node("RuntimeRegistry")
	var spec: Dictionary = registry.get_spec("artifact_069")
	var variant_id := String(spec.get("visualVariant", ""))
	var original_variant: Dictionary = registry.visual_variants.get(variant_id, {}).duplicate(true)
	var hostile_variant := original_variant.duplicate(true)
	hostile_variant["renderRecipe"] = UNKNOWN_RECIPE
	registry.visual_variants[variant_id] = hostile_variant
	var normalized: String = registry.normalized_artifact_render_recipe(UNKNOWN_RECIPE)
	var dto: Dictionary = registry.get_artifact_render_dto("artifact_069")
	registry.visual_variants[variant_id] = original_variant
	var probe := {
		"empty": dto.is_empty(),
		"normalized": normalized,
		"silentDefault": normalized == "DEFAULT",
		"allowlisted": registry.ARTIFACT_RENDER_RECIPES.has(normalized)
	}
	print("STAGE5B_UNKNOWN_RECIPE_PROBE=" + JSON.stringify(probe))
	quit(0 if bool(probe.empty) and not bool(probe.silentDefault) and not bool(probe.allowlisted) else 1)


func run() -> void:
	var registry: Node = get_root().get_node("RuntimeRegistry")
	var gs: Node = get_root().get_node("GameState")
	gs.persistence_enabled = false
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await settle_ui()

	var dto_failures: Array = []
	for spec_id_value: Variant in registry.spec_order:
		var spec_id := String(spec_id_value)
		var dto: Dictionary = registry.get_artifact_render_dto(spec_id)
		if not exact_dto_shape(dto):
			dto_failures.append({"spec": spec_id, "keys": sorted_string_keys(dto)})
	record(
		"S5B-RENDER-DTO-SHAPE-01",
		"All eighty ArtifactSpecs expose the exact canonical public render DTO whitelist",
		registry.spec_order.size() == 80 and dto_failures.is_empty(),
		{"catalogSize": registry.spec_order.size(), "failures": dto_failures, "topKeys": TOP_LEVEL_DTO_KEYS}
	)

	var pristine_dto: Dictionary = registry.get_artifact_render_dto("artifact_069")
	var expected_dto := pristine_dto.duplicate(true)
	var registry_before := JSON.stringify({
		"variants": registry.visual_variants,
		"specs": registry.specs,
		"paths": registry.runtime_model_paths
	})
	pristine_dto["specId"] = "mutated_private_spec"
	pristine_dto["palette"]["primary"] = "#000000"
	pristine_dto["trim"]["shape"] = "silent_generic_band"
	pristine_dto["detail"]["motif"] = "hidden_truth"
	pristine_dto["scale"][0] = 999.0
	var dto_after_mutation: Dictionary = registry.get_artifact_render_dto("artifact_069")
	var registry_after := JSON.stringify({
		"variants": registry.visual_variants,
		"specs": registry.specs,
		"paths": registry.runtime_model_paths
	})
	record(
		"S5B-RENDER-DTO-COPY-02",
		"Returned render DTOs are deep copies whose nested mutation cannot alter a later DTO or raw registries",
		dto_after_mutation == expected_dto and registry_after == registry_before,
		{"freshDtoRestored": dto_after_mutation == expected_dto, "rawRegistryMutation": registry_after != registry_before}
	)

	var privacy_failures: Array = []
	for spec_id_value: Variant in registry.spec_order:
		var spec_id := String(spec_id_value)
		var leaks := private_render_tokens(registry.get_artifact_render_dto(spec_id))
		if not leaks.is_empty():
			privacy_failures.append({"spec": spec_id, "tokens": leaks})
	record(
		"S5B-RENDER-DTO-PRIVACY-03",
		"The render DTO surface contains no private truth, bidder, auction, reserve, price, rarity, clue or fault token",
		privacy_failures.is_empty(),
		{"specsChecked": registry.spec_order.size(), "failures": privacy_failures}
	)

	var recipe_counts := {"DEFAULT": 0, "TYPEWRITER_CIPHER": 0, "SEXTANT": 0}
	var recipe_failures: Array = []
	for spec_id_value: Variant in registry.spec_order:
		var spec_id := String(spec_id_value)
		var expected_recipe := "TYPEWRITER_CIPHER" if spec_id == "artifact_069" else ("SEXTANT" if spec_id == "artifact_070" else "DEFAULT")
		var actual_recipe := String(registry.get_artifact_render_dto(spec_id).get("recipe", ""))
		if recipe_counts.has(actual_recipe):
			recipe_counts[actual_recipe] = int(recipe_counts[actual_recipe]) + 1
		if actual_recipe != expected_recipe:
			recipe_failures.append({"spec": spec_id, "expected": expected_recipe, "actual": actual_recipe})
	var approved_recipes: Array = registry.ARTIFACT_RENDER_RECIPES.duplicate()
	approved_recipes.sort()
	record(
		"S5B-RENDER-RECIPE-CATALOG-04",
		"The spec-only catalog resolves to DEFAULT except the two Stage 5B recipes while the global allowlist also reserves later pair-keyed recipes",
		registry.spec_order.size() == 80 and recipe_failures.is_empty() \
			and recipe_counts == {"DEFAULT": 78, "TYPEWRITER_CIPHER": 1, "SEXTANT": 1} \
			and approved_recipes == APPROVED_RECIPES,
		{"counts": recipe_counts, "allowlist": approved_recipes, "failures": recipe_failures}
	)

	var probe_output: Array = []
	var probe_args := PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--log-file", "user://r3_stage5b_unknown_recipe_probe.log",
		"--script", TEST_SCRIPT_PATH,
		"--", UNKNOWN_PROBE_ARG
	])
	var probe_exit := OS.execute(OS.get_executable_path(), probe_args, probe_output, true, true)
	var probe_text := ""
	for output_value: Variant in probe_output:
		probe_text += String(output_value)
	var probe_rejected := probe_text.contains("\"empty\":true") \
		and probe_text.contains("\"normalized\":\"%s\"" % UNKNOWN_RECIPE) \
		and probe_text.contains("\"silentDefault\":false") \
		and probe_text.contains("\"allowlisted\":false")
	record(
		"S5B-RENDER-RECIPE-FAIL-CLOSED-05",
		"An unknown render recipe remains unknown and returns no DTO instead of silently becoming DEFAULT",
		probe_exit == 0 and probe_rejected and probe_text.contains("Unknown artifact render recipe"),
		{"childExit": probe_exit, "emptyDto": probe_text.contains("\"empty\":true"), "rejectionDiagnostic": probe_text.contains("Unknown artifact render recipe")}
	)

	var artifact_069: Dictionary = gs.new_artifact("artifact_069", 5069, "stage5b_artifact_069")
	main.load_artifact(artifact_069)
	await settle_ui(2)
	var dto_069: Dictionary = registry.get_artifact_render_dto("artifact_069")
	var cipher_keyline := visible_named_nodes(main.workpiece_root, "CipherKeyline", "MeshInstance3D")
	var cipher_keys := visible_named_nodes(main.workpiece_root, "CipherThirdRowKey_*", "MeshInstance3D")
	var cipher_glyphs := visible_named_nodes(main.workpiece_root, "CipherPairedGlyph_*", "MeshInstance3D")
	var cipher_stops := visible_named_nodes(main.workpiece_root, "CipherFiledStop_*", "MeshInstance3D")
	var cipher_generic_trim := visible_named_nodes(main.workpiece_root, "VariantTrim_*", "MeshInstance3D")
	record(
		"S5B-TYPEWRITER-CIPHER-06",
		"Artifact 069 preserves its nested cipher metadata and visibly renders the keyline, nine-key third row, paired glyphs and filed stops",
		String(dto_069.get("recipe", "")) == "TYPEWRITER_CIPHER" \
			and String(dto_069.get("meshPath", "")).ends_with("/typewriter.obj") \
			and dto_069.get("trim", {}).get("shape", "") == "cipher_keyline" \
			and dto_069.get("detail", {}) == {"motif": "paired_glyphs", "placement": "third_key_row", "wearMask": "filed_stops"} \
			and cipher_keyline.size() == 1 and cipher_keys.size() == 9 \
			and cipher_glyphs.size() == 2 and cipher_stops.size() == 2 and cipher_generic_trim.is_empty(),
		{"detail": dto_069.get("detail", {}), "keyline": cipher_keyline.size(), "thirdRowKeys": cipher_keys.size(), "pairedGlyphs": cipher_glyphs.size(), "filedStops": cipher_stops.size(), "genericTrim": cipher_generic_trim.size()}
	)

	var artifact_070: Dictionary = gs.new_artifact("artifact_070", 5070, "stage5b_artifact_070")
	main.load_artifact(artifact_070)
	await settle_ui(2)
	var dto_070: Dictionary = registry.get_artifact_render_dto("artifact_070")
	var sextant_resource: Resource = load(String(dto_070.get("meshPath", "")))
	var sextant_arcs := visible_named_nodes(main.workpiece_root, "SextantArcDegree_*", "MeshInstance3D")
	var sextant_vernier := visible_named_nodes(main.workpiece_root, "SextantDegreeVernier", "MeshInstance3D")
	var sextant_mirror := visible_named_nodes(main.workpiece_root, "SextantIndexMirror", "MeshInstance3D")
	var sextant_wear := visible_named_nodes(main.workpiece_root, "SextantThirtyDegreeWear", "MeshInstance3D")
	var sextant_generic_trim := visible_named_nodes(main.workpiece_root, "VariantTrim_*", "MeshInstance3D")
	var live_mesh_path := String(main.model.mesh.resource_path) if main.model != null and main.model.mesh != null else ""
	record(
		"S5B-SEXTANT-IDENTITY-07",
		"Artifact 070 loads the sextant mesh and visible sextant-only recipe nodes without a compass mesh or generic VariantTrim",
		String(dto_070.get("recipe", "")) == "SEXTANT" \
			and String(dto_070.get("meshPath", "")) == "res://assets/artifacts/sextant.obj" \
			and sextant_resource is Mesh and not live_mesh_path.to_lower().contains("compass") \
			and live_mesh_path.ends_with("/sextant.obj") \
			and sextant_arcs.size() == 11 and sextant_vernier.size() == 1 \
			and sextant_mirror.size() == 1 and sextant_wear.size() == 1 and sextant_generic_trim.is_empty(),
		{"dtoPath": dto_070.get("meshPath", ""), "liveMeshPath": live_mesh_path, "loadableMesh": sextant_resource is Mesh, "arcSegments": sextant_arcs.size(), "vernier": sextant_vernier.size(), "mirror": sextant_mirror.size(), "wearSector": sextant_wear.size(), "genericTrim": sextant_generic_trim.size()}
	)

	var svg_failures: Array = []
	var registry_portraits: Dictionary = {}
	for fixture_value: Variant in PORTRAIT_FIXTURES:
		var fixture: Dictionary = fixture_value
		var expected_path := String(fixture.get("path", ""))
		var presentation: Dictionary = registry.authored_npc_portrait_presentation(
			String(fixture.get("npc_id", "")),
			String(fixture.get("expression", ""))
		)
		registry_portraits[String(fixture.get("npc_id", ""))] = presentation.get("asset_path", "")
		var svg := FileAccess.get_file_as_string(expected_path)
		var markers_ok := String(presentation.get("asset_path", "")) == expected_path \
			and svg.contains("viewBox=\"0 0 256 320\"") \
			and svg.contains("data-expression-geometry-version=\"2\"") \
			and svg.contains("data-eye-system=\"sclera-iris-pupil-highlight\"") \
			and svg.contains("data-layer=\"hair\"") and svg.contains("data-layer=\"face\"") \
			and svg.contains("data-layer=\"outfit\"") and svg.contains("data-layer=\"prop\"") \
			and svg.contains("data-layer=\"expression-anchors\"") \
			and svg.contains("data-eye=\"left\"") and svg.contains("data-eye=\"right\"") \
			and svg.count("data-part=\"sclera\"") == 2 \
			and svg.count("data-part=\"iris\"") == 2 \
			and svg.count("data-part=\"pupil\"") == 2 \
			and svg.count("data-part=\"highlight\"") == 2
		if not markers_ok:
			svg_failures.append({"npc": fixture.get("npc_id", ""), "path": expected_path})
	record(
		"S5B-PORTRAIT-SVG-V2-08",
		"Victor and Lena resolve to the approved local SVG V2 busts with two complete large-eye marker systems and expression anchors",
		svg_failures.is_empty(),
		{"registryPaths": registry_portraits, "failures": svg_failures}
	)

	var dossier_results: Array = []
	for fixture_value: Variant in PORTRAIT_FIXTURES:
		dossier_results.append(await actual_dossier_portrait(gs, registry, main, fixture_value))
	var dossier_failures := dossier_results.filter(func(row: Dictionary): return not bool(row.get("passed", false)))
	record(
		"S5B-PORTRAIT-DOSSIER-09",
		"Victor and Lena each render as a textured 96 by 120 CaseNpcSourcePortrait in their actual unlocked dossier detail",
		dossier_results.size() == 2 and dossier_failures.is_empty(),
		{"cases": dossier_results, "failures": dossier_failures.size()}
	)

	var signature: Variant = registry.visual_signature("artifact_069")
	var fresh_artifact: Dictionary = gs.new_artifact("artifact_069", 9069, "stage5b_signature_contract")
	var stored_signature: Variant = fresh_artifact.get("visualSignature", null)
	record(
		"S5B-VISUAL-SIGNATURE-CONTAINMENT-10",
		"The contained legacy visual_signature contract remains String and a new artifact instance stores that same String",
		typeof(signature) == TYPE_STRING and typeof(stored_signature) == TYPE_STRING \
			and not String(signature).is_empty() and stored_signature == signature,
		{"registryType": type_string(typeof(signature)), "artifactType": type_string(typeof(stored_signature)), "equal": stored_signature == signature, "schemaChangeAttempted": false}
	)

	await finish(gs, main)
