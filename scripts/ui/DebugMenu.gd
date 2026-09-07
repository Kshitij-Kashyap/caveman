## DebugMenu.gd
## Developer debug overlay. Toggle with F1 (debug_menu input action).
## Only visible in-game; allows quick testing of all systems.

extends CanvasLayer

@onready var _panel: Control = $Panel
@onready var _seed_input: LineEdit = $Panel/VBox/SeedRow/SeedInput
@onready var _status: Label = $Panel/VBox/StatusLabel

var _visible: bool = false

func _ready() -> void:
	_panel.visible = false
	layer = 100  ## Draw on top of HUD

func _input(event: InputEvent) -> void:
	if event.is_action_just_pressed("debug_menu"):
		_toggle()

func _toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_regen_dungeon() -> void:
	var seed_text := _seed_input.text.strip_edges()
	var seed := int(seed_text) if seed_text.is_valid_int() else randi()
	_set_status("Regenerating dungeon (seed=%d)…" % seed)
	GameManager.start_expedition(seed)

func _on_spawn_deer() -> void:
	_spawn_creature("deer")

func _on_spawn_boar() -> void:
	_spawn_creature("boar")

func _on_spawn_wolf() -> void:
	_spawn_creature("wolf")

func _on_spawn_bear() -> void:
	_spawn_creature("bear")

func _spawn_creature(type: String) -> void:
	if not multiplayer.is_server():
		_set_status("Creature spawning: server only")
		return
	var scene_path := "res://scenes/creatures/Creature.tscn"
	var scene := load(scene_path) as PackedScene
	if not scene:
		_set_status("Creature scene not found")
		return
	var def_path := "res://resources/creatures/%s.tres" % type
	var def := load(def_path) as CreatureDefinition
	var creature := scene.instantiate()
	get_tree().current_scene.add_child(creature)
	var player := GameManager.get_local_player() as Node3D
	if player:
		creature.global_position = player.global_position + Vector3(3, 0, 0)
	if def:
		creature.creature_def = def
	_set_status("Spawned: %s" % type)

func _on_give_all_resources() -> void:
	var items := {
		"stone": 50, "flint": 20, "wood": 30, "bone": 20,
		"meat": 15, "hide": 10, "copper": 10, "crystal": 5
	}
	ProgressionManager.deposit_resources(items)
	_set_status("Resources granted")

func _on_complete_quest() -> void:
	if QuestManager.active_quest:
		## Force completion
		QuestManager._progress[QuestManager.active_quest.target_id] = \
			QuestManager.active_quest.required_quantity
		QuestManager._complete_quest()
		_set_status("Quest force-completed")
	else:
		_set_status("No active quest")

func _on_teleport_extraction() -> void:
	var player := GameManager.get_local_player() as Node3D
	var dungeon_root := get_tree().current_scene
	var extraction_zone := dungeon_root.find_child("ExtractionZone", true, false)
	if player and extraction_zone:
		player.global_position = extraction_zone.global_position + Vector3(0, 1, 0)
		_set_status("Teleported to extraction")
	else:
		_set_status("ExtractionZone not found")

func _on_toggle_ai() -> void:
	var creatures := get_tree().get_nodes_in_group("creatures")
	var ai_enabled := true
	for c in creatures:
		var ai := c.find_child("CreatureAI") as CreatureAI
		if ai:
			ai_enabled = ai._ai_enabled
			ai.set_ai_enabled(not ai_enabled)
	_set_status("AI %s" % ("disabled" if ai_enabled else "enabled"))

func _on_return_to_menu() -> void:
	GameManager.return_to_main_menu()

func _set_status(msg: String) -> void:
	if _status:
		_status.text = msg
	print("DEBUG: " + msg)
