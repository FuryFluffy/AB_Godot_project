class_name EnemyAIController
extends RefCounted


enum Difficulty {
	STANDARD,
	EASY,
}


enum MoveReactionAction {
	DECLINE,
	ATTACK,
	GRAPPLE,
}


var battler_states: Dictionary = {}
var battle_state: BattleState
var battlefield_state: BattlefieldState
var movement_controller: BattleMovementController
var targeting_controller: BattleTargetingController
var grapple_controller: GrappleController
var group_rulebook: EnemyGroupRulebookDefinition

var difficulty: Difficulty = Difficulty.STANDARD
var base_seed: int = 1

var phase_active: bool = false
var activation_order: Array[StringName] = []
var activation_index: int = 0
var active_group_rule: EnemyGroupRuleDefinition
var pending_decision: EnemyDecision
var decision_counter: int = 0
var group_evaluation_lines: Array[String] = []
var last_evaluation_lines: Array[String] = []
var completed_activation_ids: Dictionary = {}
var activation_start_cooldowns: Dictionary = {}


func initialize(
	new_battler_states: Dictionary,
	new_battle_state: BattleState,
	new_battlefield_state: BattlefieldState,
	new_movement_controller: BattleMovementController,
	new_targeting_controller: BattleTargetingController,
	new_grapple_controller: GrappleController,
	new_group_rulebook: EnemyGroupRulebookDefinition,
	new_base_seed: int
) -> void:
	battler_states = new_battler_states
	battle_state = new_battle_state
	battlefield_state = new_battlefield_state
	movement_controller = new_movement_controller
	targeting_controller = new_targeting_controller
	grapple_controller = new_grapple_controller
	group_rulebook = new_group_rulebook
	base_seed = new_base_seed


func set_difficulty(
	new_difficulty: int
) -> void:
	difficulty = (
		Difficulty.EASY
		if new_difficulty == Difficulty.EASY
		else Difficulty.STANDARD
	)


func begin_enemy_phase() -> String:
	if battle_state == null:
		return "BattleState is missing."
	if battle_state.phase != BattleState.Phase.ENEMY:
		return "Enemy AI can only begin during the Enemy Phase."
	if group_rulebook == null:
		return "Enemy group rulebook is missing."

	phase_active = true
	activation_index = 0
	pending_decision = null
	decision_counter = 0
	group_evaluation_lines.clear()
	last_evaluation_lines.clear()
	completed_activation_ids.clear()
	activation_start_cooldowns.clear()

	active_group_rule = _select_group_rule()
	activation_order = _build_activation_order(active_group_rule)

	if active_group_rule != null:
		group_evaluation_lines.append(
			"GROUP matched: %s." % active_group_rule.display_name
		)
	else:
		group_evaluation_lines.append(
			"GROUP fallback: stable enemy ID order."
		)
	group_evaluation_lines.append(
		"Activation order: %s."
		% _get_battler_name_list(activation_order)
	)

	return ""


func end_enemy_phase() -> void:
	phase_active = false
	activation_order.clear()
	activation_index = 0
	active_group_rule = null
	pending_decision = null


func is_enemy_phase_active() -> bool:
	return phase_active


func is_phase_complete() -> bool:
	return phase_active and activation_index >= activation_order.size()


func get_next_decision() -> EnemyDecision:
	if not phase_active:
		return null
	if pending_decision != null:
		return pending_decision

	while activation_index < activation_order.size():
		var actor_id: StringName = activation_order[activation_index]
		var actor: BattlerState = _get_battler_state(actor_id)
		if (
			actor != null
			and actor.definition != null
			and not activation_start_cooldowns.has(actor_id)
		):
			activation_start_cooldowns[actor_id] = (
				actor.grapple_cooldown_activations
			)
		if (
			actor == null
			or actor.definition == null
			or actor.is_defeated
			or actor.current_actions <= 0
		):
			_finish_actor_activation(actor)
			activation_index += 1
			continue

		pending_decision = _evaluate_actor(actor)
		return pending_decision

	return null


func complete_pending_decision() -> void:
	if pending_decision == null:
		return

	decision_counter += 1
	pending_decision = null


func _finish_actor_activation(
	actor: BattlerState
) -> void:
	if actor == null or actor.definition == null:
		return
	var actor_id: StringName = actor.definition.battler_id
	if completed_activation_ids.has(actor_id):
		return
	completed_activation_ids[actor_id] = true
	if int(activation_start_cooldowns.get(actor_id, 0)) > 0:
		actor.consume_grapple_cooldown_activation()


