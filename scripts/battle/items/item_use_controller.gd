class_name ItemUseController
extends RefCounted


var battler_states: Dictionary = {}
var inventory: SixSlotInventoryState
var runtime: BattleRuntimeState
var battle_flow_controller: BattleFlowController
var battlefield_state: BattlefieldState
var targeting_controller: BattleTargetingController
var attack_resolver: AttackResolver
var status_controller: StatusController
var grapple_controller: GrappleController
var lifecycle_controller: BattleLifecycleController
var item_attack_seed: int = 1


func initialize(
	new_battler_states: Dictionary,
	new_inventory: SixSlotInventoryState,
	new_runtime: BattleRuntimeState,
	new_battle_flow_controller: BattleFlowController,
	new_battlefield_state: BattlefieldState,
	new_targeting_controller: BattleTargetingController,
	new_attack_resolver: AttackResolver,
	new_status_controller: StatusController,
	new_grapple_controller: GrappleController,
	new_lifecycle_controller: BattleLifecycleController,
	new_item_attack_seed: int
) -> void:
	battler_states = new_battler_states
	inventory = new_inventory
	runtime = new_runtime
	battle_flow_controller = new_battle_flow_controller
	battlefield_state = new_battlefield_state
	targeting_controller = new_targeting_controller
	attack_resolver = new_attack_resolver
	status_controller = new_status_controller
	grapple_controller = new_grapple_controller
	lifecycle_controller = new_lifecycle_controller
	item_attack_seed = new_item_attack_seed


func get_battler_state(
	battler_id: StringName
) -> BattlerState:
	return battler_states.get(battler_id) as BattlerState


func get_item(
	slot_index: int
) -> ItemDefinition:
	if inventory == null:
		return null
	var slot: InventorySlotState = inventory.get_slot(slot_index)
	if slot == null or slot.is_empty():
		return null
	return slot.item


func get_availability_reason(
	actor_id: StringName,
	slot_index: int
) -> String:
	var actor: BattlerState = get_battler_state(actor_id)
	var item: ItemDefinition = get_item(slot_index)
	var actor_error: String = _validate_actor(actor, item)
	if not actor_error.is_empty():
		return actor_error
	if get_legal_target_ids(actor_id, slot_index).is_empty():
		return "No legal target can currently benefit."
	return ""


func get_legal_target_ids(
	actor_id: StringName,
	slot_index: int
) -> Array[StringName]:
	var legal_ids: Array[StringName] = []
	var actor: BattlerState = get_battler_state(actor_id)
	var item: ItemDefinition = get_item(slot_index)
	if not _validate_actor(actor, item).is_empty():
		return legal_ids

	var sorted_ids: Array[StringName] = []
	for key: Variant in battler_states.keys():
		sorted_ids.append(StringName(key))
	sorted_ids.sort()

	for target_id: StringName in sorted_ids:
		var target: BattlerState = get_battler_state(target_id)
		var target_error: String = _validate_target(
			actor,
			target,
			item
		)
		if not target_error.is_empty():
			continue
		if (
			not item.performs_attack
			and not _has_applicable_effect(
				actor,
				target,
				item
			)
		):
			continue
		legal_ids.append(target_id)

	return legal_ids


