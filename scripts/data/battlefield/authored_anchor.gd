@tool
class_name AuthoredAnchor
extends Polygon2D


const BORDER_COLOR := Color(0.28, 0.78, 0.76, 0.82)
const LABEL_COLOR := Color(0.90, 1.0, 0.97, 0.96)


@export_group("Anchor Identity")
@export var anchor_id: StringName
@export var display_name: String = "Unnamed Anchor"
@export var zone_id: StringName

@export_group("Anchor Graph")
@export var connected_anchor_ids: Array[StringName] = []

@export_group("Occupancy")
@export_enum("Restricted:2", "Standard:4") var capacity: int = 4

@export_group("Engagement Area Guide")
@export var authoring_color: Color = Color(0.28, 0.78, 0.76, 0.14)
@export var show_authoring_label: bool = true

@export_group("Battler Presentation")
@export_range(0.1, 3.0, 0.01) var battler_scale: float = 1.0
@export var visual_order: int = 0
@export var visual_depth_band: StringName = &"midground"
@export var visual_orientation: StringName = &"front"
@export var bounded_y_sort_within_band: bool = true


func _ready() -> void:
	color = authoring_color
	visible = Engine.is_editor_hint()
	z_index = -40
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func get_position_nodes() -> Array[AuthoredPosition]:
	var positions: Array[AuthoredPosition] = []
	for child: Node in get_children():
		if child is AuthoredPosition:
			positions.append(child as AuthoredPosition)
	positions.sort_custom(
		func(first: AuthoredPosition, second: AuthoredPosition) -> bool:
			return first.position_index < second.position_index
	)
	return positions


func make_definition(
	battlefield_root: Node2D
) -> AnchorDefinition:
	var result := AnchorDefinition.new()
	result.anchor_id = anchor_id
	result.display_name = display_name
	result.zone_id = zone_id
	result.connected_anchor_ids = connected_anchor_ids.duplicate()
	result.capacity = capacity
	result.battler_scale = battler_scale
	result.visual_order = visual_order
	result.visual_depth_band = visual_depth_band
	result.visual_orientation = visual_orientation
	result.bounded_y_sort_within_band = bounded_y_sort_within_band
	var runtime_area_points: Array[Vector2] = []
	for local_point: Vector2 in polygon:
		runtime_area_points.append(
			battlefield_root.to_local(to_global(local_point))
		)
	result.engagement_area_points = runtime_area_points
	var runtime_points: Array[Vector2] = []
	var runtime_battler_scales: Array[float] = []
	var runtime_visual_orders: Array[int] = []
	for position_node: AuthoredPosition in get_position_nodes():
		runtime_points.append(
			battlefield_root.to_local(position_node.global_position)
		)
		runtime_battler_scales.append(
			(
				AnchorDefinition.INHERIT_BATTLER_SCALE
				if position_node.use_anchor_battler_scale
				else position_node.battler_scale
			)
		)
		runtime_visual_orders.append(
			(
				AnchorDefinition.INHERIT_VISUAL_ORDER
				if position_node.use_anchor_visual_order
				else position_node.battler_visual_order
			)
		)
	result.position_points = runtime_points
	result.position_battler_scales = runtime_battler_scales
	result.position_visual_orders = runtime_visual_orders
	return result


func get_battlefield_position(
	battlefield_root: Node2D
) -> Vector2:
	var positions := get_position_nodes()
	if positions.is_empty():
		return battlefield_root.to_local(global_position)
	var total := Vector2.ZERO
	for position_node: AuthoredPosition in positions:
		total += battlefield_root.to_local(position_node.global_position)
	return total / float(positions.size())


func contains_battlefield_point(
	battlefield_root: Node2D,
	point: Vector2
) -> bool:
	if polygon.size() < 3:
		return false
	var local_point := to_local(battlefield_root.to_global(point))
	return Geometry2D.is_point_in_polygon(local_point, polygon)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if polygon.size() >= 3:
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, BORDER_COLOR, 3.0, true)
	if not show_authoring_label:
		return
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-100.0, -14.0),
		"%s  [%s]" % [display_name, anchor_id],
		HORIZONTAL_ALIGNMENT_CENTER,
		200.0,
		14,
		LABEL_COLOR
	)
