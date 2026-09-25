extends SceneTree


var failures: int = 0


func _init() -> void:
	_test_group_rule_and_forecast_visibility()
	_test_individual_rulebook_reevaluation()
	_test_reaction_rulebook_choices()
	_test_grapple_rulebook_lifecycle()
	_test_grapple_cooldown_counts_complete_activations()
	_test_full_wipe_forces_progress_and_suppresses_other_actions()
	_test_complete_three_enemy_phase_decisions()

	if failures == 0:
		print("Enemy AI rulebook tests passed.")
	else:
		push_error(
			"%d enemy AI rulebook test(s) failed."
			% failures
		)

	quit(failures)


func _test_group_rule_and_forecast_visibility() -> void:
	var fixture: Dictionary = _make_fixture()
	var ai: EnemyAIController = fixture.get(
		"ai"
	) as EnemyAIController
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var seraphine: BattlerState = battlers.get(&"seraphine") as BattlerState
	seraphine.apply_damage(1)

	_expect(
		ai.begin_enemy_phase().is_empty(),
		"Enemy AI should begin in the active Enemy Phase."
	)
	_expect(
		ai.activation_order == [
			&"prayer_rag_novice",
			&"knife_footman",
			&"hollow_servant",
		],
		"Living Prayer-Rag Novice should trigger the support-first group rule."
	)

	var decision: EnemyDecision = ai.get_next_decision()
	_expect(
		decision != null
		and decision.type == EnemyDecision.Type.ABILITY
		and decision.actor_id == &"prayer_rag_novice"
		and decision.target_id == &"seraphine"
		and decision.ability_id == &"prayer_rag_dark_prayer",
		"Prayer-Rag Novice should use Dark Prayer on the injured legal target. Actual: %s\n%s"
		% [decision.summary if decision != null else "<null>", ai.get_debug_text()]
	)
	_expect(
		ai.get_pending_forecast() == "Forecast: Hidden (Standard)",
		"Standard must not reveal the pending enemy decision."
	)

	ai.set_difficulty(EnemyAIController.Difficulty.EASY)
	_expect(
		ai.get_pending_forecast().contains(
			"Prayer-Rag Novice → Dark Prayer on Seraphine"
		),
		"Easy should reveal the same deterministic decision as Forecast."
	)


func _test_individual_rulebook_reevaluation() -> void:
	var fixture: Dictionary = _make_fixture()
	var ai: EnemyAIController = fixture.get(
		"ai"
	) as EnemyAIController
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var seraphine: BattlerState = battlers.get(&"seraphine") as BattlerState
	seraphine.apply_damage(1)

	ai.begin_enemy_phase()
	var prayer: BattlerState = battlers.get(
		&"prayer_rag_novice"
	) as BattlerState
	prayer.set_current_actions(0)

	var move_decision: EnemyDecision = ai.get_next_decision()
	_expect(
		move_decision != null
		and move_decision.actor_id == &"knife_footman"
		and move_decision.type == EnemyDecision.Type.MOVE
		and move_decision.target_id == &"seraphine",
		"Knife Footman should move toward an engageable heroine when no Attack is legal. Actual: %s\n%s"
		% [move_decision.summary if move_decision != null else "<null>", ai.get_debug_text()]
	)
	if move_decision == null:
		return

	var knife: BattlerState = battlers.get(
		&"knife_footman"
	) as BattlerState
	knife.spend_actions(1)
	var placement_error: String = battlefield.place_battler(
		&"knife_footman",
		move_decision.move_preview.destination_anchor_id,
		move_decision.destination_position_index
	)
	_expect(
		placement_error.is_empty(),
		"Knife Footman's selected Move destination should remain legal: %s"
		% placement_error
	)
	if not placement_error.is_empty():
		return
	ai.complete_pending_decision()

	var attack_decision: EnemyDecision = ai.get_next_decision()
	_expect(
		attack_decision != null
		and attack_decision.actor_id == &"knife_footman"
		and attack_decision.type == EnemyDecision.Type.ATTACK
		and attack_decision.target_id == &"seraphine",
		"Knife Footman should reevaluate after Move and Attack from the new Anchor."
	)
	_expect(
		ai.get_debug_text().contains("MATCHED"),
		"AI debug inspection should show the first matched individual rule."
	)


