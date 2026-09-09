## CavemanModel.gd
## 3D Character model supporting Rafael's Poly Pizza Rigged Character (52 bones,
## vertex skinning, natural side-hanging idle & walk gait animations, and shader customization)
## with fallback to the stylized low-poly blocky caveman aesthetic.

class_name CavemanModel
extends Node3D

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------
@export var customization: CharacterCustomizationData = null:
	set(value):
		customization = value
		if is_inside_tree() and customization:
			apply_customization(customization)

## The authored modular mesh is the canonical Cave Raiders design language:
## lanky planes, huge eyes, primitive-shape clothing. The old imported humanoid
## remains an opt-in compatibility path for legacy animation experiments.
@export var use_rigged_character: bool = false
@export var use_unified_mesh: bool = false
@export_range(1, 5) var evolution_stage: int = 1

# Materials
var mat_skin: StandardMaterial3D
var mat_hair: StandardMaterial3D
var mat_clothing: StandardMaterial3D
var mat_accent: StandardMaterial3D
var mat_eyes_white: StandardMaterial3D
var mat_eyes_pupil: StandardMaterial3D

# Rigged character references
var rigged_instance: Node3D = null
var skeleton: Skeleton3D = null
var anim_player: AnimationPlayer = null
var char_mesh: MeshInstance3D = null
var mat_rigged: ShaderMaterial = null

# Node references for animation and ragdoll synchronization
var root_pivot: Node3D
var torso: MeshInstance3D
var head_pivot: Node3D
var head: MeshInstance3D
var stage_visuals: Node3D
var expression: String = "neutral"

# Held-item / attachment sockets (spec section 8). Always present so tools,
# torches, glow rocks and carried objects have a stable mount point.
var held_item_socket_l: Marker3D
var held_item_socket_r: Marker3D
var head_socket: Marker3D

var arm_left_pivot: Node3D
var arm_left_upper: MeshInstance3D
var arm_right_pivot: Node3D
var arm_right_upper: MeshInstance3D

var leg_left_pivot: Node3D
var leg_left_upper: MeshInstance3D
var leg_right_pivot: Node3D
var leg_right_upper: MeshInstance3D

# Animation state
var is_moving: bool = false
var walk_speed_factor: float = 10.0
var _anim_time: float = 0.0
var _action_timer: float = 0.0
var enable_idle_bob: bool = true

# AnimationTree-compatible state name. Mirrors the AnimationPlayer state so
# an AnimationTree state machine (or plain AnimationPlayer.travel-less code)
# can drive the mesh without hardcoding transitions into the mesh.
var current_state: String = "idle"

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _init() -> void:
	_init_materials()

func _ready() -> void:
	if not mat_skin:
		_init_materials()
	_build_character_mesh()
	if customization:
		apply_customization(customization)
	else:
		apply_customization(CharacterCustomizationData.get_default())

func _init_materials() -> void:
	if mat_skin:
		return

	# Skin: flat diffuse shading
	mat_skin = StandardMaterial3D.new()
	mat_skin.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_skin.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_skin.roughness = 0.85

	# Hair & Beard
	mat_hair = StandardMaterial3D.new()
	mat_hair.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_hair.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_hair.roughness = 0.95

	# Clothing / Pelt Overalls
	mat_clothing = StandardMaterial3D.new()
	mat_clothing.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_clothing.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_clothing.roughness = 0.90

	# Bone & Accents
	mat_accent = StandardMaterial3D.new()
	mat_accent.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_accent.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_accent.roughness = 0.60

	# Eyeballs
	mat_eyes_white = StandardMaterial3D.new()
	mat_eyes_white.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_eyes_white.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_eyes_white.albedo_color = Color(0.96, 0.96, 0.94)
	mat_eyes_white.roughness = 0.25

	mat_eyes_pupil = StandardMaterial3D.new()
	mat_eyes_pupil.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_eyes_pupil.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_eyes_pupil.albedo_color = Color(0.06, 0.06, 0.06)
	mat_eyes_pupil.roughness = 0.20

# ---------------------------------------------------------------------------
# Mesh Construction
# ---------------------------------------------------------------------------
func _build_character_mesh() -> void:
	for child in get_children():
		child.queue_free()

	root_pivot = Node3D.new()
	root_pivot.name = "RootPivot"
	add_child(root_pivot)

	if use_rigged_character:
		_build_rigged_character()
		return

	if use_unified_mesh:
		_build_unified_mesh()
		return

	_build_modular_caveman()

func _build_rigged_character() -> void:
	var glb_res := load("res://assets/models/character/rafael/rigged_character.glb") as PackedScene
	if not glb_res:
		push_warning("Failed to load rigged_character.glb, falling back to modular caveman")
		_build_modular_caveman()
		return

	rigged_instance = glb_res.instantiate() as Node3D
	rigged_instance.name = "RiggedCharacter"
	# Scale character to standard 1.85m human height and rotate 180 deg to face -Z (forward)
	rigged_instance.scale = Vector3(0.185, 0.185, 0.185)
	rigged_instance.rotation = Vector3(0.0, PI, 0.0)
	root_pivot.add_child(rigged_instance)

	skeleton = rigged_instance.find_child("Skeleton3D", true, false)
	anim_player = rigged_instance.find_child("AnimationPlayer", true, false)
	char_mesh = rigged_instance.find_child("Cube", true, false)

	# Shader material for body part coloring
	var char_shader := load("res://shaders/character_rigged.gdshader") as Shader
	if char_shader:
		mat_rigged = ShaderMaterial.new()
		mat_rigged.shader = char_shader
		if char_mesh:
			char_mesh.material_override = mat_rigged

	# Generate animations in AnimationPlayer
	if anim_player and skeleton:
		_setup_character_animations(anim_player, skeleton)
		anim_player.play("idle")

	# Setup bone attachments and proxy mesh nodes for ragdoll / camera compatibility
	head_pivot = Node3D.new()
	head_pivot.name = "HeadPivot"
	root_pivot.add_child(head_pivot)

	if skeleton:
		var ba_head := BoneAttachment3D.new()
		ba_head.bone_name = "mixamorig_Head"
		skeleton.add_child(ba_head)
		head = MeshInstance3D.new()
		head.name = "Head"
		ba_head.add_child(head)

		var ba_spine := BoneAttachment3D.new()
		ba_spine.bone_name = "mixamorig_Spine1"
		skeleton.add_child(ba_spine)
		torso = MeshInstance3D.new()
		torso.name = "Torso"
		ba_spine.add_child(torso)

		var ba_la := BoneAttachment3D.new()
		ba_la.bone_name = "mixamorig_LeftArm"
		skeleton.add_child(ba_la)
		arm_left_upper = MeshInstance3D.new()
		arm_left_upper.name = "ArmLeft"
		ba_la.add_child(arm_left_upper)

		var ba_ra := BoneAttachment3D.new()
		ba_ra.bone_name = "mixamorig_RightArm"
		skeleton.add_child(ba_ra)
		arm_right_upper = MeshInstance3D.new()
		arm_right_upper.name = "ArmRight"
		ba_ra.add_child(arm_right_upper)

		var ba_ll := BoneAttachment3D.new()
		ba_ll.bone_name = "mixamorig_LeftUpLeg"
		skeleton.add_child(ba_ll)
		leg_left_upper = MeshInstance3D.new()
		leg_left_upper.name = "LegLeft"
		ba_ll.add_child(leg_left_upper)

		var ba_rl := BoneAttachment3D.new()
		ba_rl.bone_name = "mixamorig_RightUpLeg"
		skeleton.add_child(ba_rl)
		leg_right_upper = MeshInstance3D.new()
		leg_right_upper.name = "LegRight"
		ba_rl.add_child(leg_right_upper)
	else:
		torso = MeshInstance3D.new()
		root_pivot.add_child(torso)
		head = MeshInstance3D.new()
		head_pivot.add_child(head)

	_ensure_sockets()