func use_item(
	actor_id: StringName,
	target_id: StringName,
	slot_index: int
) -> ItemUseResult:
	var result: ItemUseResult = _create_result(
		actor_id,
		target_id,
		slot_index
	)
	var actor: BattlerState = get_battler_state(actor_id)
	var target: BattlerState = get_battler_state(target_id)
	var validation_error: String = _validate_complete_use(
		actor,
		target,
		result.item,
		slot_index
	)
	if not validation_error.is_empty():
		return result.fail(validation_error)
	if result.item.performs_attack:
		result.requires_attack_resolution = true
		return result.fail(
			"%s must use the Attack reaction pipeline."
			% result.item.display_name
		)
	if not _has_applicable_effect(actor, target, result.item):
		return result.fail(
			"%s would have no effect on %s."
			% [
				result.item.display_name,
				target.definition.display_name,
			]
		)

	if (
		result.item.action_cost > 0
		and not actor.spend_actions(result.item.action_cost)
	):
		return result.fail(
			"%s could not spend %d Action."
			% [
				actor.definition.display_name,
				result.item.action_cost,
			]
		)
	result.actions_spent = result.item.action_cost

	var applied_count: int = 0
	for effect: ItemEffectDefinition in result.item.effects:
		var effect_log: String = _apply_effect(
			actor,
			target,
			effect
		)
		if not effect_log.is_empty():
			result.append_log(effect_log)
			applied_count += 1

	if applied_count <= 0:
		if result.actions_spent > 0:
			actor.set_current_actions(
				actor.current_actions + result.actions_spent
			)
		result.actions_spent = 0
		return result.fail(
			"%s produced no applicable effect."
			% result.item.display_name
		)

	var consume_error: String = _consume_if_needed(
		result.item,
		slot_index,
		result
	)
	if not consume_error.is_empty():
		return result.fail(consume_error)

	result.succeeded = true
	result.append_log(
		"%s used %s on %s (%d Action%s)."
		% [
			actor.definition.display_name,
			result.item.display_name,
			target.definition.display_name,
			result.actions_spent,
			"" if result.actions_spent == 1 else "s",
		]
	)
	return result


func prepare_item_attack(
	actor_id: StringName,
	target_id: StringName,
	slot_index: int
) -> ReactionContext:
	var actor: BattlerState = get_battler_state(actor_id)
	var target: BattlerState = get_battler_state(target_id)
	var item: ItemDefinition = get_item(slot_index)
	var validation_error: String = _validate_complete_use(
		actor,
		target,
		item,
		slot_index
	)
	if not validation_error.is_empty():
		return ReactionContext.new().fail(validation_error)
	if not item.performs_attack:
		return ReactionContext.new().fail(
			"%s is not an Attack item." % item.display_name
		)

	var attack_profile: WeaponDefinition = item.create_attack_profile()
	var targeting: AttackTargetingResult = (
		targeting_controller.evaluate_attack(
			actor_id,
			target_id,
			attack_profile,
			item.is_magic_attack
		)
	)
	if not targeting.is_legal:
		return ReactionContext.new().fail(
			targeting.error_message
		)

	var request: ActionRequest = ActionRequest.new(
		actor_id,
		target_id,
		attack_profile,
		item_attack_seed,
		false,
		item.is_magic_attack,
		0,
		ActionRequest.Source.ITEM,
		ActionRequest.ReactionMode.FULL
	)
	item_attack_seed += 1
	request.item = item
	request.action_cost = item.action_cost
	request.spatial_range_label = targeting.spatial_range_label
	request.attack_dice_modifier = targeting.attack_dice_modifier
	request.suppress_skill_modification = (
		targeting.suppress_skill_modification
	)

	var context: ReactionContext = attack_resolver.prepare_attack(
		request,
		actor,
		target
	)
	if not context.is_valid:
		return context

	runtime.reserve_pending_item_attack(
		actor_id,
		slot_index,
		item.item_id
	)
	runtime.store_pending_reaction(context, target_id)
	return context


