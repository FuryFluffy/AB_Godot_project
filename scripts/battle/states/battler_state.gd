class_name BattlerState
extends RefCounted

signal state_changed
signal defeated
signal revived

var definition: BattlerDefinition
var progression: HeroineProgressionState
var equipment_loadout_state: PersonalEquipmentLoadoutState
var weapon_state: WeaponState
var armor_state: ArmorState
var shield_state: ShieldState

var damage_allocation_policy: EquipmentLoadout.DamageAllocationPolicy = (
	EquipmentLoadout.DamageAllocationPolicy.ARMOR_FIRST
)

var current_hp: int = 0
var current_mp: int = 0
var max_actions: int = 0
var current_actions: int = 0
var current_resolve: int = 0
var current_corruption: int = 0
var item_guard_points: int = 0

var actions_before_defeat: int = 0
var is_defeated: bool = false
var active_statuses: Array[StatusInstance] = []
var active_grapple_track_ids: Array[StringName] = []
var grapple_cluster_position_id: StringName = &""
var grapple_cooldown_activations: int = 0
var grapple_used_once: bool = false
var grapple_stage: int = 0
var grapple_stage_count: int = 0

# Authored Level 1 kit effects. They have explicit combat lifecycles rather
# than tabletop "next activation" timing.
var analyzed_target_id: StringName = &""
var ward_dice_bonus: int = 0
var blessed_minimum_damage: int = 0
var last_blood_riposte_round: int = -1
var passive_attack_dice_bonus: int = 0
var regeneration_rounds: int = 0
var boss_phase_triggered: bool = false


func _init(
	source_definition: BattlerDefinition = null,
	source_progression: HeroineProgressionState = null,
	source_equipment_loadout: PersonalEquipmentLoadoutState = null
) -> void:
	if source_definition != null:
		initialize(
			source_definition,
			source_progression,
			source_equipment_loadout
		)


func initialize(
	source_definition: BattlerDefinition,
	source_progression: HeroineProgressionState = null,
	source_equipment_loadout: PersonalEquipmentLoadoutState = null
) -> void:
	assert(
		source_definition != null,
		"BattlerState requires a BattlerDefinition."
	)

	definition = source_definition
	if source_progression != null:
		progression = source_progression
	elif (
		progression == null
		and definition.faction == BattlerDefinition.Faction.HEROINE
	):
		progression = HeroineProgressionState.new(
			definition.battler_id
		)

	current_hp = definition.max_hp
	current_mp = definition.max_mp
	max_actions = definition.base_actions
	current_actions = max_actions
	current_resolve = definition.starting_resolve
	current_corruption = definition.starting_corruption
	item_guard_points = 0

	actions_before_defeat = 0
	is_defeated = current_hp <= 0
	active_statuses.clear()
	active_grapple_track_ids.clear()
	grapple_cluster_position_id = &""
	grapple_cooldown_activations = 0
	grapple_used_once = false
	grapple_stage = 0
	grapple_stage_count = 0
	analyzed_target_id = &""
	ward_dice_bonus = 0
	blessed_minimum_damage = 0
	last_blood_riposte_round = -1
	passive_attack_dice_bonus = 0
	regeneration_rounds = 0
	boss_phase_triggered = false

	_initialize_equipment(source_equipment_loadout)
	state_changed.emit()


func set_analyzed_target(
	target_id: StringName
) -> void:
	analyzed_target_id = target_id
	state_changed.emit()


func has_analyzed_target(
	target_id: StringName
) -> bool:
	return target_id != &"" and analyzed_target_id == target_id


func consume_analyzed_target(
	target_id: StringName
) -> bool:
	if not has_analyzed_target(target_id):
		return false
	analyzed_target_id = &""
	state_changed.emit()
	return true


func apply_ward(
	dice_bonus: int
) -> void:
	ward_dice_bonus = maxi(dice_bonus, 0)
	state_changed.emit()


func consume_ward() -> int:
	var consumed: int = ward_dice_bonus
	ward_dice_bonus = 0
	if consumed > 0:
		state_changed.emit()
	return consumed


