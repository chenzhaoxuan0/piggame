shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;
uniform bool vertex_palette = true;
uniform vec4 pigment = vec4(1.0);
uniform bool use_texture = false;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool valley_haze_enabled = true;
uniform bool canopy_cutout = false;
// Neon arena zones (course 4): extract EMISSION from the bright parts of the
// albedo so neon strips glow under a bloom-enabled environment. Off by
// default - the farm and every other zone keep the exact flat look.
uniform bool emission_from_texture = false;
uniform float emission_boost = 1.4;
uniform float emission_threshold = 0.62;
uniform vec3 player_focus = vec3(0.0,32.7,100.0);
uniform vec3 player_camera = vec3(5.0,37.75,106.25);
// Compatibility vertex colors carry the authored palette. A bounded diffuse response
// preserves the palette and cool lifted shadows without texture or bloom.
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Only foreground foliage receives this cutaway. Keep the route occluded,
	// while a small clear silhouette around the pig preserves movement feedback.
	if (canopy_cutout) {
		vec3 sight = normalize(player_camera - player_focus);
		vec3 offset = world_position - player_focus;
		float depth = dot(offset, sight);
		if (depth > 0.5 && depth < length(player_camera-player_focus) && length(offset-sight*depth) < 1.15) {
			discard;
		}
	}
	float valley_haze = valley_haze_enabled ? clamp((-world_position.y - 2.0) / 18.0, 0.0, 0.75) : 0.0;
	vec3 base = use_texture ? (texture(albedo_texture, UV).rgb * pigment.rgb) : (vertex_palette ? COLOR.rgb : pigment.rgb);
	ALBEDO = mix(base, vec3(0.73, 0.73, 0.79), valley_haze);
	ROUGHNESS = 1.0;
	if (emission_from_texture) {
		vec3 hot = clamp((base - vec3(emission_threshold)) / max(1.0 - emission_threshold, 0.001), 0.0, 1.0);
		EMISSION += hot * emission_boost;
	}
}
void light() {
	float facing = smoothstep(-0.25, 0.8, dot(NORMAL, LIGHT));
	float illumination = mix(0.52, 0.94, facing * ATTENUATION);
	vec3 tint = mix(vec3(0.91, 0.95, 1.04), vec3(1.03, 1.01, 0.96), facing * ATTENUATION);
	DIFFUSE_LIGHT += illumination * tint;
}
