class_name MapNodeState
extends RefCounted


enum NodeType {
	START,
	ROOM,
	BATTLE,
	EVENT,
	ITEM,
	ELITE,
	BOSS,
}

enum MapState {
	LOCKED,
	AVAILABLE,
	SELECTED,
	VISITED,
	CLEARED,
}


var node_id: StringName = &""
var column: int = 0
var row: int = 0
var node_type: NodeType = NodeType.ROOM
var display_name: String = ""
var encounter_id: StringName = &""
var encounter_template_id: StringName = &""
# Registry identity is separate from an executable EventRoomDefinition. This
# lets a generated map name an authored room without activating unfinished
# room-specific dialogue, loot, or presentation.
var authored_room_id: StringName = &""
var room_definition_id: StringName = &""
var content_seed: int = 0
var outgoing_ids: Array[StringName] = []
var incoming_ids: Array[StringName] = []
var visited: bool = false
var cleared: bool = false
var reward_claimed: bool = false
var reward_source_id: StringName = &""
# Retained only so Milestone 8 active-run snapshots can still be restored.
var first_clear_item_id: StringName = &""
var first_clear_item_quantity: int = 0
var first_clear_item_stack_limit: int = 1
var travel_enabled: bool = true
var locked_reason: String = ""


func to_snapshot() -> Dictionary:
	var outgoing: Array[String] = []
	for connected_id: StringName in outgoing_ids:
		outgoing.append(String(connected_id))
	var incoming: Array[String] = []
	for connected_id: StringName in incoming_ids:
		incoming.append(String(connected_id))
	return {
		"node_id": String(node_id),
		"column": column,
		"row": row,
		"node_type": int(node_type),
		"display_name": display_name,
		"encounter_id": String(encounter_id),
		"encounter_template_id": String(encounter_template_id),
		"authored_room_id": String(authored_room_id),
		"room_definition_id": String(room_definition_id),
		"content_seed": content_seed,
		"outgoing_ids": outgoing,
		"incoming_ids": incoming,
		"visited": visited,
		"cleared": cleared,
		"reward_claimed": reward_claimed,
		"reward_source_id": String(reward_source_id),
		"first_clear_item_id": String(first_clear_item_id),
		"first_clear_item_quantity": first_clear_item_quantity,
		"first_clear_item_stack_limit": first_clear_item_stack_limit,
		"travel_enabled": travel_enabled,
		"locked_reason": locked_reason,
	}


