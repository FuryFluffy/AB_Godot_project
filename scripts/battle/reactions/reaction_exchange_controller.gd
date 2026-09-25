class_name ReactionExchangeController
extends RefCounted


var action_controller: BattleActionController
var runtime: BattleRuntimeState


func initialize(
	new_action_controller: BattleActionController,
	new_runtime: BattleRuntimeState
) -> void:
	action_controller = new_action_controller
	runtime = new_runtime


func get_availability(target: BattlerState) -> Dictionary:
	if target == null:
		return {}
	var has_action := target.current_actions > 0
	return {
		"attack": (
			has_action
			and action_controller.can_reaction_attack(target)
		),
		"dodge": (
			has_action
			and not target.is_defeated
			and not target.is_grappled()
			and not target.is_attached_grappler()
		),
		"armor": has_action and target.has_usable_armor(),
		"shield": has_action and target.has_usable_shield(),
		"parry": (
			has_action
			and action_controller.can_parry(target)
		),
		"skip": true,
	}


func resolve_reaction_intention(
	choice: StringName
) -> ActionResult:
	if action_controller == null or runtime == null:
		return ActionResult.new().fail(
			"ReactionExchangeController is not initialized."
		)
	match choice:
		&"attack":
			return action_controller.resolve_attack_reaction(
				AttackReactionChoice.Type.COUNTERATTACK
			)
		&"dodge":
			return _tag_defense_result(
				action_controller.resolve_reaction(
					DefenseChoice.Type.DODGE
				),
				DefenseChoice.Type.DODGE
			)
		&"parry":
			return _tag_defense_result(
				action_controller.resolve_reaction(
					DefenseChoice.Type.PARRY
				),
				DefenseChoice.Type.PARRY
			)
		&"skip":
			if (
				runtime.has_pending_reaction()
				and runtime.pending_reaction_context.request != null
				and runtime.pending_reaction_context.request.reaction_mode
				== ActionRequest.ReactionMode.FULL
			):
				return action_controller.resolve_attack_reaction(
					AttackReactionChoice.Type.SKIP
				)
			return _tag_defense_result(
				action_controller.resolve_reaction(
					DefenseChoice.Type.SKIP
				),
				DefenseChoice.Type.SKIP
			)
	return ActionResult.new().fail(
		"Unknown reaction intention: %s." % choice
	)


func resolve_defence_intention(
	choice: StringName
) -> ActionResult:
	match choice:
		&"armor":
			return _tag_defense_result(
				action_controller.resolve_reaction(
					DefenseChoice.Type.ARMOR
				),
				DefenseChoice.Type.ARMOR
			)
		&"shield":
			return _tag_defense_result(
				action_controller.resolve_reaction(
					DefenseChoice.Type.SHIELD
				),
				DefenseChoice.Type.SHIELD
			)
	return ActionResult.new().fail(
		"Unknown Defend intention: %s." % choice
	)


func get_defense_choice(choice: StringName) -> DefenseChoice.Type:
	match choice:
		&"dodge":
			return DefenseChoice.Type.DODGE
		&"armor":
			return DefenseChoice.Type.ARMOR
		&"shield":
			return DefenseChoice.Type.SHIELD
		&"parry":
			return DefenseChoice.Type.PARRY
	return DefenseChoice.Type.SKIP


func get_attack_choice(
	choice: StringName
) -> AttackReactionChoice.Type:
	return (
		AttackReactionChoice.Type.COUNTERATTACK
		if choice == &"attack"
		else AttackReactionChoice.Type.SKIP
	)


func get_break_choice(choice: StringName) -> BreakChoice.Type:
	return (
		BreakChoice.Type.DESTROY
		if choice == &"destroy"
		else BreakChoice.Type.PRESERVE
	)


func _tag_defense_result(
	result: ActionResult,
	choice: DefenseChoice.Type
) -> ActionResult:
	if result == null:
		return ActionResult.new().fail(
			"Reaction resolver returned no ActionResult."
		)
	result.attack_reaction_choice = (
		AttackReactionChoice.Type.SKIP
		if choice == DefenseChoice.Type.SKIP
		else AttackReactionChoice.Type.DEFEND
	)
	return result
