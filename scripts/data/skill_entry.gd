class_name SkillEntry
extends Resource

enum Skill {
	#Misc
	# Deprecated: retained to preserve serialized enum indices.
	ARMOR,
	ATHLETICS,
	AWARENESS,
	KNOWLEDGE,
	SPEECH,
	
	#Weapons
	SWORD,
	AXE,
	STAFF,
	DAGGER,
	MACE,
	UNARMED,
	BOW,
	
	# Magic
	FIRE,
	AIR,
	WATER,
	EARTH,
	LIGHT,
	DARK,
	MIND,

	# Appended for authored Abyssal Bloom sheets. Appending preserves every
	# enum index already serialized by the combat prototype.
	ESPIONAGE,
	CRAFT_ALCHEMY,
	SLINGS,
	BODY,
	SPIRIT,
	LASH,
}

enum Tier {
	UNTRAINED,
	NOVICE,
	EXPERT,
	MASTER,
	GRAND_MASTER,
}

@export var skill: Skill = Skill.ATHLETICS
@export_range(0, 10, 1) var level: int = 0
@export var tier: Tier = Tier.UNTRAINED

func is_trained() -> bool:
	return level > 0 and tier != Tier.UNTRAINED
