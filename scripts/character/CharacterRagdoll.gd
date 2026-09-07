## CharacterRagdoll.gd
## Physics-based proxy ragdoll for the low-poly caveman character.
## Uses interconnected RigidBody3D nodes and Generic6DOFJoint3D constraints.
## Allows comical floppy ragdoll knockouts and seamless recovery.

class_name CharacterRagdoll
extends Node3D

signal ragdoll_started
signal ragdoll_ended

# ---------------------------------------------------------------------------
# State & References
# ---------------------------------------------------------------------------
var is_ragdoll_active: bool = false
var target_model: CavemanModel = null

# Bodies
var body_pelvis: RigidBody3D
var body_chest: RigidBody3D
var body_head: RigidBody3D
var body_arm_l: RigidBody3D
var body_arm_r: RigidBody3D
var body_leg_l: RigidBody3D
var body_leg_r: RigidBody3D

var _all_bodies: Array[RigidBody3D] = []
var _all_shapes: Array[CollisionShape3D] = []
var _all_joints: Array[Generic6DOFJoint3D] = []

# Initial local offsets relative to player root (Y=0 at feet)
const POS_PELVIS := Vector3(0.0, 0.85, 0.0)
const POS_CHEST  := Vector3(0.0, 1.25, 0.0)
const POS_HEAD   := Vector3(0.0, 1.70, 0.0)
const POS_ARM_L  := Vector3(-0.48, 1.15, 0.0)
const POS_ARM_R  := Vector3(0.48, 1.15, 0.0)
const POS_LEG_L  := Vector3(-0.24, 0.45, 0.0)
const POS_LEG_R  := Vector3(0.24, 0.45, 0.0)

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
func _ready() -> void:
	_create_ragdoll_hierarchy()
	disable_ragdoll()

func _create_ragdoll_hierarchy() -> void:
	# 1. Pelvis (Core Anchor)
	body_pelvis = _create_body("Pelvis", 18.0, BoxShape3D.new(), Vector3(0.55, 0.35, 0.45), POS_PELVIS)
	
	# 2. Chest
	body_chest = _create_body("Chest", 22.0, BoxShape3D.new(), Vector3(0.70, 0.50, 0.50), POS_CHEST)
	_create_joint("Joint_Pelvis_Chest", body_pelvis, body_chest, POS_PELVIS.lerp(POS_CHEST, 0.5), Vector3(30, 20, 20))

	# 3. Head (Floppy oversized caveman head)
	body_head = _create_body("Head", 10.0, SphereShape3D.new(), Vector3(0.38, 0.38, 0.38), POS_HEAD)
	_create_joint("Joint_Chest_Head", body_chest, body_head, POS_CHEST.lerp(POS_HEAD, 0.5), Vector3(50, 50, 40))

	# 4. Left Arm
	body_arm_l = _create_body("ArmL", 5.0, CapsuleShape3D.new(), Vector3(0.16, 0.60, 0.16), POS_ARM_L)
	_create_joint("Joint_Chest_ArmL", body_chest, body_arm_l, Vector3(-0.38, 1.30, 0.0), Vector3(80, 80, 80))

	# 5. Right Arm
	body_arm_r = _create_body("ArmR", 5.0, CapsuleShape3D.new(), Vector3(0.16, 0.60, 0.16), POS_ARM_R)
	_create_joint("Joint_Chest_ArmR", body_chest, body_arm_r, Vector3(0.38, 1.30, 0.0), Vector3(80, 80, 80))

	# 6. Left Leg
	body_leg_l = _create_body("LegL", 8.0, CapsuleShape3D.new(), Vector3(0.18, 0.70, 0.18), POS_LEG_L)
	_create_joint("Joint_Pelvis_LegL", body_pelvis, body_leg_l, Vector3(-0.24, 0.75, 0.0), Vector3(60, 25, 40))

	# 7. Right Leg
	body_leg_r = _create_body("LegR", 8.0, CapsuleShape3D.new(), Vector3(0.18, 0.70, 0.18), POS_LEG_R)
	_create_joint("Joint_Pelvis_LegR", body_pelvis, body_leg_r, Vector3(0.24, 0.75, 0.0), Vector3(60, 25, 40))

func _create_body(b_name: String, mass_val: float, shape: Shape3D, size_val: Vector3, initial_pos: Vector3) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = b_name
	body.mass = mass_val
	# Collision: Layer 2 (Player), Mask 1 (World)
	body.collision_layer = 2
	body.collision_mask = 1
	body.position = initial_pos
	body.can_sleep = true
	body.freeze = true
	body.continuous_cd = true

	var col := CollisionShape3D.new()
	col.name = "Collision"
	if shape is BoxShape3D:
		shape.size = size_val
	elif shape is SphereShape3D:
		shape.radius = size_val.x
	elif shape is CapsuleShape3D:
		shape.radius = size_val.x
		shape.height = size_val.y
	col.shape = shape
	body.add_child(col)

	add_child(body)
	_all_bodies.append(body)
	_all_shapes.append(col)
	return body

