class_name DefenseIgnoreWeaponEffect
extends WeaponEffectDefinition


enum DefenseKind {
	DODGE,
	ARMOR,
	SHIELD,
	PARRY,
}


@export_group("Defense Negation")
@export var defense: DefenseKind = DefenseKind.DODGE
@export_range(0, 10, 1) var ignored_successes: int = 1


func applies_to(
	defense_choice: DefenseChoice.Type
) -> bool:
	match defense:
		DefenseKind.DODGE:
			return defense_choice == DefenseChoice.Type.DODGE
		DefenseKind.ARMOR:
			return defense_choice == DefenseChoice.Type.ARMOR
		DefenseKind.SHIELD:
			return defense_choice == DefenseChoice.Type.SHIELD
		DefenseKind.PARRY:
			return defense_choice == DefenseChoice.Type.PARRY

	return false
