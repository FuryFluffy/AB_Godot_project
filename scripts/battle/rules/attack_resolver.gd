class_name AttackResolver
extends RefCounted


const DEFENSE_ACTION_COST: int = 1


enum TestRollMode {
	SEEDED_RANDOM,
	FORCE_ATTACK_HIT,
	FORCE_FULL_NEGATION,
	FORCE_NATURAL_MISS,
}


var dice_resolver: DiceResolver = DiceResolver.new()
var test_roll_mode: int = TestRollMode.SEEDED_RANDOM
var status_controller: StatusController


func set_test_roll_mode(
	new_mode: int
) -> void:
	test_roll_mode = clampi(
		new_mode,
		TestRollMode.SEEDED_RANDOM,
		TestRollMode.FORCE_NATURAL_MISS
	)


func prepare_attack(
	request: ActionRequest,
	actor: BattlerState,
	target: BattlerState
) -> ReactionContext:
	var context: ReactionContext = ReactionContext.new()
	context.request = request

	var validation_error: String = _validate_attack(
		request,
		actor,
		target
	)

	if not validation_error.is_empty():
		return context.fail(validation_error)

	context.attacker_actions_before = actor.current_actions

	if request.action_cost > 0:
		var action_was_spent: bool = actor.spend_actions(
			request.action_cost
		)

		if not action_was_spent:
			return context.fail(
				"%s could not spend %d Action."
				% [
					actor.definition.display_name,
					request.action_cost,
				]
			)

	context.attacker_actions_after = actor.current_actions
	context.attack_roll = request.shared_attack_roll
	if context.attack_roll == null:
		context.attack_roll = _roll_weapon_check(
			actor,
			request
		)
	context.attack_successes = (
		context.attack_roll.total_successes
		+ request.weapon.get_flat_attack_success_bonus(
			request.weapon_family_rank
		)
	)
	context.is_valid = true
	return context


func resolve_reaction(
	context: ReactionContext,
	actor: BattlerState,
	target: BattlerState,
	choice: DefenseChoice.Type
) -> ActionResult:
	var result: ActionResult = ActionResult.new()

	if context == null:
		return result.fail("Reaction context is missing.")

	result.request = context.request

	var validation_error: String = _validate_context(
		context,
		actor,
		target
	)

	if not validation_error.is_empty():
		return result.fail(validation_error)

	var defense_error: String = _validate_defense_choice(
		target,
		choice
	)
	if not defense_error.is_empty():
		return result.fail(defense_error)

	result.roll_result = context.attack_roll
	result.attack_successes = context.attack_successes
	result.weapon_attack_dice_bonus = (
		context.request.weapon.get_attack_dice_bonus(
			context.request.weapon_family_rank
		)
	)
	result.weapon_attack_success_bonus = (
		context.request.weapon.get_flat_attack_success_bonus(
			context.request.weapon_family_rank
		)
	)
	result.defense_choice = choice
	result.actor_actions_before = context.attacker_actions_before
	result.actor_actions_after = context.attacker_actions_after
	result.action_spent = context.request.action_cost
	result.target_actions_before = target.current_actions
	result.target_hp_before = target.current_hp

	match choice:
		DefenseChoice.Type.SKIP:
			result.defense_successes = 0

		DefenseChoice.Type.DODGE:
			var dodge_error: String = _resolve_dodge(
				context,
				target,
				result
			)
			if not dodge_error.is_empty():
				return result.fail(dodge_error)

		DefenseChoice.Type.ARMOR:
			var armor_error: String = _resolve_armor_defense(
				context,
				target,
				result
			)
			if not armor_error.is_empty():
				return result.fail(armor_error)

		DefenseChoice.Type.SHIELD:
			var shield_error: String = _resolve_shield_defense(
				context,
				target,
				result
			)
			if not shield_error.is_empty():
				return result.fail(shield_error)

		DefenseChoice.Type.PARRY:
			var parry_error: String = _resolve_parry(
				context,
				target,
				result
			)
			if not parry_error.is_empty():
				return result.fail(parry_error)

		_:
			return result.fail("Unsupported Defense choice.")

	result.target_actions_after = target.current_actions
	result.defense_successes_ignored = (
		_get_ignored_defense_successes(
			context.request,
			context.request.weapon,
			choice,
			result.defense_successes,
			context.request.weapon_family_rank
		)
	)
	result.effective_defense_successes = maxi(
		result.defense_successes
		- result.defense_successes_ignored,
		0
	)
	result.remaining_attack_successes = maxi(
		result.attack_successes
		- result.effective_defense_successes,
		0
	)
	if choice == DefenseChoice.Type.DODGE:
		result.dodge_step_available = (
			mini(
				result.attack_successes,
				result.effective_defense_successes
			) > 0
		)
	if (
		context.request.ignore_one_defense_success
		and result.defense_successes_ignored > 0
		and actor.consume_analyzed_target(
			target.definition.battler_id
		)
	):
		result.analyzed_bonus_consumed = true

	var blessed_minimum: int = actor.consume_bless()
	if blessed_minimum > 0:
		result.remaining_attack_successes = maxi(
			result.remaining_attack_successes,
			blessed_minimum
		)
		result.blessed_attack_consumed = true

	if result.remaining_attack_successes > 0:
		result.specialty_damage_bonus = _get_specialty_damage_bonus(
			actor,
			context.request
		)
		result.remaining_attack_successes += (
			result.specialty_damage_bonus
		)
		result.weapon_flat_damage_bonus = (
			context.request.weapon.get_flat_damage_bonus(
				context.request.weapon_family_rank
			)
		)
		result.remaining_attack_successes += (
			result.weapon_flat_damage_bonus
		)

	if choice == DefenseChoice.Type.PARRY:
		result.parry_prevented_damage = mini(
			result.attack_successes,
			result.effective_defense_successes
		)
		result.parry_should_generate_free_attack = (
			result.parry_prevented_damage > 0
		)

	result.succeeded = true

	_initialize_damage_allocation(result, target)
	if result.is_complete:
		_apply_weapon_effects_if_needed(
			result,
			actor,
			target
		)
		_apply_weapon_durability_if_needed(
			result,
			actor
		)
	return result


