class_name RangeDiceWeaponEffect
extends WeaponEffectDefinition


@export_group("Spatial Attack")
@export var spatial_range: BattlefieldState.SpatialRange = (
	BattlefieldState.SpatialRange.VERY_FAR
)
@export_range(-10, 10, 1) var dice_modifier: int = 1
