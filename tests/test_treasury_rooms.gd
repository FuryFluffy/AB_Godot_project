extends SceneTree

const ROOMS = preload("res://data/exploration/rooms/event_room_catalog.tres")
const SOURCES = preload("res://data/rewards/reward_source_catalog.tres")
const ITEMS = preload("res://data/items/layer_1_2_item_catalog.tres")
var checks: int = 0
var failures: int = 0

func _init() -> void:
	var generator := LayerMapGenerator.new()
	for seed: int in range(1, 101):
		for layer: int in [1, 2]:
			var graph: LayerMapGraph = generator.generate_layer_1(seed) if layer == 1 else generator.generate_layer_2_run(seed)
			var again: LayerMapGraph = generator.generate_layer_1(seed) if layer == 1 else generator.generate_layer_2_run(seed)
			_check(graph.to_snapshot() == again.to_snapshot() and generator.validate_generated_layer(graph).is_empty(), "Treasuries preserve deterministic topology and required story gates")
			var count: int = 0
			for node: MapNodeState in graph.nodes.values():
				if node.node_type != MapNodeState.NodeType.TREASURY:
					continue
				count += 1
				var room: EventRoomDefinition = ROOMS.get_room(node.room_definition_id)
				_check(room != null and room.validate_definition().is_empty() and room.solve_when_loot_exhausted, "Generated Treasury has executable authored loot and completion")
				_check(node.requires_event_room() and not node.requires_battle() and not node.has_encounter_content() and node.reward_source_id == &"", "Treasury enters room with no combat or duplicate first-clear reward")
			_check(count >= 1 and count <= 2, "Treasury quota stays inside full-layer room budget")
	for layer: int in [1, 2]:
		var source: RoomLootSourceDefinition = SOURCES.get_source(StringName("treasury_layer_%d_supplies" % layer))
		_check(source != null and RewardSourceResolver.collect_validation_errors(source, ITEMS, layer).is_empty(), "Treasury source uses existing canonical executable items")
		var variants: Dictionary = {}
		for seed: int in range(1, 31):
			var first: Dictionary = RewardSourceResolver.resolve(source, ITEMS, layer, seed, &"test_room:draw_0")
			var second: Dictionary = RewardSourceResolver.resolve(source, ITEMS, layer, seed, &"test_room:draw_0")
			_check(first == second and first.error == "", "Reward identity/quantity/seed are repeatable")
			variants[first.record.item_id] = true
		_check(variants.size() > 1, "Different run seeds produce varied authored rewards")
	_check(EventRoomInstanceState.validate_container_state({}).is_empty(), "Legacy room state needs no migration")
	for value: Variant in [[], {"floor_cache":1}, {"":true}]:
		_check(not EventRoomInstanceState.validate_container_state({"revealed_containers":value}).is_empty(), "Malformed explicit discovery rejects")
	_check(not EventRoomInstanceState.validate_container_state({"item_spawns":[{"container_id":false}]}).is_empty(), "Malformed container identity rejects")
	# Loading keeps stored node types; generation never retroactively adds Treasuries.
	var legacy: LayerMapGraph = generator.generate_layer_1(333)
	for node: MapNodeState in legacy.nodes.values():
		if node.node_type == MapNodeState.NodeType.TREASURY:
			node.node_type = MapNodeState.NodeType.ROOM
			node.room_definition_id = &""
	var restored: Dictionary = LayerMapGraph.from_snapshot(legacy.to_snapshot())
	_check(restored.graph.to_snapshot() == legacy.to_snapshot(), "Pre-Treasury saved maps retain their stored topology/content")
	print("Stage 18 Treasury state: %d checks, %d failures." % [checks, failures])
	quit(failures)

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
