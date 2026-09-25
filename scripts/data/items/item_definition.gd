class_name ItemDefinition
extends Resource


enum ItemType {
	CONSUMABLE,
	PASSIVE,
	KEY,
}


enum ContentCategory {
	UNSPECIFIED,
	ACTIVE,
	MEMENTO,
	KEY,
	MATERIAL,
	STORY,
	KNOWLEDGE,
	LEGACY_DEVELOPMENT,
}


enum Rarity {
	UNSPECIFIED,
	COMMON,
	UNCOMMON,
	RARE,
	UNIQUE,
}


enum KeyPersistenceScope {
	RUN_ONLY,
	PERSISTENT_REFUGE,
}


enum TargetRule {
	SELF,
	SELF_OR_ADJACENT_HEROINE,
	ADJACENT_HEROINE,
	ANY_HEROINE,
	ADJACENT_ENEMY,
	REACHABLE_ENEMY,
	ATTACHED_GRAPPLER,
}


@export_group("Identity")
@export var item_id: StringName
@export var display_name: String = "Unnamed Item"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_range(1, 20, 1) var layer: int = 1
@export var content_category: ContentCategory = ContentCategory.UNSPECIFIED
@export var rarity: Rarity = Rarity.UNSPECIFIED
@export var canonical_workbook_item: bool = false
@export var item_type: ItemType = ItemType.CONSUMABLE
@export var key_persistence_scope: KeyPersistenceScope = (
	KeyPersistenceScope.RUN_ONLY
)

@export_group("Inventory")
@export_range(1, 99, 1) var stack_limit: int = 1
@export var consumes_on_use: bool = true
@export var combat_usable: bool = true

@export_group("Use")
@export_range(0, 3, 1) var action_cost: int = 1
@export var target_rule: TargetRule = TargetRule.SELF
@export_range(0, 4, 1) var maximum_zone_distance: int = 1
@export var requires_line_of_sight: bool = false
@export var effects: Array[ItemEffectDefinition] = []

@export_group("Optional Attack")
@export var performs_attack: bool = false
@export var attack_skill: SkillEntry.Skill = SkillEntry.Skill.KNOWLEDGE
@export var attack_attribute: AttributeSet.Attribute = (
	AttributeSet.Attribute.INTELLECT
)
@export_range(-10, 10, 1) var attack_dice_modifier: int = 0
@export var attack_property: WeaponDefinition.Property = (
	WeaponDefinition.Property.NONE
)
@export var attack_range: WeaponDefinition.AttackRange = (
	WeaponDefinition.AttackRange.RANGED
)
@export var is_magic_attack: bool = false
@export var on_damage_status: StatusDefinition
@export_range(-1, 99, 1) var status_damage_override: int = -1
@export_range(-1, 10, 1) var status_tick_override: int = -1
@export var attack_effects_require_hp_damage: bool = true


func is_active_item() -> bool:
	return (
		item_type == ItemType.CONSUMABLE
		and combat_usable
	)


func get_type_label() -> String:
	match item_type:
		ItemType.CONSUMABLE:
			return "Consumable"
		ItemType.PASSIVE:
			return "Passive"
		ItemType.KEY:
			return "Key Item"
	return "Item"


func get_target_label() -> String:
	match target_rule:
		TargetRule.SELF:
			return "Self"
		TargetRule.SELF_OR_ADJACENT_HEROINE:
			return "Self or Adjacent heroine"
		TargetRule.ADJACENT_HEROINE:
			return "Adjacent heroine"
		TargetRule.ANY_HEROINE:
			return "Any heroine"
		TargetRule.ADJACENT_ENEMY:
			return "Adjacent enemy"
		TargetRule.REACHABLE_ENEMY:
			return "Reachable enemy"
		TargetRule.ATTACHED_GRAPPLER:
			return "Attached grappler"
	return "Target"


func create_attack_profile() -> WeaponDefinition:
	if not performs_attack:
		return null

	var profile: WeaponDefinition = WeaponDefinition.new()
	profile.equipment_id = StringName(
		"item_profile_%s" % String(item_id)
	)
	profile.display_name = display_name
	profile.allowed_slots = [EquipmentDefinition.Slot.MAIN_HAND]
	profile.skill = attack_skill
	profile.attribute = attack_attribute
	profile.dice_modifier = attack_dice_modifier
	profile.property = attack_property
	profile.attack_range = attack_range
	profile.is_magic_attack = is_magic_attack
	profile.maximum_zone_distance = maximum_zone_distance
	profile.can_parry = false
	profile.maximum_durability_damage = 20
	profile.on_damage_status = on_damage_status
	profile.status_damage_override = status_damage_override
	profile.status_tick_override = status_tick_override
	return profile


func validate_definition() -> String:
	if item_id == &"":
		return "An ItemDefinition has no item_id."
	if display_name.is_empty():
		return "Item '%s' has no display name." % item_id
	if canonical_workbook_item:
		if content_category in [
			ContentCategory.UNSPECIFIED,
			ContentCategory.LEGACY_DEVELOPMENT,
		]:
			return "%s has no canonical content category." % display_name
		if rarity == Rarity.UNSPECIFIED:
			return "%s has no canonical rarity." % display_name
		if icon == null:
			return "%s has no canonical icon." % display_name
	elif content_category != ContentCategory.LEGACY_DEVELOPMENT:
		return "%s is not marked as canonical or legacy content." % (
			display_name
		)
	if stack_limit <= 0:
		return "%s has an invalid stack limit." % display_name
	if (
		content_category != ContentCategory.KEY
		and key_persistence_scope != KeyPersistenceScope.RUN_ONLY
	):
		return "%s declares key persistence but is not a Key." % display_name
	if item_type != ItemType.CONSUMABLE and consumes_on_use:
		return "%s is not consumable but consumes_on_use is enabled." % (
			display_name
		)
	if performs_attack and item_type != ItemType.CONSUMABLE:
		return "%s performs an Attack but is not consumable." % (
			display_name
		)
	if performs_attack and target_rule not in [
		TargetRule.ADJACENT_ENEMY,
		TargetRule.REACHABLE_ENEMY,
		TargetRule.ATTACHED_GRAPPLER,
	]:
		return "%s performs an Attack without an enemy target rule." % (
			display_name
		)
	return ""
