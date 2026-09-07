## Pickaxe.gd
## Handles pickaxe swinging, hit detection, and damage.
## Attached to PickaxeAnchor on the Player.

class_name Pickaxe
extends Node3D

signal swing_started()
signal hit_deposit(deposit: Node)
signal hit_creature(creature_health: Node, direction: Vector3)

@export var mining_power: float = 1.0    ## Hits per swing
@export var melee_damage: float = 12.0  ## Damage to creatures
@export var swing_rate: float = 0.9     ## Swings per second
@export var reach: float = 2.2          ## Raycast reach in metres

var _can_swing: bool = true

func _ready() -> void:
	## Ensure no collision processing on non-authority
	pass

func _get_player() -> Player:
	var cur: Node = get_parent()
	while cur:
		if cur is Player:
			return cur
		cur = cur.get_parent()
	return null

func _process(_delta: float) -> void:
	var player := _get_player()
	if not player:
		return
	if not player.is_multiplayer_authority():
		return
	if Input.is_action_just_pressed("mine") and _can_swing:
		_start_swing()

func _start_swing() -> void:
	_can_swing = false
	swing_started.emit()

	## Tween the pickaxe mesh for visual feedback
	var tween := create_tween()
	tween.tween_property(self, "rotation:x", -PI * 0.4, 0.08)
	tween.tween_callback(_check_hit)
	tween.tween_property(self, "rotation:x", PI * 0.15, 0.12)
	tween.tween_property(self, "rotation:x", 0.0, 0.1)
	tween.tween_callback(_end_swing_cooldown)

func _check_hit() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return

	var origin := cam.global_position
	var end    := origin + (-cam.global_transform.basis.z) * reach
	var space  := get_world_3d().direct_space_state

	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 0b111  ## Layers 1-3
	query.exclude = []

	var result := space.intersect_ray(query)
	if result.is_empty():
		return

	var collider: Node = result.get("collider")
	var normal: Vector3 = result.get("normal", Vector3.UP)

	AudioManager.play_sfx(AudioManager.SFX.PICKAXE_HIT)

	## Walk up parent chain for mineable deposit
	var deposit := _find_ancestor_script(collider, "MineableDeposit")
	if deposit:
		deposit.on_hit(mining_power)
		hit_deposit.emit(deposit)
		AudioManager.play_sfx(AudioManager.SFX.PICKAXE_HIT_ORE)
		return

	## Check for creature
	var c_health := _find_ancestor_script(collider, "CreatureHealth")
	if c_health:
		var kd := -normal
		kd.y = 0.3
		c_health.take_damage.rpc_id(1, melee_damage, kd.normalized(), 4.0)
		hit_creature.emit(c_health, kd)

func _end_swing_cooldown() -> void:
	get_tree().create_timer(1.0 / swing_rate).timeout.connect(func(): _can_swing = true)

## Walk up the node tree looking for a node whose GDScript class_name matches
func _find_ancestor_script(node: Node, class_name_str: String) -> Node:
	var cur := node
	var limit := 8
	while cur and limit > 0:
		limit -= 1
		if cur.get_script() != null:
			var s: Script = cur.get_script()
			if s and s.get_global_name() == class_name_str:
				return cur
		cur = cur.get_parent()
	return null
