extends Resource
class_name CourseConfig

@export var course_id: String = ""
@export var title: String = ""
@export var desc: String = ""
@export var kill_y: float = -12.0
@export var bounds: AABB = AABB(Vector3(-60, -20, -150), Vector3(120, 60, 170))
@export var stuck_timeout: float = 4.0
@export var dog_count: int = 1
@export var dog_speed_min: float = 2.6
@export var dog_speed_max: float = 6.2
# Which catalog model dresses the rubber-band chaser (see chase_dog.gd).
# "CHAR_06" farm dog everywhere; the nightmare prologue passes "CHAR_07" to
# chase as the dream farmer with the stun prod.
@export var dog_visual_asset_id: String = "CHAR_06"
@export var dog_close_distance: float = 3.5
@export var dog_far_distance: float = 11.0
@export var dog_catchup_distance: float = 26.0
@export var memes: Dictionary = {}