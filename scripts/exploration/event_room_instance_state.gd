class_name EventRoomInstanceState
extends RefCounted

var source_node_id: StringName = &""
var room_id: StringName = &""
var visit_count: int = 0
var generation_seed: int = 1
var local_state: Dictionary = {}

func to_snapshot() -> Dictionary:
	return {
		"source_node_id": String(source_node_id),
		"room_id": String(room_id),
		"visit_count": visit_count,
		"generation_seed": generation_seed,
		"local_state": local_state.duplicate(true)
	}
	
static func from_snapshot(snapshot: Dictionary) -> EventRoomInstanceState:
	var state := EventRoomInstanceState.new()
	state.source_node_id = StringName(
		snapshot.get("source_node_id", "")
	)
	state.room_id = StringName(snapshot.get("room_id", ""))
	state.visit_count = int(snapshot.get("visit_count", 0))
	state.generation_seed = maxi(
		int(snapshot.get("generation_seed", 1)),
		1
	)
	state.local_state = (
		snapshot.get("local_state", {}) as Dictionary
	).duplicate(true)
	return state
