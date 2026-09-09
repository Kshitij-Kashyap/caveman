## FirstPersonController.gd
## Decoupled locomotion controller for responsive, arcade-like prehistoric movement.

class_name FirstPersonController
extends Node

const StaminaComponent = preload("res://scripts/player/components/StaminaComponent.gd")

signal footstep_stepped()
signal jumped()
signal landed(impact_velocity: float)

@export var walk_speed: float = 5.5
@export var sprint_speed: float = 9.5
@export var jump_height: float = 1.3
@export var acceleration: float = 14.0
@export var friction: float = 16.0
@export var step_interval_walk: float = 2.0
@export var step_interval_sprint: float = 2.8

@export var speed_multiplier: float = 1.0
@export var jump_multiplier: float = 1.0
var is_flying: bool = false
var fly_speed: float = 16.0

var is_active: bool = true
var is_sprinting: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _step_distance: float = 0.0
var _was_on_floor: bool = true

func update_locomotion(delta: float, body: CharacterBody3D, stamina_comp: StaminaComponent) -> Dictionary:
	if not is_active:
		return { "is_moving": false, "is_sprinting": false, "speed": 0.0 }

	# Flight / Noclip Mode
	if is_flying:
		var fly_dir := Vector3.ZERO
		var input := Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_forward", "move_back")
		).normalized()
		var horiz_dir := (body.transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
		fly_dir += horiz_dir
		if Input.is_action_pressed("jump"):
			fly_dir.y += 1.0
		if (InputMap.has_action("crouch") and Input.is_action_pressed("crouch")) or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C):
			fly_dir.y -= 1.0
		var current_fly_spd := fly_speed * speed_multiplier
		if Input.is_action_pressed("sprint"):
			current_fly_spd *= 2.2
		body.velocity = fly_dir.normalized() * current_fly_spd if fly_dir.length_squared() > 0.01 else Vector3.ZERO
		body.move_and_slide()
		return { "is_moving": fly_dir.length_squared() > 0.01, "is_sprinting": Input.is_action_pressed("sprint"), "speed": body.velocity.length() }

	# 1. Gravity
	if not body.is_on_floor():
		body.velocity.y -= _gravity * delta

	# 2. Sprinting & Stamina
	var wants_sprint := Input.is_action_pressed("sprint")
	if wants_sprint and stamina_comp and stamina_comp.has_stamina():
		is_sprinting = stamina_comp.drain(delta, 1.0)
	else:
		is_sprinting = false
		if stamina_comp:
			stamina_comp.regen(delta)

	var target_speed := (sprint_speed if is_sprinting else walk_speed) * speed_multiplier

	# 3. WASD Camera-Relative Input
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back")
	).normalized()

	var move_dir := (body.transform.basis * Vector3(input.x, 0.0, input.y)).normalized()

	if move_dir.length_squared() > 0.01:
		body.velocity.x = move_toward(body.velocity.x, move_dir.x * target_speed, acceleration * delta)
		body.velocity.z = move_toward(body.velocity.z, move_dir.z * target_speed, acceleration * delta)
	else:
		body.velocity.x = move_toward(body.velocity.x, 0.0, friction * delta)
		body.velocity.z = move_toward(body.velocity.z, 0.0, friction * delta)

	# 4. Jump
	if Input.is_action_just_pressed("jump") and body.is_on_floor():
		body.velocity.y = sqrt(2.0 * _gravity * jump_height * jump_multiplier)
		jumped.emit()
		AudioManager.play_sfx(AudioManager.SFX.JUMP)

	body.move_and_slide()

	# 5. Landing detection
	var on_floor := body.is_on_floor()
	if not _was_on_floor and on_floor:
		landed.emit(abs(body.velocity.y))
		AudioManager.play_sfx(AudioManager.SFX.LAND)
	_was_on_floor = on_floor

	# 6. Footsteps
	var horiz_speed := Vector2(body.velocity.x, body.velocity.z).length()
	var is_moving := horiz_speed > 0.4 and on_floor
	if is_moving:
		_step_distance += horiz_speed * delta
		var req_dist := step_interval_sprint if is_sprinting else step_interval_walk
		if _step_distance >= req_dist:
			_step_distance = 0.0
			footstep_stepped.emit()
			AudioManager.play_sfx(AudioManager.SFX.FOOTSTEP_DIRT)

	return {
		"is_moving": is_moving,
		"is_sprinting": is_sprinting,
		"speed": horiz_speed
	}
