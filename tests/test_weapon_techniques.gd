extends SceneTree


var failures: int = 0


func _init() -> void:
	_test_catalog_and_family_curricula()
	_test_progression_unlock_and_rank_round_trip()
	_test_run_developer_grants_preserve_ranks()
	_test_techniques_inherit_equipped_weapons()
	_test_developer_grants_reach_battler_states()
	_test_knife_dance_allows_only_legal_target()
	_test_weapon_arts_use_mp_and_multi_target_pipeline()

	if failures == 0:
		print("Weapon technique and progression tests passed.")
	else:
		push_error(
			"%d weapon technique/progression test(s) failed."
			% failures
		)
	quit(failures)


func _test_catalog_and_family_curricula() -> void:
	var catalog: AbilityCatalogDefinition = load(
		"res://data/abilities/weapon_technique_catalog.tres"
	) as AbilityCatalogDefinition
	var sword: WeaponFamilyDefinition = load(
		"res://data/weapon_families/sword.tres"
	) as WeaponFamilyDefinition
	var dagger: WeaponFamilyDefinition = load(
		"res://data/weapon_families/dagger.tres"
	) as WeaponFamilyDefinition
	var staff: WeaponFamilyDefinition = load(
		"res://data/weapon_families/staff.tres"
	) as WeaponFamilyDefinition
	_expect(
		catalog != null and catalog.abilities.size() == 3,
		"The first Refuge curriculum must contain three techniques."
	)
	_expect(
		_catalog_has(catalog, &"forced_blade")
		and _catalog_has(catalog, &"knife_dance")
		and _catalog_has(catalog, &"jaw_break"),
		"Sword, Dagger, and Staff techniques must all be catalogued."
	)
	_expect(
		sword.compatible_techniques.size() == 1
		and sword.compatible_techniques[0].ability_id == &"forced_blade"
		and dagger.compatible_techniques.size() == 1
		and dagger.compatible_techniques[0].ability_id == &"knife_dance"
		and staff.compatible_techniques.size() == 1
		and staff.compatible_techniques[0].ability_id == &"jaw_break",
		"Each family must expose its Inspector-editable Refuge curriculum."
	)


func _test_progression_unlock_and_rank_round_trip() -> void:
	var progression: HeroineProgressionState = (
		HeroineProgressionState.new(&"lysandra")
	)
	progression.set_weapon_family_rank(&"sword", 2)
	progression.unlock_ability(&"forced_blade")
	var restored: HeroineProgressionState = HeroineProgressionState.new(
		&"lysandra",
		progression.to_snapshot()
	)
	_expect(
		restored.get_weapon_family_rank(&"sword", 1) == 2
		and restored.has_unlocked_ability(&"forced_blade"),
		"Weapon ranks and technique unlocks must survive snapshot round-trip."
	)


func _test_run_developer_grants_preserve_ranks() -> void:
	var run: RunState = RunState.new()
	var graph: LayerMapGraph = LayerMapGenerator.new().generate_layer_1(8303)
	run.initialize(8303, graph)
	run.set_heroine_weapon_family_rank(&"lysandra", &"sword", 2)
	run.grant_developer_weapon_techniques()
	var lysandra: HeroineProgressionState = HeroineProgressionState.new(
		&"lysandra",
		run.heroine_progression_snapshot[&"lysandra"] as Dictionary
	)
	_expect(
		lysandra.get_weapon_family_rank(&"sword", 1) == 2
		and lysandra.has_unlocked_ability(&"forced_blade"),
		"Temporary grants must add techniques without resetting family ranks."
	)


func _test_techniques_inherit_equipped_weapons() -> void:
	var catalog: AbilityCatalogDefinition = load(
		"res://data/abilities/weapon_technique_catalog.tres"
	) as AbilityCatalogDefinition
	var lysandra: BattlerState = _make_state(
		"res://data/battlers/heroines/lysandra.tres"
	)
	var mira: BattlerState = _make_state(
		"res://data/battlers/heroines/mira.tres"
	)
	var seraphine: BattlerState = _make_state(
		"res://data/battlers/heroines/seraphine.tres"
	)
	var forced_blade: WeaponDefinition = catalog.get_ability(
		&"forced_blade"
	).create_attack_profile(lysandra.get_main_hand_weapon())
	var knife_dance: WeaponDefinition = catalog.get_ability(
		&"knife_dance"
	).create_attack_profile(mira.get_main_hand_weapon())
	var jaw_break: WeaponDefinition = catalog.get_ability(
		&"jaw_break"
	).create_attack_profile(seraphine.get_main_hand_weapon())
	_expect(
		forced_blade.is_family(&"sword")
		and forced_blade.dice_modifier
		== lysandra.get_main_hand_weapon().dice_modifier
		and forced_blade.get_ignored_defense_successes(
			DefenseChoice.Type.DODGE,
			1
		) == 2
		and forced_blade.get_flat_damage_bonus(1) == 1,
		"Forced Blade must add one Dodge negation and one flat damage."
	)
	_expect(
		knife_dance.is_family(&"dagger")
		and knife_dance.get_ignored_defense_successes(
			DefenseChoice.Type.PARRY,
			1
		) == 1
		and knife_dance.get_flat_damage_bonus(1) == 1,
		"Knife Dance must retain Dagger identity and add one flat damage."
	)
	_expect(
		jaw_break.is_family(&"staff")
		and jaw_break.attack_range
		== seraphine.get_main_hand_weapon().attack_range
		and jaw_break.get_action_loss_on_damage(1, 1) == 1
		and jaw_break.get_flat_damage_bonus(1) == 1
		and jaw_break.get_status_effects_on_undefended_hit(1).size() == 1,
		"Jaw Break must retain Staff effects, add flat damage, and Stun an undefended hit."
	)


