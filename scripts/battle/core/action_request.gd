class_name ActionRequest
extends RefCounted


enum ActionType {
	BASIC_ATTACK,
}

enum Source {
	NORMAL,
	COUNTERATTACK,
	PARRY_FREE_ATTACK,
	MOVE_REACTION,
	AOE,
	ITEM,
	ABILITY,
	BLOOD_RIPOSTE,
	WEAPON_CRITICAL,
}

enum ReactionMode {
	FULL,
	DEFENSE_ONLY,
}


var action_type: ActionType = ActionType.BASIC_ATTACK
var source: Source = Source.NORMAL
var reaction_mode: ReactionMode = ReactionMode.FULL

var actor_id: StringName = &""
var target_id: StringName = &""

var action_cost: int = 1
var seed_value: int = 0

var weapon: WeaponDefinition
var weapon_family_rank: int = 0
var ability: AbilityDefinition
var item: ItemDefinition
var shared_attack_roll: RollResult

# Free Attacks use the normal attack pipeline but spend no Action.
var is_free_attack: bool = false

	# Parry is unavailable against magic. Current weapon attacks
# leave this false; spell Actions will set it later.
var is_magic: bool = false
var permits_parry: bool = true

# 0 on the original Attack, 1 on the first Parry-generated free Attack,
# and so on. Parry uses -(parry_sequence_index + 1)d10.
var parry_sequence_index: int = 0

# The targeting controller resolves these before the Attack is committed.
# Keeping them on the request lets the dice resolver remain map-agnostic.
var spatial_range_label: String = ""
var attack_dice_modifier: int = 0
var suppress_skill_modification: bool = false
var ignore_one_defense_success: bool = false
var qualifies_for_analysis: bool = false


func _init(
	request_actor_id: StringName = &"",
	request_target_id: StringName = &"",
	request_weapon: WeaponDefinition = null,
	request_seed: int = 0,
	request_is_free_attack: bool = false,
	request_is_magic: bool = false,
	request_parry_sequence_index: int = 0,
	request_source: Source = Source.NORMAL,
	request_reaction_mode: ReactionMode = ReactionMode.FULL,
	request_weapon_family_rank: int = 0
) -> void:
	actor_id = request_actor_id
	target_id = request_target_id
	weapon = request_weapon
	weapon_family_rank = request_weapon_family_rank
	seed_value = request_seed
	is_free_attack = request_is_free_attack
	is_magic = request_is_magic
	source = request_source
	reaction_mode = request_reaction_mode
	parry_sequence_index = maxi(
		request_parry_sequence_index,
		0
	)
	action_cost = 0 if is_free_attack else 1


func get_source_label() -> String:
	match source:
		Source.COUNTERATTACK:
			return "Counterattack"
		Source.PARRY_FREE_ATTACK:
			return "Parry free Attack"
		Source.MOVE_REACTION:
			return "Move Reaction Attack"
		Source.AOE:
			return (
				ability.display_name
				if ability != null
				else "AOE"
			)
		Source.ITEM:
			return (
				item.display_name
				if item != null
				else "Item Attack"
			)
		Source.ABILITY:
			return (
				ability.display_name
				if ability != null
				else "Ability"
			)
		Source.BLOOD_RIPOSTE:
			return "Blood Riposte"
		Source.WEAPON_CRITICAL:
			return "Weapon critical free Attack"

	return "Attack"
