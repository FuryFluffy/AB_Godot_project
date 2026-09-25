class_name AttackResolutionQueue
extends RefCounted


const MAXIMUM_GENERATED_ATTACKS: int = 32


var _requests: Array[ActionRequest] = []
var generated_attack_count: int = 0


func is_empty() -> bool:
	return _requests.is_empty()


func size() -> int:
	return _requests.size()


func enqueue(request: ActionRequest) -> String:
	if request == null:
		return "Cannot queue an empty Attack request."

	if generated_attack_count >= MAXIMUM_GENERATED_ATTACKS:
		return (
			"Generated Attack safety limit (%d) was reached."
			% MAXIMUM_GENERATED_ATTACKS
		)

	_requests.append(request)
	generated_attack_count += 1
	return ""


func pop_next() -> ActionRequest:
	if _requests.is_empty():
		return null

	return _requests.pop_front()


func clear() -> void:
	_requests.clear()
	generated_attack_count = 0
