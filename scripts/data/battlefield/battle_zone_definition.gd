class_name BattleZoneDefinition
extends Resource


@export_group("Identity")
@export var zone_id: StringName
@export var display_name: String = "Unnamed BattleZone"

@export_group("Authored Graph")
@export var connected_zone_ids: Array[StringName] = []

@export_group("Debug Presentation")
@export var map_center: Vector2 = Vector2.ZERO
@export var polygon_points: Array[Vector2] = []


func contains_point(point: Vector2) -> bool:
	if polygon_points.size() < 3:
		return point.distance_to(map_center) <= 118.0
	return Geometry2D.is_point_in_polygon(
		point,
		PackedVector2Array(polygon_points)
	)
