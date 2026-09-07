## CharacterPreview.gd
## 3D studio preview container for character customization.
## Features studio lighting, stone pedestal, mouse drag rotation, and auto-spin.

class_name CharacterPreview
extends SubViewportContainer

@export var auto_rotate: bool = true
@export var auto_rotate_speed: float = 0.4
@export var drag_sensitivity: float = 0.008

@onready var viewport: SubViewport = $SubViewport
@onready var model_pivot: Node3D = $SubViewport/ModelPivot
@onready var caveman_model: CavemanModel = $SubViewport/ModelPivot/CavemanModel
@onready var camera: Camera3D = $SubViewport/Camera3D

var _is_dragging: bool = false
var _last_drag_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Ensure stretch is true so SubViewport fills container
	stretch = true
	if caveman_model and not caveman_model.customization:
		caveman_model.apply_customization(CharacterCustomizationData.get_default())

func _process(delta: float) -> void:
	if auto_rotate and not _is_dragging and model_pivot:
		model_pivot.rotation.y += auto_rotate_speed * delta

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var btn := event as InputEventMouseButton
		if btn.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = btn.pressed
			_last_drag_pos = btn.position
	elif event is InputEventMouseMotion and _is_dragging:
		var motion := event as InputEventMouseMotion
		var delta_x: float = motion.position.x - _last_drag_pos.x
		_last_drag_pos = motion.position
		if model_pivot:
			model_pivot.rotation.y += delta_x * drag_sensitivity

func update_customization(data: CharacterCustomizationData) -> void:
	if caveman_model:
		caveman_model.apply_customization(data)

func reset_rotation() -> void:
	if model_pivot:
		model_pivot.rotation.y = 0.0
