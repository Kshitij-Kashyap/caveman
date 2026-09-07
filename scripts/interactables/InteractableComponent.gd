## InteractableComponent.gd
## Generic first-person interaction component attachable to any station, chest, door, prop, or NPC.

class_name InteractableComponent
extends Node

signal interacted(player: Node)
signal hover_started(player: Node)
signal hover_ended(player: Node)

@export var prompt_key: String = "E"
@export var prompt_action: String = "INTERACT"
@export var interactable_name: String = "Object"
@export var target_type: String = "interact" ## "interact", "mine", "item", "talk"
@export var is_interactable: bool = true

func interact(player: Node) -> void:
	if not is_interactable:
		return
	AudioManager.play_sfx(AudioManager.SFX.UI_CLICK)
	interacted.emit(player)

func start_hover(player: Node) -> void:
	hover_started.emit(player)

func end_hover(player: Node) -> void:
	hover_ended.emit(player)
