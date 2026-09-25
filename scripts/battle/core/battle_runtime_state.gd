class_name BattleRuntimeState
extends RefCounted


var selected_battler_id: StringName = &"lysandra"
var battle_state: BattleState = BattleState.new()

var is_selecting_attack_target: bool = false
var pending_attacker_id: StringName = &""

var is_selecting_move: bool = false
var pending_mover_id: StringName = &""
var active_move: CommittedMoveState

var is_selecting_aoe: bool = false
var pending_aoe_caster_id: StringName = &""
var pending_aoe_ability: AbilityDefinition
var active_aoe: AoeResolutionState

var is_selecting_ability_target: bool = false
var pending_ability_caster_id: StringName = &""
var pending_ability: AbilityDefinition
var pending_ability_target_ids: Array[StringName] = []
var active_multi_target_attack: MultiTargetAttackState

var is_selecting_item_target: bool = false
var pending_item_user_id: StringName = &""
var pending_item_slot_index: int = -1
var pending_item_attack_user_id: StringName = &""
var pending_item_attack_slot_index: int = -1
var pending_item_attack_item_id: StringName = &""

var pending_reaction_context: ReactionContext
var pending_reaction_target_id: StringName = &""
var pending_action_result: ActionResult
var pending_attack_reaction_choice: AttackReactionChoice.Type = (
	AttackReactionChoice.Type.SKIP
)

var resolution_queue: AttackResolutionQueue = (
	AttackResolutionQueue.new()
)


func has_pending_reaction() -> bool:
	return pending_reaction_context != null


func can_change_phase() -> bool:
	return (
		not has_pending_reaction()
		and not is_selecting_attack_target
		and not is_selecting_move
		and active_move == null
		and not is_selecting_aoe
		and active_aoe == null
		and not is_selecting_ability_target
		and active_multi_target_attack == null
		and not is_selecting_item_target
		and not has_pending_item_attack()
		and resolution_queue.is_empty()
	)


func begin_attack_targeting(
	attacker_id: StringName
) -> void:
	is_selecting_attack_target = true
	pending_attacker_id = attacker_id


func cancel_attack_targeting() -> void:
	is_selecting_attack_target = false
	pending_attacker_id = &""


func begin_move_targeting(
	mover_id: StringName
) -> void:
	is_selecting_move = true
	pending_mover_id = mover_id


func cancel_move_targeting() -> void:
	is_selecting_move = false
	pending_mover_id = &""


func has_active_move() -> bool:
	return active_move != null


func store_active_move(
	move_state: CommittedMoveState
) -> void:
	active_move = move_state
	cancel_move_targeting()


func clear_active_move() -> void:
	active_move = null


func begin_aoe_targeting(
	caster_id: StringName,
	ability: AbilityDefinition
) -> void:
	is_selecting_aoe = true
	pending_aoe_caster_id = caster_id
	pending_aoe_ability = ability


func cancel_aoe_targeting() -> void:
	is_selecting_aoe = false
	pending_aoe_caster_id = &""
	pending_aoe_ability = null


func store_active_aoe(
	aoe_state: AoeResolutionState
) -> void:
	active_aoe = aoe_state
	cancel_aoe_targeting()


func has_active_aoe() -> bool:
	return active_aoe != null


func clear_active_aoe() -> void:
	active_aoe = null
	cancel_aoe_targeting()


func begin_ability_targeting(
	caster_id: StringName,
	ability: AbilityDefinition
) -> void:
	is_selecting_ability_target = true
	pending_ability_caster_id = caster_id
	pending_ability = ability
	pending_ability_target_ids.clear()


func add_pending_ability_target(target_id: StringName) -> void:
	if not pending_ability_target_ids.has(target_id):
		pending_ability_target_ids.append(target_id)


func cancel_ability_targeting() -> void:
	is_selecting_ability_target = false
	pending_ability_caster_id = &""
	pending_ability = null
	pending_ability_target_ids.clear()


func store_active_multi_target_attack(
	state: MultiTargetAttackState
) -> void:
	active_multi_target_attack = state
	cancel_ability_targeting()


func has_active_multi_target_attack() -> bool:
	return active_multi_target_attack != null


func clear_active_multi_target_attack() -> void:
	active_multi_target_attack = null


func begin_item_targeting(
	user_id: StringName,
	slot_index: int
) -> void:
	is_selecting_item_target = true
	pending_item_user_id = user_id
	pending_item_slot_index = slot_index


func cancel_item_targeting() -> void:
	is_selecting_item_target = false
	pending_item_user_id = &""
	pending_item_slot_index = -1


func reserve_pending_item_attack(
	user_id: StringName,
	slot_index: int,
	item_id: StringName
) -> void:
	pending_item_attack_user_id = user_id
	pending_item_attack_slot_index = slot_index
	pending_item_attack_item_id = item_id
	cancel_item_targeting()


func has_pending_item_attack() -> bool:
	return (
		pending_item_attack_user_id != &""
		and pending_item_attack_slot_index >= 0
		and pending_item_attack_item_id != &""
	)


func clear_pending_item_attack() -> void:
	pending_item_attack_user_id = &""
	pending_item_attack_slot_index = -1
	pending_item_attack_item_id = &""


func store_pending_reaction(
	context: ReactionContext,
	target_id: StringName
) -> void:
	pending_reaction_context = context
	pending_reaction_target_id = target_id
	pending_action_result = null
	pending_attack_reaction_choice = (
		AttackReactionChoice.Type.SKIP
	)
	cancel_attack_targeting()


func clear_pending_reaction() -> void:
	pending_reaction_context = null
	pending_reaction_target_id = &""
	pending_action_result = null
	pending_attack_reaction_choice = (
		AttackReactionChoice.Type.SKIP
	)


func clear_resolution_chain() -> void:
	clear_pending_reaction()
	resolution_queue.clear()


func reset() -> void:
	selected_battler_id = &"lysandra"
	cancel_attack_targeting()
	cancel_move_targeting()
	clear_active_move()
	clear_active_aoe()
	clear_active_multi_target_attack()
	cancel_ability_targeting()
	cancel_item_targeting()
	clear_pending_item_attack()
	clear_resolution_chain()
