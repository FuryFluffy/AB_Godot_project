class_name RoomTrapDefinition
extends Resource
## Authored balance data. No default production thresholds or consequences.

enum EffectKind { STAT_CHANGE, ALARM }

@export var trap_id: StringName
@export var display_name: String
@export var weight: int = 1
@export var detection_successes: int = 0
@export var automatic_detection_tier: int = -1
@export var disarm_successes: int = 0
@export var effect_kind: EffectKind = EffectKind.STAT_CHANGE
@export var hp_delta: int = 0
@export var resolve_delta: int = 0
@export var corruption_delta: int = 0
@export var enemy_ids: Array[StringName] = []
@export var visual_id: StringName

func validate_definition() -> String:
	if trap_id == &"" or display_name.is_empty() or visual_id == &"" or weight < 1:
		return "Trap requires an identity, display name and positive weight."
	if detection_successes < 1 or disarm_successes < 1:
		return "Trap detection and disarm thresholds must be authored."
	if automatic_detection_tier < -1 or automatic_detection_tier > SkillEntry.Tier.GRAND_MASTER:
		return "Trap automatic detection tier is invalid."
	if effect_kind not in [EffectKind.STAT_CHANGE, EffectKind.ALARM]:
		return "Trap effect kind is invalid."
	if hp_delta > 0 or resolve_delta > 0 or corruption_delta < 0:
		return "Trap penalties have invalid signs."
	if effect_kind == EffectKind.ALARM:
		if enemy_ids.is_empty() or hp_delta != 0 or resolve_delta != 0 or corruption_delta != 0:
			return "Alarm requires enemies without simultaneous stat penalties."
		for id: StringName in enemy_ids:
			if id == &"":
				return "Alarm enemy identity cannot be empty."
	else:
		if not enemy_ids.is_empty() or (hp_delta == 0 and resolve_delta == 0 and corruption_delta == 0):
			return "Stat trap requires a penalty without alarm enemies."
	return ""

func saved_definition() -> Dictionary:
	var enemies: Array[String] = []
	for id: StringName in enemy_ids:
		enemies.append(String(id))
	return {"trap_id":String(trap_id), "detection_successes":detection_successes,
		"automatic_detection_tier":automatic_detection_tier, "disarm_successes":disarm_successes,
		"effect_kind":int(effect_kind), "hp_delta":hp_delta, "resolve_delta":resolve_delta,
		"corruption_delta":corruption_delta, "enemy_ids":enemies, "visual_id":String(visual_id)}
