class_name EquipmentInstance
extends RefCounted


signal condition_changed


var instance_id: StringName
var definition_id: StringName
var current_condition: int = 0
var definition: EquipmentDefinition


func _init(
	source_instance_id: StringName = &"",
	source_definition: EquipmentDefinition = null,
	source_condition: int = -1
) -> void:
	if source_definition != null:
		initialize(source_instance_id, source_definition, source_condition)


func initialize(
	source_instance_id: StringName,
	source_definition: EquipmentDefinition,
	source_condition: int = -1
) -> String:
	if source_instance_id == &"":
		return "Equipment instance requires a deterministic instance ID."
	if source_definition == null:
		return "Equipment instance '%s' requires a definition." % source_instance_id
	var definition_error: String = source_definition.validate_definition()
	if not definition_error.is_empty():
		return definition_error
	var next_condition: int = source_condition
	if next_condition < 0:
		next_condition = source_definition.condition_maximum
	instance_id = source_instance_id
	definition_id = source_definition.equipment_id
	definition = source_definition
	current_condition = clampi(
		next_condition,
		0,
		source_definition.condition_maximum
	)
	condition_changed.emit()
	return ""


func is_broken() -> bool:
	return definition != null and current_condition <= 0


func apply_condition_damage(amount: int) -> String:
	if amount <= 0:
		return "Equipment condition damage must be positive."
	if definition == null:
		return "Equipment instance '%s' has no definition." % instance_id
	var next_condition: int = maxi(current_condition - amount, 0)
	if next_condition == current_condition:
		return ""
	current_condition = next_condition
	condition_changed.emit()
	return ""


func repair_condition(amount: int) -> String:
	if amount <= 0:
		return "Equipment condition repair must be positive."
	if definition == null:
		return "Equipment instance '%s' has no definition." % instance_id
	var next_condition: int = mini(
		current_condition + amount,
		definition.condition_maximum
	)
	if next_condition == current_condition:
		return ""
	current_condition = next_condition
	condition_changed.emit()
	return ""


func set_condition_clamped(value: int) -> void:
	if definition == null:
		return
	var next_condition: int = clampi(value, 0, definition.condition_maximum)
	if next_condition == current_condition:
		return
	current_condition = next_condition
	condition_changed.emit()


func get_effective_positive_effect_ids() -> Array[StringName]:
	if definition == null or is_broken():
		return []
	return definition.authored_positive_effect_ids.duplicate()


func get_effective_negative_effect_ids() -> Array[StringName]:
	if definition == null:
		return []
	return definition.authored_negative_effect_ids.duplicate()


func to_snapshot() -> Dictionary:
	return {
		"instance_id": String(instance_id),
		"definition_id": String(definition_id),
		"current_condition": current_condition,
	}


func restore_from_snapshot(
	snapshot: Dictionary,
	definitions_by_id: Dictionary
) -> String:
	var stored_instance_value: Variant = snapshot.get("instance_id", null)
	var stored_definition_value: Variant = snapshot.get("definition_id", null)
	var stored_condition_value: Variant = snapshot.get("current_condition", null)
	if not (stored_instance_value is String or stored_instance_value is StringName):
		return "Equipment snapshot requires a string instance_id."
	if not (stored_definition_value is String or stored_definition_value is StringName):
		return "Equipment snapshot requires a string definition_id."
	if not _is_integer_value(stored_condition_value):
		return "Equipment snapshot requires integer current_condition."
	var stored_instance_id := StringName(stored_instance_value)
	var stored_definition_id := StringName(stored_definition_value)
	if stored_instance_id == &"" or stored_definition_id == &"":
		return "Equipment snapshot identity cannot be empty."
	var source_definition: EquipmentDefinition = definitions_by_id.get(
		stored_definition_id,
		definitions_by_id.get(String(stored_definition_id), null)
	) as EquipmentDefinition
	if source_definition == null:
		return "Equipment snapshot references unknown definition '%s'." % stored_definition_id
	var stored_condition: int = int(stored_condition_value)
	if stored_condition < 0 or stored_condition > source_definition.condition_maximum:
		return "Equipment snapshot current_condition is outside its authored range."
	return initialize(
		stored_instance_id,
		source_definition,
		stored_condition
	)


func _is_integer_value(value: Variant) -> bool:
	return (
		typeof(value) == TYPE_INT
		or (
			typeof(value) == TYPE_FLOAT
			and float(value) == floorf(float(value))
		)
	)
