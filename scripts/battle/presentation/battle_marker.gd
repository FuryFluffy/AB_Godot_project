class_name BattleMarker
extends Marker2D

signal battler_selected(battler_id: StringName)
signal visual_pose_reset_requested(battler_id: StringName)

const ENEMY_HUD_SCENE: PackedScene = preload(
	"res://scenes/battle/ui/reusable/components/enemy_hud_view.tscn"
)
const POSE_CROSSFADE_SECONDS: float = 0.1
const CHARACTER_ART_Z_OFFSET: int = -2
const GRAPPLE_HOLDER_ART_Z_OFFSET: int = -4

@export var battler_id: StringName
@export var select_button: Button

var battler_state: BattlerState
var location_label: String = ""
var is_attack_targeting: bool = false
var is_legal_attack_target: bool = false
var grapple_progress: ProgressBar
var grapple_stage_label: Label
var cluster_display_offset: Vector2 = Vector2.ZERO
var select_button_base_position: Vector2 = Vector2.ZERO
var grapple_label_base_position: Vector2 = Vector2.ZERO
var grapple_progress_base_position: Vector2 = Vector2.ZERO
var character_art: Sprite2D
var character_art_base_position: Vector2 = Vector2.ZERO
var enemy_hud: EnemyHudView
var enemy_hud_base_position: Vector2 = Vector2.ZERO
var character_art_source_position: Vector2 = Vector2.ZERO
var character_art_source_scale: Vector2 = Vector2.ONE
var battlefield_presentation_scale: float = 1.0
var is_reaction_focus: bool = false
var visual_profile_catalog: BattlerVisualProfileCatalog
var current_visual_event: StringName = &"idle"
var current_orientation: StringName = &"front"
var current_pose_key: StringName = &""
var uses_profile_art: bool = false
var selection_visibility_alpha: float = 1.0
var pose_reset_timer: Timer
var visual_transition: Tween
var last_observed_hp: int = -1
var last_observed_grappled: bool = false
var battlefield_depth_band: StringName = &"midground"
var bounded_y_sort_within_band: bool = true
var grapple_cluster_role: StringName = &""


func configure_view(
	new_battler_id: StringName,
	view: BattlerViewDefinition
) -> void:
	battler_id = new_battler_id
	if view == null or view.texture == null:
		return
	var art := Sprite2D.new()
	art.name = "CharacterArt"
	art.z_index = CHARACTER_ART_Z_OFFSET
	art.position = view.art_offset
	art.scale = view.art_scale
	character_art_source_position = view.art_offset
	character_art_source_scale = view.art_scale
	art.texture = view.texture
	add_child(art)
	_apply_grapple_visual_layer()


func configure_visual_profile(
	catalog: BattlerVisualProfileCatalog
) -> void:
	visual_profile_catalog = catalog


func present_visual_resolution(
	resolution: Dictionary,
	transient_seconds: float = 0.0,
	crossfade: bool = true,
	preserve_pose_timer: bool = false
) -> bool:
	var texture: Texture2D = resolution.get("texture") as Texture2D
	if texture == null or not String(resolution.get("error", "")).is_empty():
		return false
	current_pose_key = StringName(resolution.get("resolved_pose_key", &"idle"))
	current_orientation = StringName(
		resolution.get("resolved_orientation_key", &"front")
	)
	if pose_reset_timer != null and not preserve_pose_timer:
		pose_reset_timer.stop()
	if crossfade and is_node_ready() and character_art != null:
		if visual_transition != null and visual_transition.is_valid():
			visual_transition.kill()
		visual_transition = create_tween()
		visual_transition.tween_property(
			character_art,
			"modulate:a",
			0.0,
			POSE_CROSSFADE_SECONDS
		)
		visual_transition.tween_callback(
			_apply_visual_resolution.bind(resolution)
		)
		visual_transition.tween_property(
			character_art,
			"modulate:a",
			1.0,
			POSE_CROSSFADE_SECONDS
		)
	else:
		_apply_visual_resolution(resolution)
	if transient_seconds > 0.0 and pose_reset_timer != null:
		pose_reset_timer.start(transient_seconds)
	return true


