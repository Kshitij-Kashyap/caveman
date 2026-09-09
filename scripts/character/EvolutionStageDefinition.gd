## Visual-only definition for a Cave Raiders evolution stage.  Gameplay data
## deliberately lives elsewhere so changing a body asset cannot reset a player.
class_name EvolutionStageDefinition
extends Resource

@export_range(1, 5) var stage: int = 1
@export var display_name: String = "Caveman"
@export var posture_pitch: float = 0.0
@export var head_scale: float = 1.0
@export var limb_scale: float = 1.0
@export var adds_refined_clothing: bool = false

static func make(stage_number: int) -> EvolutionStageDefinition:
	var definition := EvolutionStageDefinition.new()
	definition.stage = clampi(stage_number, 1, 5)
	match definition.stage:
		1:
			definition.display_name = "Caveman"
			definition.posture_pitch = deg_to_rad(8.0)
			definition.head_scale = 1.12
			definition.limb_scale = 1.08
		2:
			definition.display_name = "Hunter"
			definition.posture_pitch = deg_to_rad(5.0)
			definition.head_scale = 1.08
			definition.limb_scale = 1.05
		3:
			definition.display_name = "Tribe"
			definition.posture_pitch = deg_to_rad(2.0)
			definition.head_scale = 1.04
			definition.limb_scale = 1.02
			definition.adds_refined_clothing = true
		4:
			definition.display_name = "Crafter"
			definition.head_scale = 1.0
			definition.limb_scale = 1.0
			definition.adds_refined_clothing = true
		5:
			definition.display_name = "Tribe Civilized"
			definition.head_scale = 0.98
			definition.limb_scale = 0.98
			definition.adds_refined_clothing = true
	return definition
