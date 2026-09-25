class_name RoomEventEffectDefinition
extends Resource


enum Kind {
	HEAL_HP,
	CHANGE_RESOLVE,
	CHANGE_CORRUPTION,
	ROLL_BLOOM_D10_PER_LAYER,
}


@export var kind: Kind = Kind.HEAL_HP

@export_range(-100, 100, 1)
var amount: int = 0


func requires_heroine_target() -> bool:
	return kind in [
		Kind.HEAL_HP,
		Kind.CHANGE_RESOLVE,
		Kind.CHANGE_CORRUPTION,
	]


func validate_definition(
	effect_label: String
) -> String:
	match kind:
		Kind.HEAL_HP:
			if amount <= 0:
				return (
					"%s requires a positive heal amount."
					% effect_label
				)

		Kind.CHANGE_RESOLVE:
			if amount == 0:
				return (
					"%s requires a non-zero Resolve change."
					% effect_label
				)

		Kind.CHANGE_CORRUPTION:
			if amount == 0:
				return (
					"%s requires a non-zero Corruption change."
					% effect_label
				)

		Kind.ROLL_BLOOM_D10_PER_LAYER:
			if amount <= 0:
				return (
					"%s requires at least 1 die per layer."
					% effect_label
				)

	return ""
