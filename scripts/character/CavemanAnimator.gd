## CavemanAnimator.gd
## AnimationTree wrapper for the base caveman (spec section 13).
## Builds an AnimationNodeStateMachine from the CavemanModel AnimationPlayer
## at runtime so locomotion / actions travel through a real AnimationTree
## instead of hardcoded AnimationPlayer.play calls in gameplay code.
## Falls back to direct play_state() when no AnimationTree is present.

class_name CavemanAnimator
extends Node

var model: CavemanModel = null
var tree: AnimationTree = null

const ONE_SHOT_STATES: Array[String] = [
	"jump", "land", "attack", "spear_throw", "ragdoll_down", "ragdoll_recover"
]

func setup(target_model: CavemanModel, anim_tree: AnimationTree) -> bool:
	model = target_model
	tree = anim_tree
	if model == null or tree == null:
		return false
	if model.anim_player == null:
		return false
	return _build_state_machine()

func _build_state_machine() -> bool:
	var player := model.anim_player
	var states: Array[String] = []
	for s in CavemanRig.ANIMATION_STATES:
		if player.has_animation(s):
			states.append(s)
	if states.is_empty():
		return false

	var machine := AnimationNodeStateMachine.new()
	for s in states:
		var node := AnimationNodeAnimation.new()
		node.animation = s
		machine.add_node(s, node)
	# Start state.
	machine.start_node = "idle" if states.has("idle") else states[0]
	# Fully connect: any state can travel to any other state (validation
	# scenes and gameplay drive transitions explicitly via travel()).
	for from in states:
		for to in states:
			if from != to:
				var tr := AnimationNodeStateMachineTransition.new()
				tr.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
				machine.add_transition(from, to, tr)

	tree.tree_root = machine
	tree.anim_player = model.anim_player.get_path()
	tree.active = true
	return true

## Travel to a state through the AnimationTree when available,
## otherwise through the model. Returns false for unknown states.
func travel(state_name: String) -> bool:
	if model == null:
		return false
	if tree and tree.active and tree.tree_root is AnimationNodeStateMachine:
		if not (model.anim_player and model.anim_player.has_animation(state_name)):
			return false
		tree.set("parameters/playback/travel", state_name)
		model.current_state = state_name
		if state_name in ONE_SHOT_STATES:
			var anim: Animation = model.anim_player.get_animation(state_name)
			if anim:
				model._action_timer = anim.length
		return true
	return model.play_state(state_name)

func current_state() -> String:
	if tree and tree.active and tree.tree_root is AnimationNodeStateMachine:
		var playback := tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
		if playback:
			var cur: String = playback.get_current_node()
			if not cur.is_empty():
				return cur
	return model.current_state if model else "idle"