func complete_pending_item_attack(
	action_result: ActionResult
) -> ItemUseResult:
	var actor_id: StringName = runtime.pending_item_attack_user_id
	var slot_index: int = runtime.pending_item_attack_slot_index
	var target_id: StringName = (
		action_result.request.target_id
		if action_result != null and action_result.request != null
		else &""
	)
	var result: ItemUseResult = _create_result(
		actor_id,
		target_id,
		slot_index
	)
	if not runtime.has_pending_item_attack():
		return result.fail("No Item Attack is pending.")
	if action_result == null or not action_result.succeeded:
		runtime.clear_pending_item_attack()
		return result.fail("The Item Attack did not resolve.")
	if (
		result.item == null
		or result.item.item_id
		!= runtime.pending_item_attack_item_id
	):
		runtime.clear_pending_item_attack()
		return result.fail(
			"The reserved Item Attack stack changed before resolution."
		)

	var actor: BattlerState = get_battler_state(actor_id)
	var target: BattlerState = get_battler_state(target_id)
	result.actions_spent = result.item.action_cost
	if (
		target != null
		and (
			not result.item.attack_effects_require_hp_damage
			or action_result.damage_dealt > 0
		)
	):
		for effect: ItemEffectDefinition in result.item.effects:
			var effect_log: String = _apply_effect(
				actor,
				target,
				effect
			)
			result.append_log(effect_log)

	var consume_error: String = _consume_if_needed(
		result.item,
		slot_index,
		result
	)
	runtime.clear_pending_item_attack()
	if not consume_error.is_empty():
		return result.fail(consume_error)

	result.succeeded = true
	result.append_log(
		"%s was consumed after its Attack resolved."
		% result.item.display_name
	)
	return result


func _create_result(
	actor_id: StringName,
	target_id: StringName,
	slot_index: int
) -> ItemUseResult:
	var result: ItemUseResult = ItemUseResult.new()
	result.actor_id = actor_id
	result.target_id = target_id
	result.slot_index = slot_index
	result.item = get_item(slot_index)
	return result


func _validate_complete_use(
	actor: BattlerState,
	target: BattlerState,
	item: ItemDefinition,
	slot_index: int
) -> String:
	var actor_error: String = _validate_actor(actor, item)
	if not actor_error.is_empty():
		return actor_error
	var slot: InventorySlotState = inventory.get_slot(slot_index)
	if slot == null or slot.is_empty() or slot.item != item:
		return "The selected item slot changed."
	return _validate_target(actor, target, item)


func _validate_actor(
	actor: BattlerState,
	item: ItemDefinition
) -> String:
	if inventory == null:
		return "The six-slot inventory is missing."
	if runtime == null:
		return "Battle runtime state is missing."
	if actor == null or actor.definition == null:
		return "Select a heroine before using an item."
	if actor.definition.faction != BattlerDefinition.Faction.HEROINE:
		return "Only a heroine may use the party Item Bar."
	if item == null:
		return "The selected item slot is empty."
	if item.item_type == ItemDefinition.ItemType.PASSIVE:
		return "%s is passive and cannot be activated." % (
			item.display_name
		)
	if item.item_type == ItemDefinition.ItemType.KEY:
		return "%s is an exploration Key Item." % (
			item.display_name
		)
	if not item.combat_usable:
		return "%s cannot be used during battle." % (
			item.display_name
		)
	if actor.is_defeated:
		return "A zero-HP heroine cannot use items herself."
	if battle_flow_controller == null:
		return "BattleFlowController is missing."
	var phase_error: String = (
		battle_flow_controller.validate_active_actor(actor)
	)
	if not phase_error.is_empty():
		return phase_error
	if actor.current_actions < item.action_cost:
		return "%s needs %d Action%s." % [
			item.display_name,
			item.action_cost,
			"" if item.action_cost == 1 else "s",
		]
	return ""


