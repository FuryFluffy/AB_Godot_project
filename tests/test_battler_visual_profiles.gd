extends SceneTree


const VISUAL_CATALOG_PATH := (
	"res://data/presentation/battler_visual_profile_catalog.tres"
)
const BATTLER_CATALOG_PATH := "res://data/battlers/battler_catalog.tres"
const PROFILED_BATTLERS: Array[StringName] = [
	&"lysandra",
	&"mira",
	&"seraphine",
	&"hollow_servant",
	&"knife_footman",
	&"prayer_rag_novice",
	&"corrupted_butler",
	&"red_wax_acolyte",
	&"blood_nun",
	&"chain_thrall",
	&"iron_masked_guard",
	&"cell_slime",
	&"jailer",
]


var failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := load(VISUAL_CATALOG_PATH) as BattlerVisualProfileCatalog
	var battlers := load(BATTLER_CATALOG_PATH) as BattlerCatalogDefinition
	_test_catalog_coverage(catalog, battlers)
	_test_deterministic_resolution(catalog)
	_test_marker_only_safety(catalog, battlers)
	_test_invalid_definitions_are_rejected(catalog, battlers)
	_test_presentation_intent(catalog)
	_test_runtime_renderer_is_activated()
	if failures == 0:
		print("Battler Visual Profile tests passed.")
	else:
		push_error("%d Battler Visual Profile test(s) failed." % failures)
	quit(failures)


func _test_catalog_coverage(
	catalog: BattlerVisualProfileCatalog,
	battlers: BattlerCatalogDefinition
) -> void:
	_expect(catalog != null, "The battler visual profile catalog should load.")
	_expect(battlers != null, "The production battler catalog should load.")
	if catalog == null or battlers == null:
		return
	_expect(
		catalog.validate_definition(battlers).is_empty(),
		"The production battler visual profile catalog should validate: %s"
		% catalog.validate_definition(battlers)
	)
	_expect(
		catalog.required_battler_ids.size() == 14,
		"The visual roster should cover exactly the fourteen requested battlers."
	)
	_expect(
		catalog.profiles.size() == 13
		and catalog.allowed_marker_only_battler_ids == [&"chain_warden"],
		"All thirteen curated archives should register, with only Chain Warden marker-only."
	)
	for battler_id: StringName in PROFILED_BATTLERS:
		var profile: BattlerVisualProfile = catalog.get_profile(battler_id)
		_expect(
			profile != null and not profile.development_placeholder,
			"Profiled battler '%s' should use its approved curated sprite set."
			% battler_id
		)


func _test_deterministic_resolution(
	catalog: BattlerVisualProfileCatalog
) -> void:
	if catalog == null:
		return
	for battler_id: StringName in PROFILED_BATTLERS:
		var direct: Dictionary = catalog.resolve_visual(
			battler_id,
			&"idle",
			&"front",
			&"test_instance"
		)
		_expect(
			String(direct.get("error", "")).is_empty()
			and direct.get("texture") != null
			and direct.get("status") == &"production_texture",
			"Profile '%s' should resolve its existing idle/front texture."
			% battler_id
		)
		var fallback: Dictionary = catalog.resolve_visual(
			battler_id,
			&"block",
			&"back",
			&"test_instance"
		)
		_expect(
			fallback.get("resolved_pose_key") == &"defend"
			and fallback.get("resolved_orientation_key") == &"back"
			and fallback.get("used_fallback", false),
			"Profile '%s' should deterministically fall back block/back to defend/back."
			% battler_id
		)
		_expect(
			direct.get("render_key") == fallback.get("render_key")
			and direct.get("render_key") == StringName(
				"%s::test_instance" % battler_id
			),
			"Render identity should be stable across pose changes for '%s'."
			% battler_id
		)


