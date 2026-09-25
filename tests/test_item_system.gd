extends SceneTree


var failures: int = 0


func _init() -> void:
	_test_catalog_and_six_slot_state()
	_test_inventory_atomicity_and_slot_identity()
	_test_run_inventory_domains_and_authored_loadout()
	_test_run_inventory_stacking_movement_and_atomicity()
	_test_key_material_and_memento_domains()
	_test_authored_key_persistence_scopes()
	_test_rusty_key_lock_uses_key_chain()
	_test_save_envelope_v3_remains_reserved()
	_test_healing_cost_consumption_and_checkpoint()
	_test_item_attack_uses_normal_reaction_pipeline()
	_test_grapple_escape_item_while_attached()
	_test_revival_status_repair_and_guard_effects()

	if failures == 0:
		print("Item and run inventory state tests passed.")
	else:
		push_error(
			"%d Item system test(s) failed." % failures
		)
	quit(failures)


func _test_catalog_and_six_slot_state() -> void:
	var catalog: ItemCatalogDefinition = _load_catalog()
	_expect(catalog != null, "The Layer 1–2 item catalog should load.")
	if catalog == null:
		return
	_expect(
		catalog.validate_catalog().is_empty(),
		"The 33-entry canonical-plus-legacy catalog should pass validation."
	)
	_expect(
		catalog.items.size() == 33,
		"The catalog must contain 32 workbook entries and one legacy item."
	)
	_expect(
		catalog.get_items_for_layer(1).size() == 17,
		"Layer 1 must contain 14 carried items, two Materials, and the shared Rusty Key."
	)
	_expect(
		catalog.get_items_for_layer(2).size() == 16,
		"Layer 2 must contain 13 carried items, two Materials, and the legacy blanket."
	)
	var legacy_blanket: ItemDefinition = catalog.get_item(
		&"quiet_cell_blanket"
	)
	_expect(
		legacy_blanket != null
		and not legacy_blanket.canonical_workbook_item
		and legacy_blanket.content_category
		== ItemDefinition.ContentCategory.LEGACY_DEVELOPMENT,
		"Quiet Cell Blanket must resolve only as legacy/development content."
	)

	var inventory: SixSlotInventoryState = SixSlotInventoryState.new()
	_expect(
		inventory.initialize(catalog).is_empty(),
		"The six-slot inventory should initialize from the catalog."
	)
	var ids: Array[StringName] = [
		&"l01_bandage_roll",
		&"l01_smelling_salts",
		&"l01_warm_wine_flask",
		&"l01_servants_tonic",
		&"l01_red_wax_ampoule",
		&"l01_kitchen_knife",
	]
	var quantities: Array[int] = [2, 1, 1, 1, 1, 1]
	_expect(
		inventory.load_items(ids, quantities).is_empty(),
		"A complete six-item test loadout should fit."
	)
	_expect(
		inventory.slots.size() == SixSlotInventoryState.SLOT_COUNT,
		"The persistent inventory must always expose six slots."
	)
	_expect(
		not inventory.add_item(&"l01_ledger_seal", 1).is_empty(),
		"A seventh distinct item should be rejected while every slot is occupied."
	)
	_expect(
		inventory.get_slot(0).quantity == 2
		and inventory.get_slot(5).item.item_id == &"l01_kitchen_knife",
		"A failed capacity check must not partially mutate the loadout."
	)


func _test_inventory_atomicity_and_slot_identity() -> void:
	var inventory: SixSlotInventoryState = SixSlotInventoryState.new()
	inventory.initialize(_load_catalog())
	var item_ids: Array[StringName] = [
		&"l01_bandage_roll",
		&"",
		&"l01_servants_tonic",
	]
	var quantities: Array[int] = [2, 0, 1]
	_expect(
		inventory.load_items(item_ids, quantities).is_empty(),
		"A loadout may preserve an intentionally empty slot."
	)
	inventory.capture_checkpoint()
	inventory.consume(0, 1)
	var replacement_ids: Array[StringName] = [&"l01_red_wax_ampoule"]
	var replacement_quantities: Array[int] = [1]
	inventory.load_items(replacement_ids, replacement_quantities)
	_expect(
		inventory.restore_checkpoint().is_empty(),
		"A complete six-slot checkpoint should restore."
	)
	_expect(
		inventory.get_slot(0).item.item_id == &"l01_bandage_roll"
		and inventory.get_slot(0).quantity == 2
		and inventory.get_slot(1).is_empty()
		and inventory.get_slot(2).item.item_id == &"l01_servants_tonic",
		"Checkpoint restoration must preserve empty-slot positions."
	)


