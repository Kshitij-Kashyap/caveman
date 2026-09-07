shader_type spatial;
render_mode diffuse_lambert, cull_back;

uniform vec4 skin_color : source_color = vec4(0.88, 0.68, 0.52, 1.0);
uniform vec4 clothing_color : source_color = vec4(0.42, 0.28, 0.18, 1.0);
uniform vec4 pants_color : source_color = vec4(0.28, 0.22, 0.16, 1.0);
uniform vec4 boots_color : source_color = vec4(0.16, 0.12, 0.08, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	vec3 col = clothing_color.rgb;
	// Differentiate parts via COLOR vertex attribute
	if (COLOR.r > 0.5) {
		// Skin (head and hands)
		col = skin_color.rgb;
	} else if (COLOR.b > 0.5) {
		// Pants / legs
		col = pants_color.rgb;
	} else if (COLOR.r < 0.25 && COLOR.g < 0.25 && COLOR.b < 0.25) {
		// Boots / footwear
		col = boots_color.rgb;
	} else if (COLOR.g > 0.5) {
		// Torso clothing & sleeves
		col = clothing_color.rgb;
	}

	ALBEDO = col;
	ROUGHNESS = roughness;
	SPECULAR = 0.2;
}
