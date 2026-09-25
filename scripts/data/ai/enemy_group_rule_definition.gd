class_name EnemyGroupRuleDefinition
extends Resource


@export_group("Identity")
@export var rule_id: StringName
@export var display_name: String = "Unnamed Group Rule"

@export_group("If")
@export var required_alive_battler_ids: Array[StringName] = []

@export_group("Then")
@export var activation_order: Array[StringName] = []


func applies_to(
	battler_states: Dictionary
) -> bool:
	for battler_id: StringName in required_alive_battler_ids:
		var state: BattlerState = battler_states.get(
			battler_id
		) as BattlerState
		if state == null or state.is_defeated:
			return false

	return true