func _test_run_inventory_domains_and_authored_loadout() -> void:
	var generator := LayerMapGenerator.new()
	var run := RunState.new()
	var initialize_error: String = run.initialize(
		27072026,
		generator.generate_layer_1(27072026),
		generator.make_layer_1_generated_room_item_rules()
	)
	var state: RunInventoryState = run.run_inventory
	var item_bar: Array[Dictionary] = state.get_item_bar_snapshot()
	_expect(
		initialize_error.is_empty()
		and item_bar.size() == RunInventoryState.ITEM_BAR_SLOT_COUNT
		and StringName(item_bar[0].get("item_id", ""))
		== &"l01_bandage_roll"
		and int(item_bar[0].get("quantity", 0)) == 3
		and StringName(item_bar[4].get("item_id", ""))
		== &"l01_red_wax_ampoule",
		"A new run must source the existing authored loadout from RunInventoryState."
	)
	for heroine_id: StringName in [&"lysandra", &"mira", &"seraphine"]:
		var backpack: Array[Dictionary] = state.get_backpack_snapshot(heroine_id)
		_expect(
			backpack.size() == RunInventoryState.BACKPACK_SLOT_COUNT
			and StringName(backpack[0].get("item_id", "")) == &""
			and int(backpack[0].get("quantity", -1)) == 0
			and state.get_memento_id(heroine_id) == &"",
			"Each demo heroine must own 15 explicit backpack slots and one nullable Memento slot."
		)
	_expect(
		state.key_chain.is_empty()
		and state.material_pouch.is_empty()
		and _contains_only_plain_variants(state.get_snapshot()),
		"Key Chain and Material Pouch must start empty and all run inventory state must be plain data."
	)


func _test_run_inventory_stacking_movement_and_atomicity() -> void:
	var state := RunInventoryState.new()
	state.initialize(
		_load_catalog(),
		[&"lysandra", &"mira", &"seraphine"]
	)
	_expect(
		state.add_to_item_bar(&"l01_bandage_roll", 5).is_empty(),
		"Item Bar additions should use authored stack limits."
	)
	var item_bar: Array[Dictionary] = state.get_item_bar_snapshot()
	_expect(
		int(item_bar[0].get("quantity", 0)) == 4
		and int(item_bar[1].get("quantity", 0)) == 1,
		"Item Bar additions must fill stacks and empty slots in deterministic order."
	)
	_expect(
		state.remove_from_item_bar(&"l01_bandage_roll", 3).is_empty(),
		"Item Bar removal should succeed when enough quantity exists."
	)
	item_bar = state.get_item_bar_snapshot()
	_expect(
		int(item_bar[0].get("quantity", 0)) == 1
		and int(item_bar[1].get("quantity", 0)) == 1,
		"Item Bar removal must consume from deterministic slot order."
	)

	var item_bar_before_backpack: Array[Dictionary] = (
		state.get_item_bar_snapshot()
	)
	var backpack_add_error: String = state.add_to_backpack(
		&"lysandra",
		&"l01_bandage_roll",
		5
	)
	_expect(
		backpack_add_error.is_empty()
		and state.get_item_bar_snapshot() == item_bar_before_backpack,
		"Personal backpack contents must remain excluded from the combat Item Bar."
	)
	_expect(
		state.move_backpack_to_item_bar(
			&"lysandra",
			&"l01_bandage_roll",
			2
		).is_empty()
		and state.move_item_bar_to_backpack(
			&"lysandra",
			&"l01_bandage_roll",
			1
		).is_empty(),
		"Backpack/Item Bar movement must preserve personal ownership and quantity."
	)
	var mira_before: Array[Dictionary] = state.get_backpack_snapshot(&"mira")
	var full_before: Dictionary = state.get_snapshot()
	var capacity_error: String = state.add_to_backpack(
		&"mira",
		&"l01_bandage_roll",
		61
	)
	_expect(
		not capacity_error.is_empty()
		and state.get_backpack_snapshot(&"mira") == mira_before
		and state.get_snapshot() == full_before,
		"A failed backpack capacity check must not partially mutate any domain."
	)
	var move_before: Dictionary = state.get_snapshot()
	var move_error: String = state.move_backpack_to_item_bar(
		&"lysandra",
		&"l01_bandage_roll",
		99
	)
	_expect(
		not move_error.is_empty()
		and state.get_snapshot() == move_before,
		"A failed cross-domain move must leave both source and destination unchanged."
	)
	_expect(
		not state.add_to_item_bar(&"shared_rusty_key", 1).is_empty()
		and not state.add_to_item_bar(&"l01_courtesy_collar", 1).is_empty()
		and not state.add_to_item_bar(
			StringName("bandage" + "_roll"),
			1
		).is_empty()
		and not state.add_to_item_bar(&"quiet_cell_blanket", 1).is_empty(),
		"The Item Bar must reject keys, Mementos, legacy aliases, and isolated legacy content."
	)


