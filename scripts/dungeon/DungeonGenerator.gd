## DungeonGenerator.gd
## Generates procedural dungeon layouts for Cave Raiders expeditions.
## Algorithm: grid-based room selection → Prim's MST connectivity → type assignment → spawn points.
## Server-only: called by DungeonRoot.

class_name DungeonGenerator
extends Node

@export var grid_width: int = 6
@export var grid_height: int = 6
@export var grid_spacing: float = 22.0

@export var min_rooms: int = 7
@export var max_rooms: int = 11
@export var extra_connections: int = 2   ## Extra edges beyond MST for loops

@export var room_size_min: float = 10.0
@export var room_size_max: float = 17.0
@export var safe_room_size: float = 14.0  ## Entrance and extraction

@export var creatures_per_den: int = 4
@export var creatures_per_standard: int = 2
@export var deposits_per_resource: int = 4
@export var deposits_per_standard: int = 1

var _rng := RandomNumberGenerator.new()
var _validator := DungeonValidator.new()

func generate(dungeon_seed: int, quest: QuestDefinition = null) -> DungeonData:
	_rng.seed = dungeon_seed
	for attempt in 5:
		var data := _try_generate(dungeon_seed, quest)
		if _validator.validate(data, quest):
			print("DungeonGenerator: Seed %d — %d rooms, %d corridors (attempt %d)" % [
				dungeon_seed, data.rooms.size(), data.corridors.size(), attempt + 1
			])
			return data
		_rng.seed = dungeon_seed + attempt + 1
	push_error("DungeonGenerator: All attempts failed — returning partial dungeon")
	return _try_generate(dungeon_seed, quest)

func _try_generate(dungeon_seed: int, quest: QuestDefinition) -> DungeonData:
	var data := DungeonData.new()
	data.dungeon_seed = dungeon_seed
	_place_rooms(data)
	_connect_rooms(data)
	_assign_types(data, quest)
	_assign_depths(data)
	_scatter_spawns(data)
	_set_key_positions(data)
	return data

# ---------------------------------------------------------------------------
# Step 1 — Place rooms on grid
# ---------------------------------------------------------------------------
func _place_rooms(data: DungeonData) -> void:
	## Build all slots and shuffle
	var slots: Array[Vector2i] = []
	for row in grid_height:
		for col in grid_width:
			slots.append(Vector2i(col, row))
	_shuffle(slots)

	## Entrance on one edge, extraction on opposite
	var edge_slots := _edge_slots()
	_shuffle(edge_slots)
	var entrance_slot := edge_slots[0]
	var extraction_slot := _opposite_edge_slot(entrance_slot)

	## Total rooms
	var count := _rng.randi_range(min_rooms, max_rooms)

	## Build selected list
	var selected: Array[Vector2i] = [entrance_slot, extraction_slot]
	for s in slots:
		if selected.size() >= count:
			break
		if s != entrance_slot and s != extraction_slot:
			selected.append(s)

	## Create RoomData
	for i in selected.size():
		var slot := selected[i]
		var room := DungeonData.RoomData.new()
		room.id = i
		room.world_position = Vector3(
			(slot.x - grid_width * 0.5) * grid_spacing,
			0.0,
			(slot.y - grid_height * 0.5) * grid_spacing
		)
		var sz := _rng.randf_range(room_size_min, room_size_max)
		room.size = Vector2(sz, sz)
		data.add_room(room)

	data.entrance_room_id = 0
	data.extraction_room_id = 1

# ---------------------------------------------------------------------------
# Step 2 — Connect rooms (Prim's MST + extra edges)
# ---------------------------------------------------------------------------
func _connect_rooms(data: DungeonData) -> void:
	var max_dist := grid_spacing * 1.7

	## Build candidate edge list
	var all_edges: Array[Dictionary] = []
	for i in data.rooms.size():
		for j in range(i + 1, data.rooms.size()):
			var ra: DungeonData.RoomData = data.rooms[i]
			var rb: DungeonData.RoomData = data.rooms[j]
			var d := ra.world_position.distance_to(rb.world_position)
			if d <= max_dist:
				all_edges.append({from=ra.id, to=rb.id, dist=d})

	## Sort by distance
	all_edges.sort_custom(func(a, b): return a.dist < b.dist)

	## Prim's: grow MST
	var in_tree := {data.entrance_room_id: true}
	var mst_edges: Array[Dictionary] = []
	var iterations := 0
	while in_tree.size() < data.rooms.size() and iterations < 1000:
		iterations += 1
		for e in all_edges:
			var has_from := in_tree.has(e.from)
			var has_to   := in_tree.has(e.to)
			if has_from != has_to:  ## Exactly one end in tree
				mst_edges.append(e)
				in_tree[e.to if has_from else e.from] = true
				break

	## Add extra edges for loops
	var extra := 0
	for e in all_edges:
		if extra >= extra_connections:
			break
		if not _edge_exists(mst_edges, e.from, e.to):
			mst_edges.append(e)
			extra += 1

	## Build corridors from edges
	for e in mst_edges:
		var ra := data.get_room(e.from)
		var rb := data.get_room(e.to)
		if not ra or not rb:
			continue
		var c := DungeonData.CorridorData.new()
		c.from_room_id = e.from
		c.to_room_id   = e.to
		c.start_pos    = ra.world_position
		c.end_pos      = rb.world_position
		c.width        = _rng.randf_range(3.0, 4.5)
		data.add_corridor(c)
		ra.connected_room_ids.append(e.to)
		rb.connected_room_ids.append(e.from)

