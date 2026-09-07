## GlowRockSystem.gd
## Manages the player's throwable glow rocks (max 4, 60-second lifetime, slow regen).
## Only processes input for the local multiplayer authority.

class_name GlowRockSystem
extends Node

const MAX_ROCKS := 4
const ROCK_DURATION := 60.0   ## seconds each rock lasts
const REGEN_DELAY := 12.0     ## seconds before regen starts after throwing
const REGEN_TIME := 25.0      ## seconds to regen one rock

signal rock_count_changed(current: int, maximum: int)

@export var glow_rock_scene: PackedScene
@export var throw_force: float = 16.0
@export var glow_color: Color = Color(0.35, 0.95, 0.55)  ## Default: green

var current_rocks: int = MAX_ROCKS
var _regen_timer: float = 0.0
var _post_throw_delay: float = 0.0

func _ready() -> void:
	rock_count_changed.emit(current_rocks, MAX_ROCKS)
	if not glow_rock_scene:
		glow_rock_scene = load("res://scenes/items/GlowRock.tscn") as PackedScene

func _process(delta: float) -> void:
	var player := get_parent() as Node3D
	if not player or (player.has_method("is_multiplayer_authority") and not player.is_multiplayer_authority()):
		return

	if Input.is_action_just_pressed("throw_glow") and current_rocks > 0:
		_throw_rock()

	_tick_regen(delta)

func _throw_rock() -> void:
	var player := get_parent() as Node3D
	if not player:
		return

	var cam := get_viewport().get_camera_3d()
	var dir: Vector3
	if cam:
		dir = -cam.global_transform.basis.z
		dir.y += 0.25
		dir = dir.normalized()
	else:
		dir = (player.global_transform.basis.z * -1.0 + Vector3.UP * 0.3).normalized()

	var spawn_pos := player.global_position + Vector3(0, 1.2, 0)

	if glow_rock_scene:
		var rock := glow_rock_scene.instantiate() as RigidBody3D
		get_tree().current_scene.add_child(rock)
		rock.global_position = spawn_pos
		rock.apply_central_impulse(dir * throw_force)
		## Apply glow color
		var light := rock.find_child("OmniLight3D") as OmniLight3D
		if light:
			light.light_color = glow_color
		## Schedule despawn
		get_tree().create_timer(ROCK_DURATION).timeout.connect(
			func(): if is_instance_valid(rock): rock.queue_free()
		)

	current_rocks -= 1
	_post_throw_delay = REGEN_DELAY
	_regen_timer = 0.0
	rock_count_changed.emit(current_rocks, MAX_ROCKS)

func _tick_regen(delta: float) -> void:
	if current_rocks >= MAX_ROCKS:
		return

	if _post_throw_delay > 0.0:
		_post_throw_delay -= delta
		return

	_regen_timer += delta
	if _regen_timer >= REGEN_TIME:
		_regen_timer = 0.0
		current_rocks = mini(current_rocks + 1, MAX_ROCKS)
		rock_count_changed.emit(current_rocks, MAX_ROCKS)
