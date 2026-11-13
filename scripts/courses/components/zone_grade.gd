extends CanvasLayer

# 分区画风的全屏调色/后处理层（调色、像素化、色阶量化、暗角、扫描线）。
# 放在 layer = -1：3D 画面先于所有 canvas 层绘制，-1 层恰好盖在世界之上、
# 又在 HUD(layer 1) / 弹幕层(10) / 成就层(11) 之下，中文 UI 不吃滤镜。
# 用 CanvasLayer + hint_screen_texture 的自写 shader 而不是 Environment
# adjustments，因为本项目 gl_compatibility 渲染器不保证支持 adjustments。
#
# ZoneGrade.create(host, params) 随宿主一起释放；静态栈保证任意时刻只有
# 最新一层显示——hub 的常驻柔光滤镜在进入关卡时被压栈隐藏，关卡退出后
# 自动复显（关卡之间连续切换同样成立）。
#
# 不加 class_name：新类名在编辑器重扫前不进全局类缓存，headless 测试会
# 编译失败；统一走 preload + create()（与 zone_environment.apply 同理）。

const SHADER := preload("res://scripts/courses/components/zone_grade.gdshader")

static var _stack: Array = []

var _params: Dictionary = {}

static func create(host: Node, params: Dictionary) -> CanvasLayer:
	var grade: CanvasLayer = new()
	grade.name = "ZoneGrade"
	grade.layer = -1
	grade._params = params
	host.add_child(grade)
	return grade

func _ready() -> void:
	# Idempotence guard: if this node is ever removed and re-added to the tree
	# (reparent path), _ready runs again - don't stack a second GradeRect or
	# push a duplicate stack entry, just re-assert top position.
	if get_child_count() > 0:
		_become_top()
		return
	var rect := ColorRect.new()
	rect.name = "GradeRect"
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = SHADER
	for key in _params:
		material.set_shader_parameter(key, _params[key])
	rect.material = material
	add_child(rect)
	_become_top()

func _become_top() -> void:
	for other in _stack:
		if other != self and other is CanvasLayer and is_instance_valid(other):
			other.visible = false
	_stack.erase(self)
	_stack.push_back(self)
	visible = true

func _exit_tree() -> void:
	_stack.erase(self)
	# 弹栈后复显栈顶仍然存活的一层（例如 hub 的大鹅柔光滤镜）。
	for i in range(_stack.size() - 1, -1, -1):
		var next = _stack[i]
		if is_instance_valid(next):
			next.visible = true
			break
		_stack.remove_at(i)
