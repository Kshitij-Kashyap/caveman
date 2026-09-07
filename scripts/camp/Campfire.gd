## Campfire.gd
## Stylized prehistoric campfire featuring separated stone ring, wood logs,
## animated low-poly flames, dynamic flickering firelight, rising embers, and billowing smoke.

class_name Campfire
extends Node3D

@export var is_lit: bool = true
@export var show_stones: bool = true
@export var show_wood_logs: bool = true
@export var base_light_energy: float = 2.8
@export var light_flicker_speed: float = 14.0
@export var flame_pulse_speed: float = 6.5

var _time_elapsed: float = 0.0

@onready var stones_mesh: MeshInstance3D = $Stones if has_node("Stones") else null
@onready var wood_logs_mesh: MeshInstance3D = $WoodLogs if has_node("WoodLogs") else null
@onready var flames_node: Node3D = $Flames if has_node("Flames") else null
@onready var flame_mesh: MeshInstance3D = $Flames/FlameMesh if has_node("Flames/FlameMesh") else null
@onready var fire_light: OmniLight3D = $FireLight if has_node("FireLight") else null
@onready var embers: CPUParticles3D = $Embers if has_node("Embers") else null
@onready var smoke: CPUParticles3D = $Smoke if has_node("Smoke") else null

func _ready() -> void:
	_update_visibility()
	_update_lit_state()

func _process(delta: float) -> void:
	if not is_lit:
		return

	_time_elapsed += delta
	var t := _time_elapsed

	# 1. Flame breathing & dancing scale
	if flames_node:
		var sx: float = 1.0 + sin(t * flame_pulse_speed) * 0.04 + cos(t * (flame_pulse_speed * 1.6)) * 0.02
		var sy: float = 1.0 + sin(t * (flame_pulse_speed * 1.1) + 0.8) * 0.07 + sin(t * (flame_pulse_speed * 2.1)) * 0.025
		var sz: float = 1.0 + cos(t * (flame_pulse_speed * 0.95)) * 0.04 + sin(t * (flame_pulse_speed * 1.5)) * 0.02
		flames_node.scale = Vector3(sx, sy, sz)

		# Organic subtle flame tilt/dance
		flames_node.rotation.y = sin(t * 3.0) * 0.06
		flames_node.rotation.z = cos(t * 3.8) * 0.025

	# 2. Dynamic firelight energy and flicker
	if fire_light:
		var flicker1 := sin(t * light_flicker_speed) * 0.3
		var flicker2 := sin(t * (light_flicker_speed * 1.7) + 1.2) * 0.2
		fire_light.light_energy = maxf(1.6, base_light_energy + flicker1 + flicker2)

func set_lit(lit: bool) -> void:
	is_lit = lit
	_update_lit_state()

func set_show_stones(visible_flag: bool) -> void:
	show_stones = visible_flag
	_update_visibility()

func set_show_wood_logs(visible_flag: bool) -> void:
	show_wood_logs = visible_flag
	_update_visibility()

func _update_visibility() -> void:
	if stones_mesh:
		stones_mesh.visible = show_stones
	if wood_logs_mesh:
		wood_logs_mesh.visible = show_wood_logs

func _update_lit_state() -> void:
	if flames_node:
		flames_node.visible = is_lit
	if fire_light:
		fire_light.visible = is_lit
	if embers:
		embers.emitting = is_lit
	if smoke:
		smoke.emitting = is_lit

func is_flame_animated() -> bool:
	return is_lit and flames_node != null

func has_smoke() -> bool:
	return smoke != null and smoke.emitting == is_lit
