class_name EnemyRulebookDefinition
extends Resource


enum AttackReactionPolicy {
	DEFEND,
	COUNTERATTACK_IF_LEGAL,
	SKIP,
}


enum DefensePreference {
	DODGE,
	ARMOR,
	SHIELD,
	PARRY,
	SKIP,
}


enum BreakPolicy {
	PRESERVE,
	DESTROY,
}


enum MoveReactionPolicy {
	ATTACK,
	GRAPPLE_IF_LEGAL,
	DECLINE,
}


@export_group("Identity")
@export var rulebook_id: StringName
@export var display_name: String = "Unnamed Enemy Rulebook"

@export_group("Active Action Rules")
@export var rules: Array[EnemyRuleDefinition] = []

@export_group("Reaction Rules")
@export var attack_reaction_policy: AttackReactionPolicy = (
	AttackReactionPolicy.DEFEND
)
@export var defense_preference: DefensePreference = (
	DefensePreference.DODGE
)
@export var break_policy: BreakPolicy = BreakPolicy.PRESERVE
@export var react_to_enemy_moves: bool = true
@export_range(0, 100, 1) var move_reaction_priority: int = 0
@export var move_reaction_policy: MoveReactionPolicy = (
	MoveReactionPolicy.ATTACK
)


func get_attack_reaction_label() -> String:
	match attack_reaction_policy:
		AttackReactionPolicy.COUNTERATTACK_IF_LEGAL:
			return "Counterattack if legal"
		AttackReactionPolicy.SKIP:
			return "Skip"

	return "Defend"


func get_defense_label() -> String:
	match defense_preference:
		DefensePreference.ARMOR:
			return "Armor"
		DefensePreference.SHIELD:
			return "Shield"
		DefensePreference.PARRY:
			return "Parry"
		DefensePreference.SKIP:
			return "Skip"

	return "Dodge"


func get_move_reaction_label() -> String:
	match move_reaction_policy:
		MoveReactionPolicy.GRAPPLE_IF_LEGAL:
			return "Grapple if legal; otherwise Attack"
		MoveReactionPolicy.DECLINE:
			return "Decline"

	return "Attack"
