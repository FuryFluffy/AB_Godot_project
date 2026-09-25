extends SceneTree


var failures: int = 0


func _init() -> void:
	_test_aoe_reuses_one_roll_and_individual_defenses()
	_test_aoe_includes_every_living_grapple_participant()
	_test_status_refresh_stacking_timing_and_control()
	_test_zero_hp_revival_outcomes_and_restart()
	_test_grapple_status_interactions()
	_test_grapple_zero_hp_revival_and_deferred_full_wipe()

	if failures == 0:
		print("Ordinary combat completion tests passed.")
	else:
		push_error(
			"%d ordinary combat test(s) failed."
			% failures
		)

	quit(failures)


func _test_aoe_reuses_one_roll_and_individual_defenses() -> void:
	var fixture: Dictionary = _make_fixture()
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var aoe: AoeActionController = fixture.get(
		"aoe"
	) as AoeActionController
	var resolver: AttackResolver = fixture.get(
		"resolver"
	) as AttackResolver
	var runtime: BattleRuntimeState = fixture.get(
		"runtime"
	) as BattleRuntimeState

	var mira: BattlerState = battlers.get(&"mira") as BattlerState
	var hollow: BattlerState = battlers.get(
		&"hollow_servant"
	) as BattlerState
	var knife: BattlerState = battlers.get(
		&"knife_footman"
	) as BattlerState
	hollow.armor_state = null
	knife.armor_state = null
	knife.shield_state = null
	_expect(battlefield.place_battler(
		&"hollow_servant",
		&"central_nave",
		1
	).is_empty(), "AOE fixture should place Hollow Servant in Central Nave.")

	var ability: AbilityDefinition = mira.definition.get_ability(
		&"mira_blight_bomb"
	)
	var legal_zones: Array[StringName] = aoe.begin_zone_targeting(
		&"mira",
		ability
	)
	_expect(
		legal_zones.has(&"central_nave"),
		"Blight Bomb should legally target Central Nave."
	)

	var first_context: ReactionContext = aoe.commit_zone(
		&"central_nave"
	)
	_expect(
		first_context.is_valid,
		"AOE should commit its first target through AttackResolver."
	)
	if not first_context.is_valid:
		return
	_expect(
		first_context.request.reaction_mode
		== ActionRequest.ReactionMode.DEFENSE_ONLY,
		"BattleZone AOE targets may defend but must not Counterattack the caster."
	)
	_expect(
		aoe.attack_seed == 701,
		"Committing one shared AOE roll must advance its seed exactly once."
	)

	var shared_roll: RollResult = first_context.attack_roll
	var first_target: BattlerState = battlers.get(
		first_context.request.target_id
	) as BattlerState
	var first_result: ActionResult = resolver.resolve_reaction(
		first_context,
		mira,
		first_target,
		DefenseChoice.Type.SKIP
	)
	_expect(
		first_result.succeeded,
		"First AOE target should resolve independently."
	)
	_expect(
		first_result.status_applied,
		"Blight Bomb should apply Poison after HP damage."
	)
	aoe.complete_current_target()
	runtime.clear_pending_reaction()

	var second_context: ReactionContext = aoe.prepare_next_target()
	_expect(
		second_context.is_valid,
		"AOE should advance to its second stable target."
	)
	_expect(
		second_context.attack_roll == shared_roll,
		"Every AOE target must reuse the same RollResult object."
	)
	_expect(
		second_context.attack_successes
		== first_context.attack_successes,
		"Every AOE target must receive the same incoming successes."
	)

	var second_target: BattlerState = battlers.get(
		second_context.request.target_id
	) as BattlerState
	var second_result: ActionResult = resolver.resolve_reaction(
		second_context,
		mira,
		second_target,
		DefenseChoice.Type.DODGE
	)
	_expect(
		second_result.succeeded,
		"Second AOE target should choose its own Defense."
	)
	_expect(
		mira.current_actions == 2,
		"AOE must spend one Action total, not one per target."
	)
	_expect(
		mira.current_mp == 5,
		"Blight Bomb must spend its 2 MP once."
	)


