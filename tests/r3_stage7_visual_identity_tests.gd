extends SceneTree

## Stage 7B pair-keyed artifact rendering and authored-NPC visual acceptance.
##
## Production assertions consume only get_artifact_instance_render_dto().
## Deliberately invalid required-pair recipes run in isolated child processes so
## their expected push_error diagnostics cannot contaminate this suite's exit.

const REPORT_PATH := "res://qa/R3_STAGE7_VISUAL_IDENTITY_TESTS.json"
const TEST_SCRIPT_PATH := "res://tests/r3_stage7_visual_identity_tests.gd"
const HOSTILE_REGISTRY_FIXTURE_PATH := "res://tests/r3_stage6_hostile_registry_fixture.gd"
const EXPECTED_TEST_COUNT := 12
const UNKNOWN_PAIR_PROBE_ARG := "--stage7b-required-pair-unknown-recipe-probe"
const MISSING_PAIR_PROBE_ARG := "--stage7b-required-pair-missing-recipe-probe"
const UNKNOWN_RECIPE := "FUTURE_STORY_RECIPE"
const REQUIRED_OPTIC_PAIR := "story_artifact_19|artifact_057"
const TOP_LEVEL_DTO_KEYS := [
	"detail", "materialPath", "meshPath", "metallic", "palette",
	"recipe", "roughness", "scale", "specId", "trim"
]
const PALETTE_DTO_KEYS := ["accent", "primary", "secondary"]
const TRIM_DTO_KEYS := ["color", "materialPath", "shape"]
const DETAIL_DTO_KEYS := ["motif", "placement", "wearMask"]
const APPROVED_RECIPES := ["ASTRONOMICAL_REGULATOR", "CHRONOMETER", "COMPOSITE", "DEFAULT", "GAUGE", "MICROSCOPE", "MUSIC_BOX", "OPTIC", "SEXTANT", "SIGNAL_LANTERN", "SPECTROSCOPE", "TYPEWRITER_CIPHER", "WIRE_RECORDER"]
const EXPECTED_OVERRIDE_KEYS := [
	"story_artifact_16|artifact_050",
	"story_artifact_18|artifact_035",
	"story_artifact_19|artifact_057",
	"story_artifact_20|artifact_059",
	"story_artifact_21|artifact_061",
	"story_artifact_22|artifact_075",
	"story_artifact_23|artifact_078",
	"story_artifact_24|artifact_077",
	"story_artifact_25|artifact_079",
	"story_artifact_26|artifact_080"
]
const PRIVATE_RENDER_TOKENS := [
	"authenticity", "auction", "basevalue", "bidder", "conditionsensitivity",
	"damages", "disclosurescrutiny", "economy", "fault", "hidden", "money",
	"possibleclues", "price", "provenancescrutiny", "rarity", "reserve",
	"truehistorical", "truemarket", "truerarity", "truth"
]
const INSTANCE_FIXTURES := [
	{
		"id": "freshOptic19x057",
		"artifact": {"artifactSpecId": "artifact_057", "storyArtifactId": "story_artifact_19"},
		"recipe": "OPTIC", "mesh": "res://assets/artifacts/model_12.obj"
	},
	{
		"id": "freshComposite20x059",
		"artifact": {"artifactSpecId": "artifact_059", "storyArtifactId": "story_artifact_20"},
		"recipe": "COMPOSITE", "mesh": "res://assets/artifacts/model_14.obj"
	},
	{
		"id": "legacyOptic19x051",
		"artifact": {"artifactSpecId": "artifact_051", "storyArtifactId": "story_artifact_19"},
		"recipe": "DEFAULT", "mesh": "res://assets/artifacts/model_06.obj"
	},
	{
		"id": "legacyComposite20x057",
		"artifact": {"artifactSpecId": "artifact_057", "storyArtifactId": "story_artifact_20"},
		"recipe": "DEFAULT", "mesh": "res://assets/artifacts/model_12.obj"
	},
	{
		"id": "unrelatedOpticStoryWith059",
		"artifact": {"artifactSpecId": "artifact_059", "storyArtifactId": "story_artifact_19"},
		"recipe": "DEFAULT", "mesh": "res://assets/artifacts/model_14.obj"
	},
	{
		"id": "specOnly057",
		"artifact": {"artifactSpecId": "artifact_057"},
		"recipe": "DEFAULT", "mesh": "res://assets/artifacts/model_12.obj"
	},
	{
		"id": "specOnly059",
		"artifact": {"artifactSpecId": "artifact_059"},
		"recipe": "DEFAULT", "mesh": "res://assets/artifacts/model_14.obj"
	}
]
const PORTRAIT_FIXTURES := [
	{
		"case_id": "shadow_optic", "npc_id": "victor_hale", "expression": "neutral",
		"path": "res://assets/portraits/victor_hale_neutral.svg",
		"features": ["swept-silver-hair", "camera-list", "loupe-chain"]
	},
	{
		"case_id": "composite_prototype", "npc_id": "noah_stern", "expression": "concerned",
		"path": "res://assets/portraits/noah_stern_concerned.svg",
		"features": ["chestnut-pageboy-hair", "folio-index-card", "archival-magnifier"]
	}
]

