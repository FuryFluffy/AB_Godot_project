class_name RoomRestOfferDefinition
extends Resource
## One authored recovery offer. The room selects one; the player never selects a type.
@export var offer_id: int = 0
@export var display_name: String
@export_range(0,100) var hp_percent: int = 0
@export_range(0,100) var mp_percent: int = 0
@export var resolve_delta: int = 0
@export var corruption_delta: int = 0
@export var full_recovery: bool = false
