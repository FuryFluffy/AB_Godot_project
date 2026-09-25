extends SceneTree


var failures: int = 0


func _init() -> void:
	_test_level_one_sheets()
	_test_ability_catalogues()
	_test_explicit_effect_lifecycles()
	_test_novice_meditation_round_start()
	if failures == 0:
		print("Starting party kit tests passed.")
	else:
		push_error("%d starting party kit test(s) failed." % failures)
	quit(failures)


func _test_level_one_sheets() -> void:
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
		lysandra.max_hp == 8 and lysandra.max_mp == 8,
		"Lysandra must use the approved 8 HP / 8 MP sheet."
	)
	_expect(
		lysandra.attributes.might == 4
		and lysandra.attributes.agility == 2
		and lysandra.attributes.endurance == 4
		and lysandra.attributes.intellect == 1
		and lysandra.attributes.personality == 4,
		"Lysandra's approved Attribute array must remain exact."
	)
	_expect(
		lysandra.default_loadout.armor.armor_type
		== ArmorDefinition.Type.CHAIN
		and lysandra.default_loadout.shield == null,
		"Lysandra must start in Chain without a Shield."
	)
	_expect(
		mira.max_hp == 5 and mira.max_mp == 7,
		"Mira must use the approved 5 HP / 7 MP sheet."
	)
	_expect(
		mira.attributes.agility == 4
		and mira.attributes.intellect == 4,
		"Mira must use the approved Agility/Intellect split."
	)
	_expect(
		mira.default_loadout.armor == null,
		"Mira must begin without trained armor."
	)
	_expect(
		seraphine.max_hp == 5 and seraphine.max_mp == 9,
		"Seraphine must use the approved 5 HP / 9 MP sheet."
	)
	_expect(
		seraphine.get_skill_level(SkillEntry.Skill.LIGHT) == 3
		and seraphine.get_skill_level(SkillEntry.Skill.BODY) == 3,
		"Seraphine must begin with Light 3 and Body 3."
	)


func _test_ability_catalogues() -> void:
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
		lysandra.get_ability(&"lysandra_blood_riposte").is_passive(),
		"Blood Riposte must be a passive signature talent."
	)
	_expect(
		mira.get_ability(&"mira_find_the_catch") != null
		and mira.get_ability(&"mira_thrown_dart") != null
		and mira.get_ability(&"mira_blight_bomb") != null,
		"Mira must have analysis, Dart, and flask AOE."
	)
	var bomb: AbilityDefinition = mira.get_ability(
		&"mira_blight_bomb"
	)
	_expect(
		bomb.skill == SkillEntry.Skill.CRAFT_ALCHEMY
		and bomb.attribute == AttributeSet.Attribute.INTELLECT
		and not bomb.is_magic,
		"Blight Bomb must use non-magical Alchemy/Intellect."
	)
	for ability_id: StringName in [
		&"seraphine_light_arrow",
		&"seraphine_bless",
		&"seraphine_heal",
		&"seraphine_cleanse",
		&"seraphine_ward_of_grace",
	]:
		_expect(
			seraphine.get_ability(ability_id) != null,
			"Seraphine is missing %s." % ability_id
		)


func _test_explicit_effect_lifecycles() -> void:
	var mira_definition: BattlerDefinition = load(
		"res://data/battlers/heroines/mira.tres"
	) as BattlerDefinition
	var mira: BattlerState = BattlerState.new(mira_definition)
	mira.set_analyzed_target(&"hollow_servant")
	_expect(
		mira.has_analyzed_target(&"hollow_servant"),
		"Find the Catch must persist until an explicit terminal trigger."
	)
	_expect(
		mira.consume_analyzed_target(&"hollow_servant")
		and not mira.has_analyzed_target(&"hollow_servant"),
		"Find the Catch must be consumed explicitly."
	)
	var seraphine_definition: BattlerDefinition = load(
		"res://data/battlers/heroines/seraphine.tres"
	) as BattlerDefinition
	var seraphine: BattlerState = BattlerState.new(
		seraphine_definition
	)
	seraphine.apply_ward(1)
	_expect(
		seraphine.consume_ward() == 1
		and seraphine.consume_ward() == 0,
		"Ward of Grace must affect exactly one Defense Check."
	)
	seraphine.apply_bless(1)
	_expect(
		seraphine.consume_bless() == 1
		and seraphine.consume_bless() == 0,
		"Bless must affect exactly one Attack."
	)


func _test_novice_meditation_round_start() -> void:
	var seraphine_definition: BattlerDefinition = load(
		"res://data/battlers/heroines/seraphine.tres"
	) as BattlerDefinition
	var seraphine: BattlerState = BattlerState.new(
		seraphine_definition
	)
	seraphine.current_mp = 4
	var battlers: Dictionary = {&"seraphine": seraphine}
	var battle_state: BattleState = BattleState.new()
	var flow: BattleFlowController = BattleFlowController.new()
	flow.initialize(battlers, battle_state, DiceResolver.new(), 80)
	var error: String = flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST
	)
	_expect(error.is_empty(), "Meditation fixture must start.")
	_expect(
		seraphine.current_mp == 5,
		"Novice Meditation must restore 1 MP at round start."
	)
	_expect(
		flow.last_round_start_effects.size() == 1,
		"Meditation restoration must be exposed for the combat log."
	)


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
