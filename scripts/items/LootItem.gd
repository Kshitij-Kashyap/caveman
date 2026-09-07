## LootItem.gd
## A physics-based loot object dropped by creatures or mining.
## Players can pick it up by walking into the auto-collect area.
## Server spawns it; all clients see it via MultiplayerSynchronizer.

class_name LootItem
extends RigidBody3D

signal collected(item_id: String, quantity: int, by_player: Node)

@export var auto_pickup_radius: float = 1.2

var item_id: String = ""
var quantity: int = 1

@onready var _pickup_area: Area3D = $PickupArea
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _label: Label3D = $Label3D

func _ready() -> void:
	_pickup_area.body_entered.connect(_on_body_entered)
	_update_visuals()

## Called by CreatureLootTable or MineableDeposit after spawning
func setup(new_item_id: String, new_quantity: int) -> void:
	item_id  = new_item_id
	quantity = new_quantity
	_update_visuals()

func _update_visuals() -> void:
	if _label:
		_label.text = "%s x%d" % [item_id.capitalize().replace("_", " "), quantity]
	## Tint mesh based on item type (simple placeholder differentiation)
	if _mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _item_color()
		mat.roughness = 0.8
		_mesh.set_surface_override_material(0, mat)

func _item_color() -> Color:
	match item_id:
		"meat":    return Color(0.75, 0.25, 0.20)
		"hide":    return Color(0.65, 0.50, 0.30)
		"bone":    return Color(0.90, 0.88, 0.78)
		"wood":    return Color(0.48, 0.30, 0.15)
		"stone":   return Color(0.50, 0.50, 0.52)
		"flint":   return Color(0.55, 0.48, 0.42)
		"copper":  return Color(0.72, 0.45, 0.20)
		"gold":    return Color(0.90, 0.80, 0.20)
		"crystal": return Color(0.50, 0.85, 0.95)
		_:         return Color(0.70, 0.65, 0.55)

func _on_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server():
		return
	if not body is CharacterBody3D:
		return
	## Check if it's a player
	var player := body as Node
	if not player.has_method("get_multiplayer_authority"):
		return
	var inv := player.find_child("PlayerInventory") as PlayerInventory
	if not inv:
		return
	if inv.add_item(item_id, quantity):
		collected.emit(item_id, quantity, player)
		QuestManager.report_collect(item_id, quantity)
		AudioManager.play_sfx(AudioManager.SFX.ITEM_PICKUP)
		queue_free()