func present_visual_event(
	event_key: StringName,
	orientation_key: StringName,
	transient_seconds: float = -1.0,
	crossfade: bool = true
) -> bool:
	current_visual_event = event_key
	current_orientation = orientation_key
	if visual_profile_catalog == null:
		return false
	var resolution: Dictionary = visual_profile_catalog.resolve_visual(
		battler_id,
		BattlerVisualIntentResolver.pose_key_for_event(
			event_key,
			battler_state != null and battler_state.is_defeated
		),
		orientation_key,
		StringName(name)
	)
	var resolved_transient_seconds: float = transient_seconds
	if resolved_transient_seconds < 0.0:
		resolved_transient_seconds = (
			BattlerVisualIntentResolver.hold_seconds_for_event(event_key)
		)
	return present_visual_resolution(
		resolution,
		resolved_transient_seconds,
		crossfade and current_pose_key != &""
	)


func fade_character_art_to(
	target_alpha: float,
	duration_seconds: float
) -> void:
	if character_art == null:
		return
	if visual_transition != null and visual_transition.is_valid():
		visual_transition.kill()
	if duration_seconds <= 0.0:
		character_art.modulate.a = clampf(target_alpha, 0.0, 1.0)
		return
	visual_transition = create_tween()
	visual_transition.set_trans(Tween.TRANS_SINE)
	visual_transition.set_ease(Tween.EASE_IN_OUT)
	visual_transition.tween_property(
		character_art,
		"modulate:a",
		clampf(target_alpha, 0.0, 1.0),
		duration_seconds
	)
	await visual_transition.finished


func set_selection_visibility(
	active: bool,
	active_alpha: float = 0.52
) -> void:
	selection_visibility_alpha = (
		clampf(active_alpha, 0.15, 1.0) if active else 1.0
	)
	_apply_selection_visibility()


func _apply_visual_resolution(resolution: Dictionary) -> void:
	var texture: Texture2D = resolution.get("texture") as Texture2D
	if texture == null:
		return
	if character_art == null:
		character_art = Sprite2D.new()
		character_art.name = "CharacterArt"
		character_art.z_index = CHARACTER_ART_Z_OFFSET
		add_child(character_art)
	_apply_grapple_visual_layer()
	var pivot: Vector2 = resolution.get(
		"floor_contact_pivot",
		Vector2(0.5, 1.0)
	) as Vector2
	var baseline_scale: Vector2 = resolution.get(
		"baseline_scale",
		Vector2.ONE
	) as Vector2
	var scale_correction: Vector2 = resolution.get(
		"scale_correction",
		Vector2.ONE
	) as Vector2
	var offset_correction: Vector2 = resolution.get(
		"offset_correction",
		Vector2.ZERO
	) as Vector2
	character_art.texture = texture
	character_art.centered = false
	character_art_source_scale = baseline_scale * scale_correction
	character_art_source_position = (
		offset_correction
		- texture.get_size() * pivot * character_art_source_scale
	)
	uses_profile_art = true
	_apply_character_art_depth_scale()
	_apply_selection_visibility()
	_configure_select_area()
	_layout_enemy_hud()
	_layout_grapple_progress()
	_apply_cluster_display_offset()

func _ready() -> void:
	if select_button == null:
		select_button = find_child(
			"SelectButton",
			true,
			false
		) as Button
	
	assert(
		select_button != null,
		"%s requires a Button named SelectButton." % name
	)
	select_button_base_position = select_button.position
	select_button.add_theme_font_size_override("font_size", 13)
	select_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	character_art = find_child(
		"CharacterArt",
		true,
		false
	) as Sprite2D
	if character_art != null:
		if character_art_source_position == Vector2.ZERO:
			character_art_source_position = character_art.position
		if character_art_source_scale == Vector2.ONE:
			character_art_source_scale = character_art.scale
		_apply_character_art_depth_scale()
		_apply_grapple_visual_layer()
	pose_reset_timer = Timer.new()
	pose_reset_timer.name = "PoseResetTimer"
	pose_reset_timer.one_shot = true
	pose_reset_timer.timeout.connect(_on_pose_reset_timeout)
	add_child(pose_reset_timer)
	
	if not select_button.pressed.is_connected(
		_on_select_button_pressed
	):
		select_button.pressed.connect(
			_on_select_button_pressed
		)
	_ensure_grapple_progress()
	_apply_visual_style()
	_apply_cluster_display_offset()
	_refresh()
	
