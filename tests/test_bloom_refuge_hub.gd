extends SceneTree


const BATTLER_CATALOG: BattlerCatalogDefinition = preload(
	"res://data/battlers/battler_catalog.tres"
)
const ITEM_CATALOG: ItemCatalogDefinition = preload(
	"res://data/items/layer_1_2_item_catalog.tres"
)


var failures: int = 0


func _init() -> void:
	_test_campaign_round_trip_and_next_run()
	_test_post_refuge_defeat_returns_to_hub()
	_test_refuge_ownership_moves_and_stash_safety()
	_test_defeat_loss_policy()
	_test_material_banking_is_one_way()
	if failures == 0:
		print("Bloom Refuge hub and campaign-boundary tests passed.")
	else:
		push_error("%d Bloom Refuge hub test(s) failed." % failures)
	quit(failures)


func _test_campaign_round_trip_and_next_run() -> void:
	var generator := LayerMapGenerator.new()
	var source: RunState = _make_established_refuge_run(generator)
	var knowledge := KnowledgeState.new()
	knowledge.discovered_entries = {
		"butlers_records": true,
		"empty_mens_cell": true,
	}
	var campaign_snapshot: Dictionary = CampaignSaveStore.make_campaign_snapshot(
		source,
		knowledge
	)
	var parsed: Variant = JSON.parse_string(JSON.stringify(campaign_snapshot))
	var restored := RunState.new()
	var restored_knowledge := KnowledgeState.new()
	var restore_error: String = CampaignSaveStore.restore_campaign_snapshot(
		parsed as Dictionary,
		restored,
		restored_knowledge,
		generator.generate_bloom_refuge_holding_state(1),
		BATTLER_CATALOG
	)
	var restored_lysandra: Dictionary = restored.party_snapshot.get(
		&"lysandra",
		{}
	)
	_expect(
		restore_error.is_empty()
		and restored.graph.layer_id == &"bloom_refuge"
		and restored.current_node_id == &"bloom_refuge_farthest_cell"
		and restored.run_seed == 27072026
		and restored.bloom == 41
		and restored.completed_layer_ids.has(&"layer_1")
		and restored.has_established_refuge()
		and restored.get_campaign_mode_id() == "REFUGE_RUN"
		and restored.has_defeated_boss(RunState.BLOOD_NUN_BOSS_ID)
		and restored.party_snapshot.size() == 3
		and int(restored_lysandra.get("resolve", 0)) == 73
		and restored_knowledge.has_entry(&"butlers_records")
		and restored_knowledge.has_entry(&"empty_mens_cell"),
		"Campaign JSON round-trip must restore the complete Refuge boundary."
	)

	var invalid_graph: LayerMapGraph = generator.generate_layer_2_run(777)
	invalid_graph.start_node_id = &"invalid_layer_2_start"
	var invalid_start_error: String = restored.validate_next_layer_2_run(
		invalid_graph
	)
	_expect(
		not invalid_start_error.is_empty()
		and restored.graph.layer_id == &"bloom_refuge"
		and restored.bloom == 41,
		"Invalid next-run data must not mutate the Refuge campaign boundary."
	)

	var next_graph: LayerMapGraph = generator.generate_layer_2_run(333)
	var start_error: String = restored.begin_next_layer_2_run(next_graph)
	var first_route_node: MapNodeState = next_graph.get_nodes_in_column(1)[0]
	var deeper_route_nodes: Array[MapNodeState] = (
		next_graph.get_nodes_in_column(2)
	)
	var deeper_route_traversable: bool = not deeper_route_nodes.is_empty()
	for deeper_node: MapNodeState in deeper_route_nodes:
		deeper_route_traversable = (
			deeper_route_traversable
			and deeper_node.travel_enabled
		)
	var jailer_node: MapNodeState = next_graph.get_map_node(
		RunState.JAILER_FIRST_NODE_ID
	)
	_expect(
		start_error.is_empty()
		and restored.graph == next_graph
		and restored.graph.layer_id == &"layer_2"
		and restored.current_node_id == &"l2_refuge_farthest_cell"
		and restored.bloom == 0
		and restored.has_established_refuge()
		and restored.campaign_lifecycle.active_run_layer_seeds.size() == 10
		and first_route_node != null
		and first_route_node.travel_enabled
		and first_route_node.encounter_id == (
			LayerMapGenerator.LAYER_2_FIRST_SLICE_ENCOUNTER_ID
		)
		and deeper_route_traversable
		and jailer_node != null
		and jailer_node.encounter_id == RunState.JAILER_FIRST_ENCOUNTER_ID,
		"Next run must enter the authored first slice and expose the traversable generated Layer 2 route toward the unresolved Jailer."
	)

	(restored.party_snapshot[&"lysandra"] as Dictionary)["hp"] = 1
	(restored.party_snapshot[&"lysandra"] as Dictionary)["mp"] = 0
	var return_error: String = restored.return_current_run_to_refuge(
		generator.generate_bloom_refuge_holding_state(restored.run_seed),
		BATTLER_CATALOG
	)
	restored_lysandra = restored.party_snapshot.get(&"lysandra", {})
	_expect(
		return_error.is_empty()
		and restored.graph.layer_id == &"bloom_refuge"
		and int(restored_lysandra.get("hp", 0)) == (
			BATTLER_CATALOG.get_battler(&"lysandra").max_hp
		)
		and int(restored_lysandra.get("mp", -1)) == (
			BATTLER_CATALOG.get_battler(&"lysandra").max_mp
		)
		and int(restored_lysandra.get("resolve", 0)) == 73,
		"Voluntary Refuge return must restore HP/MP without restoring Resolve."
	)


