## DebugMenu.gd
## Developer debug overlay. Toggle with F1 (debug_menu input action).
## Only visible in-game; allows quick testing of all systems including Jolt physics.

extends CanvasLayer

const RAT_PHYSICS_SCENE := preload("res://scenes/creatures/RatPhysicsProp.tscn")

@onready var _panel: Control = $Panel
@onready var _seed_input: LineEdit = find_child("SeedInput", true, false) as LineEdit
@onready var _status: Label = find_child("StatusLabel", true, false) as Label

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
	var seed_text := _seed_input.text.strip_edges() if _seed_input else ""
	var seed := int(seed_text) if seed_text.is_valid_int() else randi()
	_set_status("Regenerating dungeon (seed=%d)…" % seed)
	GameManager.start_expedition(seed)

# ---------------------------------------------------------------------------
# Jolt Physics Rat Testing
# ---------------------------------------------------------------------------

func _on_spawn_rat_physics() -> void:
	var root := get_tree().current_scene
	if not root:
		return
	var rat := RAT_PHYSICS_SCENE.instantiate() as RigidBody3D
	root.add_child(rat)

	var player := GameManager.get_local_player() as Node3D
	var spawn_pos := Vector3(0, 1.2, 0)
	var fwd := Vector3.FORWARD
	if player:
		var cam := player.find_child("Camera3D", true, false) as Camera3D
		if cam:
			fwd = -cam.global_transform.basis.z
			spawn_pos = cam.global_position + fwd * 1.6 + Vector3(0, 0.2, 0)
		else:
			fwd = -player.global_transform.basis.z
			spawn_pos = player.global_position + fwd * 2.0 + Vector3(0, 0.5, 0)

	rat.global_position = spawn_pos
	# Dynamic toss impulse for Jolt collision testing
	rat.apply_central_impulse(fwd * 5.0 + Vector3.UP * 2.5)
	rat.apply_torque_impulse(Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3)))
	_set_status("Spawned Jolt Physics Rat")

func _on_spawn_rat_swarm() -> void:
	var root := get_tree().current_scene
	if not root:
		return

	var player := GameManager.get_local_player() as Node3D
	var base_pos := player.global_position + Vector3(0, 1.0, 0) if player else Vector3(0, 1.5, 0)

	for i in range(10):
		var rat := RAT_PHYSICS_SCENE.instantiate() as RigidBody3D
		root.add_child(rat)
		var angle := (float(i) / 10.0) * TAU
		var offset := Vector3(cos(angle), 0, sin(angle)) * 0.9
		rat.global_position = base_pos + offset + Vector3(0, randf_range(0.1, 0.6), 0)

		# Fountain radial impulse
		var burst := (offset.normalized() + Vector3.UP * randf_range(1.2, 2.2)) * randf_range(3.5, 6.5)
		rat.apply_central_impulse(burst)
		rat.apply_torque_impulse(Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4)))

	_set_status("Spawned 10 Physics Rats (Jolt Swarm Fountain)")

func _on_shockwave_blast() -> void:
	var player := GameManager.get_local_player() as Node3D
	var origin := player.global_position if player else Vector3.ZERO
	var rats := get_tree().get_nodes_in_group("physics_rats")
	var count := 0
	for node in rats:
		if node.has_method("apply_explosion_impulse"):
			node.apply_explosion_impulse(origin, 18.0, 14.0)
			count += 1
		elif node is RigidBody3D:
			var diff := (node as RigidBody3D).global_position - origin
			var dist := diff.length()
			if dist < 16.0:
				var dir := diff.normalized() if dist > 0.01 else Vector3.UP
				dir.y = max(dir.y, 0.4)
				var force := (1.0 - dist / 16.0) * 16.0
				(node as RigidBody3D).apply_central_impulse(dir.normalized() * force)
				count += 1
	_set_status("Shockwave blast applied to %d rats" % count)

func _on_spawn_rat_creature() -> void:
	_spawn_creature("rat")

func _on_clear_rats() -> void:
	var count := 0
	for node in get_tree().get_nodes_in_group("physics_rats"):
		node.queue_free()
		count += 1
	_set_status("Cleared %d physics rats" % count)

# ---------------------------------------------------------------------------
# Creature Spawning & World Helpers
# ---------------------------------------------------------------------------

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

func _on_club_t1() -> void:
	_set_club_tier(1)

func _on_club_t2() -> void:
	_set_club_tier(2)

func _on_club_t3() -> void:
	_set_club_tier(3)

func _on_club_t4() -> void:
	_set_club_tier(4)

func _set_club_tier(tier: int) -> void:
	ProgressionManager.set_weapon_tier("club", tier)
	var data: Dictionary = ProgressionManager.get_weapon_tier_data("club", tier)
	_set_status("Club set to Tier %d: %s (%d DMG)" % [tier, data.get("name", ""), int(data.get("damage", 32))])

func _on_return_to_menu() -> void:
	GameManager.return_to_main_menu()

func _set_status(msg: String) -> void:
	if _status:
		_status.text = msg
	print("DEBUG: " + msg)
