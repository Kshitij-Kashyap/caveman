## AnimationTestScene.gd
## ANIMATION_TEST validation scene (spec section 20).
## Drives every CavemanRig.ANIMATION_STATES entry through the AnimationTree
## (CavemanAnimator.travel). Keys 1-0 select states; SPACE plays attack.

class_name AnimationTestScene
extends Node3D

var _caveman: Caveman = null
var _label: Label = null

func _ready() -> void:
	_caveman = get_node_or_null("ModelPivot/Caveman") as Caveman
	_label = get_node_or_null("UI/InfoLabel") as Label
	_update_label()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var states := CavemanRig.ANIMATION_STATES
		var idx := -1
		match event.physical_keycode:
			KEY_1:
				idx = 0
			KEY_2:
				idx = 1
			KEY_3:
				idx = 2
			KEY_4:
				idx = 3
			KEY_5:
				idx = 4
			KEY_6:
				idx = 5
			KEY_7:
				idx = 6
			KEY_8:
				idx = 7
			KEY_9:
				idx = 8
			KEY_0:
				idx = 9
			KEY_SPACE:
				_caveman.travel("attack")
				_update_label()
				return
		if idx >= 0 and idx < states.size():
			_caveman.travel(states[idx])
			_update_label()

func _process(_delta: float) -> void:
	_update_label()

func _update_label() -> void:
	if _label and _caveman:
		_label.text = "1-0: idle walk run jump fall land attack spear_throw ragdoll_down ragdoll_recover — current=%s" % _caveman.current_state()
