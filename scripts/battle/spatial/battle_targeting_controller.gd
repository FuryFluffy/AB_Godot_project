class_name BattleTargetingController
extends RefCounted


var battler_states: Dictionary = {}
var battlefield_state: BattlefieldState


func initialize(
	new_battler_states: Dictionary,
	new_battlefield_state: BattlefieldState
) -> void:
	battler_states = new_battler_states
	battlefield_state = new_battlefield_state


func evaluate_attack(
	attacker_id: StringName,
	target_id: StringName,
	weapon: WeaponDefinition,
	is_magic: bool = false,
	weapon_family_rank: int = 0
) -> AttackTargetingResult:
	var result: AttackTargetingResult = AttackTargetingResult.new()

	if battlefield_state == null:
		return result.deny("BattlefieldState is missing.")
	if weapon == null:
		return result.deny("No attack weapon is available.")

	var attacker: BattlerState = _get_battler_state(attacker_id)
	var target: BattlerState = _get_battler_state(target_id)
	var combatant_error: String = _validate_combatants(
		attacker,
		target
	)
	if not combatant_error.is_empty():
		return result.deny(combatant_error)

	result.spatial_range = battlefield_state.get_spatial_range(
		attacker_id,
		target_id
	)
	result.spatial_range_label = (
		battlefield_state.get_spatial_range_label(
			result.spatial_range
		)
	)

	var range_error: String = _get_range_error(
		attacker_id,
		target_id,
		weapon,
		is_magic,
		result.spatial_range
	)
	if not range_error.is_empty():
		return result.deny(range_error)

	if (
		is_magic
		or weapon.attack_range
		== WeaponDefinition.AttackRange.RANGED
	):
		result.blocking_terrain_names = (
			battlefield_state.get_line_blocker_names(
				attacker_id,
				target_id
			)
		)
		result.has_line_of_sight = (
			result.blocking_terrain_names.is_empty()
		)
		if not result.has_line_of_sight:
			return result.deny(
				"Line of sight is blocked by %s."
				% ", ".join(
					PackedStringArray(
						result.blocking_terrain_names
					)
				)
			)

	if (
		not is_magic
		and weapon.attack_range
		== WeaponDefinition.AttackRange.RANGED
	):
		var cover_names: Array[String] = (
			battlefield_state.get_ranged_cover_names(
				attacker_id,
				target_id
			)
		)
		result.blocked_by_cover = not cover_names.is_empty()
		if result.blocked_by_cover:
			return result.deny(
				"Ordinary ranged Attack is denied by cover: %s."
				% ", ".join(PackedStringArray(cover_names))
			)

		if _is_engaged_with_hostile(attacker):
			result.attack_dice_modifier -= 2
			result.suppress_skill_modification = true

	result.attack_dice_modifier += weapon.get_range_dice_bonus(
		result.spatial_range,
		weapon_family_rank
	)

	return result.allow()


func get_legal_target_ids(
	attacker_id: StringName,
	weapon: WeaponDefinition,
	is_magic: bool = false,
	weapon_family_rank: int = 0
) -> Array[StringName]:
	var legal_ids: Array[StringName] = []

	for target_value: Variant in battler_states.values():
		var target: BattlerState = target_value as BattlerState
		if target == null or target.definition == null:
			continue

		var result: AttackTargetingResult = evaluate_attack(
			attacker_id,
			target.definition.battler_id,
			weapon,
			is_magic,
			weapon_family_rank
		)
		if result.is_legal:
			legal_ids.append(target.definition.battler_id)

	legal_ids.sort()
	return legal_ids


func _get_range_error(
	attacker_id: StringName,
	target_id: StringName,
	weapon: WeaponDefinition,
	is_magic: bool,
	spatial_range: BattlefieldState.SpatialRange
) -> String:
	if is_magic:
		if _is_within_zone_distance(
			attacker_id,
			target_id,
			weapon.maximum_zone_distance
		):
			return ""
		return "Magic target is outside its %d-zone range." % (
			weapon.maximum_zone_distance
		)

	match weapon.attack_range:
		WeaponDefinition.AttackRange.MELEE:
			if spatial_range == BattlefieldState.SpatialRange.ADJACENT:
				return ""
			return "Melee Attack requires an Adjacent target."

		WeaponDefinition.AttackRange.REACH:
			if spatial_range == BattlefieldState.SpatialRange.ADJACENT:
				return ""
			if battlefield_state.are_battler_anchors_connected(
				attacker_id,
				target_id
			):
				return ""
			return "Reach Attack requires the same or a directly connected Anchor."

		WeaponDefinition.AttackRange.RANGED:
			if _is_within_zone_distance(
				attacker_id,
				target_id,
				weapon.maximum_zone_distance
			):
				return ""
			return "Ranged target is outside its %d-zone range." % (
				weapon.maximum_zone_distance
			)

	return "The weapon has no supported spatial Attack range."


func _is_within_zone_distance(
	attacker_id: StringName,
	target_id: StringName,
	maximum_zone_distance: int
) -> bool:
	var attacker_anchor: AnchorDefinition = (
		battlefield_state.get_battler_anchor(attacker_id)
	)
	var target_anchor: AnchorDefinition = (
		battlefield_state.get_battler_anchor(target_id)
	)
	if attacker_anchor == null or target_anchor == null:
		return false
	if attacker_anchor.zone_id == target_anchor.zone_id:
		return true

	var distance: int = battlefield_state.get_zone_distance(
		attacker_anchor.zone_id,
		target_anchor.zone_id
	)
	return (
		distance >= 0
		and distance <= maxi(maximum_zone_distance, 0)
	)


func _is_engaged_with_hostile(
	attacker: BattlerState
) -> bool:
	if attacker == null or attacker.definition == null:
		return false

	var position_state: BattlerPositionState = (
		battlefield_state.get_battler_position(
			attacker.definition.battler_id
		)
	)
	if position_state == null:
		return false

	for occupant_id: StringName in (
		battlefield_state.get_adjacent_battler_ids_to_position(
			position_state.anchor_id,
			position_state.position_index,
			attacker.definition.battler_id
		)
	):
		var occupant: BattlerState = _get_battler_state(
			occupant_id
		)
		if _are_opponents(attacker, occupant):
			return true

	return false


func _validate_combatants(
	attacker: BattlerState,
	target: BattlerState
) -> String:
	if attacker == null or attacker.definition == null:
		return "The attacker is invalid."
	if target == null or target.definition == null:
		return "The target is invalid."
	if attacker == target:
		return "A combatant cannot attack itself."
	if not _are_opponents(attacker, target):
		return "A combatant cannot attack an ally."
	if attacker.is_defeated:
		return "%s is defeated." % attacker.definition.display_name
	if target.is_defeated:
		return "%s is already defeated." % target.definition.display_name

	return ""


func _are_opponents(
	first: BattlerState,
	second: BattlerState
) -> bool:
	if (
		first == null
		or second == null
		or first.definition == null
		or second.definition == null
	):
		return false

	return (
		(
			first.definition.faction
			== BattlerDefinition.Faction.HEROINE
			and second.definition.faction
			== BattlerDefinition.Faction.ENEMY
		)
		or (
			first.definition.faction
			== BattlerDefinition.Faction.ENEMY
			and second.definition.faction
			== BattlerDefinition.Faction.HEROINE
		)
	)


func _get_battler_state(
	battler_id: StringName
) -> BattlerState:
	return battler_states.get(battler_id) as BattlerState
