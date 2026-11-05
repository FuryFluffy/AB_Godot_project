class_name RoomTrapState
extends RefCounted
## Room-owned saved state. Dice and consequences never belong to particles/UI.

static func assign(local: Dictionary, seed: int, profile: RoomTrapProfile, eligible: Array[String]) -> String:
	if local.has("item_traps"):
		return validate(local)
	if profile == null:
		return ""
	var error: String = profile.validate_definition()
	if not error.is_empty():
		return error
	if eligible.size() <= profile.maximum_traps:
		return "Trap room must retain at least one eligible safe item."
	var candidates: Array[String] = eligible.duplicate()
	candidates.sort()
	var seen: Dictionary = {}
	for id: String in candidates:
		if id.is_empty() or seen.has(id):
			return "Trap candidates require unique stable spawn IDs."
		seen[id] = true
	var effects: Array[RoomTrapDefinition] = profile.definitions.duplicate()
	effects.sort_custom(func(a: RoomTrapDefinition, b: RoomTrapDefinition) -> bool: return String(a.trap_id) < String(b.trap_id))
	var rng := RandomNumberGenerator.new()
	rng.seed = StableSeedMixer.make_seed(seed, &"room_trap_assignment", profile.profile_id)
	var count: int = rng.randi_range(profile.minimum_traps, profile.maximum_traps)
	var weight: int = 0
	for effect: RoomTrapDefinition in effects:
		weight += effect.weight
	var traps: Dictionary = {}
	for i: int in range(count):
		var index: int = rng.randi_range(0, candidates.size()-1)
		var id: String = candidates.pop_at(index)
		var draw: int = rng.randi_range(1, weight)
		var chosen: RoomTrapDefinition
		for effect: RoomTrapDefinition in effects:
			draw -= effect.weight
			if draw <= 0:
				chosen = effect
				break
		traps[id] = {"definition":chosen.saved_definition(), "seed":StableSeedMixer.make_seed(seed, &"item_trap", StringName(id)),
			"detected":false, "announced":false, "disarmed":false, "triggered":false,
			"observers":{}, "detector_id":"", "interactor_id":"", "disarm_result":{},
			"alarm_pending":false, "alarm_resolved":false}
	local["item_traps"] = traps
	return ""

static func detect(trap: Dictionary, party: Dictionary) -> void:
	if trap.detected or trap.disarmed or trap.triggered:
		return
	var ids: Array = party.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for id: Variant in ids:
		var actor: BattlerState = party[id]
		if actor == null or actor.is_defeated or trap.observers.has(String(id)):
			continue
		var sheet: BattlerDefinition = actor.definition
		var tier: int = sheet.get_skill_tier(SkillEntry.Skill.AWARENESS)
		var auto_tier: int = int(trap.definition.automatic_detection_tier)
		var automatic: bool = auto_tier >= 0 and tier >= auto_tier
		var roll_seed: int = StableSeedMixer.make_seed(int(trap.seed), &"awareness", StringName(id))
		var successes: int = 0
		if not automatic:
			var roll: RollResult = DiceResolver.new().roll_check(sheet.attributes.intellect,
				sheet.get_skill_level(SkillEntry.Skill.AWARENESS), tier, roll_seed)
			successes = roll.total_successes
		var detected: bool = automatic or successes >= int(trap.definition.detection_successes)
		trap.observers[String(id)] = {"seed":roll_seed, "automatic":automatic, "successes":successes, "detected":detected}
		if detected:
			trap.detected = true
			trap.detector_id = String(id)
			return

static func disarm(trap: Dictionary, actor: BattlerState) -> Dictionary:
	if actor == null or actor.is_defeated or not trap.detected or trap.disarmed or trap.triggered or not trap.disarm_result.is_empty():
		return {"error":"This trap cannot be disarmed now.", "triggered":false}
	var seed: int = StableSeedMixer.make_seed(int(trap.seed), &"disarm", actor.definition.battler_id)
	var roll: RollResult = DiceResolver.new().roll_attribute(actor.definition.attributes.agility, seed)
	var success: bool = roll.total_successes >= int(trap.definition.disarm_successes)
	trap.disarm_result = {"seed":seed,"successes":roll.total_successes,"succeeded":success}
	trap.interactor_id = String(actor.definition.battler_id)
	if success:
		trap.disarmed = true
		return {"error":"", "triggered":false, "disarmed":true}
	return trigger(trap, actor)

