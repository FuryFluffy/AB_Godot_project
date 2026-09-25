class_name WeaponState
extends RefCounted


signal condition_changed


var definition: WeaponDefinition
var instance: EquipmentInstance
var family_rank: int = 0
var durability_damage: int:
	get:
		if instance == null or definition == null:
			return 0
		return definition.condition_maximum - instance.current_condition
	set(value):
		if instance != null and definition != null:
			instance.set_condition_clamped(
				definition.condition_maximum - maxi(value, 0)
			)
var is_broken: bool:
	get:
		return instance != null and instance.is_broken()
	set(value):
		if instance == null:
			return
		if value:
			instance.set_condition_clamped(0)
		elif instance.is_broken():
			instance.set_condition_clamped(1)


func _init(
	source_definition: WeaponDefinition = null,
	source_family_rank: int = 0,
	source_instance: EquipmentInstance = null
) -> void:
	if source_definition != null:
		initialize(source_definition, source_family_rank, source_instance)


func initialize(
	source_definition: WeaponDefinition,
	source_family_rank: int = 0,
	source_instance: EquipmentInstance = null
) -> void:
	assert(
		source_definition != null,
		"WeaponState requires a WeaponDefinition."
	)

	definition = source_definition
	instance = source_instance
	if instance == null:
		instance = EquipmentInstance.new(
			StringName("combat:%s:001" % definition.equipment_id),
			definition
		)
	else:
		assert(
			instance.definition == definition,
			"WeaponState instance definition must match its WeaponDefinition."
		)
	family_rank = definition.get_resolved_family_rank(
		source_family_rank
	)
	condition_changed.emit()


func get_rank_definition() -> WeaponRankDefinition:
	if definition == null:
		return null

	return definition.get_rank_definition(family_rank)


func get_attack_dice_bonus() -> int:
	if definition == null:
		return 0

	return definition.get_attack_dice_bonus(family_rank)


func get_maximum_durability_damage() -> int:
	if definition == null:
		return 5

	return maxi(
		definition.condition_maximum,
		1
	)


func can_use() -> bool:
	return definition != null and not is_broken


func can_parry() -> bool:
	return (
		can_use()
		and definition.can_parry
	)


func apply_durability_event() -> bool:
	if definition == null or instance == null or is_broken:
		return false
	var before: int = instance.current_condition
	instance.apply_condition_damage(1)
	if instance.current_condition == before:
		return false
	condition_changed.emit()
	return true


func repair(
	amount: int
) -> int:
	if definition == null or instance == null or amount <= 0:
		return 0
	var before: int = durability_damage
	instance.repair_condition(amount)
	if durability_damage != before:
		condition_changed.emit()
	return before - durability_damage


func get_condition_text() -> String:
	if is_broken:
		return "Broken"

	return "%d/%d" % [
		durability_damage,
		get_maximum_durability_damage(),
	]
