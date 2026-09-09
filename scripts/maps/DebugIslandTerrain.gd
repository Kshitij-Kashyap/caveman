## DebugIslandTerrain.gd
## Procedural island terrain generator designed for the Debug Island sandbox.
## Produces a low-poly island surrounded by ocean, with dedicated level pads
## for the central hub, arsenal range, combat colosseum, physics ramp, and parkour course.

class_name DebugIslandTerrain
extends StaticBody3D

@export var island_size: Vector2 = Vector2(130.0, 130.0)
@export var subdivisions: int = 64
@export var plateau_height: float = 1.0
@export var beach_radius: float = 42.0
@export var water_radius: float = 55.0

var _mesh_instance: MeshInstance3D = null
var _col_shape: CollisionShape3D = null

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0

	_mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not _mesh_instance:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "MeshInstance3D"
		add_child(_mesh_instance)

	_col_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not _col_shape:
		_col_shape = CollisionShape3D.new()
		_col_shape.name = "CollisionShape3D"
		add_child(_col_shape)

	generate_island()

func generate_island() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 1337
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.04
	noise.fractal_octaves = 2

	var nx := subdivisions + 1
	var nz := subdivisions + 1
	var step_x := island_size.x / float(subdivisions)
	var step_z := island_size.y / float(subdivisions)
	var half_x := island_size.x * 0.5
	var half_z := island_size.y * 0.5

	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	var col_grass := Color(0.32, 0.68, 0.28)
	var col_sand := Color(0.85, 0.78, 0.55)
	var col_rock := Color(0.42, 0.38, 0.32)
	var col_path := Color(0.48, 0.40, 0.28)

	for iz in range(nz):
		var z := -half_z + float(iz) * step_z
		for ix in range(nx):
			var x := -half_x + float(ix) * step_x
			var dist := Vector2(x, z).length()

			var h := plateau_height

			# 1. Island Falloff to ocean
			if dist > beach_radius:
				var drop_factor := clampf((dist - beach_radius) / (water_radius - beach_radius), 0.0, 1.0)
				h = lerpf(plateau_height, -3.5, drop_factor)
			else:
				# Gentle interior rolling terrain variations
				h += noise.get_noise_2d(x, z) * 0.45

			# 2. Cliff Observatory in North-West (x: -32 to -18, z: -32 to -18)
			var cliff_dist := Vector2(x + 26.0, z + 26.0).length()
			if cliff_dist < 10.0:
				var c_factor := 1.0 - smoothstep(4.0, 10.0, cliff_dist)
				h += c_factor * 5.2

			# 3. Physics Launch Ramp in South (x: -8 to 8, z: 18 to 36)
			if absf(x) < 8.0 and z > 16.0 and z < 36.0:
				var ramp_t := clampf((z - 16.0) / 18.0, 0.0, 1.0)
				h += ramp_t * 4.5

			# 4. Sunken Combat Colosseum in East (x: 24 to 40, z: -8 to 8)
			var arena_dist := Vector2(x - 32.0, z).length()
			if arena_dist < 9.0:
				var a_factor := 1.0 - smoothstep(6.0, 9.0, arena_dist)
				h -= a_factor * 1.2 # slightly sunken arena floor

			# Level central plaza
			if dist < 12.0:
				h = plateau_height

			var vert := Vector3(x, h, z)
			verts.append(vert)
			uvs.append(Vector2(float(ix) / float(subdivisions) * 12.0, float(iz) / float(subdivisions) * 12.0))

			# Colors
			var vcol: Color
			if h < 0.2:
				vcol = col_sand
			elif dist < 10.0 or absf(x) < 2.0 or absf(z) < 2.0:
				vcol = col_path
			elif h > 3.0:
				vcol = col_rock
			else:
				vcol = col_grass.lerp(col_sand, clampf((1.0 - h) * 0.5, 0.0, 0.5))
			colors.append(vcol)

	# Build Triangles (CCW upward facing)
	for iz in range(subdivisions):
		for ix in range(subdivisions):
			var i0 := iz * nx + ix
			var i1 := i0 + 1
			var i2 := (iz + 1) * nx + ix
			var i3 := i2 + 1

			indices.append(i0)
			indices.append(i1)
			indices.append(i2)

			indices.append(i1)
			indices.append(i3)
			indices.append(i2)

	# Normals
	normals.resize(verts.size())
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO

	for t in range(0, indices.size(), 3):
		var ia := indices[t]
		var ib := indices[t + 1]
		var ic := indices[t + 2]
		var va := verts[ia]
		var vb := verts[ib]
		var vc := verts[ic]
		var fn := (vb - va).cross(vc - va).normalized()
		normals[ia] += fn
		normals[ib] += fn
		normals[ic] += fn

	for i in range(normals.size()):
		normals[i] = normals[i].normalized()

	# Create ArrayMesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)

	_mesh_instance.mesh = mesh

	# Continuous Jolt Physics Collision Shape
	var c_shape := ConcavePolygonShape3D.new()
	var col_faces := PackedVector3Array()
	col_faces.resize(indices.size())
	for i in range(indices.size()):
		col_faces[i] = verts[indices[i]]
	c_shape.set_faces(col_faces)
	c_shape.backface_collision = true
	_col_shape.shape = c_shape

	_create_bedrock_foundation()

func _create_bedrock_foundation() -> void:
	var existing := get_node_or_null("BedrockFoundation")
	if existing:
		return
	var bedrock := CollisionShape3D.new()
	bedrock.name = "BedrockFoundation"
	var box := BoxShape3D.new()
	box.size = Vector3(island_size.x + 20.0, 2.0, island_size.y + 20.0)
	bedrock.shape = box
	bedrock.position = Vector3(0, -4.5, 0)
	add_child(bedrock)