func _validate_target(
	actor: BattlerState,
	target: BattlerState,
	item: ItemDefinition
) -> String:
	if target == null or target.definition == null:
		return "The item target is invalid."
	if actor == null or actor.definition == null or item == null:
		return "The item-use context is incomplete."

	var actor_id: StringName = actor.definition.battler_id
	var target_id: StringName = target.definition.battler_id
	var same_faction: bool = (
		actor.definition.faction == target.definition.faction
	)
	var adjacent: bool = battlefield_state.are_adjacent(
		actor_id,
		target_id
	)

	match item.target_rule:
		ItemDefinition.TargetRule.SELF:
			if target != actor:
				return "%s targets only its user." % item.display_name

		ItemDefinition.TargetRule.SELF_OR_ADJACENT_HEROINE:
			if not same_faction:
				return "%s requires a heroine target." % item.display_name
			if target != actor and not adjacent:
				return "%s requires an Adjacent heroine." % (
					item.display_name
				)

		ItemDefinition.TargetRule.ADJACENT_HEROINE:
			if not same_faction or target == actor or not adjacent:
				return "%s requires another Adjacent heroine." % (
					item.display_name
				)

		ItemDefinition.TargetRule.ANY_HEROINE:
			if not same_faction:
				return "%s requires a heroine target." % item.display_name

		ItemDefinition.TargetRule.ADJACENT_ENEMY:
			if same_faction or not adjacent:
				return "%s requires an Adjacent enemy." % item.display_name

		ItemDefinition.TargetRule.REACHABLE_ENEMY:
			if same_faction:
				return "%s requires an enemy target." % item.display_name
			var range_error: String = _validate_reachable_range(
				actor_id,
				target_id,
				item
			)
			if not range_error.is_empty():
				return range_error

		ItemDefinition.TargetRule.ATTACHED_GRAPPLER:
			if (
				same_faction
				or not _is_target_attached_to_actor(
					actor_id,
					target_id
				)
			):
				return (
					"%s requires a grappler attached to its user."
					% item.display_name
				)

	if target.is_defeated and not _item_can_revive(item):
		return "%s is already defeated." % target.definition.display_name
	if item.performs_attack and target.is_defeated:
		return "%s is already defeated." % target.definition.display_name
	return ""


func _validate_reachable_range(
	actor_id: StringName,
	target_id: StringName,
	item: ItemDefinition
) -> String:
	var actor_anchor: AnchorDefinition = (
		battlefield_state.get_battler_anchor(actor_id)
	)
	var target_anchor: AnchorDefinition = (
		battlefield_state.get_battler_anchor(target_id)
	)
	if actor_anchor == null or target_anchor == null:
		return "Item range cannot be resolved."

	var distance: int = battlefield_state.get_zone_distance(
		actor_anchor.zone_id,
		target_anchor.zone_id
	)
	if distance < 0 or distance > item.maximum_zone_distance:
		return "%s is outside %s's range." % [
			get_battler_state(target_id).definition.display_name,
			item.display_name,
		]
	if (
		item.requires_line_of_sight
		and not battlefield_state.has_line_of_sight(
			actor_id,
			target_id
		)
	):
		return "Line of sight is blocked."
	return ""


func _has_applicable_effect(
	actor: BattlerState,
	target: BattlerState,
	item: ItemDefinition
) -> bool:
	for effect: ItemEffectDefinition in item.effects:
		if _is_effect_applicable(actor, target, effect):
			return true
	return false


