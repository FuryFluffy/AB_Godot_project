class_name BattlerCatalogDefinition
extends Resource


@export var battlers: Array[BattlerDefinition] = []


func get_battler(battler_id: StringName) -> BattlerDefinition:
	for battler: BattlerDefinition in battlers:
		if battler != null and battler.battler_id == battler_id:
			return battler
	return null


func resolve_battlers(
	battler_ids: Array[StringName]
) -> Array[BattlerDefinition]:
	var resolved: Array[BattlerDefinition] = []
	for battler_id: StringName in battler_ids:
		var battler: BattlerDefinition = get_battler(battler_id)
		if battler != null:
			resolved.append(battler)
	return resolved
