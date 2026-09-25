class_name AbilityActionController
extends RefCounted


var battler_states: Dictionary = {}
var runtime: BattleRuntimeState
var battle_flow_controller: BattleFlowController
var battlefield_state: BattlefieldState
var targeting_controller: BattleTargetingController
var attack_resolver: AttackResolver
var status_controller: StatusController
var effect_resolver: AbilityEffectResolver
var attack_seed: int = 1


func initialize(
	new_battler_states: Dictionary,
	new_runtime: BattleRuntimeState,
	new_battle_flow_controller: BattleFlowController,
	new_battlefield_state: BattlefieldState,
	new_targeting_controller: BattleTargetingController,
	new_attack_resolver: AttackResolver,
	new_status_controller: StatusController,
	new_dice_resolver: DiceResolver,
	new_attack_seed: int
) -> void:
	battler_states = new_battler_states
	runtime = new_runtime
	battle_flow_controller = new_battle_flow_controller
	battlefield_state = new_battlefield_state
	targeting_controller = new_targeting_controller
	attack_resolver = new_attack_resolver
	status_controller = new_status_controller
	effect_resolver = AbilityEffectResolver.new()
	effect_resolver.initialize(
		battler_states,
		battlefield_state,
		status_controller,
		new_dice_resolver,
		new_attack_seed + 500
	)
	attack_seed = new_attack_seed


func get_active_abilities(
	caster_id: StringName
) -> Array[AbilityDefinition]:
	var active: Array[AbilityDefinition] = []
	var caster: BattlerState = _get_battler(caster_id)
	if caster == null or caster.definition == null:
		return active
	for ability: AbilityDefinition in caster.get_available_abilities():
		if ability != null and not ability.is_passive():
			active.append(ability)
	return active


func get_availability_reason(
	caster_id: StringName,
	ability: AbilityDefinition
) -> String:
	var caster: BattlerState = _get_battler(caster_id)
	if caster == null or caster.definition == null:
		return "No valid ability user is selected."
	if ability == null:
		return "The selected ability is missing."
	if (
		ability.requires_progression_unlock
		and caster.get_ability(ability.ability_id) == null
	):
		return "%s has not learned %s." % [
			caster.definition.display_name,
			ability.display_name,
		]
	if ability.is_passive():
		return "%s is passive." % ability.display_name
	if ability.effects.is_empty():
		return "%s has no effect Resources." % ability.display_name
	if battle_flow_controller == null:
		return "Battle flow is missing."
	var phase_error: String = battle_flow_controller.validate_active_actor(caster)
	if not phase_error.is_empty():
		return phase_error
	if caster.is_defeated:
		return "%s is defeated." % caster.definition.display_name
	if caster.is_grappled():
		return "%s cannot use active abilities while grappled." % (
			caster.definition.display_name
		)
	if not ability.required_weapon_family_id.is_empty():
		var weapon: WeaponDefinition = (
			caster.get_usable_main_hand_weapon()
		)
		if (
			weapon == null
			or not weapon.is_family(
				ability.required_weapon_family_id
			)
		):
			return "%s requires an equipped %s-family weapon." % [
				ability.display_name,
				String(ability.required_weapon_family_id).capitalize(),
			]
		if (
			caster.get_main_hand_weapon_rank()
			< ability.minimum_weapon_family_rank
		):
			return "%s requires %s Rank %d." % [
				ability.display_name,
				weapon.family.display_name,
				ability.minimum_weapon_family_rank,
			]
	if caster.current_actions < ability.action_cost:
		return "%s needs %d Action." % [
			ability.display_name,
			ability.action_cost,
		]
	if caster.current_mp < ability.mp_cost:
		return "%s needs %d MP." % [
			ability.display_name,
			ability.mp_cost,
		]
	if (
		ability.get_self_hp_cost() > 0
		and caster.current_hp <= ability.get_self_hp_cost()
	):
		return "%s needs more than %d HP." % [
			ability.display_name,
			ability.get_self_hp_cost(),
		]
	return ""


