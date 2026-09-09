## DebugIsland.gd
## Map controller for the Prehistoric Debug Island sandbox.
## Coordinates day/night environment, sector markers, auto-respawning test nodes,
## and player safety boundaries.

class_name DebugIsland
extends Node3D

@onready var sun: DirectionalLight3D = $DirectionalLight3D if has_node("DirectionalLight3D") else null
@onready var world_env: WorldEnvironment = $WorldEnvironment if has_node("WorldEnvironment") else null

var current_hour: float = 12.0

func _ready() -> void:
	# Ensure time of day starts at bright clear noon
	set_time_of_day(12.0)
	_setup_respawners()

func _process(_delta: float) -> void:
	# Safety check: if player falls off the world, return to hub
	var player := GameManager.get_local_player() as Node3D
	if player and player.global_position.y < -6.0:
		player.global_position = Vector3(0, 1.5, 0)
		if "velocity" in player:
			player.velocity = Vector3.ZERO

func set_time_of_day(hour: float) -> void:
	current_hour = hour
	if not sun:
		return

	# Hour: 0 to 24.
	# 6 = Dawn, 12 = Noon, 18 = Dusk, 0/24 = Midnight
	var sun_progress := ((hour - 6.0) / 24.0) * TAU
	sun.rotation_degrees.x = -rad_to_deg(sin(sun_progress)) * 65.0
	sun.rotation_degrees.y = rad_to_deg(sun_progress) - 90.0

	var is_day := hour >= 5.5 and hour <= 18.5

	if hour >= 5.0 and hour < 8.0:
		# Dawn: Warm golden-rose
		var t := (hour - 5.0) / 3.0
		sun.light_color = Color(1.0, 0.65, 0.4).lerp(Color(1.0, 0.92, 0.82), t)
		sun.light_energy = lerpf(0.2, 1.3, t)
	elif hour >= 8.0 and hour <= 16.5:
		# Noon: Bright warm prehistoric sun
		sun.light_color = Color(1.0, 0.95, 0.88)
		sun.light_energy = 1.35
	elif hour > 16.5 and hour <= 19.5:
		# Dusk: Deep amber sunset
		var t := (hour - 16.5) / 3.0
		sun.light_color = Color(1.0, 0.92, 0.82).lerp(Color(1.0, 0.45, 0.2), t)
		sun.light_energy = lerpf(1.35, 0.25, t)
	else:
		# Midnight: Cold blue moonlight
		sun.light_color = Color(0.4, 0.55, 0.85)
		sun.light_energy = 0.2

	if world_env and world_env.environment:
		var env := world_env.environment
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
			if is_day:
				sky_mat.sky_top_color = Color(0.25, 0.55, 0.95)
				sky_mat.sky_horizon_color = Color(0.65, 0.78, 0.9)
				sky_mat.ground_bottom_color = Color(0.18, 0.22, 0.18)
				env.ambient_light_energy = 0.75
			else:
				sky_mat.sky_top_color = Color(0.04, 0.06, 0.14)
				sky_mat.sky_horizon_color = Color(0.12, 0.16, 0.28)
				sky_mat.ground_bottom_color = Color(0.03, 0.04, 0.06)
				env.ambient_light_energy = 0.25

func _setup_respawners() -> void:
	# Wire all MineableDeposit nodes to auto-respawn after depletion
	for node in find_children("*", "MineableDeposit", true, false):
		if node is MineableDeposit:
			node.deposit_depleted.connect(func():
				var t_pos: Vector3 = node.global_position
				var t_item: String = node.item_id
				await get_tree().create_timer(6.0).timeout
				if is_instance_valid(node):
					node._hits_taken = 0
					node._depleted = false
					node.visible = true
					if node._col_shape:
						node._col_shape.set_deferred("disabled", false)
			)
