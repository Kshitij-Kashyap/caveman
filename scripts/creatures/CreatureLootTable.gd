## CreatureLootTable.gd
## Spawns loot items into the world when a creature dies. Server-only.

class_name CreatureLootTable
extends Node

@export var loot_item_scene: PackedScene

func _ready() -> void:
	if not loot_item_scene:
		loot_item_scene = load("res://scenes/items/LootItem.tscn") as PackedScene

## Called by CreatureHealth._die() on the server
func drop_loot(world_pos: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var ctrl := get_parent() as CreatureController
	if not ctrl or not ctrl.creature_def:
		return

	for entry: Dictionary in ctrl.creature_def.loot_entries:
		var chance: float = entry.get("chance", 1.0)
		if randf() > chance:
			continue
		var item_id: String = entry.get("item_id", "")
		if item_id.is_empty():
			continue
		var qty := randi_range(
			entry.get("min_qty", 1),
			entry.get("max_qty", 1)
		)
		if qty > 0:
			_spawn_item(item_id, qty, world_pos)

func _spawn_item(item_id: String, quantity: int, at_pos: Vector3) -> void:
	if not loot_item_scene:
		return
	var item := loot_item_scene.instantiate()
	get_tree().current_scene.add_child(item)
	## Scatter slightly around death position
	item.global_position = at_pos + Vector3(
		randf_range(-0.7, 0.7),
		0.4,
		randf_range(-0.7, 0.7)
	)
	if item.has_method("setup"):
		item.setup(item_id, quantity)
