## PlayerSpawner.gd
## Manages spawning and despawning of Player nodes for all peers.
## Attached to the DungeonRoot and TribeCamp scenes.

class_name PlayerSpawner
extends Node

@export var player_scene: PackedScene
@export var spawn_point: Marker3D = null

## Offset between simultaneous spawns so players don't stack
const SPAWN_SPREAD := 2.0

func _ready() -> void:
	if not player_scene:
		player_scene = load("res://scenes/player/Player.tscn") as PackedScene
	if not multiplayer.is_server():
		return

	# Defer spawn to the next frame so the parent scene finishes _ready()
	await get_tree().process_frame

	if not is_inside_tree():
		return

	if not spawn_point:
		spawn_point = get_parent().get_node_or_null("SpawnPoint") as Marker3D

	## Spawn a player for every connected peer (including host)
	var peer_ids: Array[int] = NetworkManager.get_connected_peer_ids()
	if peer_ids.is_empty():
		# Solo / Local host player
		peer_ids = [multiplayer.get_unique_id()]

	for i in peer_ids.size():
		_spawn_player(peer_ids[i], i)

	## Also connect future joins
	if not NetworkManager.player_connected.is_connected(_on_player_connected):
		NetworkManager.player_connected.connect(_on_player_connected)
	if not NetworkManager.player_disconnected.is_connected(_on_player_disconnected):
		NetworkManager.player_disconnected.connect(_on_player_disconnected)

func _spawn_player(peer_id: int, index: int = 0) -> void:
	if not player_scene or not is_inside_tree():
		return
	var parent_node := get_parent()
	if not parent_node or not parent_node.is_inside_tree():
		return

	# Avoid duplicate spawns
	var existing := parent_node.get_node_or_null("Player_%d" % peer_id)
	if existing:
		return

	var player := player_scene.instantiate() as Node3D
	player.name = "Player_%d" % peer_id
	player.set_multiplayer_authority(peer_id)
	parent_node.add_child(player)

	## Position
	var base := Vector3.ZERO
	if spawn_point and is_instance_valid(spawn_point):
		base = spawn_point.global_position
	elif parent_node.has_node("SpawnPoint"):
		var sp := parent_node.get_node("SpawnPoint") as Marker3D
		if sp:
			base = sp.global_position

	player.global_position = base + Vector3(
		(index % 2) * SPAWN_SPREAD - SPAWN_SPREAD * 0.5,
		0.5,
		(index / 2) * SPAWN_SPREAD - SPAWN_SPREAD * 0.5
	)
	print("PlayerSpawner: Spawned player %d at %v" % [peer_id, player.global_position])

func _on_player_connected(peer_id: int) -> void:
	var index := NetworkManager.player_info.keys().find(peer_id)
	_spawn_player(peer_id, maxi(index, 0))

func _on_player_disconnected(peer_id: int) -> void:
	var parent_node := get_parent()
	if not parent_node:
		return
	var player_node := parent_node.find_child("Player_%d" % peer_id, true, false)
	if player_node:
		player_node.queue_free()
