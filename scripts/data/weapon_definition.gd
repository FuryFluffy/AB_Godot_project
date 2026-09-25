class_name WeaponDefinition
extends EquipmentDefinition

enum Property {
	NONE,
	IGNORE_DODGE,
	IGNORE_ARMOR,
	REMOVE_ACTION_ON_DAMAGE,
	IGNORE_PARRY,
	IGNORE_SHIELD,
	UNARMED_CRITICAL_ATTACK,
	BONUS_AT_VERY_FAR,
}


enum AttackRange {
	MELEE,
	REACH,
	RANGED,
}


@export_group("Family and Progression")
@export var family: WeaponFamilyDefinition
@export_range(1, 3, 1) var default_family_rank: int = 1
@export var unique_effects: Array[WeaponEffectDefinition] = []

@export_group("Attack Check")
@export var skill: SkillEntry.Skill = SkillEntry.Skill.SWORD
@export var attribute: AttributeSet.Attribute = AttributeSet.Attribute.MIGHT
@export_range(-10, 10, 1) var dice_modifier: int = 0

@export_group("Rules")
@export var property: Property = Property.NONE
@export var attack_range: AttackRange = AttackRange.MELEE
@export var is_magic_attack: bool = false
@export_range(0, 2, 1) var maximum_zone_distance: int = 2
@export var can_parry: bool = true
@export var is_two_handed: bool = false
var maximum_durability_damage: int:
	get:
		return condition_maximum
	set(value):
		condition_maximum = clampi(value, 1, 20)

@export_group("On HP Damage")
@export var on_damage_status: StatusDefinition
@export_range(-1, 99, 1) var status_damage_override: int = -1
@export_range(-1, 10, 1) var status_tick_override: int = -1


func validate_definition() -> String:
	var definition_error: String = super.validate_definition()
	if not definition_error.is_empty():
		return definition_error
	for slot_value: int in allowed_slots:
		if slot_value not in [Slot.MAIN_HAND, Slot.OFF_HAND]:
			return "Weapon '%s' may use only Main Hand or Off Hand." % equipment_id
	return ""


func get_resolved_family_rank(
	requested_rank: int = 0
) -> int:
	if family == null:
		return 0

	var resolved_rank: int = (
		requested_rank
		if requested_rank > 0
		else default_family_rank
	)
	if family.is_valid_rank(resolved_rank):
		return resolved_rank

	return 0


func get_rank_definition(
	requested_rank: int = 0
) -> WeaponRankDefinition:
	if family == null:
		return null

	var resolved_rank: int = get_resolved_family_rank(
		requested_rank
	)
	if resolved_rank <= 0:
		return null

	return family.get_rank_definition(resolved_rank)


func get_all_effects(
	requested_rank: int = 0
) -> Array[WeaponEffectDefinition]:
	var combined: Array[WeaponEffectDefinition] = []
	var rank_definition: WeaponRankDefinition = (
		get_rank_definition(requested_rank)
	)

	if rank_definition != null:
		for effect: WeaponEffectDefinition in rank_definition.effects:
			if effect != null:
				combined.append(effect)

	for effect: WeaponEffectDefinition in unique_effects:
		if effect != null:
			combined.append(effect)

	return combined


func get_attack_dice_bonus(
	requested_rank: int = 0
) -> int:
	var rank_definition: WeaponRankDefinition = (
		get_rank_definition(requested_rank)
	)
	if rank_definition == null:
		return 0

	return rank_definition.attack_dice_bonus


func get_flat_attack_success_bonus(
	requested_rank: int = 0
) -> int:
	var total: int = 0

	for effect: WeaponEffectDefinition in get_all_effects(
		requested_rank
	):
		if effect is FlatAttackSuccessWeaponEffect:
			total += (
				effect as FlatAttackSuccessWeaponEffect
			).added_successes

	return total


func get_flat_damage_bonus(
	requested_rank: int = 0
) -> int:
	var total: int = 0

	for effect: WeaponEffectDefinition in get_all_effects(
		requested_rank
	):
		if effect is FlatDamageWeaponEffect:
			total += (
				effect as FlatDamageWeaponEffect
			).added_damage

	return total


func get_ignored_defense_successes(
	defense_choice: DefenseChoice.Type,
	requested_rank: int = 0
) -> int:
	var total: int = 0

	for effect: WeaponEffectDefinition in get_all_effects(
		requested_rank
	):
		if not (effect is DefenseIgnoreWeaponEffect):
			continue
		var ignore_effect: DefenseIgnoreWeaponEffect = (
			effect as DefenseIgnoreWeaponEffect
		)
		if ignore_effect.applies_to(defense_choice):
			total += ignore_effect.ignored_successes

	if total == 0:
		match property:
			Property.IGNORE_DODGE:
				if defense_choice == DefenseChoice.Type.DODGE:
					total = 1
			Property.IGNORE_ARMOR:
				if defense_choice == DefenseChoice.Type.ARMOR:
					total = 1
			Property.IGNORE_SHIELD:
				if defense_choice == DefenseChoice.Type.SHIELD:
					total = 1
			Property.IGNORE_PARRY:
				if defense_choice == DefenseChoice.Type.PARRY:
					total = 1

	return total


