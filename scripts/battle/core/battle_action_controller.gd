class_name BattleActionController
extends RefCounted


var battler_states: Dictionary = {}
var runtime: BattleRuntimeState
var attack_resolver: AttackResolver
var battle_flow_controller: BattleFlowController
var targeting_controller: BattleTargetingController
var attack_seed: int = 1


func initialize(
	new_battler_states: Dictionary,
	new_runtime: BattleRuntimeState,
	new_attack_resolver: AttackResolver,
	new_battle_flow_controller: BattleFlowController,
	new_attack_seed: int,
	new_targeting_controller: BattleTargetingController = null
) -> void:
	battler_states = new_battler_states
	runtime = new_runtime
	attack_resolver = new_attack_resolver
	battle_flow_controller = new_battle_flow_controller
	attack_seed = new_attack_seed
	targeting_controller = new_targeting_controller


func get_battler_state(
	battler_id: StringName
) -> BattlerState:
	return battler_states.get(
		battler_id
	) as BattlerState


func get_selected_attacker() -> BattlerState:
	if runtime == null:
		return null

	return get_battler_state(
		runtime.selected_battler_id
	)


func get_targeting_attacker() -> BattlerState:
	if runtime == null:
		return null

	return get_battler_state(
		runtime.pending_attacker_id
	)


func get_pending_reaction_attacker() -> BattlerState:
	if (
		runtime == null
		or runtime.pending_reaction_context == null
		or runtime.pending_reaction_context.request == null
	):
		return null

	return get_battler_state(
		runtime.pending_reaction_context.request.actor_id
	)


func get_pending_reaction_target() -> BattlerState:
	if runtime == null:
		return null

	return get_battler_state(
		runtime.pending_reaction_target_id
	)


func get_main_hand_weapon(
	state: BattlerState
) -> WeaponDefinition:
	if state == null:
		return null

	return state.get_main_hand_weapon()


func get_usable_main_hand_weapon(
	state: BattlerState
) -> WeaponDefinition:
	if state == null:
		return null

	return state.get_usable_main_hand_weapon()


func begin_attack_targeting() -> String:
	if runtime == null:
		return "Battle runtime state is missing."

	var attacker: BattlerState = get_selected_attacker()

	if attacker == null:
		return "No valid attacker is selected."

	if attacker.definition == null:
		return "Selected attacker has no definition."

	if battle_flow_controller == null:
		return "BattleFlowController is missing."

	var phase_error: String = (
		battle_flow_controller.validate_active_actor(attacker)
	)

	if not phase_error.is_empty():
		return phase_error

	if attacker.is_defeated:
		return "%s is defeated and cannot attack." % (
			attacker.definition.display_name
		)

	if attacker.current_actions <= 0:
		return "%s has no Actions remaining." % (
			attacker.definition.display_name
		)

	var weapon: WeaponDefinition = get_usable_main_hand_weapon(
		attacker
	)

	if weapon == null:
		return "%s has no usable main-hand weapon." % (
			attacker.definition.display_name
		)

	if (
		targeting_controller != null
		and get_legal_attack_target_ids(
			attacker,
			weapon
		).is_empty()
	):
		return "%s has no legal targets for %s." % [
			attacker.definition.display_name,
			weapon.display_name,
		]

	runtime.resolution_queue.clear()
	runtime.begin_attack_targeting(
		attacker.definition.battler_id
	)

	return ""