func _test_key_material_and_memento_domains() -> void:
	var catalog: ItemCatalogDefinition = _make_material_test_catalog()
	var state := RunInventoryState.new()
	state.initialize(catalog, [&"lysandra", &"mira", &"seraphine"])
	_expect(
		state.route_reward(&"shared_rusty_key", 2).is_empty()
		and state.get_key_quantity(&"shared_rusty_key") == 2
		and _snapshot_quantity(
			state.get_item_bar_snapshot(),
			&"shared_rusty_key"
		) == 0,
		"Key-compatible rewards must route exclusively to the shared Key Chain."
	)
	_expect(
		state.route_reward(&"test_only_material_stable_id", 3).is_empty()
		and int(state.material_pouch.get(
			"test_only_material_stable_id",
			0
		)) == 3
		and not state.add_to_item_bar(
			&"test_only_material_stable_id",
			1
		).is_empty(),
		"Material-compatible rewards must route to the pouch and be rejected by ordinary slots."
	)
	_expect(
		state.assign_memento(&"mira", &"l01_courtesy_collar").is_empty()
		and state.get_memento_id(&"mira") == &"l01_courtesy_collar"
		and not state.assign_memento(
			&"mira",
			&"l01_chapel_rosary"
		).is_empty()
		and not state.assign_memento(
			&"unknown_heroine",
			&"l01_chapel_rosary"
		).is_empty()
		and not state.assign_memento(
			&"lysandra",
			&"l01_bandage_roll"
		).is_empty(),
		"Memento slots must validate item type, personal ownership, and one-slot capacity."
	)


func _test_authored_key_persistence_scopes() -> void:
	var catalog: ItemCatalogDefinition = _load_catalog()
	var key_ids: Array[StringName] = []
	var all_keys_are_explicitly_run_only: bool = true
	for item: ItemDefinition in catalog.items:
		if item.content_category != ItemDefinition.ContentCategory.KEY:
			continue
		key_ids.append(item.item_id)
		all_keys_are_explicitly_run_only = (
			all_keys_are_explicitly_run_only
			and item.key_persistence_scope
			== ItemDefinition.KeyPersistenceScope.RUN_ONLY
		)
	key_ids.sort()
	_expect(
		all_keys_are_explicitly_run_only
		and key_ids.size() == 3
		and key_ids.has(&"l01_ledger_seal")
		and key_ids.has(&"l02_guiltless_key")
		and key_ids.has(&"shared_rusty_key"),
		"Every currently registered Key must explicitly preserve its ordinary run-only loss scope."
	)


func _test_rusty_key_lock_uses_key_chain() -> void:
	var screen := EventRoomScreen.new()
	var state := RunInventoryState.new()
	state.initialize(_load_catalog(), [&"lysandra", &"mira", &"seraphine"])
	state.add_to_key_chain(&"shared_rusty_key", 1)
	screen.run_inventory = state
	screen.instance_state = EventRoomInstanceState.new()
	var room_lock := RoomLockHotspot.new()
	room_lock.lock_id = &"test_rusty_lock"
	room_lock.required_item_id = &"shared_rusty_key"
	var unlock_error: String = screen._try_unlock_room_lock(room_lock)
	_expect(
		unlock_error.is_empty()
		and room_lock.is_unlocked
		and state.get_key_quantity(&"shared_rusty_key") == 0
		and bool((screen.instance_state.local_state.get(
			"locks",
			{}
		) as Dictionary).get("test_rusty_lock", false)),
		"The authored Rusty Key lock must consume from the Key Chain, not the Item Bar."
	)
	screen.free()
	room_lock.free()


