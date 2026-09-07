## NetworkManager.gd
## ENet-based multiplayer manager. Autoloaded as NetworkManager.
## Handles hosting, joining, disconnecting, and syncing player info.

extends Node

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal server_disconnected()
signal connection_failed()
signal connection_succeeded()

## Synced player metadata — peer_id -> info Dictionary
var player_info: Dictionary = {}

var _enet_peer: ENetMultiplayerPeer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Host a new session
func host_game(port: int = DEFAULT_PORT) -> Error:
	_enet_peer = ENetMultiplayerPeer.new()
	var err := _enet_peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("NetworkManager: Host failed on port %d — %s" % [port, error_string(err)])
		_enet_peer = null
		return err
	multiplayer.multiplayer_peer = _enet_peer
	## Register host as player 1
	var local_id := multiplayer.get_unique_id()
	player_info[local_id] = _local_player_info()
	player_connected.emit(local_id)
	print("NetworkManager: Hosting on port %d  (ID=%d)" % [port, local_id])
	return OK

## Join an existing session
func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	_enet_peer = ENetMultiplayerPeer.new()
	var err := _enet_peer.create_client(address, port)
	if err != OK:
		push_error("NetworkManager: Join failed to %s:%d — %s" % [address, port, error_string(err)])
		_enet_peer = null
		return err
	multiplayer.multiplayer_peer = _enet_peer
	print("NetworkManager: Connecting to %s:%d …" % [address, port])
	return OK

## Disconnect and clean up all state
func disconnect_from_game() -> void:
	if _enet_peer:
		_enet_peer.close()
		_enet_peer = null
	multiplayer.multiplayer_peer = null
	player_info.clear()

func is_server() -> bool:
	return multiplayer.is_server()

func is_connected_to_session() -> bool:
	return _enet_peer != null and _enet_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED

func get_connected_peer_ids() -> Array[int]:
	var ids: Array[int] = []
	for id: int in player_info:
		ids.append(id)
	return ids

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _local_player_info() -> Dictionary:
	return {
		"player_name": "CavePerson_%d" % randi_range(100, 999),
		"role": "BRUTE",
		"skin_index": 0,
		"ready": false,
	}

func _on_peer_connected(id: int) -> void:
	print("NetworkManager: Peer %d connected" % id)
	## Host: send existing player info to new peer
	if multiplayer.is_server():
		for existing_id: int in player_info:
			_rpc_receive_player_info.rpc_id(id, existing_id, player_info[existing_id])
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("NetworkManager: Peer %d disconnected" % id)
	player_info.erase(id)
	GameManager.unregister_player(id)
	player_disconnected.emit(id)

func _on_server_disconnected() -> void:
	print("NetworkManager: Server disconnected")
	disconnect_from_game()
	server_disconnected.emit()
	GameManager.return_to_main_menu()

func _on_connected_to_server() -> void:
	var local_id := multiplayer.get_unique_id()
	var info := _local_player_info()
	player_info[local_id] = info
	## Tell the server who we are; server will broadcast to others
	_rpc_send_player_info.rpc(local_id, info)
	connection_succeeded.emit()
	print("NetworkManager: Connected to server as ID=%d" % local_id)

func _on_connection_failed() -> void:
	_enet_peer = null
	connection_failed.emit()
	print("NetworkManager: Connection failed")

@rpc("any_peer", "reliable")
func _rpc_send_player_info(sender_id: int, info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	player_info[sender_id] = info
	_rpc_receive_player_info.rpc(sender_id, info)

@rpc("authority", "reliable")
func _rpc_receive_player_info(peer_id: int, info: Dictionary) -> void:
	player_info[peer_id] = info
