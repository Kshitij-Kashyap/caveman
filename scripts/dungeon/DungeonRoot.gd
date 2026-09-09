## DungeonRoot.gd
## Root scene for a procedural expedition.
## On _ready() (server): generates dungeon, builds geometry, bakes navigation, spawns players and creatures.

extends Node3D

@onready var _generator: DungeonGenerator = $DungeonGenerator
@onready var _mesh_builder: DungeonMeshBuilder = $DungeonMeshBuilder
@onready var _geometry_root: Node3D = $GeometryRoot
@onready var _nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var _spawner: Node = $PlayerSpawner
@onready var _hud: CanvasLayer = $HUD
@onready var _debug_menu: CanvasLayer = $DebugMenu

var _dungeon_data: DungeonData = null

## Public accessor for the world map schematic (MapMenu). Server-only data.
func get_dungeon_data() -> DungeonData:
	return _dungeon_data

func _ready() -> void:
	if not multiplayer.is_server():
		## Clients wait for server to sync dungeon state
		_setup_hud()
		return
	## Server generates and builds the dungeon
	await get_tree().process_frame  ## Let all nodes initialise
	_generate()
	_setup_hud()

func _generate() -> void:
	var seed := GameManager.current_dungeon_seed
	var quest := QuestManager.active_quest
	_dungeon_data = _generator.generate(seed, quest)

	## Build geometry
	_mesh_builder.build(_dungeon_data, _geometry_root)

	## Bake navigation over all geometry
	_bake_navigation()

	## Position player spawner at dungeon entrance
	if _dungeon_data:
		var spawner_node := _spawner as PlayerSpawner
		if spawner_node and has_node("SpawnPoint"):
			$SpawnPoint.global_position = _dungeon_data.player_spawn_point
		
	## Position extraction zone
	var ez := find_child("ExtractionZone") as ExtractionZone
	if ez and _dungeon_data:
		ez.global_position = _dungeon_data.extraction_point

	## Spawn creatures
	await get_tree().physics_frame  ## Navigation must be ready
	_spawn_creatures()

func _bake_navigation() -> void:
	if not _nav_region:
		return
	## Build a NavigationMesh from the dungeon geometry
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_height = 1.8
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0
	_nav_region.navigation_mesh = nav_mesh
	var source_data := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source_data, _geometry_root)
	NavigationServer3D.bake_from_source_geometry_data_async(
		nav_mesh, source_data, Callable(self, "_on_nav_baked")
	)

func _on_nav_baked() -> void:
	print("DungeonRoot: Navigation baked")
	_nav_region.set_navigation_mesh(_nav_region.navigation_mesh)

func _spawn_creatures() -> void:
	if not _dungeon_data:
		return
	var creature_scene := load("res://scenes/creatures/Creature.tscn") as PackedScene
	## Load creature defs
	var defs := {
		"CREATURE_DEN": _load_def("bear"),
		"STANDARD":     _load_def("boar"),
	}
	var fallback := _load_def("deer")

	for room in _dungeon_data.rooms:
		var def: CreatureDefinition
		match room.type:
			DungeonData.RoomType.CREATURE_DEN: def = defs["CREATURE_DEN"]
			DungeonData.RoomType.STANDARD:     def = defs["STANDARD"]
			_: continue

		for spawn_pt: Vector3 in room.creature_spawn_points:
			var c := creature_scene.instantiate() as CreatureController
			add_child(c)
			c.creature_def = def if def else fallback
			c.global_position = spawn_pt + Vector3(0, 0.5, 0)
			c.add_to_group("creatures")

	## Spawn resource deposits
	var deposit_scene := load("res://scenes/items/MineableDeposit.tscn") as PackedScene
	for room in _dungeon_data.rooms:
		for pt: Vector3 in room.resource_spawn_points:
			if not deposit_scene:
				break
			var dep := deposit_scene.instantiate() as MineableDeposit
			add_child(dep)
			dep.global_position = pt
			dep.item_id = _deposit_item_for_room(room)

func _load_def(creature_name: String) -> CreatureDefinition:
	var path := "res://resources/creatures/%s.tres" % creature_name
	if ResourceLoader.exists(path):
		return load(path) as CreatureDefinition
	return null

func _deposit_item_for_room(room: DungeonData.RoomData) -> String:
	match room.type:
		DungeonData.RoomType.RESOURCE:
			var items := ["stone", "flint", "copper", "crystal", "bone"]
			return items[randi() % items.size()]
		_:
			return "stone"

func _setup_hud() -> void:
	## Connect ExtractionZone to HUD for countdown display
	await get_tree().process_frame
	var ez := find_child("ExtractionZone") as ExtractionZone
	var hud := _hud.get_node_or_null("HUD") if _hud else null
	if ez and hud and hud.has_method("show_extraction_countdown"):
		ez.extraction_countdown.connect(hud.show_extraction_countdown)