func get_legal_target_ids(
	caster_id: StringName,
	ability: AbilityDefinition
) -> Array[StringName]:
	var legal_ids: Array[StringName] = []
	var caster: BattlerState = _get_battler(caster_id)
	if caster == null or caster.definition == null or ability == null:
		return legal_ids
	if not get_availability_reason(caster_id, ability).is_empty():
		return legal_ids
	if ability.targeting_mode == AbilityDefinition.TargetingMode.SELF:
		legal_ids.append(caster_id)
		return legal_ids
	if ability.targeting_mode == AbilityDefinition.TargetingMode.BATTLE_ZONE:
		return legal_ids

	for target_value: Variant in battler_states.values():
		var target: BattlerState = target_value as BattlerState
		if not _is_legal_target(caster, target, ability):
			continue
		if runtime.pending_ability_target_ids.has(
			target.definition.battler_id
		):
			continue
		legal_ids.append(target.definition.battler_id)

	legal_ids.sort()
	return legal_ids


func begin_targeting(
	caster_id: StringName,
	ability: AbilityDefinition
) -> Array[StringName]:
	var legal_ids: Array[StringName] = get_legal_target_ids(
		caster_id,
		ability
	)
	var minimum_target_count: int = (
		ability.required_target_count if ability != null else 1
	)
	if (
		ability != null
		and ability.allows_fewer_targets_when_unavailable
	):
		minimum_target_count = 1
	if (
		runtime != null
		and legal_ids.size() >= minimum_target_count
	):
		runtime.begin_ability_targeting(caster_id, ability)
	else:
		legal_ids.clear()
	return legal_ids


func commit_target(
	target_id: StringName
) -> Variant:
	if (
		runtime == null
		or not runtime.is_selecting_ability_target
		or runtime.pending_ability == null
	):
		return AbilityUseResult.new().fail(
			"No targeted ability is active."
		)

	var caster_id: StringName = runtime.pending_ability_caster_id
	var ability: AbilityDefinition = runtime.pending_ability
	var legal_ids: Array[StringName] = get_legal_target_ids(
		caster_id,
		ability
	)
	if not legal_ids.has(target_id):
		return AbilityUseResult.new().fail(
			"That combatant is not a legal target for %s."
			% ability.display_name
		)

	if ability.required_target_count > 1:
		runtime.add_pending_ability_target(target_id)
		var remaining_legal_ids: Array[StringName] = (
			get_legal_target_ids(caster_id, ability)
		)
		if (
			runtime.pending_ability_target_ids.size()
			< ability.required_target_count
			and not remaining_legal_ids.is_empty()
		):
			var selection: AbilityTargetSelectionResult = (
				AbilityTargetSelectionResult.new()
			)
			selection.succeeded = true
			selection.selected_target_ids = (
				runtime.pending_ability_target_ids.duplicate()
			)
			selection.legal_target_ids = remaining_legal_ids
			selection.remaining_target_count = (
				ability.required_target_count
				- selection.selected_target_ids.size()
			)
			return selection
		return _prepare_multi_target_attack(
			caster_id,
			ability,
			runtime.pending_ability_target_ids.duplicate()
		)

	if ability.is_attack():
		return _prepare_attack(caster_id, target_id, ability)
	return _resolve_direct_effect(caster_id, target_id, ability)


func use_self_ability(
	caster_id: StringName,
	ability: AbilityDefinition
) -> AbilityUseResult:
	if ability == null or (
		ability.targeting_mode
		!= AbilityDefinition.TargetingMode.SELF
	):
		return AbilityUseResult.new().fail(
			"The selected ability is not self-targeted."
		)
	return _resolve_direct_effect(caster_id, caster_id, ability)


func cancel_targeting() -> void:
	if runtime != null:
		runtime.cancel_ability_targeting()


