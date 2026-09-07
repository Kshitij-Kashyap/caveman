## StaminaComponent.gd
## Decoupled component managing player stamina, drain, regeneration, and sprint expenditure.

class_name StaminaComponent
extends Node

signal stamina_changed(current: float, maximum: float)
signal stamina_depleted()
signal stamina_restored()

@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 22.0
@export var stamina_regen_rate: float = 10.0

var current_stamina: float

func _ready() -> void:
	max_stamina += ProgressionManager.get_upgrade_bonus(UpgradeDefinition.EffectType.STAMINA_MAX)
	current_stamina = max_stamina
	stamina_changed.emit(current_stamina, max_stamina)

func drain(delta: float, multiplier: float = 1.0) -> bool:
	if current_stamina <= 0.0:
		return false

	var was_above_zero := current_stamina > 0.0
	current_stamina = maxf(0.0, current_stamina - stamina_drain_rate * multiplier * delta)
	stamina_changed.emit(current_stamina, max_stamina)

	if was_above_zero and current_stamina <= 0.0:
		stamina_depleted.emit()

	return current_stamina > 0.0

func regen(delta: float) -> void:
	if current_stamina >= max_stamina:
		return

	var was_depleted := current_stamina <= 0.0
	current_stamina = minf(max_stamina, current_stamina + stamina_regen_rate * delta)
	stamina_changed.emit(current_stamina, max_stamina)

	if was_depleted and current_stamina > 0.0:
		stamina_restored.emit()

func has_stamina() -> bool:
	return current_stamina > 0.0

func consume(amount: float) -> bool:
	if current_stamina < amount:
		return false
	current_stamina = maxf(0.0, current_stamina - amount)
	stamina_changed.emit(current_stamina, max_stamina)
	return true
