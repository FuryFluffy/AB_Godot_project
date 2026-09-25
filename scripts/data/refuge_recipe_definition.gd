class_name RefugeRecipeDefinition
extends Resource


enum Action {
	REPAIR_EQUIPMENT,
}


enum EquipmentTarget {
	ANY,
	WEAPON,
	ARMOR,
	SHIELD,
}


@export_group("Identity")
@export var recipe_id: StringName
@export var display_name: String = "Unnamed Refuge Service"

@export_group("Inputs")
@export var material_inputs: Dictionary = {}

@export_group("Result")
@export var action: Action = Action.REPAIR_EQUIPMENT
@export var equipment_target: EquipmentTarget = EquipmentTarget.ANY
@export_range(1, 99, 1) var condition_restore_amount: int = 1


func validate_definition(material_catalog: MaterialCatalogDefinition) -> String:
	if recipe_id == &"":
		return "A Refuge recipe requires a Stable ID."
	if display_name.strip_edges().is_empty():
		return "Refuge recipe '%s' requires a display name." % recipe_id
	if material_catalog == null:
		return "Refuge recipe '%s' requires the Material catalog." % recipe_id
	if material_inputs.is_empty():
		return "Refuge recipe '%s' requires at least one Material input." % recipe_id
	for material_value: Variant in material_inputs.keys():
		if not (material_value is String or material_value is StringName):
			return "Refuge recipe '%s' contains a non-string Material ID." % recipe_id
		var material_id := StringName(material_value)
		if material_catalog.get_material(material_id) == null:
			return "Refuge recipe '%s' references unknown Material '%s'." % [
				recipe_id,
				material_id,
			]
		var quantity_value: Variant = material_inputs[material_value]
		if typeof(quantity_value) != TYPE_INT or int(quantity_value) <= 0:
			return "Refuge recipe '%s' requires positive integer inputs." % recipe_id
	if action != Action.REPAIR_EQUIPMENT:
		return "Refuge recipe '%s' has an unsupported action." % recipe_id
	if equipment_target < EquipmentTarget.ANY or equipment_target > EquipmentTarget.SHIELD:
		return "Refuge recipe '%s' has an invalid equipment target." % recipe_id
	if condition_restore_amount <= 0:
		return "Refuge recipe '%s' requires positive condition restoration." % recipe_id
	return ""


func accepts_target(definition: EquipmentDefinition) -> bool:
	if definition == null:
		return false
	match equipment_target:
		EquipmentTarget.ANY:
			return true
		EquipmentTarget.WEAPON:
			return definition is WeaponDefinition
		EquipmentTarget.ARMOR:
			return definition is ArmorDefinition
		EquipmentTarget.SHIELD:
			return definition is ShieldDefinition
	return false
