class_name RollResult
extends RefCounted

var seed_used: int = 0
var dice_requested: int = 0
var success_threshold: int = 7

var base_rolls: Array[int] = []
var explosion_rolls: Array[int] = []

# All raw dice after base rolls and explosions.
var final_rolls: Array[int] = []

var skill_level: int = 0
var skill_tier: SkillEntry.Tier = SkillEntry.Tier.UNTRAINED
var skill_budget: int = 0
var skill_spent: int = 0

# Each entry refers to an index inside final_rolls.
var modified_indices: Array[int] = []
var modification_amounts: Array[int] = []

var successes_before_skill: int = 0
var total_successes: int = 0


func get_all_rolls() -> Array[int]:
	var combined_rolls: Array[int] = []

	combined_rolls.append_array(base_rolls)
	combined_rolls.append_array(explosion_rolls)

	return combined_rolls


func get_natural_ten_count() -> int:
	var count: int = 0

	for value: int in get_all_rolls():
		if value == 10:
			count += 1

	return count


func has_explosions() -> bool:
	return not explosion_rolls.is_empty()


func has_skill_modifications() -> bool:
	return not modified_indices.is_empty()
