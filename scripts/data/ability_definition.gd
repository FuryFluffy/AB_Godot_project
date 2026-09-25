class_name AbilityDefinition
extends Resource


enum TargetingMode {
	ENEMY,
	ALLY,
	SELF,
	BATTLE_ZONE,
	PASSIVE,
	ANY,
}


enum School {
	NONE,
	FIRE,
	AIR,
	WATER,
	EARTH,
	LIGHT,
	DARK,
	BODY,
	MIND,
	SPIRIT,
	NATURES_VEIL,
	ESSENCE_SHAPING,
	ALCHEMY,
}


@export_group("Identity")
@export var ability_id: StringName
@export var display_name: String = "Unnamed Ability"
@export_multiline var description: String = ""
@export var school: School = School.NONE
@export var tier: SkillEntry.Tier = SkillEntry.Tier.UNTRAINED
@export_flags("Spell", "Alchemy", "Weapon Technique", "Passive", "AOE") var tags: int = 0
@export var replaces_ability_id: StringName
@export var requires_progression_unlock: bool = false

@export_group("Weapon Technique Requirement")
@export var required_weapon_family_id: StringName
@export_range(1, 3, 1) var minimum_weapon_family_rank: int = 1
@export var uses_equipped_weapon_attack_profile: bool = false
@export var additional_weapon_effects: Array[WeaponEffectDefinition] = []

@export_group("Costs")
@export_range(0, 3, 1) var action_cost: int = 1
@export_range(0, 99, 1) var mp_cost: int = 0

@export_group("Attack Check")
@export var skill: SkillEntry.Skill = SkillEntry.Skill.KNOWLEDGE
@export var attribute: AttributeSet.Attribute = (
	AttributeSet.Attribute.INTELLECT
)
@export_range(-10, 10, 1) var dice_modifier: int = 0

@export_group("Targeting")
@export var targeting_mode: TargetingMode = (
	TargetingMode.BATTLE_ZONE
)
@export_range(1, 8, 1) var required_target_count: int = 1
@export var allows_fewer_targets_when_unavailable: bool = false
@export_range(0, 4, 1) var maximum_zone_distance: int = 2
@export var requires_same_zone: bool = false
@export var requires_same_anchor: bool = false
@export var is_magic: bool = true
@export var can_be_parried: bool = false
@export var requires_line_of_sight: bool = true
@export var affects_allies: bool = false
@export var can_target_self: bool = false
@export var qualifies_for_analysis: bool = false

@export_group("Composed Effects")
@export var effects: Array[AbilityEffectDefinition] = []


func create_attack_profile(
	equipped_weapon: WeaponDefinition = null
) -> WeaponDefinition:
	var attack_effect: AttackAbilityEffect = get_attack_effect()
	if attack_effect == null:
		return null
	if uses_equipped_weapon_attack_profile:
		if equipped_weapon == null:
			return null
		return _create_weapon_technique_profile(
			equipped_weapon,
			attack_effect
		)
	var profile: WeaponDefinition = WeaponDefinition.new()
	profile.equipment_id = StringName(
		"ability_profile_%s" % String(ability_id)
	)
	profile.display_name = display_name
	profile.allowed_slots = [EquipmentDefinition.Slot.MAIN_HAND]
	profile.skill = skill
	profile.attribute = attribute
	profile.dice_modifier = dice_modifier
	profile.attack_range = WeaponDefinition.AttackRange.RANGED
	profile.is_magic_attack = is_magic
	profile.maximum_zone_distance = maximum_zone_distance
	profile.can_parry = false
	profile.maximum_durability_damage = 20
	profile.on_damage_status = attack_effect.on_damage_status
	profile.status_damage_override = attack_effect.status_damage_override
	profile.status_tick_override = attack_effect.status_tick_override
	return profile


func _create_weapon_technique_profile(
	equipped_weapon: WeaponDefinition,
	attack_effect: AttackAbilityEffect
) -> WeaponDefinition:
	var profile: WeaponDefinition = WeaponDefinition.new()
	profile.equipment_id = StringName(
		"technique_profile_%s" % String(ability_id)
	)
	profile.display_name = display_name
	profile.allowed_slots = [EquipmentDefinition.Slot.MAIN_HAND]
	profile.family = equipped_weapon.family
	profile.default_family_rank = equipped_weapon.default_family_rank
	profile.skill = equipped_weapon.skill
	profile.attribute = equipped_weapon.attribute
	profile.dice_modifier = equipped_weapon.dice_modifier + dice_modifier
	profile.property = equipped_weapon.property
	profile.attack_range = equipped_weapon.attack_range
	profile.is_magic_attack = false
	profile.maximum_zone_distance = equipped_weapon.maximum_zone_distance
	profile.can_parry = equipped_weapon.can_parry
	profile.is_two_handed = equipped_weapon.is_two_handed
	profile.maximum_durability_damage = (
		equipped_weapon.maximum_durability_damage
	)
	profile.unique_effects = equipped_weapon.unique_effects.duplicate()
	for effect: WeaponEffectDefinition in additional_weapon_effects:
		if effect != null:
			profile.unique_effects.append(effect)
	profile.on_damage_status = (
		attack_effect.on_damage_status
		if attack_effect.on_damage_status != null
		else equipped_weapon.on_damage_status
	)
	profile.status_damage_override = (
		attack_effect.status_damage_override
		if attack_effect.on_damage_status != null
		else equipped_weapon.status_damage_override
	)
	profile.status_tick_override = (
		attack_effect.status_tick_override
		if attack_effect.on_damage_status != null
		else equipped_weapon.status_tick_override
	)
	return profile


func is_passive() -> bool:
	return targeting_mode == TargetingMode.PASSIVE


func is_attack() -> bool:
	return get_attack_effect() != null


func get_attack_effect() -> AttackAbilityEffect:
	for effect: AbilityEffectDefinition in effects:
		if effect is AttackAbilityEffect:
			return effect as AttackAbilityEffect
	return null


func get_group_heal_effect() -> GroupHealAbilityEffect:
	for effect: AbilityEffectDefinition in effects:
		if effect is GroupHealAbilityEffect:
			return effect as GroupHealAbilityEffect
	return null


func get_blood_riposte_effect() -> BloodRiposteAbilityEffect:
	for effect: AbilityEffectDefinition in effects:
		if effect is BloodRiposteAbilityEffect:
			return effect as BloodRiposteAbilityEffect
	return null


func get_self_hp_cost() -> int:
	var group_heal: GroupHealAbilityEffect = get_group_heal_effect()
	return group_heal.self_hp_cost if group_heal != null else 0