func forfeit_current_actor_actions(
	reason: String
) -> void:
	if activation_index >= activation_order.size():
		return

	var actor: BattlerState = _get_battler_state(
		activation_order[activation_index]
	)
	if actor != null:
		actor.set_current_actions(0)

	last_evaluation_lines.append(
		"Activation forfeited: %s" % reason
	)
	complete_pending_decision()


func get_next_attack_seed() -> int:
	var round_offset: int = (
		battle_state.round_number * 1000
		if battle_state != null
		else 0
	)
	return base_seed + round_offset + decision_counter


func get_pending_forecast() -> String:
	if difficulty != Difficulty.EASY:
		return "Forecast: Hidden (Standard)"
	if pending_decision == null:
		return "Forecast: Enemy phase complete"

	return "Forecast: %s" % pending_decision.summary


func get_debug_text() -> String:
	var combined_lines: Array[String] = []
	combined_lines.append_array(group_evaluation_lines)
	if (
		not combined_lines.is_empty()
		and not last_evaluation_lines.is_empty()
	):
		combined_lines.append("")
	combined_lines.append_array(last_evaluation_lines)

	if combined_lines.is_empty():
		return "No enemy rule has been evaluated yet."

	return "\n".join(PackedStringArray(combined_lines))


func choose_move_reactor(
	reactor_ids: Array[StringName]
) -> StringName:
	var best_id: StringName = &""
	var best_priority: int = -1

	for reactor_id: StringName in reactor_ids:
		var state: BattlerState = _get_battler_state(reactor_id)
		if state == null or state.definition == null:
			continue

		var rulebook: EnemyRulebookDefinition = (
			state.definition.enemy_rulebook
		)
		if rulebook == null or not rulebook.react_to_enemy_moves:
			continue

		if (
			rulebook.move_reaction_priority > best_priority
			or (
				rulebook.move_reaction_priority == best_priority
				and (
					best_id == &""
					or String(reactor_id) < String(best_id)
				)
			)
		):
			best_id = reactor_id
			best_priority = rulebook.move_reaction_priority

	return best_id


func choose_move_reaction_action(
	reactor_id: StringName,
	mover_id: StringName
) -> MoveReactionAction:
	var reactor: BattlerState = _get_battler_state(reactor_id)
	var mover: BattlerState = _get_battler_state(mover_id)
	var rulebook: EnemyRulebookDefinition = _get_rulebook(reactor)
	if (
		reactor == null
		or mover == null
		or rulebook == null
		or not rulebook.react_to_enemy_moves
	):
		return MoveReactionAction.DECLINE

	match rulebook.move_reaction_policy:
		EnemyRulebookDefinition.MoveReactionPolicy.DECLINE:
			return MoveReactionAction.DECLINE
		EnemyRulebookDefinition.MoveReactionPolicy.GRAPPLE_IF_LEGAL:
			if (
				grapple_controller != null
				and grapple_controller.can_initiate(
					reactor_id,
					mover_id
				)
			):
				return MoveReactionAction.GRAPPLE

	return MoveReactionAction.ATTACK


func get_move_reaction_action_label(
	action: MoveReactionAction
) -> String:
	match action:
		MoveReactionAction.GRAPPLE:
			return "Grapple"
		MoveReactionAction.ATTACK:
			return "Attack"

	return "Decline"


func choose_attack_reaction(
	target: BattlerState,
	can_counterattack: bool
) -> AttackReactionChoice.Type:
	var rulebook: EnemyRulebookDefinition = _get_rulebook(target)
	if rulebook == null:
		return AttackReactionChoice.Type.SKIP

	match rulebook.attack_reaction_policy:
		EnemyRulebookDefinition.AttackReactionPolicy.COUNTERATTACK_IF_LEGAL:
			if can_counterattack:
				return AttackReactionChoice.Type.COUNTERATTACK
			return AttackReactionChoice.Type.DEFEND
		EnemyRulebookDefinition.AttackReactionPolicy.SKIP:
			return AttackReactionChoice.Type.SKIP

	return AttackReactionChoice.Type.DEFEND