func _test_post_refuge_defeat_returns_to_hub() -> void:
	var generator := LayerMapGenerator.new()
	var run: RunState = _make_established_refuge_run(generator)
	run.begin_next_layer_2_run(generator.generate_layer_2_run(444))
	var defeat := EncounterOutcome.new()
	defeat.result = EncounterOutcome.Result.DEFEAT
	defeat.encounter_id = &"layer_2_future_regular"
	defeat.source_node_id = &"l2_c1_n0"
	defeat.party_snapshot = {
		&"lysandra": _heroine_snapshot(0, 0, 58, 13),
		&"mira": _heroine_snapshot(0, 0, 62, 17),
		&"seraphine": _heroine_snapshot(0, 0, 67, 9),
	}
	defeat.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	defeat.heroine_progression_snapshot = (
		run.heroine_progression_snapshot.duplicate(true)
	)
	var recovery_error: String = run.apply_post_refuge_defeat(
		defeat,
		generator.generate_bloom_refuge_holding_state(run.run_seed),
		BATTLER_CATALOG
	)
	var lysandra: Dictionary = run.party_snapshot.get(&"lysandra", {})
	_expect(
		recovery_error.is_empty()
		and run.graph.layer_id == &"bloom_refuge"
		and int(lysandra.get("hp", 0)) == (
			BATTLER_CATALOG.get_battler(&"lysandra").max_hp
		)
		and int(lysandra.get("resolve", 0)) == 58
		and int(lysandra.get("corruption", 0)) == 13,
		"A post-Refuge defeat must recover at the hub and retain Resolve/Corruption consequences."
	)


