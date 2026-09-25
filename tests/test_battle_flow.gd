extends SceneTree


var failures: int = 0


func _init() -> void:
	_test_party_wins_order_ties()
	_test_party_momentum_locks_enemies_for_round_one()
	_test_phase_transition_preserves_then_refreshes_actions()
	_test_active_side_validation_and_heroine_interleaving()
	_test_saved_actions_remain_available_for_reactions()

	if failures == 0:
		print("Battle flow tests passed.")
	else:
		push_error(
			"%d battle flow test(s) failed."
			% failures
		)

	quit(failures)


func _test_party_wins_order_ties() -> void:
	var state: BattleState = BattleState.new()
	state.set_order(4, 4)

	_expect(
		state.first_side == BattleState.CombatSide.HEROES,
		"Party must win an Order tie."
	)
	_expect(
		state.momentum_side == BattleState.CombatSide.NONE,
		"An Order tie must not grant Momentum."
	)


func _test_party_momentum_locks_enemies_for_round_one() -> void:
	var fixture: Dictionary = _make_flow_fixture()
	var flow: BattleFlowController = fixture.get(
		"flow"
	) as BattleFlowController
	var state: BattleState = fixture.get(
		"state"
	) as BattleState
	var battlers: Dictionary = fixture.get(
		"battlers"
	) as Dictionary

	var error_message: String = flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_MOMENTUM
	)

	_expect(
		error_message.is_empty(),
		"Forced Party Momentum encounter should start."
	)
	_expect(
		state.phase == BattleState.Phase.HERO,
		"Party Order win must begin with Hero Phase."
	)
	_expect(
		state.momentum_side == BattleState.CombatSide.HEROES,
		"Party should own forced Momentum."
	)

	for enemy_id: StringName in [
		&"hollow_servant",
		&"knife_footman",
		&"prayer_rag_novice",
	]:
		var enemy: BattlerState = battlers.get(
			enemy_id
		) as BattlerState
		_expect(
			enemy.current_actions == 0,
			"Enemy Momentum loser must have zero Actions in round one."
		)

	flow.end_current_phase()
	_expect(
		state.phase == BattleState.Phase.ENEMY,
		"Losing side's round-one phase must still occur."
	)

	flow.end_current_phase()
	_expect(
		state.round_number == 2,
		"Ending both phases must start round two."
	)

	for enemy_id: StringName in [
		&"hollow_servant",
		&"knife_footman",
		&"prayer_rag_novice",
	]:
		var enemy: BattlerState = battlers.get(
			enemy_id
		) as BattlerState
		_expect(
			enemy.current_actions == enemy.get_max_actions(),
			"Momentum loser must refresh normally at Round Start 2."
		)


func _test_phase_transition_preserves_then_refreshes_actions() -> void:
	var fixture: Dictionary = _make_flow_fixture()
	var flow: BattleFlowController = fixture.get(
		"flow"
	) as BattleFlowController
	var state: BattleState = fixture.get(
		"state"
	) as BattleState
	var battlers: Dictionary = fixture.get(
		"battlers"
	) as Dictionary
	var lysandra: BattlerState = battlers.get(
		&"lysandra"
	) as BattlerState

	flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST
	)
	lysandra.spend_actions(1)

	flow.end_current_phase()
	_expect(
		state.phase == BattleState.Phase.ENEMY,
		"Second side phase should begin in the same round."
	)
	_expect(
		lysandra.current_actions == 2,
		"Leftover heroine Actions must remain during Enemy Phase."
	)

	flow.end_current_phase()
	_expect(
		state.round_number == 2,
		"Second phase completion must advance the round."
	)
	_expect(
		lysandra.current_actions == lysandra.get_max_actions(),
		"Round Start must discard leftovers and refresh to maximum."
	)


