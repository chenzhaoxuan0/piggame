class_name ZoneEnvironment
extends Node

# Per-course atmosphere for the hidden tracks. The hub's WorldEnvironment and
# Sun live on the office root and stay lit for the farm, so "迷雾林间/霓虹竞技场"
# never actually looked different. This node swaps the hub environment for a
# zone-specific one and dims the Sun, then restores both in _exit_tree(); it is
# freed together with the course, so there is no manual teardown anywhere.
#
# Usage: ZoneEnvironment.apply(self, "fairy_woodland") from a course's _ready().

const PRESETS := {
	# Minecraft voxel creek: bright saturated day with a hint of water haze.
	"voxel_creek": {
		"bg_color": Color("7EC0EE"),
		"ambient_color": Color("E8F7FF"), "ambient_energy": 0.95,
		"fog_density": 0.006, "fog_color": Color("CFEFFF"),
		"sun_energy": 0.7, "sun_color": Color("FFF4D6"),
		"glow": false,
	},
	# Fairytale woodland: cool mist at ~20-25 m visibility, dim warm sun.
	"fairy_woodland": {
		"bg_color": Color("8FA3BF"),
		"ambient_color": Color("B8C4DC"), "ambient_energy": 0.55,
		"fog_density": 0.045, "fog_color": Color("A9BDD6"),
		"sun_energy": 0.3, "sun_color": Color("E8E4D0"),
		"glow": false,
	},
	# Neon variety-show courtyard: dusk navy sky, glow bloom for the neon set.
	"neon_courtyard": {
		"bg_color": Color("0B1226"),
		"ambient_color": Color("44507E"), "ambient_energy": 0.6,
		"fog_density": 0.015, "fog_color": Color("141E42"),
		"sun_energy": 0.12, "sun_color": Color("6F86C9"),
		"glow": true,
	},
	# Nightmare meat plant (course 0 prologue dream): a working FACTORY, not
	# hell - cool grey hangar light, thin industrial haze, white fluorescent
	# sun. The unease comes from the machinery, not from darkness. Gameplay-line
	# provisional look; the art line owns the final zone style (AGENTS.md S5).
	"nightmare_plant": {
		"bg_color": Color("454C55"),
		"ambient_color": Color("ACB4BE"), "ambient_energy": 0.85,
		"fog_density": 0.022, "fog_color": Color("6B7480"),
		"sun_energy": 0.32, "sun_color": Color("FFF4E6"),
		"glow": false,
	},
}

var preset: String = ""

var _hub_env: WorldEnvironment = null
var _hub_environment: Environment = null
var _sun: DirectionalLight3D = null
var _sun_energy := 0.0
var _sun_color := Color.WHITE

static func apply(host: Node, preset_id: String) -> Node:
	# new() instead of ZoneEnvironment.new(): a freshly added class_name is not in
	# .godot/global_script_class_cache.cfg until the editor rescans, and headless
	# test runs would fail to compile any reference to it by name.
	var ze = new()
	ze.name = "ZoneEnvironment"
	ze.preset = preset_id
	host.add_child(ze)
	return ze

func _ready() -> void:
	var data: Dictionary = PRESETS.get(preset, {})
	if data.is_empty():
		push_warning("ZoneEnvironment: unknown preset '%s'" % preset)
		return
	_swap_hub_environment(_make_environment(data))
	_dim_sun(data)

func _exit_tree() -> void:
	if is_instance_valid(_hub_env) and _hub_environment != null:
		_hub_env.environment = _hub_environment
	if is_instance_valid(_sun):
		_sun.light_energy = _sun_energy
		_sun.light_color = _sun_color

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
	if data.get("glow", false):
		env.glow_enabled = true
		env.glow_intensity = 0.6
		env.glow_bloom = 0.1
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
			return

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
