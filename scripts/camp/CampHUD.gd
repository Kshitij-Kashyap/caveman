## CampHUD.gd
## Heads-up display for the Tribe Camp hub.
## Displays prompt banners when approaching stations and modal dialogs when interacting.

class_name CampHUD
extends CanvasLayer

signal expedition_confirmed
signal quest_chosen(quest: QuestDefinition)

# ---------------------------------------------------------------------------
# Node References
# ---------------------------------------------------------------------------
@onready var prompt_panel: PanelContainer = $PromptContainer
@onready var prompt_label: Label = $PromptContainer/PromptLabel

@onready var resources_label: Label = $TopRight/VBox/ResourcesLabel
@onready var currency_label: Label = $TopRight/VBox/CurrencyLabel

@onready var modal_container: Control = $ModalContainer
@onready var modal_title: Label = $ModalContainer/Panel/VBox/ModalTitle
@onready var modal_body: Label = $ModalContainer/Panel/VBox/ModalBody
@onready var modal_action_btn: Button = $ModalContainer/Panel/VBox/ActionBtn
@onready var modal_close_btn: Button = $ModalContainer/Panel/VBox/CloseBtn

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var _active_station: CampStation = null
var _current_modal_action: Callable

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	prompt_panel.visible = false
	modal_container.visible = false

	ProgressionManager.currency_changed.connect(_on_currency_changed)
	ProgressionManager.resources_changed.connect(_on_resources_changed)

	_on_currency_changed(ProgressionManager.currency)
	_on_resources_changed(ProgressionManager.stored_resources)

	modal_close_btn.pressed.connect(close_modal)
	modal_action_btn.pressed.connect(_on_action_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if modal_container.visible and event.is_action_pressed("ui_cancel"):
		close_modal()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Station Prompts
# ---------------------------------------------------------------------------
func show_station_prompt(station: CampStation) -> void:
	_active_station = station
	prompt_label.text = "[E]  %s — %s" % [station.prompt_action, station.station_name.to_upper()]
	prompt_panel.visible = true

func hide_station_prompt(station: CampStation) -> void:
	if _active_station == station:
		_active_station = null
		prompt_panel.visible = false

# ---------------------------------------------------------------------------
# Modals
# ---------------------------------------------------------------------------
func show_modal(title: String, body_text: String, action_text: String = "", action_callback: Callable = Callable()) -> void:
	modal_title.text = title
	modal_body.text = body_text
	_current_modal_action = action_callback

	if action_text.is_empty():
		modal_action_btn.visible = false
	else:
		modal_action_btn.text = action_text
		modal_action_btn.visible = true

	modal_container.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_modal() -> void:
	modal_container.visible = false
	_current_modal_action = Callable()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_action_pressed() -> void:
	AudioManager.play_sfx(AudioManager.SFX.UI_CLICK)
	if _current_modal_action.is_valid():
		_current_modal_action.call()
	close_modal()

# ---------------------------------------------------------------------------
# Resource Summary
# ---------------------------------------------------------------------------
func _on_currency_changed(amount: int) -> void:
	if currency_label:
		currency_label.text = "🦴 %d BONES" % amount

func _on_resources_changed(totals: Dictionary) -> void:
	if not resources_label:
		return
	var parts: Array[String] = []
	for item_id in totals:
		parts.append("%s: %d" % [item_id.capitalize(), totals[item_id]])
	if parts.is_empty():
		resources_label.text = "Stockpile: Empty"
	else:
		resources_label.text = "Stockpile: " + " | ".join(parts)