func prepare_attack(
	target_id: StringName
) -> ReactionContext:
	if runtime == null:
		return ReactionContext.new().fail(
			"Battle runtime state is missing."
		)

	if attack_resolver == null:
		return ReactionContext.new().fail(
			"AttackResolver is missing."
		)

	var attacker: BattlerState = get_targeting_attacker()

	if attacker == null:
		runtime.cancel_attack_targeting()
		return ReactionContext.new().fail(
			"Pending attacker no longer exists."
		)

	var target: BattlerState = get_battler_state(
		target_id
	)

	if target == null or target.definition == null:
		return ReactionContext.new().fail(
			"Selected target is invalid."
		)

	var weapon: WeaponDefinition = get_usable_main_hand_weapon(
		attacker
	)

	if weapon == null:
		runtime.cancel_attack_targeting()
		return ReactionContext.new().fail(
			"%s no longer has a usable main-hand weapon."
			% attacker.definition.display_name
		)

	var targeting_result: AttackTargetingResult = (
		_evaluate_spatial_attack(
			attacker,
			target,
			weapon,
			weapon.is_magic_attack
		)
	)
	if not targeting_result.is_legal:
		return ReactionContext.new().fail(
			targeting_result.error_message
		)

	var request: ActionRequest = ActionRequest.new(
		attacker.definition.battler_id,
		target.definition.battler_id,
		weapon,
		attack_seed,
		false,
		weapon.is_magic_attack
	)
	request.weapon_family_rank = (
		attacker.get_main_hand_weapon_rank()
	)
	request.qualifies_for_analysis = (
		weapon.skill == SkillEntry.Skill.DAGGER
		or weapon.skill == SkillEntry.Skill.SLINGS
	)
	request.ignore_one_defense_success = (
		request.qualifies_for_analysis
		and attacker.has_analyzed_target(
			target.definition.battler_id
		)
	)
	_apply_targeting_result(request, targeting_result)

	var context: ReactionContext = (
		attack_resolver.prepare_attack(
			request,
			attacker,
			target
		)
	)

	if context.is_valid:
		# The resolver is intentionally deterministic for reproducible QA, but
		# every committed primary Attack must consume a different seed.
		attack_seed += 1
		runtime.store_pending_reaction(
			context,
			target.definition.battler_id
		)

	return context


func resolve_reaction(
	choice: DefenseChoice.Type
) -> ActionResult:
	if runtime == null:
		return ActionResult.new().fail(
			"Battle runtime state is missing."
		)

	if attack_resolver == null:
		return ActionResult.new().fail(
			"AttackResolver is missing."
		)

	if not runtime.has_pending_reaction():
		return ActionResult.new().fail(
			"No ReactionContext is pending."
		)

	var attacker: BattlerState = (
		get_pending_reaction_attacker()
	)

	var target: BattlerState = (
		get_pending_reaction_target()
	)

	if attacker == null or target == null:
		return ActionResult.new().fail(
			"Pending attack combatants are missing."
		)

	var result: ActionResult = (
		attack_resolver.resolve_reaction(
			runtime.pending_reaction_context,
			attacker,
			target,
			choice
		)
	)

	if (
		result.succeeded
		and result.requires_equipment_break_choice
	):
		runtime.pending_action_result = result

	return result


func resolve_attack_reaction(
	choice: AttackReactionChoice.Type
) -> ActionResult:
	if runtime == null:
		return ActionResult.new().fail(
			"Battle runtime state is missing."
		)

	if not runtime.has_pending_reaction():
		return ActionResult.new().fail(
			"No ReactionContext is pending."
		)

	runtime.pending_attack_reaction_choice = choice

	match choice:
		AttackReactionChoice.Type.SKIP:
			var skipped_result: ActionResult = resolve_reaction(
				DefenseChoice.Type.SKIP
			)
			skipped_result.attack_reaction_choice = choice
			return skipped_result

		AttackReactionChoice.Type.COUNTERATTACK:
			var target: BattlerState = (
				get_pending_reaction_target()
			)
			if not can_counterattack(target):
				return ActionResult.new().fail(
					"Counterattack is not currently legal."
				)

			var counter_result: ActionResult = resolve_reaction(
				DefenseChoice.Type.SKIP
			)
			counter_result.attack_reaction_choice = choice
			counter_result.counterattack_requested = (
				counter_result.succeeded
			)
			return counter_result

		AttackReactionChoice.Type.DEFEND:
			var defend_result: ActionResult = ActionResult.new()
			defend_result.succeeded = true
			defend_result.attack_reaction_choice = choice
			return defend_result

	return ActionResult.new().fail(
		"Unsupported Attack reaction choice."
	)


func resolve_equipment_break_choice(
	choice: BreakChoice.Type
) -> ActionResult:
	if runtime == null:
		return ActionResult.new().fail(
			"Battle runtime state is missing."
		)

	if attack_resolver == null:
		return ActionResult.new().fail(
			"AttackResolver is missing."
		)

	if (
		not runtime.has_pending_reaction()
		or runtime.pending_action_result == null
	):
		return ActionResult.new().fail(
			"No equipment-break resolution is pending."
		)

	var target: BattlerState = (
		get_pending_reaction_target()
	)

	if target == null:
		return ActionResult.new().fail(
			"Pending equipment-break target is missing."
		)

	var result: ActionResult = (
		attack_resolver.resolve_equipment_break_choice(
			runtime.pending_action_result,
			get_pending_reaction_attacker(),
			target,
			choice
		)
	)

	if result.succeeded:
		runtime.pending_action_result = result

	return result