func apply_bless(
	minimum_damage: int
) -> void:
	blessed_minimum_damage = maxi(minimum_damage, 0)
	state_changed.emit()


func consume_bless() -> int:
	var consumed: int = blessed_minimum_damage
	blessed_minimum_damage = 0
	if consumed > 0:
		state_changed.emit()
	return consumed


func can_trigger_blood_riposte(
	round_number: int
) -> bool:
	var ability: AbilityDefinition = (
		get_ability(&"lysandra_blood_riposte")
		if definition != null
		else null
	)
	return (
		ability != null
		and ability.get_blood_riposte_effect() != null
		and last_blood_riposte_round != round_number
	)


func mark_blood_riposte_used(
	round_number: int
) -> void:
	last_blood_riposte_round = round_number
	state_changed.emit()


func is_grappled() -> bool:
	return not active_grapple_track_ids.is_empty()


func is_attached_grappler() -> bool:
	return grapple_cluster_position_id != &""


func add_grapple_track(
	track_id: StringName
) -> void:
	if track_id == &"" or active_grapple_track_ids.has(track_id):
		return
	active_grapple_track_ids.append(track_id)
	state_changed.emit()


func remove_grapple_track(
	track_id: StringName
) -> void:
	if not active_grapple_track_ids.has(track_id):
		return
	active_grapple_track_ids.erase(track_id)
	state_changed.emit()


func begin_grapple_cooldown(
	activation_count: int
) -> void:
	grapple_cooldown_activations = maxi(activation_count, 0)
	state_changed.emit()


func consume_grapple_cooldown_activation() -> bool:
	if grapple_cooldown_activations <= 0:
		return false
	grapple_cooldown_activations -= 1
	state_changed.emit()
	return true


func get_max_hp() -> int:
	if definition == null:
		return 0
	return definition.max_hp


func get_max_mp() -> int:
	if definition == null:
		return 0
	return definition.max_mp


func get_max_actions() -> int:
	return max_actions


func apply_damage(amount: int) -> int:
	if amount <= 0 or is_defeated:
		return 0

	var remaining_damage: int = amount
	if item_guard_points > 0:
		var guard_absorbed: int = mini(
			remaining_damage,
			item_guard_points
		)
		item_guard_points -= guard_absorbed
		remaining_damage -= guard_absorbed

	var applied_damage: int = mini(remaining_damage, current_hp)
	current_hp -= applied_damage

	if current_hp == 0:
		actions_before_defeat = current_actions
		current_actions = 0
		is_defeated = true
		ward_dice_bonus = 0
		blessed_minimum_damage = 0
		_remove_status_kind_on_defeat(
			StatusDefinition.Kind.REGENERATION
		)
		defeated.emit()

	state_changed.emit()
	return applied_damage


func _remove_status_kind_on_defeat(
	kind: StatusDefinition.Kind
) -> void:
	var remaining: Array[StatusInstance] = []
	for instance: StatusInstance in active_statuses:
		if (
			instance != null
			and instance.definition != null
			and instance.definition.kind == kind
		):
			continue
		remaining.append(instance)
	active_statuses = remaining


func add_item_guard(
	amount: int
) -> int:
	if amount <= 0 or is_defeated:
		return 0
	var before: int = item_guard_points
	item_guard_points = clampi(
		item_guard_points + amount,
		0,
		99
	)
	state_changed.emit()
	return item_guard_points - before


func heal(amount: int) -> int:
	if amount <= 0 or is_defeated:
		return 0

	var missing_hp: int = get_max_hp() - current_hp
	var restored_hp: int = mini(amount, missing_hp)
	current_hp += restored_hp

	if restored_hp > 0:
		state_changed.emit()

	return restored_hp


func spend_mp(amount: int) -> bool:
	if amount < 0 or is_defeated:
		return false
	if current_mp < amount:
		return false

	current_mp -= amount
	state_changed.emit()
	return true