static func from_snapshot(snapshot: Dictionary) -> Dictionary:
	var restored_id := StringName(snapshot.get("node_id", ""))
	var restored_type: int = int(snapshot.get("node_type", -1))
	var outgoing_value: Variant = snapshot.get("outgoing_ids", null)
	var incoming_value: Variant = snapshot.get("incoming_ids", null)
	var authored_room_value: Variant = snapshot.get(
		"authored_room_id",
		snapshot.get("room_definition_id", "")
	)
	var content_seed_value: Variant = snapshot.get("content_seed", 0)
	if restored_id == &"":
		return {"error": "Map snapshot contains an empty node ID.", "node": null}
	if restored_type < NodeType.START or restored_type > NodeType.BOSS:
		return {"error": "Map snapshot contains an invalid node type.", "node": null}
	if not (outgoing_value is Array) or not (incoming_value is Array):
		return {"error": "Map snapshot contains invalid node connections.", "node": null}
	if not (authored_room_value is String or authored_room_value is StringName):
		return {"error": "Map snapshot contains an invalid authored room ID.", "node": null}
	if (
		not (content_seed_value is int or content_seed_value is float)
		or float(content_seed_value) < 0.0
		or float(content_seed_value) != floorf(float(content_seed_value))
	):
		return {"error": "Map snapshot contains an invalid content seed.", "node": null}
	var restored := MapNodeState.new()
	restored.node_id = restored_id
	restored.column = int(snapshot.get("column", -1))
	restored.row = int(snapshot.get("row", -1))
	if restored.column < 0 or restored.row < 0:
		return {"error": "Map snapshot contains invalid node coordinates.", "node": null}
	restored.node_type = restored_type as NodeType
	restored.display_name = String(snapshot.get("display_name", ""))
	restored.encounter_id = StringName(snapshot.get("encounter_id", ""))
	restored.encounter_template_id = StringName(snapshot.get("encounter_template_id", ""))
	restored.room_definition_id = StringName(snapshot.get("room_definition_id", ""))
	restored.authored_room_id = StringName(authored_room_value)
	restored.content_seed = int(content_seed_value)
	for value: Variant in outgoing_value as Array:
		if not (value is String or value is StringName) or StringName(value) == &"":
			return {"error": "Map snapshot contains an invalid outgoing node ID.", "node": null}
		restored.outgoing_ids.append(StringName(value))
	for value: Variant in incoming_value as Array:
		if not (value is String or value is StringName) or StringName(value) == &"":
			return {"error": "Map snapshot contains an invalid incoming node ID.", "node": null}
		restored.incoming_ids.append(StringName(value))
	for boolean_field: String in ["visited", "cleared", "reward_claimed", "travel_enabled"]:
		if typeof(snapshot.get(boolean_field, null)) != TYPE_BOOL:
			return {"error": "Map snapshot contains invalid %s." % boolean_field, "node": null}
	restored.visited = bool(snapshot.get("visited"))
	restored.cleared = bool(snapshot.get("cleared"))
	restored.reward_claimed = bool(snapshot.get("reward_claimed"))
	restored.reward_source_id = StringName(snapshot.get("reward_source_id", ""))
	restored.first_clear_item_id = StringName(snapshot.get("first_clear_item_id", ""))
	restored.first_clear_item_quantity = int(snapshot.get("first_clear_item_quantity", 0))
	restored.first_clear_item_stack_limit = int(snapshot.get("first_clear_item_stack_limit", 1))
	if restored.first_clear_item_quantity < 0 or restored.first_clear_item_stack_limit <= 0:
		return {"error": "Map snapshot contains invalid first-clear item data.", "node": null}
	# Narrow Milestone 8 compatibility: the only authored first-clear item was
	# Chain Oil. Its canonical source is fixed, so this cannot reroll old data.
	if (
		restored.reward_source_id == &""
		and restored.first_clear_item_id == &"l02_chain_oil"
		and restored.first_clear_item_quantity == 1
	):
		restored.reward_source_id = &"l02_kept_watch_chain_oil"
	elif (
		restored.reward_source_id == &""
		and restored.node_type == NodeType.ITEM
	):
		# The former controller path granted Bandage deterministically. Preserve
		# that exact unresolved reward rather than introducing a migration reroll.
		restored.reward_source_id = &"m8_compat_bandage_cache"
	restored.travel_enabled = bool(snapshot.get("travel_enabled"))
	restored.locked_reason = String(snapshot.get("locked_reason", ""))
	return {"error": "", "node": restored}


func get_type_label() -> String:
	match node_type:
		NodeType.START:
			return "Start"
		NodeType.ROOM:
			return "Room"
		NodeType.BATTLE:
			return "Battle"
		NodeType.EVENT:
			return "Event"
		NodeType.ITEM:
			return "Item"
		NodeType.ELITE:
			return "Elite"
		NodeType.BOSS:
			return "Boss"
	return "Unknown"


func requires_battle() -> bool:
	return node_type in [
		NodeType.BATTLE,
		NodeType.ELITE,
		NodeType.BOSS,
	]


func has_encounter_content() -> bool:
	return encounter_id != &"" and encounter_template_id != &""


func requires_event_room() -> bool:
	return(
		node_type in [
			NodeType.ROOM,
			NodeType.EVENT,
			NodeType.ITEM,
		]
		and room_definition_id != &""
	)
