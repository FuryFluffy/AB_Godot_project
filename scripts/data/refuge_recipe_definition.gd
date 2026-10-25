class_name RefugeRecipeDefinition
extends Resource


enum Action {
	REPAIR_EQUIPMENT,
	PRODUCE_ITEM,
}


enum Station { WORKBENCH, ALCHEMY, CRAFTING }


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
@export var station: Station = Station.WORKBENCH
@export var output_item_id: StringName
@export_range(1, 999, 1) var output_quantity: int = 1
@export var equipment_target: EquipmentTarget = EquipmentTarget.ANY
@export_range(1, 99, 1) var condition_restore_amount: int = 1


func validate_definition(material_catalog: MaterialCatalogDefinition, item_catalog: ItemCatalogDefinition = null) -> String:
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
	if action == Action.PRODUCE_ITEM:
		if station not in [Station.ALCHEMY, Station.CRAFTING]:
			return "Production requires an Alchemy or Crafting station."
		var output: ItemDefinition = null if item_catalog == null else item_catalog.get_item(output_item_id)
		if output == null or not output.canonical_workbook_item or output.content_category != ItemDefinition.ContentCategory.ACTIVE:
			return "Production output must be a canonical ordinary active item."
		if output_quantity <= 0 or output.stack_limit <= 0:
			return "Production requires a positive output quantity and stack limit."
		return ""
	if action != Action.REPAIR_EQUIPMENT:
		return "Refuge recipe '%s' has an unsupported action." % recipe_id
	if station != Station.WORKBENCH or output_item_id != &"":
		return "Repair recipes must use Workbench without a production output."
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


func execute_production(provider: RecipeProductionProvider) -> Dictionary:
	if provider == null or action != Action.PRODUCE_ITEM:
		return {"error": "Production requires a recipe and explicit storage provider."}
	var error: String = validate_definition(provider.material_catalog, provider.item_catalog)
	if not error.is_empty():
		return {"error": error}
	var staged: RecipeProductionProvider = provider.fork()
	if staged == null or staged == provider:
		return {"error": "Production storage cannot stage this operation."}
	for id: Variant in material_inputs:
		if staged.material_quantity(StringName(id)) < int(material_inputs[id]):
			return {"error": "Insufficient Materials for this recipe."}
	# Output capacity/eligibility must succeed before any input is consumed.
	error = staged.store_output(output_item_id, output_quantity)
	if not error.is_empty():
		return {"error": error}
	for id: Variant in material_inputs:
		error = staged.consume_material(StringName(id), int(material_inputs[id]))
		if not error.is_empty():
			return {"error": error}
	error = provider.publish(staged)
	return {"error": error, "recipe_id": recipe_id, "output_item_id": output_item_id, "quantity": output_quantity, "materials_consumed": material_inputs.duplicate(true)}
