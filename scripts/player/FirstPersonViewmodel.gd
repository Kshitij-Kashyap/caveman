## FirstPersonViewmodel.gd
## High-polish first-person viewmodel for Cave Raiders.
## Features:
## - Chunky low-poly prehistoric arsenal: Pickaxe, Spear, Club, and Fire Torch
## - Dynamic weapon sway based on mouse motion
## - Locomotion bobbing (idle breathing, walking figure-8, sprinting stride)
## - Jump/fall and landing dips
## - Tool-specific attack animations (Pickaxe chop, Spear thrust, Club slam, Torch jab)
## - Weapon switching with smooth drop & raise animations
## - Dynamic torch firelight casting warm glow into dark caves
## - Customization-linked skin tones

class_name FirstPersonViewmodel
extends Node3D

signal swing_started()
signal active_tool_changed(tool_type: int, tool_name: String)
signal hit_deposit(deposit: Node)
signal hit_creature(creature_health: Node, direction: Vector3)
signal hit_world(position: Vector3, normal: Vector3)
signal spear_aim_started()
signal spear_aim_ended()
signal spear_thrown()

# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------
enum ToolType {
	PICKAXE = 0,
	AXE = 1,
	SPEAR = 2,
	CLUB = 3,
	TORCH = 4
}

const TOOL_NAMES := {
	ToolType.PICKAXE: "Stone Pickaxe",
	ToolType.AXE: "Stone Axe",
	ToolType.SPEAR: "Flint Spear",
	ToolType.CLUB: "Stone Club",
	ToolType.TORCH: "Fire Torch"
}

# ---------------------------------------------------------------------------
# Exports & Stats
# ---------------------------------------------------------------------------
@export var current_tool: ToolType = ToolType.PICKAXE
@export var reach: float = 2.4
@export var mining_power: float = 1.0
@export var melee_damage: float = 15.0
@export var swing_rate: float = 1.35 ## Swings per second

@export var sway_amount: float = 0.0018
@export var max_sway: float = 0.05
@export var sway_smoothness: float = 10.0
@export var rotation_sway_amount: float = 0.025

@export var default_pos: Vector3 = Vector3(0.24, -0.22, -0.38)
@export var default_rot: Vector3 = Vector3(0.08, -0.12, 0.04)

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var _can_swing: bool = true
var _is_swinging: bool = false
var _is_switching: bool = false
var is_aiming_spear: bool = false
var _sway_offset: Vector3 = Vector3.ZERO
var _rotation_sway: Vector3 = Vector3.ZERO
var _bob_timer: float = 0.0
var _land_dip: float = 0.0

var _rest_transform: Transform3D

# Visual instances
var arm_mesh: MeshInstance3D
var pickaxe_mesh: MeshInstance3D
var axe_mesh: MeshInstance3D
var spear_mesh: MeshInstance3D
var club_mesh: MeshInstance3D
var club_t2_mesh: MeshInstance3D
var club_t3_mesh: MeshInstance3D
var club_t4_mesh: MeshInstance3D
var torch_mesh: MeshInstance3D
var torch_light: OmniLight3D

var mat_skin: StandardMaterial3D
var mat_wood: StandardMaterial3D
var mat_stone: StandardMaterial3D
var mat_leather: StandardMaterial3D
var mat_fire: StandardMaterial3D
var mat_bone: StandardMaterial3D
var mat_obsidian: StandardMaterial3D
var mat_volcanic: StandardMaterial3D

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_init_materials()
	_build_viewmodel()
	transform.origin = default_pos
	rotation = default_rot
	_rest_transform = transform
	_apply_tool_visibility()
	_update_tool_stats()

	var pm := get_node_or_null("/root/ProgressionManager")
	if pm:
		if pm.has_signal("weapon_upgraded"):
			pm.weapon_upgraded.connect(_on_weapon_upgraded)
		apply_weapon_tier("club", pm.get_weapon_tier("club"))