func _test_save_envelope_v3_remains_reserved() -> void:
	var envelope: Dictionary = CampaignSaveSlotStore.make_v3_envelope(
		1,
		{"existing_campaign_state": true},
		27072026,
		100,
		101
	)
	_expect(
		envelope.has("active_run_snapshot")
		and envelope.get("active_run_snapshot") == null
		and (envelope.get("refuge_snapshot", {}) as Dictionary).is_empty()
		and not (envelope.get("campaign_snapshot", {}) as Dictionary).has(
			"run_inventory_snapshot"
		),
		"Milestone 3 must leave Save Envelope v3 reserved fields unchanged."
	)


func _test_healing_cost_consumption_and_checkpoint() -> void:
	var fixture: Dictionary = _make_fixture(
		[&"l01_bandage_roll"],
		[2]
	)
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var items: ItemUseController = fixture.get(
		"items"
	) as ItemUseController
	var inventory: SixSlotInventoryState = fixture.get(
		"inventory"
	) as SixSlotInventoryState
	var lysandra: BattlerState = battlers.get(
		&"lysandra"
	) as BattlerState
	lysandra.apply_damage(2)
	var hp_before: int = lysandra.current_hp
	var actions_before: int = lysandra.current_actions
	inventory.capture_checkpoint()

	var result: ItemUseResult = items.use_item(
		&"lysandra",
		&"lysandra",
		0
	)
	_expect(result.succeeded, "Bandage Roll should resolve on its user.")
	_expect(
		lysandra.current_hp == hp_before + 2,
		"Bandage Roll should restore its authored 2 HP."
	)
	_expect(
		lysandra.current_actions == actions_before - 1,
		"Bandage Roll should spend one Action."
	)
	_expect(
		inventory.get_slot(0).quantity == 1,
		"Successful use should consume one item."
	)
	_expect(
		inventory.restore_checkpoint().is_empty()
		and inventory.get_slot(0).quantity == 2,
		"Restart checkpoint restoration should restore item quantities."
	)


func _test_item_attack_uses_normal_reaction_pipeline() -> void:
	var fixture: Dictionary = _make_fixture(
		[&"l01_red_wax_ampoule"],
		[1]
	)
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var items: ItemUseController = fixture.get(
		"items"
	) as ItemUseController
	var resolver: AttackResolver = fixture.get(
		"resolver"
	) as AttackResolver
	var inventory: SixSlotInventoryState = fixture.get(
		"inventory"
	) as SixSlotInventoryState
	battlefield.place_battler(
		&"hollow_servant",
		&"altar_left",
		2
	)
	var mira: BattlerState = battlers.get(&"mira") as BattlerState
	var hollow: BattlerState = battlers.get(
		&"hollow_servant"
	) as BattlerState
	hollow.armor_state = null
	var context: ReactionContext = items.prepare_item_attack(
		&"mira",
		&"hollow_servant",
		0
	)
	_expect(
		context.is_valid,
		"Red-Wax Ampoule should commit through AttackResolver."
	)
	if not context.is_valid:
		return
	_expect(
		context.request.source == ActionRequest.Source.ITEM,
		"Offensive items require an explicit ITEM Action source."
	)
	_expect(
		mira.current_actions == 2,
		"Preparing the Item Attack should spend its one Action."
	)
	var attack_result: ActionResult = resolver.resolve_reaction(
		context,
		mira,
		hollow,
		DefenseChoice.Type.SKIP
	)
	var item_result: ItemUseResult = (
		items.complete_pending_item_attack(attack_result)
	)
	_expect(
		item_result.succeeded,
		"The item stack should complete after reaction resolution."
	)
	_expect(
		inventory.get_slot(0).is_empty(),
		"The offensive item should be consumed only after resolution."
	)