func resolve_equipment_break_choice(
	result: ActionResult,
	actor: BattlerState,
	target: BattlerState,
	choice: BreakChoice.Type
) -> ActionResult:
	if result == null:
		return ActionResult.new().fail("ActionResult is missing.")
	if actor == null:
		return result.fail("Equipment-break attacker is missing.")
	if target == null:
		return result.fail("Equipment-break target is missing.")
	if not result.requires_equipment_break_choice:
		return result.fail("No equipment-break confirmation is pending.")

	var remaining_damage: int = (
		result.pending_damage_after_safe_absorption
	)

	match choice:
		BreakChoice.Type.PRESERVE:
			pass

		BreakChoice.Type.DESTROY:
			var absorbed: int = 0

			match result.pending_break_item:
				ActionResult.AllocationItem.ARMOR:
					absorbed = target.destroy_armor_to_absorb_one()
					if absorbed > 0:
						result.armor_damage_absorbed += absorbed
						result.armor_broken = true

				ActionResult.AllocationItem.SHIELD:
					absorbed = target.destroy_shield_to_absorb_one()
					if absorbed > 0:
						result.shield_damage_absorbed += absorbed
						result.shield_broken = true

				_:
					return result.fail("Unknown equipment break target.")

			if absorbed <= 0:
				return result.fail(
					"Equipment could not absorb its breaking point."
				)

			remaining_damage -= absorbed

		_:
			return result.fail(
				"Unsupported break confirmation choice."
			)

	result.requires_equipment_break_choice = false
	result.pending_break_item = ActionResult.AllocationItem.NONE
	result.pending_damage_after_safe_absorption = 0
	result.allocation_index += 1

	_continue_damage_allocation(
		result,
		target,
		maxi(remaining_damage, 0)
	)

	if result.is_complete:
		_apply_weapon_effects_if_needed(
			result,
			actor,
			target
		)
		_apply_weapon_durability_if_needed(
			result,
			actor
		)

	return result


func get_dodge_dice_count(target: BattlerState) -> int:
	if (
		target == null
		or target.definition == null
		or target.definition.attributes == null
	):
		return 0

	var agility: int = target.definition.attributes.get_value(
		AttributeSet.Attribute.AGILITY
	)

	return maxi(
		agility
		+ target.get_armor_dodge_modifier()
		+ target.get_shield_dodge_modifier(),
		0
	)