func _is_effect_applicable(
	actor: BattlerState,
	target: BattlerState,
	effect: ItemEffectDefinition
) -> bool:
	if effect == null:
		return false
	var recipient: BattlerState = (
		actor
		if effect.recipient == ItemEffectDefinition.Recipient.ACTOR
		else target
	)
	if recipient == null:
		return false

	match effect.kind:
		ItemEffectDefinition.Kind.HEAL_HP:
			return (
				not recipient.is_defeated
				and recipient.current_hp < recipient.get_max_hp()
			)
		ItemEffectDefinition.Kind.RESTORE_MP:
			return (
				not recipient.is_defeated
				and recipient.current_mp < recipient.get_max_mp()
			)
		ItemEffectDefinition.Kind.RESTORE_ACTIONS:
			return (
				not recipient.is_defeated
				and recipient.current_actions
				< recipient.get_max_actions()
			)
		ItemEffectDefinition.Kind.CHANGE_RESOLVE:
			return (
				(effect.amount > 0 and recipient.current_resolve < 100)
				or (effect.amount < 0 and recipient.current_resolve > 0)
			)
		ItemEffectDefinition.Kind.CHANGE_CORRUPTION:
			return (
				(
					effect.amount > 0
					and recipient.current_corruption < 100
				)
				or (
					effect.amount < 0
					and recipient.current_corruption > 0
				)
			)
		ItemEffectDefinition.Kind.REMOVE_STATUS:
			return recipient.has_status_kind(effect.status_kind)
		ItemEffectDefinition.Kind.REVIVE:
			return recipient.is_defeated
		ItemEffectDefinition.Kind.REPAIR_WEAPON:
			return (
				recipient.weapon_state != null
				and (
					recipient.weapon_state.is_broken
					or recipient.weapon_state.durability_damage > 0
				)
			)
		ItemEffectDefinition.Kind.REPAIR_ARMOR:
			return (
				recipient.armor_state != null
				and (
					recipient.armor_state.is_broken
					or recipient.armor_state.absorbed_damage > 0
				)
			)
		ItemEffectDefinition.Kind.REPAIR_SHIELD:
			return (
				recipient.shield_state != null
				and (
					recipient.shield_state.is_broken
					or recipient.shield_state.absorbed_damage > 0
				)
			)
		ItemEffectDefinition.Kind.ADD_GUARD:
			return not recipient.is_defeated
		ItemEffectDefinition.Kind.DAMAGE_WEAPON:
			return (
				recipient.weapon_state != null
				and not recipient.weapon_state.is_broken
			)
		ItemEffectDefinition.Kind.DAMAGE_ARMOR:
			return (
				recipient.armor_state != null
				and not recipient.armor_state.is_broken
			)
		ItemEffectDefinition.Kind.DAMAGE_SHIELD:
			return (
				recipient.shield_state != null
				and not recipient.shield_state.is_broken
			)
		ItemEffectDefinition.Kind.GRAPPLE_REDUCE_STAGE:
			return _is_target_attached_to_actor(
				actor.definition.battler_id,
				target.definition.battler_id
			)
		ItemEffectDefinition.Kind.GRAPPLE_DETACH:
			return _is_target_attached_to_actor(
				actor.definition.battler_id,
				target.definition.battler_id
			)
	return false


