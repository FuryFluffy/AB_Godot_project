class_name AbilityEffectResolver
extends RefCounted


var battler_states: Dictionary = {}
var battlefield_state: BattlefieldState
var status_controller: StatusController
var dice_resolver: DiceResolver
var base_seed: int = 1
var resolution_counter: int = 0


func initialize(
	new_battler_states: Dictionary,
	new_battlefield_state: BattlefieldState,
	new_status_controller: StatusController,
	new_dice_resolver: DiceResolver,
	new_base_seed: int
) -> void:
	battler_states = new_battler_states
	battlefield_state = new_battlefield_state
	status_controller = new_status_controller
	dice_resolver = new_dice_resolver
	base_seed = new_base_seed
	resolution_counter = 0


func can_affect_target(
	caster: BattlerState,
	target: BattlerState,
	ability: AbilityDefinition
) -> bool:
	if (
		caster == null
		or caster.definition == null
		or target == null
		or target.definition == null
		or ability == null
	):
		return false
	for effect: AbilityEffectDefinition in ability.effects:
		if effect is HealAbilityEffect:
			if target.current_hp < target.get_max_hp():
				return true
			continue
		if effect is RemoveStatusAbilityEffect:
			if _can_remove_effect(
				target,
				effect as RemoveStatusAbilityEffect
			):
				return true
			continue
		if effect is ApplyStatusAbilityEffect:
			if (effect as ApplyStatusAbilityEffect).status != null:
				return true
			continue
		if effect is GroupHealAbilityEffect:
			if _has_group_heal_target(
				caster,
				effect as GroupHealAbilityEffect
			):
				return true
			continue
		if (
			effect is BlessAbilityEffect
			or effect is WardAbilityEffect
			or effect is AnalyzeAbilityEffect
		):
			return true
	return false


func resolve(
	caster: BattlerState,
	target: BattlerState,
	ability: AbilityDefinition,
	result: AbilityUseResult
) -> AbilityUseResult:
	if result == null:
		result = AbilityUseResult.new()
	if (
		caster == null
		or caster.definition == null
		or target == null
		or target.definition == null
		or ability == null
	):
		return result.fail("Ability effect resolution is missing combat data.")
	if ability.effects.is_empty():
		return result.fail(
			"%s has no composed effects." % ability.display_name
		)

	resolution_counter += 1
	for effect_index: int in range(ability.effects.size()):
		var effect: AbilityEffectDefinition = ability.effects[effect_index]
		if effect == null:
			return result.fail(
				"%s contains a missing effect Resource."
				% ability.display_name
			)
		var effect_error: String = _resolve_one(
			caster,
			target,
			ability,
			effect,
			result,
			_effect_seed(effect_index)
		)
		if not effect_error.is_empty():
			return result.fail(effect_error)

	result.succeeded = true
	return result


func _resolve_one(
	caster: BattlerState,
	target: BattlerState,
	ability: AbilityDefinition,
	effect: AbilityEffectDefinition,
	result: AbilityUseResult,
	seed_value: int
) -> String:
	if effect is AttackAbilityEffect:
		return (
			"%s's Attack effect must use the shared AttackResolver."
			% ability.display_name
		)
	if effect is HealAbilityEffect:
		_resolve_heal(
			caster,
			target,
			ability,
			effect as HealAbilityEffect,
			result,
			seed_value
		)
		return ""
	if effect is RemoveStatusAbilityEffect:
		_resolve_removal(
			caster,
			target,
			ability,
			effect as RemoveStatusAbilityEffect,
			result
		)
		return ""
	if effect is ApplyStatusAbilityEffect:
		_resolve_status_application(
			caster,
			target,
			ability,
			effect as ApplyStatusAbilityEffect,
			result,
			seed_value
		)
		return ""
	if effect is BlessAbilityEffect:
		var blessing: BlessAbilityEffect = effect as BlessAbilityEffect
		target.apply_bless(maxi(blessing.minimum_damage, 1))
		result.effect_amount += maxi(blessing.minimum_damage, 1)
		result.append_log(
			"%s blesses %s. Their next Attack deals at least %d damage."
			% [
				caster.definition.display_name,
				target.definition.display_name,
				maxi(blessing.minimum_damage, 1),
			]
		)
		return ""
	if effect is WardAbilityEffect:
		var ward: WardAbilityEffect = effect as WardAbilityEffect
		if ward.unique_per_faction:
			_remove_existing_faction_wards(caster)
		target.apply_ward(maxi(ward.defense_dice_bonus, 1))
		result.effect_amount += maxi(ward.defense_dice_bonus, 1)
		result.append_log(
			"%s wards %s: +%dd10 on the next Defense Check."
			% [
				caster.definition.display_name,
				target.definition.display_name,
				maxi(ward.defense_dice_bonus, 1),
			]
		)
		return ""
	if effect is AnalyzeAbilityEffect:
		var analysis: AnalyzeAbilityEffect = effect as AnalyzeAbilityEffect
		caster.set_analyzed_target(target.definition.battler_id)
		result.effect_amount += maxi(
			analysis.ignored_defense_successes,
			1
		)
		result.append_log(
			"%s uses %s on %s. The next qualifying Attack ignores %d Defense success."
			% [
				caster.definition.display_name,
				ability.display_name,
				target.definition.display_name,
				maxi(analysis.ignored_defense_successes, 1),
			]
		)
		return ""
	if effect is GroupHealAbilityEffect:
		_resolve_group_heal(
			caster,
			ability,
			effect as GroupHealAbilityEffect,
			result
		)
		return ""
	return (
		"%s uses an unsupported effect Resource: %s."
		% [ability.display_name, effect.get_class()]
	)


