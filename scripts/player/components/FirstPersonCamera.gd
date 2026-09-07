## FirstPersonCamera.gd
## Decoupled first-person camera controller for Cave Raiders.
## Features:
## - Direct mouse-look with body yaw and pitch clamping
## - Subtle head bobbing scaled with locomotion speed
## - Landing dip and camera trauma/punch
## - Ragdoll Tumble Follow: Camera smoothly follows/tumbles with the physical ragdoll body
## - Smooth recovery transition back to standing eye-level

class_name FirstPersonCamera
extends Node3D

enum State {
	NORMAL,
	RAGDOLL_TUMBLE,
	RECOVERING
}

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------
@export var mouse_sensitivity_h: float = 0.0025
@export var mouse_sensitivity_v: float = 0.0022
@export var min_pitch: float = -1.45 ## ~-83 deg
@export var max_pitch: float = 1.45  ## ~+83 deg
@export var eye_height: float = 1.65
@export var head_bob_enabled: bool = true
@export var head_bob_intensity: float = 0.032

# ---------------------------------------------------------------------------
# Node References
# ---------------------------------------------------------------------------
@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $InteractRaycast

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var current_state: State = State.NORMAL
var camera_pitch: float = 0.0
var _bob_timer: float = 0.0
var _land_offset: float = 0.0

var _target_player: CharacterBody3D = null
var _ragdoll_follow_node: Node3D = null
var _recover_timer: float = 0.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	transform.origin = Vector3(0.0, eye_height, 0.0)
	if get_parent() is CharacterBody3D:
		_target_player = get_parent() as CharacterBody3D

func make_active_for_local_player() -> void:
	if camera:
		camera.current = true
		camera.make_current()

func handle_mouse_input(event: InputEventMouseMotion) -> void:
	if current_state == State.RECOVERING:
		current_state = State.NORMAL
		transform.origin = Vector3(0.0, eye_height, 0.0)
		if camera:
			camera.position = Vector3.ZERO
			camera.rotation = Vector3.ZERO

	if current_state != State.NORMAL:
		return

	if not _target_player and get_parent() is CharacterBody3D:
		_target_player = get_parent() as CharacterBody3D

	# Body yaw rotation
	if _target_player:
		_target_player.rotate_y(-event.relative.x * mouse_sensitivity_h)

	# Camera vertical pitch
	camera_pitch = clamp(camera_pitch - event.relative.y * mouse_sensitivity_v, min_pitch, max_pitch)
	rotation.x = camera_pitch

func add_camera_kick(pitch_kick: float) -> void:
	camera_pitch = clamp(camera_pitch + pitch_kick, min_pitch, max_pitch)
	rotation.x = camera_pitch

func trigger_land_dip(intensity: float = 0.04) -> void:
	_land_offset = clamp(intensity, 0.02, 0.08)

func process_camera(delta: float, velocity: Vector3, is_on_floor: bool, speed: float) -> void:
	match current_state:
		State.NORMAL:
			_process_normal_camera(delta, velocity, is_on_floor, speed)
		State.RAGDOLL_TUMBLE:
			_process_ragdoll_tumble(delta)
		State.RECOVERING:
			_process_recovery(delta)

func _process_normal_camera(delta: float, velocity: Vector3, is_on_floor: bool, speed: float) -> void:
	_land_offset = move_toward(_land_offset, 0.0, delta * 0.3)

	var is_moving := Vector2(velocity.x, velocity.z).length_squared() > 0.2
	if head_bob_enabled and is_moving and is_on_floor:
		_bob_timer += delta * (speed * 1.8)
		transform.origin.y = eye_height + sin(_bob_timer) * head_bob_intensity - _land_offset
		transform.origin.x = cos(_bob_timer * 0.5) * (head_bob_intensity * 0.6)
	else:
		_bob_timer = 0.0
		transform.origin.y = move_toward(transform.origin.y, eye_height - _land_offset, delta * 2.5)
		transform.origin.x = move_toward(transform.origin.x, 0.0, delta * 2.5)

# ---------------------------------------------------------------------------
# Ragdoll Follow Camera
# ---------------------------------------------------------------------------
func enter_ragdoll_state(follow_node: Node3D) -> void:
	_ragdoll_follow_node = follow_node
	current_state = State.RAGDOLL_TUMBLE
	# When tumbling, position camera directly at the physical ragdoll center/head
	if camera:
		camera.position = Vector3(0.0, 0.3, 0.8)

func exit_ragdoll_state() -> void:
	current_state = State.NORMAL
	_recover_timer = 0.0
	_ragdoll_follow_node = null
	if camera:
		camera.position = Vector3.ZERO
		camera.rotation = Vector3.ZERO
	transform.origin = Vector3(0.0, eye_height, 0.0)

func _process_ragdoll_tumble(_delta: float) -> void:
	if not _ragdoll_follow_node or not is_instance_valid(_ragdoll_follow_node):
		return
	# Follow the physical tumbling body smoothly in first-person
	global_position = _ragdoll_follow_node.global_position + Vector3(0.0, 0.4, 0.0)
	# Look in direction of ragdoll tumble
	if camera:
		camera.look_at(_ragdoll_follow_node.global_position + Vector3.UP * 0.2, Vector3.UP)

func _process_recovery(delta: float) -> void:
	_recover_timer += delta
	# Smoothly snap back to standing eye-level
	if camera:
		camera.position = camera.position.lerp(Vector3.ZERO, delta * 8.0)
		camera.rotation = camera.rotation.lerp(Vector3.ZERO, delta * 8.0)

	transform.origin = transform.origin.lerp(Vector3(0.0, eye_height, 0.0), delta * 8.0)
	rotation.x = camera_pitch

	if _recover_timer > 0.35:
		current_state = State.NORMAL
		transform.origin = Vector3(0.0, eye_height, 0.0)
		if camera:
			camera.position = Vector3.ZERO
			camera.rotation = Vector3.ZERO
