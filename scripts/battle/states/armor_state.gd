class_name ArmorState
extends RefCounted


var definition: ArmorDefinition
var instance: EquipmentInstance
var absorbed_damage: int:
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
	source_definition: ArmorDefinition = null,
	source_instance: EquipmentInstance = null
) -> void:
	if source_definition != null:
		initialize(source_definition, source_instance)


func initialize(
	source_definition: ArmorDefinition,
	source_instance: EquipmentInstance = null
) -> void:
	assert(
		source_definition != null,
		"ArmorState requires an ArmorDefinition."
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
			"ArmorState instance definition must match its ArmorDefinition."
		)


func can_defend() -> bool:
	return definition != null and not is_broken


func get_safe_absorption_limit() -> int:
	if definition == null:
		return 0

	return definition.get_safe_absorption_limit()


func get_safe_absorption_remaining() -> int:
	if definition == null or is_broken:
		return 0

	return maxi(
		get_safe_absorption_limit() - absorbed_damage,
		0
	)


func absorb_safely(
	damage: int
) -> int:
	if damage <= 0 or is_broken:
		return 0

	var absorbed: int = mini(
		damage,
		get_safe_absorption_remaining()
	)

	if absorbed > 0:
		instance.apply_condition_damage(absorbed)
	return absorbed


func is_at_breaking_point() -> bool:
	if definition == null or is_broken:
		return false

	return (
		absorbed_damage
		>= get_safe_absorption_limit()
	)


func break_and_absorb_one() -> int:
	if not is_at_breaking_point():
		return 0

	instance.apply_condition_damage(1)

	return 1


func damage_condition(
	amount: int
) -> int:
	if definition == null or amount <= 0 or is_broken:
		return 0
	var before: int = absorbed_damage
	instance.apply_condition_damage(amount)
	return absorbed_damage - before


func repair(
	amount: int
) -> int:
	if definition == null or amount <= 0:
		return 0
	var before: int = absorbed_damage
	instance.repair_condition(amount)
	return before - absorbed_damage


func reset() -> void:
	if instance != null and definition != null:
		instance.set_condition_clamped(definition.condition_maximum)