func _resolve_heal(
	caster: BattlerState,
	target: BattlerState,
	ability: AbilityDefinition,
	effect: HealAbilityEffect,
	result: AbilityUseResult,
	seed_value: int
) -> void:
	var healing_amount: int = maxi(effect.fixed_amount, 0)
	var check: RollResult
	if effect.uses_check_successes:
		check = _roll_check(
			caster,
			effect.skill,
			effect.attribute,
			effect.dice_modifier,
			seed_value
		)
		healing_amount += check.total_successes
		healing_amount = maxi(healing_amount, effect.minimum_amount)
	var restored: int = target.heal(healing_amount)
	result.effect_amount += restored
	if check != null:
		result.append_log(
			"%s casts %s on %s: %d success%s restore%s %d HP."
			% [
				caster.definition.display_name,
				ability.display_name,
				target.definition.display_name,
				check.total_successes,
				"" if check.total_successes == 1 else "es",
				"s" if check.total_successes == 1 else "",
				restored,
			]
		)
	else:
		result.append_log(
			"%s casts %s on %s: restores %d HP."
			% [
				caster.definition.display_name,
				ability.display_name,
				target.definition.display_name,
				restored,
			]
		)


func _resolve_removal(
	caster: BattlerState,
	target: BattlerState,
	ability: AbilityDefinition,
	effect: RemoveStatusAbilityEffect,
	result: AbilityUseResult
) -> void:
	var removed_name: String = ""
	match effect.removal_mode:
		RemoveStatusAbilityEffect.RemovalMode.ONE_STATUS_KIND:
			var removed_count: int = status_controller.remove_one_status_kind(
				target,
				effect.status_kind
			)
			if removed_count > 0:
				removed_name = _status_kind_name(effect.status_kind)
		RemoveStatusAbilityEffect.RemovalMode.ONE_REMOVABLE_MAGIC_EFFECT:
			removed_name = status_controller.remove_one_removable_magic_effect(
				target
			)
			if removed_name.is_empty() and target.blessed_minimum_damage > 0:
				target.consume_bless()
				removed_name = "Bless"
			if removed_name.is_empty() and target.ward_dice_bonus > 0:
				target.consume_ward()
				removed_name = "Ward"
	if not removed_name.is_empty():
		result.effect_amount += 1
	result.append_log(
		"%s casts %s on %s: removes %s."
		% [
			caster.definition.display_name,
			ability.display_name,
			target.definition.display_name,
			removed_name if not removed_name.is_empty() else "nothing",
		]
	)


func _resolve_status_application(
	caster: BattlerState,
	target: BattlerState,
	ability: AbilityDefinition,
	effect: ApplyStatusAbilityEffect,
	result: AbilityUseResult,
	seed_value: int
) -> void:
	if effect.status == null:
		return
	if effect.requires_opposed_check:
		var casting_roll: RollResult = _roll_check(
			caster,
			effect.casting_skill,
			effect.casting_attribute,
			effect.casting_dice_modifier,
			seed_value
		)
		var resistance_roll: RollResult = _roll_check(
			target,
			effect.resistance_skill,
			effect.resistance_attribute,
			effect.resistance_dice_modifier,
			seed_value + 1
		)
		if casting_roll.total_successes <= resistance_roll.total_successes:
			result.append_log(
				"%s resists %s (%d vs %d successes)."
				% [
					target.definition.display_name,
					ability.display_name,
					resistance_roll.total_successes,
					casting_roll.total_successes,
				]
			)
			return
	var application: StatusApplicationResult = status_controller.apply_status(
		target,
		effect.status,
		caster.definition.battler_id,
		effect.damage_override,
		effect.tick_override,
		1 if effect.status_is_magical else 0,
		1 if effect.status_is_dispellable else 0
	)
	if not application.succeeded:
		result.append_log(
			"%s failed to apply %s: %s"
			% [
				ability.display_name,
				effect.status.display_name,
				application.error_message,
			]
		)
		return
	result.effect_amount += 1
	result.append_log(
		"%s casts %s on %s: applies %s for %d ticks."
		% [
			caster.definition.display_name,
			ability.display_name,
			target.definition.display_name,
			effect.status.display_name,
			application.instance.total_ticks,
		]
	)