func _test_marker_only_safety(
	catalog: BattlerVisualProfileCatalog,
	battlers: BattlerCatalogDefinition
) -> void:
	if catalog == null:
		return
	var placeholder: Dictionary = catalog.resolve_visual(
		&"chain_warden",
		&"hurt",
		&"back",
		&"enemy_1"
	)
	_expect(
		String(placeholder.get("error", "")).is_empty()
		and placeholder.get("status") == catalog.MARKER_ONLY_STATUS
		and placeholder.get("texture") == null,
		"An explicitly deferred battler should safely resolve to marker-only presentation."
	)
	var unknown: Dictionary = catalog.resolve_visual(
		&"not_a_battler",
		&"idle",
		&"front"
	)
	_expect(
		not String(unknown.get("error", "")).is_empty()
		and unknown.get("texture") == null,
		"An unknown battler should fail safely without a texture or crash."
	)
	var diagnostics: Array[String] = catalog.get_development_diagnostics(battlers)
	_expect(
		diagnostics.size() == 2
		and _contains_text(diagnostics, "cell_slime")
		and _contains_text(diagnostics, "BattlerDefinition is also deferred"),
		"Diagnostics should expose the deferred Cell Slime definition and Chain Warden art gap."
	)


func _test_invalid_definitions_are_rejected(
	catalog: BattlerVisualProfileCatalog,
	battlers: BattlerCatalogDefinition
) -> void:
	if catalog == null or battlers == null:
		return
	var source: BattlerVisualProfile = catalog.get_profile(&"lysandra")
	var malformed := BattlerVisualProfile.new()
	malformed.profile_id = &"malformed"
	malformed.battler_id = &"lysandra"
	malformed.supported_pose_keys = [&"idle"]
	malformed.supported_orientation_keys = [&"front"]
	malformed.floor_contact_pivot = Vector2(1.2, 1.0)
	malformed.states = source.states.duplicate()
	_expect(
		"non-normalized floor pivot" in malformed.validate_definition(),
		"Out-of-range floor pivots should be rejected."
	)
	malformed.floor_contact_pivot = Vector2(0.5, 1.0)
	malformed.baseline_scale = Vector2.ZERO
	_expect(
		"positive baseline scale" in malformed.validate_definition(),
		"Non-positive profile scales should be rejected."
	)

	var missing_texture := BattlerVisualStateDefinition.new()
	_expect(
		"has no texture" in missing_texture.validate_definition(),
		"A registered visual state with a missing asset should be rejected."
	)

	var cyclic := BattlerVisualProfile.new()
	cyclic.profile_id = &"cyclic"
	cyclic.battler_id = &"lysandra"
	cyclic.supported_pose_keys = [&"idle", &"move", &"attack"]
	cyclic.supported_orientation_keys = [&"front"]
	cyclic.states = [source.get_state(&"idle", &"front")]
	var move_to_attack := BattlerVisualFallbackDefinition.new()
	move_to_attack.from_key = &"move"
	move_to_attack.to_key = &"attack"
	var attack_to_move := BattlerVisualFallbackDefinition.new()
	attack_to_move.from_key = &"attack"
	attack_to_move.to_key = &"move"
	cyclic.pose_fallbacks = [move_to_attack, attack_to_move]
	_expect(
		"cyclic pose fallback" in cyclic.validate_definition(),
		"Fallback cycles should be rejected deterministically."
	)

	var duplicate_catalog := BattlerVisualProfileCatalog.new()
	duplicate_catalog.required_battler_ids = [&"lysandra"]
	duplicate_catalog.profiles = [source, source]
	_expect(
		"repeats profile" in duplicate_catalog.validate_definition(battlers),
		"Duplicate stable profile IDs should be rejected."
	)
	var unknown_profile := source.duplicate(true) as BattlerVisualProfile
	unknown_profile.profile_id = &"unknown_visual"
	unknown_profile.battler_id = &"not_a_battler"
	var unknown_catalog := BattlerVisualProfileCatalog.new()
	unknown_catalog.required_battler_ids = [&"lysandra"]
	unknown_catalog.profiles = [unknown_profile]
	_expect(
		"references unknown battler" in unknown_catalog.validate_definition(
			battlers
		),
		"A profile outside the canonical required roster should be rejected."
	)
	var uncovered_catalog := BattlerVisualProfileCatalog.new()
	uncovered_catalog.required_battler_ids = [&"chain_warden"]
	_expect(
		"has no profile or allowed fallback" in uncovered_catalog.validate_definition(
			battlers
		),
		"Every required battler should need a profile or explicit placeholder."
	)
	var grapple_metadata := BattlerGrappleVisualMetadata.new()
	grapple_metadata.supported_role_keys = [&"subject", &"subject"]
	_expect(
		"repeats role" in grapple_metadata.validate_definition(),
		"Malformed optional Grapple presentation metadata should be rejected."
	)


