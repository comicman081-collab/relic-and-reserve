extends Control

const PORTRAIT_VIEWBOX := Vector2(256.0, 320.0)

var expression := "NEUTRAL"
var accent := Color("#e3c681")
var expression_geometry: Dictionary = {}
var face_render: Dictionary = {}
var face_anchor_svg := Vector2(128.0, 136.0)
var face_zone_svg := Rect2(74.0, 58.0, 108.0, 138.0)
var drawing_mode := "PORTRAIT_FACE_GEOMETRY"


func configure(expression_value: String, accent_value: Color, geometry_value: Dictionary = {}, face_render_value: Dictionary = {}) -> void:
	expression = expression_value.to_upper()
	accent = accent_value
	expression_geometry = geometry_value.duplicate(true)
	face_render = face_render_value.duplicate(true)
	var anchor_values: Array = face_render.get("faceAnchor", [128.0, 136.0])
	if anchor_values.size() == 2:
		face_anchor_svg = Vector2(float(anchor_values[0]), float(anchor_values[1]))
	var zone_values: Array = face_render.get("faceZone", [74.0, 58.0, 108.0, 138.0])
	if zone_values.size() == 4:
		face_zone_svg = Rect2(float(zone_values[0]), float(zone_values[1]), float(zone_values[2]), float(zone_values[3]))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func portrait_scale(display_size: Vector2 = size) -> float:
	if display_size.x <= 0.0 or display_size.y <= 0.0:
		return 0.0
	return minf(display_size.x / PORTRAIT_VIEWBOX.x, display_size.y / PORTRAIT_VIEWBOX.y)


func portrait_origin(display_size: Vector2 = size) -> Vector2:
	var scale_value := portrait_scale(display_size)
	return (display_size - PORTRAIT_VIEWBOX * scale_value) * 0.5


func svg_to_control(svg_point: Vector2, display_size: Vector2 = size) -> Vector2:
	return portrait_origin(display_size) + svg_point * portrait_scale(display_size)


func face_rect_for_size(display_size: Vector2 = size) -> Rect2:
	var scale_value := portrait_scale(display_size)
	return Rect2(portrait_origin(display_size) + face_zone_svg.position * scale_value, face_zone_svg.size * scale_value)


func ellipse_points(center: Vector2, radius_x: float, radius_y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


func draw_filled_ellipse(center_svg: Vector2, radius_svg: Vector2, fill: Color, outline: Color = Color.TRANSPARENT, outline_width_svg: float = 0.0) -> void:
	var scale_value := portrait_scale()
	var points := ellipse_points(svg_to_control(center_svg), radius_svg.x * scale_value, radius_svg.y * scale_value)
	draw_colored_polygon(points, fill)
	if outline_width_svg > 0.0 and outline.a > 0.0:
		draw_polyline(points, outline, outline_width_svg * scale_value, true)


func face_color(key: String, fallback: String) -> Color:
	return Color(String(face_render.get(key, fallback)))


func _draw() -> void:
	var scale_value := portrait_scale()
	if scale_value <= 0.0:
		return
	var skin := face_color("skinColor", "#efb287")
	var ink := face_color("inkColor", "#69404a")
	var sclera := face_color("scleraColor", "#fff9f1")
	var iris := face_color("irisColor", accent.to_html())
	var pupil := face_color("pupilColor", "#352a2d")
	var brow_shift := float(expression_geometry.get("browShiftSvg", 0.0))
	var eye_height_shift := float(expression_geometry.get("eyeHeightShiftSvg", 0.0))
	var mouth_corner_shift := float(expression_geometry.get("mouthCornerShiftSvg", 0.0))
	var eye_y := face_anchor_svg.y - 13.0
	var eye_left := Vector2(face_anchor_svg.x - 22.0, eye_y)
	var eye_right := Vector2(face_anchor_svg.x + 22.0, eye_y)
	var left_eye_values: Array = face_render.get("leftEye", [])
	var right_eye_values: Array = face_render.get("rightEye", [])
	if left_eye_values.size() >= 2:
		eye_left = Vector2(float(left_eye_values[0]), float(left_eye_values[1]))
	if right_eye_values.size() >= 2:
		eye_right = Vector2(float(right_eye_values[0]), float(right_eye_values[1]))

	# Replace the neutral base features inside the normalized face zone so the
	# actual portrait face, not a corner badge, carries the semantic expression.
	draw_filled_ellipse(Vector2(eye_left.x, eye_left.y - 18.0), Vector2(20.0, 10.0), skin)
	draw_filled_ellipse(Vector2(eye_right.x, eye_right.y - 18.0), Vector2(20.0, 10.0), skin)
	draw_filled_ellipse(eye_left, Vector2(18.5, 12.5), skin)
	draw_filled_ellipse(eye_right, Vector2(18.5, 12.5), skin)
	draw_filled_ellipse(Vector2(face_anchor_svg.x, face_anchor_svg.y + 33.0), Vector2(20.0, 16.0), skin)

	var brow_y := eye_y - 18.0 + brow_shift
	var brow_tilt := clampf(mouth_corner_shift * 0.4, -2.5, 2.5)
	var left_brow := PackedVector2Array([
		svg_to_control(Vector2(eye_left.x - 15.0, brow_y - brow_tilt)),
		svg_to_control(Vector2(eye_left.x, brow_y - 2.0)),
		svg_to_control(Vector2(eye_left.x + 15.0, brow_y + brow_tilt))
	])
	var right_brow := PackedVector2Array([
		svg_to_control(Vector2(eye_right.x - 15.0, brow_y + brow_tilt)),
		svg_to_control(Vector2(eye_right.x, brow_y - 2.0)),
		svg_to_control(Vector2(eye_right.x + 15.0, brow_y - brow_tilt))
	])
	draw_polyline(left_brow, ink, 3.5 * scale_value, true)
	draw_polyline(right_brow, ink, 3.5 * scale_value, true)

	var eye_radius_y := maxf(5.5, 10.0 + eye_height_shift)
	for eye_center: Vector2 in [eye_left, eye_right]:
		draw_filled_ellipse(eye_center, Vector2(15.0, eye_radius_y), sclera, ink, 1.2)
		draw_filled_ellipse(eye_center + Vector2(0.0, 1.0), Vector2(8.0, minf(8.0, eye_radius_y - 1.0)), iris)
		draw_filled_ellipse(eye_center + Vector2(0.0, 1.0), Vector2(4.2, 4.2), pupil)
		draw_filled_ellipse(eye_center + Vector2(-3.0, -3.0), Vector2(2.4, 2.4), Color.WHITE)

	var mouth_y := face_anchor_svg.y + 33.0
	var mouth_center_curve := 0.0
	if expression == "POSITIVE":
		mouth_center_curve = 7.0
	elif expression == "NEGATIVE":
		mouth_center_curve = -7.0
	var mouth_points := PackedVector2Array([
		svg_to_control(Vector2(face_anchor_svg.x - 14.0, mouth_y + mouth_corner_shift)),
		svg_to_control(Vector2(face_anchor_svg.x, mouth_y + mouth_center_curve)),
		svg_to_control(Vector2(face_anchor_svg.x + 14.0, mouth_y + mouth_corner_shift))
	])
	draw_polyline(mouth_points, ink, 3.5 * scale_value, true)
