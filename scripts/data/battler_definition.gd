class_name BattlerDefinition
extends Resource


enum Faction {
	HEROINE,
	ENEMY,
	NEUTRAL,
}


enum Category {
	HEROINE,
	STANDARD_ENEMY,
	ELITE_ENEMY,
	BOSS,
}


@export_group("Identity")
@export var battler_id: StringName
@export var display_name: String = "Unnamed Battler"
@export var faction: Faction = Faction.NEUTRAL
@export var category: Category = Category.STANDARD_ENEMY


@export_group("Attributes")
@export var attributes: AttributeSet


@export_group("Resources")
@export_range(1, 999, 1) var max_hp: int = 1
@export_range(0, 999, 1) var max_mp: int = 0
@export_range(1, 10, 1) var base_actions: int = 3
@export_range(0, 100, 1) var starting_resolve: int = 100
@export_range(0, 100, 1) var starting_corruption: int = 0
@export_range(0, 20, 1) var order_value: int = 0


@export_group("Skills")
@export var skills: Array[SkillEntry] = []

@export_group("Specialties")
@export var specialties: Array[SpecialtyEntry] = []

@export_group("Abilities")
@export var abilities: Array[AbilityDefinition] = []
@export var unlockable_abilities: Array[AbilityDefinition] = []


@export_group("Protection Proficiencies")
@export var protection_proficiencies: Array[ProtectionProficiencyEntry] = []


@export_group("Equipment")
@export var default_loadout: EquipmentLoadout

@export_group("Enemy AI")
@export var enemy_rulebook: EnemyRulebookDefinition

@export_group("Grapple")
@export var grapple_template: GrappleTemplateDefinition


func get_skill_entry(
	skill: SkillEntry.Skill
) -> SkillEntry:
	for entry: SkillEntry in skills:
		if entry != null and entry.skill == skill:
			return entry

	return null


func get_skill_level(
	skill: SkillEntry.Skill
) -> int:
	var entry: SkillEntry = get_skill_entry(skill)

	if entry == null:
		return 0

	return entry.level


func get_skill_tier(
	skill: SkillEntry.Skill
) -> SkillEntry.Tier:
	var entry: SkillEntry = get_skill_entry(skill)

	if entry == null:
		return SkillEntry.Tier.UNTRAINED

	return entry.tier


func get_specialty_tier(
	specialty: SpecialtyEntry.Specialty
) -> SkillEntry.Tier:
	for entry: SpecialtyEntry in specialties:
		if entry != null and entry.specialty == specialty:
			return entry.tier

	return SkillEntry.Tier.UNTRAINED


func has_specialty(
	specialty: SpecialtyEntry.Specialty,
	minimum_tier: SkillEntry.Tier = SkillEntry.Tier.NOVICE
) -> bool:
	return get_specialty_tier(specialty) >= minimum_tier


func get_ability(
	ability_id: StringName
) -> AbilityDefinition:
	for ability: AbilityDefinition in abilities:
		if ability != null and ability.ability_id == ability_id:
			return ability

	return null


func get_unlockable_ability(
	ability_id: StringName
) -> AbilityDefinition:
	for ability: AbilityDefinition in unlockable_abilities:
		if ability != null and ability.ability_id == ability_id:
			return ability

	return null

func get_protection_proficiency(
	protection_type: ProtectionProficiencyEntry.Type
) -> ProtectionProficiencyEntry:
	for entry: ProtectionProficiencyEntry in (
		protection_proficiencies
	):
		if entry == null:
			continue

		if entry.protection_type == protection_type:
			return entry

	return null


func get_protection_level(
	protection_type: ProtectionProficiencyEntry.Type
) -> int:
	var entry: ProtectionProficiencyEntry = (
		get_protection_proficiency(protection_type)
	)

	if entry == null:
		return 0

	return entry.level


func get_protection_tier(
	protection_type: ProtectionProficiencyEntry.Type
) -> SkillEntry.Tier:
	var entry: ProtectionProficiencyEntry = (
		get_protection_proficiency(protection_type)
	)

	if entry == null:
		return SkillEntry.Tier.UNTRAINED

	return entry.tier
