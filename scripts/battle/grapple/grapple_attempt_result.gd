class_name GrappleAttemptResult
extends RefCounted


var actor_id: StringName = &""
var target_id: StringName = &""
var template: GrappleTemplateDefinition

var succeeded: bool = false
var is_complete: bool = false
var error_message: String = ""

var attack_roll: RollResult
var dodge_roll: RollResult
var rolled_pool: int = 0
var automatic_successes: int = 1
var attack_successes: int = 0
var dodge_successes: int = 0
var remaining_successes: int = 0

var action_spent: int = 0
var dodge_action_spent: int = 0
var corruption_snapshot: int = 0
var resolve_snapshot: int = 0
var stage_corruption_applied: int = 0
var stage_resolve_applied: int = 0
var track: GrappleTrackState
var is_move_reaction: bool = false


func fail(message: String) -> GrappleAttemptResult:
	error_message = message
	succeeded = false
	is_complete = false
	return self