func choose_defense(
	target: BattlerState,
	action_controller: BattleActionController
) -> DefenseChoice.Type:
	var rulebook: EnemyRulebookDefinition = _get_rulebook(target)
	if rulebook == null or action_controller == null:
		return DefenseChoice.Type.SKIP

	var preferred: DefenseChoice.Type = _map_defense_preference(
		rulebook.defense_preference
	)
	var candidates: Array[int] = [
		preferred,
		DefenseChoice.Type.PARRY,
		DefenseChoice.Type.SHIELD,
		DefenseChoice.Type.ARMOR,
		DefenseChoice.Type.DODGE,
		DefenseChoice.Type.SKIP,
	]
	var considered: Array[int] = []

	for candidate_value: int in candidates:
		if considered.has(candidate_value):
			continue
		considered.append(candidate_value)

		var candidate: DefenseChoice.Type = (
			_defense_choice_from_value(candidate_value)
		)
		if _is_defense_legal(
			candidate,
			target,
			action_controller
		):
			return candidate

	return DefenseChoice.Type.SKIP


func choose_break_choice(
	target: BattlerState
) -> BreakChoice.Type:
	var rulebook: EnemyRulebookDefinition = _get_rulebook(target)
	if (
		rulebook != null
		and rulebook.break_policy
		== EnemyRulebookDefinition.BreakPolicy.DESTROY
	):
		return BreakChoice.Type.DESTROY

	return BreakChoice.Type.PRESERVE


func get_attack_reaction_label(
	choice: AttackReactionChoice.Type
) -> String:
	match choice:
		AttackReactionChoice.Type.DEFEND:
			return "Defend"
		AttackReactionChoice.Type.COUNTERATTACK:
			return "Counterattack"

	return "Skip"


func get_defense_label(
	choice: DefenseChoice.Type
) -> String:
	match choice:
		DefenseChoice.Type.DODGE:
			return "Dodge"
		DefenseChoice.Type.ARMOR:
			return "Armor Defense"
		DefenseChoice.Type.SHIELD:
			return "Shield Defense"
		DefenseChoice.Type.PARRY:
			return "Parry"

	return "Skip"


func _evaluate_actor(
	actor: BattlerState
) -> EnemyDecision:
	last_evaluation_lines.clear()
	last_evaluation_lines.append(
		"ACTOR: %s (%d Actions)." % [
			actor.definition.display_name,
			actor.current_actions,
		]
	)

	if (
		grapple_controller != null
		and grapple_controller.is_full_party_defeated()
	):
		if grapple_controller.get_track_for_grappler(
			actor.definition.battler_id
		) != null:
			if grapple_controller.can_progress_track(
				actor.definition.battler_id
			):
				last_evaluation_lines.append(
					"FULL WIPE: existing track must Progress; Hold is suppressed."
				)
				return _make_forced_progress(actor)
			last_evaluation_lines.append(
				"FULL WIPE: track is maintained, but Progress is currently blocked."
			)
			return _make_implicit_wait(actor)

		last_evaluation_lines.append(
			"FULL WIPE: unattached enemy takes no further meaningful Action."
		)
		return _make_implicit_wait(actor)

	var rulebook: EnemyRulebookDefinition = _get_rulebook(actor)
	if rulebook == null:
		last_evaluation_lines.append(
			"No individual rulebook; implicit Wait."
		)
		return _make_implicit_wait(actor)

	var ability_decision: EnemyDecision = (
		_build_priority_ability_decision(actor)
	)
	if ability_decision != null:
		last_evaluation_lines.append(
			"Ability priority: MATCHED → %s."
			% ability_decision.summary
		)
		return ability_decision

	var weapon: WeaponDefinition = actor.get_usable_main_hand_weapon()
	var legal_attack_ids: Array[StringName] = []
	if weapon != null and targeting_controller != null:
		legal_attack_ids = targeting_controller.get_legal_target_ids(
			actor.definition.battler_id,
			weapon,
			weapon.is_magic_attack,
			actor.get_main_hand_weapon_rank()
		)
	var legal_grapple_ids: Array[StringName] = []
	if grapple_controller != null:
		legal_grapple_ids = (
			grapple_controller.get_legal_grapple_action_target_ids(
				actor.definition.battler_id
			)
		)

	for rule_index: int in range(rulebook.rules.size()):
		var rule: EnemyRuleDefinition = rulebook.rules[rule_index]
		if rule == null:
			last_evaluation_lines.append(
				"Rule %d: empty — skipped." % (rule_index + 1)
			)
			continue

		var condition_matches: bool = _condition_matches(
			rule.condition,
			actor,
			not legal_attack_ids.is_empty(),
			not legal_grapple_ids.is_empty()
		)
		if not condition_matches:
			last_evaluation_lines.append(
				"Rule %d %s: condition false (%s)." % [
					rule_index + 1,
					rule.display_name,
					rule.get_condition_label(),
				]
			)
			continue

		var decision: EnemyDecision
		match rule.action:
			EnemyRuleDefinition.Action.ATTACK:
				decision = _build_attack_decision(
					actor,
					rule,
					legal_attack_ids
				)
			EnemyRuleDefinition.Action.MOVE_TOWARD_TARGET:
				decision = _build_move_decision(actor, rule)
			EnemyRuleDefinition.Action.GRAPPLE:
				decision = _build_grapple_decision(
					actor,
					rule,
					legal_grapple_ids
				)
			EnemyRuleDefinition.Action.GRAPPLE_HOLD:
				decision = _build_grapple_track_decision(
					actor,
					rule,
					EnemyDecision.Type.GRAPPLE_HOLD
				)
			EnemyRuleDefinition.Action.GRAPPLE_PROGRESS:
				decision = _build_grapple_track_decision(
					actor,
					rule,
					EnemyDecision.Type.GRAPPLE_PROGRESS
				)
			EnemyRuleDefinition.Action.WAIT:
				decision = _build_wait_decision(actor, rule)

		if decision != null and decision.is_valid():
			last_evaluation_lines.append(
				"Rule %d %s: MATCHED → %s." % [
					rule_index + 1,
					rule.display_name,
					decision.summary,
				]
			)
			return decision

		last_evaluation_lines.append(
			"Rule %d %s: action is not legal now." % [
				rule_index + 1,
				rule.display_name,
			]
		)

	last_evaluation_lines.append(
		"No authored rule produced a legal Action; implicit Wait."
	)
	return _make_implicit_wait(actor)


