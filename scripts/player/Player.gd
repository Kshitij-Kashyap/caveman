## Player.gd
## Central player coordinator in Cave Raiders.
## Orchestrates decoupled components:
## - FirstPersonController: Locomotion, jumping, sprinting, friction
## - FirstPersonCamera: First-person mouse look, pitch clamping, bobbing, and ragdoll tumble follow
## - FirstPersonViewmodel: Low-poly pickaxe and customized caveman arm/fist
## - HealthComponent: Health, damage, healing, and death
## - StaminaComponent: Stamina drain and regeneration
## - StatusEffectComponent: Status conditions and buffs
## - InventoryComponent: Loot and resource management
## - CharacterVisual (CavemanModel): Third-person mesh for shadows/multiplayer
## - CharacterRagdoll: Physics ragdoll with camera follow anchor

class_name Player
extends CharacterBody3D

const FirstPersonViewmodel = preload("res://scripts/player/FirstPersonViewmodel.gd")
const Crosshair = preload("res://scripts/ui/Crosshair.gd")
const FirstPersonController = preload("res://scripts/player/components/FirstPersonController.gd")
const FirstPersonCamera = preload("res://scripts/player/components/FirstPersonCamera.gd")
const HealthComponent = preload("res://scripts/player/components/HealthComponent.gd")
const StaminaComponent = preload("res://scripts/player/components/StaminaComponent.gd")
const StatusEffectComponent = preload("res://scripts/player/components/StatusEffectComponent.gd")
const InventoryComponent = preload("res://scripts/player/components/InventoryComponent.gd")
const InteractableComponent = preload("res://scripts/interactables/InteractableComponent.gd")

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal player_died()
signal ragdoll_state_changed(is_ragdolling: bool)

# ---------------------------------------------------------------------------
# Exports & Customization
# ---------------------------------------------------------------------------
@export var customization: CharacterCustomizationData = null

# ---------------------------------------------------------------------------
# Component Node References
# ---------------------------------------------------------------------------
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var controller: FirstPersonController = $FirstPersonController
@onready var fp_camera: FirstPersonCamera = $FirstPersonCamera
@onready var viewmodel: FirstPersonViewmodel = $FirstPersonCamera/FirstPersonViewmodel
@onready var caveman_model: CavemanModel = $CavemanModel
@onready var ragdoll: CharacterRagdoll = $CharacterRagdoll

@onready var health_comp: HealthComponent = $HealthComponent
@onready var stamina_comp: StaminaComponent = $StaminaComponent
@onready var status_comp: StatusEffectComponent = $StatusEffectComponent
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var glow_system: GlowRockSystem = $GlowRockSystem

@onready var first_person_hud: CanvasLayer = $FirstPersonHUD
@onready var crosshair: Crosshair = $FirstPersonHUD/Crosshair
@onready var _sync: MultiplayerSynchronizer = $MultiplayerSynchronizer

# Backward-compatibility aliases for existing scenes and scripts
var head_pitch_pivot: Node3D:
	get: return fp_camera
var camera: Camera3D:
	get: return fp_camera.camera if fp_camera else null
var interact_ray: RayCast3D:
	get: return fp_camera.interact_ray if fp_camera else null

var current_health: float:
	get: return health_comp.current_health if health_comp else 100.0
	set(v): if health_comp: health_comp.current_health = v
var max_health: float:
	get: return health_comp.max_health if health_comp else 100.0
	set(v): if health_comp: health_comp.max_health = v
var current_stamina: float:
	get: return stamina_comp.current_stamina if stamina_comp else 100.0
	set(v): if stamina_comp: stamina_comp.current_stamina = v
var max_stamina: float:
	get: return stamina_comp.max_stamina if stamina_comp else 100.0
	set(v): if stamina_comp: stamina_comp.max_stamina = v
var is_dead: bool:
	get: return health_comp.is_dead if health_comp else false

