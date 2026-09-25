class_name ArmorDefinition
extends EquipmentDefinition


enum Type {
	CLOTH,
	LEATHER,
	CHAIN,
	PLATE,
}


@export_group("Armor Type")
@export var armor_type: Type = Type.CLOTH


func validate_definition() -> String:
	var definition_error: String = super.validate_definition()
	if not definition_error.is_empty():
		return definition_error
	if allowed_slots != [Slot.ARMOR]:
		return "Armor '%s' must explicitly allow only the Armor slot." % equipment_id
	if condition_maximum != get_safe_absorption_limit() + 1:
		return "Armor '%s' condition must preserve its authored breaking point." % equipment_id
	return ""


func get_safe_absorption_limit() -> int:
	match armor_type:
		Type.CLOTH:
			return 1
		Type.LEATHER:
			return 2
		Type.CHAIN:
			return 3
		Type.PLATE:
			return 4

	push_error("Unknown armor type: %s" % armor_type)
	return 0


func get_dodge_dice_modifier() -> int:
	match armor_type:
		Type.CLOTH:
			return 2
		Type.LEATHER:
			return 1
		Type.CHAIN:
			return -1
		Type.PLATE:
			return -2

	push_error("Unknown armor type: %s" % armor_type)
	return 0


func get_protection_type() -> ProtectionProficiencyEntry.Type:
	match armor_type:
		Type.CLOTH:
			return ProtectionProficiencyEntry.Type.CLOTH

		Type.LEATHER:
			return ProtectionProficiencyEntry.Type.LEATHER

		Type.CHAIN:
			return ProtectionProficiencyEntry.Type.CHAIN

		Type.PLATE:
			return ProtectionProficiencyEntry.Type.PLATE

	push_error(
		"Unknown armor type: %s"
		% armor_type
	)

	return ProtectionProficiencyEntry.Type.CLOTH
