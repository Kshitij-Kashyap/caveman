shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 flame_tint : source_color = vec4(1.0, 0.72, 0.2, 1.0);
uniform vec4 ember_tint : source_color = vec4(1.0, 0.32, 0.05, 1.0);
uniform float emission_strength : hint_range(0.0, 6.0) = 1.8;
uniform float animation_speed : hint_range(0.1, 15.0) = 4.8;
uniform float wave_amplitude : hint_range(0.0, 0.3) = 0.05;

void vertex() {
	float t = TIME * animation_speed;
	// Height factor: anchored at wood logs (y < 0.6), dynamic at flame tongues (y > 0.8)
	float h = clamp((VERTEX.y - 0.35) * 0.75, 0.0, 1.4);
	
	// Sinusoidal wind/flame licks
	float sway_x = sin(t * 1.1 + VERTEX.y * 4.0) * wave_amplitude * h;
	float sway_z = cos(t * 0.9 + VERTEX.y * 3.2) * wave_amplitude * 0.8 * h;
	float pulse_y = (sin(t * 1.6 + VERTEX.x * 3.0) * 0.5 + 0.5) * wave_amplitude * 1.1 * h;
	
	VERTEX.x += sway_x;
	VERTEX.y += pulse_y;
	VERTEX.z += sway_z;
}

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	
	// Height gradient: glowing red/orange near logs, golden yellow body
	float h_factor = clamp((VERTEX.y - 0.3) * 0.6, 0.0, 1.0);
	vec3 fire_col = mix(ember_tint.rgb, flame_tint.rgb, h_factor) * tex_color.rgb;
	
	ALBEDO = fire_col;
	EMISSION = fire_col * emission_strength;
	ROUGHNESS = 0.4;
}
