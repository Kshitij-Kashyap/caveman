## DungeonMeshBuilder.gd
## Converts DungeonData into visible 3D geometry (floors + ceilings) and StaticBody3D collision.
## Also inserts a single NavigationRegion3D covering all floor tiles.
## Prototype uses simple BoxMesh geometry — replace with authored meshes later.

class_name DungeonMeshBuilder
extends Node

const FLOOR_Y := 0.0
const FLOOR_H := 0.4
const CEIL_H  := 4.0   ## Room height
const WALL_T  := 0.5   ## Wall thickness

## Materials (created programmatically — replace with authored materials later)
var mat_floor: StandardMaterial3D
var mat_ceiling: StandardMaterial3D
var mat_entrance: StandardMaterial3D
var mat_extraction: StandardMaterial3D
var mat_corridor: StandardMaterial3D
var mat_den: StandardMaterial3D
var mat_resource: StandardMaterial3D

func _ready() -> void:
	_build_materials()

## Build all dungeon geometry and attach to parent
func build(data: DungeonData, parent: Node3D) -> void:
	for room in data.rooms:
		_build_room(room, parent)
	for corridor in data.corridors:
		_build_corridor(corridor, parent)

# ---------------------------------------------------------------------------
# Room geometry
# ---------------------------------------------------------------------------
func _build_room(room: DungeonData.RoomData, parent: Node3D) -> void:
	var root := StaticBody3D.new()
	root.name = "Room%d_%s" % [room.id, DungeonData.RoomType.keys()[room.type]]
	root.set_meta("room_id", room.id)
	root.set_meta("room_type", room.type)
	root.collision_layer = 1  ## "World" layer
	root.collision_mask  = 0
	parent.add_child(root)

	var w := room.size.x
	var d := room.size.y

	## Floor
	_add_box(root, Vector3(room.world_position.x, FLOOR_Y - FLOOR_H * 0.5, room.world_position.z),
		Vector3(w, FLOOR_H, d), _floor_mat(room))

	## Ceiling (atmospheric, no collision needed for prototype)
	var ceil_mi := MeshInstance3D.new()
	var ceil_mesh := BoxMesh.new()
	ceil_mesh.size = Vector3(w, FLOOR_H, d)
	ceil_mi.mesh = ceil_mesh
	ceil_mi.position = Vector3(room.world_position.x, CEIL_H + FLOOR_H * 0.5, room.world_position.z)
	ceil_mi.set_surface_override_material(0, mat_ceiling)
	parent.add_child(ceil_mi)

# ---------------------------------------------------------------------------
# Corridor geometry (L-shaped: horizontal segment then vertical)
# ---------------------------------------------------------------------------
func _build_corridor(c: DungeonData.CorridorData, parent: Node3D) -> void:
	var s := c.start_pos
	var e := c.end_pos
	var w := c.width
	## Horizontal segment (same Z as start, X goes to end.x)
	var mid := Vector3(e.x, 0.0, s.z)
	_build_seg(parent, Vector3(s.x, 0.0, s.z), mid, w)
	## Vertical segment (same X as end, Z goes from start.z to end.z)
	_build_seg(parent, mid, Vector3(e.x, 0.0, e.z), w)

func _build_seg(parent: Node3D, from: Vector3, to: Vector3, width: float) -> void:
	var diff := to - from
	var length := diff.length()
	if length < 0.3:
		return
	var center := (from + to) * 0.5
	var is_z := absf(diff.z) > absf(diff.x)
	var size := Vector3(width if is_z else length, FLOOR_H, length if is_z else width)
	_add_box(parent, Vector3(center.x, FLOOR_Y - FLOOR_H * 0.5, center.z), size, mat_corridor)

# ---------------------------------------------------------------------------
# Helper: add a static box (floor tile) with mesh + collision
# ---------------------------------------------------------------------------
func _add_box(parent: Node3D, center: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var is_static := parent is StaticBody3D

	## Mesh
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_surface_override_material(0, mat)
	mi.position = center if is_static else Vector3.ZERO

	## Collision
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = center if is_static else Vector3.ZERO

	if is_static:
		parent.add_child(mi)
		parent.add_child(col)
	else:
		## For non-StaticBody (segment corridors), wrap in a StaticBody3D
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask  = 0
		sb.add_child(mi)
		sb.add_child(col)
		parent.add_child(sb)

# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------
func _build_materials() -> void:
	mat_floor      = _mat(Color(0.30, 0.27, 0.22))
	mat_ceiling    = _mat(Color(0.15, 0.13, 0.11))
	mat_entrance   = _mat(Color(0.38, 0.32, 0.22))
	mat_extraction = _mat(Color(0.24, 0.38, 0.28))
	mat_corridor   = _mat(Color(0.26, 0.23, 0.19))
	mat_den        = _mat(Color(0.28, 0.18, 0.16))
	mat_resource   = _mat(Color(0.22, 0.28, 0.32))

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	m.metallic  = 0.0
	return m

func _floor_mat(room: DungeonData.RoomData) -> StandardMaterial3D:
	match room.type:
		DungeonData.RoomType.ENTRANCE:    return mat_entrance
		DungeonData.RoomType.EXTRACTION:  return mat_extraction
		DungeonData.RoomType.CREATURE_DEN:return mat_den
		DungeonData.RoomType.RESOURCE:    return mat_resource
		_:                                return mat_floor
