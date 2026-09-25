class_name EventRoomOutcome
extends RefCounted

var source_node_id: StringName = &""
var clear_node: bool = false
var room_state_snapshot: Dictionary = {}
var inventory_snapshot: Array[Dictionary] = []
var run_inventory_snapshot: Dictionary = {}
var party_snapshot: Dictionary = {}
var bloom_delta: int = 0
var dialogue_result_snapshots: Array[Dictionary] = []