func _setup_character_animations(ap: AnimationPlayer, skel: Skeleton3D) -> void:
	var lib: AnimationLibrary
	if ap.has_animation_library(""):
		lib = ap.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		ap.add_animation_library("", lib)

	# Extract bone indices and rests
	var b_l_arm := skel.find_bone("mixamorig_LeftArm")
	var b_r_arm := skel.find_bone("mixamorig_RightArm")
	var b_l_fa  := skel.find_bone("mixamorig_LeftForeArm")
	var b_r_fa  := skel.find_bone("mixamorig_RightForeArm")
	var b_spine1 := skel.find_bone("mixamorig_Spine1")
	var b_head  := skel.find_bone("mixamorig_Head")
	var b_hips  := skel.find_bone("mixamorig_Hips")
	var b_l_leg := skel.find_bone("mixamorig_LeftUpLeg")
	var b_r_leg := skel.find_bone("mixamorig_RightUpLeg")
	var b_l_knee := skel.find_bone("mixamorig_LeftLeg")
	var b_r_knee := skel.find_bone("mixamorig_RightLeg")

	var rest_la := skel.get_bone_rest(b_l_arm) if b_l_arm >= 0 else Transform3D()
	var rest_ra := skel.get_bone_rest(b_r_arm) if b_r_arm >= 0 else Transform3D()
	var rest_l_fa := skel.get_bone_rest(b_l_fa) if b_l_fa >= 0 else Transform3D()
	var rest_r_fa := skel.get_bone_rest(b_r_fa) if b_r_fa >= 0 else Transform3D()
	var rest_spine1 := skel.get_bone_rest(b_spine1) if b_spine1 >= 0 else Transform3D()
	var rest_head := skel.get_bone_rest(b_head) if b_head >= 0 else Transform3D()
	var rest_hips := skel.get_bone_rest(b_hips) if b_hips >= 0 else Transform3D()
	var rest_l_leg := skel.get_bone_rest(b_l_leg) if b_l_leg >= 0 else Transform3D()
	var rest_r_leg := skel.get_bone_rest(b_r_leg) if b_r_leg >= 0 else Transform3D()
	var rest_l_knee := skel.get_bone_rest(b_l_knee) if b_l_knee >= 0 else Transform3D()
	var rest_r_knee := skel.get_bone_rest(b_r_knee) if b_r_knee >= 0 else Transform3D()

	# Downward resting arm rotations (breaks Mixamo 90-deg T-pose down to natural side-hanging pose)
	var delta_l_idle := Vector3(deg_to_rad(85), deg_to_rad(-5), deg_to_rad(-40))
	var delta_r_idle := Vector3(deg_to_rad(85), deg_to_rad(5), deg_to_rad(40))

	var q_l_idle := rest_la.basis.get_rotation_quaternion() * Basis.from_euler(delta_l_idle).get_rotation_quaternion()
	var q_r_idle := rest_ra.basis.get_rotation_quaternion() * Basis.from_euler(delta_r_idle).get_rotation_quaternion()
	var q_l_fa_idle := rest_l_fa.basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, deg_to_rad(15))
	var q_r_fa_idle := rest_r_fa.basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, deg_to_rad(15))

	var q_spine1 := rest_spine1.basis.get_rotation_quaternion()
	var q_head := rest_head.basis.get_rotation_quaternion()
	var hips_rest_pos := rest_hips.origin
	var q_l_leg := rest_l_leg.basis.get_rotation_quaternion()
	var q_r_leg := rest_r_leg.basis.get_rotation_quaternion()
	var q_l_knee := rest_l_knee.basis.get_rotation_quaternion()
	var q_r_knee := rest_r_knee.basis.get_rotation_quaternion()

	# -------------------------------------------------------------
	# 1. IDLE ANIMATION (Looping natural relaxed humanoid stance, breathing & micro-sway)
	# -------------------------------------------------------------
	var anim_idle := Animation.new()
	anim_idle.length = 2.4
	anim_idle.loop_mode = Animation.LOOP_LINEAR

	# Hips subtle breathing lift
	if b_hips >= 0:
		var t_hb := anim_idle.add_track(Animation.TYPE_POSITION_3D)
		anim_idle.track_set_path(t_hb, "RootNode/Skeleton3D:mixamorig_Hips")
		anim_idle.position_track_insert_key(t_hb, 0.0, hips_rest_pos)
		anim_idle.position_track_insert_key(t_hb, 1.2, hips_rest_pos + Vector3(0.0, 0.02, 0.0))
		anim_idle.position_track_insert_key(t_hb, 2.4, hips_rest_pos)

	# Spine breathing expansion
	if b_spine1 >= 0:
		var t_sp := anim_idle.add_track(Animation.TYPE_ROTATION_3D)
		anim_idle.track_set_path(t_sp, "RootNode/Skeleton3D:mixamorig_Spine1")
		anim_idle.rotation_track_insert_key(t_sp, 0.0, q_spine1)
		anim_idle.rotation_track_insert_key(t_sp, 1.2, q_spine1 * Quaternion(Vector3.RIGHT, 0.035))
		anim_idle.rotation_track_insert_key(t_sp, 2.4, q_spine1)

	# Head subtle micro-drift
	if b_head >= 0:
		var t_hd := anim_idle.add_track(Animation.TYPE_ROTATION_3D)
		anim_idle.track_set_path(t_hd, "RootNode/Skeleton3D:mixamorig_Head")
		anim_idle.rotation_track_insert_key(t_hd, 0.0, q_head)
		anim_idle.rotation_track_insert_key(t_hd, 0.8, q_head * Quaternion(Vector3.UP, 0.04))
		anim_idle.rotation_track_insert_key(t_hd, 1.6, q_head * Quaternion(Vector3.UP, -0.04))
		anim_idle.rotation_track_insert_key(t_hd, 2.4, q_head)

	# Arms hanging naturally at sides (NOT T-pose!)
	if b_l_arm >= 0 and b_r_arm >= 0:
		var t_la := anim_idle.add_track(Animation.TYPE_ROTATION_3D)
		anim_idle.track_set_path(t_la, "RootNode/Skeleton3D:mixamorig_LeftArm")
		anim_idle.rotation_track_insert_key(t_la, 0.0, q_l_idle)
		anim_idle.rotation_track_insert_key(t_la, 1.2, q_l_idle * Quaternion(Vector3.FORWARD, 0.03))
		anim_idle.rotation_track_insert_key(t_la, 2.4, q_l_idle)

		var t_ra := anim_idle.add_track(Animation.TYPE_ROTATION_3D)
		anim_idle.track_set_path(t_ra, "RootNode/Skeleton3D:mixamorig_RightArm")
		anim_idle.rotation_track_insert_key(t_ra, 0.0, q_r_idle)
		anim_idle.rotation_track_insert_key(t_ra, 1.2, q_r_idle * Quaternion(Vector3.FORWARD, -0.03))
		anim_idle.rotation_track_insert_key(t_ra, 2.4, q_r_idle)

	# Forearms slight inward elbow bend
	if b_l_fa >= 0 and b_r_fa >= 0:
		var t_lfa := anim_idle.add_track(Animation.TYPE_ROTATION_3D)
		anim_idle.track_set_path(t_lfa, "RootNode/Skeleton3D:mixamorig_LeftForeArm")
		anim_idle.rotation_track_insert_key(t_lfa, 0.0, q_l_fa_idle)
		anim_idle.rotation_track_insert_key(t_lfa, 1.2, q_l_fa_idle * Quaternion(Vector3.RIGHT, 0.02))
		anim_idle.rotation_track_insert_key(t_lfa, 2.4, q_l_fa_idle)

		var t_rfa := anim_idle.add_track(Animation.TYPE_ROTATION_3D)
		anim_idle.track_set_path(t_rfa, "RootNode/Skeleton3D:mixamorig_RightForeArm")
		anim_idle.rotation_track_insert_key(t_rfa, 0.0, q_r_fa_idle)
		anim_idle.rotation_track_insert_key(t_rfa, 1.2, q_r_fa_idle * Quaternion(Vector3.RIGHT, 0.02))
		anim_idle.rotation_track_insert_key(t_rfa, 2.4, q_r_fa_idle)

	# Legs in relaxed standing pose
	if b_l_leg >= 0 and b_r_leg >= 0:
		var t_ll := anim_idle.add_track(Animation.TYPE_ROTATION_3D)
		anim_idle.track_set_path(t_ll, "RootNode/Skeleton3D:mixamorig_LeftUpLeg")
		anim_idle.rotation_track_insert_key(t_ll, 0.0, q_l_leg)
		anim_idle.rotation_track_insert_key(t_ll, 2.4, q_l_leg)

		var t_rl := anim_idle.add_track(Animation.TYPE_ROTATION_3D)
		anim_idle.track_set_path(t_rl, "RootNode/Skeleton3D:mixamorig_RightUpLeg")
		anim_idle.rotation_track_insert_key(t_rl, 0.0, q_r_leg)
		anim_idle.rotation_track_insert_key(t_rl, 2.4, q_r_leg)

	lib.add_animation("idle", anim_idle)

	# -------------------------------------------------------------
	# 2. WALK ANIMATION (Looping rhythmic humanoid gait with knee flexion & natural arm swings)
	# -------------------------------------------------------------
	var anim_walk := Animation.new()
	anim_walk.length = 1.0
	anim_walk.loop_mode = Animation.LOOP_LINEAR

	# Hips step bobbing & lateral weight transfer
	if b_hips >= 0:
		var t_hw := anim_walk.add_track(Animation.TYPE_POSITION_3D)
		anim_walk.track_set_path(t_hw, "RootNode/Skeleton3D:mixamorig_Hips")
		anim_walk.position_track_insert_key(t_hw, 0.0, hips_rest_pos)
		anim_walk.position_track_insert_key(t_hw, 0.25, hips_rest_pos - Vector3(0.02, 0.07, 0.0))
		anim_walk.position_track_insert_key(t_hw, 0.50, hips_rest_pos)
		anim_walk.position_track_insert_key(t_hw, 0.75, hips_rest_pos - Vector3(-0.02, 0.07, 0.0))
		anim_walk.position_track_insert_key(t_hw, 1.0, hips_rest_pos)

	# Spine counter-twist
	if b_spine1 >= 0:
		var t_sp_w := anim_walk.add_track(Animation.TYPE_ROTATION_3D)
		anim_walk.track_set_path(t_sp_w, "RootNode/Skeleton3D:mixamorig_Spine1")
		anim_walk.rotation_track_insert_key(t_sp_w, 0.0, q_spine1)
		anim_walk.rotation_track_insert_key(t_sp_w, 0.25, q_spine1 * Quaternion(Vector3.UP, 0.06))
		anim_walk.rotation_track_insert_key(t_sp_w, 0.50, q_spine1)
		anim_walk.rotation_track_insert_key(t_sp_w, 0.75, q_spine1 * Quaternion(Vector3.UP, -0.06))
		anim_walk.rotation_track_insert_key(t_sp_w, 1.0, q_spine1)

	# Legs strides
	if b_l_leg >= 0 and b_r_leg >= 0:
		var t_ll_w := anim_walk.add_track(Animation.TYPE_ROTATION_3D)
		anim_walk.track_set_path(t_ll_w, "RootNode/Skeleton3D:mixamorig_LeftUpLeg")
		anim_walk.rotation_track_insert_key(t_ll_w, 0.0, q_l_leg)
		anim_walk.rotation_track_insert_key(t_ll_w, 0.25, q_l_leg * Quaternion(Vector3.RIGHT, 0.50))
		anim_walk.rotation_track_insert_key(t_ll_w, 0.50, q_l_leg)
		anim_walk.rotation_track_insert_key(t_ll_w, 0.75, q_l_leg * Quaternion(Vector3.RIGHT, -0.40))
		anim_walk.rotation_track_insert_key(t_ll_w, 1.0, q_l_leg)

		var t_rl_w := anim_walk.add_track(Animation.TYPE_ROTATION_3D)
		anim_walk.track_set_path(t_rl_w, "RootNode/Skeleton3D:mixamorig_RightUpLeg")
		anim_walk.rotation_track_insert_key(t_rl_w, 0.0, q_r_leg)
		anim_walk.rotation_track_insert_key(t_rl_w, 0.25, q_r_leg * Quaternion(Vector3.RIGHT, -0.40))
		anim_walk.rotation_track_insert_key(t_rl_w, 0.50, q_r_leg)
		anim_walk.rotation_track_insert_key(t_rl_w, 0.75, q_r_leg * Quaternion(Vector3.RIGHT, 0.50))
		anim_walk.rotation_track_insert_key(t_rl_w, 1.0, q_r_leg)

	# Knees flexion
	if b_l_knee >= 0 and b_r_knee >= 0:
		var t_lk_w := anim_walk.add_track(Animation.TYPE_ROTATION_3D)
		anim_walk.track_set_path(t_lk_w, "RootNode/Skeleton3D:mixamorig_LeftLeg")
		anim_walk.rotation_track_insert_key(t_lk_w, 0.0, q_l_knee)
		anim_walk.rotation_track_insert_key(t_lk_w, 0.25, q_l_knee)
		anim_walk.rotation_track_insert_key(t_lk_w, 0.50, q_l_knee * Quaternion(Vector3.RIGHT, 0.20))
		anim_walk.rotation_track_insert_key(t_lk_w, 0.75, q_l_knee * Quaternion(Vector3.RIGHT, 0.55))
		anim_walk.rotation_track_insert_key(t_lk_w, 1.0, q_l_knee)

		var t_rk_w := anim_walk.add_track(Animation.TYPE_ROTATION_3D)
		anim_walk.track_set_path(t_rk_w, "RootNode/Skeleton3D:mixamorig_RightLeg")
		anim_walk.rotation_track_insert_key(t_rk_w, 0.0, q_r_knee)
		anim_walk.rotation_track_insert_key(t_rk_w, 0.25, q_r_knee * Quaternion(Vector3.RIGHT, 0.55))
		anim_walk.rotation_track_insert_key(t_rk_w, 0.50, q_r_knee * Quaternion(Vector3.RIGHT, 0.20))
		anim_walk.rotation_track_insert_key(t_rk_w, 0.75, q_r_knee)
		anim_walk.rotation_track_insert_key(t_rk_w, 1.0, q_r_knee)

	# Arms swinging forward and backward from downward resting position (opposite to legs!)
	if b_l_arm >= 0 and b_r_arm >= 0:
		var t_la_w := anim_walk.add_track(Animation.TYPE_ROTATION_3D)
		anim_walk.track_set_path(t_la_w, "RootNode/Skeleton3D:mixamorig_LeftArm")
		anim_walk.rotation_track_insert_key(t_la_w, 0.0, q_l_idle)
		anim_walk.rotation_track_insert_key(t_la_w, 0.25, q_l_idle * Quaternion(Vector3.FORWARD, deg_to_rad(-22)))
		anim_walk.rotation_track_insert_key(t_la_w, 0.50, q_l_idle)
		anim_walk.rotation_track_insert_key(t_la_w, 0.75, q_l_idle * Quaternion(Vector3.FORWARD, deg_to_rad(28)))
		anim_walk.rotation_track_insert_key(t_la_w, 1.0, q_l_idle)

		var t_ra_w := anim_walk.add_track(Animation.TYPE_ROTATION_3D)
		anim_walk.track_set_path(t_ra_w, "RootNode/Skeleton3D:mixamorig_RightArm")
		anim_walk.rotation_track_insert_key(t_ra_w, 0.0, q_r_idle)
		anim_walk.rotation_track_insert_key(t_ra_w, 0.25, q_r_idle * Quaternion(Vector3.FORWARD, deg_to_rad(-28)))
		anim_walk.rotation_track_insert_key(t_ra_w, 0.50, q_r_idle)
		anim_walk.rotation_track_insert_key(t_ra_w, 0.75, q_r_idle * Quaternion(Vector3.FORWARD, deg_to_rad(22)))
		anim_walk.rotation_track_insert_key(t_ra_w, 1.0, q_r_idle)

	# Forearms natural elbow flexion on forward swing
	if b_l_fa >= 0 and b_r_fa >= 0:
		var t_lfa_w := anim_walk.add_track(Animation.TYPE_ROTATION_3D)
		anim_walk.track_set_path(t_lfa_w, "RootNode/Skeleton3D:mixamorig_LeftForeArm")
		anim_walk.rotation_track_insert_key(t_lfa_w, 0.0, q_l_fa_idle)
		anim_walk.rotation_track_insert_key(t_lfa_w, 0.25, q_l_fa_idle * Quaternion(Vector3.RIGHT, deg_to_rad(-8)))
		anim_walk.rotation_track_insert_key(t_lfa_w, 0.50, q_l_fa_idle)
		anim_walk.rotation_track_insert_key(t_lfa_w, 0.75, q_l_fa_idle * Quaternion(Vector3.RIGHT, deg_to_rad(20)))
		anim_walk.rotation_track_insert_key(t_lfa_w, 1.0, q_l_fa_idle)

		var t_rfa_w := anim_walk.add_track(Animation.TYPE_ROTATION_3D)
		anim_walk.track_set_path(t_rfa_w, "RootNode/Skeleton3D:mixamorig_RightForeArm")
		anim_walk.rotation_track_insert_key(t_rfa_w, 0.0, q_r_fa_idle)
		anim_walk.rotation_track_insert_key(t_rfa_w, 0.25, q_r_fa_idle * Quaternion(Vector3.RIGHT, deg_to_rad(20)))
		anim_walk.rotation_track_insert_key(t_rfa_w, 0.50, q_r_fa_idle)
		anim_walk.rotation_track_insert_key(t_rfa_w, 0.75, q_r_fa_idle * Quaternion(Vector3.RIGHT, deg_to_rad(-8)))
		anim_walk.rotation_track_insert_key(t_rfa_w, 1.0, q_r_fa_idle)

	lib.add_animation("walk", anim_walk)

	# -------------------------------------------------------------
	# 3. SPEAR THROW ANIMATION (Overhand draw back, explosive kinetic release)
	# -------------------------------------------------------------
	var anim_throw := Animation.new()
	anim_throw.length = 0.55
	anim_throw.loop_mode = Animation.LOOP_NONE

	# Spine twisting and leaning back
	if b_spine1 >= 0:
		var t_sp_t := anim_throw.add_track(Animation.TYPE_ROTATION_3D)
		anim_throw.track_set_path(t_sp_t, "RootNode/Skeleton3D:mixamorig_Spine1")
		anim_throw.rotation_track_insert_key(t_sp_t, 0.0, q_spine1)
		anim_throw.rotation_track_insert_key(t_sp_t, 0.16, q_spine1 * Quaternion(Vector3.UP, deg_to_rad(-25)) * Quaternion(Vector3.RIGHT, deg_to_rad(-12)))
		anim_throw.rotation_track_insert_key(t_sp_t, 0.30, q_spine1 * Quaternion(Vector3.UP, deg_to_rad(15)) * Quaternion(Vector3.RIGHT, deg_to_rad(20)))
		anim_throw.rotation_track_insert_key(t_sp_t, 0.55, q_spine1)

	# Right Arm: Wind-up over shoulder and explosive forward throw
	if b_r_arm >= 0:
		var t_ra_t := anim_throw.add_track(Animation.TYPE_ROTATION_3D)
		anim_throw.track_set_path(t_ra_t, "RootNode/Skeleton3D:mixamorig_RightArm")
		anim_throw.rotation_track_insert_key(t_ra_t, 0.0, q_r_idle)
		anim_throw.rotation_track_insert_key(t_ra_t, 0.16, rest_ra.basis.get_rotation_quaternion() * Basis.from_euler(Vector3(deg_to_rad(-45), deg_to_rad(30), deg_to_rad(65))).get_rotation_quaternion())
		anim_throw.rotation_track_insert_key(t_ra_t, 0.30, rest_ra.basis.get_rotation_quaternion() * Basis.from_euler(Vector3(deg_to_rad(110), deg_to_rad(-10), deg_to_rad(15))).get_rotation_quaternion())
		anim_throw.rotation_track_insert_key(t_ra_t, 0.55, q_r_idle)

	# Right Forearm: flex at draw, snap straight at release
	if b_r_fa >= 0:
		var t_rfa_t := anim_throw.add_track(Animation.TYPE_ROTATION_3D)
		anim_throw.track_set_path(t_rfa_t, "RootNode/Skeleton3D:mixamorig_RightForeArm")
		anim_throw.rotation_track_insert_key(t_rfa_t, 0.0, q_r_fa_idle)
		anim_throw.rotation_track_insert_key(t_rfa_t, 0.16, rest_r_fa.basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, deg_to_rad(75)))
		anim_throw.rotation_track_insert_key(t_rfa_t, 0.30, rest_r_fa.basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, deg_to_rad(5)))
		anim_throw.rotation_track_insert_key(t_rfa_t, 0.55, q_r_fa_idle)

	# Left Arm: Counter-balance aiming forward
	if b_l_arm >= 0:
		var t_la_t := anim_throw.add_track(Animation.TYPE_ROTATION_3D)
		anim_throw.track_set_path(t_la_t, "RootNode/Skeleton3D:mixamorig_LeftArm")
		anim_throw.rotation_track_insert_key(t_la_t, 0.0, q_l_idle)
		anim_throw.rotation_track_insert_key(t_la_t, 0.16, rest_la.basis.get_rotation_quaternion() * Basis.from_euler(Vector3(deg_to_rad(35), deg_to_rad(-20), deg_to_rad(-25))).get_rotation_quaternion())
		anim_throw.rotation_track_insert_key(t_la_t, 0.30, rest_la.basis.get_rotation_quaternion() * Basis.from_euler(Vector3(deg_to_rad(70), deg_to_rad(15), deg_to_rad(-35))).get_rotation_quaternion())
		anim_throw.rotation_track_insert_key(t_la_t, 0.55, q_l_idle)

	lib.add_animation("spear_throw", anim_throw)

	_setup_extended_animations(lib, skel)