func _test_presentation_intent(
	catalog: BattlerVisualProfileCatalog
) -> void:
	if catalog == null:
		return
	var anchor := AnchorDefinition.new()
	anchor.anchor_id = &"hero_front"
	anchor.capacity = 2
	anchor.position_points = [Vector2(100.0, 220.0), Vector2(150.0, 220.0)]
	anchor.position_battler_scales = [0.6, 1.8]
	anchor.position_visual_orders = [5, 9]
	anchor.visual_orientation = &"back"
	anchor.visual_depth_band = &"foreground"
	anchor.battler_scale = 0.75
	anchor.visual_order = 6
	anchor.bounded_y_sort_within_band = true
	var battlefield := BattlefieldDefinition.new()
	battlefield.anchors = [anchor]
	var placement := BattlerPlacementDefinition.new()
	placement.battler_id = &"lysandra"
	placement.anchor_id = anchor.anchor_id
	placement.position_index = 1
	var intent: Dictionary = BattlerVisualIntentResolver.resolve_intent(
		catalog,
		battlefield,
		&"lysandra",
		&"heroine_0",
		&"damage_received",
		false,
		placement
	)
	var overridden_intent: Dictionary = (
		BattlerVisualIntentResolver.resolve_intent(
			catalog,
			battlefield,
			&"lysandra",
			&"heroine_override",
			&"idle",
			false,
			placement,
			&"front"
		)
	)
	_expect(
		String(intent.get("error", "")).is_empty()
		and intent.get("requested_pose_key") == &"hurt"
		and intent.get("requested_orientation_key") == &"back"
		and intent.get("resolved_pose_key") == &"hurt"
		and intent.get("resolved_orientation_key") == &"back",
		"Combat presentation events should resolve through deterministic pose/orientation fallbacks."
	)
	_expect(
		intent.get("world_position") == Vector2(150.0, 220.0)
		and intent.get("depth_band") == &"foreground"
		and is_equal_approx(float(intent.get("anchor_scale")), 1.8)
		and intent.get("visual_order") == 9
		and not intent.get("bounded_y_sort_within_band")
		and anchor.has_position_visual_order_override(1),
		"Visual intent should preserve authored placement and presentation-only ordering data."
	)
	_expect(
		overridden_intent.get("requested_orientation_key") == &"front"
		and overridden_intent.get("resolved_orientation_key") == &"front"
		and BattlerVisualIntentResolver.orientation_toward_opponent(
			Vector2(100.0, 400.0),
			Vector2(100.0, 200.0),
			&"front",
			&"front"
		) == &"back"
		and BattlerVisualIntentResolver.orientation_toward_opponent(
			Vector2(100.0, 200.0),
			Vector2(100.0, 400.0),
			&"back",
			&"back"
		) == &"front"
		and BattlerVisualIntentResolver.orientation_toward_opponent(
			Vector2(100.0, 200.0),
			Vector2(110.0, 205.0),
			&"back",
			&"front"
		) == &"back",
		"Closest-opponent facing must override anchors while equal depth remains stable."
	)
	_expect(
		BattlerVisualIntentResolver.hold_seconds_for_event(
			&"attack_started"
		) == 0.7
		and BattlerVisualIntentResolver.hold_seconds_for_event(
			&"damage_received"
		) == 0.55
		and BattlerVisualIntentResolver.hold_seconds_for_event(
			&"move_started"
		) == 0.0,
		"Static action poses should use the centralized slower presentation cadence."
	)
	_expect(
		BattlerVisualIntentResolver.pose_key_for_event(&"cast_started", true)
		== &"defeated",
		"Defeat should override a concurrent presentation event."
	)


func _test_runtime_renderer_is_activated() -> void:
	var scene_text: String = FileAccess.get_file_as_string(
		"res://scenes/battle/combat_encounter.tscn"
	)
	_expect(
		"battler_visual_profile_catalog" in scene_text
		and "CombatStagePresenter" in scene_text,
		"Milestone 14 should activate the reviewed visual-profile renderer."
	)


func _contains_text(values: Array[String], fragment: String) -> bool:
	for value: String in values:
		if fragment in value:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
