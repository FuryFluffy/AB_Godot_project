class_name StatusController
extends RefCounted


var battler_states: Dictionary = {}
var stable_battler_order: Array[StringName] = []


func initialize(
	new_battler_states: Dictionary,
	new_stable_battler_order: Array[StringName]
) -> void:
	battler_states = new_battler_states
	stable_battler_order = new_stable_battler_order.duplicate()


func apply_status(
	target: BattlerState,
	status_definition: StatusDefinition,
	source_battler_id: StringName,
	damage_override: int = -1,
	tick_override: int = -1,
	magical_override: int = -1,
	dispellable_override: int = -1
) -> StatusApplicationResult:
	var result: StatusApplicationResult = StatusApplicationResult.new()
	if target == null or target.definition == null:
		return result.fail("Status target is invalid.")
	if target.is_defeated:
		return result.fail(
			"%s is defeated and cannot receive an ordinary status."
			% target.definition.display_name
		)
	if status_definition == null:
		return result.fail("StatusDefinition is missing.")
	if status_definition.status_id == &"":
		return result.fail("StatusDefinition has no status_id.")
	if source_battler_id == &"":
		return result.fail("Status source is missing.")

	for instance: StatusInstance in target.active_statuses:
		if instance == null:
			continue
		if not instance.matches(
			status_definition,
			source_battler_id
		):
			continue

		instance.refresh(
			damage_override,
			tick_override,
			magical_override,
			dispellable_override
		)
		result.succeeded = true
		result.replaced_existing = true
		result.instance = instance
		_apply_immediate_control(target, instance)
		target.notify_statuses_changed()
		return result

	var new_instance: StatusInstance = StatusInstance.new(
		status_definition,
		source_battler_id,
		damage_override,
		tick_override,
		magical_override,
		dispellable_override
	)
	target.active_statuses.append(new_instance)
	result.succeeded = true
	result.instance = new_instance
	_apply_immediate_control(target, new_instance)
	target.notify_statuses_changed()
	return result


func process_side_phase(
	side: BattleState.CombatSide
) -> StatusPhaseReport:
	var report: StatusPhaseReport = StatusPhaseReport.new()
	report.side = side

	for battler_id: StringName in stable_battler_order:
		var state: BattlerState = _get_battler_state(battler_id)
		if (
			state == null
			or state.definition == null
			or state.is_defeated
			or _side_for_state(state) != side
		):
			continue

		_process_periodic_healing(state, report)
		_process_periodic_damage(state, report)
		if state.is_defeated:
			_expire_finished_statuses(state, report)
			continue

		_process_control(state, report)
		_expire_finished_statuses(state, report)

	return report


func remove_all_statuses(
	target: BattlerState
) -> void:
	if target == null:
		return

	target.active_statuses.clear()
	_recalculate_maximum_actions(target)
	target.notify_statuses_changed()


func remove_first_status(
	target: BattlerState
) -> int:
	if target == null or target.active_statuses.is_empty():
		return 0
	target.active_statuses.remove_at(0)
	_recalculate_maximum_actions(target)
	target.notify_statuses_changed()
	return 1


func remove_status_kind(
	target: BattlerState,
	status_kind: StatusDefinition.Kind
) -> int:
	if target == null:
		return 0

	var remaining: Array[StatusInstance] = []
	var removed_count: int = 0
	for instance: StatusInstance in target.active_statuses:
		if (
			instance != null
			and instance.definition != null
			and instance.definition.kind == status_kind
		):
			removed_count += 1
			continue
		remaining.append(instance)

	if removed_count > 0:
		target.active_statuses = remaining
		_recalculate_maximum_actions(target)
		target.notify_statuses_changed()
	return removed_count


func remove_one_status_kind(
	target: BattlerState,
	status_kind: StatusDefinition.Kind
) -> int:
	if target == null:
		return 0
	var remaining: Array[StatusInstance] = []
	var removed: bool = false
	for instance: StatusInstance in target.active_statuses:
		if (
			not removed
			and instance != null
			and instance.definition != null
			and instance.definition.kind == status_kind
		):
			removed = true
			continue
		remaining.append(instance)
	if removed:
		target.active_statuses = remaining
		_recalculate_maximum_actions(target)
		target.notify_statuses_changed()
		return 1
	return 0


func has_removable_magic_effect(
	target: BattlerState
) -> bool:
	if target == null:
		return false
	for instance: StatusInstance in target.active_statuses:
		if (
			instance != null
			and instance.definition != null
			and instance.is_magical
			and instance.is_dispellable
		):
			return true
	return false


func remove_one_removable_magic_effect(
	target: BattlerState
) -> String:
	if target == null:
		return ""
	var candidate_index: int = -1
	var candidate_key: String = ""
	for index: int in range(target.active_statuses.size()):
		var instance: StatusInstance = target.active_statuses[index]
		if (
			instance == null
			or instance.definition == null
			or not instance.is_magical
			or not instance.is_dispellable
		):
			continue
		var key: String = "%s|%s" % [
			String(instance.definition.status_id),
			String(instance.source_battler_id),
		]
		if candidate_index < 0 or key < candidate_key:
			candidate_index = index
			candidate_key = key
	if candidate_index < 0:
		return ""
	var removed: StatusInstance = target.active_statuses[candidate_index]
	target.active_statuses.remove_at(candidate_index)
	_recalculate_maximum_actions(target)
	target.notify_statuses_changed()
	return removed.definition.display_name