func _test_refuge_ownership_moves_and_stash_safety() -> void:
	var generator := LayerMapGenerator.new()
	var run: RunState = _make_established_refuge_run(generator)
	var initialize_error: String = run.ensure_refuge_ownership_initialized()
	var refuge: RefugeOwnershipState = run.refuge_ownership
	var setup_error: String = refuge.add_preparation_item(
		&"lysandra",
		&"l01_bandage_roll",
		2
	)
	if setup_error.is_empty():
		setup_error = refuge.add_stash_item(&"l01_smelling_salts", 3)
	var before_failed_move: Dictionary = refuge.to_snapshot()
	var failed_move_error: String = refuge.move_stash_item_to_preparation(
		&"mira",
		&"l01_smelling_salts",
		4
	)
	_expect(
		not failed_move_error.is_empty()
		and refuge.to_snapshot() == before_failed_move,
		"A failed Stash transfer must not partially mutate either inventory."
	)
	if setup_error.is_empty():
		setup_error = refuge.assign_memento(
			&"mira",
			&"l01_hollow_livery_pin"
		)
	var default_order: Array[StringName] = [
		&"lysandra",
		&"mira",
		&"seraphine",
	]
	_expect(
		initialize_error.is_empty()
		and setup_error.is_empty()
		and refuge.selected_party_ids == default_order,
		"Refuge ownership must initialize the fixed selected-party order."
	)
	var lysandra_loadout: Dictionary = refuge.equipment_loadouts_by_heroine.get(
		&"lysandra",
		{}
	) as Dictionary
	var lysandra_slots: Dictionary = lysandra_loadout.get("slots", {}) as Dictionary
	var sword_instance_id := StringName(lysandra_slots.get("main_hand", ""))
	var equipped_stash_error: String = refuge.move_unequipped_equipment_to_stash(
		&"lysandra",
		sword_instance_id
	)
	var equipment_move_error: String = refuge.unequip_owned_slot(
		&"lysandra",
		EquipmentDefinition.Slot.MAIN_HAND
	)
	if equipment_move_error.is_empty():
		equipment_move_error = refuge.move_unequipped_equipment_to_stash(
			&"lysandra",
			sword_instance_id
		)
	if equipment_move_error.is_empty():
		equipment_move_error = refuge.move_stash_equipment_to_heroine(
			sword_instance_id,
			&"lysandra"
		)
	if equipment_move_error.is_empty():
		equipment_move_error = refuge.equip_owned_instance(
			&"lysandra",
			EquipmentDefinition.Slot.MAIN_HAND,
			sword_instance_id
		)
	_expect(
		not equipped_stash_error.is_empty()
		and equipment_move_error.is_empty()
		and refuge.stash_equipment_instances.is_empty(),
		"Equipped gear must not enter the Stash, while unequipped instance moves remain transactional."
	)
	var start_error: String = run.begin_next_layer_2_run(
		generator.generate_layer_2_run(555)
	)
	_expect(
		start_error.is_empty()
		and _backpack_quantity(
			run.run_inventory,
			&"lysandra",
			&"l01_bandage_roll"
		) == 2
		and _preparation_quantity(
			run.refuge_ownership,
			&"lysandra",
			&"l01_bandage_roll"
		) == 0
		and run.run_inventory.get_memento_id(&"mira")
		== &"l01_hollow_livery_pin"
		and run.refuge_ownership.equipment_loadouts_by_heroine.is_empty()
		and run.run_equipment.loadouts_by_heroine.size() == 3,
		"Run start must move prepared inventory, equipment, and Mementos without Refuge duplication."
	)
	var lysandra_runtime: PersonalEquipmentLoadoutState = (
		run.run_equipment.get_loadout(&"lysandra")
	)
	var sword: EquipmentInstance = lysandra_runtime.get_equipped_instance(
		EquipmentDefinition.Slot.MAIN_HAND
	)
	sword.set_condition_clamped(1)
	run.narrative_state.flags_by_scope[&"save"][&"m5_story_fact"] = true
	var return_error: String = run.return_current_run_to_refuge(
		generator.generate_bloom_refuge_holding_state(run.run_seed),
		BATTLER_CATALOG
	)
	_expect(
		return_error.is_empty()
		and _refuge_main_hand_condition(
			run.refuge_ownership,
			&"lysandra"
		) == 1
		and _preparation_quantity(
			run.refuge_ownership,
			&"lysandra",
			&"l01_bandage_roll"
		) == 2
		and _backpack_quantity(
			run.run_inventory,
			&"lysandra",
			&"l01_bandage_roll"
		) == 0
		and run.refuge_ownership.memento_slots_by_heroine.get(
			&"mira",
			null
		) == &"l01_hollow_livery_pin"
		and run.run_equipment.loadouts_by_heroine.is_empty()
		and bool(run.narrative_state.flags_by_scope[&"save"].get(
			&"m5_story_fact",
			false
		)),
		"Voluntary return must preserve carried items, condition, Mementos, and persistent story facts without duplicate runtime ownership."
	)


