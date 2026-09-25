extends SceneTree


var failures: int = 0


func _init() -> void:
	_test_empty_legal_target_collection()
	_test_melee_and_reach_legality()
	_test_ranged_cover_and_engagement_penalty()
	_test_magic_ignores_cover_but_respects_sight_blockers()
	_test_spatial_roll_modifier_reaches_resolver()
	_test_attack_pool_has_minimum_one_die()
	_test_committed_primary_attacks_advance_seed()
	_test_melee_and_reach_counterattacks_require_adjacency()
	_test_committed_move_reaction_uses_attack_queue()

	if failures == 0:
		print("Spatial combat integration tests passed.")
	else:
		push_error(
			"%d spatial combat integration test(s) failed."
			% failures
		)

	quit(failures)


func _test_empty_legal_target_collection() -> void:
	var fixture: Dictionary = _make_fixture()
	var action_controller: BattleActionController = fixture.get(
		"action_controller"
	) as BattleActionController
	var target_ids: Array[StringName] = (
		action_controller.get_legal_attack_target_ids()
	)

	_expect(
		target_ids.is_empty(),
		"No selected attacker should return an empty typed target list."
	)


func _test_melee_and_reach_legality() -> void:
	var fixture: Dictionary = _make_fixture()
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var targeting: BattleTargetingController = fixture.get(
		"targeting"
	) as BattleTargetingController
	var battlers: Dictionary = fixture.get("battlers") as Dictionary

	var lysandra: BattlerState = battlers.get(
		&"lysandra"
	) as BattlerState
	var sword: WeaponDefinition = lysandra.get_main_hand_weapon()
	var distant_melee: AttackTargetingResult = (
		targeting.evaluate_attack(
			&"lysandra",
			&"knife_footman",
			sword
		)
	)
	_expect(
		not distant_melee.is_legal,
		"Melee should reject a target in another Anchor."
	)

	_expect(battlefield.place_battler(
		&"lysandra",
		&"central_nave",
		2
	).is_empty(), "Melee fixture should place Lysandra in a free Nave position.")
	var adjacent_melee: AttackTargetingResult = (
		targeting.evaluate_attack(
			&"lysandra",
			&"knife_footman",
			sword
		)
	)
	_expect(
		adjacent_melee.is_legal,
		"Melee should allow a target in the same Anchor."
	)

	var seraphine: BattlerState = battlers.get(
		&"seraphine"
	) as BattlerState
	var reach_result: AttackTargetingResult = (
		targeting.evaluate_attack(
			&"seraphine",
			&"knife_footman",
			seraphine.get_main_hand_weapon()
		)
	)
	_expect(
		reach_result.is_legal,
		"Seraphine's Reach staff should cross one direct Anchor connection."
	)


func _test_ranged_cover_and_engagement_penalty() -> void:
	var fixture: Dictionary = _make_fixture()
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var targeting: BattleTargetingController = fixture.get(
		"targeting"
	) as BattleTargetingController

	var ranged_weapon: WeaponDefinition = WeaponDefinition.new()
	ranged_weapon.display_name = "Test Bow"
	ranged_weapon.attack_range = (
		WeaponDefinition.AttackRange.RANGED
	)
	ranged_weapon.maximum_zone_distance = 2

	_expect(battlefield.place_battler(
		&"seraphine",
		&"right_nave",
		1
	).is_empty(), "Cover fixture should place Seraphine in a free Right Nave position.")
	var cover_result: AttackTargetingResult = (
		targeting.evaluate_attack(
			&"seraphine",
			&"knife_footman",
			ranged_weapon
		)
	)
	_expect(
		not cover_result.is_legal
		and cover_result.blocked_by_cover,
		"Overturned Pews should deny the ordinary ranged line."
	)

	_expect(battlefield.place_battler(
		&"seraphine",
		&"central_nave",
		2
	).is_empty(), "Engagement fixture should place Seraphine in a free Nave position.")
	var engaged_result: AttackTargetingResult = (
		targeting.evaluate_attack(
			&"seraphine",
			&"hollow_servant",
			ranged_weapon
		)
	)
	_expect(
		engaged_result.is_legal,
		"An engaged ranged attacker may still select an unobstructed target."
	)
	_expect(
		engaged_result.attack_dice_modifier == -2,
		"Engaged ordinary ranged Attack should receive -2d10."
	)
	_expect(
		engaged_result.suppress_skill_modification,
		"Engaged ordinary ranged Attack should suppress Skill modification."
	)


