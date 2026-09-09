## RagdollTest.gd
## RAGDOLL_TEST validation scene (spec section 14/20).
## Full body + stairs + wall + impulses. Debug controls:
##   R -> enable ragdoll   T -> forward impulse   Y -> upward impulse
##   U -> strong side impulse (+enable)   I -> recover
## The ragdoll must feel funny but stay stable on built-in (Jolt) physics.

class_name RagdollTestScene
extends Node3D

var _caveman: Caveman = null
var _label: Label = null

func _ready() -> void:
	_caveman = get_node_or_null("Caveman") as Caveman
	_label = get_node_or_null("UI/InfoLabel") as Label
	_update_label()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				_caveman.enable_ragdoll(Vector3.ZERO, -_caveman.global_transform.basis.z * 8.0 + Vector3.UP * 3.0)
			KEY_T:
				_push(Vector3.FORWARD, 30.0)
			KEY_Y:
				_push(Vector3.UP, 45.0)
			KEY_U:
				_caveman.enable_ragdoll(Vector3.UP * 6.0, Vector3.RIGHT * 25.0 + Vector3.UP * 10.0)
			KEY_I:
				_caveman.disable_ragdoll()
		_update_label()

func _push(dir: Vector3, force: float) -> void:
	if _caveman.is_ragdoll():
		_caveman._ragdoll.apply_impulse(dir, force)
	else:
		_caveman.enable_ragdoll(Vector3.ZERO, dir * force * 0.4)

func _update_label() -> void:
	if _label and _caveman:
		_label.text = "R ragdoll | T fwd | Y up | U side | I recover — ragdoll=%s state=%s" % [
			str(_caveman.is_ragdoll()), _caveman.current_state()]