func _test_developer_grants_reach_battler_states() -> void:
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
	]
	var snapshots: Dictionary = (
		RunState.make_default_heroine_progression_snapshot(true)
	)
	(snapshots[&"lysandra"] as Dictionary)[
		"weapon_family_ranks"
	] = {"sword": 2, "dagger": 1}
	var battlers: Dictionary = BattleBootstrap.new().create_battler_states(
		definitions,
		snapshots
	)
	var lysandra: BattlerState = battlers.get(&"lysandra") as BattlerState
	var mira: BattlerState = battlers.get(&"mira") as BattlerState
	var seraphine: BattlerState = battlers.get(
		&"seraphine"
	) as BattlerState
	_expect(
		lysandra.get_ability(&"forced_blade") != null
		and mira.get_ability(&"knife_dance") != null
		and seraphine.get_ability(&"jaw_break") != null,
		"Developer grants must expose the three techniques without mutating definitions."
	)
	_expect(
		lysandra.get_main_hand_weapon_rank() == 2,
		"Persistent family rank must override the authored Rank I test loadout."
	)
	var ungranted: BattlerState = BattlerState.new(definitions[0])
	_expect(
		ungranted.get_ability(&"forced_blade") == null
		and definitions[0].get_unlockable_ability(&"forced_blade") != null,
		"Unlockable technique data must stay separate from the starting kit."
	)


func _test_weapon_arts_use_mp_and_multi_target_pipeline() -> void:
	var definitions: Array[BattlerDefinition] = [
		load("res://data/battlers/heroines/lysandra.tres") as BattlerDefinition,
		load("res://data/battlers/heroines/mira.tres") as BattlerDefinition,
		load("res://data/battlers/heroines/seraphine.tres") as BattlerDefinition,
		load("res://data/battlers/enemies/hollow_servant.tres") as BattlerDefinition,
		load("res://data/battlers/enemies/knife_footman.tres") as BattlerDefinition,
		load("res://data/battlers/enemies/prayer_rag_novice.tres") as BattlerDefinition,
	]
	var battlers: Dictionary = BattleBootstrap.new().create_battler_states(
		definitions,
		RunState.make_default_heroine_progression_snapshot(true)
	)
	var runtime: BattleRuntimeState = BattleRuntimeState.new()
	var dice: DiceResolver = DiceResolver.new()
	var flow: BattleFlowController = BattleFlowController.new()
	flow.initialize(battlers, runtime.battle_state, dice, 8100)
	flow.start_encounter(BattleFlowController.OrderMode.FORCE_PARTY_FIRST)
	var battlefield: BattlefieldState = BattlefieldState.new()
	battlefield.initialize(
		load(
			"res://data/battlefields/ruined_chapel_spatial_test.tres"
		) as BattlefieldDefinition,
		battlers
	)
	battlefield.place_battler(&"hollow_servant", &"altar_left", 2)
	battlefield.place_battler(&"knife_footman", &"altar_left", 3)
	var targeting: BattleTargetingController = BattleTargetingController.new()
	targeting.initialize(battlers, battlefield)
	var statuses: StatusController = StatusController.new()
	var order: Array[StringName] = [
		&"lysandra", &"mira", &"seraphine", &"hollow_servant",
		&"knife_footman", &"prayer_rag_novice",
	]
	statuses.initialize(battlers, order)
	var resolver: AttackResolver = AttackResolver.new()
	resolver.dice_resolver = dice
	resolver.status_controller = statuses
	var controller: AbilityActionController = AbilityActionController.new()
	controller.initialize(
		battlers,
		runtime,
		flow,
		battlefield,
		targeting,
		resolver,
		statuses,
		dice,
		8200
	)
	var catalog: AbilityCatalogDefinition = load(
		"res://data/abilities/weapon_technique_catalog.tres"
	) as AbilityCatalogDefinition
	var forced_blade: AbilityDefinition = catalog.get_ability(
		&"forced_blade"
	)
	var knife_dance: AbilityDefinition = catalog.get_ability(
		&"knife_dance"
	)
	var jaw_break: AbilityDefinition = catalog.get_ability(&"jaw_break")
	_expect(
		forced_blade.action_cost == 1
		and forced_blade.mp_cost == 2
		and knife_dance.action_cost == 1
		and knife_dance.mp_cost == 2
		and knife_dance.allows_fewer_targets_when_unavailable
		and jaw_break.action_cost == 1
		and jaw_break.mp_cost == 2,
		"Every initial weapon art must cost 1 Action and 2 MP."
	)
	var mira: BattlerState = battlers.get(&"mira") as BattlerState
	var legal_ids: Array[StringName] = controller.begin_targeting(
		&"mira",
		knife_dance
	)
	_expect(
		legal_ids.has(&"hollow_servant")
		and legal_ids.has(&"knife_footman"),
		"Knife Dance must offer both legal targets in Dagger range."
	)
	var first_selection: AbilityTargetSelectionResult = (
		controller.commit_target(&"hollow_servant")
		as AbilityTargetSelectionResult
	)
	_expect(
		first_selection != null
		and first_selection.succeeded
		and first_selection.remaining_target_count == 1
		and not first_selection.legal_target_ids.has(&"hollow_servant")
		and first_selection.legal_target_ids.has(&"knife_footman"),
		"Knife Dance must reject selecting the same target twice."
	)
	var context: ReactionContext = controller.commit_target(
		&"knife_footman"
	) as ReactionContext
	_expect(
		context != null
		and context.is_valid
		and context.request.action_cost == 1
		and context.request.weapon_family_rank == 1
		and context.request.weapon.is_family(&"dagger")
		and context.request.target_id == &"hollow_servant"
		and mira.current_actions == 2
		and mira.current_mp == mira.definition.max_mp - 2
		and runtime.has_active_multi_target_attack()
		and runtime.active_multi_target_attack.target_ids
		== [&"hollow_servant", &"knife_footman"],
		"Knife Dance must pay once and resolve two distinct attacks in selection order."
	)