func restore_mp(amount: int) -> int:
	if amount <= 0 or is_defeated:
		return 0

	var missing_mp: int = get_max_mp() - current_mp
	var restored_mp: int = mini(amount, missing_mp)
	current_mp += restored_mp

	if restored_mp > 0:
		state_changed.emit()

	return restored_mp


func spend_actions(amount: int) -> bool:
	if amount <= 0 or is_defeated:
		return false
	if current_actions < amount:
		return false

	current_actions -= amount
	state_changed.emit()
	return true


func restore_actions_to_maximum() -> void:
	if is_defeated:
		return

	var restored_actions: int = get_max_actions()
	if is_stunned():
		restored_actions = 0
	if current_actions == restored_actions:
		return
	current_actions = restored_actions
	state_changed.emit()


func set_current_actions(
	new_value: int
) -> void:
	if is_defeated:
		return

	var clamped_value: int = clampi(
		new_value,
		0,
		get_max_actions()
	)

	if current_actions == clamped_value:
		return

	current_actions = clamped_value
	state_changed.emit()


func set_max_actions(
	new_value: int
) -> void:
	var next_maximum: int = maxi(new_value, 0)
	var next_current: int = mini(current_actions, next_maximum)
	if max_actions == next_maximum and current_actions == next_current:
		return
	max_actions = next_maximum
	current_actions = next_current
	state_changed.emit()


func change_resolve(amount: int) -> int:
	var previous_value: int = current_resolve
	current_resolve = clampi(current_resolve + amount, 0, 100)

	if current_resolve != previous_value:
		state_changed.emit()

	return current_resolve - previous_value


func change_corruption(amount: int) -> int:
	var previous_value: int = current_corruption
	current_corruption = clampi(current_corruption + amount, 0, 100)

	if current_corruption != previous_value:
		state_changed.emit()

	return current_corruption - previous_value


func revive(restored_hp: int = 1) -> bool:
	if not is_defeated:
		return false

	current_hp = clampi(restored_hp, 1, get_max_hp())
	current_actions = clampi(
		actions_before_defeat,
		0,
		get_max_actions()
	)

	is_defeated = false
	if is_stunned():
		current_actions = 0
	revived.emit()
	state_changed.emit()
	return true


func reset_to_definition() -> void:
	if definition == null:
		push_error("Cannot reset BattlerState without a definition.")
		return

	initialize(definition, progression, equipment_loadout_state)


func _initialize_equipment(
	source_equipment_loadout: PersonalEquipmentLoadoutState = null
) -> void:
	weapon_state = null
	armor_state = null
	shield_state = null
	damage_allocation_policy = (
		EquipmentLoadout.DamageAllocationPolicy.ARMOR_FIRST
	)

	if definition == null:
		return

	var loadout: EquipmentLoadout = definition.default_loadout
	if loadout == null:
		return
	if (
		equipment_loadout_state != null
		and equipment_loadout_state.loadout_changed.is_connected(
			_refresh_equipment_adapters
		)
	):
		equipment_loadout_state.loadout_changed.disconnect(
			_refresh_equipment_adapters
		)
	equipment_loadout_state = source_equipment_loadout
	if equipment_loadout_state == null:
		equipment_loadout_state = PersonalEquipmentLoadoutState.new()
		var loadout_error: String = (
			equipment_loadout_state.initialize_from_authored_loadout(
				definition.battler_id,
				loadout
			)
		)
		assert(loadout_error.is_empty(), loadout_error)
	if not equipment_loadout_state.loadout_changed.is_connected(
		_refresh_equipment_adapters
	):
		equipment_loadout_state.loadout_changed.connect(
			_refresh_equipment_adapters
		)

	damage_allocation_policy = (
		loadout.default_damage_allocation_policy
	)
	_refresh_equipment_adapters()


