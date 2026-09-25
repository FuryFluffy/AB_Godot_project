class_name EquipmentLoadout
extends Resource


enum DamageAllocationPolicy {
	ARMOR_FIRST,
	SHIELD_FIRST,
}


@export_group("Weapons")
@export var main_hand: WeaponDefinition
@export_range(1, 3, 1) var main_hand_family_rank: int = 1
@export var off_hand: EquipmentDefinition

@export_group("Protection")
@export var armor: ArmorDefinition
var shield: ShieldDefinition:
	get:
		return off_hand as ShieldDefinition
	set(value):
		off_hand = value

@export_group("Damage Allocation")
@export var default_damage_allocation_policy: DamageAllocationPolicy = (
	DamageAllocationPolicy.ARMOR_FIRST
)


func validate_definition() -> String:
	for slot: EquipmentDefinition.Slot in [
		EquipmentDefinition.Slot.MAIN_HAND,
		EquipmentDefinition.Slot.OFF_HAND,
		EquipmentDefinition.Slot.ARMOR,
	]:
		var definition: EquipmentDefinition = get_equipment(slot)
		if definition == null:
			continue
		var definition_error: String = definition.validate_definition()
		if not definition_error.is_empty():
			return definition_error
		if not definition.allows_slot(slot):
			return "Equipment '%s' is incompatible with authored %s." % [
				definition.equipment_id,
				EquipmentDefinition.get_slot_label(slot),
			]
	if (
		main_hand != null
		and off_hand != null
		and main_hand.equipment_id == off_hand.equipment_id
	):
		return "An authored loadout cannot assign one definition to both hands."
	return ""


func get_equipment(slot: EquipmentDefinition.Slot) -> EquipmentDefinition:
	match slot:
		EquipmentDefinition.Slot.MAIN_HAND:
			return main_hand
		EquipmentDefinition.Slot.OFF_HAND:
			return off_hand
		EquipmentDefinition.Slot.ARMOR:
			return armor
	return null


func get_all_equipment() -> Array[EquipmentDefinition]:
	var result: Array[EquipmentDefinition] = []
	for definition: EquipmentDefinition in [main_hand, off_hand, armor]:
		if definition != null:
			result.append(definition)
	return result
