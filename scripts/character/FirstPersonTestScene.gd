## FirstPersonTestScene.gd
## FIRST_PERSON_TEST validation scene (spec section 15/20).
## Player + camera + hands + floor + lighting. Verifies look / walk /
## sprint / jump / land and that the full body never blocks the camera
## (CavemanModel shadows-only mode) while the HeldItemSocket stays mounted.

class_name FirstPersonTestScene
extends Node3D

var _label: Label = null
var _player: Player = null

func _ready() -> void:
	_player = get_node_or_null("Player") as Player
	_label = get_node_or_null("UI/InfoLabel") as Label
	_update_label()

func _process(_delta: float) -> void:
	_update_label()

func _update_label() -> void:
	if _label == null or _player == null:
		return
	var socket_ok := _player.caveman_model.get_held_item_socket() != null
	_label.text = "WASD move | Sprint | Space jump | LMB swing | 1-5 tools | R ragdoll — cam=%s hands=%s socket=%s" % [
		str(_player.camera != null and _player.camera.current),
		str(_player.viewmodel != null and _player.viewmodel.visible),
		str(socket_ok),
	]
