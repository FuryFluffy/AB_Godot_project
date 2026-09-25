class_name SpawnSlotDefinition
extends Resource


@export_group("Identity")
@export var slot_id: StringName
@export var display_name: String = "Unnamed Spawn Slot"

@export_group("Placement")
@export var faction: BattlerDefinition.Faction = (
	BattlerDefinition.Faction.NEUTRAL
)
@export var anchor_id: StringName
@export_range(0, 3, 1) var position_index: int = 0
@export var role_tags: Array[StringName] = []


func accepts_faction(
	candidate_faction: BattlerDefinition.Faction
) -> bool:
	return (
		faction == BattlerDefinition.Faction.NEUTRAL
		or faction == candidate_faction
	)