func _resolve_group_heal(
	caster: BattlerState,
	ability: AbilityDefinition,
	effect: GroupHealAbilityEffect,
	result: AbilityUseResult
) -> void:
	caster.apply_damage(effect.self_hp_cost)
	var caster_anchor: AnchorDefinition = battlefield_state.get_battler_anchor(
		caster.definition.battler_id
	)
	var healed_total: int = 0
	for state_value: Variant in battler_states.values():
		var ally: BattlerState = state_value as BattlerState
		if (
			ally == null
			or ally.definition == null
			or ally.is_defeated
			or ally.definition.faction != caster.definition.faction
			or (effect.excludes_caster and ally == caster)
		):
			continue
		if effect.requires_same_zone:
			var ally_anchor: AnchorDefinition = (
				battlefield_state.get_battler_anchor(
					ally.definition.battler_id
				)
			)
			if (
				caster_anchor == null
				or ally_anchor == null
				or caster_anchor.zone_id != ally_anchor.zone_id
			):
				continue
		healed_total += ally.heal(effect.healing_per_ally)
	result.effect_amount += healed_total
	result.append_log(
		"%s uses %s: sacrifices %d HP and restores %d allied HP."
		% [
			caster.definition.display_name,
			ability.display_name,
			effect.self_hp_cost,
			healed_total,
		]
	)


func _roll_check(
	state: BattlerState,
	skill: SkillEntry.Skill,
	attribute: AttributeSet.Attribute,
	dice_modifier: int,
	seed_value: int
) -> RollResult:
	var dice_count: int = maxi(
		state.definition.attributes.get_value(attribute) + dice_modifier,
		0
	)
	var entry: SkillEntry = state.definition.get_skill_entry(skill)
	return dice_resolver.roll_check(
		dice_count,
		entry.level if entry != null else 0,
		entry.tier if entry != null else SkillEntry.Tier.UNTRAINED,
		seed_value
	)


func _can_remove_effect(
	target: BattlerState,
	effect: RemoveStatusAbilityEffect
) -> bool:
	match effect.removal_mode:
		RemoveStatusAbilityEffect.RemovalMode.ONE_STATUS_KIND:
			return target.has_status_kind(effect.status_kind)
		RemoveStatusAbilityEffect.RemovalMode.ONE_REMOVABLE_MAGIC_EFFECT:
			return (
				status_controller.has_removable_magic_effect(target)
				or target.blessed_minimum_damage > 0
				or target.ward_dice_bonus > 0
			)
	return false


func _has_group_heal_target(
	caster: BattlerState,
	effect: GroupHealAbilityEffect
) -> bool:
	var caster_anchor: AnchorDefinition = battlefield_state.get_battler_anchor(
		caster.definition.battler_id
	)
	for state_value: Variant in battler_states.values():
		var ally: BattlerState = state_value as BattlerState
		if (
			ally == null
			or ally.definition == null
			or ally.is_defeated
			or ally.definition.faction != caster.definition.faction
			or ally.current_hp >= ally.get_max_hp()
			or (effect.excludes_caster and ally == caster)
		):
			continue
		if not effect.requires_same_zone:
			return true
		var ally_anchor: AnchorDefinition = battlefield_state.get_battler_anchor(
			ally.definition.battler_id
		)
		if (
			caster_anchor != null
			and ally_anchor != null
			and caster_anchor.zone_id == ally_anchor.zone_id
		):
			return true
	return false


func _remove_existing_faction_wards(
	caster: BattlerState
) -> void:
	for state_value: Variant in battler_states.values():
		var warded: BattlerState = state_value as BattlerState
		if (
			warded != null
			and warded.definition != null
			and warded.definition.faction == caster.definition.faction
			and warded.ward_dice_bonus > 0
		):
			warded.consume_ward()


func _effect_seed(
	effect_index: int
) -> int:
	return (
		base_seed
		+ resolution_counter * 101
		+ effect_index * 2
	)


func _status_kind_name(
	kind: StatusDefinition.Kind
) -> String:
	match kind:
		StatusDefinition.Kind.BLEED:
			return "Bleed"
		StatusDefinition.Kind.POISON:
			return "Poison"
		StatusDefinition.Kind.SLOW:
			return "Slow"
		StatusDefinition.Kind.STUNNED:
			return "Stunned"
		StatusDefinition.Kind.BURNING:
			return "Burning"
		StatusDefinition.Kind.REGENERATION:
			return "Regeneration"
	return "Status"
