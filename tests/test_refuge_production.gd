extends "res://tests/test_inventory_transfers.gd"
## Synthetic recipe mappings are process-local test data, never campaign content.
const CLOTH: StringName = &"mat_l01_servant_cloth"
const WAX: StringName = &"mat_l01_red_wax"
var fixture_recipe: RefugeRecipeDefinition

func _run() -> void:
	_fixture()
	_expect(controller.get_production_entries(RefugeRecipeDefinition.Station.ALCHEMY).is_empty() and controller.get_production_entries(RefugeRecipeDefinition.Station.CRAFTING).is_empty(), "Production catalog remains empty pending authored recipes.")
	fixture_recipe = make_recipe(RefugeRecipeDefinition.Station.CRAFTING, &"fixture:production", StringName(A))
	controller.RECIPE_CATALOG.recipes.append(fixture_recipe)
	_test_validation_and_transaction()
	_test_explicit_provider()
	await _test_production_ui()
	controller.RECIPE_CATALOG.recipes.erase(fixture_recipe)
	print("Stage 06 Refuge production: %d failures." % failures)
	quit(failures)

func make_recipe(station: RefugeRecipeDefinition.Station, id: StringName, output: StringName) -> RefugeRecipeDefinition:
	var recipe := RefugeRecipeDefinition.new()
	recipe.recipe_id = id
	recipe.display_name = "Fixture recipe — not game content"
	recipe.action = RefugeRecipeDefinition.Action.PRODUCE_ITEM
	recipe.station = station
	recipe.material_inputs = {String(CLOTH): 2, String(WAX): 1}
	recipe.output_item_id = output
	recipe.output_quantity = 3
	return recipe

func _produce(expected: Dictionary = {}) -> Dictionary:
	return controller.produce_item(fixture_recipe.station, fixture_recipe.recipe_id, run.refuge_ownership.to_snapshot() if expected.is_empty() else expected)

func _test_validation_and_transaction() -> void:
	_fixture()
	_expect(fixture_recipe.validate_definition(controller.MATERIAL_CATALOG, ITEMS).is_empty(), "Production definition validates canonical item and Materials.")
	var invalid: RefugeRecipeDefinition = fixture_recipe.duplicate(true)
	invalid.output_item_id = CLOTH
	_expect(not invalid.validate_definition(controller.MATERIAL_CATALOG, ITEMS).is_empty(), "Production cannot disguise Materials as ordinary output.")
	invalid.output_item_id = StringName(M)
	_expect(not invalid.validate_definition(controller.MATERIAL_CATALOG, ITEMS).is_empty(), "Production does not author Mementos or equipment.")
	invalid.output_item_id = &"missing:item"
	_expect(not invalid.validate_definition(controller.MATERIAL_CATALOG, ITEMS).is_empty(), "Unknown output fails validation.")
	invalid.output_item_id = StringName(A)
	invalid.output_quantity = 0
	_expect(not invalid.validate_definition(controller.MATERIAL_CATALOG, ITEMS).is_empty(), "Zero output rejected.")
	var before: Dictionary = run.refuge_ownership.to_snapshot()
	_expect(not String(_produce().error).is_empty() and before == run.refuge_ownership.to_snapshot() and saves == 0, "Insufficient inputs create nothing and do not save.")
	run.refuge_ownership.banked_materials = {String(CLOTH): 5, String(WAX): 4}
	var cap: int = ITEMS.get_item(StringName(A)).stack_limit
	run.refuge_ownership.add_stash_item(StringName(A), cap - 1)
	for index: int in range(15):
		run.refuge_ownership.preparation_slots_by_heroine[&"lysandra"][index] = _slot(index, A, cap)
	before = run.refuge_ownership.to_snapshot()
	fail_save = true
	_expect(String(_produce().error) == "Injected save failure" and before == run.refuge_ownership.to_snapshot() and saves == 1, "Save failure rolls back all inputs and output stacks.")
	fail_save = false
	var result: Dictionary = _produce()
	var state: RefugeOwnershipState = run.refuge_ownership
	_expect(String(result.error).is_empty() and saves == 2 and state.stash_item_stacks.size() == 2 and state.stash_item_stacks[0].quantity == cap and state.stash_item_stacks[1].quantity == 2, "Production fills existing Stash stack first, then adds exact remainder despite full Backpack.")
	_expect(state.get_banked_material_quantity(CLOTH) == 3 and state.get_banked_material_quantity(WAX) == 3 and state.preparation_slots_by_heroine[&"lysandra"] == before.heroine_records.lysandra.preparation_slots, "Both authored inputs consumed once; carried items unchanged.")
	var after: Dictionary = state.to_snapshot()
	_expect(not String(_produce(before).error).is_empty() and state.to_snapshot() == after and saves == 2, "Repeated stale request cannot create duplicates.")
	_expect(not String(controller.produce_item(RefugeRecipeDefinition.Station.ALCHEMY, fixture_recipe.recipe_id, after).error).is_empty(), "Wrong-station execution rejected.")
	_expect(controller.get_recipe_entries().size() == 1 and controller.get_repair_target_entries(fixture_recipe.recipe_id).is_empty(), "Production recipes never appear as repair services.")
	var restored := RefugeOwnershipState.new()
	_expect(restored.restore_from_snapshot(JSON.parse_string(JSON.stringify(saved)), ITEMS, BATTLERS, HEROES).is_empty() and restored.to_snapshot() == after, "Inputs/output round-trip through unchanged ownership schema.")
	result = controller.transfer_item(&"stash", &"preparation", &"mira", StringName(A), 1)
	_expect(String(result.error).is_empty(), "Produced items use existing Stash-to-Backpack transfer.")

