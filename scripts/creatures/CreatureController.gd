## CreatureController.gd
## Base physics controller for all creatures.
## Receives movement intentions from CreatureAI and applies them via CharacterBody3D.

class_name CreatureController
extends CharacterBody3D

@export var creature_def: CreatureDefinition = null

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _knockback: Vector3 = Vector3.ZERO

@onready var ai: CreatureAI = $CreatureAI
@onready var health: CreatureHealth = $CreatureHealth
@onready var loot_table: CreatureLootTable = $CreatureLootTable
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var mesh_root: Node3D = $MeshRoot
@onready var _sync: MultiplayerSynchronizer = $MultiplayerSynchronizer

func _ready() -> void:
	if creature_def:
		if mesh_root:
			mesh_root.scale = creature_def.visual_scale
		health.initialize(creature_def.max_health)

	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.8
	nav_agent.avoidance_enabled = true

	## Clients only receive synced position — no physics/AI
	if not multiplayer.is_server():
		set_physics_process(false)
		if ai:
			ai.set_process(false)
	
	_setup_sync()

func _setup_sync() -> void:
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:global_position"))
	cfg.add_property(NodePath(".:global_rotation"))
	if _sync:
		_sync.replication_config = cfg
		_sync.root_path = NodePath(".")

func _physics_process(delta: float) -> void:
	## Gravity
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	## Decay knockback
	if _knockback.length_squared() > 0.1:
		velocity += _knockback * delta
		_knockback = _knockback.lerp(Vector3.ZERO, 10.0 * delta)
	else:
		_knockback = Vector3.ZERO

	## Navigation-driven horizontal movement
	_navigate(delta)

	move_and_slide()

func _navigate(delta: float) -> void:
	if not nav_agent or nav_agent.is_navigation_finished():
		## Decelerate
		var spd := (creature_def.move_speed if creature_def else 3.0) * 5.0
		velocity.x = move_toward(velocity.x, 0.0, spd * delta)
		velocity.z = move_toward(velocity.z, 0.0, spd * delta)
		return

	var next_pos := nav_agent.get_next_path_position()
	var dir := (next_pos - global_position)
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		return
	dir = dir.normalized()

	var spd := creature_def.run_speed if creature_def else 5.0
	velocity.x = lerp(velocity.x, dir.x * spd, 10.0 * delta)
	velocity.z = lerp(velocity.z, dir.z * spd, 10.0 * delta)

	## Face movement direction
	var target_angle := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)

## Called by CreatureAI to set a navigation target
func move_to(target_pos: Vector3) -> void:
	nav_agent.target_position = target_pos

## Called by CreatureAI to stop navigation
func stop_moving() -> void:
	nav_agent.target_position = global_position

## Apply an impulse force (knockback, stumble)
func apply_knockback(direction: Vector3, force: float) -> void:
	_knockback += direction.normalized() * force

func get_definition() -> CreatureDefinition:
	return creature_def
