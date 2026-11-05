class_name IntelOptionDefinition
extends Resource

## Prices are provisional balance explicitly approved for Stages 22–23.
enum Effect { SCOUTING, BATTLE_SENSE, COIN_ROUTE, PATHFINDING, SANCTUARY, DANGER, ARTISAN, CASTLE_MEMORY, CONQUEROR_PASSAGE, SUBMIT }
@export var option_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var effect: Effect
@export var one_run_price: int = 10
@export var permanent_only: bool = false
@export var permanent_price: int = 0
@export var available: bool = true
@export var provisional_price: bool = true

func price(permanent: bool, layer: int = 0) -> int:
	var scale: int = layer if effect == Effect.CONQUEROR_PASSAGE and layer in [1, 2] else 1
	return permanent_price if permanent_only else one_run_price * scale * (100 if permanent else 1)