func _test_magic_ignores_cover_but_respects_sight_blockers() -> void:
	var fixture: Dictionary = _make_fixture()
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var targeting: BattleTargetingController = fixture.get(
		"targeting"
	) as BattleTargetingController
	var battlers: Dictionary = fixture.get("battlers") as Dictionary

	var prayer: BattlerState = battlers.get(
		&"prayer_rag_novice"
	) as BattlerState
	var magic_weapon: WeaponDefinition = prayer.get_main_hand_weapon()

	_expect(battlefield.place_battler(
		&"prayer_rag_novice",
		&"right_nave",
		1
	).is_empty(), "Cover fixture should place the Novice in a free Right Nave position.")
	_expect(battlefield.place_battler(
		&"lysandra",
		&"central_nave",
		2
	).is_empty(), "Cover fixture should place Lysandra in a free Nave position.")
	var through_cover: AttackTargetingResult = (
		targeting.evaluate_attack(
			&"prayer_rag_novice",
			&"lysandra",
			magic_weapon,
			true
		)
	)
	_expect(
		through_cover.is_legal,
		"Magic should ignore ordinary ranged cover."
	)

	_expect(battlefield.place_battler(
		&"prayer_rag_novice",
		&"rear_gallery",
		1
	).is_empty(), "Sight fixture should place the Novice in the free Gallery position.")
	_expect(battlefield.place_battler(
		&"seraphine",
		&"altar_right",
		0
	).is_empty(), "Sight fixture should retain Seraphine at Altar Right.")
	var blocked_magic: AttackTargetingResult = (
		targeting.evaluate_attack(
			&"prayer_rag_novice",
			&"seraphine",
			magic_weapon,
			true
		)
	)
	_expect(
		not blocked_magic.is_legal
		and not blocked_magic.has_line_of_sight,
		"Collapsed Screen should block the authored magic sight line."
	)


func _test_spatial_roll_modifier_reaches_resolver() -> void:
	var fixture: Dictionary = _make_fixture()
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var seraphine: BattlerState = battlers.get(
		&"seraphine"
	) as BattlerState
	var hollow: BattlerState = battlers.get(
		&"hollow_servant"
	) as BattlerState
	var weapon: WeaponDefinition = seraphine.get_main_hand_weapon()

	var request: ActionRequest = ActionRequest.new(
		&"seraphine",
		&"hollow_servant",
		weapon,
		1600
	)
	request.attack_dice_modifier = -2
	request.suppress_skill_modification = true

	var resolver: AttackResolver = AttackResolver.new()
	resolver.set_test_roll_mode(
		AttackResolver.TestRollMode.FORCE_NATURAL_MISS
	)
	var context: ReactionContext = resolver.prepare_attack(
		request,
		seraphine,
		hollow
	)
	var expected_dice: int = maxi(
		seraphine.definition.attributes.get_value(
			weapon.attribute
		)
		+ weapon.dice_modifier
		- 2,
		1
	)

	_expect(
		context.is_valid,
		"Spatially modified request should remain a normal Attack request."
	)
	if not context.is_valid:
		return
	_expect(
		context.attack_roll.dice_requested == expected_dice,
		"AttackResolver should apply the targeting dice modifier."
	)
	_expect(
		context.attack_roll.skill_budget == 0,
		"AttackResolver should suppress Skill manipulation when requested."
	)


func _test_attack_pool_has_minimum_one_die() -> void:
	var fixture: Dictionary = _make_fixture()
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var attacker: BattlerState = battlers.get(
		&"prayer_rag_novice"
	) as BattlerState
	var target: BattlerState = battlers.get(
		&"lysandra"
	) as BattlerState
	var request := ActionRequest.new(
		attacker.definition.battler_id,
		target.definition.battler_id,
		attacker.get_main_hand_weapon(),
		1650
	)
	request.attack_dice_modifier = -99
	request.suppress_skill_modification = true

	var resolver := AttackResolver.new()
	resolver.set_test_roll_mode(
		AttackResolver.TestRollMode.FORCE_NATURAL_MISS
	)
	var context := resolver.prepare_attack(request, attacker, target)

	_expect(
		context.is_valid,
		"A penalized legal Attack should remain a valid committed Attack."
	)
	if not context.is_valid:
		return
	_expect(
		context.attack_roll.dice_requested == 1,
		"Every legal committed Attack must roll at least 1d10."
	)


