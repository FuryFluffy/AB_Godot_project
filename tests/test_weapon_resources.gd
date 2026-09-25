extends SceneTree


var failures: int = 0


func _init() -> void:
	_test_family_rank_curves()
	_test_equipped_weapons_use_family_resources()
	_test_unique_effects_layer_over_family()
	_test_runtime_rank_is_separate_from_definition()
	_test_example_unique_weapons()
	_test_prayer_rag_spell_is_not_a_staff_attack()
	_test_equipment_definition_validation()
	_test_equipment_instance_condition_and_effects()
	_test_personal_loadout_ownership_and_compatibility()
	_test_runtime_equipment_bridge_and_unarmed_fallback()

	if failures == 0:
		print("Weapon Resource tests passed.")
	else:
		push_error(
			"%d weapon Resource test(s) failed."
			% failures
		)

	quit(failures)


func _test_family_rank_curves() -> void:
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
		sword != null
		and dagger != null
		and staff != null,
		"All currently used weapon families must load."
	)
	_expect(
		sword.get_rank_definition(1).attack_dice_bonus == 0
		and sword.get_rank_definition(2).attack_dice_bonus == 1
		and sword.get_rank_definition(3).attack_dice_bonus == 2,
		"Sword ranks must use the approved +0/+1/+2d10 curve."
	)
	_expect(
		dagger.get_rank_definition(1).attack_dice_bonus == 0
		and dagger.get_rank_definition(2).attack_dice_bonus == 1
		and dagger.get_rank_definition(3).attack_dice_bonus == 2,
		"Dagger ranks must use the approved +0/+1/+2d10 curve."
	)
	_expect(
		staff.get_rank_definition(1).attack_dice_bonus == 0
		and staff.get_rank_definition(2).attack_dice_bonus == 1
		and staff.get_rank_definition(3).attack_dice_bonus == 2,
		"Staff ranks must use the approved +0/+1/+2d10 curve."
	)


func _test_equipped_weapons_use_family_resources() -> void:
	var lysandra: BattlerState = _make_state(
		"res://data/battlers/heroines/lysandra.tres"
	)
	var mira: BattlerState = _make_state(
		"res://data/battlers/heroines/mira.tres"
	)
	var seraphine: BattlerState = _make_state(
		"res://data/battlers/heroines/seraphine.tres"
	)
	var footman: BattlerState = _make_state(
		"res://data/battlers/enemies/knife_footman.tres"
	)

	var sword: WeaponDefinition = lysandra.get_main_hand_weapon()
	var mira_dagger: WeaponDefinition = mira.get_main_hand_weapon()
	var staff: WeaponDefinition = seraphine.get_main_hand_weapon()
	var footman_dagger: WeaponDefinition = (
		footman.get_main_hand_weapon()
	)

	_expect(
		sword.is_family(&"sword")
		and sword.get_ignored_defense_successes(
			DefenseChoice.Type.DODGE,
			lysandra.get_main_hand_weapon_rank()
		) == 1,
		"Lysandra must retain Rank I Sword Dodge negation."
	)
	_expect(
		mira_dagger.is_family(&"dagger")
		and mira_dagger.get_ignored_defense_successes(
			DefenseChoice.Type.PARRY,
			mira.get_main_hand_weapon_rank()
		) == 1,
		"Mira must retain Rank I Dagger Parry negation."
	)
	_expect(
		footman_dagger.is_family(&"dagger")
		and footman_dagger.get_ignored_defense_successes(
			DefenseChoice.Type.PARRY,
			footman.get_main_hand_weapon_rank()
		) == 1,
		"Knife Footman must retain Rank I Dagger Parry negation."
	)
	_expect(
		staff.is_family(&"staff")
		and staff.get_action_loss_on_damage(
			1,
			seraphine.get_main_hand_weapon_rank()
		) == 1,
		"Seraphine's Rank I Staff must remove one Action after HP damage."
	)


func _test_unique_effects_layer_over_family() -> void:
	var footman: BattlerState = _make_state(
		"res://data/battlers/enemies/knife_footman.tres"
	)
	var knife: WeaponDefinition = footman.get_main_hand_weapon()
	var status_effects: Array[StatusOnDamageWeaponEffect] = (
		knife.get_status_effects_on_damage(
			1,
			footman.get_main_hand_weapon_rank()
		)
	)

	_expect(
		knife.is_family(&"dagger")
		and status_effects.size() == 1
		and status_effects[0].status != null
		and status_effects[0].status.kind
		== StatusDefinition.Kind.BLEED,
		"Footman's unique Bleed must layer over its Dagger family."
	)