func bind_state(new_state: BattlerState) -> void:
	if battler_state != null:
		if battler_state.state_changed.is_connected(_refresh):
			battler_state.state_changed.disconnect(_refresh)
			
	battler_state = new_state
	
	if battler_state != null:
		last_observed_hp = battler_state.current_hp
		last_observed_grappled = (
			battler_state.is_grappled()
			or battler_state.is_attached_grappler()
		)
		if not battler_state.state_changed.is_connected(_refresh):
			battler_state.state_changed.connect(_refresh)
	_configure_select_area()
	_apply_visual_style()
	_refresh()


func set_location_label(
	new_location_label: String
) -> void:
	location_label = new_location_label
	_refresh()


func set_attack_targeting(
	active: bool,
	is_legal_target: bool = false
) -> void:
	is_attack_targeting = active
	is_legal_attack_target = is_legal_target
	select_button.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if not active or is_legal_target
		else Control.MOUSE_FILTER_IGNORE
	)
	_refresh()


func set_reaction_focus(active: bool) -> void:
	is_reaction_focus = active
	queue_redraw()


func get_reaction_anchor_screen_position() -> Vector2:
	if select_button == null:
		return get_global_transform_with_canvas().origin
	var rect: Rect2 = select_button.get_global_rect()
	return Vector2(rect.get_center().x, rect.position.y - 8.0)


func set_battlefield_presentation(
	new_scale: float,
	new_visual_order: int,
	new_depth_band: StringName = &"midground",
	new_bounded_y_sort: bool = true,
	world_y: float = 0.0
) -> void:
	battlefield_presentation_scale = clampf(new_scale, 0.1, 3.0)
	battlefield_depth_band = new_depth_band
	bounded_y_sort_within_band = new_bounded_y_sort
	var bounded_y_bias: int = (
		clampi(int(floorf(world_y / 360.0)), 0, 3)
		if bounded_y_sort_within_band
		else 0
	)
	z_index = new_visual_order + bounded_y_bias
	_apply_character_art_depth_scale()
	_configure_select_area()
	_layout_enemy_hud()
	_layout_grapple_progress()
	_apply_cluster_display_offset()
	queue_redraw()


func _apply_character_art_depth_scale() -> void:
	if character_art == null:
		return
	character_art.scale = (
		character_art_source_scale
		* battlefield_presentation_scale
	)
	character_art_base_position = (
		character_art_source_position
		* battlefield_presentation_scale
	)
	character_art.position = character_art_base_position


func _apply_selection_visibility() -> void:
	if character_art == null:
		return
	# Keep selection fading separate from pose crossfades and defeat tinting.
	# self_modulate multiplies those existing effects without overwriting them.
	character_art.self_modulate = Color(
		1.0,
		1.0,
		1.0,
		selection_visibility_alpha
	)


func set_cluster_display_offset(new_offset: Vector2) -> void:
	cluster_display_offset = new_offset
	_apply_cluster_display_offset()


func set_grapple_cluster_role(new_role: StringName) -> void:
	grapple_cluster_role = (
		new_role if new_role in [&"subject", &"holder"] else &""
	)
	_apply_grapple_visual_layer()


func get_resting_visual_event() -> StringName:
	if battler_state != null:
		if battler_state.is_attached_grappler():
			return &"grapple_holder"
		if battler_state.is_grappled():
			return &"grapple_subject"
	return &"idle"


func _apply_grapple_visual_layer() -> void:
	if character_art == null:
		return
	# Grapple participants retain separate sprites until combined authored
	# Grapple art exists. Put the holder behind the subject so their overlap
	# reads as a restraint instead of covering the heroine.
	character_art.z_index = (
		GRAPPLE_HOLDER_ART_Z_OFFSET
		if grapple_cluster_role == &"holder"
		else CHARACTER_ART_Z_OFFSET
	)
	
