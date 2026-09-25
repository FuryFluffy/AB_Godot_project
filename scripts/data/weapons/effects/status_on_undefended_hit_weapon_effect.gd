class_name StatusOnUndefendedHitWeaponEffect
extends WeaponEffectDefinition


@export_group("On Undefended Hit")
@export var status: StatusDefinition
@export_range(-1, 99, 1) var status_damage_override: int = -1
@export_range(-1, 10, 1) var status_tick_override: int = -1
