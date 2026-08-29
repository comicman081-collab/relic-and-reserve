extends Node3D

const HYPOTHESES := [
	"GENUINE", "GENUINE_WITH_PERIOD_REPAIR", "GENUINE_WITH_MODERN_REPAIR",
	"REPRODUCTION", "FORGERY", "UNKNOWN"
]

var screen := "title"
var selected: Dictionary = {}
var model: MeshInstance3D
var damage_marks: Array = []
var parts: Dictionary = {}
var trim_nodes: Array = []
var camera: Camera3D
var audio: AudioStreamPlayer
var bgm: AudioStreamPlayer
var bgm_track_key := ""
var orbit := Vector2.ZERO
var distance := 6.0
var dragging := false
var ui: Control
var content_root: Control
var status: Label
var language := "en"
var workpiece_root: Node3D
var workshop_set: Node3D
var grand_reserve_set: Node3D
var hypothesis_buttons: Dictionary = {}
var hypothesis_accept_button: Button
var last_auction_result: Dictionary = {}
var case_dossier_case_id := ""
var case_detail_evidence_id := ""
var character_catalog: Dictionary = {}
var portrait_render_cache: Dictionary = {}
var market_character_state := "WELCOME"
var market_character_fact := ""
var market_character_dialogue := ""
var market_active_lot_id := ""
var last_event_result: Dictionary = {}
var event_cue_state := "REQUEST"
var auction_cue_queue: Array = []
var auction_cue_index := 0
var auction_sequence_key := ""
var listing_artifact_id := ""
var listing_step := "PRICE"
var listing_price_preset := ""
var listing_disclosure := ""
var tutorial_guidance_state: Dictionary = {}
var tutorial_target_control: Control
var tutorial_render_serial := 0
var final_lot_page := 0
var postgame_credits_visible := false
var inventory_page := 0
var inventory_selected_uid := ""
var authentication_evidence_page := 0
var authentication_evidence_index := 0
var upgrade_page := 0
var selected_upgrade_id := ""
var master_volume_db := 0.0
var bgm_volume_db := -14.0
var sfx_volume_db := -4.0
var ui_text_scale := 1.0
var reduced_motion := false
var settings_return_screen := "title"

const CASE_ICON_ROOT := "res://assets/ui/case_icons/"
const CHARACTER_CATALOG_PATH := "res://data/characters/characters.json"
const PORTRAIT_EXPRESSION_OVERLAY := preload("res://scripts/portrait_expression_overlay.gd")
const PLAYER_SETTINGS_PATH := "user://relic_reserve_settings.cfg"
const BGM_ROOT := "res://audio/bgm/relic_reserve_bgm/"
const TITLE_ROOT := "res://audio/title/relic_reserve_title/"
const ENDING_ROOT := "res://audio/endings/relic_reserve_endings/"
const BGM_TRACKS := {
	"title": "01_first_bell_sunshine.mp3",
	"workshop": "001_morning_hallway.mp3",
	"market": "002_lunch_break_laughs.mp3",
	"event": "007_festival_lanterns.mp3",
	"inspection": "005_library_sunbeams.mp3",
	"auction": "008_exam_night_window.mp3",
	"grand_reserve": "010_graduation_rehearsal.mp3"
}
const TITLE_TRACK := "01_first_bell_sunshine.mp3"
const ENDING_TRACKS := {
	"ENDING_S": "01_see_you_tomorrow.mp3",
	"ENDING_A": "02_the_memory_we_keep.mp3",
	"ENDING_B": "03_after_the_final_bell.mp3",
	"ENDING_C": "04_summer_never_ends.mp3",
	"ENDING_D": "05_our_next_adventure.mp3",
	"POSTGAME": "06_the_sky_is_still_blue.mp3"
}
const LISTING_PRICE_PRESETS := {
	"FAST": {"startingRatio": 0.50, "reserveRatio": 0.60, "icon": "objective"},
	"BALANCED": {"startingRatio": 0.60, "reserveRatio": 0.72, "icon": "report"},
	"HIGH": {"startingRatio": 0.68, "reserveRatio": 0.82, "icon": "risk"}
}


func _ready() -> void:
	load_player_settings()
	build_world()
	build_ui()
	apply_player_settings()
	language = GameState.language
	show_title()


func build_world() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#12161a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b79c7b")
	environment.ambient_light_energy = 0.62
	world_environment.environment = environment
	add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48, -28, 0)
	key_light.light_energy = 1.2
	key_light.shadow_enabled = true
	add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-3, 3, 3)
	fill_light.light_color = Color("#d8b27a")
	fill_light.omni_range = 11
	fill_light.light_energy = 4.0
	add_child(fill_light)
	# The playable artifact is the visual hero of the investigation screens.
	# Keep a warm key and a cool rim independent of the workshop props, so an
	# uncluttered inspection still reads as a carefully lit display rather than a
	# flat model against the background.
	var artifact_key_light := OmniLight3D.new()
	artifact_key_light.name = "ArtifactKeyLight"
	artifact_key_light.position = Vector3(-1.8, 3.4, 3.6)
	artifact_key_light.light_color = Color("#ffe4b5")
	artifact_key_light.omni_range = 8.0
	artifact_key_light.light_energy = 2.5
	add_child(artifact_key_light)
	var artifact_rim_light := OmniLight3D.new()
	artifact_rim_light.name = "ArtifactRimLight"
	artifact_rim_light.position = Vector3(2.6, 2.5, -1.8)
	artifact_rim_light.light_color = Color("#9cced3")
	artifact_rim_light.omni_range = 7.0
	artifact_rim_light.light_energy = 1.8
	add_child(artifact_rim_light)

	camera = Camera3D.new()
	camera.position = Vector3(0, 2.3, distance)
	add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0, 1.0, 0))
	audio = AudioStreamPlayer.new()
	audio.name = "AudioManager"
	audio.bus = "SFX"
	add_child(audio)
	bgm = AudioStreamPlayer.new()
	bgm.name = "BGMManager"
	bgm.bus = "BGM"
	bgm.finished.connect(_on_bgm_finished)
	add_child(bgm)

	workshop_set = Node3D.new()
	workshop_set.name = "WorkshopEnvironment3D"
	add_child(workshop_set)
	build_workshop_environment()
	grand_reserve_set = Node3D.new()
	grand_reserve_set.name = "GrandReserveHall3D"
	add_child(grand_reserve_set)
	build_grand_reserve_environment()
	grand_reserve_set.visible = false

	workpiece_root = Node3D.new()
	workpiece_root.name = "WorkpieceRoot"
	add_child(workpiece_root)


func build_workshop_environment() -> void:
	add_box(workshop_set, "Workbench", Vector3(0, 0, 0), Vector3(4.8, 0.35, 2.8), Color("#5a3924"))
	add_box(workshop_set, "Shelf", Vector3(-4, 2, 0), Vector3(1.0, 3.5, 1.2), Color("#7a5230"))
	add_box(workshop_set, "Cabinet", Vector3(4, 1, 0), Vector3(1.3, 2.2, 1.2), Color("#28373c"))
	add_box(workshop_set, "Lamp", Vector3(0, 3, 0), Vector3(0.25, 1.8, 0.25), Color("#b27a2a"))
	add_box(workshop_set, "InspectionMat", Vector3(0, 0.22, 0), Vector3(3.5, 0.08, 2.0), Color("#2d4b4e"))
	var prop_files := DirAccess.get_files_at("res://assets/workshop_props")
	var placed := 0
	for prop_path: String in prop_files:
		if not prop_path.ends_with(".obj") or prop_path == "materials.mtl" or placed >= 12:
			continue
		var resource := load("res://assets/workshop_props/" + prop_path)
		if resource is Mesh:
			var prop_mesh := MeshInstance3D.new()
			prop_mesh.name = "RuntimeProp_" + prop_path.trim_suffix(".obj")
			prop_mesh.mesh = resource
			prop_mesh.position = Vector3(-5.0 + (placed % 6) * 2.0, 0.45 + (placed % 2) * 0.3, -2.2 - (placed / 6) * 1.1)
			prop_mesh.scale = Vector3.ONE * 0.32
			var material_name := "steel" if ("tool" in prop_path or "cabinet" in prop_path) else ("painted_metal" if "lamp" in prop_path else "aged_wood")
			var material_path: String = RuntimeRegistry.materials.get(material_name, "")
			if not material_path.is_empty():
				prop_mesh.material_override = load(material_path)
			workshop_set.add_child(prop_mesh)
			placed += 1
	for grade in range(2, 6):
		var module := Node3D.new()
		module.name = "GradeModule_%d" % grade
		module.visible = false
		workshop_set.add_child(module)
		add_box(module, "ModuleBench", Vector3(-5.0 + grade * 2.1, 0.55, -3.7), Vector3(1.5, 1.0, 0.8), Color.from_hsv(0.08 * grade, 0.42, 0.52))


func build_grand_reserve_environment() -> void:
	add_box(grand_reserve_set, "HallFloor", Vector3(0, -0.25, -1), Vector3(14, 0.3, 11), Color("#1f2430"))
	add_box(grand_reserve_set, "AuctionPodium", Vector3(0, 0.65, -2.6), Vector3(2.6, 1.3, 1.1), Color("#6a3d27"))
	add_box(grand_reserve_set, "AuctioneerDesk", Vector3(-3.8, 0.55, -2.5), Vector3(2.2, 1.1, 1.0), Color("#40302a"))
	add_box(grand_reserve_set, "LargeScreen", Vector3(0, 3.4, -4.4), Vector3(6.6, 3.0, 0.25), Color("#22394a"))
	for index in range(3):
		add_box(grand_reserve_set, "DisplayPlinth_%d" % (index + 1), Vector3(-3.2 + index * 3.2, 0.6, 0.4), Vector3(1.5, 1.2, 1.5), Color("#c0aa7a"))
	for row in range(3):
		for seat in range(7):
			add_box(grand_reserve_set, "BidderSeat_%d_%d" % [row, seat], Vector3(-5.4 + seat * 1.8, 0.25, 2.5 + row * 1.2), Vector3(0.75, 0.8, 0.75), Color("#303946"))
	for side in [-1, 1]:
		add_box(grand_reserve_set, "WallPanel_%d" % side, Vector3(side * 6.3, 2.0, -1.0), Vector3(0.25, 4.0, 8.0), Color("#3d2d42"))
	var reserve_light := OmniLight3D.new()
	reserve_light.name = "ReserveLightingRig"
	reserve_light.position = Vector3(0, 5, 0)
	reserve_light.light_color = Color("#d7c3ff")
	reserve_light.omni_range = 14
	reserve_light.light_energy = 7.0
	grand_reserve_set.add_child(reserve_light)


func add_box(parent: Node, node_name: String, position_value: Vector3, size_value: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = make_material(color, 0.08, 0.72)
	instance.name = node_name
	parent.add_child(instance)
	return instance


func make_material(color: Color, metallic: float = 0.2, roughness: float = 0.55) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	# A controlled specular response keeps brass, glass and painted-metal trim
	# legible at thumbnail size without turning every relic into chrome.
	material.metallic_specular = clampf(0.44 + metallic * 0.34, 0.44, 0.78)
	return material


func set_world_mode(mode: String) -> void:
	grand_reserve_set.visible = mode == "grand_reserve"
	workshop_set.visible = mode != "grand_reserve"
	update_workshop_grade_visuals()


func update_workshop_grade_visuals() -> void:
	if workshop_set == null:
		return
	var grade := int(GameState.campaign_state.get("workshopGrade", 1))
	for child: Node in workshop_set.get_children():
		if child.name.begins_with("GradeModule_"):
			child.visible = int(child.name.trim_prefix("GradeModule_")) <= grade


func play_sfx(effect_name: String) -> void:
	if audio == null:
		return
	var stream := load("res://audio/%s.wav" % effect_name)
	if stream is AudioStream:
		audio.stream = stream
		audio.play()


func _on_bgm_finished() -> void:
	if bgm != null and bgm.stream != null and not bgm.playing:
		bgm.play()


func bgm_key_for_screen(screen_name: String) -> String:
	match screen_name:
		"title", "stage_select":
			return "title"
		"workshop", "campaign":
			return "workshop"
		"market", "commissions":
			return "market"
		"event":
			return "event"
		"inventory", "inspection", "authentication", "case_dossier":
			return "inspection"
		"appraisal", "upgrades":
			return "workshop"
		"auction":
			return "auction"
		"final_selection", "grand_reserve":
			return "grand_reserve"
		"ending":
			return String(GameState.campaign_state.get("currentEnding", "ENDING_S"))
		"postgame":
			return "POSTGAME"
		"settings":
			return bgm_key_for_screen(settings_return_screen) if settings_return_screen != "settings" else "workshop"
		_:
			return "workshop"


func play_bgm_for_screen(screen_name: String) -> void:
	if bgm == null:
		return
	var track_key := bgm_key_for_screen(screen_name)
	var stream_path := ""
	if track_key == "title":
		stream_path = TITLE_ROOT + TITLE_TRACK
	elif ENDING_TRACKS.has(track_key):
		stream_path = ENDING_ROOT + String(ENDING_TRACKS.get(track_key, ""))
	else:
		stream_path = BGM_ROOT + String(BGM_TRACKS.get(track_key, ""))
	if stream_path.is_empty() or not ResourceLoader.exists(stream_path):
		return
	if track_key == bgm_track_key and bgm.playing:
		return
	var stream := load(stream_path)
	if stream is AudioStream:
		bgm.stop()
		bgm.stream = stream
		bgm.play()
		bgm_track_key = track_key


func clear_workpiece_nodes() -> void:
	for child: Node in workpiece_root.get_children():
		child.free()
	model = null
	damage_marks.clear()
	parts.clear()
	trim_nodes.clear()


func load_artifact(artifact: Dictionary) -> void:
	var prior_uid := String(selected.get("uniqueId", ""))
	selected = artifact
	if String(artifact.get("uniqueId", "")) != prior_uid:
		authentication_evidence_page = 0
		authentication_evidence_index = 0
	GameState.active_workpiece = artifact
	sync_workpiece_from_state()


func sync_workpiece_from_state() -> void:
	clear_workpiece_nodes()
	if selected.is_empty():
		return
	var render_dto := RuntimeRegistry.get_artifact_instance_render_dto(selected)
	var mesh_path := String(render_dto.get("meshPath", ""))
	var resource: Resource = load(mesh_path) if not mesh_path.is_empty() else null
	model = MeshInstance3D.new()
	model.name = "ArtifactMesh"
	model.mesh = resource if resource is Mesh else BoxMesh.new()
	model.position = Vector3(0, 1.2, 0)
	var scale_values: Array = render_dto.get("scale", [1.0, 1.0, 1.0])
	model.scale = Vector3(float(scale_values[0]), float(scale_values[1]), float(scale_values[2])) * 1.08
	var palette_value: Variant = render_dto.get("palette", {})
	var palette: Dictionary = palette_value if palette_value is Dictionary else {}
	var material_path: String = render_dto.get("materialPath", "")
	var variant_material: Material
	if not material_path.is_empty() and load(material_path) is Material:
		variant_material = load(material_path).duplicate()
	else:
		variant_material = make_material(Color(palette.get("primary", "#b8893f")))
	if variant_material is StandardMaterial3D:
		variant_material.albedo_color = Color(palette.get("primary", "#b8893f"))
		variant_material.metallic = float(render_dto.get("metallic", 0.2))
		variant_material.roughness = float(render_dto.get("roughness", 0.55))
	model.material_override = variant_material
	workpiece_root.add_child(model)
	add_artifact_render_recipe(render_dto)
	add_damage_visuals(selected)
	add_part_nodes(selected)
	camera.look_at_from_position(camera.position, Vector3(0, 1.2, 0))


func refresh_workpiece_visuals() -> void:
	sync_workpiece_from_state()


func add_artifact_render_recipe(render_dto: Dictionary) -> void:
	match String(render_dto.get("recipe", "")):
		"DEFAULT":
			add_variant_trim(render_dto)
		"TYPEWRITER_CIPHER":
			add_typewriter_cipher_overlay(render_dto)
		"SEXTANT":
			add_sextant_overlay(render_dto)
		"GAUGE":
			add_gauge_overlay(render_dto)
		"CHRONOMETER":
			add_chronometer_overlay(render_dto)
		"MUSIC_BOX":
			add_music_box_overlay(render_dto)
		"MICROSCOPE":
			add_microscope_overlay(render_dto)
		"WIRE_RECORDER":
			add_wire_recorder_overlay(render_dto)
		"SIGNAL_LANTERN":
			add_signal_lantern_overlay(render_dto)
		"SPECTROSCOPE":
			add_spectroscope_overlay(render_dto)
		"ASTRONOMICAL_REGULATOR":
			add_astronomical_regulator_overlay(render_dto)
		"OPTIC":
			add_optic_overlay(render_dto)
		"COMPOSITE":
			add_composite_overlay(render_dto)
		_:
			push_error("Artifact render DTO has no allowlisted recipe: %s" % render_dto.get("recipe", "<missing>"))


func add_variant_trim(render_dto: Dictionary) -> void:
	var trim_value: Variant = render_dto.get("trim", {})
	var trim_data: Dictionary = trim_value if trim_value is Dictionary else {}
	var palette_value: Variant = render_dto.get("palette", {})
	var palette: Dictionary = palette_value if palette_value is Dictionary else {}
	var trim := MeshInstance3D.new()
	trim.name = "VariantTrim_%s" % trim_data.get("shape", "band")
	var shape: String = trim_data.get("shape", "band")
	if shape == "ring":
		var torus := TorusMesh.new()
		torus.inner_radius = 0.48
		torus.outer_radius = 0.58
		trim.mesh = torus
	elif shape == "stud":
		var sphere := SphereMesh.new()
		sphere.radius = 0.17
		sphere.height = 0.34
		trim.mesh = sphere
	else:
		var box := BoxMesh.new()
		box.size = Vector3(1.5, 0.12, 0.15) if shape == "band" else Vector3(0.7, 0.5, 0.12)
		trim.mesh = box
	trim.position = Vector3(0, 1.35, 0.72)
	trim.material_override = make_material(Color(trim_data.get("color", "#d0a14d")), 0.35, 0.42)
	workpiece_root.add_child(trim)
	trim_nodes.append(trim)
	# Stage-expansion data already supplies a one-of-a-kind trim and motif for
	# every artifact. The old renderer reduced most of them to the same box. Keep
	# the authored primary trim as the contract node, then consume its shape as a
	# compact, readable front-facing detail set.
	add_variant_trim_details(shape, palette, Color(trim_data.get("color", "#d0a14d")))


func variant_box(size_value: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	return mesh


func variant_cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	return mesh


func variant_sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	return mesh


func add_variant_detail_mesh(node_name: String, mesh_value: Mesh, position_value: Vector3, rotation_value: Vector3, color: Color, metallic: float = 0.34, roughness: float = 0.38) -> MeshInstance3D:
	return add_recipe_mesh("VariantDetail_%s" % node_name, mesh_value, position_value, rotation_value, color, metallic, roughness)


func add_variant_trim_details(shape: String, palette: Dictionary, trim_color: Color) -> void:
	var primary := Color(palette.get("primary", "#b8893f"))
	var secondary := Color(palette.get("secondary", "#705038"))
	var accent := Color(palette.get("accent", trim_color.to_html()))
	match shape:
		"salt_bezel":
			var bezel := TorusMesh.new()
			bezel.inner_radius = 0.52
			bezel.outer_radius = 0.64
			add_variant_detail_mesh("SaltBezel", bezel, Vector3(0, 1.23, 0.86), Vector3(90, 0, 0), accent, 0.62, 0.25)
			for nick_index in range(4):
				add_variant_detail_mesh("SaltNick_%02d" % nick_index, variant_box(Vector3(0.1, 0.07, 0.06)), Vector3(-0.46 + nick_index * 0.31, 1.72, 0.91), Vector3(0, 0, nick_index * 9.0), secondary, 0.22, 0.58)
		"folded_corner":
			add_variant_detail_mesh("BellowsEdgeLeft", variant_box(Vector3(0.58, 0.07, 0.08)), Vector3(-0.53, 1.26, 0.88), Vector3(0, 0, -38), trim_color, 0.18, 0.48)
			add_variant_detail_mesh("BellowsEdgeRight", variant_box(Vector3(0.58, 0.07, 0.08)), Vector3(0.53, 1.26, 0.88), Vector3(0, 0, 38), trim_color, 0.18, 0.48)
			add_variant_detail_mesh("VellumStitch", variant_box(Vector3(0.72, 0.045, 0.05)), Vector3(0, 1.55, 0.91), Vector3.ZERO, accent, 0.22, 0.46)
		"relay_rail":
			add_variant_detail_mesh("RelayRail", variant_box(Vector3(1.35, 0.09, 0.11)), Vector3(0, 1.19, 0.86), Vector3.ZERO, accent, 0.56, 0.28)
			for coil_index in range(2):
				add_variant_detail_mesh("Coil_%02d" % coil_index, variant_cylinder(0.14, 0.34), Vector3(-0.38 + coil_index * 0.76, 1.41, 0.88), Vector3(90, 0, 0), secondary, 0.6, 0.3)
		"orbit_ring":
			var orbit := TorusMesh.new()
			orbit.inner_radius = 0.68
			orbit.outer_radius = 0.73
			add_variant_detail_mesh("OrbitRing", orbit, Vector3(0, 1.26, 0.84), Vector3(90, 0, 0), accent, 0.66, 0.24)
			add_variant_detail_mesh("OrbitPlanet", variant_sphere(0.105), Vector3(0.53, 1.62, 0.91), Vector3.ZERO, secondary, 0.3, 0.34)
		"mandrel_band":
			add_variant_detail_mesh("Mandrel", variant_cylinder(0.17, 1.28), Vector3(0, 1.35, 0.86), Vector3(0, 0, 90), accent, 0.58, 0.28)
			for rib_index in range(4):
				add_variant_detail_mesh("CylinderRib_%02d" % rib_index, variant_box(Vector3(0.05, 0.32, 0.07)), Vector3(-0.42 + rib_index * 0.28, 1.35, 0.93), Vector3.ZERO, secondary, 0.35, 0.38)
		"tripod_yoke":
			add_variant_detail_mesh("YokeCrossbar", variant_box(Vector3(1.08, 0.09, 0.11)), Vector3(0, 1.44, 0.87), Vector3.ZERO, trim_color, 0.58, 0.3)
			add_variant_detail_mesh("YokeLeft", variant_box(Vector3(0.08, 0.62, 0.1)), Vector3(-0.43, 1.12, 0.88), Vector3(0, 0, -22), secondary, 0.54, 0.34)
			add_variant_detail_mesh("YokeRight", variant_box(Vector3(0.08, 0.62, 0.1)), Vector3(0.43, 1.12, 0.88), Vector3(0, 0, 22), secondary, 0.54, 0.34)
			add_variant_detail_mesh("LevelVial", variant_cylinder(0.08, 0.44), Vector3(0, 1.64, 0.94), Vector3(0, 0, 90), Color("#8fd8c8"), 0.12, 0.16)
		"marquetry_bead":
			add_variant_detail_mesh("MarquetryInlay", variant_box(Vector3(1.0, 0.18, 0.07)), Vector3(0, 1.37, 0.88), Vector3.ZERO, accent, 0.28, 0.46)
			for bead_index in range(5):
				add_variant_detail_mesh("MarquetryBead_%02d" % bead_index, variant_sphere(0.052), Vector3(-0.38 + bead_index * 0.19, 1.48, 0.94), Vector3.ZERO, secondary, 0.4, 0.35)
		"balance_foot":
			add_variant_detail_mesh("BalanceBeam", variant_box(Vector3(1.26, 0.08, 0.1)), Vector3(0, 1.48, 0.86), Vector3.ZERO, trim_color, 0.62, 0.26)
			add_variant_detail_mesh("BalanceFootLeft", variant_box(Vector3(0.22, 0.15, 0.14)), Vector3(-0.48, 1.08, 0.88), Vector3.ZERO, secondary, 0.44, 0.4)
			add_variant_detail_mesh("BalanceFootRight", variant_box(Vector3(0.22, 0.15, 0.14)), Vector3(0.48, 1.08, 0.88), Vector3.ZERO, secondary, 0.44, 0.4)
			for mark_index in range(3):
				add_variant_detail_mesh("DosageMark_%02d" % mark_index, variant_box(Vector3(0.05, 0.2, 0.04)), Vector3(-0.22 + mark_index * 0.22, 1.35, 0.94), Vector3.ZERO, Color("#35658b"), 0.28, 0.4)
		"viewing_slots":
			for slot_index in range(4):
				add_variant_detail_mesh("ViewingSlot_%02d" % slot_index, variant_box(Vector3(0.17, 0.08, 0.07)), Vector3(-0.42 + slot_index * 0.28, 1.36, 0.91), Vector3.ZERO, trim_color, 0.48, 0.32)
			add_variant_detail_mesh("FoxDrum", variant_cylinder(0.12, 0.92), Vector3(0, 1.16, 0.84), Vector3(0, 0, 90), primary, 0.3, 0.4)
		"terminal_coil":
			var coil := TorusMesh.new()
			coil.inner_radius = 0.26
			coil.outer_radius = 0.33
			add_variant_detail_mesh("TerminalCoil", coil, Vector3(0, 1.34, 0.88), Vector3(90, 0, 0), trim_color, 0.6, 0.25)
			for division_index in range(5):
				add_variant_detail_mesh("ZeroDivision_%02d" % division_index, variant_box(Vector3(0.045, 0.16, 0.04)), Vector3(-0.32 + division_index * 0.16, 1.6, 0.94), Vector3.ZERO, accent, 0.38, 0.34)
		"crystal_dial":
			add_variant_detail_mesh("CrystalDial", variant_cylinder(0.42, 0.075), Vector3(0, 1.33, 0.88), Vector3(90, 0, 0), Color("#b7d9de"), 0.08, 0.16)
			add_variant_detail_mesh("StationNeedle", variant_box(Vector3(0.42, 0.055, 0.04)), Vector3(0.13, 1.34, 0.94), Vector3(0, 0, -24), accent, 0.42, 0.28)
		"tracing_arm":
			add_variant_detail_mesh("TracingArm", variant_box(Vector3(0.96, 0.075, 0.1)), Vector3(0.03, 1.37, 0.88), Vector3(0, 0, -14), trim_color, 0.62, 0.27)
			add_variant_detail_mesh("CountingWheel", variant_cylinder(0.18, 0.08), Vector3(-0.42, 1.36, 0.94), Vector3(90, 0, 0), secondary, 0.56, 0.26)
		"objective_turret":
			for lens_index in range(2):
				add_variant_detail_mesh("Objective_%02d" % lens_index, variant_cylinder(0.18, 0.3), Vector3(-0.25 + lens_index * 0.5, 1.38, 0.88), Vector3(0, 0, 90), trim_color, 0.66, 0.23)
			add_variant_detail_mesh("WingScale", variant_box(Vector3(0.72, 0.06, 0.05)), Vector3(0, 1.64, 0.94), Vector3.ZERO, secondary, 0.3, 0.48)
		"chart_grille":
			add_variant_detail_mesh("ChartFrame", variant_box(Vector3(1.08, 0.42, 0.06)), Vector3(0, 1.32, 0.88), Vector3.ZERO, trim_color, 0.4, 0.42)
			for grid_index in range(4):
				add_variant_detail_mesh("ChartGrid_%02d" % grid_index, variant_box(Vector3(0.045, 0.32, 0.05)), Vector3(-0.33 + grid_index * 0.22, 1.32, 0.94), Vector3.ZERO, secondary, 0.34, 0.42)
		"vented_crown":
			add_variant_detail_mesh("VentedCrown", variant_box(Vector3(0.86, 0.15, 0.1)), Vector3(0, 1.72, 0.86), Vector3.ZERO, trim_color, 0.48, 0.3)
			add_variant_detail_mesh("SignalLensRed", variant_cylinder(0.12, 0.07), Vector3(-0.2, 1.38, 0.94), Vector3(90, 0, 0), Color("#d85b4d"), 0.2, 0.2)
			add_variant_detail_mesh("SignalLensGreen", variant_cylinder(0.12, 0.07), Vector3(0.2, 1.38, 0.94), Vector3(90, 0, 0), Color("#67b7a1"), 0.2, 0.2)
		"reel_guard":
			var reel := TorusMesh.new()
			reel.inner_radius = 0.3
			reel.outer_radius = 0.36
			add_variant_detail_mesh("ReelGuard", reel, Vector3(-0.24, 1.35, 0.88), Vector3(90, 0, 0), secondary, 0.58, 0.28)
			add_variant_detail_mesh("SpiralWire", variant_cylinder(0.05, 0.82), Vector3(0.32, 1.35, 0.9), Vector3(0, 0, 90), accent, 0.54, 0.26)
		"prism_cradle":
			add_variant_detail_mesh("PrismChamber", variant_box(Vector3(0.76, 0.38, 0.12)), Vector3(0, 1.35, 0.86), Vector3.ZERO, Color("#82c9d1"), 0.1, 0.18)
			add_variant_detail_mesh("PrismClampLeft", variant_box(Vector3(0.08, 0.48, 0.11)), Vector3(-0.42, 1.35, 0.92), Vector3(0, 0, -18), trim_color, 0.6, 0.28)
			add_variant_detail_mesh("PrismClampRight", variant_box(Vector3(0.08, 0.48, 0.11)), Vector3(0.42, 1.35, 0.92), Vector3(0, 0, 18), trim_color, 0.6, 0.28)
		"mercury_pendulum":
			add_variant_detail_mesh("PendulumRod", variant_cylinder(0.055, 1.1), Vector3(0, 1.31, 0.86), Vector3.ZERO, trim_color, 0.62, 0.25)
			add_variant_detail_mesh("MercuryBob", variant_sphere(0.18), Vector3(0, 0.82, 0.9), Vector3.ZERO, Color("#c4d6d8"), 0.7, 0.18)
			for star_index in range(3):
				add_variant_detail_mesh("StarGrid_%02d" % star_index, variant_sphere(0.04), Vector3(-0.28 + star_index * 0.28, 1.67, 0.95), Vector3.ZERO, accent, 0.5, 0.24)


func add_recipe_mesh(node_name: String, mesh_value: Mesh, position_value: Vector3, rotation_value: Vector3, color: Color, metallic: float = 0.28, roughness: float = 0.42) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh_value
	instance.position = position_value
	instance.rotation_degrees = rotation_value
	instance.material_override = make_material(color, metallic, roughness)
	workpiece_root.add_child(instance)
	trim_nodes.append(instance)
	return instance


func add_typewriter_cipher_overlay(render_dto: Dictionary) -> void:
	var palette_value: Variant = render_dto.get("palette", {})
	var palette: Dictionary = palette_value if palette_value is Dictionary else {}
	var accent := Color(palette.get("accent", "#c2c8c6"))
	var secondary := Color(palette.get("secondary", "#0d2635"))
	var keyline := BoxMesh.new()
	keyline.size = Vector3(1.82, 0.08, 0.11)
	add_recipe_mesh("CipherKeyline", keyline, Vector3(0, 1.42, 0.83), Vector3.ZERO, accent, 0.72, 0.24)
	for key_index in range(9):
		var key := BoxMesh.new()
		key.size = Vector3(0.13, 0.075, 0.13)
		add_recipe_mesh(
			"CipherThirdRowKey_%02d" % (key_index + 1),
			key,
			Vector3(-0.72 + key_index * 0.18, 1.55, 0.89),
			Vector3(-10, 0, 0),
			accent if key_index % 2 == 0 else secondary,
			0.58,
			0.3
		)
	for glyph_index in range(2):
		var glyph := SphereMesh.new()
		glyph.radius = 0.045
		glyph.height = 0.09
		add_recipe_mesh(
			"CipherPairedGlyph_%d" % (glyph_index + 1),
			glyph,
			Vector3(-0.09 + glyph_index * 0.18, 1.63, 0.98),
			Vector3.ZERO,
			Color("#f0d07a"),
			0.4,
			0.28
		)
	for stop_index in range(2):
		var filed_stop := BoxMesh.new()
		filed_stop.size = Vector3(0.1, 0.16, 0.08)
		add_recipe_mesh(
			"CipherFiledStop_%d" % (stop_index + 1),
			filed_stop,
			Vector3(-0.5 + stop_index, 1.35, 0.94),
			Vector3(0, 0, -18 if stop_index == 0 else 18),
			Color("#cb735c"),
			0.18,
			0.55
		)


func add_sextant_overlay(render_dto: Dictionary) -> void:
	var palette_value: Variant = render_dto.get("palette", {})
	var palette: Dictionary = palette_value if palette_value is Dictionary else {}
	var accent := Color(palette.get("accent", "#d8d1b4"))
	var secondary := Color(palette.get("secondary", "#234b55"))
	var arc_center := Vector2(0.0, 1.34)
	var arc_radius := 0.9
	for segment_index in range(11):
		var angle_degrees := 205.0 + segment_index * 13.0
		var angle := deg_to_rad(angle_degrees)
		var segment := BoxMesh.new()
		segment.size = Vector3(0.27, 0.075, 0.1)
		add_recipe_mesh(
			"SextantArcDegree_%02d" % segment_index,
			segment,
			Vector3(arc_center.x + cos(angle) * arc_radius, arc_center.y + sin(angle) * arc_radius, 0.74),
			Vector3(0, 0, angle_degrees + 90.0),
			accent if segment_index % 2 == 0 else Color("#b99545"),
			0.64,
			0.3
		)
	var vernier := BoxMesh.new()
	vernier.size = Vector3(0.43, 0.15, 0.09)
	add_recipe_mesh("SextantDegreeVernier", vernier, Vector3(0, 0.44, 0.82), Vector3.ZERO, accent, 0.48, 0.32)
	var mirror := CylinderMesh.new()
	mirror.top_radius = 0.17
	mirror.bottom_radius = 0.17
	mirror.height = 0.07
	add_recipe_mesh("SextantIndexMirror", mirror, Vector3(0, 2.08, 0.75), Vector3(90, 0, 0), secondary, 0.18, 0.18)
	var wear_sector := BoxMesh.new()
	wear_sector.size = Vector3(0.32, 0.09, 0.13)
	add_recipe_mesh("SextantThirtyDegreeWear", wear_sector, Vector3(0.47, 0.55, 0.85), Vector3(0, 0, 38), Color("#6d8e8d"), 0.12, 0.7)


func add_gauge_overlay(render_dto: Dictionary) -> void:
	var palette_value: Variant = render_dto.get("palette", {})
	var palette: Dictionary = palette_value if palette_value is Dictionary else {}
	var accent := Color(palette.get("accent", "#e2c06f"))
	var secondary := Color(palette.get("secondary", "#345d63"))
	# The reusable gauge mesh is authored in the XZ plane. The GAUGE recipe
	# alone turns its face toward the workshop camera; spec-only/legacy uses of
	# the same baseline model retain their canonical transform.
	if model != null:
		model.rotation_degrees = Vector3(90, 0, 0)
	var dial_center := Vector2(0.0, 1.2)
	var dial_radius := 0.64
	for tick_index in range(13):
		var angle_degrees := -150.0 + tick_index * 25.0
		var angle := deg_to_rad(angle_degrees)
		var tick := BoxMesh.new()
		tick.size = Vector3(0.075, 0.19 if tick_index % 3 == 0 else 0.13, 0.055)
		add_recipe_mesh(
			"GaugeScaleTick_%02d" % tick_index,
			tick,
			Vector3(dial_center.x + cos(angle) * dial_radius, dial_center.y + sin(angle) * dial_radius, 0.91),
			Vector3(0, 0, angle_degrees - 90.0),
			accent if tick_index % 3 == 0 else Color("#e8e1ca"),
			0.42,
			0.3
		)
	var needle := BoxMesh.new()
	needle.size = Vector3(0.54, 0.07, 0.055)
	add_recipe_mesh("GaugePressureNeedle", needle, Vector3(0.21, 1.06, 0.94), Vector3(0, 0, -33), Color("#d96554"), 0.35, 0.28)
	var hub := CylinderMesh.new()
	hub.top_radius = 0.13
	hub.bottom_radius = 0.13
	hub.height = 0.08
	add_recipe_mesh("GaugePressureHub", hub, Vector3(0, 1.2, 0.96), Vector3(90, 0, 0), secondary, 0.62, 0.24)
	var label_plate := BoxMesh.new()
	label_plate.size = Vector3(0.5, 0.16, 0.06)
	add_recipe_mesh("GaugeCalibrationPlate", label_plate, Vector3(0, 0.83, 0.93), Vector3.ZERO, Color("#f0e4bd"), 0.18, 0.48)
	var seal := SphereMesh.new()
	seal.radius = 0.09
	seal.height = 0.07
	add_recipe_mesh("GaugeCalibrationSeal", seal, Vector3(0.48, 0.75, 0.96), Vector3(90, 0, 0), accent, 0.5, 0.34)


func add_chronometer_overlay(render_dto: Dictionary) -> void:
	var palette_value: Variant = render_dto.get("palette", {})
	var palette: Dictionary = palette_value if palette_value is Dictionary else {}
	var accent := Color(palette.get("accent", "#d8b56a"))
	var secondary := Color(palette.get("secondary", "#47352b"))
	var dial := CylinderMesh.new()
	dial.top_radius = 0.58
	dial.bottom_radius = 0.58
	dial.height = 0.08
	add_recipe_mesh("ChronometerDial", dial, Vector3(0, 1.34, 0.86), Vector3(90, 0, 0), Color("#f0e6c8"), 0.22, 0.34)
	for tick_index in range(12):
		var angle_degrees := float(tick_index) * 30.0
		var angle := deg_to_rad(angle_degrees)
		var tick := BoxMesh.new()
		tick.size = Vector3(0.06, 0.16 if tick_index % 3 == 0 else 0.10, 0.045)
		add_recipe_mesh(
			"ChronometerHourMark_%02d" % tick_index,
			tick,
			Vector3(cos(angle) * 0.46, 1.34 + sin(angle) * 0.46, 0.93),
			Vector3(0, 0, angle_degrees),
			accent if tick_index % 3 == 0 else secondary,
			0.5,
			0.28
		)
	var minute_hand := BoxMesh.new()
	minute_hand.size = Vector3(0.06, 0.40, 0.045)
	add_recipe_mesh("ChronometerMinuteHand", minute_hand, Vector3(0.0, 1.47, 0.96), Vector3(0, 0, -24), secondary, 0.4, 0.3)
	var second_hand := BoxMesh.new()
	second_hand.size = Vector3(0.035, 0.48, 0.035)
	add_recipe_mesh("ChronometerSecondHand", second_hand, Vector3(0.18, 1.34, 0.98), Vector3(0, 0, 68), Color("#b64f48"), 0.35, 0.3)
	var jewel := SphereMesh.new()
	jewel.radius = 0.075
	jewel.height = 0.15
	for jewel_index in range(3):
		add_recipe_mesh("ChronometerEscapementJewel_%02d" % jewel_index, jewel, Vector3(-0.38 + jewel_index * 0.38, 0.93, 0.98), Vector3(90, 0, 0), Color("#75c3c8"), 0.15, 0.18)
	var crown := CylinderMesh.new()
	crown.top_radius = 0.11
	crown.bottom_radius = 0.11
	crown.height = 0.18
	add_recipe_mesh("ChronometerWindingCrown", crown, Vector3(0.76, 1.77, 0.18), Vector3(0, 0, 90), accent, 0.66, 0.26)


func add_microscope_overlay(render_dto: Dictionary) -> void:
	var palette_value: Variant = render_dto.get("palette", {})
	var palette: Dictionary = palette_value if palette_value is Dictionary else {}
	var primary := Color(palette.get("primary", "#476e6a"))
	var secondary := Color(palette.get("secondary", "#283f4c"))
	var accent := Color(palette.get("accent", "#d7c7a1"))
	# artifact_075 retains binoculars.obj as a legacy resource reference, but
	# the fresh Stage 8 pair is a microscope and must not render as binoculars.
	if model != null:
		model.visible = false
	var base := BoxMesh.new()
	base.size = Vector3(1.48, 0.22, 0.82)
	add_recipe_mesh("MicroscopeWeightedBase", base, Vector3(0, 0.54, 0.04), Vector3.ZERO, secondary, 0.48, 0.44)
	var column := BoxMesh.new()
	column.size = Vector3(0.18, 1.15, 0.22)
	add_recipe_mesh("MicroscopeColumn", column, Vector3(0.48, 1.10, 0.04), Vector3(0, 0, -8), secondary, 0.52, 0.38)
	var arm := BoxMesh.new()
	arm.size = Vector3(1.10, 0.18, 0.23)
	add_recipe_mesh("MicroscopeArm", arm, Vector3(0.05, 1.64, 0.04), Vector3(0, 0, -8), primary, 0.46, 0.34)
	var head := CylinderMesh.new()
	head.top_radius = 0.30
	head.bottom_radius = 0.34
	head.height = 0.42
	add_recipe_mesh("MicroscopeOpticalHead", head, Vector3(-0.40, 1.67, 0.05), Vector3(0, 0, 90), accent, 0.62, 0.24)
	var eyepiece := CylinderMesh.new()
	eyepiece.top_radius = 0.16
	eyepiece.bottom_radius = 0.20
	eyepiece.height = 0.42
	add_recipe_mesh("MicroscopeEyepiece", eyepiece, Vector3(-0.68, 1.67, 0.05), Vector3(0, 0, 90), secondary, 0.5, 0.3)
	var objective := CylinderMesh.new()
	objective.top_radius = 0.10
	objective.bottom_radius = 0.14
	objective.height = 0.44
	add_recipe_mesh("MicroscopeObjective", objective, Vector3(-0.24, 1.34, 0.12), Vector3.ZERO, accent, 0.58, 0.26)
	var stage := BoxMesh.new()
	stage.size = Vector3(0.86, 0.10, 0.56)
	add_recipe_mesh("MicroscopeStage", stage, Vector3(-0.05, 1.05, 0.05), Vector3.ZERO, Color("#e8dfc0"), 0.35, 0.34)
	var lens := CylinderMesh.new()
	lens.top_radius = 0.23
	lens.bottom_radius = 0.23
	lens.height = 0.05
	add_recipe_mesh("MicroscopeStageLens", lens, Vector3(-0.05, 1.12, 0.34), Vector3(90, 0, 0), Color("#79c7c7"), 0.08, 0.14)
	var focus := TorusMesh.new()
	focus.inner_radius = 0.18
	focus.outer_radius = 0.25
	add_recipe_mesh("MicroscopeFocusWheel", focus, Vector3(0.34, 1.34, 0.12), Vector3(90, 0, 0), accent, 0.62, 0.25)


func add_wire_recorder_overlay(render_dto: Dictionary) -> void:
	var palette_value: Variant = render_dto.get("palette", {})
	var palette: Dictionary = palette_value if palette_value is Dictionary else {}
	var primary := Color(palette.get("primary", "#724b31"))
	var secondary := Color(palette.get("secondary", "#596267"))
	var accent := Color(palette.get("accent", "#b47a45"))
	# model_02 is retained as the stable DTO mesh reference, but its generic
	# silhouette is hidden so the fresh Stage 9 case reads as a wire recorder.
	if model != null:
		model.visible = false
	var body := BoxMesh.new()
	body.size = Vector3(1.52, 0.78, 0.86)
	add_recipe_mesh("WireRecorderLeatherBody", body, Vector3(0, 1.02, 0.04), Vector3.ZERO, primary, 0.14, 0.72)
	var top := BoxMesh.new()
	top.size = Vector3(1.35, 0.12, 0.76)
	add_recipe_mesh("WireRecorderTopPlate", top, Vector3(0, 1.46, 0.06), Vector3(0, 0, -4), primary.lightened(0.08), 0.18, 0.64)
	var front_plate := BoxMesh.new()
	front_plate.size = Vector3(1.25, 0.56, 0.08)
	add_recipe_mesh("WireRecorderFrontPlate", front_plate, Vector3(0, 1.12, 0.52), Vector3.ZERO, secondary, 0.62, 0.3)
	for reel_index in range(2):
		var reel := CylinderMesh.new()
		reel.top_radius = 0.27
		reel.bottom_radius = 0.27
		reel.height = 0.10
		var reel_x := -0.36 if reel_index == 0 else 0.36
		add_recipe_mesh("WireRecorderReel_%d" % (reel_index + 1), reel, Vector3(reel_x, 1.16, 0.60), Vector3(90, 0, 0), accent if reel_index == 0 else secondary.lightened(0.18), 0.58, 0.28)
		var hub := CylinderMesh.new()
		hub.top_radius = 0.075
		hub.bottom_radius = 0.075
		hub.height = 0.12
		add_recipe_mesh("WireRecorderReelHub_%d" % (reel_index + 1), hub, Vector3(reel_x, 1.16, 0.67), Vector3(90, 0, 0), Color("#e5d5aa"), 0.42, 0.3)
	var spindle := CylinderMesh.new()
	spindle.top_radius = 0.06
	spindle.bottom_radius = 0.06
	spindle.height = 0.76
	add_recipe_mesh("WireRecorderTakeupSpindle", spindle, Vector3(0, 1.16, 0.70), Vector3(0, 90, 0), accent, 0.62, 0.24)
	var strap := BoxMesh.new()
	strap.size = Vector3(0.16, 0.7, 0.09)
	add_recipe_mesh("WireRecorderCaseStrap", strap, Vector3(0.59, 1.06, 0.50), Vector3(0, 0, -5), primary.darkened(0.18), 0.12, 0.76)


func add_signal_lantern_overlay(render_dto: Dictionary) -> void:
	var palette_value: Variant = render_dto.get("palette", {})
	var palette: Dictionary = palette_value if palette_value is Dictionary else {}
	var primary := Color(palette.get("primary", "#244e43"))
	var secondary := Color(palette.get("secondary", "#8a1f26"))
	var accent := Color(palette.get("accent", "#d4b64c"))
	# telephone.obj is only the stable legacy resource reference. Hide it and
	# build a readable two-lens railway signal lantern from local primitives.
	if model != null:
		model.visible = false
	var body := CylinderMesh.new()
	body.top_radius = 0.52
	body.bottom_radius = 0.64
	body.height = 0.92
	add_recipe_mesh("SignalLanternEnamelBody", body, Vector3(0, 1.05, 0.04), Vector3.ZERO, primary, 0.42, 0.38)
	var base := CylinderMesh.new()
	base.top_radius = 0.68
	base.bottom_radius = 0.72
	base.height = 0.14
	add_recipe_mesh("SignalLanternBase", base, Vector3(0, 0.56, 0.04), Vector3.ZERO, accent, 0.62, 0.26)
	var crown := CylinderMesh.new()
	crown.top_radius = 0.28
	crown.bottom_radius = 0.56
	crown.height = 0.30
	add_recipe_mesh("SignalLanternVentedCrown", crown, Vector3(0, 1.68, 0.04), Vector3.ZERO, accent, 0.68, 0.24)
	var handle := TorusMesh.new()
	handle.inner_radius = 0.27
	handle.outer_radius = 0.36
	add_recipe_mesh("SignalLanternHandle", handle, Vector3(0, 1.95, 0.08), Vector3(90, 0, 0), accent, 0.68, 0.23)
	for lens_index in range(2):
		var lens := CylinderMesh.new()
		lens.top_radius = 0.27
		lens.bottom_radius = 0.27
		lens.height = 0.08
		var lens_x := -0.28 if lens_index == 0 else 0.28
		add_recipe_mesh("SignalLanternLens_%d" % (lens_index + 1), lens, Vector3(lens_x, 1.12, 0.60), Vector3(90, 0, 0), secondary if lens_index == 0 else Color("#75c88b"), 0.12, 0.18)
		var rim := TorusMesh.new()
		rim.inner_radius = 0.27
		rim.outer_radius = 0.32
		add_recipe_mesh("SignalLanternLensRim_%d" % (lens_index + 1), rim, Vector3(lens_x, 1.12, 0.65), Vector3(90, 0, 0), accent, 0.64, 0.24)
	for vent_index in range(3):
		var vent := BoxMesh.new()
		vent.size = Vector3(0.58, 0.055, 0.08)
		add_recipe_mesh("SignalLanternVent_%d" % (vent_index + 1), vent, Vector3(0, 1.54 + vent_index * 0.08, 0.28), Vector3(0, 0, 0), secondary, 0.42, 0.3)


func add_spectroscope_overlay(render_dto: Dictionary) -> void:
	var palette_value: Variant = render_dto.get("palette", {})
	var palette: Dictionary = palette_value if palette_value is Dictionary else {}
	var primary := Color(palette.get("primary", "#83b8c2"))
	var secondary := Color(palette.get("secondary", "#2a2e38"))
	var accent := Color(palette.get("accent", "#c99b50"))
	# The model_05 resource is retained for stable authored DTOs, while the
	# pair renderer builds the compact prism instrument that the case names.
	if model != null:
		model.visible = false
	var base := BoxMesh.new()
	base.size = Vector3(1.62, 0.18, 0.72)
	add_recipe_mesh("SpectroscopeWeightedBase", base, Vector3(0, 0.58, 0.04), Vector3.ZERO, secondary, 0.48, 0.42)
	var body := BoxMesh.new()
	body.size = Vector3(1.12, 0.72, 0.54)
	add_recipe_mesh("SpectroscopeOpticalBody", body, Vector3(0.05, 1.05, 0.04), Vector3(0, 0, -8), primary.lightened(0.18), 0.22, 0.44)
	var prism := CylinderMesh.new()
	prism.top_radius = 0.29
	prism.bottom_radius = 0.29
	prism.height = 0.42
	var prism_node := add_recipe_mesh("SpectroscopeGlassPrism", prism, Vector3(-0.18, 1.48, 0.08), Vector3(90, 0, 0), Color("#d7ffff"), 0.08, 0.12)
	var prism_material := prism_node.material_override as StandardMaterial3D
	if prism_material != null:
		prism_material.emission_enabled = true
		prism_material.emission = Color("#5bd9e4")
		prism_material.emission_energy_multiplier = 0.38
	var prism_core := BoxMesh.new()
	prism_core.size = Vector3(0.28, 0.38, 0.12)
	var prism_core_node := add_recipe_mesh("SpectroscopePrismCore", prism_core, Vector3(-0.18, 1.48, 0.88), Vector3(0, 0, 18), Color("#a8f7fa"), 0.04, 0.1)
	var prism_core_material := prism_core_node.material_override as StandardMaterial3D
	if prism_core_material != null:
		prism_core_material.emission_enabled = true
		prism_core_material.emission = Color("#54dbe6")
		prism_core_material.emission_energy_multiplier = 0.52
	var prism_clamp := TorusMesh.new()
	prism_clamp.inner_radius = 0.28
	prism_clamp.outer_radius = 0.34
	add_recipe_mesh("SpectroscopePrismClamp", prism_clamp, Vector3(-0.18, 1.48, 0.83), Vector3(90, 0, 0), accent, 0.68, 0.22)
	# Three short high-contrast spectral bars make the prism readable at the
	# actual 1280x720 inspection scale instead of blending into the workbench.
	var spectral_colors := [Color("#68e4ef"), Color("#f3d36b"), Color("#e58bb9")]
	for beam_index in range(3):
		var beam := BoxMesh.new()
		beam.size = Vector3(0.075, 0.34, 0.045)
		var beam_node := add_recipe_mesh(
			"SpectroscopeSpectralBar_%d" % beam_index,
			beam,
				Vector3(-0.30 + beam_index * 0.12, 1.50, 0.96),
			Vector3(0, 0, -20.0 + beam_index * 20.0),
			spectral_colors[beam_index],
			0.08,
			0.18
		)
		var beam_material := beam_node.material_override as StandardMaterial3D
		if beam_material != null:
			beam_material.emission_enabled = true
			beam_material.emission = spectral_colors[beam_index]
			beam_material.emission_energy_multiplier = 0.32
	var eyepiece := CylinderMesh.new()
	eyepiece.top_radius = 0.16
	eyepiece.bottom_radius = 0.21
	eyepiece.height = 0.42
	add_recipe_mesh("SpectroscopeEyepiece", eyepiece, Vector3(0.70, 1.18, 0.04), Vector3(0, 0, 90), secondary, 0.48, 0.34)
	var adjustment := CylinderMesh.new()
	adjustment.top_radius = 0.10
	adjustment.bottom_radius = 0.10
	adjustment.height = 0.32
	add_recipe_mesh("SpectroscopeAdjustmentKnob", adjustment, Vector3(0.38, 1.58, 0.04), Vector3(0, 0, 90), accent, 0.6, 0.26)


func add_astronomical_regulator_overlay(render_dto: Dictionary) -> void:
	var palette_value: Variant = render_dto.get("palette", {})
	var palette: Dictionary = palette_value if palette_value is Dictionary else {}
	var primary := Color(palette.get("primary", "#69452f"))
	var secondary := Color(palette.get("secondary", "#2d3e4c"))
	var accent := Color(palette.get("accent", "#c6a56a"))
	# watch.obj is a legacy mechanical reference; suppress it so the final lot
	# reads as a tall observatory regulator rather than a pocket watch.
	if model != null:
		model.visible = false
	var case_body := BoxMesh.new()
	case_body.size = Vector3(1.18, 1.72, 0.46)
	add_recipe_mesh("RegulatorObservatoryCase", case_body, Vector3(0, 1.28, 0.02), Vector3.ZERO, primary, 0.2, 0.52)
	var crown := BoxMesh.new()
	crown.size = Vector3(1.38, 0.16, 0.56)
	add_recipe_mesh("RegulatorCrown", crown, Vector3(0, 2.18, 0.02), Vector3.ZERO, accent, 0.58, 0.26)
	var dial := CylinderMesh.new()
	dial.top_radius = 0.38
	dial.bottom_radius = 0.38
	dial.height = 0.08
	add_recipe_mesh("RegulatorDial", dial, Vector3(0, 1.72, 0.30), Vector3(90, 0, 0), Color("#eee2bd"), 0.18, 0.34)
	for tick_index in range(8):
		var angle_degrees := float(tick_index) * 45.0
		var angle := deg_to_rad(angle_degrees)
		var tick := BoxMesh.new()
		tick.size = Vector3(0.045, 0.13 if tick_index % 2 == 0 else 0.09, 0.035)
		add_recipe_mesh("RegulatorHourMark_%02d" % tick_index, tick, Vector3(cos(angle) * 0.29, 1.72 + sin(angle) * 0.29, 0.37), Vector3(0, 0, angle_degrees), secondary, 0.38, 0.3)
	var pendulum := CylinderMesh.new()
	pendulum.top_radius = 0.08
	pendulum.bottom_radius = 0.08
	pendulum.height = 0.76
	add_recipe_mesh("RegulatorPendulumRod", pendulum, Vector3(0, 0.90, 0.28), Vector3.ZERO, accent, 0.62, 0.24)
	var pendulum_bob := SphereMesh.new()
	pendulum_bob.radius = 0.19
	pendulum_bob.height = 0.16
	add_recipe_mesh("RegulatorPendulumBob", pendulum_bob, Vector3(0, 0.54, 0.28), Vector3(90, 0, 0), accent, 0.62, 0.24)
	var foot := BoxMesh.new()
	foot.size = Vector3(1.48, 0.16, 0.62)
	add_recipe_mesh("RegulatorFoot", foot, Vector3(0, 0.34, 0.02), Vector3.ZERO, secondary, 0.44, 0.42)


func add_music_box_overlay(render_dto: Dictionary) -> void:
	var palette_value: Variant = render_dto.get("palette", {})
	var palette: Dictionary = palette_value if palette_value is Dictionary else {}
	var accent := Color(palette.get("accent", "#e1bd66"))
	var secondary := Color(palette.get("secondary", "#704a32"))
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.14
	cylinder.bottom_radius = 0.14
	cylinder.height = 1.15
	add_recipe_mesh("MusicBoxPinnedCylinder", cylinder, Vector3(-0.15, 1.58, 0.91), Vector3(0, 0, 90), accent, 0.68, 0.26)
	for pin_index in range(8):
		var pin := SphereMesh.new()
		pin.radius = 0.035
		pin.height = 0.07
		add_recipe_mesh(
			"MusicBoxCylinderPin_%02d" % pin_index,
			pin,
			Vector3(-0.62 + pin_index * 0.135, 1.58 + (0.055 if pin_index % 2 == 0 else -0.035), 1.07),
			Vector3.ZERO,
			Color("#f1df9e"),
			0.62,
			0.24
		)
	var comb_back := BoxMesh.new()
	comb_back.size = Vector3(1.05, 0.17, 0.07)
	add_recipe_mesh("MusicBoxComb", comb_back, Vector3(-0.08, 1.27, 0.94), Vector3.ZERO, Color("#d7d9cf"), 0.7, 0.22)
	for tooth_index in range(7):
		var tooth := BoxMesh.new()
		tooth.size = Vector3(0.07, 0.25 - tooth_index * 0.012, 0.045)
		add_recipe_mesh(
			"MusicBoxCombTooth_%02d" % tooth_index,
			tooth,
			Vector3(-0.47 + tooth_index * 0.13, 1.09 + tooth_index * 0.006, 0.99),
			Vector3.ZERO,
			Color("#ece8d6"),
			0.72,
			0.2
		)
	var key_stem := BoxMesh.new()
	key_stem.size = Vector3(0.42, 0.07, 0.07)
	add_recipe_mesh("MusicBoxWindingStem", key_stem, Vector3(1.25, 0.76, 0.15), Vector3(0, 0, 90), accent, 0.6, 0.28)
	var key_ring := TorusMesh.new()
	key_ring.inner_radius = 0.09
	key_ring.outer_radius = 0.16
	add_recipe_mesh("MusicBoxWindingKey", key_ring, Vector3(1.25, 0.98, 0.15), Vector3(90, 0, 0), accent, 0.6, 0.28)
	var inlay := BoxMesh.new()
	inlay.size = Vector3(0.72, 0.08, 0.28)
	add_recipe_mesh("MusicBoxLidInlay", inlay, Vector3(0.0, 1.76, 0.18), Vector3.ZERO, secondary, 0.18, 0.52)


func add_optic_overlay(render_dto: Dictionary) -> void:
	var palette_value: Variant = render_dto.get("palette", {})
	var palette: Dictionary = palette_value if palette_value is Dictionary else {}
	var primary := Color(palette.get("primary", "#7d3e2f"))
	var secondary := Color(palette.get("secondary", "#294b54"))
	var accent := Color(palette.get("accent", "#d7c7a1"))
	# model_12 is a legacy gauge silhouette. It remains the exact pair DTO mesh
	# for save/schema stability, but cannot dominate the fresh telescope read.
	if model != null:
		model.visible = false
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.28
	barrel.bottom_radius = 0.31
	barrel.height = 2.15
	add_recipe_mesh("OpticTelescopeBarrel", barrel, Vector3(0, 1.48, 0.12), Vector3(0, 0, 90), primary, 0.58, 0.3)
	var objective_housing := CylinderMesh.new()
	objective_housing.top_radius = 0.42
	objective_housing.bottom_radius = 0.42
	objective_housing.height = 0.32
	add_recipe_mesh("OpticObjectiveHousing", objective_housing, Vector3(-1.16, 1.48, 0.12), Vector3(0, 0, 90), accent, 0.72, 0.23)
	var objective_lens := SphereMesh.new()
	objective_lens.radius = 0.29
	objective_lens.height = 0.16
	add_recipe_mesh("OpticObjectiveLens", objective_lens, Vector3(-1.34, 1.48, 0.18), Vector3(0, 0, 90), Color("#75c3c8"), 0.08, 0.12)
	var eyepiece := CylinderMesh.new()
	eyepiece.top_radius = 0.17
	eyepiece.bottom_radius = 0.22
	eyepiece.height = 0.4
	add_recipe_mesh("OpticEyepiece", eyepiece, Vector3(1.25, 1.48, 0.12), Vector3(0, 0, 90), secondary, 0.42, 0.34)
	var focus_collar := TorusMesh.new()
	focus_collar.inner_radius = 0.27
	focus_collar.outer_radius = 0.37
	add_recipe_mesh("OpticFocusCollar", focus_collar, Vector3(0.52, 1.48, 0.12), Vector3(0, 0, 90), accent, 0.68, 0.24)
	var yoke := BoxMesh.new()
	yoke.size = Vector3(1.02, 0.16, 0.34)
	add_recipe_mesh("OpticMountingYoke", yoke, Vector3(0, 1.04, 0.08), Vector3.ZERO, secondary, 0.5, 0.38)
	for support_index in range(2):
		var support := BoxMesh.new()
		support.size = Vector3(0.13, 0.55, 0.18)
		add_recipe_mesh(
			"OpticYokeSupport_%02d" % (support_index + 1),
			support,
			Vector3(-0.4 + support_index * 0.8, 0.82, 0.08),
			Vector3(0, 0, -8 if support_index == 0 else 8),
			secondary,
			0.48,
			0.4
		)
	var support_foot := BoxMesh.new()
	support_foot.size = Vector3(1.35, 0.16, 0.62)
	add_recipe_mesh("OpticSupportFoot", support_foot, Vector3(0, 0.5, 0.02), Vector3.ZERO, primary.darkened(0.18), 0.34, 0.5)
	var optical_axis := BoxMesh.new()
	optical_axis.size = Vector3(2.82, 0.035, 0.035)
	add_recipe_mesh("OpticOpticalAxis", optical_axis, Vector3(-0.02, 1.48, 0.49), Vector3.ZERO, Color("#a8edf0"), 0.05, 0.16)


func add_composite_overlay(render_dto: Dictionary) -> void:
	var palette_value: Variant = render_dto.get("palette", {})
	var palette: Dictionary = palette_value if palette_value is Dictionary else {}
	var primary := Color(palette.get("primary", "#a5774f"))
	var secondary := Color(palette.get("secondary", "#394b55"))
	var accent := Color(palette.get("accent", "#7f8b91"))
	# model_14 is an ordinary camera. The pair keeps that canonical resource
	# reference but suppresses it so the fresh case reads as a hybrid measuring
	# prototype instead of a recolored film camera.
	if model != null:
		model.visible = false
	var main_body := BoxMesh.new()
	main_body.size = Vector3(1.58, 1.02, 0.68)
	add_recipe_mesh("CompositeMainMeasuringBody", main_body, Vector3(-0.28, 1.14, 0.05), Vector3.ZERO, primary, 0.24, 0.52)
	var dial := CylinderMesh.new()
	dial.top_radius = 0.36
	dial.bottom_radius = 0.36
	dial.height = 0.09
	add_recipe_mesh("CompositeGraduatedDial", dial, Vector3(-0.55, 1.37, 0.46), Vector3(90, 0, 0), Color("#eee1bd"), 0.2, 0.32)
	var dial_center := Vector2(-0.55, 1.37)
	for tick_index in range(11):
		var angle_degrees := -140.0 + tick_index * 28.0
		var angle := deg_to_rad(angle_degrees)
		var tick := BoxMesh.new()
		tick.size = Vector3(0.035, 0.1 if tick_index % 2 == 0 else 0.07, 0.03)
		add_recipe_mesh(
			"CompositeScaleTick_%02d" % tick_index,
			tick,
			Vector3(dial_center.x + cos(angle) * 0.27, dial_center.y + sin(angle) * 0.27, 0.54),
			Vector3(0, 0, angle_degrees - 90.0),
			secondary,
			0.32,
			0.32
		)
	var needle := BoxMesh.new()
	needle.size = Vector3(0.31, 0.045, 0.035)
	add_recipe_mesh("CompositeMeasurementNeedle", needle, Vector3(-0.43, 1.31, 0.57), Vector3(0, 0, -28), Color("#c94f48"), 0.28, 0.3)
	var secondary_component := CylinderMesh.new()
	secondary_component.top_radius = 0.25
	secondary_component.bottom_radius = 0.31
	secondary_component.height = 0.82
	add_recipe_mesh("CompositeSecondaryComponent", secondary_component, Vector3(0.83, 1.28, 0.08), Vector3.ZERO, secondary, 0.62, 0.26)
	var secondary_cap := SphereMesh.new()
	secondary_cap.radius = 0.25
	secondary_cap.height = 0.18
	add_recipe_mesh("CompositeSecondaryComponentCap", secondary_cap, Vector3(0.83, 1.73, 0.09), Vector3.ZERO, accent, 0.54, 0.28)
	var adapter := TorusMesh.new()
	adapter.inner_radius = 0.19
	adapter.outer_radius = 0.31
	add_recipe_mesh("CompositeAdapterInterfaceJoint", adapter, Vector3(0.43, 1.25, 0.12), Vector3(0, 0, 90), Color("#d0b35f"), 0.72, 0.24)
	var connector := BoxMesh.new()
	connector.size = Vector3(0.54, 0.17, 0.2)
	add_recipe_mesh("CompositeMismatchedConnector", connector, Vector3(0.38, 0.95, 0.43), Vector3(0, 0, -17), Color("#798f96"), 0.7, 0.26)
	for fastener_index in range(3):
		var fastener := SphereMesh.new()
		fastener.radius = 0.07 if fastener_index != 1 else 0.09
		fastener.height = 0.08
		add_recipe_mesh(
			"CompositeMismatchedFastener_%02d" % (fastener_index + 1),
			fastener,
			Vector3(0.18 + fastener_index * 0.2, 0.91 + (0.05 if fastener_index == 1 else 0.0), 0.56),
			Vector3(90, 0, 0),
			Color("#b95b42") if fastener_index == 1 else accent,
			0.58,
			0.3
		)


func add_damage_visuals(artifact: Dictionary) -> void:
	for index in range(artifact.damageInstances.size()):
		var damage: String = artifact.damageInstances[index]
		var marker := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.085
		sphere.height = 0.17
		marker.mesh = sphere
		marker.position = Vector3(-0.72 + (index % 7) * 0.23, 1.78 - (index / 7) * 0.22, 0.73)
		marker.material_override = make_material(Color("#a52f25") if damage in ["RUST", "CRACK", "PAINT_LOSS", "SCRATCH"] else Color("#42372f"), 0.05, 0.85)
		marker.name = "Damage_%s_%02d" % [damage, index]
		workpiece_root.add_child(marker)
		damage_marks.append(marker)


func add_part_nodes(artifact: Dictionary) -> void:
	var operations := RuntimeRegistry.supported_operations(artifact.artifactSpecId)
	if not bool(operations.get("disassembly", false)):
		return
	var family: String = operations.part_family
	for part_name: String in operations.parts:
		var resource := load("res://assets/artifacts/parts/%s_%s.obj" % [family, part_name])
		if resource is Mesh:
			var instance := MeshInstance3D.new()
			instance.name = "Part_%s" % part_name
			instance.mesh = resource
			instance.position = Vector3(0, 1.0, 0)
			instance.visible = bool(artifact.partStates.get(part_name, true))
			instance.material_override = make_material(Color("#d0a14d"), 0.4, 0.48)
			workpiece_root.add_child(instance)
			parts[part_name] = instance


func update_camera() -> void:
	camera.position = Vector3(sin(orbit.x) * distance, 2.2 + orbit.y, distance * cos(orbit.x))
	camera.look_at(Vector3(0, 1.2, 0), Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if screen == "inspection" and event is InputEventMouseMotion and dragging:
		orbit.x -= event.relative.x * 0.01
		orbit.y = clampf(orbit.y + event.relative.y * 0.01, -1.0, 1.0)
		update_camera()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(3.0, distance - 0.4)
			update_camera()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(10.0, distance + 0.4)
			update_camera()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and screen != "title":
		show_workshop()


func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.name = "R3Interface"
	ui.position = Vector2.ZERO
	ui.size = Vector2(1280, 720)
	layer.add_child(ui)


func load_player_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PLAYER_SETTINGS_PATH) != OK:
		return
	master_volume_db = clampf(float(config.get_value("audio", "master_db", 0.0)), -80.0, 0.0)
	bgm_volume_db = clampf(float(config.get_value("audio", "music_db", -14.0)), -80.0, 0.0)
	sfx_volume_db = clampf(float(config.get_value("audio", "effects_db", -4.0)), -80.0, 0.0)
	ui_text_scale = clampf(float(config.get_value("accessibility", "text_scale", 1.0)), 1.0, 1.16)
	reduced_motion = bool(config.get_value("accessibility", "reduced_motion", false))


func save_player_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value("audio", "master_db", master_volume_db)
	config.set_value("audio", "music_db", bgm_volume_db)
	config.set_value("audio", "effects_db", sfx_volume_db)
	config.set_value("accessibility", "text_scale", ui_text_scale)
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	return config.save(PLAYER_SETTINGS_PATH) == OK


func apply_player_settings() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, master_volume_db)
		AudioServer.set_bus_mute(master_bus, master_volume_db <= -79.0)
	var bgm_bus := AudioServer.get_bus_index("BGM")
	if bgm_bus >= 0:
		AudioServer.set_bus_volume_db(bgm_bus, bgm_volume_db)
		AudioServer.set_bus_mute(bgm_bus, bgm_volume_db <= -79.0)
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, sfx_volume_db)
		AudioServer.set_bus_mute(sfx_bus, sfx_volume_db <= -79.0)


func scaled_font_size(base_size: int) -> int:
	return maxi(1, roundi(float(base_size) * ui_text_scale))


func text_for(key: String) -> String:
	return RuntimeRegistry.tr_key(language, key)


func localized_value(value: Variant) -> String:
	if value is Dictionary:
		return String(value.get(language, value.get("en", value.values()[0] if not value.is_empty() else "")))
	var raw := String(value)
	return RuntimeRegistry.tr_key(language, raw)


func bilingual(en_text: String, ko_text: String) -> String:
	return ko_text if language == "ko" else en_text


func text_format(key: String, values: Array = []) -> String:
	return text_for(key) % values


func clear_ui() -> void:
	tutorial_render_serial += 1
	tutorial_guidance_state = {}
	tutorial_target_control = null
	for child: Node in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	hypothesis_buttons.clear()
	hypothesis_accept_button = null
	content_root = null
	status = null


func make_label(text_value: String, font_size: int = 18, color: Color = Color("#f2e8cf")) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", scaled_font_size(font_size))
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func make_button(text_value: String, callback: Callable, node_name: String = "") -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(120, 42)
	button.add_theme_font_size_override("font_size", scaled_font_size(15))
	button.add_theme_color_override("font_color", Color("#e9e3d5"))
	button.add_theme_color_override("font_hover_color", Color("#fff4d6"))
	button.add_theme_color_override("font_pressed_color", Color("#f4ddb0"))
	button.add_theme_color_override("font_disabled_color", Color("#727c7a"))
	button.add_theme_stylebox_override("normal", case_panel_style(Color("#131b1ee8"), Color("#465653")))
	button.add_theme_stylebox_override("hover", case_panel_style(Color("#1d2b2be8"), Color("#9fd6bd"), 2))
	button.add_theme_stylebox_override("focus", case_panel_style(Color("#1b2728ed"), Color("#e3c681"), 2))
	button.add_theme_stylebox_override("pressed", case_panel_style(Color("#24352fed"), Color("#d1b66f"), 2))
	button.add_theme_stylebox_override("disabled", case_panel_style(Color("#111719b8"), Color("#303b3a")))
	if not node_name.is_empty():
		button.name = node_name
	button.pressed.connect(func() -> void:
		play_sfx("ui_click")
		callback.call()
	)
	return button


func make_compact_navigation_button(text_value: String, callback: Callable, node_name: String, icon_name: String = "objective") -> TextureButton:
	# TextureButton keeps the route keyboard-focusable while allowing one compact
	# icon-and-label control to coexist with the dense authentication decision grid.
	var button := TextureButton.new()
	button.name = node_name
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(120, 42)
	button.tooltip_text = text_value
	button.pressed.connect(func() -> void:
		play_sfx("ui_click")
		callback.call()
	)
	var face := PanelContainer.new()
	face.name = "CompactNavFace"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.add_theme_stylebox_override("panel", case_panel_style(Color("#131b1ee8"), Color("#465653")))
	button.add_child(face)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7)
	face.add_child(row)
	var icon := TextureRect.new()
	icon.texture = case_icon(icon_name)
	icon.custom_minimum_size = Vector2(22, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := RichTextLabel.new()
	label.name = "CompactNavLabel"
	label.text = text_value
	label.bbcode_enabled = false
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(34, 22)
	label.add_theme_font_size_override("normal_font_size", scaled_font_size(13))
	label.add_theme_color_override("default_color", Color("#e9e3d5"))
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	button.set_meta("compact_face", face)
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			face.add_theme_stylebox_override("panel", case_panel_style(Color("#1d2b2be8"), Color("#9fd6bd"), 2))
	)
	button.mouse_exited.connect(func() -> void:
		face.add_theme_stylebox_override("panel", case_panel_style(Color("#111719b8"), Color("#303b3a")) if button.disabled else case_panel_style(Color("#131b1ee8"), Color("#465653")))
	)
	button.focus_entered.connect(func() -> void:
		if not button.disabled:
			face.add_theme_stylebox_override("panel", case_panel_style(Color("#1b2728ed"), Color("#e3c681"), 2))
	)
	button.focus_exited.connect(func() -> void:
		face.add_theme_stylebox_override("panel", case_panel_style(Color("#111719b8"), Color("#303b3a")) if button.disabled else case_panel_style(Color("#131b1ee8"), Color("#465653")))
	)
	return button


func refresh_compact_navigation_button(button: TextureButton) -> void:
	var face_value: Variant = button.get_meta("compact_face", null)
	if face_value is PanelContainer:
		(face_value as PanelContainer).add_theme_stylebox_override("panel", case_panel_style(Color("#111719b8"), Color("#303b3a")) if button.disabled else case_panel_style(Color("#131b1ee8"), Color("#465653")))


func mark_primary_action(button: Button) -> Button:
	# Visual hierarchy only: this never changes the callback, disabled state or
	# authority boundary of the existing commit action.
	button.set_meta("ui_role", "primary")
	button.add_theme_stylebox_override("normal", case_panel_style(Color("#254238"), Color("#e3c681"), 2))
	button.add_theme_stylebox_override("hover", case_panel_style(Color("#315548"), Color("#f2d891"), 2))
	button.add_theme_stylebox_override("pressed", case_panel_style(Color("#1d352d"), Color("#c9ae6d"), 2))
	button.add_theme_stylebox_override("disabled", case_panel_style(Color("#1b2423"), Color("#59635f"), 1))
	button.add_theme_color_override("font_color", Color("#fff4d6"))
	return button


func compact_case_text(value: Variant, max_characters: int = 54) -> String:
	var rendered := localized_value(value).replace("\n", " ").replace("\r", " ").strip_edges()
	while rendered.contains("  "):
		rendered = rendered.replace("  ", " ")
	if rendered.length() <= max_characters:
		return rendered
	return rendered.left(maxi(1, max_characters - 1)).strip_edges() + "…"


func case_icon(icon_name: String) -> Texture2D:
	var resource := load(CASE_ICON_ROOT + icon_name + ".svg")
	return resource if resource is Texture2D else null


func case_panel_style(fill: Color, border: Color = Color("#6e685c"), border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.anti_aliasing = true
	return style


func title_card_style() -> StyleBoxFlat:
	var style := case_panel_style(Color("#101a1bed"), Color("#e3c681"), 2)
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_left = 24
	style.corner_radius_bottom_right = 24
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	style.shadow_color = Color("#00000088")
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 8)
	return style


func make_title_badge(icon_name: String, tint: Color, node_name: String) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.name = node_name
	badge.custom_minimum_size = Vector2(58, 58)
	var style := case_panel_style(Color(tint, 0.18), Color(tint, 0.90), 2)
	style.corner_radius_top_left = 29
	style.corner_radius_top_right = 29
	style.corner_radius_bottom_left = 29
	style.corner_radius_bottom_right = 29
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	badge.add_theme_stylebox_override("panel", style)
	var icon := TextureRect.new()
	icon.texture = case_icon(icon_name)
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(icon)
	return badge


func make_title_character(character_id: String, node_name: String) -> PanelContainer:
	var profile := character_profile(character_id)
	var palette: Array = profile.get("basePalette", ["#e3c681"])
	var accent := Color(String(palette[0])) if not palette.is_empty() else Color("#e3c681")
	var frame := PanelContainer.new()
	frame.name = node_name
	frame.custom_minimum_size = Vector2(128, 168)
	var style := case_panel_style(Color(accent, 0.12), Color(accent, 0.82), 2)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 6
	frame.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	frame.add_child(column)
	var portrait := TextureRect.new()
	portrait.name = "TitleCharacterPortrait"
	portrait.custom_minimum_size = Vector2(112, 130)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var portrait_path := String(profile.get("portraitAssetId", ""))
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path)
	portrait.tooltip_text = localized_value(profile.get("accessibilityLabel", profile.get("displayName", "")))
	portrait.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(portrait)
	var identity_text := localized_value(profile.get("displayName", ""))
	var identity := make_label(identity_text, 12, Color("#f2e8cf"))
	identity.name = "TitleCharacterName"
	identity.tooltip_text = localized_value(profile.get("displayName", ""))
	identity.max_lines_visible = 1
	identity.autowrap_mode = TextServer.AUTOWRAP_OFF
	identity.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(identity)
	return frame


func make_case_tile(icon_name: String, heading: String, value: Variant, tooltip_value: String = "") -> PanelContainer:
	var tile := PanelContainer.new()
	tile.name = "CaseTile_%s" % icon_name
	tile.custom_minimum_size = Vector2(0, 78)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", case_panel_style(Color("#171d21e8"), Color("#75664b")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	tile.add_child(row)
	var icon_rect := TextureRect.new()
	icon_rect.texture = case_icon(icon_name)
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_rect)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	row.add_child(words)
	var heading_label := make_label(heading, 13, Color("#e3c681"))
	heading_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	words.add_child(heading_label)
	var summary := make_label(compact_case_text(value, 42), 14, Color("#e8e0cf"))
	summary.name = "CaseTileSummary_%s" % icon_name
	summary.max_lines_visible = 2
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(summary)
	tile.tooltip_text = tooltip_value if not tooltip_value.is_empty() else localized_value(value)
	return tile


func make_case_icon_button(icon_name: String, text_value: String, callback: Callable, node_name: String, minimum_size := Vector2(120, 64)) -> Button:
	var button := make_button(text_value, callback, node_name)
	button.icon = case_icon(icon_name)
	button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Authored labels are intentionally descriptive, but their intrinsic text
	# width must not widen compact evidence/hypothesis/citation grids past the
	# 1280 target. Preserve the complete accessible copy in each caller's
	# tooltip while the illustrated button respects its data-driven minimum.
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", scaled_font_size(14))
	button.add_theme_constant_override("icon_max_width", 40)
	button.add_theme_stylebox_override("normal", case_panel_style(Color("#151b1fe8"), Color("#5d625f")))
	button.add_theme_stylebox_override("hover", case_panel_style(Color("#222b2fe8"), Color("#e3c681"), 2))
	button.add_theme_stylebox_override("focus", case_panel_style(Color("#20282ce8"), Color("#9fd6bd"), 3))
	button.add_theme_stylebox_override("pressed", case_panel_style(Color("#283236e8"), Color("#e3c681"), 2))
	return button


func load_character_catalog() -> Dictionary:
	if not character_catalog.is_empty():
		return character_catalog
	if not FileAccess.file_exists(CHARACTER_CATALOG_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHARACTER_CATALOG_PATH))
	if parsed is Dictionary:
		character_catalog = parsed
	return character_catalog


func regex_capture(source: String, pattern: String, fallback: String = "") -> String:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return fallback
	var matched := regex.search(source)
	return matched.get_string(1) if matched != null else fallback


func svg_number_list(value: String) -> Array:
	var numbers: Array = []
	for token: String in value.replace(",", " ").split(" ", false):
		if token.is_valid_float():
			numbers.append(float(token))
	return numbers


func portrait_face_render(portrait_path: String) -> Dictionary:
	if portrait_render_cache.has(portrait_path):
		return portrait_render_cache[portrait_path]
	var render := {
		"faceAnchor": [128.0, 136.0], "faceZone": [74.0, 58.0, 108.0, 138.0],
		"skinColor": "#efb287", "inkColor": "#69404a", "scleraColor": "#fff9f1",
		"irisColor": "#8a5c68", "pupilColor": "#352a2d",
		"leftEye": [106.0, 123.0], "rightEye": [150.0, 123.0]
	}
	if portrait_path.is_empty() or not FileAccess.file_exists(portrait_path):
		portrait_render_cache[portrait_path] = render
		return render
	var svg_source := FileAccess.get_file_as_string(portrait_path)
	var anchor_values := svg_number_list(regex_capture(svg_source, "data-expression-anchor=\"([^\"]+)\"", "128,136"))
	var zone_values := svg_number_list(regex_capture(svg_source, "data-face-zone=\"([^\"]+)\"", "74 58 108 138"))
	if anchor_values.size() == 2:
		render.faceAnchor = anchor_values
	if zone_values.size() == 4:
		render.faceZone = zone_values
	render.skinColor = regex_capture(svg_source, "data-part=\"face-shape\"[^>]*fill=\"(#[0-9A-Fa-f]{6})\"", render.skinColor)
	render.inkColor = regex_capture(svg_source, "data-part=\"brows\"[^>]*stroke=\"(#[0-9A-Fa-f]{6})\"", render.inkColor)
	render.scleraColor = regex_capture(svg_source, "data-part=\"sclera\"[^>]*fill=\"(#[0-9A-Fa-f]{6})\"", render.scleraColor)
	render.irisColor = regex_capture(svg_source, "data-part=\"iris\"[^>]*fill=\"(#[0-9A-Fa-f]{6})\"", render.irisColor)
	render.pupilColor = regex_capture(svg_source, "data-part=\"pupil\"[^>]*fill=\"(#[0-9A-Fa-f]{6})\"", render.pupilColor)
	var eye_regex := RegEx.new()
	if eye_regex.compile("data-part=\"sclera\"[^>]*cx=\"([^\"]+)\"[^>]*cy=\"([^\"]+)\"") == OK:
		var eye_matches := eye_regex.search_all(svg_source)
		if eye_matches.size() >= 2:
			render.leftEye = [float(eye_matches[0].get_string(1)), float(eye_matches[0].get_string(2))]
			render.rightEye = [float(eye_matches[1].get_string(1)), float(eye_matches[1].get_string(2))]
	portrait_render_cache[portrait_path] = render
	return render


func character_profile(character_id: String) -> Dictionary:
	for profile: Dictionary in load_character_catalog().get("profiles", []):
		if profile.get("characterId", "") == character_id:
			return profile
	return {}


func auction_bidder_display_name(bidder_id: String, legacy_name: String = "") -> String:
	var profile := character_profile(bidder_id)
	var rendered := localized_value(profile.get("displayName", {}))
	if not rendered.is_empty():
		return rendered
	if language == "en" and not legacy_name.is_empty():
		return legacy_name
	return bilingual("Bidder", "입찰자")


func current_stage_band() -> String:
	var stage_id := clampi(int(GameState.current_stage), 1, 10)
	if stage_id <= 3:
		return "EARLY"
	if stage_id <= 7:
		return "MID"
	return "LATE"


func character_state_label(semantic_state: String) -> String:
	var labels := {
		"INTRO": {"en": "INTRODUCTION", "ko": "경매 시작"},
		"CALL": {"en": "CALLING BIDS", "ko": "호가 진행"},
		"SOLD": {"en": "SOLD", "ko": "낙찰"},
		"NO_SALE": {"en": "NO SALE", "ko": "유찰"},
		"WATCH": {"en": "WATCHING", "ko": "관망"},
		"BID": {"en": "BIDDING", "ko": "입찰"},
		"DROPOUT": {"en": "DROPPED OUT", "ko": "입찰 포기"},
		"WON": {"en": "WINNING BIDDER", "ko": "낙찰자"},
		"WELCOME": {"en": "WELCOME", "ko": "어서 오세요"},
		"OFFER": {"en": "TODAY'S OFFER", "ko": "오늘의 제안"},
		"PURCHASE_OK": {"en": "PURCHASE COMPLETE", "ko": "구매 완료"},
		"PURCHASE_FAIL": {"en": "PURCHASE UNAVAILABLE", "ko": "구매 불가"},
		"REQUEST": {"en": "REQUEST", "ko": "오늘의 사건"},
		"REACTION_POS": {"en": "GOOD RESULT", "ko": "좋은 결과"},
		"REACTION_NEG": {"en": "CAUTION", "ko": "주의 결과"}
	}
	return localized_value(labels.get(semantic_state, {"en": semantic_state.capitalize(), "ko": semantic_state.capitalize()}))


func character_role_label(role: String) -> String:
	var labels := {
		"AUCTIONEER": {"en": "Auction host", "ko": "경매 진행"},
		"BIDDER": {"en": "Bidder", "ko": "입찰자"},
		"SHOPKEEPER": {"en": "Shopkeeper", "ko": "상점 주인"},
		"EVENT": {"en": "Event visitor", "ko": "이벤트 인물"}
	}
	return localized_value(labels.get(role, {"en": role.replace("_", " ").capitalize(), "ko": role.replace("_", " ").capitalize()}))


func stage_band_label(band: String) -> String:
	return localized_value({
		"EARLY": {"en": "EARLY", "ko": "초반"},
		"MID": {"en": "MID", "ko": "중반"},
		"LATE": {"en": "LATE", "ko": "후반"}
	}.get(band, {"en": band.capitalize(), "ko": band.capitalize()}))


func dropout_reason_label(reason: String) -> String:
	return localized_value({
		"BUDGET": {"en": "budget limit", "ko": "예산 한도"},
		"VALUE": {"en": "value limit", "ko": "가치 판단"},
		"AFTER_FIRST_BID": {"en": "one-bid strategy", "ko": "1회 입찰 전략"}
	}.get(reason, {"en": "bid limit", "ko": "입찰 한도"}))


func auction_reason_label(code: String) -> String:
	var labels := {
		"RESERVE_TOO_HIGH": {"en": "High reserve", "ko": "예약가 높음"},
		"PROVENANCE_UNCERTAIN": {"en": "Provenance uncertain", "ko": "출처 불확실"},
		"PROVENANCE_STRONG": {"en": "Provenance strong", "ko": "출처 근거 충분"},
		"CONDITION_RISK": {"en": "Condition risk", "ko": "상태 위험"},
		"CONDITION_GOOD": {"en": "Good condition", "ko": "상태 양호"},
		"DISCLOSURE_UNCLEAR": {"en": "Disclosure mismatch", "ko": "공개 불균형"},
		"DISCLOSURE_CLEAR": {"en": "Disclosure matched", "ko": "공개 균형"},
		"RESERVE_MET": {"en": "Reserve met", "ko": "예약가 충족"},
		"NO_PUBLIC_BID": {"en": "No public bid", "ko": "공개 입찰 없음"}
	}
	return localized_value(labels.get(code, {}))


func make_public_reason_chip(reason_tag: Dictionary, chip_name: String, label_name: String, tooltip_heading: String, minimum_width: float = 116.0) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = chip_name
	# HFlowContainer otherwise uses Label's one-glyph wrap minimum and can
	# collapse a complete reason into an unreadable one-character chip.
	chip.custom_minimum_size = Vector2(minimum_width, 32)
	var positive := String(reason_tag.get("polarity", "")) == "POSITIVE"
	chip.add_theme_stylebox_override("panel", case_panel_style(Color("#19241f") if positive else Color("#281c1a"), Color("#9fd6bd") if positive else Color("#e59b7a")))
	var label_text := auction_reason_label(String(reason_tag.get("code", "")))
	var label := make_label(label_text, 12, Color("#bfe4d2") if positive else Color("#f0b29a"))
	label.name = label_name
	label.max_lines_visible = 1
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_child(label)
	chip.tooltip_text = "%s · %s" % [tooltip_heading, label_text]
	return chip


func make_auction_reason_chip(reason_tag: Dictionary, chip_index: int) -> PanelContainer:
	return make_public_reason_chip(
		reason_tag,
		"AuctionReasonChip_%d" % chip_index,
		"AuctionReasonLabel",
		bilingual("Bidder reaction", "입찰자 반응"),
		132.0
	)


func make_listing_causal_chip(reason_tag: Dictionary, chip_index: int) -> PanelContainer:
	return make_public_reason_chip(
		reason_tag,
		"ListingCausalChip_%d" % chip_index,
		"ListingCausalLabel",
		bilingual("Public listing fact", "공개 출품 정보"),
		190.0
	)


func hardcap_character_dialogue(value: Variant) -> String:
	var rendered := localized_value(value).replace("\n", " ").replace("\r", " ").strip_edges()
	while rendered.contains("  "):
		rendered = rendered.replace("  ", " ")
	if rendered.length() <= 44:
		return rendered
	return rendered.left(43).strip_edges() + "…"


func character_cue(character_id: String, semantic_state: String, dialogue_override: String = "", fact_label: String = "") -> Dictionary:
	var profile := character_profile(character_id)
	if profile.is_empty():
		return {}
	var cue_set_id: String = profile.get("cueSetId", "")
	var cue_spec: Dictionary = load_character_catalog().get("cueSets", {}).get(cue_set_id, {}).get(semantic_state, {})
	var expression: String = String(cue_spec.get("expression", "NEUTRAL")).to_upper()
	if not expression in ["NEUTRAL", "POSITIVE", "NEGATIVE"]:
		expression = "NEUTRAL"
	var band := current_stage_band()
	var stage_variant: Dictionary = profile.get("stageVariants", {}).get(band, {})
	var palette: Array = stage_variant.get("accentPalette", profile.get("basePalette", ["#e3c681"]))
	var accent_value: String = String(stage_variant.get("accentColor", ""))
	var accent := Color(accent_value) if not accent_value.is_empty() else (Color(String(palette[0])) if not palette.is_empty() else Color("#e3c681"))
	var dialogue_value: Variant = dialogue_override if not dialogue_override.is_empty() else cue_spec.get("dialogue", {"en": character_state_label(semantic_state), "ko": character_state_label(semantic_state)})
	if dialogue_override.is_empty() and String(profile.get("role", "")) == "BIDDER":
		var identity_dialogue: Variant = profile.get("auctionDialogue", {}).get(semantic_state, {})
		if identity_dialogue is Dictionary and not identity_dialogue.is_empty():
			dialogue_value = identity_dialogue
	return {
		"profile": profile,
		"characterId": character_id,
		"semanticState": semantic_state,
		"expression": expression,
		"dialogue": hardcap_character_dialogue(dialogue_value),
		"factLabel": hardcap_character_dialogue(fact_label),
		"stageBand": band,
		"stageVariant": stage_variant,
		"accent": accent
	}


func event_character_mapping(event_id: String) -> Dictionary:
	for mapping: Dictionary in load_character_catalog().get("eventCharacterMap", []):
		if mapping.get("eventId", "") == event_id:
			return mapping
	return {}


func event_character_id(event_id: String) -> String:
	return event_character_mapping(event_id).get("characterId", "")


func portrait_reaction_contract(expression_id: String) -> Dictionary:
	var normalized := expression_id.to_upper()
	var kind := "alpha_settle"
	var duration_ms := 120
	if normalized == "POSITIVE":
		kind = "gentle_pop"
		duration_ms = 160
	elif normalized == "NEGATIVE":
		kind = "soft_tilt"
		duration_ms = 140
	return {
		"kind": kind,
		"durationMs": mini(180, duration_ms),
		"finalTransform": {
			"scale": [1.0, 1.0],
			"rotationDegrees": 0.0,
			"alpha": 1.0,
			"positionOffset": [0.0, 0.0]
		}
	}


func finish_portrait_micro_reaction(anchor: Control) -> void:
	if not is_instance_valid(anchor):
		return
	anchor.scale = Vector2.ONE
	anchor.rotation_degrees = 0.0
	anchor.modulate = Color.WHITE
	anchor.set_meta("reaction_running", false)
	if anchor.has_meta("_reaction_tween"):
		anchor.remove_meta("_reaction_tween")


func play_portrait_micro_reaction(anchor: Control, contract: Dictionary) -> void:
	if reduced_motion:
		finish_portrait_micro_reaction(anchor)
		return
	# Let containers resolve their rectangles first. A panel cleared during this
	# frame simply exits here; tweens are also bound to the surviving child.
	await get_tree().process_frame
	if not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return
	var prior_tween: Variant = anchor.get_meta("_reaction_tween") if anchor.has_meta("_reaction_tween") else null
	if prior_tween is Tween and prior_tween.is_valid():
		prior_tween.kill()
	finish_portrait_micro_reaction(anchor)
	anchor.pivot_offset = anchor.size * 0.5
	anchor.set_meta("reaction_running", true)
	var kind: String = String(contract.get("kind", "alpha_settle"))
	var duration_ms := clampi(int(contract.get("durationMs", 120)), 100, 180)
	var tween := create_tween().bind_node(anchor)
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	anchor.set_meta("_reaction_tween", tween)
	if kind == "gentle_pop":
		anchor.scale = Vector2(0.96, 0.96)
		tween.tween_property(anchor, "scale", Vector2(1.02, 1.02), float(duration_ms) * 0.0005625).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(anchor, "scale", Vector2.ONE, float(duration_ms) * 0.0004375).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	elif kind == "soft_tilt":
		anchor.rotation_degrees = -0.8
		tween.tween_property(anchor, "rotation_degrees", 0.8, float(duration_ms) * 0.0005).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(anchor, "rotation_degrees", 0.0, float(duration_ms) * 0.0005).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		anchor.modulate = Color(1.0, 1.0, 1.0, 0.78)
		tween.tween_property(anchor, "modulate", Color.WHITE, float(duration_ms) * 0.001).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(finish_portrait_micro_reaction.bind(anchor))


func make_portrait_dialogue_panel(cue: Dictionary, panel_width: float, portrait_height: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "PortraitDialoguePanel_%s" % String(cue.get("characterId", "Unavailable")).validate_node_name()
	panel.custom_minimum_size = Vector2(panel_width, portrait_height + 112.0)
	if cue.is_empty():
		panel.add_theme_stylebox_override("panel", case_panel_style(Color("#171d21e8"), Color("#6e685c")))
		panel.add_child(make_label(bilingual("Character portrait data is unavailable.", "인물 초상 데이터를 불러올 수 없습니다."), 13, Color("#e59b7a")))
		return panel
	var profile: Dictionary = cue.profile
	var accent: Color = cue.accent
	panel.add_theme_stylebox_override("panel", case_panel_style(Color("#11171bf2"), accent, 2))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var portrait_stack := Control.new()
	portrait_stack.name = "PortraitStack"
	portrait_stack.custom_minimum_size = Vector2(panel_width - 20.0, portrait_height)
	portrait_stack.clip_contents = true
	column.add_child(portrait_stack)
	var portrait_backdrop := ColorRect.new()
	portrait_backdrop.color = Color(accent, 0.18)
	portrait_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_stack.add_child(portrait_backdrop)
	var reaction_anchor := Control.new()
	reaction_anchor.name = "PortraitReactionAnchor"
	reaction_anchor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reaction_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reaction_contract := portrait_reaction_contract(String(cue.expression))
	reaction_anchor.set_meta("reaction_contract", reaction_contract.duplicate(true))
	portrait_stack.add_child(reaction_anchor)
	var portrait := TextureRect.new()
	portrait.name = "CharacterPortrait"
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var portrait_path: String = profile.get("portraitAssetId", "")
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path)
	portrait.tooltip_text = localized_value(profile.get("accessibilityLabel", profile.get("displayName", "")))
	portrait.mouse_filter = Control.MOUSE_FILTER_PASS
	reaction_anchor.add_child(portrait)
	var overlay := PORTRAIT_EXPRESSION_OVERLAY.new()
	overlay.name = "ExpressionOverlay_%s" % cue.expression
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var expression_meta: Dictionary = profile.get("expressionMetadata", {}).get(cue.expression, {})
	var mood_accent_value: String = String(expression_meta.get("moodAccent", accent.to_html()))
	var geometry_contract: Dictionary = load_character_catalog().get("expressionGeometry", {})
	var expression_geometry: Dictionary = geometry_contract.get(cue.expression, {}).duplicate(true)
	expression_geometry["svgToReferenceScale"] = float(geometry_contract.get("svgToReferenceScale", 0.78125))
	overlay.configure(cue.expression, Color(mood_accent_value), expression_geometry, portrait_face_render(portrait_path))
	overlay.tooltip_text = localized_value(expression_meta.get("stateLabel", {"en": cue.expression.capitalize(), "ko": cue.expression.capitalize()}))
	reaction_anchor.add_child(overlay)
	var band_badge := Label.new()
	band_badge.name = "StageBandBadge"
	var accessory := localized_value(cue.get("stageVariant", {}).get("accessoryVariant", ""))
	band_badge.text = "%s %d · %s" % [stage_band_label(cue.stageBand), int(GameState.current_stage), accessory]
	band_badge.position = Vector2(8, portrait_height - 29)
	band_badge.size = Vector2(panel_width - 36, 24)
	band_badge.add_theme_font_size_override("font_size", scaled_font_size(12))
	band_badge.add_theme_color_override("font_color", Color("#fff5d9"))
	band_badge.add_theme_stylebox_override("normal", case_panel_style(Color(accent, 0.82), accent, 0))
	portrait_stack.add_child(band_badge)
	var identity := make_label(localized_value(profile.get("displayName", "")), 17, Color("#e3c681"))
	identity.name = "CharacterDisplayName"
	identity.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(identity)
	var role_label := make_label(character_role_label(String(profile.get("role", ""))), 12, Color("#8fa5aa"))
	role_label.name = "CharacterRole"
	role_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(role_label)
	var state_label := make_label(character_state_label(cue.semanticState), 13, accent)
	state_label.name = "CharacterSemanticState"
	state_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(state_label)
	var dialogue := make_label(cue.dialogue, 14, Color("#f2e8cf"))
	dialogue.name = "CharacterDialogue"
	dialogue.max_lines_visible = 2
	dialogue.tooltip_text = cue.dialogue
	column.add_child(dialogue)
	if not String(cue.factLabel).is_empty():
		var fact := make_label(cue.factLabel, 13, Color("#9fd6bd") if cue.expression != "NEGATIVE" else Color("#e59b7a"))
		fact.name = "CharacterFactLabel"
		fact.max_lines_visible = 2
		column.add_child(fact)
	play_portrait_micro_reaction(reaction_anchor, reaction_contract)
	return panel


func make_tutorial_guidance_rail(public_state: Dictionary) -> PanelContainer:
	var rail := PanelContainer.new()
	rail.name = "TutorialGuidanceRail"
	rail.custom_minimum_size = Vector2(0, 54)
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.add_theme_stylebox_override("panel", case_panel_style(Color("#18231fe8"), Color("#e3c681"), 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	rail.add_child(row)
	var icon := TextureRect.new()
	icon.name = "TutorialGuidanceIcon"
	icon.texture = case_icon(String(public_state.get("icon", "objective")))
	icon.custom_minimum_size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var counter := make_label("%s %d/%d" % [bilingual("GUIDE", "안내"), int(public_state.get("step", 0)), int(public_state.get("total", 0))], 13, Color("#9fd6bd"))
	counter.name = "TutorialStepCounter"
	counter.custom_minimum_size = Vector2(92, 0)
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	counter.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(counter)
	var copy_column := VBoxContainer.new()
	copy_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_column.add_theme_constant_override("separation", 0)
	row.add_child(copy_column)
	var title := make_label(compact_case_text(public_state.get("title", ""), 34), 15, Color("#e3c681"))
	title.name = "TutorialStepTitle"
	title.max_lines_visible = 1
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy_column.add_child(title)
	var instruction := make_label(compact_case_text(public_state.get("text", ""), 72), 13, Color("#f2e8cf"))
	instruction.name = "TutorialStepText"
	instruction.max_lines_visible = 1
	instruction.autowrap_mode = TextServer.AUTOWRAP_OFF
	instruction.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy_column.add_child(instruction)
	rail.tooltip_text = "%s — %s" % [localized_value(public_state.get("title", "")), localized_value(public_state.get("text", ""))]
	return rail


func tutorial_public_state_for_screen() -> Dictionary:
	var public_state := GameState.tutorial_public_state()
	# Before the dossier exists, the first authored step needs one plain-language
	# bridge from the campaign list to the highlighted case-start button. The
	# underlying public state and authoritative step sequence remain unchanged.
	if bool(public_state.get("visible", false)) and screen == "campaign" and int(public_state.get("step", 0)) == 1:
		public_state.title = bilingual("START THE FIRST CASE", "첫 사건 시작")
		public_state.text = bilingual("Open the first case below to begin your investigation.", "아래 첫 사건의 시작 버튼을 눌러 조사를 시작하세요.")
	return public_state


func tutorial_control_is_actionable(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	return control.size.x > 0.0 and control.size.y > 0.0


func tutorial_target_patterns(public_state: Dictionary) -> Array[String]:
	var patterns: Array[String] = []
	for target_value: Variant in public_state.get("targets", []):
		var pattern := String(target_value)
		if not pattern.is_empty() and not patterns.has(pattern):
			patterns.append(pattern)
	# Prefer a direct action on the current screen to a global navigation route.
	# The public contract still provides every candidate; this only chooses the
	# nearest currently reachable control.
	var direct_patterns: Array[String] = []
	var navigation_patterns: Array[String] = []
	for pattern: String in patterns:
		if pattern.begins_with("Nav_"):
			navigation_patterns.append(pattern)
		else:
			direct_patterns.append(pattern)
	patterns = direct_patterns + navigation_patterns
	# The dossier's primary target is the selectable clue card, while its route
	# target is the separate action that actually records the clue.  Highlight
	# the enabled action so the guide never stops one click too early.
	if patterns.has("CaseEvidence_*"):
		patterns.erase("CaseEvidence_*")
		patterns.push_front("CaseEvidence_*")
	if int(public_state.get("step", 0)) == 1 and screen == "campaign":
		var pending_case_id := GameState.current_stage_first_pending_case()
		if not pending_case_id.is_empty():
			var first_case_pattern := "Case_%s" % pending_case_id.validate_node_name()
			patterns.erase(first_case_pattern)
			patterns.push_front(first_case_pattern)
	if int(public_state.get("step", 0)) == 4:
		var required_tools: Array = GameState.repair_requirements(selected).get("requiredTools", []) if not selected.is_empty() else []
		var tool_ready := required_tools.is_empty() or required_tools.has(GameState.selected_tool)
		var preferred := "Tool_repair" if tool_ready else "RepairTool_*"
		patterns.erase(preferred)
		patterns.push_front(preferred)
	if int(public_state.get("step", 0)) == 6 and screen == "auction" and ui.find_child("HammerButton", true, false) == null:
		patterns.push_front("AuctionCueNext")
	return patterns


func find_tutorial_target(public_state: Dictionary) -> Control:
	for pattern: String in tutorial_target_patterns(public_state):
		for candidate: Node in ui.find_children(pattern, "Control", true, false):
			if candidate is Control and tutorial_control_is_actionable(candidate):
				return candidate as Control
	return null


func stabilize_tutorial_target_scroll(target: Control, scroll: ScrollContainer, render_serial: int) -> void:
	# resolve_tutorial_guidance_target is already deferred once.  Waiting one
	# more frame lets both locale-dependent glyph metrics and the ScrollContainer
	# finish layout before a single ensure operation.  Calling ensure twice can
	# compound the offset on a tall English dossier.
	await get_tree().process_frame
	if render_serial != tutorial_render_serial or target == null or scroll == null or not is_instance_valid(target) or not is_instance_valid(scroll):
		return
	scroll.ensure_control_visible(target)
	# The dossier is intentionally vertical-only.  ensure_control_visible may
	# still alter a hidden horizontal scrollbar, so pin it to the public layout.
	scroll.scroll_horizontal = 0
	# Godot applies ensure_control_visible during the following container-layout
	# pass. Measuring sooner can see the pre-scroll rect, then the deferred ensure
	# overrides our correction and leaves a citation button clipped behind the
	# tutorial rail. Let that one authoritative ensure settle before enforcing
	# the visible viewport bounds.
	await get_tree().process_frame
	if render_serial != tutorial_render_serial or target == null or scroll == null or not is_instance_valid(target) or not is_instance_valid(scroll):
		return
	var target_rect := target.get_global_rect()
	var visible_rect := scroll.get_global_rect()
	if target_rect.position.y < visible_rect.position.y:
		scroll.scroll_vertical -= ceili(visible_rect.position.y - target_rect.position.y)
	elif target_rect.end.y > visible_rect.end.y:
		scroll.scroll_vertical += ceili(target_rect.end.y - visible_rect.end.y)
	var vertical_bar := scroll.get_v_scroll_bar()
	var maximum_scroll := maxi(0, ceili(vertical_bar.max_value - vertical_bar.page))
	scroll.scroll_vertical = clampi(scroll.scroll_vertical, 0, maximum_scroll)


func resolve_tutorial_guidance_target(render_serial: int) -> void:
	if render_serial != tutorial_render_serial or tutorial_guidance_state.is_empty() or not bool(tutorial_guidance_state.get("visible", false)):
		return
	var target := find_tutorial_target(tutorial_guidance_state)
	if target == null:
		return
	tutorial_target_control = target
	var guidance_tooltip := "%s %d/%d · %s\n%s" % [
		bilingual("GUIDE", "안내"),
		int(tutorial_guidance_state.get("step", 0)),
		int(tutorial_guidance_state.get("total", 0)),
		localized_value(tutorial_guidance_state.get("title", "")),
		localized_value(tutorial_guidance_state.get("text", ""))
	]
	if not target.tooltip_text.contains(guidance_tooltip):
		target.tooltip_text = guidance_tooltip if target.tooltip_text.is_empty() else target.tooltip_text + "\n" + guidance_tooltip
	if target.focus_mode != Control.FOCUS_NONE:
		target.grab_focus()
	var target_scroll: ScrollContainer = null
	var ancestor: Node = target.get_parent()
	while ancestor != null and ancestor != ui:
		if ancestor is ScrollContainer:
			target_scroll = ancestor as ScrollContainer
			break
		ancestor = ancestor.get_parent()
	var outline := PanelContainer.new()
	outline.name = "TutorialTargetOutline"
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.z_index = 80
	var outline_style := case_panel_style(Color("#00000000"), Color("#f0bd71"), 3)
	outline_style.content_margin_left = 0
	outline_style.content_margin_right = 0
	outline_style.content_margin_top = 0
	outline_style.content_margin_bottom = 0
	outline.add_theme_stylebox_override("panel", outline_style)
	target.add_child(outline)
	outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outline.offset_left = -4.0
	outline.offset_top = -4.0
	outline.offset_right = 4.0
	outline.offset_bottom = 4.0
	if target_scroll != null:
		stabilize_tutorial_target_scroll(target, target_scroll, render_serial)


func journey_public_facts() -> Dictionary:
	return GameState.workflow_public_facts(String(selected.get("uniqueId", "")))


func journey_phase_index(screen_name: String = screen) -> int:
	if screen_name in ["title", "stage_select", "settings", "ending", "postgame"] or GameState.stage_clear_pending():
		return -1
	var facts := journey_public_facts()
	if not bool(facts.get("artifactPresent", false)):
		return 0
	if String(facts.get("auctionStatus", "NONE")) in ["PENDING", "COMMITTED"] or GameState.grand_reserve_active():
		return 5
	if not bool(facts.get("investigated", false)):
		return 1
	if bool(facts.get("caseBound", false)) and not bool(facts.get("caseResolved", false)):
		return 2
	if not bool(facts.get("hypothesisPrepared", false)):
		return 2
	if bool(facts.get("repairRequired", false)) and not bool(facts.get("repairCompleted", false)):
		return 3
	if not bool(facts.get("listed", false)):
		return 4
	return 5


func journey_step_copy(step_index: int) -> Dictionary:
	var steps := [
		{"icon": "artifact", "en": "FIND", "ko": "유물"},
		{"icon": "clue_generic", "en": "INSPECT", "ko": "조사"},
		{"icon": "citation", "en": "DECIDE", "ko": "판단"},
		{"icon": "tool", "en": "PRESERVE", "ko": "보존"},
		{"icon": "report", "en": "LIST", "ko": "출품"},
		{"icon": "support", "en": "AUCTION", "ko": "경매"}
	]
	return steps[clampi(step_index, 0, steps.size() - 1)]


func make_journey_rail() -> PanelContainer:
	var active_index := journey_phase_index()
	var rail := PanelContainer.new()
	rail.name = "JourneyRail"
	rail.custom_minimum_size = Vector2(0, 36)
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.add_theme_stylebox_override("panel", case_panel_style(Color("#101619df"), Color("#4d5b58")))
	var row := HBoxContainer.new()
	row.name = "JourneySteps"
	row.add_theme_constant_override("separation", 5)
	rail.add_child(row)
	for step_index in range(6):
		var step := journey_step_copy(step_index)
		var active := step_index == active_index
		var completed := active_index >= 0 and step_index < active_index
		var step_panel := PanelContainer.new()
		step_panel.name = "JourneyStep_%d" % step_index
		step_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		step_panel.add_theme_stylebox_override("panel", case_panel_style(
			Color("#1b2b25") if active else Color("#151b1ee8"),
			Color("#e3c681") if active else (Color("#6fae98") if completed else Color("#394548")),
			2 if active else 1
		))
		var step_row := HBoxContainer.new()
		step_row.add_theme_constant_override("separation", 5)
		step_panel.add_child(step_row)
		var icon := TextureRect.new()
		icon.texture = case_icon(String(step.icon))
		icon.custom_minimum_size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		step_row.add_child(icon)
		var prefix := "● " if active else ("✓ " if completed else "")
		var label := make_label(prefix + bilingual(String(step.en), String(step.ko)), 12, Color("#f2e8cf") if active else Color("#aab7b5"))
		label.name = "JourneyStepLabel_%d" % step_index
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.max_lines_visible = 1
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		step_row.add_child(label)
		step_panel.tooltip_text = bilingual(
			"Relic workflow step %d of 6" % [step_index + 1],
			"유물 작업 흐름 %d / 6" % [step_index + 1]
		)
		row.add_child(step_panel)
	return rail


func should_show_journey_rail() -> bool:
	if bool(tutorial_guidance_state.get("visible", false)) or journey_phase_index() < 0:
		return false
	# Auction already presents the active step, price and primary action in its
	# own hierarchy. Repeating the six-step rail here steals the exact vertical
	# space needed for terminal receipts at the 116% accessibility size.
	if screen == "auction":
		return false
	if screen == "inventory":
		var pending := GameState.pending_auction_public_state()
		if bool(pending.get("ok", false)) \
			and String(pending.get("status", "")) == "COMMITTED" \
			and not bool(pending.get("grandReserve", false)):
			return false
	return true


func screen_shell(title_value: String, world_mode: String = "workshop") -> VBoxContainer:
	clear_ui()
	play_bgm_for_screen(screen)
	set_world_mode(world_mode)
	tutorial_guidance_state = tutorial_public_state_for_screen()
	var tutorial_active := bool(tutorial_guidance_state.get("visible", false))
	var background := ColorRect.new()
	background.color = Color(0.035, 0.045, 0.055, 0.90)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(background)

	var header := Control.new()
	header.name = "Header"
	header.position = Vector2(28, 18)
	# The right edge follows the same 34px safe area as the content/navigation
	# chrome so the optional tutorial action never touches the 1280px boundary.
	header.size = Vector2(1218, 52)
	ui.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.name = "HeaderRow"
	header_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_row.add_theme_constant_override("separation", 10)
	header.add_child(header_row)
	var title_label := make_label(title_value, 28, Color("#e3c681"))
	title_label.name = "HeaderTitle"
	title_label.custom_minimum_size = Vector2(560, 52)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.max_lines_visible = 1
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.tooltip_text = title_value
	header_row.add_child(title_label)
	var header_stats := make_label("%s %d   ¤ %d   %s %d   %s %d" % [bilingual("DAY", "일차"), GameState.day, GameState.money, bilingual("REP", "평판"), GameState.reputation, bilingual("GRADE", "등급"), int(GameState.campaign_state.workshopGrade)], 14)
	header_stats.name = "HeaderStats"
	header_stats.custom_minimum_size = Vector2(320 if tutorial_active else 420, 42)
	header_stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	header_stats.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(header_stats)
	if tutorial_active:
		var skip_button := make_button(bilingual("SKIP GUIDE", "튜토리얼 건너뛰기"), skip_tutorial_from_ui, "TutorialSkipButton")
		skip_button.custom_minimum_size = Vector2(188, 42)
		skip_button.clip_text = true
		skip_button.tooltip_text = bilingual("Skip the guide and remember this choice for future NEW GAME sessions.", "튜토리얼을 건너뛰며 다음 새 게임부터도 이 선택을 기억합니다.")
		header_row.add_child(skip_button)

	var margin := MarginContainer.new()
	margin.name = "ContentMargin"
	margin.position = Vector2(34, 82)
	margin.size = Vector2(1212, 526)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	ui.add_child(margin)
	var body := VBoxContainer.new()
	body.name = "ScreenContent"
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)
	content_root = body
	var current_tutorial_serial := tutorial_render_serial
	if bool(tutorial_guidance_state.get("visible", false)):
		body.add_child(make_tutorial_guidance_rail(tutorial_guidance_state))
	elif should_show_journey_rail():
		body.add_child(make_journey_rail())

	var nav := Control.new()
	nav.name = "Navigation"
	nav.position = Vector2(28, 620)
	nav.size = Vector2(1224, 46)
	ui.add_child(nav)
	var pending_auction_lock: bool = GameState.pending_auction_active()
	var grand_reserve_lock: bool = GameState.grand_reserve_active()
	var transaction_lock: bool = pending_auction_lock or grand_reserve_lock
	var stage_clear_lock: bool = GameState.stage_clear_pending()
	var nav_entries: Array = [
		["AUCTION", resume_grand_reserve_from_ui if grand_reserve_lock else resume_pending_auction_from_ui] if transaction_lock else ["WORKSHOP", show_workshop],
		["MARKET", show_market], ["INVENTORY", show_inventory],
		["UPGRADES", show_upgrades], ["COMMISSIONS", show_commissions], ["CAMPAIGN", show_campaign],
		["SAVE", save_from_ui], ["SETTINGS", open_settings_from_ui], ["LANGUAGE", toggle_language]
	]
	# Keep the global route and selector stable on every screen. Authentication
	# renders this one route as a compact BaseButton so its 2x3 decision boards
	# retain the established density ceiling without removing keyboard access.
	nav_entries.insert(6, ["END_DAY", end_day_from_ui])
	var nav_width := 122.0 if nav_entries.size() >= 10 else (134.0 if nav_entries.size() >= 9 else 146.0)
	for nav_index: int in nav_entries.size():
		var entry: Array = nav_entries[nav_index]
		var nav_label := text_for(entry[0])
		if String(entry[0]) == "COMMISSIONS":
			nav_label = bilingual("JOBS", "의뢰")
		var nav_button: BaseButton
		if screen == "authentication" and String(entry[0]) == "END_DAY":
			nav_button = make_compact_navigation_button(bilingual("END", "마감"), entry[1], "Nav_END_DAY", "objective")
			nav_button.tooltip_text = text_for("END_DAY")
		else:
			nav_button = make_button(nav_label, entry[1], "Nav_%s" % entry[0])
		nav_button.position = Vector2(nav_index * nav_width, 0)
		nav_button.size = Vector2(nav_width - 4.0, 46)
		nav_button.custom_minimum_size = Vector2.ZERO
		if nav_button is Button:
			(nav_button as Button).clip_text = true
		if transaction_lock and String(entry[0]) not in ["AUCTION", "SAVE", "SETTINGS", "LANGUAGE"]:
			nav_button.disabled = true
			nav_button.tooltip_text = friendly_pending_auction_error("PENDING_AUCTION_LOCKED")
		elif transaction_lock and String(entry[0]) == "AUCTION" and screen == "auction":
			nav_button.disabled = true
			nav_button.tooltip_text = bilingual("Current auction", "현재 경매")
		elif stage_clear_lock and String(entry[0]) not in ["CAMPAIGN", "SAVE", "SETTINGS", "LANGUAGE"]:
			nav_button.disabled = true
			nav_button.tooltip_text = bilingual("Review the Stage result first.", "스테이지 결과를 먼저 확인하세요.")
		elif stage_clear_lock and String(entry[0]) == "CAMPAIGN" and screen == "campaign":
			nav_button.disabled = true
			nav_button.tooltip_text = bilingual("Current Stage result", "현재 스테이지 결과")
		elif String(entry[0]) == "SETTINGS" and screen == "settings":
			nav_button.disabled = true
			nav_button.tooltip_text = bilingual("Current settings", "현재 설정")
		if nav_button is TextureButton:
			refresh_compact_navigation_button(nav_button as TextureButton)
		nav.add_child(nav_button)

	status = make_label("", 15, Color("#9fd6bd"))
	status.name = "StatusMessage"
	status.position = Vector2(36, 674)
	status.size = Vector2(1208, 30)
	ui.add_child(status)
	if bool(tutorial_guidance_state.get("visible", false)):
		resolve_tutorial_guidance_target.call_deferred(current_tutorial_serial)
	return body


func open_settings_from_ui() -> void:
	if screen != "settings":
		# Settings is a presentation overlay. Freeze the resumable market/event/
		# auction mirror before changing the local screen name so Settings,
		# locale changes and saves cannot replace it with an unrestorable token.
		sync_public_interaction_state()
		settings_return_screen = screen
	show_settings()


func settings_back_from_ui() -> void:
	var target := settings_return_screen
	if target.is_empty() or target == "settings":
		target = "title"
	screen = target
	refresh_current_screen()


func volume_level_label(option_index: int) -> String:
	return localized_value([
		{"en": "OFF", "ko": "끄기"},
		{"en": "LOW", "ko": "작게"},
		{"en": "NORMAL", "ko": "보통"},
		{"en": "HIGH", "ko": "크게"}
	][clampi(option_index, 0, 3)])


func setting_option_button(text_value: String, callback: Callable, selected_option: bool, node_name: String) -> Button:
	var button := make_button(text_value, callback, node_name)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 42)
	button.add_theme_stylebox_override("normal", case_panel_style(
		Color("#213029") if selected_option else Color("#151b1fe8"),
		Color("#e3c681") if selected_option else Color("#5d625f"),
		2 if selected_option else 1
	))
	button.tooltip_text = bilingual("Current choice" if selected_option else "Apply this choice", "현재 선택" if selected_option else "이 설정 적용")
	return button


func make_setting_group(title_value: String, description: String, options: Array) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", case_panel_style(Color("#151b1fe8"), Color("#5d625f")))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var heading := make_label(title_value, 16, Color("#e3c681"))
	heading.max_lines_visible = 1
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(heading)
	var help := make_label(description, 12, Color("#aab7b5"))
	help.max_lines_visible = 1
	help.autowrap_mode = TextServer.AUTOWRAP_OFF
	help.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(help)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	column.add_child(row)
	for option_value: Variant in options:
		if option_value is Control:
			row.add_child(option_value)
	return panel


func set_audio_setting(channel: String, value: float) -> void:
	match channel:
		"master": master_volume_db = value
		"music": bgm_volume_db = value
		"effects": sfx_volume_db = value
	apply_player_settings()
	var saved := save_player_settings()
	show_settings()
	status.text = bilingual("Audio setting saved.", "오디오 설정을 저장했습니다.") if saved else bilingual("The setting could not be saved.", "설정을 저장하지 못했습니다.")


func set_text_scale_from_ui(value: float) -> void:
	ui_text_scale = clampf(value, 1.0, 1.16)
	var saved := save_player_settings()
	show_settings()
	status.text = bilingual("Text size saved.", "글자 크기를 저장했습니다.") if saved else bilingual("The setting could not be saved.", "설정을 저장하지 못했습니다.")


func set_reduced_motion_from_ui(value: bool) -> void:
	reduced_motion = value
	var saved := save_player_settings()
	show_settings()
	status.text = bilingual("Motion preference saved.", "동작 효과 설정을 저장했습니다.") if saved else bilingual("The setting could not be saved.", "설정을 저장하지 못했습니다.")


func toggle_display_mode_from_ui() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		status.text = bilingual("Display mode is unavailable in headless mode.", "헤드리스 모드에서는 화면 모드를 바꿀 수 없습니다.")
		return
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
	show_settings()
	status.text = bilingual("Window mode updated.", "화면 모드를 변경했습니다.")


func show_settings() -> void:
	screen = "settings"
	var body := screen_shell(bilingual("PLAYER SETTINGS", "플레이 설정"))
	var intro := make_label(bilingual("Tune sound and readability. Your campaign progress and auction choices stay unchanged.", "소리와 읽기 편의를 조정합니다. 캠페인 진행과 경매 선택은 그대로 유지됩니다."), 14, Color("#b7c4c8"))
	intro.max_lines_visible = 1
	intro.autowrap_mode = TextServer.AUTOWRAP_OFF
	intro.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(intro)
	var grid := GridContainer.new()
	grid.name = "SettingsGrid"
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)

	var master_options: Array = []
	var master_values: Array = [-80.0, -12.0, -6.0, 0.0]
	for option_index in master_values.size():
		var value := float(master_values[option_index])
		master_options.append(setting_option_button(volume_level_label(option_index), set_audio_setting.bind("master", value), is_equal_approx(master_volume_db, value), "SettingsMaster_%d" % option_index))
	grid.add_child(make_setting_group(bilingual("MASTER", "전체 음량"), bilingual("Overall game volume", "게임 전체 소리"), master_options))

	var music_options: Array = []
	var music_values: Array = [-80.0, -20.0, -14.0, -8.0]
	for option_index in music_values.size():
		var value := float(music_values[option_index])
		music_options.append(setting_option_button(volume_level_label(option_index), set_audio_setting.bind("music", value), is_equal_approx(bgm_volume_db, value), "SettingsMusic_%d" % option_index))
	grid.add_child(make_setting_group(bilingual("MUSIC", "배경 음악"), bilingual("Title, workshop and ending music", "타이틀·공방·엔딩 음악"), music_options))

	var effects_options: Array = []
	var effects_values: Array = [-80.0, -12.0, -6.0, -4.0]
	for option_index in effects_values.size():
		var value := float(effects_values[option_index])
		effects_options.append(setting_option_button(volume_level_label(option_index), set_audio_setting.bind("effects", value), is_equal_approx(sfx_volume_db, value), "SettingsEffects_%d" % option_index))
	grid.add_child(make_setting_group(bilingual("EFFECTS", "효과음"), bilingual("Buttons, tools and auction cues", "버튼·도구·경매 효과음"), effects_options))

	var text_options: Array = []
	for value: float in [1.0, 1.08, 1.16]:
		text_options.append(setting_option_button("%d%%" % roundi(value * 100.0), set_text_scale_from_ui.bind(value), is_equal_approx(ui_text_scale, value), "SettingsText_%d" % roundi(value * 100.0)))
	grid.add_child(make_setting_group(bilingual("TEXT SIZE", "글자 크기"), bilingual("Readable labels and dialogue", "라벨과 대화 글자 크기"), text_options))

	var motion_options: Array = [
		setting_option_button(bilingual("STANDARD", "기본"), set_reduced_motion_from_ui.bind(false), not reduced_motion, "SettingsMotionStandard"),
		setting_option_button(bilingual("REDUCED", "줄임"), set_reduced_motion_from_ui.bind(true), reduced_motion, "SettingsMotionReduced")
	]
	grid.add_child(make_setting_group(bilingual("PORTRAIT MOTION", "초상화 움직임"), bilingual("Reduce decorative reactions", "장식 동작 효과 줄이기"), motion_options))

	var fullscreen := DisplayServer.get_name().to_lower() != "headless" and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	var display_options: Array = [setting_option_button(bilingual("WINDOWED" if fullscreen else "FULLSCREEN", "창 모드" if fullscreen else "전체 화면"), toggle_display_mode_from_ui, false, "SettingsDisplayToggle")]
	grid.add_child(make_setting_group(bilingual("DISPLAY", "화면"), bilingual("Switch the current window mode", "현재 화면 모드 전환"), display_options))

	var back := mark_primary_action(make_case_icon_button("objective", text_for("BACK"), settings_back_from_ui, "SettingsBack", Vector2(0, 46)))
	body.add_child(back)


func toggle_language() -> void:
	var focus_name := current_focus_control_name()
	sync_public_interaction_state(focus_name)
	language = "ko" if language == "en" else "en"
	GameState.language = language
	refresh_current_screen()
	restore_focus_by_name(focus_name)


func current_focus_control_name() -> String:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner == null or not focus_owner.is_inside_tree():
		return ""
	return String(focus_owner.name)


func restore_focus_by_name(focus_name: String) -> void:
	if focus_name.is_empty():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(ui) or not ui.is_inside_tree():
		return
	var candidate: Node = ui.find_child(focus_name, true, false)
	if not candidate is Control or not candidate.is_visible_in_tree():
		return
	if candidate is BaseButton and candidate.disabled:
		return
	candidate.grab_focus()


func sync_public_interaction_state(focus_override: String = "") -> Dictionary:
	var previous_value: Variant = GameState.campaign_state.get("publicInteraction", {})
	var previous: Dictionary = previous_value if previous_value is Dictionary else {}
	if screen == "settings":
		return previous.duplicate(true)
	var focus_name := focus_override
	if focus_name.is_empty():
		focus_name = current_focus_control_name()
	if focus_name.is_empty():
		focus_name = String(previous.get("focusName", ""))
	var public_state := {"schemaVersion": 1, "screen": screen, "focusName": focus_name}
	match screen:
		"auction":
			public_state["auction"] = {
				"artifactId": String(selected.get("uniqueId", "")),
				"cueIndex": auction_cue_index
			}
		"market":
			public_state["market"] = {
				"state": market_character_state,
				"lotId": market_active_lot_id
			}
		"event":
			public_state["event"] = {
				"state": event_cue_state,
				"eventId": String(last_event_result.get("eventId", GameState.current_event_id))
			}
	GameState.campaign_state["publicInteraction"] = public_state
	return public_state.duplicate(true)


func event_result_from_history(event_id: String) -> Dictionary:
	for history_index: int in range(GameState.event_history.size() - 1, -1, -1):
		var history_entry: Dictionary = GameState.event_history[history_index]
		if String(history_entry.get("eventId", "")) == event_id and history_entry.get("result", {}) is Dictionary:
			return history_entry.get("result", {}).duplicate(true)
	return {}


func resume_pending_auction_from_ui() -> void:
	if GameState.grand_reserve_active():
		resume_grand_reserve_from_ui()
		return
	var pending: Dictionary = GameState.pending_auction_public_state()
	if not bool(pending.get("ok", false)) or String(pending.get("status", "")) != "PENDING":
		status.text = friendly_pending_auction_error(String(pending.get("code", "NO_PENDING_AUCTION")))
		return
	var artifact: Dictionary = GameState.find_inventory_instance(String(pending.get("artifactId", "")))
	if artifact.is_empty():
		status.text = friendly_pending_auction_error("AUCTION_LOT_UNAVAILABLE")
		return
	load_artifact(artifact)
	reset_auction_cue_sequence()
	ensure_auction_cue_sequence()
	show_auction()
	var focus_name := "HammerButton" if bool(auction_public_cue_state().get("isFinal", false)) else "AuctionCueNext"
	restore_focus_by_name(focus_name)


func resume_grand_reserve_from_ui() -> void:
	var session: Dictionary = GameState.grand_reserve_public_state()
	var phase := String(session.get("phase", "IDLE"))
	if not phase in ["AUCTION_PENDING", "BETWEEN_LOTS"]:
		show_campaign()
		return
	var pending: Dictionary = GameState.pending_auction_public_state()
	if not bool(pending.get("ok", false)):
		status.text = friendly_pending_auction_error(String(pending.get("code", "NO_PENDING_AUCTION")))
		return
	var artifact: Dictionary = GameState.find_inventory_instance(String(pending.get("artifactId", "")))
	if not artifact.is_empty():
		load_artifact(artifact)
	else:
		selected = session.get("activeArtifact", {}).duplicate(true) if session.get("activeArtifact", {}) is Dictionary else {}
		GameState.active_workpiece = {}
		sync_workpiece_from_state()
	reset_auction_cue_sequence()
	ensure_auction_cue_sequence()
	show_auction()
	var focus_name := "GrandReserveNextLot" if phase == "BETWEEN_LOTS" else ("HammerButton" if bool(auction_public_cue_state().get("isFinal", false)) else "AuctionCueNext")
	restore_focus_by_name(focus_name)


func restore_public_interaction_state() -> bool:
	var public_value: Variant = GameState.campaign_state.get("publicInteraction", {})
	var public_state: Dictionary = public_value if public_value is Dictionary else {}
	var restored_screen := String(public_state.get("screen", ""))
	var focus_name := String(public_state.get("focusName", ""))
	# A PENDING auction is the authoritative resumable interaction even if an
	# older save has no presentation mirror or its last public screen was stale.
	if GameState.grand_reserve_active():
		resume_grand_reserve_from_ui()
		return true
	var pending: Dictionary = GameState.pending_auction_public_state()
	if bool(pending.get("ok", false)) and String(pending.get("status", "")) == "PENDING":
		var pending_artifact: Dictionary = GameState.find_inventory_instance(String(pending.get("artifactId", "")))
		if pending_artifact.is_empty():
			return false
		load_artifact(pending_artifact)
		reset_auction_cue_sequence()
		ensure_auction_cue_sequence()
		show_auction()
		var pending_focus := focus_name if restored_screen == "auction" and not focus_name.is_empty() else ("HammerButton" if bool(auction_public_cue_state().get("isFinal", false)) else "AuctionCueNext")
		restore_focus_by_name(pending_focus)
		return true
	match restored_screen:
		"auction":
			# Auction restoration is authorized only by GameState's PENDING record,
			# handled above. A stale presentation mirror after a committed no-sale
			# must never generate a free second preview on Continue.
			return false
		"market":
			var market_value: Variant = public_state.get("market", {})
			var market_state: Dictionary = market_value if market_value is Dictionary else {}
			market_character_state = String(market_state.get("state", "WELCOME"))
			if not market_character_state in ["WELCOME", "OFFER", "PURCHASE_OK", "PURCHASE_FAIL"]:
				market_character_state = "WELCOME"
			market_active_lot_id = String(market_state.get("lotId", ""))
			market_character_dialogue = ""
			market_character_fact = ""
			show_market()
		"event":
			var event_value: Variant = public_state.get("event", {})
			var event_state: Dictionary = event_value if event_value is Dictionary else {}
			event_cue_state = String(event_state.get("state", "REQUEST"))
			if not event_cue_state in ["REQUEST", "REACTION_POS", "REACTION_NEG"]:
				event_cue_state = "REQUEST"
			var event_id := String(event_state.get("eventId", GameState.current_event_id))
			last_event_result = event_result_from_history(event_id)
			if last_event_result.is_empty() and not event_id.is_empty():
				var event_data: Dictionary = RuntimeRegistry.get_event(event_id)
				last_event_result = {"eventId": event_id, "effect": event_data.get("effect", {}).duplicate(true), "appliedAmount": float(event_data.get("effect", {}).get("amount", 0.0))}
			show_event_dialogue(last_event_result)
		_:
			return false
	restore_focus_by_name(focus_name)
	return true


func continue_from_ui(save_path: String = "") -> bool:
	var loaded := GameState.load_game() if save_path.is_empty() else GameState.load_game(save_path)
	if not loaded:
		show_title()
		return false
	language = GameState.language
	# Terminal campaign hand-offs outrank stale presentation mirrors. A pending
	# auction still resumes before ordinary workshop/market/event screens.
	if bool(GameState.campaign_state.get("postGame", false)):
		show_postgame()
	elif GameState.stage_clear_pending():
		show_campaign()
	elif not String(GameState.campaign_state.get("currentEnding", "")).is_empty():
		show_ending()
	elif GameState.grand_reserve_active():
		resume_grand_reserve_from_ui()
	elif GameState.pending_auction_active():
		if not restore_public_interaction_state():
			show_workshop()
	elif String(GameState.campaign_state.get("currentAct", "")) == "GRAND_RESERVE":
		show_campaign()
	elif not restore_public_interaction_state():
		show_workshop()
	return true


func refresh_current_screen() -> void:
	match screen:
		"title": show_title()
		"stage_select": show_stage_select()
		"workshop": show_workshop()
		"market": show_market()
		"inventory": show_inventory()
		"inspection": show_inspection()
		"authentication": show_authentication()
		"case_dossier": show_case_dossier()
		"event": show_event_dialogue(last_event_result)
		"appraisal": show_appraisal()
		"auction": show_auction()
		"upgrades": show_upgrades()
		"commissions": show_commissions()
		"campaign": show_campaign()
		"final_selection": show_final_lot_selection()
		"grand_reserve": show_grand_reserve()
		"ending": show_ending()
		"postgame": show_postgame()
		"settings": show_settings()
		_: show_workshop()


func save_from_ui(save_path: String = "") -> void:
	sync_public_interaction_state()
	var saved := GameState.save_game() if save_path.is_empty() else GameState.save_game(save_path)
	status.text = text_for("SAVE_OK" if saved else "SAVE_FAIL")


func end_day_from_ui() -> void:
	var result := GameState.advance_day()
	if not bool(result.get("ok", true)):
		status.text = friendly_pending_auction_error(String(result.get("code", "PENDING_AUCTION_LOCKED")))
		return
	last_event_result = result
	event_cue_state = "REQUEST"
	show_event_dialogue(result)
	sync_public_interaction_state("EventRevealResult")
	restore_focus_by_name("EventRevealResult")
	status.text = bilingual("A new event has arrived.", "새로운 사건이 찾아왔습니다.")


func event_public_title(event_id: String) -> String:
	var event_data: Dictionary = RuntimeRegistry.get_event(event_id)
	var rendered := localized_value(event_data.get("localizedName", {}))
	if not rendered.is_empty():
		return rendered
	if language == "en" and not String(event_data.get("name", "")).is_empty():
		return String(event_data.get("name", ""))
	return bilingual("Workshop Visitor", "공방 방문객")


func event_public_description(event_id: String) -> String:
	var event_data: Dictionary = RuntimeRegistry.get_event(event_id)
	var rendered := localized_value(event_data.get("localizedDescription", {}))
	if not rendered.is_empty():
		return rendered
	return bilingual("A visitor brings news for today's work.", "방문객이 오늘의 공방 소식을 전합니다.")


func event_effect_label(effect_type: String) -> String:
	var labels := {
		"money": {"en": "Funds", "ko": "자금"},
		"commission_credit": {"en": "Commission reward", "ko": "의뢰 보상"},
		"market_slots": {"en": "Market lots", "ko": "시장 물량"},
		"market_modifier": {"en": "Market trend", "ko": "시장 동향"},
		"museum_trust": {"en": "Museum trust", "ko": "박물관 신뢰"},
		"integrity_warning": {"en": "Historical integrity", "ko": "역사 보존도"},
		"storage_damage": {"en": "Storage damage", "ko": "보관 손상"},
		"rarity_bonus": {"en": "Rare-maker interest", "ko": "희귀 제작자 관심"},
		"clue_bonus": {"en": "Extra clues", "ko": "추가 단서"},
		"restoration_discount": {"en": "Restoration cost", "ko": "수리 비용 절감"},
		"auction_fee_discount": {"en": "Auction fee", "ko": "경매 수수료 절감"},
		"inspection_bonus": {"en": "Inspection insight", "ko": "감정 보너스"},
		"acquisition_discount": {"en": "Acquisition cost", "ko": "매입가 할인"},
		"reputation": {"en": "Reputation", "ko": "평판"},
		"listing_bonus": {"en": "Listing appeal", "ko": "출품 매력"},
		"bidder_reach": {"en": "Bidder reach", "ko": "입찰자 유입"}
	}
	return localized_value(labels.get(effect_type, {"en": "Today's change", "ko": "오늘의 변화"}))


func signed_event_integer(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


func event_effect_value(effect: Dictionary, applied_amount: float) -> String:
	var effect_type := String(effect.get("type", ""))
	var target := String(effect.get("target", ""))
	if effect_type in ["money", "commission_credit"] or target == "money":
		return "¤ %s" % signed_event_integer(int(applied_amount))
	if effect_type.contains("bonus") or effect_type.contains("discount") or target.contains("bonus") or target.contains("discount"):
		return "%s%%" % signed_event_integer(roundi(applied_amount * 100.0))
	# Slot, count, trust, reputation and reach effects use the same integer
	# conversion as GameState. Remaining score-like effects are integers too.
	return signed_event_integer(int(applied_amount))


func event_effect_fact(effect: Dictionary, applied_amount: float) -> String:
	return "%s · %s" % [event_effect_label(String(effect.get("type", ""))), event_effect_value(effect, applied_amount)]


func show_event_dialogue(event_result: Dictionary = {}) -> void:
	if not event_result.is_empty():
		last_event_result = event_result
	var event_id: String = last_event_result.get("eventId", GameState.current_event_id)
	var event_data: Dictionary = RuntimeRegistry.get_event(event_id)
	var public_title := event_public_title(event_id)
	var public_description := event_public_description(event_id)
	var effect: Dictionary = last_event_result.get("effect", event_data.get("effect", {}))
	screen = "event"
	var body := screen_shell("%s — %s" % [bilingual("DAILY EVENT", "오늘의 사건"), compact_case_text(public_title, 40)])
	var layout := HBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 14)
	body.add_child(layout)
	var character_id := event_character_id(event_id)
	var applied_amount := float(last_event_result.get("appliedAmount", 0.0))
	var fact := compact_case_text(event_effect_label(String(effect.get("type", ""))), 32)
	if event_cue_state != "REQUEST":
		fact = event_effect_fact(effect, applied_amount)
	var cue := character_cue(character_id, event_cue_state, "", fact)
	layout.add_child(make_portrait_dialogue_panel(cue, 300, 295))
	var choice_panel := PanelContainer.new()
	choice_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_panel.add_theme_stylebox_override("panel", case_panel_style(Color("#151b1fe8"), Color("#75664b")))
	layout.add_child(choice_panel)
	var choice_column := VBoxContainer.new()
	choice_column.add_theme_constant_override("separation", 11)
	choice_panel.add_child(choice_column)
	choice_column.add_child(make_case_tile("briefing", bilingual("EVENT", "사건"), public_title, public_description))
	var event_description := make_label(compact_case_text(public_description, 80), 15, Color("#d9d1bd"))
	event_description.max_lines_visible = 2
	event_description.tooltip_text = public_description
	choice_column.add_child(event_description)
	if event_cue_state == "REQUEST":
		choice_column.add_child(make_case_tile("core_question", bilingual("CHOICE", "선택"), bilingual("Review what changed today.", "오늘 무엇이 달라졌는지 확인합니다.")))
		var reveal_button := make_case_icon_button("objective", bilingual("REVIEW RESULT", "결과 확인"), reveal_event_reaction, "EventRevealResult", Vector2(0, 58))
		reveal_button.tooltip_text = bilingual("Show the applied effect and the visitor's reaction.", "적용된 효과와 방문객의 반응을 확인합니다.")
		choice_column.add_child(reveal_button)
	else:
		var positive := event_cue_state == "REACTION_POS"
		choice_column.add_child(make_case_tile("support" if positive else "risk", bilingual("RESULT", "결과"), fact))
		var continue_button := mark_primary_action(make_case_icon_button("objective", bilingual("CONTINUE TO MARKET", "시장으로 이동"), show_market, "EventContinueMarket", Vector2(0, 58)))
		choice_column.add_child(continue_button)
	sync_public_interaction_state()


func reveal_event_reaction() -> void:
	var mapping := event_character_mapping(last_event_result.get("eventId", GameState.current_event_id))
	var polarity: String = mapping.get("outcomePolarity", "")
	if polarity == "NEGATIVE":
		event_cue_state = "REACTION_NEG"
	elif polarity == "POSITIVE":
		event_cue_state = "REACTION_POS"
	else:
		event_cue_state = "REACTION_POS" if float(last_event_result.get("appliedAmount", 0.0)) >= 0.0 else "REACTION_NEG"
	show_event_dialogue(last_event_result)
	sync_public_interaction_state("EventContinueMarket")
	restore_focus_by_name("EventContinueMarket")
	status.text = bilingual("The event result is now recorded.", "사건 결과를 기록했습니다.")


func show_title() -> void:
	screen = "title"
	clear_ui()
	play_bgm_for_screen(screen)
	set_world_mode("workshop")
	var veil := ColorRect.new()
	veil.name = "TitleBackdropVeil"
	veil.color = Color("#071014c9")
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(veil)
	var card := PanelContainer.new()
	card.name = "TitleCard"
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.position = Vector2(-380, -250)
	card.size = Vector2(760, 500)
	card.add_theme_stylebox_override("panel", title_card_style())
	ui.add_child(card)
	var center := VBoxContainer.new()
	center.name = "TitleMenu"
	center.add_theme_constant_override("separation", 10)
	card.add_child(center)
	var eyebrow := make_label(bilingual("A LITTLE HOUSE OF RELIC STORIES", "작은 유물 이야기 경매소"), 12, Color("#9fd6bd"))
	eyebrow.name = "TitleEyebrow"
	eyebrow.max_lines_visible = 1
	eyebrow.autowrap_mode = TextServer.AUTOWRAP_OFF
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(eyebrow)
	var hero := HBoxContainer.new()
	hero.name = "TitleHero"
	hero.add_theme_constant_override("separation", 16)
	center.add_child(hero)
	hero.add_child(make_title_character("shopkeeper", "TitleShopkeeper"))
	var title_words := VBoxContainer.new()
	title_words.name = "TitleWords"
	title_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_words.alignment = BoxContainer.ALIGNMENT_CENTER
	title_words.add_theme_constant_override("separation", 8)
	hero.add_child(title_words)
	var game_title := make_label("RELIC & RESERVE", 46, Color("#f0ce80"))
	game_title.name = "TitleLogoText"
	game_title.add_theme_constant_override("outline_size", 5)
	game_title.add_theme_color_override("font_outline_color", Color("#16130f"))
	game_title.max_lines_visible = 1
	game_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_words.add_child(game_title)
	var charm_row := HBoxContainer.new()
	charm_row.name = "TitleCharmRow"
	charm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	charm_row.add_theme_constant_override("separation", 10)
	charm_row.add_child(make_title_badge("clue_generic", Color("#9fd6bd"), "TitleCharmClue"))
	charm_row.add_child(make_title_badge("artifact", Color("#e3c681"), "TitleCharmArtifact"))
	charm_row.add_child(make_title_badge("support", Color("#d79a86"), "TitleCharmAuction"))
	title_words.add_child(charm_row)
	var subtitle := make_label(text_for("TITLE_SUBTITLE"), 16, Color("#e8e0cf"))
	subtitle.name = "TitleSubtitle"
	subtitle.max_lines_visible = 2
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_words.add_child(subtitle)
	hero.add_child(make_title_character("auctioneer", "TitleAuctioneer"))
	var loop_copy := make_label(bilingual("COLLECT  ·  INVESTIGATE  ·  RESTORE  ·  AUCTION", "수집  ·  조사  ·  복원  ·  경매"), 12, Color("#8fa5aa"))
	loop_copy.name = "TitleLoopCopy"
	loop_copy.max_lines_visible = 1
	loop_copy.autowrap_mode = TextServer.AUTOWRAP_OFF
	loop_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(loop_copy)
	var new_game_button := mark_primary_action(make_button(text_for("NEW_GAME"), start_progression_game_from_ui, "NewGameButton"))
	new_game_button.custom_minimum_size = Vector2(0, 52)
	center.add_child(new_game_button)
	var continue_button := make_button(text_for("CONTINUE"), continue_from_ui, "ContinueButton")
	continue_button.custom_minimum_size = Vector2(0, 46)
	center.add_child(continue_button)
	var utility_row := HBoxContainer.new()
	utility_row.name = "TitleUtilityRow"
	utility_row.add_theme_constant_override("separation", 8)
	center.add_child(utility_row)
	var settings_button := make_button(text_for("SETTINGS"), open_settings_from_ui, "TitleSettingsButton")
	settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_button.custom_minimum_size = Vector2(0, 42)
	utility_row.add_child(settings_button)
	var language_button := make_button(text_for("LANGUAGE"), toggle_language, "TitleLanguageButton")
	language_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_button.custom_minimum_size = Vector2(0, 42)
	utility_row.add_child(language_button)


func stage_score_text(value: Variant) -> String:
	var score_value := float(value)
	return str(roundi(score_value)) if is_equal_approx(score_value, float(roundi(score_value))) else "%.1f" % score_value


func stage_select_tooltip(definition: Dictionary, public_summary: Dictionary, replayable: bool) -> String:
	var lines := [
		compact_case_text(definition.get("title", ""), 42),
		compact_case_text(public_summary.get("goalLabel", ""), 72),
		bilingual("The recommendation never blocks a clear or unlock.", "권장 기준이며 클리어·해금을 막지 않습니다.")
	]
	if not replayable:
		lines.append(bilingual("Clear this Stage in the main journey before replaying it here.", "본편에서 이 스테이지를 클리어하면 여기서 재도전할 수 있습니다."))
	return "\n".join(lines)


func stage_replay_axis_label(axis_id: String) -> String:
	return localized_value({
		"investigation": {"en": "EVIDENCE", "ko": "근거"},
		"preservation": {"en": "PRESERVE", "ko": "보존"},
		"sale": {"en": "SALE", "ko": "판매"}
	}.get(axis_id, {}))


func stage_replay_axis_icon(axis_id: String) -> String:
	return String({
		"investigation": "citation",
		"preservation": "tool",
		"sale": "report"
	}.get(axis_id, "objective"))


func stage_replay_axis_score(axis_state: Dictionary) -> String:
	var value: Variant = axis_state.get("value", null)
	if not bool(axis_state.get("available", false)) or value == null:
		return "—"
	return str(clampi(roundi(float(value)), 0, 100))


func stage_replay_axis_status(axis_id: String, axis_state: Dictionary) -> String:
	var value: Variant = axis_state.get("value", null)
	if not bool(axis_state.get("available", false)) or value == null:
		return bilingual("NO RECORD", "기록 없음")
	var status_code := String(axis_state.get("statusCode", ""))
	return localized_value({
		"STRONG": {"en": "GOOD", "ko": "좋음"},
		"STEADY": {"en": "ON TRACK", "ko": "안정"},
		"FRAGILE": {"en": "NEEDS WORK", "ko": "보완 필요"}
	}.get(status_code, {"en": "RECORDED", "ko": "기록됨"}))


func make_stage_replay_axis_tile(axis_id: String, axis_state: Dictionary) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.name = "StageReplayAxis_%s" % axis_id
	tile.custom_minimum_size = Vector2(0, 72)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", case_panel_style(Color("#111a1be8"), Color("#75664b")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	tile.add_child(row)
	var icon := TextureRect.new()
	icon.name = "StageReplayAxisIcon_%s" % axis_id
	icon.texture = case_icon(stage_replay_axis_icon(axis_id))
	icon.custom_minimum_size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var label := make_label(stage_replay_axis_label(axis_id), 12, Color("#e3c681"))
	label.name = "StageReplayAxisLabel_%s" % axis_id
	label.max_lines_visible = 1
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(label)
	var score_row := HBoxContainer.new()
	score_row.add_theme_constant_override("separation", 8)
	words.add_child(score_row)
	var score := make_label(stage_replay_axis_score(axis_state), 21, Color("#f2e8cf"))
	score.name = "StageReplayAxisScore_%s" % axis_id
	score.max_lines_visible = 1
	score.autowrap_mode = TextServer.AUTOWRAP_OFF
	score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_row.add_child(score)
	var state := make_label(stage_replay_axis_status(axis_id, axis_state), 12, Color("#9fd6bd") if bool(axis_state.get("available", false)) else Color("#e59b7a"))
	state.name = "StageReplayAxisStatus_%s" % axis_id
	state.max_lines_visible = 1
	state.autowrap_mode = TextServer.AUTOWRAP_OFF
	state.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_row.add_child(state)
	var axis_copy := "%s · %s · %s" % [stage_replay_axis_label(axis_id), stage_replay_axis_score(axis_state), stage_replay_axis_status(axis_id, axis_state)]
	tile.tooltip_text = axis_copy
	return tile


func stage_replay_advice(feedback: Dictionary) -> String:
	var weakest := String(feedback.get("weakest", ""))
	var advice_code := String(feedback.get("adviceCode", ""))
	if advice_code == "STRENGTHEN_EVIDENCE" or weakest == "investigation":
		return bilingual("Cite more independent evidence.", "독립 근거를 더 인용해 보세요")
	if advice_code == "PROTECT_CONDITION" or weakest == "preservation":
		return bilingual("Use fewer interventions and preserve condition.", "개입을 줄이고 상태를 보존해 보세요")
	if advice_code == "IMPROVE_SALE" or weakest == "sale":
		var sale_axis: Dictionary = feedback.get("axes", {}).get("sale", {})
		var sale_unattempted := not bool(sale_axis.get("available", false)) or sale_axis.get("value", null) == null \
			or advice_code.contains("NO_ATTEMPT") or advice_code.contains("NOT_LISTED") or advice_code.contains("NO_RECORD")
		if sale_unattempted:
			return bilingual("List a prepared relic at auction.", "준비한 유물을 경매에 올려 보세요")
		return bilingual("Adjust the reserve and public claim.", "예약가와 공개 주장을 조정해 보세요")
	return bilingual("Compare the three records before replaying.", "세 기록을 비교한 뒤 다시 도전해 보세요")


func stage_pressure_summary(telemetry: Dictionary) -> String:
	if not bool(telemetry.get("available", false)):
		return ""
	var parts: Array = []
	var risk_actions := int(telemetry.get("investigationRiskActions", 0))
	var investigation_actions := int(telemetry.get("investigationActions", 0))
	if investigation_actions <= 0:
		parts.append(bilingual("NO CLUE RECORD", "조사 기록 없음"))
	else:
		parts.append(bilingual("RISK CLUES %d" % risk_actions, "위험 조사 %d" % risk_actions) if risk_actions > 0 else bilingual("SAFE CLUES", "안전 조사"))
	var relists := int(telemetry.get("relistCount", 0))
	if relists > 0:
		parts.append(bilingual("RELIST %d" % relists, "재출품 %d" % relists))
	else:
		var tool_count: int = telemetry.get("repairToolIdsUsed", []).size() if telemetry.get("repairToolIdsUsed", []) is Array else 0
		var summary_codes: Array = telemetry.get("summaryCodes", []) if telemetry.get("summaryCodes", []) is Array else []
		if summary_codes.has("TOOL_FOCUS_HIGH"):
			parts.append(bilingual("TOOL FOCUS HIGH", "도구 편중 높음"))
		elif tool_count > 0:
			parts.append(bilingual("TOOLS %d" % tool_count, "도구 %d종" % tool_count))
	return "%s · %s" % [bilingual("JUDGMENT LOG", "판단 기록"), " · ".join(parts)]


func make_stage_clear_card(public_summary: Dictionary, replay_feedback: Dictionary = {}, replay_telemetry: Dictionary = {}) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "StageClearCard"
	panel.add_theme_stylebox_override("panel", case_panel_style(Color("#17231fe8"), Color("#9fd6bd"), 2))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var primary_row := HBoxContainer.new()
	primary_row.name = "StageClearPrimaryRow"
	primary_row.add_theme_constant_override("separation", 12)
	column.add_child(primary_row)
	var heading := make_label("STAGE CLEAR", 24, Color("#9fd6bd"))
	heading.name = "StageClearHeading"
	heading.max_lines_visible = 1
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary_row.add_child(heading)
	var score_line := make_label("%s · %s %s" % [String(public_summary.get("grade", bilingual("CLEARED", "클리어"))), bilingual("SCORE", "점수"), stage_score_text(public_summary.get("current", 0.0))], 18, Color("#f2e8cf"))
	score_line.name = "StageClearScore"
	score_line.max_lines_visible = 1
	score_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	score_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary_row.add_child(score_line)
	var fact_row := HBoxContainer.new()
	fact_row.name = "StageClearFactRow"
	fact_row.add_theme_constant_override("separation", 12)
	column.add_child(fact_row)
	var target_line_text := bilingual("RECOMMENDED TARGET MET", "권장 목표 달성")
	if not bool(public_summary.get("metTarget", false)):
		var gap := maxi(0, ceili(float(public_summary.get("target", 0.0)) - float(public_summary.get("current", 0.0))))
		target_line_text = bilingual("%d points to the recommendation" % gap, "권장 목표까지 %d점" % gap)
	var target_line := make_label(target_line_text, 14, Color("#e3c681"))
	target_line.name = "StageClearTarget"
	target_line.max_lines_visible = 1
	target_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	target_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	target_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fact_row.add_child(target_line)
	var unlock_text := bilingual("NEXT STAGE UNLOCKED", "다음 스테이지 해금") if bool(public_summary.get("hasNextStage", false)) and bool(public_summary.get("nextStageUnlocked", false)) else bilingual("FINAL STAGE COMPLETE", "최종 스테이지 완료")
	var unlock_line := make_label(unlock_text, 14, Color("#9fd6bd"))
	unlock_line.name = "StageClearUnlock"
	unlock_line.max_lines_visible = 1
	unlock_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	unlock_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unlock_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fact_row.add_child(unlock_line)
	var best_prefix := bilingual("NEW RECORD · ", "신기록 · ") if bool(public_summary.get("isNewBest", false)) else ""
	var best_line := make_label("%sBEST %s" % [best_prefix, stage_score_text(public_summary.get("best", 0.0))], 15, Color("#b7c4c8"))
	best_line.name = "StageClearBest"
	best_line.max_lines_visible = 1
	best_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	best_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	best_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fact_row.add_child(best_line)
	if not replay_feedback.is_empty():
		var axes: Dictionary = replay_feedback.get("axes", {})
		var axis_row := HBoxContainer.new()
		axis_row.name = "StageReplayAxes"
		axis_row.add_theme_constant_override("separation", 8)
		column.add_child(axis_row)
		for axis_id: String in ["investigation", "preservation", "sale"]:
			axis_row.add_child(make_stage_replay_axis_tile(axis_id, axes.get(axis_id, {})))
		var pressure_summary := stage_pressure_summary(replay_telemetry)
		if not pressure_summary.is_empty():
			var pressure_row := HBoxContainer.new()
			pressure_row.name = "StagePressureSummary"
			pressure_row.add_theme_constant_override("separation", 8)
			column.add_child(pressure_row)
			var pressure_icon := TextureRect.new()
			pressure_icon.name = "StagePressureIcon"
			pressure_icon.texture = case_icon("risk")
			pressure_icon.custom_minimum_size = Vector2(24, 24)
			pressure_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pressure_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pressure_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pressure_row.add_child(pressure_icon)
			var pressure_label := make_label(pressure_summary, 13, Color("#b7c4c8"))
			pressure_label.name = "StagePressureText"
			pressure_label.max_lines_visible = 1
			pressure_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			pressure_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			pressure_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pressure_row.add_child(pressure_label)
		var replay_advice := stage_replay_advice(replay_feedback)
		var advice_line := make_label("%s · %s" % [bilingual("REPLAY TIP", "재도전 팁"), replay_advice], 14, Color("#e59b7a"))
		advice_line.name = "StageClearAdvice"
		advice_line.max_lines_visible = 1
		advice_line.autowrap_mode = TextServer.AUTOWRAP_OFF
		advice_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		advice_line.tooltip_text = replay_advice
		column.add_child(advice_line)
	elif not bool(public_summary.get("metTarget", false)) and not String(public_summary.get("advice", "")).is_empty():
		var legacy_advice_line := make_label("%s · %s" % [bilingual("IMPROVEMENT", "개선 포인트"), compact_case_text(public_summary.get("advice", ""), 68)], 14, Color("#e59b7a"))
		legacy_advice_line.name = "StageClearAdvice"
		legacy_advice_line.max_lines_visible = 1
		legacy_advice_line.tooltip_text = String(public_summary.get("advice", ""))
		column.add_child(legacy_advice_line)
	return panel


func show_stage_select() -> void:
	screen = "stage_select"
	var body := screen_shell(bilingual("STAGE PROGRESS — REPLAY CLEARED", "스테이지 진행 — 클리어 재도전"))
	var profile: Dictionary = GameState.player_profile
	var highest := int(profile.get("highestUnlockedStage", 1))
	var cleared: Array = profile.get("clearedStages", [])
	var summary := make_label(bilingual("NEW GAME advances to the first uncleared Stage. This screen is for cleared-stage replay.", "새 게임은 첫 미클리어 스테이지로 진행합니다. 이 화면은 클리어 스테이지 재도전용입니다."), 15, Color("#b7c4c8"))
	summary.max_lines_visible = 2
	body.add_child(summary)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for stage_id in range(1, 11):
		var definition := RuntimeRegistry.get_stage_definition(stage_id)
		var completed := cleared.has(stage_id)
		var replayable := completed
		var best_score := float(profile.get("stageBest", {}).get(str(stage_id), 0.0))
		var public_summary := GameState.stage_public_summary(stage_id, best_score if completed else null)
		var state_text := bilingual("CLEARED", "클리어") if completed else bilingual("STORY LOCKED", "본편 잠김")
		var attempt_text := "BEST %s %s" % [String(public_summary.get("grade", "")), stage_score_text(best_score)] if completed else bilingual("FIRST TRY", "첫 도전")
		var caption := "%s %d · %s\n%s %s · %s" % [bilingual("STAGE", "스테이지"), stage_id, state_text, bilingual("RECOMMENDED", "권장"), stage_score_text(public_summary.get("target", 0.0)), attempt_text]
		var icon_name := "support" if completed else "locked"
		var button := make_case_icon_button(icon_name, caption, func(): start_stage_from_ui(stage_id), "StageSelect_%02d" % stage_id, Vector2(225, 94))
		button.disabled = not replayable
		button.tooltip_text = stage_select_tooltip(definition, public_summary, replayable)
		grid.add_child(button)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	body.add_child(footer)
	var progress_label := make_label("%s %d / 10" % [bilingual("HIGHEST UNLOCKED", "최고 해금 단계"), highest], 14, Color("#e3c681"))
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(progress_label)
	var replay_help := make_case_icon_button("briefing", bilingual("REPLAY GUIDE", "도움말 다시 보기"), replay_tutorial_guidance_from_ui, "TutorialReplayButton", Vector2(220, 42))
	replay_help.tooltip_text = bilingual("Restart the six-step guide with Stage 1.", "스테이지 1에서 여섯 단계 안내를 다시 시작합니다.")
	footer.add_child(replay_help)


func replay_tutorial_guidance_from_ui() -> void:
	GameState.reset_tutorial_guidance()
	var result := GameState.new_game(1)
	if not bool(result.get("ok", false)):
		show_stage_select()
		status.text = bilingual("Stage 1 guidance could not be restarted.", "스테이지 1 안내를 다시 시작하지 못했습니다.")
		return
	show_campaign()
	status.text = bilingual("Stage 1 guidance is active again.", "스테이지 1 안내를 다시 시작했습니다.")


func skip_tutorial_from_ui() -> void:
	var result: Dictionary = GameState.skip_tutorial_guidance()
	if not bool(result.get("ok", false)):
		status.text = bilingual("The guide could not be skipped right now.", "지금은 튜토리얼을 건너뛸 수 없습니다.")
		return
	refresh_current_screen()
	status.text = bilingual("Guide skipped. You can replay it from Stage Select.", "튜토리얼을 건너뛰었습니다. 스테이지 선택에서 다시 볼 수 있습니다.")


func start_stage_from_ui(stage_id: int) -> void:
	var result := GameState.new_game(stage_id)
	if not bool(result.get("ok", false)):
		show_stage_select()
		status.text = bilingual("That stage is still locked.", "아직 잠긴 스테이지입니다.")
		return
	market_character_state = "WELCOME"
	market_character_dialogue = ""
	market_character_fact = ""
	market_active_lot_id = ""
	show_campaign()
	status.text = "%s %d · ×%.2f" % [bilingual("STAGE STARTED", "스테이지 시작"), stage_id, float(result.get("difficultyMultiplier", 1.0))]


func show_workshop() -> void:
	screen = "workshop"
	var body := screen_shell("%s — %s" % [text_for("WORKSHOP"), text_for("CONSERVATION_FLOOR")])
	body.add_child(make_label(text_for("WORKSHOP_SUMMARY"), 18))
	body.add_child(make_label(text_for("WORKSHOP_HELP"), 16, Color("#a8b0ad")))
	if not GameState.current_event_id.is_empty():
		body.add_child(make_label("%s: %s — %s" % [bilingual("TODAY", "오늘"), event_public_title(GameState.current_event_id), event_public_description(GameState.current_event_id)], 17, Color("#d6b36a")))
	body.add_child(make_label(text_format("WORKSHOP_STATUS", [friendly_act_title(String(GameState.campaign_state.currentAct)), int(GameState.campaign_state.museumTrust), int(GameState.campaign_state.historicalIntegrity)]), 18))


func market_lot_by_id(lot_id: String) -> Dictionary:
	for lot: Dictionary in GameState.market_roster:
		if String(lot.get("lotId", "")) == lot_id:
			return lot
	return {}


func market_lot_index(lot_id: String) -> int:
	for lot_index: int in GameState.market_roster.size():
		if String(GameState.market_roster[lot_index].get("lotId", "")) == lot_id:
			return lot_index
	return -1


func market_cue_copy() -> Dictionary:
	var dialogue := market_character_dialogue
	var fact := market_character_fact
	var lot := market_lot_by_id(market_active_lot_id)
	var spec: Dictionary = RuntimeRegistry.get_spec(String(lot.get("specId", ""))) if not lot.is_empty() else {}
	match market_character_state:
		"OFFER":
			dialogue = bilingual("Worth a close look before you decide.", "결정하기 전에 찬찬히 살펴보세요.")
			fact = "%s · ¤%d" % [compact_case_text(spec.get("displayName", bilingual("today's lot", "오늘의 유물")), 24), int(lot.get("price", 0))]
		"PURCHASE_OK":
			dialogue = bilingual("Good choice. It is headed to your bench.", "좋은 선택이에요. 작업대로 보내 드릴게요.")
			fact = bilingual("PURCHASED", "구매 완료") + " · ¤%d" % int(lot.get("price", 0))
		"PURCHASE_FAIL":
			dialogue = bilingual("Check your funds and storage space.", "예산과 보관함 여유를 확인해 주세요.")
			fact = bilingual("UNAVAILABLE", "구매 불가") + " · " + compact_case_text(spec.get("displayName", bilingual("the selected lot", "선택한 유물")), 24)
	return {"dialogue": dialogue, "fact": fact}


func show_market() -> void:
	screen = "market"
	var body := screen_shell("%s — %s" % [text_for("MARKET"), text_for("SEEDED_DAILY_LOTS")])
	var layout := HBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12)
	body.add_child(layout)
	var cue_copy := market_cue_copy()
	market_character_dialogue = String(cue_copy.get("dialogue", ""))
	market_character_fact = String(cue_copy.get("fact", ""))
	var shop_cue := character_cue("shopkeeper", market_character_state, market_character_dialogue, market_character_fact)
	layout.add_child(make_portrait_dialogue_panel(shop_cue, 250, 278))
	var market_column := VBoxContainer.new()
	market_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	market_column.add_theme_constant_override("separation", 7)
	layout.add_child(market_column)
	var market_help := make_label(compact_case_text(text_for("MARKET_HELP"), 72), 14, Color("#a8b0ad"))
	market_help.max_lines_visible = 2
	market_column.add_child(market_help)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	market_column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)
	for lot_index: int in GameState.market_roster.size():
		var lot: Dictionary = GameState.market_roster[lot_index]
		var spec := RuntimeRegistry.get_spec(lot.specId)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 58)
		var label := make_label("%s\n%s · %s   |   ¤%d" % [spec.displayName, friendly_artifact_visual(spec), spec.era, int(lot.price)], 15)
		label.max_lines_visible = 2
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var lot_id: String = lot.lotId
		var offer_button := make_button(bilingual("OFFER", "제안"), func(): preview_market_offer(lot_id), "MarketOffer_%d" % lot_index)
		offer_button.disabled = GameState.gameplay_mutation_locked()
		offer_button.custom_minimum_size = Vector2(82, 42)
		offer_button.tooltip_text = bilingual("Hear the shopkeeper's short offer.", "상점원의 짧은 제안을 듣습니다.")
		row.add_child(offer_button)
		var buy_button := make_button(text_for("SOLD") if lot.sold else text_for("BUY"), func(): buy_market_from_ui(lot_id), "MarketLot_%d" % lot_index)
		buy_button.disabled = bool(lot.sold) or GameState.gameplay_mutation_locked()
		buy_button.custom_minimum_size = Vector2(92, 42)
		row.add_child(buy_button)
		rows.add_child(row)
	sync_public_interaction_state()


func preview_market_offer(lot_id: String) -> void:
	for lot: Dictionary in GameState.market_roster:
		if lot.get("lotId", "") != lot_id:
			continue
		market_character_state = "OFFER"
		market_active_lot_id = lot_id
		market_character_dialogue = ""
		market_character_fact = ""
		show_market()
		var focus_name := "MarketOffer_%d" % market_lot_index(lot_id)
		sync_public_interaction_state(focus_name)
		restore_focus_by_name(focus_name)
		status.text = bilingual("Offer selected. Purchase remains a separate action.", "제안을 골랐습니다. 구매는 별도 행동입니다.")
		return


func buy_market_from_ui(lot_id: String) -> void:
	if GameState.buy_market_lot(lot_id):
		play_sfx("purchase")
		market_character_state = "PURCHASE_OK"
		market_active_lot_id = lot_id
		market_character_dialogue = ""
		market_character_fact = ""
		show_market()
		var success_focus := "MarketLot_%d" % market_lot_index(lot_id)
		sync_public_interaction_state(success_focus)
		restore_focus_by_name(success_focus)
		status.text = text_for("LOT_ACQUIRED")
	else:
		market_character_state = "PURCHASE_FAIL"
		market_active_lot_id = lot_id
		market_character_dialogue = ""
		market_character_fact = ""
		show_market()
		var failure_focus := "MarketLot_%d" % market_lot_index(lot_id)
		sync_public_interaction_state(failure_focus)
		restore_focus_by_name(failure_focus)
		status.text = friendly_pending_auction_error(GameState.last_action_error) if GameState.last_action_error == "PENDING_AUCTION_LOCKED" else text_for("BUY_BLOCKED")


func inventory_artifact_index(instance_id: String) -> int:
	for artifact_index in GameState.inventory.size():
		if String(GameState.inventory[artifact_index].get("uniqueId", "")) == instance_id:
			return artifact_index
	return -1


func inventory_artifact_by_uid(instance_id: String) -> Dictionary:
	var artifact_index := inventory_artifact_index(instance_id)
	return GameState.inventory[artifact_index] if artifact_index >= 0 else {}


func select_inventory_card(instance_id: String) -> void:
	if inventory_artifact_index(instance_id) < 0:
		return
	inventory_selected_uid = instance_id
	show_inventory()
	status.text = bilingual("Relic details selected. Inspect remains a separate action.", "유물 상세를 골랐습니다. 검사는 별도 행동입니다.")


func change_inventory_page(page_delta: int) -> void:
	var page_count := maxi(1, ceili(float(GameState.inventory.size()) / 8.0))
	inventory_page = clampi(inventory_page + page_delta, 0, page_count - 1)
	var page_start := inventory_page * 8
	inventory_selected_uid = String(GameState.inventory[page_start].get("uniqueId", "")) if page_start < GameState.inventory.size() else ""
	show_inventory()


func inspect_inventory_selection_from_ui() -> void:
	var artifact := inventory_artifact_by_uid(inventory_selected_uid)
	if artifact.is_empty():
		status.text = bilingual("Choose a relic first.", "유물을 먼저 고르세요.")
		return
	load_artifact(artifact)
	show_inspection()


func make_inventory_card(artifact: Dictionary, slot_index: int, is_selected: bool, compact: bool = false) -> Button:
	var damage_count: int = artifact.get("damageInstances", []).size() if artifact.get("damageInstances", []) is Array else 0
	var clue_count: int = artifact.get("knownClues", []).size() if artifact.get("knownClues", []) is Array else 0
	var card_text := "%s\n¤%d · %s %d · %s %d" % [
		String(artifact.get("displayName", bilingual("Relic", "유물"))),
		int(artifact.get("estimatedValue", 0)),
		bilingual("DAMAGE", "손상"), damage_count,
		bilingual("CLUES", "단서"), clue_count
	] if compact else "%s\n¤%d\n%s %d · %s %d" % [
		String(artifact.get("displayName", bilingual("Relic", "유물"))),
		int(artifact.get("estimatedValue", 0)),
		bilingual("DAMAGE", "손상"), damage_count,
		bilingual("CLUES", "단서"), clue_count
	]
	var instance_id := String(artifact.get("uniqueId", ""))
	var card := make_case_icon_button("artifact", card_text, func(): select_inventory_card(instance_id), "InventoryCard_%d" % slot_index, Vector2(584, 58 if compact else 68))
	card.add_theme_font_size_override("font_size", scaled_font_size(12 if compact else 13))
	card.add_theme_constant_override("icon_max_width", 32 if compact else 42)
	var normal_style := case_panel_style(
		Color("#17231fe8") if is_selected else Color("#151b1fe8"),
		Color("#9fd6bd") if is_selected else Color("#5d625f"),
		2 if is_selected else 1
	)
	if compact:
		normal_style.content_margin_top = 4
		normal_style.content_margin_bottom = 4
	card.add_theme_stylebox_override("normal", normal_style)
	card.tooltip_text = "%s\n%s · ¤%d" % [String(artifact.get("displayName", "")), friendly_artifact_visual(artifact), int(artifact.get("estimatedValue", 0))]
	return card


func make_inventory_detail(artifact: Dictionary, artifact_index: int, compact: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "InventoryDetailPanel"
	panel.custom_minimum_size = Vector2(0, 72 if compact else 84)
	var panel_style := case_panel_style(Color("#17201ee8"), Color("#e3c681"), 2)
	if compact:
		panel_style.content_margin_top = 5
		panel_style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", panel_style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = case_icon("artifact")
	icon.custom_minimum_size = Vector2(44, 44) if compact else Vector2(54, 54)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 1)
	row.add_child(words)
	var name_label := make_label(String(artifact.get("displayName", bilingual("Relic", "유물"))), 15 if compact else 17, Color("#e3c681"))
	name_label.name = "InventoryDetailName"
	name_label.max_lines_visible = 1
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(name_label)
	var case_id := String(artifact.get("caseId", ""))
	var case_text := "%s · %s" % [bilingual("CASE", "사건"), friendly_case_name(case_id)] if not case_id.is_empty() else bilingual("OPEN MARKET RELIC", "시장 입수 유물")
	var case_label := make_label(case_text, 12 if compact else 13, Color("#b7c4c8"))
	case_label.name = "InventoryDetailCase"
	case_label.max_lines_visible = 1
	case_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	case_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(case_label)
	var damage_count: int = artifact.get("damageInstances", []).size() if artifact.get("damageInstances", []) is Array else 0
	var clue_count: int = artifact.get("knownClues", []).size() if artifact.get("knownClues", []) is Array else 0
	var stats := make_label("%s %d · %s %d · ¤%d" % [bilingual("DAMAGE", "손상"), damage_count, bilingual("CLUES", "단서"), clue_count, int(artifact.get("estimatedValue", 0))], 12 if compact else 13, Color("#9fd6bd"))
	stats.name = "InventoryDetailStats"
	stats.max_lines_visible = 1
	stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	words.add_child(stats)
	var inspect_button := make_case_icon_button("objective", text_for("PLACE_INSPECT"), inspect_inventory_selection_from_ui, "InspectLot_%d" % artifact_index, Vector2(250, 50) if compact else Vector2(270, 54))
	if compact:
		inspect_button.add_theme_font_size_override("font_size", scaled_font_size(12))
		inspect_button.add_theme_constant_override("icon_max_width", 32)
	row.add_child(inspect_button)
	return panel


func show_inventory() -> void:
	screen = "inventory"
	var pending := GameState.pending_auction_public_state()
	var dense_receipt := bool(pending.get("ok", false)) and String(pending.get("status", "")) == "COMMITTED" and not bool(pending.get("grandReserve", false))
	var body := screen_shell("%s — %s" % [text_for("INVENTORY"), text_for("WORKBENCH_PLACEMENT")])
	if dense_receipt:
		# One illustrated line keeps the exactly-once receipt visible without
		# pushing an 8-card page and its Inspect action under navigation.
		var receipt_recap := make_auction_causal_recap(true)
		receipt_recap.name = "InventoryAuctionReceiptRecap"
		receipt_recap.tooltip_text = bilingual("Latest auction receipt: choice, bidder response, frozen result.", "최근 경매 기록: 내 선택, 입찰자 반응, 확정 결과.")
		body.add_child(receipt_recap)
	if GameState.inventory.is_empty():
		inventory_page = 0
		inventory_selected_uid = ""
		body.add_child(make_case_tile("artifact", text_for("INVENTORY"), text_for("NO_LOTS")))
		return
	var page_count := maxi(1, ceili(float(GameState.inventory.size()) / 8.0))
	inventory_page = clampi(inventory_page, 0, page_count - 1)
	var selected_index := inventory_artifact_index(inventory_selected_uid)
	if selected_index < 0:
		selected_index = inventory_page * 8
		inventory_selected_uid = String(GameState.inventory[selected_index].get("uniqueId", ""))
	else:
		inventory_page = selected_index / 8
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	body.add_child(progress_row)
	var progress := make_label("%s %d · %s %d / %d" % [bilingual("RELICS", "유물"), GameState.inventory.size(), bilingual("PAGE", "쪽"), inventory_page + 1, page_count], 16, Color("#e3c681"))
	progress.name = "InventoryProgress"
	progress.max_lines_visible = 1
	progress.autowrap_mode = TextServer.AUTOWRAP_OFF
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(progress)
	var previous := make_case_icon_button("briefing", bilingual("PREVIOUS", "이전"), func(): change_inventory_page(-1), "InventoryPrev", Vector2(132, 36))
	previous.disabled = inventory_page <= 0
	progress_row.add_child(previous)
	var page_label := make_label("%d / %d" % [inventory_page + 1, page_count], 14, Color("#b7c4c8"))
	page_label.name = "InventoryPage"
	page_label.custom_minimum_size = Vector2(64, 36)
	page_label.max_lines_visible = 1
	page_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_row.add_child(page_label)
	var next := make_case_icon_button("briefing", bilingual("NEXT", "다음"), func(): change_inventory_page(1), "InventoryNext", Vector2(132, 36))
	next.disabled = inventory_page >= page_count - 1
	progress_row.add_child(next)
	var grid := GridContainer.new()
	grid.name = "InventoryGrid"
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	var page_start := inventory_page * 8
	var page_end := mini(page_start + 8, GameState.inventory.size())
	for artifact_index in range(page_start, page_end):
		var artifact: Dictionary = GameState.inventory[artifact_index]
		grid.add_child(make_inventory_card(artifact, artifact_index - page_start, String(artifact.get("uniqueId", "")) == inventory_selected_uid, dense_receipt))
	var detail_artifact := inventory_artifact_by_uid(inventory_selected_uid)
	if not detail_artifact.is_empty():
		body.add_child(make_inventory_detail(detail_artifact, inventory_artifact_index(inventory_selected_uid), dense_receipt))


func show_inspection() -> void:
	screen = "inspection"
	var body := screen_shell("%s — %s" % [text_for("INSPECTION"), text_for("ORBIT_ZOOM_EVIDENCE")])
	if selected.is_empty():
		body.add_child(make_label(text_for("SELECT_INVENTORY_LOT")))
		return
	var columns := HBoxContainer.new()
	columns.name = "InspectionColumns"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	body.add_child(columns)
	var info := VBoxContainer.new()
	info.name = "InspectionInfoColumn"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(make_label(selected.displayName, 24, Color("#e3c681")))
	info.add_child(make_label(text_for("INSPECTION_HELP"), 15))
	info.add_child(make_label(text_format("INSPECTION_STATS", [damage_marks.size(), int(selected.cleanliness), int(selected.mechanicalCondition), int(selected.historicalIntegrity), int(selected.get("restorationCost", 0.0)), friendly_artifact_visual(selected)]), 16))
	var observable: Variant = selected.get("inspectionObservable", {})
	if not localized_value(observable).is_empty():
		var observable_tile := make_case_tile("clue_generic", bilingual("VISIBLE CLUE", "눈에 띄는 단서"), observable, localized_value(observable))
		observable_tile.name = "InspectionObservableTile"
		# Keep the authored 3D workpiece readable behind the compact clue card.
		# The card remains high-contrast while no longer becoming an opaque wall at
		# the actual 1280x720 inspection scale.
		observable_tile.add_theme_stylebox_override("panel", case_panel_style(Color("#17231fb8"), Color("#e3c681"), 1))
		info.add_child(observable_tile)
	columns.add_child(info)
	var controls := VBoxContainer.new()
	controls.name = "InspectionControlsColumn"
	controls.custom_minimum_size = Vector2(470, 0)
	columns.add_child(controls)
	var clue_grid := GridContainer.new()
	clue_grid.name = "InspectionClueGrid"
	clue_grid.columns = 2
	clue_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clue_grid.add_theme_constant_override("h_separation", 8)
	clue_grid.add_theme_constant_override("v_separation", 6)
	for clue_value: String in selected.possibleClues.slice(0, mini(8, selected.possibleClues.size())):
		var clue: String = clue_value
		var clue_button := make_button(inspection_clue_button_label(clue), func(): inspect_from_ui(clue), "Clue_%s" % clue)
		clue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clue_button.clip_text = true
		clue_button.tooltip_text = text_format("INSPECT_CLUE", [friendly_clue_label(clue)])
		clue_grid.add_child(clue_button)
	controls.add_child(clue_grid)
	# Authentication is the next major route after a repair. Keep it above the
	# optional repair detail stack so the compact tutorial rail never pushes the
	# action beneath navigation at 1280x720.
	var route_actions := HBoxContainer.new()
	route_actions.name = "InspectionRouteActions"
	route_actions.add_theme_constant_override("separation", 8)
	controls.add_child(route_actions)
	var authenticate_button := make_button(text_for("AUTHENTICATION"), func(): GameState.authenticate(selected); show_authentication(), "AuthenticateButton")
	authenticate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route_actions.add_child(authenticate_button)
	if not selected.get("caseId", "").is_empty():
		var dossier_button := make_button(bilingual("OPEN DOSSIER", "사건 서류"), func(): show_case_dossier(selected.caseId), "OpenCaseDossier")
		dossier_button.custom_minimum_size = Vector2(170, 42)
		dossier_button.tooltip_text = bilingual("Open the related case dossier.", "연결된 사건 서류를 엽니다.")
		route_actions.add_child(dossier_button)
	var required_repair_tools: Array = GameState.repair_requirements(selected).get("requiredTools", [])
	if not required_repair_tools.is_empty():
		var repair_tradeoff: Variant = selected.get("repairProfile", {}).get("interventionTradeoff", {})
		if not localized_value(repair_tradeoff).is_empty():
			var tradeoff_tile := make_case_tile("risk", bilingual("REPAIR TRADE-OFF", "수리 판단"), repair_tradeoff, localized_value(repair_tradeoff))
			tradeoff_tile.name = "RepairTradeoffTile"
			tradeoff_tile.add_theme_stylebox_override("panel", case_panel_style(Color("#151b1fb8"), Color("#e59b7a"), 1))
			controls.add_child(tradeoff_tile)
		var repair_tool_hint := make_label(bilingual("REPAIR · use any one recommended tool", "수리 · 권장 도구 중 하나를 사용"), 15, Color("#e3c681"))
		repair_tool_hint.name = "RepairToolAnyOneHint"
		repair_tool_hint.max_lines_visible = 1
		controls.add_child(repair_tool_hint)
		var repair_tool_grid := GridContainer.new()
		repair_tool_grid.name = "RepairToolGrid"
		repair_tool_grid.columns = 2
		repair_tool_grid.add_theme_constant_override("h_separation", 8)
		repair_tool_grid.add_theme_constant_override("v_separation", 8)
		for tool_value: Variant in required_repair_tools:
			var repair_tool_id := String(tool_value)
			var repair_tool_selected := GameState.selected_tool == repair_tool_id
			var availability := bilingual("SELECTED", "선택됨") if repair_tool_selected else bilingual("AVAILABLE", "사용 가능")
			var repair_tool_button := make_case_icon_button(
				"tool",
				"%s\n%s" % [friendly_case_tool(repair_tool_id), availability],
				func(): select_repair_tool_from_ui(repair_tool_id),
				"RepairTool_%s" % repair_tool_id,
				Vector2(220, 54)
			)
			repair_tool_button.tooltip_text = bilingual("Select this recommended repair tool.", "이 권장 수리 도구를 선택합니다.")
			repair_tool_grid.add_child(repair_tool_button)
		controls.add_child(repair_tool_grid)
	var action_grid := GridContainer.new()
	action_grid.columns = 2
	action_grid.add_child(make_button(text_for("SOFT_BRUSH"), func(): restore_from_ui("clean", "soft_brush"), "Tool_soft_brush"))
	action_grid.add_child(make_button(text_for("RUST_TREATMENT"), func(): restore_from_ui("clean", "rust_treatment"), "Tool_rust_treatment"))
	action_grid.add_child(make_button(text_for("REPAIR"), func(): restore_from_ui("repair"), "Tool_repair"))
	var operations := RuntimeRegistry.supported_operations(selected.artifactSpecId)
	var disassembly_button := make_button(text_for("DISASSEMBLE_PANEL") if operations.disassembly else text_for("DISASSEMBLY_UNSUPPORTED"), func(): restore_from_ui("disassemble"), "Tool_disassemble")
	disassembly_button.disabled = not bool(operations.disassembly)
	action_grid.add_child(disassembly_button)
	controls.add_child(action_grid)


func inspect_from_ui(clue: String) -> void:
	var result := GameState.inspect_clue(selected, clue)
	status.text = result.get("observation", text_for("UNSUPPORTED_CLUE"))


func restore_from_ui(action: String, tool_id: String = "") -> void:
	var message := ""
	if action == "clean":
		play_sfx("brush")
		message = GameState.clean(selected, tool_id)
	elif action == "repair":
		play_sfx("metal_click")
		message = GameState.repair(selected)
	elif action == "disassemble":
		message = text_for("PANEL_DETACHED") if GameState.disassemble(selected, "panel") else text_for("NO_DETACHABLE_PANEL")
	refresh_workpiece_visuals()
	show_inspection()
	status.text = friendly_pending_auction_error(GameState.last_action_error) if GameState.last_action_error == "PENDING_AUCTION_LOCKED" else friendly_restoration_status(message)


func select_repair_tool_from_ui(tool_id: String) -> void:
	var tool_selected := GameState.select_tool(tool_id)
	show_inspection()
	status.text = bilingual("Repair tool selected: %s", "수리 도구 선택: %s") % friendly_case_tool(tool_id) if tool_selected else bilingual("Tool unavailable.", "도구를 사용할 수 없습니다.")


func authentication_case_public_state() -> Dictionary:
	var case_id := String(selected.get("caseId", ""))
	return GameState.get_case_public_state(case_id) if not case_id.is_empty() else {}


func authentication_public_evidence_row(evidence: Dictionary, public_state: Dictionary) -> Dictionary:
	var clue_id := String(evidence.get("clueType", ""))
	return case_evidence_row(public_state, clue_id) if not public_state.is_empty() else {}


func authentication_evidence_relation_label(evidence: Dictionary, public_row: Dictionary) -> String:
	var saw_support := false
	var saw_refute := false
	for relation_value: Variant in public_row.get("relations", []):
		if not relation_value is Dictionary:
			continue
		if String(relation_value.get("stance", "")) == "SUPPORT":
			saw_support = true
		elif String(relation_value.get("stance", "")) == "REFUTE":
			saw_refute = true
	if public_row.is_empty():
		saw_support = evidence.get("supports", []) is Array and not evidence.get("supports", []).is_empty()
		saw_refute = evidence.get("contradicts", []) is Array and not evidence.get("contradicts", []).is_empty()
	if saw_support and saw_refute:
		return bilingual("MIXED", "혼합")
	if saw_support:
		return bilingual("SUPPORT", "지지")
	if saw_refute:
		return bilingual("REFUTE", "반박")
	return bilingual("OBSERVED", "관찰")


func select_authentication_evidence(evidence_index: int) -> void:
	if evidence_index < 0 or evidence_index >= selected.get("evidence", []).size():
		return
	authentication_evidence_index = evidence_index
	authentication_evidence_page = evidence_index / 6
	show_authentication()
	status.text = bilingual("Evidence detail opened. No conclusion was changed.", "근거 상세를 열었습니다. 결론은 바뀌지 않았습니다.")


func change_authentication_evidence_page(page_delta: int) -> void:
	var evidence_count: int = selected.get("evidence", []).size() if selected.get("evidence", []) is Array else 0
	var page_count := maxi(1, ceili(float(evidence_count) / 6.0))
	authentication_evidence_page = clampi(authentication_evidence_page + page_delta, 0, page_count - 1)
	authentication_evidence_index = mini(authentication_evidence_page * 6, maxi(0, evidence_count - 1))
	show_authentication()


func make_authentication_evidence_card(evidence: Dictionary, public_state: Dictionary, evidence_index: int, slot_index: int) -> Button:
	var public_row := authentication_public_evidence_row(evidence, public_state)
	var source_kind := String(public_row.get("sourceKind", ""))
	var relation_label := authentication_evidence_relation_label(evidence, public_row)
	var reliability_label := case_reliability_label(String(public_row.get("reliability", "UNSPECIFIED")))
	var title := authentication_evidence_label(evidence)
	var card_text := "%s\n%s · %s" % [compact_case_text(title, 34), relation_label, reliability_label]
	var card := make_case_icon_button(
		case_source_icon(source_kind),
		card_text,
		func(): select_authentication_evidence(evidence_index),
		"AuthenticationEvidenceCard_%d" % slot_index,
		Vector2(274, 58)
	)
	card.add_theme_font_size_override("font_size", scaled_font_size(12))
	card.add_theme_constant_override("icon_max_width", 34)
	var is_selected := evidence_index == authentication_evidence_index
	card.add_theme_stylebox_override("normal", case_panel_style(
		Color("#17231fe8") if is_selected else Color("#151b1fe8"),
		Color("#9fd6bd") if is_selected else Color("#5d625f"),
		2 if is_selected else 1
	))
	card.tooltip_text = "%s\n%s" % [title, localized_value(evidence.get("observation", ""))]
	return card


func make_authentication_evidence_detail(evidence: Dictionary, public_state: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "AuthenticationEvidenceDetail"
	panel.custom_minimum_size = Vector2(0, 94)
	panel.add_theme_stylebox_override("panel", case_panel_style(Color("#111a1be8"), Color("#75664b")))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	if evidence.is_empty():
		column.add_child(make_label(bilingual("No evidence recorded yet.", "아직 기록된 근거가 없습니다."), 14, Color("#b7c4c8")))
		return panel
	var public_row := authentication_public_evidence_row(evidence, public_state)
	var title := make_label(authentication_evidence_label(evidence), 14, Color("#e3c681"))
	title.name = "AuthenticationEvidenceDetailTitle"
	title.max_lines_visible = 1
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(title)
	var meta := make_label("%s · %s · %s" % [
		case_source_label(String(public_row.get("sourceKind", ""))),
		authentication_evidence_relation_label(evidence, public_row),
		case_reliability_label(String(public_row.get("reliability", "UNSPECIFIED")))
	], 11, Color("#9fd6bd"))
	meta.name = "AuthenticationEvidenceMeta"
	meta.max_lines_visible = 1
	meta.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(meta)
	var observation_text := localized_value(evidence.get("observation", ""))
	var observation := make_label(observation_text, 12, Color("#d9d1bd"))
	observation.name = "AuthenticationEvidenceObservation"
	observation.max_lines_visible = 2
	observation.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	observation.tooltip_text = observation_text
	column.add_child(observation)
	return panel


func hypothesis_relation_counts(hypothesis_id: String, public_state: Dictionary) -> Dictionary:
	var support := 0
	var refute := 0
	for evidence_value: Variant in public_state.get("evidence", []):
		if not evidence_value is Dictionary or not bool(evidence_value.get("discovered", false)):
			continue
		for relation_value: Variant in evidence_value.get("relations", []):
			if not relation_value is Dictionary or String(relation_value.get("hypothesis_id", "")) != hypothesis_id:
				continue
			if String(relation_value.get("stance", "")) == "SUPPORT":
				support += 1
			elif String(relation_value.get("stance", "")) == "REFUTE":
				refute += 1
	return {"support": support, "refute": refute}


func compact_hypothesis_label(hypothesis_id: String) -> String:
	return localized_value({
		"GENUINE": {"en": "GENUINE", "ko": "진품"},
		"GENUINE_WITH_PERIOD_REPAIR": {"en": "PERIOD REPAIR", "ko": "시대 수리 진품"},
		"GENUINE_WITH_MODERN_REPAIR": {"en": "MODERN REPAIR", "ko": "현대 수리 진품"},
		"REPRODUCTION": {"en": "REPRODUCTION", "ko": "복제품"},
		"FORGERY": {"en": "FORGERY", "ko": "위조품"},
		"UNKNOWN": {"en": "UNDECIDED", "ko": "판단 보류"}
	}.get(hypothesis_id, {"en": "HYPOTHESIS", "ko": "가설"}))


func hypothesis_card_text(hypothesis_id: String, public_state: Dictionary) -> String:
	var counts := hypothesis_relation_counts(hypothesis_id, public_state)
	return "%s\n%s %d · %s %d" % [
		compact_hypothesis_label(hypothesis_id),
		bilingual("SUP", "지지"), int(counts.get("support", 0)),
		bilingual("REF", "반박"), int(counts.get("refute", 0))
	]


func authentication_hypothesis_detail_text(hypothesis_id: String, public_state: Dictionary) -> String:
	var counts := hypothesis_relation_counts(hypothesis_id, public_state)
	return "%s · %s %d · %s %d" % [
		text_for("HYP_" + hypothesis_id),
		bilingual("SUPPORT", "지지"), int(counts.get("support", 0)),
		bilingual("REFUTE", "반박"), int(counts.get("refute", 0))
	]


func show_authentication() -> void:
	screen = "authentication"
	var body := screen_shell("%s — %s" % [text_for("AUTHENTICATION"), text_for("EVIDENCE_VS_CLAIM")])
	if selected.is_empty():
		body.add_child(make_case_tile("artifact", text_for("AUTHENTICATION"), text_for("SELECT_INVENTORY_LOT")))
		return
	var confidence := make_label(text_format("EVIDENCE_CONFIDENCE", [int(float(selected.get("confidence", 0.0)) * 100.0)]), 18, Color("#e3c681"))
	confidence.name = "AuthenticationConfidence"
	confidence.max_lines_visible = 1
	confidence.autowrap_mode = TextServer.AUTOWRAP_OFF
	body.add_child(confidence)
	var columns := HBoxContainer.new()
	columns.name = "AuthenticationColumns"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	body.add_child(columns)
	var evidence_column := VBoxContainer.new()
	evidence_column.custom_minimum_size = Vector2(570, 0)
	evidence_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	evidence_column.add_theme_constant_override("separation", 6)
	columns.add_child(evidence_column)
	var evidence_values: Array = selected.get("evidence", []) if selected.get("evidence", []) is Array else []
	var evidence_count := evidence_values.size()
	var evidence_page_count := maxi(1, ceili(float(evidence_count) / 6.0))
	authentication_evidence_page = clampi(authentication_evidence_page, 0, evidence_page_count - 1)
	authentication_evidence_index = clampi(authentication_evidence_index, 0, maxi(0, evidence_count - 1))
	if evidence_count > 0 and authentication_evidence_index / 6 != authentication_evidence_page:
		authentication_evidence_index = mini(authentication_evidence_page * 6, evidence_count - 1)
	var public_state := authentication_case_public_state()
	var evidence_header := HBoxContainer.new()
	evidence_header.add_theme_constant_override("separation", 6)
	evidence_column.add_child(evidence_header)
	var evidence_title := make_label("%s %d" % [bilingual("EVIDENCE", "근거"), evidence_count], 14, Color("#e3c681"))
	evidence_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evidence_header.add_child(evidence_title)
	var evidence_previous := make_button("‹", func(): change_authentication_evidence_page(-1), "AuthenticationEvidencePrev")
	evidence_previous.custom_minimum_size = Vector2(42, 30)
	evidence_previous.disabled = authentication_evidence_page <= 0
	evidence_header.add_child(evidence_previous)
	var evidence_page_label := make_label("%d / %d" % [authentication_evidence_page + 1, evidence_page_count], 12, Color("#b7c4c8"))
	evidence_page_label.name = "AuthenticationEvidencePage"
	evidence_page_label.custom_minimum_size = Vector2(54, 30)
	evidence_page_label.max_lines_visible = 1
	evidence_page_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	evidence_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	evidence_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	evidence_header.add_child(evidence_page_label)
	var evidence_next := make_button("›", func(): change_authentication_evidence_page(1), "AuthenticationEvidenceNext")
	evidence_next.custom_minimum_size = Vector2(42, 30)
	evidence_next.disabled = authentication_evidence_page >= evidence_page_count - 1
	evidence_header.add_child(evidence_next)
	var evidence_grid := GridContainer.new()
	evidence_grid.name = "AuthenticationEvidenceGrid"
	evidence_grid.columns = 2
	evidence_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	evidence_grid.add_theme_constant_override("h_separation", 6)
	evidence_grid.add_theme_constant_override("v_separation", 5)
	evidence_column.add_child(evidence_grid)
	var evidence_page_start := authentication_evidence_page * 6
	var evidence_page_end := mini(evidence_page_start + 6, evidence_count)
	for evidence_index in range(evidence_page_start, evidence_page_end):
		var evidence: Dictionary = evidence_values[evidence_index]
		evidence_grid.add_child(make_authentication_evidence_card(evidence, public_state, evidence_index, evidence_index - evidence_page_start))
	var detail_evidence: Dictionary = evidence_values[authentication_evidence_index] if evidence_count > 0 else {}
	evidence_column.add_child(make_authentication_evidence_detail(detail_evidence, public_state))
	var hypothesis_column := VBoxContainer.new()
	hypothesis_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hypothesis_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hypothesis_column.add_theme_constant_override("separation", 7)
	columns.add_child(hypothesis_column)
	var hypothesis_heading := make_label(bilingual("CHOOSE A HYPOTHESIS", "가설 선택"), 14, Color("#e3c681"))
	hypothesis_heading.max_lines_visible = 1
	hypothesis_column.add_child(hypothesis_heading)
	var grid := GridContainer.new()
	grid.name = "HypothesisGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	hypothesis_column.add_child(grid)
	for hypothesis_value: String in HYPOTHESES:
		var hypothesis: String = hypothesis_value
		var button := make_case_icon_button("hypothesis", hypothesis_card_text(hypothesis, public_state), func(): choose_hypothesis_from_ui(hypothesis), "Hypothesis_%s" % hypothesis, Vector2(194, 72))
		button.toggle_mode = true
		button.button_pressed = String(selected.get("playerHypothesis", "UNKNOWN")) == hypothesis
		button.add_theme_font_size_override("font_size", scaled_font_size(12))
		button.add_theme_constant_override("icon_max_width", 32)
		button.tooltip_text = text_for("HYP_" + hypothesis)
		grid.add_child(button)
		hypothesis_buttons[hypothesis] = button
	var selected_hypothesis := String(selected.get("playerHypothesis", "UNKNOWN"))
	var hypothesis_detail := make_label(authentication_hypothesis_detail_text(selected_hypothesis, public_state), 14, Color("#d9d1bd"))
	hypothesis_detail.name = "AuthenticationHypothesisDetail"
	hypothesis_detail.max_lines_visible = 2
	hypothesis_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hypothesis_column.add_child(hypothesis_detail)
	var requirement := make_label(bilingual("Choose a definite hypothesis to continue.", "명확한 가설을 골라 계속하세요."), 12, Color("#e59b7a") if selected_hypothesis == "UNKNOWN" else Color("#9fd6bd"))
	requirement.name = "AuthenticationRequirement"
	requirement.max_lines_visible = 1
	requirement.autowrap_mode = TextServer.AUTOWRAP_OFF
	hypothesis_column.add_child(requirement)
	hypothesis_accept_button = mark_primary_action(make_case_icon_button("support", text_for("AUTH_ACCEPT"), accept_hypothesis_from_ui, "AcceptHypothesisButton", Vector2(0, 48)))
	hypothesis_accept_button.disabled = selected_hypothesis == "UNKNOWN"
	hypothesis_column.add_child(hypothesis_accept_button)


func authentication_evidence_label(evidence: Dictionary) -> String:
	var clue_id := String(evidence.get("clueType", ""))
	var case_id := String(selected.get("caseId", ""))
	if not case_id.is_empty():
		var public_state := GameState.get_case_public_state(case_id)
		var authored_row := case_evidence_row(public_state, clue_id)
		if not authored_row.is_empty():
			return case_evidence_title(case_id, authored_row)
	return friendly_clue_label(clue_id)


func choose_hypothesis_from_ui(hypothesis: String) -> void:
	GameState.choose_hypothesis(selected, hypothesis)
	for key: String in hypothesis_buttons.keys():
		hypothesis_buttons[key].button_pressed = key == hypothesis
	hypothesis_accept_button.disabled = hypothesis == "UNKNOWN"
	var public_state := authentication_case_public_state()
	var detail := ui.find_child("AuthenticationHypothesisDetail", true, false)
	if detail is Label:
		detail.text = authentication_hypothesis_detail_text(hypothesis, public_state)
	var requirement := ui.find_child("AuthenticationRequirement", true, false)
	if requirement is Label:
		requirement.add_theme_color_override("font_color", Color("#e59b7a") if hypothesis == "UNKNOWN" else Color("#9fd6bd"))
	status.text = text_format("HYPOTHESIS_SELECTED", [text_for("HYP_" + hypothesis)])


func accept_hypothesis_from_ui() -> void:
	if GameState.accept_hypothesis(selected):
		show_appraisal()
	else:
		status.text = text_for("SELECT_DEFINITE_HYPOTHESIS")


func listing_price_label(preset_id: String) -> String:
	return localized_value({
		"FAST": {"en": "FAST", "ko": "빠른 판매"},
		"BALANCED": {"en": "BALANCED", "ko": "균형 판매"},
		"HIGH": {"en": "HIGH", "ko": "높은 목표"}
	}.get(preset_id, {}))


func listing_disclosure_label(disclosure_id: String) -> String:
	return localized_value({
		"CERTAIN": {"en": "Definite claim", "ko": "단정적 주장"},
		"LIKELY": {"en": "Likely claim", "ko": "유력한 주장"},
		"UNCERTAIN": {"en": "Limited claim", "ko": "제한적 주장"}
	}.get(disclosure_id, {}))


func listing_disclosure_description(disclosure_id: String) -> String:
	return localized_value({
		"CERTAIN": {"en": "State the public claim firmly.", "ko": "공개 주장을 단정적으로 제시"},
		"LIKELY": {"en": "State the public claim with measured limits.", "ko": "공개 주장과 한계를 신중하게 제시"},
		"UNCERTAIN": {"en": "State only a limited public claim.", "ko": "제한된 공개 주장만 조심스럽게 제시"}
	}.get(disclosure_id, {}))


func listing_support_band_label(band: String) -> String:
	return localized_value({
		"LOW": {"en": "Support low", "ko": "근거 부족"},
		"MEDIUM": {"en": "Support moderate", "ko": "근거 보통"},
		"HIGH": {"en": "Support sufficient", "ko": "근거 충분"}
	}.get(band, {"en": "Support low", "ko": "근거 부족"}))


func listing_disclosure_risk_label(risk: String) -> String:
	return localized_value({
		"OVERCLAIM": {"en": "Overclaim risk", "ko": "과장 위험"},
		"BALANCED": {"en": "Balanced", "ko": "균형"},
		"UNDERCLAIM": {"en": "Under-disclosure · lower interest", "ko": "과소공개 · 관심 저하"}
	}.get(risk, {"en": "Balanced", "ko": "균형"}))


func make_listing_public_support_badge(public_support: Dictionary) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.name = "ListingPublicSupportBadge"
	badge.custom_minimum_size = Vector2(0, 36)
	badge.add_theme_stylebox_override("panel", case_panel_style(Color("#19241f"), Color("#9fd6bd")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	badge.add_child(row)
	var icon := TextureRect.new()
	icon.texture = case_icon("citation")
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := make_label("%s · %s" % [bilingual("PUBLIC SUPPORT", "공개 근거"), listing_support_band_label(String(public_support.get("band", "LOW")))], 14, Color("#bfe4d2"))
	label.name = "ListingPublicSupportLabel"
	label.max_lines_visible = 1
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	badge.tooltip_text = bilingual("Uses only recorded confidence, provenance and visible condition.", "기록한 조사 신뢰도·출처·공개 상태 정보만 사용합니다.")
	return badge


func listing_prices(appraised_value: int, preset_id: String) -> Dictionary:
	var preset: Dictionary = LISTING_PRICE_PRESETS.get(preset_id, {})
	if preset.is_empty():
		return {}
	return {
		"starting": int(float(appraised_value) * float(preset.get("startingRatio", 0.0))),
		"reserve": int(float(appraised_value) * float(preset.get("reserveRatio", 0.0)))
	}


func make_listing_material_badge(label_text: String, positive: bool, badge_index: int) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.name = "ListingMaterialBadge_%d" % badge_index
	# Keep the three public facts as complete badges at the 1280px target.
	# A wrapping Label reports a one-glyph minimum width to HBoxContainer.
	badge.custom_minimum_size = Vector2(190, 36)
	badge.add_theme_stylebox_override("panel", case_panel_style(Color("#19241f") if positive else Color("#281c1a"), Color("#9fd6bd") if positive else Color("#e59b7a")))
	var label := make_label(label_text, 13, Color("#bfe4d2") if positive else Color("#f0b29a"))
	label.name = "ListingMaterialLabel_%d" % badge_index
	label.max_lines_visible = 1
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.add_child(label)
	return badge


func add_listing_material_badges(parent: Control) -> void:
	var condition_score: float = (float(selected.get("cleanliness", 0.0)) + float(selected.get("surfaceCondition", 0.0)) + float(selected.get("mechanicalCondition", 0.0))) / 300.0
	var confidence_sufficient: bool = float(selected.get("confidence", 0.0)) >= 0.55
	var provenance_known: bool = selected.get("knownClues", []).has("PROVENANCE")
	var badge_row := HBoxContainer.new()
	badge_row.name = "ListingMaterialBadges"
	badge_row.add_theme_constant_override("separation", 7)
	parent.add_child(badge_row)
	var badges := [
		{"text": bilingual("Condition documented", "상태 정보 충분") if condition_score >= 0.72 else bilingual("Condition risk", "상태 위험"), "positive": condition_score >= 0.72},
		{"text": bilingual("Investigation sufficient", "조사 정보 충분") if confidence_sufficient else bilingual("Investigation limited", "조사 정보 부족"), "positive": confidence_sufficient},
		{"text": bilingual("Provenance confirmed", "출처 확인") if provenance_known else bilingual("Provenance uncertain", "출처 불확실"), "positive": provenance_known}
	]
	for badge_index in range(badges.size()):
		badge_row.add_child(make_listing_material_badge(String(badges[badge_index].text), bool(badges[badge_index].positive), badge_index))


func add_listing_causal_summary(parent: Control) -> void:
	var causal_tags: Array = GameState.listing_public_status_tags(selected, listing_disclosure)
	var causal_row := HBoxContainer.new()
	causal_row.name = "ListingCausalSummary"
	causal_row.add_theme_constant_override("separation", 7)
	parent.add_child(causal_row)
	for reason_index in range(mini(3, causal_tags.size())):
		var reason_value: Variant = causal_tags[reason_index]
		if not reason_value is Dictionary or auction_reason_label(String(reason_value.get("code", ""))).is_empty():
			continue
		var chip := make_listing_causal_chip(reason_value, reason_index)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		causal_row.add_child(chip)


func select_listing_price_preset(preset_id: String) -> void:
	if not LISTING_PRICE_PRESETS.has(preset_id):
		return
	listing_price_preset = preset_id
	listing_disclosure = ""
	listing_step = "DISCLOSURE"
	show_appraisal()
	status.text = bilingual("Choose the strength of the public claim.", "공개 주장의 강도를 선택하세요.")


func select_listing_disclosure(disclosure_id: String) -> void:
	if not disclosure_id in ["CERTAIN", "LIKELY", "UNCERTAIN"]:
		return
	listing_disclosure = disclosure_id
	show_appraisal()
	status.text = bilingual("Listing choice ready to confirm.", "출품 선택을 확인할 준비가 되었습니다.")


func listing_back_to_price() -> void:
	listing_step = "PRICE"
	listing_disclosure = ""
	show_appraisal()


func confirm_listing_from_ui() -> void:
	var appraised_value: int = int(GameState.appraise(selected))
	var prices: Dictionary = listing_prices(appraised_value, listing_price_preset)
	if prices.is_empty() or not listing_disclosure in ["CERTAIN", "LIKELY", "UNCERTAIN"]:
		status.text = bilingual("Choose a price and disclosure first.", "가격과 공개 수준을 먼저 선택하세요.")
		return
	var listed: bool = bool(GameState.list_auction(selected, int(prices.starting), int(prices.reserve), float(selected.get("confidence", 0.0)), listing_disclosure, appraised_value))
	if not listed:
		status.text = friendly_pending_auction_error(GameState.last_action_error) if GameState.last_action_error == "PENDING_AUCTION_LOCKED" else bilingual("The listing could not be created.", "출품을 만들 수 없습니다.")
		return
	reset_auction_cue_sequence()
	show_auction()


func show_appraisal() -> void:
	screen = "appraisal"
	var selected_id := String(selected.get("uniqueId", ""))
	if listing_artifact_id != selected_id:
		listing_artifact_id = selected_id
		listing_step = "PRICE"
		listing_price_preset = ""
		listing_disclosure = ""
	var body := screen_shell("%s — %s" % [text_for("APPRAISAL"), text_for("LISTING_DISCLOSURE")])
	# The second listing step has more compact illustrated rows. A six-pixel
	# rhythm keeps its authoritative Confirm action above navigation even while
	# the 1/6 tutorial rail is present at 1280x720.
	if listing_step == "DISCLOSURE":
		body.add_theme_constant_override("separation", 6)
	var value: int = int(GameState.appraise(selected))
	body.add_child(make_label(selected.displayName, 22, Color("#e3c681")))
	body.add_child(make_label(text_format("APPRAISAL_STATS", [text_for("HYP_" + selected.playerHypothesis), int(selected.confidence * 100.0), value]), 17))
	if not selected.get("caseId", "").is_empty() and not selected.get("caseResolved", false):
		body.add_child(make_case_icon_button("report", text_for("SUBMIT_CASE_REPORT"), func(): show_case_dossier(selected.caseId), "SubmitCaseReport", Vector2(0, 50)))
	if listing_step == "PRICE":
		add_listing_material_badges(body)
		var price_heading := make_label(bilingual("1 / 2 · CHOOSE A PRICE PLAN", "1 / 2 · 가격 전략 선택"), 18, Color("#e3c681"))
		price_heading.name = "ListingPriceHeading"
		price_heading.max_lines_visible = 1
		body.add_child(price_heading)
		var price_grid := GridContainer.new()
		price_grid.name = "ListingPriceGrid"
		price_grid.columns = 3
		price_grid.add_theme_constant_override("h_separation", 10)
		body.add_child(price_grid)
		for preset_id: String in ["FAST", "BALANCED", "HIGH"]:
			var chosen_preset_id := preset_id
			var prices := listing_prices(value, chosen_preset_id)
			var caption := "%s\n%s ¤%d · %s ¤%d" % [listing_price_label(chosen_preset_id), bilingual("START", "시작"), int(prices.starting), bilingual("RESERVE", "예약"), int(prices.reserve)]
			var button := make_case_icon_button(String(LISTING_PRICE_PRESETS[chosen_preset_id].icon), caption, func(): select_listing_price_preset(chosen_preset_id), "ListingPrice_%s" % chosen_preset_id, Vector2(370, 104))
			button.tooltip_text = bilingual("Use the shown fixed price ratios.", "표시된 고정 가격 비율을 사용합니다.")
			price_grid.add_child(button)
		return
	var public_support: Dictionary = GameState.listing_public_support(selected)
	body.add_child(make_listing_public_support_badge(public_support))
	var disclosure_heading := make_label(bilingual("2 / 2 · CHOOSE CLAIM STRENGTH", "2 / 2 · 주장 강도 선택"), 18, Color("#e3c681"))
	disclosure_heading.name = "ListingDisclosureHeading"
	disclosure_heading.max_lines_visible = 1
	body.add_child(disclosure_heading)
	var disclosure_grid := GridContainer.new()
	disclosure_grid.name = "ListingDisclosureGrid"
	disclosure_grid.columns = 3
	disclosure_grid.add_theme_constant_override("h_separation", 10)
	body.add_child(disclosure_grid)
	for disclosure_id: String in ["CERTAIN", "LIKELY", "UNCERTAIN"]:
		var chosen_disclosure_id := disclosure_id
		var selected_prefix := bilingual("SELECTED · ", "선택됨 · ") if listing_disclosure == chosen_disclosure_id else ""
		var disclosure_support: Dictionary = GameState.listing_public_support(selected, chosen_disclosure_id)
		var disclosure_risk := String(disclosure_support.get("risk", "BALANCED"))
		var risk_hint := listing_disclosure_risk_label(disclosure_risk)
		var caption := "%s%s\n%s" % [selected_prefix, listing_disclosure_label(chosen_disclosure_id), risk_hint]
		var disclosure_icon: String = String({"OVERCLAIM": "risk", "BALANCED": "support", "UNDERCLAIM": "citation"}.get(disclosure_risk, "citation"))
		var button := make_case_icon_button(String(disclosure_icon), caption, func(): select_listing_disclosure(chosen_disclosure_id), "ListingDisclosure_%s" % chosen_disclosure_id, Vector2(370, 82))
		button.toggle_mode = true
		button.button_pressed = listing_disclosure == chosen_disclosure_id
		button.tooltip_text = "%s\n%s" % [listing_disclosure_description(chosen_disclosure_id), risk_hint]
		disclosure_grid.add_child(button)
	add_listing_causal_summary(body)
	var prices := listing_prices(value, listing_price_preset)
	var disclosure_summary := listing_disclosure_label(listing_disclosure) if not listing_disclosure.is_empty() else bilingual("Choose one public-information level", "공개 수준 하나를 선택하세요")
	var selected_risk := listing_disclosure_risk_label(String(GameState.listing_public_support(selected, listing_disclosure).get("risk", "BALANCED"))) if not listing_disclosure.is_empty() else ""
	var calibrated_summary := "%s · %s" % [disclosure_summary, selected_risk] if not selected_risk.is_empty() else disclosure_summary
	var summary_tile := make_case_tile("report", bilingual("FINAL LISTING", "최종 출품"), "%s · %s ¤%d · %s ¤%d · %s" % [listing_price_label(listing_price_preset), bilingual("START", "시작"), int(prices.get("starting", 0)), bilingual("RESERVE", "예약"), int(prices.get("reserve", 0)), calibrated_summary])
	summary_tile.name = "ListingSummaryTile"
	summary_tile.custom_minimum_size = Vector2(0, 64)
	body.add_child(summary_tile)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	body.add_child(actions)
	actions.add_child(make_case_icon_button("objective", bilingual("← CHANGE PRICE", "← 가격 변경"), listing_back_to_price, "ListingBackToPrice", Vector2(250, 52)))
	var confirm_button := mark_primary_action(make_case_icon_button("report", bilingual("CONFIRM LISTING", "출품 확정"), confirm_listing_from_ui, "ListingConfirmButton", Vector2(0, 52)))
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.disabled = listing_disclosure.is_empty()
	actions.add_child(confirm_button)


func submit_case_from_ui() -> void:
	if selected.get("caseId", "").is_empty():
		status.text = text_for("CASE_REPORT_BLOCKED")
		return
	show_case_dossier(selected.caseId)


func case_hypothesis_label(public_state: Dictionary, hypothesis_id: String) -> String:
	for hypothesis: Dictionary in public_state.get("hypotheses", []):
		if hypothesis.get("id", "") == hypothesis_id:
			return localized_value(hypothesis.get("label", hypothesis.get("label_key", hypothesis_id)))
	return bilingual("Unknown hypothesis", "알 수 없는 가설")


func case_source_icon(source_kind: String) -> String:
	return {
		"ARTIFACT": "artifact",
		"DOCUMENT": "document",
		"NPC": "npc",
		"REFERENCE": "reference"
	}.get(source_kind, "clue_generic")


func case_source_label(source_kind: String) -> String:
	return {
		"ARTIFACT": bilingual("OBJECT", "실물"),
		"DOCUMENT": bilingual("DOCUMENT", "문서"),
		"NPC": bilingual("WITNESS", "인물"),
		"REFERENCE": bilingual("REFERENCE", "참고자료")
	}.get(source_kind, bilingual("CLUE", "단서"))


func case_reliability_label(reliability: String) -> String:
	return {
		"HIGH": bilingual("high trust", "신뢰 높음"),
		"MEDIUM": bilingual("medium trust", "신뢰 보통"),
		"LOW": bilingual("low trust", "신뢰 낮음"),
		"UNSPECIFIED": bilingual("trust ungraded", "신뢰 미평가")
	}.get(reliability, bilingual("trust ungraded", "신뢰 미평가"))


func case_risk_label(risk_level: String) -> String:
	return {
		"HIGH": bilingual("HIGH RISK", "위험 높음"),
		"MEDIUM": bilingual("MEDIUM RISK", "위험 보통"),
		"LOW": bilingual("LOW RISK", "위험 낮음"),
		"NONE": bilingual("NO DAMAGE RISK", "손상 위험 없음")
	}.get(risk_level, bilingual("RISK CHECK", "위험 확인"))


func friendly_case_tool(tool_id: String) -> String:
	var known := {
		"soft_brush": {"en": "soft brush", "ko": "부드러운 솔"},
		"cleaning_cloth": {"en": "cleaning cloth", "ko": "청소 천"},
		"cotton_swab": {"en": "cotton swab", "ko": "면봉"},
		"mild_cleaner": {"en": "mild cleaner", "ko": "순한 세정제"},
		"rust_treatment": {"en": "rust treatment", "ko": "녹 처리 도구"},
		"polishing_pad": {"en": "polishing pad", "ko": "광택 패드"},
		"precision_screwdriver": {"en": "precision screwdriver", "ko": "정밀 드라이버"},
		"repair_toolkit": {"en": "repair toolkit", "ko": "수리 도구 세트"},
		"uv_lamp": {"en": "UV inspection lamp", "ko": "자외선 검사등"},
		"material_scanner": {"en": "material scanner", "ko": "재질 스캐너"},
		"precision_scale": {"en": "precision scale", "ko": "정밀 저울"},
		"reference_database": {"en": "reference database", "ko": "참고 자료실"},
		"magnifier": {"en": "magnifier", "ko": "확대경"},
	}
	if known.has(tool_id):
		return localized_value(known[tool_id])
	var tool: Dictionary = RuntimeRegistry.get_tool(tool_id)
	if not tool.is_empty() and not String(tool.get("name", "")).is_empty():
		return String(tool.name)
	return tool_id.replace("_", " ").capitalize()


func friendly_clue_label(clue_id: String) -> String:
	var labels := {
		"MAKER_MARK": {"en": "maker mark", "ko": "제작자 표식"},
		"SERIAL_PATTERN": {"en": "serial pattern", "ko": "일련번호 패턴"},
		"MATERIAL": {"en": "material", "ko": "재질"},
		"CONSTRUCTION_METHOD": {"en": "construction method", "ko": "제작 방식"},
		"COMPONENT_STYLE": {"en": "component style", "ko": "부품 양식"},
		"REPAIR_TRACE": {"en": "repair trace", "ko": "수리 흔적"},
		"PATINA": {"en": "aged surface", "ko": "세월의 표면"},
		"PROVENANCE": {"en": "ownership history", "ko": "소장 이력"},
		"MECHANISM": {"en": "mechanism", "ko": "기계 구조"},
		"TOOL_MARK": {"en": "tool mark", "ko": "공구 자국"},
		"LABEL": {"en": "label", "ko": "표기와 라벨"},
		"WEAR_PATTERN": {"en": "wear pattern", "ko": "마모 패턴"}
	}
	if labels.has(clue_id):
		return localized_value(labels[clue_id])
	return bilingual("Investigation clue", "조사 단서")


func inspection_clue_button_label(clue_id: String) -> String:
	var compact_labels := {
		"MAKER_MARK": {"en": "MAKER MARK", "ko": "제작자 표식"},
		"SERIAL_PATTERN": {"en": "SERIAL", "ko": "일련번호"},
		"MATERIAL": {"en": "MATERIAL", "ko": "재질"},
		"CONSTRUCTION_METHOD": {"en": "CONSTRUCTION", "ko": "제작 방식"},
		"COMPONENT_STYLE": {"en": "COMPONENT", "ko": "부품 양식"},
		"REPAIR_TRACE": {"en": "REPAIR TRACE", "ko": "수리 흔적"},
		"PATINA": {"en": "PATINA", "ko": "세월의 표면"},
		"PROVENANCE": {"en": "OWNERSHIP", "ko": "소장 이력"},
		"MECHANISM": {"en": "MECHANISM", "ko": "기계 구조"},
		"TOOL_MARK": {"en": "TOOL MARK", "ko": "공구 자국"},
		"LABEL": {"en": "LABEL", "ko": "표기"},
		"WEAR_PATTERN": {"en": "WEAR", "ko": "마모 패턴"}
	}
	return localized_value(compact_labels.get(clue_id, {"en": "CLUE", "ko": "단서"}))


func friendly_artifact_visual(artifact: Dictionary) -> String:
	var category_id := String(artifact.get("category", ""))
	var ko_categories := {
		"acoustic_reproducers": "음향 재생 장치", "astronomical_models": "천문 모형",
		"cartographic_instruments": "지도 제작 기구", "ceramics": "도자기",
		"cryptographic_office_machines": "암호 사무 기기", "decorative_objects": "장식 유물",
		"electrical_measurement": "전기 측정기", "geodetic_instruments": "측지 기구",
		"horological_instruments": "정밀 시계", "magnetic_recorders": "자기 기록 장치",
		"mechanical_automata": "기계식 자동인형", "mechanical_instruments": "기계식 기구",
		"meteorological_recorders": "기상 기록계", "microscopy_instruments": "현미경 기구",
		"nautical_instruments": "항해 기구", "office_machines": "사무 기기",
		"optical_animation_devices": "광학 영상 장치", "optical_devices": "광학 기구",
		"pharmaceutical_scales": "약제 저울", "photographic_apparatus": "사진 기구",
		"precision_regulators": "정밀 조절기", "railway_signaling": "철도 신호 장치",
		"scientific_instruments": "과학 기구", "spectroscopy_instruments": "분광 기구",
		"telegraphy_equipment": "전신 장비", "telephony": "전화 장비",
		"vintage_audio": "고전 음향 기기", "wireless_receivers": "무선 수신기"
	}
	if language == "ko":
		return String(ko_categories.get(category_id, "유물 외형"))
	return category_id.replace("_", " ").capitalize() if not category_id.is_empty() else "artifact form"


func friendly_case_name(case_id: String) -> String:
	var definition: Dictionary = GameState.case_definition(case_id)
	var authored_title: Variant = definition.get("title", "")
	if authored_title is Dictionary and not localized_value(authored_title).is_empty():
		return localized_value(authored_title)
	var story_case := RuntimeRegistry.get_case(case_id)
	var english_title: String = String(story_case.get("title", "Case lot"))
	var ko_titles := {
		"The Closed Workshop": "닫힌 공방", "The Silent Radio": "침묵하는 라디오", "The Perfect Fake": "완벽한 가짜",
		"Leave the Patina": "세월의 흔적", "The Estate Compass": "유산의 나침반", "The Pawn Broker Watch": "전당포 시계",
		"The Garage Lamp": "차고의 램프", "A Voice in Bakelite": "베이클라이트의 목소리", "The Early Mechanical Camera": "초기 기계식 카메라",
		"The False Invoice": "거짓 송장", "The Mislabelled Collection": "뒤바뀐 소장품", "The Observatory Instrument": "천문대의 기구",
		"The Collector Promise": "수집가의 약속", "The Three Cameras": "세 대의 카메라", "Shadow Mark: Camera": "그림자 표식: 카메라",
		"Shadow Mark: Gauge": "그림자 표식: 계기", "Shadow Mark: Clock": "그림자 표식: 시계", "Shadow Mark: Music Box": "그림자 표식: 오르골",
		"Shadow Mark: Optic": "그림자 표식: 광학기", "The Composite Prototype": "조합된 시제품", "Master Work: Chronometer": "거장의 작업: 크로노미터",
		"Master Work: Optical Engine": "거장의 작업: 광학 엔진", "Master Work: Recorder": "거장의 작업: 기록 장치", "Master Work: Precision Gauge": "거장의 작업: 정밀 계기",
		"Master Work: Prototype Camera": "거장의 작업: 시제품 카메라", "Master Work: Decorative Mechanism": "거장의 작업: 장식 기계"
	}
	if language == "ko":
		return String(ko_titles.get(english_title, "사건 유물"))
	return english_title


func friendly_act_title(act_id: String) -> String:
	var ko_titles := {
		"PROLOGUE": "닫힌 공방", "ACT_1": "지역 경매 순회", "ACT_2": "소장 이력",
		"ACT_3": "수집가들", "ACT_4": "위조범의 그림자", "ACT_5": "수석 보존가",
		"GRAND_RESERVE": "그랜드 리저브", "EPILOGUE": "에필로그", "POSTGAME": "끝없는 공방"
	}
	if language == "ko":
		return String(ko_titles.get(act_id, "캠페인"))
	return String(RuntimeRegistry.get_act(act_id).get("title", "Campaign"))


func friendly_location_label(location_id: String) -> String:
	var labels := {
		"small_workshop": {"en": "small workshop", "ko": "작은 공방"},
		"local_market": {"en": "local market", "ko": "지역 시장"},
		"archive_room": {"en": "archive room", "ko": "기록 보관실"},
		"collector_home": {"en": "collector's home", "ko": "수집가의 저택"},
		"premium_showroom": {"en": "premium showroom", "ko": "고급 전시장"},
		"museum_room": {"en": "museum conservation room", "ko": "박물관 보존실"},
		"grand_reserve_hall": {"en": "Grand Reserve hall", "ko": "그랜드 리저브 홀"},
		"upgraded_workshop": {"en": "expanded workshop", "ko": "확장된 공방"}
	}
	return localized_value(labels.get(location_id, {"en": "workshop district", "ko": "공방 지구"}))


func friendly_ending_title(ending_id: String) -> String:
	var ko_titles := {
		"ENDING_D": "명예를 잃은 전문가", "ENDING_S": "리저브의 거장", "ENDING_A": "복원의 거장",
		"ENDING_B": "경매의 강자", "ENDING_C": "박물관 보존가"
	}
	if language == "ko":
		return String(ko_titles.get(ending_id, "새로운 결말"))
	for ending: Dictionary in RuntimeRegistry.campaign.get("endings", []):
		if ending.get("id", "") == ending_id:
			return String(ending.get("title", "New ending"))
	return "New ending"


func friendly_auction_status(status_id: String) -> String:
	var labels := {
		"SOLD": {"en": "sold", "ko": "낙찰"}, "NO_SALE": {"en": "no sale", "ko": "유찰"},
		"CASE_LOCKED": {"en": "case unresolved", "ko": "사건 미해결"}, "ALREADY_RECORDED": {"en": "already recorded", "ko": "기록 완료"}
	}
	return localized_value(labels.get(status_id, {"en": "auction result", "ko": "경매 결과"}))


func friendly_case_error(code: String) -> String:
	var labels := {
		"CASE_ALREADY_RESOLVED": {"en": "this case is already closed", "ko": "이미 마친 사건입니다"},
		"CASE_NOT_ACTIVE": {"en": "open this case first", "ko": "사건을 먼저 시작하세요"},
		"EVIDENCE_NOT_IN_CASE": {"en": "that clue is unavailable", "ko": "이 사건에서 찾을 수 없는 단서입니다"},
		"EVIDENCE_LOCKED": {"en": "meet the clue requirement first", "ko": "단서 조건을 먼저 충족하세요"},
		"TOOL_REQUIRED": {"en": "select a recommended tool", "ko": "권장 도구를 먼저 선택하세요"},
		"UNKNOWN_CASE": {"en": "case data is unavailable", "ko": "사건 자료를 불러올 수 없습니다"},
		"INVALID_HYPOTHESIS": {"en": "select a hypothesis", "ko": "가설을 먼저 선택하세요"},
		"CROSS_CASE_EVIDENCE": {"en": "use clues from this case only", "ko": "현재 사건의 단서만 인용하세요"},
		"EVIDENCE_NOT_DISCOVERED": {"en": "investigate that clue first", "ko": "해당 단서를 먼저 조사하세요"},
		"EVIDENCE_NOT_CITABLE": {"en": "that clue cannot be cited", "ko": "보고서에 인용할 수 없는 단서입니다"}
	}
	return localized_value(labels.get(code, {"en": "check the case requirements", "ko": "사건 조건을 확인하세요"}))


func friendly_restoration_status(message: String) -> String:
	var labels := {
		"Effective restoration.": {"en": "Restoration completed.", "ko": "보존 처리를 마쳤습니다."},
		"Wrong tool: finish and historical integrity suffered.": {"en": "Wrong tool — surface and integrity were affected.", "ko": "도구가 맞지 않아 표면과 온전성이 낮아졌습니다."},
		"Required precision tool is not selected.": {"en": "Select one recommended repair tool.", "ko": "권장 수리 도구 중 하나를 선택하세요."},
		"Insufficient funds.": {"en": "Not enough funds for this restoration action.", "ko": "이 복원 작업을 수행할 자금이 부족합니다."},
		"Mechanism repaired.": {"en": "Repair completed.", "ko": "수리를 마쳤습니다."},
		"Light adjustment completed.": {"en": "Light adjustment completed.", "ko": "가벼운 조정을 마쳤습니다."}
	}
	return localized_value(labels.get(message, {"en": message, "ko": message}))


func case_evidence_title(_case_id: String, evidence: Dictionary) -> String:
	# Presentation data already passed the registry/public-state privacy bridge.
	# Do not look the row up in the authored definition here: that would let a
	# locked card reach undiscovered citation or source identifiers.
	var title_value: Variant = evidence.get("shortObservation", {}) if bool(evidence.get("discovered", false)) else evidence.get("sourceDisplayName", {})
	var fallback := localized_value(title_value)
	if not fallback.is_empty():
		return compact_case_text(fallback, 38)
	return case_source_label(String(evidence.get("sourceKind", "")))


func case_locked_action_text(evidence: Dictionary) -> String:
	var action := localized_value(evidence.get("unlockActionLabel", {"en": "Investigate", "ko": "조사하기"}))
	var target := localized_value(evidence.get("unlockTargetLabel", {"en": "the clue", "ko": "단서"}))
	if action.is_empty():
		action = bilingual("Investigate", "조사하기")
	if target.is_empty():
		target = bilingual("the clue", "단서")
	return "%s · %s" % [action, target]


func case_evidence_row(public_state: Dictionary, evidence_id: String) -> Dictionary:
	for evidence: Dictionary in public_state.get("evidence", []):
		if evidence.get("id", "") == evidence_id:
			return evidence
	return {}


func case_text_chunks(value: Variant, target_length: int = 54) -> Array:
	var remaining := localized_value(value).replace("\n", " ").replace("\r", " ").strip_edges()
	var chunks: Array = []
	while remaining.length() > target_length:
		var cut := target_length
		for cursor in range(target_length, maxi(10, target_length - 18), -1):
			if remaining.substr(cursor, 1) in [" ", ".", ",", "!", "?", "。"]:
				cut = cursor + 1
				break
		chunks.append(remaining.left(cut).strip_edges())
		remaining = remaining.substr(cut).strip_edges()
	if not remaining.is_empty():
		chunks.append(remaining)
	return chunks


func add_case_text_chunks(parent: Control, value: Variant, color := Color("#d9d1bd"), font_size: int = 14) -> void:
	for chunk: String in case_text_chunks(value):
		var label := make_label(chunk, font_size, color)
		label.max_lines_visible = 2
		parent.add_child(label)


func case_requirement_names(case_id: String, public_state: Dictionary, evidence: Dictionary) -> Array:
	var names: Array = []
	for requirement_id: String in evidence.get("requires", []):
		var required_evidence := case_evidence_row(public_state, requirement_id)
		names.append(case_evidence_title(case_id, required_evidence) if not required_evidence.is_empty() else bilingual("another clue", "선행 단서"))
	for tool_id: String in evidence.get("requiredTools", []):
		names.append(friendly_case_tool(tool_id))
	return names


func case_relation_stance_for_selected(evidence: Dictionary, selected_hypothesis_id: String) -> String:
	var saw_support := false
	var saw_refute := false
	for relation: Dictionary in evidence.get("relations", []):
		if relation.get("hypothesis_id", "") != selected_hypothesis_id:
			continue
		if relation.get("stance", "") == "SUPPORT":
			saw_support = true
		elif relation.get("stance", "") == "REFUTE":
			saw_refute = true
	if saw_support and saw_refute:
		return bilingual("MIXED", "혼합")
	if saw_support:
		return bilingual("SUPPORT", "지지")
	if saw_refute:
		return bilingual("REFUTE", "반박")
	return bilingual("CONTEXT", "정황")


func case_substantiation_label(substantiation_id: String) -> String:
	return localized_value({
		"STRONG": {"en": "Strong support", "ko": "강한 입증"},
		"PLAUSIBLE": {"en": "Plausible", "ko": "개연성 있음"},
		"INCONCLUSIVE": {"en": "Inconclusive", "ko": "결론 보류"}
	}.get(substantiation_id, {"en": "Pending review", "ko": "검토 중"}))


func case_resolution_verdict_text(result: Dictionary) -> String:
	return "%s · %s  |  %s · %s  |  %s %d" % [
		bilingual("CONCLUSION", "결론"), bilingual("ACCURATE", "정확") if bool(result.get("conclusionAccurate", false)) else bilingual("INCORRECT", "부정확"),
		bilingual("EVIDENCE", "입증"), case_substantiation_label(String(result.get("substantiation", "INCONCLUSIVE"))),
		bilingual("INDEPENDENT", "독립 출처"), int(result.get("independentSourceCount", 0))
	]


func select_case_evidence_detail(case_id: String, evidence_id: String) -> void:
	case_dossier_case_id = case_id
	case_detail_evidence_id = evidence_id
	show_case_dossier(case_id)
	status.text = bilingual("Clue details opened. Investigation requires its own action.", "단서 상세를 열었습니다. 조사는 별도 버튼으로 실행합니다.")


func add_case_relation_row(parent: Control, public_state: Dictionary, relation: Dictionary) -> void:
	var supports: bool = relation.get("stance", "") == "SUPPORT"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	parent.add_child(row)
	var icon_rect := TextureRect.new()
	icon_rect.texture = case_icon("support" if supports else "refute")
	icon_rect.custom_minimum_size = Vector2(25, 25)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon_rect)
	var relation_text := "%s — %s · %s %d" % [
		bilingual("SUPPORTS", "지지") if supports else bilingual("REFUTES", "반박"),
		case_hypothesis_label(public_state, relation.get("hypothesis_id", "")),
		bilingual("strength", "강도"),
		int(relation.get("strength", 0))
	]
	var relation_label := make_label(relation_text, 13, Color("#9fd6bd") if supports else Color("#e59b7a"))
	relation_label.max_lines_visible = 2
	relation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(relation_label)


func add_case_evidence_detail(parent: Control, case_id: String, public_state: Dictionary, evidence: Dictionary) -> void:
	if evidence.is_empty():
		parent.add_child(make_label(bilingual("Choose a clue card to inspect it.", "단서 카드를 선택해 상세 내용을 확인하세요."), 15, Color("#b7c4c8")))
		return
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	parent.add_child(heading)
	var icon_rect := TextureRect.new()
	var npc_portrait_value: Variant = evidence.get("npcPortrait", {})
	var npc_portrait: Dictionary = npc_portrait_value if npc_portrait_value is Dictionary else {}
	var npc_asset_path := String(npc_portrait.get("asset_path", ""))
	var uses_approved_npc_portrait := false
	if not bool(evidence.get("unlocked", false)):
		icon_rect.texture = case_icon("locked")
		icon_rect.name = "CaseLockedSourceIcon"
	elif String(evidence.get("sourceKind", "")) == "NPC" \
			and not npc_asset_path.is_empty() and ResourceLoader.exists(npc_asset_path):
		icon_rect.texture = load(npc_asset_path)
		icon_rect.tooltip_text = localized_value(npc_portrait.get("accessibility_name", bilingual("Witness portrait", "인물 초상")))
		icon_rect.name = "CaseNpcSourcePortrait"
		uses_approved_npc_portrait = true
	else:
		icon_rect.texture = case_icon(case_source_icon(evidence.get("sourceKind", "")))
		icon_rect.name = "CaseSourceIcon"
	icon_rect.custom_minimum_size = Vector2(96, 120) if uses_approved_npc_portrait else Vector2(42, 42)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heading.add_child(icon_rect)
	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title_column)
	var title_text := case_locked_action_text(evidence) if not bool(evidence.get("unlocked", false)) else case_evidence_title(case_id, evidence)
	var title_label := make_label(title_text, 16, Color("#e3c681"))
	title_label.name = "CaseEvidenceDisplayTitle"
	title_label.max_lines_visible = 2
	title_column.add_child(title_label)
	var source_meta := make_label(
		bilingual("LOCKED", "잠김") if not bool(evidence.get("unlocked", false)) else "%s · %s" % [case_source_label(evidence.get("sourceKind", "")), case_reliability_label(evidence.get("reliability", "UNSPECIFIED"))],
		12,
		Color("#8fa5aa")
	)
	source_meta.name = "CaseEvidenceSourceMeta"
	title_column.add_child(source_meta)

	if not bool(evidence.get("unlocked", false)):
		var lock_row := HBoxContainer.new()
		lock_row.add_theme_constant_override("separation", 7)
		parent.add_child(lock_row)
		var lock_icon := TextureRect.new()
		lock_icon.texture = case_icon("locked")
		lock_icon.custom_minimum_size = Vector2(28, 28)
		lock_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_row.add_child(lock_icon)
		var lock_text := case_locked_action_text(evidence)
		var lock_label := make_label(compact_case_text(lock_text, 64), 14, Color("#aeb5b4"))
		lock_label.name = "CaseLockedActionTarget"
		lock_label.max_lines_visible = 2
		lock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lock_row.add_child(lock_label)
		return

	if bool(evidence.get("discovered", false)):
		var text_scroll := ScrollContainer.new()
		text_scroll.custom_minimum_size = Vector2(0, 88)
		text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		parent.add_child(text_scroll)
		var full_text := VBoxContainer.new()
		full_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		full_text.add_theme_constant_override("separation", 3)
		text_scroll.add_child(full_text)
		add_case_text_chunks(full_text, evidence.get("text", ""))
		var citation_locator := localized_value(evidence.get("citationLocator", {}))
		if not citation_locator.is_empty():
			var locator_label := make_label("%s · %s" % [bilingual("SOURCE LOCATION", "출처 위치"), compact_case_text(citation_locator, 58)], 12, Color("#8fa5aa"))
			locator_label.name = "CaseCitationLocator"
			locator_label.max_lines_visible = 2
			locator_label.tooltip_text = citation_locator
			full_text.add_child(locator_label)
		if evidence.get("relations", []).is_empty():
			parent.add_child(make_label(bilingual("CONTEXT — no direct support or refutation", "정황 — 직접 지지하거나 반박하지 않음"), 13, Color("#b7c4c8")))
		else:
			for relation: Dictionary in evidence.get("relations", []):
				add_case_relation_row(parent, public_state, relation)
		if bool(evidence.get("citationAllowed", true)):
			var cite_caption := bilingual("REMOVE FROM REPORT", "보고서에서 제외") if bool(evidence.get("cited", false)) else bilingual("ADD TO REPORT", "보고서에 인용")
			var cite_button := make_case_icon_button("citation", cite_caption, func(): toggle_case_citation_from_ui(case_id, evidence.get("id", "")), "CaseCitation_%s" % String(evidence.get("id", "")).validate_node_name(), Vector2(0, 46))
			cite_button.tooltip_text = bilingual("Citations may support or refute your chosen hypothesis.", "지지·반박 단서 모두 보고서에 인용할 수 있습니다.")
			parent.add_child(cite_button)
		return

	var risk_row := HBoxContainer.new()
	risk_row.add_theme_constant_override("separation", 7)
	parent.add_child(risk_row)
	var risk_icon := TextureRect.new()
	risk_icon.texture = case_icon("risk")
	risk_icon.custom_minimum_size = Vector2(30, 30)
	risk_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	risk_row.add_child(risk_icon)
	var risk_label := make_label(case_risk_label(evidence.get("riskLevel", "NONE")), 14, Color("#e59b7a") if evidence.get("riskLevel", "NONE") != "NONE" else Color("#9fd6bd"))
	risk_label.name = "CaseEvidenceRiskLabel"
	risk_label.max_lines_visible = 1
	risk_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	risk_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	risk_row.add_child(risk_label)
	var warning := localized_value(evidence.get("riskWarning", ""))
	if warning.is_empty():
		warning = bilingual("Record the clue before changing the object.", "유물을 바꾸기 전에 단서를 기록하세요.")
	add_case_text_chunks(parent, warning, Color("#d9c4ac"), 13)
	var required_tools: Array = evidence.get("requiredTools", [])
	var tool_ready := required_tools.is_empty() or required_tools.has(GameState.selected_tool)
	if not required_tools.is_empty() and not tool_ready:
		var required_tool := String(required_tools[0])
		var tool_button := make_case_icon_button("tool", bilingual("EQUIP ", "도구 장착 · ") + friendly_case_tool(required_tool), func(): equip_case_tool_from_ui(case_id, required_tool), "CaseTool_%s" % required_tool.validate_node_name(), Vector2(0, 44))
		tool_button.tooltip_text = bilingual("Equip the required tool before investigating.", "조사 전에 필요한 도구를 장착합니다.")
		parent.add_child(tool_button)
	var discover_button := make_case_icon_button("clue_generic", bilingual("BEGIN INVESTIGATION", "조사 실행"), func(): discover_case_evidence_from_ui(case_id, evidence.get("id", "")), "CaseEvidence_%s" % String(evidence.get("id", "")).validate_node_name(), Vector2(0, 48))
	discover_button.disabled = not tool_ready
	discover_button.tooltip_text = bilingual("This separate action records the clue after you review the risk.", "위험 안내를 확인한 뒤 별도 행동으로 단서를 기록합니다.")
	parent.add_child(discover_button)


func show_case_dossier(case_id: String = "") -> void:
	var resolved_case_id := case_id
	if resolved_case_id.is_empty() and not case_dossier_case_id.is_empty():
		resolved_case_id = case_dossier_case_id
	if resolved_case_id.is_empty() and not selected.get("caseId", "").is_empty():
		resolved_case_id = selected.caseId
	if resolved_case_id.is_empty():
		resolved_case_id = GameState.campaign_state.get("activeCaseId", "")
	if resolved_case_id != case_dossier_case_id:
		case_detail_evidence_id = ""
	case_dossier_case_id = resolved_case_id
	screen = "case_dossier"
	var public_state := GameState.get_case_public_state(resolved_case_id)
	var title := localized_value(public_state.get("title", bilingual("CASE DOSSIER", "사건 서류")))
	var body := screen_shell("%s — %s" % [bilingual("CASE DOSSIER", "사건 서류"), title])
	if not bool(public_state.get("ok", false)):
		body.add_child(make_label(bilingual("No active case file is available.", "열 수 있는 사건 서류가 없습니다."), 18))
		return
	var scroll := ScrollContainer.new()
	scroll.name = "CaseDossierScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.name = "CaseDossierRows"
	# ScrollContainer children derive their width from minimum sizes.  Give the
	# dossier a stable 1280-target width so smart-wrapped labels never report a
	# one-glyph column during a locale rebuild.
	rows.custom_minimum_size = Vector2(1180, 0)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 9)
	scroll.add_child(rows)
	var artifact_display_name := localized_value(public_state.get("artifactDisplayName", {}))
	if not artifact_display_name.is_empty():
		var artifact_identity := make_case_tile(
			"artifact",
			bilingual("CASE OBJECT", "사건 유물"),
			public_state.get("artifactDisplayName", {}),
			artifact_display_name
		)
		artifact_identity.name = "CaseArtifactIdentity"
		rows.add_child(artifact_identity)
	var overview_tiles := GridContainer.new()
	overview_tiles.columns = 3
	overview_tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview_tiles.add_theme_constant_override("h_separation", 9)
	rows.add_child(overview_tiles)
	overview_tiles.add_child(make_case_tile("briefing", bilingual("BRIEF", "상황"), public_state.get("briefing", ""), localized_value(public_state.get("briefing", ""))))
	overview_tiles.add_child(make_case_tile("core_question", bilingual("QUESTION", "핵심 질문"), public_state.get("centralQuestion", ""), localized_value(public_state.get("centralQuestion", ""))))
	overview_tiles.add_child(make_case_tile("objective", bilingual("GOAL", "목표"), public_state.get("reportPrompt", ""), localized_value(public_state.get("reportPrompt", ""))))
	if not localized_value(public_state.get("fictionNotice", "")).is_empty():
		var fiction_label := make_label("ⓘ " + compact_case_text(public_state.get("fictionNotice", ""), 70), 12, Color("#8fa5aa"))
		fiction_label.max_lines_visible = 2
		fiction_label.tooltip_text = localized_value(public_state.get("fictionNotice", ""))
		rows.add_child(fiction_label)
	if bool(public_state.get("resolved", false)):
		var result: Dictionary = public_state.get("resolutionResult", {})
		var result_panel := PanelContainer.new()
		result_panel.add_theme_stylebox_override("panel", case_panel_style(Color("#15211fe8"), Color("#9fd6bd") if bool(result.get("conclusionAccurate", false)) else Color("#e59b7a"), 2))
		rows.add_child(result_panel)
		var result_row := HBoxContainer.new()
		result_row.add_theme_constant_override("separation", 12)
		result_panel.add_child(result_row)
		var result_icon := TextureRect.new()
		result_icon.texture = case_icon("report")
		result_icon.custom_minimum_size = Vector2(68, 68)
		result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		result_row.add_child(result_icon)
		var result_words := VBoxContainer.new()
		result_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		result_row.add_child(result_words)
		result_words.add_child(make_label(bilingual("REPORT ACCEPTED", "보고서 접수 완료"), 20, Color("#e3c681")))
		var verdict := case_resolution_verdict_text(result)
		result_words.add_child(make_label(verdict, 15, Color("#9fd6bd") if bool(result.get("conclusionAccurate", false)) else Color("#e59b7a")))
		var result_summary := make_label(compact_case_text(public_state.get("success", "") if bool(result.get("conclusionAccurate", false)) else public_state.get("failure", ""), 88), 14)
		result_summary.max_lines_visible = 2
		result_words.add_child(result_summary)
		var continue_button := mark_primary_action(make_case_icon_button("objective", bilingual("CONTINUE CAMPAIGN", "캠페인 계속"), show_campaign, "CaseContinue", Vector2(210, 54)))
		result_row.add_child(continue_button)
		rows.add_child(make_case_relationship_reaction(case_id, result))
		return

	if case_detail_evidence_id.is_empty() and not public_state.get("evidence", []).is_empty():
		case_detail_evidence_id = String(public_state.get("evidence", [])[0].get("id", ""))
	if case_evidence_row(public_state, case_detail_evidence_id).is_empty() and not public_state.get("evidence", []).is_empty():
		case_detail_evidence_id = String(public_state.get("evidence", [])[0].get("id", ""))
	var evidence_section := HBoxContainer.new()
	evidence_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evidence_section.add_theme_constant_override("separation", 10)
	rows.add_child(evidence_section)
	var ledger_column := VBoxContainer.new()
	ledger_column.custom_minimum_size = Vector2(730, 0)
	ledger_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ledger_column.add_theme_constant_override("separation", 5)
	evidence_section.add_child(ledger_column)
	ledger_column.add_child(make_label(bilingual("CLUE CARDS", "단서 카드"), 17, Color("#e3c681")))
	var evidence_grid := GridContainer.new()
	evidence_grid.columns = 2
	evidence_grid.add_theme_constant_override("h_separation", 7)
	evidence_grid.add_theme_constant_override("v_separation", 7)
	ledger_column.add_child(evidence_grid)
	for evidence: Dictionary in public_state.get("evidence", []):
		var evidence_id: String = evidence.get("id", "")
		var state_label := bilingual("FOUND", "확인됨") if bool(evidence.get("discovered", false)) else (bilingual("READY", "조사 가능") if bool(evidence.get("unlocked", false)) else bilingual("LOCKED", "잠김"))
		if bool(evidence.get("cited", false)):
			state_label += " · " + bilingual("CITED", "인용됨")
		var card_text := ""
		if bool(evidence.get("unlocked", false)):
			var meta := "%s · %s · %s" % [case_source_label(evidence.get("sourceKind", "")), case_reliability_label(evidence.get("reliability", "UNSPECIFIED")), case_risk_label(evidence.get("riskLevel", "NONE"))]
			card_text = "%s · %s\n%s" % [state_label, case_evidence_title(resolved_case_id, evidence), meta]
		else:
			# Locked cards are an explicit two-field contract: localized action and
			# localized public target. Do not reveal source/citation names, raw
			# targets, prerequisites, tools or evidence text here.
			card_text = "%s\n%s" % [state_label, case_locked_action_text(evidence)]
		var card := make_case_icon_button(case_source_icon(evidence.get("sourceKind", "")) if bool(evidence.get("unlocked", false)) else "locked", card_text, func(): select_case_evidence_detail(resolved_case_id, evidence_id), "CaseEvidenceCard_%s" % evidence_id.validate_node_name(), Vector2(356, 67))
		card.toggle_mode = true
		card.button_pressed = evidence_id == case_detail_evidence_id
		card.tooltip_text = (localized_value(evidence.get("text", "")) if bool(evidence.get("discovered", false)) else (bilingual("Open details. Investigation is a separate action.", "상세를 엽니다. 조사는 별도 행동입니다.") if bool(evidence.get("unlocked", false)) else bilingual("Open to see the short unlock requirement.", "짧은 잠금 해제 조건을 확인합니다.")))
		evidence_grid.add_child(card)
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(430, 225)
	detail_panel.add_theme_stylebox_override("panel", case_panel_style(Color("#11171be8"), Color("#75664b")))
	evidence_section.add_child(detail_panel)
	var detail_column := VBoxContainer.new()
	detail_column.add_theme_constant_override("separation", 5)
	detail_panel.add_child(detail_column)
	detail_column.add_child(make_label(bilingual("SELECTED CLUE", "선택한 단서"), 13, Color("#8fa5aa")))
	add_case_evidence_detail(detail_column, resolved_case_id, public_state, case_evidence_row(public_state, case_detail_evidence_id))

	rows.add_child(make_label(bilingual("CHOOSE A HYPOTHESIS", "가설 선택"), 17, Color("#e3c681")))
	var hypothesis_grid := GridContainer.new()
	hypothesis_grid.columns = 3
	rows.add_child(hypothesis_grid)
	for hypothesis: Dictionary in public_state.get("hypotheses", []):
		var hypothesis_id: String = hypothesis.get("id", "")
		var label := localized_value(hypothesis.get("label", hypothesis.get("label_key", hypothesis_id)))
		var selected_hypothesis: bool = public_state.get("selectedHypothesisId", "") == hypothesis_id
		var hypothesis_caption := (bilingual("SELECTED · ", "선택됨 · ") if selected_hypothesis else "") + label
		var hypothesis_button := make_case_icon_button("hypothesis", hypothesis_caption, func(): select_case_hypothesis_from_ui(resolved_case_id, hypothesis_id), "CaseHypothesis_%s" % hypothesis_id.validate_node_name(), Vector2(375, 58))
		hypothesis_button.toggle_mode = true
		hypothesis_button.button_pressed = selected_hypothesis
		hypothesis_button.tooltip_text = localized_value(hypothesis.get("claim", label))
		hypothesis_grid.add_child(hypothesis_button)

	var report_panel := PanelContainer.new()
	report_panel.add_theme_stylebox_override("panel", case_panel_style(Color("#171d21e8"), Color("#75664b")))
	rows.add_child(report_panel)
	var report_column := VBoxContainer.new()
	report_column.add_theme_constant_override("separation", 6)
	report_panel.add_child(report_column)
	var report_header := HBoxContainer.new()
	report_header.add_theme_constant_override("separation", 8)
	report_column.add_child(report_header)
	var report_icon := TextureRect.new()
	report_icon.texture = case_icon("report")
	report_icon.custom_minimum_size = Vector2(38, 38)
	report_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	report_header.add_child(report_icon)
	var cited_evidence: Array = []
	var independent_sources := {}
	for evidence: Dictionary in public_state.get("evidence", []):
		if bool(evidence.get("cited", false)):
			cited_evidence.append(evidence)
			independent_sources[String(evidence.get("sourceId", evidence.get("id", "")))] = true
	var dots := ""
	for dot_index in range(independent_sources.size()):
		dots += "● "
	var report_heading := VBoxContainer.new()
	report_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_header.add_child(report_heading)
	report_heading.add_child(make_label(bilingual("REPORT SUMMARY", "보고서 요약"), 17, Color("#e3c681")))
	report_heading.add_child(make_label("%s%d  ·  %s%s (%d)" % [bilingual("citations ", "인용 "), cited_evidence.size(), dots, bilingual("independent sources", "독립 출처"), independent_sources.size()], 13, Color("#9fd6bd")))
	var report_prompt_label := make_label(compact_case_text(public_state.get("reportPrompt", ""), 92), 13, Color("#b7c4c8"))
	report_prompt_label.name = "CaseReportPrompt"
	report_prompt_label.max_lines_visible = 2
	report_prompt_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_prompt_label.tooltip_text = localized_value(public_state.get("reportPrompt", ""))
	# A second expanding child in report_header previously starved this prompt
	# to a one-character column.  It belongs directly below the compact heading.
	report_column.add_child(report_prompt_label)
	var citation_grid := GridContainer.new()
	citation_grid.columns = 3
	citation_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	citation_grid.add_theme_constant_override("h_separation", 6)
	citation_grid.add_theme_constant_override("v_separation", 5)
	report_column.add_child(citation_grid)
	if cited_evidence.is_empty():
		var empty_citations := make_label(bilingual("No citations yet — support and refutation are both allowed.", "아직 인용 없음 — 지지·반박 단서 모두 사용할 수 있습니다."), 13, Color("#8fa5aa"))
		empty_citations.name = "CaseEmptyCitations"
		empty_citations.max_lines_visible = 1
		empty_citations.autowrap_mode = TextServer.AUTOWRAP_OFF
		empty_citations.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		empty_citations.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		citation_grid.add_child(empty_citations)
	else:
		for evidence: Dictionary in cited_evidence:
			var evidence_id: String = evidence.get("id", "")
			var stance := case_relation_stance_for_selected(evidence, public_state.get("selectedHypothesisId", ""))
			var citation_title := case_evidence_title(resolved_case_id, evidence)
			var citation_button := make_case_icon_button("citation", "%s · %s  ×" % [stance, citation_title], func(): toggle_case_citation_from_ui(resolved_case_id, evidence_id), "ReportCitationRemove_%s" % evidence_id.validate_node_name(), Vector2(360, 43))
			var citation_locator := localized_value(evidence.get("citationLocator", {}))
			citation_button.tooltip_text = "%s\n%s" % [bilingual("Remove this citation from the report.", "이 인용을 보고서에서 제외합니다."), citation_title]
			if not citation_locator.is_empty():
				citation_button.tooltip_text += "\n%s · %s" % [bilingual("Source location", "출처 위치"), citation_locator]
			citation_grid.add_child(citation_button)
	var submit_button := mark_primary_action(make_case_icon_button("report", bilingual("SUBMIT EVIDENCE-BACKED REPORT", "증거 기반 보고서 제출"), func(): resolve_case_report_from_ui(resolved_case_id), "ResolveCaseReport", Vector2(0, 52)))
	submit_button.disabled = String(public_state.get("selectedHypothesisId", "")).is_empty() or public_state.get("citedEvidenceIds", []).is_empty()
	submit_button.tooltip_text = bilingual("Choose one hypothesis and at least one citation.", "가설 하나와 인용할 단서를 선택하세요.")
	report_column.add_child(submit_button)


func discover_case_evidence_from_ui(case_id: String, evidence_id: String) -> void:
	var result := GameState.discover_case_evidence(case_id, evidence_id)
	show_case_dossier(case_id)
	status.text = bilingual("Evidence recorded.", "증거를 기록했습니다.") if bool(result.get("ok", false)) else "%s — %s" % [bilingual("Investigation blocked", "조사 불가"), friendly_case_error(String(result.get("code", "UNKNOWN")))]


func equip_case_tool_from_ui(case_id: String, tool_id: String) -> void:
	var equipped := GameState.select_tool(tool_id)
	show_case_dossier(case_id)
	status.text = bilingual("Equipped: %s", "장착: %s") % friendly_case_tool(tool_id) if equipped else bilingual("Tool unavailable.", "도구를 사용할 수 없습니다.")


func toggle_case_citation_from_ui(case_id: String, evidence_id: String) -> void:
	var changed := GameState.toggle_case_citation(case_id, evidence_id)
	show_case_dossier(case_id)
	status.text = bilingual("Report citations updated.", "보고서 인용을 갱신했습니다.") if changed else text_for("CASE_REPORT_BLOCKED")


func select_case_hypothesis_from_ui(case_id: String, hypothesis_id: String) -> void:
	var changed := GameState.set_case_hypothesis(case_id, hypothesis_id)
	show_case_dossier(case_id)
	status.text = bilingual("Hypothesis selected.", "가설을 선택했습니다.") if changed else text_for("CASE_REPORT_BLOCKED")


func resolve_case_report_from_ui(case_id: String) -> void:
	var public_state := GameState.get_case_public_state(case_id)
	var result := GameState.resolve_case_v2(case_id, public_state.get("selectedHypothesisId", ""), public_state.get("citedEvidenceIds", []))
	show_case_dossier(case_id)
	status.text = text_for("CASE_REPORT_ACCEPTED") if bool(result.get("ok", false)) else "%s — %s" % [text_for("CASE_REPORT_BLOCKED"), friendly_case_error(String(result.get("code", "UNKNOWN")))]


func ensure_pending_auction_snapshot() -> Dictionary:
	var pending: Dictionary = GameState.pending_auction_public_state()
	var reserve_session: Dictionary = GameState.grand_reserve_public_state()
	if bool(pending.get("ok", false)) \
		and bool(pending.get("grandReserve", false)) \
		and String(reserve_session.get("phase", "IDLE")) in ["AUCTION_PENDING", "BETWEEN_LOTS"]:
		return pending
	if selected.is_empty() or selected.get("listing", {}).is_empty():
		return {}
	if bool(pending.get("ok", false)) and String(pending.get("status", "")) == "PENDING" and String(pending.get("artifactId", "")) == String(selected.get("uniqueId", "")):
		return pending
	return GameState.create_pending_auction(selected)


func reset_auction_cue_sequence() -> void:
	auction_cue_queue = []
	auction_cue_index = 0
	auction_sequence_key = ""
	last_auction_result = {}


func ensure_auction_cue_sequence() -> void:
	var pending := ensure_pending_auction_snapshot()
	if not bool(pending.get("ok", false)):
		reset_auction_cue_sequence()
		return
	last_auction_result = pending.get("result", {}).duplicate(true)
	auction_cue_queue = pending.get("cueQueue", []).duplicate(true)
	auction_cue_index = clampi(int(pending.get("cueIndex", 0)), 0, maxi(0, auction_cue_queue.size() - 1))
	auction_sequence_key = String(pending.get("transactionId", ""))


func auction_public_cue_state() -> Dictionary:
	if auction_cue_queue.is_empty():
		return {}
	var cue: Dictionary = auction_cue_queue[clampi(auction_cue_index, 0, auction_cue_queue.size() - 1)].duplicate(true)
	cue["index"] = auction_cue_index
	cue["total"] = auction_cue_queue.size()
	cue["isFinal"] = auction_cue_index == auction_cue_queue.size() - 1
	return cue


func auction_phase_label(phase: String) -> String:
	return localized_value({
		"ENTRY": {"en": "LOT ENTRY", "ko": "유물 입장"},
		"CALL": {"en": "OPENING CALL", "ko": "호가 시작"},
		"BID": {"en": "LIVE BID", "ko": "실시간 입찰"},
		"DROPOUT": {"en": "BIDDER OUT", "ko": "입찰 포기"},
		"SOLD": {"en": "SOLD", "ko": "낙찰"},
		"NO_SALE": {"en": "NO SALE", "ko": "유찰"}
	}.get(phase, {"en": "AUCTION", "ko": "경매"}))


func auction_primary_public_state(cue_state: Dictionary) -> Dictionary:
	var phase := String(cue_state.get("phase", "ENTRY"))
	var terminal := phase in ["SOLD", "NO_SALE"]
	var amount := int(last_auction_result.get("hammer", 0)) if terminal else int(cue_state.get("amount", 0))
	if not terminal and amount <= 0:
		var visible_bids: Array = cue_state.get("visibleBids", []) if cue_state.get("visibleBids", []) is Array else []
		if not visible_bids.is_empty() and visible_bids[-1] is Dictionary:
			amount = int(visible_bids[-1].get("amount", 0))
	if not terminal and amount <= 0:
		amount = int(last_auction_result.get("opening", 0))
	var rendered_text := ""
	if phase == "SOLD":
		rendered_text = "%s · ¤%d" % [text_for("SOLD"), amount]
	elif phase == "NO_SALE":
		rendered_text = "%s · %s ¤%d" % [text_for("NO_SALE"), bilingual("HIGH BID", "최고"), amount] if amount > 0 else "%s · %s" % [text_for("NO_SALE"), bilingual("NO PUBLIC BID", "공개 입찰 없음")]
	else:
		rendered_text = "%s · ¤%d" % [bilingual("CURRENT BID", "현재 호가"), amount]
	return {
		"phase": phase,
		"terminal": terminal,
		"amount": amount,
		"text": rendered_text,
		"positive": phase == "SOLD"
	}


func make_auction_primary_state(cue_state: Dictionary) -> PanelContainer:
	var public_state := auction_primary_public_state(cue_state)
	var terminal := bool(public_state.get("terminal", false))
	var panel := PanelContainer.new()
	panel.name = "AuctionPrimaryState"
	# Preserve the established 58px dominant-result target even in compact
	# terminal layout; space is recovered from secondary price/portrait chrome.
	panel.custom_minimum_size = Vector2(0, 58)
	var accent := Color("#9fd6bd") if bool(public_state.get("positive", false)) else (Color("#e59b7a") if bool(public_state.get("terminal", false)) else Color("#e3c681"))
	var panel_style := case_panel_style(Color("#17201ee8"), accent, 2)
	if terminal:
		panel_style.content_margin_top = 5
		panel_style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", panel_style)
	var label := make_label(String(public_state.get("text", "")), 26 if terminal else 30, accent)
	label.name = "AuctionPrimaryText"
	label.max_lines_visible = 1
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


func auction_terminal_primary_reason(result: Dictionary) -> Dictionary:
	for reason_value: Variant in result.get("reasonTags", []):
		if reason_value is Dictionary and not auction_reason_label(String(reason_value.get("code", ""))).is_empty():
			return reason_value.duplicate(true)
	return {
		"code": "RESERVE_MET" if bool(result.get("reserve_met", false)) else "NO_PUBLIC_BID",
		"category": "PRICE",
		"polarity": "POSITIVE" if bool(result.get("reserve_met", false)) else "NEGATIVE"
	}


func advance_auction_cue() -> void:
	ensure_auction_cue_sequence()
	if auction_cue_queue.is_empty() or auction_cue_index >= auction_cue_queue.size() - 1:
		return
	var advanced: Dictionary = GameState.set_pending_auction_cue_index(auction_sequence_key, auction_cue_index + 1)
	if not bool(advanced.get("ok", false)):
		status.text = bilingual("The next auction cue could not be saved.", "다음 경매 장면을 저장하지 못했습니다.")
		return
	auction_cue_index = int(advanced.get("cueIndex", auction_cue_index + 1))
	show_auction()
	var focus_name := "HammerButton" if auction_cue_index == auction_cue_queue.size() - 1 else "AuctionCueNext"
	sync_public_interaction_state(focus_name)
	restore_focus_by_name(focus_name)
	status.text = bilingual("Auction cue advanced.", "경매 장면을 진행했습니다.")


func grand_reserve_progress_text(session: Dictionary) -> String:
	var receipts: Array = session.get("receipts", []) if session.get("receipts", []) is Array else []
	var current_index := int(session.get("currentLotIndex", 0))
	var phase := String(session.get("phase", "IDLE"))
	var marks: Array = []
	for lot_index in range(3):
		var is_active_lot := lot_index == current_index and phase == "AUCTION_PENDING"
		var is_next_lot := lot_index == current_index + 1 and phase == "BETWEEN_LOTS"
		var marker := "✓" if lot_index < receipts.size() else ("●" if is_active_lot or is_next_lot else "○")
		marks.append("%d %s" % [lot_index + 1, marker])
	return "%s   %s" % [text_for("GRAND_RESERVE"), "   ".join(marks)]


func auction_causal_recap_data() -> Dictionary:
	var pending := GameState.pending_auction_public_state()
	if not bool(pending.get("ok", false)):
		return {}
	var cue := auction_public_cue_state()
	var terminal_visible := String(cue.get("phase", "")) in ["SOLD", "NO_SALE"] or String(pending.get("status", "")) == "COMMITTED"
	if not terminal_visible:
		return {}
	var decisions: Dictionary = pending.get("decisions", {}) if pending.get("decisions", {}) is Dictionary else {}
	var public_result: Dictionary = pending.get("result", {}) if pending.get("result", {}) is Dictionary else {}
	var strategy_id := String(GameState.listing_strategy_id_from_decisions(decisions, bool(pending.get("grandReserve", false)))) if GameState.has_method("listing_strategy_id_from_decisions") else ""
	var disclosure_id := String(decisions.get("disclosure", "UNCERTAIN"))
	var strategy_label := bilingual("RESERVE PLAN", "예약가 전략") if strategy_id == "AUTO_GRAND_RESERVE" else listing_price_label(strategy_id)
	if strategy_label.is_empty():
		strategy_label = bilingual("CUSTOM TERMS", "직접 설정")
	var choice_copy := "%s · %s" % [
		strategy_label,
		listing_disclosure_label(disclosure_id)
	]
	var primary_reason := auction_terminal_primary_reason(public_result)
	var reaction_copy := auction_reason_label(String(primary_reason.get("code", "")))
	if reaction_copy.is_empty():
		reaction_copy = bilingual("Public terms reviewed", "공개 조건 검토")
	var result_copy := "%s · %s ¤%d" % [
		text_for("SOLD") if bool(public_result.get("reserve_met", false)) else text_for("NO_SALE"),
		bilingual("NET", "정산"),
		int(public_result.get("net", 0))
	]
	return {"choice": choice_copy, "reaction": reaction_copy, "result": result_copy, "sold": bool(public_result.get("reserve_met", false))}


func make_compact_auction_causal_step(icon_name: String, heading: String, summary_text: String, preserve_case_tile_contract: bool = false) -> PanelContainer:
	var tile := PanelContainer.new()
	if preserve_case_tile_contract:
		tile.name = "CaseTile_%s" % icon_name
	tile.custom_minimum_size = Vector2(0, 52)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := case_panel_style(Color("#171d21e8"), Color("#75664b"))
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	tile.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	tile.add_child(row)
	var icon_rect := TextureRect.new()
	icon_rect.texture = case_icon(icon_name)
	icon_rect.custom_minimum_size = Vector2(30, 30)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_rect)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	var heading_label := make_label(heading, 12, Color("#e3c681"))
	heading_label.max_lines_visible = 1
	heading_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(heading_label)
	var summary := make_label(compact_case_text(summary_text, 34), 12, Color("#e8e0cf"))
	if preserve_case_tile_contract:
		summary.name = "CaseTileSummary_%s" % icon_name
	summary.max_lines_visible = 1
	summary.autowrap_mode = TextServer.AUTOWRAP_OFF
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(summary)
	tile.tooltip_text = "%s · %s" % [heading, summary_text]
	return tile


func make_auction_causal_recap(compact: bool = false) -> GridContainer:
	var recap := GridContainer.new()
	recap.name = "AuctionCausalRecap"
	recap.columns = 3
	recap.add_theme_constant_override("h_separation", 6)
	var data := auction_causal_recap_data()
	if data.is_empty():
		recap.visible = false
		return recap
	var choice := make_compact_auction_causal_step("objective", bilingual("YOUR CHOICE", "내 선택"), String(data.choice)) if compact else make_case_tile("objective", bilingual("YOUR CHOICE", "내 선택"), data.choice)
	choice.name = "AuctionCausalChoice"
	recap.add_child(choice)
	var reaction := make_compact_auction_causal_step("citation", bilingual("BIDDER RESPONSE", "입찰자 반응"), String(data.reaction)) if compact else make_case_tile("citation", bilingual("BIDDER RESPONSE", "입찰자 반응"), data.reaction)
	reaction.name = "AuctionCausalReaction"
	recap.add_child(reaction)
	var result_icon := "support" if bool(data.get("sold", false)) else "risk"
	var result := make_compact_auction_causal_step(result_icon, bilingual("FROZEN RESULT", "확정 결과"), String(data.result)) if compact else make_case_tile(result_icon, bilingual("FROZEN RESULT", "확정 결과"), data.result)
	result.name = "AuctionCausalOutcome"
	recap.add_child(result)
	return recap


func show_auction() -> void:
	screen = "auction"
	ensure_auction_cue_sequence()
	if auction_cue_queue.is_empty():
		show_inventory()
		status.text = bilingual("No listed lot is ready.", "준비된 출품 유물이 없습니다.")
		return
	var cue_state := auction_public_cue_state()
	var phase := String(cue_state.get("phase", "ENTRY"))
	var final_phase := bool(cue_state.get("isFinal", false))
	var body := screen_shell("%s — %s" % [text_for("AUCTION"), text_for("LIVE_BIDDERS")])
	var reserve_session: Dictionary = GameState.grand_reserve_public_state()
	var reserve_phase := String(reserve_session.get("phase", "IDLE"))
	var is_grand_reserve := bool(ensure_pending_auction_snapshot().get("grandReserve", false)) \
		and reserve_phase in ["AUCTION_PENDING", "BETWEEN_LOTS"]
	if is_grand_reserve:
		var reserve_progress := make_label(grand_reserve_progress_text(reserve_session), 15, Color("#e3c681"))
		reserve_progress.name = "GrandReserveProgress"
		reserve_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reserve_progress.autowrap_mode = TextServer.AUTOWRAP_OFF
		body.add_child(reserve_progress)
	var layout := HBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 12)
	body.add_child(layout)

	var auctioneer_state := "INTRO"
	var auctioneer_fact := bilingual("LOT READY", "유물 준비")
	if phase in ["CALL", "BID", "DROPOUT"]:
		auctioneer_state = "CALL"
		auctioneer_fact = bilingual("BIDS OPEN", "입찰 진행 중")
	elif phase in ["SOLD", "NO_SALE"]:
		auctioneer_state = phase
		auctioneer_fact = bilingual("RESULT READY", "결과 기록 대기")
	var auctioneer_cue := character_cue("auctioneer", auctioneer_state, "", auctioneer_fact)
	# Terminal copy adds both result and causal receipt. A 220px portrait remains
	# comfortably above the face-legibility contract while keeping Grand Reserve
	# progress and reason chips clear of the fixed navigation bar.
	var auction_portrait_height := 220.0 if final_phase else 250.0
	var auctioneer_panel := make_portrait_dialogue_panel(auctioneer_cue, 220, auction_portrait_height)

	var center_panel := PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.add_theme_stylebox_override("panel", case_panel_style(Color("#151b1fe8"), Color("#75664b")))
	layout.add_child(center_panel)
	var center_column := VBoxContainer.new()
	center_column.add_theme_constant_override("separation", 7)
	center_panel.add_child(center_column)
	center_column.add_child(make_label(compact_case_text(selected.get("displayName", bilingual("Auction lot", "경매 유물")), 46), 21, Color("#e3c681")))
	center_column.add_child(make_auction_primary_state(cue_state))
	var primary_action := VBoxContainer.new()
	primary_action.name = "AuctionPrimaryAction"
	center_column.add_child(primary_action)
	var auction_action: Button
	if final_phase:
		if is_grand_reserve and reserve_phase == "BETWEEN_LOTS":
			auction_action = make_button(bilingual("NEXT LOT", "다음 유물"), advance_grand_reserve_lot_from_ui, "GrandReserveNextLot")
		else:
			auction_action = make_button(text_for("HAMMER_RECORD"), finalize_sale_from_ui, "HammerButton")
	else:
		auction_action = make_button(bilingual("NEXT CUE", "다음 장면"), advance_auction_cue, "AuctionCueNext")
	primary_action.add_child(mark_primary_action(auction_action))
	var cue_panel := PanelContainer.new()
	cue_panel.name = "AuctionCuePanel"
	cue_panel.add_theme_stylebox_override("panel", case_panel_style(Color("#18231fe8"), Color("#9fd6bd")))
	center_column.add_child(cue_panel)
	var cue_row := HBoxContainer.new()
	cue_panel.add_child(cue_row)
	var phase_label := make_label(auction_phase_label(phase), 14, Color("#e3c681"))
	phase_label.name = "AuctionCuePhase"
	phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	cue_row.add_child(phase_label)
	var progress_label := make_label("%d / %d" % [int(cue_state.get("index", 0)) + 1, int(cue_state.get("total", 1))], 13, Color("#9fd6bd"))
	progress_label.name = "AuctionCueProgress"
	progress_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	cue_row.add_child(progress_label)
	var price_grid := GridContainer.new()
	price_grid.name = "AuctionPriceGrid"
	price_grid.columns = 3
	price_grid.add_theme_constant_override("h_separation", 6)
	center_column.add_child(price_grid)
	var visible_bids: Array = cue_state.get("visibleBids", [])
	if final_phase:
		price_grid.add_child(make_compact_auction_causal_step("objective", bilingual("OPEN", "시작가"), "¤%d" % int(last_auction_result.get("opening", 0)), true))
		price_grid.add_child(make_compact_auction_causal_step("risk", bilingual("RESERVE", "예약가"), "¤%d" % int(last_auction_result.get("reserve", 0)), true))
		price_grid.add_child(make_compact_auction_causal_step("report", bilingual("BIDS", "입찰 수"), "%d" % visible_bids.size(), true))
	else:
		price_grid.add_child(make_case_tile("objective", bilingual("OPEN", "시작가"), "¤%d" % int(last_auction_result.get("opening", 0))))
		price_grid.add_child(make_case_tile("risk", bilingual("RESERVE", "예약가"), "¤%d" % int(last_auction_result.get("reserve", 0))))
		price_grid.add_child(make_case_tile("report", bilingual("BIDS", "입찰 수"), "%d" % visible_bids.size()))
	var calls_heading := bilingual("RECENT CALLS", "최근 호가")
	if final_phase:
		calls_heading += " · %d" % visible_bids.size()
	center_column.add_child(make_label(calls_heading, 15, Color("#8fa5aa")))
	var bid_list: Container
	if final_phase:
		var terminal_bid_grid := GridContainer.new()
		terminal_bid_grid.columns = 2
		terminal_bid_grid.add_theme_constant_override("h_separation", 10)
		terminal_bid_grid.add_theme_constant_override("v_separation", 2)
		bid_list = terminal_bid_grid
	else:
		var live_bid_list := VBoxContainer.new()
		live_bid_list.add_theme_constant_override("separation", 2)
		bid_list = live_bid_list
	bid_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_column.add_child(bid_list)
	if visible_bids.is_empty():
		bid_list.add_child(make_label(bilingual("Waiting for the first public bid.", "첫 공개 입찰을 기다리는 중입니다."), 14, Color("#8fa5aa")))
	else:
		# Keep all four public recent calls without stealing terminal receipt
		# height: the terminal state uses a compact two-column, two-row grid.
		var first_visible_bid := maxi(0, visible_bids.size() - 4) if final_phase else 0
		for bid_value: Variant in visible_bids.slice(first_visible_bid):
			var bid: Dictionary = bid_value if bid_value is Dictionary else {}
			var bid_label := make_label("%s  ·  ¤%d" % [auction_bidder_display_name(String(bid.get("bidderId", ""))), int(bid.get("amount", 0))], 13)
			bid_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bid_label.max_lines_visible = 1
			bid_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			bid_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			bid_list.add_child(bid_label)
	if final_phase:
		var result_color := Color("#9fd6bd") if bool(last_auction_result.get("reserve_met", false)) else Color("#e59b7a")
		var result_label := make_label("%s  ·  %s ¤%d  ·  %s ¤%d" % [text_for("SOLD") if bool(last_auction_result.get("reserve_met", false)) else text_for("NO_SALE"), bilingual("FEE", "수수료"), int(last_auction_result.get("fee", 0)), bilingual("NET", "정산액"), int(last_auction_result.get("net", 0))], 17, result_color)
		result_label.name = "AuctionResultFact"
		center_column.add_child(result_label)
		center_column.add_child(make_auction_causal_recap(true))
	else:
		var cue_fact := make_label("%s · %s" % [auction_phase_label(phase), bilingual("Follow the public call.", "공개 호가를 확인하세요.")], 15, Color("#9fd6bd"))
		cue_fact.name = "AuctionCueFact"
		center_column.add_child(cue_fact)

	var bidder_id := String(cue_state.get("bidderId", ""))
	var bidder_state := "WATCH"
	var bidder_fact := bilingual("WATCHING THE LOT", "유물을 살펴보는 중")
	if phase == "BID":
		bidder_state = "BID"
		bidder_fact = bilingual("LEADING BID", "선두 입찰")
	elif phase == "DROPOUT":
		bidder_state = "DROPOUT"
		bidder_fact = bilingual("BIDDER OUT", "입찰 포기") + " · " + dropout_reason_label(String(cue_state.get("dropoutReason", "")))
	elif phase == "SOLD":
		bidder_state = "WON"
		bidder_fact = bilingual("WINNING BIDDER", "낙찰자")
	elif phase == "NO_SALE":
		bidder_state = "DROPOUT"
		bidder_fact = bilingual("RESERVE NOT MET", "예약가 미달")
	var bidder_cue := character_cue(bidder_id, bidder_state, "", bidder_fact)
	var bidder_column := VBoxContainer.new()
	bidder_column.name = "AuctionBidderColumn"
	bidder_column.custom_minimum_size = Vector2(260, 0)
	bidder_column.add_theme_constant_override("separation", 6)
	layout.add_child(bidder_column)
	bidder_column.add_child(make_portrait_dialogue_panel(bidder_cue, 260, auction_portrait_height))
	var rendered_reasons: Array = [auction_terminal_primary_reason(last_auction_result)] if final_phase else cue_state.get("reasonTags", []).slice(0, mini(2, cue_state.get("reasonTags", []).size()))
	rendered_reasons = rendered_reasons.filter(func(reason_value: Variant): return reason_value is Dictionary and not auction_reason_label(String(reason_value.get("code", ""))).is_empty())
	if not rendered_reasons.is_empty():
		var reason_heading := make_label(bilingual("KEY REACTION", "핵심 반응") if final_phase else bilingual("BIDDER REASONS", "입찰자 반응"), 12, Color("#8fa5aa"))
		reason_heading.name = "AuctionReasonHeading"
		bidder_column.add_child(reason_heading)
		var reason_row := HFlowContainer.new()
		reason_row.name = "AuctionReasonChips"
		bidder_column.add_child(reason_row)
		for reason_index in range(rendered_reasons.size()):
			reason_row.add_child(make_auction_reason_chip(rendered_reasons[reason_index], reason_index))
	# Gameplay hierarchy is center state/action first, active bidder second and
	# the recurring auctioneer last. Portrait identity remains unchanged.
	layout.add_child(auctioneer_panel)
	sync_public_interaction_state()


func finalize_sale_from_ui() -> void:
	var pending := ensure_pending_auction_snapshot()
	if not bool(pending.get("ok", false)):
		status.text = friendly_pending_auction_error(String(pending.get("code", "NO_PENDING_AUCTION")))
		return
	play_sfx("auction_hammer")
	var is_grand_reserve := bool(pending.get("grandReserve", false)) and GameState.grand_reserve_active()
	var result: Dictionary = GameState.commit_grand_reserve_lot(String(pending.get("transactionId", ""))) if is_grand_reserve else GameState.commit_pending_auction(String(pending.get("transactionId", "")))
	if not bool(result.get("ok", false)):
		status.text = friendly_pending_auction_error(String(result.get("code", "AUCTION_COMMIT_FAILED")))
		return
	if is_grand_reserve:
		var reserve_phase := String(GameState.grand_reserve_public_state().get("phase", "IDLE"))
		if reserve_phase == "BETWEEN_LOTS":
			show_auction()
			sync_public_interaction_state("GrandReserveNextLot")
			status.text = bilingual("Lot recorded. Continue when ready.", "유물 결과를 기록했습니다. 준비되면 다음 유물로 진행하세요.")
			return
		if reserve_phase == "FINALIZED":
			show_campaign()
			status.text = bilingual("Grand Reserve complete.", "그랜드 리저브를 마쳤습니다.")
			return
	show_inventory()
	sync_public_interaction_state()
	status.text = text_for("SOLD") if result.get("reserve_met", false) else text_for("NO_SALE_RELIST")


func advance_grand_reserve_lot_from_ui() -> void:
	var result: Dictionary = GameState.advance_grand_reserve_lot()
	if not bool(result.get("ok", false)):
		status.text = friendly_grand_reserve_error(String(result.get("code", "GRAND_RESERVE_SEQUENCE_INVALID")))
		return
	var pending: Dictionary = GameState.pending_auction_public_state()
	var artifact: Dictionary = GameState.find_inventory_instance(String(pending.get("artifactId", "")))
	if artifact.is_empty():
		status.text = friendly_pending_auction_error("AUCTION_LOT_UNAVAILABLE")
		return
	load_artifact(artifact)
	reset_auction_cue_sequence()
	ensure_auction_cue_sequence()
	show_auction()
	sync_public_interaction_state("AuctionCueNext")
	restore_focus_by_name("AuctionCueNext")
	status.text = bilingual("Next Grand Reserve lot opened.", "다음 그랜드 리저브 유물을 공개했습니다.")


func friendly_pending_auction_error(code: String) -> String:
	return localized_value({
		"PENDING_AUCTION_LOCKED": {"en": "Finish the current auction first.", "ko": "현재 경매를 먼저 마치세요."},
		"STALE_PENDING_AUCTION": {"en": "The frozen listing no longer matches. Return to the pending auction.", "ko": "고정된 출품 정보와 다릅니다. 진행 중인 경매로 돌아가세요."},
		"ALREADY_COMMITTED": {"en": "This auction was already recorded.", "ko": "이미 정산한 경매입니다."},
		"AUCTION_LOT_UNAVAILABLE": {"en": "This lot is no longer available.", "ko": "이 유물은 더 이상 정산할 수 없습니다."},
		"UNRESOLVED_CASE_ARTIFACT": {"en": "Resolve the linked case first.", "ko": "연결된 사건을 먼저 해결하세요."},
		"PENDING_AUCTION_SAVE_FAILED": {"en": "The auction state could not be saved.", "ko": "경매 상태를 저장하지 못했습니다."}
	}.get(code, {"en": "The auction action could not be completed.", "ko": "경매 행동을 완료하지 못했습니다."}))


func upgrade_index_by_id(upgrade_id: String) -> int:
	for upgrade_index in RuntimeRegistry.upgrades.size():
		if String(RuntimeRegistry.upgrades[upgrade_index].get("id", "")) == upgrade_id:
			return upgrade_index
	return -1


func upgrade_by_id(upgrade_id: String) -> Dictionary:
	var upgrade_index := upgrade_index_by_id(upgrade_id)
	return RuntimeRegistry.upgrades[upgrade_index] if upgrade_index >= 0 else {}


func friendly_upgrade_name(upgrade: Dictionary) -> String:
	if language == "en":
		return String(upgrade.get("name", "Workshop upgrade"))
	var names := {
		"upgrade_01": "저장 공간 확장", "upgrade_02": "개선 조명", "upgrade_03": "고급 스캐너",
		"upgrade_04": "정밀 도구 세트", "upgrade_05": "촬영 스튜디오", "upgrade_06": "경매 단말기",
		"upgrade_07": "추가 작업대", "upgrade_08": "전시 진열장", "upgrade_09": "부품 보관장",
		"upgrade_10": "복원 작업대", "upgrade_11": "참고 자료실", "upgrade_12": "공방 보험",
		"upgrade_13": "신속 배송", "upgrade_14": "보호 포장", "upgrade_15": "명성 간판",
		"upgrade_16": "항온 보관장", "upgrade_17": "전문가 데스크", "upgrade_18": "보안 기록실",
		"upgrade_19": "시장 연감", "upgrade_20": "중고품 네트워크", "upgrade_21": "박물관 연락관",
		"upgrade_22": "희귀 부품함", "upgrade_23": "고급 카메라", "upgrade_24": "보존 후드",
		"upgrade_25": "공방 보조원"
	}
	return String(names.get(String(upgrade.get("id", "")), "공방 설비"))


func upgrade_role_icon(upgrade: Dictionary) -> String:
	return {
		"capacity": "objective",
		"inspection": "clue_generic",
		"restoration": "tool",
		"auction": "report",
		"network": "support"
	}.get(String(upgrade.get("category", "")), "objective")


func friendly_upgrade_effect_summary(upgrade: Dictionary) -> String:
	var effect: Dictionary = upgrade.get("effect", {})
	var effect_type := String(effect.get("type", ""))
	var value := float(effect.get("value", 0.0))
	var amount := roundi(value * 100.0)
	var count := roundi(value)
	return localized_value({
		"storage_capacity": {"en": "STORAGE +%d" % count, "ko": "보관 +%d" % count},
		"inspection_confidence": {"en": "INSPECTION +%d%%" % amount, "ko": "조사 신뢰 +%d%%" % amount},
		"clue_quality": {"en": "CLUE QUALITY +%d%%" % amount, "ko": "단서 품질 +%d%%" % amount},
		"tool_risk_reduction": {"en": "TOOL RISK −%d%%" % amount, "ko": "도구 위험 −%d%%" % amount},
		"listing_bonus": {"en": "LISTING +%d%%" % amount, "ko": "출품 효과 +%d%%" % amount},
		"auction_fee_reduction": {"en": "AUCTION FEE −%d%%" % amount, "ko": "경매 수수료 −%d%%" % amount},
		"workbench_slots": {"en": "WORKBENCH +%d" % count, "ko": "작업대 +%d" % count},
		"display_bonus": {"en": "DISPLAY +%d%%" % amount, "ko": "전시 효과 +%d%%" % amount},
		"restoration_cost_reduction": {"en": "RESTORE COST −%d%%" % amount, "ko": "복원 비용 −%d%%" % amount},
		"repair_efficiency": {"en": "REPAIR +%d%%" % amount, "ko": "수리 효율 +%d%%" % amount},
		"appraisal_precision": {"en": "APPRAISAL +%d%%" % amount, "ko": "평가 정밀도 +%d%%" % amount},
		"event_mitigation": {"en": "EVENT LOSS −%d%%" % amount, "ko": "사건 손실 −%d%%" % amount},
		"market_slots": {"en": "MARKET LOT +%d" % count, "ko": "시장 유물 +%d" % count},
		"transport_discount": {"en": "TRANSPORT −%d%%" % amount, "ko": "운송 비용 −%d%%" % amount},
		"reputation_bonus": {"en": "REPUTATION +%d" % count, "ko": "명성 +%d" % count},
		"damage_prevention": {"en": "DAMAGE RISK −%d%%" % amount, "ko": "손상 위험 −%d%%" % amount},
		"mastery_gain": {"en": "MASTERY +%d%%" % amount, "ko": "숙련 획득 +%d%%" % amount},
		"provenance_confidence": {"en": "PROVENANCE +%d%%" % amount, "ko": "소장 이력 +%d%%" % amount},
		"market_forecast": {"en": "FORECAST +%d" % count, "ko": "시장 예보 +%d" % count},
		"bidder_reach": {"en": "BIDDER REACH +%d" % count, "ko": "입찰자 범위 +%d" % count},
		"museum_trust_bonus": {"en": "MUSEUM TRUST +%d" % count, "ko": "박물관 신뢰 +%d" % count},
		"repair_risk_reduction": {"en": "REPAIR RISK −%d%%" % amount, "ko": "수리 위험 −%d%%" % amount},
		"integrity_protection": {"en": "INTEGRITY +%d%%" % amount, "ko": "온전성 보호 +%d%%" % amount},
		"workflow_efficiency": {"en": "WORKFLOW +%d%%" % amount, "ko": "작업 효율 +%d%%" % amount}
	}.get(effect_type, {"en": "WORKSHOP BENEFIT", "ko": "공방 효과"}))


func friendly_upgrade_effect_detail(upgrade: Dictionary) -> String:
	var effect: Dictionary = upgrade.get("effect", {})
	var effect_type := String(effect.get("type", ""))
	var summary := friendly_upgrade_effect_summary(upgrade)
	var targets := {
		"storage_capacity": {"en": "Adds room for more owned relics.", "ko": "보유 유물을 둘 공간이 늘어납니다."},
		"inspection_confidence": {"en": "Improves confidence gained during inspection.", "ko": "조사에서 얻는 신뢰도가 높아집니다."},
		"clue_quality": {"en": "Raises the quality of newly recorded clues.", "ko": "새로 기록하는 단서의 품질이 높아집니다."},
		"tool_risk_reduction": {"en": "Reduces risk from workshop tool use.", "ko": "공방 도구 사용 위험을 낮춥니다."},
		"listing_bonus": {"en": "Improves the public presentation of listed relics.", "ko": "출품 유물의 공개 제시 효과를 높입니다."},
		"auction_fee_reduction": {"en": "Reduces fees on completed auction sales.", "ko": "경매 낙찰 수수료를 낮춥니다."},
		"workbench_slots": {"en": "Adds another active workbench place.", "ko": "사용 가능한 작업대 자리가 늘어납니다."},
		"display_bonus": {"en": "Improves collection display benefits.", "ko": "소장품 전시 효과를 높입니다."},
		"restoration_cost_reduction": {"en": "Reduces material cost during restoration.", "ko": "복원 재료 비용을 낮춥니다."},
		"repair_efficiency": {"en": "Improves successful repair efficiency.", "ko": "성공한 수리의 효율을 높입니다."},
		"appraisal_precision": {"en": "Narrows uncertainty in public appraisal.", "ko": "공개 평가의 불확실성을 줄입니다."},
		"event_mitigation": {"en": "Reduces losses from harmful daily events.", "ko": "불리한 일일 사건의 손실을 줄입니다."},
		"market_slots": {"en": "Adds another offer to the daily market.", "ko": "일일 시장 제안이 하나 늘어납니다."},
		"transport_discount": {"en": "Reduces transport and handling cost.", "ko": "운송과 취급 비용을 낮춥니다."},
		"reputation_bonus": {"en": "Adds reputation when its trigger is earned.", "ko": "조건을 달성할 때 명성을 더 얻습니다."},
		"damage_prevention": {"en": "Reduces preventable workshop damage.", "ko": "공방에서 생길 수 있는 손상을 줄입니다."},
		"mastery_gain": {"en": "Increases mastery earned from eligible work.", "ko": "조건에 맞는 작업의 숙련 획득을 높입니다."},
		"provenance_confidence": {"en": "Improves confidence from ownership records.", "ko": "소장 이력 근거의 신뢰도를 높입니다."},
		"market_forecast": {"en": "Adds one step of market foresight.", "ko": "시장 흐름을 한 단계 더 내다봅니다."},
		"bidder_reach": {"en": "Expands the reachable bidder network.", "ko": "접근 가능한 입찰자 네트워크를 넓힙니다."},
		"museum_trust_bonus": {"en": "Adds museum trust when its trigger is earned.", "ko": "조건을 달성할 때 박물관 신뢰를 더 얻습니다."},
		"repair_risk_reduction": {"en": "Reduces risk during precision repairs.", "ko": "정밀 수리 중 위험을 낮춥니다."},
		"integrity_protection": {"en": "Protects historical integrity during work.", "ko": "작업 중 역사적 온전성을 보호합니다."},
		"workflow_efficiency": {"en": "Improves routine workshop efficiency.", "ko": "일상 공방 작업 효율을 높입니다."}
	}
	return "%s · %s" % [summary, localized_value(targets.get(effect_type, {"en": "Improves the workshop.", "ko": "공방 운영을 개선합니다."}))]


func select_upgrade_card(upgrade_id: String) -> void:
	var upgrade_index := upgrade_index_by_id(upgrade_id)
	if upgrade_index < 0:
		return
	selected_upgrade_id = upgrade_id
	upgrade_page = upgrade_index / 6
	show_upgrades()
	status.text = bilingual("Upgrade details selected. Purchase remains a separate action.", "설비 상세를 골랐습니다. 구매는 별도 행동입니다.")


func change_upgrade_page(page_delta: int) -> void:
	var page_count := maxi(1, ceili(float(RuntimeRegistry.upgrades.size()) / 6.0))
	upgrade_page = clampi(upgrade_page + page_delta, 0, page_count - 1)
	var page_start := upgrade_page * 6
	selected_upgrade_id = String(RuntimeRegistry.upgrades[page_start].get("id", "")) if page_start < RuntimeRegistry.upgrades.size() else ""
	show_upgrades()


func make_upgrade_card(upgrade: Dictionary, slot_index: int, is_selected: bool) -> Button:
	var upgrade_id := String(upgrade.get("id", ""))
	var owned := GameState.owned_upgrades.has(upgrade_id)
	var card_text := "%s\n¤%d · %s\n%s" % [
		friendly_upgrade_name(upgrade),
		int(upgrade.get("cost", 0)),
		text_for("OWNED") if owned else text_for("BUY"),
		friendly_upgrade_effect_summary(upgrade)
	]
	var card := make_case_icon_button(upgrade_role_icon(upgrade), card_text, func(): select_upgrade_card(upgrade_id), "UpgradeCard_%d" % slot_index, Vector2(584, 88))
	card.add_theme_font_size_override("font_size", scaled_font_size(13))
	card.add_theme_constant_override("icon_max_width", 42)
	card.add_theme_stylebox_override("normal", case_panel_style(
		Color("#17231fe8") if is_selected else Color("#151b1fe8"),
		Color("#9fd6bd") if is_selected else (Color("#75664b") if owned else Color("#5d625f")),
		2 if is_selected else 1
	))
	card.tooltip_text = "%s\n%s" % [friendly_upgrade_name(upgrade), friendly_upgrade_effect_detail(upgrade)]
	return card


func make_upgrade_detail(upgrade: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "UpgradeDetailPanel"
	panel.custom_minimum_size = Vector2(0, 96)
	panel.add_theme_stylebox_override("panel", case_panel_style(Color("#17201ee8"), Color("#e3c681"), 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = case_icon(upgrade_role_icon(upgrade))
	icon.custom_minimum_size = Vector2(58, 58)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	row.add_child(words)
	var name_label := make_label(friendly_upgrade_name(upgrade), 17, Color("#e3c681"))
	name_label.name = "UpgradeDetailName"
	name_label.max_lines_visible = 1
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(name_label)
	var effect_text := friendly_upgrade_effect_detail(upgrade)
	var effect_label := make_label(effect_text, 13, Color("#d9d1bd"))
	effect_label.name = "UpgradeDetailEffect"
	effect_label.max_lines_visible = 2
	effect_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	effect_label.tooltip_text = effect_text
	words.add_child(effect_label)
	var upgrade_id := String(upgrade.get("id", ""))
	var owned := GameState.owned_upgrades.has(upgrade_id)
	var buy_button := make_case_icon_button("support", text_for("OWNED") if owned else "%s · ¤%d" % [text_for("BUY"), int(upgrade.get("cost", 0))], func(): buy_upgrade_from_ui(upgrade_id), "Upgrade_%s" % upgrade_id, Vector2(280, 58))
	buy_button.disabled = owned
	row.add_child(buy_button)
	return panel


func show_upgrades() -> void:
	screen = "upgrades"
	var body := screen_shell("%s — %s" % [text_for("UPGRADES"), text_for("MATERIAL_EFFECTS_25")])
	if RuntimeRegistry.upgrades.is_empty():
		body.add_child(make_case_tile("tool", text_for("UPGRADES"), bilingual("No upgrades available.", "이용 가능한 설비가 없습니다.")))
		return
	var page_count := maxi(1, ceili(float(RuntimeRegistry.upgrades.size()) / 6.0))
	upgrade_page = clampi(upgrade_page, 0, page_count - 1)
	var selected_index := upgrade_index_by_id(selected_upgrade_id)
	if selected_index < 0:
		selected_index = upgrade_page * 6
		selected_upgrade_id = String(RuntimeRegistry.upgrades[selected_index].get("id", ""))
	else:
		upgrade_page = selected_index / 6
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	body.add_child(progress_row)
	var progress := make_label("%s %d · %s %d / %d" % [bilingual("UPGRADES", "설비"), RuntimeRegistry.upgrades.size(), bilingual("PAGE", "쪽"), upgrade_page + 1, page_count], 16, Color("#e3c681"))
	progress.name = "UpgradeProgress"
	progress.max_lines_visible = 1
	progress.autowrap_mode = TextServer.AUTOWRAP_OFF
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(progress)
	var previous := make_case_icon_button("briefing", bilingual("PREVIOUS", "이전"), func(): change_upgrade_page(-1), "UpgradePrev", Vector2(132, 36))
	previous.disabled = upgrade_page <= 0
	progress_row.add_child(previous)
	var page_label := make_label("%d / %d" % [upgrade_page + 1, page_count], 14, Color("#b7c4c8"))
	page_label.name = "UpgradePage"
	page_label.custom_minimum_size = Vector2(64, 36)
	page_label.max_lines_visible = 1
	page_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_row.add_child(page_label)
	var next := make_case_icon_button("briefing", bilingual("NEXT", "다음"), func(): change_upgrade_page(1), "UpgradeNext", Vector2(132, 36))
	next.disabled = upgrade_page >= page_count - 1
	progress_row.add_child(next)
	var grid := GridContainer.new()
	grid.name = "UpgradeGrid"
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	var page_start := upgrade_page * 6
	var page_end := mini(page_start + 6, RuntimeRegistry.upgrades.size())
	for upgrade_index in range(page_start, page_end):
		var upgrade: Dictionary = RuntimeRegistry.upgrades[upgrade_index]
		grid.add_child(make_upgrade_card(upgrade, upgrade_index - page_start, String(upgrade.get("id", "")) == selected_upgrade_id))
	var detail_upgrade := upgrade_by_id(selected_upgrade_id)
	if not detail_upgrade.is_empty():
		body.add_child(make_upgrade_detail(detail_upgrade))


func buy_upgrade_from_ui(upgrade_id: String) -> void:
	if GameState.buy_upgrade(upgrade_id):
		show_upgrades()
		status.text = text_for("UPGRADE_PURCHASED")
	else:
		status.text = friendly_pending_auction_error(GameState.last_action_error) if GameState.last_action_error == "PENDING_AUCTION_LOCKED" else text_for("UPGRADE_BLOCKED")


func commission_requirement_copy(requirements: Dictionary) -> String:
	var labels: Array = []
	if bool(requirements.get("requiresInspected", false)):
		labels.append(bilingual("INSPECTED", "조사 완료"))
	if bool(requirements.get("requiresRepaired", false)):
		labels.append(bilingual("REPAIRED", "수리 완료"))
	var minimum_clues := int(requirements.get("minimumClues", 0))
	if minimum_clues > 0:
		labels.append(bilingual("%d CLUES" % minimum_clues, "단서 %d개" % minimum_clues))
	var minimum_confidence := float(requirements.get("minimumConfidence", 0.0))
	if minimum_confidence > 0.0:
		labels.append(bilingual("CONFIDENCE %d%%" % roundi(minimum_confidence * 100.0), "신뢰도 %d%%" % roundi(minimum_confidence * 100.0)))
	var minimum_condition := float(requirements.get("minimumCondition", 0.0))
	if minimum_condition > 0.0:
		labels.append(bilingual("CONDITION %d%%" % roundi(minimum_condition * 100.0), "상태 %d%%" % roundi(minimum_condition * 100.0)))
	var minimum_integrity := float(requirements.get("minimumIntegrity", 0.0))
	if minimum_integrity > 0.0:
		labels.append(bilingual("INTEGRITY %d%%" % roundi(minimum_integrity * 100.0), "보존도 %d%%" % roundi(minimum_integrity * 100.0)))
	return " · ".join(labels)


func friendly_commission_error(code: String) -> String:
	return localized_value({
		"COMMISSION_REQUIREMENTS_NOT_MET": {"en": "The selected lot does not meet this request.", "ko": "선택한 유물이 의뢰 조건을 충족하지 않습니다."},
		"ARTIFACT_ALREADY_COMMISSIONED": {"en": "This lot already served one commission.", "ko": "이 유물은 이미 다른 의뢰에 사용되었습니다."},
		"COMMISSION_ALREADY_COMPLETED": {"en": "This request is already complete.", "ko": "이미 완료한 의뢰입니다."},
		"ARTIFACT_NOT_OWNED": {"en": "That lot is no longer in the inventory.", "ko": "해당 유물이 보관함에 없습니다."},
		"CASE_ARTIFACT_LOCKED": {"en": "Resolve the related case first.", "ko": "연결된 사건을 먼저 해결하세요."},
		"PENDING_AUCTION_LOCKED": {"en": "Finish the pending auction first.", "ko": "진행 중인 경매를 먼저 마치세요."}
	}.get(code, {"en": "Commission request unavailable.", "ko": "의뢰를 처리할 수 없습니다."}))


func complete_commission_from_ui(commission_id: String, artifact_id: String) -> void:
	var result := GameState.complete_commission_from_artifact(commission_id, artifact_id)
	show_commissions()
	status.text = bilingual("Commission paid: ¤%d" % int(result.get("net", 0)), "의뢰 보상: ¤%d" % int(result.get("net", 0))) if bool(result.get("ok", false)) else friendly_commission_error(String(result.get("code", "")))


func show_commissions() -> void:
	screen = "commissions"
	var body := screen_shell("%s — %s" % [text_for("COMMISSIONS"), bilingual("SERVICE BOARD", "서비스 게시판")])
	var scroll := ScrollContainer.new()
	scroll.name = "CommissionScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "CommissionGrid"
	grid.columns = 2
	grid.custom_minimum_size = Vector2(1160, 0)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for row_value: Variant in GameState.get_commission_public_state():
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value
		var commission_id := String(row.get("id", ""))
		var panel := PanelContainer.new()
		panel.name = "CommissionCard_%s" % commission_id
		panel.custom_minimum_size = Vector2(570, 148)
		panel.add_theme_stylebox_override("panel", case_panel_style(Color("#111922e8"), Color("#75664b"), 2))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		panel.add_child(column)
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 7)
		column.add_child(header)
		var commission_icon := TextureRect.new()
		commission_icon.name = "CommissionIcon_%s" % commission_id
		commission_icon.texture = case_icon("report")
		commission_icon.custom_minimum_size = Vector2(42, 42)
		commission_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		commission_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		commission_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(commission_icon)
		var title := make_label("%s   ¤%d" % [localized_value(row.get("localizedName", {})), int(row.get("baseReward", 0))], 16, Color("#e3c681"))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.max_lines_visible = 1
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		header.add_child(title)
		var completed := bool(row.get("completed", false))
		var status_label := make_label(text_for("COMPLETE") if completed else bilingual("OPEN", "진행 가능"), 13, Color("#9fd6bd") if completed else Color("#e59b7a"))
		status_label.name = "CommissionStatus_%s" % commission_id
		status_label.custom_minimum_size = Vector2(72, 24)
		status_label.max_lines_visible = 1
		status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header.add_child(status_label)
		var description := make_label(compact_case_text(localized_value(row.get("localizedDescription", {})), 88), 12, Color("#b7c4c8"))
		description.max_lines_visible = 1
		description.autowrap_mode = TextServer.AUTOWRAP_OFF
		description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		column.add_child(description)
		var requirement_label := make_label(commission_requirement_copy(row.get("requirements", {})), 12, Color("#d9d1bd"))
		requirement_label.max_lines_visible = 1
		requirement_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		requirement_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		column.add_child(requirement_label)
		var artifact_row := HBoxContainer.new()
		artifact_row.add_theme_constant_override("separation", 5)
		artifact_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(artifact_row)
		var eligible: Array = row.get("eligibleArtifacts", []) if row.get("eligibleArtifacts", []) is Array else []
		if completed:
			var completed_label := make_label(bilingual("Request completed.", "완료된 의뢰입니다."), 12, Color("#9fd6bd"))
			completed_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			completed_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			completed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			artifact_row.add_child(completed_label)
		elif eligible.is_empty():
			var no_match_label := make_label(bilingual("No matching lot in Inventory.", "조건에 맞는 보관함 유물이 없습니다."), 12, Color("#e59b7a"))
			no_match_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			no_match_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			no_match_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			artifact_row.add_child(no_match_label)
		else:
			for artifact_value: Variant in eligible.slice(0, 3):
				if not artifact_value is Dictionary:
					continue
				var artifact_row_value: Dictionary = artifact_value
				var artifact_id := String(artifact_row_value.get("id", ""))
				var artifact_name := compact_case_text(localized_value(artifact_row_value.get("displayName", "Artifact")), 22)
				var use_button := make_case_icon_button("artifact", bilingual("USE %s" % artifact_name, "%s 사용" % artifact_name), func(): complete_commission_from_ui(commission_id, artifact_id), "CommissionUse_%s_%s" % [commission_id, artifact_id.validate_node_name()], Vector2(170, 42))
				use_button.tooltip_text = artifact_name
				artifact_row.add_child(use_button)
		grid.add_child(panel)


func friendly_npc_name(npc_id: String) -> String:
	var ko_names := {
		"mara_venn": "마라 벤", "elias_rowe": "일라이어스 로",
		"hana_mire": "하나 마이어", "victor_hale": "빅터 헤일",
		"noah_stern": "노아 스턴", "lena_falk": "레나 포크",
		"iris_bell": "아이리스 벨", "dorian_vale": "도리안 베일"
	}
	if language == "ko" and ko_names.has(npc_id):
		return String(ko_names[npc_id])
	return String(RuntimeRegistry.npcs.get(npc_id, {}).get("displayName", bilingual("Workshop contact", "공방 인연")))


func make_case_relationship_reaction(case_id: String, resolution: Dictionary) -> PanelContainer:
	# The resolution transaction already applied the authoritative relationship
	# delta. This compact card explains that public consequence without estimating
	# or reapplying any state change.
	var case_definition := RuntimeRegistry.get_case(case_id)
	var npc_id := String(case_definition.get("npcId", ""))
	var outcome := String(resolution.get("outcome", "reviewed_with_mentor"))
	var semantic := "NEUTRAL"
	var expression := "concerned"
	var reaction_copy := bilingual("We will review the conclusion together.", "결론을 함께 다시 살펴봅니다.")
	if outcome in ["masterful", "credible"]:
		semantic = "POSITIVE"
		expression = "positive"
		reaction_copy = bilingual("Trust grew through careful evidence.", "꼼꼼한 근거로 신뢰가 깊어졌습니다.")
	elif outcome == "mistaken":
		semantic = "NEGATIVE"
		reaction_copy = bilingual("Concern remains about this conclusion.", "이번 결론에 대한 우려가 남았습니다.")
	var relationships_value: Variant = GameState.campaign_state.get("relationships", {})
	var relationships: Dictionary = relationships_value if relationships_value is Dictionary else {}
	var relationship: Dictionary = relationships.get(npc_id, {}) if relationships.get(npc_id, {}) is Dictionary else {}
	var trust := int(relationship.get("trust", 0))
	var panel := PanelContainer.new()
	panel.name = "CaseRelationshipReaction"
	panel.add_theme_stylebox_override("panel", case_panel_style(
		Color("#17251f") if semantic == "POSITIVE" else (Color("#271d1b") if semantic == "NEGATIVE" else Color("#1a2226")),
		Color("#9fd6bd") if semantic == "POSITIVE" else (Color("#e59b7a") if semantic == "NEGATIVE" else Color("#8fa5aa"))
	))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var portrait := TextureRect.new()
	portrait.name = "CaseRelationshipPortrait"
	portrait.custom_minimum_size = Vector2(96, 120)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var presentation := RuntimeRegistry.authored_npc_portrait_presentation(npc_id, expression)
	var asset_path := String(presentation.get("asset_path", ""))
	if not asset_path.is_empty() and ResourceLoader.exists(asset_path):
		portrait.texture = load(asset_path)
		portrait.tooltip_text = localized_value(presentation.get("accessibility_name", friendly_npc_name(npc_id)))
	else:
		portrait.texture = case_icon("npc")
		portrait.tooltip_text = bilingual("Character portrait unavailable", "인물 초상을 불러올 수 없음")
	row.add_child(portrait)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	var heading := make_label("%s · %s" % [friendly_npc_name(npc_id), relationship_band_label(trust)], 16, Color("#e3c681"))
	heading.name = "CaseRelationshipHeading"
	heading.max_lines_visible = 1
	words.add_child(heading)
	var reaction := make_label(reaction_copy, 14, Color("#d9d1bd"))
	reaction.name = "CaseRelationshipCopy"
	reaction.max_lines_visible = 2
	words.add_child(reaction)
	var semantic_label := make_label(bilingual("RELATIONSHIP RESPONSE", "관계 반응"), 12, Color("#8fa5aa"))
	semantic_label.name = "CaseRelationshipSemantic_%s" % semantic
	semantic_label.max_lines_visible = 1
	words.add_child(semantic_label)
	return panel


func strongest_relationship_public() -> Dictionary:
	var best := {"npcId": "", "trust": 0, "relationship": 0}
	var relationships: Dictionary = GameState.campaign_state.get("relationships", {}) if GameState.campaign_state.get("relationships", {}) is Dictionary else {}
	for npc_value: Variant in relationships.keys():
		var npc_id := String(npc_value)
		var row: Dictionary = relationships.get(npc_value, {}) if relationships.get(npc_value, {}) is Dictionary else {}
		var trust := int(row.get("trust", 0))
		var relationship := int(row.get("relationship", 0))
		# Default profile rows mean "not met", not eight equally strong ties.
		if trust == 0 and relationship == 0:
			continue
		if String(best.npcId).is_empty() or trust > int(best.trust) or (trust == int(best.trust) and npc_id < String(best.npcId)):
			best = {"npcId": npc_id, "trust": trust, "relationship": relationship}
	return best


func relationship_band_label(trust: int) -> String:
	if trust >= 6:
		return bilingual("TRUSTED", "깊은 신뢰")
	if trust >= 2:
		return bilingual("GROWING", "신뢰 형성")
	if trust < 0:
		return bilingual("STRAINED", "관계 주의")
	return bilingual("NEW", "새 인연")


func make_relationship_compass() -> PanelContainer:
	var strongest := strongest_relationship_public()
	var panel := PanelContainer.new()
	panel.name = "RelationshipCompass"
	panel.custom_minimum_size = Vector2(0, 36)
	panel.add_theme_stylebox_override("panel", case_panel_style(Color("#151d22e8"), Color("#6f8390")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = case_icon("support")
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var npc_id := String(strongest.get("npcId", ""))
	var trust := int(strongest.get("trust", 0))
	var connection := bilingual("No recurring contact yet", "아직 이어진 인연 없음") if npc_id.is_empty() else "%s · %s" % [friendly_npc_name(npc_id), relationship_band_label(trust)]
	var label := make_label("%s · %s   |   %s %d   |   %s %d" % [
		bilingual("STRONGEST CONNECTION", "이어진 인연"), connection,
		bilingual("ETHICS", "윤리"), int(GameState.campaign_state.get("ethics", 0)),
		bilingual("MUSEUM", "박물관"), int(GameState.campaign_state.get("museumTrust", 0))
	], 12, Color("#d9d1bd"))
	label.name = "RelationshipCompassText"
	label.max_lines_visible = 1
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	panel.tooltip_text = bilingual("Relationships and ethics shape the final reserve outcome.", "인연과 윤리적 선택은 마지막 리저브 결과에 이어집니다.")
	return panel


func show_campaign() -> void:
	screen = "campaign"
	var current_act: String = GameState.campaign_state.currentAct
	var act := RuntimeRegistry.get_act(current_act)
	var world_mode := "grand_reserve" if current_act == "GRAND_RESERVE" else "workshop"
	var stage_status := String(GameState.stage_run_state.get("status", "NOT_STARTED"))
	var stage_scoped := stage_status in ["RUNNING", "CLEARED"]
	var stage_definition := RuntimeRegistry.get_stage_definition(GameState.current_stage) if stage_scoped else {}
	var campaign_title := "%s — %s" % [text_for("CAMPAIGN"), friendly_act_title(current_act)]
	if stage_scoped:
		campaign_title = "%s %d — %s" % [bilingual("STAGE", "스테이지"), GameState.current_stage, compact_case_text(stage_definition.get("title", ""), 42)]
	var body := screen_shell(campaign_title, world_mode)
	if stage_scoped:
		var story_breadcrumb := make_label("%s · %s" % [bilingual("STORY", "이야기"), friendly_act_title(current_act)], 13, Color("#8fa5aa"))
		story_breadcrumb.name = "CampaignStoryBreadcrumb"
		story_breadcrumb.max_lines_visible = 1
		story_breadcrumb.autowrap_mode = TextServer.AUTOWRAP_OFF
		body.add_child(story_breadcrumb)
		var stage_summary := GameState.stage_public_summary()
		var stage_case_ids: Array = GameState.get_current_stage_case_ids()
		var completed_stage_cases := stage_case_ids.filter(func(case_id: String): return GameState.campaign_state.completedCases.has(case_id)).size()
		var stage_header := HBoxContainer.new()
		stage_header.add_theme_constant_override("separation", 8)
		body.add_child(stage_header)
		stage_header.add_child(make_case_tile("objective", "%s %d" % [bilingual("STAGE", "스테이지"), GameState.current_stage], stage_definition.get("title", "")))
		var score_tile := make_case_tile("support", bilingual("PERFORMANCE", "성과"), "%s %s · %s %s" % [bilingual("CURRENT", "현재"), stage_score_text(stage_summary.get("current", 0.0)), bilingual("RECOMMENDED", "권장"), stage_score_text(stage_summary.get("target", 0.0))])
		score_tile.name = "StageProgressScore"
		stage_header.add_child(score_tile)
		var case_tile := make_case_tile("report", bilingual("CASES", "사건"), "%d / %d" % [completed_stage_cases, stage_case_ids.size()])
		case_tile.name = "StageProgressCases"
		stage_header.add_child(case_tile)
		var focus_panel := PanelContainer.new()
		focus_panel.name = "StageFocusBar"
		focus_panel.custom_minimum_size = Vector2(0, 36)
		focus_panel.add_theme_stylebox_override("panel", case_panel_style(Color("#18231fe8"), Color("#9fd6bd")))
		var focus_row := HBoxContainer.new()
		focus_row.add_theme_constant_override("separation", 8)
		focus_panel.add_child(focus_row)
		var focus_icon := TextureRect.new()
		focus_icon.texture = case_icon("core_question")
		focus_icon.custom_minimum_size = Vector2(24, 24)
		focus_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		focus_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		focus_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_row.add_child(focus_icon)
		var focus_copy := localized_value(stage_definition.get("performance_target", {}).get("goal_label", {}))
		var focus_label := make_label("%s · %s" % [bilingual("STAGE FOCUS", "이번 스테이지의 판단"), focus_copy], 13, Color("#d9d1bd"))
		focus_label.name = "StageFocusText"
		focus_label.max_lines_visible = 1
		focus_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		focus_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		focus_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		focus_row.add_child(focus_label)
		focus_panel.tooltip_text = focus_copy
		body.add_child(focus_panel)
	else:
		body.add_child(make_label(text_format("CAMPAIGN_LOCATION", [friendly_location_label(String(act.get("location", ""))), GameState.campaign_state.completedCases.size(), RuntimeRegistry.campaign_cases.size()]), 17))
	body.add_child(make_label(text_format("CAMPAIGN_STATS", [int(GameState.campaign_state.museumTrust), int(GameState.campaign_state.collectorNetwork), GameState.mastery_total(), int(GameState.campaign_state.historicalIntegrity)]), 16, Color("#a8b0ad")))
	# The full Stage-clear card is the densest 720p campaign state. Keep the
	# relationship summary on active campaign and postgame screens, but yield its
	# row here so 116% text and both result actions stay above global navigation.
	if not (stage_scoped and stage_status == "CLEARED" and GameState.stage_clear_pending()):
		body.add_child(make_relationship_compass())
	if current_act == "POSTGAME" or bool(GameState.campaign_state.get("postGame", false)):
		show_postgame()
		return
	if stage_scoped and stage_status == "CLEARED" and GameState.stage_clear_pending():
		# Completion freezes public scores/status keys. Recomputing here would let a
		# locale refresh or later history mutation rewrite an already-earned card.
		var replay_feedback: Dictionary = GameState.stage_run_state.get("stageReplayFeedbackSnapshot", {}).duplicate(true)
		if replay_feedback.is_empty() and GameState.has_method("stage_replay_feedback"):
			var legacy_feedback: Variant = GameState.call("stage_replay_feedback")
			if legacy_feedback is Dictionary:
				replay_feedback = legacy_feedback
		var replay_telemetry: Dictionary = GameState.stage_run_state.get("stageReplayTelemetrySnapshot", {}).duplicate(true)
		body.add_child(make_stage_clear_card(GameState.stage_public_summary(), replay_feedback, replay_telemetry))
		if GameState.current_stage == 10 and not String(GameState.campaign_state.get("currentEnding", "")).is_empty():
			body.add_child(mark_primary_action(make_case_icon_button("support", bilingual("VIEW ENDING", "엔딩 보기"), view_stage_ending_from_ui, "StageClearViewEnding", Vector2(0, 58))))
		else:
			var clear_actions := HBoxContainer.new()
			clear_actions.name = "StageClearActions"
			clear_actions.add_theme_constant_override("separation", 8)
			var next_button := mark_primary_action(make_case_icon_button("support", bilingual("NEXT STAGE", "다음 스테이지"), acknowledge_stage_clear_then_start_next, "CampaignStageSelect", Vector2(0, 58)))
			next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			next_button.tooltip_text = bilingual("A stage must be cleared before the next one becomes available.", "스테이지를 클리어해야 다음 스테이지로 진행할 수 있습니다.")
			clear_actions.add_child(next_button)
			var replay_button := make_case_icon_button("briefing", bilingual("REPLAY CLEARED", "클리어 스테이지 재도전"), acknowledge_stage_clear_then_select, "CampaignStageReplaySelect", Vector2(0, 58))
			replay_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			replay_button.tooltip_text = bilingual("Replay a cleared stage without changing progression.", "진행도를 바꾸지 않고 클리어한 스테이지를 다시 플레이합니다.")
			clear_actions.add_child(replay_button)
			body.add_child(clear_actions)
		return
	if current_act == "EPILOGUE" or not String(GameState.campaign_state.get("currentEnding", "")).is_empty():
		show_ending()
		return
	if current_act == "GRAND_RESERVE":
		body.add_child(make_label(text_for("GRAND_RESERVE_READY"), 20, Color("#e3c681")))
		body.add_child(make_button(text_for("SELECT_FINAL_LOTS"), show_final_lot_selection, "GrandReserveSelect"))
		return
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var visible_case_ids: Array = GameState.get_current_stage_case_ids() if stage_scoped else GameState.act_case_ids(current_act)
	var pending_case_id := GameState.current_stage_first_pending_case() if stage_scoped else ""
	for case_id: String in visible_case_ids:
		var story_case := RuntimeRegistry.get_case(case_id)
		var row := HBoxContainer.new()
		var complete: bool = GameState.campaign_state.completedCases.has(case_id)
		var waiting := stage_scoped and not complete and case_id != pending_case_id
		var case_state_text: String = text_for("COMPLETE") if complete else (bilingual("Complete the clue card above first", "위 사건을 먼저 해결하세요") if waiting else String(story_case.summary))
		var label := make_label("%s — %s" % [friendly_case_name(case_id), compact_case_text(case_state_text, 76)], 16)
		label.max_lines_visible = 2
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var selected_case_id: String = case_id
		var button := make_button(text_for("COMPLETE") if complete else (bilingual("LOCKED", "잠김") if waiting else text_for("BEGIN_CASE")), func(): begin_case_from_ui(selected_case_id), "Case_%s" % case_id)
		button.disabled = complete or waiting
		row.add_child(button)
		rows.add_child(row)


func acknowledge_stage_clear_then_select() -> void:
	var result: Dictionary = GameState.acknowledge_stage_clear()
	if not bool(result.get("ok", false)):
		status.text = bilingual("The Stage result could not be saved.", "스테이지 결과 확인을 저장하지 못했습니다.")
		return
	show_stage_select()


func acknowledge_stage_clear_then_start_next() -> void:
	var result: Dictionary = GameState.acknowledge_stage_clear()
	if not bool(result.get("ok", false)):
		status.text = bilingual("The Stage result could not be saved.", "스테이지 결과 확인을 저장하지 못했습니다.")
		return
	start_progression_game_from_ui()


func start_progression_game_from_ui() -> void:
	var result: Dictionary = GameState.new_game_progression()
	if not bool(result.get("ok", false)):
		show_stage_select()
		status.text = bilingual("The next Stage could not be started.", "다음 스테이지를 시작하지 못했습니다.")
		return
	market_character_state = "WELCOME"
	market_character_dialogue = ""
	market_character_fact = ""
	market_active_lot_id = ""
	show_campaign()
	status.text = "%s %d · ×%.2f" % [bilingual("STAGE STARTED", "스테이지 시작"), int(result.get("stage", GameState.current_stage)), float(result.get("difficultyMultiplier", 1.0))]


func view_stage_ending_from_ui() -> void:
	var result: Dictionary = GameState.acknowledge_stage_clear()
	if not bool(result.get("ok", false)):
		status.text = bilingual("The Stage result could not be saved.", "스테이지 결과 확인을 저장하지 못했습니다.")
		return
	show_ending()


func begin_case_from_ui(case_id: String) -> void:
	var artifact := GameState.begin_case(case_id)
	if artifact.is_empty():
		status.text = text_for("CASE_CANNOT_BEGIN")
		return
	selected = artifact
	load_artifact(artifact)
	show_case_dossier(case_id)
	status.text = text_for("CASE_ARTIFACT_ADDED")


func make_compact_status_badge(text_value: String, positive: bool, node_name: String) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.name = node_name
	badge.custom_minimum_size = Vector2(112, 28)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.add_theme_stylebox_override("panel", case_panel_style(
		Color("#17231f") if positive else Color("#25231d"),
		Color("#9fd6bd") if positive else Color("#d6b36a")
	))
	var label := make_label(text_value, 12, Color("#bfe4d2") if positive else Color("#e3c681"))
	label.name = "%sLabel" % node_name
	label.max_lines_visible = 1
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(label)
	badge.tooltip_text = text_value
	return badge


func final_lot_badges(artifact: Dictionary) -> Array:
	var integrity := clampf(float(artifact.get("historicalIntegrity", 0.0)), 0.0, 100.0)
	return [
		{"text": bilingual("EVIDENCE READY", "근거 준비"), "positive": true},
		{
			"text": bilingual("PRESERVED", "보존 양호") if integrity >= 70.0 else bilingual("STABLE", "보존 안정"),
			"positive": integrity >= 60.0
		}
	]


func make_final_lot_card(artifact: Dictionary, slot_index: int, is_selected: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "FinalLotCard_%d" % slot_index
	card.custom_minimum_size = Vector2(380, 146)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", case_panel_style(
		Color("#17231fe8") if is_selected else Color("#151b1fe8"),
		Color("#9fd6bd") if is_selected else Color("#75664b"),
		2 if is_selected else 1
	))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	card.add_child(column)
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 8)
	column.add_child(summary_row)
	var icon := TextureRect.new()
	icon.name = "FinalLotIcon"
	icon.texture = case_icon("artifact")
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_row.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	summary_row.add_child(words)
	var full_name := String(artifact.get("displayName", bilingual("Final lot", "최종 출품작")))
	var name_label := make_label(full_name, 14, Color("#f2e8cf"))
	name_label.name = "FinalLotName"
	name_label.max_lines_visible = 1
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.tooltip_text = full_name
	words.add_child(name_label)
	var value_label := make_label("¤%d · %s" % [int(artifact.get("estimatedValue", 0)), friendly_artifact_visual(artifact)], 16, Color("#e3c681"))
	value_label.name = "FinalLotValue"
	value_label.max_lines_visible = 1
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.tooltip_text = friendly_artifact_visual(artifact)
	words.add_child(value_label)
	var badge_row := HBoxContainer.new()
	badge_row.name = "FinalLotBadgeRow"
	badge_row.add_theme_constant_override("separation", 6)
	column.add_child(badge_row)
	var badge_specs := final_lot_badges(artifact)
	for badge_index in range(mini(2, badge_specs.size())):
		var badge_spec: Dictionary = badge_specs[badge_index]
		badge_row.add_child(make_compact_status_badge(
			String(badge_spec.get("text", "")),
			bool(badge_spec.get("positive", false)),
			"FinalLotBadge_%d" % badge_index
		))
	var instance_id := String(artifact.get("uniqueId", ""))
	var toggle := make_case_icon_button(
		"support" if is_selected else "objective",
		text_for("REMOVE") if is_selected else text_for("SELECT"),
		func(): select_final_lot_from_ui(instance_id),
		"FinalLotToggle",
		Vector2(0, 36)
	)
	toggle.alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(toggle)
	card.tooltip_text = "%s\n%s · ¤%d" % [full_name, friendly_artifact_visual(artifact), int(artifact.get("estimatedValue", 0))]
	return card


func change_final_lot_page(page_delta: int) -> void:
	var page_count := maxi(1, ceili(float(GameState.eligible_final_lots().size()) / 6.0))
	final_lot_page = clampi(final_lot_page + page_delta, 0, page_count - 1)
	show_final_lot_selection()


func show_final_lot_selection() -> void:
	screen = "final_selection"
	var body := screen_shell("%s — %s" % [text_for("GRAND_RESERVE"), text_for("THREE_FINAL_LOTS")], "grand_reserve")
	var eligible_lots: Array = GameState.eligible_final_lots()
	var selected_ids: Array = GameState.campaign_state.grandReserve.selectedLotIds
	var page_count := maxi(1, ceili(float(eligible_lots.size()) / 6.0))
	final_lot_page = clampi(final_lot_page, 0, page_count - 1)
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 8)
	body.add_child(progress_row)
	var progress := make_label("%s %d / 3" % [bilingual("SELECTED", "선택"), selected_ids.size()], 19, Color("#e3c681"))
	progress.name = "FinalSelectionProgress"
	progress.max_lines_visible = 1
	progress.autowrap_mode = TextServer.AUTOWRAP_OFF
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(progress)
	if page_count > 1:
		var previous := make_case_icon_button("briefing", bilingual("PREVIOUS", "이전"), func(): change_final_lot_page(-1), "FinalLotPrev", Vector2(128, 38))
		previous.disabled = final_lot_page <= 0
		progress_row.add_child(previous)
		var page_label := make_label("%d / %d" % [final_lot_page + 1, page_count], 14, Color("#b7c4c8"))
		page_label.name = "FinalLotPage"
		page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		progress_row.add_child(page_label)
		var next := make_case_icon_button("briefing", bilingual("NEXT", "다음"), func(): change_final_lot_page(1), "FinalLotNext", Vector2(128, 38))
		next.disabled = final_lot_page >= page_count - 1
		progress_row.add_child(next)
	var grid := GridContainer.new()
	grid.name = "FinalLotGrid"
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	var page_start := final_lot_page * 6
	var page_end := mini(page_start + 6, eligible_lots.size())
	for final_index in range(page_start, page_end):
		var artifact: Dictionary = eligible_lots[final_index]
		var is_selected := selected_ids.has(String(artifact.get("uniqueId", "")))
		grid.add_child(make_final_lot_card(artifact, final_index - page_start, is_selected))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	body.add_child(footer)
	var requirement_text := bilingual("Choose exactly 3 different prepared relics.", "준비된 서로 다른 유물 3점을 고르세요.")
	var requirement := make_label(requirement_text, 14, Color("#9fd6bd") if selected_ids.size() == 3 else Color("#e59b7a"))
	requirement.name = "FinalSelectionRequirement"
	requirement.max_lines_visible = 1
	requirement.autowrap_mode = TextServer.AUTOWRAP_OFF
	requirement.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	requirement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	requirement.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(requirement)
	var start_button := make_case_icon_button("support", text_for("BEGIN_GRAND_RESERVE"), run_grand_reserve_from_ui, "BeginGrandReserve", Vector2(390, 50))
	start_button.disabled = selected_ids.size() != 3
	footer.add_child(start_button)


func select_final_lot_from_ui(instance_id: String) -> void:
	var changed := GameState.select_final_lot(instance_id)
	show_final_lot_selection()
	if not changed and GameState.last_action_error == "PENDING_AUCTION_LOCKED":
		status.text = friendly_pending_auction_error(GameState.last_action_error)


func run_grand_reserve_from_ui() -> void:
	var result := GameState.begin_grand_reserve_session()
	if not bool(result.get("ok", false)):
		status.text = "%s · %s" % [text_for("GRAND_RESERVE_INCOMPLETE"), friendly_grand_reserve_error(String(result.get("code", "PREFLIGHT_FAILED")))]
		return
	var pending: Dictionary = GameState.pending_auction_public_state()
	var artifact: Dictionary = GameState.find_inventory_instance(String(pending.get("artifactId", "")))
	if artifact.is_empty():
		status.text = friendly_pending_auction_error("AUCTION_LOT_UNAVAILABLE")
		return
	load_artifact(artifact)
	reset_auction_cue_sequence()
	ensure_auction_cue_sequence()
	show_auction()
	sync_public_interaction_state("AuctionCueNext")
	restore_focus_by_name("AuctionCueNext")
	status.text = bilingual("Grand Reserve lot 1 opened.", "그랜드 리저브 첫 유물을 공개했습니다.")


func friendly_grand_reserve_error(code: String) -> String:
	var labels := {
		"NOT_INVITED": {"en": "invitation required", "ko": "초대가 필요합니다"},
		"ALREADY_COMPLETED": {"en": "auction already completed", "ko": "이미 경매를 마쳤습니다"},
		"REQUIRES_THREE_LOTS": {"en": "select three eligible lots", "ko": "출품 가능 유물 3개를 선택하세요"},
		"DUPLICATE_LOT": {"en": "choose three different lots", "ko": "서로 다른 유물 3개를 고르세요"},
		"LOT_NOT_OWNED": {"en": "a selected lot is unavailable", "ko": "선택한 유물을 보유하고 있지 않습니다"},
		"CASE_LOT_LOCKED": {"en": "finish the linked case first", "ko": "연결된 사건을 먼저 해결하세요"},
		"LOT_NOT_ELIGIBLE": {"en": "a selected lot is not eligible", "ko": "출품 조건에 맞지 않는 유물이 있습니다"},
		"PENDING_AUCTION_LOCKED": {"en": "finish the current auction first", "ko": "현재 경매를 먼저 마치세요"},
		"GRAND_RESERVE_NOT_BETWEEN_LOTS": {"en": "record this lot before continuing", "ko": "현재 유물 결과를 먼저 기록하세요"},
		"GRAND_RESERVE_SEQUENCE_INVALID": {"en": "the saved auction sequence is inconsistent", "ko": "저장된 경매 순서를 확인할 수 없습니다"},
		"PENDING_AUCTION_SAVE_FAILED": {"en": "the auction checkpoint could not be saved", "ko": "경매 진행을 저장하지 못했습니다"},
		"PREFLIGHT_FAILED": {"en": "check the final lot requirements", "ko": "최종 출품 조건을 확인하세요"}
	}
	return localized_value(labels.get(code, labels.PREFLIGHT_FAILED))


func show_grand_reserve() -> void:
	show_final_lot_selection()


func ending_public_summary(ending_id: String) -> String:
	var summaries := {
		"ENDING_S": {
			"en": "Evidence, preservation, and sale moved in balance. The Reserve remembers a complete craft.",
			"ko": "근거와 보존, 판매가 균형을 이뤘습니다. 리저브는 완성된 솜씨를 기억합니다."
		},
		"ENDING_A": {
			"en": "Careful hands gave fragile history another life. Restoration became your signature.",
			"ko": "세심한 손길이 위태로운 역사에 새 생명을 주었습니다. 복원이 당신의 표식이 되었습니다."
		},
		"ENDING_B": {
			"en": "The room learned to follow your gavel. Your house became a force at auction.",
			"ko": "경매장은 당신의 망치 소리를 따르게 됐습니다. 공방은 시장의 강자가 되었습니다."
		},
		"ENDING_C": {
			"en": "You kept the story with the object. Museums now trust your careful judgment.",
			"ko": "유물과 함께 이야기도 지켜냈습니다. 박물관은 당신의 신중한 판단을 신뢰합니다."
		},
		"ENDING_D": {
			"en": "A damaged trust cannot be restored in one night. The workshop must earn its name again.",
			"ko": "무너진 신뢰는 하룻밤에 복원되지 않습니다. 공방의 이름을 다시 증명해야 합니다."
		}
	}
	return localized_value(summaries.get(ending_id, {
		"en": "The workshop opens a new chapter after the Grand Reserve.",
		"ko": "그랜드 리저브를 지나 공방의 새로운 장이 열립니다."
	}))


func ending_public_icon(ending_id: String) -> String:
	return "risk" if ending_id == "ENDING_D" else ("tool" if ending_id == "ENDING_A" else ("report" if ending_id == "ENDING_B" else ("citation" if ending_id == "ENDING_C" else "support")))


func make_ending_hero(ending_id: String) -> PanelContainer:
	var hero := PanelContainer.new()
	hero.name = "EndingHeroCard"
	hero.custom_minimum_size = Vector2(0, 86)
	hero.add_theme_stylebox_override("panel", case_panel_style(Color("#17231fe8"), Color("#e3c681"), 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	hero.add_child(row)
	var icon := TextureRect.new()
	icon.name = "EndingHeroIcon"
	icon.texture = case_icon(ending_public_icon(ending_id))
	icon.custom_minimum_size = Vector2(60, 60)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	row.add_child(words)
	var title := make_label(friendly_ending_title(ending_id), 22, Color("#e3c681"))
	title.name = "EndingTitle"
	title.max_lines_visible = 1
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(title)
	var summary := make_label(ending_public_summary(ending_id), 14, Color("#d9d1bd"))
	summary.name = "EndingSummary"
	summary.max_lines_visible = 2
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(summary)
	return hero


func ending_axis_label(axis_id: String) -> String:
	return localized_value({
		"investigation": {"en": "INVESTIGATION", "ko": "조사"},
		"preservation": {"en": "PRESERVATION", "ko": "보존"},
		"sale": {"en": "SALE", "ko": "판매"}
	}.get(axis_id, {"en": "RESULT", "ko": "결과"}))


func make_ending_axis_tile(axis_id: String, axis_state: Dictionary) -> PanelContainer:
	var tile := make_stage_replay_axis_tile(axis_id, axis_state)
	tile.name = "EndingAxis_%s" % axis_id
	var axis_label := tile.find_child("StageReplayAxisLabel_%s" % axis_id, true, false)
	if axis_label is Label:
		axis_label.text = ending_axis_label(axis_id)
	tile.tooltip_text = "%s · %s · %s" % [ending_axis_label(axis_id), stage_replay_axis_score(axis_state), stage_replay_axis_status(axis_id, axis_state)]
	return tile


func ending_lot_reason(auction: Dictionary) -> Dictionary:
	var reason_values: Variant = auction.get("reasonTags", [])
	if reason_values is Array:
		for reason_value: Variant in reason_values:
			if reason_value is Dictionary and not auction_reason_label(String(reason_value.get("code", ""))).is_empty():
				return reason_value.duplicate(true)
	var sold := String(auction.get("sale_status", "")) == "SOLD"
	if sold:
		return {"code": "RESERVE_MET", "polarity": "POSITIVE"}
	return {
		"code": "NO_PUBLIC_BID" if int(auction.get("hammer", 0)) <= 0 else "RESERVE_TOO_HIGH",
		"polarity": "NEGATIVE"
	}


func make_ending_lot_card(result: Dictionary, result_index: int) -> PanelContainer:
	var artifact: Dictionary = result.get("artifact", {})
	var auction: Dictionary = result.get("auction", {})
	var card := PanelContainer.new()
	card.name = "EndingLotCard_%d" % result_index
	card.custom_minimum_size = Vector2(380, 122)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", case_panel_style(Color("#151b1fe8"), Color("#75664b")))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	card.add_child(column)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	column.add_child(name_row)
	var icon := TextureRect.new()
	icon.name = "EndingLotIcon"
	icon.texture = case_icon("artifact")
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(icon)
	var full_name := String(artifact.get("displayName", bilingual("Final lot", "최종 출품작")))
	var name_label := make_label(full_name, 14, Color("#f2e8cf"))
	name_label.name = "EndingLotName"
	name_label.max_lines_visible = 1
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.tooltip_text = full_name
	name_row.add_child(name_label)
	var sold := String(auction.get("sale_status", "")) == "SOLD"
	var result_text := "%s · ¤%d" % [friendly_auction_status("SOLD"), int(auction.get("hammer", 0))] if sold else friendly_auction_status("NO_SALE")
	var result_label := make_label(result_text, 16, Color("#9fd6bd") if sold else Color("#e59b7a"))
	result_label.name = "EndingLotResult"
	result_label.max_lines_visible = 1
	result_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	column.add_child(result_label)
	var reason := ending_lot_reason(auction)
	column.add_child(make_public_reason_chip(
		reason,
		"EndingLotReasonChip",
		"EndingLotReasonLabel",
		bilingual("Final public reason", "최종 공개 사유"),
		176.0
	))
	return card


func show_ending() -> void:
	screen = "ending"
	var ending_id: String = GameState.campaign_state.currentEnding
	var body := screen_shell("%s — %s" % [text_for("ENDING"), friendly_ending_title(ending_id)], "grand_reserve")
	body.add_child(make_ending_hero(ending_id))
	var replay_feedback: Dictionary = GameState.stage_run_state.get("stageReplayFeedbackSnapshot", {}).duplicate(true)
	if replay_feedback.is_empty():
		replay_feedback = GameState.stage_replay_feedback(10)
	var axes_row := HBoxContainer.new()
	axes_row.name = "EndingAxes"
	axes_row.add_theme_constant_override("separation", 8)
	body.add_child(axes_row)
	for axis_id in ["investigation", "preservation", "sale"]:
		var axis_state: Dictionary = replay_feedback.get("axes", {}).get(axis_id, {})
		axes_row.add_child(make_ending_axis_tile(axis_id, axis_state))
	var result_grid := GridContainer.new()
	result_grid.name = "EndingLotGrid"
	result_grid.columns = 3
	result_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_grid.add_theme_constant_override("h_separation", 8)
	body.add_child(result_grid)
	var final_results: Array = GameState.campaign_state.grandReserve.results
	for result_index in range(mini(3, final_results.size())):
		result_grid.add_child(make_ending_lot_card(final_results[result_index], result_index))
	var continue_button := make_case_icon_button("support", text_for("CONTINUE_POSTGAME"), enter_postgame_from_ui, "PostgameButton", Vector2(0, 52))
	body.add_child(continue_button)


func enter_postgame_from_ui() -> void:
	GameState.acknowledge_epilogue()
	postgame_credits_visible = false
	show_postgame()


func make_postgame_hero(ending_id: String) -> PanelContainer:
	var hero := make_ending_hero(ending_id)
	hero.name = "PostgameHeroCard"
	var title := hero.find_child("EndingTitle", true, false)
	if title is Label:
		title.name = "PostgameEndingTitle"
	var summary := hero.find_child("EndingSummary", true, false)
	if summary is Label:
		summary.name = "PostgameSummary"
		summary.text = text_for("POSTGAME_SUMMARY")
		summary.max_lines_visible = 2
	return hero


func make_postgame_ending_card(ending_id: String, card_index: int, unlocked: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "EndingCard_%d" % card_index
	card.custom_minimum_size = Vector2(228, 150)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", case_panel_style(
		Color("#17231fe8") if unlocked else Color("#12171ae8"),
		Color("#9fd6bd") if unlocked else Color("#4f565a"),
		2 if unlocked else 1
	))
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var icon := TextureRect.new()
	icon.name = "EndingCardIcon"
	icon.texture = case_icon(ending_public_icon(ending_id) if unlocked else "locked")
	icon.custom_minimum_size = Vector2(58, 58)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon)
	var title := make_label(friendly_ending_title(ending_id) if unlocked else "???", 14, Color("#f2e8cf") if unlocked else Color("#7e8588"))
	title.name = "EndingCardTitle"
	title.max_lines_visible = 2
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(title)
	var state := make_label(bilingual("UNLOCKED", "해금") if unlocked else bilingual("LOCKED", "잠김"), 12, Color("#9fd6bd") if unlocked else Color("#7e8588"))
	state.name = "EndingCardState"
	state.max_lines_visible = 1
	state.autowrap_mode = TextServer.AUTOWRAP_OFF
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(state)
	card.tooltip_text = friendly_ending_title(ending_id) if unlocked else bilingual("Discover this ending in a new run.", "새 게임에서 이 결말을 발견하세요.")
	return card


func postgame_best_score(profile: Dictionary) -> float:
	var best := 0.0
	var stage_best_value: Variant = profile.get("stageBest", {})
	if stage_best_value is Dictionary:
		for score_value: Variant in stage_best_value.values():
			if score_value is int or score_value is float:
				best = maxf(best, float(score_value))
	return best


func toggle_postgame_credits() -> void:
	postgame_credits_visible = not postgame_credits_visible
	show_postgame()


func postgame_new_game_from_ui() -> void:
	postgame_credits_visible = false
	final_lot_page = 0
	var result: Dictionary = GameState.new_game_progression()
	if not bool(result.get("ok", false)):
		show_stage_select()
		status.text = bilingual("A new run could not be started.", "새 게임을 시작하지 못했습니다.")
		return
	show_campaign()
	status.text = "%s %d" % [bilingual("The next Stage has begun.", "다음 스테이지를 시작했습니다."), int(result.get("stage", GameState.current_stage))]


func show_postgame() -> void:
	screen = "postgame"
	var body := screen_shell("%s — %s" % [text_for("POSTGAME"), text_for("ENDLESS_WORKSHOP")])
	var ending_id := String(GameState.campaign_state.get("currentEnding", ""))
	body.add_child(make_postgame_hero(ending_id))
	var profile: Dictionary = GameState.player_profile
	var cleared: Array = profile.get("clearedStages", []) if profile.get("clearedStages", []) is Array else []
	var unlocked_endings: Array = GameState.campaign_state.get("endingUnlocked", []) if GameState.campaign_state.get("endingUnlocked", []) is Array else []
	var progress_text := "%s %d / 10 · %s %s · %s %d / 5" % [
		bilingual("CLEARED", "클리어"), cleared.size(),
		bilingual("BEST", "최고"), stage_score_text(postgame_best_score(profile)),
		bilingual("ENDINGS", "결말"), unlocked_endings.size()
	]
	var progress := make_label(progress_text, 16, Color("#e3c681"))
	progress.name = "PostgameProgress"
	progress.max_lines_visible = 1
	progress.autowrap_mode = TextServer.AUTOWRAP_OFF
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(progress)
	var archive := GridContainer.new()
	archive.name = "PostgameArchiveSummary"
	archive.visible = not postgame_credits_visible
	archive.columns = 3
	archive.add_theme_constant_override("h_separation", 8)
	body.add_child(archive)
	var completed_cases: Dictionary = GameState.campaign_state.get("completedCases", {}) if GameState.campaign_state.get("completedCases", {}) is Dictionary else {}
	var statistics: Dictionary = GameState.statistics
	var case_archive := make_case_tile("briefing", bilingual("CASE FILES", "사건 기록"), "%d / %d" % [completed_cases.size(), RuntimeRegistry.campaign_cases.size()])
	case_archive.name = "PostgameCaseArchive"
	archive.add_child(case_archive)
	var restoration_archive := make_case_tile("tool", bilingual("RESTORATIONS", "복원 기록"), "%d" % int(statistics.get("restorations", 0)))
	restoration_archive.name = "PostgameRestorationArchive"
	archive.add_child(restoration_archive)
	var sale_archive := make_case_tile("report", bilingual("NEW KEEPERS", "새 소유자"), "%d" % int(statistics.get("sales", 0)))
	sale_archive.name = "PostgameSaleArchive"
	archive.add_child(sale_archive)
	var relationship_compass := make_relationship_compass()
	relationship_compass.visible = not postgame_credits_visible
	body.add_child(relationship_compass)
	var gallery := GridContainer.new()
	gallery.name = "EndingGallery"
	gallery.columns = 5
	gallery.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gallery.add_theme_constant_override("h_separation", 8)
	body.add_child(gallery)
	var ending_order: Array = RuntimeRegistry.campaign.get("endings", []).map(func(ending_value: Variant): return String(ending_value.get("id", "")) if ending_value is Dictionary else "")
	ending_order = ending_order.filter(func(ending_value: Variant): return not String(ending_value).is_empty()).slice(0, 5)
	for ending_index in ending_order.size():
		var gallery_ending_id: String = String(ending_order[ending_index])
		gallery.add_child(make_postgame_ending_card(gallery_ending_id, ending_index, unlocked_endings.has(gallery_ending_id)))
	var actions := HBoxContainer.new()
	actions.name = "PostgameActions"
	actions.add_theme_constant_override("separation", 8)
	body.add_child(actions)
	actions.add_child(make_case_icon_button("support", bilingual("STAGE SELECT", "스테이지 선택"), show_stage_select, "PostgameStageSelect", Vector2(390, 48)))
	actions.add_child(make_case_icon_button("objective", bilingual("NEW GAME", "새 게임"), postgame_new_game_from_ui, "PostgameNewGame", Vector2(390, 48)))
	var credits_button := make_case_icon_button("briefing", bilingual("HIDE CREDITS", "크레딧 닫기") if postgame_credits_visible else bilingual("CREDITS", "크레딧"), toggle_postgame_credits, "PostgameCredits", Vector2(390, 48))
	actions.add_child(credits_button)
	var credits_panel := PanelContainer.new()
	credits_panel.name = "CreditsPanel"
	credits_panel.visible = postgame_credits_visible
	credits_panel.add_theme_stylebox_override("panel", case_panel_style(Color("#11171ae8"), Color("#5d625f")))
	var credits := make_label(text_for("CREDITS"), 13, Color("#b7c4c8"))
	credits.name = "CreditsText"
	credits.max_lines_visible = 2
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_panel.add_child(credits)
	body.add_child(credits_panel)