func get_armor_defense_dice_count(target: BattlerState) -> int:
	if (
		target == null
		or target.definition == null
		or target.definition.attributes == null
		or not target.has_usable_armor()
	):
		return 0

	var dice_count: int = target.definition.attributes.get_value(
		AttributeSet.Attribute.AGILITY
	)
	if target.definition.has_specialty(
		SpecialtyEntry.Specialty.ARMORER
	):
		dice_count += 1
	return dice_count


func get_shield_defense_dice_count(target: BattlerState) -> int:
	if (
		target == null
		or target.definition == null
		or target.definition.attributes == null
		or not target.has_usable_shield()
	):
		return 0

	var dice_count: int = target.definition.attributes.get_value(
		AttributeSet.Attribute.MIGHT
	)
	if target.definition.has_specialty(
		SpecialtyEntry.Specialty.ARMORER
	):
		dice_count += 1
	return dice_count


func can_parry(
	context: ReactionContext,
	target: BattlerState
) -> bool:
	if (
		context == null
		or context.request == null
		or target == null
		or target.definition == null
		or target.definition.attributes == null
		or target.is_defeated
		or _is_grappled_heroine(target)
		or target.is_attached_grappler()
	):
		return false

	if context.request.is_magic:
		return false
	if not context.request.permits_parry:
		return false

	return target.can_parry_with_weapon()


func get_parry_dice_count(
	context: ReactionContext,
	target: BattlerState
) -> int:
	if not can_parry(context, target):
		return 0

	var weapon: WeaponDefinition = _get_main_hand_weapon(
		target
	)
	var attribute_value: int = (
		target.definition.attributes.get_value(
			weapon.attribute
		)
	)

	return maxi(
		attribute_value
		+ weapon.dice_modifier
		+ target.get_shield_parry_modifier()
		- get_parry_penalty(context),
		0
	)


func get_parry_penalty(
	context: ReactionContext
) -> int:
	if context == null or context.request == null:
		return 1

	return maxi(
		context.request.parry_sequence_index + 1,
		1
	)


func _resolve_dodge(
	context: ReactionContext,
	target: BattlerState,
	result: ActionResult
) -> String:
	if target.is_defeated:
		return "%s is defeated and cannot Dodge." % (
			target.definition.display_name
		)
	if target.current_actions < DEFENSE_ACTION_COST:
		return "%s does not have enough Actions to Dodge." % (
			target.definition.display_name
		)

	if not target.spend_actions(DEFENSE_ACTION_COST):
		return "%s could not spend a reaction Action." % (
			target.definition.display_name
		)

	result.reaction_action_spent = DEFENSE_ACTION_COST
	result.ward_dice_bonus = target.consume_ward()

	var athletics_entry: SkillEntry = target.definition.get_skill_entry(
		SkillEntry.Skill.ATHLETICS
	)
	var skill_level: int = 0
	var skill_tier: SkillEntry.Tier = SkillEntry.Tier.UNTRAINED

	if athletics_entry != null:
		skill_level = athletics_entry.level
		skill_tier = athletics_entry.tier

	var dice_count: int = (
		get_dodge_dice_count(target)
		+ result.ward_dice_bonus
	)
	result.defense_roll = dice_resolver.roll_check(
		dice_count,
		skill_level,
		skill_tier,
		context.request.seed_value + 1,
		_get_forced_rolls(
			dice_count,
			false
		)
	)
	result.defense_successes = result.defense_roll.total_successes
	return ""


