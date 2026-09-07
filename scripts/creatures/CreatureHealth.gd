## CreatureHealth.gd
## Manages creature HP and death. Server-authoritative damage processing.

class_name CreatureHealth
extends Node

signal health_changed(current: float, maximum: float)
signal creature_died(death_pos: Vector3)

var max_health: float = 100.0
var current_health: float = 100.0
var is_dead: bool = false

func initialize(hp: float) -> void:
	max_health = hp
	current_health = hp

## Called by Pickaxe or other damage sources. Validated on the server.
@rpc("any_peer", "reliable")
func take_damage(amount: float, knockback_dir: Vector3, knockback_force: float) -> void:
	if not multiplayer.is_server():
		return
	_apply(amount, knockback_dir, knockback_force)
	## Sync visual feedback to all clients
	_rpc_damage_vfx.rpc(amount, knockback_dir, knockback_force, current_health)

@rpc("authority", "unreliable")
func _rpc_damage_vfx(amount: float, knockback_dir: Vector3, knockback_force: float, synced_hp: float) -> void:
	current_health = synced_hp
	health_changed.emit(current_health, max_health)
	## Visual knockback on client
	var ctrl := get_parent() as CreatureController
	if ctrl:
		ctrl.apply_knockback(knockback_dir, knockback_force * 0.4)

func _apply(amount: float, knockback_dir: Vector3, knockback_force: float) -> void:
	if is_dead:
		return
	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)

	var ctrl := get_parent() as CreatureController
	if ctrl:
		ctrl.apply_knockback(knockback_dir, knockback_force)

	var ai := get_parent().find_child("CreatureAI") as CreatureAI
	if ai:
		ai.on_hurt(knockback_dir)

	if current_health <= 0.0:
		_die()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	var death_pos := (get_parent() as Node3D).global_position if get_parent() is Node3D else Vector3.ZERO
	creature_died.emit(death_pos)

	## Notify AI
	var ai := get_parent().find_child("CreatureAI") as CreatureAI
	if ai:
		ai.on_death()

	## Drop loot (server only)
	var loot := get_parent().find_child("CreatureLootTable") as CreatureLootTable
	if loot:
		loot.drop_loot(death_pos)

	## Report to quest manager
	var ctrl := get_parent() as CreatureController
	if ctrl and ctrl.creature_def:
		QuestManager.report_kill(ctrl.creature_def.creature_name)

	## Schedule despawn after death animation time
	get_tree().create_timer(3.5).timeout.connect(
		func(): if is_instance_valid(get_parent()): get_parent().queue_free()
	)

func get_health_fraction() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0
