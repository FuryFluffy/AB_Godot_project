@tool
class_name DialogueConditionDefinition
extends Resource


enum Kind {
	ALWAYS,
	PARTY_CONTAINS,
	ACTOR_PRESENT,
	RECRUITED,
	HEROINE_STAT,
	INVENTORY_HAS_ITEM,
	KNOWLEDGE_DISCOVERED,
	FLAG_SET,
	PREVIOUS_CHOICE,
	INTERACTION_RESOLVED,
}

enum Comparison {
	EQUAL,
	NOT_EQUAL,
	LESS,
	LESS_OR_EQUAL,
	GREATER,
	GREATER_OR_EQUAL,
}


@export var kind: Kind = Kind.ALWAYS
@export var subject_id: StringName
@export var key: StringName
@export var scope: StringName = &"run"
@export var comparison: Comparison = Comparison.EQUAL
@export var expected_integer: int = 1
@export var expected_boolean: bool = true


func evaluate(context: DialogueContext) -> bool:
	if context == null:
		return false

	match kind:
		Kind.ALWAYS:
			return true
		Kind.PARTY_CONTAINS:
			return context.current_party_ids.has(subject_id)
		Kind.ACTOR_PRESENT:
			return context.present_actor_ids.has(subject_id)
		Kind.RECRUITED:
			return context.recruited_heroine_ids.has(subject_id)
		Kind.HEROINE_STAT:
			return _compare_integers(
				context.get_heroine_stat(subject_id, key),
				expected_integer
			)
		Kind.INVENTORY_HAS_ITEM:
			return _compare_integers(
				context.get_item_quantity(subject_id),
				expected_integer
			)
		Kind.KNOWLEDGE_DISCOVERED:
			return (
				context.knowledge_ids.has(subject_id)
				== expected_boolean
			)
		Kind.FLAG_SET:
			return (
				context.get_flag(scope, subject_id)
				== expected_boolean
			)
		Kind.PREVIOUS_CHOICE:
			return (
				context.choice_ids.has(subject_id)
				== expected_boolean
			)
		Kind.INTERACTION_RESOLVED:
			return (
				context.resolved_interaction_ids.has(subject_id)
				== expected_boolean
			)

	return false


func validate_definition() -> String:
	if kind == Kind.ALWAYS:
		return ""
	if subject_id == &"":
		return "A dialogue condition has no subject_id."
	if kind == Kind.HEROINE_STAT and key == &"":
		return "Heroine-stat dialogue condition has no stat key."
	if kind == Kind.FLAG_SET and scope not in [
		&"run",
		&"save",
		&"persistent",
	]:
		return "Dialogue flag condition has an invalid scope."
	return ""


func _compare_integers(left: int, right: int) -> bool:
	match comparison:
		Comparison.EQUAL:
			return left == right
		Comparison.NOT_EQUAL:
			return left != right
		Comparison.LESS:
			return left < right
		Comparison.LESS_OR_EQUAL:
			return left <= right
		Comparison.GREATER:
			return left > right
		Comparison.GREATER_OR_EQUAL:
			return left >= right
	return false
