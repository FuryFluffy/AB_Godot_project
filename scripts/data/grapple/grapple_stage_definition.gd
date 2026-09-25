class_name GrappleStageDefinition
extends Resource


@export_group("Identity")
@export_range(1, 20, 1) var stage_number: int = 1
@export var display_name: String = "Stage 1"

@export_group("Main Track Effects")
@export_range(-100, 100, 1) var corruption_change: int = 0
@export_range(-100, 100, 1) var resolve_change: int = 0

@export_group("Pacing")
@export_range(0, 20, 1) var maximum_holds: int = 0
@export var is_climax: bool = false

