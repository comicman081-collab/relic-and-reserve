extends SceneTree

# This capture is deliberately framebuffer-independent. Godot's CPU SVG loader and
# Image compositor keep it valid under --headless, where the dummy renderer has no
# viewport texture. It reads production SVG/data and writes only PNG QA evidence.

const DATA_PATH := "res://data/characters/characters.json"
const OUTPUT_DIR := "res://qa/character_portraits"
const OUTPUT_PATH := OUTPUT_DIR + "/portrait_contact_sheet.png"
const GRAYSCALE_OUTPUT_PATH := OUTPUT_DIR + "/portrait_contact_sheet_grayscale.png"
const EXPRESSION_OUTPUT_PATH := OUTPUT_DIR + "/portrait_expression_triplets.png"
const SHEET_SIZE := Vector2i(1280, 720)
const CARD_SIZE := Vector2i(190, 204)
const GRID_ORIGIN := Vector2i(25, 65)
const GRID_STEP := Vector2i(205, 214)

const ROLE_COLORS := {
	"AUCTIONEER": Color("#E6B85D"),
	"SHOPKEEPER": Color("#76B99E"),
	"BIDDER": Color("#A995D6"),
	"EVENT": Color("#E48078")
}

const EXPRESSION_REPRESENTATIVES := [
	"auctioneer",
	"shopkeeper",
	"bidder_03",
	"bidder_07",
	"event_courier",
	"event_patron"
]

# Tiny deterministic 5x7 QA font. English display names are taken from the same
# localized profile records that the UI consumes, so all 18 portraits stay labeled
# even when no system font or rendering device is available.
const GLYPHS := {
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
	"C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
	"G": ["01111", "10000", "10000", "10111", "10001", "10001", "01111"],
	"H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
	"I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
	"J": ["00111", "00010", "00010", "00010", "10010", "10010", "01100"],
	"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
	"N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
	"W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
	"X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
	"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
	"Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
	"0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
	"1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
	"2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
	"3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
	"4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
	"5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
	"6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
	"7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
	"8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
	"9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
	"&": ["01100", "10010", "10100", "01000", "10101", "10010", "01101"],
	"-": ["00000", "00000", "00000", "11111", "00000", "00000", "00000"],
	"/": ["00001", "00010", "00010", "00100", "01000", "01000", "10000"],
	"?": ["01110", "10001", "00001", "00010", "00100", "00000", "00100"]
}


func _init() -> void:
	call_deferred("capture")


func fail(message: String) -> void:
	push_error(message)
	quit(1)


func text_width(text: String, scale: int) -> int:
	if text.is_empty():
		return 0
	return (text.length() * 6 - 1) * scale


func draw_text(image: Image, text: String, origin: Vector2i, scale: int, color: Color) -> void:
	var uppercase := text.to_upper()
	for character_index in range(uppercase.length()):
		var character := uppercase.substr(character_index, 1)
		if character == " ":
			continue
		var rows: Array = GLYPHS.get(character, GLYPHS["?"])
		for row_index in range(rows.size()):
			var row := String(rows[row_index])
			for column_index in range(row.length()):
				if row.substr(column_index, 1) != "1":
					continue
				var pixel_origin := origin + Vector2i((character_index * 6 + column_index) * scale, row_index * scale)
				image.fill_rect(Rect2i(pixel_origin, Vector2i(scale, scale)), color)


func draw_centered_text(image: Image, text: String, center_x: int, y: int, scale: int, color: Color) -> void:
	draw_text(image, text, Vector2i(center_x - int(text_width(text, scale) / 2.0), y), scale, color)


func wrap_words(text: String, max_characters: int) -> Array:
	var lines: Array = []
	var current := ""
	for word_variant in text.to_upper().split(" ", false):
		var word := String(word_variant)
		if current.is_empty():
			current = word
		elif current.length() + 1 + word.length() <= max_characters:
			current += " " + word
		else:
			lines.append(current)
			current = word
	if not current.is_empty():
		lines.append(current)
	return lines


func english_name(profile: Dictionary) -> String:
	var display_name: Dictionary = profile.get("displayName", {})
	return String(display_name.get("en", profile.get("characterId", "UNKNOWN")))