func _test_explicit_provider() -> void:
	var provider := IsolatedProvider.new()
	provider.item_catalog = ITEMS
	provider.material_catalog = controller.MATERIAL_CATALOG
	provider.materials = {String(CLOTH): 2, String(WAX): 1}
	var refuge_before: Dictionary = run.refuge_ownership.to_snapshot()
	provider.capacity = 2
	_expect(not String(fixture_recipe.execute_production(provider).error).is_empty() and provider.materials[String(CLOTH)] == 2 and provider.outputs.is_empty(), "Provider output capacity failure cannot consume inputs.")
	provider.capacity = 10
	provider.reject_debit = true
	_expect(not String(fixture_recipe.execute_production(provider).error).is_empty() and provider.materials[String(CLOTH)] == 2 and provider.outputs.is_empty(), "Input failure discards the staged output too.")
	provider.reject_debit = false
	_expect(String(fixture_recipe.execute_production(provider).error).is_empty() and provider.outputs[String(A)] == 3 and provider.materials[String(CLOTH)] == 0 and run.refuge_ownership.to_snapshot() == refuge_before, "Explicit alternate provider cannot touch Refuge bank or Stash.")
	_expect(not String(fixture_recipe.execute_production(RecipeProductionProvider.new()).error).is_empty(), "Unbound provider fails closed; no implicit remote storage.")

func _test_production_ui() -> void:
	_fixture()
	run.refuge_ownership.banked_materials = {String(CLOTH): 4, String(WAX): 2}
	var screen := load("res://scenes/refuge/bloom_refuge_screen.tscn").instantiate() as BloomRefugeScreen
	root.add_child(screen)
	await process_frame
	_expect(screen.present(run, BATTLERS, KnowledgeState.new(), false, controller).is_empty(), "Bind production station UI.")
	var alchemy: RefugeProductionView = screen.production_views[0]
	var crafting: RefugeProductionView = screen.production_views[1]
	_expect(alchemy.entries.is_empty() and alchemy.action_button.disabled and crafting.entries.size() == 1, "Separate station lists: empty Alchemy cannot brew Crafting recipes.")
	screen.room_shell.open_station(&"crafting")
	await process_frame
	var before: Dictionary = run.refuge_ownership.to_snapshot()
	crafting.recipes.item_selected.emit(0)
	_expect(before == run.refuge_ownership.to_snapshot() and saves == 0 and crafting.result_label.text.contains("×3"), "Preview shows exact result without consuming anything.")
	screen.handle_cancel()
	_expect(before == run.refuge_ownership.to_snapshot() and root.gui_get_focus_owner() == screen.room_shell.hotspots[&"crafting"], "Cancel restores separate toolbox focus without consuming anything.")
	screen.room_shell.open_station(&"crafting")
	crafting.action_button.pressed.emit()
	_expect(saves == 1 and run.refuge_ownership.get_banked_material_quantity(CLOTH) == 2, "Explicit Craft persists once.")
	screen.set_actions_enabled(false)
	crafting.action_button.pressed.emit()
	_expect(crafting.action_button.disabled and saves == 1, "Disabled service cannot commit.")
	screen.queue_free()
	await process_frame

class IsolatedProvider extends RecipeProductionProvider:
	var materials: Dictionary = {}
	var outputs: Dictionary = {}
	var capacity: int = 0
	var reject_debit: bool = false
	func fork() -> RecipeProductionProvider:
		var copy := IsolatedProvider.new()
		copy.item_catalog = item_catalog
		copy.material_catalog = material_catalog
		copy.materials = materials.duplicate(true)
		copy.outputs = outputs.duplicate(true)
		copy.capacity = capacity
		copy.reject_debit = reject_debit
		return copy
	func material_quantity(id: StringName) -> int:
		return int(materials.get(String(id), 0))
	func consume_material(id: StringName, quantity: int) -> String:
		if reject_debit:
			return "Injected debit failure"
		materials[String(id)] = material_quantity(id) - quantity
		return ""
	func store_output(id: StringName, quantity: int) -> String:
		if quantity > capacity:
			return "Insufficient output capacity"
		outputs[String(id)] = quantity
		return ""
	func publish(staged: RecipeProductionProvider) -> String:
		materials = (staged as IsolatedProvider).materials.duplicate(true)
		outputs = (staged as IsolatedProvider).outputs.duplicate(true)
		return ""