func get_dodge_dice_count(
	target: BattlerState
) -> int:
	if attack_resolver == null or target == null:
		return 0

	return (
		attack_resolver.get_dodge_dice_count(target)
		+ target.ward_dice_bonus
	)


func get_armor_defense_dice_count(
	target: BattlerState
) -> int:
	if attack_resolver == null or target == null:
		return 0

	return (
		attack_resolver.get_armor_defense_dice_count(target)
		+ target.ward_dice_bonus
	)


func get_shield_defense_dice_count(
	target: BattlerState
) -> int:
	if attack_resolver == null or target == null:
		return 0

	return (
		attack_resolver.get_shield_defense_dice_count(target)
		+ target.ward_dice_bonus
	)


func can_parry(
	target: BattlerState
) -> bool:
	if (
		attack_resolver == null
		or runtime == null
		or target == null
		or runtime.pending_reaction_context == null
	):
		return false

	return attack_resolver.can_parry(
		runtime.pending_reaction_context,
		target
	)


func get_parry_dice_count(
	target: BattlerState
) -> int:
	if (
		attack_resolver == null
		or runtime == null
		or target == null
		or runtime.pending_reaction_context == null
	):
		return 0

	return (
		attack_resolver.get_parry_dice_count(
			runtime.pending_reaction_context,
			target
		)
		+ target.ward_dice_bonus
	)


func can_counterattack(
	target: BattlerState
) -> bool:
	if (
		runtime == null
		or not runtime.has_pending_reaction()
		or runtime.pending_reaction_context.request == null
		or target == null
		or target.is_defeated
		or target.is_stunned()
		or (
			target.definition != null
			and target.definition.faction
			== BattlerDefinition.Faction.HEROINE
			and target.is_grappled()
		)
		or target.is_attached_grappler()
		or target.current_actions <= 0
	):
		return false

	if (
		runtime.pending_reaction_context.request.reaction_mode
		!= ActionRequest.ReactionMode.FULL
	):
		return false

	var counter_weapon: WeaponDefinition = (
		get_usable_main_hand_weapon(target)
	)
	if counter_weapon == null:
		return false
	if targeting_controller == null:
		return true

	var original_attacker: BattlerState = (
		get_pending_reaction_attacker()
	)
	var targeting_result: AttackTargetingResult = _evaluate_spatial_attack(
		target,
		original_attacker,
		counter_weapon,
		counter_weapon.is_magic_attack
	)
	if not targeting_result.is_legal:
		return false

	# A reactive melee strike belongs to the defender's current engagement
	# cluster. Reach still expands ordinary Active Attacks across a connected
	# Anchor, but it does not turn a spell or ranged hit from another Anchor
	# into an immediate melee Counterattack.
	if (
		not counter_weapon.is_magic_attack
		and counter_weapon.attack_range
		!= WeaponDefinition.AttackRange.RANGED
	):
		return (
			targeting_result.spatial_range
			== BattlefieldState.SpatialRange.ADJACENT
		)

	return true


## Revised reaction terminology. Kept beside can_counterattack() so older
## regression tests and serialized rulebooks remain compatible while the
## player-facing contract is Attack | Dodge | Defend | Parry | Skip.
func can_reaction_attack(target: BattlerState) -> bool:
	return can_counterattack(target)


func get_legal_attack_target_ids(
		attacker: BattlerState = null,
		weapon: WeaponDefinition = null
) -> Array[StringName]:
	var target_ids: Array[StringName] = []
	if attacker == null:
		attacker = get_selected_attacker()
	if attacker == null or attacker.definition == null:
		return target_ids
	if weapon == null:
		weapon = get_usable_main_hand_weapon(attacker)
	if weapon == null:
		return target_ids

	if targeting_controller != null:
		return targeting_controller.get_legal_target_ids(
			attacker.definition.battler_id,
			weapon,
			weapon.is_magic_attack,
			attacker.get_main_hand_weapon_rank()
		)

	for state_value: Variant in battler_states.values():
		var target: BattlerState = state_value as BattlerState
		if (
			target == null
			or target.definition == null
			or target == attacker
			or target.is_defeated
			or target.definition.faction
			== attacker.definition.faction
		):
			continue
		target_ids.append(target.definition.battler_id)

	target_ids.sort()
	return target_ids


