shader_type canvas_item;
// 分区画风全屏调色层：取屏 → 像素化 / 色阶量化 / 饱和 / 对比 / 色调 / 抬黑 / 暗角 / 扫描线。
// 仅供 zone_grade.gd 使用；uniform 名与 zone_environment.gd PRESETS["grade"] 的键一一对应。

uniform sampler2D screen_src : hint_screen_texture, filter_nearest, repeat_disable;

uniform float pixel_size = 1.0;       // 1 = 关闭；>1 时按 N 设备像素分块（我的世界 / 合金弹头）
uniform float posterize_levels = 0.0; // 0 = 关闭；每通道色阶数（<2 视为关闭）
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float brightness = 0.0;
uniform vec3 tint_col : source_color = vec3(1.0);
uniform float tint_amount = 0.0;
uniform float black_lift = 0.0;       // 抬黑：大鹅的印刷平涂感 / 糖豆人的糖果奶油感
uniform float vignette = 0.0;
uniform float scanline = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	if (pixel_size > 1.5) {
		vec2 res = vec2(textureSize(screen_src, 0));
		vec2 blocks = max(res / pixel_size, vec2(1.0));
		uv = (floor(uv * blocks) + vec2(0.5)) / blocks;
	}
	vec3 col = texture(screen_src, uv).rgb;
	col += vec3(brightness);
	col = (col - vec3(0.5)) * contrast + vec3(0.5);
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(vec3(lum), col, saturation);
	col = mix(col, col * tint_col, tint_amount);
	if (black_lift > 0.001) {
		col += black_lift * (vec3(1.0) - col);
	}
	if (posterize_levels >= 2.0) {
		col = floor(col * posterize_levels + vec3(0.5)) / posterize_levels;
	}
	if (vignette > 0.001) {
		float d = distance(UV, vec2(0.5));
		col *= vec3(1.0) - vignette * smoothstep(0.35, 0.78, d);
	}
	if (scanline > 0.001) {
		float sl = sin(FRAGCOORD.y * 3.14159) * 0.5 + 0.5;
		col *= vec3(1.0) - scanline * sl;
	}
	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