func get_action_loss_on_damage(
	hp_damage: int,
	requested_rank: int = 0
) -> int:
	var total: int = 0

	for effect: WeaponEffectDefinition in get_all_effects(
		requested_rank
	):
		if not (effect is ActionLossOnDamageWeaponEffect):
			continue
		var action_effect: ActionLossOnDamageWeaponEffect = (
			effect as ActionLossOnDamageWeaponEffect
		)
		if hp_damage >= action_effect.minimum_hp_damage:
			total += action_effect.action_loss

	if (
		total == 0
		and property == Property.REMOVE_ACTION_ON_DAMAGE
		and hp_damage > 0
	):
		total = 1

	return total


func get_status_effects_on_damage(
	hp_damage: int,
	requested_rank: int = 0
) -> Array[StatusOnDamageWeaponEffect]:
	var matching: Array[StatusOnDamageWeaponEffect] = []

	for effect: WeaponEffectDefinition in get_all_effects(
		requested_rank
	):
		if not (effect is StatusOnDamageWeaponEffect):
			continue
		var status_effect: StatusOnDamageWeaponEffect = (
			effect as StatusOnDamageWeaponEffect
		)
		if (
			status_effect.status != null
			and hp_damage >= status_effect.minimum_hp_damage
		):
			matching.append(status_effect)

	return matching


func get_status_effects_on_undefended_hit(
	requested_rank: int = 0
) -> Array[StatusOnUndefendedHitWeaponEffect]:
	var matching: Array[StatusOnUndefendedHitWeaponEffect] = []

	for effect: WeaponEffectDefinition in get_all_effects(
		requested_rank
	):
		if not (effect is StatusOnUndefendedHitWeaponEffect):
			continue
		var status_effect: StatusOnUndefendedHitWeaponEffect = (
			effect as StatusOnUndefendedHitWeaponEffect
		)
		if status_effect.status != null:
			matching.append(status_effect)

	return matching


func get_range_dice_bonus(
	spatial_range: BattlefieldState.SpatialRange,
	requested_rank: int = 0
) -> int:
	var total: int = 0

	for effect: WeaponEffectDefinition in get_all_effects(
		requested_rank
	):
		if not (effect is RangeDiceWeaponEffect):
			continue
		var range_effect: RangeDiceWeaponEffect = (
			effect as RangeDiceWeaponEffect
		)
		if range_effect.spatial_range == spatial_range:
			total += range_effect.dice_modifier

	if (
		total == 0
		and property == Property.BONUS_AT_VERY_FAR
		and spatial_range == BattlefieldState.SpatialRange.VERY_FAR
	):
		total = 1

	return total


func has_critical_free_attack(
	roll_result: RollResult,
	skill_entry: SkillEntry,
	requested_rank: int = 0
) -> bool:
	if roll_result == null:
		return false

	for effect: WeaponEffectDefinition in get_all_effects(
		requested_rank
	):
		if not (effect is CriticalFreeAttackWeaponEffect):
			continue
		var critical_effect: CriticalFreeAttackWeaponEffect = (
			effect as CriticalFreeAttackWeaponEffect
		)
		if (
			critical_effect.requires_trained_weapon_skill
			and (
				skill_entry == null
				or not skill_entry.is_trained()
			)
		):
			continue
		if (
			roll_result.get_natural_ten_count()
			>= critical_effect.required_natural_tens
		):
			return true

	if property != Property.UNARMED_CRITICAL_ATTACK:
		return false
	if skill_entry == null or not skill_entry.is_trained():
		return false
	return roll_result.get_natural_ten_count() > 0


func is_family(
	family_id: StringName
) -> bool:
	return (
		family != null
		and family.family_id == family_id
	)


func get_property_summary(
	requested_rank: int = 0
) -> String:
	var parts: PackedStringArray = []

	for effect: WeaponEffectDefinition in get_all_effects(
		requested_rank
	):
		if not effect.display_name.is_empty():
			parts.append(effect.display_name)

	if parts.is_empty():
		match property:
			Property.IGNORE_DODGE:
				parts.append("Ignore 1 Dodge success")
			Property.IGNORE_ARMOR:
				parts.append("Ignore 1 Armor success")
			Property.REMOVE_ACTION_ON_DAMAGE:
				parts.append("Remove 1 Action after HP damage")
			Property.IGNORE_PARRY:
				parts.append("Ignore 1 Parry success")
			Property.IGNORE_SHIELD:
				parts.append("Ignore 1 Shield success")
			Property.UNARMED_CRITICAL_ATTACK:
				parts.append("Critical grants a free Attack")
			Property.BONUS_AT_VERY_FAR:
				parts.append("+1d10 at Very Far")

	return ", ".join(parts)
