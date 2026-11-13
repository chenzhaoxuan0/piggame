class_name ZoneEnvironment
extends Node

# Per-course atmosphere for the hidden tracks. The hub's WorldEnvironment and
# Sun live on the office root and stay lit for the farm, so "迷雾林间/霓虹竞技场"
# never actually looked different. This node swaps the hub environment for a
# zone-specific one and dims the Sun, then restores both in _exit_tree(); it is
# freed together with the course, so there is no manual teardown anywhere.
#
# Usage: ZONE_ENVIRONMENT.apply(self, "fairy_woodland") from a course's _ready().
# apply() 额外接受 overrides 深合并到 preset 之上，各关卡的最终观感由各自
# 脚本自己微调，避免六个任务并发改这个共享文件：
#   ZONE_ENVIRONMENT.apply(self, "voxel_creek", {"grade": {"pixel_size": 5.0}})
#
# 2026-11 分区画风强化（写实序章 / 大鹅下山路 / 糖豆人牛耕地 / 我的世界
# 溪流 / 合金弹头林间 / 马里奥赛车大院）：preset 除天空/环境光/雾/太阳外
# 还可带 tonemap_* 与 grade（ZoneGrade 全屏调色层，见 zone_grade.gd）。

const ZONE_GRADE = preload("res://scripts/courses/components/zone_grade.gd")

const PRESETS := {
	# 隐藏2 · 溪流 → 我的世界：正版天空蓝、高照度平光、像素化 + 色阶量化。
	"voxel_creek": {
		"bg_color": Color("78A7FF"),
		"ambient_color": Color("F2F6FF"), "ambient_energy": 1.0,
		"fog_density": 0.006, "fog_color": Color("C3D9FF"),
		"sun_energy": 0.78, "sun_color": Color("FFF8E8"),
		"glow": false,
		"tonemap_mode": Environment.TONE_MAPPER_LINEAR,
		"grade": {
			"pixel_size": 4.0, "posterize_levels": 10.0,
			"saturation": 1.16, "contrast": 1.04,
		},
	},
	# 隐藏3 · 林间 → 合金弹头：军绿密林、暖橙低角度阳光、像素 + 硬色阶 +
	# 扫描线的街机感。雾密度必须 > 0.03（test_level_select 契约）。
	"fairy_woodland": {
		"bg_color": Color("2F3B2C"),
		"ambient_color": Color("8FA08A"), "ambient_energy": 0.62,
		"fog_density": 0.052, "fog_color": Color("31402C"),
		"sun_energy": 0.34, "sun_color": Color("FFC97A"),
		"glow": false,
		"tonemap_mode": Environment.TONE_MAPPER_LINEAR,
		"grade": {
			"pixel_size": 3.0, "posterize_levels": 8.0,
			"saturation": 1.02, "contrast": 1.16,
			"scanline": 0.05, "vignette": 0.12,
		},
	},
	# 隐藏4 · 大院 → 马里奥赛车：晴朗卡丁竞技场的正午阳光、高饱和糖果主色、
	# 霓虹广告牌在白天也吃一点 bloom。太阳能量必须低于 hub 太阳
	# （test_level_select 契约：course 4 dims the hub sun）。
	"neon_courtyard": {
		"bg_color": Color("3E9BFF"),
		"ambient_color": Color("FFF4DC"), "ambient_energy": 0.95,
		"fog_density": 0.006, "fog_color": Color("BFE4FF"),
		"sun_energy": 0.38, "sun_color": Color("FFF6DE"),
		"glow": true, "glow_intensity": 0.5, "glow_bloom": 0.08,
		"tonemap_mode": Environment.TONE_MAPPER_LINEAR,
		"sun_shadow_max_distance": 90.0,
		"grade": {
			"saturation": 1.2, "contrast": 1.07,
			"black_lift": 0.05, "vignette": 0.04,
		},
	},
	# 序章梦魇屠宰场（course 0）→ 写实风：ACES filmic、冷调钢厂工矿光、
	# 薄油雾、低饱和高对比 + 暗角的后处理级调色。不安感来自机器与冷光。
	"nightmare_plant": {
		"bg_color": Color("3F454D"),
		"ambient_color": Color("9FA8B2"), "ambient_energy": 0.72,
		"fog_density": 0.028, "fog_color": Color("5D6672"),
		"sun_energy": 0.42, "sun_color": Color("EDF2F8"),
		"glow": false,
		"tonemap_mode": Environment.TONE_MAPPER_ACES,
		"tonemap_exposure": 1.05,
		"sun_shadow_max_distance": 80.0,
		"grade": {
			"saturation": 0.86, "contrast": 1.14, "vignette": 0.16,
			"tint_col": Color(0.965, 0.99, 1.045), "tint_amount": 0.35,
		},
	},
	# 隐藏1 · 糖豆人式闯关（course 1 牛耕地）→ Fall Guys：糖果综艺色的
	# 高亮平光、轻微辉光、高饱和提亮。牛耕地本是大鹅平涂基准世界，进入
	# 闯关后叠加综艺糖果滤镜（无像素化）。
	"fall_guys_field": {
		"bg_color": Color("8ED9FF"),
		"ambient_color": Color("FFF6E8"), "ambient_energy": 1.05,
		"fog_density": 0.004, "fog_color": Color("E4F6FF"),
		"sun_energy": 0.55, "sun_color": Color("FFF3D0"),
		"glow": true, "glow_intensity": 0.45, "glow_bloom": 0.06,
		"tonemap_mode": Environment.TONE_MAPPER_LINEAR,
		"grade": {
			"saturation": 1.22, "contrast": 1.06,
			"black_lift": 0.06, "vignette": 0.05,
		},
	},
}