var results: Array = []


func _init() -> void:
	var user_args := OS.get_cmdline_user_args()
	if user_args.has(UNKNOWN_PAIR_PROBE_ARG):
		call_deferred("run_required_pair_probe", false)
	elif user_args.has(MISSING_PAIR_PROBE_ARG):
		call_deferred("run_required_pair_probe", true)
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
		and dto.get("scale", null) is Array and dto.get("scale", []).size() == 3


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


func named_nodes(root_node: Node, pattern: String, type_name: String = "MeshInstance3D") -> Array:
	var output: Array = []
	for node_value: Node in root_node.find_children(pattern, type_name, true, false):
		if node_value.is_inside_tree():
			output.append(node_value)
	return output


func visible_named_nodes(root_node: Node, pattern: String, type_name: String) -> Array:
	var output: Array = []
	for node_value: Node in root_node.find_children(pattern, type_name, true, false):
		if node_value.is_inside_tree() and node_value.is_visible_in_tree():
			output.append(node_value)
	return output


func forbidden_recipe_nodes(root_node: Node, active_recipe: String) -> Dictionary:
	var patterns := {
		"genericTrim": "VariantTrim_*",
		"typewriter": "Cipher*",
		"sextant": "*Compass*",
		"gauge": "Gauge*",
		"musicBox": "MusicBox*",
		"optic": "Optic*",
		"composite": "Composite*"
	}
	patterns.erase(active_recipe.to_lower())
	var counts := {}
	for label: String in patterns:
		counts[label] = named_nodes(root_node, String(patterns[label])).size()
	return counts


func all_zero(counts: Dictionary) -> bool:
	for count_value: Variant in counts.values():
		if int(count_value) != 0:
			return false
	return true


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
				gs.select_tool(String(required_tools[0]))
			var discovery: Dictionary = gs.discover_case_evidence(case_id, String(evidence.get("id", "")))
			if bool(discovery.get("ok", false)) and String(discovery.get("code", "")) == "DISCOVERED":
				discovered.append(String(evidence.get("id", "")))
				progress = true
		if not progress:
			break
	return discovered


func actual_dossier_portrait(gs: Node, registry: Node, main: Node, fixture: Dictionary) -> Dictionary:
	gs.persistence_enabled = false
	gs.reset_game()
	gs.persistence_enabled = false
	gs.current_stage = 7
	gs.stage_run_state = gs.default_stage_run_state(7)
	gs.stage_run_state["status"] = "RUNNING"
	var case_id := String(fixture.get("case_id", ""))
	var story_case: Dictionary = registry.get_case(case_id)
	gs.campaign_state["currentAct"] = String(story_case.get("act", ""))
	var artifact: Dictionary = gs.begin_case(case_id)
	var discovered := discover_all_case_evidence(gs, case_id)
	var npc_row: Dictionary = {}
	for evidence_value: Variant in gs.get_case_public_state(case_id).get("evidence", []):
		if not evidence_value is Dictionary:
			continue
		var evidence: Dictionary = evidence_value
		if String(evidence.get("sourceKind", "")) == "NPC" \
				and String(evidence.get("sourceRef", "")) == String(fixture.get("npc_id", "")) \
				and bool(evidence.get("discovered", false)):
			npc_row = evidence
			break
	if not artifact.is_empty():
		main.selected = artifact
		main.load_artifact(artifact)
	main.language = "en"
	main.case_dossier_case_id = case_id
	main.case_detail_evidence_id = String(npc_row.get("id", ""))
	main.show_case_dossier(case_id)
	await settle_ui()
	var portrait_nodes := visible_named_nodes(main, "CaseNpcSourcePortrait", "TextureRect")
	var generic_nodes := visible_named_nodes(main, "CaseSourceIcon", "TextureRect")
	var locked_nodes := visible_named_nodes(main, "CaseLockedSourceIcon", "TextureRect")
	var portrait: TextureRect = portrait_nodes[0] if portrait_nodes.size() == 1 else null
	var expected_path := String(fixture.get("path", ""))
	var npc_path := String(npc_row.get("npcPortrait", {}).get("asset_path", ""))
	var texture_path := String(portrait.texture.resource_path) if portrait != null and portrait.texture != null else ""
	return {
		"case": case_id,
		"npc": fixture.get("npc_id", ""),
		"artifactCreated": not artifact.is_empty(),
		"discoveredCount": discovered.size(),
		"npcDiscovered": not npc_row.is_empty(),
		"npcPath": npc_path,
		"texturePath": texture_path,
		"portraitCount": portrait_nodes.size(),
		"genericFallbackCount": generic_nodes.size(),
		"lockedFallbackCount": locked_nodes.size(),
		"minimumSize": [portrait.custom_minimum_size.x, portrait.custom_minimum_size.y] if portrait != null else [],
		"hasTexture": portrait != null and portrait.texture != null,
		"passed": not artifact.is_empty() and not npc_row.is_empty() and npc_path == expected_path \
			and portrait != null and portrait.texture != null and texture_path == expected_path \
			and portrait.custom_minimum_size.x >= 96.0 and portrait.custom_minimum_size.y >= 120.0 \
			and generic_nodes.is_empty() and locked_nodes.is_empty()
	}