func _test_reaction_rulebook_choices() -> void:
	var fixture: Dictionary = _make_fixture()
	var ai: EnemyAIController = fixture.get(
		"ai"
	) as EnemyAIController
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var action_controller: BattleActionController = fixture.get(
		"action_controller"
	) as BattleActionController

	var knife: BattlerState = battlers.get(
		&"knife_footman"
	) as BattlerState
	_expect(
		ai.choose_attack_reaction(knife, true)
		== AttackReactionChoice.Type.COUNTERATTACK,
		"Knife Footman should Counterattack when its authored policy is legal."
	)

	var hollow: BattlerState = battlers.get(
		&"hollow_servant"
	) as BattlerState
	_expect(
		ai.choose_defense(hollow, action_controller)
		== DefenseChoice.Type.ARMOR,
		"Hollow Servant should prefer its authored Armor Defense."
	)

	_expect(
		ai.choose_move_reactor(
			[&"hollow_servant", &"knife_footman"]
		) == &"knife_footman",
		"Highest authored Move Reaction priority should win deterministically."
	)


func _test_grapple_rulebook_lifecycle() -> void:
	var fixture: Dictionary = _make_fixture()
	var ai: EnemyAIController = fixture.get("ai") as EnemyAIController
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var grapple: GrappleController = fixture.get(
		"grapple"
	) as GrappleController
	var hollow: BattlerState = battlers.get(
		&"hollow_servant"
	) as BattlerState
	var prayer: BattlerState = battlers.get(
		&"prayer_rag_novice"
	) as BattlerState
	var knife: BattlerState = battlers.get(
		&"knife_footman"
	) as BattlerState

	_expect(
		battlefield.place_battler(
			&"hollow_servant",
			&"altar_left",
			2
		).is_empty(),
		"The AI Grapple fixture should place Hollow Servant beside Lysandra."
	)
	prayer.set_current_actions(0)
	knife.set_current_actions(0)
	ai.begin_enemy_phase()

	var initiate: EnemyDecision = ai.get_next_decision()
	_expect(
		initiate != null
		and initiate.type == EnemyDecision.Type.GRAPPLE
		and initiate.target_id == &"lysandra",
		"Hollow Servant should prioritize a legal authored Grapple."
	)
	if initiate == null:
		return
	var attempt: GrappleAttemptResult = grapple.prepare_initiation(
		initiate.actor_id,
		initiate.target_id
	)
	_expect(
		attempt.error_message.is_empty(),
		"The AI-selected Grapple should pass shared revalidation."
	)
	if not attempt.error_message.is_empty():
		return
	grapple.resolve_initiation(false)
	ai.complete_pending_decision()
	_expect(
		hollow.current_actions == 0,
		"Successful ordinary Grapple should forfeit remaining Actions."
	)

	ai.end_enemy_phase()
	hollow.restore_actions_to_maximum()
	ai.begin_enemy_phase()
	var hold: EnemyDecision = ai.get_next_decision()
	_expect(
		hold != null
		and hold.type == EnemyDecision.Type.GRAPPLE_HOLD,
		"The next activation should follow the authored finite Hold rule."
	)
	if hold != null:
		grapple.hold_track(hold.actor_id)
		ai.complete_pending_decision()

	ai.end_enemy_phase()
	hollow.restore_actions_to_maximum()
	ai.begin_enemy_phase()
	var progress: EnemyDecision = ai.get_next_decision()
	_expect(
		progress != null
		and progress.type == EnemyDecision.Type.GRAPPLE_PROGRESS,
		"Exhausted Hold allowance should make Progress the next legal rule."
	)


