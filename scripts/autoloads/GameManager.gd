## GameManager.gd
## Central game-state manager. Autoloaded as GameManager.
## Controls scene transitions: MainMenu → Camp → Expedition → Extraction.

extends Node

enum GameState {
	MAIN_MENU,
	LOADING,
	CAMP,
	EXPEDITION,
	EXTRACTING,
}

signal game_state_changed(new_state: GameState)
signal expedition_started(dungeon_seed: int)
signal expedition_ended(success: bool)

var current_state: GameState = GameState.MAIN_MENU
var current_dungeon_seed: int = 0

## All currently active Player nodes keyed by peer_id
var active_players: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Transition to a new game state
func change_state(new_state: GameState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	game_state_changed.emit(new_state)

## Begin an expedition. Pass seed = -1 to auto-generate.
func start_expedition(seed: int = -1) -> void:
	if seed < 0:
		seed = randi()
	current_dungeon_seed = seed
	change_state(GameState.LOADING)
	expedition_started.emit(seed)
	get_tree().change_scene_to_file("res://scenes/dungeon/DungeonRoot.tscn")

## Enter the tribe camp hub from menu or elsewhere
func enter_camp() -> void:
	active_players.clear()
	change_state(GameState.CAMP)
	get_tree().change_scene_to_file("res://scenes/camp/TribeCamp.tscn")

## Return all players to the tribe camp hub
func return_to_camp() -> void:
	enter_camp()

## Enter the debug island sandbox map
func enter_debug_island() -> void:
	active_players.clear()
	change_state(GameState.CAMP)
	get_tree().change_scene_to_file("res://scenes/maps/DebugIsland.tscn")

## Fully disconnect and return to main menu
func return_to_main_menu() -> void:
	active_players.clear()
	change_state(GameState.MAIN_MENU)
	NetworkManager.disconnect_from_game()
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

## Called by PlayerSpawner when a Player node enters the game
func register_player(peer_id: int, player_node: Node) -> void:
	active_players[peer_id] = player_node

## Called when a player disconnects or their node is freed
func unregister_player(peer_id: int) -> void:
	active_players.erase(peer_id)

func get_player_count() -> int:
	return active_players.size()

func get_all_players() -> Array:
	return active_players.values()

func get_local_player() -> Node:
	var local_id := multiplayer.get_unique_id()
	return active_players.get(local_id, null)

func get_player_by_id(peer_id: int) -> Node:
	return active_players.get(peer_id, null)
