class_name ShieldDefinition
extends EquipmentDefinition


enum Type {
	SMALL,
	REGULAR,
	HEAVY,
}


@export_group("Shield Type")
@export var shield_type: Type = Type.REGULAR


func validate_definition() -> String:
	var definition_error: String = super.validate_definition()
	if not definition_error.is_empty():
		return definition_error
	if allowed_slots != [Slot.OFF_HAND]:
		return "Shield '%s' must explicitly allow only the Off Hand slot." % equipment_id
	if condition_maximum != get_safe_absorption_limit() + 1:
		return "Shield '%s' condition must preserve its authored breaking point." % equipment_id
	return ""


func get_safe_absorption_limit() -> int:
	match shield_type:
		Type.SMALL:
			return 0
		Type.REGULAR:
			return 2
		Type.HEAVY:
			return 3

	push_error("Unknown shield type: %s" % shield_type)
	return 0


func get_dodge_dice_modifier() -> int:
	match shield_type:
		Type.SMALL:
			return 0
		Type.REGULAR:
			return -1
		Type.HEAVY:
			return -2

	push_error("Unknown shield type: %s" % shield_type)
	return 0


func get_parry_dice_modifier() -> int:
	if shield_type == Type.SMALL:
		return 1

	return 0


func can_absorb_damage() -> bool:
	return get_safe_absorption_limit() > 0


func get_protection_type() -> ProtectionProficiencyEntry.Type:
	return ProtectionProficiencyEntry.Type.SHIELD
