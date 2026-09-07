## DungeonValidator.gd
## Validates that a generated dungeon satisfies all gameplay requirements.
## Used by DungeonGenerator before returning the final DungeonData.

class_name DungeonValidator
extends RefCounted

func validate(data: DungeonData, quest: QuestDefinition = null) -> bool:
	if not _has_entrance(data):
		push_warning("DungeonValidator: Missing ENTRANCE room")
		return false
	if not _has_extraction(data):
		push_warning("DungeonValidator: Missing EXTRACTION room")
		return false
	if data.rooms.size() < 3:
		push_warning("DungeonValidator: Too few rooms (%d)" % data.rooms.size())
		return false
	if not _is_fully_connected(data):
		push_warning("DungeonValidator: Rooms are not all reachable from entrance")
		return false
	if quest and not _quest_satisfiable(data, quest):
		push_warning("DungeonValidator: Quest '%s' is not satisfiable in this layout" % quest.quest_id)
		return false
	return true

func _has_entrance(data: DungeonData) -> bool:
	for room in data.rooms:
		if room.type == DungeonData.RoomType.ENTRANCE:
			return true
	return false

func _has_extraction(data: DungeonData) -> bool:
	for room in data.rooms:
		if room.type == DungeonData.RoomType.EXTRACTION:
			return true
	return false

func _is_fully_connected(data: DungeonData) -> bool:
	if data.rooms.is_empty():
		return false
	## Build adjacency from corridors
	var adj: Dictionary = {}
	for room in data.rooms:
		adj[room.id] = []
	for c in data.corridors:
		adj[c.from_room_id].append(c.to_room_id)
		adj[c.to_room_id].append(c.from_room_id)
	## BFS from entrance
	var visited := {}
	var queue := [data.entrance_room_id]
	visited[data.entrance_room_id] = true
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for nb: int in adj.get(cur, []):
			if not visited.has(nb):
				visited[nb] = true
				queue.append(nb)
	return visited.size() == data.rooms.size()

func _quest_satisfiable(data: DungeonData, quest: QuestDefinition) -> bool:
	match quest.quest_type:
		QuestDefinition.QuestType.KILL, QuestDefinition.QuestType.HUNT:
			var total := 0
			for room in data.rooms:
				total += room.creature_spawn_points.size()
			return total >= quest.required_quantity
		QuestDefinition.QuestType.COLLECT:
			for room in data.rooms:
				if not room.resource_spawn_points.is_empty():
					return true
			return false
		_:
			return true