func _ensure_sockets() -> void:
	# Right hand socket — primary held-item mount (pickaxe/club/spear/torch).
	if not is_instance_valid(held_item_socket_r):
		held_item_socket_r = Marker3D.new()
		held_item_socket_r.name = "HeldItemSocketR"
		if skeleton:
			var ba := BoneAttachment3D.new()
			ba.bone_name = "mixamorig_RightHand"
			skeleton.add_child(ba)
			ba.add_child(held_item_socket_r)
			held_item_socket_r.position = Vector3(0.0, -0.12, -0.05)
		else:
			root_pivot.add_child(held_item_socket_r)
			held_item_socket_r.position = Vector3(0.55, 0.30, -0.10)
	# Left hand socket — carried objects / glow rock / two-handed helpers.
	if not is_instance_valid(held_item_socket_l):
		held_item_socket_l = Marker3D.new()
		held_item_socket_l.name = "HeldItemSocketL"
		if skeleton:
			var ba_l := BoneAttachment3D.new()
			ba_l.bone_name = "mixamorig_LeftHand"
			skeleton.add_child(ba_l)
			ba_l.add_child(held_item_socket_l)
			held_item_socket_l.position = Vector3(0.0, -0.12, -0.05)
		else:
			root_pivot.add_child(held_item_socket_l)
			held_item_socket_l.position = Vector3(-0.55, 0.30, -0.10)
	# Head socket — hats, headlamps, status markers.
	if not is_instance_valid(head_socket):
		head_socket = Marker3D.new()
		head_socket.name = "HeadSocket"
		if skeleton:
			var ba_h := BoneAttachment3D.new()
			ba_h.bone_name = "mixamorig_Head"
			skeleton.add_child(ba_h)
			ba_h.add_child(head_socket)
			head_socket.position = Vector3(0.0, 0.25, 0.0)
		else:
			head_pivot.add_child(head_socket)