func _test_grapple_cooldown_counts_complete_activations() -> void:
	var fixture: Dictionary = _make_fixture()
	var ai: EnemyAIController = fixture.get("ai") as EnemyAIController
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var hollow: BattlerState = battlers.get(
		&"hollow_servant"
	) as BattlerState
	var prayer: BattlerState = battlers.get(
		&"prayer_rag_novice"
	) as BattlerState
	var knife: BattlerState = battlers.get(
		&"knife_footman"
	) as BattlerState

	_expect(
		battlefield.place_battler(&"hollow_servant", &"altar_left", 2).is_empty(),
		"Cooldown fixture should place Hollow Servant beside Lysandra."
	)
	hollow.begin_grapple_cooldown(2)
	prayer.set_current_actions(0)
	knife.set_current_actions(0)

	for expected_remaining: int in [1, 0]:
		hollow.restore_actions_to_maximum()
		ai.begin_enemy_phase()
		var decision: EnemyDecision = ai.get_next_decision()
		_expect(
			decision != null
			and decision.type != EnemyDecision.Type.GRAPPLE,
			"Cooldown activations must keep Grapple illegal."
		)
		hollow.set_current_actions(0)
		ai.complete_pending_decision()
		ai.get_next_decision()
		_expect(
			hollow.grapple_cooldown_activations == expected_remaining,
			"Cooldown should decrement once after the blocked activation."
		)
		ai.end_enemy_phase()

	hollow.restore_actions_to_maximum()
	ai.begin_enemy_phase()
	var legal_again: EnemyDecision = ai.get_next_decision()
	_expect(
		legal_again != null
		and legal_again.type == EnemyDecision.Type.GRAPPLE,
		"Grapple should become legal on the activation after cooldown reaches zero."
	)


func _test_full_wipe_forces_progress_and_suppresses_other_actions() -> void:
	var fixture: Dictionary = _make_fixture()
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var grapple: GrappleController = fixture.get(
		"grapple"
	) as GrappleController
	var ai: EnemyAIController = fixture.get(
		"ai"
	) as EnemyAIController

	_expect(
		battlefield.place_battler(&"hollow_servant", &"altar_left", 2).is_empty(),
		"Full-wipe fixture should place Hollow Servant beside Lysandra."
	)
	var attempt: GrappleAttemptResult = grapple.prepare_initiation(
		&"hollow_servant",
		&"lysandra"
	)
	_expect(
		attempt.error_message.is_empty(),
		"Full-wipe fixture should prepare a legal Grapple: %s"
		% attempt.error_message
	)
	if not attempt.error_message.is_empty():
		return
	attempt = grapple.resolve_initiation(false)
	_expect(attempt.succeeded, "Full-wipe fixture should create a Grapple track.")
	if not attempt.succeeded:
		return
	(battlers.get(&"hollow_servant") as BattlerState).restore_actions_to_maximum()
	for heroine_id: StringName in [&"lysandra", &"mira", &"seraphine"]:
		var heroine: BattlerState = battlers.get(
			heroine_id
		) as BattlerState
		heroine.apply_damage(heroine.current_hp)

	_expect(
		ai.begin_enemy_phase().is_empty(),
		"Full-wipe AI test should begin during the Enemy Phase."
	)
	var found_grappler: bool = false
	for decision_index: int in range(6):
		var decision: EnemyDecision = ai.get_next_decision()
		if decision == null:
			break
		var actor: BattlerState = battlers.get(
			decision.actor_id
		) as BattlerState
		if decision.actor_id == &"hollow_servant":
			found_grappler = true
			_expect(
				decision.type
				== EnemyDecision.Type.GRAPPLE_PROGRESS,
				"An attached grappler must force Progress after full wipe."
			)
			break
		_expect(
			decision.type == EnemyDecision.Type.WAIT,
			"Unattached enemies must take no meaningful full-wipe Action."
		)
		actor.set_current_actions(0)
		ai.complete_pending_decision()

	_expect(
		found_grappler,
		"The full-wipe decision pass should reach the attached grappler."
	)