func _resolve_armor_defense(
	context: ReactionContext,
	target: BattlerState,
	result: ActionResult
) -> String:
	if target.is_defeated:
		return "%s is defeated and cannot Armor Defend." % (
			target.definition.display_name
		)
	if not target.has_usable_armor():
		return "%s has no usable armor." % (
			target.definition.display_name
		)
	if target.current_actions < DEFENSE_ACTION_COST:
		return (
			"%s does not have enough Actions for Armor Defense."
			% target.definition.display_name
		)
	if not target.spend_actions(DEFENSE_ACTION_COST):
		return "%s could not spend a reaction Action." % (
			target.definition.display_name
		)

	result.reaction_action_spent = DEFENSE_ACTION_COST
	result.ward_dice_bonus = target.consume_ward()

	var armor_state: ArmorState = target.armor_state
	if armor_state == null or armor_state.definition == null:
		return "%s has no valid armor definition." % (
			target.definition.display_name
		)

	var protection_type: ProtectionProficiencyEntry.Type = (
		armor_state.definition.get_protection_type()
	)
	var proficiency: ProtectionProficiencyEntry = (
		target.definition.get_protection_proficiency(protection_type)
	)
	var skill_level: int = 0
	var skill_tier: SkillEntry.Tier = SkillEntry.Tier.UNTRAINED

	if proficiency != null:
		skill_level = proficiency.level
		skill_tier = proficiency.tier

	var dice_count: int = (
		get_armor_defense_dice_count(target)
		+ result.ward_dice_bonus
	)
	result.defense_roll = dice_resolver.roll_check(
		dice_count,
		skill_level,
		skill_tier,
		context.request.seed_value + 2,
		_get_forced_rolls(
			dice_count,
			false
		)
	)
	result.defense_successes = result.defense_roll.total_successes
	return ""


func _resolve_shield_defense(
	context: ReactionContext,
	target: BattlerState,
	result: ActionResult
) -> String:
	if target.is_defeated:
		return "%s is defeated and cannot Shield Defend." % (
			target.definition.display_name
		)
	if not target.has_usable_shield():
		return "%s has no usable shield." % (
			target.definition.display_name
		)
	if target.current_actions < DEFENSE_ACTION_COST:
		return (
			"%s does not have enough Actions for Shield Defense."
			% target.definition.display_name
		)
	if not target.spend_actions(DEFENSE_ACTION_COST):
		return "%s could not spend a reaction Action." % (
			target.definition.display_name
		)

	result.reaction_action_spent = DEFENSE_ACTION_COST
	result.ward_dice_bonus = target.consume_ward()

	var proficiency: ProtectionProficiencyEntry = (
		target.definition.get_protection_proficiency(
			ProtectionProficiencyEntry.Type.SHIELD
		)
	)
	var skill_level: int = 0
	var skill_tier: SkillEntry.Tier = SkillEntry.Tier.UNTRAINED

	if proficiency != null:
		skill_level = proficiency.level
		skill_tier = proficiency.tier

	var dice_count: int = (
		get_shield_defense_dice_count(target)
		+ result.ward_dice_bonus
	)
	result.defense_roll = dice_resolver.roll_check(
		dice_count,
		skill_level,
		skill_tier,
		context.request.seed_value + 3,
		_get_forced_rolls(
			dice_count,
			false
		)
	)
	result.defense_successes = result.defense_roll.total_successes
	return ""


func _resolve_parry(
	context: ReactionContext,
	target: BattlerState,
	result: ActionResult
) -> String:
	if target.is_defeated:
		return "%s is defeated and cannot Parry." % (
			target.definition.display_name
		)

	if context.request.is_magic:
		return "Magic attacks cannot be Parried."

	var weapon: WeaponDefinition = target.get_usable_main_hand_weapon()

	if weapon == null or not target.can_parry_with_weapon():
		return "%s has no suitable weapon for Parry." % (
			target.definition.display_name
		)

	if target.current_actions < DEFENSE_ACTION_COST:
		return "%s does not have enough Actions to Parry." % (
			target.definition.display_name
		)

	if not target.spend_actions(DEFENSE_ACTION_COST):
		return "%s could not spend a reaction Action." % (
			target.definition.display_name
		)

	result.reaction_action_spent = DEFENSE_ACTION_COST
	result.ward_dice_bonus = target.consume_ward()
	result.parry_penalty = get_parry_penalty(context)
	result.parry_shield_bonus = target.get_shield_parry_modifier()

	var skill_entry: SkillEntry = (
		target.definition.get_skill_entry(weapon.skill)
	)
	var skill_level: int = 0
	var skill_tier: SkillEntry.Tier = SkillEntry.Tier.UNTRAINED

	if skill_entry != null:
		skill_level = skill_entry.level
		skill_tier = skill_entry.tier

	var dice_count: int = (
		get_parry_dice_count(context, target)
		+ result.ward_dice_bonus
	)
	result.defense_roll = dice_resolver.roll_check(
		dice_count,
		skill_level,
		skill_tier,
		context.request.seed_value + 4,
		_get_forced_rolls(
			dice_count,
			false
		)
	)
	result.defense_successes = (
		result.defense_roll.total_successes
	)
	return ""


