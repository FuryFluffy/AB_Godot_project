class_name AttackAbilityEffect
extends AbilityEffectDefinition


@export_group("On HP Damage")
@export var on_damage_status: StatusDefinition
@export_range(-1, 99, 1) var status_damage_override: int = -1
@export_range(-1, 10, 1) var status_tick_override: int = -1

