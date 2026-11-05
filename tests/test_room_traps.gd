extends "res://tests/test_run_loot.gd"
## Approved provisional profiles plus synthetic edge cases exercise saved rules.

func _run() -> void:
	_production()
	_assignment()
	_detection()
	_disarm()
	_commit_boundary()
	_validation()
	print("Stage 19 trap state: %d checks, %d failures." % [checks, failures])
	quit(failures)

func _profile() -> RoomTrapProfile:
	var profile := RoomTrapProfile.new()
	profile.profile_id = &"test_profile"
	profile.minimum_traps = 1
	profile.maximum_traps = 2
	for kind: String in ["poison","corruption","alarm"]:
		var effect := RoomTrapDefinition.new()
		effect.trap_id = StringName(kind)
		effect.display_name = kind
		effect.visual_id = StringName(kind)
		effect.detection_successes = 2
		effect.disarm_successes = 2
		effect.automatic_detection_tier = SkillEntry.Tier.EXPERT
		match kind:
			"poison":
				effect.hp_delta = -1
				effect.resolve_delta = -5
			"corruption": effect.corruption_delta = 20
			"alarm":
				effect.effect_kind = RoomTrapDefinition.EffectKind.ALARM
				effect.enemy_ids = [&"hollow_servant", &"hollow_servant"]
		profile.definitions.append(effect)
	return profile

func _trap(kind: String = "poison", seed: int = 3) -> Dictionary:
	var local: Dictionary = {}
	var profile: RoomTrapProfile = _profile()
	profile.definitions.assign(profile.definitions.filter(func(effect: RoomTrapDefinition) -> bool: return effect.trap_id == StringName(kind)))
	RoomTrapState.assign(local,seed,profile,["a","b","c"])
	return local.item_traps.values()[0]

func _assignment() -> void:
	var variants: Dictionary = {}
	for seed: int in range(1,61):
		var local: Dictionary = {}
		var again: Dictionary = {}
		_check(RoomTrapState.assign(local,seed,_profile(),["a","b","c"]).is_empty(), "Trap assignment validates")
		RoomTrapState.assign(again,seed,_profile(),["c","a","b"])
		_check(local == again and local.item_traps.size() in [1,2], "Seed/IDs determine assignments while preserving safe items")
		var saved: Dictionary = local.duplicate(true)
		RoomTrapState.assign(local,seed+999,_profile(),["a","b","c"])
		_check(local == saved and RoomTrapState.validate(local).is_empty(), "Existing assignments never reroll: " + RoomTrapState.validate(local))
		variants[JSON.stringify(local)] = true
	_check(variants.size() > 1, "Different seeds vary assigned hotspots/effects")
	var empty: Dictionary = {"item_traps":{}}
	_check(RoomTrapState.assign(empty,1,_profile(),["a","b","c"]).is_empty() and empty.item_traps.is_empty(), "An initialized empty trap list stays empty")
	_check(not RoomTrapState.assign({},1,_profile(),["a","b"]).is_empty(), "Uniformly trapped rooms reject")

func _detection() -> void:
	_setup()
	var trap: Dictionary = _trap()
	var original: Dictionary = trap.duplicate(true)
	var sheet: BattlerDefinition = BATTLERS.get_battler(&"mira").duplicate(true)
	sheet.get_skill_entry(SkillEntry.Skill.AWARENESS).tier = SkillEntry.Tier.EXPERT
	var actor := BattlerState.new(sheet)
	RoomTrapState.detect(trap,{&"mira":actor})
	_check(trap.detected and trap.detector_id == "mira" and trap.observers.mira.automatic, "Configured high tier identifies without a roll")
	_check(not original.detected and not trap.triggered and not trap.announced, "Detection does not trigger or announce on its own")
	_check(BATTLERS.get_battler(&"mira").get_skill_tier(SkillEntry.Skill.AWARENESS) == SkillEntry.Tier.NOVICE, "Production Mira sheet stays unchanged")
	var before: Dictionary = trap.duplicate(true)
	RoomTrapState.detect(trap,service.party_states)
	_check(trap == before, "Repeated inspection does not reroll or change detector")
	var detected_count: int = 0
	var missed_count: int = 0
	for seed: int in range(1,50):
		trap = _trap("poison",seed)
		trap.definition.automatic_detection_tier = -1
		RoomTrapState.detect(trap,service.party_states)
		if trap.detected:
			detected_count += 1
			_check(trap.observers[trap.detector_id].successes >= 2, "A single observer supplies the threshold without pooled successes")
		else:
			missed_count += 1
			_check(trap.detector_id == "" and not trap.announced, "Failed detection leaks no detector/announcement")
		before = trap.duplicate(true)
		RoomTrapState.detect(trap,service.party_states)
		_check(trap == before, "Per-observer results survive repeated entry checks")
	_check(detected_count > 0 and missed_count > 0, "Seeded check coverage includes success and failure")

func _disarm() -> void:
	var successes: int = 0
	var failures_seen: int = 0
	for seed: int in range(1,40):
		_setup()
		var trap: Dictionary = _trap("poison",seed)
		trap.detected = true
		trap.detector_id = "mira"
		var actor: BattlerState = service.party_states[&"lysandra"]
		var hp: int = actor.current_hp
		var resolve: int = actor.current_resolve
		RoomTrapState.disarm(trap,actor)
		if trap.disarmed:
			successes += 1
			_check(not trap.triggered and actor.current_hp == hp, "Successful plain Agility leaves a safe item")
		else:
			failures_seen += 1
			_check(trap.triggered and actor.current_hp == hp-1 and actor.current_resolve == resolve-5, "Failed Disarm immediately applies one saved penalty")
		_check(trap.interactor_id == "lysandra" and service.party_states[&"mira"].current_hp == BATTLERS.get_battler(&"mira").max_hp, "Interacting heroine differs from detector and owns penalty")
		var before: Dictionary = trap.duplicate(true)
		_check(not RoomTrapState.disarm(trap,actor).error.is_empty() and trap == before, "No free repeated Disarm attempt")
	_check(successes > 0 and failures_seen > 0, "Disarm fixtures cover both outcomes")