func _test_status_refresh_stacking_timing_and_control() -> void:
	var fixture: Dictionary = _make_fixture()
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var statuses: StatusController = fixture.get(
		"statuses"
	) as StatusController
	var movement: BattleMovementController = fixture.get(
		"movement"
	) as BattleMovementController
	var flow: BattleFlowController = fixture.get(
		"flow"
	) as BattleFlowController

	var hollow: BattlerState = battlers.get(
		&"hollow_servant"
	) as BattlerState
	var bleed: StatusDefinition = load(
		"res://data/statuses/bleed.tres"
	) as StatusDefinition
	statuses.apply_status(hollow, bleed, &"source_a")
	hollow.active_statuses[0].resolved_ticks = 2
	var refreshed: StatusApplicationResult = statuses.apply_status(
		hollow,
		bleed,
		&"source_a",
		2,
		3
	)
	_expect(
		refreshed.replaced_existing
		and hollow.active_statuses.size() == 1
		and hollow.active_statuses[0].resolved_ticks == 0
		and hollow.active_statuses[0].damage_per_tick == 2,
		"Same-source status reapplication should replace and refresh."
	)

	statuses.apply_status(hollow, bleed, &"source_b", 1, 3)
	_expect(
		hollow.active_statuses.size() == 2,
		"Different status sources should stack independently."
	)
	var hp_before: int = hollow.current_hp
	statuses.process_side_phase(BattleState.CombatSide.ENEMIES)
	_expect(
		hollow.current_hp == hp_before - 3,
		"Stacked Bleed sources should each resolve one actual tick."
	)

	var mira: BattlerState = battlers.get(&"mira") as BattlerState
	var slow: StatusDefinition = load(
		"res://data/statuses/slow.tres"
	) as StatusDefinition
	statuses.apply_status(mira, slow, &"source_slow")
	_expect(
		mira.get_max_actions() == 2
		and mira.get_move_step_limit() == 1,
		"Slow should reduce maximum Actions and Move to one step."
	)
	var previews: Array[MovementPreview] = movement.get_move_previews(
		&"mira"
	)
	for preview: MovementPreview in previews:
		_expect(
			preview.get_step_count() <= 1,
			"Slow movement previews must never exceed one Anchor step."
		)

	var stunned: StatusDefinition = load(
		"res://data/statuses/stunned.tres"
	) as StatusDefinition
	statuses.apply_status(mira, stunned, &"source_stun")
	_expect(
		mira.current_actions == 0 and mira.is_stunned(),
		"Stunned should immediately remove all available Actions."
	)
	_expect(
		flow.validate_active_actor(mira).contains("Stunned"),
		"Stunned should prevent Active Actions through shared validation."
	)


