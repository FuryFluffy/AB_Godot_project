class_name ActionLossOnDamageWeaponEffect
extends WeaponEffectDefinition


@export_group("On HP Damage")
@export_range(0, 3, 1) var action_loss: int = 1
@export_range(1, 99, 1) var minimum_hp_damage: int = 1
