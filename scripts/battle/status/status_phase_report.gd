class_name StatusPhaseReport
extends RefCounted


var side: BattleState.CombatSide = BattleState.CombatSide.NONE
var entries: Array[String] = []
var defeated_battler_ids: Array[StringName] = []
var expired_status_count: int = 0


func append(message: String) -> void:
	entries.append(message)


func is_empty() -> bool:
	return entries.is_empty()

