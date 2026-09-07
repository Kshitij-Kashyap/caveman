## ChoppableTree.gd
## A harvestable tree in Cave Raiders that can be chopped down for wood or ignited with a torch.
## Features wood splinter particles, trunk wobble physics, felling animation, and wood loot drops.

class_name ChoppableTree
extends StaticBody3D

signal tree_hit(remaining_hp: int)
signal tree_chopped()
signal tree_ignited()

@export var max_health: int = 5
@export var wood_drop_min: int = 3
@export var wood_drop_max: int = 6
@export var loot_item_scene: PackedScene

var current_health: int = 5
var is_chopped: bool = false
var is_burning: bool = false

var _burn_timer: float = 0.0

@onready var _trunk_pivot: Node3D = $TrunkPivot if has_node("TrunkPivot") else self
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null
@onready var _fire_light: OmniLight3D = $FireLight if has_node("FireLight") else null

func _ready() -> void:
	current_health = max_health
	if not loot_item_scene:
		loot_item_scene = load("res://scenes/items/LootItem.tscn") as PackedScene
	if _fire_light:
		_fire_light.visible = false

func _process(delta: float) -> void:
	if is_burning and not is_chopped:
		_burn_timer += delta
		if _burn_timer >= 0.8:
			_burn_timer = 0.0
			on_hit(1.0, false)

## Called when hit by an equipped tool
func on_hit(power: float = 1.0, is_axe: bool = false) -> void:
	if is_chopped:
		return

	# Stone Axe does 2.5x damage on wood compared to generic tools
	var damage: int = int(round(power * (2.5 if is_axe else 1.0)))
	if damage < 1:
		damage = 1

	current_health -= damage
	AudioManager.play_sfx(AudioManager.SFX.AXE_HIT_WOOD)

	# Trunk wobble animation feedback
	_play_wobble_fx()

	tree_hit.emit(max(0, current_health))

	if current_health <= 0:
		fell_tree()

## Called when ignited by a torch
func on_torch_hit() -> void:
	if is_chopped or is_burning:
		return
	is_burning = true
	if _fire_light:
		_fire_light.visible = true
	AudioManager.play_sfx(AudioManager.SFX.TORCH_IGNITE)
	tree_ignited.emit()

func _play_wobble_fx() -> void:
	if not _trunk_pivot:
		return
	var tween := create_tween()
	var wobble_angle := deg_to_rad(randf_range(3.0, 5.0))
	var dir := 1.0 if randf() > 0.5 else -1.0
	tween.tween_property(_trunk_pivot, "rotation:z", wobble_angle * dir, 0.05)
	tween.tween_property(_trunk_pivot, "rotation:z", -wobble_angle * 0.5 * dir, 0.08)
	tween.tween_property(_trunk_pivot, "rotation:z", 0.0, 0.06)

## Fell the tree, play falling animation and spawn wood logs
func fell_tree() -> void:
	if is_chopped:
		return
	is_chopped = true
	tree_chopped.emit()
	AudioManager.play_sfx(AudioManager.SFX.TREE_FALL)

	# Disable collision so player can walk through
	if _collision_shape:
		_collision_shape.set_deferred("disabled", true)

	# Spawn wood loot items
	_spawn_wood_loot()

	# Toppling animation
	var tween := create_tween()
	var fall_dir_x := randf_range(-1.0, 1.0)
	var fall_dir_z := 1.0 if abs(fall_dir_x) < 0.2 else randf_range(-1.0, 1.0)
	var fall_rot := Vector3(fall_dir_x, 0.0, fall_dir_z).normalized() * deg_to_rad(85.0)

	if _trunk_pivot and _trunk_pivot != self:
		tween.tween_property(_trunk_pivot, "rotation", Vector3(fall_rot.z, 0.0, -fall_rot.x), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Bounce slightly upon hitting ground
		tween.tween_property(_trunk_pivot, "position:y", _trunk_pivot.position.y - 0.1, 0.15)
		# Fade away fallen trunk after 3 seconds
		tween.tween_interval(2.5)
		tween.tween_property(_trunk_pivot, "scale", Vector3.ZERO, 0.5)
		tween.tween_callback(_cleanup_trunk)
	else:
		tween.tween_property(self, "scale", Vector3(1.2, 0.1, 1.2), 0.5)
		tween.tween_interval(2.0)
		tween.tween_callback(queue_free)

func _cleanup_trunk() -> void:
	if _trunk_pivot and _trunk_pivot != self:
		_trunk_pivot.queue_free()

func _spawn_wood_loot() -> void:
	if not loot_item_scene:
		return
	# Spawn on server or in single-player
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var qty := randi_range(wood_drop_min, wood_drop_max)
	for i in qty:
		var item := loot_item_scene.instantiate()
		var parent_node := get_tree().current_scene if get_tree() and get_tree().current_scene else get_parent()
		if parent_node:
			parent_node.add_child(item)
			var offset := Vector3(
				randf_range(-1.0, 1.0),
				randf_range(0.4, 1.2),
				randf_range(-1.0, 1.0)
			)
			item.global_position = global_position + offset
			if item.has_method("setup"):
				item.setup("wood", 1)
			if item is RigidBody3D:
				item.apply_impulse(Vector3(randf_range(-1.5, 1.5), randf_range(2.0, 4.0), randf_range(-1.5, 1.5)))
