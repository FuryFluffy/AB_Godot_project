class_name ExplorationStageTriggerState
extends RefCounted


var binding: CombatStageBindingDefinition
var elapsed_seconds: float = 0.0
var armed: bool = false
var fired: bool = false
var cancelled: bool = false


func configure(
	new_binding: CombatStageBindingDefinition,
	restored_as_fired: bool = false
) -> String:
	if new_binding == null:
		return "Exploration-stage trigger requires a binding."
	var binding_error: String = new_binding.validate_definition()
	if not binding_error.is_empty():
		return binding_error
	binding = new_binding
	elapsed_seconds = 0.0
	armed = not restored_as_fired
	fired = restored_as_fired
	cancelled = false
	return ""


func activate(trigger_type: StringName) -> bool:
	if not armed or fired or cancelled or binding == null:
		return false
	if binding.trigger_type != trigger_type:
		return false
	return _fire()


func advance_delayed(
	delta: float,
	room_resolved: bool = false,
	room_exited: bool = false,
	dialogue_opened: bool = false,
	mode_changed: bool = false
) -> bool:
	if not armed or fired or cancelled or binding == null:
		return false
	if binding.trigger_type != &"delayed_on_enter":
		return false
	if room_resolved or room_exited or dialogue_opened or mode_changed:
		cancel()
		return false
	elapsed_seconds += maxf(delta, 0.0)
	if elapsed_seconds < binding.delay_seconds:
		return false
	return _fire()


func cancel() -> void:
	armed = false
	cancelled = true


func _fire() -> bool:
	armed = false
	fired = true
	return true
