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

func on_hit(damage: float = 1.0, _is_axe: bool = false) -> void:
	_trigger_wobble()
	_spawn_damage_popup(damage)

func _spawn_damage_popup(dmg: float) -> void:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 36
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.text = "%d DMG" % int(dmg)
	
	if dmg >= 80.0:
		label.modulate = Color(1.0, 0.35, 0.1, 1.0) # Volcanic Red-Orange
	elif dmg >= 60.0:
		label.modulate = Color(0.8, 0.4, 1.0, 1.0)  # Obsidian Purple
	elif dmg >= 45.0:
		label.modulate = Color(1.0, 0.85, 0.3, 1.0) # Bone Gold
	else:
		label.modulate = Color(0.95, 0.95, 0.95, 1.0) # White/Wood

	add_child(label)
	label.position = Vector3(randf_range(-0.2, 0.2), 2.2, randf_range(-0.1, 0.1))

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 0.8, 0.65).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(label, "scale", Vector3(1.3, 1.3, 1.3), 0.2).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(label, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(label.queue_free)

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
	_spawn_damage_popup(float(score))
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
