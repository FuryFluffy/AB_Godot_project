class_name EventRoomInstanceState
extends RefCounted

var source_node_id: StringName = &""
var room_id: StringName = &""
var visit_count: int = 0
var generation_seed: int = 1
var local_state: Dictionary = {}

static func validate_container_state(state: Dictionary) -> String:
	if state.has("station_prepared") and not state.station_prepared is bool:
		return "Station preparation flag must be a boolean."
	var trap_error: String = RoomTrapState.validate(state)
	if not trap_error.is_empty():
		return trap_error
	var revealed: Variant = state.get("revealed_containers", {})
	if not revealed is Dictionary:
		return "Room container discovery state must be a dictionary."
	for id: Variant in revealed:
		if not id is String or id.is_empty() or not revealed[id] is bool:
			return "Room container discovery contains an invalid entry."
	var records: Variant = state.get("item_spawns", [])
	if state.has("item_traps"):
		if not records is Array:
			return "Trapped room requires saved item records."
		var eligible: Dictionary = {}
		for record: Variant in records:
			if record is Dictionary and String(record.get("container_id","")) == "":
				eligible[String(record.get("spawn_id",""))] = true
		for id: String in state.item_traps:
			if not eligible.has(id):
				return "Saved trap has no matching visible item record."

	if records is Array:
		for record: Variant in records:
			if record is Dictionary and record.has("container_id"):
				if not record.container_id is String or record.container_id.is_empty():
					return "Room item contains an invalid container identity."
	return ""

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