func queue_move_reaction(
	reactor_id: StringName,
	mover_id: StringName,
	seed_value: int
) -> String:
	if runtime == null:
		return "Battle runtime state is missing."

	var reactor: BattlerState = get_battler_state(reactor_id)
	var mover: BattlerState = get_battler_state(mover_id)
	if (
		reactor == null
		or reactor.definition == null
		or mover == null
		or mover.definition == null
	):
		return "Move Reaction combatants are missing."
	if reactor.current_actions <= 0:
		return "%s has no Action for a Move Reaction." % (
			reactor.definition.display_name
		)

	var weapon: WeaponDefinition = get_usable_main_hand_weapon(
		reactor
	)
	if (
		weapon == null
		or weapon.attack_range
		!= WeaponDefinition.AttackRange.MELEE
	):
		return "%s has no usable melee Move Reaction weapon." % (
			reactor.definition.display_name
		)

	var targeting_result: AttackTargetingResult = (
		_evaluate_spatial_attack(
			reactor,
			mover,
			weapon,
			false
		)
	)
	if not targeting_result.is_legal:
		return targeting_result.error_message

	var request: ActionRequest = ActionRequest.new(
		reactor_id,
		mover_id,
		weapon,
		seed_value,
		false,
		false,
		0,
		ActionRequest.Source.MOVE_REACTION,
		ActionRequest.ReactionMode.FULL
	)
	request.weapon_family_rank = (
		reactor.get_main_hand_weapon_rank()
	)
	_apply_targeting_result(request, targeting_result)
	return runtime.resolution_queue.enqueue(request)


func enqueue_result_follow_up(
	completed_result: ActionResult
) -> String:
	if runtime == null:
		return "Battle runtime state is missing."

	if attack_resolver == null:
		return "AttackResolver is missing."

	if (
		completed_result == null
		or not completed_result.is_complete
	):
		return "Completed ActionResult is missing."

	if not runtime.has_pending_reaction():
		return "The original reaction context is missing."

	var previous_context: ReactionContext = (
		runtime.pending_reaction_context
	)

	if _should_generate_blood_riposte(completed_result):
		return _enqueue_blood_riposte(
			completed_result,
			previous_context
		)

	if completed_result.parry_should_generate_free_attack:
		return _enqueue_parry_free_attack(
			completed_result,
			previous_context
		)

	if completed_result.weapon_critical_free_attack_requested:
		var critical_error: String = (
			_enqueue_weapon_critical_free_attack(
				completed_result,
				previous_context
			)
		)
		if not critical_error.is_empty():
			return critical_error

	if completed_result.counterattack_requested:
		return _enqueue_counterattack(
			completed_result,
			previous_context
		)

	return ""


func _should_generate_blood_riposte(
	completed_result: ActionResult
) -> bool:
	if (
		completed_result == null
		or completed_result.defense_choice
		!= DefenseChoice.Type.DODGE
		or completed_result.attack_successes <= 0
		or completed_result.effective_defense_successes
		< completed_result.attack_successes
		or completed_result.damage_dealt > 0
		or battle_flow_controller == null
		or battle_flow_controller.battle_state == null
	):
		return false
	var defender: BattlerState = get_pending_reaction_target()
	return (
		defender != null
		and defender.can_trigger_blood_riposte(
			battle_flow_controller.battle_state.round_number
		)
	)


func _enqueue_blood_riposte(
	completed_result: ActionResult,
	previous_context: ReactionContext
) -> String:
	var riposte_attacker: BattlerState = get_pending_reaction_target()
	var riposte_target: BattlerState = get_pending_reaction_attacker()
	if (
		riposte_attacker == null
		or riposte_attacker.definition == null
		or riposte_target == null
		or riposte_target.definition == null
	):
		return "Blood Riposte combatants are missing."
	if riposte_attacker.is_defeated or riposte_target.is_defeated:
		return "Blood Riposte requires two living combatants."
	var sword: WeaponDefinition = get_usable_main_hand_weapon(
		riposte_attacker
	)
	if sword == null or sword.skill != SkillEntry.Skill.SWORD:
		return "%s has no usable Sword for Blood Riposte." % (
			riposte_attacker.definition.display_name
		)
	var targeting_result: AttackTargetingResult = (
		_evaluate_spatial_attack(
			riposte_attacker,
			riposte_target,
			sword,
			false
		)
	)
	if not targeting_result.is_legal:
		return "Blood Riposte cannot reach the attacker: %s" % (
			targeting_result.error_message
		)

	var request: ActionRequest = ActionRequest.new(
		riposte_attacker.definition.battler_id,
		riposte_target.definition.battler_id,
		sword,
		previous_context.request.seed_value
			+ 40
			+ runtime.resolution_queue.generated_attack_count,
		true,
		false,
		0,
		ActionRequest.Source.BLOOD_RIPOSTE,
		ActionRequest.ReactionMode.FULL
	)
	request.weapon_family_rank = (
		riposte_attacker.get_main_hand_weapon_rank()
	)
	_apply_targeting_result(request, targeting_result)
	var queue_error: String = runtime.resolution_queue.enqueue(request)
	if queue_error.is_empty():
		riposte_attacker.mark_blood_riposte_used(
			battle_flow_controller.battle_state.round_number
		)
		completed_result.blood_riposte_generated = true
	return queue_error


