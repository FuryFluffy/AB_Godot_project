class_name CombatPresentationDirector
extends Node2D

const HOME: Vector2 = Vector2(960.0, 540.0)
const SPELL_LIGHT: Shader = preload("res://scripts/battle/presentation/spell_light.gdshader")

var profile: CombatPresentationProfile
var markers: Array[BattleMarker] = []
var camera: Camera2D
var camera_tween: Tween
var movement_tween: Tween
var moving_marker: BattleMarker
var busy: bool = false
var temporary_lights: Array[Dictionary] = []
var held_target: BattleMarker


func initialize(new_profile: CombatPresentationProfile, new_markers: Array[BattleMarker]) -> void:
	profile = new_profile
	markers = new_markers
	camera = Camera2D.new()
	camera.name = "PresentationCamera"
	camera.position = HOME
	camera.enabled = profile.cinematic_camera_enabled
	add_child(camera)
	set_process(true)


func supports_action(request: ActionRequest) -> bool:
	if profile == null or request == null:
		return false
	if request.ability != null:
		return request.ability.ability_id == profile.light_arrow_ability_id
	return (
		request.source == ActionRequest.Source.NORMAL
		and request.weapon != null
		and request.weapon.skill == SkillEntry.Skill.SWORD
		and not request.is_magic
	)


func prepare_result(request: ActionRequest) -> void:
	if not supports_action(request):
		return
	held_target = _marker(request.target_id)
	if held_target != null:
		held_target.defer_result_pose = true


func release_result_pose() -> void:
	if is_instance_valid(held_target):
		held_target.defer_result_pose = false
		held_target._refresh()
	held_target = null


func play_action(request: ActionRequest, result: ActionResult) -> void:
	if busy or not supports_action(request):
		return
	var actor: BattleMarker = _marker(request.actor_id)
	var target: BattleMarker = _marker(request.target_id)
	if actor == null or target == null:
		release_result_pose()
		return
	busy = true
	var spell: bool = request.ability != null
	actor.present_visual_event(&"cast_started" if spell else &"attack_started",
		actor.current_orientation, 1.0, false)
	_focus(actor, target)
	if profile.effects_enabled:
		var effect := CombatActionEffect.new()
		effect.caster_floor = actor.position
		effect.target_floor = target.position
		effect.target_scale = target.battlefield_presentation_scale
		effect.caster_scale = actor.battlefield_presentation_scale
		effect.start = _body_point(actor, 0.32 if spell else 0.48)
		effect.destination = _body_point(target)
		effect.spell = spell
		effect.damaged = result != null and result.damage_dealt > 0
		add_child(effect)
		if spell:
			_light_sprite(actor, 0.24)
			_light_sprite(target, 0.12)
	await get_tree().create_timer(0.49 if spell else 0.25).timeout
	if not is_inside_tree():
		return
	if result != null and result.damage_dealt > 0:
		target.defer_result_pose = false
		target.present_visual_event(&"damage_received" if not target.battler_state.is_defeated else &"defeated",
			target.current_orientation, 0.55, false)
		_shake()
	release_result_pose()
	await get_tree().create_timer(0.24).timeout
	if not is_inside_tree():
		return
	await restore_camera()
	_restore_lights()
	busy = false


func animate_move(marker: BattleMarker, destination: Vector2, destination_scale: float) -> void:
	moving_marker = marker
	var origin: Vector2 = marker.position
	var origin_scale: float = marker.battlefield_presentation_scale
	movement_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	movement_tween.tween_method(
		_apply_move_sample.bind(marker, origin, destination, origin_scale, destination_scale),
		0.0, 1.0, profile.movement_seconds)
	await movement_tween.finished
	moving_marker = null


func is_moving(marker: BattleMarker) -> bool:
	return marker == moving_marker


func restore_camera() -> void:
	if camera == null or not camera.enabled:
		return
	if camera_tween != null and camera_tween.is_valid():
		camera_tween.kill()
	camera.offset = Vector2.ZERO
	camera_tween = create_tween().set_parallel(true)
	camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(camera, "position", HOME, 0.25)
	camera_tween.tween_property(camera, "zoom", Vector2.ONE, 0.25)
	await camera_tween.finished


func _focus(actor: BattleMarker, target: BattleMarker) -> void:
	if not camera.enabled:
		return
	if camera_tween != null and camera_tween.is_valid():
		camera_tween.kill()
	var zoom_value: float = profile.camera_zoom
	var half_view: Vector2 = HOME / zoom_value
	var focus: Vector2 = (_body_point(actor) + _body_point(target)) * 0.5
	focus = focus.clamp(half_view, Vector2(1920.0, 1080.0) - half_view)
	camera_tween = create_tween().set_parallel(true)
	camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(camera, "position", focus, 0.18)
	camera_tween.tween_property(camera, "zoom", Vector2.ONE * zoom_value, 0.18)


func _shake() -> void:
	if not camera.enabled:
		return
	var shake: Tween = create_tween()
	shake.tween_property(camera, "offset", Vector2(3.0, -2.0), 0.035)
	shake.tween_property(camera, "offset", Vector2(-2.0, 1.0), 0.035)
	shake.tween_property(camera, "offset", Vector2.ZERO, 0.06)


func _apply_move_sample(t: float, marker: BattleMarker, origin: Vector2,
	destination: Vector2, origin_scale: float, destination_scale: float) -> void:
	if not is_instance_valid(marker):
		return
	marker.position = origin.lerp(destination, t)
	marker.battlefield_presentation_scale = lerpf(origin_scale, destination_scale, t)
	marker._apply_character_art_depth_scale()
	marker._layout_enemy_hud()
	marker._apply_cluster_display_offset()


func _body_point(marker: BattleMarker, height: float = 0.48) -> Vector2:
	if marker.character_art == null or marker.character_art.texture == null:
		return marker.position
	var art: Sprite2D = marker.character_art
	return marker.position + art.position + art.texture.get_size() * art.scale * Vector2(0.5, height)


func _marker(id: StringName) -> BattleMarker:
	for marker: BattleMarker in markers:
		if is_instance_valid(marker) and marker.battler_id == id:
			return marker
	return null


func _light_sprite(marker: BattleMarker, strength: float) -> void:
	if marker.character_art == null:
		return
	var light := ShaderMaterial.new()
	light.shader = SPELL_LIGHT
	light.set_shader_parameter("light_strength", strength)
	temporary_lights.append({"art": marker.character_art, "material": marker.character_art.material})
	marker.character_art.material = light


func _restore_lights() -> void:
	for entry: Dictionary in temporary_lights:
		var art: Sprite2D = entry["art"] as Sprite2D
		if is_instance_valid(art):
			art.material = entry["material"] as Material
	temporary_lights.clear()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if profile == null or not profile.contact_shadows_enabled:
		return
	for marker: BattleMarker in markers:
		if not is_instance_valid(marker) or not marker.uses_profile_art:
			continue
		var size: Vector2 = Vector2(67.0, 13.0) * marker.battlefield_presentation_scale
		draw_set_transform(marker.position + marker.cluster_display_offset, 0.0, size)
		for index: int in range(8, 0, -1):
			draw_circle(Vector2.ZERO, float(index) / 8.0, Color(0.01, 0.005, 0.0, 0.055))
		draw_set_transform(Vector2.ZERO)


func _exit_tree() -> void:
	release_result_pose()
	_restore_lights()
	if camera_tween != null and camera_tween.is_valid():
		camera_tween.kill()
	if movement_tween != null and movement_tween.is_valid():
		movement_tween.kill()
	busy = false
	moving_marker = null
