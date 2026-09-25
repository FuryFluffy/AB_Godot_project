class_name BattleFlowController
extends RefCounted


enum OrderMode {
	SEEDED,
	FORCE_PARTY_FIRST,
	FORCE_ENEMIES_FIRST,
	FORCE_PARTY_MOMENTUM,
	FORCE_ENEMY_MOMENTUM,
}


var battler_states: Dictionary = {}
var battle_state: BattleState
var dice_resolver: DiceResolver
var order_seed: int = 1
var last_round_start_effects: Array[String] = []


func initialize(
	new_battler_states: Dictionary,
	new_battle_state: BattleState,
	new_dice_resolver: DiceResolver,
	new_order_seed: int
) -> void:
	battler_states = new_battler_states
	battle_state = new_battle_state
	dice_resolver = new_dice_resolver
	order_seed = new_order_seed


func start_encounter(
	order_mode: int = OrderMode.SEEDED
) -> String:
	if battle_state == null:
		return "BattleState is missing."
	if dice_resolver == null:
		return "DiceResolver is missing."
	if battle_state.encounter_started:
		return "The encounter has already started."

	var order_error: String = _resolve_order(order_mode)
	if not order_error.is_empty():
		return order_error

	_start_round(1)
	return ""


func end_current_phase() -> String:
	if battle_state == null:
		return "BattleState is missing."
	if not battle_state.encounter_started:
		return "The encounter has not started."
	if battle_state.phase == BattleState.Phase.COMPLETE:
		return "The battle is already complete."

	if battle_state.advance_phase():
		return ""

	_start_round(battle_state.round_number + 1)
	return ""


func validate_active_actor(
	actor: BattlerState
) -> String:
	if battle_state == null:
		return "BattleState is missing."
	if not battle_state.encounter_started:
		return "Begin the encounter before taking an Action."
	if actor == null or actor.definition == null:
		return "The acting combatant is invalid."

	var actor_side: BattleState.CombatSide = side_for_faction(
		actor.definition.faction
	)

	if actor_side == BattleState.CombatSide.NONE:
		return "%s has no active battle side." % (
			actor.definition.display_name
		)

	if not battle_state.is_side_active(actor_side):
		return "%s cannot take an Active Action during %s." % [
			actor.definition.display_name,
			battle_state.get_phase_label(),
		]

	if battle_state.is_side_momentum_locked(actor_side):
		return "%s has no opening Actions because of Momentum." % (
			actor.definition.display_name
		)
	if actor.is_stunned():
		return "%s is Stunned and cannot take Active Actions." % (
			actor.definition.display_name
		)

	return ""


func side_for_faction(
	faction: BattlerDefinition.Faction
) -> BattleState.CombatSide:
	match faction:
		BattlerDefinition.Faction.HEROINE:
			return BattleState.CombatSide.HEROES
		BattlerDefinition.Faction.ENEMY:
			return BattleState.CombatSide.ENEMIES

	return BattleState.CombatSide.NONE


func _resolve_order(
	order_mode: int
) -> String:
	match order_mode:
		OrderMode.SEEDED:
			return _resolve_seeded_order()
		OrderMode.FORCE_PARTY_FIRST:
			battle_state.set_order(5, 4, {}, true)
		OrderMode.FORCE_ENEMIES_FIRST:
			battle_state.set_order(4, 5, {}, true)
		OrderMode.FORCE_PARTY_MOMENTUM:
			battle_state.set_order(6, 3, {}, true)
		OrderMode.FORCE_ENEMY_MOMENTUM:
			battle_state.set_order(3, 6, {}, true)
		_:
			return "Unknown Order test mode."

	return ""


func _resolve_seeded_order() -> String:
	var heroine_ids: Array[StringName] = []
	var highest_enemy_order: int = 0

	for state_value: Variant in battler_states.values():
		var state: BattlerState = state_value as BattlerState
		if state == null or state.definition == null:
			continue

		match state.definition.faction:
			BattlerDefinition.Faction.HEROINE:
				heroine_ids.append(
					state.definition.battler_id
				)
			BattlerDefinition.Faction.ENEMY:
				highest_enemy_order = maxi(
					highest_enemy_order,
					state.definition.order_value
				)

	if heroine_ids.is_empty():
		return "Order requires at least one heroine."

	heroine_ids.sort()

	var party_total: int = 0
	var party_rolls: Dictionary = {}

	for heroine_index: int in range(heroine_ids.size()):
		var heroine: BattlerState = battler_states.get(
			heroine_ids[heroine_index]
		) as BattlerState

		if (
			heroine == null
			or heroine.definition == null
			or heroine.definition.attributes == null
		):
			return "A heroine is missing an AttributeSet for Order."

		var agility: int = heroine.definition.attributes.get_value(
			AttributeSet.Attribute.AGILITY
		)
		var roll: RollResult = dice_resolver.roll_attribute(
			agility,
			order_seed + heroine_index
		)

		party_rolls[heroine.definition.battler_id] = roll
		party_total += roll.total_successes

	battle_state.set_order(
		party_total,
		highest_enemy_order,
		party_rolls,
		false
	)
	return ""


func _start_round(
	new_round_number: int
) -> void:
	last_round_start_effects.clear()
	for state_value: Variant in battler_states.values():
		var state: BattlerState = state_value as BattlerState
		if state != null:
			state.restore_actions_to_maximum()
			if (
				state.definition != null
				and state.definition.has_specialty(
					SpecialtyEntry.Specialty.MEDITATION
				)
			):
				var restored_mp: int = state.restore_mp(1)
				if restored_mp > 0:
					last_round_start_effects.append(
						"%s's Meditation restores %d MP."
						% [
							state.definition.display_name,
							restored_mp,
						]
					)
			if state.regeneration_rounds > 0:
				var regenerated_hp: int = state.heal(1)
				state.regeneration_rounds -= 1
				if regenerated_hp > 0:
					last_round_start_effects.append(
						"%s regenerates %d HP from Blood Rite."
						% [
							state.definition.display_name,
							regenerated_hp,
						]
					)

	battle_state.begin_round(new_round_number)

	if (
		new_round_number == 1
		and battle_state.momentum_side != BattleState.CombatSide.NONE
	):
		var losing_side: BattleState.CombatSide = (
			battle_state.second_side
		)

		for state_value: Variant in battler_states.values():
			var state: BattlerState = state_value as BattlerState
			if state == null or state.definition == null:
				continue

			if (
				side_for_faction(state.definition.faction)
				== losing_side
			):
				state.set_current_actions(0)
