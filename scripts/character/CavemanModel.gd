## CavemanModel.gd
## Stylized low-poly 3D character matching the "How to Fish" / TABS aesthetic:
## Elongated bean/peanut head, giant bulging faceted eyes with derpy pupils,
## chunky faceted pelt overalls, and comedic waddle animation.
## Fully color-customizable via CharacterCustomizationData.

class_name CavemanModel
extends Node3D

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------
@export var customization: CharacterCustomizationData = null:
	set(value):
		customization = value
		if is_inside_tree() and customization:
			apply_customization(customization)

@export var use_unified_mesh: bool = false

# Materials
var mat_skin: StandardMaterial3D
var mat_hair: StandardMaterial3D
var mat_clothing: StandardMaterial3D
var mat_accent: StandardMaterial3D
var mat_eyes_white: StandardMaterial3D
var mat_eyes_pupil: StandardMaterial3D

# Node references for animation and ragdoll synchronization
var root_pivot: Node3D
var torso: MeshInstance3D
var head_pivot: Node3D
var head: MeshInstance3D

var arm_left_pivot: Node3D
var arm_left_upper: MeshInstance3D
var arm_right_pivot: Node3D
var arm_right_upper: MeshInstance3D

var leg_left_pivot: Node3D
var leg_left_upper: MeshInstance3D
var leg_right_pivot: Node3D
var leg_right_upper: MeshInstance3D

# Animation state
var is_moving: bool = false
var walk_speed_factor: float = 10.0
var _anim_time: float = 0.0
var enable_idle_bob: bool = true

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _init() -> void:
	_init_materials()

func _ready() -> void:
	if not mat_skin:
		_init_materials()
	_build_character_mesh()
	if customization:
		apply_customization(customization)
	else:
		apply_customization(CharacterCustomizationData.get_default())

func _init_materials() -> void:
	if mat_skin:
		return

	# Skin: flat diffuse shading for crisp faceted look
	mat_skin = StandardMaterial3D.new()
	mat_skin.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_skin.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_skin.roughness = 0.85

	# Hair & Beard
	mat_hair = StandardMaterial3D.new()
	mat_hair.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_hair.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_hair.roughness = 0.95

	# Clothing / Pelt Overalls
	mat_clothing = StandardMaterial3D.new()
	mat_clothing.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_clothing.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_clothing.roughness = 0.90

	# Bone & Accents
	mat_accent = StandardMaterial3D.new()
	mat_accent.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_accent.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_accent.roughness = 0.60

	# Big Bulging White Eyeballs (Glossy)
	mat_eyes_white = StandardMaterial3D.new()
	mat_eyes_white.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_eyes_white.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_eyes_white.albedo_color = Color(0.96, 0.96, 0.94)
	mat_eyes_white.roughness = 0.25

	# Derpy Black Pupils
	mat_eyes_pupil = StandardMaterial3D.new()
	mat_eyes_pupil.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat_eyes_pupil.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat_eyes_pupil.albedo_color = Color(0.06, 0.06, 0.06)
	mat_eyes_pupil.roughness = 0.20

