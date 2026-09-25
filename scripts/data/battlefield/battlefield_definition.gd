class_name BattlefieldDefinition
extends Resource


@export_group("Identity")
@export var battlefield_id: StringName
@export var display_name: String = "Unnamed Battlefield"

@export_group("Spatial Definitions")
@export var zones: Array[BattleZoneDefinition] = []
@export var anchors: Array[AnchorDefinition] = []
@export var initial_placements: Array[BattlerPlacementDefinition] = []

@export_group("Position Contact Adjacency")
@export var position_contacts: Array[PositionContactDefinition] = []

@export_group("Line of Sight and Cover")
@export var terrain_lines: Array[TerrainLineDefinition] = []


func get_zone(
	zone_id: StringName
) -> BattleZoneDefinition:
	for zone: BattleZoneDefinition in zones:
		if zone != null and zone.zone_id == zone_id:
			return zone

	return null


func get_anchor(
	anchor_id: StringName
) -> AnchorDefinition:
	for anchor: AnchorDefinition in anchors:
		if anchor != null and anchor.anchor_id == anchor_id:
			return anchor

	return null


func get_initial_placement(
	battler_id: StringName
) -> BattlerPlacementDefinition:
	for placement: BattlerPlacementDefinition in initial_placements:
		if (
			placement != null
			and placement.battler_id == battler_id
		):
			return placement

	return null


func get_position_contact(
	first_anchor_id: StringName,
	first_position_index: int,
	second_anchor_id: StringName,
	second_position_index: int
) -> PositionContactDefinition:
	for contact: PositionContactDefinition in position_contacts:
		if (
			contact != null
			and contact.connects(
				first_anchor_id,
				first_position_index,
				second_anchor_id,
				second_position_index
			)
		):
			return contact
	return null


func are_positions_in_contact(
	first_anchor_id: StringName,
	first_position_index: int,
	second_anchor_id: StringName,
	second_position_index: int
) -> bool:
	return get_position_contact(
		first_anchor_id,
		first_position_index,
		second_anchor_id,
		second_position_index
	) != null
