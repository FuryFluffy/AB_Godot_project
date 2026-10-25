class_name LootClaim
extends RefCounted
## Counters extend the existing resolved source/room assignment. Authored quantity
## and resolution seed never change. Absence preserves legacy all-or-nothing saves.

static func remaining(record: Dictionary) -> int:
	return int(record.get("remaining_quantity", 0 if bool(record.get("claimed", record.get("collected", false))) else int(record.get("quantity", 0))))

static func is_fight(record: Dictionary) -> bool:
	return not record.has("spawn_id") and int(record.get("source_channel", -1)) == RoomLootSourceDefinition.SourceChannel.ENCOUNTER_COMPLETION

static func validate(record: Dictionary) -> String:
	var total: int = int(record.get("quantity", 0))
	if not record.has("remaining_quantity") and not record.has("abandoned_quantity"):
		return ""
	var authored: Variant = record.get("quantity")
	if not (authored is int or authored is float) or float(authored) != floorf(float(authored)) or total <= 0:
		return "Loot source has an invalid original quantity."
	for flag: String in ["claimed", "deferred", "collected"]:
		if record.has(flag) and typeof(record[flag]) != TYPE_BOOL:
			return "Loot source has an invalid %s flag." % flag
	for key: String in ["remaining_quantity", "abandoned_quantity"]:
		var value: Variant = record.get(key)
		if not (value is int or value is float) or float(value) != floorf(float(value)) or int(value) < 0 or int(value) > total:
			return "Loot source has an invalid %s." % key
	var left: int = int(record.remaining_quantity)
	var lost: int = int(record.abandoned_quantity)
	if left + lost > total or (lost > 0 and (not is_fight(record) or left > 0)):
		return "Loot remainder/abandonment does not match source lifetime."
	if bool(record.get("claimed", record.get("collected", false))) != (left == 0):
		return "Loot remainder does not match its claim state."
	if left == 0 and bool(record.get("deferred", false)):
		return "An exhausted Loot source cannot be deferred."
	if record.has("collected") and bool(record.collected) != (left == 0):
		return "Room collection does not match its remainder."
	return ""

static func accept(record: Dictionary, count: int) -> void:
	record.remaining_quantity = remaining(record) - count
	record.abandoned_quantity = int(record.get("abandoned_quantity", 0))
	record.claimed = record.remaining_quantity == 0
	record.deferred = not record.claimed
	if record.has("spawn_id") or record.has("collected"):
		record.collected = record.claimed

static func abandon(record: Dictionary) -> void:
	assert(is_fight(record))
	var left: int = remaining(record)
	accept(record, left)
	record.abandoned_quantity = int(record.abandoned_quantity) + left
