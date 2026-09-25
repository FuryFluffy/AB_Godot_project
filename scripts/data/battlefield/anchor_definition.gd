class_name AnchorDefinition
extends Resource


const INHERIT_VISUAL_ORDER: int = -1000
const INHERIT_BATTLER_SCALE: float = -1.0


@export_group("Identity")
@export var anchor_id: StringName
@export var display_name: String = "Unnamed Anchor"
@export var zone_id: StringName

@export_group("Authored Graph")
@export var connected_anchor_ids: Array[StringName] = []

@export_group("Occupancy Positions")
@export_enum("Restricted:2", "Standard:4") var capacity: int = 4
@export var position_points: Array[Vector2] = []
@export var position_battler_scales: Array[float] = []
@export var position_visual_orders: Array[int] = []

@export_group("Engagement Area")
@export var engagement_area_points: Array[Vector2] = []

@export_group("Battler Presentation")
@export_range(0.1, 3.0, 0.01) var battler_scale: float = 1.0
@export var visual_order: int = 0
@export var visual_depth_band: StringName = &"midground"
@export var visual_orientation: StringName = &"front"
@export var bounded_y_sort_within_band: bool = true


func get_position_point(
	position_index: int
) -> Vector2:
	if (
		position_index < 0
		or position_index >= capacity
		or position_index >= position_points.size()
	):
		return Vector2.ZERO

	return position_points[position_index]


func get_position_visual_order(position_index: int) -> int:
	if (
		position_index >= 0
		and position_index < position_visual_orders.size()
		and position_visual_orders[position_index] != INHERIT_VISUAL_ORDER
	):
		return position_visual_orders[position_index]
	return visual_order


func get_position_battler_scale(position_index: int) -> float:
	if (
		position_index >= 0
		and position_index < position_battler_scales.size()
		and position_battler_scales[position_index]
		!= INHERIT_BATTLER_SCALE
	):
		return position_battler_scales[position_index]
	return battler_scale


func has_position_visual_order_override(position_index: int) -> bool:
	return (
		position_index >= 0
		and position_index < position_visual_orders.size()
		and position_visual_orders[position_index] != INHERIT_VISUAL_ORDER
	)


func get_center() -> Vector2:
	if capacity <= 0 or position_points.is_empty():
		return Vector2.ZERO

	var total: Vector2 = Vector2.ZERO
	var counted_positions: int = mini(
		capacity,
		position_points.size()
	)

	for position_index: int in range(counted_positions):
		total += position_points[position_index]

	return total / float(counted_positions)


func get_engagement_polygon() -> PackedVector2Array:
	if engagement_area_points.size() >= 3:
		return PackedVector2Array(engagement_area_points)

	# Historical fixtures do not contain authored area polygons. Keep them
	# usable by deriving a quiet rectangular hit area from their Positions.
	if position_points.is_empty():
		var centre := get_center()
		return PackedVector2Array([
			centre + Vector2(-76.0, -56.0),
			centre + Vector2(76.0, -56.0),
			centre + Vector2(76.0, 56.0),
			centre + Vector2(-76.0, 56.0),
		])

	var minimum := position_points[0]
	var maximum := position_points[0]
	for point: Vector2 in position_points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	var padding := Vector2(42.0, 36.0)
	minimum -= padding
	maximum += padding
	return PackedVector2Array([
		Vector2(minimum.x, minimum.y),
		Vector2(maximum.x, minimum.y),
		Vector2(maximum.x, maximum.y),
		Vector2(minimum.x, maximum.y),
	])


func contains_engagement_point(point: Vector2) -> bool:
	var polygon := get_engagement_polygon()
	return (
		polygon.size() >= 3
		and Geometry2D.is_point_in_polygon(point, polygon)
	)
