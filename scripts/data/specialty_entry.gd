class_name SpecialtyEntry
extends Resource


enum Specialty {
	ARMORER,
	ARMSMASTER,
	BODYBUILDING,
	SPELLCASTER,
	MEDITATION,
	ALCHEMY,
	TINKERING,
}


@export var specialty: Specialty = Specialty.ARMORER
@export var tier: SkillEntry.Tier = SkillEntry.Tier.UNTRAINED


func is_trained() -> bool:
	return tier != SkillEntry.Tier.UNTRAINED
