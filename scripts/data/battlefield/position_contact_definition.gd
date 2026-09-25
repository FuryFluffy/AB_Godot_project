@tool
class_name PositionContactDefinition
extends Resource


@export_group("First Position")
@export var first_anchor_id: StringName
@export_range(0, 3, 1) var first_position_index: int = 0

@export_group("Second Position")
@export var second_anchor_id: StringName
@export_range(0, 3, 1) var second_position_index: int = 0


func connects(
	first_anchor: StringName,
	first_position: int,
	second_anchor: StringName,
	second_position: int
) -> bool:
	return (
		(
			first_anchor_id == first_anchor
			and first_position_index == first_position
			and second_anchor_id == second_anchor
			and second_position_index == second_position
		)
		or (
			first_anchor_id == second_anchor
			and first_position_index == second_position
			and second_anchor_id == first_anchor
			and second_position_index == first_position
		)
	)


func contains(anchor_id: StringName, position_index: int) -> bool:
	return (
		(first_anchor_id == anchor_id and first_position_index == position_index)
		or (
			second_anchor_id == anchor_id
			and second_position_index == position_index
		)
	)


func get_other_endpoint(
	anchor_id: StringName,
	position_index: int
) -> Dictionary:
	if (
		first_anchor_id == anchor_id
		and first_position_index == position_index
	):
		return {
			"anchor_id": second_anchor_id,
			"position_index": second_position_index,
		}
	if (
		second_anchor_id == anchor_id
		and second_position_index == position_index
	):
		return {
			"anchor_id": first_anchor_id,
			"position_index": first_position_index,
		}
	return {}


func get_stable_key() -> String:
	var first_key := "%s:%d" % [first_anchor_id, first_position_index]
	var second_key := "%s:%d" % [second_anchor_id, second_position_index]
	if first_key <= second_key:
		return "%s|%s" % [first_key, second_key]
	return "%s|%s" % [second_key, first_key]
