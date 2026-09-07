## PlayerCamera.gd
## Third-person camera with SpringArm3D collision, mouse-look, and smooth follow.
## Spawned as a separate node in the scene root by the local Player on _ready().

class_name PlayerCamera
extends Node3D

@export var target: Node3D = null:
	set(value):
		target = value
		if is_instance_valid(target):
			global_position = target.global_position + follow_offset

@export var follow_offset: Vector3 = Vector3(0.0, 1.4, 0.0)
@export var follow_speed: float = 12.0

@export var mouse_sensitivity_h: float = 0.003
@export var mouse_sensitivity_v: float = 0.002
@export var min_pitch: float = -1.0       ## ~-57 deg
@export var max_pitch: float = 1.1        ## ~+63 deg

@export var arm_default: float = 5.0
@export var arm_min: float = 2.0
@export var arm_max: float = 12.0

var _yaw: float = 0.0
var _pitch: float = -0.25

@onready var _spring_arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D

func _ready() -> void:
	_spring_arm.spring_length = arm_default
	_spring_arm.collision_mask = 1
	if _camera:
		_camera.current = true
		_camera.make_current()

func _input(event: InputEvent) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		if event.is_action_pressed("ui_cancel"):
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	if event is InputEventMouseMotion:
		_yaw   -= event.relative.x * mouse_sensitivity_h
		_pitch  = clamp(_pitch - event.relative.y * mouse_sensitivity_v, min_pitch, max_pitch)

	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_spring_arm.spring_length = clamp(_spring_arm.spring_length - 0.5, arm_min, arm_max)
			MOUSE_BUTTON_WHEEL_DOWN:
				_spring_arm.spring_length = clamp(_spring_arm.spring_length + 0.5, arm_min, arm_max)

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return

	## Smooth position follow
	var target_pos := target.global_position + follow_offset
	global_position = global_position.lerp(target_pos, follow_speed * delta)

	## Yaw on this node, pitch on the spring arm
	rotation.y = _yaw
	_spring_arm.rotation.x = _pitch

	## Always look at the pivot (player head position)
	if _camera and is_instance_valid(_camera):
		if _camera.global_position.distance_squared_to(global_position) > 0.05:
			_camera.look_at(global_position, Vector3.UP)
