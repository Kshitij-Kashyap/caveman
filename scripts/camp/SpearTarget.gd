## SpearTarget.gd
## Interactive wooden practice target for spear throwing in the basecamp testing ground.
## Features concentric score rings (Bullseye 100, Mid 50, Outer 25) and hit reaction.

class_name SpearTarget
extends StaticBody3D

signal target_hit(score: int, hit_position: Vector3)

@export var max_score: int = 100
@onready var disk_mesh: MeshInstance3D = $DiskMesh
@onready var stand_mesh: Node3D = $StandMesh

func _ready() -> void:
	add_to_group("targets")
	add_to_group("props")

func on_hit(mining_power: float = 1.0, is_axe: bool = false) -> void:
	_trigger_wobble()

func on_spear_hit(hit_pos: Vector3) -> int:
	var local_hit := to_local(hit_pos)
	# Distance from disk center in local XY
	var r := Vector2(local_hit.x, local_hit.y - 1.4).length()
	var score := 25
	if r < 0.18:
		score = 100 # Bullseye!
	elif r < 0.40:
		score = 50
	else:
		score = 25

	_trigger_wobble()
	target_hit.emit(score, hit_pos)

	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(am.SFX.AXE_HIT_WOOD)

	return score

func _trigger_wobble() -> void:
	var tw := create_tween()
	tw.tween_property(self, "rotation:x", 0.18, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation:x", -0.10, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation:x", 0.05, 0.08)
	tw.tween_property(self, "rotation:x", 0.0, 0.10)