func _test_grapple_escape_item_while_attached() -> void:
	var fixture: Dictionary = _make_fixture(
		[&"l01_kitchen_knife"],
		[1]
	)
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var battlefield: BattlefieldState = fixture.get(
		"battlefield"
	) as BattlefieldState
	var grapple: GrappleController = fixture.get(
		"grapple"
	) as GrappleController
	var items: ItemUseController = fixture.get(
		"items"
	) as ItemUseController
	battlefield.place_battler(
		&"hollow_servant",
		&"altar_left",
		2
	)
	var attempt: GrappleAttemptResult = grapple.prepare_initiation(
		&"hollow_servant",
		&"lysandra"
	)
	_expect(
		attempt.error_message.is_empty(),
		"The escape-item fixture should create a Grapple."
	)
	if not attempt.error_message.is_empty():
		return
	grapple.resolve_initiation(false)
	var lysandra: BattlerState = battlers.get(
		&"lysandra"
	) as BattlerState
	lysandra.set_current_actions(3)
	var result: ItemUseResult = items.use_item(
		&"lysandra",
		&"hollow_servant",
		0
	)
	_expect(
		result.succeeded,
		"A grappled heroine should be able to use Kitchen Knife."
	)
	_expect(
		not lysandra.is_grappled()
		and not grapple.has_active_tracks(),
		"Kitchen Knife's explicit Grapple hook should detach its target."
	)
	_expect(
		lysandra.current_resolve == 100,
		"Kitchen Knife should apply its separately authored Resolve gain."
	)


func _test_revival_status_repair_and_guard_effects() -> void:
	var fixture: Dictionary = _make_fixture(
		[
			&"l01_smelling_salts",
			&"l01_wax_sealed_needle",
			&"l01_repair_thread_wax",
			&"l01_polished_serving_tray",
		],
		[1, 1, 1, 1]
	)
	var battlers: Dictionary = fixture.get("battlers") as Dictionary
	var items: ItemUseController = fixture.get(
		"items"
	) as ItemUseController
	var statuses: StatusController = fixture.get(
		"statuses"
	) as StatusController
	var lysandra: BattlerState = battlers.get(
		&"lysandra"
	) as BattlerState
	var mira: BattlerState = battlers.get(&"mira") as BattlerState

	mira.apply_damage(mira.current_hp)
	var revive_result: ItemUseResult = items.use_item(
		&"lysandra",
		&"mira",
		0
	)
	_expect(
		revive_result.succeeded
		and not mira.is_defeated
		and mira.current_hp == 2,
		"Smelling Salts should explicitly Revive an Adjacent heroine."
	)

	lysandra.set_current_actions(3)
	lysandra.apply_damage(1)
	statuses.apply_status(
		lysandra,
		load("res://data/statuses/bleed.tres") as StatusDefinition,
		&"item_test_source"
	)
	var needle_result: ItemUseResult = items.use_item(
		&"lysandra",
		&"lysandra",
		1
	)
	_expect(
		needle_result.succeeded
		and not lysandra.has_status_kind(StatusDefinition.Kind.BLEED),
		"Wax-Sealed Needle should remove Bleed."
	)

	lysandra.set_current_actions(3)
	lysandra.damage_armor(2)
	var armor_damage_before: int = (
		lysandra.armor_state.absorbed_damage
	)
	var repair_result: ItemUseResult = items.use_item(
		&"lysandra",
		&"lysandra",
		2
	)
	_expect(
		repair_result.succeeded
		and lysandra.armor_state.absorbed_damage
		< armor_damage_before,
		"Repair Thread and Wax should restore armor condition."
	)

	lysandra.set_current_actions(3)
	var guard_result: ItemUseResult = items.use_item(
		&"lysandra",
		&"lysandra",
		3
	)
	var hp_before_guard_hit: int = lysandra.current_hp
	lysandra.apply_damage(2)
	_expect(
		guard_result.succeeded
		and lysandra.current_hp == hp_before_guard_hit
		and lysandra.item_guard_points == 0,
		"Polished Serving Tray should absorb two HP damage."
	)


