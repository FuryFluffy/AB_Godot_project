class_name ReactionContext
extends RefCounted


var request: ActionRequest

var attack_roll: RollResult

var attacker_actions_before: int = 0
var attacker_actions_after: int = 0

var attack_successes: int = 0

var is_valid: bool = false
var error_message: String = ""


func fail(message: String) -> ReactionContext:
	is_valid = false
	error_message = message
	return self