func _test_active_side_validation_and_heroine_interleaving() -> void:
	var fixture: Dictionary = _make_flow_fixture()
	var battlers: Dictionary = fixture.get(
		"battlers"
	) as Dictionary
	var runtime: BattleRuntimeState = BattleRuntimeState.new()
	var battle_state: BattleState = fixture.get(
		"state"
	) as BattleState
	var flow: BattleFlowController = fixture.get(
		"flow"
	) as BattleFlowController
	runtime.battle_state = battle_state
	var resolver: AttackResolver = AttackResolver.new()
	resolver.set_test_roll_mode(
		AttackResolver.TestRollMode.FORCE_NATURAL_MISS
	)
	var controller: BattleActionController = BattleActionController.new()
	controller.initialize(
		battlers,
		runtime,
		resolver,
		flow,
		300
	)

	flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST
	)

	runtime.selected_battler_id = &"hollow_servant"
	_expect(
		not controller.begin_attack_targeting().is_empty(),
		"Enemy Active Action must be rejected during Hero Phase."
	)

	runtime.selected_battler_id = &"lysandra"
	_resolve_natural_miss_attack(
		controller,
		&"hollow_servant"
	)

	runtime.selected_battler_id = &"mira"
	_resolve_natural_miss_attack(
		controller,
		&"hollow_servant"
	)

	var lysandra: BattlerState = battlers.get(
		&"lysandra"
	) as BattlerState
	var mira: BattlerState = battlers.get(
		&"mira"
	) as BattlerState

	_expect(
		lysandra.current_actions == 2,
		"Lysandra should spend exactly one interleaved Action."
	)
	_expect(
		mira.current_actions == 2,
		"Mira should act before Hero Phase ends."
	)


func _test_saved_actions_remain_available_for_reactions() -> void:
	var fixture: Dictionary = _make_flow_fixture()
	var battlers: Dictionary = fixture.get(
		"battlers"
	) as Dictionary
	var runtime: BattleRuntimeState = BattleRuntimeState.new()
	var battle_state: BattleState = fixture.get(
		"state"
	) as BattleState
	var flow: BattleFlowController = fixture.get(
		"flow"
	) as BattleFlowController
	runtime.battle_state = battle_state
	var resolver: AttackResolver = AttackResolver.new()
	resolver.set_test_roll_mode(
		AttackResolver.TestRollMode.FORCE_ATTACK_HIT
	)
	var controller: BattleActionController = BattleActionController.new()
	controller.initialize(
		battlers,
		runtime,
		resolver,
		flow,
		500
	)

	flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST
	)

	var lysandra: BattlerState = battlers.get(
		&"lysandra"
	) as BattlerState
	lysandra.spend_actions(1)
	flow.end_current_phase()

	runtime.selected_battler_id = &"hollow_servant"
	_expect(
		controller.begin_attack_targeting().is_empty(),
		"Enemy should take an Active Action during Enemy Phase."
	)
	var context: ReactionContext = controller.prepare_attack(
		&"lysandra"
	)
	_expect(
		context.is_valid,
		"Enemy Attack should create a heroine reaction."
	)
	var result: ActionResult = controller.resolve_reaction(
		DefenseChoice.Type.ARMOR
	)
	_expect(
		result.succeeded,
		"Saved heroine Action should pay for Armor Defense."
	)
	_expect(
		lysandra.current_actions == 1,
		"Heroine should retain and spend an Action during Enemy Phase."
	)


func _resolve_natural_miss_attack(
	controller: BattleActionController,
	target_id: StringName
) -> void:
	_expect(
		controller.begin_attack_targeting().is_empty(),
		"Active heroine should begin Attack targeting."
	)
	var context: ReactionContext = controller.prepare_attack(
		target_id
	)
	_expect(
		context.is_valid,
		"Interleaved Attack should create a ReactionContext."
	)
	var result: ActionResult = controller.resolve_reaction(
		DefenseChoice.Type.SKIP
	)
	_expect(
		result.succeeded,
		"Interleaved Attack should resolve."
	)
	controller.clear_pending_reaction()


func _make_flow_fixture() -> Dictionary:
	var definitions: Array[BattlerDefinition] = [
		load(
			"res://data/battlers/heroines/lysandra.tres"
		) as BattlerDefinition,
		load(
			"res://data/battlers/heroines/mira.tres"
		) as BattlerDefinition,
		load(
			"res://data/battlers/heroines/seraphine.tres"
		) as BattlerDefinition,
		load(
			"res://data/battlers/enemies/hollow_servant.tres"
		) as BattlerDefinition,
		load(
			"res://data/battlers/enemies/knife_footman.tres"
		) as BattlerDefinition,
		load(
			"res://data/battlers/enemies/prayer_rag_novice.tres"
		) as BattlerDefinition,
	]
	var battlers: Dictionary = (
		BattleBootstrap.new().create_battler_states(
			definitions
		)
	)
	var state: BattleState = BattleState.new()
	var flow: BattleFlowController = BattleFlowController.new()
	flow.initialize(
		battlers,
		state,
		DiceResolver.new(),
		700
	)

	return {
		"battlers": battlers,
		"state": state,
		"flow": flow,
	}


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	failures += 1
	push_error(message)
