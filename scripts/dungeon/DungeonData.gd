## DungeonData.gd
## Pure data container describing a generated dungeon layout.
## Created by DungeonGenerator, consumed by DungeonMeshBuilder and creature/resource spawners.

class_name DungeonData
extends RefCounted

enum RoomType {
	ENTRANCE,      ## Player spawn room
	STANDARD,      ## Generic exploration room
	RESOURCE,      ## Rich in mining deposits
	CREATURE_DEN,  ## Dense creature spawns
	BOSS,          ## Boss fight arena
	EXTRACTION,    ## Extraction zone
}

# ---------------------------------------------------------------------------
# Inner classes
# ---------------------------------------------------------------------------
class RoomData:
	var id: int = 0
	var type: DungeonData.RoomType = DungeonData.RoomType.STANDARD
	var world_position: Vector3 = Vector3.ZERO
	var size: Vector2 = Vector2(12.0, 12.0)  ## Width (X), Depth (Z)
	var connected_room_ids: Array[int] = []
	var creature_spawn_points: Array[Vector3] = []
	var resource_spawn_points: Array[Vector3] = []
	var depth: int = 0   ## Graph distance from entrance

class CorridorData:
	var from_room_id: int = 0
	var to_room_id: int = 0
	var start_pos: Vector3 = Vector3.ZERO
	var end_pos: Vector3 = Vector3.ZERO
	var width: float = 3.5

# ---------------------------------------------------------------------------
# Layout data
# ---------------------------------------------------------------------------
var rooms: Array = []       ## Array[RoomData]
var corridors: Array = []   ## Array[CorridorData]
var entrance_room_id: int = 0
var extraction_room_id: int = 1
var boss_room_id: int = -1

var player_spawn_point: Vector3 = Vector3.ZERO
var extraction_point: Vector3 = Vector3.ZERO

var dungeon_seed: int = 0
var biome: String = "shallow_caves"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func get_room(id: int) -> RoomData:
	for room in rooms:
		if room.id == id:
			return room
	return null

func add_room(room: RoomData) -> void:
	rooms.append(room)

func add_corridor(c: CorridorData) -> void:
	corridors.append(c)
