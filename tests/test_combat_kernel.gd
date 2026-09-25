extends SceneTree


var failures: int = 0


func _init() -> void:
	_test_forced_natural_miss_does_not_damage_weapon()
	_test_full_negation_damages_and_breaks_weapon()
	_test_counterattack_uses_generated_attack_queue()
	_test_dodge_mitigation_action_cost_and_optional_step()
	_test_parry_free_attack_rules_and_chain_penalties()
	_test_grappled_heroine_reaction_restrictions()
	_test_generated_attack_queue_is_bounded()

	if failures == 0:
		print("Combat kernel tests passed.")
	else:
		push_error(
			"%d combat kernel test(s) failed."
			% failures
		)

	quit(failures)


func _test_forced_natural_miss_does_not_damage_weapon() -> void:
	var actor: BattlerState = _make_state(
		"res://data/battlers/heroines/lysandra.tres"
	)
	var target: BattlerState = _make_state(
		"res://data/battlers/enemies/hollow_servant.tres"
	)
	var resolver: AttackResolver = AttackResolver.new()
	resolver.set_test_roll_mode(
		AttackResolver.TestRollMode.FORCE_NATURAL_MISS
	)

	var request: ActionRequest = ActionRequest.new(
		actor.definition.battler_id,
		target.definition.battler_id,
		actor.get_usable_main_hand_weapon(),
		100
	)
	var context: ReactionContext = resolver.prepare_attack(
		request,
		actor,
		target
	)
	var result: ActionResult = resolver.resolve_reaction(
		context,
		actor,
		target,
		DefenseChoice.Type.SKIP
	)

	_expect(
		result.attack_successes == 0,
		"Forced natural miss must have zero successes."
	)
	_expect(
		not result.weapon_durability_event,
		"A natural miss must not damage the weapon."
	)


func _test_full_negation_damages_and_breaks_weapon() -> void:
	var actor: BattlerState = _make_state(
		"res://data/battlers/heroines/lysandra.tres"
	)
	var target: BattlerState = _make_state(
		"res://data/battlers/enemies/hollow_servant.tres"
	)
	target.definition = target.definition.duplicate(true) as BattlerDefinition
	target.definition.attributes = (
		target.definition.attributes.duplicate(true) as AttributeSet
	)
	target.definition.attributes.agility = 1
	var resolver: AttackResolver = AttackResolver.new()
	resolver.set_test_roll_mode(
		AttackResolver.TestRollMode.FORCE_FULL_NEGATION
	)

	for durability_index: int in range(5):
		actor.restore_actions_to_maximum()
		target.restore_actions_to_maximum()

		var request: ActionRequest = ActionRequest.new(
			actor.definition.battler_id,
			target.definition.battler_id,
			actor.get_usable_main_hand_weapon(),
			200 + durability_index
		)
		request.attack_dice_modifier = -99
		request.suppress_skill_modification = true
		var context: ReactionContext = resolver.prepare_attack(
			request,
			actor,
			target
		)
		var result: ActionResult = resolver.resolve_reaction(
			context,
			actor,
			target,
			DefenseChoice.Type.ARMOR
		)

		_expect(
			result.weapon_durability_event,
			"Every fully negated successful Attack must damage the weapon."
		)
		_expect(
			result.weapon_durability_after
			== durability_index + 1,
			"Weapon durability must increase exactly once per Attack."
		)

	_expect(
		actor.weapon_state.is_broken,
		"Weapon must become Broken at five durability damage."
	)
	_expect(
		actor.get_usable_main_hand_weapon() == null,
		"A Broken weapon must be unusable."
	)


