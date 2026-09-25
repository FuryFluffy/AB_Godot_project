class_name AoeActionController
extends RefCounted


var battler_states: Dictionary = {}
var stable_battler_order: Array[StringName] = []
var runtime: BattleRuntimeState
var battlefield_state: BattlefieldState
var battle_flow_controller: BattleFlowController
var attack_resolver: AttackResolver
var attack_seed: int = 1


func initialize(
	new_battler_states: Dictionary,
	new_stable_battler_order: Array[StringName],
	new_runtime: BattleRuntimeState,
	new_battlefield_state: BattlefieldState,
	new_battle_flow_controller: BattleFlowController,
	new_attack_resolver: AttackResolver,
	new_attack_seed: int
) -> void:
	battler_states = new_battler_states
	stable_battler_order = new_stable_battler_order.duplicate()
	runtime = new_runtime
	battlefield_state = new_battlefield_state
	battle_flow_controller = new_battle_flow_controller
	attack_resolver = new_attack_resolver
	attack_seed = new_attack_seed


func get_first_usable_aoe_ability(
	caster: BattlerState
) -> AbilityDefinition:
	if caster == null or caster.definition == null:
		return null

	for ability: AbilityDefinition in caster.get_available_abilities():
		if (
			ability != null
			and ability.targeting_mode
			== AbilityDefinition.TargetingMode.BATTLE_ZONE
			and caster.current_mp >= ability.mp_cost
		):
			return ability

	return null


func begin_zone_targeting(
	caster_id: StringName,
	ability: AbilityDefinition
) -> Array[StringName]:
	var legal_zone_ids: Array[StringName] = []
	if runtime == null:
		return legal_zone_ids

	var caster: BattlerState = _get_battler_state(caster_id)
	var validation_error: String = _validate_caster(caster, ability)
	if not validation_error.is_empty():
		return legal_zone_ids

	legal_zone_ids = get_legal_zone_ids(caster, ability)
	if legal_zone_ids.is_empty():
		return legal_zone_ids

	runtime.begin_aoe_targeting(caster_id, ability)
	return legal_zone_ids


func get_legal_zone_ids(
	caster: BattlerState,
	ability: AbilityDefinition
) -> Array[StringName]:
	var legal_zone_ids: Array[StringName] = []
	if (
		caster == null
		or caster.definition == null
		or ability == null
		or battlefield_state == null
		or battlefield_state.definition == null
	):
		return legal_zone_ids

	var caster_anchor: AnchorDefinition = (
		battlefield_state.get_battler_anchor(
			caster.definition.battler_id
		)
	)
	if caster_anchor == null:
		return legal_zone_ids

	for zone: BattleZoneDefinition in (
		battlefield_state.definition.zones
	):
		if zone == null:
			continue

		var distance: int = battlefield_state.get_zone_distance(
			caster_anchor.zone_id,
			zone.zone_id
		)
		if (
			distance < 0
			or distance > ability.maximum_zone_distance
		):
			continue

		if not _get_targets_in_zone(
			caster,
			ability,
			zone.zone_id
		).is_empty():
			legal_zone_ids.append(zone.zone_id)

	return legal_zone_ids


func commit_zone(
	zone_id: StringName
) -> ReactionContext:
	if (
		runtime == null
		or not runtime.is_selecting_aoe
		or runtime.pending_aoe_ability == null
	):
		return ReactionContext.new().fail(
			"No AOE zone selection is active."
		)

	var caster: BattlerState = _get_battler_state(
		runtime.pending_aoe_caster_id
	)
	var ability: AbilityDefinition = runtime.pending_aoe_ability
	var validation_error: String = _validate_caster(
		caster,
		ability
	)
	if not validation_error.is_empty():
		runtime.cancel_aoe_targeting()
		return ReactionContext.new().fail(validation_error)

	var legal_zone_ids: Array[StringName] = get_legal_zone_ids(
		caster,
		ability
	)
	if not legal_zone_ids.has(zone_id):
		return ReactionContext.new().fail(
			"The selected BattleZone is not a legal AOE target."
		)

	var target_ids: Array[StringName] = _get_targets_in_zone(
		caster,
		ability,
		zone_id
	)
	if target_ids.is_empty():
		return ReactionContext.new().fail(
			"The selected BattleZone has no affected targets."
		)

	var aoe_state: AoeResolutionState = AoeResolutionState.new()
	aoe_state.is_valid = true
	aoe_state.caster_id = caster.definition.battler_id
	aoe_state.zone_id = zone_id
	aoe_state.ability = ability
	aoe_state.attack_profile = ability.create_attack_profile()
	aoe_state.target_ids = target_ids

	if not caster.spend_mp(ability.mp_cost):
		return ReactionContext.new().fail(
			"%s could not spend %d MP."
			% [
				caster.definition.display_name,
				ability.mp_cost,
			]
		)

	aoe_state.mp_was_spent = ability.mp_cost > 0
	runtime.store_active_aoe(aoe_state)

	var context: ReactionContext = prepare_next_target()
	if not context.is_valid:
		if aoe_state.mp_was_spent:
			caster.restore_mp(ability.mp_cost)
		runtime.clear_active_aoe()
		return context

	return context