func _refresh() -> void:
	if not is_node_ready() or select_button == null:
		return
		
	if battler_state == null or battler_state.definition == null:
		select_button.text = "Unbound"
		select_button.disabled = true
		return
	var hp_decreased: bool = (
		last_observed_hp >= 0
		and battler_state.current_hp < last_observed_hp
	)
	var grappled_now: bool = (
		battler_state.is_grappled()
		or battler_state.is_attached_grappler()
	)
	if battler_state.is_defeated and current_visual_event != &"defeated":
		present_visual_event(&"defeated", current_orientation)
	elif hp_decreased:
		present_visual_event(&"damage_received", current_orientation)
	elif grappled_now and (
		not last_observed_grappled
		or current_visual_event not in [&"grapple_subject", &"grapple_holder"]
	):
		present_visual_event(
			get_resting_visual_event(),
			current_orientation,
			0.0
		)
	elif not grappled_now and last_observed_grappled:
		present_visual_event(&"idle", current_orientation, 0.0)
	last_observed_hp = battler_state.current_hp
	last_observed_grappled = grappled_now
		
	var targeting_label: String = ""
	if is_attack_targeting:
		targeting_label = (
			"\nLEGAL TARGET"
			if is_legal_attack_target
			else "\nNot targetable"
		)

	var status_line: String = ""
	if not battler_state.active_statuses.is_empty():
		status_line = "\n%s" % battler_state.get_status_summary()
	if battler_state.item_guard_points > 0:
		status_line += "\nItem Guard %d" % (
			battler_state.item_guard_points
		)

	if _is_heroine():
		select_button.text = ""
		select_button.tooltip_text = (
			"%s\n%s%s%s"
			% [
				battler_state.definition.display_name,
				location_label,
				status_line,
				targeting_label,
			]
		)
	else:
		select_button.text = ""
		select_button.tooltip_text = "%s\n%s%s%s" % [
			battler_state.definition.display_name,
			location_label,
			status_line,
			targeting_label,
		]
		_ensure_enemy_hud()
		enemy_hud.display_state(battler_state)
	select_button.disabled = (
		is_attack_targeting
		and not is_legal_attack_target
	)
	select_button.modulate = (
		Color.WHITE
		if not is_attack_targeting or is_legal_attack_target
		else Color(0.52, 0.52, 0.52, 0.72)
	)
	if enemy_hud != null:
		enemy_hud.modulate = select_button.modulate
	if character_art != null:
		character_art.modulate = (
			Color(0.42, 0.42, 0.46, 0.68)
			if battler_state.is_defeated
			else Color.WHITE
		)
	_refresh_grapple_progress()
	queue_redraw()


func _on_pose_reset_timeout() -> void:
	if battler_state != null and battler_state.is_defeated:
		return
	var resting_event: StringName = get_resting_visual_event()
	visual_pose_reset_requested.emit(battler_id)
	# A coordinator resolves the latest opponent-facing direction before
	# returning to the correct resting pose. Marker-only uses still receive a
	# safe local fallback, including persistent Grapple role presentation.
	if current_visual_event != resting_event:
		present_visual_event(resting_event, current_orientation, 0.0)


func _exit_tree() -> void:
	if pose_reset_timer != null:
		pose_reset_timer.stop()
	if visual_transition != null and visual_transition.is_valid():
		visual_transition.kill()


func _configure_select_area() -> void:
	if select_button == null or battler_state == null:
		return
	if character_art == null:
		select_button_base_position = select_button.position
		return
	if character_art.texture == null:
		return
	var scaled_size: Vector2 = (
		character_art.texture.get_size()
		* character_art.scale.abs()
	)
	scaled_size.x = maxf(scaled_size.x, 140.0)
	scaled_size.y = maxf(scaled_size.y, 260.0)
	select_button.size = scaled_size
	select_button.custom_minimum_size = scaled_size
	# Profile art is explicitly top-left anchored so its authored floor-contact
	# pivot remains stable across pose swaps. Legacy centered sprites still need
	# the half-size correction, but applying it to profile art displaces the
	# selection rectangle and enemy HUD by another half sprite.
	select_button.position = character_art_base_position
	if character_art.centered:
		select_button.position -= scaled_size * 0.5
	select_button_base_position = select_button.position
	_layout_enemy_hud()
	_apply_cluster_display_offset()


func _ensure_enemy_hud() -> void:
	if enemy_hud != null or _is_heroine():
		return
	enemy_hud = ENEMY_HUD_SCENE.instantiate() as EnemyHudView
	if enemy_hud == null:
		return
	enemy_hud.position = select_button_base_position
	enemy_hud.custom_minimum_size = Vector2(
		maxf(select_button.size.x, 160.0),
		58.0
	)
	enemy_hud.size = enemy_hud.custom_minimum_size
	enemy_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_hud.z_index = 11
	add_child(enemy_hud)
	_layout_enemy_hud()
	_layout_grapple_progress()
	_apply_cluster_display_offset()


