class_name WeaponRankDefinition
extends Resource


@export_group("Identity")
@export_range(1, 3, 1) var rank: int = 1
@export var display_name: String = "Rank I"
@export_multiline var description: String = ""

@export_group("Attack")
@export_range(-10, 10, 1) var attack_dice_bonus: int = 0

@export_group("Family Effects")
@export var effects: Array[WeaponEffectDefinition] = []