func _build_priority_ability_decision(
	actor: BattlerState
) -> EnemyDecision:
	if actor == null or actor.definition == null:
		return null
	for ability: AbilityDefinition in actor.get_available_abilities():
		if (
			ability == null
			or ability.is_passive()
			or actor.current_actions < ability.action_cost
			or actor.current_mp < ability.mp_cost
		):
			continue
		var candidate_ids: Array[StringName] = []
		var group_heal: GroupHealAbilityEffect = (
			ability.get_group_heal_effect()
		)
		if group_heal != null:
			if not _has_injured_ally_in_same_zone(actor):
				continue
			candidate_ids.append(actor.definition.battler_id)
		for state_value: Variant in battler_states.values():
			var target: BattlerState = state_value as BattlerState
			if (
				target == null
				or target.definition == null
				or target.is_defeated
			):
				continue
			if group_heal != null:
				continue
			if not _matches_ability_faction(actor, target, ability):
				continue
			if (
				ability.targeting_mode
				== AbilityDefinition.TargetingMode.SELF
				and target != actor
			):
				continue
			if (
				_ability_has_bless(ability)
				and target.blessed_minimum_damage > 0
			):
				continue
			if (
				_ability_has_ward(ability)
				and target.ward_dice_bonus > 0
			):
				continue
			if ability.is_attack():
				var attack_profile: WeaponDefinition = (
					ability.create_attack_profile(
						actor.get_usable_main_hand_weapon()
					)
				)
				if (
					attack_profile == null
					or targeting_controller == null
					or not targeting_controller.evaluate_attack(
						actor.definition.battler_id,
						target.definition.battler_id,
						attack_profile,
						ability.is_magic,
						actor.get_main_hand_weapon_rank()
					).is_legal
				):
					continue
			candidate_ids.append(target.definition.battler_id)
		candidate_ids.sort()
		if ability.is_attack() and not candidate_ids.is_empty():
			var weakest_id: StringName = _select_target(
				actor.definition.battler_id,
				candidate_ids,
				EnemyRuleDefinition.TargetPolicy.LOWEST_HP_PERCENT
			)
			candidate_ids.clear()
			candidate_ids.append(weakest_id)
		for target_id: StringName in candidate_ids:
			var caster_position: BattlerPositionState = (
				battlefield_state.get_battler_position(
					actor.definition.battler_id
				)
			)
			var target_position: BattlerPositionState = (
				battlefield_state.get_battler_position(target_id)
			)
			if caster_position == null or target_position == null:
				continue
			if (
				ability.requires_same_anchor
				and caster_position.anchor_id
				!= target_position.anchor_id
			):
				continue
			var caster_anchor: AnchorDefinition = (
				battlefield_state.get_battler_anchor(
					actor.definition.battler_id
				)
			)
			var target_anchor: AnchorDefinition = (
				battlefield_state.get_battler_anchor(target_id)
			)
			if caster_anchor == null or target_anchor == null:
				continue
			if (
				ability.requires_same_zone
				and caster_anchor.zone_id != target_anchor.zone_id
			):
				continue
			if caster_anchor.zone_id != target_anchor.zone_id:
				var zone_distance: int = (
					battlefield_state.get_zone_distance(
						caster_anchor.zone_id,
						target_anchor.zone_id
					)
				)
				if (
					zone_distance < 0
					or zone_distance > ability.maximum_zone_distance
				):
					continue
			var decision: EnemyDecision = EnemyDecision.new()
			decision.type = EnemyDecision.Type.ABILITY
			decision.actor_id = actor.definition.battler_id
			decision.target_id = target_id
			decision.ability_id = ability.ability_id
			var synthetic_rule: EnemyRuleDefinition = (
				EnemyRuleDefinition.new()
			)
			synthetic_rule.rule_id = StringName(
				"ability_%s" % String(ability.ability_id)
			)
			synthetic_rule.display_name = ability.display_name
			decision.source_rule = synthetic_rule
			var target: BattlerState = _get_battler_state(target_id)
			decision.summary = "%s → %s on %s" % [
				actor.definition.display_name,
				ability.display_name,
				target.definition.display_name,
			]
			return decision
	return null


