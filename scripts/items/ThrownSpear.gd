## ThrownSpear.gd
## Physical ballistic spear projectile simulated by Jolt Physics.
## Flies in realistic aerodynamic arc, deals 50 piercing damage to creatures,
## knocks back physics props (like Jolt rats), embeds into walls/trees, and is retrievable.

class_name ThrownSpear
extends RigidBody3D

signal spear_hit(collider: Node, hit_position: Vector3)
signal spear_retrieved(player: Node)

@export var damage: float = 50.0
@export var throw_speed: float = 28.0
@export var is_embedded: bool = false
@export var can_be_retrieved: bool = false

@onready var model_pivot: Node3D = $ModelPivot
@onready var spear_mesh: MeshInstance3D = $ModelPivot/SpearMesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var interactable_comp: InteractableComponent = $InteractableComponent

var _flight_time: float = 0.0
var _max_lifetime: float = 90.0
var _has_hit: bool = false

func _ready() -> void:
	add_to_group("thrown_spears")
	add_to_group("props")

	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	if interactable_comp:
		interactable_comp.interacted.connect(_on_interacted)
		interactable_comp.is_interactable = false
		interactable_comp.prompt_key = "E"
		interactable_comp.prompt_action = "Retrieve Spear"
		interactable_comp.interactable_name = "Flint Spear"
		interactable_comp.target_type = "item"

	_setup_materials()

func _setup_materials() -> void:
	if not spear_mesh or not spear_mesh.mesh:
		return
	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.48, 0.32, 0.16)
	mat_wood.roughness = 0.85
	mat_wood.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mat_stone := StandardMaterial3D.new()
	mat_stone.albedo_color = Color(0.24, 0.23, 0.22)
	mat_stone.roughness = 0.65
	mat_stone.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mat_leather := StandardMaterial3D.new()
	mat_leather.albedo_color = Color(0.38, 0.26, 0.16)
	mat_leather.roughness = 0.90
	mat_leather.cull_mode = BaseMaterial3D.CULL_DISABLED

	var m: Mesh = spear_mesh.mesh
	for i in m.get_surface_count():
		var s_name: String = str(m.surface_get_name(i)).to_lower()
		if "wood" in s_name:
			spear_mesh.set_surface_override_material(i, mat_wood)
		elif "stone" in s_name:
			spear_mesh.set_surface_override_material(i, mat_stone)
		else:
			spear_mesh.set_surface_override_material(i, mat_leather)

func launch(origin: Vector3, direction: Vector3, initial_velocity: float = 28.0) -> void:
	global_position = origin
	var dir := direction.normalized()
	# Face flight direction initially
	if dir.length_squared() > 0.001:
		look_at(global_position + dir, Vector3.UP)

	linear_velocity = dir * initial_velocity
	# Slight forward aerodynamic spin
	angular_velocity = dir * 1.5
	_has_hit = false
	is_embedded = false

	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(am.SFX.SPEAR_THROW)

func _physics_process(delta: float) -> void:
	if is_embedded:
		return

	_flight_time += delta
	if _flight_time > _max_lifetime:
		queue_free()
		return

	# Align aerodynamic orientation along trajectory
	var vel := linear_velocity
	if vel.length() > 2.0:
		var target_fwd := vel.normalized()
		var current_fwd := -global_transform.basis.z
		var new_fwd := current_fwd.slerp(target_fwd, clampf(delta * 12.0, 0.0, 1.0))
		if new_fwd.length_squared() > 0.001 and abs(new_fwd.dot(Vector3.UP)) < 0.99:
			look_at(global_position + new_fwd, Vector3.UP)