func _initialize_damage_allocation(
	result: ActionResult,
	target: BattlerState
) -> void:
	result.allocation_order.clear()
	result.allocation_index = 0

	match target.damage_allocation_policy:
		EquipmentLoadout.DamageAllocationPolicy.SHIELD_FIRST:
			result.allocation_order.append(
				ActionResult.AllocationItem.SHIELD
			)
			result.allocation_order.append(
				ActionResult.AllocationItem.ARMOR
			)

		_:
			result.allocation_order.append(
				ActionResult.AllocationItem.ARMOR
			)
			result.allocation_order.append(
				ActionResult.AllocationItem.SHIELD
			)

	_continue_damage_allocation(
		result,
		target,
		result.remaining_attack_successes
	)


func _continue_damage_allocation(
	result: ActionResult,
	target: BattlerState,
	starting_damage: int
) -> void:
	var remaining_damage: int = maxi(starting_damage, 0)

	result.requires_equipment_break_choice = false
	result.pending_break_item = ActionResult.AllocationItem.NONE
	result.pending_damage_after_safe_absorption = 0

	while (
		remaining_damage > 0
		and result.allocation_index < result.allocation_order.size()
	):
		var allocation_item: int = result.allocation_order[
			result.allocation_index
		]

		match allocation_item:
			ActionResult.AllocationItem.ARMOR:
				if not target.has_usable_armor():
					result.allocation_index += 1
					continue

				var armor_absorbed: int = (
					target.absorb_damage_with_armor_safely(
						remaining_damage
					)
				)
				result.armor_damage_absorbed += armor_absorbed
				remaining_damage -= armor_absorbed

				if (
					remaining_damage > 0
					and target.armor_state != null
					and target.armor_state.is_at_breaking_point()
				):
					_set_pending_break_choice(
						result,
						target,
						ActionResult.AllocationItem.ARMOR,
						remaining_damage
					)
					return

			ActionResult.AllocationItem.SHIELD:
				if not target.has_damage_absorbing_shield():
					result.allocation_index += 1
					continue

				var shield_absorbed: int = (
					target.absorb_damage_with_shield_safely(
						remaining_damage
					)
				)
				result.shield_damage_absorbed += shield_absorbed
				remaining_damage -= shield_absorbed

				if (
					remaining_damage > 0
					and target.shield_state != null
					and target.shield_state.is_at_breaking_point()
				):
					_set_pending_break_choice(
						result,
						target,
						ActionResult.AllocationItem.SHIELD,
						remaining_damage
					)
					return

			_:
				result.allocation_index += 1
				continue

		result.allocation_index += 1

	result.damage_dealt = target.apply_damage(remaining_damage)
	result.target_hp_after = target.current_hp
	result.target_defeated = target.is_defeated
	result.is_complete = true
	result.succeeded = true


func _set_pending_break_choice(
	result: ActionResult,
	target: BattlerState,
	allocation_item: ActionResult.AllocationItem,
	remaining_damage: int
) -> void:
	result.requires_equipment_break_choice = true
	result.pending_break_item = allocation_item
	result.pending_damage_after_safe_absorption = remaining_damage
	result.target_hp_after = target.current_hp
	result.target_defeated = target.is_defeated
	result.is_complete = false


func _get_main_hand_weapon(
	state: BattlerState
) -> WeaponDefinition:
	if state == null:
		return null

	return state.get_usable_main_hand_weapon()


func _get_ignored_defense_successes(
	request: ActionRequest,
	weapon: WeaponDefinition,
	choice: DefenseChoice.Type,
	defense_successes: int,
	weapon_family_rank: int = 0
) -> int:
	if weapon == null or defense_successes <= 0:
		return 0

	var ignored: int = weapon.get_ignored_defense_successes(
		choice,
		weapon_family_rank
	)

	if request != null and request.ignore_one_defense_success:
		ignored += 1
	return mini(ignored, defense_successes)


