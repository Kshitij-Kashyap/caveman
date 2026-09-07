shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 flame_core_color : source_color = vec4(1.0, 0.85, 0.25, 1.0);
uniform vec4 flame_tip_color : source_color = vec4(1.0, 0.35, 0.05, 1.0);
uniform float emission_strength : hint_range(0.0, 10.0) = 4.0;
uniform float animation_speed : hint_range(0.1, 15.0) = 5.0;
uniform float wave_amplitude : hint_range(0.0, 0.5) = 0.08;

void vertex() {
	float t = TIME * animation_speed;
	float height_factor = clamp(VERTEX.y * 0.6, 0.0, 1.5);
	
	// Flame lick swaying along X and Z
	float sway_x = sin(t + VERTEX.y * 3.5) * wave_amplitude * height_factor;
	float sway_z = cos(t * 1.2 + VERTEX.y * 2.8) * wave_amplitude * 0.8 * height_factor;
	
	// Flame upward pulse
	float pulse_y = (sin(t * 1.8 + VERTEX.x * 2.0) * 0.5 + 0.5) * wave_amplitude * 1.2 * height_factor;
	
	VERTEX.x += sway_x;
	VERTEX.y += pulse_y;
	VERTEX.z += sway_z;
}

void fragment() {
	vec4 tex_color = texture(albedo_texture, UV);
	
	// Mix core yellow to tip orange based on vertical position
	float vert_factor = clamp(VERTEX.y * 0.5, 0.0, 1.0);
	vec3 base_col = mix(tex_color.rgb * flame_core_color.rgb, flame_tip_color.rgb, vert_factor * 0.6);
	
	ALBEDO = base_col;
	EMISSION = base_col * emission_strength;
	ROUGHNESS = 0.3;
}
