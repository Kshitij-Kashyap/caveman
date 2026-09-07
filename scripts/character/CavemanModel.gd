## CavemanModel.gd
## 3D Character model supporting Rafael's Poly Pizza Rigged Character (52 bones,
## vertex skinning, custom walk/idle animations, and shader customization)
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

@export var use_rigged_character: bool = true
@export var use_unified_mesh: bool = false

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
var enable_idle_bob: bool = true

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

func _setup_character_animations(ap: AnimationPlayer, skel: Skeleton3D) -> void:
	var lib: AnimationLibrary
	if ap.has_animation_library(""):
		lib = ap.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		ap.add_animation_library("", lib)

	# 1. IDLE ANIMATION (Looping subtle breathing & gentle micro-sway)
	var anim_idle := Animation.new()
	anim_idle.length = 2.4
	anim_idle.loop_mode = Animation.LOOP_LINEAR

	var b_spine1 := skel.find_bone("mixamorig_Spine1")
	if b_spine1 >= 0:
		var q_spine1 := skel.get_bone_rest(b_spine1).basis.get_rotation_quaternion()
		var t_sp := anim_idle.add_track(Animation.TYPE_ROTATION_3D)
		anim_idle.track_set_path(t_sp, "RootNode/Skeleton3D:mixamorig_Spine1")
		anim_idle.rotation_track_insert_key(t_sp, 0.0, q_spine1)
		anim_idle.rotation_track_insert_key(t_sp, 1.2, q_spine1 * Quaternion(Vector3.RIGHT, 0.035))
		anim_idle.rotation_track_insert_key(t_sp, 2.4, q_spine1)

	var b_head := skel.find_bone("mixamorig_Head")
	if b_head >= 0:
		var q_head := skel.get_bone_rest(b_head).basis.get_rotation_quaternion()
		var t_hd := anim_idle.add_track(Animation.TYPE_ROTATION_3D)
		anim_idle.track_set_path(t_hd, "RootNode/Skeleton3D:mixamorig_Head")
		anim_idle.rotation_track_insert_key(t_hd, 0.0, q_head)
		anim_idle.rotation_track_insert_key(t_hd, 0.8, q_head * Quaternion(Vector3.UP, 0.04))
		anim_idle.rotation_track_insert_key(t_hd, 1.6, q_head * Quaternion(Vector3.UP, -0.04))
		anim_idle.rotation_track_insert_key(t_hd, 2.4, q_head)

	var b_l_arm := skel.find_bone("mixamorig_LeftArm")
	var b_r_arm := skel.find_bone("mixamorig_RightArm")
	if b_l_arm >= 0 and b_r_arm >= 0:
		var q_l_arm := skel.get_bone_rest(b_l_arm).basis.get_rotation_quaternion()
		var q_r_arm := skel.get_bone_rest(b_r_arm).basis.get_rotation_quaternion()

		var t_la := anim_idle.add_track(Animation.TYPE_ROTATION_3D)
		anim_idle.track_set_path(t_la, "RootNode/Skeleton3D:mixamorig_LeftArm")
		anim_idle.rotation_track_insert_key(t_la, 0.0, q_l_arm)
		anim_idle.rotation_track_insert_key(t_la, 1.2, q_l_arm * Quaternion(Vector3.FORWARD, 0.02))
		anim_idle.rotation_track_insert_key(t_la, 2.4, q_l_arm)

		var t_ra := anim_idle.add_track(Animation.TYPE_ROTATION_3D)
		anim_idle.track_set_path(t_ra, "RootNode/Skeleton3D:mixamorig_RightArm")
		anim_idle.rotation_track_insert_key(t_ra, 0.0, q_r_arm)
		anim_idle.rotation_track_insert_key(t_ra, 1.2, q_r_arm * Quaternion(Vector3.FORWARD, -0.02))
		anim_idle.rotation_track_insert_key(t_ra, 2.4, q_r_arm)

	lib.add_animation("idle", anim_idle)

	# 2. WALK ANIMATION (Looping rhythmic humanoid gait with knee flexion & arm swing)
	var anim_walk := Animation.new()
	anim_walk.length = 1.0
	anim_walk.loop_mode = Animation.LOOP_LINEAR

	var b_l_leg := skel.find_bone("mixamorig_LeftUpLeg")
	var b_r_leg := skel.find_bone("mixamorig_RightUpLeg")
	if b_l_leg >= 0 and b_r_leg >= 0:
		var q_l_leg := skel.get_bone_rest(b_l_leg).basis.get_rotation_quaternion()
		var q_r_leg := skel.get_bone_rest(b_r_leg).basis.get_rotation_quaternion()

		var t_ll := anim_walk.add_track(Animation.TYPE_ROTATION_3D)
		anim_walk.track_set_path(t_ll, "RootNode/Skeleton3D:mixamorig_LeftUpLeg")
		anim_walk.rotation_track_insert_key(t_ll, 0.0, q_l_leg)
		anim_walk.rotation_track_insert_key(t_ll, 0.25, q_l_leg * Quaternion(Vector3.RIGHT, 0.45))
		anim_walk.rotation_track_insert_key(t_ll, 0.50, q_l_leg)
		anim_walk.rotation_track_insert_key(t_ll, 0.75, q_l_leg * Quaternion(Vector3.RIGHT, -0.35))
		anim_walk.rotation_track_insert_key(t_ll, 1.0, q_l_leg)

		var t_rl := anim_walk.add_track(Animation.TYPE_ROTATION_3D)
		anim_walk.track_set_path(t_rl, "RootNode/Skeleton3D:mixamorig_RightUpLeg")
		anim_walk.rotation_track_insert_key(t_rl, 0.0, q_r_leg)
		anim_walk.rotation_track_insert_key(t_rl, 0.25, q_r_leg * Quaternion(Vector3.RIGHT, -0.35))
		anim_walk.rotation_track_insert_key(t_rl, 0.50, q_r_leg)
		anim_walk.rotation_track_insert_key(t_rl, 0.75, q_r_leg * Quaternion(Vector3.RIGHT, 0.45))
		anim_walk.rotation_track_insert_key(t_rl, 1.0, q_r_leg)

	var b_l_knee := skel.find_bone("mixamorig_LeftLeg")
	var b_r_knee := skel.find_bone("mixamorig_RightLeg")
	if b_l_knee >= 0 and b_r_knee >= 0:
		var q_l_knee := skel.get_bone_rest(b_l_knee).basis.get_rotation_quaternion()
		var q_r_knee := skel.get_bone_rest(b_r_knee).basis.get_rotation_quaternion()

		var t_lk := anim_walk.add_track(Animation.TYPE_ROTATION_3D)
		anim_walk.track_set_path(t_lk, "RootNode/Skeleton3D:mixamorig_LeftLeg")
		anim_walk.rotation_track_insert_key(t_lk, 0.0, q_l_knee)
		anim_walk.rotation_track_insert_key(t_lk, 0.25, q_l_knee)
		anim_walk.rotation_track_insert_key(t_lk, 0.50, q_l_knee)
		anim_walk.rotation_track_insert_key(t_lk, 0.75, q_l_knee * Quaternion(Vector3.RIGHT, 0.45))
		anim_walk.rotation_track_insert_key(t_lk, 1.0, q_l_knee)

		var t_rk := anim_walk.add_track(Animation.TYPE_ROTATION_3D)
		anim_walk.track_set_path(t_rk, "RootNode/Skeleton3D:mixamorig_RightLeg")
		anim_walk.rotation_track_insert_key(t_rk, 0.0, q_r_knee)
		anim_walk.rotation_track_insert_key(t_rk, 0.25, q_r_knee * Quaternion(Vector3.RIGHT, 0.45))
		anim_walk.rotation_track_insert_key(t_rk, 0.50, q_r_knee)
		anim_walk.rotation_track_insert_key(t_rk, 0.75, q_r_knee)
		anim_walk.rotation_track_insert_key(t_rk, 1.0, q_r_knee)

	if b_l_arm >= 0 and b_r_arm >= 0:
		var q_l_arm := skel.get_bone_rest(b_l_arm).basis.get_rotation_quaternion()
		var q_r_arm := skel.get_bone_rest(b_r_arm).basis.get_rotation_quaternion()

		var t_la_w := anim_walk.add_track(Animation.TYPE_ROTATION_3D)
		anim_walk.track_set_path(t_la_w, "RootNode/Skeleton3D:mixamorig_LeftArm")
		anim_walk.rotation_track_insert_key(t_la_w, 0.0, q_l_arm)
		anim_walk.rotation_track_insert_key(t_la_w, 0.25, q_l_arm * Quaternion(Vector3.RIGHT, -0.35))
		anim_walk.rotation_track_insert_key(t_la_w, 0.50, q_l_arm)
		anim_walk.rotation_track_insert_key(t_la_w, 0.75, q_l_arm * Quaternion(Vector3.RIGHT, 0.35))
		anim_walk.rotation_track_insert_key(t_la_w, 1.0, q_l_arm)

		var t_ra_w := anim_walk.add_track(Animation.TYPE_ROTATION_3D)
		anim_walk.track_set_path(t_ra_w, "RootNode/Skeleton3D:mixamorig_RightArm")
		anim_walk.rotation_track_insert_key(t_ra_w, 0.0, q_r_arm)
		anim_walk.rotation_track_insert_key(t_ra_w, 0.25, q_r_arm * Quaternion(Vector3.RIGHT, 0.35))
		anim_walk.rotation_track_insert_key(t_ra_w, 0.50, q_r_arm)
		anim_walk.rotation_track_insert_key(t_ra_w, 0.75, q_r_arm * Quaternion(Vector3.RIGHT, -0.35))
		anim_walk.rotation_track_insert_key(t_ra_w, 1.0, q_r_arm)

	var b_hips := skel.find_bone("mixamorig_Hips")
	if b_hips >= 0:
		var hips_rest_pos := skel.get_bone_rest(b_hips).origin
		var t_hb := anim_walk.add_track(Animation.TYPE_POSITION_3D)
		anim_walk.track_set_path(t_hb, "RootNode/Skeleton3D:mixamorig_Hips")
		anim_walk.position_track_insert_key(t_hb, 0.0, hips_rest_pos)
		anim_walk.position_track_insert_key(t_hb, 0.25, hips_rest_pos - Vector3(0, 0.08, 0))
		anim_walk.position_track_insert_key(t_hb, 0.50, hips_rest_pos)
		anim_walk.position_track_insert_key(t_hb, 0.75, hips_rest_pos - Vector3(0, 0.08, 0))
		anim_walk.position_track_insert_key(t_hb, 1.0, hips_rest_pos)

	lib.add_animation("walk", anim_walk)

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

func _build_unified_mesh() -> void:
	torso = MeshInstance3D.new()
	torso.name = "UnifiedModel"
	torso.mesh = load("res://assets/models/character/caveman.obj") as Mesh
	_apply_materials_to_instance(torso)
	root_pivot.add_child(torso)
	head = torso

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
	if head:
		head.cast_shadow = shadow_mode

# ---------------------------------------------------------------------------
# Animation Process
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not enable_idle_bob or not root_pivot:
		return

	if use_rigged_character and anim_player:
		if is_moving:
			if anim_player.current_animation != "walk":
				anim_player.play("walk", 0.15)
			anim_player.speed_scale = clampf(walk_speed_factor * 0.12, 0.6, 2.5)
		else:
			if anim_player.current_animation != "idle":
				anim_player.play("idle", 0.25)
			anim_player.speed_scale = 1.0
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
