class_name StoryDialogueOutcome
extends RefCounted


var story_id: StringName = &""
var source_node_id: StringName = &""
var inventory_snapshot: Array[Dictionary] = []
var run_inventory_snapshot: Dictionary = {}
var party_snapshot: Dictionary = {}
var bloom_delta: int = 0
var dialogue_result_snapshots: Array[Dictionary] = []