func _roll_weapon_check(
	actor: BattlerState,
	request: ActionRequest
) -> RollResult:
	var weapon: WeaponDefinition = request.weapon
	var attribute_value: int = actor.definition.attributes.get_value(
		weapon.attribute
	)
	var dice_count: int = (
		attribute_value
		+ weapon.dice_modifier
		+ weapon.get_attack_dice_bonus(
			request.weapon_family_rank
		)
		+ request.attack_dice_modifier
		+ actor.passive_attack_dice_bonus
	)
	if (
		request.ability == null
		and request.item == null
		and actor.definition.has_specialty(
			SpecialtyEntry.Specialty.BODYBUILDING
		)
	):
		dice_count += 1
	# A legal committed Attack always rolls. Penalties can reduce its pool to
	# the universal floor, but never turn it into a spent Action with no dice.
	dice_count = maxi(dice_count, 1)
	var skill_entry: SkillEntry = actor.definition.get_skill_entry(
		weapon.skill
	)
	var skill_level: int = 0
	var skill_tier: SkillEntry.Tier = SkillEntry.Tier.UNTRAINED

	if (
		skill_entry != null
		and not request.suppress_skill_modification
	):
		skill_level = skill_entry.level
		skill_tier = skill_entry.tier

	return dice_resolver.roll_check(
		dice_count,
		skill_level,
		skill_tier,
		request.seed_value,
		_get_forced_rolls(
			dice_count,
			true
		)
	)


func _get_forced_rolls(
	dice_count: int,
	is_attack_roll: bool
) -> Array[int]:
	var forced_rolls: Array[int] = []

	if (
		test_roll_mode == TestRollMode.SEEDED_RANDOM
		or dice_count <= 0
	):
		return forced_rolls

	for _index: int in range(dice_count):
		forced_rolls.append(1)

	match test_roll_mode:
		TestRollMode.FORCE_ATTACK_HIT:
			if is_attack_roll:
				forced_rolls[0] = 8

		TestRollMode.FORCE_FULL_NEGATION:
			forced_rolls[0] = 8

		TestRollMode.FORCE_NATURAL_MISS:
			pass

	return forced_rolls


func _apply_weapon_durability_if_needed(
	result: ActionResult,
	actor: BattlerState
) -> void:
	if result.durability_processed:
		return

	result.durability_processed = true

	if (
		result.attack_successes <= 0
		or result.damage_dealt > 0
		or (
			result.request != null
			and result.request.ability != null
		)
		or actor == null
		or actor.weapon_state == null
		or (
			result.request != null
			and result.request.source == ActionRequest.Source.ITEM
		)
	):
		return

	result.weapon_durability_before = (
		actor.weapon_state.durability_damage
	)

	result.weapon_durability_event = (
		actor.apply_weapon_durability_event()
	)

	result.weapon_durability_after = (
		actor.weapon_state.durability_damage
	)
	result.weapon_broken = actor.weapon_state.is_broken


func _apply_weapon_effects_if_needed(
	result: ActionResult,
	actor: BattlerState,
	target: BattlerState
) -> void:
	if result.weapon_effects_processed:
		return

	result.weapon_effects_processed = true
	result.status_processed = true
	if (
		result.request == null
		or result.request.weapon == null
	):
		return

	var weapon: WeaponDefinition = result.request.weapon
	var weapon_rank: int = result.request.weapon_family_rank
	if (
		result.remaining_attack_successes > 0
		and result.defense_choice == DefenseChoice.Type.SKIP
		and not target.is_defeated
	):
		_apply_undefended_hit_statuses_if_needed(
			result,
			actor,
			target,
			weapon,
			weapon_rank
		)
	if result.damage_dealt <= 0:
		return
	var requested_action_loss: int = (
		weapon.get_action_loss_on_damage(
			result.damage_dealt,
			weapon_rank
		)
	)
	if requested_action_loss > 0 and not target.is_defeated:
		var actions_before: int = target.current_actions
		target.set_current_actions(
			target.current_actions - requested_action_loss
		)
		result.weapon_action_loss = (
			actions_before - target.current_actions
		)
		result.target_actions_after = target.current_actions
		if result.weapon_action_loss > 0:
			result.weapon_effect_messages.append(
				"%s loses %d Action from %s."
				% [
					target.definition.display_name,
					result.weapon_action_loss,
					weapon.display_name,
				]
			)

	_apply_status_effects_if_needed(
		result,
		actor,
		target,
		weapon,
		weapon_rank
	)

	var skill_entry: SkillEntry = null
	if actor != null and actor.definition != null:
		skill_entry = actor.definition.get_skill_entry(
			weapon.skill
		)
	result.weapon_critical_free_attack_requested = (
		weapon.has_critical_free_attack(
			result.roll_result,
			skill_entry,
			weapon_rank
		)
	)


