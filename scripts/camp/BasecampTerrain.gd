## BasecampTerrain.gd
## Procedural uneven terrain generator for TribeCamp and testing grounds.
## Generates a subdivided low-poly undulating terrain mesh (ArrayMesh) with
## matching Jolt physics ConcavePolygonShape3D collisions.
## Features:
## - Perfectly flat central plaza (stations, huts, campfire remain grounded)
## - Smooth Hermite transition zone
## - Natural undulating rolling mounds (-0.8m to +2.4m) in perimeter
## - Dedicated elevated training berm & target range in the North-East sector
## - Prehistoric vertex colors (lush grass, trodden camp soil, rocky knolls)

class_name BasecampTerrain
extends StaticBody3D

@export var terrain_size: Vector2 = Vector2(96.0, 96.0)
@export var subdivisions: int = 48
@export var flat_radius: float = 16.0
@export var blend_radius: float = 24.0
@export var max_height: float = 2.4
@export var enable_target_range: bool = true

@export var mat_grass: StandardMaterial3D = null

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

	generate_terrain()

func generate_terrain() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 42
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.45

	var nx := subdivisions + 1
	var nz := subdivisions + 1
	var step_x := terrain_size.x / float(subdivisions)
	var step_z := terrain_size.y / float(subdivisions)
	var half_x := terrain_size.x * 0.5
	var half_z := terrain_size.y * 0.5

	# 1. Compute Heights & Vertex Colors
	var heights: Array = []
	heights.resize(nx * nz)

	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	var col_grass := Color(0.34, 0.66, 0.26)
	var col_soil := Color(0.44, 0.40, 0.30)
	var col_rock := Color(0.38, 0.32, 0.24)

	for iz in range(nz):
		var z := -half_z + float(iz) * step_z
		for ix in range(nx):
			var x := -half_x + float(ix) * step_x
			var dist := Vector2(x, z).length()

			# Masking: flat inside flat_radius, smooth blend out to blend_radius
			var mask: float = smoothstep(flat_radius, blend_radius, dist)

			var n_val := noise.get_noise_2d(x, z)
			var h := n_val * max_height * mask

			# Testing Range: elevated target berm in North-East sector (x: 14 to 34, z: -10 to -34)
			if enable_target_range and x > 12.0 and z < -8.0:
				var tr_mask := smoothstep(12.0, 18.0, x) * smoothstep(-8.0, -14.0, z)
				var tr_edge := (1.0 - smoothstep(28.0, 36.0, x)) * (1.0 - smoothstep(-34.0, -42.0, z))
				var berm := sin(clampf((x - 12.0) / 16.0, 0.0, 1.0) * PI) * 1.6
				h += berm * tr_mask * tr_edge

			heights[iz * nx + ix] = h

			var vert := Vector3(x, h, z)
			verts.append(vert)
			uvs.append(Vector2(float(ix) / float(subdivisions) * 8.0, float(iz) / float(subdivisions) * 8.0))

			# Color blending based on mask and slope/elevation
			var vert_col: Color
			if mask < 0.2:
				vert_col = col_soil
			elif h > 1.2:
				vert_col = col_grass.lerp(col_rock, clampf((h - 1.2) * 0.8, 0.0, 1.0))
			elif h < -0.3:
				vert_col = col_grass.lerp(col_soil, 0.45)
			else:
				vert_col = col_grass.lerp(col_soil, (1.0 - mask) * 0.6)
			colors.append(vert_col)

	# 2. Compute Triangles / Indices
	for iz in range(subdivisions):
		for ix in range(subdivisions):
			var i0 := iz * nx + ix
			var i1 := i0 + 1
			var i2 := (iz + 1) * nx + ix
			var i3 := i2 + 1

			# Triangle 1 (CCW facing UP)
			indices.append(i0)
			indices.append(i1)
			indices.append(i2)

			# Triangle 2 (CCW facing UP)
			indices.append(i1)
			indices.append(i3)
			indices.append(i2)

	# 3. Compute Smooth Vertex Normals (Upward-pointing)
	normals.resize(verts.size())
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO

	for t in range(0, indices.size(), 3):
		var i_a := indices[t]
		var i_b := indices[t + 1]
		var i_c := indices[t + 2]

		var va := verts[i_a]
		var vb := verts[i_b]
		var vc := verts[i_c]

		var fn := (vc - va).cross(vb - va).normalized()
		normals[i_a] += fn
		normals[i_b] += fn
		normals[i_c] += fn

	for i in range(normals.size()):
		normals[i] = normals[i].normalized()

	# 4. Construct ArrayMesh
	var surface_array := []
	surface_array.resize(Mesh.ARRAY_MAX)
	surface_array[Mesh.ARRAY_VERTEX] = verts
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_COLOR] = colors
	surface_array[Mesh.ARRAY_INDEX] = indices

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)

	# Apply Material
	if not mat_grass:
		mat_grass = StandardMaterial3D.new()
		mat_grass.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat_grass.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
		mat_grass.vertex_color_use_as_albedo = true
		mat_grass.roughness = 0.88
		mat_grass.metallic_specular = 0.15

	_mesh_instance.transform = Transform3D.IDENTITY
	_mesh_instance.mesh = array_mesh
	_mesh_instance.set_surface_override_material(0, mat_grass)

	# 5. Build Jolt Collision Shape with backface collision enabled
	_col_shape.transform = Transform3D.IDENTITY
	var shape := array_mesh.create_trimesh_shape()
	if shape is ConcavePolygonShape3D:
		shape.backface_collision = true
	if shape and _col_shape:
		_col_shape.shape = shape

	# 6. Safety Foundation Floor (prevents any tunneling/falling into the void)
	var foundation := get_node_or_null("FoundationCollisionShape3D") as CollisionShape3D
	if not foundation:
		foundation = CollisionShape3D.new()
		foundation.name = "FoundationCollisionShape3D"
		var box := BoxShape3D.new()
		box.size = Vector3(terrain_size.x + 40.0, 4.0, terrain_size.y + 40.0)
		foundation.shape = box
		foundation.position = Vector3(0.0, -3.2, 0.0) # top at y = -1.2, safely below dips
		add_child(foundation)