func regex_color(svg_source: String, pattern: String, fallback: String) -> String:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return fallback
	var match := regex.search(svg_source)
	if match == null:
		return fallback
	return match.get_string(1)


func expression_svg(svg_source: String, expression: String, geometry: Dictionary) -> String:
	var skin := regex_color(svg_source, "data-part=\"face-shape\" fill=\"(#[0-9A-Fa-f]{6})\"", "#E4AA82")
	var iris := regex_color(svg_source, "data-part=\"iris\" fill=\"(#[0-9A-Fa-f]{6})\"", "#7C6AA4")
	var pupil := regex_color(svg_source, "data-part=\"pupil\" fill=\"(#[0-9A-Fa-f]{6})\"", "#332D38")
	var brow := regex_color(svg_source, "data-part=\"brows\"[^>]*stroke=\"(#[0-9A-Fa-f]{6})\"", "#513C43")
	var mouth := regex_color(svg_source, "data-part=\"mouth\"[^>]*stroke=\"(#[0-9A-Fa-f]{6})\"", "#7A4450")
	var brow_shift := float(geometry.get("browShiftSvg", 0.0))
	var eye_height_shift := float(geometry.get("eyeHeightShiftSvg", 0.0))
	var mouth_shift := float(geometry.get("mouthCornerShiftSvg", 0.0))
	var eye_ry := maxf(6.5, 10.0 + eye_height_shift)
	var eye_cy := 126.0 if expression == "NEGATIVE" else 124.0
	var iris_radius := minf(8.0, eye_ry - 0.5)
	var left_brow := "M90 107q15-8 30 0"
	var right_brow := "M136 107q15-8 30 0"
	if expression == "POSITIVE":
		var brow_y := 107.0 + brow_shift
		left_brow = "M90 %.1fq15-12 30-1" % brow_y
		right_brow = "M136 %.1fq15-11 30 1" % brow_y
	elif expression == "NEGATIVE":
		var outer_y := 107.0 + brow_shift
		var inner_y := 107.0 - brow_shift
		left_brow = "M90 %.1fQ105 %.1f 120 %.1f" % [outer_y, outer_y, inner_y]
		right_brow = "M136 %.1fQ151 %.1f 166 %.1f" % [inner_y, outer_y, outer_y]
	var mouth_corner_y := 170.0 + mouth_shift
	var mouth_center_y := 174.0
	if expression == "POSITIVE":
		mouth_center_y = 185.0
	elif expression == "NEGATIVE":
		mouth_center_y = 158.0
	var overlay := """
  <g data-qa-expression="%s">
    <rect x="84" y="94" width="88" height="20" rx="8" fill="%s"/>
    <rect x="84" y="112" width="88" height="30" rx="10" fill="%s"/>
    <rect x="108" y="158" width="40" height="30" rx="10" fill="%s"/>
    <path fill="none" stroke="%s" stroke-width="3.5" stroke-linecap="round" d="%s"/>
    <path fill="none" stroke="%s" stroke-width="3.5" stroke-linecap="round" d="%s"/>
    <ellipse fill="#FFF9F1" cx="106" cy="%.1f" rx="15" ry="%.1f"/>
    <circle fill="%s" cx="107" cy="%.1f" r="%.1f"/>
    <circle fill="%s" cx="107" cy="%.1f" r="4"/>
    <circle fill="#FFFFFF" cx="104" cy="%.1f" r="2.5"/>
    <ellipse fill="#FFF9F1" cx="150" cy="%.1f" rx="15" ry="%.1f"/>
    <circle fill="%s" cx="149" cy="%.1f" r="%.1f"/>
    <circle fill="%s" cx="149" cy="%.1f" r="4"/>
    <circle fill="#FFFFFF" cx="146" cy="%.1f" r="2.5"/>
    <path fill="#C17260" d="M124 136l-5 14 9 5 8-5-5-14z"/>
    <path fill="none" stroke="%s" stroke-width="3.5" stroke-linecap="round" d="M114 %.1fQ128 %.1f 142 %.1f"/>
  </g>
""" % [
		expression, skin, skin, skin,
		brow, left_brow, brow, right_brow,
		eye_cy, eye_ry, iris, eye_cy + 1.0, iris_radius, pupil, eye_cy + 1.0, eye_cy - 3.0,
		eye_cy, eye_ry, iris, eye_cy + 1.0, iris_radius, pupil, eye_cy + 1.0, eye_cy - 3.0,
		mouth, mouth_corner_y, mouth_center_y, mouth_corner_y
	]
	return svg_source.replace("</svg>", overlay + "</svg>")