func prepare_next_queued_attack() -> ReactionContext:
	if runtime == null:
		return ReactionContext.new().fail(
			"Battle runtime state is missing."
		)

	var request: ActionRequest = (
		runtime.resolution_queue.pop_next()
	)

	if request == null:
		return ReactionContext.new().fail(
			"No generated Attack is queued."
		)

	var attacker: BattlerState = get_battler_state(
		request.actor_id
	)
	var target: BattlerState = get_battler_state(
		request.target_id
	)

	if attacker == null or target == null:
		return ReactionContext.new().fail(
			"Queued Attack combatants are missing."
		)

	var context: ReactionContext = (
		_prepare_request_with_spatial_validation(
			request,
			attacker,
			target
		)
	)

	if context.is_valid:
		runtime.store_pending_reaction(
			context,
			target.definition.battler_id
		)

	return context


func has_queued_attacks() -> bool:
	return (
		runtime != null
		and not runtime.resolution_queue.is_empty()
	)


func _enqueue_parry_free_attack(
	completed_result: ActionResult,
	previous_context: ReactionContext
) -> String:
	var free_attacker: BattlerState = (
		get_pending_reaction_target()
	)
	var free_target: BattlerState = (
		get_pending_reaction_attacker()
	)

	if free_attacker == null or free_target == null:
		return "Parry free Attack combatants are missing."

	if free_attacker.is_defeated:
		return (
			"%s was defeated and cannot make the free Attack."
			% free_attacker.definition.display_name
		)

	if free_target.is_defeated:
		return "The original attacker is already defeated."

	var weapon: WeaponDefinition = get_usable_main_hand_weapon(
		free_attacker
	)

	if weapon == null:
		return (
			"%s no longer has a suitable Parry weapon."
			% free_attacker.definition.display_name
		)

	var next_sequence_index: int = (
		previous_context.request.parry_sequence_index + 1
	)
	var free_attack_seed: int = (
		previous_context.request.seed_value
		+ 10
		+ runtime.resolution_queue.generated_attack_count
	)

	var request: ActionRequest = ActionRequest.new(
		free_attacker.definition.battler_id,
		free_target.definition.battler_id,
		weapon,
		free_attack_seed,
		true,
		weapon.is_magic_attack,
		next_sequence_index,
		ActionRequest.Source.PARRY_FREE_ATTACK,
		ActionRequest.ReactionMode.FULL
	)
	request.weapon_family_rank = (
		free_attacker.get_main_hand_weapon_rank()
	)

	var queue_error: String = (
		runtime.resolution_queue.enqueue(request)
	)

	if queue_error.is_empty():
		completed_result.parry_generated_free_attack = true

	return queue_error


func _enqueue_weapon_critical_free_attack(
	completed_result: ActionResult,
	previous_context: ReactionContext
) -> String:
	var attacker: BattlerState = get_pending_reaction_attacker()
	var target: BattlerState = get_pending_reaction_target()

	if attacker == null or target == null:
		return "Weapon critical combatants are missing."
	if attacker.is_defeated:
		return "The critical attacker is defeated."
	if target.is_defeated:
		return ""

	var weapon: WeaponDefinition = get_usable_main_hand_weapon(
		attacker
	)
	if weapon == null:
		return "%s has no usable weapon for its critical free Attack." % (
			attacker.definition.display_name
		)

	var request: ActionRequest = ActionRequest.new(
		attacker.definition.battler_id,
		target.definition.battler_id,
		weapon,
		previous_context.request.seed_value
			+ 50
			+ runtime.resolution_queue.generated_attack_count,
		true,
		weapon.is_magic_attack,
		previous_context.request.parry_sequence_index,
		ActionRequest.Source.WEAPON_CRITICAL,
		ActionRequest.ReactionMode.FULL
	)
	request.weapon_family_rank = (
		attacker.get_main_hand_weapon_rank()
	)
	var queue_error: String = runtime.resolution_queue.enqueue(
		request
	)
	if queue_error.is_empty():
		completed_result.weapon_critical_free_attack_generated = true
	return queue_error


