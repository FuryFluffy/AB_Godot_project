extends SceneTree
const ITEMS = preload("res://data/items/layer_1_2_item_catalog.tres")
const BATTLERS = preload("res://data/battlers/battler_catalog.tres")
const ROOMS = preload("res://data/exploration/rooms/event_room_catalog.tres")
const HEROES: Array[StringName] = [&"lysandra",&"mira",&"seraphine"]
const CLOTH = &"mat_l01_servant_cloth"
const ITEM = &"l01_bandage_roll"
var checks: int = 0
var failures: int = 0
var recipe: RefugeRecipeDefinition

func _init() -> void:
	_generation()
	recipe = RefugeRecipeDefinition.new()
	recipe.recipe_id = &"fixture:field_recipe"
	recipe.display_name = "Fixture only"
	recipe.action = RefugeRecipeDefinition.Action.PRODUCE_ITEM
	recipe.station = RefugeRecipeDefinition.Station.ALCHEMY
	recipe.starts_known = false
	recipe.material_inputs = {String(CLOTH):2}
	recipe.output_item_id = ITEM
	recipe.output_quantity = 3
	RefugeOwnershipState.RECIPE_CATALOG.recipes.append(recipe)
	_provider()
	_knowledge()
	RefugeOwnershipState.RECIPE_CATALOG.recipes.erase(recipe)
	print("Stage 21 field production state: %d checks, %d failures." % [checks,failures])
	quit(failures)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _generation() -> void:
	var generator := LayerMapGenerator.new()
	var combinations: Dictionary = {}
	for seed: int in range(1,101):
		for layer: int in [1,2]:
			var graph: LayerMapGraph = generator.generate_layer_1(seed) if layer == 1 else generator.generate_layer_2_run(seed)
			var counts: Array[int] = [0,0]
			for node: MapNodeState in graph.nodes.values():
				if node.node_type not in [MapNodeState.NodeType.ALCHEMY,MapNodeState.NodeType.WORKSHOP]:
					continue
				counts[0 if node.node_type == MapNodeState.NodeType.ALCHEMY else 1] += 1
				var definition: EventRoomDefinition = ROOMS.get_room(node.room_definition_id)
				check(node.requires_event_room() and not node.has_encounter_content() and node.reward_source_id == &"","Field node does not inherit combat or rewards")
				check(definition != null and definition.field_station.validate_definition().is_empty(),"Authored room/station validates")
			check(counts[0] <= 1 and counts[1] <= 1 and generator.validate_special_room_quotas(graph).is_empty(),"Independent zero-or-one stations preserve quotas")
			combinations[str(counts)] = true
			var restored: Dictionary = LayerMapGraph.from_snapshot(JSON.parse_string(JSON.stringify(graph.to_snapshot())))
			check(restored.error.is_empty(),"Station map survives JSON")
	check(combinations.size() == 4,"Both stations independently optional")

func _provider() -> void:
	var inventory := RunInventoryState.new()
	inventory.initialize(ITEMS,HEROES)
	inventory.add_to_material_pouch(CLOTH,10)
	var provider := FieldProductionProvider.new(inventory,&"mira")
	var cap: int = ITEMS.get_item(ITEM).stack_limit
	inventory.add_to_backpack(&"mira",ITEM,cap-1)
	var result: Dictionary = recipe.execute_production(provider)
	check(result.error.is_empty() and inventory.material_pouch[String(CLOTH)] == 8,"Run inputs consumed once")
	var slots: Array[Dictionary] = inventory.get_backpack_snapshot(&"mira")
	check(slots[0].quantity == cap and slots[1].quantity == 2,"Output fills existing stack then exact remainder")
	check(inventory.get_backpack_snapshot(&"lysandra")[0].item_id == "","Only selected Backpack receives output")
	for i: int in range(15):
		inventory.backpacks_by_heroine[&"mira"][i] = {"slot_index":i,"item_id":String(ITEM),"quantity":cap}
	var before: Dictionary = inventory.get_snapshot()
	check(not String(recipe.execute_production(provider).error).is_empty() and before == inventory.get_snapshot(),"Capacity failure consumes no Materials or output")
	inventory.material_pouch.clear()
	before = inventory.get_snapshot()
	check(not String(recipe.execute_production(provider).error).is_empty() and before == inventory.get_snapshot(),"Insufficient run inputs do not mutate")
	check(not String(recipe.execute_production(FieldProductionProvider.new(inventory,&"inactive" )).error).is_empty(),"Inactive recipient rejected")

