class_name AbilityCatalogDefinition
extends Resource


@export var catalog_id: StringName
@export var display_name: String = "Ability Catalog"
@export var abilities: Array[AbilityDefinition] = []


func get_ability(
	ability_id: StringName
) -> AbilityDefinition:
	for ability: AbilityDefinition in abilities:
		if ability != null and ability.ability_id == ability_id:
			return ability
	return null