func _process_periodic_healing(
	target: BattlerState,
	report: StatusPhaseReport
) -> void:
	var ordered_statuses: Array[StatusInstance] = _get_ordered_statuses(target)
	for instance: StatusInstance in ordered_statuses:
		if (
			instance == null
			or instance.definition == null
			or instance.healing_per_tick <= 0
		):
			continue
		var hp_before: int = target.current_hp
		var restored: int = target.heal(instance.healing_per_tick)
		instance.resolved_ticks += 1
		report.append(
			"%s restores %d HP from %s (HP %d -> %d)." % [
				target.definition.display_name,
				restored,
				instance.definition.display_name,
				hp_before,
				target.current_hp,
			]
		)


func _process_periodic_damage(
	target: BattlerState,
	report: StatusPhaseReport
) -> void:
	var ordered_statuses: Array[StatusInstance] = (
		_get_ordered_statuses(target)
	)

	for instance: StatusInstance in ordered_statuses:
		if (
			instance == null
			or instance.definition == null
			or instance.damage_per_tick <= 0
		):
			continue
		if target.is_defeated:
			break

		var hp_before: int = target.current_hp
		var damage: int = target.apply_damage(
			instance.damage_per_tick
		)
		instance.resolved_ticks += 1
		report.append(
			"%s suffers %d %s damage (HP %d -> %d)." % [
				target.definition.display_name,
				damage,
				instance.definition.display_name,
				hp_before,
				target.current_hp,
			]
		)

		if target.is_defeated:
			report.defeated_battler_ids.append(
				target.definition.battler_id
			)
			report.append(
				"%s is defeated by %s."
				% [
					target.definition.display_name,
					instance.definition.display_name,
				]
			)


func _process_control(
	target: BattlerState,
	report: StatusPhaseReport
) -> void:
	var ordered_statuses: Array[StatusInstance] = (
		_get_ordered_statuses(target)
	)

	for instance: StatusInstance in ordered_statuses:
		if (
			instance == null
			or instance.definition == null
			or instance.damage_per_tick > 0
			or instance.healing_per_tick > 0
		):
			continue

		if instance.definition.prevents_actions:
			target.set_current_actions(0)
			report.append(
				"%s is %s and loses all available Actions."
				% [
					target.definition.display_name,
					instance.definition.display_name,
				]
			)

		instance.resolved_ticks += 1

	_recalculate_maximum_actions(target)


func _expire_finished_statuses(
	target: BattlerState,
	report: StatusPhaseReport
) -> void:
	var remaining: Array[StatusInstance] = []

	for instance: StatusInstance in target.active_statuses:
		if instance == null or instance.definition == null:
			continue
		if instance.is_expired():
			report.expired_status_count += 1
			report.append(
				"%s expires from %s."
				% [
					instance.definition.display_name,
					target.definition.display_name,
				]
			)
			continue
		remaining.append(instance)

	target.active_statuses = remaining
	_recalculate_maximum_actions(target)
	target.notify_statuses_changed()


func _apply_immediate_control(
	target: BattlerState,
	instance: StatusInstance
) -> void:
	if (
		instance != null
		and instance.definition != null
		and instance.definition.prevents_actions
	):
		target.set_current_actions(0)
	elif (
		instance != null
		and instance.definition != null
		and instance.definition.immediate_action_loss > 0
	):
		target.spend_actions(
			mini(
				target.current_actions,
				instance.definition.immediate_action_loss
			)
		)

	_recalculate_maximum_actions(target)


func _recalculate_maximum_actions(
	target: BattlerState
) -> void:
	if target == null or target.definition == null:
		return

	var total_penalty: int = 0
	for instance: StatusInstance in target.active_statuses:
		if instance == null or instance.definition == null:
			continue
		total_penalty += instance.definition.maximum_action_penalty

	target.set_max_actions(
		maxi(target.definition.base_actions - total_penalty, 0)
	)


func _get_ordered_statuses(
	target: BattlerState
) -> Array[StatusInstance]:
	var ordered: Array[StatusInstance] = (
		target.active_statuses.duplicate()
	)
	ordered.sort_custom(_is_status_before)
	return ordered


func _is_status_before(
	first: StatusInstance,
	second: StatusInstance
) -> bool:
	return _status_sort_key(first) < _status_sort_key(second)


func _status_sort_key(
	instance: StatusInstance
) -> String:
	if instance == null or instance.definition == null:
		return ""

	return "%s|%s" % [
		String(instance.definition.status_id),
		String(instance.source_battler_id),
	]


func _side_for_state(
	state: BattlerState
) -> BattleState.CombatSide:
	if state == null or state.definition == null:
		return BattleState.CombatSide.NONE

	match state.definition.faction:
		BattlerDefinition.Faction.HEROINE:
			return BattleState.CombatSide.HEROES
		BattlerDefinition.Faction.ENEMY:
			return BattleState.CombatSide.ENEMIES

	return BattleState.CombatSide.NONE


func _get_battler_state(
	battler_id: StringName
) -> BattlerState:
	return battler_states.get(battler_id) as BattlerState
