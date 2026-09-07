## CampStation.gd
## Interactive Area3D station in the Tribe Camp.
## Emits interaction signals when a player approaches and presses the interact key (E).

class_name CampStation
extends Area3D

signal player_entered(player: Player)
signal player_exited(player: Player)
signal station_interacted(station: CampStation, player: Player)

@export var station_id: String = "station"
@export var station_name: String = "Station"
@export var prompt_action: String = "INTERACT"

var current_player: Player = null

func _ready() -> void:
	# Layer 5 is Trigger
	collision_layer = 0
	collision_mask = 2 # Player layer

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if current_player and event.is_action_pressed("interact"):
		if current_player.is_multiplayer_authority():
			station_interacted.emit(self, current_player)
			get_viewport().set_input_as_handled()

func _on_body_entered(body: Node3D) -> void:
	if body is Player and body.is_multiplayer_authority():
		current_player = body
		player_entered.emit(body)

func _on_body_exited(body: Node3D) -> void:
	if body == current_player:
		current_player = null
		player_exited.emit(body)