func _apply_effect(
	actor: BattlerState,
	target: BattlerState,
	effect: ItemEffectDefinition
) -> String:
	if not _is_effect_applicable(actor, target, effect):
		return ""
	var recipient: BattlerState = (
		actor
		if effect.recipient == ItemEffectDefinition.Recipient.ACTOR
		else target
	)
	var recipient_name: String = recipient.definition.display_name

	match effect.kind:
		ItemEffectDefinition.Kind.HEAL_HP:
			var healed: int = recipient.heal(effect.amount)
			return "%s restored %d HP." % [recipient_name, healed]

		ItemEffectDefinition.Kind.RESTORE_MP:
			var restored_mp: int = recipient.restore_mp(effect.amount)
			return "%s restored %d MP." % [
				recipient_name,
				restored_mp,
			]

		ItemEffectDefinition.Kind.RESTORE_ACTIONS:
			var before_actions: int = recipient.current_actions
			recipient.set_current_actions(
				recipient.current_actions + effect.amount
			)
			return "%s restored %d Action%s." % [
				recipient_name,
				recipient.current_actions - before_actions,
				(
					""
					if recipient.current_actions - before_actions == 1
					else "s"
				),
			]

		ItemEffectDefinition.Kind.CHANGE_RESOLVE:
			var resolve_change: int = recipient.change_resolve(
				effect.amount
			)
			return "%s Resolve changed by %+d." % [
				recipient_name,
				resolve_change,
			]

		ItemEffectDefinition.Kind.CHANGE_CORRUPTION:
			var corruption_change: int = recipient.change_corruption(
				effect.amount
			)
			return "%s Corruption changed by %+d." % [
				recipient_name,
				corruption_change,
			]

		ItemEffectDefinition.Kind.REMOVE_STATUS:
			var removed: int = status_controller.remove_status_kind(
				recipient,
				effect.status_kind
			)
			return "%s removed %d %s status stack%s." % [
				recipient_name,
				removed,
				_get_status_kind_label(effect.status_kind),
				"" if removed == 1 else "s",
			]

		ItemEffectDefinition.Kind.REVIVE:
			var revive_error: String = (
				lifecycle_controller.revive_battler(
					recipient.definition.battler_id,
					maxi(effect.amount, 1)
				)
			)
			return (
				"%s was Revived at %d HP."
				% [recipient_name, recipient.current_hp]
				if revive_error.is_empty()
				else ""
			)

		ItemEffectDefinition.Kind.REPAIR_WEAPON:
			var weapon_repair: int = recipient.repair_weapon(
				effect.amount
			)
			return "%s repaired %d weapon condition." % [
				recipient_name,
				weapon_repair,
			]

		ItemEffectDefinition.Kind.REPAIR_ARMOR:
			var armor_repair: int = recipient.repair_armor(
				effect.amount
			)
			return "%s repaired %d armor condition." % [
				recipient_name,
				armor_repair,
			]

		ItemEffectDefinition.Kind.REPAIR_SHIELD:
			var shield_repair: int = recipient.repair_shield(
				effect.amount
			)
			return "%s repaired %d shield condition." % [
				recipient_name,
				shield_repair,
			]

		ItemEffectDefinition.Kind.ADD_GUARD:
			var guard_added: int = recipient.add_item_guard(
				effect.amount
			)
			return "%s gained %d temporary Item Guard." % [
				recipient_name,
				guard_added,
			]

		ItemEffectDefinition.Kind.DAMAGE_WEAPON:
			var weapon_damage: int = recipient.damage_weapon(
				effect.amount
			)
			return "%s weapon condition worsened by %d." % [
				recipient_name,
				weapon_damage,
			]

		ItemEffectDefinition.Kind.DAMAGE_ARMOR:
			var armor_damage: int = recipient.damage_armor(
				effect.amount
			)
			return "%s armor condition worsened by %d." % [
				recipient_name,
				armor_damage,
			]

		ItemEffectDefinition.Kind.DAMAGE_SHIELD:
			var shield_damage: int = recipient.damage_shield(
				effect.amount
			)
			return "%s shield condition worsened by %d." % [
				recipient_name,
				shield_damage,
			]

		ItemEffectDefinition.Kind.GRAPPLE_REDUCE_STAGE:
			var reduce_result: GrappleActionResult = (
				grapple_controller.apply_item_track_effect(
					actor.definition.battler_id,
					target.definition.battler_id,
					maxi(effect.amount, 1),
					false
				)
			)
			if not reduce_result.succeeded:
				return ""
			return "%s's Grapple track fell from Stage %d to %d." % [
				target.definition.display_name,
				reduce_result.stage_before,
				reduce_result.stage_after,
			]

		ItemEffectDefinition.Kind.GRAPPLE_DETACH:
			var detach_result: GrappleActionResult = (
				grapple_controller.apply_item_track_effect(
					actor.definition.battler_id,
					target.definition.battler_id,
					0,
					true
				)
			)
			if not detach_result.succeeded:
				return ""
			return "%s was detached by an explicit item effect." % (
				target.definition.display_name
			)

	return ""


func _consume_if_needed(
	item: ItemDefinition,
	slot_index: int,
	result: ItemUseResult
) -> String:
	if not item.consumes_on_use:
		return ""
	var consume_error: String = inventory.consume(slot_index, 1)
	if consume_error.is_empty():
		result.quantity_consumed = 1
	return consume_error


func _item_can_revive(
	item: ItemDefinition
) -> bool:
	for effect: ItemEffectDefinition in item.effects:
		if (
			effect != null
			and effect.kind == ItemEffectDefinition.Kind.REVIVE
		):
			return true
	return false


func _is_target_attached_to_actor(
	actor_id: StringName,
	target_id: StringName
) -> bool:
	if grapple_controller == null:
		return false
	var track: GrappleTrackState = (
		grapple_controller.get_track_for_grappler(target_id)
	)
	return track != null and track.heroine_id == actor_id


func _get_status_kind_label(
	status_kind: StatusDefinition.Kind
) -> String:
	match status_kind:
		StatusDefinition.Kind.BLEED:
			return "Bleed"
		StatusDefinition.Kind.POISON:
			return "Poison"
		StatusDefinition.Kind.SLOW:
			return "Slow"
		StatusDefinition.Kind.STUNNED:
			return "Stunned"
	return "Status"