func _test_complete_three_enemy_phase_decisions() -> void:
	var fixture: Dictionary = _make_fixture()
	var ai: EnemyAIController = fixture.get(
		"ai"
	) as EnemyAIController
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var runtime: BattleRuntimeState = fixture.get(
		"runtime"
	) as BattleRuntimeState
	var movement: BattleMovementController = fixture.get(
		"movement"
	) as BattleMovementController
	var action_controller: BattleActionController = fixture.get(
		"action_controller"
	) as BattleActionController
	var ability_controller: AbilityActionController = fixture.get(
		"ability_controller"
	) as AbilityActionController

	ai.begin_enemy_phase()
	var safety_counter: int = 0

	while safety_counter < 30:
		safety_counter += 1
		var decision: EnemyDecision = ai.get_next_decision()
		if decision == null:
			break

		var actor: BattlerState = battlers.get(
			decision.actor_id
		) as BattlerState
		match decision.type:
			EnemyDecision.Type.ATTACK:
				runtime.selected_battler_id = decision.actor_id
				action_controller.attack_seed = (
					ai.get_next_attack_seed()
				)
				var begin_error: String = (
					action_controller.begin_attack_targeting()
				)
				_expect(
					begin_error.is_empty(),
					"AI Attack should pass the shared active-actor validation."
				)
				if not begin_error.is_empty():
					actor.set_current_actions(0)
				else:
					var context: ReactionContext = (
						action_controller.prepare_attack(
							decision.target_id
						)
					)
					_expect(
						context.is_valid,
						"AI Attack should pass shared spatial revalidation."
					)
					if context.is_valid:
						var result: ActionResult = (
							action_controller.resolve_reaction(
								DefenseChoice.Type.SKIP
							)
						)
						_expect(
							result.succeeded,
							"AI Attack should resolve through the shared kernel."
						)
						action_controller.clear_pending_reaction()

			EnemyDecision.Type.MOVE:
				runtime.begin_move_targeting(decision.actor_id)
				var move_state: CommittedMoveState = (
					movement.begin_committed_move(
						decision.move_preview,
						decision.destination_position_index
					)
				)
				_expect(
					move_state.is_valid,
					"AI Move should commit through the shared movement controller."
				)
				if move_state.is_valid:
					while not move_state.is_complete:
						for reactor_id: StringName in movement.get_active_move_reactor_ids():
							_expect(
								movement.mark_active_move_reaction_declined(reactor_id).is_empty(),
								"Phase-driver Move Reaction should be explicitly declined."
							)
						var advance_error: String = movement.advance_active_move_step()
						_expect(
							advance_error.is_empty(),
							"AI Move step should advance: %s" % advance_error
						)
						if not advance_error.is_empty():
							actor.set_current_actions(0)
							break
					movement.finish_active_move()

			EnemyDecision.Type.GRAPPLE:
				var grapple: GrappleController = fixture.get(
					"grapple"
				) as GrappleController
				var attempt: GrappleAttemptResult = (
					grapple.prepare_initiation(
						decision.actor_id,
						decision.target_id
					)
				)
				if attempt.error_message.is_empty():
					grapple.resolve_initiation(false)
				else:
					actor.spend_actions(1)

			EnemyDecision.Type.GRAPPLE_HOLD:
				(
					fixture.get("grapple") as GrappleController
				).hold_track(decision.actor_id)

			EnemyDecision.Type.GRAPPLE_PROGRESS:
				(
					fixture.get("grapple") as GrappleController
				).progress_track(decision.actor_id)

			EnemyDecision.Type.ABILITY:
				var ability: AbilityDefinition = actor.get_ability(
					decision.ability_id
				)
				var legal_target_ids: Array[StringName] = (
					ability_controller.begin_targeting(
						decision.actor_id,
						ability
					)
				)
				_expect(
					legal_target_ids.has(decision.target_id),
					"AI ability target should pass shared revalidation."
				)
				if legal_target_ids.has(decision.target_id):
					var outcome: Variant = ability_controller.commit_target(
						decision.target_id
					)
					if outcome is ReactionContext:
						var context: ReactionContext = outcome as ReactionContext
						_expect(
							context.is_valid,
							"AI Attack ability should prepare through the shared resolver."
						)
						if context.is_valid:
							var result: ActionResult = action_controller.resolve_reaction(
								DefenseChoice.Type.SKIP
							)
							_expect(
								result.succeeded,
								"AI Attack ability should resolve through the shared kernel."
							)
							action_controller.clear_pending_reaction()
					else:
						_expect(
							(outcome as AbilityUseResult).succeeded,
							"AI direct ability should resolve through the shared controller."
						)
				else:
					actor.spend_actions(1)

			EnemyDecision.Type.WAIT:
				actor.set_current_actions(0)

		ai.complete_pending_decision()

	_expect(
		safety_counter < 30,
		"Enemy rulebooks must terminate without an infinite decision loop."
	)
	_expect(
		ai.is_phase_complete(),
		"All three enemies should spend or forfeit every Enemy Phase Action."
	)