func _layout_enemy_hud() -> void:
	if enemy_hud == null or select_button == null:
		return
	var width: float = maxf(select_button.size.x, 160.0)
	enemy_hud.custom_minimum_size = Vector2(width, 58.0)
	enemy_hud.size = enemy_hud.custom_minimum_size
	if character_art != null:
		enemy_hud_base_position = Vector2(
			select_button_base_position.x
				+ (select_button.size.x - width) * 0.5,
			select_button_base_position.y - 66.0
		)
	else:
		enemy_hud_base_position = select_button_base_position
	enemy_hud.position = enemy_hud_base_position


func _is_heroine() -> bool:
	return (
		battler_state != null
		and battler_state.definition != null
		and battler_state.definition.faction
		== BattlerDefinition.Faction.HEROINE
	)


func _ensure_grapple_progress() -> void:
	if grapple_progress != null:
		return
	var width: float = maxf(select_button.size.x, 160.0)
	var left: float = select_button.position.x
	var label_top: float = (
		select_button.position.y
		+ select_button.size.y
		+ 5.0
	)
	grapple_stage_label = Label.new()
	grapple_stage_label.name = "GrappleStageLabel"
	grapple_stage_label.position = Vector2(left, label_top)
	grapple_stage_label.size = Vector2(width, 16.0)
	grapple_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grapple_stage_label.add_theme_font_size_override("font_size", 12)
	grapple_stage_label.add_theme_color_override(
		"font_color",
		Color(0.96, 0.79, 0.42)
	)
	grapple_stage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grapple_stage_label.z_index = 12
	grapple_stage_label.visible = false
	add_child(grapple_stage_label)

	grapple_progress = ProgressBar.new()
	grapple_progress.name = "GrappleProgress"
	grapple_progress.position = Vector2(left, label_top + 17.0)
	grapple_progress.size = Vector2(width, 12.0)
	grapple_progress.min_value = 0.0
	grapple_progress.max_value = 1.0
	grapple_progress.show_percentage = false
	grapple_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grapple_progress.z_index = 12
	grapple_progress.add_theme_stylebox_override(
		"background",
		_progress_style(
			Color(0.025, 0.02, 0.018, 0.98),
			Color(0.71, 0.55, 0.27),
			1
		)
	)
	grapple_progress.add_theme_stylebox_override(
		"fill",
		_progress_style(
			Color(0.48, 0.10, 0.58, 1.0),
			Color(0.96, 0.79, 0.42),
			1
		)
	)
	grapple_progress.visible = false
	add_child(grapple_progress)
	grapple_label_base_position = grapple_stage_label.position
	grapple_progress_base_position = grapple_progress.position
	_layout_grapple_progress()


func _layout_grapple_progress() -> void:
	if (
		select_button == null
		or grapple_stage_label == null
		or grapple_progress == null
	):
		return
	var overlay_height: float = select_button.size.y
	var overlay_width: float = maxf(select_button.size.x, 160.0)
	var left: float = select_button_base_position.x
	var label_top: float = (
		select_button_base_position.y
		+ overlay_height
		+ 5.0
	)
	if enemy_hud != null:
		overlay_width = maxf(
			160.0,
			enemy_hud.custom_minimum_size.x
		)
		left = enemy_hud_base_position.x
		label_top = (
			enemy_hud_base_position.y
			+ enemy_hud.custom_minimum_size.y
			+ 4.0
		)
	grapple_stage_label.size.x = overlay_width
	grapple_progress.size.x = overlay_width
	grapple_label_base_position = Vector2(left, label_top)
	grapple_progress_base_position = Vector2(left, label_top + 17.0)


func _apply_cluster_display_offset() -> void:
	if select_button != null:
		select_button.position = (
			select_button_base_position
			+ cluster_display_offset
		)
	if character_art != null:
		character_art.position = (
			character_art_base_position
			+ cluster_display_offset
		)
	if grapple_progress != null:
		grapple_progress.position = (
			grapple_progress_base_position
			+ cluster_display_offset
		)
	if grapple_stage_label != null:
		grapple_stage_label.position = (
			grapple_label_base_position
			+ cluster_display_offset
		)
	if enemy_hud != null:
		enemy_hud.position = (
			enemy_hud_base_position
			+ cluster_display_offset
		)