func _apply_undefended_hit_statuses_if_needed(
	result: ActionResult,
	actor: BattlerState,
	target: BattlerState,
	weapon: WeaponDefinition,
	weapon_rank: int
) -> void:
	if status_controller == null:
		return
	var source_id: StringName = (
		actor.definition.battler_id
		if actor != null and actor.definition != null
		else &"unknown_source"
	)
	for effect: StatusOnUndefendedHitWeaponEffect in (
		weapon.get_status_effects_on_undefended_hit(weapon_rank)
	):
		var application: StatusApplicationResult = (
			status_controller.apply_status(
				target,
				effect.status,
				source_id,
				effect.status_damage_override,
				effect.status_tick_override
			)
		)
		result.status_applied = (
			result.status_applied or application.succeeded
		)
		result.status_replaced_existing = (
			result.status_replaced_existing
			or application.replaced_existing
		)
		result.status_display_name = effect.status.display_name
		result.status_error_message = application.error_message


func _apply_status_effects_if_needed(
	result: ActionResult,
	actor: BattlerState,
	target: BattlerState,
	weapon: WeaponDefinition,
	weapon_rank: int
) -> void:
	if status_controller == null:
		return

	var source_id: StringName = (
		actor.definition.battler_id
		if actor != null and actor.definition != null
		else &"unknown_source"
	)
	var status_effects: Array[StatusOnDamageWeaponEffect] = (
		weapon.get_status_effects_on_damage(
			result.damage_dealt,
			weapon_rank
		)
	)

	if (
		status_effects.is_empty()
		and weapon.on_damage_status != null
	):
		var legacy_effect: StatusOnDamageWeaponEffect = (
			StatusOnDamageWeaponEffect.new()
		)
		legacy_effect.status = weapon.on_damage_status
		legacy_effect.status_damage_override = (
			weapon.status_damage_override
		)
		legacy_effect.status_tick_override = (
			weapon.status_tick_override
		)
		status_effects.append(legacy_effect)

	for effect: StatusOnDamageWeaponEffect in status_effects:
		var application: StatusApplicationResult = (
			status_controller.apply_status(
				target,
				effect.status,
				source_id,
				effect.status_damage_override,
				effect.status_tick_override
			)
		)
		result.status_applied = (
			result.status_applied
			or application.succeeded
		)
		result.status_replaced_existing = (
			result.status_replaced_existing
			or application.replaced_existing
		)
		result.status_display_name = effect.status.display_name
		result.status_error_message = application.error_message