func _test_defeat_loss_policy() -> void:
	var generator := LayerMapGenerator.new()
	var run: RunState = _make_established_refuge_run(generator)
	run.ensure_refuge_ownership_initialized()
	run.refuge_ownership.add_stash_item(&"l01_smelling_salts", 2)
	run.refuge_ownership.assign_memento(
		&"lysandra",
		&"l01_hollow_livery_pin"
	)
	run.begin_next_layer_2_run(generator.generate_layer_2_run(666))
	run.run_inventory.add_to_backpack(
		&"lysandra",
		&"l01_bandage_roll",
		1
	)
	run.run_inventory.add_to_key_chain(&"shared_rusty_key", 1)
	run.narrative_state.flags_by_scope[&"save"][&"m5_defeat_story_fact"] = true
	run.narrative_state.resolved_interaction_ids.append(&"m5_defeat_lore_fact")
	var knowledge := KnowledgeState.new()
	knowledge.discover_entry(&"m5_defeat_knowledge_fact")
	var sword: EquipmentInstance = run.run_equipment.get_loadout(
		&"lysandra"
	).get_equipped_instance(EquipmentDefinition.Slot.MAIN_HAND)
	sword.set_condition_clamped(0)
	var defeat := EncounterOutcome.new()
	defeat.result = EncounterOutcome.Result.DEFEAT
	defeat.encounter_id = &"layer_2_future_regular"
	defeat.source_node_id = &"l2_c1_n0"
	defeat.party_snapshot = {
		&"lysandra": _heroine_snapshot(0, 0, 58, 13),
		&"mira": _heroine_snapshot(0, 0, 62, 17),
		&"seraphine": _heroine_snapshot(0, 0, 67, 9),
	}
	defeat.inventory_snapshot = run.inventory_snapshot.duplicate(true)
	defeat.heroine_progression_snapshot = run.heroine_progression_snapshot.duplicate(true)
	var recovery_error: String = run.apply_post_refuge_defeat(
		defeat,
		generator.generate_bloom_refuge_holding_state(run.run_seed),
		BATTLER_CATALOG
	)
	var item_bar_empty: bool = true
	for slot: Dictionary in run.inventory_snapshot:
		item_bar_empty = item_bar_empty and String(slot.get("item_id", "")).is_empty()
	_expect(
		recovery_error.is_empty()
		and item_bar_empty
		and _backpack_quantity(
			run.run_inventory,
			&"lysandra",
			&"l01_bandage_roll"
		) == 0
		and run.run_inventory.get_key_quantity(&"shared_rusty_key") == 0
		and run.refuge_ownership.key_chain.is_empty()
		and run.refuge_ownership.memento_slots_by_heroine.get(
			&"lysandra",
			null
		) == &"l01_hollow_livery_pin"
		and _refuge_main_hand_condition(
			run.refuge_ownership,
			&"lysandra"
		) == 0
		and run.refuge_ownership.stash_item_stacks.size() == 1,
		"Defeat must lose disposable inventory and ordinary keys while preserving broken gear, Mementos, and Stash."
	)
	_expect(
		bool(run.narrative_state.flags_by_scope[&"save"].get(
			&"m5_defeat_story_fact",
			false
		))
		and run.narrative_state.resolved_interaction_ids.has(
			&"m5_defeat_lore_fact"
		)
		and knowledge.has_entry(&"m5_defeat_knowledge_fact"),
		"Defeat must preserve the existing Story, Lore, and Knowledge authorities."
	)