func _commit_boundary() -> void:
	_setup()
	var record: Dictionary = _source(2)
	var trap: Dictionary = _trap("corruption")
	service.bind_sources([record])
	var actor: BattlerState = service.party_states[&"lysandra"]
	var before_corruption: int = actor.current_corruption
	var observations: Array[bool] = []
	service.collection_guard = func(_record: Dictionary, owner: StringName) -> String:
		return "Choose a living heroine." if service.party_states[owner].is_defeated else ""
	service.collection_effect = func(_record: Dictionary, owner: StringName) -> void:
		RoomTrapState.trigger(trap,service.party_states[owner])
	service.changed.connect(func() -> void: observations.append(trap.triggered and LootClaim.remaining(record) < 2 and _quantity(&"lysandra","l01_bandage_roll") > 0))
	var result: Dictionary = service.collect(_request(),_bag(),1,true)
	_check(result.moved == 1 and not trap.triggered and observations.is_empty(), "Capacity preview emits no effect/notification")
	for i: int in range(15):
		bags.backpacks_by_heroine[&"lysandra"][i] = {"slot_index":i,"item_id":"l01_smelling_salts","quantity":ITEMS.get_item(&"l01_smelling_salts").stack_limit}
	_check(_take(1).moved == 0 and not trap.triggered and actor.current_corruption == before_corruption, "Full backpack triggers no trap")
	bags.backpacks_by_heroine[&"lysandra"][0] = RefugeInventoryTransfer._at({},0,0,"backpack")
	_check(_take(1).moved == 1 and trap.triggered and actor.current_corruption == before_corruption+20, "Accepted partial pickup commits one effect")
	_check(observations == [true], "Inventory observers see destination, claim and trap state together")
	_check(_take(1).moved == 1 and actor.current_corruption == before_corruption+20, "Remaining quantity collects without repeating damage")
	var alarm: Dictionary = _trap("alarm")
	var hp: int = actor.current_hp
	var outcome: Dictionary = RoomTrapState.trigger(alarm,actor)
	_check(outcome.alarm and alarm.alarm_pending and actor.current_hp == hp and not RoomTrapState.resolved({"item_traps":{"a":alarm}}), "Alarm queues party encounter without stat damage or Solved")
	_check(not RoomTrapState.trigger(alarm,actor).triggered, "Alarm cannot trigger twice")
	alarm.alarm_pending = false
	alarm.alarm_resolved = true
	_check(RoomTrapState.resolved({"item_traps":{"a":alarm}}), "Resolved alarm no longer blocks trap completion")

func _validation() -> void:
	_check(RoomTrapState.validate({}).is_empty(), "Legacy room state needs no trap migration")
	var valid: Dictionary = {"item_traps":{"a":_trap()}}
	_check(RoomTrapState.validate(JSON.parse_string(JSON.stringify(valid))).is_empty(), "JSON roundtrip retains valid optional trap state")
	for field: String in ["detected","announced","triggered","disarmed","alarm_pending","alarm_resolved"]:
		var bad: Dictionary = valid.duplicate(true)
		bad.item_traps.a[field] = 1
		_check(not RoomTrapState.validate(bad).is_empty(), "Malformed explicit trap flag rejects")
	for value: Variant in [-1,1.5,"2",null]:
		var bad: Dictionary = valid.duplicate(true)
		bad.item_traps.a.definition.detection_successes = value
		_check(not RoomTrapState.validate(bad).is_empty(), "Malformed threshold rejects")

func _production() -> void:
	var generator := LayerMapGenerator.new()
	var catalog = preload("res://data/exploration/rooms/event_room_catalog.tres")
	for seed: int in range(1,101):
		for layer: int in [1,2]:
			var graph: LayerMapGraph = generator.generate_layer_1(seed) if layer == 1 else generator.generate_layer_2_run(seed)
			_check(generator.validate_generated_layer(graph).is_empty(),"Trap generation preserves topology and protected content")
			var count: int = 0
			for node: MapNodeState in graph.nodes.values():
				if node.node_type != MapNodeState.NodeType.TRAP:
					continue
				count += 1
				var room: EventRoomDefinition = catalog.get_room(node.room_definition_id)
				_check(room != null and room.validate_definition().is_empty() and room.trap_profile != null and room.solve_when_loot_exhausted,"Executable trap room has valid authored profile")
			_check(count in [1,2],"Full layer has one or two executable Trap rooms")
	var old: LayerMapGraph = generator.generate_layer_1(333)
	for node: MapNodeState in old.nodes.values():
		if node.node_type == MapNodeState.NodeType.TRAP:
			node.node_type = MapNodeState.NodeType.ROOM
			node.room_definition_id = &""
	var loaded: Dictionary = LayerMapGraph.from_snapshot(old.to_snapshot())
	_check(loaded.graph.to_snapshot() == old.to_snapshot(),"Stored pre-Trap graphs remain unchanged on load")
	var profile = preload("res://data/exploration/traps/provisional_room_traps.tres")
	_check(profile.minimum_traps == 1 and profile.maximum_traps == 2,"Approved provisional hotspot counts")
	for effect: RoomTrapDefinition in profile.definitions:
		_check(effect.weight == 1 and effect.detection_successes == 2 and effect.disarm_successes == 2 and effect.automatic_detection_tier == SkillEntry.Tier.EXPERT,"Approved provisional thresholds and equal weights")