func _matches_ability_faction(
	actor: BattlerState,
	target: BattlerState,
	ability: AbilityDefinition
) -> bool:
	match ability.targeting_mode:
		AbilityDefinition.TargetingMode.ENEMY:
			return target.definition.faction != actor.definition.faction
		AbilityDefinition.TargetingMode.ALLY:
			return target.definition.faction == actor.definition.faction
		AbilityDefinition.TargetingMode.SELF:
			return target == actor
		AbilityDefinition.TargetingMode.ANY:
			return true
	return false


func _ability_has_bless(
	ability: AbilityDefinition
) -> bool:
	for effect: AbilityEffectDefinition in ability.effects:
		if effect is BlessAbilityEffect:
			return true
	return false


func _ability_has_ward(
	ability: AbilityDefinition
) -> bool:
	for effect: AbilityEffectDefinition in ability.effects:
		if effect is WardAbilityEffect:
			return true
	return false


func _has_injured_ally_in_same_zone(
	actor: BattlerState
) -> bool:
	var actor_anchor: AnchorDefinition = battlefield_state.get_battler_anchor(
		actor.definition.battler_id
	)
	if actor_anchor == null:
		return false
	for state_value: Variant in battler_states.values():
		var ally: BattlerState = state_value as BattlerState
		if (
			ally == null
			or ally == actor
			or ally.definition == null
			or ally.is_defeated
			or ally.definition.faction != actor.definition.faction
			or ally.current_hp >= ally.get_max_hp()
		):
			continue
		var ally_anchor: AnchorDefinition = (
			battlefield_state.get_battler_anchor(
				ally.definition.battler_id
			)
		)
		if (
			ally_anchor != null
			and ally_anchor.zone_id == actor_anchor.zone_id
		):
			return true
	return false


func _build_attack_decision(
	actor: BattlerState,
	rule: EnemyRuleDefinition,
	legal_attack_ids: Array[StringName]
) -> EnemyDecision:
	if legal_attack_ids.is_empty():
		return null

	var target_id: StringName = _select_target(
		actor.definition.battler_id,
		legal_attack_ids,
		rule.target_policy
	)
	if target_id == &"":
		return null

	var target: BattlerState = _get_battler_state(target_id)
	var decision: EnemyDecision = EnemyDecision.new()
	decision.type = EnemyDecision.Type.ATTACK
	decision.actor_id = actor.definition.battler_id
	decision.target_id = target_id
	decision.source_rule = rule
	decision.summary = "%s → Attack %s" % [
		actor.definition.display_name,
		target.definition.display_name,
	]
	return decision


func _build_grapple_decision(
	actor: BattlerState,
	rule: EnemyRuleDefinition,
	legal_grapple_ids: Array[StringName]
) -> EnemyDecision:
	if legal_grapple_ids.is_empty():
		return null

	var target_id: StringName = _select_target(
		actor.definition.battler_id,
		legal_grapple_ids,
		rule.target_policy
	)
	if target_id == &"":
		return null

	var target: BattlerState = _get_battler_state(target_id)
	var decision: EnemyDecision = EnemyDecision.new()
	decision.type = EnemyDecision.Type.GRAPPLE
	decision.actor_id = actor.definition.battler_id
	decision.target_id = target_id
	decision.source_rule = rule
	decision.summary = "%s → Grapple %s" % [
		actor.definition.display_name,
		target.definition.display_name,
	]
	return decision