func _init_materials() -> void:
	mat_skin = StandardMaterial3D.new()
	mat_skin.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_skin.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_skin.albedo_color = Color(0.85, 0.60, 0.44)
	mat_skin.roughness = 0.85

	mat_wood = StandardMaterial3D.new()
	mat_wood.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_wood.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_wood.albedo_color = Color(0.42, 0.28, 0.16)
	mat_wood.roughness = 0.92

	mat_stone = StandardMaterial3D.new()
	mat_stone.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_stone.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_stone.albedo_color = Color(0.24, 0.26, 0.28)
	mat_stone.roughness = 0.78

	mat_leather = StandardMaterial3D.new()
	mat_leather.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_leather.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_leather.albedo_color = Color(0.55, 0.36, 0.22)
	mat_leather.roughness = 0.90

	mat_fire = StandardMaterial3D.new()
	mat_fire.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_fire.albedo_color = Color(1.0, 0.45, 0.1)
	mat_fire.emission_enabled = true
	mat_fire.emission = Color(1.0, 0.45, 0.1)
	mat_fire.emission_energy_multiplier = 3.5

	mat_bone = StandardMaterial3D.new()
	mat_bone.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_bone.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_bone.albedo_color = Color(0.92, 0.88, 0.78)
	mat_bone.roughness = 0.60

	mat_obsidian = StandardMaterial3D.new()
	mat_obsidian.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_obsidian.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat_obsidian.albedo_color = Color(0.06, 0.06, 0.08)
	mat_obsidian.metallic = 0.35
	mat_obsidian.roughness = 0.12

	mat_volcanic = StandardMaterial3D.new()
	mat_volcanic.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_volcanic.albedo_color = Color(1.0, 0.35, 0.05)
	mat_volcanic.emission_enabled = true
	mat_volcanic.emission = Color(1.0, 0.30, 0.05)
	mat_volcanic.emission_energy_multiplier = 3.5

func _build_viewmodel() -> void:
	for c in get_children():
		c.queue_free()

	# 1. Arm & Fist
	arm_mesh = MeshInstance3D.new()
	arm_mesh.name = "ArmMesh"
	var arm_obj := load("res://assets/models/character/viewmodel_arm.obj") as Mesh
	if arm_obj:
		arm_mesh.mesh = arm_obj
		for i in arm_obj.get_surface_count():
			arm_mesh.set_surface_override_material(i, mat_skin)
	add_child(arm_mesh)

	# 2. Pickaxe
	pickaxe_mesh = MeshInstance3D.new()
	pickaxe_mesh.name = "PickaxeMesh"
	var pick_obj := load("res://assets/models/character/tool_pickaxe.obj") as Mesh
	if pick_obj:
		pickaxe_mesh.mesh = pick_obj
		_assign_tool_materials(pickaxe_mesh, pick_obj)
	add_child(pickaxe_mesh)

	# 3. Stone Axe
	axe_mesh = MeshInstance3D.new()
	axe_mesh.name = "AxeMesh"
	var axe_obj := load("res://assets/models/character/tool_axe.obj") as Mesh
	if axe_obj:
		axe_mesh.mesh = axe_obj
		_assign_tool_materials(axe_mesh, axe_obj)
	add_child(axe_mesh)

	# 3. Spear
	spear_mesh = MeshInstance3D.new()
	spear_mesh.name = "SpearMesh"
	spear_mesh.position = Vector3(-0.02, -0.05, 0.1)
	var spear_obj := load("res://assets/models/character/tool_spear.obj") as Mesh
	if spear_obj:
		spear_mesh.mesh = spear_obj
		_assign_tool_materials(spear_mesh, spear_obj)
	add_child(spear_mesh)

	# 4. Club & Modular Upgrade Attachments
	club_mesh = MeshInstance3D.new()
	club_mesh.name = "ClubMesh"
	club_mesh.position = Vector3(0.0, -0.02, 0.0)
	var club_obj := load("res://assets/models/character/tool_club.obj") as Mesh
	if club_obj:
		club_mesh.mesh = club_obj
		_assign_tool_materials(club_mesh, club_obj)
	add_child(club_mesh)

	club_t2_mesh = MeshInstance3D.new()
	club_t2_mesh.name = "ClubAttachmentsTier2"
	var t2_obj := load("res://assets/models/character/club_attachments_tier2.obj") as Mesh
	if t2_obj:
		club_t2_mesh.mesh = t2_obj
		_assign_tool_materials(club_t2_mesh, t2_obj)
	club_t2_mesh.visible = false
	club_mesh.add_child(club_t2_mesh)

	club_t3_mesh = MeshInstance3D.new()
	club_t3_mesh.name = "ClubAttachmentsTier3"
	var t3_obj := load("res://assets/models/character/club_attachments_tier3.obj") as Mesh
	if t3_obj:
		club_t3_mesh.mesh = t3_obj
		_assign_tool_materials(club_t3_mesh, t3_obj)
	club_t3_mesh.visible = false
	club_mesh.add_child(club_t3_mesh)

	club_t4_mesh = MeshInstance3D.new()
	club_t4_mesh.name = "ClubAttachmentsTier4"
	var t4_obj := load("res://assets/models/character/club_attachments_tier4.obj") as Mesh
	if t4_obj:
		club_t4_mesh.mesh = t4_obj
		_assign_tool_materials(club_t4_mesh, t4_obj)
	club_t4_mesh.visible = false
	club_mesh.add_child(club_t4_mesh)

	# 5. Torch
	torch_mesh = MeshInstance3D.new()
	torch_mesh.name = "TorchMesh"
	torch_mesh.position = Vector3(0.0, -0.02, 0.0)
	var torch_obj := load("res://assets/models/character/tool_torch.obj") as Mesh
	if torch_obj:
		torch_mesh.mesh = torch_obj
		_assign_tool_materials(torch_mesh, torch_obj)
	add_child(torch_mesh)

	# Torch Dynamic Light
	torch_light = OmniLight3D.new()
	torch_light.name = "TorchLight"
	torch_light.position = Vector3(0.0, 0.45, 0.0)
	torch_light.light_color = Color(1.0, 0.60, 0.18)
	torch_light.light_energy = 2.4
	torch_light.shadow_enabled = true
	torch_light.omni_range = 10.0
	torch_mesh.add_child(torch_light)

