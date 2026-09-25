extends SceneTree


var failures: int = 0


func _init() -> void:
	_test_successful_grapple_reaction_interrupts_route()
	_test_failed_grapple_reaction_preserves_route()
	_test_rulebook_selects_grapple_and_attached_enemy_cannot_react()

	if failures == 0:
		print("Grapple Move Reaction tests passed.")
	else:
		push_error(
			"%d Grapple Move Reaction test(s) failed." % failures
		)

	quit(failures)


func _test_successful_grapple_reaction_interrupts_route() -> void:
	var fixture: Dictionary = _make_fixture(5100)
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var movement: BattleMovementController = fixture.get(
		"movement"
	) as BattleMovementController
	var grapple: GrappleController = fixture.get(
		"grapple"
	) as GrappleController
	var hollow: BattlerState = battlers.get(
		&"hollow_servant"
	) as BattlerState

	var move_state: CommittedMoveState = _begin_two_step_lysandra_move(
		movement
	)
	if move_state == null:
		return

	_expect(
		movement.advance_active_move_step().is_empty(),
		"Lysandra should reach Central Nave before the reaction."
	)
	_expect(
		movement.get_active_move_reactor_ids()
		== [&"hollow_servant"],
		"Hollow Servant should receive the reached-Anchor reaction."
	)
	_expect(
		movement.mark_active_move_reaction_used(
			&"hollow_servant"
		).is_empty(),
		"The Grapple Reaction opportunity should be consumed."
	)

	var actions_before: int = hollow.current_actions
	var attempt: GrappleAttemptResult = grapple.prepare_initiation(
		&"hollow_servant",
		&"lysandra",
		true
	)
	_expect(
		attempt.error_message.is_empty()
		and attempt.is_move_reaction,
		"The reached-Anchor Grapple Reaction should prepare normally."
	)
	if not attempt.error_message.is_empty():
		return

	attempt = grapple.resolve_initiation(false)
	_expect(
		attempt.succeeded,
		"Skip should allow the Grapple Reaction to succeed."
	)
	_expect(
		hollow.current_actions == actions_before - 1,
		"A successful Grapple Reaction should retain all Actions beyond its one-Action cost."
	)
	_expect(
		movement.interrupt_active_move(
			"Lysandra was Grappled."
		).is_empty(),
		"A successful Grapple Reaction should interrupt the route."
	)
	_expect(
		move_state.is_complete
		and move_state.stopped_early
		and move_state.get_current_anchor_id() == &"central_nave",
		"The heroine should stop at the exact Position where Grapple succeeded."
	)
	_expect(
		movement.get_active_move_reactor_ids().is_empty(),
		"Successful Grapple should expire every later reaction window."
	)


func _test_failed_grapple_reaction_preserves_route() -> void:
	var fixture: Dictionary = _make_fixture(5200)
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var movement: BattleMovementController = fixture.get(
		"movement"
	) as BattleMovementController
	var grapple: GrappleController = fixture.get(
		"grapple"
	) as GrappleController
	var lysandra: BattlerState = battlers.get(
		&"lysandra"
	) as BattlerState
	var hollow: BattlerState = battlers.get(
		&"hollow_servant"
	) as BattlerState
	lysandra.definition = lysandra.definition.duplicate(true) as BattlerDefinition
	lysandra.definition.attributes = (
		lysandra.definition.attributes.duplicate(true) as AttributeSet
	)
	lysandra.definition.attributes.agility = 10

	var move_state: CommittedMoveState = _begin_two_step_lysandra_move(
		movement
	)
	if move_state == null:
		return
	movement.advance_active_move_step()
	movement.mark_active_move_reaction_used(&"hollow_servant")

	var hollow_actions_before: int = hollow.current_actions
	var heroine_actions_before: int = lysandra.current_actions
	var attempt: GrappleAttemptResult = grapple.prepare_initiation(
		&"hollow_servant",
		&"lysandra",
		true
	)
	if not attempt.error_message.is_empty():
		_expect(false, attempt.error_message)
		return
	attempt = grapple.resolve_initiation(true)

	_expect(
		not attempt.succeeded,
		"The high-Agility seeded Dodge should prevent Grapple."
	)
	_expect(
		hollow.current_actions == hollow_actions_before - 1,
		"A failed Grapple Reaction should still spend one reactor Action."
	)
	_expect(
		lysandra.current_actions == heroine_actions_before - 1,
		"Dodge should spend one heroine Action."
	)
	_expect(
		not move_state.is_complete
		and movement.advance_active_move_step().is_empty()
		and move_state.is_complete,
		"A failed Grapple Reaction should allow the remaining route to continue."
	)
	_expect(
		not lysandra.is_grappled(),
		"A prevented Grapple Reaction should create no track."
	)