func _refresh_equipment_adapters() -> void:
	weapon_state = null
	armor_state = null
	shield_state = null
	if equipment_loadout_state == null:
		return
	var main_hand_instance: EquipmentInstance = (
		equipment_loadout_state.get_equipped_instance(
			EquipmentDefinition.Slot.MAIN_HAND
		)
	)
	if (
		main_hand_instance != null
		and main_hand_instance.definition is WeaponDefinition
	):
		var weapon_definition := (
			main_hand_instance.definition as WeaponDefinition
		)
		var family_rank: int = (
			definition.default_loadout.main_hand_family_rank
			if definition != null and definition.default_loadout != null
			else weapon_definition.default_family_rank
		)
		if progression != null and weapon_definition.family != null:
			family_rank = progression.get_weapon_family_rank(
				weapon_definition.family.family_id,
				family_rank
			)
		weapon_state = WeaponState.new(
			weapon_definition,
			family_rank,
			main_hand_instance
		)
	var armor_instance: EquipmentInstance = (
		equipment_loadout_state.get_equipped_instance(
			EquipmentDefinition.Slot.ARMOR
		)
	)
	if armor_instance != null and armor_instance.definition is ArmorDefinition:
		armor_state = ArmorState.new(
			armor_instance.definition as ArmorDefinition,
			armor_instance
		)
	var off_hand_instance: EquipmentInstance = (
		equipment_loadout_state.get_equipped_instance(
			EquipmentDefinition.Slot.OFF_HAND
		)
	)
	if off_hand_instance != null and off_hand_instance.definition is ShieldDefinition:
		shield_state = ShieldState.new(
			off_hand_instance.definition as ShieldDefinition,
			off_hand_instance
		)


func get_main_hand_weapon() -> WeaponDefinition:
	if weapon_state == null:
		return null

	return weapon_state.definition


func get_usable_main_hand_weapon() -> WeaponDefinition:
	if weapon_state == null or not weapon_state.can_use():
		return null

	return weapon_state.definition


func get_main_hand_weapon_rank() -> int:
	if weapon_state == null:
		return 0

	return weapon_state.family_rank


func get_available_abilities() -> Array[AbilityDefinition]:
	var available: Array[AbilityDefinition] = []
	if definition == null:
		return available
	for ability: AbilityDefinition in definition.abilities:
		if ability != null:
			available.append(ability)
	if progression == null:
		return available
	for ability: AbilityDefinition in definition.unlockable_abilities:
		if (
			ability != null
			and progression.has_unlocked_ability(ability.ability_id)
		):
			available.append(ability)
	return available


func get_ability(ability_id: StringName) -> AbilityDefinition:
	if definition == null:
		return null
	var innate: AbilityDefinition = definition.get_ability(ability_id)
	if innate != null:
		return innate
	if (
		progression != null
		and progression.has_unlocked_ability(ability_id)
	):
		return definition.get_unlockable_ability(ability_id)
	return null


func get_progression_snapshot() -> Dictionary:
	return progression.to_snapshot() if progression != null else {}


func has_usable_weapon() -> bool:
	return weapon_state != null and weapon_state.can_use()


func can_parry_with_weapon() -> bool:
	return weapon_state != null and weapon_state.can_parry()


func apply_weapon_durability_event() -> bool:
	if weapon_state == null:
		return false

	var applied: bool = weapon_state.apply_durability_event()
	if applied:
		state_changed.emit()

	return applied


func repair_weapon(
	amount: int
) -> int:
	if weapon_state == null:
		return 0
	var repaired: int = weapon_state.repair(amount)
	if repaired > 0:
		state_changed.emit()
	return repaired


func repair_armor(
	amount: int
) -> int:
	if armor_state == null:
		return 0
	var repaired: int = armor_state.repair(amount)
	if repaired > 0:
		state_changed.emit()
	return repaired


func repair_shield(
	amount: int
) -> int:
	if shield_state == null:
		return 0
	var repaired: int = shield_state.repair(amount)
	if repaired > 0:
		state_changed.emit()
	return repaired


func damage_weapon(
	amount: int
) -> int:
	if weapon_state == null or amount <= 0:
		return 0
	var before: int = weapon_state.durability_damage
	for _event_index: int in range(amount):
		if not weapon_state.apply_durability_event():
			break
	var applied: int = weapon_state.durability_damage - before
	if applied > 0:
		state_changed.emit()
	return applied


