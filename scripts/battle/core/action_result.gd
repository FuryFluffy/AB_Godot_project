class_name ActionResult
extends RefCounted


enum AllocationItem {
	NONE,
	ARMOR,
	SHIELD,
}


var request: ActionRequest

var succeeded: bool = false
var is_complete: bool = false
var error_message: String = ""

var roll_result: RollResult
var defense_roll: RollResult

var defense_choice: DefenseChoice.Type = DefenseChoice.Type.SKIP
var attack_reaction_choice: AttackReactionChoice.Type = (
	AttackReactionChoice.Type.SKIP
)

var attack_successes: int = 0
var defense_successes: int = 0
var defense_successes_ignored: int = 0
var effective_defense_successes: int = 0
var remaining_attack_successes: int = 0
var ward_dice_bonus: int = 0
var analyzed_bonus_consumed: bool = false
var blessed_attack_consumed: bool = false
var weapon_attack_dice_bonus: int = 0
var weapon_attack_success_bonus: int = 0
var weapon_flat_damage_bonus: int = 0
var weapon_action_loss: int = 0
var weapon_critical_free_attack_requested: bool = false
var weapon_critical_free_attack_generated: bool = false
var weapon_effect_messages: Array[String] = []
var specialty_damage_bonus: int = 0
var blood_riposte_generated: bool = false
var dodge_step_available: bool = false
var dodge_step_taken: bool = false
var dodge_destination_anchor_id: StringName = &""
var dodge_destination_position_index: int = -1

var action_spent: int = 0
var reaction_action_spent: int = 0

# Parry details. The penalty is stored as a positive magnitude for logs.
var parry_penalty: int = 0
var parry_shield_bonus: int = 0
var parry_prevented_damage: int = 0
var parry_should_generate_free_attack: bool = false
var parry_generated_free_attack: bool = false

var counterattack_requested: bool = false
var counterattack_generated: bool = false

var durability_processed: bool = false
var weapon_durability_event: bool = false
var weapon_durability_before: int = 0
var weapon_durability_after: int = 0
var weapon_broken: bool = false

# HP damage only.
var damage_dealt: int = 0

var armor_damage_absorbed: int = 0
var shield_damage_absorbed: int = 0
var armor_broken: bool = false
var shield_broken: bool = false

var requires_equipment_break_choice: bool = false
var pending_break_item: AllocationItem = AllocationItem.NONE
var pending_damage_after_safe_absorption: int = 0

# Runtime cursor for automatic Shield First / Armor First allocation.
var allocation_order: Array[int] = []
var allocation_index: int = 0

var actor_actions_before: int = 0
var actor_actions_after: int = 0

var target_actions_before: int = 0
var target_actions_after: int = 0

var target_hp_before: int = 0
var target_hp_after: int = 0

var target_defeated: bool = false

var weapon_effects_processed: bool = false
var status_processed: bool = false
var status_applied: bool = false
var status_replaced_existing: bool = false
var status_display_name: String = ""
var status_error_message: String = ""


func fail(message: String) -> ActionResult:
	succeeded = false
	is_complete = false
	error_message = message
	return self
