## Campfire.gd
## Stylized prehistoric campfire featuring animated low-poly flames,
## dynamic firelight flickering, and floating ember particles.

class_name Campfire
extends Node3D

@export var is_lit: bool = true
@export var base_light_energy: float = 3.6
@export var light_flicker_speed: float = 14.0
@export var flame_pulse_speed: float = 7.5

var _time_elapsed: float = 0.0

@onready var flames_node: Node3D = $Flames if has_node("Flames") else null
@onready var flame_mesh: MeshInstance3D = $Flames/FlameMesh if has_node("Flames/FlameMesh") else null
@onready var fire_light: OmniLight3D = $FireLight if has_node("FireLight") else null
@onready var embers: CPUParticles3D = $Embers if has_node("Embers") else null

func _ready() -> void:
	_update_lit_state()

func _process(delta: float) -> void:
	if not is_lit:
		return

	_time_elapsed += delta
	var t := _time_elapsed

	# 1. Flame physical breathing & dancing scale
	if flames_node:
		var sx: float = 1.0 + sin(t * flame_pulse_speed) * 0.05 + cos(t * (flame_pulse_speed * 1.7)) * 0.025
		var sy: float = 1.0 + sin(t * (flame_pulse_speed * 1.1) + 0.8) * 0.09 + sin(t * (flame_pulse_speed * 2.1)) * 0.035
		var sz: float = 1.0 + cos(t * (flame_pulse_speed * 0.95)) * 0.05 + sin(t * (flame_pulse_speed * 1.5)) * 0.025
		flames_node.scale = Vector3(sx, sy, sz)

		# Subtle horizontal flame tilt/dance
		flames_node.rotation.y = sin(t * 3.5) * 0.08
		flames_node.rotation.z = cos(t * 4.2) * 0.03

	# 2. Dynamic firelight energy and range flicker
	if fire_light:
		var flicker1 := sin(t * light_flicker_speed) * 0.35
		var flicker2 := sin(t * (light_flicker_speed * 1.8) + 1.5) * 0.25
		var flicker3 := cos(t * (light_flicker_speed * 0.6)) * 0.2
		fire_light.light_energy = maxf(1.8, base_light_energy + flicker1 + flicker2 + flicker3)

func set_lit(lit: bool) -> void:
	is_lit = lit
	_update_lit_state()

func _update_lit_state() -> void:
	if flames_node:
		flames_node.visible = is_lit
	if fire_light:
		fire_light.visible = is_lit
	if embers:
		embers.emitting = is_lit

func is_flame_animated() -> bool:
	return is_lit and flames_node != null
