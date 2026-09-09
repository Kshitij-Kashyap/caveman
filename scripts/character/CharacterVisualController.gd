## Owns presentation state only. PlayerData may replace the visual stage at any
## time without replacing inventory, stats, or customization.
class_name CharacterVisualController
extends Node

signal stage_changed(stage: int, definition: EvolutionStageDefinition)

@export_range(1, 5) var evolution_stage: int = 1:
	set(value):
		evolution_stage = clampi(value, 1, 5)
		_apply()
@export var customization: CharacterCustomizationData

var character_visual: CavemanModel

func setup(target: CavemanModel, data: CharacterCustomizationData = null) -> void:
	character_visual = target
	if data:
		customization = data
	_apply()

func set_customization(data: CharacterCustomizationData) -> void:
	customization = data
	_apply()

func _apply() -> void:
	if not is_instance_valid(character_visual):
		return
	if customization:
		character_visual.apply_customization(customization)
	character_visual.set_evolution_stage(evolution_stage)
	stage_changed.emit(evolution_stage, EvolutionStageDefinition.make(evolution_stage))