# ---------------------------------------------------------------------------
# Mesh Construction (Faceted Low-Poly Meshes)
# ---------------------------------------------------------------------------
func _build_character_mesh() -> void:
	for child in get_children():
		child.queue_free()

	root_pivot = Node3D.new()
	root_pivot.name = "RootPivot"
	add_child(root_pivot)

	if use_unified_mesh:
		_build_unified_mesh()
		return

	# Load modular meshes
	var mesh_torso := load("res://assets/models/character/part_torso.obj") as Mesh
	var mesh_head  := load("res://assets/models/character/part_head.obj") as Mesh
	var mesh_arm_l := load("res://assets/models/character/part_arm_l.obj") as Mesh
	var mesh_arm_r := load("res://assets/models/character/part_arm_r.obj") as Mesh
	var mesh_leg_l := load("res://assets/models/character/part_leg_l.obj") as Mesh
	var mesh_leg_r := load("res://assets/models/character/part_leg_r.obj") as Mesh

	# 1. TORSO (Pivoted at hips/waist center: Y=0.70)
	torso = MeshInstance3D.new()
	torso.name = "Torso"
	torso.mesh = mesh_torso
	torso.position = Vector3(0.0, 0.70, 0.0)
	_apply_materials_to_instance(torso)
	root_pivot.add_child(torso)

	# 2. HEAD (Elongated peanut head with bulging eyes, neck base at Y=1.02)
	head_pivot = Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0.0, 1.02, 0.0)
	root_pivot.add_child(head_pivot)

	head = MeshInstance3D.new()
	head.name = "HeadMesh"
	head.mesh = mesh_head
	_apply_materials_to_instance(head)
	head_pivot.add_child(head)

	# 3. LEFT ARM (Pivot at left shoulder: X=-0.44, Y=0.98)
	arm_left_pivot = Node3D.new()
	arm_left_pivot.name = "ArmLeftPivot"
	arm_left_pivot.position = Vector3(-0.44, 0.98, 0.0)
	root_pivot.add_child(arm_left_pivot)

	arm_left_upper = MeshInstance3D.new()
	arm_left_upper.name = "ArmLeftMesh"
	arm_left_upper.mesh = mesh_arm_l
	_apply_materials_to_instance(arm_left_upper)
	arm_left_pivot.add_child(arm_left_upper)

	# 4. RIGHT ARM (Pivot at right shoulder: X=0.44, Y=0.98)
	arm_right_pivot = Node3D.new()
	arm_right_pivot.name = "ArmRightPivot"
	arm_right_pivot.position = Vector3(0.44, 0.98, 0.0)
	root_pivot.add_child(arm_right_pivot)

	arm_right_upper = MeshInstance3D.new()
	arm_right_upper.name = "ArmRightMesh"
	arm_right_upper.mesh = mesh_arm_r
	_apply_materials_to_instance(arm_right_upper)
	arm_right_pivot.add_child(arm_right_upper)

	# 5. LEFT LEG (Pivot at left hip: X=-0.20, Y=0.38)
	leg_left_pivot = Node3D.new()
	leg_left_pivot.name = "LegLeftPivot"
	leg_left_pivot.position = Vector3(-0.20, 0.38, 0.0)
	root_pivot.add_child(leg_left_pivot)

	leg_left_upper = MeshInstance3D.new()
	leg_left_upper.name = "LegLeftMesh"
	leg_left_upper.mesh = mesh_leg_l
	_apply_materials_to_instance(leg_left_upper)
	leg_left_pivot.add_child(leg_left_upper)

	# 6. RIGHT LEG (Pivot at right hip: X=0.20, Y=0.38)
	leg_right_pivot = Node3D.new()
	leg_right_pivot.name = "LegRightPivot"
	leg_right_pivot.position = Vector3(0.20, 0.38, 0.0)
	root_pivot.add_child(leg_right_pivot)

	leg_right_upper = MeshInstance3D.new()
	leg_right_upper.name = "LegRightMesh"
	leg_right_upper.mesh = mesh_leg_r
	_apply_materials_to_instance(leg_right_upper)
	leg_right_pivot.add_child(leg_right_upper)

func _build_unified_mesh() -> void:
	torso = MeshInstance3D.new()
	torso.name = "UnifiedModel"
	torso.mesh = load("res://assets/models/character/caveman.obj") as Mesh
	_apply_materials_to_instance(torso)
	root_pivot.add_child(torso)
	head = torso

func _apply_materials_to_instance(mesh_inst: MeshInstance3D) -> void:
	if not mesh_inst or not mesh_inst.mesh:
		return
	var m := mesh_inst.mesh
	for i in m.get_surface_count():
		var s_name: String = m.surface_get_name(i).to_lower()
		var mat: Material = m.surface_get_material(i)
		var m_name: String = mat.resource_name.to_lower() if mat else ""
		var target_name: String = m_name if not m_name.is_empty() else s_name

		if "skin" in target_name:
			mesh_inst.set_surface_override_material(i, mat_skin)
		elif "clothing" in target_name:
			mesh_inst.set_surface_override_material(i, mat_clothing)
		elif "hair" in target_name:
			mesh_inst.set_surface_override_material(i, mat_hair)
		elif "accent" in target_name:
			mesh_inst.set_surface_override_material(i, mat_accent)
		elif "eyes_white" in target_name:
			mesh_inst.set_surface_override_material(i, mat_eyes_white)
		elif "eyes_pupil" in target_name:
			mesh_inst.set_surface_override_material(i, mat_eyes_pupil)