func _test_committed_primary_attacks_advance_seed() -> void:
	var fixture: Dictionary = _make_fixture()
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var runtime: BattleRuntimeState = fixture.get(
		"runtime"
	) as BattleRuntimeState
	var controller: BattleActionController = fixture.get(
		"action_controller"
	) as BattleActionController
	var seraphine: BattlerState = battlers.get(
		&"seraphine"
	) as BattlerState

	_expect(
		battlefield.place_battler(&"seraphine", &"central_nave", 2).is_empty(),
		"Seed fixture should place Seraphine in a free Nave position."
	)
	_expect(
		battlefield.place_battler(&"hollow_servant", &"central_nave", 3).is_empty(),
		"Seed fixture should place Hollow Servant in a free Nave position."
	)

	runtime.begin_attack_targeting(&"seraphine")
	var first: ReactionContext = controller.prepare_attack(
		&"hollow_servant"
	)
	_expect(
		first.is_valid and first.attack_roll.seed_used == 1200,
		"First primary Attack should use the controller's initial seed."
	)
	if not first.is_valid:
		return

	runtime.clear_resolution_chain()
	seraphine.restore_actions_to_maximum()
	runtime.begin_attack_targeting(&"seraphine")
	var second: ReactionContext = controller.prepare_attack(
		&"hollow_servant"
	)
	_expect(
		second.is_valid
		and second.attack_roll.seed_used == 1201
		and second.attack_roll.seed_used != first.attack_roll.seed_used,
		"Repeated primary Attacks must consume distinct deterministic seeds."
	)


func _test_melee_and_reach_counterattacks_require_adjacency() -> void:
	var fixture: Dictionary = _make_fixture()
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var runtime: BattleRuntimeState = fixture.get(
		"runtime"
	) as BattleRuntimeState
	var controller: BattleActionController = fixture.get(
		"action_controller"
	) as BattleActionController
	var seraphine: BattlerState = battlers.get(
		&"seraphine"
	) as BattlerState
	var blood_nun: BattlerState = battlers.get(
		&"blood_nun"
	) as BattlerState

	_expect(
		battlefield.get_spatial_range(
			&"blood_nun",
			&"seraphine"
		) == BattlefieldState.SpatialRange.FAR,
		"Blood Nun and Seraphine should begin Far across the Nave/Altar zone boundary."
	)

	var staff_request: ActionRequest = ActionRequest.new(
		&"seraphine",
		&"blood_nun",
		seraphine.get_main_hand_weapon(),
		1300
	)
	var staff_context: ReactionContext = ReactionContext.new()
	staff_context.request = staff_request
	staff_context.is_valid = true
	runtime.store_pending_reaction(staff_context, &"blood_nun")
	_expect(
		not controller.can_counterattack(blood_nun),
		"A Far Staff hit must not permit Blood Nun's Reach melee Counterattack."
	)

	var light_arrow: AbilityDefinition = load(
		"res://data/abilities/seraphine_light_arrow.tres"
	) as AbilityDefinition
	var light_request: ActionRequest = ActionRequest.new(
		&"seraphine",
		&"blood_nun",
		light_arrow.create_attack_profile(),
		1301,
		false,
		true,
		0,
		ActionRequest.Source.ABILITY
	)
	light_request.ability = light_arrow
	var light_context: ReactionContext = ReactionContext.new()
	light_context.request = light_request
	light_context.is_valid = true
	runtime.store_pending_reaction(light_context, &"blood_nun")
	_expect(
		not controller.can_counterattack(blood_nun),
		"Far Light Arrow must not permit Blood Nun's Reach melee Counterattack."
	)

	_expect(
		battlefield.place_battler(
			&"seraphine",
			&"central_nave",
			2
		).is_empty(),
		"Seraphine should be placeable beside Blood Nun for the adjacency control."
	)
	_expect(
		controller.can_counterattack(blood_nun),
		"Blood Nun's Counterattack must remain legal against an Adjacent attacker."
	)
	runtime.clear_pending_reaction()