func _test_counterattack_uses_generated_attack_queue() -> void:
	var lysandra: BattlerState = _make_state(
		"res://data/battlers/heroines/lysandra.tres"
	)
	var hollow: BattlerState = _make_state(
		"res://data/battlers/enemies/hollow_servant.tres"
	)
	hollow.armor_state = null
	hollow.shield_state = null
	var states: Dictionary = {}
	states[lysandra.definition.battler_id] = lysandra
	states[hollow.definition.battler_id] = hollow
	var runtime: BattleRuntimeState = BattleRuntimeState.new()
	var resolver: AttackResolver = AttackResolver.new()
	var flow: BattleFlowController = BattleFlowController.new()
	flow.initialize(
		states,
		runtime.battle_state,
		DiceResolver.new(),
		1
	)
	flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST
	)
	hollow.set_current_actions(1)
	resolver.set_test_roll_mode(
		AttackResolver.TestRollMode.FORCE_ATTACK_HIT
	)
	var controller: BattleActionController = (
		BattleActionController.new()
	)
	controller.initialize(
		states,
		runtime,
		resolver,
		flow,
		300
	)

	_expect(
		controller.begin_attack_targeting().is_empty(),
		"Normal Attack targeting should begin."
	)

	var context: ReactionContext = controller.prepare_attack(
		hollow.definition.battler_id
	)
	_expect(
		context.is_valid,
		"Normal Attack should create a ReactionContext."
	)

	var result: ActionResult = (
		controller.resolve_attack_reaction(
			AttackReactionChoice.Type.COUNTERATTACK
		)
	)
	_expect(
		result.counterattack_requested,
		"Counterattack choice must be retained until damage resolves."
	)
	var counter_queue_error: String = controller.enqueue_result_follow_up(result)
	_expect(
		counter_queue_error.is_empty(),
		"Surviving defender should queue a Counterattack: %s"
		% counter_queue_error
	)
	_expect(
		controller.has_queued_attacks(),
		"Counterattack must enter the generated Attack queue."
	)

	var hollow_actions_before: int = hollow.current_actions
	var counter_context: ReactionContext = (
		controller.prepare_next_queued_attack()
	)
	_expect(
		counter_context.is_valid,
		"Queued Counterattack must use the normal Attack resolver."
	)
	if not counter_context.is_valid:
		return
	_expect(
		counter_context.request.source
		== ActionRequest.Source.COUNTERATTACK,
		"Queued request must retain the Counterattack source."
	)
	_expect(
		counter_context.request.reaction_mode
		== ActionRequest.ReactionMode.FULL,
		"Attack reactions must open the full revised reaction set."
	)
	_expect(
		hollow.current_actions == hollow_actions_before - 1,
		"Counterattack Action must be paid after survival."
	)


