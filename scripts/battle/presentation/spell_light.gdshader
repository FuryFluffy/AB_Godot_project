shader_type canvas_item;
uniform float light_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 light_color : source_color = vec3(1.0, 0.65, 0.18);
varying vec4 sprite_modulate;

void vertex() {
	sprite_modulate = COLOR;
}

void fragment() {
	vec4 sprite = texture(TEXTURE, UV);
	// A brief stylized light contribution, not reconstructed 3D surface lighting.
	sprite.rgb += light_color * light_strength * sprite.rgb;
	COLOR = sprite * sprite_modulate;
}
