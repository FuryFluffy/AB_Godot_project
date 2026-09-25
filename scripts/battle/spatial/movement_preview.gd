class_name MovementPreview
extends RefCounted


var is_valid: bool = false
var error_message: String = ""

var mover_id: StringName
var anchor_path: Array[StringName] = []
var destination_anchor_id: StringName
var available_destination_positions: Array[int] = []

var hostile_step_anchor_ids: Array[StringName] = []
var threat_battler_ids: Array[StringName] = []
var threat_battler_ids_by_destination_position: Dictionary = {}


func get_step_count() -> int:
	return maxi(anchor_path.size() - 1, 0)


func get_threat_battler_ids_for_position(
	position_index: int
) -> Array[StringName]:
	var result: Array[StringName] = []
	var stored: Variant = threat_battler_ids_by_destination_position.get(
		position_index,
		[]
	)
	if stored is Array:
		for battler_id: Variant in stored:
			result.append(StringName(battler_id))
	result.sort()
	return result


func is_destination_position_threatened(position_index: int) -> bool:
	return not get_threat_battler_ids_for_position(position_index).is_empty()


func get_route_label(
	battlefield: BattlefieldDefinition
) -> String:
	if battlefield == null or anchor_path.is_empty():
		return "Invalid route"

	var anchor_names: Array[String] = []

	for anchor_id: StringName in anchor_path:
		var anchor: AnchorDefinition = battlefield.get_anchor(
			anchor_id
		)
		anchor_names.append(
			anchor.display_name
			if anchor != null
			else String(anchor_id)
		)

	var prefix: String = (
		"Reposition"
		if get_step_count() == 0
		else "%d step%s" % [
			get_step_count(),
			"" if get_step_count() == 1 else "s",
		]
	)

	return "%s: %s" % [
		prefix,
		" → ".join(PackedStringArray(anchor_names)),
	]
