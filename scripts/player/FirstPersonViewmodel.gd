## FirstPersonViewmodel.gd
## High-polish first-person viewmodel for Cave Raiders.
## Features:
## - Chunky low-poly prehistoric pickaxe + caveman forearm & fist
## - Dynamic weapon sway based on mouse motion
## - Locomotion bobbing (idle breathing, walking figure-8, sprinting stride)
## - Jump/fall and landing dips
## - Responsive kinetic swing animation with mining & combat hit detection
## - Customization-linked skin tones

class_name FirstPersonViewmodel
extends Node3D

signal swing_started()
signal hit_deposit(deposit: Node)
signal hit_creature(creature_health: Node, direction: Vector3)
signal hit_world(position: Vector3, normal: Vector3)

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------
@export var reach: float = 2.4
@export var mining_power: float = 1.0
@export var melee_damage: float = 14.0
@export var swing_rate: float = 1.35 ## Swings per second

@export var sway_amount: float = 0.0018
@export var max_sway: float = 0.05
@export var sway_smoothness: float = 10.0
@export var rotation_sway_amount: float = 0.025

@export var default_pos: Vector3 = Vector3(0.24, -0.22, -0.38)
@export var default_rot: Vector3 = Vector3(0.08, -0.12, 0.04)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var _can_swing: bool = true
var _is_swinging: bool = false
var _sway_offset: Vector3 = Vector3.ZERO
var _rotation_sway: Vector3 = Vector3.ZERO
var _bob_timer: float = 0.0
var _land_dip: float = 0.0

var _rest_transform: Transform3D

# Visual instances
var pickaxe_mesh: MeshInstance3D
var arm_mesh: MeshInstance3D

var mat_skin: StandardMaterial3D
var mat_wood: StandardMaterial3D
var mat_stone: StandardMaterial3D
var mat_leather: StandardMaterial3D

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_init_materials()
	_build_viewmodel()
	transform.origin = default_pos
	rotation = default_rot
	_rest_transform = transform

func _init_materials() -> void:
	mat_skin = StandardMaterial3D.new()
	mat_skin.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_skin.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_skin.albedo_color = Color(0.85, 0.60, 0.44)
	mat_skin.roughness = 0.85

	mat_wood = StandardMaterial3D.new()
	mat_wood.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_wood.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_wood.albedo_color = Color(0.42, 0.28, 0.16)
	mat_wood.roughness = 0.92

	mat_stone = StandardMaterial3D.new()
	mat_stone.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_stone.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_stone.albedo_color = Color(0.24, 0.26, 0.28)
	mat_stone.roughness = 0.78

	mat_leather = StandardMaterial3D.new()
	mat_leather.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_leather.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_leather.albedo_color = Color(0.55, 0.36, 0.22)
	mat_leather.roughness = 0.90

func _build_viewmodel() -> void:
	for c in get_children():
		c.queue_free()

	# 1. Arm & Fist
	arm_mesh = MeshInstance3D.new()
	arm_mesh.name = "ArmMesh"
	var arm_obj := load("res://assets/models/character/viewmodel_arm.obj") as Mesh
	if arm_obj:
		arm_mesh.mesh = arm_obj
		for i in arm_obj.get_surface_count():
			arm_mesh.set_surface_override_material(i, mat_skin)
	add_child(arm_mesh)

	# 2. Prehistoric Pickaxe
	pickaxe_mesh = MeshInstance3D.new()
	pickaxe_mesh.name = "PickaxeMesh"
	var pick_obj := load("res://assets/models/character/tool_pickaxe.obj") as Mesh
	if pick_obj:
		pickaxe_mesh.mesh = pick_obj
		for i in pick_obj.get_surface_count():
			var s_name: String = pick_obj.surface_get_name(i).to_lower()
			if "wood" in s_name:
				pickaxe_mesh.set_surface_override_material(i, mat_wood)
			elif "stone" in s_name:
				pickaxe_mesh.set_surface_override_material(i, mat_stone)
			else:
				pickaxe_mesh.set_surface_override_material(i, mat_leather)
	add_child(pickaxe_mesh)

# ---------------------------------------------------------------------------
# Customization Sync
# ---------------------------------------------------------------------------
func apply_customization(data: CharacterCustomizationData) -> void:
	if not data:
		return
	if mat_skin:
		mat_skin.albedo_color = data.skin_color
	if mat_leather:
		mat_leather.albedo_color = data.clothing_color

# ---------------------------------------------------------------------------
# Sway & Motion Processing
# ---------------------------------------------------------------------------
func add_sway(mouse_relative: Vector2) -> void:
	var target_x: float = clamp(-mouse_relative.x * sway_amount, -max_sway, max_sway)
	var target_y: float = clamp(mouse_relative.y * sway_amount, -max_sway, max_sway)
	_sway_offset.x = clamp(_sway_offset.x + target_x, -max_sway, max_sway)
	_sway_offset.y = clamp(_sway_offset.y + target_y, -max_sway, max_sway)

	_rotation_sway.y = clamp(_rotation_sway.y - mouse_relative.x * rotation_sway_amount * 0.05, -0.15, 0.15)
	_rotation_sway.x = clamp(_rotation_sway.x + mouse_relative.y * rotation_sway_amount * 0.05, -0.15, 0.15)