func _assign_tool_materials(m_inst: MeshInstance3D, m_obj: Mesh) -> void:
	for i in m_obj.get_surface_count():
		var s_name: String = m_obj.surface_get_name(i).to_lower()
		if "wood" in s_name:
			m_inst.set_surface_override_material(i, mat_wood)
		elif "stone" in s_name:
			m_inst.set_surface_override_material(i, mat_stone)
		elif "fire" in s_name:
			m_inst.set_surface_override_material(i, mat_fire)
		elif "volcanic" in s_name:
			m_inst.set_surface_override_material(i, mat_volcanic)
		elif "bone" in s_name:
			m_inst.set_surface_override_material(i, mat_bone)
		elif "obsidian" in s_name:
			m_inst.set_surface_override_material(i, mat_obsidian)
		else:
			m_inst.set_surface_override_material(i, mat_leather)

func apply_weapon_tier(weapon_id: String, tier: int) -> void:
	if weapon_id == "club":
		if club_t2_mesh:
			club_t2_mesh.visible = (tier == 2)
		if club_t3_mesh:
			club_t3_mesh.visible = (tier == 3)
		if club_t4_mesh:
			club_t4_mesh.visible = (tier == 4)
		if current_tool == ToolType.CLUB:
			_update_tool_stats()

func _on_weapon_upgraded(weapon_id: String, new_tier: int) -> void:
	apply_weapon_tier(weapon_id, new_tier)

# ---------------------------------------------------------------------------
# Weapon Switching
# ---------------------------------------------------------------------------
func set_tool(new_tool: ToolType) -> void:
	current_tool = new_tool
	_apply_tool_visibility()
	_update_tool_stats()
	active_tool_changed.emit(int(current_tool), get_current_tool_name())

func switch_tool(new_tool: ToolType, instant: bool = false) -> void:
	if new_tool == current_tool:
		return

	if is_aiming_spear:
		cancel_spear_aim()

	if instant:
		_is_swinging = false
		_is_switching = false
		_can_swing = true
		set_tool(new_tool)
		return

	if _is_switching or _is_swinging:
		return

	_is_switching = true
	_can_swing = false

	# Smooth lower weapon
	var t := create_tween()
	t.tween_property(self, "position", default_pos + Vector3(0.0, -0.28, 0.08), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		set_tool(new_tool)
	)
	# Smooth raise weapon
	t.tween_property(self, "position", default_pos, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		_is_switching = false
		_can_swing = true
	)

func cycle_tool(direction: int) -> void:
	var count := ToolType.size()
	var next := (int(current_tool) + direction) % count
	if next < 0:
		next += count
	switch_tool(next as ToolType)