func _on_body_entered(body: Node) -> void:
	if _has_hit or is_embedded:
		return

	# Prevent colliding with thrower in first 0.08 seconds
	if _flight_time < 0.08 and body.is_in_group("player"):
		return

	_has_hit = true
	var hit_pos := global_position
	var hit_dir := linear_velocity.normalized()
	var impact_spd := linear_velocity.length()

	spear_hit.emit(body, hit_pos)

	# 1. Creature / Living target
	var c_health := _find_component(body, "CreatureHealth")
	if c_health and c_health.has_method("take_damage"):
		var kd := hit_dir
		kd.y = max(kd.y, 0.2)
		c_health.take_damage.rpc_id(1, damage, kd, 12.0)
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.play_sfx(am.SFX.SPEAR_HIT_FLESH)
		_stick_to_target(body, hit_pos, hit_dir)
		return

	# 2. Physics Prop (such as Jolt Rat or rollable wheel)
	if body is RigidBody3D:
		var rb := body as RigidBody3D
		var force := damage * 0.65
		rb.apply_central_impulse(hit_dir * force + Vector3.UP * (force * 0.4))
		rb.apply_torque_impulse(Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3)))
		if rb.has_method("on_tool_hit"):
			rb.on_tool_hit(2, hit_dir, force) # ToolType.SPEAR = 2
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.play_sfx(am.SFX.SPEAR_HIT_FLESH)
		# Spear drops or bounces slightly off small physics props
		if impact_spd > 15.0:
			linear_velocity = -hit_dir * 3.0 + Vector3.UP * 2.0
		return

	# 3. Choppable Tree
	var tree := _find_component(body, "ChoppableTree")
	if tree and tree.has_method("on_hit"):
		tree.on_hit(2.0, false)
		_stick_to_target(body, hit_pos, hit_dir)
		return

	# 4. Spear Target
	if body.has_method("on_spear_hit"):
		body.on_spear_hit(hit_pos)
		_stick_to_target(body, hit_pos, hit_dir)
		return

	# 5. World Geometry (Ground, Cave Walls, Stone Monuments)
	_stick_to_target(body, hit_pos, hit_dir)

func _stick_to_target(surface_node: Node, pos: Vector3, dir: Vector3) -> void:
	is_embedded = true
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC

	# Penetrate 20cm into target surface
	global_position = pos + dir * 0.20
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

	# Play impact thud
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(am.SFX.SPEAR_HIT_WALL)

	# High-frequency mechanical vibration tween on the spear shaft
	if model_pivot:
		var orig_rot := model_pivot.rotation
		var tw := create_tween()
		tw.tween_property(model_pivot, "rotation:x", orig_rot.x + 0.12, 0.04)
		tw.tween_property(model_pivot, "rotation:x", orig_rot.x - 0.08, 0.05)
		tw.tween_property(model_pivot, "rotation:x", orig_rot.x + 0.04, 0.06)
		tw.tween_property(model_pivot, "rotation:x", orig_rot.x, 0.08)

	# Enable retrieval interaction
	can_be_retrieved = true
	if interactable_comp:
		interactable_comp.is_interactable = true

	# Parent to hit target if moving entity (e.g. creature body)
	if surface_node and surface_node != get_tree().current_scene and not (surface_node is StaticBody3D):
		call_deferred("_reparent_to_target", surface_node)

func _reparent_to_target(new_parent: Node) -> void:
	if not is_inside_tree() or not is_instance_valid(new_parent):
		return
	var g_xform := global_transform
	get_parent().remove_child(self)
	new_parent.add_child(self)
	global_transform = g_xform

func _on_interacted(player: Node) -> void:
	if not can_be_retrieved:
		return
	retrieve(player)

func retrieve(player: Node) -> void:
	if not is_inside_tree():
		return

	# Add spear back to player inventory
	if player and player.get("inventory"):
		var inv: InventoryComponent = player.inventory
		if inv and inv.has_method("add_item"):
			inv.add_item("flint_spear", 1)

	# Play pickup sound
	var am := get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(am.SFX.ITEM_PICKUP)

	spear_retrieved.emit(player)
	queue_free()

func _find_component(node: Node, type_name: String) -> Node:
	var cur := node
	var limit := 6
	while cur and limit > 0:
		limit -= 1
		if cur.get_script() != null:
			var s: Script = cur.get_script()
			if s.get_global_name() == type_name:
				return cur
		cur = cur.get_parent()
	return null