func _build_grapple_track_decision(
	actor: BattlerState,
	rule: EnemyRuleDefinition,
	decision_type: EnemyDecision.Type
) -> EnemyDecision:
	if grapple_controller == null:
		return null
	if (
		decision_type == EnemyDecision.Type.GRAPPLE_HOLD
		and not grapple_controller.can_hold_track(
			actor.definition.battler_id
		)
	):
		return null
	if (
		decision_type == EnemyDecision.Type.GRAPPLE_PROGRESS
		and not grapple_controller.can_progress_track(
			actor.definition.battler_id
		)
	):
		return null

	var decision: EnemyDecision = EnemyDecision.new()
	decision.type = decision_type
	decision.actor_id = actor.definition.battler_id
	decision.source_rule = rule
	decision.summary = "%s → %s" % [
		actor.definition.display_name,
		"Hold Grapple"
		if decision_type == EnemyDecision.Type.GRAPPLE_HOLD
		else "Progress Grapple",
	]
	return decision


func _build_move_decision(
	actor: BattlerState,
	rule: EnemyRuleDefinition
) -> EnemyDecision:
	if movement_controller == null or battlefield_state == null:
		return null

	var previews: Array[MovementPreview] = (
		movement_controller.get_move_previews(
			actor.definition.battler_id
		)
	)
	var target_ids: Array[StringName] = _get_living_opponent_ids(actor)
	if previews.is_empty() or target_ids.is_empty():
		return null

	var best_preview: MovementPreview
	var best_target_id: StringName = &""
	var best_distance: int = 2147483647
	var best_position_index: int = -1

	for preview: MovementPreview in previews:
		if (
			preview == null
			or not preview.is_valid
			or preview.available_destination_positions.is_empty()
		):
			continue

		var position_indices: Array[int] = (
			preview.available_destination_positions.duplicate()
		)
		position_indices.sort()

		for target_id: StringName in target_ids:
			var target_position: BattlerPositionState = (
				battlefield_state.get_battler_position(target_id)
			)
			if target_position == null:
				continue

			var anchor_distance: int = battlefield_state.get_anchor_distance(
				preview.destination_anchor_id,
				target_position.anchor_id
			)
			if anchor_distance < 0:
				continue

			for position_index: int in position_indices:
				var distance := anchor_distance
				if battlefield_state.are_positions_adjacent(
					preview.destination_anchor_id,
					position_index,
					target_position.anchor_id,
					target_position.position_index
				):
					distance = 0
				var target_is_better := (
					distance == best_distance
					and _is_target_better(
						actor.definition.battler_id,
						target_id,
						best_target_id,
						rule.target_policy
					)
				)
				var same_target := target_id == best_target_id
				var route_is_better := (
					distance == best_distance
					and same_target
					and _is_preview_route_better(preview, best_preview)
				)
				var position_is_better := (
					distance == best_distance
					and same_target
					and preview == best_preview
					and (
						best_position_index < 0
						or position_index < best_position_index
					)
				)
				if (
					best_preview == null
					or distance < best_distance
					or target_is_better
					or route_is_better
					or position_is_better
				):
					best_preview = preview
					best_target_id = target_id
					best_distance = distance
					best_position_index = position_index

	if best_preview == null or best_target_id == &"":
		return null

	var target: BattlerState = _get_battler_state(best_target_id)
	var decision: EnemyDecision = EnemyDecision.new()
	decision.type = EnemyDecision.Type.MOVE
	decision.actor_id = actor.definition.battler_id
	decision.target_id = best_target_id
	decision.source_rule = rule
	decision.move_preview = best_preview
	decision.destination_position_index = best_position_index
	decision.summary = "%s → Move toward %s via %s" % [
		actor.definition.display_name,
		target.definition.display_name,
		best_preview.get_route_label(battlefield_state.definition),
	]
	return decision


func _build_wait_decision(
	actor: BattlerState,
	rule: EnemyRuleDefinition
) -> EnemyDecision:
	var decision: EnemyDecision = EnemyDecision.new()
	decision.type = EnemyDecision.Type.WAIT
	decision.actor_id = actor.definition.battler_id
	decision.source_rule = rule
	decision.summary = "%s → Wait" % actor.definition.display_name
	return decision


func _make_implicit_wait(
	actor: BattlerState
) -> EnemyDecision:
	var fallback_rule: EnemyRuleDefinition = EnemyRuleDefinition.new()
	fallback_rule.rule_id = &"implicit_wait"
	fallback_rule.display_name = "Implicit Wait"
	fallback_rule.action = EnemyRuleDefinition.Action.WAIT
	return _build_wait_decision(actor, fallback_rule)


