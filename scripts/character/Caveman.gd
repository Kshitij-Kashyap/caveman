## Caveman.gd
## Canonical reusable base caveman scene root (spec section 18).
## Keeps gameplay CharacterBody3D separate from this visual asset:
## Player.tscn instances this scene (or mirrors its structure) for the
## third-person / shadow / multiplayer body while FirstPersonVisual +
## HeldItemSockets serve the local first-person presentation.
##
##   Caveman (this script)
##   ├── CharacterVisual (CavemanModel: Skeleton3D + MeshInstance3D)
##   ├── FirstPersonVisual
##   │   ├── LeftArm / RightArm
##   │   └── HeldItemSocket (Marker3D, primary tool mount)
##   ├── AnimationTree (+ CavemanAnimator)
##   └── RagdollComponent (CharacterRagdoll)

class_name Caveman
extends Node3D

@export var customization: CharacterCustomizationData = null:
	set(value):
		customization = value
		if is_inside_tree() and _model:
			_model.customization = value
@export_range(1, 5) var evolution_stage: int = 1

var _model: CavemanModel = null
var _animator: CavemanAnimator = null
var _tree: AnimationTree = null
var _ragdoll: CharacterRagdoll = null
var _fp_visual: Node3D = null
var _visual_controller: CharacterVisualController = null

func _ready() -> void:
	_model = get_node_or_null("CharacterVisual/CavemanModel") as CavemanModel
	_tree = get_node_or_null("AnimationTree") as AnimationTree
	_ragdoll = get_node_or_null("RagdollComponent") as CharacterRagdoll
	_fp_visual = get_node_or_null("FirstPersonVisual") as Node3D

	if _model == null:
		# Scene was instantiated without the subscene wired (e.g. unit test
		# creating the script directly) — build a model programmatically.
		_model = CavemanModel.new()
		_model.name = "CavemanModel"
		var visual := get_node_or_null("CharacterVisual")
		if visual == null:
			visual = Node3D.new()
			visual.name = "CharacterVisual"
			add_child(visual)
		visual.add_child(_model)
		await _model.ready

	if _animator == null:
		_animator = CavemanAnimator.new()
		_animator.name = "CavemanAnimator"
		add_child(_animator)
	if _visual_controller == null:
		_visual_controller = CharacterVisualController.new()
		_visual_controller.name = "CharacterVisualController"
		add_child(_visual_controller)
	_visual_controller.evolution_stage = evolution_stage
	_visual_controller.setup(_model, customization)

	if _tree and _model:
		_animator.setup(_model, _tree)

	if _ragdoll and _model:
		_ragdoll.target_model = _model

	if customization:
		apply_customization(customization)
	else:
		apply_customization(CharacterCustomizationData.get_default())

## ---- Customization (spec section 6) ----
func apply_customization(data: CharacterCustomizationData) -> void:
	customization = data
	if _model:
		_model.apply_customization(data)
	if _visual_controller:
		_visual_controller.set_customization(data)

func set_evolution_stage(stage: int) -> void:
	evolution_stage = clampi(stage, 1, 5)
	if _model:
		_model.set_evolution_stage(evolution_stage)
	if _visual_controller:
		_visual_controller.evolution_stage = evolution_stage

func set_expression(expression: String) -> void:
	if _model:
		_model.set_expression(expression)

## ---- Animation (spec section 13, AnimationTree-driven) ----
func travel(state_name: String) -> bool:
	if _animator:
		return _animator.travel(state_name)
	if _model:
		return _model.play_state(state_name)
	return false

func current_state() -> String:
	if _animator:
		return _animator.current_state()
	return _model.current_state if _model else "idle"

## ---- First-person / full-body coexistence (spec section 9) ----
func set_first_person_visibility(is_first_person: bool) -> void:
	if _model:
		_model.set_first_person_visibility(is_first_person)

func get_held_item_socket(right_hand: bool = true) -> Marker3D:
	if _model:
		return _model.get_held_item_socket(right_hand)
	return get_node_or_null("FirstPersonVisual/HeldItemSocket") as Marker3D

## ---- Ragdoll (spec sections 11/14) ----
func enable_ragdoll(velocity: Vector3 = Vector3.ZERO, impulse: Vector3 = Vector3.ZERO) -> void:
	travel("ragdoll_down")
	if _ragdoll:
		_ragdoll.enable_ragdoll(velocity, impulse)

func disable_ragdoll() -> void:
	if _ragdoll:
		_ragdoll.disable_ragdoll()
	travel("ragdoll_recover")

func is_ragdoll() -> bool:
	return _ragdoll.is_ragdoll_active if _ragdoll else false