func _prepare_attack(
	caster_id: StringName,
	target_id: StringName,
	ability: AbilityDefinition
) -> ReactionContext:
	var caster: BattlerState = _get_battler(caster_id)
	var target: BattlerState = _get_battler(target_id)
	var availability: String = get_availability_reason(
		caster_id,
		ability
	)
	if not availability.is_empty():
		return ReactionContext.new().fail(availability)

	var profile: WeaponDefinition = _create_attack_profile(caster, ability)
	if profile == null:
		return ReactionContext.new().fail(
			"%s has no Attack effect Resource." % ability.display_name
		)
	var targeting: AttackTargetingResult = targeting_controller.evaluate_attack(
		caster_id,
		target_id,
		profile,
		ability.is_magic,
		caster.get_main_hand_weapon_rank()
	)
	if not targeting.is_legal:
		return ReactionContext.new().fail(targeting.error_message)
	if not caster.spend_mp(ability.mp_cost):
		return ReactionContext.new().fail(
			"%s could not spend %d MP." % [
				caster.definition.display_name,
				ability.mp_cost,
			]
		)

	var request: ActionRequest = ActionRequest.new(
		caster_id,
		target_id,
		profile,
		attack_seed,
		false,
		ability.is_magic,
		0,
		ActionRequest.Source.ABILITY,
		ActionRequest.ReactionMode.FULL
	)
	request.ability = ability
	request.weapon_family_rank = caster.get_main_hand_weapon_rank()
	request.permits_parry = ability.can_be_parried
	request.action_cost = ability.action_cost
	request.spatial_range_label = targeting.spatial_range_label
	request.attack_dice_modifier = targeting.attack_dice_modifier
	request.suppress_skill_modification = (
		targeting.suppress_skill_modification
	)
	request.qualifies_for_analysis = ability.qualifies_for_analysis
	request.ignore_one_defense_success = (
		ability.qualifies_for_analysis
		and caster.has_analyzed_target(target_id)
	)

	var context: ReactionContext = attack_resolver.prepare_attack(
		request,
		caster,
		target
	)
	if not context.is_valid:
		caster.restore_mp(ability.mp_cost)
		return context
	# Repeated casts use a deterministic sequence, not the same roll again.
	attack_seed += 1
	runtime.cancel_ability_targeting()
	runtime.store_pending_reaction(context, target_id)
	return context


func _prepare_multi_target_attack(
	caster_id: StringName,
	ability: AbilityDefinition,
	target_ids: Array[StringName]
) -> ReactionContext:
	var caster: BattlerState = _get_battler(caster_id)
	var availability: String = get_availability_reason(
		caster_id,
		ability
	)
	if not availability.is_empty():
		return ReactionContext.new().fail(availability)
	var has_allowed_partial_count: bool = (
		ability.allows_fewer_targets_when_unavailable
		and target_ids.size() >= 1
		and target_ids.size() <= ability.required_target_count
	)
	if (
		target_ids.size() != ability.required_target_count
		and not has_allowed_partial_count
	):
		return ReactionContext.new().fail(
			"%s requires %d distinct targets." % [
				ability.display_name,
				ability.required_target_count,
			]
		)
	var unique_targets: Dictionary = {}
	for target_id: StringName in target_ids:
		if unique_targets.has(target_id):
			return ReactionContext.new().fail(
				"%s cannot target the same combatant twice."
				% ability.display_name
			)
		unique_targets[target_id] = true

	var profile: WeaponDefinition = _create_attack_profile(caster, ability)
	if profile == null:
		return ReactionContext.new().fail(
			"%s has no Attack effect Resource." % ability.display_name
		)
	for target_id: StringName in target_ids:
		var target: BattlerState = _get_battler(target_id)
		if not _is_legal_target(caster, target, ability):
			return ReactionContext.new().fail(
				"%s is not a legal target for %s." % [
					(
						target.definition.display_name
						if target != null and target.definition != null
						else String(target_id)
					),
					ability.display_name,
				]
			)

	if not caster.spend_mp(ability.mp_cost):
		return ReactionContext.new().fail(
			"%s could not spend %d MP." % [
				caster.definition.display_name,
				ability.mp_cost,
			]
		)

	var state: MultiTargetAttackState = MultiTargetAttackState.new()
	state.is_valid = true
	state.caster_id = caster_id
	state.ability = ability
	state.attack_profile = profile
	state.target_ids = target_ids.duplicate()
	state.mp_was_spent = ability.mp_cost > 0
	runtime.store_active_multi_target_attack(state)

	var context: ReactionContext = prepare_next_multi_target_attack()
	if not context.is_valid:
		if state.mp_was_spent:
			caster.restore_mp(ability.mp_cost)
		runtime.clear_active_multi_target_attack()
	return context