func get_current_tool_name() -> String:
	return TOOL_NAMES.get(current_tool, "Weapon")

func _apply_tool_visibility() -> void:
	if pickaxe_mesh:
		pickaxe_mesh.visible = (current_tool == ToolType.PICKAXE)
	if axe_mesh:
		axe_mesh.visible = (current_tool == ToolType.AXE)
	if spear_mesh:
		spear_mesh.visible = (current_tool == ToolType.SPEAR)
	if club_mesh:
		club_mesh.visible = (current_tool == ToolType.CLUB)
	if torch_mesh:
		torch_mesh.visible = (current_tool == ToolType.TORCH)
	if torch_light:
		torch_light.visible = (current_tool == ToolType.TORCH)

func _update_tool_stats() -> void:
	match current_tool:
		ToolType.PICKAXE:
			reach = 2.4
			mining_power = 1.0
			melee_damage = 15.0
			swing_rate = 1.35
		ToolType.AXE:
			reach = 2.4
			mining_power = 1.0
			melee_damage = 22.0
			swing_rate = 1.25
		ToolType.SPEAR:
			reach = 3.6
			mining_power = 0.2
			melee_damage = 25.0
			swing_rate = 1.60
		ToolType.CLUB:
			reach = 2.2
			mining_power = 0.6
			var pm := get_node_or_null("/root/ProgressionManager")
			var tier: int = pm.get_weapon_tier("club") if pm else 1
			var t_data: Dictionary = pm.get_weapon_tier_data("club", tier) if pm else {}
			melee_damage = t_data.get("damage", 32.0)
			swing_rate = 1.05
		ToolType.TORCH:
			reach = 2.0
			mining_power = 0.0
			melee_damage = 10.0
			swing_rate = 1.40

# ---------------------------------------------------------------------------
# Customization Sync
# ---------------------------------------------------------------------------
func apply_customization(data: CharacterCustomizationData) -> void:
	if not data:
		return
	if mat_skin:
		mat_skin.albedo_color = data.skin_color
	if mat_leather:
		mat_leather.albedo_color = data.clothing_color

# ---------------------------------------------------------------------------
# Sway & Motion Processing
# ---------------------------------------------------------------------------
func add_sway(mouse_relative: Vector2) -> void:
	var target_x: float = clamp(-mouse_relative.x * sway_amount, -max_sway, max_sway)
	var target_y: float = clamp(mouse_relative.y * sway_amount, -max_sway, max_sway)
	_sway_offset.x = clamp(_sway_offset.x + target_x, -max_sway, max_sway)
	_sway_offset.y = clamp(_sway_offset.y + target_y, -max_sway, max_sway)

	_rotation_sway.y = clamp(_rotation_sway.y - mouse_relative.x * rotation_sway_amount * 0.05, -0.15, 0.15)
	_rotation_sway.x = clamp(_rotation_sway.x + mouse_relative.y * rotation_sway_amount * 0.05, -0.15, 0.15)

func trigger_land_dip(impact_velocity: float) -> void:
	_land_dip = clamp(impact_velocity * 0.005, 0.02, 0.06)

