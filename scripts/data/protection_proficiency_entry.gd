class_name ProtectionProficiencyEntry
extends Resource


enum Type {
	CLOTH,
	LEATHER,
	CHAIN,
	PLATE,
	SHIELD,
}


@export var protection_type: Type = Type.CLOTH

@export_range(0, 10, 1)
var level: int = 0

@export var tier: SkillEntry.Tier = (
	SkillEntry.Tier.UNTRAINED
)


func is_trained() -> bool:
	return (
		level > 0
		and tier != SkillEntry.Tier.UNTRAINED
	)