func get_held_item_socket(right_hand: bool = true) -> Marker3D:
	return held_item_socket_r if right_hand else held_item_socket_l

## AnimationTree-compatible state list (spec section 13).
func get_animation_states() -> Array[String]:
	return CavemanRig.ANIMATION_STATES.duplicate()

func has_state(state_name: String) -> bool:
	return anim_player and anim_player.has_animation(state_name)

## Play a named character state with a blend time. Safe no-op if missing.
## This is the single entry point an AnimationTree state machine (or test
## scene) should use — never poke anim_player directly from outside.
func play_state(state_name: String, blend: float = 0.2) -> bool:
	if anim_player and anim_player.has_animation(state_name):
		if anim_player.current_animation != state_name:
			anim_player.play(state_name, blend)
		current_state = state_name
		if state_name in ["attack", "spear_throw", "land", "ragdoll_down", "ragdoll_recover"]:
			var anim: Animation = anim_player.get_animation(state_name)
			if anim:
				_action_timer = anim.length
		return true
	return false

## Alias used by AnimationTree travel-style callers.
func travel_to(state_name: String) -> bool:
	return play_state(state_name)

func _setup_extended_animations(lib: AnimationLibrary, skel: Skeleton3D) -> void:
	var b_l_arm := skel.find_bone("mixamorig_LeftArm")
	var b_r_arm := skel.find_bone("mixamorig_RightArm")
	var b_l_fa := skel.find_bone("mixamorig_LeftForeArm")
	var b_r_fa := skel.find_bone("mixamorig_RightForeArm")
	var b_spine1 := skel.find_bone("mixamorig_Spine1")
	var b_head := skel.find_bone("mixamorig_Head")
	var b_hips := skel.find_bone("mixamorig_Hips")
	var b_l_leg := skel.find_bone("mixamorig_LeftUpLeg")
	var b_r_leg := skel.find_bone("mixamorig_RightUpLeg")
	var b_l_knee := skel.find_bone("mixamorig_LeftLeg")
	var b_r_knee := skel.find_bone("mixamorig_RightLeg")

	const TRACK_PREFIX := "RootNode/Skeleton3D:"
	var q := func(bone: int) -> Quaternion:
		if bone < 0:
			return Quaternion.IDENTITY
		return skel.get_bone_rest(bone).basis.get_rotation_quaternion()
	var hips_pos := skel.get_bone_rest(b_hips).origin if b_hips >= 0 else Vector3.ZERO

	# -- RUN (exaggerated goofy sprint: big lean, pumping arms, high knees) --
	var anim_run := Animation.new()
	anim_run.length = 0.6
	anim_run.loop_mode = Animation.LOOP_LINEAR
	if b_hips >= 0:
		var t := anim_run.add_track(Animation.TYPE_POSITION_3D)
		anim_run.track_set_path(t, TRACK_PREFIX + "mixamorig_Hips")
		anim_run.position_track_insert_key(t, 0.0, hips_pos)
		anim_run.position_track_insert_key(t, 0.15, hips_pos + Vector3(0, -0.10, 0))
		anim_run.position_track_insert_key(t, 0.30, hips_pos)
		anim_run.position_track_insert_key(t, 0.45, hips_pos + Vector3(0, -0.10, 0))
		anim_run.position_track_insert_key(t, 0.6, hips_pos)
	if b_spine1 >= 0:
		var t := anim_run.add_track(Animation.TYPE_ROTATION_3D)
		anim_run.track_set_path(t, TRACK_PREFIX + "mixamorig_Spine1")
		var lean: Quaternion = q.call(b_spine1) * Quaternion(Vector3.RIGHT, deg_to_rad(14))
		anim_run.rotation_track_insert_key(t, 0.0, lean)
		anim_run.rotation_track_insert_key(t, 0.3, lean * Quaternion(Vector3.UP, 0.10))
		anim_run.rotation_track_insert_key(t, 0.6, lean)
	if b_l_leg >= 0 and b_r_leg >= 0:
		for side in [0, 1]:
			var b := b_l_leg if side == 0 else b_r_leg
			var nm := "mixamorig_LeftUpLeg" if side == 0 else "mixamorig_RightUpLeg"
			var t := anim_run.add_track(Animation.TYPE_ROTATION_3D)
			anim_run.track_set_path(t, TRACK_PREFIX + nm)
			anim_run.rotation_track_insert_key(t, 0.0, q.call(b))
			anim_run.rotation_track_insert_key(t, 0.15, q.call(b) * Quaternion(Vector3.RIGHT, 0.85 if side == 0 else -0.65))
			anim_run.rotation_track_insert_key(t, 0.30, q.call(b))
			anim_run.rotation_track_insert_key(t, 0.45, q.call(b) * Quaternion(Vector3.RIGHT, -0.65 if side == 0 else 0.85))
			anim_run.rotation_track_insert_key(t, 0.6, q.call(b))
	if b_l_knee >= 0 and b_r_knee >= 0:
		for side in [0, 1]:
			var b := b_l_knee if side == 0 else b_r_knee
			var nm := "mixamorig_LeftLeg" if side == 0 else "mixamorig_RightLeg"
			var t := anim_run.add_track(Animation.TYPE_ROTATION_3D)
			anim_run.track_set_path(t, TRACK_PREFIX + nm)
			anim_run.rotation_track_insert_key(t, 0.0, q.call(b))
			anim_run.rotation_track_insert_key(t, 0.30, q.call(b) * Quaternion(Vector3.RIGHT, 0.9))
			anim_run.rotation_track_insert_key(t, 0.6, q.call(b))
	if b_l_arm >= 0 and b_r_arm >= 0:
		var t_la := anim_run.add_track(Animation.TYPE_ROTATION_3D)
		anim_run.track_set_path(t_la, TRACK_PREFIX + "mixamorig_LeftArm")
		anim_run.rotation_track_insert_key(t_la, 0.0, q.call(b_l_arm) * Quaternion(Vector3.FORWARD, deg_to_rad(-45)))
		anim_run.rotation_track_insert_key(t_la, 0.3, q.call(b_l_arm) * Quaternion(Vector3.FORWARD, deg_to_rad(45)))
		anim_run.rotation_track_insert_key(t_la, 0.6, q.call(b_l_arm) * Quaternion(Vector3.FORWARD, deg_to_rad(-45)))
		var t_ra := anim_run.add_track(Animation.TYPE_ROTATION_3D)
		anim_run.track_set_path(t_ra, TRACK_PREFIX + "mixamorig_RightArm")
		anim_run.rotation_track_insert_key(t_ra, 0.0, q.call(b_r_arm) * Quaternion(Vector3.FORWARD, deg_to_rad(45)))
		anim_run.rotation_track_insert_key(t_ra, 0.3, q.call(b_r_arm) * Quaternion(Vector3.FORWARD, deg_to_rad(-45)))
		anim_run.rotation_track_insert_key(t_ra, 0.6, q.call(b_r_arm) * Quaternion(Vector3.FORWARD, deg_to_rad(45)))
	lib.add_animation("run", anim_run)

	# -- JUMP (crouch anticipation -> explosive stretch, arms flung up) --
	var anim_jump := Animation.new()
	anim_jump.length = 0.45
	anim_jump.loop_mode = Animation.LOOP_NONE
	if b_hips >= 0:
		var t := anim_jump.add_track(Animation.TYPE_POSITION_3D)
		anim_jump.track_set_path(t, TRACK_PREFIX + "mixamorig_Hips")
		anim_jump.position_track_insert_key(t, 0.0, hips_pos + Vector3(0, -0.12, 0))
		anim_jump.position_track_insert_key(t, 0.2, hips_pos + Vector3(0, 0.10, 0))
		anim_jump.position_track_insert_key(t, 0.45, hips_pos + Vector3(0, 0.16, 0))
	if b_l_arm >= 0 and b_r_arm >= 0:
		var arms: Array = [[b_l_arm, "mixamorig_LeftArm", -1.0], [b_r_arm, "mixamorig_RightArm", 1.0]]
		for data in arms:
			var t := anim_jump.add_track(Animation.TYPE_ROTATION_3D)
			anim_jump.track_set_path(t, TRACK_PREFIX + str(data[1]))
			anim_jump.rotation_track_insert_key(t, 0.0, q.call(data[0]))
			anim_jump.rotation_track_insert_key(t, 0.45, q.call(data[0]) * Quaternion(Vector3.FORWARD, float(data[2]) * 2.4))
	if b_l_knee >= 0 and b_r_knee >= 0:
		var knees: Array = [[b_l_knee, "mixamorig_LeftLeg"], [b_r_knee, "mixamorig_RightLeg"]]
		for data in knees:
			var t := anim_jump.add_track(Animation.TYPE_ROTATION_3D)
			anim_jump.track_set_path(t, TRACK_PREFIX + str(data[1]))
			anim_jump.rotation_track_insert_key(t, 0.0, q.call(data[0]) * Quaternion(Vector3.RIGHT, 0.7))
			anim_jump.rotation_track_insert_key(t, 0.25, q.call(data[0]))
			anim_jump.rotation_track_insert_key(t, 0.45, q.call(data[0]) * Quaternion(Vector3.RIGHT, 0.25))
	lib.add_animation("jump", anim_jump)

	# -- FALL (flailing loop: arms windmill, legs dangle-kick) --
	var anim_fall := Animation.new()
	anim_fall.length = 0.8
	anim_fall.loop_mode = Animation.LOOP_LINEAR
	if b_l_arm >= 0 and b_r_arm >= 0:
		var fall_arms: Array = [[b_l_arm, "mixamorig_LeftArm"], [b_r_arm, "mixamorig_RightArm"]]
		for data in fall_arms:
			var t := anim_fall.add_track(Animation.TYPE_ROTATION_3D)
			anim_fall.track_set_path(t, TRACK_PREFIX + str(data[1]))
			anim_fall.rotation_track_insert_key(t, 0.0, q.call(data[0]) * Quaternion(Vector3.FORWARD, 1.4))
			anim_fall.rotation_track_insert_key(t, 0.4, q.call(data[0]) * Quaternion(Vector3.FORWARD, -1.4))
			anim_fall.rotation_track_insert_key(t, 0.8, q.call(data[0]) * Quaternion(Vector3.FORWARD, 1.4))
	if b_l_leg >= 0 and b_r_leg >= 0:
		var fall_legs: Array = [[b_l_leg, "mixamorig_LeftUpLeg"], [b_r_leg, "mixamorig_RightUpLeg"]]
		for data in fall_legs:
			var t := anim_fall.add_track(Animation.TYPE_ROTATION_3D)
			anim_fall.track_set_path(t, TRACK_PREFIX + str(data[1]))
			anim_fall.rotation_track_insert_key(t, 0.0, q.call(data[0]) * Quaternion(Vector3.RIGHT, 0.3))
			anim_fall.rotation_track_insert_key(t, 0.4, q.call(data[0]) * Quaternion(Vector3.RIGHT, -0.2))
			anim_fall.rotation_track_insert_key(t, 0.8, q.call(data[0]) * Quaternion(Vector3.RIGHT, 0.3))
	lib.add_animation("fall", anim_fall)

	# -- LAND (goofy squash: deep knee bend, torso crunch) --
	var anim_land := Animation.new()
	anim_land.length = 0.35
	anim_land.loop_mode = Animation.LOOP_NONE
	if b_hips >= 0:
		var t := anim_land.add_track(Animation.TYPE_POSITION_3D)
		anim_land.track_set_path(t, TRACK_PREFIX + "mixamorig_Hips")
		anim_land.position_track_insert_key(t, 0.0, hips_pos)
		anim_land.position_track_insert_key(t, 0.12, hips_pos + Vector3(0, -0.18, 0))
		anim_land.position_track_insert_key(t, 0.35, hips_pos)
	if b_spine1 >= 0:
		var t := anim_land.add_track(Animation.TYPE_ROTATION_3D)
		anim_land.track_set_path(t, TRACK_PREFIX + "mixamorig_Spine1")
		anim_land.rotation_track_insert_key(t, 0.0, q.call(b_spine1))
		anim_land.rotation_track_insert_key(t, 0.12, q.call(b_spine1) * Quaternion(Vector3.RIGHT, 0.35))
		anim_land.rotation_track_insert_key(t, 0.35, q.call(b_spine1))
	if b_l_knee >= 0 and b_r_knee >= 0:
		var land_knees: Array = [[b_l_knee, "mixamorig_LeftLeg"], [b_r_knee, "mixamorig_RightLeg"]]
		for data in land_knees:
			var t := anim_land.add_track(Animation.TYPE_ROTATION_3D)
			anim_land.track_set_path(t, TRACK_PREFIX + str(data[1]))
			anim_land.rotation_track_insert_key(t, 0.0, q.call(data[0]))
			anim_land.rotation_track_insert_key(t, 0.12, q.call(data[0]) * Quaternion(Vector3.RIGHT, 0.8))
			anim_land.rotation_track_insert_key(t, 0.35, q.call(data[0]))
	lib.add_animation("land", anim_land)

	# -- ATTACK (basic club smash: big wind-up, overhead slam) --
	var anim_attack := Animation.new()
	anim_attack.length = 0.5
	anim_attack.loop_mode = Animation.LOOP_NONE
	if b_spine1 >= 0:
		var t := anim_attack.add_track(Animation.TYPE_ROTATION_3D)
		anim_attack.track_set_path(t, TRACK_PREFIX + "mixamorig_Spine1")
		anim_attack.rotation_track_insert_key(t, 0.0, q.call(b_spine1))
		anim_attack.rotation_track_insert_key(t, 0.18, q.call(b_spine1) * Quaternion(Vector3.RIGHT, -0.30))
		anim_attack.rotation_track_insert_key(t, 0.30, q.call(b_spine1) * Quaternion(Vector3.RIGHT, 0.45))
		anim_attack.rotation_track_insert_key(t, 0.5, q.call(b_spine1))
	if b_r_arm >= 0:
		var t := anim_attack.add_track(Animation.TYPE_ROTATION_3D)
		anim_attack.track_set_path(t, TRACK_PREFIX + "mixamorig_RightArm")
		anim_attack.rotation_track_insert_key(t, 0.0, q.call(b_r_arm))
		anim_attack.rotation_track_insert_key(t, 0.18, q.call(b_r_arm) * Quaternion(Vector3.FORWARD, 2.2))
		anim_attack.rotation_track_insert_key(t, 0.30, q.call(b_r_arm) * Quaternion(Vector3.FORWARD, -0.6))
		anim_attack.rotation_track_insert_key(t, 0.5, q.call(b_r_arm))
	if b_r_fa >= 0:
		var t := anim_attack.add_track(Animation.TYPE_ROTATION_3D)
		anim_attack.track_set_path(t, TRACK_PREFIX + "mixamorig_RightForeArm")
		anim_attack.rotation_track_insert_key(t, 0.0, q.call(b_r_fa))
		anim_attack.rotation_track_insert_key(t, 0.18, q.call(b_r_fa) * Quaternion(Vector3.RIGHT, 1.0))
		anim_attack.rotation_track_insert_key(t, 0.30, q.call(b_r_fa))
		anim_attack.rotation_track_insert_key(t, 0.5, q.call(b_r_fa))
	lib.add_animation("attack", anim_attack)

	# -- RAGDOLL_DOWN (0.3s blend-out pose: go limp, arms out, chin up) --
	var anim_down := Animation.new()
	anim_down.length = 0.3
	anim_down.loop_mode = Animation.LOOP_NONE
	if b_l_arm >= 0 and b_r_arm >= 0:
		var down_arms: Array = [[b_l_arm, "mixamorig_LeftArm", 1.2], [b_r_arm, "mixamorig_RightArm", -1.2]]
		for data in down_arms:
			var t := anim_down.add_track(Animation.TYPE_ROTATION_3D)
			anim_down.track_set_path(t, TRACK_PREFIX + str(data[1]))
			anim_down.rotation_track_insert_key(t, 0.0, q.call(data[0]))
			anim_down.rotation_track_insert_key(t, 0.3, q.call(data[0]) * Quaternion(Vector3.FORWARD, float(data[2])))
	if b_head >= 0:
		var t := anim_down.add_track(Animation.TYPE_ROTATION_3D)
		anim_down.track_set_path(t, TRACK_PREFIX + "mixamorig_Head")
		anim_down.rotation_track_insert_key(t, 0.0, q.call(b_head))
		anim_down.rotation_track_insert_key(t, 0.3, q.call(b_head) * Quaternion(Vector3.RIGHT, -0.35))
	lib.add_animation("ragdoll_down", anim_down)

	# -- RAGDOLL_RECOVER (0.6s get-up: push torso up, shake head) --
	var anim_up := Animation.new()
	anim_up.length = 0.6
	anim_up.loop_mode = Animation.LOOP_NONE
	if b_hips >= 0:
		var t := anim_up.add_track(Animation.TYPE_POSITION_3D)
		anim_up.track_set_path(t, TRACK_PREFIX + "mixamorig_Hips")
		anim_up.position_track_insert_key(t, 0.0, hips_pos + Vector3(0, -0.25, 0))
		anim_up.position_track_insert_key(t, 0.6, hips_pos)
	if b_head >= 0:
		var t := anim_up.add_track(Animation.TYPE_ROTATION_3D)
		anim_up.track_set_path(t, TRACK_PREFIX + "mixamorig_Head")
		anim_up.rotation_track_insert_key(t, 0.0, q.call(b_head) * Quaternion(Vector3.UP, 0.5))
		anim_up.rotation_track_insert_key(t, 0.3, q.call(b_head) * Quaternion(Vector3.UP, -0.5))
		anim_up.rotation_track_insert_key(t, 0.6, q.call(b_head))
	if b_spine1 >= 0:
		var t := anim_up.add_track(Animation.TYPE_ROTATION_3D)
		anim_up.track_set_path(t, TRACK_PREFIX + "mixamorig_Spine1")
		anim_up.rotation_track_insert_key(t, 0.0, q.call(b_spine1) * Quaternion(Vector3.RIGHT, 0.5))
		anim_up.rotation_track_insert_key(t, 0.6, q.call(b_spine1))
	lib.add_animation("ragdoll_recover", anim_up)