func _make_fixture() -> Dictionary:
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
	var battlefield_definition: BattlefieldDefinition = load(
		"res://data/battlefields/ruined_chapel_spatial_test.tres"
	) as BattlefieldDefinition
	var battlefield: BattlefieldState = BattlefieldState.new()
	var spatial_error: String = battlefield.initialize(
		battlefield_definition,
		battlers
	)
	_expect(
		spatial_error.is_empty(),
		"Enemy AI fixture battlefield should initialize."
	)

	var state: BattleState = BattleState.new()
	var runtime: BattleRuntimeState = BattleRuntimeState.new()
	runtime.battle_state = state
	var flow: BattleFlowController = BattleFlowController.new()
	flow.initialize(
		battlers,
		state,
		DiceResolver.new(),
		2100
	)
	flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST
	)
	flow.end_current_phase()

	var movement: BattleMovementController = (
		BattleMovementController.new()
	)
	movement.initialize(
		battlers,
		battlefield,
		flow,
		runtime
	)

	var targeting: BattleTargetingController = (
		BattleTargetingController.new()
	)
	targeting.initialize(battlers, battlefield)

	var resolver: AttackResolver = AttackResolver.new()
	resolver.set_test_roll_mode(
		AttackResolver.TestRollMode.FORCE_NATURAL_MISS
	)
	var action_controller: BattleActionController = (
		BattleActionController.new()
	)
	action_controller.initialize(
		battlers,
		runtime,
		resolver,
		flow,
		2200,
		targeting
	)
	var statuses: StatusController = StatusController.new()
	statuses.initialize(
		battlers,
		[&"lysandra", &"mira", &"seraphine", &"hollow_servant", &"knife_footman", &"prayer_rag_novice"]
	)
	resolver.status_controller = statuses
	var ability_controller: AbilityActionController = AbilityActionController.new()
	ability_controller.initialize(
		battlers,
		runtime,
		flow,
		battlefield,
		targeting,
		resolver,
		statuses,
		DiceResolver.new(),
		2275
	)

	var grapple: GrappleController = GrappleController.new()
	grapple.initialize(
		battlers,
		battlefield,
		targeting,
		DiceResolver.new(),
		2250
	)

	var ai: EnemyAIController = EnemyAIController.new()
	ai.initialize(
		battlers,
		state,
		battlefield,
		movement,
		targeting,
		grapple,
		load(
			"res://data/enemy_ai/ruined_chapel_group_rulebook.tres"
		) as EnemyGroupRulebookDefinition,
		2300
	)

	return {
		"battlers": battlers,
		"battlefield": battlefield,
		"state": state,
		"runtime": runtime,
		"flow": flow,
		"movement": movement,
		"targeting": targeting,
		"action_controller": action_controller,
		"ability_controller": ability_controller,
		"grapple": grapple,
		"ai": ai,
	}


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	failures += 1
	push_error(message)
