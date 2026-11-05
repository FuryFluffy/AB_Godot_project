class_name RefugeRecipeCatalogDefinition
extends Resource


@export var recipes: Array[RefugeRecipeDefinition] = []


func get_recipe(recipe_id: StringName) -> RefugeRecipeDefinition:
	for recipe: RefugeRecipeDefinition in recipes:
		if recipe != null and recipe.recipe_id == recipe_id:
			return recipe
	return null


func validate_catalog(material_catalog: MaterialCatalogDefinition, item_catalog: ItemCatalogDefinition = null) -> String:
	var seen_ids: Dictionary = {}
	for recipe: RefugeRecipeDefinition in recipes:
		if recipe == null:
			return "The Refuge recipe catalog contains an empty entry."
		var recipe_error: String = recipe.validate_definition(material_catalog, item_catalog)
		if not recipe_error.is_empty():
			return recipe_error
		if seen_ids.has(recipe.recipe_id):
			return "Duplicate Refuge recipe Stable ID: %s." % recipe.recipe_id
		seen_ids[recipe.recipe_id] = true
	return ""


func production_entries(station: RefugeRecipeDefinition.Station, provider: RecipeProductionProvider, knows: Callable) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if provider == null or not knows.is_valid():
		return result
	for recipe: RefugeRecipeDefinition in recipes:
		if recipe.action != RefugeRecipeDefinition.Action.PRODUCE_ITEM or recipe.station != station or not knows.call(recipe.recipe_id):
			continue
		if not recipe.validate_definition(provider.material_catalog,provider.item_catalog).is_empty():
			continue
		var inputs: Array[Dictionary] = []
		var can_pay: bool = true
		for id: Variant in recipe.material_inputs:
			var material: MaterialDefinition = provider.material_catalog.get_material(StringName(id))
			var owned: int = provider.material_quantity(StringName(id))
			var required: int = int(recipe.material_inputs[id])
			inputs.append({"id":StringName(id),"name":material.display_name,"icon":material.icon,"owned":owned,"required":required})
			can_pay = can_pay and owned >= required
		var output: ItemDefinition = provider.item_catalog.get_item(recipe.output_item_id)
		result.append({"recipe_id":recipe.recipe_id,"name":recipe.display_name,"inputs":inputs,"can_pay":can_pay,"output_name":output.display_name,"output_icon":output.icon,"quantity":recipe.output_quantity})
	return result