func prepare_next_target() -> ReactionContext:
	if (
		runtime == null
		or runtime.active_aoe == null
		or not runtime.active_aoe.is_valid
	):
		return ReactionContext.new().fail(
			"No committed AOE is active."
		)

	var aoe_state: AoeResolutionState = runtime.active_aoe
	var caster: BattlerState = _get_battler_state(
		aoe_state.caster_id
	)
	if (
		caster == null
		or caster.definition == null
		or caster.is_defeated
	):
		return ReactionContext.new().fail(
			"The AOE caster is defeated or missing."
		)

	while aoe_state.has_remaining_targets():
		var target_id: StringName = aoe_state.get_next_target_id()
		var target: BattlerState = _get_battler_state(target_id)
		if (
			target == null
			or target.definition == null
			or target.is_defeated
		):
			aoe_state.next_target_index += 1
			continue

		var is_first_target: bool = (
			aoe_state.shared_attack_roll == null
		)
		var request: ActionRequest = ActionRequest.new(
			aoe_state.caster_id,
			target_id,
			aoe_state.attack_profile,
			attack_seed,
			not is_first_target,
			aoe_state.ability.is_magic,
			0,
			ActionRequest.Source.AOE,
			ActionRequest.ReactionMode.DEFENSE_ONLY
		)
		request.ability = aoe_state.ability
		request.permits_parry = aoe_state.ability.can_be_parried
		request.qualifies_for_analysis = (
			aoe_state.ability.qualifies_for_analysis
		)
		request.ignore_one_defense_success = (
			aoe_state.ability.qualifies_for_analysis
			and caster.has_analyzed_target(target_id)
		)
		request.action_cost = (
			aoe_state.ability.action_cost
			if is_first_target
			else 0
		)
		request.shared_attack_roll = aoe_state.shared_attack_roll
		request.spatial_range_label = (
			"BattleZone: %s"
			% _get_zone_name(aoe_state.zone_id)
		)

		var context: ReactionContext = attack_resolver.prepare_attack(
			request,
			caster,
			target
		)
		if not context.is_valid:
			return context

		if aoe_state.shared_attack_roll == null:
			aoe_state.shared_attack_roll = context.attack_roll
			# One AOE owns one shared roll. Advance only after creating that
			# roll so every target still resolves against the same result.
			attack_seed += 1

		aoe_state.current_target_id = target_id
		runtime.store_pending_reaction(context, target_id)
		return context

	return ReactionContext.new().fail(
		"The committed AOE has no remaining living targets."
	)


func complete_current_target() -> void:
	if runtime != null and runtime.active_aoe != null:
		runtime.active_aoe.mark_current_target_complete()


func finish_active_aoe() -> AoeResolutionState:
	if runtime == null:
		return null

	var completed: AoeResolutionState = runtime.active_aoe
	runtime.clear_active_aoe()
	return completed


func cancel_zone_targeting() -> void:
	if runtime != null:
		runtime.cancel_aoe_targeting()


func _validate_caster(
	caster: BattlerState,
	ability: AbilityDefinition
) -> String:
	if caster == null or caster.definition == null:
		return "No valid AOE caster is selected."
	if ability == null:
		return "%s has no usable AOE ability." % (
			caster.definition.display_name
		)
	if ability.targeting_mode != AbilityDefinition.TargetingMode.BATTLE_ZONE:
		return "%s is not a BattleZone-targeted ability." % (
			ability.display_name
		)
	if battle_flow_controller == null:
		return "BattleFlowController is missing."

	var phase_error: String = (
		battle_flow_controller.validate_active_actor(caster)
	)
	if not phase_error.is_empty():
		return phase_error
	if caster.is_defeated or caster.is_stunned():
		return "%s cannot use an AOE now." % (
			caster.definition.display_name
		)
	if caster.current_actions < ability.action_cost:
		return "%s does not have enough Actions." % (
			caster.definition.display_name
		)
	if caster.current_mp < ability.mp_cost:
		return "%s does not have enough MP." % (
			caster.definition.display_name
		)

	return ""


func _get_targets_in_zone(
	caster: BattlerState,
	ability: AbilityDefinition,
	zone_id: StringName
) -> Array[StringName]:
	var target_ids: Array[StringName] = []
	for battler_id: StringName in stable_battler_order:
		var target: BattlerState = _get_battler_state(battler_id)
		if (
			target == null
			or target.definition == null
			or target.is_defeated
			or target == caster
		):
			continue

		if (
			not ability.affects_allies
			and target.definition.faction
			== caster.definition.faction
		):
			continue

		var target_anchor: AnchorDefinition = (
			battlefield_state.get_battler_anchor(battler_id)
		)
		if target_anchor == null or target_anchor.zone_id != zone_id:
			continue

		if (
			ability.requires_line_of_sight
			and not battlefield_state.has_line_of_sight(
				caster.definition.battler_id,
				battler_id
			)
		):
			continue

		target_ids.append(battler_id)

	return target_ids


func _get_zone_name(
	zone_id: StringName
) -> String:
	if battlefield_state == null or battlefield_state.definition == null:
		return String(zone_id)

	var zone: BattleZoneDefinition = (
		battlefield_state.definition.get_zone(zone_id)
	)
	return (
		zone.display_name
		if zone != null
		else String(zone_id)
	)


func _get_battler_state(
	battler_id: StringName
) -> BattlerState:
	return battler_states.get(battler_id) as BattlerState
