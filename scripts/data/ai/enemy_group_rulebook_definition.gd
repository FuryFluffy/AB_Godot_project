class_name EnemyGroupRulebookDefinition
extends Resource


@export_group("Identity")
@export var rulebook_id: StringName
@export var display_name: String = "Unnamed Enemy Group Rulebook"

@export_group("Ordered Rules")
@export var rules: Array[EnemyGroupRuleDefinition] = []
