## WeaponTierDefinition.gd
## Defines a specific upgrade tier for a weapon or tool in Cave Raiders.
## Controls visual attachment setup, damage stats, impulse multipliers, and upgrade costs.

class_name WeaponTierDefinition
extends Resource

@export var weapon_id: String = "club"
@export var tier: int = 1
@export var tier_name: String = "Crude Club"
@export_multiline var description: String = ""
@export var damage: float = 32.0
@export var impulse_multiplier: float = 1.0
@export var swing_rate_multiplier: float = 1.0
@export var mining_power: float = 0.6

## Upgrade requirements from previous tier
@export var cost_stone_rings: int = 0
@export var cost_resources: Dictionary = {} ## e.g. { "wood": 10, "stone": 5 }
