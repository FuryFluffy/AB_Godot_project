extends RefCounted
## Process-local recipe only; never registered by production content.
static func register_discovery() -> RefugeRecipeDefinition:
	var recipe := RefugeRecipeDefinition.new()
	recipe.recipe_id = &"fixture:refuge_origin_recipe"
	recipe.display_name = "Fixture discovery"
	recipe.action = RefugeRecipeDefinition.Action.PRODUCE_ITEM
	recipe.station = RefugeRecipeDefinition.Station.ALCHEMY
	recipe.starts_known = false
	recipe.material_inputs = {"mat_l01_servant_cloth":1}
	recipe.output_item_id = &"l01_bandage_roll"
	RefugeOwnershipState.RECIPE_CATALOG.recipes.append(recipe)
	return recipe
