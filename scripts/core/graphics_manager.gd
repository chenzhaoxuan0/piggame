extends Node
## 画质档位管理器（2026-11-17 评测新增）：低/中/高三档，持久化到
## user://graphics_settings.json。低档关阴影降分辨率省电，高档 4×MSAA +
## 远阴影 + 色彩分级。场景里后出现的灯/环境由 node_added 自动套档。
signal quality_changed(tier: String)

const TIERS := ["low", "medium", "high"]
const TIER_NAMES := {"low": "低 · 省电", "medium": "中 · 均衡", "high": "高 · 精致"}
const DEFAULT_PATH := "user://graphics_settings.json"
var settings_path := DEFAULT_PATH
var tier := "high"

func _ready() -> void:
	# headless（测试进程）不读真实玩家档案；测试要验证持久化就显式重定向
	# settings_path（GameManager 的同款纪律）。
	if DisplayServer.get_name() != "headless":
		_load()
	apply()
	get_tree().node_added.connect(_on_node_added)

func _load() -> void:
	if not FileAccess.file_exists(settings_path):
		return
	var f := FileAccess.open(settings_path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary and TIERS.has(str(parsed.get("tier", ""))):
		tier = str(parsed.get("tier"))

func _persist() -> void:
	if DisplayServer.get_name() == "headless" and settings_path == DEFAULT_PATH:
		return
	var f := FileAccess.open(settings_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"tier": tier}))
	f.close()

func set_tier(new_tier: String) -> void:
	if not TIERS.has(new_tier) or new_tier == tier:
		return
	tier = new_tier
	_persist()
	apply()
	quality_changed.emit(tier)

func apply() -> void:
	var msaa: int = Viewport.MSAA_4X
	var fxaa := false
	var render_scale := 1.0
	match tier:
		"low":
			msaa = Viewport.MSAA_DISABLED
			fxaa = true
			render_scale = 0.75
		"medium":
			msaa = Viewport.MSAA_2X
	var vp := get_viewport()
	if vp != null:
		vp.msaa_3d = msaa as Viewport.MSAA
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
		vp.scaling_3d_scale = render_scale
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", msaa)
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/screen_space_aa", 1 if fxaa else 0)
	_scan(get_tree().root)

func _on_node_added(node: Node) -> void:
	if node is DirectionalLight3D:
		_apply_light(node)
	elif node is WorldEnvironment:
		_apply_env(node)

func _scan(node: Node) -> void:
	if node is DirectionalLight3D:
		_apply_light(node)
	elif node is WorldEnvironment:
		_apply_env(node)
	for child in node.get_children():
		_scan(child)

func _apply_light(light: DirectionalLight3D) -> void:
	match tier:
		"low":
			light.shadow_enabled = false
		"medium":
			light.shadow_enabled = true
			light.directional_shadow_max_distance = 80.0
		"high":
			light.shadow_enabled = true
			light.directional_shadow_max_distance = 140.0

func _apply_env(world_env: WorldEnvironment) -> void:
	var env := world_env.environment
	if env == null:
		return
	if tier == "low":
		env.adjustment_enabled = false
	else:
		env.adjustment_enabled = true
		env.adjustment_saturation = 1.05 if tier == "medium" else 1.12
		env.adjustment_contrast = 1.03 if tier == "medium" else 1.06