func _build_modular_caveman() -> void:
	var mesh_torso := load("res://assets/models/character/part_torso.obj") as Mesh
	var mesh_head  := load("res://assets/models/character/part_head.obj") as Mesh
	var mesh_arm_l := load("res://assets/models/character/part_arm_l.obj") as Mesh
	var mesh_arm_r := load("res://assets/models/character/part_arm_r.obj") as Mesh
	var mesh_leg_l := load("res://assets/models/character/part_leg_l.obj") as Mesh
	var mesh_leg_r := load("res://assets/models/character/part_leg_r.obj") as Mesh

	# 1. TORSO
	torso = MeshInstance3D.new()
	torso.name = "Torso"
	torso.mesh = mesh_torso
	torso.position = Vector3(0.0, 0.70, 0.0)
	_apply_materials_to_instance(torso)
	root_pivot.add_child(torso)

	# 2. HEAD
	head_pivot = Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0.0, 1.02, 0.0)
	root_pivot.add_child(head_pivot)

	head = MeshInstance3D.new()
	head.name = "HeadMesh"
	head.mesh = mesh_head
	_apply_materials_to_instance(head)
	head_pivot.add_child(head)

	# 3. LEFT ARM
	arm_left_pivot = Node3D.new()
	arm_left_pivot.name = "ArmLeftPivot"
	arm_left_pivot.position = Vector3(-0.44, 0.98, 0.0)
	root_pivot.add_child(arm_left_pivot)

	arm_left_upper = MeshInstance3D.new()
	arm_left_upper.name = "ArmLeftMesh"
	arm_left_upper.mesh = mesh_arm_l
	_apply_materials_to_instance(arm_left_upper)
	arm_left_pivot.add_child(arm_left_upper)

	# 4. RIGHT ARM
	arm_right_pivot = Node3D.new()
	arm_right_pivot.name = "ArmRightPivot"
	arm_right_pivot.position = Vector3(0.44, 0.98, 0.0)
	root_pivot.add_child(arm_right_pivot)

	arm_right_upper = MeshInstance3D.new()
	arm_right_upper.name = "ArmRightMesh"
	arm_right_upper.mesh = mesh_arm_r
	_apply_materials_to_instance(arm_right_upper)
	arm_right_pivot.add_child(arm_right_upper)

	# 5. LEFT LEG
	leg_left_pivot = Node3D.new()
	leg_left_pivot.name = "LegLeftPivot"
	leg_left_pivot.position = Vector3(-0.20, 0.38, 0.0)
	root_pivot.add_child(leg_left_pivot)

	leg_left_upper = MeshInstance3D.new()
	leg_left_upper.name = "LegLeftMesh"
	leg_left_upper.mesh = mesh_leg_l
	_apply_materials_to_instance(leg_left_upper)
	leg_left_pivot.add_child(leg_left_upper)

	# 6. RIGHT LEG
	leg_right_pivot = Node3D.new()
	leg_right_pivot.name = "LegRightPivot"
	leg_right_pivot.position = Vector3(0.20, 0.38, 0.0)
	root_pivot.add_child(leg_right_pivot)

	leg_right_upper = MeshInstance3D.new()
	leg_right_upper.name = "LegRightMesh"
	leg_right_upper.mesh = mesh_leg_r
	_apply_materials_to_instance(leg_right_upper)
	leg_right_pivot.add_child(leg_right_upper)
	_build_stage_visuals()
	_ensure_sockets()

