class_name DialogueContext
extends RefCounted


var current_party_ids: Array[StringName] = []
var present_actor_ids: Array[StringName] = []
var recruited_heroine_ids: Array[StringName] = []
var heroine_states: Dictionary = {}
var inventory_quantities: Dictionary = {}
var knowledge_ids: Array[StringName] = []
var flags_by_scope: Dictionary = {
	&"run": {},
	&"save": {},
	&"persistent": {},
}
var choice_ids: Array[StringName] = []
var resolved_interaction_ids: Array[StringName] = []
var campaign_item_ids: Array[StringName] = []
var pending_bloom: int = 0


func get_heroine_stat(
	heroine_id: StringName,
	stat_id: StringName
) -> int:
	var snapshot: Dictionary = heroine_states.get(
		heroine_id,
		heroine_states.get(String(heroine_id), {})
	) as Dictionary
	return int(snapshot.get(String(stat_id), snapshot.get(stat_id, 0)))


func modify_heroine_stat(
	heroine_id: StringName,
	stat_id: StringName,
	delta: int
) -> void:
	var snapshot: Dictionary = (
		heroine_states.get(
			heroine_id,
			heroine_states.get(String(heroine_id), {})
		) as Dictionary
	).duplicate(true)
	snapshot[String(stat_id)] = get_heroine_stat(
		heroine_id,
		stat_id
	) + delta
	heroine_states[heroine_id] = snapshot


func get_item_quantity(item_id: StringName) -> int:
	return int(
		inventory_quantities.get(
			item_id,
			inventory_quantities.get(String(item_id), 0)
		)
	)


func change_item_quantity(
	item_id: StringName,
	delta: int
) -> void:
	inventory_quantities[item_id] = maxi(
		get_item_quantity(item_id) + delta,
		0
	)


func get_flag(
	scope: StringName,
	flag_id: StringName
) -> bool:
	var flags: Dictionary = flags_by_scope.get(scope, {}) as Dictionary
	return bool(flags.get(flag_id, flags.get(String(flag_id), false)))


func set_flag(
	scope: StringName,
	flag_id: StringName,
	value: bool
) -> void:
	var flags: Dictionary = (
		flags_by_scope.get(scope, {}) as Dictionary
	).duplicate(true)
	flags[flag_id] = value
	flags_by_scope[scope] = flags


func to_snapshot() -> Dictionary:
	return {
		"current_party_ids": _string_array(current_party_ids),
		"present_actor_ids": _string_array(present_actor_ids),
		"recruited_heroine_ids": _string_array(recruited_heroine_ids),
		"heroine_states": heroine_states.duplicate(true),
		"inventory_quantities": inventory_quantities.duplicate(true),
		"knowledge_ids": _string_array(knowledge_ids),
		"flags_by_scope": flags_by_scope.duplicate(true),
		"choice_ids": _string_array(choice_ids),
		"resolved_interaction_ids": _string_array(
			resolved_interaction_ids
		),
		"campaign_item_ids": _string_array(campaign_item_ids),
		"pending_bloom": pending_bloom,
	}


static func from_snapshot(snapshot: Dictionary) -> DialogueContext:
	var context := DialogueContext.new()
	context.current_party_ids = _name_array(
		snapshot.get("current_party_ids", []) as Array
	)
	context.present_actor_ids = _name_array(
		snapshot.get("present_actor_ids", []) as Array
	)
	context.recruited_heroine_ids = _name_array(
		snapshot.get("recruited_heroine_ids", []) as Array
	)
	context.heroine_states = (
		snapshot.get("heroine_states", {}) as Dictionary
	).duplicate(true)
	context.inventory_quantities = (
		snapshot.get("inventory_quantities", {}) as Dictionary
	).duplicate(true)
	context.knowledge_ids = _name_array(
		snapshot.get("knowledge_ids", []) as Array
	)
	context.flags_by_scope = (
		snapshot.get("flags_by_scope", {}) as Dictionary
	).duplicate(true)
	for scope: StringName in [&"run", &"save", &"persistent"]:
		if not context.flags_by_scope.has(scope):
			context.flags_by_scope[scope] = {}
	context.choice_ids = _name_array(
		snapshot.get("choice_ids", []) as Array
	)
	context.resolved_interaction_ids = _name_array(
		snapshot.get("resolved_interaction_ids", []) as Array
	)
	context.campaign_item_ids = _name_array(
		snapshot.get("campaign_item_ids", []) as Array
	)
	context.pending_bloom = int(snapshot.get("pending_bloom", 0))
	return context


static func _name_array(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in values:
		result.append(StringName(value))
	return result


static func _string_array(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(String(value))
	return result