func prepare_next_multi_target_attack() -> ReactionContext:
	if (
		runtime == null
		or runtime.active_multi_target_attack == null
		or not runtime.active_multi_target_attack.is_valid
	):
		return ReactionContext.new().fail(
			"No committed multi-target weapon art is active."
		)
	var state: MultiTargetAttackState = (
		runtime.active_multi_target_attack
	)
	var caster: BattlerState = _get_battler(state.caster_id)
	if (
		caster == null
		or caster.definition == null
		or caster.is_defeated
	):
		return ReactionContext.new().fail(
			"The weapon-art user is defeated or missing."
		)

	while state.has_remaining_targets():
		var target_id: StringName = state.get_next_target_id()
		var target: BattlerState = _get_battler(target_id)
		if (
			target == null
			or target.definition == null
			or target.is_defeated
		):
			state.next_target_index += 1
			continue
		var targeting: AttackTargetingResult = (
			targeting_controller.evaluate_attack(
				state.caster_id,
				target_id,
				state.attack_profile,
				state.ability.is_magic,
				caster.get_main_hand_weapon_rank()
			)
		)
		if not targeting.is_legal:
			state.next_target_index += 1
			continue

		var is_first_target: bool = state.next_target_index == 0
		var request: ActionRequest = ActionRequest.new(
			state.caster_id,
			target_id,
			state.attack_profile,
			attack_seed,
			not is_first_target,
			state.ability.is_magic,
			0,
			ActionRequest.Source.ABILITY,
			ActionRequest.ReactionMode.FULL
		)
		request.ability = state.ability
		request.weapon_family_rank = caster.get_main_hand_weapon_rank()
		request.permits_parry = state.ability.can_be_parried
		request.action_cost = (
			state.ability.action_cost if is_first_target else 0
		)
		request.spatial_range_label = targeting.spatial_range_label
		request.attack_dice_modifier = targeting.attack_dice_modifier
		request.suppress_skill_modification = (
			targeting.suppress_skill_modification
		)

		var context: ReactionContext = attack_resolver.prepare_attack(
			request,
			caster,
			target
		)
		if not context.is_valid:
			return context
		attack_seed += 1
		state.current_target_id = target_id
		runtime.store_pending_reaction(context, target_id)
		return context

	return ReactionContext.new().fail(
		"The committed weapon art has no remaining living targets."
	)


func complete_current_multi_target() -> void:
	if runtime != null and runtime.active_multi_target_attack != null:
		runtime.active_multi_target_attack.mark_current_target_complete()


func finish_active_multi_target_attack() -> MultiTargetAttackState:
	if runtime == null:
		return null
	var completed: MultiTargetAttackState = (
		runtime.active_multi_target_attack
	)
	runtime.clear_active_multi_target_attack()
	return completed


