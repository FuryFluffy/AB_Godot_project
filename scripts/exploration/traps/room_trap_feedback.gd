extends Node2D
## Presentation only. The room owns particles/timers, including transition cleanup.

func play(visual_id: StringName) -> void:
	z_index = 20
	if visual_id == &"alarm":
		var marker := Sprite2D.new()
		marker.texture = preload("res://assets/map/revision_2/traps/markers/alarm_bell.png")
		marker.scale = Vector2.ONE * 60.0 / marker.texture.get_width()
		add_child(marker)
		create_tween().tween_property(marker,"scale",marker.scale * 1.3,0.25)
	else:
		var particles := CPUParticles2D.new()
		particles.emitting = false
		particles.one_shot = true
		particles.amount = 28
		particles.lifetime = 1.0
		particles.explosiveness = 0.85
		particles.randomness = 0.4
		particles.direction = Vector2.UP
		particles.spread = 65.0
		particles.gravity = Vector2(0,-10)
		particles.initial_velocity_min = 12.0
		particles.initial_velocity_max = 32.0
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 22.0
		particles.scale_amount_min = 0.6
		particles.scale_amount_max = 1.4
		var soft := Gradient.new()
		soft.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0)])
		var texture := GradientTexture2D.new()
		texture.gradient = soft
		texture.width = 32
		texture.height = 32
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5,0.5)
		texture.fill_to = Vector2(1,0.5)
		particles.texture = texture
		var tint: Color = Color(0.36,0.45,0.17,0.8) if visual_id == &"poison" else Color(0.43,0.26,0.52,0.8)
		var fade := Gradient.new()
		fade.colors = PackedColorArray([tint,Color(tint.r,tint.g,tint.b,0)])
		particles.color_ramp = fade
		add_child(particles)
		particles.emitting = true
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 1.25
	add_child(timer)
	timer.timeout.connect(queue_free)
	timer.start()
