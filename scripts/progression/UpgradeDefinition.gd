## UpgradeDefinition.gd
## Data resource defining a purchasable upgrade at the Tribe Camp.
## Create instances as .tres files in res://resources/upgrades/

class_name UpgradeDefinition
extends Resource

enum EffectType {
	HEALTH_MAX,
	STAMINA_MAX,
	CARRY_WEIGHT,
	WALK_SPEED,
	SPRINT_SPEED,
	JUMP_HEIGHT,
	MINING_SPEED,
	MINING_POWER,
	GLOW_ROCK_COUNT,
	GLOW_ROCK_DURATION,
	ATTACK_DAMAGE,
}

@export var upgrade_id: String = ""
@export var upgrade_name: String = ""
@export_multiline var description: String = ""
@export var effect_type: EffectType = EffectType.HEALTH_MAX
@export var effect_value: float = 25.0

## Resources required to purchase: { item_id: quantity }
@export var cost_resources: Dictionary = {}

## upgrade_ids that must be purchased first
@export var prerequisites: PackedStringArray = PackedStringArray()