func _knowledge() -> void:
	var state := RefugeOwnershipState.new()
	state.initialize_default(ITEMS,BATTLERS,HEROES)
	check(not state.knows_recipe(recipe.recipe_id),"Discovery-only recipe starts unknown")
	var legacy: Dictionary = state.to_snapshot()
	legacy.erase("discovered_recipe_ids")
	check(state.restore_from_snapshot(legacy,ITEMS,BATTLERS,HEROES).is_empty() and state.discovered_recipe_ids.is_empty(),"Old saves default empty discoveries")
	check(state.discover_recipe(recipe.recipe_id).is_empty() and state.discover_recipe(recipe.recipe_id).is_empty() and state.discovered_recipe_ids.size() == 1,"Learning is idempotent")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(state.to_snapshot()))
	var copy := RefugeOwnershipState.new()
	check(copy.restore_from_snapshot(saved,ITEMS,BATTLERS,HEROES).is_empty() and copy.knows_recipe(recipe.recipe_id),"Permanent knowledge survives JSON restore")
	for bad: Variant in [null,{},["missing"],[String(recipe.recipe_id),String(recipe.recipe_id)],[1]]:
		var malformed: Dictionary = saved.duplicate(true)
		malformed.discovered_recipe_ids = bad
		var before: Dictionary = copy.to_snapshot()
		check(not copy.restore_from_snapshot(malformed,ITEMS,BATTLERS,HEROES).is_empty() and copy.to_snapshot() == before,"Malformed knowledge rejects atomically")
	state.banked_materials[String(CLOTH)] = 99
	var start: Dictionary = state.make_run_start_transfer()
	check(String(start.error).is_empty(),"Expedition ownership transfer prepared")
	var deployed: RefugeOwnershipState = start.refuge_state
	check(deployed.knows_recipe(recipe.recipe_id),"Knowledge survives expedition deployment")
	var inventory: RunInventoryState = start.run_inventory
	inventory.add_to_material_pouch(CLOTH,6)
	recipe.execute_production(FieldProductionProvider.new(inventory,&"mira"))
	check(deployed.get_banked_material_quantity(CLOTH) == 99 and deployed.stash_item_stacks.is_empty(),"Field production never touches bank or Stash")
	# Return/defeat use the same existing ownership transfer with different losses.
	for defeated: bool in [false,true]:
		var returned: Dictionary = deployed.make_run_return_transfer(inventory,start.run_equipment,defeated)
		check(String(returned.error).is_empty(),"Run return transfer succeeds")
		if String(returned.error).is_empty():
			check(returned.refuge_state.knows_recipe(recipe.recipe_id) and returned.refuge_state.get_banked_material_quantity(CLOTH) == 103,"Knowledge survives return/defeat; only unspent Materials bank")
			var next: Dictionary = returned.refuge_state.make_run_start_transfer()
			check(String(next.error).is_empty() and next.refuge_state.knows_recipe(recipe.recipe_id) and next.run_inventory.material_pouch.is_empty(),"Next run retains knowledge without withdrawing or restoring Materials")
	check(EventRoomInstanceState.validate_container_state({"station_prepared":true}).is_empty() and not EventRoomInstanceState.validate_container_state({"station_prepared":1}).is_empty(),"Saved grant flag validated")