# State
var is_ragdoll: bool = false
var _authority_id: int = 1
var _current_interactable: Node = null
var _camera_pitch: float:
	get: return fp_camera.camera_pitch if fp_camera else 0.0
	set(v): if fp_camera: fp_camera.camera_pitch = v

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_authority_id = get_multiplayer_authority()
	GameManager.register_player(_authority_id, self)

	# Component signal wiring
	health_comp.health_changed.connect(func(c, m): health_changed.emit(c, m))
	health_comp.died.connect(_on_died)
	stamina_comp.stamina_changed.connect(func(c, m): stamina_changed.emit(c, m))

	controller.landed.connect(func(spd):
		fp_camera.trigger_land_dip(0.04)
		if viewmodel:
			viewmodel.trigger_land_dip(spd)
	)

	# Character Customization
	if not customization:
		customization = CharacterCustomizationData.load_or_create()
	if caveman_model:
		caveman_model.apply_customization(customization)
	if viewmodel:
		viewmodel.apply_customization(customization)

	# Link ragdoll proxy to visual model
	if ragdoll and caveman_model:
		ragdoll.target_model = caveman_model

	_setup_sync()

	if not is_multiplayer_authority():
		set_physics_process(false)
		set_process(false)
		if fp_camera and fp_camera.camera:
			fp_camera.camera.current = false
		if first_person_hud:
			first_person_hud.visible = false
		if viewmodel:
			viewmodel.visible = false
		return

	# Local player setup: activate first-person view
	fp_camera.make_active_for_local_player()

	if caveman_model:
		caveman_model.set_first_person_visibility(true)

	if viewmodel:
		viewmodel.hit_deposit.connect(func(_d): if crosshair: crosshair.trigger_hit_marker())
		viewmodel.hit_creature.connect(func(_c, _d): if crosshair: crosshair.trigger_hit_marker())
		viewmodel.active_tool_changed.connect(func(_t, tool_name):
			if crosshair:
				crosshair.show_prompt("", "[%s]" % tool_name.to_upper(), "weapon")
				get_tree().create_timer(1.2).timeout.connect(func():
					if _current_interactable == null and crosshair:
						crosshair.hide_prompt()
				)
		)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _setup_sync() -> void:
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:global_position"))
	cfg.add_property(NodePath(".:rotation:y"))
	cfg.add_property(NodePath("FirstPersonCamera:rotation:x"))
	if _sync:
		_sync.replication_config = cfg
		_sync.root_path = NodePath(".")

# ---------------------------------------------------------------------------
# First-Person Input & Mouse Look
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	# Mouse Look
	var is_captured := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"
	if event is InputEventMouseMotion and is_captured and not is_ragdoll:
		fp_camera.handle_mouse_input(event)
		if viewmodel:
			viewmodel.add_sway(event.relative)
		return

	# Mouse capture toggle
	if event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	# Interaction trigger
	if event.is_action_pressed("interact") and not is_ragdoll:
		_perform_interaction()
		return

	# Weapon / Tool switching (Keys 1-4 & Mouse Wheel)
	if event is InputEventMouseButton and event.pressed and not is_ragdoll:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if viewmodel:
				viewmodel.cycle_tool(-1)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if viewmodel:
				viewmodel.cycle_tool(1)
			return

	if event is InputEventKey and event.pressed and not event.echo and not is_ragdoll:
		match event.physical_keycode:
			KEY_1:
				if viewmodel:
					viewmodel.switch_tool(FirstPersonViewmodel.ToolType.PICKAXE)
				return
			KEY_2:
				if viewmodel:
					viewmodel.switch_tool(FirstPersonViewmodel.ToolType.AXE)
				return
			KEY_3:
				if viewmodel:
					viewmodel.switch_tool(FirstPersonViewmodel.ToolType.SPEAR)
				return
			KEY_4:
				if viewmodel:
					viewmodel.switch_tool(FirstPersonViewmodel.ToolType.CLUB)
				return
			KEY_5:
				if viewmodel:
					viewmodel.switch_tool(FirstPersonViewmodel.ToolType.TORCH)
				return

	# Debug keys
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				if is_ragdoll:
					disable_ragdoll()
				else:
					enable_ragdoll(Vector3.ZERO, -global_transform.basis.z * 10.0 + Vector3.UP * 4.0)
			KEY_T:
				if is_ragdoll:
					ragdoll.apply_impulse(-global_transform.basis.z, 30.0)
				else:
					velocity += -global_transform.basis.z * 15.0
			KEY_Y:
				if is_ragdoll:
					ragdoll.apply_impulse(Vector3.UP, 45.0)
				else:
					velocity.y += 18.0
			KEY_U:
				enable_ragdoll(Vector3.UP * 6.0, -global_transform.basis.z * 25.0 + Vector3.UP * 10.0)
			KEY_I:
				if is_ragdoll:
					disable_ragdoll()