func _make_forced_progress(
	actor: BattlerState
) -> EnemyDecision:
	var forced_rule: EnemyRuleDefinition = EnemyRuleDefinition.new()
	forced_rule.rule_id = &"full_wipe_forced_progress"
	forced_rule.display_name = "Full-Wipe Forced Progress"
	forced_rule.action = EnemyRuleDefinition.Action.GRAPPLE_PROGRESS
	return _build_grapple_track_decision(
		actor,
		forced_rule,
		EnemyDecision.Type.GRAPPLE_PROGRESS
	)


func _condition_matches(
	condition: EnemyRuleDefinition.Condition,
	actor: BattlerState,
	has_legal_attack: bool,
	has_legal_grapple: bool
) -> bool:
	match condition:
		EnemyRuleDefinition.Condition.LEGAL_ATTACK_EXISTS:
			return has_legal_attack
		EnemyRuleDefinition.Condition.NO_LEGAL_ATTACK_EXISTS:
			return not has_legal_attack
		EnemyRuleDefinition.Condition.ACTIVE_GRAPPLE_CAN_HOLD:
			return (
				grapple_controller != null
				and grapple_controller.can_hold_track(
					actor.definition.battler_id
				)
			)
		EnemyRuleDefinition.Condition.ACTIVE_GRAPPLE_CAN_PROGRESS:
			return (
				grapple_controller != null
				and grapple_controller.can_progress_track(
					actor.definition.battler_id
				)
			)
		EnemyRuleDefinition.Condition.LEGAL_GRAPPLE_TARGET_EXISTS:
			return has_legal_grapple

	return true


func _select_group_rule() -> EnemyGroupRuleDefinition:
	if group_rulebook == null:
		return null

	for rule: EnemyGroupRuleDefinition in group_rulebook.rules:
		if rule != null and rule.applies_to(battler_states):
			return rule

	return null


func _build_activation_order(
	group_rule: EnemyGroupRuleDefinition
) -> Array[StringName]:
	var ordered_ids: Array[StringName] = []
	if group_rule != null:
		for battler_id: StringName in group_rule.activation_order:
			if (
				_is_living_enemy_id(battler_id)
				and not ordered_ids.has(battler_id)
			):
				ordered_ids.append(battler_id)

	var remaining_ids: Array[StringName] = []
	for state_value: Variant in battler_states.values():
		var state: BattlerState = state_value as BattlerState
		if (
			state == null
			or state.definition == null
			or state.is_defeated
			or state.definition.faction
			!= BattlerDefinition.Faction.ENEMY
			or ordered_ids.has(state.definition.battler_id)
		):
			continue
		remaining_ids.append(state.definition.battler_id)

	remaining_ids.sort()
	ordered_ids.append_array(remaining_ids)
	return ordered_ids


func _get_living_opponent_ids(
	actor: BattlerState
) -> Array[StringName]:
	var target_ids: Array[StringName] = []
	if actor == null or actor.definition == null:
		return target_ids

	for state_value: Variant in battler_states.values():
		var target: BattlerState = state_value as BattlerState
		if (
			target == null
			or target.definition == null
			or target.is_defeated
			or target.definition.faction
			== actor.definition.faction
		):
			continue
		target_ids.append(target.definition.battler_id)

	target_ids.sort()
	return target_ids


func _select_target(
	actor_id: StringName,
	target_ids: Array[StringName],
	policy: EnemyRuleDefinition.TargetPolicy
) -> StringName:
	var best_id: StringName = &""
	for target_id: StringName in target_ids:
		if _is_target_better(
			actor_id,
			target_id,
			best_id,
			policy
		):
			best_id = target_id

	return best_id


func _is_target_better(
	actor_id: StringName,
	candidate_id: StringName,
	current_best_id: StringName,
	policy: EnemyRuleDefinition.TargetPolicy
) -> bool:
	if current_best_id == &"":
		return true

	var candidate: BattlerState = _get_battler_state(candidate_id)
	var current_best: BattlerState = _get_battler_state(current_best_id)
	if (
		candidate == null
		or candidate.definition == null
		or current_best == null
		or current_best.definition == null
	):
		return String(candidate_id) < String(current_best_id)

	match policy:
		EnemyRuleDefinition.TargetPolicy.LOWEST_HP:
			if candidate.current_hp != current_best.current_hp:
				return candidate.current_hp < current_best.current_hp

		EnemyRuleDefinition.TargetPolicy.LOWEST_HP_PERCENT:
			var candidate_scaled: int = (
				candidate.current_hp
				* maxi(current_best.get_max_hp(), 1)
			)
			var best_scaled: int = (
				current_best.current_hp
				* maxi(candidate.get_max_hp(), 1)
			)
			if candidate_scaled != best_scaled:
				return candidate_scaled < best_scaled

		EnemyRuleDefinition.TargetPolicy.NEAREST:
			var candidate_distance: int = _get_battler_distance(
				actor_id,
				candidate_id
			)
			var best_distance: int = _get_battler_distance(
				actor_id,
				current_best_id
			)
			if candidate_distance != best_distance:
				if candidate_distance < 0:
					return false
				if best_distance < 0:
					return true
				return candidate_distance < best_distance

	return String(candidate_id) < String(current_best_id)


