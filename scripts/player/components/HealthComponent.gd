## HealthComponent.gd
## Decoupled component managing health, damage, healing, and death state.

class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, knockback_dir: Vector3, knockback_force: float)
signal healed(amount: float)
signal died()

@export var max_health: float = 100.0

var current_health: float
var is_dead: bool = false

func _ready() -> void:
	max_health += ProgressionManager.get_upgrade_bonus(UpgradeDefinition.EffectType.HEALTH_MAX)
	current_health = max_health
	health_changed.emit(current_health, max_health)

func take_damage(amount: float, knockback_dir: Vector3 = Vector3.ZERO, knockback_force: float = 0.0) -> void:
	if is_dead or amount <= 0.0:
		return

	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	damaged.emit(amount, knockback_dir, knockback_force)

	if current_health <= 0.0:
		is_dead = true
		died.emit()

func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return

	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
	healed.emit(amount)

func set_synced_health(hp: float) -> void:
	current_health = hp
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0 and not is_dead:
		is_dead = true
		died.emit()