func _test_material_banking_is_one_way() -> void:
	var material := ItemDefinition.new()
	material.item_id = &"test_refuge_material"
	material.display_name = "Test Refuge Material"
	material.description = "Focused test fixture."
	material.icon = ITEM_CATALOG.get_item(&"l01_bandage_roll").icon
	material.content_category = ItemDefinition.ContentCategory.MATERIAL
	material.rarity = ItemDefinition.Rarity.COMMON
	material.canonical_workbook_item = true
	material.item_type = ItemDefinition.ItemType.PASSIVE
	material.stack_limit = 9
	material.consumes_on_use = false
	material.combat_usable = false
	var persistent_key := ItemDefinition.new()
	persistent_key.item_id = &"test_persistent_refuge_key"
	persistent_key.display_name = "Test Persistent Refuge Key"
	persistent_key.description = "Focused persistence-scope fixture."
	persistent_key.icon = ITEM_CATALOG.get_item(&"shared_rusty_key").icon
	persistent_key.content_category = ItemDefinition.ContentCategory.KEY
	persistent_key.rarity = ItemDefinition.Rarity.UNIQUE
	persistent_key.canonical_workbook_item = true
	persistent_key.item_type = ItemDefinition.ItemType.KEY
	persistent_key.key_persistence_scope = (
		ItemDefinition.KeyPersistenceScope.PERSISTENT_REFUGE
	)
	persistent_key.stack_limit = 1
	persistent_key.consumes_on_use = false
	persistent_key.combat_usable = false
	persistent_key.action_cost = 0
	var catalog := ItemCatalogDefinition.new()
	catalog.items = ITEM_CATALOG.items.duplicate()
	catalog.items.append(material)
	catalog.items.append(persistent_key)
	var heroine_ids: Array[StringName] = [&"lysandra", &"mira", &"seraphine"]
	var refuge := RefugeOwnershipState.new()
	var initialize_error: String = refuge.initialize_default(
		catalog,
		BATTLER_CATALOG,
		heroine_ids
	)
	var inventory := RunInventoryState.new()
	var inventory_error: String = inventory.initialize(catalog, heroine_ids)
	if inventory_error.is_empty():
		inventory_error = inventory.add_to_material_pouch(
			&"test_refuge_material",
			3
		)
	var equipment := RunEquipmentState.new()
	var equipment_error: String = equipment.initialize(
		BATTLER_CATALOG,
		heroine_ids,
		inventory
	)
	var resolution: Dictionary = refuge.make_run_return_transfer(
		inventory,
		equipment,
		false
	)
	var resolved_refuge: RefugeOwnershipState = resolution.get(
		"refuge_state"
	) as RefugeOwnershipState
	var resolved_inventory: RunInventoryState = resolution.get(
		"run_inventory"
	) as RunInventoryState
	var bank_before: int = (
		resolved_refuge.get_banked_material_quantity(&"test_refuge_material")
		if resolved_refuge != null
		else 0
	)
	var withdrawal_error: String = (
		resolved_refuge.withdraw_banked_material_to_run(
			&"test_refuge_material",
			1
		)
		if resolved_refuge != null
		else "missing"
	)
	var defeat_inventory := RunInventoryState.new()
	var defeat_inventory_error: String = defeat_inventory.initialize(
		catalog,
		heroine_ids
	)
	if defeat_inventory_error.is_empty():
		defeat_inventory_error = defeat_inventory.add_to_material_pouch(
			&"test_refuge_material",
			4
		)
	if defeat_inventory_error.is_empty():
		defeat_inventory_error = defeat_inventory.add_to_key_chain(
			&"test_persistent_refuge_key",
			1
		)
	var defeat_equipment := RunEquipmentState.new()
	var defeat_equipment_error: String = defeat_equipment.initialize(
		BATTLER_CATALOG,
		heroine_ids,
		defeat_inventory
	)
	var defeat_resolution: Dictionary = (
		resolved_refuge.make_run_return_transfer(
			defeat_inventory,
			defeat_equipment,
			true
		)
		if resolved_refuge != null
		else {"error": "missing"}
	)
	var defeat_refuge: RefugeOwnershipState = defeat_resolution.get(
		"refuge_state"
	) as RefugeOwnershipState
	var defeat_resolved_inventory: RunInventoryState = defeat_resolution.get(
		"run_inventory"
	) as RunInventoryState
	_expect(
		initialize_error.is_empty()
		and inventory_error.is_empty()
		and equipment_error.is_empty()
		and String(resolution.get("error", "")).is_empty()
		and bank_before == 3
		and resolved_inventory.material_pouch.is_empty()
		and not withdrawal_error.is_empty()
		and resolved_refuge.get_banked_material_quantity(
			&"test_refuge_material"
		) == bank_before
		and defeat_inventory_error.is_empty()
		and defeat_equipment_error.is_empty()
		and String(defeat_resolution.get("error", "")).is_empty()
		and defeat_refuge.get_banked_material_quantity(
			&"test_refuge_material"
		) == 7
		and int(defeat_refuge.key_chain.get(
			"test_persistent_refuge_key",
			0
		)) == 1
		and defeat_resolved_inventory.material_pouch.is_empty(),
		"Voluntary return and defeat must bank Materials one-way, while defeat preserves only explicitly persistent Keys."
	)