func grayscale_copy(source: Image) -> Image:
	var grayscale: Image = source.duplicate()
	for y in range(grayscale.get_height()):
		for x in range(grayscale.get_width()):
			var color: Color = grayscale.get_pixel(x, y)
			var luminance: float = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			grayscale.set_pixel(x, y, Color(luminance, luminance, luminance, color.a))
	return grayscale


func draw_card(sheet: Image, profile: Dictionary, index: int) -> bool:
	var card_position := GRID_ORIGIN + Vector2i(index % 6, int(index / 6)) * GRID_STEP
	var role := String(profile.get("role", ""))
	var accent: Color = ROLE_COLORS.get(role, Color("#D6B960"))
	sheet.fill_rect(Rect2i(card_position, CARD_SIZE), accent)
	sheet.fill_rect(Rect2i(card_position + Vector2i(2, 2), CARD_SIZE - Vector2i(4, 4)), Color("#202936"))
	sheet.fill_rect(Rect2i(card_position + Vector2i(9, 8), Vector2i(172, 4)), accent)

	var portrait_path := String(profile.get("portraitAssetId", ""))
	var svg_source := FileAccess.get_file_as_string(portrait_path)
	if svg_source.is_empty():
		fail("Could not read portrait SVG: %s" % portrait_path)
		return false
	var portrait := Image.new()
	var load_error := portrait.load_svg_from_string(svg_source, 1.0)
	if load_error != OK or portrait.is_empty():
		fail("Godot CPU SVG loader rejected %s: %s" % [portrait_path, error_string(load_error)])
		return false
	portrait.resize(122, 152, Image.INTERPOLATE_LANCZOS)
	sheet.blend_rect(portrait, Rect2i(Vector2i.ZERO, portrait.get_size()), card_position + Vector2i(34, 14))

	var name_lines := wrap_words(english_name(profile), 14)
	if name_lines.size() > 2:
		fail("English portrait label needs more than two lines: %s" % english_name(profile))
		return false
	var first_y := card_position.y + (174 if name_lines.size() == 1 else 166)
	for line_index in range(name_lines.size()):
		draw_centered_text(
			sheet,
			String(name_lines[line_index]),
			card_position.x + int(CARD_SIZE.x / 2.0),
			first_y + line_index * 16,
			2,
			Color("#F7E9C8")
		)
	return true


func draw_expression_card(sheet: Image, profile: Dictionary, expression: String, geometry: Dictionary, column: int, row: int) -> bool:
	var card_position := GRID_ORIGIN + Vector2i(column, row) * GRID_STEP
	var accent := Color("#E6B85D") if expression == "NEUTRAL" else (Color("#76B99E") if expression == "POSITIVE" else Color("#E48078"))
	sheet.fill_rect(Rect2i(card_position, CARD_SIZE), accent)
	sheet.fill_rect(Rect2i(card_position + Vector2i(2, 2), CARD_SIZE - Vector2i(4, 4)), Color("#202936"))
	sheet.fill_rect(Rect2i(card_position + Vector2i(9, 8), Vector2i(172, 4)), accent)
	var portrait_path := String(profile.get("portraitAssetId", ""))
	var svg_source := FileAccess.get_file_as_string(portrait_path)
	if svg_source.is_empty():
		fail("Could not read expression portrait SVG: %s" % portrait_path)
		return false
	var portrait := Image.new()
	var load_error := portrait.load_svg_from_string(expression_svg(svg_source, expression, geometry), 1.0)
	if load_error != OK or portrait.is_empty():
		fail("Expression SVG rejected for %s/%s" % [profile.get("characterId"), expression])
		return false
	portrait.resize(122, 152, Image.INTERPOLATE_LANCZOS)
	sheet.blend_rect(portrait, Rect2i(Vector2i.ZERO, portrait.get_size()), card_position + Vector2i(34, 14))
	draw_centered_text(sheet, english_name(profile), card_position.x + int(CARD_SIZE.x / 2.0), card_position.y + 168, 1, Color("#F7E9C8"))
	draw_centered_text(sheet, expression, card_position.x + int(CARD_SIZE.x / 2.0), card_position.y + 184, 2, accent)
	return true