func _create_joint(j_name: String, node_a: RigidBody3D, node_b: RigidBody3D, joint_pos: Vector3, angular_limits_deg: Vector3) -> Generic6DOFJoint3D:
	var joint := Generic6DOFJoint3D.new()
	joint.name = j_name
	joint.position = joint_pos
	joint.node_a = node_a.get_path()
	joint.node_b = node_b.get_path()

	joint.set("angular_limit_x/enabled", true)
	joint.set("angular_limit_x/lower_angle", -deg_to_rad(angular_limits_deg.x))
	joint.set("angular_limit_x/upper_angle", deg_to_rad(angular_limits_deg.x))

	joint.set("angular_limit_y/enabled", true)
	joint.set("angular_limit_y/lower_angle", -deg_to_rad(angular_limits_deg.y))
	joint.set("angular_limit_y/upper_angle", deg_to_rad(angular_limits_deg.y))

	joint.set("angular_limit_z/enabled", true)
	joint.set("angular_limit_z/lower_angle", -deg_to_rad(angular_limits_deg.z))
	joint.set("angular_limit_z/upper_angle", deg_to_rad(angular_limits_deg.z))

	add_child(joint)
	_all_joints.append(joint)
	return joint

# ---------------------------------------------------------------------------
# Activation / Deactivation
# ---------------------------------------------------------------------------
func enable_ragdoll(initial_velocity: Vector3 = Vector3.ZERO, impulse: Vector3 = Vector3.ZERO) -> void:
	if is_ragdoll_active:
		return

	is_ragdoll_active = true
	# Align bodies with current global transform
	var parent_transform: Transform3D = global_transform

	body_pelvis.global_transform.origin = parent_transform * POS_PELVIS
	body_chest.global_transform.origin  = parent_transform * POS_CHEST
	body_head.global_transform.origin   = parent_transform * POS_HEAD
	body_arm_l.global_transform.origin  = parent_transform * POS_ARM_L
	body_arm_r.global_transform.origin  = parent_transform * POS_ARM_R
	body_leg_l.global_transform.origin  = parent_transform * POS_LEG_L
	body_leg_r.global_transform.origin  = parent_transform * POS_LEG_R

	for col in _all_shapes:
		col.set_deferred("disabled", false)

	for body in _all_bodies:
		body.freeze = false
		body.linear_velocity = initial_velocity
		body.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))

	if impulse.length_squared() > 0.01:
		body_chest.apply_central_impulse(impulse * 1.2)
		body_pelvis.apply_central_impulse(impulse * 0.8)
		body_head.apply_central_impulse(impulse * 0.4)

	if target_model:
		target_model.enable_idle_bob = false

	ragdoll_started.emit()

func disable_ragdoll() -> void:
	is_ragdoll_active = false

	for body in _all_bodies:
		body.freeze = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO

	for col in _all_shapes:
		col.set_deferred("disabled", true)

	if target_model:
		target_model.enable_idle_bob = true
		# Reset visual model local transform
		if target_model.torso:
			target_model.torso.position = Vector3(0.0, 0.70, 0.0)
			target_model.torso.rotation = Vector3.ZERO
		if target_model.head:
			target_model.head.position = Vector3.ZERO
			target_model.head.rotation = Vector3.ZERO
		if target_model.arm_left_upper:
			target_model.arm_left_upper.position = Vector3.ZERO
			target_model.arm_left_upper.rotation = Vector3.ZERO
		if target_model.arm_right_upper:
			target_model.arm_right_upper.position = Vector3.ZERO
			target_model.arm_right_upper.rotation = Vector3.ZERO
		if target_model.leg_left_upper:
			target_model.leg_left_upper.position = Vector3.ZERO
			target_model.leg_left_upper.rotation = Vector3.ZERO
		if target_model.leg_right_upper:
			target_model.leg_right_upper.position = Vector3.ZERO
			target_model.leg_right_upper.rotation = Vector3.ZERO

	ragdoll_ended.emit()

func apply_impulse(direction: Vector3, force: float) -> void:
	if not is_ragdoll_active:
		return
	var imp := direction.normalized() * force
	body_chest.apply_central_impulse(imp)
	body_head.apply_central_impulse(imp * 0.5)

func get_recovery_position() -> Vector3:
	if body_pelvis:
		# Return position on the ground where pelvis landed
		return body_pelvis.global_position - Vector3(0, 0.8, 0)
	return global_position

func get_camera_follow_node() -> Node3D:
	return body_head if body_head else (body_chest if body_chest else body_pelvis)

# ---------------------------------------------------------------------------
# Visual Synchronization
# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if not is_ragdoll_active or not target_model:
		return

	# Synchronize target visual model parts with ragdoll bodies
	if target_model.torso and body_chest:
		target_model.torso.global_transform = body_chest.global_transform
	if target_model.head and body_head:
		target_model.head.global_transform = body_head.global_transform
	if target_model.arm_left_upper and body_arm_l:
		target_model.arm_left_upper.global_transform = body_arm_l.global_transform
	if target_model.arm_right_upper and body_arm_r:
		target_model.arm_right_upper.global_transform = body_arm_r.global_transform
	if target_model.leg_left_upper and body_leg_l:
		target_model.leg_left_upper.global_transform = body_leg_l.global_transform
	if target_model.leg_right_upper and body_leg_r:
		target_model.leg_right_upper.global_transform = body_leg_r.global_transform
