extends SceneTree


var failures: int = 0


func _init() -> void:
	_test_existing_kits_use_composed_effects()
	_test_retained_spell_catalog()
	_test_regeneration_dispel_and_cure_resolution()
	_test_slow_status_contract()
	if failures == 0:
		print("Ability Resource tests passed.")
	else:
		push_error("%d Ability Resource test(s) failed." % failures)
	quit(failures)


func _test_existing_kits_use_composed_effects() -> void:
	var lysandra: BattlerDefinition = load(
		"res://data/battlers/heroines/lysandra.tres"
	) as BattlerDefinition
	var mira: BattlerDefinition = load(
		"res://data/battlers/heroines/mira.tres"
	) as BattlerDefinition
	var seraphine: BattlerDefinition = load(
		"res://data/battlers/heroines/seraphine.tres"
	) as BattlerDefinition
	_expect(
		lysandra.get_ability(
			&"lysandra_blood_riposte"
		).get_blood_riposte_effect() != null,
		"Blood Riposte must be authored as a passive effect Resource."
	)
	var bomb: AbilityDefinition = mira.get_ability(&"mira_blight_bomb")
	var bomb_attack: AttackAbilityEffect = bomb.get_attack_effect()
	_expect(
		bomb_attack != null
		and bomb_attack.on_damage_status != null
		and bomb_attack.on_damage_status.kind == StatusDefinition.Kind.POISON,
		"Blight Bomb must retain Poison through its Attack effect Resource."
	)
	_expect(
		seraphine.get_ability(&"seraphine_heal").effects[0]
		is HealAbilityEffect
		and seraphine.get_ability(&"seraphine_cleanse").effects[0]
		is RemoveStatusAbilityEffect
		and seraphine.get_ability(&"seraphine_bless").effects[0]
		is BlessAbilityEffect
		and seraphine.get_ability(&"seraphine_ward_of_grace").effects[0]
		is WardAbilityEffect,
		"Seraphine's existing kit must use composed effect Resources."
	)


func _test_retained_spell_catalog() -> void:
	var catalog: AbilityCatalogDefinition = load(
		"res://data/abilities/retained_spell_catalog.tres"
	) as AbilityCatalogDefinition
	_expect(
		catalog != null and catalog.abilities.size() == 4,
		"The retained spell catalogue must contain exactly four spells."
	)
	if catalog == null:
		return
	var dispel: AbilityDefinition = catalog.get_ability(&"dispel_magic")
	var slow: AbilityDefinition = catalog.get_ability(&"spell_slow")
	var regeneration: AbilityDefinition = catalog.get_ability(
		&"regeneration"
	)
	var cure: AbilityDefinition = catalog.get_ability(&"cure")
	_expect(
		dispel != null
		and dispel.targeting_mode == AbilityDefinition.TargetingMode.ANY
		and dispel.effects[0] is RemoveStatusAbilityEffect,
		"Dispel Magic must target either faction and remove magic."
	)
	_expect(
		slow != null
		and slow.effects[0] is ApplyStatusAbilityEffect
		and (slow.effects[0] as ApplyStatusAbilityEffect).requires_opposed_check,
		"Slow must use a resisted ApplyStatus effect."
	)
	_expect(
		regeneration != null
		and regeneration.effects[0] is ApplyStatusAbilityEffect,
		"Regeneration must apply its runtime Status Resource."
	)
	_expect(
		cure != null
		and cure.effects[0] is HealAbilityEffect
		and (cure.effects[0] as HealAbilityEffect).uses_check_successes,
		"Cure must be a roll-scaled Heal effect."
	)
	_expect(
		cure != null
		and cure.replaces_ability_id == &"seraphine_heal",
		"Cure must replace Heal when unlocked."
	)