func _resolve_direct_effect(
	caster_id: StringName,
	target_id: StringName,
	ability: AbilityDefinition
) -> AbilityUseResult:
	var result: AbilityUseResult = AbilityUseResult.new()
	result.caster_id = caster_id
	result.target_id = target_id
	result.ability = ability
	var caster: BattlerState = _get_battler(caster_id)
	var target: BattlerState = _get_battler(target_id)
	var availability: String = get_availability_reason(
		caster_id,
		ability
	)
	if not availability.is_empty():
		return result.fail(availability)
	if not _is_legal_target(caster, target, ability):
		return result.fail(
			"That combatant is not a legal target for %s."
			% ability.display_name
		)
	if not caster.spend_actions(ability.action_cost):
		return result.fail(
			"%s could not spend %d Action." % [
				caster.definition.display_name,
				ability.action_cost,
			]
		)
	result.action_spent = ability.action_cost
	if not caster.spend_mp(ability.mp_cost):
		caster.set_current_actions(
			caster.current_actions + ability.action_cost
		)
		result.action_spent = 0
		return result.fail(
			"%s could not spend %d MP." % [
				caster.definition.display_name,
				ability.mp_cost,
			]
		)
	result.mp_spent = ability.mp_cost

	result = effect_resolver.resolve(caster, target, ability, result)
	if not result.succeeded:
		return result
	runtime.cancel_ability_targeting()
	return result


func _is_legal_target(
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
		or target.is_defeated
	):
		return false
	if target == caster and not (
		ability.can_target_self
		or ability.targeting_mode
		== AbilityDefinition.TargetingMode.SELF
	):
		return false
	match ability.targeting_mode:
		AbilityDefinition.TargetingMode.ENEMY:
			if (
				target.definition.faction
				== caster.definition.faction
			):
				return false
		AbilityDefinition.TargetingMode.ALLY:
			if (
				target.definition.faction
				!= caster.definition.faction
			):
				return false
		AbilityDefinition.TargetingMode.SELF:
			if target != caster:
				return false
		AbilityDefinition.TargetingMode.ANY:
			pass
		_:
			return false

	if ability.is_attack():
		var profile: WeaponDefinition = _create_attack_profile(caster, ability)
		if profile == null:
			return false
		return targeting_controller.evaluate_attack(
			caster.definition.battler_id,
			target.definition.battler_id,
			profile,
			ability.is_magic,
			caster.get_main_hand_weapon_rank()
		).is_legal
	if not _passes_range_rule(caster, target, ability):
		return false
	return effect_resolver.can_affect_target(caster, target, ability)


func _passes_range_rule(
	caster: BattlerState,
	target: BattlerState,
	ability: AbilityDefinition
) -> bool:
	var caster_position: BattlerPositionState = (
		battlefield_state.get_battler_position(
			caster.definition.battler_id
		)
	)
	var target_position: BattlerPositionState = (
		battlefield_state.get_battler_position(
			target.definition.battler_id
		)
	)
	if caster_position == null or target_position == null:
		return false
	if (
		ability.requires_same_anchor
		and caster_position.anchor_id != target_position.anchor_id
	):
		return false
	var caster_anchor: AnchorDefinition = battlefield_state.get_battler_anchor(
		caster.definition.battler_id
	)
	var target_anchor: AnchorDefinition = battlefield_state.get_battler_anchor(
		target.definition.battler_id
	)
	if caster_anchor == null or target_anchor == null:
		return false
	if (
		ability.requires_same_zone
		and caster_anchor.zone_id != target_anchor.zone_id
	):
		return false
	if caster_anchor.zone_id == target_anchor.zone_id:
		return true
	var distance: int = battlefield_state.get_zone_distance(
		caster_anchor.zone_id,
		target_anchor.zone_id
	)
	return (
		distance >= 0
		and distance <= ability.maximum_zone_distance
	)


func _get_battler(
	battler_id: StringName
) -> BattlerState:
	return battler_states.get(battler_id) as BattlerState


func _create_attack_profile(
	caster: BattlerState,
	ability: AbilityDefinition
) -> WeaponDefinition:
	if ability == null:
		return null
	var equipped_weapon: WeaponDefinition = (
		caster.get_usable_main_hand_weapon()
		if caster != null
		else null
	)
	return ability.create_attack_profile(equipped_weapon)
