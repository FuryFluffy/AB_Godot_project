class_name RefugeRecipeCatalogDefinition
extends Resource


@export var recipes: Array[RefugeRecipeDefinition] = []


func get_recipe(recipe_id: StringName) -> RefugeRecipeDefinition:
	for recipe: RefugeRecipeDefinition in recipes:
		if recipe != null and recipe.recipe_id == recipe_id:
			return recipe
	return null


func validate_catalog(material_catalog: MaterialCatalogDefinition) -> String:
	var seen_ids: Dictionary = {}
	for recipe: RefugeRecipeDefinition in recipes:
		if recipe == null:
			return "The Refuge recipe catalog contains an empty entry."
		var recipe_error: String = recipe.validate_definition(material_catalog)
		if not recipe_error.is_empty():
			return recipe_error
		if seen_ids.has(recipe.recipe_id):
			return "Duplicate Refuge recipe Stable ID: %s." % recipe.recipe_id
		seen_ids[recipe.recipe_id] = true
	return ""
