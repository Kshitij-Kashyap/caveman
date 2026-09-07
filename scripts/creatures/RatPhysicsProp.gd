## RatPhysicsProp.gd
## Physical RigidBody3D Rat model using Jolt Physics.
## Fully interactive: reacts to gravity, bounces, rolls, responds to weapon strikes,
## dynamic shockwaves, and plays context-sensitive animations (idle, run, jump/tumble).

class_name RatPhysicsProp
extends RigidBody3D

@export var squeak_on_impact: bool = true
@export var min_impact_velocity: float = 2.5

@onready var model_pivot: Node3D = $ModelPivot
var anim_player: AnimationPlayer = null
var _last_velocity: Vector3 = Vector3.ZERO
var _time_since_last_squeak: float = 1.0

func _ready() -> void:
	add_to_group("physics_rats")
	add_to_group("props")

	# Jolt physics settings
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	# Find AnimationPlayer inside the instantiated rat.glb
	anim_player = find_child("AnimationPlayer", true, false)
	if anim_player:
		if anim_player.has_animation("RatArmature|Rat_Idle"):
			anim_player.play("RatArmature|Rat_Idle")

func _physics_process(delta: float) -> void:
	_time_since_last_squeak += delta
	var spd := linear_velocity.length()

	# Dynamic animation blending based on physical locomotion state
	if anim_player:
		if abs(linear_velocity.y) > 1.8 and not _is_grounded():
			# Airborne tumble / leap
			if anim_player.current_animation != "RatArmature|Rat_Jump":
				anim_player.play("RatArmature|Rat_Jump", 0.15)
		elif spd > 2.0:
			# Fast scramble / slide
			if anim_player.current_animation != "RatArmature|Rat_Run":
				anim_player.play("RatArmature|Rat_Run", 0.15)
			anim_player.speed_scale = clampf(spd * 0.35, 0.8, 2.0)
		elif spd > 0.3:
			# Scurry / walk
			if anim_player.current_animation != "RatArmature|Rat_Walk":
				anim_player.play("RatArmature|Rat_Walk", 0.2)
			anim_player.speed_scale = clampf(spd * 0.8, 0.7, 1.5)
		else:
			# Resting idle
			if anim_player.current_animation != "RatArmature|Rat_Idle":
				anim_player.play("RatArmature|Rat_Idle", 0.3)
			anim_player.speed_scale = 1.0

	_last_velocity = linear_velocity

func _is_grounded() -> bool:
	# Check if any contact is below the rat center
	for body in get_colliding_bodies():
		if body is Node:
			return true
	return false

func _on_body_entered(_body: Node) -> void:
	var impact_speed := _last_velocity.length()
	if squeak_on_impact and impact_speed >= min_impact_velocity and _time_since_last_squeak > 0.4:
		_time_since_last_squeak = 0.0
		_play_squeak()

func on_hit(power: float = 1.0, direction: Vector3 = Vector3.ZERO) -> void:
	var dir := direction.normalized() if direction.length_squared() > 0.01 else Vector3.UP
	dir.y = max(dir.y, 0.35)
	dir = dir.normalized()

	var launch_force := 14.0 * power
	apply_central_impulse(dir * launch_force + Vector3.UP * (3.5 * power))
	apply_torque_impulse(Vector3(
		randf_range(-14.0, 14.0),
		randf_range(-14.0, 14.0),
		randf_range(-14.0, 14.0)
	) * power)

	_play_squeak()

func _play_squeak() -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(22) # CREATURE_HURT

func on_tool_hit(tool_type: int, hit_dir: Vector3) -> void:
	# Weapon-specific kinetic physics multiplier
	var mult := 1.0
	match tool_type:
		0: mult = 1.2  # Stone Pickaxe
		1: mult = 1.4  # Stone Axe
		2: mult = 1.1  # Flint Spear
		3: mult = 1.8  # Stone Club (Home-run baseball whack!)
		4: mult = 0.9  # Torch jab

	on_hit(mult, hit_dir)

func apply_explosion_impulse(epicenter: Vector3, max_force: float = 25.0, radius: float = 12.0) -> void:
	var diff := global_position - epicenter
	var dist := diff.length()
	if dist > radius:
		return

	var falloff := 1.0 - (dist / radius)
	var dir := diff.normalized() if dist > 0.01 else Vector3.UP
	dir.y = max(dir.y, 0.4)
	dir = dir.normalized()

	apply_central_impulse(dir * (max_force * falloff) + Vector3.UP * (6.0 * falloff))
	apply_torque_impulse(Vector3(
		randf_range(-20.0, 20.0),
		randf_range(-20.0, 20.0),
		randf_range(-20.0, 20.0)
	) * falloff)