func _get_battler_distance(
	first_id: StringName,
	second_id: StringName
) -> int:
	if battlefield_state == null:
		return -1

	var first_position: BattlerPositionState = (
		battlefield_state.get_battler_position(first_id)
	)
	var second_position: BattlerPositionState = (
		battlefield_state.get_battler_position(second_id)
	)
	if first_position == null or second_position == null:
		return -1

	return battlefield_state.get_anchor_distance(
		first_position.anchor_id,
		second_position.anchor_id
	)


func _is_preview_route_better(
	candidate: MovementPreview,
	current_best: MovementPreview
) -> bool:
	if candidate.get_step_count() != current_best.get_step_count():
		return candidate.get_step_count() > current_best.get_step_count()

	return (
		_get_route_key(candidate.anchor_path)
		< _get_route_key(current_best.anchor_path)
	)


func _get_route_key(
	anchor_path: Array[StringName]
) -> String:
	var parts: Array[String] = []
	for anchor_id: StringName in anchor_path:
		parts.append(String(anchor_id))
	return "|".join(PackedStringArray(parts))


func _is_living_enemy_id(
	battler_id: StringName
) -> bool:
	var state: BattlerState = _get_battler_state(battler_id)
	return (
		state != null
		and state.definition != null
		and not state.is_defeated
		and state.definition.faction
		== BattlerDefinition.Faction.ENEMY
	)


func _get_rulebook(
	state: BattlerState
) -> EnemyRulebookDefinition:
	if state == null or state.definition == null:
		return null

	return state.definition.enemy_rulebook


func _map_defense_preference(
	preference: EnemyRulebookDefinition.DefensePreference
) -> DefenseChoice.Type:
	match preference:
		EnemyRulebookDefinition.DefensePreference.ARMOR:
			return DefenseChoice.Type.ARMOR
		EnemyRulebookDefinition.DefensePreference.SHIELD:
			return DefenseChoice.Type.SHIELD
		EnemyRulebookDefinition.DefensePreference.PARRY:
			return DefenseChoice.Type.PARRY
		EnemyRulebookDefinition.DefensePreference.SKIP:
			return DefenseChoice.Type.SKIP

	return DefenseChoice.Type.DODGE


func _defense_choice_from_value(
	value: int
) -> DefenseChoice.Type:
	match value:
		DefenseChoice.Type.ARMOR:
			return DefenseChoice.Type.ARMOR
		DefenseChoice.Type.SHIELD:
			return DefenseChoice.Type.SHIELD
		DefenseChoice.Type.PARRY:
			return DefenseChoice.Type.PARRY
		DefenseChoice.Type.SKIP:
			return DefenseChoice.Type.SKIP

	return DefenseChoice.Type.DODGE


func _is_defense_legal(
	choice: DefenseChoice.Type,
	target: BattlerState,
	action_controller: BattleActionController
) -> bool:
	if target == null or target.current_actions <= 0:
		return choice == DefenseChoice.Type.SKIP

	match choice:
		DefenseChoice.Type.DODGE:
			return true
		DefenseChoice.Type.ARMOR:
			return target.has_usable_armor()
		DefenseChoice.Type.SHIELD:
			return target.has_usable_shield()
		DefenseChoice.Type.PARRY:
			return action_controller.can_parry(target)
		DefenseChoice.Type.SKIP:
			return true

	return false


func _get_battler_name_list(
	battler_ids: Array[StringName]
) -> String:
	var names: Array[String] = []
	for battler_id: StringName in battler_ids:
		var state: BattlerState = _get_battler_state(battler_id)
		names.append(
			state.definition.display_name
			if state != null and state.definition != null
			else String(battler_id)
		)

	return ", ".join(PackedStringArray(names))


func _get_battler_state(
	battler_id: StringName
) -> BattlerState:
	return battler_states.get(battler_id) as BattlerState