func _make_fixture(
	item_ids: Array,
	quantities: Array
) -> Dictionary:
	var definitions: Array[BattlerDefinition] = [
		load(
			"res://data/battlers/heroines/lysandra.tres"
		) as BattlerDefinition,
		load(
			"res://data/battlers/heroines/mira.tres"
		) as BattlerDefinition,
		load(
			"res://data/battlers/heroines/seraphine.tres"
		) as BattlerDefinition,
		load(
			"res://data/battlers/enemies/hollow_servant.tres"
		) as BattlerDefinition,
		load(
			"res://data/battlers/enemies/knife_footman.tres"
		) as BattlerDefinition,
		load(
			"res://data/battlers/enemies/prayer_rag_novice.tres"
		) as BattlerDefinition,
	]
	var order: Array[StringName] = [
		&"lysandra",
		&"mira",
		&"seraphine",
		&"hollow_servant",
		&"knife_footman",
		&"prayer_rag_novice",
	]
	var battlers: Dictionary = BattleBootstrap.new().create_battler_states(
		definitions
	)
	var runtime: BattleRuntimeState = BattleRuntimeState.new()
	var dice: DiceResolver = DiceResolver.new()
	var flow: BattleFlowController = BattleFlowController.new()
	flow.initialize(
		battlers,
		runtime.battle_state,
		dice,
		1100
	)
	flow.start_encounter(
		BattleFlowController.OrderMode.FORCE_PARTY_FIRST
	)
	var battlefield: BattlefieldState = BattlefieldState.new()
	battlefield.initialize(
		load(
			"res://data/battlefields/ruined_chapel_spatial_test.tres"
		) as BattlefieldDefinition,
		battlers
	)
	var targeting: BattleTargetingController = BattleTargetingController.new()
	targeting.initialize(battlers, battlefield)
	var statuses: StatusController = StatusController.new()
	statuses.initialize(battlers, order)
	var grapple: GrappleController = GrappleController.new()
	grapple.initialize(
		battlers,
		battlefield,
		targeting,
		dice,
		1200
	)
	var resolver: AttackResolver = AttackResolver.new()
	resolver.dice_resolver = dice
	resolver.status_controller = statuses
	resolver.set_test_roll_mode(
		AttackResolver.TestRollMode.FORCE_ATTACK_HIT
	)
	var lifecycle: BattleLifecycleController = (
		BattleLifecycleController.new()
	)
	lifecycle.initialize(
		battlers,
		order,
		runtime.battle_state,
		runtime,
		battlefield,
		statuses,
		grapple
	)
	var inventory: SixSlotInventoryState = SixSlotInventoryState.new()
	inventory.initialize(_load_catalog())
	var typed_item_ids: Array[StringName] = []
	typed_item_ids.assign(item_ids)
	var typed_quantities: Array[int] = []
	typed_quantities.assign(quantities)
	inventory.load_items(typed_item_ids, typed_quantities)
	var items: ItemUseController = ItemUseController.new()
	items.initialize(
		battlers,
		inventory,
		runtime,
		flow,
		battlefield,
		targeting,
		resolver,
		statuses,
		grapple,
		lifecycle,
		1300
	)
	return {
		"battlers": battlers,
		"runtime": runtime,
		"flow": flow,
		"battlefield": battlefield,
		"targeting": targeting,
		"statuses": statuses,
		"grapple": grapple,
		"resolver": resolver,
		"lifecycle": lifecycle,
		"inventory": inventory,
		"items": items,
	}


func _load_catalog() -> ItemCatalogDefinition:
	return load(
		"res://data/items/layer_1_2_item_catalog.tres"
	) as ItemCatalogDefinition


func _make_material_test_catalog() -> ItemCatalogDefinition:
	var source: ItemCatalogDefinition = _load_catalog()
	var result := ItemCatalogDefinition.new()
	result.items.assign(source.items)
	var material := source.get_item(&"l01_torn_cuff").duplicate(
		true
	) as ItemDefinition
	material.item_id = &"test_only_material_stable_id"
	material.display_name = "Test-only Material"
	material.content_category = ItemDefinition.ContentCategory.MATERIAL
	material.item_type = ItemDefinition.ItemType.PASSIVE
	material.consumes_on_use = false
	material.combat_usable = false
	material.stack_limit = 9
	result.items.append(material)
	return result


func _snapshot_quantity(
	slots: Array[Dictionary],
	item_id: StringName
) -> int:
	var quantity: int = 0
	for slot: Dictionary in slots:
		if StringName(slot.get("item_id", "")) == item_id:
			quantity += int(slot.get("quantity", 0))
	return quantity


func _contains_only_plain_variants(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_ARRAY:
			for entry: Variant in (value as Array):
				if not _contains_only_plain_variants(entry):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in (value as Dictionary).keys():
				if not _contains_only_plain_variants(key):
					return false
				if not _contains_only_plain_variants(
					(value as Dictionary)[key]
				):
					return false
			return true
	return false


func _expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