func _refresh_grapple_progress() -> void:
	if grapple_progress == null:
		return
	if (
		battler_state == null
		or not battler_state.is_attached_grappler()
		or battler_state.grapple_stage_count <= 0
	):
		grapple_progress.visible = false
		if grapple_stage_label != null:
			grapple_stage_label.visible = false
		return

	grapple_progress.visible = true
	if grapple_stage_label != null:
		grapple_stage_label.visible = true
		grapple_stage_label.text = "GRAPPLE STAGE %d / %d" % [
			battler_state.grapple_stage,
			battler_state.grapple_stage_count,
		]
	grapple_progress.value = (
		float(battler_state.grapple_stage)
		/ float(battler_state.grapple_stage_count)
	)


func _progress_style(
	background: Color,
	border: Color,
	width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style


func _apply_visual_style() -> void:
	if select_button == null:
		return
	var heroine := _is_heroine()
	# The full character rectangle is only a hit area. The enemy HUD owns the
	# visible nameplate; an opaque enemy Button here covers CharacterArt.
	select_button.flat = true
	var border := (
		Color(0.28, 0.58, 0.76)
		if heroine
		else Color(0.73, 0.24, 0.18)
	)
	var normal := _nameplate_style(
		Color(0, 0, 0, 0),
		Color(0, 0, 0, 0),
		0
	)
	var hover := _nameplate_style(
		Color(0.15, 0.115, 0.075, 0.10),
		Color(0.96, 0.79, 0.42),
		1
	)
	var pressed := _nameplate_style(
		Color(0.04, 0.035, 0.032, 0.12),
		Color(1.0, 0.87, 0.48),
		1
	)
	select_button.add_theme_stylebox_override("normal", normal)
	select_button.add_theme_stylebox_override("hover", hover)
	select_button.add_theme_stylebox_override("pressed", pressed)
	select_button.add_theme_stylebox_override("focus", hover)
	select_button.add_theme_color_override(
		"font_color",
		Color(0.94, 0.89, 0.77)
	)
	select_button.add_theme_color_override(
		"font_hover_color",
		Color.WHITE
	)


func _nameplate_style(
	background: Color,
	border: Color,
	width: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 7
	style.content_margin_right = 7
	return style


func _draw() -> void:
	if battler_state == null or battler_state.definition == null:
		return
	if not should_draw_context_ring():
		return
	var ring_color := Color(1.0, 0.82, 0.30, 0.95)
	if is_reaction_focus:
		ring_color = Color(1.0, 0.82, 0.30, 1.0)
	draw_arc(
		cluster_display_offset + Vector2(0, 20),
		55.0 * battlefield_presentation_scale,
		0.0,
		TAU,
		36,
		ring_color,
		4.0 if is_reaction_focus else 2.0,
		true
	)
	if is_reaction_focus and select_button != null:
		_draw_reaction_brackets(
			Rect2(select_button.position, select_button.size).grow(6.0)
		)


func should_draw_context_ring() -> bool:
	return (
		(is_attack_targeting and is_legal_attack_target)
		or is_reaction_focus
	)


func _draw_reaction_brackets(rect: Rect2) -> void:
	var color := Color(1.0, 0.82, 0.30, 0.95)
	var length: float = 22.0
	var width: float = 3.0
	var left: float = rect.position.x
	var top: float = rect.position.y
	var right: float = rect.end.x
	var bottom: float = rect.end.y
	var corners: Array[PackedVector2Array] = [
		PackedVector2Array([
			Vector2(left + length, top), Vector2(left, top),
			Vector2(left, top + length),
		]),
		PackedVector2Array([
			Vector2(right - length, top), Vector2(right, top),
			Vector2(right, top + length),
		]),
		PackedVector2Array([
			Vector2(left, bottom - length), Vector2(left, bottom),
			Vector2(left + length, bottom),
		]),
		PackedVector2Array([
			Vector2(right, bottom - length), Vector2(right, bottom),
			Vector2(right - length, bottom),
		]),
	]
	for points: PackedVector2Array in corners:
		draw_polyline(points, color, width, true)
	
func _on_select_button_pressed() -> void:
	if battler_state == null:
		return
		
	if battler_state.definition == null:
		return
		
	battler_selected.emit(
		battler_state.definition.battler_id
	)
