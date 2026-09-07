## CreatureAI.gd
## Finite-state-machine AI for creatures. Runs on server only.
## States: IDLE, WANDER, ALERT, FLEE, CHASE, ATTACK, HURT, DEAD
## Each CreatureDefinition declares which subset of states the creature uses.

class_name CreatureAI
extends Node

enum State { IDLE, WANDER, ALERT, FLEE, CHASE, ATTACK, HURT, DEAD }

signal state_changed(new_state: State)
signal player_spotted(player: Node3D)
signal attacked_player(player: Node3D)

@export var tick_rate: float = 0.12  ## AI update interval in seconds

var current_state: State = State.IDLE
var _target: Node3D = null
var _wander_pos: Vector3 = Vector3.ZERO
var _attack_cooldown: float = 0.0
var _hurt_timer: float = 0.0
var _tick_acc: float = 0.0
var _ai_enabled: bool = true

@onready var _ctrl: CreatureController = get_parent()

func _ready() -> void:
	if not multiplayer.is_server():
		set_process(false)
		return
	_pick_wander_pos()
	_enter_state(State.WANDER)

func _process(delta: float) -> void:
	if not _ai_enabled:
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_hurt_timer      = maxf(0.0, _hurt_timer - delta)
	_tick_acc += delta
	if _tick_acc < tick_rate:
		return
	_tick_acc = 0.0
	_tick()

# ---------------------------------------------------------------------------
# Main tick dispatcher
# ---------------------------------------------------------------------------
func _tick() -> void:
	var def := _ctrl.get_definition()
	if not def:
		return
	match current_state:
		State.IDLE:   _tick_idle(def)
		State.WANDER: _tick_wander(def)
		State.ALERT:  _tick_alert(def)
		State.FLEE:   _tick_flee(def)
		State.CHASE:  _tick_chase(def)
		State.ATTACK: _tick_attack(def)
		State.HURT:   _tick_hurt()
		State.DEAD:   pass

# ---------------------------------------------------------------------------
# State ticks
# ---------------------------------------------------------------------------
func _tick_idle(def: CreatureDefinition) -> void:
	var p := _nearest_player(def.sight_range)
	if p:
		_target = p
		_react_to_player_spotted(def)
		return
	## After short idle, wander
	if randf() < 0.6:
		_pick_wander_pos()
		_enter_state(State.WANDER)

func _tick_wander(def: CreatureDefinition) -> void:
	var p := _nearest_player(def.sight_range)
	if p:
		_target = p
		player_spotted.emit(p)
		_react_to_player_spotted(def)
		return
	if _ctrl.global_position.distance_to(_wander_pos) < 1.5:
		_enter_state(State.IDLE)
		return
	_ctrl.move_to(_wander_pos)

func _tick_alert(def: CreatureDefinition) -> void:
	if not _target_valid():
		_enter_state(State.WANDER)
		return
	var dist := _ctrl.global_position.distance_to(_target.global_position)
	if dist <= def.attack_range and def.is_aggressive:
		_enter_state(State.ATTACK)
	elif dist <= def.sight_range:
		if def.is_aggressive:
			_enter_state(State.CHASE)
		elif _has("FLEE", def):
			_enter_state(State.FLEE)
	else:
		_target = null
		_enter_state(State.WANDER)

func _tick_chase(def: CreatureDefinition) -> void:
	if not _target_valid():
		_enter_state(State.WANDER)
		return
	var dist := _ctrl.global_position.distance_to(_target.global_position)
	if dist > def.sight_range * 1.8:
		_target = null
		_enter_state(State.WANDER)
		return
	if dist <= def.attack_range:
		_enter_state(State.ATTACK)
		return
	_ctrl.move_to(_target.global_position)

func _tick_flee(def: CreatureDefinition) -> void:
	if not _target_valid():
		_enter_state(State.WANDER)
		return
	var dist := _ctrl.global_position.distance_to(_target.global_position)
	if dist > def.sight_range * 2.5:
		_target = null
		_enter_state(State.WANDER)
		return
	var away := (_ctrl.global_position - _target.global_position).normalized()
	_ctrl.move_to(_ctrl.global_position + away * 8.0)

func _tick_attack(def: CreatureDefinition) -> void:
	if not _target_valid():
		_enter_state(State.WANDER)
		return
	var dist := _ctrl.global_position.distance_to(_target.global_position)
	if dist > def.attack_range * 1.6:
		_enter_state(State.CHASE)
		return
	## Face target
	var face := (_target.global_position - _ctrl.global_position)
	face.y = 0.0
	if face.length_squared() > 0.01:
		_ctrl.rotation.y = lerp_angle(_ctrl.rotation.y, atan2(face.x, face.z), 0.2)
	_ctrl.stop_moving()
	if _attack_cooldown <= 0.0:
		_execute_attack(def)

func _tick_hurt() -> void:
	if _hurt_timer <= 0.0:
		_enter_state(State.CHASE if _target_valid() else State.WANDER)

# ---------------------------------------------------------------------------
# Attack execution
# ---------------------------------------------------------------------------
func _execute_attack(def: CreatureDefinition) -> void:
	_attack_cooldown = def.attack_cooldown
	attacked_player.emit(_target)
	var dist := _ctrl.global_position.distance_to(_target.global_position)
	if dist <= def.attack_range + 0.5:
		if _target.has_method("take_damage"):
			var kd := (_target.global_position - _ctrl.global_position).normalized()
			_target.take_damage.rpc_id(
				_target.get_multiplayer_authority(),
				def.attack_damage, kd, def.knockback_force
			)

# ---------------------------------------------------------------------------
# Event callbacks (called by CreatureHealth)
# ---------------------------------------------------------------------------
func on_hurt(knockback_dir: Vector3) -> void:
	if current_state == State.DEAD:
		return
	_hurt_timer = 0.5
	_enter_state(State.HURT)
	if not _target_valid():
		_target = _nearest_player(20.0)

func on_death() -> void:
	_enter_state(State.DEAD)
	_ctrl.stop_moving()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func set_ai_enabled(enabled: bool) -> void:
	_ai_enabled = enabled

func _enter_state(new_state: State) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(new_state)
	if new_state in [State.IDLE, State.ATTACK, State.HURT, State.DEAD]:
		_ctrl.stop_moving()

func _react_to_player_spotted(def: CreatureDefinition) -> void:
	if def.is_aggressive:
		_enter_state(State.ALERT)
	elif _has("FLEE", def):
		_enter_state(State.FLEE)
	else:
		_enter_state(State.ALERT)

func _pick_wander_pos() -> void:
	var r := (_ctrl.get_definition().wander_radius if _ctrl.get_definition() else 8.0)
	_wander_pos = _ctrl.global_position + Vector3(
		randf_range(-r, r), 0.0, randf_range(-r, r)
	)

func _nearest_player(max_range: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_range * max_range
	for p in GameManager.get_all_players():
		if not is_instance_valid(p):
			continue
		var d2 := _ctrl.global_position.distance_squared_to(p.global_position)
		if d2 < best_d:
			best_d = d2
			best = p
	return best

func _target_valid() -> bool:
	return _target != null and is_instance_valid(_target)

func _has(state_name: String, def: CreatureDefinition) -> bool:
	return state_name in def.ai_states
