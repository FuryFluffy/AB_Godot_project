class_name EnemyRuleDefinition
extends Resource


enum Condition {
	ALWAYS,
	LEGAL_ATTACK_EXISTS,
	NO_LEGAL_ATTACK_EXISTS,
	ACTIVE_GRAPPLE_CAN_HOLD,
	ACTIVE_GRAPPLE_CAN_PROGRESS,
	LEGAL_GRAPPLE_TARGET_EXISTS,
}


enum Action {
	ATTACK,
	MOVE_TOWARD_TARGET,
	WAIT,
	GRAPPLE,
	GRAPPLE_HOLD,
	GRAPPLE_PROGRESS,
}


enum TargetPolicy {
	NEAREST,
	LOWEST_HP,
	LOWEST_HP_PERCENT,
}


@export_group("Identity")
@export var rule_id: StringName
@export var display_name: String = "Unnamed Rule"

@export_group("If")
@export var condition: Condition = Condition.ALWAYS

@export_group("Then")
@export var action: Action = Action.WAIT
@export var target_policy: TargetPolicy = TargetPolicy.NEAREST


func get_condition_label() -> String:
	match condition:
		Condition.LEGAL_ATTACK_EXISTS:
			return "a legal Attack target exists"
		Condition.NO_LEGAL_ATTACK_EXISTS:
			return "no legal Attack target exists"
		Condition.ACTIVE_GRAPPLE_CAN_HOLD:
			return "its active Grapple track can Hold"
		Condition.ACTIVE_GRAPPLE_CAN_PROGRESS:
			return "its active Grapple track can Progress"
		Condition.LEGAL_GRAPPLE_TARGET_EXISTS:
			return "a legal Grapple target exists"

	return "always"


func get_action_label() -> String:
	match action:
		Action.ATTACK:
			return "Attack"
		Action.MOVE_TOWARD_TARGET:
			return "Move toward target"
		Action.GRAPPLE:
			return "Grapple"
		Action.GRAPPLE_HOLD:
			return "Hold Grapple"
		Action.GRAPPLE_PROGRESS:
			return "Progress Grapple"
		Action.WAIT:
			return "Wait"

	return "Unknown"


func get_target_policy_label() -> String:
	match target_policy:
		TargetPolicy.LOWEST_HP:
			return "lowest current HP"
		TargetPolicy.LOWEST_HP_PERCENT:
			return "lowest HP percentage"

	return "nearest"