func build_expression_sheet(profiles: Array, expression_geometry: Dictionary) -> Image:
	var profile_by_id := {}
	for profile_variant in profiles:
		var profile: Dictionary = profile_variant
		profile_by_id[String(profile.get("characterId", ""))] = profile
	var sheet := Image.create_empty(SHEET_SIZE.x, SHEET_SIZE.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#111720"))
	draw_text(sheet, "EXPRESSION GEOMETRY - SIX CHARACTER PROOF", Vector2i(25, 18), 3, Color("#F1D48B"))
	var expressions := ["NEUTRAL", "POSITIVE", "NEGATIVE"]
	for row in range(expressions.size()):
		var expression := String(expressions[row])
		var geometry: Dictionary = expression_geometry.get(expression, {})
		for column in range(EXPRESSION_REPRESENTATIVES.size()):
			var character_id := String(EXPRESSION_REPRESENTATIVES[column])
			if not profile_by_id.has(character_id):
				fail("Missing expression representative: %s" % character_id)
				return sheet
			if not draw_expression_card(sheet, profile_by_id[character_id], expression, geometry, column, row):
				return sheet
	return sheet


func capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var data_file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if data_file == null:
		fail("Could not open character profile data")
		return
	var parsed: Variant = JSON.parse_string(data_file.get_as_text())
	data_file.close()
	if not parsed is Dictionary:
		fail("Character profile data is not a JSON object")
		return
	var profiles: Array = parsed.get("profiles", [])
	if profiles.size() != 18:
		fail("Contact sheet requires exactly 18 profiles; found %d" % profiles.size())
		return

	var sheet := Image.create_empty(SHEET_SIZE.x, SHEET_SIZE.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#111720"))
	draw_text(sheet, "RELIC & RESERVE - CHARACTER ROSTER", Vector2i(25, 18), 3, Color("#F1D48B"))
	var summary := "18 PORTRAITS / 12 BIDDERS / 4 EVENT NPCS"
	draw_text(sheet, summary, Vector2i(1255 - text_width(summary, 2), 24), 2, Color("#A9B7C5"))

	for index in range(profiles.size()):
		if not draw_card(sheet, profiles[index], index):
			return

	var absolute_output := ProjectSettings.globalize_path(OUTPUT_PATH)
	var save_error := sheet.save_png(absolute_output)
	if save_error != OK:
		fail("Could not save portrait contact sheet: %s" % error_string(save_error))
		return
	var grayscale := grayscale_copy(sheet)
	var grayscale_error := grayscale.save_png(ProjectSettings.globalize_path(GRAYSCALE_OUTPUT_PATH))
	if grayscale_error != OK:
		fail("Could not save grayscale portrait contact sheet: %s" % error_string(grayscale_error))
		return
	var expression_geometry: Dictionary = parsed.get("expressionGeometry", {})
	var expression_sheet := build_expression_sheet(profiles, expression_geometry)
	var expression_error := expression_sheet.save_png(ProjectSettings.globalize_path(EXPRESSION_OUTPUT_PATH))
	if expression_error != OK:
		fail("Could not save expression triplet sheet: %s" % error_string(expression_error))
		return
	print("R3_CHARACTER_PORTRAIT_QA_CREATED neutral=%s grayscale=%s expressions=%s size=%s profiles=%d" % [OUTPUT_PATH, GRAYSCALE_OUTPUT_PATH, EXPRESSION_OUTPUT_PATH, sheet.get_size(), profiles.size()])
	quit(0)