func trigger_land_dip(impact_velocity: float) -> void:
	_land_dip = clamp(impact_velocity * 0.005, 0.02, 0.06)

func process_viewmodel(delta: float, velocity: Vector3, is_on_floor: bool, is_sprinting: bool) -> void:
	# Recovery from sway
	_sway_offset = _sway_offset.lerp(Vector3.ZERO, sway_smoothness * delta)
	_rotation_sway = _rotation_sway.lerp(Vector3.ZERO, sway_smoothness * delta)
	_land_dip = move_toward(_land_dip, 0.0, delta * 0.2)

	if _is_swinging:
		return

	# Locomotion bobbing
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	var bob_pos := Vector3.ZERO
	var bob_rot := Vector3.ZERO

	if is_on_floor and horiz_speed > 0.2:
		var freq := 14.0 if is_sprinting else 9.0
		var amp_y := 0.016 if is_sprinting else 0.008
		var amp_x := 0.012 if is_sprinting else 0.006
		_bob_timer += delta * freq
		bob_pos.y = sin(_bob_timer) * amp_y
		bob_pos.x = cos(_bob_timer * 0.5) * amp_x
		bob_rot.z = cos(_bob_timer * 0.5) * 0.03
	else:
		# Idle breathing bob
		_bob_timer += delta * 2.0
		bob_pos.y = sin(_bob_timer) * 0.003
		bob_pos.x = cos(_bob_timer * 0.5) * 0.002

	if not is_on_floor:
		bob_pos.y -= 0.025 # In-air drop

	bob_pos.y -= _land_dip

	# Apply target transform smoothly
	var target_pos := default_pos + _sway_offset + bob_pos
	var target_rot := default_rot + _rotation_sway + bob_rot

	transform.origin = transform.origin.lerp(target_pos, delta * 14.0)
	rotation.x = lerp_angle(rotation.x, target_rot.x, delta * 14.0)
	rotation.y = lerp_angle(rotation.y, target_rot.y, delta * 14.0)
	rotation.z = lerp_angle(rotation.z, target_rot.z, delta * 14.0)

# ---------------------------------------------------------------------------
# Kinetic Mining & Combat Swing
# ---------------------------------------------------------------------------
func try_swing() -> bool:
	if not _can_swing or _is_swinging:
		return false
	_start_swing()
	return true

func _start_swing() -> void:
	_can_swing = false
	_is_swinging = true
	swing_started.emit()

	var t := create_tween().set_parallel(false)
	
	# Phase 1: Rapid wind-up (0.07s)
	t.parallel().tween_property(self, "position", default_pos + Vector3(-0.04, 0.06, 0.05), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation", default_rot + Vector3(-0.35, 0.22, -0.15), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Phase 2: High-energy kinetic chop (0.09s)
	t.chain().parallel().tween_property(self, "position", default_pos + Vector3(-0.06, -0.10, -0.14), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "rotation", default_rot + Vector3(0.75, -0.28, 0.25), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	# Hit impact frame
	t.tween_callback(_check_hit)

	# Phase 3: Recoil & recovery (0.18s)
	t.chain().parallel().tween_property(self, "position", default_pos, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation", default_rot, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	t.tween_callback(func():
		_is_swinging = false
	)

	get_tree().create_timer(1.0 / swing_rate).timeout.connect(func():
		_can_swing = true
	)

func _check_hit() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return

	var origin := cam.global_position
	var forward := -cam.global_transform.basis.z
	var end := origin + forward * reach
	var space := get_world_3d().direct_space_state

	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 0b111 # Layers 1 (World), 2 (Player), 3 (Creature)

	var result := space.intersect_ray(query)
	if result.is_empty():
		return

	var collider: Node = result.get("collider")
	var hit_pos: Vector3 = result.get("position", end)
	var hit_norm: Vector3 = result.get("normal", Vector3.UP)

	# Check for MineableDeposit
	var deposit := _find_ancestor_script(collider, "MineableDeposit")
	if deposit and deposit.has_method("on_hit"):
		deposit.on_hit(mining_power)
		hit_deposit.emit(deposit)
		AudioManager.play_sfx(AudioManager.SFX.PICKAXE_HIT_ORE)
		return

	# Check for Creature
	var c_health := _find_ancestor_script(collider, "CreatureHealth")
	if c_health and c_health.has_method("take_damage"):
		var kd := forward
		kd.y = 0.25
		c_health.take_damage.rpc_id(1, melee_damage, kd.normalized(), 6.0)
		hit_creature.emit(c_health, kd)
		AudioManager.play_sfx(AudioManager.SFX.PICKAXE_HIT)
		return

	# World hit (stone walls, cave floors)
	hit_world.emit(hit_pos, hit_norm)
	AudioManager.play_sfx(AudioManager.SFX.PICKAXE_HIT)

func _find_ancestor_script(node: Node, class_name_str: String) -> Node:
	var cur := node
	var limit := 8
	while cur and limit > 0:
		limit -= 1
		if cur.get_script() != null:
			var s: Script = cur.get_script()
			if s.get_global_name() == class_name_str:
				return cur
		cur = cur.get_parent()
	return null