# ---------------------------------------------------------------------------
# Process & Physics Loop
# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if not is_multiplayer_authority() or is_ragdoll:
		return

	# Continuous mining / attack swing on Left Click hold
	var is_captured := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"
	if Input.is_action_pressed("mine") and is_captured:
		if viewmodel:
			viewmodel.try_swing()

func _physics_process(delta: float) -> void:
	if is_ragdoll:
		fp_camera.process_camera(delta, Vector3.ZERO, false, 0.0)
		return

	# 1. Locomotion
	var loco := controller.update_locomotion(delta, self, stamina_comp)

	# 2. Camera bobbing & motion
	fp_camera.process_camera(delta, velocity, is_on_floor(), loco.get("speed", 0.0))

	# 3. Viewmodel sway & bobbing
	if viewmodel:
		viewmodel.process_viewmodel(delta, velocity, is_on_floor(), loco.get("is_sprinting", false))

	# 4. First-Person Interaction Targeting
	_check_interaction_target()

	# 5. Third-Person Visual Character Model & Dynamic Shadow Animation
	if caveman_model:
		var horiz_vel := Vector2(velocity.x, velocity.z)
		var is_walking := horiz_vel.length_squared() > 0.1 and is_on_floor()
		caveman_model.is_moving = is_walking
		caveman_model.walk_speed_factor = 14.0 if loco.get("is_sprinting", false) else 9.0

# ---------------------------------------------------------------------------
# First-Person Interaction & Targeting
# ---------------------------------------------------------------------------
func _check_interaction_target() -> void:
	var ray := interact_ray
	if not ray or not crosshair:
		return

	if ray.is_colliding():
		var collider: Node = ray.get_collider()

		# A. Generic InteractableComponent
		var comp := _find_interactable_component(collider)
		if comp and comp.is_interactable:
			_current_interactable = comp
			crosshair.show_prompt(comp.prompt_key, "%s — %s" % [comp.prompt_action, comp.interactable_name], comp.target_type)
			return

		# B. MineableDeposit
		var deposit := _find_ancestor_script(collider, "MineableDeposit")
		if deposit:
			_current_interactable = deposit
			var d_name: String = deposit.get("deposit_name") if "deposit_name" in deposit else "Ore Deposit"
			var hits: int = deposit.get("current_hits_remaining") if "current_hits_remaining" in deposit else 3
			crosshair.show_prompt("LMB", "Mine %s (%d Hits)" % [d_name, hits], "mine")
			return

		# B2. ChoppableTree
		var tree := _find_ancestor_script(collider, "ChoppableTree")
		if not tree and (collider is ChoppableTree or (collider.has_method("on_hit") and collider.has_signal("tree_chopped"))):
			tree = collider
		if tree and not tree.get("is_chopped"):
			_current_interactable = tree
			var hp: int = tree.get("current_health") if "current_health" in tree else 5
			if viewmodel and viewmodel.current_tool == FirstPersonViewmodel.ToolType.TORCH:
				crosshair.show_prompt("LMB", "Ignite Tree with Torch", "mine")
			elif viewmodel and viewmodel.current_tool == FirstPersonViewmodel.ToolType.AXE:
				crosshair.show_prompt("LMB", "Chop Tree (Stone Axe) [%d HP]" % hp, "mine")
			else:
				crosshair.show_prompt("LMB", "Chop Tree [%d HP]" % hp, "mine")
			return

		# C. LootItem
		var loot := _find_ancestor_script(collider, "LootItem")
		if loot:
			_current_interactable = loot
			var item_name: String = loot.get("item_id").capitalize() if "item_id" in loot else "Item"
			crosshair.show_prompt("E", "Collect %s" % item_name, "item")
			return

		# D. Creature
		var creature := _find_ancestor_script(collider, "CreatureController")
		if creature:
			_current_interactable = creature
			var c_name := "Creature"
			if "creature_def" in creature and creature.creature_def:
				c_name = creature.creature_def.creature_name
			crosshair.show_prompt("LMB", "Attack %s" % c_name, "creature")
			return

	_current_interactable = null
	crosshair.hide_prompt()

