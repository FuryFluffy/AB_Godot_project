class_name WeaponFamilyDefinition
extends Resource


@export_group("Identity")
@export var family_id: StringName
@export var display_name: String = "Unnamed Weapon Family"
@export_multiline var description: String = ""

@export_group("Progression")
@export var ranks: Array[WeaponRankDefinition] = []

@export_group("Refuge Training")
@export var compatible_techniques: Array[AbilityDefinition] = []


func get_rank_definition(
	requested_rank: int
) -> WeaponRankDefinition:
	var normalized_rank: int = maxi(requested_rank, 1)

	for definition: WeaponRankDefinition in ranks:
		if definition != null and definition.rank == normalized_rank:
			return definition

	return null


func get_highest_rank() -> int:
	var highest_rank: int = 0

	for definition: WeaponRankDefinition in ranks:
		if definition != null:
			highest_rank = maxi(highest_rank, definition.rank)

	return highest_rank


func is_valid_rank(
	requested_rank: int
) -> bool:
	return get_rank_definition(requested_rank) != null