func svg_has_two_complete_eyes(svg: String) -> bool:
	if svg.count("data-eye=\"left\"") != 1 or svg.count("data-eye=\"right\"") != 1:
		return false
	if svg.count("data-part=\"sclera\"") != 2 \
			or svg.count("data-part=\"iris\"") != 2 \
			or svg.count("data-part=\"pupil\"") != 2 \
			or svg.count("data-part=\"highlight\"") != 2:
		return false
	for eye_id: String in ["left", "right"]:
		var eye_start := svg.find("data-eye=\"%s\"" % eye_id)
		var eye_end := svg.find("</g>", eye_start)
		if eye_start < 0 or eye_end < 0:
			return false
		var eye_group := svg.substr(eye_start, eye_end - eye_start)
		for part_id: String in ["sclera", "iris", "pupil", "highlight"]:
			if not eye_group.contains("data-part=\"%s\"" % part_id):
				return false
	return true


func imported_source_md5(asset_path: String) -> String:
	var import_source := FileAccess.get_file_as_string(asset_path + ".import")
	var texture_path_matcher := RegEx.new()
	texture_path_matcher.compile("path=\"(res://[^\"]+\\.ctex)\"")
	var texture_path_match := texture_path_matcher.search(import_source)
	if texture_path_match == null:
		return ""
	var imported_texture_path := texture_path_match.get_string(1)
	var imported_md5_path := imported_texture_path.trim_suffix(".ctex") + ".md5"
	var imported_md5_source := FileAccess.get_file_as_string(imported_md5_path)
	var source_hash_matcher := RegEx.new()
	source_hash_matcher.compile("source_md5=\"([0-9a-f]+)\"")
	var source_hash_match := source_hash_matcher.search(imported_md5_source)
	return source_hash_match.get_string(1) if source_hash_match != null else ""


func image_unique_colors(image: Image, area: Rect2i, step: int = 2) -> int:
	var colors: Dictionary = {}
	var clipped := area.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	for y: int in range(clipped.position.y, clipped.end.y, step):
		for x: int in range(clipped.position.x, clipped.end.x, step):
			var color := image.get_pixel(x, y)
			if color.a > 0.05:
				colors[color.to_rgba32()] = true
	return colors.size()


func eye_pixel_evidence(image: Image, area: Rect2i) -> Dictionary:
	var white_pixels := 0
	var dark_pixels := 0
	var chromatic_pixels := 0
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var color := image.get_pixel(x, y)
			if color.a < 0.5:
				continue
			if color.r > 0.88 and color.g > 0.88 and color.b > 0.84:
				white_pixels += 1
			if color.r < 0.32 and color.g < 0.32 and color.b < 0.32:
				dark_pixels += 1
			var maximum := maxf(color.r, maxf(color.g, color.b))
			var minimum := minf(color.r, minf(color.g, color.b))
			if maximum - minimum > 0.16 and maximum > 0.25 and maximum < 0.9:
				chromatic_pixels += 1
	return {
		"white": white_pixels,
		"dark": dark_pixels,
		"chromatic": chromatic_pixels,
		"passed": white_pixels >= 80 and dark_pixels >= 24 and chromatic_pixels >= 35
	}