func _test_aoe_includes_every_living_grapple_participant() -> void:
	var fixture: Dictionary = _make_fixture()
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var grapple: GrappleController = fixture.get(
		"grapple"
	) as GrappleController
	var aoe: AoeActionController = fixture.get(
		"aoe"
	) as AoeActionController
	var runtime: BattleRuntimeState = fixture.get(
		"runtime"
	) as BattleRuntimeState

	var lysandra: BattlerState = battlers.get(
		&"lysandra"
	) as BattlerState
	var hollow: BattlerState = battlers.get(
		&"hollow_servant"
	) as BattlerState
	var knife: BattlerState = battlers.get(
		&"knife_footman"
	) as BattlerState
	lysandra.change_corruption(30)
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	_expect(
		battlefield.place_battler(&"hollow_servant", &"altar_left", 2).is_empty(),
		"Grapple AOE fixture should place Hollow Servant beside Lysandra."
	)
	_expect(
		battlefield.place_battler(&"knife_footman", &"altar_left", 3).is_empty(),
		"Grapple AOE fixture should place Knife Footman beside Lysandra."
	)

	var attempt: GrappleAttemptResult = grapple.prepare_initiation(
		&"hollow_servant",
		&"lysandra"
	)
	_expect(
		attempt.error_message.is_empty(),
		"The AOE integration fixture should create its main track."
	)
	grapple.resolve_initiation(false)
	knife.restore_actions_to_maximum()
	var secondary: GrappleActionResult = grapple.attach_secondary(
		&"knife_footman",
		&"lysandra",
		hollow.definition.grapple_template,
		true
	)
	_expect(
		secondary.succeeded,
		"The AOE integration fixture should create its secondary track."
	)

	var mira: BattlerState = battlers.get(&"mira") as BattlerState
	var ability: AbilityDefinition = mira.definition.get_ability(
		&"mira_blight_bomb"
	)
	var legal_zones: Array[StringName] = aoe.begin_zone_targeting(
		&"mira",
		ability
	)
	var cluster_anchor: AnchorDefinition = (
		(fixture.get("battlefield") as BattlefieldState)
		.get_battler_anchor(&"lysandra")
	)
	_expect(
		cluster_anchor != null
		and legal_zones.has(cluster_anchor.zone_id),
		"The shared Grapple Position should expose its BattleZone to AOE."
	)
	if cluster_anchor == null:
		return

	var context: ReactionContext = aoe.commit_zone(
		cluster_anchor.zone_id
	)
	_expect(
		context.is_valid and runtime.active_aoe != null,
		"AOE should commit against the Grapple cluster's BattleZone."
	)
	if runtime.active_aoe == null:
		return
	_expect(
		runtime.active_aoe.target_ids.has(&"hollow_servant")
		and runtime.active_aoe.target_ids.has(&"knife_footman"),
		"Every living attached enemy must remain an individual AOE target."
	)
	_expect(
		not runtime.active_aoe.target_ids.has(&"lysandra"),
		"Normal friendly-fire rules must still exclude Lysandra from Blight Bomb."
	)


func _test_zero_hp_revival_outcomes_and_restart() -> void:
	var fixture: Dictionary = _make_fixture()
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var lifecycle: BattleLifecycleController = fixture.get(
		"lifecycle"
	) as BattleLifecycleController
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var battle_state: BattleState = fixture.get(
		"battle_state"
	) as BattleState

	var mira: BattlerState = battlers.get(&"mira") as BattlerState
	mira.set_current_actions(2)
	mira.apply_damage(mira.current_hp)
	_expect(
		mira.is_defeated
		and mira.actions_before_defeat == 2
		and mira.current_actions == 0,
		"Zero HP should store remaining Actions and make the battler inactive."
	)
	_expect(
		mira.heal(2) == 0 and mira.is_defeated,
		"Ordinary healing must not Revive a defeated battler."
	)
	_expect(
		lifecycle.revive_battler(&"mira", 2).is_empty()
		and mira.current_hp == 2
		and mira.current_actions == 2,
		"Explicit Revive should restore authored HP and stored Actions."
	)

	for enemy_id: StringName in [
		&"hollow_servant",
		&"knife_footman",
		&"prayer_rag_novice",
	]:
		var enemy: BattlerState = battlers.get(enemy_id) as BattlerState
		enemy.apply_damage(enemy.current_hp)

	_expect(
		lifecycle.evaluate_outcome()
		== BattleState.Outcome.VICTORY,
		"Defeating every enemy while one heroine lives should be Victory."
	)

	var restart_error: String = lifecycle.restart_battle()
	_expect(
		restart_error.is_empty()
		and battle_state.outcome == BattleState.Outcome.NONE
		and not battle_state.encounter_started,
		"Restart should return the lifecycle to Encounter Setup."
	)
	_expect(
		battlefield.get_battler_position(&"mira").anchor_id
		== &"altar_left",
		"Restart should restore authored battlefield placements."
	)

	var flow: BattleFlowController = fixture.get(
		"flow"
	) as BattleFlowController
	flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST
	)
	for state_value: Variant in battlers.values():
		var state: BattlerState = state_value as BattlerState
		state.apply_damage(state.current_hp)

	_expect(
		lifecycle.evaluate_outcome()
		== BattleState.Outcome.DEFEAT,
		"Simultaneous final defeat must give Defeat priority."
	)

	var defeat_restart_error: String = lifecycle.restart_battle()
	_expect(
		defeat_restart_error.is_empty()
		and battle_state.outcome == BattleState.Outcome.NONE
		and not battle_state.encounter_started,
		"Restart must recover cleanly from Defeat."
	)
	_expect(
		battlefield.get_battler_position(&"lysandra").anchor_id
		== &"altar_left",
		"Defeat restart must restore Lysandra's authored placement."
	)


