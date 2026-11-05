class_name FieldStationDefinition
extends Resource
@export var station: RefugeRecipeDefinition.Station = RefugeRecipeDefinition.Station.ALCHEMY
@export var first_visit_materials: Dictionary = {}
@export var recipe_discoveries: Array[StringName] = []

func validate_definition() -> String:
	if station not in [RefugeRecipeDefinition.Station.ALCHEMY,RefugeRecipeDefinition.Station.CRAFTING]:
		return "Invalid field station type."
	for id: Variant in first_visit_materials:
		if not (id is String or id is StringName) or RefugeOwnershipState.MATERIAL_CATALOG.get_material(StringName(id)) == null:
			return "Unknown station Material."
		if not first_visit_materials[id] is int or first_visit_materials[id] <= 0:
			return "Station Material grants require positive integers."
	var seen: Array[StringName] = []
	for id: StringName in recipe_discoveries:
		var recipe: RefugeRecipeDefinition = RefugeOwnershipState.RECIPE_CATALOG.get_recipe(id)
		if seen.has(id) or recipe == null or recipe.action != RefugeRecipeDefinition.Action.PRODUCE_ITEM or recipe.station != station:
			return "Invalid station recipe discovery."
		seen.append(id)
	return ""