func damage_armor(
	amount: int
) -> int:
	if armor_state == null:
		return 0
	var applied: int = armor_state.damage_condition(amount)
	if applied > 0:
		state_changed.emit()
	return applied


func damage_shield(
	amount: int
) -> int:
	if shield_state == null:
		return 0
	var applied: int = shield_state.damage_condition(amount)
	if applied > 0:
		state_changed.emit()
	return applied


func has_usable_armor() -> bool:
	return armor_state != null and armor_state.can_defend()


func has_usable_shield() -> bool:
	return shield_state != null and shield_state.can_defend()


func has_damage_absorbing_shield() -> bool:
	return shield_state != null and shield_state.can_absorb_damage()


func get_armor_dodge_modifier() -> int:
	if armor_state == null or armor_state.definition == null:
		return 0

	# Broken armor keeps penalties. Positive bonuses are lost.
	var modifier: int = armor_state.definition.get_dodge_dice_modifier()
	if armor_state.is_broken and modifier > 0:
		return 0

	return modifier


func get_shield_dodge_modifier() -> int:
	if shield_state == null or shield_state.definition == null:
		return 0

	# Shield penalties remain while a broken shield is equipped.
	return shield_state.definition.get_dodge_dice_modifier()


func get_shield_parry_modifier() -> int:
	if shield_state == null or shield_state.definition == null:
		return 0
	if shield_state.is_broken:
		return 0

	return shield_state.definition.get_parry_dice_modifier()


func absorb_damage_with_armor_safely(damage: int) -> int:
	if armor_state == null:
		return 0

	var absorbed: int = armor_state.absorb_safely(damage)
	if absorbed > 0:
		state_changed.emit()

	return absorbed


func absorb_damage_with_shield_safely(damage: int) -> int:
	if shield_state == null:
		return 0

	var absorbed: int = shield_state.absorb_safely(damage)
	if absorbed > 0:
		state_changed.emit()

	return absorbed


func destroy_armor_to_absorb_one() -> int:
	if armor_state == null:
		return 0

	var absorbed: int = armor_state.break_and_absorb_one()
	if absorbed > 0:
		state_changed.emit()

	return absorbed


func destroy_shield_to_absorb_one() -> int:
	if shield_state == null:
		return 0

	var absorbed: int = shield_state.break_and_absorb_one()
	if absorbed > 0:
		state_changed.emit()

	return absorbed


func set_damage_allocation_policy(
	new_policy: EquipmentLoadout.DamageAllocationPolicy
) -> void:
	if damage_allocation_policy == new_policy:
		return

	damage_allocation_policy = new_policy
	state_changed.emit()


func get_damage_allocation_policy_name() -> String:
	match damage_allocation_policy:
		EquipmentLoadout.DamageAllocationPolicy.ARMOR_FIRST:
			return "Armor First"
		EquipmentLoadout.DamageAllocationPolicy.SHIELD_FIRST:
			return "Shield First"

	return "Unknown"


func notify_statuses_changed() -> void:
	state_changed.emit()


func has_status_kind(
	kind: StatusDefinition.Kind
) -> bool:
	for instance: StatusInstance in active_statuses:
		if (
			instance != null
			and instance.definition != null
			and instance.definition.kind == kind
		):
			return true

	return false


func is_stunned() -> bool:
	return has_status_kind(StatusDefinition.Kind.STUNNED)


func is_slowed() -> bool:
	return has_status_kind(StatusDefinition.Kind.SLOW)


func get_move_step_limit() -> int:
	return 1 if is_slowed() else 2


func get_status_summary() -> String:
	var labels: Array[String] = []
	for instance: StatusInstance in active_statuses:
		if instance != null and instance.definition != null:
			labels.append(instance.get_display_text())

	labels.sort()
	return (
		"None"
		if labels.is_empty()
		else ", ".join(PackedStringArray(labels))
	)
