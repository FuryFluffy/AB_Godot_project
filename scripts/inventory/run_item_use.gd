class_name RunItemUse
extends RefCounted
## Shared existing field-item rules; no combat permissions are granted here.

static func _validate_exploration_item_use(
	item: ItemDefinition,
	target: BattlerState
) -> String:
	if item == null:
		return (
			"The selected item slot is empty."
		)

	if (
		target == null
		or target.definition == null
	):
		return "Select a valid heroine."

	if (
		target.definition.faction
		!= BattlerDefinition.Faction.HEROINE
	):
		return (
			"Exploration items require a heroine target."
		)

	match item.item_type:
		ItemDefinition.ItemType.PASSIVE:
			return (
				"%s is passive and cannot be activated."
				% item.display_name
			)

		ItemDefinition.ItemType.KEY:
			return (
				"%s must be used on an "
				+ "environmental interaction."
			) % item.display_name

	if item.performs_attack:
		return (
			"%s can only be used through "
			+ "the battle Attack system."
		) % item.display_name

	if item.target_rule not in [
		ItemDefinition.TargetRule.SELF,
		ItemDefinition.TargetRule.SELF_OR_ADJACENT_HEROINE,
		ItemDefinition.TargetRule.ANY_HEROINE,
	]:
		return (
			"%s requires a battle or "
			+ "environmental target."
		) % item.display_name

	if item.effects.is_empty():
		return (
			"%s has no active effects."
			% item.display_name
		)

	if (
		target.is_defeated
		and not _item_has_effect_kind(
			item,
			ItemEffectDefinition.Kind.REVIVE
		)
	):
		return (
			"%s is defeated and requires "
			+ "a revival item."
		) % target.definition.display_name

	if not _has_applicable_exploration_effect(
		item,
		target
	):
		return (
			"%s would have no effect on %s."
			% [
				item.display_name,
				target.definition.display_name,
			]
		)

	return ""


static func _item_has_effect_kind(
	item: ItemDefinition,
	kind: ItemEffectDefinition.Kind
) -> bool:
	for effect: ItemEffectDefinition in item.effects:
		if (
			effect != null
			and effect.kind == kind
		):
			return true

	return false


static func _has_applicable_exploration_effect(
	item: ItemDefinition,
	target: BattlerState
) -> bool:
	for effect: ItemEffectDefinition in item.effects:
		if _is_exploration_effect_applicable(
			target,
			effect
		):
			return true

	return false


static func _is_exploration_effect_applicable(
	target: BattlerState,
	effect: ItemEffectDefinition
) -> bool:
	if target == null or effect == null:
		return false

	match effect.kind:
		ItemEffectDefinition.Kind.HEAL_HP:
			return (
				not target.is_defeated
				and effect.amount > 0
				and target.current_hp
				< target.get_max_hp()
			)

		ItemEffectDefinition.Kind.RESTORE_MP:
			return (
				not target.is_defeated
				and effect.amount > 0
				and target.current_mp
				< target.get_max_mp()
			)

		ItemEffectDefinition.Kind.CHANGE_RESOLVE:
			return (
				(
					effect.amount > 0
					and target.current_resolve < 100
				)
				or (
					effect.amount < 0
					and target.current_resolve > 0
				)
			)

		ItemEffectDefinition.Kind.CHANGE_CORRUPTION:
			return (
				(
					effect.amount > 0
					and target.current_corruption < 100
				)
				or (
					effect.amount < 0
					and target.current_corruption > 0
				)
			)

		ItemEffectDefinition.Kind.REVIVE:
			return target.is_defeated

		ItemEffectDefinition.Kind.ADD_GUARD:
			return (
				not target.is_defeated
				and effect.amount > 0
				and target.item_guard_points < 99
			)

		ItemEffectDefinition.Kind.REPAIR_WEAPON:
			return (
				target.weapon_state != null
				and (
					target.weapon_state.is_broken
					or target.weapon_state.durability_damage > 0
				)
			)

		ItemEffectDefinition.Kind.REPAIR_ARMOR:
			return (
				target.armor_state != null
				and (
					target.armor_state.is_broken
					or target.armor_state.absorbed_damage > 0
				)
			)

		ItemEffectDefinition.Kind.REPAIR_SHIELD:
			return (
				target.shield_state != null
				and (
					target.shield_state.is_broken
					or target.shield_state.absorbed_damage > 0
				)
			)

	return false


static func _apply_exploration_item_effect(
	target: BattlerState,
	effect: ItemEffectDefinition
) -> String:
	if not _is_exploration_effect_applicable(
		target,
		effect
	):
		return ""

	var display_name: String = (
		target.definition.display_name
	)

	match effect.kind:
		ItemEffectDefinition.Kind.HEAL_HP:
			var restored_hp: int = target.heal(
				effect.amount
			)

			if restored_hp > 0:
				return (
					"%s restored %d HP."
					% [
						display_name,
						restored_hp,
					]
				)

		ItemEffectDefinition.Kind.RESTORE_MP:
			var restored_mp: int = target.restore_mp(
				effect.amount
			)

			if restored_mp > 0:
				return (
					"%s restored %d MP."
					% [
						display_name,
						restored_mp,
					]
				)

		ItemEffectDefinition.Kind.CHANGE_RESOLVE:
			var resolve_change: int = (
				target.change_resolve(
					effect.amount
				)
			)

			if resolve_change != 0:
				return (
					"%s's Resolve changed by %d."
					% [
						display_name,
						resolve_change,
					]
				)

		ItemEffectDefinition.Kind.CHANGE_CORRUPTION:
			var corruption_change: int = (
				target.change_corruption(
					effect.amount
				)
			)

			if corruption_change != 0:
				return (
					"%s's Corruption changed by %d."
					% [
						display_name,
						corruption_change,
					]
				)

		ItemEffectDefinition.Kind.REVIVE:
			if target.revive(
				maxi(
					effect.amount,
					1
				)
			):
				return (
					"%s was revived."
					% display_name
				)

		ItemEffectDefinition.Kind.ADD_GUARD:
			var guard_added: int = (
				target.add_item_guard(
					effect.amount
				)
			)

			if guard_added > 0:
				return (
					"%s gained %d Item Guard."
					% [
						display_name,
						guard_added,
					]
				)

		ItemEffectDefinition.Kind.REPAIR_WEAPON:
			var weapon_repaired: int = (
				target.repair_weapon(
					effect.amount
				)
			)

			if weapon_repaired > 0:
				return (
					"%s repaired %d Weapon damage."
					% [
						display_name,
						weapon_repaired,
					]
				)

		ItemEffectDefinition.Kind.REPAIR_ARMOR:
			var armor_repaired: int = (
				target.repair_armor(
					effect.amount
				)
			)

			if armor_repaired > 0:
				return (
					"%s repaired %d Armor damage."
					% [
						display_name,
						armor_repaired,
					]
				)

		ItemEffectDefinition.Kind.REPAIR_SHIELD:
			var shield_repaired: int = (
				target.repair_shield(
					effect.amount
				)
			)

			if shield_repaired > 0:
				return (
					"%s repaired %d Shield damage."
					% [
						display_name,
						shield_repaired,
					]
				)

	return ""
