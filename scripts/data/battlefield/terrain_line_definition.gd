class_name TerrainLineDefinition
extends Resource


@export_group("Identity")
@export var terrain_id: StringName
@export var display_name: String = "Unnamed Terrain Line"

@export_group("Authored Ray Blocker")
@export var start_point: Vector2 = Vector2.ZERO
@export var end_point: Vector2 = Vector2.ZERO

@export_group("Rules")
@export var blocks_line_of_sight: bool = false
@export var provides_ranged_cover: bool = false


func is_meaningful() -> bool:
	return (
		start_point.distance_squared_to(end_point)
		> 0.001
		and (
			blocks_line_of_sight
			or provides_ranged_cover
		)
	)