## Stage assets are intentionally big, readable primitive forms. They sit on
## top of the shared body rather than swapping PlayerData or gameplay nodes.
func _build_stage_visuals() -> void:
	stage_visuals = Node3D.new()
	stage_visuals.name = "StageVisuals"
	root_pivot.add_child(stage_visuals)
	_refresh_stage_visuals()

func _refresh_stage_visuals() -> void:
	if not stage_visuals:
		return
	for child in stage_visuals.get_children():
		child.queue_free()
	var definition := EvolutionStageDefinition.make(evolution_stage)
	if torso:
		torso.rotation.x = definition.posture_pitch
	if head_pivot:
		head_pivot.scale = Vector3.ONE * definition.head_scale
	if arm_left_pivot:
		arm_left_pivot.scale = Vector3(1.0, definition.limb_scale, 1.0)
	if arm_right_pivot:
		arm_right_pivot.scale = Vector3(1.0, definition.limb_scale, 1.0)
	if leg_left_pivot:
		leg_left_pivot.scale = Vector3(1.0, definition.limb_scale, 1.0)
	if leg_right_pivot:
		leg_right_pivot.scale = Vector3(1.0, definition.limb_scale, 1.0)

	# Later stages gain only large silhouette pieces: no tiny pouches or noise.
	if evolution_stage >= 2:
		_add_stage_box("HunterMantle", Vector3(0.55, 0.12, 0.12), Vector3(0, 1.0, -0.20), mat_clothing)
	if evolution_stage >= 3:
		_add_stage_box("TribalSash", Vector3(0.12, 0.54, 0.08), Vector3(-0.24, 0.78, 0.24), mat_accent)
	if evolution_stage >= 4:
		_add_stage_box("CraftedBelt", Vector3(0.58, 0.10, 0.46), Vector3(0, 0.62, 0), mat_accent)
	if evolution_stage >= 5:
		_add_stage_box("RefinedCollar", Vector3(0.46, 0.10, 0.38), Vector3(0, 1.12, 0), mat_clothing)