func _perform_interaction() -> void:
	if not _current_interactable or not is_instance_valid(_current_interactable):
		return

	if _current_interactable is InteractableComponent:
		var comp := _current_interactable as InteractableComponent
		comp.interact(self)
	elif _current_interactable.has_signal("station_interacted"):
		_current_interactable.emit_signal("station_interacted", _current_interactable, self)
	elif _current_interactable is LootItem:
		var lt := _current_interactable as LootItem
		lt._on_body_entered(self)

func _find_interactable_component(node: Node) -> InteractableComponent:
	var cur := node
	var limit := 6
	while cur and limit > 0:
		limit -= 1
		if cur is InteractableComponent:
			return cur
		for child in cur.get_children():
			if child is InteractableComponent:
				return child
		cur = cur.get_parent()
	return null

func _find_ancestor_script(node: Node, class_name_str: String) -> Node:
	var cur := node
	var limit := 8
	while cur and limit > 0:
		limit -= 1
		if cur.get_script() != null:
			var s: Script = cur.get_script()
			if s.get_global_name() == class_name_str:
				return cur
		cur = cur.get_parent()
	return null

# ---------------------------------------------------------------------------
# Ragdoll System & First-Person Tumble Follow Camera
# ---------------------------------------------------------------------------
func enable_ragdoll(initial_velocity: Vector3 = Vector3.ZERO, impulse: Vector3 = Vector3.ZERO) -> void:
	if is_ragdoll or not ragdoll:
		return
	is_ragdoll = true
	controller.is_active = false
	if collision_shape:
		collision_shape.set_deferred("disabled", true)

	# Local player camera: smoothly follows the physical tumbling ragdoll body
	if is_multiplayer_authority():
		if caveman_model:
			caveman_model.set_first_person_visibility(false)
		if viewmodel:
			viewmodel.visible = false
		if crosshair:
			crosshair.visible = false
		fp_camera.enter_ragdoll_state(ragdoll.get_camera_follow_node())

	ragdoll.enable_ragdoll(initial_velocity + velocity, impulse)
	velocity = Vector3.ZERO
	ragdoll_state_changed.emit(true)

func disable_ragdoll() -> void:
	if not is_ragdoll or not ragdoll:
		return
	var recover_pos := ragdoll.get_recovery_position()
	global_position = recover_pos
	ragdoll.disable_ragdoll()

	if collision_shape:
		collision_shape.set_deferred("disabled", false)

	# Restore normal first-person camera and hands
	if is_multiplayer_authority():
		fp_camera.exit_ragdoll_state()
		if caveman_model:
			caveman_model.set_first_person_visibility(true)
		if viewmodel:
			viewmodel.visible = true
		if crosshair:
			crosshair.visible = true

	controller.is_active = true
	velocity = Vector3.ZERO
	is_ragdoll = false
	ragdoll_state_changed.emit(false)

# ---------------------------------------------------------------------------
# Damage & Health RPCs
# ---------------------------------------------------------------------------
@rpc("any_peer", "call_local", "reliable")
func take_damage(amount: float, knockback_dir: Vector3, knockback_force: float) -> void:
	if not multiplayer.is_server():
		return
	_apply_damage_local(amount, knockback_dir, knockback_force)
	_rpc_client_damage.rpc(amount, knockback_dir, knockback_force, health_comp.current_health)

@rpc("authority", "unreliable")
func _rpc_client_damage(amount: float, kd: Vector3, kf: float, synced_hp: float) -> void:
	health_comp.set_synced_health(synced_hp)
	if kf > 15.0:
		enable_ragdoll(kd.normalized() * kf)

func _apply_damage_local(amount: float, knockback_dir: Vector3, knockback_force: float) -> void:
	health_comp.take_damage(amount, knockback_dir, knockback_force)
	if health_comp.is_dead:
		enable_ragdoll(knockback_dir.normalized() * maxf(knockback_force, 12.0))
	elif knockback_force > 15.0:
		enable_ragdoll(knockback_dir.normalized() * knockback_force)
	elif knockback_force > 0.0:
		velocity += knockback_dir.normalized() * knockback_force

func apply_knockback(direction: Vector3, force: float) -> void:
	if force > 15.0:
		enable_ragdoll(direction.normalized() * force)
	else:
		velocity += direction.normalized() * force

func heal(amount: float) -> void:
	health_comp.heal(amount)

func _on_died() -> void:
	player_died.emit()

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if multiplayer and _authority_id == multiplayer.get_unique_id():
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		GameManager.unregister_player(_authority_id)