func _make_established_refuge_run(generator: LayerMapGenerator) -> RunState:
	var party: Dictionary = {
		&"lysandra": _heroine_snapshot(10, 4, 73, 8),
		&"mira": _heroine_snapshot(9, 6, 69, 12),
		&"seraphine": _heroine_snapshot(8, 8, 81, 4),
	}
	var run := RunState.new()
	run.initialize(
		27072026,
		generator.generate_bloom_refuge_holding_state(27072026),
		[],
		party
	)
	run.opening_completed = true
	run.bloom = 41
	run.completed_layer_ids = [&"layer_1"]
	run.narrative_state.recruited_heroine_ids = [
		&"lysandra",
		&"mira",
		&"seraphine",
	]
	run.campaign_lifecycle.restore_legacy_refuge(27072026)
	run.campaign_lifecycle.mark_boss_defeated(RunState.BLOOD_NUN_BOSS_ID)
	var save_flags: Dictionary = run.narrative_state.flags_by_scope.get(
		&"save",
		{}
	) as Dictionary
	save_flags[RunState.LAYER_1_COMPLETED_FLAG_ID] = true
	save_flags[RunState.REFUGE_EVER_ESTABLISHED_FLAG_ID] = true
	return run


func _heroine_snapshot(
	hp: int,
	mp: int,
	resolve: int,
	corruption: int
) -> Dictionary:
	return {
		"hp": hp,
		"mp": mp,
		"resolve": resolve,
		"corruption": corruption,
		"item_guard": 0,
		"weapon_damage": 0,
		"weapon_broken": false,
		"armor_damage": 0,
		"armor_broken": false,
		"shield_damage": 0,
		"shield_broken": false,
	}


func _preparation_quantity(
	refuge: RefugeOwnershipState,
	heroine_id: StringName,
	item_id: StringName
) -> int:
	var slots: Array = refuge.preparation_slots_by_heroine.get(heroine_id, []) as Array
	var total: int = 0
	for value: Variant in slots:
		var slot: Dictionary = value as Dictionary
		if StringName(slot.get("item_id", "")) == item_id:
			total += int(slot.get("quantity", 0))
	return total


func _backpack_quantity(
	inventory: RunInventoryState,
	heroine_id: StringName,
	item_id: StringName
) -> int:
	var total: int = 0
	for slot: Dictionary in inventory.get_backpack_snapshot(heroine_id):
		if StringName(slot.get("item_id", "")) == item_id:
			total += int(slot.get("quantity", 0))
	return total


func _refuge_main_hand_condition(
	refuge: RefugeOwnershipState,
	heroine_id: StringName
) -> int:
	var loadout: Dictionary = refuge.equipment_loadouts_by_heroine.get(
		heroine_id,
		{}
	) as Dictionary
	var slots: Dictionary = loadout.get("slots", {}) as Dictionary
	var instance_id: String = String(slots.get("main_hand", ""))
	var instances: Dictionary = loadout.get("instances", {}) as Dictionary
	return int((instances.get(instance_id, {}) as Dictionary).get(
		"current_condition",
		-1
	))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
