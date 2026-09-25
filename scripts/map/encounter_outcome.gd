class_name EncounterOutcome
extends RefCounted


enum Result {
	NONE,
	VICTORY,
	DEFEAT,
}


var result: Result = Result.NONE
var encounter_id: StringName = &""
var source_node_id: StringName = &""
var party_snapshot: Dictionary = {}
var inventory_snapshot: Array[Dictionary] = []
var heroine_progression_snapshot: Dictionary = {}
var bloom_reward: int = 0