func _test_knife_dance_allows_only_legal_target() -> void:
	var definitions: Array[BattlerDefinition] = [
		load("res://data/battlers/heroines/mira.tres") as BattlerDefinition,
		load("res://data/battlers/enemies/hollow_servant.tres") as BattlerDefinition,
	]
	var battlers: Dictionary = BattleBootstrap.new().create_battler_states(
		definitions,
		RunState.make_default_heroine_progression_snapshot(true)
	)
	var runtime: BattleRuntimeState = BattleRuntimeState.new()
	var dice: DiceResolver = DiceResolver.new()
	var flow: BattleFlowController = BattleFlowController.new()
	flow.initialize(battlers, runtime.battle_state, dice, 8110)
	flow.start_encounter(BattleFlowController.OrderMode.FORCE_PARTY_FIRST)
	var battlefield: BattlefieldState = BattlefieldState.new()
	battlefield.initialize(
		load(
			"res://data/battlefields/ruined_chapel_spatial_test.tres"
		) as BattlefieldDefinition,
		battlers
	)
	battlefield.place_battler(&"hollow_servant", &"altar_left", 2)
	var targeting: BattleTargetingController = BattleTargetingController.new()
	targeting.initialize(battlers, battlefield)
	var statuses: StatusController = StatusController.new()
	var stable_order: Array[StringName] = [&"mira", &"hollow_servant"]
	statuses.initialize(battlers, stable_order)
	var resolver: AttackResolver = AttackResolver.new()
	resolver.dice_resolver = dice
	resolver.status_controller = statuses
	var controller: AbilityActionController = AbilityActionController.new()
	controller.initialize(
		battlers,
		runtime,
		flow,
		battlefield,
		targeting,
		resolver,
		statuses,
		dice,
		8210
	)
	var catalog: AbilityCatalogDefinition = load(
		"res://data/abilities/weapon_technique_catalog.tres"
	) as AbilityCatalogDefinition
	var knife_dance: AbilityDefinition = catalog.get_ability(&"knife_dance")
	var legal_ids: Array[StringName] = controller.begin_targeting(
		&"mira",
		knife_dance
	)
	var context: ReactionContext = controller.commit_target(
		&"hollow_servant"
	) as ReactionContext
	var mira: BattlerState = battlers.get(&"mira") as BattlerState
	_expect(
		legal_ids == [&"hollow_servant"]
		and context != null
		and context.is_valid
		and context.request.target_id == &"hollow_servant"
		and mira.current_actions == 2
		and mira.current_mp == mira.definition.max_mp - 2
		and runtime.has_active_multi_target_attack()
		and runtime.active_multi_target_attack.target_ids
		== [&"hollow_servant"],
		"Knife Dance must attack once when only one legal target remains."
	)


func _catalog_has(
	catalog: AbilityCatalogDefinition,
	ability_id: StringName
) -> bool:
	return catalog != null and catalog.get_ability(ability_id) != null


func _make_state(resource_path: String) -> BattlerState:
	return BattlerState.new(
		load(resource_path) as BattlerDefinition
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
