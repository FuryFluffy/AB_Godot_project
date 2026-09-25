extends SceneTree


const WINE: DialogueDefinition = preload(
	"res://data/dialogue/layer1_wine_cellar_observation.tres"
)
const LEDGER: DialogueDefinition = preload(
	"res://data/dialogue/layer1_servant_ledger_observation.tres"
)
const CONFESSIONAL: DialogueDefinition = preload(
	"res://data/dialogue/layer1_ruined_confessional.tres"
)
const COAT: DialogueDefinition = preload(
	"res://data/dialogue/layer1_coat_torn_cuff.tres"
)
const WINE_LOOT: RoomLootProfileDefinition = preload(
	"res://data/exploration/loot_profiles/layer1/wine_cellar_loot_profile.tres"
)
const JAILER: BattlerDefinition = preload(
	"res://data/battlers/enemies/jailer.tres"
)


var failures: int = 0


func _init() -> void:
	_test_wine_offer_contract()
	_test_confessional_holy_gate_and_party_effects()
	_test_ledger_and_torn_cuff_campaign_state()
	_test_wine_hotspot_sources()
	_test_jailer_first_run_profile()
	if failures == 0:
		print("Layer 1 novel integration tests passed.")
	else:
		push_error("%d Layer 1 novel integration test(s) failed." % failures)
	quit(failures)


func _test_wine_offer_contract() -> void:
	var context: DialogueContext = _party_context([&"lysandra", &"mira"])
	var runner := DialogueRunner.new()
	var start_error: String = runner.start(WINE, context)
	var accepted: DialogueResult = runner.choose(&"wine_cellar_accept")
	var kinds: Array[int] = []
	for outcome: DialogueOutcomeDefinition in accepted.outcomes:
		kinds.append(outcome.kind)
	_expect(
		start_error.is_empty()
		and kinds.has(DialogueOutcomeDefinition.Kind.RESTORE_ACTIVE_PARTY_FULL)
		and kinds.has(DialogueOutcomeDefinition.Kind.CONSUME_ROOM_ITEM)
		and context.get_flag(&"run", &"wine_cellar_offer_used")
		and context.get_flag(&"save", &"hidden_feeding_flag_minor")
		and context.get_heroine_stat(&"lysandra", &"hp") == 8
		and context.get_heroine_stat(&"mira", &"mp") == 7
		and context.get_heroine_stat(&"lysandra", &"resolve") == 50
		and context.get_heroine_stat(&"mira", &"corruption") == 30,
		"Accepting Wine must consume the room bottle, fully restore the active party, add 10 Resolve/Corruption, and advance feeding knowledge."
	)

	var refusal_context: DialogueContext = _party_context([&"lysandra"])
	var refusal_runner := DialogueRunner.new()
	refusal_runner.start(WINE, refusal_context)
	var refused: DialogueResult = refusal_runner.choose(&"wine_cellar_refuse")
	var refusal_consumes_room_item: bool = false
	for outcome: DialogueOutcomeDefinition in refused.outcomes:
		refusal_consumes_room_item = refusal_consumes_room_item or (
			outcome.kind == DialogueOutcomeDefinition.Kind.CONSUME_ROOM_ITEM
		)
	_expect(
		refusal_context.get_flag(&"run", &"wine_cellar_offer_used")
		and not refusal_context.get_flag(&"save", &"hidden_feeding_flag_minor")
		and not refusal_consumes_room_item
		and refusal_context.get_heroine_stat(&"lysandra", &"resolve") == 40,
		"Refusing Wine must leave the guaranteed bottle and party stats unchanged while spending the offer for this run."
	)


func _test_confessional_holy_gate_and_party_effects() -> void:
	var no_holy_context: DialogueContext = _party_context([&"lysandra", &"mira"])
	var no_holy := DialogueRunner.new()
	var no_holy_error: String = no_holy.start(CONFESSIONAL, no_holy_context)
	var dormant_node: DialogueNodeDefinition = no_holy.get_current_node()
	var dormant_completion: DialogueResult = no_holy.advance()
	_expect(
		no_holy_error.is_empty()
		and dormant_node != null
		and dormant_node.node_id == &"dormant"
		and dormant_completion.completed
		and not no_holy_context.get_flag(&"run", &"ruined_confessional_used")
		and not no_holy_context.get_flag(&"persistent", &"ruined_confessional_completed"),
		"The Confessional must remain dormant and undiscovered without a holy heroine."
	)

	var confess_context: DialogueContext = _party_context([
		&"lysandra", &"mira", &"seraphine",
	])
	var confess := DialogueRunner.new()
	confess.start(CONFESSIONAL, confess_context)
	var confessed: DialogueResult = confess.choose(
		&"ruined_confessional_confess_fully"
	)
	_expect(
		confessed.selected_choice_id == &"ruined_confessional_confess_fully"
		and confess_context.get_flag(&"run", &"ruined_confessional_used")
		and confess_context.get_flag(&"persistent", &"ruined_confessional_completed")
		and confess_context.get_heroine_stat(&"lysandra", &"resolve") == 50
		and confess_context.get_heroine_stat(&"seraphine", &"corruption") == 30,
		"Full confession must add 10 Resolve and 10 Corruption to every active heroine and grant knowledge."
	)

	var refuse_context: DialogueContext = _party_context([
		&"lysandra", &"mira", &"seraphine",
	])
	var refuse := DialogueRunner.new()
	refuse.start(CONFESSIONAL, refuse_context)
	refuse.choose(&"ruined_confessional_refuse")
	_expect(
		refuse_context.get_heroine_stat(&"lysandra", &"resolve") == 55
		and refuse_context.get_heroine_stat(&"mira", &"corruption") == 15,
		"Refusing the Confessional must add 15 Resolve and remove 5 Corruption from every active heroine."
	)