func _test_regeneration_dispel_and_cure_resolution() -> void:
	var fixture: Dictionary = _make_fixture()
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var controller: AbilityActionController = fixture.get(
		"abilities"
	) as AbilityActionController
	var statuses: StatusController = fixture.get(
		"statuses"
	) as StatusController
	var catalog: AbilityCatalogDefinition = load(
		"res://data/abilities/retained_spell_catalog.tres"
	) as AbilityCatalogDefinition
	var seraphine: BattlerState = battlers.get(
		&"seraphine"
	) as BattlerState
	var lysandra: BattlerState = battlers.get(
		&"lysandra"
	) as BattlerState
	lysandra.apply_damage(3)

	var regeneration: AbilityDefinition = catalog.get_ability(
		&"regeneration"
	)
	var legal_regen: Array[StringName] = controller.begin_targeting(
		&"seraphine",
		regeneration
	)
	_expect(
		legal_regen.has(&"lysandra"),
		"Regeneration must legally target an ally in Seraphine's zone."
	)
	var regen_result: AbilityUseResult = controller.commit_target(
		&"lysandra"
	) as AbilityUseResult
	_expect(
		regen_result != null
		and regen_result.succeeded
		and lysandra.has_status_kind(StatusDefinition.Kind.REGENERATION),
		"Regeneration must resolve through the generic ability controller."
	)
	var hp_before_tick: int = lysandra.current_hp
	statuses.process_side_phase(BattleState.CombatSide.HEROES)
	_expect(
		lysandra.current_hp == hp_before_tick + 1,
		"Regeneration must heal before other phase-start effects."
	)

	var dispel: AbilityDefinition = catalog.get_ability(&"dispel_magic")
	controller.begin_targeting(&"seraphine", dispel)
	var dispel_result: AbilityUseResult = controller.commit_target(
		&"lysandra"
	) as AbilityUseResult
	_expect(
		dispel_result != null
		and dispel_result.succeeded
		and not lysandra.has_status_kind(
			StatusDefinition.Kind.REGENERATION
		),
		"Dispel Magic must remove one removable magical effect."
	)

	seraphine.restore_actions_to_maximum()
	seraphine.restore_mp(99)
	var cure: AbilityDefinition = catalog.get_ability(&"cure")
	controller.begin_targeting(&"seraphine", cure)
	var hp_before_cure: int = lysandra.current_hp
	var cure_result: AbilityUseResult = controller.commit_target(
		&"lysandra"
	) as AbilityUseResult
	_expect(
		cure_result != null
		and cure_result.succeeded
		and lysandra.current_hp > hp_before_cure,
		"Cure must restore at least 1 HP through its Body check."
	)


func _test_slow_status_contract() -> void:
	var definition: BattlerDefinition = load(
		"res://data/battlers/heroines/mira.tres"
	) as BattlerDefinition
	var mira: BattlerState = BattlerState.new(definition)
	var statuses: StatusController = StatusController.new()
	var battlers: Dictionary = {&"mira": mira}
	var order: Array[StringName] = [&"mira"]
	statuses.initialize(battlers, order)
	var slow: StatusDefinition = load(
		"res://data/statuses/slow.tres"
	) as StatusDefinition
	statuses.apply_status(
		mira,
		slow,
		&"spell_slow",
		-1,
		-1,
		1,
		1
	)
	_expect(
		mira.current_actions == 2
		and mira.get_max_actions() == 2
		and mira.get_move_step_limit() == 1,
		"Slow must remove one current Action, lower maximum Actions, and halve Move."
	)
	_expect(
		statuses.has_removable_magic_effect(mira)
		and statuses.remove_one_removable_magic_effect(mira) == "Slow"
		and not mira.has_status_kind(StatusDefinition.Kind.SLOW)
		and mira.get_max_actions() == 3,
		"Spell-applied Slow must be removable by Dispel without making item Slow magical."
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
	flow.initialize(battlers, runtime.battle_state, dice, 500)
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
	var statuses: StatusController = StatusController.new()
	statuses.initialize(battlers, order)
	var targeting: BattleTargetingController = BattleTargetingController.new()
	targeting.initialize(battlers, battlefield)
	var resolver: AttackResolver = AttackResolver.new()
	resolver.dice_resolver = dice
	resolver.status_controller = statuses
	var abilities: AbilityActionController = AbilityActionController.new()
	abilities.initialize(
		battlers,
		runtime,
		flow,
		battlefield,
		targeting,
		resolver,
		statuses,
		dice,
		700
	)
	return {
		"battlers": battlers,
		"runtime": runtime,
		"flow": flow,
		"battlefield": battlefield,
		"statuses": statuses,
		"targeting": targeting,
		"resolver": resolver,
		"abilities": abilities,
	}


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