# ---------------------------------------------------------------------------
# Customization Application
# ---------------------------------------------------------------------------
func apply_customization(data: CharacterCustomizationData) -> void:
	if not data:
		return
	if mat_skin:
		mat_skin.albedo_color = data.skin_color
	if mat_hair:
		mat_hair.albedo_color = data.hair_color
	if mat_clothing:
		mat_clothing.albedo_color = data.clothing_color
	if mat_accent:
		mat_accent.albedo_color = data.accent_color

func set_first_person_visibility(is_first_person: bool) -> void:
	if head:
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if is_first_person else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

# ---------------------------------------------------------------------------
# Procedural Animation ("How to Fish" Comedic Waddle & Idle Bob)
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not enable_idle_bob or not root_pivot:
		return

	_anim_time += delta

	if is_moving:
		var walk_cycle: float = _anim_time * walk_speed_factor

		# Comical torso bob and waddle roll
		if torso:
			torso.position.y = 0.70 + abs(sin(walk_cycle)) * 0.08
			torso.rotation.z = sin(walk_cycle) * 0.10
			torso.rotation.y = sin(walk_cycle) * 0.08

		# Head derpy counter-wobble (that iconic rubbery neck look!)
		if head_pivot:
			head_pivot.position.y = 1.02 + abs(sin(walk_cycle)) * 0.08
			head_pivot.rotation.z = -sin(walk_cycle) * 0.14
			head_pivot.rotation.x = sin(walk_cycle * 2.0) * 0.06

		# Exaggerated arm swing
		if arm_left_pivot:
			arm_left_pivot.rotation.x = sin(walk_cycle) * 0.75
			arm_left_pivot.rotation.z = 0.15 + sin(walk_cycle) * 0.10
		if arm_right_pivot:
			arm_right_pivot.rotation.x = -sin(walk_cycle) * 0.75
			arm_right_pivot.rotation.z = -0.15 - sin(walk_cycle) * 0.10

		# Exaggerated leg swing
		if leg_left_pivot:
			leg_left_pivot.rotation.x = -sin(walk_cycle) * 0.70
		if leg_right_pivot:
			leg_right_pivot.rotation.x = sin(walk_cycle) * 0.70
	else:
		# Idle goofy breathing
		var breath: float = sin(_anim_time * 2.2)
		if torso:
			torso.position.y = 0.70 + breath * 0.015
			torso.rotation.z = lerp_angle(torso.rotation.z, 0.0, delta * 8.0)
			torso.rotation.y = lerp_angle(torso.rotation.y, 0.0, delta * 8.0)

		# Slight head idle look
		if head_pivot:
			head_pivot.position.y = 1.02 + breath * 0.015
			head_pivot.rotation.y = sin(_anim_time * 0.7) * 0.08
			head_pivot.rotation.x = sin(_anim_time * 1.4) * 0.04
			head_pivot.rotation.z = lerp_angle(head_pivot.rotation.z, 0.0, delta * 8.0)

		# Relaxed hanging arms
		if arm_left_pivot:
			arm_left_pivot.rotation.x = lerp_angle(arm_left_pivot.rotation.x, breath * 0.03, delta * 5.0)
			arm_left_pivot.rotation.z = lerp_angle(arm_left_pivot.rotation.z, 0.12, delta * 5.0)
		if arm_right_pivot:
			arm_right_pivot.rotation.x = lerp_angle(arm_right_pivot.rotation.x, -breath * 0.03, delta * 5.0)
			arm_right_pivot.rotation.z = lerp_angle(arm_right_pivot.rotation.z, -0.12, delta * 5.0)

		# Reset legs
		if leg_left_pivot:
			leg_left_pivot.rotation.x = lerp_angle(leg_left_pivot.rotation.x, 0.0, delta * 8.0)
		if leg_right_pivot:
			leg_right_pivot.rotation.x = lerp_angle(leg_right_pivot.rotation.x, 0.0, delta * 8.0)