static func trigger(trap: Dictionary, actor: BattlerState) -> Dictionary:
	if actor == null or actor.is_defeated or trap.disarmed or trap.triggered:
		return {"error":"", "triggered":false}
	trap.triggered = true
	trap.interactor_id = String(actor.definition.battler_id)
	var definition: Dictionary = trap.definition
	if int(definition.effect_kind) == RoomTrapDefinition.EffectKind.ALARM:
		trap.alarm_pending = true
	else:
		actor.apply_damage(-int(definition.hp_delta))
		actor.change_resolve(int(definition.resolve_delta))
		actor.change_corruption(int(definition.corruption_delta))
	return {"error":"", "triggered":true, "alarm":bool(trap.alarm_pending), "visual_id":definition.visual_id}

static func resolved(local: Dictionary) -> bool:
	for trap: Dictionary in local.get("item_traps", {}).values():
		if (not trap.disarmed and not trap.triggered) or trap.alarm_pending:
			return false
	return true

static func validate(local: Dictionary) -> String:
	if not local.has("item_traps"):
		return ""
	var traps: Variant = local.item_traps
	if not traps is Dictionary:
		return "Room item traps must be a dictionary."
	for id: Variant in traps:
		if not id is String or id.is_empty() or not traps[id] is Dictionary:
			return "Room item trap identity is invalid."
		var trap: Dictionary = traps[id]
		for field: String in ["detected","announced","disarmed","triggered","alarm_pending","alarm_resolved"]:
			if not trap.get(field) is bool:
				return "Room trap flag is invalid: " + field
		if not _integer(trap.get("seed"), 1) or not trap.get("definition") is Dictionary or not trap.get("observers") is Dictionary or not trap.get("disarm_result") is Dictionary:
			return "Room trap saved data is invalid."
		for field: String in ["detector_id","interactor_id"]:
			if not trap.get(field) is String:
				return "Room trap actor identity is invalid."
		if (trap.disarmed and trap.triggered) or (trap.announced and not trap.detected) or (trap.alarm_pending and (not trap.triggered or trap.alarm_resolved)):
			return "Room trap flags contradict each other."
		var definition: Dictionary = trap.definition
		for field: String in ["trap_id","visual_id"]:
			if not definition.get(field) is String or definition[field].is_empty():
				return "Saved trap definition identity is invalid."
		for field: String in ["detection_successes","disarm_successes"]:
			if not _integer(definition.get(field),1):
				return "Saved trap threshold is invalid."
		if not _integer(definition.get("automatic_detection_tier"),-1,SkillEntry.Tier.GRAND_MASTER) or not _integer(definition.get("effect_kind"),0,1):
			return "Saved trap rule is invalid."
		for field: String in ["hp_delta","resolve_delta","corruption_delta"]:
			if not _integer(definition.get(field),-100000,100000):
				return "Saved trap penalty is invalid."
		if int(definition.hp_delta) > 0 or int(definition.resolve_delta) > 0 or int(definition.corruption_delta) < 0 or not definition.get("enemy_ids") is Array:
			return "Saved trap consequence is invalid."
		for enemy: Variant in definition.enemy_ids:
			if not enemy is String or enemy.is_empty():
				return "Saved alarm enemy is invalid."
		var alarm: bool = int(definition.effect_kind) == RoomTrapDefinition.EffectKind.ALARM
		if alarm == definition.enemy_ids.is_empty() or (alarm and (definition.hp_delta != 0 or definition.resolve_delta != 0 or definition.corruption_delta != 0)):
			return "Saved trap consequences disagree with their kind."
		if not alarm and definition.hp_delta == 0 and definition.resolve_delta == 0 and definition.corruption_delta == 0:
			return "Saved stat trap requires a penalty."
		if alarm and trap.triggered != (trap.alarm_pending or trap.alarm_resolved):
			return "Triggered alarm must be pending or resolved."
		if (trap.alarm_pending or trap.alarm_resolved) and (not alarm or not trap.triggered):
			return "Saved alarm state is invalid."
		for observer: Variant in trap.observers:
			if not observer is String or observer.is_empty() or not trap.observers[observer] is Dictionary:
				return "Saved trap observer is invalid."
			var check: Dictionary = trap.observers[observer]
			if not _integer(check.get("seed"),1) or not _integer(check.get("successes"),0) or not check.get("automatic") is bool or not check.get("detected") is bool:
				return "Saved Awareness result is invalid."
		if not trap.disarm_result.is_empty():
			var check: Dictionary = trap.disarm_result
			if not _integer(check.get("seed"),1) or not _integer(check.get("successes"),0) or not check.get("succeeded") is bool:
				return "Saved Disarm result is invalid."
	return ""

static func _integer(value: Variant, minimum: int, maximum: int = StableSeedMixer.UINT32_MASK) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum
