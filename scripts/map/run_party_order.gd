class_name RunPartyOrder
extends RefCounted
## A presentation permutation only. Never supplies initiative or battlefield slots.

static func resolve(preferred: Array[StringName], members: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in preferred + members:
		if members.has(id) and not result.has(id):
			result.append(id)
	return result

static func validate(value: Variant, members: Array[StringName]) -> String:
	if not value is Array or value.size() != members.size():
		return "Party order must contain every current member exactly once."
	var seen: Array[StringName] = []
	for id: Variant in value:
		if not (id is String or id is StringName) or not members.has(StringName(id)) or seen.has(StringName(id)):
			return "Party order cannot add, remove or duplicate a heroine."
		seen.append(StringName(id))
	return ""