func _test_runtime_rank_is_separate_from_definition() -> void:
	var lysandra_definition: BattlerDefinition = load(
		"res://data/battlers/heroines/lysandra.tres"
	) as BattlerDefinition
	var rank_one: BattlerState = BattlerState.new(
		lysandra_definition
	)
	var rank_three: WeaponState = WeaponState.new(
		rank_one.get_main_hand_weapon(),
		3
	)

	_expect(
		rank_one.get_main_hand_weapon_rank() == 1,
		"The authored Lysandra loadout must remain Rank I."
	)
	_expect(
		rank_three.family_rank == 3
		and rank_three.get_attack_dice_bonus() == 2
		and rank_one.get_main_hand_weapon().default_family_rank == 1,
		"Runtime rank changes must not mutate the shared WeaponDefinition."
	)


func _test_example_unique_weapons() -> void:
	var ember: WeaponDefinition = load(
		"res://scripts/data/equipment/weapons/examples/ember_sword.tres"
	) as WeaponDefinition
	var accurate: WeaponDefinition = load(
		"res://scripts/data/equipment/weapons/examples/accurate_sword.tres"
	) as WeaponDefinition

	_expect(
		ember.is_family(&"sword")
		and ember.get_status_effects_on_damage(2, 1).is_empty()
		and ember.get_status_effects_on_damage(3, 1).size() == 1,
		"Ember Sword must apply Burning only after 3+ HP damage."
	)
	_expect(
		accurate.is_family(&"sword")
		and accurate.get_flat_attack_success_bonus(1) == 1
		and accurate.get_ignored_defense_successes(
			DefenseChoice.Type.DODGE,
			1
		) == 1,
		"Accurate Sword must add one success without replacing Sword Dodge negation."
	)


func _test_prayer_rag_spell_is_not_a_staff_attack() -> void:
	var novice: BattlerState = _make_state(
		"res://data/battlers/enemies/prayer_rag_novice.tres"
	)
	var staff: WeaponDefinition = novice.get_main_hand_weapon()
	var prayer: AbilityDefinition = novice.definition.get_ability(
		&"prayer_rag_dark_prayer"
	)

	_expect(
		staff != null
		and staff.is_family(&"staff")
		and staff.attack_range == WeaponDefinition.AttackRange.REACH
		and not staff.is_magic_attack,
		"Prayer Staff must remain a physical Reach weapon."
	)
	_expect(
		prayer != null
		and prayer.is_attack()
		and prayer.skill == SkillEntry.Skill.DARK
		and prayer.attribute == AttributeSet.Attribute.PERSONALITY
		and prayer.maximum_zone_distance == 2,
		"Dark Prayer must own the Novice's Very Far magical Attack profile."
	)
	_expect(
		prayer.create_attack_profile().validate_definition().is_empty(),
		"Generated ability attack profiles must satisfy the equipment definition contract."
	)
	var red_wax_ampoule: ItemDefinition = load(
		"res://data/items/layer_1/red_wax_ampoule.tres"
	) as ItemDefinition
	_expect(
		red_wax_ampoule != null
		and red_wax_ampoule.create_attack_profile().validate_definition().is_empty(),
		"Generated item attack profiles must satisfy the equipment definition contract."
	)


func _test_equipment_definition_validation() -> void:
	var destructible_weapon := WeaponDefinition.new()
	destructible_weapon.equipment_id = &"test_destructible_weapon"
	destructible_weapon.display_name = "Test Destructible Weapon"
	destructible_weapon.allowed_slots = [EquipmentDefinition.Slot.MAIN_HAND]
	destructible_weapon.condition_maximum = 5
	destructible_weapon.destructible = true
	_expect(
		not destructible_weapon.validate_definition().is_empty(),
		"Destructible equipment must reject a missing salvage material ID."
	)
	destructible_weapon.salvage_material_id = &"mat_l01_red_wax"
	destructible_weapon.rarity = EquipmentDefinition.Rarity.COMMON
	_expect(
		destructible_weapon.validate_definition().is_empty(),
		"A destructible fixture with an explicit authoritative material ID must validate."
	)
	destructible_weapon.destructible = false
	_expect(
		not destructible_weapon.validate_definition().is_empty(),
		"Non-destructible equipment must reject a fake salvage material assignment."
	)

	var malformed_armor := ArmorDefinition.new()
	malformed_armor.equipment_id = &"test_malformed_armor"
	malformed_armor.display_name = "Malformed Armor"
	malformed_armor.allowed_slots = [EquipmentDefinition.Slot.MAIN_HAND]
	malformed_armor.condition_maximum = 2
	_expect(
		not malformed_armor.validate_definition().is_empty(),
		"Armor must reject an explicitly incompatible slot."
	)


