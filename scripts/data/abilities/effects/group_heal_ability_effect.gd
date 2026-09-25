class_name GroupHealAbilityEffect
extends AbilityEffectDefinition


@export_range(0, 99, 1) var healing_per_ally: int = 0
@export_range(0, 99, 1) var self_hp_cost: int = 0
@export var excludes_caster: bool = true
@export var requires_same_zone: bool = true