func imported_portrait_pixel_contract(asset_path: String) -> Dictionary:
	var current_source_md5 := FileAccess.get_md5(asset_path)
	var imported_md5 := imported_source_md5(asset_path)
	var texture: Texture2D = load(asset_path) if ResourceLoader.exists(asset_path) else null
	var image: Image = texture.get_image() if texture != null else null
	var size := image.get_size() if image != null and not image.is_empty() else Vector2i.ZERO
	var left_eye: Dictionary = eye_pixel_evidence(image, Rect2i(86, 108, 38, 38)) if size == Vector2i(256, 320) else {}
	var right_eye: Dictionary = eye_pixel_evidence(image, Rect2i(132, 108, 38, 38)) if size == Vector2i(256, 320) else {}
	var total_colors := image_unique_colors(image, Rect2i(0, 0, 256, 320)) if size == Vector2i(256, 320) else 0
	var hair_colors := image_unique_colors(image, Rect2i(58, 20, 142, 98), 1) if size == Vector2i(256, 320) else 0
	var outfit_prop_colors := image_unique_colors(image, Rect2i(35, 180, 185, 128), 1) if size == Vector2i(256, 320) else 0
	return {
		"assetPath": asset_path,
		"sourceMd5": current_source_md5,
		"importedSourceMd5": imported_md5,
		"sourceImportMatch": not current_source_md5.is_empty() and current_source_md5 == imported_md5,
		"texturePath": texture.resource_path if texture != null else "",
		"textureSize": [size.x, size.y],
		"leftEye": left_eye,
		"rightEye": right_eye,
		"uniqueColors": total_colors,
		"hairZoneColors": hair_colors,
		"outfitPropZoneColors": outfit_prop_colors,
		"passed": not current_source_md5.is_empty() and current_source_md5 == imported_md5 \
			and texture != null and String(texture.resource_path) == asset_path and size == Vector2i(256, 320) \
			and bool(left_eye.get("passed", false)) and bool(right_eye.get("passed", false)) \
			and total_colors >= 80 and hair_colors >= 25 and outfit_prop_colors >= 35
	}


func run_child_probe(probe_arg: String, marker: String, log_name: String) -> Dictionary:
	var child_output: Array = []
	var child_args := PackedStringArray([
		"--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"--log-file", "user://%s" % log_name,
		"--script", TEST_SCRIPT_PATH,
		"--", probe_arg
	])
	var child_exit := OS.execute(OS.get_executable_path(), child_args, child_output, true, true)
	var child_text := ""
	for output_value: Variant in child_output:
		child_text += String(output_value)
	return {
		"exit": child_exit,
		"markerFound": child_text.contains(marker),
		"emptyDto": child_text.contains("\"emptyDto\":true"),
		"diagnostic": child_text.contains("Invalid required story artifact render override")
	}