func _test_parry_free_attack_rules_and_chain_penalties() -> void:
	var lysandra: BattlerState = _make_state(
		"res://data/battlers/heroines/lysandra.tres"
	)
	var knife: BattlerState = _make_state(
		"res://data/battlers/enemies/knife_footman.tres"
	)
	var miss_resolver := AttackResolver.new()
	miss_resolver.set_test_roll_mode(
		AttackResolver.TestRollMode.FORCE_NATURAL_MISS
	)
	var miss_request := ActionRequest.new(
		knife.definition.battler_id,
		lysandra.definition.battler_id,
		knife.get_usable_main_hand_weapon(),
		330
	)
	var miss_context := miss_resolver.prepare_attack(
		miss_request,
		knife,
		lysandra
	)
	var zero_parry := miss_resolver.resolve_reaction(
		miss_context,
		knife,
		lysandra,
		DefenseChoice.Type.PARRY
	)
	_expect(
		zero_parry.succeeded
		and zero_parry.attack_successes == 0
		and not zero_parry.parry_should_generate_free_attack,
		"Parrying a zero-success Attack must not create a free Attack."
	)

	lysandra = _make_state(
		"res://data/battlers/heroines/lysandra.tres"
	)
	knife = _make_state(
		"res://data/battlers/enemies/knife_footman.tres"
	)
	lysandra.definition = lysandra.definition.duplicate(true) as BattlerDefinition
	lysandra.definition.attributes = (
		lysandra.definition.attributes.duplicate(true) as AttributeSet
	)
	lysandra.definition.attributes.agility = 4
	knife.definition = knife.definition.duplicate(true) as BattlerDefinition
	knife.definition.attributes = (
		knife.definition.attributes.duplicate(true) as AttributeSet
	)
	knife.definition.attributes.agility = 4
	knife.definition.attributes.might = 4
	knife.weapon_state = WeaponState.new(
		load(
			"res://scripts/data/equipment/weapons/lysandra_sword.tres"
		) as WeaponDefinition,
		1
	)
	var states: Dictionary = {
		lysandra.definition.battler_id: lysandra,
		knife.definition.battler_id: knife,
	}
	var runtime := BattleRuntimeState.new()
	var resolver := AttackResolver.new()
	resolver.set_test_roll_mode(
		AttackResolver.TestRollMode.FORCE_FULL_NEGATION
	)
	var flow := BattleFlowController.new()
	flow.initialize(states, runtime.battle_state, DiceResolver.new(), 1)
	flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST
	)
	knife.restore_actions_to_maximum()
	var controller := BattleActionController.new()
	controller.initialize(states, runtime, resolver, flow, 340)
	_expect(
		controller.begin_attack_targeting().is_empty(),
		"Parry-chain fixture should begin Attack targeting."
	)
	var first_context := controller.prepare_attack(
		knife.definition.battler_id
	)
	var first_parry := controller.resolve_reaction(
		DefenseChoice.Type.PARRY
	)
	_expect(
		first_context.is_valid
		and first_parry.parry_should_generate_free_attack,
		(
			"A successful first Parry should generate a free Attack: "
			+ "context='%s', result='%s', attack=%d, defense=%d, effective=%d."
			% [
				first_context.error_message,
				first_parry.error_message,
				first_parry.attack_successes,
				first_parry.defense_successes,
				first_parry.effective_defense_successes,
			]
		)
	)
	_expect(
		controller.enqueue_result_follow_up(first_parry).is_empty(),
		"First Parry free Attack should enter the queue."
	)
	var second_context := controller.prepare_next_queued_attack()
	_expect(
		second_context.is_valid
		and second_context.request.parry_sequence_index == 1
		and resolver.get_parry_penalty(second_context) == 2,
		"The first chained response must Parry at -2d10."
	)
	var second_parry := controller.resolve_reaction(
		DefenseChoice.Type.PARRY
	)
	_expect(
		second_parry.parry_should_generate_free_attack,
		(
			"The second successful Parry should continue the exchange: "
			+ "error='%s', attack=%d, defense=%d, effective=%d."
			% [
				second_parry.error_message,
				second_parry.attack_successes,
				second_parry.defense_successes,
				second_parry.effective_defense_successes,
			]
		)
	)
	var second_queue_error: String = controller.enqueue_result_follow_up(
		second_parry
	)
	_expect(
		second_queue_error.is_empty(),
		"Second Parry free Attack should enter the queue: %s"
		% second_queue_error
	)
	var third_context := controller.prepare_next_queued_attack()
	_expect(
		third_context.is_valid
		and third_context.request.parry_sequence_index == 2
		and resolver.get_parry_penalty(third_context) == 3,
		"The second chained response must Parry at -3d10."
	)


