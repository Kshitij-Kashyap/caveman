## CreatureDefinition.gd
## Data resource describing a creature's stats, AI behaviour, and loot table.
## Create instances as .tres files in res://resources/creatures/

class_name CreatureDefinition
extends Resource

@export var creature_name: String = ""
@export var display_name: String = ""

## Combat stats
@export var max_health: float = 100.0
@export var move_speed: float = 3.0
@export var run_speed: float = 6.0
@export var attack_damage: float = 10.0
@export var attack_range: float = 1.8
@export var attack_cooldown: float = 1.5
@export var knockback_force: float = 5.0

## Sensing
@export var sight_range: float = 12.0
@export var alert_range: float = 6.0   ## Range at which creature becomes immediately hostile
@export var wander_radius: float = 8.0

## Behaviour flags
@export var is_aggressive: bool = false  ## Attacks players unprovoked

## Below this health fraction the creature attempts to flee (0 = never flees)
@export_range(0.0, 1.0) var flee_health_threshold: float = 0.0

## Which AI state names this creature uses (subset of CreatureAI.State enum keys)
@export var ai_states: PackedStringArray = PackedStringArray(["IDLE", "WANDER", "DEAD"])

## Visual scale multiplier applied to MeshRoot
@export var visual_scale: Vector3 = Vector3(1.0, 1.0, 1.0)

## Mesh colour tint (used on the placeholder capsule body)
@export var body_color: Color = Color(0.6, 0.5, 0.35)

## Loot drop entries — Array of Dictionaries:
## { "item_id": String, "min_qty": int, "max_qty": int, "chance": float 0..1 }
@export var loot_entries: Array[Dictionary] = []

## Score/XP granted when killed
@export var kill_value: int = 10
