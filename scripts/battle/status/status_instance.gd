class_name StatusInstance
extends RefCounted


var definition: StatusDefinition
var source_battler_id: StringName = &""
var damage_per_tick: int = 0
var healing_per_tick: int = 0
var is_magical: bool = false
var is_dispellable: bool = false
var total_ticks: int = 1
var resolved_ticks: int = 0


func _init(
	new_definition: StatusDefinition = null,
	new_source_battler_id: StringName = &"",
	damage_override: int = -1,
	tick_override: int = -1,
	magical_override: int = -1,
	dispellable_override: int = -1
) -> void:
	if new_definition == null:
		return

	definition = new_definition
	source_battler_id = new_source_battler_id
	damage_per_tick = (
		damage_override
		if damage_override >= 0
		else definition.periodic_damage
	)
	healing_per_tick = definition.periodic_healing
	is_magical = (
		definition.is_magical
		if magical_override < 0
		else magical_override > 0
	)
	is_dispellable = (
		definition.is_dispellable
		if dispellable_override < 0
		else dispellable_override > 0
	)
	total_ticks = maxi(
		(
			tick_override
			if tick_override > 0
			else definition.duration_ticks
		),
		1
	)


func refresh(
	damage_override: int = -1,
	tick_override: int = -1,
	magical_override: int = -1,
	dispellable_override: int = -1
) -> void:
	if definition == null:
		return

	damage_per_tick = (
		damage_override
		if damage_override >= 0
		else definition.periodic_damage
	)
	healing_per_tick = definition.periodic_healing
	is_magical = (
		definition.is_magical
		if magical_override < 0
		else magical_override > 0
	)
	is_dispellable = (
		definition.is_dispellable
		if dispellable_override < 0
		else dispellable_override > 0
	)
	total_ticks = maxi(
		(
			tick_override
			if tick_override > 0
			else definition.duration_ticks
		),
		1
	)
	resolved_ticks = 0


func matches(
	status_definition: StatusDefinition,
	source_id: StringName
) -> bool:
	return (
		definition != null
		and status_definition != null
		and definition.status_id == status_definition.status_id
		and source_battler_id == source_id
	)


func is_expired() -> bool:
	return resolved_ticks >= total_ticks


func get_display_text() -> String:
	if definition == null:
		return "Invalid Status"

	return "%s %d/%d" % [
		definition.display_name,
		resolved_ticks,
		total_ticks,
	]