func _test_equipment_instance_condition_and_effects() -> void:
	var definition := WeaponDefinition.new()
	definition.equipment_id = &"test_condition_weapon"
	definition.display_name = "Condition Test Weapon"
	definition.allowed_slots = [
		EquipmentDefinition.Slot.MAIN_HAND,
		EquipmentDefinition.Slot.OFF_HAND,
	]
	definition.condition_maximum = 5
	definition.authored_positive_effect_ids = [&"test_positive"]
	definition.authored_negative_effect_ids = [&"test_negative"]
	var instance := EquipmentInstance.new()
	var initialize_error: String = instance.initialize(
		&"lysandra:test_condition_weapon:001",
		definition,
		99
	)
	_expect(initialize_error.is_empty(), "A valid equipment instance must initialize.")
	_expect(
		instance.current_condition == 5,
		"Equipment instance condition must clamp to its authored maximum."
	)
	var before_invalid_damage: Dictionary = instance.to_snapshot()
	_expect(
		not instance.apply_condition_damage(0).is_empty()
		and instance.to_snapshot() == before_invalid_damage,
		"Invalid condition damage must fail without mutating the instance."
	)
	_expect(
		instance.apply_condition_damage(5).is_empty()
		and instance.is_broken(),
		"Condition damage must break an instance at zero condition."
	)
	_expect(
		instance.get_effective_positive_effect_ids().is_empty()
		and instance.get_effective_negative_effect_ids() == [&"test_negative"],
		"Broken equipment must suppress positive effects and retain negative effects."
	)
	var serialized: Dictionary = instance.to_snapshot()
	_expect(
		serialized == {
			"instance_id": "lysandra:test_condition_weapon:001",
			"definition_id": "test_condition_weapon",
			"current_condition": 0,
		}
		and not _contains_object(serialized),
		"Equipment identity and condition snapshots must contain only plain serializable data."
	)
	_expect(
		instance.repair_condition(2).is_empty()
		and instance.current_condition == 2
		and instance.get_effective_positive_effect_ids() == [&"test_positive"],
		"Valid repair must restore condition and positive effects."
	)


func _test_personal_loadout_ownership_and_compatibility() -> void:
	var run := RunState.new()
	_expect(
		run.run_equipment.loadouts_by_heroine.size() == 3,
		"Run equipment must create one personal loadout per demo heroine."
	)
	var lysandra: PersonalEquipmentLoadoutState = (
		run.run_equipment.get_loadout(&"lysandra")
	)
	var mira: PersonalEquipmentLoadoutState = run.run_equipment.get_loadout(&"mira")
	_expect(
		lysandra != null
		and mira != null
		and lysandra.get_equipped_instance(EquipmentDefinition.Slot.MAIN_HAND) != null
		and mira.get_equipped_instance(EquipmentDefinition.Slot.MAIN_HAND) != null
		and (
			lysandra.get_equipped_instance(EquipmentDefinition.Slot.MAIN_HAND).instance_id
			!= mira.get_equipped_instance(EquipmentDefinition.Slot.MAIN_HAND).instance_id
		),
		"Authored Main Hand instances must have deterministic personal identities."
	)
	_expect(
		lysandra.get_equipped_instance(EquipmentDefinition.Slot.ARMOR) != null
		and lysandra.get_equipped_instance(EquipmentDefinition.Slot.OFF_HAND) == null,
		"Personal loadouts must keep distinct Armor and empty Off Hand slots."
	)
	var off_hand_definition := WeaponDefinition.new()
	off_hand_definition.equipment_id = &"test_off_hand_weapon"
	off_hand_definition.display_name = "Test Off Hand Weapon"
	off_hand_definition.allowed_slots = [EquipmentDefinition.Slot.OFF_HAND]
	off_hand_definition.condition_maximum = 4
	var off_hand_instance := EquipmentInstance.new(
		&"lysandra:test_off_hand_weapon:001",
		off_hand_definition
	)
	_expect(
		lysandra.register_instance(off_hand_instance).is_empty()
		and lysandra.equip(
			EquipmentDefinition.Slot.OFF_HAND,
			off_hand_instance.instance_id
		).is_empty(),
		"An explicitly compatible authored Off Hand weapon must equip."
	)
	var before_duplicate: Dictionary = lysandra.to_snapshot()
	_expect(
		not lysandra.equip(
			EquipmentDefinition.Slot.MAIN_HAND,
			off_hand_instance.instance_id
		).is_empty()
		and lysandra.to_snapshot() == before_duplicate,
		"One equipment instance must not be assigned twice, and failure must be transactional."
	)
	var armor_instance: EquipmentInstance = lysandra.get_equipped_instance(
		EquipmentDefinition.Slot.ARMOR
	)
	var before_incompatible: Dictionary = lysandra.to_snapshot()
	_expect(
		not lysandra.equip(
			EquipmentDefinition.Slot.OFF_HAND,
			armor_instance.instance_id
		).is_empty()
		and lysandra.to_snapshot() == before_incompatible,
		"Incompatible slot assignment must not partially mutate a personal loadout."
	)
	_expect(
		not run.run_equipment.equip(
			&"missing_heroine",
			EquipmentDefinition.Slot.MAIN_HAND,
			&"missing_instance"
		).is_empty(),
		"Run equipment must reject a missing heroine owner."
	)
	_expect(
		run.run_equipment.assign_memento(
			&"lysandra",
			&"l01_hollow_livery_pin"
		).is_empty()
		and run.run_equipment.get_memento_id(&"lysandra")
		== &"l01_hollow_livery_pin"
		and run.run_inventory.get_memento_id(&"lysandra")
		== &"l01_hollow_livery_pin",
		"Personal equipment must delegate Memento ownership to RunInventoryState."
	)
	_expect(
		run.run_equipment.get_snapshot().get("loadouts_by_heroine", {}) is Dictionary
		and not _contains_object(run.run_equipment.get_snapshot()),
		"Run equipment snapshots must contain only plain serializable values."
	)


