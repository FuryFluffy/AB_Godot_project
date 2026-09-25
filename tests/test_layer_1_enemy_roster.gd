extends SceneTree


var failures: int = 0


func _init() -> void:
	_test_roster_resources()
	_test_encounter_runtime_filtering()
	if failures == 0:
		print("Layer 1 enemy roster tests passed.")
	else:
		push_error("%d Layer 1 enemy roster test(s) failed." % failures)
	quit(failures)


func _test_roster_resources() -> void:
	var expected: Dictionary = {
		&"hollow_servant": [6, 3, 1],
		&"knife_footman": [4, 2, 1],
		&"prayer_rag_novice": [3, 6, 1],
		&"corrupted_butler": [7, 8, 1],
		&"red_wax_acolyte": [9, 9, 2],
		&"blood_nun": [18, 12, 3],
	}
	var tutorial_profiles: Dictionary = {
		&"hollow_servant": [
			[2, 0, 2, 0, 0],
			1,
			[2, 0],
			[0],
		],
		&"knife_footman": [
			[1, 3, 1, 0, 0],
			3,
			[2, 2, 1],
			[0, 0],
		],
		&"prayer_rag_novice": [
			[0, 1, 1, 1, 3],
			2,
			[2, 1, 0, 1],
			[0],
		],
		&"corrupted_butler": [
			[2, 2, 3, 1, 3],
			4,
			[2, 2, 2, 1],
			[0],
		],
		&"red_wax_acolyte": [
			[1, 1, 3, 2, 4],
			3,
			[3, 2, 1, 2],
			[1],
		],
		&"blood_nun": [
			[3, 2, 4, 3, 5],
			3,
			[3, 3, 3, 2, 3],
			[2],
		],
	}
	for enemy_id: StringName in expected:
		var path: String = (
			"res://data/battlers/enemies/%s.tres"
			% String(enemy_id)
		)
		var definition: BattlerDefinition = load(path)
		var values: Array = expected[enemy_id]
		_expect(
			definition != null,
			"Enemy resource should load: %s." % enemy_id
		)
		if definition == null:
			continue
		_expect(
			definition.max_hp == values[0]
			and definition.max_mp == values[1]
			and definition.category == values[2],
			"Enemy stat block/category should match the approved baseline: %s."
			% enemy_id
		)
		_expect(
			definition.enemy_rulebook != null
			and definition.default_loadout != null,
			"Every Layer 1 enemy needs equipment and an AI rulebook: %s."
			% enemy_id
		)
		var profile: Array = tutorial_profiles[enemy_id]
		var attributes: Array = profile[0]
		_expect(
			definition.attributes.might == attributes[0]
			and definition.attributes.agility == attributes[1]
			and definition.attributes.endurance == attributes[2]
			and definition.attributes.intellect == attributes[3]
			and definition.attributes.personality == attributes[4]
			and definition.order_value == profile[1],
			"Enemy Attributes and Order should use the Layer 1 tutorial profile: %s."
			% enemy_id
		)
		var expected_skill_levels: Array = profile[2]
		_expect(
			definition.skills.size() == expected_skill_levels.size(),
			"Enemy Skill count should remain stable: %s." % enemy_id
		)
		for skill_index: int in range(
			mini(definition.skills.size(), expected_skill_levels.size())
		):
			_expect(
				definition.skills[skill_index].level
				== expected_skill_levels[skill_index],
				"Enemy Skill %d should use the Layer 1 tutorial level: %s."
				% [skill_index, enemy_id]
			)
		var expected_protection_levels: Array = profile[3]
		_expect(
			definition.protection_proficiencies.size()
			== expected_protection_levels.size(),
			"Enemy protection proficiency count should remain stable: %s."
			% enemy_id
		)
		for protection_index: int in range(
			mini(
				definition.protection_proficiencies.size(),
				expected_protection_levels.size()
			)
		):
			_expect(
				definition.protection_proficiencies[
					protection_index
				].level == expected_protection_levels[protection_index],
				"Enemy protection proficiency %d should use the Layer 1 tutorial level: %s."
				% [protection_index, enemy_id]
			)
	_expect(
		(load("res://data/battlers/enemies/blood_nun.tres")
		as BattlerDefinition).base_actions == 4,
		"Blood Nun must retain four Actions."
	)
	_expect(
		(load("res://data/battlers/enemies/red_wax_acolyte.tres")
		as BattlerDefinition).has_specialty(
			SpecialtyEntry.Specialty.MEDITATION
		),
		"Red-Wax Acolyte should restore MP through Novice Meditation."
	)


func _test_encounter_runtime_filtering() -> void:
	var battlefield: BattlefieldDefinition = load(
		"res://data/battlefields/ruined_chapel_spatial_test.tres"
	)
	var heroine: BattlerDefinition = load(
		"res://data/battlers/heroines/lysandra.tres"
	)
	var hollow: BattlerDefinition = load(
		"res://data/battlers/enemies/hollow_servant.tres"
	)
	var states: Dictionary = BattleBootstrap.new().create_battler_states(
		[heroine, hollow]
	)
	var battlefield_state: BattlefieldState = BattlefieldState.new()
	_expect(
		battlefield_state.initialize(battlefield, states).is_empty(),
		"Shared battlefield placements should skip inactive roster members."
	)
	_expect(
		battlefield_state.get_battler_position(&"hollow_servant")
		!= null
		and battlefield_state.get_battler_position(&"knife_footman")
		== null,
		"Only active encounter enemies should occupy battlefield positions."
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
