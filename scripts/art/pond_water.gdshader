shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

// 羊矮棚真水池：顶点正弦波 + 伪法线高光 + 菲涅尔深浅色 + 游走波光。
// 平涂卡通水体：不追求物理折射，追求「一眼读出水在动」。

uniform vec4 shallow_color : source_color = vec4(0.36, 0.66, 0.72, 1.0);
uniform vec4 deep_color : source_color = vec4(0.07, 0.27, 0.35, 1.0);
uniform float wave_amplitude = 0.03;
uniform float wave_speed = 1.0;
uniform float sparkle_strength = 0.5;
uniform float alpha_base = 0.84;

varying vec3 world_pos;

float wave_h(vec2 p, float t) {
	return sin(p.x * 1.6 + t * 1.1) + sin(p.y * 2.1 + t * 0.9) + sin((p.x + p.y) * 0.8 + t * 0.6);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_pos = wp;
	VERTEX.y += wave_h(wp.xz, TIME * wave_speed) * wave_amplitude;
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 p = world_pos.xz;
	float e = 0.4;
	float hx = wave_h(p + vec2(e, 0.0), t) - wave_h(p - vec2(e, 0.0), t);
	float hz = wave_h(p + vec2(0.0, e), t) - wave_h(p - vec2(0.0, e), t);
	NORMAL = normalize(NORMAL + vec3(-hx, 0.0, -hz) * 0.12);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float depth_mix = clamp(fresnel * 0.85 + wave_h(p, t) * 0.06 + 0.25, 0.0, 1.0);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, depth_mix);
	ALPHA = alpha_base;
	ROUGHNESS = 0.15;
	METALLIC = 0.0;
	SPECULAR = 0.55;
	float glint = pow(max(0.0, sin(p.x * 7.0 + t * 2.2) * sin(p.y * 6.3 - t * 1.8)), 28.0);
	EMISSION = vec3(0.9, 0.97, 1.0) * glint * sparkle_strength * 0.4;
}