func _test_rulebook_selects_grapple_and_attached_enemy_cannot_react() -> void:
	var fixture: Dictionary = _make_fixture(5300)
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var movement: BattleMovementController = fixture.get(
		"movement"
	) as BattleMovementController
	var grapple: GrappleController = fixture.get(
		"grapple"
	) as GrappleController
	var ai: EnemyAIController = fixture.get("ai") as EnemyAIController
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	_expect(
		battlefield.place_battler(&"lysandra", &"central_nave", 2).is_empty(),
		"Reaction-policy fixture should place Lysandra beside Hollow Servant."
	)

	_expect(
		ai.choose_move_reaction_action(
			&"hollow_servant",
			&"lysandra"
		) == EnemyAIController.MoveReactionAction.GRAPPLE,
		"Hollow Servant's authored reaction policy should choose Grapple when legal."
	)
	_expect(
		ai.choose_move_reaction_action(
			&"knife_footman",
			&"lysandra"
		) == EnemyAIController.MoveReactionAction.ATTACK,
		"Knife Footman's authored reaction policy should remain Attack."
	)

	var attempt: GrappleAttemptResult = grapple.prepare_initiation(
		&"hollow_servant",
		&"lysandra",
		true
	)
	if not attempt.error_message.is_empty():
		_expect(false, attempt.error_message)
		return
	grapple.resolve_initiation(false)
	_expect(
		grapple.force_move_cluster(&"lysandra", &"altar_left", 2).is_empty(),
		"Attached-reaction fixture should return the cluster to Altar Left."
	)

	var seraphine_previews: Array[MovementPreview] = (
		movement.begin_move_selection(&"seraphine")
	)
	var preview: MovementPreview = _find_preview(
		seraphine_previews,
		[&"altar_right", &"altar_left"]
	)
	_expect(
		preview != null,
		"Seraphine should be able to enter the attached cluster's Anchor."
	)
	if preview == null:
		return
	var move_state: CommittedMoveState = (
		movement.begin_committed_move(preview, 3)
	)
	_expect(move_state.is_valid, "Seraphine's test Move should commit.")
	if not move_state.is_valid:
		return
	movement.advance_active_move_step()
	_expect(
		movement.get_active_move_reactor_ids().is_empty(),
		"An attached grappler must receive no Move Reaction opportunity."
	)


func _begin_two_step_lysandra_move(
	movement: BattleMovementController
) -> CommittedMoveState:
	var previews: Array[MovementPreview] = (
		movement.begin_move_selection(&"lysandra")
	)
	var preview: MovementPreview = _find_preview(
		previews,
		[&"altar_left", &"central_nave", &"left_nave"]
	)
	_expect(
		preview != null,
		"The two-step Grapple Reaction route should exist."
	)
	if preview == null:
		return null

	var move_state: CommittedMoveState = (
		movement.begin_committed_move(preview, 1)
	)
	_expect(
		move_state.is_valid,
		"The two-step Grapple Reaction route should commit."
	)
	return move_state


func _make_fixture(
	seed_value: int
) -> Dictionary:
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
		BattleBootstrap.new().create_battler_states(definitions)
	)
	var battlefield: BattlefieldState = BattlefieldState.new()
	var field_definition: BattlefieldDefinition = load(
		"res://data/battlefields/ruined_chapel_spatial_test.tres"
	) as BattlefieldDefinition
	var error: String = battlefield.initialize(
		field_definition,
		battlers
	)
	_expect(error.is_empty(), "The reaction fixture battlefield should load.")

	error = battlefield.place_battler(
		&"hollow_servant",
		&"central_nave",
		1
	)
	_expect(error.is_empty(), "Hollow Servant should occupy Central Nave.")
	error = battlefield.place_battler(
		&"knife_footman",
		&"left_nave",
		0
	)
	_expect(error.is_empty(), "Knife Footman should leave Central Nave.")

	var state: BattleState = BattleState.new()
	var flow: BattleFlowController = BattleFlowController.new()
	flow.initialize(
		battlers,
		state,
		DiceResolver.new(),
		seed_value + 100
	)
	flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST
	)
	var runtime: BattleRuntimeState = BattleRuntimeState.new()
	runtime.battle_state = state
	var movement: BattleMovementController = BattleMovementController.new()
	movement.initialize(battlers, battlefield, flow, runtime)
	var targeting: BattleTargetingController = BattleTargetingController.new()
	targeting.initialize(battlers, battlefield)
	var grapple: GrappleController = GrappleController.new()
	grapple.initialize(
		battlers,
		battlefield,
		targeting,
		DiceResolver.new(),
		seed_value
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
		seed_value + 200
	)
	return {
		"battlers": battlers,
		"battlefield": battlefield,
		"runtime": runtime,
		"movement": movement,
		"grapple": grapple,
		"ai": ai,
	}


func _find_preview(
	previews: Array[MovementPreview],
	path: Array[StringName]
) -> MovementPreview:
	for preview: MovementPreview in previews:
		if preview != null and preview.anchor_path == path:
			return preview
	return null


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