func process_viewmodel(delta: float, velocity: Vector3, is_on_floor: bool, is_sprinting: bool) -> void:
	# Flickering torch light
	if current_tool == ToolType.TORCH and torch_light and torch_light.visible:
		torch_light.light_energy = 2.2 + sin(Time.get_ticks_msec() * 0.015) * 0.35

	# Recovery from sway
	_sway_offset = _sway_offset.lerp(Vector3.ZERO, sway_smoothness * delta)
	_rotation_sway = _rotation_sway.lerp(Vector3.ZERO, sway_smoothness * delta)
	_land_dip = move_toward(_land_dip, 0.0, delta * 0.2)

	if _is_swinging or _is_switching:
		return

	# Overhand spear aim stance processing
	if is_aiming_spear:
		var aim_pos := default_pos + Vector3(-0.05, 0.08, 0.16) + _sway_offset * 0.35
		var aim_rot := default_rot + Vector3(-0.42, 0.12, -0.20) + _rotation_sway * 0.35
		aim_pos.y += sin(Time.get_ticks_msec() * 0.012) * 0.0015
		transform.origin = transform.origin.lerp(aim_pos, delta * 16.0)
		rotation.x = lerp_angle(rotation.x, aim_rot.x, delta * 16.0)
		rotation.y = lerp_angle(rotation.y, aim_rot.y, delta * 16.0)
		rotation.z = lerp_angle(rotation.z, aim_rot.z, delta * 16.0)
		return

	# Locomotion bobbing
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	var bob_pos := Vector3.ZERO
	var bob_rot := Vector3.ZERO

	if is_on_floor and horiz_speed > 0.2:
		var freq := 14.0 if is_sprinting else 9.0
		var amp_y := 0.016 if is_sprinting else 0.008
		var amp_x := 0.012 if is_sprinting else 0.006
		_bob_timer += delta * freq
		bob_pos.y = sin(_bob_timer) * amp_y
		bob_pos.x = cos(_bob_timer * 0.5) * amp_x
		bob_rot.z = cos(_bob_timer * 0.5) * 0.03
	else:
		# Idle breathing bob
		_bob_timer += delta * 2.0
		bob_pos.y = sin(_bob_timer) * 0.003
		bob_pos.x = cos(_bob_timer * 0.5) * 0.002

	if not is_on_floor:
		bob_pos.y -= 0.025

	bob_pos.y -= _land_dip

	# Apply target transform smoothly
	var target_pos := default_pos + _sway_offset + bob_pos
	var target_rot := default_rot + _rotation_sway + bob_rot

	transform.origin = transform.origin.lerp(target_pos, delta * 14.0)
	rotation.x = lerp_angle(rotation.x, target_rot.x, delta * 14.0)
	rotation.y = lerp_angle(rotation.y, target_rot.y, delta * 14.0)
	rotation.z = lerp_angle(rotation.z, target_rot.z, delta * 14.0)

# ---------------------------------------------------------------------------
# Kinetic Mining & Combat Attacks
# ---------------------------------------------------------------------------
func try_swing() -> bool:
	if not _can_swing or _is_swinging or _is_switching or is_aiming_spear:
		return false

	match current_tool:
		ToolType.PICKAXE:
			_start_pickaxe_chop()
		ToolType.AXE:
			_start_axe_swing()
		ToolType.SPEAR:
			_start_spear_thrust()
		ToolType.CLUB:
			_start_club_slam()
		ToolType.TORCH:
			_start_torch_jab()

	return true