func _add_stage_box(node_name: String, size: Vector3, pos: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	stage_visuals.add_child(instance)

func set_evolution_stage(value: int) -> void:
	evolution_stage = clampi(value, 1, 5)
	if is_inside_tree() and not use_rigged_character:
		_refresh_stage_visuals()

## Expression remains deliberately sparse: brows are the only extra facial
## geometry, keeping personality in broad read-at-a-distance shapes.
func set_expression(value: String) -> void:
	expression = value.to_lower()
	if not head_pivot:
		return
	var brow := head_pivot.get_node_or_null("ExpressionBrows") as Node3D
	if brow:
		brow.queue_free()
	brow = Node3D.new()
	brow.name = "ExpressionBrows"
	head_pivot.add_child(brow)
	if expression == "neutral":
		return
	var tilt := 0.0
	if expression == "angry": tilt = 0.35
	elif expression == "scared" or expression == "surprised": tilt = -0.22
	elif expression == "happy": tilt = -0.12
	for side in [-1.0, 1.0]:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.14, 0.035, 0.025)
		var eyebrow := MeshInstance3D.new()
		eyebrow.mesh = mesh
		eyebrow.material_override = mat_hair
		eyebrow.position = Vector3(side * 0.14, 0.89, 0.285)
		eyebrow.rotation.z = tilt * side
		brow.add_child(eyebrow)