func _test_committed_move_reaction_uses_attack_queue() -> void:
	var fixture: Dictionary = _make_fixture()
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var flow: BattleFlowController = fixture.get(
		"flow"
	) as BattleFlowController
	var movement: BattleMovementController = fixture.get(
		"movement"
	) as BattleMovementController
	var runtime: BattleRuntimeState = fixture.get(
		"runtime"
	) as BattleRuntimeState
	var action_controller: BattleActionController = fixture.get(
		"action_controller"
	) as BattleActionController
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState

	flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST
	)
	_expect(battlefield.place_battler(
		&"blood_nun",
		&"rear_gallery",
		1
	).is_empty(), "Move-reaction fixture should clear Blood Nun from the Nave.")
	_expect(battlefield.place_battler(
		&"hollow_servant",
		&"central_nave",
		1
	).is_empty(), "Move-reaction fixture should place Hollow Servant beside Knife Footman.")
	var previews: Array[MovementPreview] = (
		movement.begin_move_selection(&"seraphine")
	)
	var preview: MovementPreview = _find_preview(
		previews,
		[
			&"altar_right",
			&"altar_left",
			&"central_nave",
		]
	)
	_expect(
		preview != null,
		"Move Reaction test route should exist."
	)
	if preview == null:
		return

	var move_state: CommittedMoveState = (
		movement.begin_committed_move(preview, 2)
	)
	_expect(
		move_state.is_valid,
		"Threatened Move should commit before its reaction."
	)
	if not move_state.is_valid:
		return

	_expect(
		movement.advance_active_move_step().is_empty(),
		"Full allied Altar Left pass-through should advance."
	)
	_expect(
		movement.get_active_move_reactor_ids().is_empty(),
		"Allied pass-through should not create a reaction."
	)
	_expect(
		movement.advance_active_move_step().is_empty(),
		"Move should enter the hostile Nave Crossing."
	)

	var reactor_ids: Array[StringName] = (
		movement.get_active_move_reactor_ids()
	)
	_expect(
		reactor_ids
		== [&"hollow_servant", &"knife_footman"],
		"Every eligible combatant at the reached Anchor should receive a Move Reaction opportunity."
	)
	_expect(
		movement.mark_active_move_reaction_used(
			&"knife_footman"
		).is_empty(),
		"Move reaction opportunity should be consumed once."
	)
	_expect(
		movement.get_active_move_reactor_ids()
		== [&"hollow_servant"],
		"Using Knife Footman's reaction must preserve Hollow Servant's separate opportunity."
	)
	_expect(
		movement.mark_active_move_reaction_declined(
			&"hollow_servant"
		).is_empty(),
		"Hollow Servant should be able to decline its own reaction independently."
	)
	_expect(
		movement.get_active_move_reactor_ids().is_empty(),
		"Only after every eligible combatant acts or declines should the Move continue."
	)
	_expect(
		action_controller.queue_move_reaction(
			&"knife_footman",
			&"seraphine",
			1700
		).is_empty(),
		"Move Reaction should enter the shared Attack queue."
	)

	var knife: BattlerState = battlers.get(
		&"knife_footman"
	) as BattlerState
	var actions_before: int = knife.current_actions
	var context: ReactionContext = (
		action_controller.prepare_next_queued_attack()
	)
	_expect(
		context.is_valid,
		"Queued Move Reaction should prepare through the normal resolver."
	)
	if not context.is_valid:
		return
	_expect(
		context.request.source
		== ActionRequest.Source.MOVE_REACTION,
		"Queued request should retain the Move Reaction source."
	)
	_expect(
		knife.current_actions == actions_before - 1,
		"Move Reaction should spend exactly one reactor Action."
	)

	var result: ActionResult = (
		action_controller.resolve_attack_reaction(
			AttackReactionChoice.Type.SKIP
		)
	)
	_expect(
		result.succeeded,
		"Move Reaction target should resolve the normal reaction menu."
	)
	action_controller.clear_pending_reaction()

	_expect(
		runtime.active_move != null
		and runtime.active_move.is_complete,
		"Committed route should remain complete after ordinary damage."
	)
	_expect(
		movement.finish_active_move() != null,
		"Completed threatened Move should close normally."
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
		load(
			"res://data/battlers/enemies/blood_nun.tres"
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
	if not spatial_error.is_empty():
		_expect(false, "Fixture failed: %s" % spatial_error)
		return {}

	var battle_state: BattleState = BattleState.new()
	var runtime: BattleRuntimeState = BattleRuntimeState.new()
	runtime.battle_state = battle_state

	var flow: BattleFlowController = BattleFlowController.new()
	flow.initialize(
		battlers,
		battle_state,
		DiceResolver.new(),
		900
	)

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
		1200,
		targeting
	)

	return {
		"battlers": battlers,
		"battlefield": battlefield,
		"runtime": runtime,
		"flow": flow,
		"movement": movement,
		"targeting": targeting,
		"action_controller": action_controller,
	}


func _find_preview(
	previews: Array[MovementPreview],
	expected_path: Array[StringName]
) -> MovementPreview:
	for preview: MovementPreview in previews:
		if preview.anchor_path == expected_path:
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
