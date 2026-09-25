@tool
class_name AuthoredBattleZone
extends Polygon2D


@export_group("BattleZone Identity")
@export var zone_id: StringName
@export var display_name: String = "Unnamed BattleZone"

@export_group("Zone Graph")
@export var connected_zone_ids: Array[StringName] = []

@export_group("Editor Guide")
@export var authoring_color: Color = Color(0.22, 0.66, 0.96, 0.22)


func _ready() -> void:
	color = authoring_color
	visible = Engine.is_editor_hint()
	z_index = -60


func make_definition(
	battlefield_root: Node2D
) -> BattleZoneDefinition:
	var result := BattleZoneDefinition.new()
	result.zone_id = zone_id
	result.display_name = display_name
	result.connected_zone_ids = connected_zone_ids.duplicate()
	var runtime_points: Array[Vector2] = []
	for local_point: Vector2 in polygon:
		runtime_points.append(
			battlefield_root.to_local(to_global(local_point))
		)
	result.polygon_points = runtime_points
	result.map_center = _get_runtime_center(runtime_points)
	return result


func contains_battlefield_point(
	battlefield_root: Node2D,
	point: Vector2
) -> bool:
	if polygon.size() < 3:
		return false
	var local_point: Vector2 = to_local(
		battlefield_root.to_global(point)
	)
	return Geometry2D.is_point_in_polygon(local_point, polygon)


func _get_runtime_center(points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return battlefield_root_position()
	var total := Vector2.ZERO
	for point: Vector2 in points:
		total += point
	return total / float(points.size())


func battlefield_root_position() -> Vector2:
	var root := get_parent().get_parent() as Node2D
	if root == null:
		return position
	return root.to_local(global_position)
