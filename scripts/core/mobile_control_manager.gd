extends Node
## 移动端控制与横屏模式管理器：
## 1) 自动识别当前是否运行在移动设备（Web 端结合 OS 特性与 JS 触屏/UA 检测）；
## 2) 管理虚拟摇杆与触屏按键开关（默认跟随设备检测，支持玩家手动一键切换并持久化）；
## 3) 管理 Web 端横屏策略（"auto" 默认尝试全屏横屏 + 竖屏轻提示；"force" 强制 90° 旋转横屏）；
## 4) 保存当前虚拟摇杆方向向量，供 PigController 直接读取，与键盘互不干扰。

signal touch_controls_changed(enabled: bool)
signal landscape_mode_changed(mode: String)

const LANDSCAPE_MODES := ["auto", "force"]
const DEFAULT_PATH := "user://mobile_settings.json"

var settings_path := DEFAULT_PATH
var is_mobile_detected := false
var touch_controls_enabled := false
var _touch_user_override := false
var landscape_mode := "auto"
var joystick_vector := Vector2.ZERO

func _ready() -> void:
	is_mobile_detected = detect_mobile_device()
	touch_controls_enabled = is_mobile_detected
	# headless 测试进程不读真实玩家档案（与 GraphicsManager 同款纪律）。
	if DisplayServer.get_name() != "headless":
		_load()
	_sync_web_landscape()

func detect_mobile_device() -> bool:
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	if OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge"):
		var res = JavaScriptBridge.eval("Boolean(window.__pigMobile && window.__pigMobile.isMobile)")
		if res is bool and res:
			return true
	return false

func _load() -> void:
	if not FileAccess.file_exists(settings_path):
		return
	var f := FileAccess.open(settings_path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return
	if parsed.has("touch_controls_enabled"):
		touch_controls_enabled = bool(parsed.get("touch_controls_enabled"))
		_touch_user_override = true
	var saved_landscape := str(parsed.get("landscape_mode", ""))
	if LANDSCAPE_MODES.has(saved_landscape):
		landscape_mode = saved_landscape

func _persist() -> void:
	if DisplayServer.get_name() == "headless" and settings_path == DEFAULT_PATH:
		return
	var f := FileAccess.open(settings_path, FileAccess.WRITE)
	if f == null:
		return
	var data := {
		"landscape_mode": landscape_mode,
	}
	if _touch_user_override:
		data["touch_controls_enabled"] = touch_controls_enabled
	f.store_string(JSON.stringify(data))
	f.close()

func is_touch_controls_active() -> bool:
	return touch_controls_enabled

func set_touch_controls_enabled(enabled: bool) -> void:
	_touch_user_override = true
	if touch_controls_enabled == enabled:
		_persist()
		return
	touch_controls_enabled = enabled
	if not enabled:
		clear_virtual_inputs()
	_persist()
	touch_controls_changed.emit(touch_controls_enabled)

func toggle_touch_controls() -> bool:
	set_touch_controls_enabled(not touch_controls_enabled)
	return touch_controls_enabled

func set_landscape_mode(mode: String) -> void:
	if not LANDSCAPE_MODES.has(mode):
		return
	var changed := (landscape_mode != mode)
	landscape_mode = mode
	_persist()
	_sync_web_landscape()
	if changed:
		landscape_mode_changed.emit(landscape_mode)

func toggle_landscape_mode() -> String:
	var next_mode := "force" if landscape_mode == "auto" else "auto"
	set_landscape_mode(next_mode)
	return landscape_mode

func request_native_landscape() -> void:
	if OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge"):
		JavaScriptBridge.eval("window.__pigMobile && window.__pigMobile.requestLandscape && window.__pigMobile.requestLandscape()")

func _sync_web_landscape() -> void:
	if OS.has_feature("web") and ClassDB.class_exists("JavaScriptBridge"):
		var escaped := "force" if landscape_mode == "force" else "auto"
		JavaScriptBridge.eval("window.__pigMobile && window.__pigMobile.setLandscapeMode && window.__pigMobile.setLandscapeMode('%s')" % escaped)

func set_joystick_vector(vec: Vector2) -> void:
	if vec.length_squared() < 0.001:
		joystick_vector = Vector2.ZERO
	else:
		joystick_vector = vec.limit_length(1.0)

func clear_virtual_inputs() -> void:
	joystick_vector = Vector2.ZERO
	for action_name in ["action_dash", "action_jump", "action_interact"]:
		if InputMap.has_action(action_name) and Input.is_action_pressed(action_name):
			var ev := InputEventAction.new()
			ev.action = action_name
			ev.pressed = false
			Input.parse_input_event(ev)

func touch_mode_label() -> String:
	return "📱 触屏摇杆：开" if touch_controls_enabled else "📱 触屏摇杆：关"

func landscape_mode_label() -> String:
	return "🔄 横屏：强制" if landscape_mode == "force" else "🔄 横屏：自动"
