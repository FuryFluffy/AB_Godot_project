class_name GrappleActionResult
extends RefCounted


var succeeded: bool = false
var error_message: String = ""
var action_name: String = ""
var track: GrappleTrackState

var stage_before: int = 0
var stage_after: int = 0
var actions_spent: int = 0
var corruption_applied: int = 0
var resolve_applied: int = 0
var detached: bool = false
var climax_reached: bool = false

var heroine_roll: RollResult
var grappler_roll: RollResult
var heroine_successes: int = 0
var grappler_successes: int = 0


func fail(message: String) -> GrappleActionResult:
	error_message = message
	succeeded = false
	return self

