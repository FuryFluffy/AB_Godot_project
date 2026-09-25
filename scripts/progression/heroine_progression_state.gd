class_name HeroineProgressionState
extends RefCounted


var heroine_id: StringName = &""
var weapon_family_ranks: Dictionary = {}
var unlocked_ability_ids: Array[StringName] = []


func _init(
	new_heroine_id: StringName = &"",
	snapshot: Dictionary = {}
) -> void:
	initialize(new_heroine_id, snapshot)


func initialize(
	new_heroine_id: StringName,
	snapshot: Dictionary = {}
) -> void:
	heroine_id = new_heroine_id
	weapon_family_ranks.clear()
	unlocked_ability_ids.clear()

	var stored_ranks: Dictionary = snapshot.get(
		"weapon_family_ranks",
		{}
	) as Dictionary
	for family_key: Variant in stored_ranks.keys():
		set_weapon_family_rank(
			StringName(family_key),
			int(stored_ranks[family_key])
		)

	var stored_unlocks: Array = snapshot.get(
		"unlocked_ability_ids",
		[]
	) as Array
	for ability_value: Variant in stored_unlocks:
		unlock_ability(StringName(ability_value))


func set_weapon_family_rank(
	family_id: StringName,
	rank: int
) -> void:
	if family_id == &"":
		return
	weapon_family_ranks[family_id] = clampi(rank, 1, 3)


func get_weapon_family_rank(
	family_id: StringName,
	fallback_rank: int = 1
) -> int:
	if family_id == &"":
		return clampi(fallback_rank, 1, 3)
	return clampi(
		int(weapon_family_ranks.get(family_id, fallback_rank)),
		1,
		3
	)


func unlock_ability(ability_id: StringName) -> bool:
	if ability_id == &"" or unlocked_ability_ids.has(ability_id):
		return false
	unlocked_ability_ids.append(ability_id)
	unlocked_ability_ids.sort()
	return true


func has_unlocked_ability(ability_id: StringName) -> bool:
	return unlocked_ability_ids.has(ability_id)


func to_snapshot() -> Dictionary:
	var serialized_ranks: Dictionary = {}
	for family_key: Variant in weapon_family_ranks.keys():
		serialized_ranks[String(family_key)] = int(
			weapon_family_ranks[family_key]
		)
	var serialized_unlocks: Array[String] = []
	for ability_id: StringName in unlocked_ability_ids:
		serialized_unlocks.append(String(ability_id))
	return {
		"weapon_family_ranks": serialized_ranks,
		"unlocked_ability_ids": serialized_unlocks,
	}