func _test_grapple_zero_hp_revival_and_deferred_full_wipe() -> void:
	var fixture: Dictionary = _make_fixture()
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var grapple: GrappleController = fixture.get(
		"grapple"
	) as GrappleController
	var lifecycle: BattleLifecycleController = fixture.get(
		"lifecycle"
	) as BattleLifecycleController
	var battle_state: BattleState = fixture.get(
		"battle_state"
	) as BattleState

	var lysandra: BattlerState = battlers.get(
		&"lysandra"
	) as BattlerState
	var hollow: BattlerState = battlers.get(
		&"hollow_servant"
	) as BattlerState
	lysandra.set_current_actions(2)
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	_expect(
		battlefield.place_battler(&"hollow_servant", &"altar_left", 2).is_empty(),
		"Revival fixture should place Hollow Servant beside Lysandra."
	)
	var attempt: GrappleAttemptResult = grapple.prepare_initiation(
		&"hollow_servant",
		&"lysandra"
	)
	grapple.resolve_initiation(false)
	lysandra.apply_damage(lysandra.current_hp)
	_expect(
		lysandra.is_defeated
		and lysandra.is_grappled()
		and lysandra.actions_before_defeat == 2,
		"Zero HP must preserve the heroine's active track and stored Actions."
	)
	_expect(
		lifecycle.revive_battler(&"lysandra", 2).is_empty()
		and lysandra.is_grappled()
		and lysandra.current_actions == 2,
		"Explicit Revival must restore the heroine without changing her track."
	)

	lysandra.apply_damage(lysandra.current_hp)
	for heroine_id: StringName in [&"mira", &"seraphine"]:
		var heroine: BattlerState = battlers.get(
			heroine_id
		) as BattlerState
		heroine.apply_damage(heroine.current_hp)

	_expect(
		lifecycle.evaluate_outcome() == BattleState.Outcome.NONE
		and lifecycle.is_deferred_defeat_active(),
		"Full wipe with a surviving Grapple track must defer Defeat."
	)
	_expect(
		not grapple.can_hold_track(&"hollow_servant"),
		"Full wipe must suppress Hold while a track remains."
	)

	hollow.restore_actions_to_maximum()
	grapple.progress_track(&"hollow_servant")
	hollow.restore_actions_to_maximum()
	grapple.progress_track(&"hollow_servant")
	_expect(
		not grapple.has_active_tracks(),
		"The final forced Progress should Climax and end the last track."
	)

	var resolve_before_penalty: Dictionary = {}
	for heroine_id: StringName in [&"lysandra", &"mira", &"seraphine"]:
		var heroine: BattlerState = battlers.get(
			heroine_id
		) as BattlerState
		resolve_before_penalty[heroine_id] = heroine.current_resolve

	_expect(
		lifecycle.evaluate_outcome() == BattleState.Outcome.DEFEAT
		and battle_state.phase == BattleState.Phase.COMPLETE,
		"Defeat must resolve immediately after the final active track ends."
	)
	for heroine_id: StringName in [&"lysandra", &"mira", &"seraphine"]:
		var heroine: BattlerState = battlers.get(
			heroine_id
		) as BattlerState
		_expect(
			heroine.current_resolve
			== maxi(int(resolve_before_penalty[heroine_id]) - 15, 0),
			"Full wipe must apply the locked 15 Resolve consequence once."
		)