func _validate_attack(
	request: ActionRequest,
	actor: BattlerState,
	target: BattlerState
) -> String:
	if request == null:
		return "Attack request is missing."
	if actor == null:
		return "Attacker state is missing."
	if target == null:
		return "Target state is missing."
	if actor.definition == null:
		return "Attacker definition is missing."
	if target.definition == null:
		return "Target definition is missing."
	if request.actor_id != actor.definition.battler_id:
		return "Attack request contains the wrong attacker ID."
	if request.target_id != target.definition.battler_id:
		return "Attack request contains the wrong target ID."
	if actor == target:
		return "A combatant cannot attack itself."
	if actor.definition.faction == target.definition.faction:
		return "A combatant cannot attack an ally."
	if actor.is_defeated:
		return "%s is defeated." % actor.definition.display_name
	if actor.is_stunned():
		return "%s is Stunned." % actor.definition.display_name
	if target.is_defeated:
		return "%s is already defeated." % target.definition.display_name
	if request.action_cost < 0:
		return "Attack Action cost cannot be negative."
	if request.is_free_attack and request.action_cost != 0:
		return "A free Attack must cost zero Actions."
	if not request.is_free_attack and request.action_cost <= 0:
		return "A normal Attack Action cost must be positive."
	if actor.current_actions < request.action_cost:
		return "%s does not have enough Actions." % (
			actor.definition.display_name
		)
	if request.weapon == null:
		return "%s has no attack weapon." % (
			actor.definition.display_name
		)
	if request.source == ActionRequest.Source.ITEM:
		if request.item == null:
			return "Item Attack request has no ItemDefinition."
		if not request.item.performs_attack:
			return "%s is not authored as an Item Attack." % (
				request.item.display_name
			)
	elif request.ability == null:
		if (
			actor.weapon_state == null
			or not actor.weapon_state.can_use()
		):
			return "%s's weapon is Broken and unusable." % (
				actor.definition.display_name
			)
		if actor.weapon_state.definition != request.weapon:
			return "Attack request does not use the attacker's equipped weapon."
	else:
		if (
			request.source == ActionRequest.Source.AOE
			and request.ability.targeting_mode
			!= AbilityDefinition.TargetingMode.BATTLE_ZONE
		):
			return "AOE requests require a BattleZone ability."
		if (
			request.source == ActionRequest.Source.ABILITY
			and request.ability.targeting_mode
			!= AbilityDefinition.TargetingMode.ENEMY
		):
			return "Targeted ability requests require an enemy target."
		if (
			request.source != ActionRequest.Source.AOE
			and request.source != ActionRequest.Source.ABILITY
		):
			return "Ability request has an unsupported Action source."
	if actor.definition.attributes == null:
		return "%s has no AttributeSet." % (
			actor.definition.display_name
		)

	return ""


func _get_specialty_damage_bonus(
	actor: BattlerState,
	request: ActionRequest
) -> int:
	if actor == null or actor.definition == null or request == null:
		return 0
	if (
		request.is_magic
		and actor.definition.has_specialty(
			SpecialtyEntry.Specialty.SPELLCASTER
		)
	):
		return 1
	if (
		not request.is_magic
		and request.ability == null
		and request.item == null
		and actor.definition.has_specialty(
			SpecialtyEntry.Specialty.ARMSMASTER
		)
	):
		return 1
	return 0


func _validate_context(
	context: ReactionContext,
	actor: BattlerState,
	target: BattlerState
) -> String:
	if not context.is_valid:
		return context.error_message
	if context.request == null:
		return "Committed attack request is missing."
	if actor == null:
		return "Committed attacker state is missing."
	if target == null:
		return "Committed target state is missing."
	if actor.definition == null:
		return "Committed attacker definition is missing."
	if target.definition == null:
		return "Committed target definition is missing."
	if context.request.actor_id != actor.definition.battler_id:
		return "Reaction context contains the wrong attacker."
	if context.request.target_id != target.definition.battler_id:
		return "Reaction context contains the wrong target."
	if target.is_defeated:
		return "%s is already defeated." % (
			target.definition.display_name
		)
	if context.attack_roll == null:
		return "Committed attack has no RollResult."

	return ""


func _validate_defense_choice(
	target: BattlerState,
	choice: DefenseChoice.Type
) -> String:
	if target == null:
		return "Defense target is missing."

	if target.is_attached_grappler():
		if choice != DefenseChoice.Type.SKIP:
			return (
				"Attached grapplers cannot use active Defense reactions."
			)
		return ""

	if not _is_grappled_heroine(target):
		return ""

	if (
		choice == DefenseChoice.Type.SKIP
		or choice == DefenseChoice.Type.ARMOR
		or choice == DefenseChoice.Type.SHIELD
	):
		return ""

	return (
		"Grappled heroines may only use Armor Defense, "
		+ "Shield Defense, or Skip."
	)


func _is_grappled_heroine(
	target: BattlerState
) -> bool:
	return (
		target != null
		and target.definition != null
		and target.definition.faction
		== BattlerDefinition.Faction.HEROINE
		and target.is_grappled()
	)