func _build_unified_mesh() -> void:
	torso = MeshInstance3D.new()
	torso.name = "UnifiedModel"
	torso.mesh = load("res://assets/models/character/caveman.obj") as Mesh
	_apply_materials_to_instance(torso)
	root_pivot.add_child(torso)
	head = torso
	_ensure_sockets()

func _apply_materials_to_instance(mesh_inst: MeshInstance3D) -> void:
	if not mesh_inst or not mesh_inst.mesh:
		return
	var m := mesh_inst.mesh
	for i in m.get_surface_count():
		var s_name: String = m.surface_get_name(i).to_lower()
		var mat: Material = m.surface_get_material(i)
		var m_name: String = mat.resource_name.to_lower() if mat else ""
		var target_name: String = m_name if not m_name.is_empty() else s_name

		if "skin" in target_name:
			mesh_inst.set_surface_override_material(i, mat_skin)
		elif "clothing" in target_name:
			mesh_inst.set_surface_override_material(i, mat_clothing)
		elif "hair" in target_name:
			mesh_inst.set_surface_override_material(i, mat_hair)
		elif "accent" in target_name:
			mesh_inst.set_surface_override_material(i, mat_accent)
		elif "eyes_white" in target_name:
			mesh_inst.set_surface_override_material(i, mat_eyes_white)
		elif "eyes_pupil" in target_name:
			mesh_inst.set_surface_override_material(i, mat_eyes_pupil)

# ---------------------------------------------------------------------------
# Customization Application
# ---------------------------------------------------------------------------
func apply_customization(data: CharacterCustomizationData) -> void:
	if not data:
		return
	if mat_skin:
		mat_skin.albedo_color = data.skin_color
	if mat_hair:
		mat_hair.albedo_color = data.hair_color
	if mat_clothing:
		mat_clothing.albedo_color = data.clothing_color
	if mat_accent:
		mat_accent.albedo_color = data.accent_color

	if mat_rigged:
		mat_rigged.set_shader_parameter("skin_color", data.skin_color)
		mat_rigged.set_shader_parameter("clothing_color", data.clothing_color)
		mat_rigged.set_shader_parameter("pants_color", data.accent_color)
		mat_rigged.set_shader_parameter("boots_color", Color(0.16, 0.12, 0.08))

func set_first_person_visibility(is_first_person: bool) -> void:
	var shadow_mode := GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if is_first_person else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if char_mesh:
		char_mesh.cast_shadow = shadow_mode
	for visible_part in [torso, head, arm_left_upper, arm_right_upper, leg_left_upper, leg_right_upper]:
		if visible_part:
			visible_part.cast_shadow = shadow_mode
	if stage_visuals:
		for accessory in stage_visuals.get_children():
			if accessory is MeshInstance3D:
				(accessory as MeshInstance3D).cast_shadow = shadow_mode

# ---------------------------------------------------------------------------
# Animation Process
# ---------------------------------------------------------------------------
func play_action(action_name: String) -> void:
	if anim_player and anim_player.has_animation(action_name):
		anim_player.play(action_name, 0.08)
		current_state = action_name
		var anim: Animation = anim_player.get_animation(action_name)
		if anim:
			_action_timer = anim.length

func _process(delta: float) -> void:
	if use_rigged_character:
		if anim_player:
			if _action_timer > 0.0:
				_action_timer -= delta
				return
			if is_moving:
				var want := "run" if walk_speed_factor >= 12.0 and anim_player.has_animation("run") else "walk"
				if anim_player.current_animation != want:
					anim_player.play(want, 0.2)
					current_state = want
				anim_player.speed_scale = clampf(walk_speed_factor * 0.12, 0.6, 2.5)
			else:
				if anim_player.current_animation != "idle":
					anim_player.play("idle", 0.25)
					current_state = "idle"
				anim_player.speed_scale = 1.0
		return

	if not enable_idle_bob or not root_pivot:
		return

	_anim_time += delta

	if is_moving:
		var walk_cycle: float = _anim_time * walk_speed_factor

		# Torso bob and waddle roll
		if torso:
			torso.position.y = 0.70 + abs(sin(walk_cycle)) * 0.08
			torso.rotation.z = sin(walk_cycle) * 0.10
			torso.rotation.y = sin(walk_cycle) * 0.08

		# Head counter-wobble
		if head_pivot:
			head_pivot.position.y = 1.02 + abs(sin(walk_cycle)) * 0.08
			head_pivot.rotation.z = -sin(walk_cycle) * 0.14
			head_pivot.rotation.x = sin(walk_cycle * 2.0) * 0.06

		# Arm swing
		if arm_left_pivot:
			arm_left_pivot.rotation.x = sin(walk_cycle) * 0.75
			arm_left_pivot.rotation.z = 0.15 + sin(walk_cycle) * 0.10
		if arm_right_pivot:
			arm_right_pivot.rotation.x = -sin(walk_cycle) * 0.75
			arm_right_pivot.rotation.z = -0.15 - sin(walk_cycle) * 0.10

		# Leg swing
		if leg_left_pivot:
			leg_left_pivot.rotation.x = -sin(walk_cycle) * 0.70
		if leg_right_pivot:
			leg_right_pivot.rotation.x = sin(walk_cycle) * 0.70
	else:
		# Idle breathing
		var breath: float = sin(_anim_time * 2.2)
		if torso:
			torso.position.y = 0.70 + breath * 0.015
			torso.rotation.z = lerp_angle(torso.rotation.z, 0.0, delta * 8.0)
			torso.rotation.y = lerp_angle(torso.rotation.y, 0.0, delta * 8.0)

		# Head idle look
		if head_pivot:
			head_pivot.position.y = 1.02 + breath * 0.015
			head_pivot.rotation.y = sin(_anim_time * 0.7) * 0.08
			head_pivot.rotation.x = sin(_anim_time * 1.4) * 0.04
			head_pivot.rotation.z = lerp_angle(head_pivot.rotation.z, 0.0, delta * 8.0)

		# Relaxed hanging arms
		if arm_left_pivot:
			arm_left_pivot.rotation.x = lerp_angle(arm_left_pivot.rotation.x, breath * 0.03, delta * 5.0)
			arm_left_pivot.rotation.z = lerp_angle(arm_left_pivot.rotation.z, 0.12, delta * 5.0)
		if arm_right_pivot:
			arm_right_pivot.rotation.x = lerp_angle(arm_right_pivot.rotation.x, -breath * 0.03, delta * 5.0)
			arm_right_pivot.rotation.z = lerp_angle(arm_right_pivot.rotation.z, -0.12, delta * 5.0)

		# Reset legs
		if leg_left_pivot:
			leg_left_pivot.rotation.x = lerp_angle(leg_left_pivot.rotation.x, 0.0, delta * 8.0)
		if leg_right_pivot:
			leg_right_pivot.rotation.x = lerp_angle(leg_right_pivot.rotation.x, 0.0, delta * 8.0)
