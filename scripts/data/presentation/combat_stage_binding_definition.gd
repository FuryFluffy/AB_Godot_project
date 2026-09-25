@tool
class_name CombatStageBindingDefinition
extends Resource


const TRIGGER_TYPES: Array[StringName] = [
	&"interaction",
	&"dialogue_result",
	&"route",
	&"delayed_on_enter",
]


@export_group("Identity")
@export var binding_id: StringName
@export var exploration_room_id: StringName
@export var accepts_runtime_room_identity: bool = false
@export var trigger_id: StringName

@export_group("Encounter")
@export var encounter_id: StringName
@export var combat_stage_id: StringName
@export var battlefield_id: StringName

@export_group("Trigger")
@export var trigger_type: StringName = &"route"
@export_range(0.0, 60.0, 0.05) var delay_seconds: float = 0.0

@export_group("Return")
@export var completion_state_id: StringName
@export var return_target: StringName


func matches_room(runtime_room_id: StringName) -> bool:
	return (
		accepts_runtime_room_identity
		or runtime_room_id == &""
		or exploration_room_id == runtime_room_id
	)


func validate_definition() -> String:
	if binding_id == &"":
		return "A combat-stage binding has no binding_id."
	if exploration_room_id == &"":
		return "Combat-stage binding '%s' has no exploration room identity." % binding_id
	if trigger_id == &"":
		return "Combat-stage binding '%s' has no trigger_id." % binding_id
	if encounter_id == &"" or combat_stage_id == &"" or battlefield_id == &"":
		return "Combat-stage binding '%s' has incomplete encounter/stage identity." % binding_id
	if trigger_type not in TRIGGER_TYPES:
		return "Combat-stage binding '%s' has invalid trigger type '%s'." % [
			binding_id,
			trigger_type,
		]
	if trigger_type == &"delayed_on_enter" and delay_seconds <= 0.0:
		return "Delayed combat-stage binding '%s' requires a positive delay." % binding_id
	if trigger_type != &"delayed_on_enter" and not is_zero_approx(delay_seconds):
		return "Non-delayed combat-stage binding '%s' must not declare a delay." % binding_id
	if completion_state_id == &"" or return_target == &"":
		return "Combat-stage binding '%s' has incomplete aftermath data." % binding_id
	return ""
