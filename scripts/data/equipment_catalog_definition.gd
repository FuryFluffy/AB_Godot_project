class_name EquipmentCatalogDefinition
extends Resource


@export var equipment: Array[EquipmentDefinition] = []


func get_equipment(equipment_id: StringName) -> EquipmentDefinition:
	for definition: EquipmentDefinition in equipment:
		if definition != null and definition.equipment_id == equipment_id:
			return definition
	return null


func make_registry() -> Dictionary:
	var result: Dictionary = {}
	for definition: EquipmentDefinition in equipment:
		if definition != null:
			result[definition.equipment_id] = definition
	return result


func validate_catalog(material_catalog: MaterialCatalogDefinition) -> String:
	if material_catalog == null:
		return "Equipment catalog validation requires the Material catalog."
	var material_error: String = material_catalog.validate_catalog()
	if not material_error.is_empty():
		return material_error
	var seen_ids: Dictionary = {}
	for definition: EquipmentDefinition in equipment:
		if definition == null:
			return "The Equipment catalog contains an empty entry."
		var definition_error: String = definition.validate_definition()
		if not definition_error.is_empty():
			return definition_error
		if seen_ids.has(definition.equipment_id):
			return "Duplicate Equipment Stable ID: %s." % definition.equipment_id
		seen_ids[definition.equipment_id] = true
		if (
			definition.destructible
			and material_catalog.get_material(definition.salvage_material_id) == null
		):
			return "Equipment '%s' references an unknown salvage Material '%s'." % [
				definition.equipment_id,
				definition.salvage_material_id,
			]
	return ""
