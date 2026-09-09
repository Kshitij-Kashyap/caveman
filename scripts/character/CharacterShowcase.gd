## CharacterShowcase.gd
## CHARACTER_SHOWCASE validation scene (spec section 20).
## Neutral environment: pedestal + soft studio lighting + slow turntable.
## Proves the silhouette reads as a flat gray game character and that the
## full body (head/hands/feet/hair/beard/clothing) survives the import.

class_name CharacterShowcase
extends Node3D

@export var auto_rotate_speed: float = 0.4

var _pivot: Node3D = null
var _caveman: Caveman = null

func _ready() -> void:
	_pivot = get_node_or_null("ModelPivot") as Node3D
	_caveman = get_node_or_null("ModelPivot/Caveman") as Caveman

func _process(delta: float) -> void:
	if _pivot:
		_pivot.rotation.y += auto_rotate_speed * delta