func _test_dodge_mitigation_action_cost_and_optional_step() -> void:
	var attacker: BattlerState = _make_state(
		"res://data/battlers/enemies/hollow_servant.tres"
	)
	var defender: BattlerState = _make_state(
		"res://data/battlers/heroines/lysandra.tres"
	)
	var resolver := AttackResolver.new()
	resolver.set_test_roll_mode(
		AttackResolver.TestRollMode.FORCE_FULL_NEGATION
	)
	var request := ActionRequest.new(
		attacker.definition.battler_id,
		defender.definition.battler_id,
		attacker.get_usable_main_hand_weapon(),
		360
	)
	var context := resolver.prepare_attack(
		request,
		attacker,
		defender
	)
	var actions_before: int = defender.current_actions
	var hp_before: int = defender.current_hp
	var dodge_result := resolver.resolve_reaction(
		context,
		attacker,
		defender,
		DefenseChoice.Type.DODGE
	)
	_expect(
		dodge_result.succeeded
		and defender.current_actions == actions_before - 1
		and dodge_result.reaction_action_spent == 1,
		"Dodge must spend exactly one saved Action."
	)
	_expect(
		dodge_result.effective_defense_successes > 0
		and dodge_result.remaining_attack_successes == 0
		and defender.current_hp == hp_before,
		"Dodge successes must mitigate incoming Attack successes."
	)
	_expect(
		dodge_result.dodge_step_available,
		"Preventing damage with Dodge must offer one optional step."
	)


func _test_grappled_heroine_reaction_restrictions() -> void:
	var lysandra: BattlerState = _make_state(
		"res://data/battlers/heroines/lysandra.tres"
	)
	var knife: BattlerState = _make_state(
		"res://data/battlers/enemies/knife_footman.tres"
	)
	lysandra.add_grapple_track(&"test_grapple")

	var resolver: AttackResolver = AttackResolver.new()
	resolver.set_test_roll_mode(
		AttackResolver.TestRollMode.FORCE_ATTACK_HIT
	)
	var request: ActionRequest = ActionRequest.new(
		knife.definition.battler_id,
		lysandra.definition.battler_id,
		knife.get_usable_main_hand_weapon(),
		350
	)
	var context: ReactionContext = resolver.prepare_attack(
		request,
		knife,
		lysandra
	)
	_expect(
		context.is_valid,
		"Knife Footman should be able to commit the test Attack."
	)

	var dodge_result: ActionResult = resolver.resolve_reaction(
		context,
		knife,
		lysandra,
		DefenseChoice.Type.DODGE
	)
	_expect(
		not dodge_result.succeeded,
		"Grappled heroines must not Dodge ordinary Attacks."
	)
	var parry_result: ActionResult = resolver.resolve_reaction(
		context,
		knife,
		lysandra,
		DefenseChoice.Type.PARRY
	)
	_expect(
		not parry_result.succeeded,
		"Grappled heroines must not Parry ordinary Attacks."
	)
	var armor_result: ActionResult = resolver.resolve_reaction(
		context,
		knife,
		lysandra,
		DefenseChoice.Type.ARMOR
	)
	_expect(
		armor_result.succeeded,
		"Grappled heroines may still use legal Armor Defense."
	)

	var states: Dictionary = {
		lysandra.definition.battler_id: lysandra,
		knife.definition.battler_id: knife,
	}
	var runtime: BattleRuntimeState = BattleRuntimeState.new()
	runtime.pending_reaction_context = context
	var controller: BattleActionController = (
		BattleActionController.new()
	)
	controller.initialize(
		states,
		runtime,
		resolver,
		null,
		351
	)
	_expect(
		not controller.can_counterattack(lysandra),
		"Grappled heroines must not Counterattack."
	)


func _test_generated_attack_queue_is_bounded() -> void:
	var queue: AttackResolutionQueue = AttackResolutionQueue.new()
	var request: ActionRequest = ActionRequest.new()

	for _index: int in range(
		AttackResolutionQueue.MAXIMUM_GENERATED_ATTACKS
	):
		_expect(
			queue.enqueue(request).is_empty(),
			"Queue should accept requests below its safety limit."
		)

	_expect(
		not queue.enqueue(request).is_empty(),
		"Queue must reject a generated Attack beyond its safety limit."
	)


func _make_state(
	resource_path: String
) -> BattlerState:
	var definition: BattlerDefinition = load(
		resource_path
	) as BattlerDefinition

	_expect(
		definition != null,
		"Battler definition must load: %s" % resource_path
	)

	return BattlerState.new(definition)


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	failures += 1
	push_error(message)
