class_name RefugeRoomHotspot
extends Button
## A focusable authored silhouette; texture padding is never a hit target.

var polygon := PackedVector2Array()
var station_id: StringName
var hovered: bool = false


func configure(station: Dictionary) -> void:
	station_id = StringName(station.id)
	name = String(station_id)
	var bounds := Rect2(Vector2(station.polygon[0][0], station.polygon[0][1]), Vector2.ZERO)
	for point: Array in station.polygon:
		bounds = bounds.expand(Vector2(point[0], point[1]))
	position = bounds.position
	size = bounds.size
	for point: Array in station.polygon:
		polygon.append(Vector2(point[0], point[1]) - position)
	tooltip_text = String(station.name)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for style: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	mouse_entered.connect(func() -> void: hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: hovered = false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, polygon)


func _draw() -> void:
	if disabled or not (hovered or has_focus()) or polygon.is_empty():
		return
	draw_colored_polygon(polygon, Color(1.0, 0.75, 0.36, 0.12))
	var outline := polygon.duplicate()
	outline.append(polygon[0])
	draw_polyline(outline, Color(1.0, 0.80, 0.46, 0.85), 1.6, true)
