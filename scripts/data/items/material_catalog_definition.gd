class_name MaterialCatalogDefinition
extends Resource


@export var materials: Array[MaterialDefinition] = []


func get_material(material_id: StringName) -> MaterialDefinition:
	for material: MaterialDefinition in materials:
		if material != null and material.item_id == material_id:
			return material
	return null


func validate_catalog() -> String:
	var seen_ids: Dictionary = {}
	for material: MaterialDefinition in materials:
		if material == null:
			return "The Material catalog contains an empty entry."
		var definition_error: String = material.validate_definition()
		if not definition_error.is_empty():
			return definition_error
		if seen_ids.has(material.item_id):
			return "Duplicate Material Stable ID: %s." % material.item_id
		seen_ids[material.item_id] = true
	return ""


func validate_references(
	equipment_catalog: EquipmentCatalogDefinition,
	recipe_catalog: RefugeRecipeCatalogDefinition
) -> String:
	var validation_error: String = validate_catalog()
	if not validation_error.is_empty():
		return validation_error
	if equipment_catalog == null or recipe_catalog == null:
		return "Material reference validation requires equipment and recipe catalogs."
	var referenced_ids: Dictionary = {}
	for definition: EquipmentDefinition in equipment_catalog.equipment:
		if definition != null and definition.destructible:
			referenced_ids[definition.salvage_material_id] = true
	for recipe: RefugeRecipeDefinition in recipe_catalog.recipes:
		if recipe == null:
			continue
		for material_value: Variant in recipe.material_inputs.keys():
			referenced_ids[StringName(material_value)] = true
	for material: MaterialDefinition in materials:
		if not referenced_ids.has(material.item_id):
			return "Executable Material '%s' has no salvage or recipe reference." % material.item_id
	return ""
