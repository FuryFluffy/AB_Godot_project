class_name EquipmentDefinition
extends Resource


enum Slot {
	MAIN_HAND,
	OFF_HAND,
	ARMOR,
}


enum Rarity {
	UNSPECIFIED,
	COMMON,
	UNCOMMON,
	RARE,
}


@export_group("Identity")
@export var equipment_id: StringName
@export var display_name: String = "Unnamed Equipment"
@export var player_refuge_available: bool = false

@export_group("Runtime Equipment")
@export var allowed_slots: Array[int] = []
@export_range(1, 99, 1) var condition_maximum: int = 1
@export var destructible: bool = false
@export var rarity: Rarity = Rarity.UNSPECIFIED
@export var salvage_material_id: StringName

@export_group("Authored Effect Identity")
@export var authored_positive_effect_ids: Array[StringName] = []
@export var authored_negative_effect_ids: Array[StringName] = []


func validate_definition() -> String:
	if equipment_id == &"":
		return "Equipment definition requires a stable equipment ID."
	if display_name.strip_edges().is_empty():
		return "Equipment '%s' requires a display name." % equipment_id
	if allowed_slots.is_empty():
		return "Equipment '%s' requires at least one explicit allowed slot." % equipment_id
	var seen_slots: Dictionary = {}
	for slot_value: int in allowed_slots:
		if slot_value < Slot.MAIN_HAND or slot_value > Slot.ARMOR:
			return "Equipment '%s' contains an unknown allowed slot." % equipment_id
		if seen_slots.has(slot_value):
			return "Equipment '%s' repeats an allowed slot." % equipment_id
		seen_slots[slot_value] = true
	if condition_maximum <= 0:
		return "Equipment '%s' requires positive maximum condition." % equipment_id
	if destructible and salvage_material_id == &"":
		return "Destructible equipment '%s' requires salvage_material_id." % equipment_id
	if destructible and rarity == Rarity.UNSPECIFIED:
		return "Destructible equipment '%s' requires a salvage rarity." % equipment_id
	if destructible and rarity not in [Rarity.COMMON, Rarity.UNCOMMON, Rarity.RARE]:
		return "Destructible equipment '%s' has an invalid salvage rarity." % equipment_id
	if not destructible and salvage_material_id != &"":
		return "Non-destructible equipment '%s' must not declare salvage material." % equipment_id
	if not destructible and rarity != Rarity.UNSPECIFIED:
		return "Non-destructible equipment '%s' must not declare salvage rarity." % equipment_id
	var seen_effects: Dictionary = {}
	for effect_id: StringName in authored_positive_effect_ids:
		if effect_id == &"":
			return "Equipment '%s' contains an empty positive effect ID." % equipment_id
		if seen_effects.has(effect_id):
			return "Equipment '%s' repeats authored effect '%s'." % [equipment_id, effect_id]
		seen_effects[effect_id] = true
	for effect_id: StringName in authored_negative_effect_ids:
		if effect_id == &"":
			return "Equipment '%s' contains an empty negative effect ID." % equipment_id
		if seen_effects.has(effect_id):
			return "Equipment '%s' repeats authored effect '%s'." % [equipment_id, effect_id]
		seen_effects[effect_id] = true
	return ""


func allows_slot(slot: Slot) -> bool:
	return allowed_slots.has(int(slot))


func get_salvage_yield() -> int:
	if not destructible:
		return 0
	match rarity:
		Rarity.COMMON:
			return 1
		Rarity.UNCOMMON:
			return 2
		Rarity.RARE:
			return 3
	return 0


static func get_slot_key(slot: Slot) -> StringName:
	match slot:
		Slot.MAIN_HAND:
			return &"main_hand"
		Slot.OFF_HAND:
			return &"off_hand"
		Slot.ARMOR:
			return &"armor"
	return &""


static func get_slot_label(slot: Slot) -> String:
	match slot:
		Slot.MAIN_HAND:
			return "Main Hand"
		Slot.OFF_HAND:
			return "Off Hand"
		Slot.ARMOR:
			return "Armor"
	return "Unknown"