func _test_runtime_equipment_bridge_and_unarmed_fallback() -> void:
	var lysandra: BattlerState = _make_state(
		"res://data/battlers/heroines/lysandra.tres"
	)
	var main_instance: EquipmentInstance = (
		lysandra.equipment_loadout_state.get_equipped_instance(
			EquipmentDefinition.Slot.MAIN_HAND
		)
	)
	_expect(
		lysandra.weapon_state != null
		and lysandra.weapon_state.instance == main_instance,
		"WeaponState must adapt the personal loadout's single EquipmentInstance authority."
	)
	lysandra.damage_weapon(lysandra.weapon_state.get_maximum_durability_damage())
	_expect(
		main_instance.is_broken()
		and lysandra.get_usable_main_hand_weapon() == null,
		"A broken Main Hand instance must preserve the existing unarmed fallback."
	)
	var fresh_lysandra: BattlerState = _make_state(
		"res://data/battlers/heroines/lysandra.tres"
	)
	_expect(
		fresh_lysandra.equipment_loadout_state.unequip(
			EquipmentDefinition.Slot.MAIN_HAND
		).is_empty()
		and fresh_lysandra.weapon_state == null
		and fresh_lysandra.get_usable_main_hand_weapon() == null,
		"Removing a valid Main Hand must refresh adapters and use the existing unarmed fallback."
	)
	var armor_instance: EquipmentInstance = (
		fresh_lysandra.equipment_loadout_state.get_equipped_instance(
			EquipmentDefinition.Slot.ARMOR
		)
	)
	_expect(
		fresh_lysandra.damage_armor(armor_instance.definition.condition_maximum)
		== armor_instance.definition.condition_maximum
		and armor_instance.is_broken()
		and fresh_lysandra.get_armor_dodge_modifier() == -1
		and fresh_lysandra.repair_armor(1) == 1
		and not armor_instance.is_broken(),
		"Existing armor condition, retained broken penalty, and repair behavior must share the instance."
	)
	var seraphine: BattlerState = _make_state(
		"res://data/battlers/heroines/seraphine.tres"
	)
	var cloth_condition: int = seraphine.armor_state.definition.condition_maximum
	_expect(
		seraphine.damage_armor(cloth_condition) == cloth_condition
		and seraphine.armor_state.is_broken
		and seraphine.get_armor_dodge_modifier() == 0,
		"Broken armor must suppress an existing positive dodge modifier."
	)
	var footman: BattlerState = _make_state(
		"res://data/battlers/enemies/knife_footman.tres"
	)
	_expect(
		footman.shield_state != null
		and footman.equipment_loadout_state.get_equipped_instance(
			EquipmentDefinition.Slot.OFF_HAND
		) == footman.shield_state.instance,
		"Existing shields must occupy the explicit Off Hand and share instance condition."
	)
	var shield_limit: int = footman.shield_state.get_safe_absorption_limit() + 1
	_expect(
		footman.damage_shield(shield_limit) == shield_limit
		and footman.shield_state.is_broken
		and footman.get_shield_dodge_modifier() == -1
		and footman.repair_shield(1) == 1
		and not footman.shield_state.is_broken,
		"Existing shield breakage, retained penalty, and repair behavior must remain intact."
	)


func _contains_object(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT:
		return true
	if value is Dictionary:
		for key: Variant in (value as Dictionary).keys():
			if _contains_object(key) or _contains_object((value as Dictionary)[key]):
				return true
	if value is Array:
		for entry: Variant in value as Array:
			if _contains_object(entry):
				return true
	return false


func _make_state(
	resource_path: String
) -> BattlerState:
	var definition: BattlerDefinition = load(
		resource_path
	) as BattlerDefinition
	_expect(
		definition != null,
		"Battler definition must load: %s"
		% resource_path
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