var preset: String = ""

var _hub_env: WorldEnvironment = null
var _hub_environment: Environment = null
var _sun: DirectionalLight3D = null
var _sun_energy := 0.0
var _sun_color := Color.WHITE
var _sun_shadow_max_distance := -1.0
var _overrides: Dictionary = {}

static func apply(host: Node, preset_id: String, overrides: Dictionary = {}) -> Node:
	# new() instead of ZoneEnvironment.new(): a freshly added class_name is not in
	# .godot/global_script_class_cache.cfg until the editor rescans, and headless
	# test runs would fail to compile any reference to it by name.
	var ze = new()
	ze.name = "ZoneEnvironment"
	ze.preset = preset_id
	ze._overrides = overrides
	host.add_child(ze)
	return ze

func _ready() -> void:
	var data: Dictionary = PRESETS.get(preset, {}).duplicate(true)
	if data.is_empty():
		push_warning("ZoneEnvironment: unknown preset '%s'" % preset)
		return
	_deep_merge(data, _overrides)
	_swap_hub_environment(_make_environment(data))
	_dim_sun(data)
	if not data.get("grade", {}).is_empty():
		ZONE_GRADE.create(self, data["grade"])

func _exit_tree() -> void:
	if is_instance_valid(_hub_env) and _hub_environment != null:
		_hub_env.environment = _hub_environment
	if is_instance_valid(_sun):
		_sun.light_energy = _sun_energy
		_sun.light_color = _sun_color
		if _sun_shadow_max_distance >= 0.0:
			_sun.directional_shadow_max_distance = _sun_shadow_max_distance

func _make_environment(data: Dictionary) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = data["bg_color"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = data["ambient_color"]
	env.ambient_light_energy = data["ambient_energy"]
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = data["fog_density"]
	env.fog_light_color = data["fog_color"]
	env.tonemap_mode = data.get("tonemap_mode", Environment.TONE_MAPPER_LINEAR)
	env.tonemap_exposure = data.get("tonemap_exposure", 1.0)
	if data.get("glow", false):
		env.glow_enabled = true
		env.glow_intensity = data.get("glow_intensity", 0.6)
		env.glow_bloom = data.get("glow_bloom", 0.1)
	return env

func _swap_hub_environment(course_env: Environment) -> void:
	# Only the office root carries a WorldEnvironment; swap its resource so the
	# zone look is guaranteed regardless of multi-WorldEnvironment resolution.
	for node in _office_root_children():
		if node is WorldEnvironment:
			_hub_env = node
			_hub_environment = _hub_env.environment
			_hub_env.environment = course_env
			return

func _dim_sun(data: Dictionary) -> void:
	for node in _office_root_children():
		if node is DirectionalLight3D:
			_sun = node
			_sun_energy = _sun.light_energy
			_sun_color = _sun.light_color
			_sun.light_energy = data["sun_energy"]
			_sun.light_color = data["sun_color"]
			if data.has("sun_shadow_max_distance"):
				_sun_shadow_max_distance = _sun.directional_shadow_max_distance
				_sun.directional_shadow_max_distance = data["sun_shadow_max_distance"]
			return

func _deep_merge(base: Dictionary, extra: Dictionary) -> void:
	for key in extra:
		if base.has(key) and base[key] is Dictionary and extra[key] is Dictionary:
			_deep_merge(base[key], extra[key])
		else:
			base[key] = extra[key]

func _office_root_children() -> Array:
	# The course hangs under the office scene root, which is the node sitting
	# directly below the SceneTree root window. Walk up to it and scan its
	# direct children (WorldEnvironment/Sun). A course mounted on its own (unit
	# tests) simply finds neither and leaves the world untouched.
	if not is_inside_tree():
		return []
	var tree_root: Node = get_tree().root
	var node := get_parent()
	while node != null and node.get_parent() != null and node.get_parent() != tree_root:
		node = node.get_parent()
	if node == null:
		return []
	return node.get_children()