func finish(gs: Node, main: Node) -> void:
	var passed: int = results.filter(func(row: Dictionary): return bool(row.get("passed", false))).size()
	var report := {
		"suite": "R3 Stage 7B Visual Identity",
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


func run_required_pair_probe(missing_recipe: bool) -> void:
	var canonical_registry: Node = get_root().get_node("RuntimeRegistry")
	var original_value: Dictionary = canonical_registry.STORY_ARTIFACT_RENDER_OVERRIDES.get(REQUIRED_OPTIC_PAIR, {}).duplicate(true)
	var hostile_value := original_value.duplicate(true)
	if missing_recipe:
		hostile_value.erase("recipe")
	else:
		hostile_value["recipe"] = UNKNOWN_RECIPE
	var hostile_registry: Node = load(HOSTILE_REGISTRY_FIXTURE_PATH).new()
	hostile_registry.configure_pair_override("story_artifact_19", "artifact_057", hostile_value)
	get_root().add_child(hostile_registry)
	var dto: Dictionary = hostile_registry.get_artifact_instance_render_dto({
		"artifactSpecId": "artifact_057", "storyArtifactId": "story_artifact_19"
	})
	var marker := "STAGE7B_MISSING_PAIR_RECIPE_PROBE" if missing_recipe else "STAGE7B_UNKNOWN_PAIR_RECIPE_PROBE"
	var probe := {
		"emptyDto": dto.is_empty(),
		"missingRecipe": missing_recipe,
		"hostileRecipe": hostile_value.get("recipe", "<missing>"),
		"silentDefaultDto": String(dto.get("recipe", "")) == "DEFAULT"
	}
	print(marker + "=" + JSON.stringify(probe))
	quit(0 if bool(probe.emptyDto) and not bool(probe.silentDefaultDto) else 1)


func run() -> void:
	var registry: Node = get_root().get_node("RuntimeRegistry")
	var gs: Node = get_root().get_node("GameState")
	gs.persistence_enabled = false
	var main: Node3D = load("res://scenes/Main.tscn").instantiate()
	get_root().add_child(main)
	await settle_ui()

	var shape_failures: Array = []
	for fixture_value: Variant in INSTANCE_FIXTURES:
		var fixture: Dictionary = fixture_value
		var dto: Dictionary = registry.get_artifact_instance_render_dto(fixture.get("artifact", {}))
		if not exact_dto_shape(dto):
			shape_failures.append({"fixture": fixture.get("id", ""), "keys": sorted_string_keys(dto)})
	record(
		"S7B-INSTANCE-DTO-WHITELIST-01",
		"Every Stage 7 instance fixture exposes the exact ten-key public render DTO and exact nested allowlists",
		shape_failures.is_empty(),
		{"fixturesChecked": INSTANCE_FIXTURES.size(), "topKeys": TOP_LEVEL_DTO_KEYS, "failures": shape_failures}
	)

	var pristine_optic: Dictionary = registry.get_artifact_instance_render_dto(INSTANCE_FIXTURES[0].artifact)
	var expected_optic := pristine_optic.duplicate(true)
	var registry_before := JSON.stringify({
		"overrides": registry.STORY_ARTIFACT_RENDER_OVERRIDES,
		"variants": registry.visual_variants,
		"specs": registry.specs,
		"paths": registry.runtime_model_paths
	})
	pristine_optic["specId"] = "mutated_private_spec"
	pristine_optic["recipe"] = "MUTATED"
	pristine_optic["palette"]["primary"] = "#000000"
	pristine_optic["trim"]["shape"] = "hidden_truth"
	pristine_optic["detail"]["motif"] = "auction_price"
	pristine_optic["scale"][0] = 999.0
	var optic_after_mutation: Dictionary = registry.get_artifact_instance_render_dto(INSTANCE_FIXTURES[0].artifact)
	var registry_after := JSON.stringify({
		"overrides": registry.STORY_ARTIFACT_RENDER_OVERRIDES,
		"variants": registry.visual_variants,
		"specs": registry.specs,
		"paths": registry.runtime_model_paths
	})
	var privacy_failures: Array = []
	for fixture_value: Variant in INSTANCE_FIXTURES:
		var fixture: Dictionary = fixture_value
		var leaks := private_render_tokens(registry.get_artifact_instance_render_dto(fixture.get("artifact", {})))
		if not leaks.is_empty():
			privacy_failures.append({"fixture": fixture.get("id", ""), "tokens": leaks})
	record(
		"S7B-INSTANCE-DTO-ISOLATION-02",
		"Instance DTOs are deep copies with mutation zero and expose no private truth, economy, auction, clue, rarity, reserve or price token",
		optic_after_mutation == expected_optic and registry_after == registry_before and privacy_failures.is_empty(),
		{"freshDtoRestored": optic_after_mutation == expected_optic, "rawRegistryMutation": registry_after != registry_before, "privacyFailures": privacy_failures}
	)

	var pair_rows: Array = []
	var pair_failures: Array = []
	for fixture_index: int in range(2):
		var fixture: Dictionary = INSTANCE_FIXTURES[fixture_index]
		var dto: Dictionary = registry.get_artifact_instance_render_dto(fixture.artifact)
		var mesh_resource: Resource = load(String(dto.get("meshPath", "")))
		var row_ok := String(dto.get("specId", "")) == String(fixture.artifact.artifactSpecId) \
			and String(dto.get("recipe", "")) == String(fixture.recipe) \
			and String(dto.get("meshPath", "")) == String(fixture.mesh) and mesh_resource is Mesh
		pair_rows.append({"fixture": fixture.id, "recipe": dto.get("recipe", ""), "mesh": dto.get("meshPath", ""), "loadable": mesh_resource is Mesh})
		if not row_ok:
			pair_failures.append(fixture.id)
	record(
		"S7B-FRESH-PAIR-MAPPING-03",
		"Only story 19 plus Artifact 057 maps to OPTIC and only story 20 plus Artifact 059 maps to COMPOSITE",
		pair_rows.size() == 2 and pair_failures.is_empty(),
		{"pairs": pair_rows, "failures": pair_failures}
	)

	var default_rows: Array = []
	var default_failures: Array = []
	for fixture_index: int in range(2, INSTANCE_FIXTURES.size()):
		var fixture: Dictionary = INSTANCE_FIXTURES[fixture_index]
		var before: Dictionary = registry.get_artifact_instance_render_dto(fixture.artifact)
		registry.get_artifact_instance_render_dto(INSTANCE_FIXTURES[0].artifact)
		registry.get_artifact_instance_render_dto(INSTANCE_FIXTURES[1].artifact)
		var after: Dictionary = registry.get_artifact_instance_render_dto(fixture.artifact)
		var row_ok := String(before.get("recipe", "")) == String(fixture.recipe) \
			and String(before.get("meshPath", "")) == String(fixture.mesh) and before == after
		default_rows.append({"fixture": fixture.id, "recipe": before.get("recipe", ""), "mesh": before.get("meshPath", ""), "repeatExact": before == after})
		if not row_ok:
			default_failures.append(fixture.id)
	record(
		"S7B-LEGACY-DEFAULT-ISOLATION-04",
		"Legacy story 19 plus 051, story 20 plus 057 and unrelated/spec-only 057/059 remain canonical DEFAULT with cross-contamination zero",
		default_failures.is_empty() and default_rows.size() == 5,
		{"rows": default_rows, "failures": default_failures, "crossContamination": default_failures.size()}
	)

	var unknown_probe := run_child_probe(UNKNOWN_PAIR_PROBE_ARG, "STAGE7B_UNKNOWN_PAIR_RECIPE_PROBE=", "r3_stage7b_unknown_pair_recipe_probe.log")
	var missing_probe := run_child_probe(MISSING_PAIR_PROBE_ARG, "STAGE7B_MISSING_PAIR_RECIPE_PROBE=", "r3_stage7b_missing_pair_recipe_probe.log")
	var probes_pass := int(unknown_probe.get("exit", -1)) == 0 and bool(unknown_probe.get("markerFound", false)) \
		and bool(unknown_probe.get("emptyDto", false)) and bool(unknown_probe.get("diagnostic", false)) \
		and int(missing_probe.get("exit", -1)) == 0 and bool(missing_probe.get("markerFound", false)) \
		and bool(missing_probe.get("emptyDto", false)) and bool(missing_probe.get("diagnostic", false))
	record(
		"S7B-REQUIRED-PAIR-FAIL-CLOSED-05",
		"A required Stage 7 pair with an unknown or missing recipe returns an empty DTO instead of silently using DEFAULT",
		probes_pass,
		{"unknownRecipe": unknown_probe, "missingRecipe": missing_probe}
	)

	var optic_artifact: Dictionary = gs.new_artifact("artifact_057", 7057, "stage7b_fresh_optic")
	optic_artifact["storyArtifactId"] = "story_artifact_19"
	main.load_artifact(optic_artifact)
	await settle_ui(2)
	var optic_live_path := String(main.model.mesh.resource_path) if main.model != null and main.model.mesh != null else ""
	var optic_nodes := {
		"barrel": named_nodes(main.workpiece_root, "OpticTelescopeBarrel").size(),
		"objectiveHousing": named_nodes(main.workpiece_root, "OpticObjectiveHousing").size(),
		"objectiveLens": named_nodes(main.workpiece_root, "OpticObjectiveLens").size(),
		"eyepiece": named_nodes(main.workpiece_root, "OpticEyepiece").size(),
		"focusCollar": named_nodes(main.workpiece_root, "OpticFocusCollar").size(),
		"mountingYoke": named_nodes(main.workpiece_root, "OpticMountingYoke").size(),
		"yokeSupports": named_nodes(main.workpiece_root, "OpticYokeSupport_*").size(),
		"supportFoot": named_nodes(main.workpiece_root, "OpticSupportFoot").size(),
		"opticalAxis": named_nodes(main.workpiece_root, "OpticOpticalAxis").size(),
		"total": named_nodes(main.workpiece_root, "Optic*").size()
	}
	var expected_optic_nodes := {"barrel": 1, "objectiveHousing": 1, "objectiveLens": 1, "eyepiece": 1, "focusCollar": 1, "mountingYoke": 1, "yokeSupports": 2, "supportFoot": 1, "opticalAxis": 1, "total": 10}
	var optic_forbidden := forbidden_recipe_nodes(main.workpiece_root, "OPTIC")
	var optic_base_count := named_nodes(main.workpiece_root, "ArtifactMesh").size()
	var optic_base_hidden: bool = main.model != null and main.model.name == "ArtifactMesh" and not main.model.visible and not main.model.is_visible_in_tree()
	record(
		"S7B-OPTIC-RENDERER-06",
		"OPTIC hides the legacy gauge base and renders the exact telescope barrel, optics, focus collar, yoke/support and optical-axis silhouette with other recipe residue zero",
		optic_live_path == "res://assets/artifacts/model_12.obj" and optic_base_count == 1 and optic_base_hidden \
			and optic_nodes == expected_optic_nodes and all_zero(optic_forbidden),
		{"liveMeshPath": optic_live_path, "artifactMeshCount": optic_base_count, "artifactMeshHidden": optic_base_hidden, "nodes": optic_nodes, "expected": expected_optic_nodes, "forbidden": optic_forbidden}
	)

	var composite_artifact: Dictionary = gs.new_artifact("artifact_059", 7059, "stage7b_fresh_composite")
	composite_artifact["storyArtifactId"] = "story_artifact_20"
	main.load_artifact(composite_artifact)
	await settle_ui(2)
	var composite_live_path := String(main.model.mesh.resource_path) if main.model != null and main.model.mesh != null else ""
	var composite_nodes := {
		"mainBody": named_nodes(main.workpiece_root, "CompositeMainMeasuringBody").size(),
		"dial": named_nodes(main.workpiece_root, "CompositeGraduatedDial").size(),
		"scaleTicks": named_nodes(main.workpiece_root, "CompositeScaleTick_*").size(),
		"needle": named_nodes(main.workpiece_root, "CompositeMeasurementNeedle").size(),
		"secondary": named_nodes(main.workpiece_root, "CompositeSecondaryComponent").size(),
		"secondaryCap": named_nodes(main.workpiece_root, "CompositeSecondaryComponentCap").size(),
		"adapterJoint": named_nodes(main.workpiece_root, "CompositeAdapterInterfaceJoint").size(),
		"connector": named_nodes(main.workpiece_root, "CompositeMismatchedConnector").size(),
		"fasteners": named_nodes(main.workpiece_root, "CompositeMismatchedFastener_*").size(),
		"total": named_nodes(main.workpiece_root, "Composite*").size()
	}
	var expected_composite_nodes := {"mainBody": 1, "dial": 1, "scaleTicks": 11, "needle": 1, "secondary": 1, "secondaryCap": 1, "adapterJoint": 1, "connector": 1, "fasteners": 3, "total": 21}
	var composite_forbidden := forbidden_recipe_nodes(main.workpiece_root, "COMPOSITE")
	var composite_base_count := named_nodes(main.workpiece_root, "ArtifactMesh").size()
	var composite_base_hidden: bool = main.model != null and main.model.name == "ArtifactMesh" and not main.model.visible and not main.model.is_visible_in_tree()
	record(
		"S7B-COMPOSITE-RENDERER-07",
		"COMPOSITE hides the legacy camera base and renders the exact measuring body, graduated dial, secondary module, adapter, connector and mismatched fasteners with other recipe residue zero",
		composite_live_path == "res://assets/artifacts/model_14.obj" and composite_base_count == 1 and composite_base_hidden \
			and composite_nodes == expected_composite_nodes and all_zero(composite_forbidden),
		{"liveMeshPath": composite_live_path, "artifactMeshCount": composite_base_count, "artifactMeshHidden": composite_base_hidden, "nodes": composite_nodes, "expected": expected_composite_nodes, "forbidden": composite_forbidden}
	)

	var svg_rows: Array = []
	var svg_failures: Array = []
	for fixture_value: Variant in PORTRAIT_FIXTURES:
		var fixture: Dictionary = fixture_value
		var npc_id := String(fixture.get("npc_id", ""))
		var expression := String(fixture.get("expression", ""))
		var expected_path := String(fixture.get("path", ""))
		var raw_npc: Dictionary = registry.npcs.get(npc_id, {})
		var raw_mapping := String(raw_npc.get("expressions", {}).get(expression, ""))
		var presentation: Dictionary = registry.authored_npc_portrait_presentation(npc_id, expression)
		var public_mapping := String(presentation.get("asset_path", ""))
		var svg := FileAccess.get_file_as_string(expected_path)
		var feature_failures: Array = []
		for feature_value: Variant in fixture.get("features", []):
			var feature := String(feature_value)
			if not svg.contains("data-feature=\"%s\"" % feature):
				feature_failures.append(feature)
		var markers_ok := raw_mapping == expected_path and public_mapping == expected_path \
			and svg.contains("viewBox=\"0 0 256 320\"") \
			and svg.contains("data-expression-geometry-version=\"2\"") \
			and svg.contains("data-eye-system=\"sclera-iris-pupil-highlight\"") \
			and svg.contains("data-layer=\"hair\"") and svg.contains("data-layer=\"face\"") \
			and svg.contains("data-layer=\"outfit\"") and svg.contains("data-layer=\"prop\"") \
			and svg.contains("data-layer=\"expression-anchors\"") \
			and svg_has_two_complete_eyes(svg) and feature_failures.is_empty()
		svg_rows.append({"npc": npc_id, "rawRegistryPath": raw_mapping, "publicRegistryPath": public_mapping, "twoCompleteEyes": svg_has_two_complete_eyes(svg), "missingFeatures": feature_failures, "passed": markers_ok})
		if not markers_ok:
			svg_failures.append(npc_id)
	record(
		"S7B-PORTRAIT-SVG-V2-08",
		"Victor neutral and Noah concerned resolve explicitly to local SVG V2 busts with two complete eyes and character-specific hair, outfit and occupational props",
		svg_rows.size() == 2 and svg_failures.is_empty(),
		{"portraits": svg_rows, "failures": svg_failures}
	)

	var imported_pixel_rows: Array = []
	for fixture_value: Variant in PORTRAIT_FIXTURES:
		imported_pixel_rows.append(imported_portrait_pixel_contract(String(fixture_value.get("path", ""))))
	var imported_pixel_failures := imported_pixel_rows.filter(func(row: Dictionary): return not bool(row.get("passed", false)))
	record(
		"S7B-PORTRAIT-IMPORTED-PIXELS-09",
		"Victor and Noah loaded textures match current source imports and contain pixel-visible white, chromatic and dark eye systems plus detailed hair/outfit/prop zones",
		imported_pixel_rows.size() == 2 and imported_pixel_failures.is_empty(),
		{"portraits": imported_pixel_rows, "failures": imported_pixel_failures.size(), "staleGenericImportAllowed": false}
	)

	var dossier_results: Array = []
	for fixture_value: Variant in PORTRAIT_FIXTURES:
		dossier_results.append(await actual_dossier_portrait(gs, registry, main, fixture_value))
	var dossier_failures := dossier_results.filter(func(row: Dictionary): return not bool(row.get("passed", false)))
	record(
		"S7B-PORTRAIT-DOSSIER-10",
		"The Stage 7 Victor and Noah NPC sources each render one actual textured CaseNpcSourcePortrait at least 96 by 120 with generic fallback zero",
		dossier_results.size() == 2 and dossier_failures.is_empty(),
		{"cases": dossier_results, "failures": dossier_failures.size()}
	)

	var recipe_counts := {"DEFAULT": 0, "TYPEWRITER_CIPHER": 0, "SEXTANT": 0}
	var recipe_failures: Array = []
	for spec_id_value: Variant in registry.spec_order:
		var spec_id := String(spec_id_value)
		var expected_recipe := "TYPEWRITER_CIPHER" if spec_id == "artifact_069" else ("SEXTANT" if spec_id == "artifact_070" else "DEFAULT")
		var actual_recipe := String(registry.get_artifact_instance_render_dto({"artifactSpecId": spec_id}).get("recipe", ""))
		if recipe_counts.has(actual_recipe):
			recipe_counts[actual_recipe] = int(recipe_counts[actual_recipe]) + 1
		if actual_recipe != expected_recipe:
			recipe_failures.append({"spec": spec_id, "expected": expected_recipe, "actual": actual_recipe})
	var approved_recipes: Array = registry.ARTIFACT_RENDER_RECIPES.duplicate()
	approved_recipes.sort()
	record(
		"S7B-SPEC-ONLY-DISTRIBUTION-11",
		"The eighty-spec distribution remains seventy-eight DEFAULT, one cipher and one sextant while all special recipes stay pair-only",
		registry.spec_order.size() == 80 and recipe_counts == {"DEFAULT": 78, "TYPEWRITER_CIPHER": 1, "SEXTANT": 1} \
			and recipe_failures.is_empty() and approved_recipes == APPROVED_RECIPES,
		{"catalogSize": registry.spec_order.size(), "counts": recipe_counts, "allowlist": approved_recipes, "failures": recipe_failures}
	)

	var override_keys := sorted_string_keys(registry.STORY_ARTIFACT_RENDER_OVERRIDES)
	var future_21: Dictionary = registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_061", "storyArtifactId": "story_artifact_21"})
	var future_22: Dictionary = registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_075", "storyArtifactId": "story_artifact_22"})
	var future_23: Dictionary = registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_078", "storyArtifactId": "story_artifact_23"})
	var future_24: Dictionary = registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_077", "storyArtifactId": "story_artifact_24"})
	var future_25: Dictionary = registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_079", "storyArtifactId": "story_artifact_25"})
	var future_26: Dictionary = registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_080", "storyArtifactId": "story_artifact_26"})
	var future_key_found := false
	for override_key_value: Variant in override_keys:
		var override_key := String(override_key_value)
		if override_key.begins_with("story_artifact_21|") or override_key.begins_with("story_artifact_22|") \
				or override_key.begins_with("story_artifact_23|") or override_key.begins_with("story_artifact_24|") \
				or override_key.begins_with("story_artifact_25|") or override_key.begins_with("story_artifact_26|"):
			future_key_found = true
	record(
		"S7B-STAGE8-CONTAINMENT-12",
		"The exact override table binds only authored later-stage pairs and leaves unrelated combinations on DEFAULT",
		override_keys == EXPECTED_OVERRIDE_KEYS and future_key_found \
			and String(future_21.get("recipe", "")) == "CHRONOMETER" and String(future_22.get("recipe", "")) == "MICROSCOPE" \
			and String(future_23.get("recipe", "")) == "WIRE_RECORDER" and String(future_24.get("recipe", "")) == "SIGNAL_LANTERN" \
			and String(future_25.get("recipe", "")) == "SPECTROSCOPE" and String(future_26.get("recipe", "")) == "ASTRONOMICAL_REGULATOR" \
			and String(registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_061"}).get("recipe", "")) == "DEFAULT" \
			and String(registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_075", "storyArtifactId": "story_artifact_21"}).get("recipe", "")) == "DEFAULT" \
			and String(registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_078"}).get("recipe", "")) == "DEFAULT" \
			and String(registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_077", "storyArtifactId": "story_artifact_23"}).get("recipe", "")) == "DEFAULT" \
			and String(registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_079"}).get("recipe", "")) == "DEFAULT" \
			and String(registry.get_artifact_instance_render_dto({"artifactSpecId": "artifact_080", "storyArtifactId": "story_artifact_25"}).get("recipe", "")) == "DEFAULT",
		{"overrideKeys": override_keys, "expected": EXPECTED_OVERRIDE_KEYS, "futureKeyFound": future_key_found, "story21Recipe": future_21.get("recipe", ""), "story22Recipe": future_22.get("recipe", ""), "story23Recipe": future_23.get("recipe", ""), "story24Recipe": future_24.get("recipe", ""), "story25Recipe": future_25.get("recipe", ""), "story26Recipe": future_26.get("recipe", "")}
	)

	await finish(gs, main)
