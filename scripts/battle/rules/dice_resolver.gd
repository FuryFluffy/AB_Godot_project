class_name DiceResolver
extends RefCounted

const DIE_MINIMUM: int = 1
const DIE_MAXIMUM: int = 10
const SUCCESS_THRESHOLD: int = 7

# Safety guard against an endless explosion chain.
const MAXIMUM_TOTAL_ROLLS: int = 100


func roll_attribute(
	dice_count: int,
	seed_value: int
) -> RollResult:
	assert(
		dice_count >= 0,
		"An Attribute dice pool cannot be negative."
	)

	var result: RollResult = RollResult.new()
	result.seed_used = seed_value
	result.dice_requested = dice_count
	result.success_threshold = SUCCESS_THRESHOLD

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value

	var pending_explosions: int = 0

	for _die_index: int in range(dice_count):
		var rolled_value: int = rng.randi_range(
			DIE_MINIMUM,
			DIE_MAXIMUM
		)

		result.base_rolls.append(rolled_value)

		if rolled_value == DIE_MAXIMUM:
			pending_explosions += 1

	while pending_explosions > 0:
		pending_explosions -= 1

		var current_total: int = (
			result.base_rolls.size()
			+ result.explosion_rolls.size()
		)

		if current_total >= MAXIMUM_TOTAL_ROLLS:
			push_error(
				"Roll exceeded the maximum explosion limit."
			)
			break

		var explosion_value: int = rng.randi_range(
			DIE_MINIMUM,
			DIE_MAXIMUM
		)

		result.explosion_rolls.append(explosion_value)

		if explosion_value == DIE_MAXIMUM:
			pending_explosions += 1

	var raw_rolls: Array[int] = result.get_all_rolls()

	result.final_rolls = raw_rolls.duplicate()
	result.successes_before_skill = _count_successes(raw_rolls)
	result.total_successes = result.successes_before_skill

	return result


func roll_check(
	dice_count: int,
	skill_level: int,
	skill_tier: SkillEntry.Tier,
	seed_value: int,
	forced_base_rolls: Array[int] = []
) -> RollResult:
	var result: RollResult

	if forced_base_rolls.is_empty():
		result = roll_attribute(
			dice_count,
			seed_value
		)
	else:
		result = _build_forced_attribute_roll(
			dice_count,
			seed_value,
			forced_base_rolls
		)

	result.skill_level = skill_level
	result.skill_tier = skill_tier
	result.skill_budget = SkillRules.get_budget(
		skill_level,
		skill_tier
	)

	_apply_skill_automatically(result)

	result.total_successes = _count_successes(
		result.final_rolls
	)

	return result


func _build_forced_attribute_roll(
	dice_count: int,
	seed_value: int,
	forced_base_rolls: Array[int]
) -> RollResult:
	assert(
		forced_base_rolls.size() == dice_count,
		"A forced roll must provide exactly one value per die."
	)

	var result: RollResult = RollResult.new()
	result.seed_used = seed_value
	result.dice_requested = dice_count
	result.success_threshold = SUCCESS_THRESHOLD

	for value: int in forced_base_rolls:
		assert(
			value >= DIE_MINIMUM and value < DIE_MAXIMUM,
			"Forced test dice must be between 1 and 9."
		)
		result.base_rolls.append(value)

	result.final_rolls = result.base_rolls.duplicate()
	result.successes_before_skill = _count_successes(
		result.final_rolls
	)
	result.total_successes = result.successes_before_skill
	return result


func _apply_skill_automatically(
	result: RollResult
) -> void:
	var remaining_budget: int = result.skill_budget
	var target_limit: int = SkillRules.get_target_limit(
		result.skill_tier
	)

	if remaining_budget <= 0 or target_limit == 0:
		return

	var candidate_indices: Array[int] = []

	for index: int in range(result.final_rolls.size()):
		if result.final_rolls[index] < SUCCESS_THRESHOLD:
			candidate_indices.append(index)

	var targets_used: int = 0

	while (
		remaining_budget > 0
		and not candidate_indices.is_empty()
		and (
			target_limit < 0
			or targets_used < target_limit
		)
	):
		var target_index: int = _find_closest_failure(
			result.final_rolls,
			candidate_indices
		)

		if target_index < 0:
			break

		var needed_for_success: int = (
			SUCCESS_THRESHOLD
			- result.final_rolls[target_index]
		)

		var applied_bonus: int = min(
			remaining_budget,
			needed_for_success
		)

		_apply_modification(
			result,
			target_index,
			applied_bonus
		)

		remaining_budget -= applied_bonus
		targets_used += 1
		candidate_indices.erase(target_index)

		# The remaining budget cannot make the closest die succeed,
		# so it cannot make any other failed die succeed either.
		if applied_bonus < needed_for_success:
			break

	# Any remaining budget is added to the first selected die.
	# This preserves the full Skill modifier where possible.
	if (
		remaining_budget > 0
		and not result.modified_indices.is_empty()
	):
		var first_target: int = result.modified_indices[0]

		var remaining_capacity: int = (
			DIE_MAXIMUM
			- result.final_rolls[first_target]
		)

		var extra_bonus: int = min(
			remaining_budget,
			remaining_capacity
		)

		if extra_bonus > 0:
			_extend_modification(
				result,
				first_target,
				extra_bonus
			)


func _find_closest_failure(
	rolls: Array[int],
	candidate_indices: Array[int]
) -> int:
	var best_index: int = -1
	var smallest_distance: int = 999

	for index: int in candidate_indices:
		var distance: int = (
			SUCCESS_THRESHOLD
			- rolls[index]
		)

		if distance < smallest_distance:
			smallest_distance = distance
			best_index = index

	return best_index


func _apply_modification(
	result: RollResult,
	die_index: int,
	bonus: int
) -> void:
	if bonus <= 0:
		return

	result.final_rolls[die_index] = mini(
		result.final_rolls[die_index] + bonus,
		DIE_MAXIMUM
	)

	result.modified_indices.append(die_index)
	result.modification_amounts.append(bonus)
	result.skill_spent += bonus


func _extend_modification(
	result: RollResult,
	die_index: int,
	extra_bonus: int
) -> void:
	if extra_bonus <= 0:
		return

	var modification_position: int = (
		result.modified_indices.find(die_index)
	)

	if modification_position < 0:
		return

	result.final_rolls[die_index] = mini(
		result.final_rolls[die_index] + extra_bonus,
		DIE_MAXIMUM
	)

	result.modification_amounts[modification_position] += (
		extra_bonus
	)

	result.skill_spent += extra_bonus


func _count_successes(
	rolls: Array[int]
) -> int:
	var successes: int = 0

	for value: int in rolls:
		if value >= SUCCESS_THRESHOLD:
			successes += 1

	return successes