func _start_pickaxe_chop() -> void:
	_can_swing = false
	_is_swinging = true
	swing_started.emit()

	var t := create_tween().set_parallel(false)
	# Wind-up
	t.parallel().tween_property(self, "position", default_pos + Vector3(-0.04, 0.06, 0.05), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation", default_rot + Vector3(-0.35, 0.22, -0.15), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Kinetic chop
	t.chain().parallel().tween_property(self, "position", default_pos + Vector3(-0.06, -0.10, -0.14), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "rotation", default_rot + Vector3(0.75, -0.28, 0.25), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	t.tween_callback(_check_hit)

	# Recovery
	t.chain().parallel().tween_property(self, "position", default_pos, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation", default_rot, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	t.tween_callback(func(): _is_swinging = false)
	get_tree().create_timer(1.0 / swing_rate).timeout.connect(func(): _can_swing = true)

func _start_axe_swing() -> void:
	_can_swing = false
	_is_swinging = true
	swing_started.emit()

	var t := create_tween().set_parallel(false)
	# Wind-up: pull axe up and back right
	t.parallel().tween_property(self, "position", default_pos + Vector3(0.06, 0.08, 0.04), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation", default_rot + Vector3(-0.40, 0.35, -0.20), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Powerful diagonal chopping cleave
	t.chain().parallel().tween_property(self, "position", default_pos + Vector3(-0.12, -0.12, -0.16), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "rotation", default_rot + Vector3(0.85, -0.45, 0.35), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	t.tween_callback(_check_hit)

	# Smooth follow-through recovery
	t.chain().parallel().tween_property(self, "position", default_pos, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation", default_rot, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	t.tween_callback(func(): _is_swinging = false)
	get_tree().create_timer(1.0 / swing_rate).timeout.connect(func(): _can_swing = true)

func _start_spear_thrust() -> void:
	_can_swing = false
	_is_swinging = true
	swing_started.emit()

	var t := create_tween().set_parallel(false)
	# Pull back slightly (0.05s)
	t.parallel().tween_property(self, "position", default_pos + Vector3(0.02, 0.02, 0.14), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation", default_rot + Vector3(-0.05, 0.04, 0.02), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Explosive forward thrust along Z (0.08s)
	t.chain().parallel().tween_property(self, "position", default_pos + Vector3(-0.03, 0.01, -0.36), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "rotation", default_rot + Vector3(0.04, -0.02, -0.06), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	t.tween_callback(_check_hit)

	# Recoil back to ready stance (0.16s)
	t.chain().parallel().tween_property(self, "position", default_pos, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation", default_rot, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	t.tween_callback(func(): _is_swinging = false)
	get_tree().create_timer(1.0 / swing_rate).timeout.connect(func(): _can_swing = true)

# ---------------------------------------------------------------------------
# Ballistic Spear Throwing
# ---------------------------------------------------------------------------
func start_spear_aim() -> bool:
	if current_tool != ToolType.SPEAR or _is_swinging or _is_switching or is_aiming_spear:
		return false
	is_aiming_spear = true
	_can_swing = false
	spear_aim_started.emit()
	return true

func cancel_spear_aim() -> void:
	if not is_aiming_spear:
		return
	is_aiming_spear = false
	_can_swing = true
	spear_aim_ended.emit()

func throw_spear(on_launch_callback: Callable = Callable()) -> bool:
	if not is_aiming_spear or _is_swinging:
		return false
	is_aiming_spear = false
	_is_swinging = true
	_can_swing = false
	spear_aim_ended.emit()

	var t := create_tween().set_parallel(false)
	# Fast explosive overhand spear throw forward & down
	t.parallel().tween_property(self, "position", default_pos + Vector3(0.04, -0.06, -0.42), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "rotation", default_rot + Vector3(0.35, -0.10, 0.15), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	t.tween_callback(func():
		if on_launch_callback.is_valid():
			on_launch_callback.call()
		spear_thrown.emit()
		if spear_mesh:
			spear_mesh.visible = false
	)

	# Recovery: pull arm back down
	t.chain().parallel().tween_property(self, "position", default_pos + Vector3(0.0, -0.22, 0.08), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "rotation", default_rot + Vector3(0.1, 0, 0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Re-arm spear mesh
	t.tween_callback(func():
		if spear_mesh and current_tool == ToolType.SPEAR:
			spear_mesh.visible = true
	)
	t.chain().parallel().tween_property(self, "position", default_pos, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation", default_rot, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	t.tween_callback(func():
		_is_swinging = false
		_can_swing = true
	)
	return true

func _start_club_slam() -> void:
	_can_swing = false
	_is_swinging = true
	swing_started.emit()

	var t := create_tween().set_parallel(false)
	# Heavy wind-up right and back (0.10s)
	t.parallel().tween_property(self, "position", default_pos + Vector3(0.08, 0.08, 0.08), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation", default_rot + Vector3(-0.25, -0.45, 0.30), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Sweeping horizontal slam (0.11s)
	t.chain().parallel().tween_property(self, "position", default_pos + Vector3(-0.15, -0.04, -0.16), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "rotation", default_rot + Vector3(0.35, 0.65, -0.45), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	t.tween_callback(_check_hit)

	# Slower heavy recovery (0.24s)
	t.chain().parallel().tween_property(self, "position", default_pos, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation", default_rot, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	t.tween_callback(func(): _is_swinging = false)
	get_tree().create_timer(1.0 / swing_rate).timeout.connect(func(): _can_swing = true)

func _start_torch_jab() -> void:
	_can_swing = false
	_is_swinging = true
	swing_started.emit()

	var t := create_tween().set_parallel(false)
	# Quick jab forward with flame flare (0.07s)
	t.parallel().tween_property(self, "position", default_pos + Vector3(-0.02, 0.02, -0.25), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation", default_rot + Vector3(0.12, -0.08, 0.10), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	t.tween_callback(_check_hit)

	# Recovery (0.15s)
	t.chain().parallel().tween_property(self, "position", default_pos, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "rotation", default_rot, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	t.tween_callback(func(): _is_swinging = false)
	get_tree().create_timer(1.0 / swing_rate).timeout.connect(func(): _can_swing = true)

func _check_hit() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return

	var origin := cam.global_position
	var forward := -cam.global_transform.basis.z
	var end := origin + forward * reach
	var space := get_world_3d().direct_space_state

	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 0b1111 # Layers 1 (World), 2 (Player), 3 (Creature), 4 (Physics Props)

	var result := space.intersect_ray(query)
	if result.is_empty():
		return

	var collider: Node = result.get("collider")
	var hit_pos: Vector3 = result.get("position", end)
	var hit_norm: Vector3 = result.get("normal", Vector3.UP)

	# Check for RigidBody3D / Physics Props (e.g. Jolt Physics Rats)
	var rb: RigidBody3D = collider as RigidBody3D
	if not rb and collider:
		rb = _find_ancestor_rigidbody(collider)
	if rb:
		var hit_dir := (hit_pos - origin).normalized()
		var force := melee_damage * 0.4
		var pm := get_node_or_null("/root/ProgressionManager")
		var imp_mult: float = 1.0
		if pm and current_tool == ToolType.CLUB:
			var tier: int = pm.get_weapon_tier("club")
			imp_mult = pm.get_weapon_tier_data("club", tier).get("impulse", 1.0)
		if current_tool == ToolType.CLUB:
			force *= 1.8 * imp_mult
		elif current_tool == ToolType.SPEAR:
			force *= 1.3
		var impulse := hit_dir * force + Vector3.UP * (force * 0.35)
		rb.apply_central_impulse(impulse)
		var torque := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * (force * 0.5)
		rb.apply_torque_impulse(torque)
		if rb.has_method("on_tool_hit"):
			rb.on_tool_hit(current_tool, hit_dir, force)
		hit_deposit.emit(rb)
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.play_sfx(am.SFX.PICKAXE_HIT)
		return

	# Check for SpearTarget / Practice dummies
	var target := _find_ancestor_script(collider, "SpearTarget")
	if not target and collider and (collider.is_in_group("targets") or collider.has_method("on_hit") and not collider.has_method("take_damage")):
		if not collider is MineableDeposit and not collider is ChoppableTree:
			target = collider
	if target and target.has_method("on_hit"):
		target.on_hit(melee_damage, current_tool == ToolType.AXE)
		hit_deposit.emit(target)
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.play_sfx(am.SFX.AXE_HIT_WOOD)
		return

	# Check for ChoppableTree
	var tree := _find_ancestor_script(collider, "ChoppableTree")
	if not tree and (collider is ChoppableTree or (collider.has_method("on_hit") and collider.has_signal("tree_chopped"))):
		tree = collider
	if tree:
		if current_tool == ToolType.TORCH and tree.has_method("on_torch_hit"):
			tree.on_torch_hit()
		elif tree.has_method("on_hit"):
			tree.on_hit(mining_power, current_tool == ToolType.AXE)
		hit_deposit.emit(tree)
		return

	# Check for MineableDeposit
	var deposit := _find_ancestor_script(collider, "MineableDeposit")
	if deposit and deposit.has_method("on_hit"):
		deposit.on_hit(mining_power)
		hit_deposit.emit(deposit)
		AudioManager.play_sfx(AudioManager.SFX.PICKAXE_HIT_ORE)
		return

	# Check for Creature
	var c_health := _find_ancestor_script(collider, "CreatureHealth")
	if c_health and c_health.has_method("take_damage"):
		var kd := forward
		kd.y = 0.25
		var impulse_force := 10.0 if current_tool == ToolType.CLUB else (7.0 if current_tool == ToolType.SPEAR else 5.0)
		c_health.take_damage.rpc_id(1, melee_damage, kd.normalized(), impulse_force)
		hit_creature.emit(c_health, kd)
		AudioManager.play_sfx(AudioManager.SFX.PICKAXE_HIT)
		return

	# World hit (stone walls, cave floors)
	hit_world.emit(hit_pos, hit_norm)
	AudioManager.play_sfx(AudioManager.SFX.PICKAXE_HIT)

func _find_ancestor_rigidbody(node: Node) -> RigidBody3D:
	var cur := node
	var limit := 8
	while cur and limit > 0:
		limit -= 1
		if cur is RigidBody3D:
			return cur as RigidBody3D
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