# ---------------------------------------------------------------------------
# Step 3 — Assign room types
# ---------------------------------------------------------------------------
func _assign_types(data: DungeonData, quest: QuestDefinition) -> void:
	## Force entrance and extraction types
	var entrance := data.get_room(data.entrance_room_id)
	if entrance:
		entrance.type = DungeonData.RoomType.ENTRANCE
		entrance.size = Vector2(safe_room_size, safe_room_size)
	var extraction := data.get_room(data.extraction_room_id)
	if extraction:
		extraction.type = DungeonData.RoomType.EXTRACTION
		extraction.size = Vector2(safe_room_size, safe_room_size)

	## Weighted pool for other rooms
	var pool: Array[DungeonData.RoomType] = []
	for _i in 5: pool.append(DungeonData.RoomType.STANDARD)
	for _i in 3: pool.append(DungeonData.RoomType.RESOURCE)
	for _i in 3: pool.append(DungeonData.RoomType.CREATURE_DEN)
	## Boost based on quest
	if quest:
		if quest.quest_type in [QuestDefinition.QuestType.KILL, QuestDefinition.QuestType.HUNT]:
			for _i in 4: pool.append(DungeonData.RoomType.CREATURE_DEN)
		elif quest.quest_type == QuestDefinition.QuestType.COLLECT:
			for _i in 4: pool.append(DungeonData.RoomType.RESOURCE)

	var has_resource := false
	var has_den := false

	for room in data.rooms:
		if room.id in [data.entrance_room_id, data.extraction_room_id]:
			continue
		room.type = pool[_rng.randi() % pool.size()]
		if room.type == DungeonData.RoomType.RESOURCE:
			has_resource = true
		if room.type == DungeonData.RoomType.CREATURE_DEN:
			has_den = true

	## Guarantee at least one of each
	for room in data.rooms:
		if room.id in [data.entrance_room_id, data.extraction_room_id]:
			continue
		if not has_resource and room.type == DungeonData.RoomType.STANDARD:
			room.type = DungeonData.RoomType.RESOURCE
			has_resource = true
		elif not has_den and room.type == DungeonData.RoomType.STANDARD:
			room.type = DungeonData.RoomType.CREATURE_DEN
			has_den = true
		if has_resource and has_den:
			break

# ---------------------------------------------------------------------------
# Step 4 — BFS depth from entrance
# ---------------------------------------------------------------------------
func _assign_depths(data: DungeonData) -> void:
	var visited := {}
	var queue := [[data.entrance_room_id, 0]]
	visited[data.entrance_room_id] = true
	while not queue.is_empty():
		var e: Array = queue.pop_front()
		var room_id: int = e[0]
		var depth: int = e[1]
		var room := data.get_room(room_id)
		if room:
			room.depth = depth
		for nb: int in (room.connected_room_ids if room else []):
			if not visited.has(nb):
				visited[nb] = true
				queue.append([nb, depth + 1])

# ---------------------------------------------------------------------------
# Step 5 — Scatter spawn points inside rooms
# ---------------------------------------------------------------------------
func _scatter_spawns(data: DungeonData) -> void:
	for room in data.rooms:
		match room.type:
			DungeonData.RoomType.CREATURE_DEN:
				_fill(room.creature_spawn_points, room, creatures_per_den, 0.55)
				_fill(room.resource_spawn_points, room, deposits_per_standard, 0.7)
			DungeonData.RoomType.RESOURCE:
				_fill(room.resource_spawn_points, room, deposits_per_resource, 0.65)
				_fill(room.creature_spawn_points, room, 1, 0.8)
			DungeonData.RoomType.STANDARD:
				_fill(room.creature_spawn_points, room, creatures_per_standard, 0.7)
				_fill(room.resource_spawn_points, room, deposits_per_standard, 0.8)
			_:
				pass  ## No spawns in entrance/extraction

func _fill(points: Array, room: DungeonData.RoomData, count: int, margin: float) -> void:
	var hw := room.size.x * 0.5 * margin
	var hd := room.size.y * 0.5 * margin
	for _i in count:
		points.append(Vector3(
			room.world_position.x + _rng.randf_range(-hw, hw),
			0.0,
			room.world_position.z + _rng.randf_range(-hd, hd)
		))

# ---------------------------------------------------------------------------
# Step 6 — Key positions
# ---------------------------------------------------------------------------
func _set_key_positions(data: DungeonData) -> void:
	var entrance := data.get_room(data.entrance_room_id)
	if entrance:
		data.player_spawn_point = entrance.world_position + Vector3(0, 1.0, 0)
	var extraction := data.get_room(data.extraction_room_id)
	if extraction:
		data.extraction_point = extraction.world_position

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------
func _edge_slots() -> Array[Vector2i]:
	var e: Array[Vector2i] = []
	for c in grid_width:
		e.append(Vector2i(c, 0))
		e.append(Vector2i(c, grid_height - 1))
	for r in range(1, grid_height - 1):
		e.append(Vector2i(0, r))
		e.append(Vector2i(grid_width - 1, r))
	return e

func _opposite_edge_slot(slot: Vector2i) -> Vector2i:
	var candidates: Array[Vector2i] = []
	if slot.y == 0:
		for c in grid_width: candidates.append(Vector2i(c, grid_height - 1))
	elif slot.y == grid_height - 1:
		for c in grid_width: candidates.append(Vector2i(c, 0))
	elif slot.x == 0:
		for r in grid_height: candidates.append(Vector2i(grid_width - 1, r))
	else:
		for r in grid_height: candidates.append(Vector2i(0, r))
	return candidates[_rng.randi() % candidates.size()] if not candidates.is_empty() else Vector2i(3, 3)

func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

func _edge_exists(edges: Array, from: int, to: int) -> bool:
	for e in edges:
		if (e.from == from and e.to == to) or (e.from == to and e.to == from):
			return true
	return false