func _enqueue_counterattack(
	completed_result: ActionResult,
	previous_context: ReactionContext
) -> String:
	var counterattacker: BattlerState = (
		get_pending_reaction_target()
	)
	var counter_target: BattlerState = (
		get_pending_reaction_attacker()
	)

	if counterattacker == null or counter_target == null:
		return "Counterattack combatants are missing."

	if counterattacker.is_defeated:
		return (
			"%s did not survive and cannot Counterattack."
			% counterattacker.definition.display_name
		)

	if counter_target.is_defeated:
		return "The original attacker is already defeated."

	if counterattacker.current_actions <= 0:
		return (
			"%s has no Action left for Counterattack."
			% counterattacker.definition.display_name
		)

	# Revalidate at generation time as well as when the reaction menu is
	# presented. This prevents a stale or programmatic Counterattack choice
	# from bypassing the engagement-range rule.
	if not can_counterattack(counterattacker):
		return (
			"%s cannot legally Counterattack the original attacker from its current position."
			% counterattacker.definition.display_name
		)

	var weapon: WeaponDefinition = get_usable_main_hand_weapon(
		counterattacker
	)

	if weapon == null:
		return (
			"%s has no usable Counterattack weapon."
			% counterattacker.definition.display_name
		)

	var counter_seed: int = (
		previous_context.request.seed_value
		+ 20
		+ runtime.resolution_queue.generated_attack_count
	)

	var request: ActionRequest = ActionRequest.new(
		counterattacker.definition.battler_id,
		counter_target.definition.battler_id,
		weapon,
		counter_seed,
		false,
		weapon.is_magic_attack,
		previous_context.request.parry_sequence_index,
		ActionRequest.Source.COUNTERATTACK,
		ActionRequest.ReactionMode.FULL
	)
	request.weapon_family_rank = (
		counterattacker.get_main_hand_weapon_rank()
	)

	var queue_error: String = (
		runtime.resolution_queue.enqueue(request)
	)

	if queue_error.is_empty():
		completed_result.counterattack_generated = true

	return queue_error


func cancel_attack_targeting() -> void:
	if runtime != null:
		runtime.cancel_attack_targeting()


func clear_pending_reaction() -> void:
	if runtime != null:
		runtime.clear_resolution_chain()


func _prepare_request_with_spatial_validation(
	request: ActionRequest,
	attacker: BattlerState,
	target: BattlerState
) -> ReactionContext:
	var targeting_result: AttackTargetingResult = (
		_evaluate_spatial_attack(
			attacker,
			target,
			request.weapon,
			request.is_magic
		)
	)
	if not targeting_result.is_legal:
		return ReactionContext.new().fail(
			targeting_result.error_message
		)

	_apply_targeting_result(request, targeting_result)
	return attack_resolver.prepare_attack(
		request,
		attacker,
		target
	)


func _evaluate_spatial_attack(
	attacker: BattlerState,
	target: BattlerState,
	weapon: WeaponDefinition,
	is_magic: bool
) -> AttackTargetingResult:
	if targeting_controller == null:
		return AttackTargetingResult.new().allow()
	if (
		attacker == null
		or attacker.definition == null
		or target == null
		or target.definition == null
	):
		return AttackTargetingResult.new().deny(
			"Spatial Attack combatants are missing."
		)

	return targeting_controller.evaluate_attack(
		attacker.definition.battler_id,
		target.definition.battler_id,
		weapon,
		is_magic,
		attacker.get_main_hand_weapon_rank()
	)


func _apply_targeting_result(
	request: ActionRequest,
	result: AttackTargetingResult
) -> void:
	if request == null or result == null:
		return

	request.spatial_range_label = result.spatial_range_label
	request.attack_dice_modifier = result.attack_dice_modifier
	request.suppress_skill_modification = (
		result.suppress_skill_modification
	)
