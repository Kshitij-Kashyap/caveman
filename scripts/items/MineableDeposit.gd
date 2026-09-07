## MineableDeposit.gd
## A destructible resource deposit (ore vein, crystal, bone pile).
## Takes hits from Pickaxe and drops loot items when depleted.

class_name MineableDeposit
extends StaticBody3D

signal deposit_hit(remaining_hits: int)
signal deposit_depleted()

@export var item_id: String = "stone"
@export var quantity_min: int = 2
@export var quantity_max: int = 4
@export var required_hits: int = 3
@export var loot_item_scene: PackedScene

var _hits_taken: int = 0
var _depleted: bool = false

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _particles: GPUParticles3D = $HitParticles if has_node("HitParticles") else null

func _ready() -> void:
	if not loot_item_scene:
		loot_item_scene = load("res://scenes/items/LootItem.tscn") as PackedScene
	_apply_material()

func _apply_material() -> void:
	if not _mesh:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _deposit_color()
	mat.roughness = 0.95
	_mesh.set_surface_override_material(0, mat)

func _deposit_color() -> Color:
	match item_id:
		"stone":   return Color(0.48, 0.46, 0.44)
		"flint":   return Color(0.40, 0.35, 0.30)
		"copper":  return Color(0.65, 0.40, 0.18)
		"gold":    return Color(0.88, 0.78, 0.10)
		"crystal": return Color(0.60, 0.90, 0.95)
		"bone":    return Color(0.88, 0.85, 0.72)
		"fossil":  return Color(0.70, 0.60, 0.42)
		_:         return Color(0.55, 0.52, 0.48)

## Called by Pickaxe when the raycast hits this deposit
func on_hit(mining_power: float = 1.0) -> void:
	if _depleted:
		return
	_hits_taken += int(mining_power)
	AudioManager.play_sfx(AudioManager.SFX.PICKAXE_HIT_ORE)
	## Squash-and-stretch feedback
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.15, 0.85, 1.15), 0.06)
	tween.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.1)
	deposit_hit.emit(required_hits - _hits_taken)
	if _hits_taken >= required_hits:
		_deplete()

func _deplete() -> void:
	_depleted = true
	deposit_depleted.emit()
	## Spawn loot
	if multiplayer.is_server() and loot_item_scene:
		var qty := randi_range(quantity_min, quantity_max)
		for i in qty:
			var item := loot_item_scene.instantiate()
			get_tree().current_scene.add_child(item)
			item.global_position = global_position + Vector3(
				randf_range(-0.6, 0.6), 0.5, randf_range(-0.6, 0.6)
			)
			if item.has_method("setup"):
				item.setup(item_id, 1)
	## Visual collapse then remove
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.3, 0.1, 1.3), 0.25)
	tween.tween_callback(queue_free)