func _test_ledger_and_torn_cuff_campaign_state() -> void:
	var leave_context: DialogueContext = _party_context([&"lysandra"])
	var leave := DialogueRunner.new()
	leave.start(LEDGER, leave_context)
	leave.choose(&"servant_ledger_leave_choice")
	_expect(
		not leave_context.get_flag(&"persistent", &"servant_ledger_read"),
		"Leaving the optional Ledger must not grant its permanent knowledge."
	)

	var read_context: DialogueContext = _party_context([&"lysandra", &"mira"])
	var read := DialogueRunner.new()
	read.start(LEDGER, read_context)
	read.choose(&"servant_ledger_read_choice")
	_expect(
		read_context.get_flag(&"persistent", &"servant_ledger_read")
		and read.get_current_node().node_id == &"mira_callback",
		"Reading the Ledger must grant campaign knowledge and adapt its callback to visit order and party composition."
	)

	var cuff_context: DialogueContext = _party_context([&"lysandra"])
	cuff_context.flags_by_scope[&"persistent"][&"servant_ledger_read"] = true
	var cuff := DialogueRunner.new()
	cuff.start(COAT, cuff_context)
	var cuff_result: DialogueResult = cuff.choose(&"take_torn_cuff")
	var narrative := NarrativeState.new()
	var apply_error: String = narrative.apply_dialogue_result_snapshot(
		cuff_result.to_snapshot()
	)
	var replay_error: String = narrative.apply_dialogue_result_snapshot(
		cuff_result.to_snapshot()
	)
	var before_malformed: Dictionary = narrative.to_snapshot()
	var malformed_error: String = narrative.restore_from_snapshot({
		"recruited_heroine_ids": ["lysandra"],
		"campaign_item_ids": ["l01_torn_cuff", 7],
	})
	_expect(
		apply_error.is_empty()
		and replay_error.is_empty()
		and narrative.campaign_item_ids == [&"l01_torn_cuff"]
		and narrative.has_campaign_item(&"l01_torn_cuff")
		and malformed_error != ""
		and narrative.to_snapshot() == before_malformed,
		"The Torn Cuff must enter capacity-free campaign ownership exactly once and malformed ownership restoration must be transactional."
	)


func _test_wine_hotspot_sources() -> void:
	var optional_sources: int = 0
	var pool_entries: int = 0
	var equal_weights: bool = true
	for source: RoomLootSourceDefinition in WINE_LOOT.sources:
		if String(source.source_id).begins_with("wine_cellar_optional_"):
			optional_sources += 1
			pool_entries = source.pool.entries.size()
			for entry: RoomItemPoolEntryDefinition in source.pool.entries:
				equal_weights = equal_weights and entry.weight == 1
			_expect(
				is_equal_approx(source.activation_chance, 0.65)
				and source.minimum_draws == 1
				and source.maximum_draws == 1,
				"Each optional Wine hotspot must independently make one 65% item draw."
			)
	_expect(
		WINE_LOOT.sources.size() == 4
		and WINE_LOOT.sources[0].fixed_entry_id == &"warm_wine_flask_spawn"
		and optional_sources == 3
		and pool_entries == 9
		and equal_weights,
		"Wine must guarantee one offered flask and expose three independent, equally weighted optional hotspot draws."
	)


func _test_jailer_first_run_profile() -> void:
	var crush: WeaponDefinition = JAILER.default_loadout.main_hand
	var flat_damage := crush.unique_effects[0] as FlatDamageWeaponEffect
	_expect(
		JAILER.max_hp == 48
		and JAILER.base_actions == 2
		and JAILER.attributes.might == 6
		and crush.dice_modifier == 0
		and flat_damage != null
		and flat_damage.added_damage == 1,
		"The first Jailer must use the hard-but-winnable two-action profile rather than the former overwhelming damage loop."
	)


func _party_context(heroine_ids: Array[StringName]) -> DialogueContext:
	var context := DialogueContext.new()
	context.current_party_ids = heroine_ids.duplicate()
	context.recruited_heroine_ids = heroine_ids.duplicate()
	context.flags_by_scope = {&"run": {}, &"save": {}, &"persistent": {}}
	for heroine_id: StringName in heroine_ids:
		var max_hp: int = 8 if heroine_id == &"lysandra" else 5
		var max_mp: int = 8 if heroine_id == &"lysandra" else (7 if heroine_id == &"mira" else 9)
		context.heroine_states[heroine_id] = {
			"hp": 1,
			"mp": 1,
			"max_hp": max_hp,
			"max_mp": max_mp,
			"resolve": 40,
			"corruption": 20,
		}
	return context


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
