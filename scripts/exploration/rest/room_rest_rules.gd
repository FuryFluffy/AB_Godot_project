class_name RoomRestRules
extends RefCounted

const OFFERS: Array[RoomRestOfferDefinition] = [
	preload("res://data/exploration/rest/restore_hp.tres"),
	preload("res://data/exploration/rest/restore_mp.tres"),
	preload("res://data/exploration/rest/restore_both.tres"),
	preload("res://data/exploration/rest/restore_resolve.tres"),
	preload("res://data/exploration/rest/reduce_corruption.tres"),
	preload("res://data/exploration/rest/full_recovery.tres"),
]

static func assigned_offer(seed: int, node_id: StringName) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = StableSeedMixer.make_seed(seed,&"rest_offer",node_id)
	return OFFERS[rng.randi_range(0,OFFERS.size()-1)].offer_id

static func get_offer(id: int) -> RoomRestOfferDefinition:
	for offer: RoomRestOfferDefinition in OFFERS:
		if offer.offer_id == id:
			return offer
	return null

static func preview(offer_id: int, states: Dictionary, order: Array[StringName]) -> Dictionary:
	var offer: RoomRestOfferDefinition = get_offer(offer_id)
	if offer == null or states.is_empty() or order.size() != states.size():
		return {"error":"Rest requires an assigned offer and the current active party."}
	var before: Dictionary = {}
	var after: Dictionary = {}
	var lines: PackedStringArray = [offer.display_name,"Every active heroine · No currency or Material cost","One use for this room. Ordinary Rest charges are unchanged.",""]
	for id: StringName in order:
		var actor: BattlerState = states.get(id)
		if actor == null or actor.definition == null or actor.definition.battler_id != id or before.has(id):
			return {"error":"Rest requires valid current heroine states."}
		var hp_max: int = actor.get_max_hp()
		var mp_max: int = actor.get_max_mp()
		before[id] = {"hp":actor.current_hp,"mp":actor.current_mp,"resolve":actor.current_resolve,"corruption":actor.current_corruption,"max_hp":hp_max,"max_mp":mp_max,"defeated":actor.is_defeated}
		# Same ceiling convention as ordinary Rest; add a fraction of the maximum.
		after[id] = {"hp":hp_max if offer.full_recovery else mini(hp_max,actor.current_hp+ceili(hp_max*offer.hp_percent/100.0)),
			"mp":mp_max if offer.full_recovery else mini(mp_max,actor.current_mp+ceili(mp_max*offer.mp_percent/100.0)),
			"resolve":100 if offer.full_recovery else clampi(actor.current_resolve+offer.resolve_delta,0,100),
			"corruption":clampi(actor.current_corruption+offer.corruption_delta,0,100)}
		lines.append(actor.definition.display_name)
		lines.append("HP %d → %d   MP %d → %d" % [actor.current_hp,after[id].hp,actor.current_mp,after[id].mp])
		lines.append("Resolve %d → %d   Corruption %d → %d" % [actor.current_resolve,after[id].resolve,actor.current_corruption,after[id].corruption])
	return {"error":"","title":"Rest room — Confirm","text":"\n".join(lines),"offer_id":offer_id,"before":before,"after":after}