func _test_grapple_status_interactions() -> void:
	var fixture: Dictionary = _make_fixture()
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var grapple: GrappleController = fixture.get(
		"grapple"
	) as GrappleController
	var statuses: StatusController = fixture.get(
		"statuses"
	) as StatusController
	var hollow: BattlerState = battlers.get(
		&"hollow_servant"
	) as BattlerState
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	_expect(
		battlefield.place_battler(&"hollow_servant", &"altar_left", 2).is_empty(),
		"Status fixture should place Hollow Servant beside Lysandra."
	)

	grapple.prepare_initiation(&"hollow_servant", &"lysandra")
	grapple.resolve_initiation(false)
	statuses.apply_status(
		hollow,
		load("res://data/statuses/slow.tres") as StatusDefinition,
		&"slow_source"
	)
	statuses.apply_status(
		hollow,
		load("res://data/statuses/stunned.tres") as StatusDefinition,
		&"stun_source"
	)
	_expect(
		grapple.has_active_tracks()
		and not grapple.can_progress_track(&"hollow_servant")
		and not grapple.can_hold_track(&"hollow_servant"),
		"Stun must preserve a track while blocking both Progress and Hold."
	)
	var separation: GrappleActionResult = (
		grapple.force_separate_grappler(&"hollow_servant")
	)
	_expect(
		separation.succeeded and hollow.active_statuses.size() == 2,
		"Ordinary Slow and Stun must remain after detachment."
	)

	fixture = _make_fixture()
	battlers = fixture.get("battlers") as Dictionary
	grapple = fixture.get("grapple") as GrappleController
	statuses = fixture.get("statuses") as StatusController
	hollow = battlers.get(&"hollow_servant") as BattlerState
	battlefield = fixture.get("battlefield") as BattlefieldState
	_expect(
		battlefield.place_battler(&"hollow_servant", &"altar_left", 2).is_empty(),
		"Poison fixture should place Hollow Servant beside Lysandra."
	)
	grapple.prepare_initiation(&"hollow_servant", &"lysandra")
	grapple.resolve_initiation(false)
	statuses.apply_status(
		hollow,
		load("res://data/statuses/poison.tres") as StatusDefinition,
		&"poison_source",
		hollow.current_hp,
		3
	)
	statuses.process_side_phase(BattleState.CombatSide.ENEMIES)
	_expect(
		hollow.is_defeated and not grapple.has_active_tracks(),
		"Phase-start Poison defeat must immediately end the grappler's track."
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
	var order: Array[StringName] = [
		&"lysandra",
		&"mira",
		&"seraphine",
		&"hollow_servant",
		&"knife_footman",
		&"prayer_rag_novice",
	]
	var battlers: Dictionary = BattleBootstrap.new().create_battler_states(
		definitions
	)
	var runtime: BattleRuntimeState = BattleRuntimeState.new()
	var dice: DiceResolver = DiceResolver.new()
	var flow: BattleFlowController = BattleFlowController.new()
	flow.initialize(
		battlers,
		runtime.battle_state,
		dice,
		500
	)
	flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST
	)

	var battlefield: BattlefieldState = BattlefieldState.new()
	battlefield.initialize(
		load(
			"res://data/battlefields/ruined_chapel_spatial_test.tres"
		) as BattlefieldDefinition,
		battlers
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

	var statuses: StatusController = StatusController.new()
	statuses.initialize(battlers, order)
	var targeting: BattleTargetingController = BattleTargetingController.new()
	targeting.initialize(battlers, battlefield)
	var grapple: GrappleController = GrappleController.new()
	grapple.initialize(
		battlers,
		battlefield,
		targeting,
		dice,
		900
	)
	var resolver: AttackResolver = AttackResolver.new()
	resolver.dice_resolver = dice
	resolver.status_controller = statuses
	resolver.set_test_roll_mode(
		AttackResolver.TestRollMode.FORCE_ATTACK_HIT
	)

	var aoe: AoeActionController = AoeActionController.new()
	aoe.initialize(
		battlers,
		order,
		runtime,
		battlefield,
		flow,
		resolver,
		700
	)

	var lifecycle: BattleLifecycleController = (
		BattleLifecycleController.new()
	)
	lifecycle.initialize(
		battlers,
		order,
		runtime.battle_state,
		runtime,
		battlefield,
		statuses,
		grapple
	)

	return {
		"battlers": battlers,
		"runtime": runtime,
		"battle_state": runtime.battle_state,
		"flow": flow,
		"battlefield": battlefield,
		"movement": movement,
		"statuses": statuses,
		"targeting": targeting,
		"grapple": grapple,
		"resolver": resolver,
		"aoe": aoe,
		"lifecycle": lifecycle,
	}


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	failures += 1
	push_error(message)
