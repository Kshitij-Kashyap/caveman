## DebugMenu.gd
## Comprehensive in-game Developer Debug Overlay for testing all mechanics,
## combat, physics, weapons, resources, day/night cycles, and navigation.
## Can be toggled via F1, ~ (tilde/backtick), or the floating [🛠️ DEBUG] button.

extends CanvasLayer

const RAT_PHYSICS_SCENE := preload("res://scenes/creatures/RatPhysicsProp.tscn")

@onready var _panel: Control = $Panel
@onready var _toggle_btn: Button = get_node_or_null("DebugToggleBtn") as Button
@onready var _status: Label = find_child("StatusLabel", true, false) as Label
@onready var _seed_input: LineEdit = find_child("SeedInput", true, false) as LineEdit

# Cheats UI
@onready var _god_check: CheckBox = find_child("GodModeCheck", true, false) as CheckBox
@onready var _stamina_check: CheckBox = find_child("InfStaminaCheck", true, false) as CheckBox
@onready var _flight_check: CheckBox = find_child("FlightCheck", true, false) as CheckBox

var _visible: bool = false
var _simulated_hour: float = 12.0
var _time_multiplier: float = 1.0

func _ready() -> void:
	layer = 100
	_panel.visible = false
	if _toggle_btn:
		_toggle_btn.visible = true
		if not _toggle_btn.pressed.is_connected(_on_toggle_btn_pressed):
			_toggle_btn.pressed.connect(_on_toggle_btn_pressed)

func _input(event: InputEvent) -> void:
	if event.is_action_just_pressed("debug_menu"):
		_toggle()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_QUOTELEFT: # Tilde / Backtick
			_toggle()

func _on_toggle_btn_pressed() -> void:
	_toggle()

func _toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _toggle_btn:
		_toggle_btn.visible = not _visible

	if _visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_sync_player_cheats_ui()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _sync_player_cheats_ui() -> void:
	var player := GameManager.get_local_player() as Node
	if player:
		if _god_check and "god_mode" in player:
			_god_check.button_pressed = player.god_mode
		if _stamina_check and "infinite_stamina" in player:
			_stamina_check.button_pressed = player.infinite_stamina
		if _flight_check and "controller" in player and player.controller:
			_flight_check.button_pressed = player.controller.get("is_flying")

# ---------------------------------------------------------------------------
# Player Cheats & Movement
# ---------------------------------------------------------------------------

func _on_god_mode_toggled(toggled_on: bool) -> void:
	var player := GameManager.get_local_player() as Node
	if player and player.has_method("set_god_mode"):
		player.set_god_mode(toggled_on)
		_set_status("God Mode: %s" % ("ENABLED" if toggled_on else "DISABLED"))
	elif player and "god_mode" in player:
		player.god_mode = toggled_on
		_set_status("God Mode: %s" % ("ENABLED" if toggled_on else "DISABLED"))

func _on_inf_stamina_toggled(toggled_on: bool) -> void:
	var player := GameManager.get_local_player() as Node
	if player and "infinite_stamina" in player:
		player.infinite_stamina = toggled_on
		_set_status("Infinite Stamina: %s" % ("ENABLED" if toggled_on else "DISABLED"))

func _on_flight_toggled(toggled_on: bool) -> void:
	var player := GameManager.get_local_player() as Node
	if player and player.has_method("set_flight_mode"):
		player.set_flight_mode(toggled_on)
		_set_status("Noclip / 3D Flight: %s" % ("ENABLED" if toggled_on else "DISABLED"))

func _on_speed_1x() -> void: _set_speed(1.0)
func _on_speed_2x() -> void: _set_speed(2.0)
func _on_speed_5x() -> void: _set_speed(5.0)

func _set_speed(mult: float) -> void:
	var player := GameManager.get_local_player() as Node
	if player and player.has_method("set_speed_multiplier"):
		player.set_speed_multiplier(mult)
		_set_status("Speed Multiplier: %.1fx" % mult)

func _on_jump_1x() -> void: _set_jump(1.0)
func _on_jump_2x() -> void: _set_jump(2.0)
func _on_jump_3x() -> void: _set_jump(3.0)

func _set_jump(mult: float) -> void:
	var player := GameManager.get_local_player() as Node
	if player and player.has_method("set_jump_multiplier"):
		player.set_jump_multiplier(mult)
		_set_status("Jump Multiplier: %.1fx" % mult)

func _on_heal_player() -> void:
	var player := GameManager.get_local_player() as Node
	if player and player.has_method("heal"):
		player.heal(100.0)
		_set_status("Player healed to full (100 HP)")

func _on_suicide_ragdoll() -> void:
	var player := GameManager.get_local_player() as Node3D
	if player and player.has_method("enable_ragdoll"):
		_toggle() # Close menu so camera tumble can be seen
		var fwd: Vector3 = -player.global_transform.basis.z
		player.enable_ragdoll(fwd * 12.0 + Vector3.UP * 4.0)
		_set_status("Triggered Player Death Ragdoll")

func _on_teleport_hub() -> void: _teleport_to("Teleport_Hub", Vector3(0, 1.2, 0))
func _on_teleport_range() -> void: _teleport_to("Teleport_Range", Vector3(0, 1.2, -32))
func _on_teleport_arena() -> void: _teleport_to("Teleport_Arena", Vector3(32, 1.2, 0))
func _on_teleport_physics() -> void: _teleport_to("Teleport_Physics", Vector3(0, 5.0, 28))
func _on_teleport_parkour() -> void: _teleport_to("Teleport_Parkour", Vector3(-32, 1.2, 0))
func _on_teleport_cliff() -> void: _teleport_to("Teleport_Cliff", Vector3(-26, 6.0, -26))

func _teleport_to(marker_name: String, fallback_pos: Vector3) -> void:
	var player := GameManager.get_local_player() as Node3D
	if not player:
		_set_status("Player not found")
		return
	var root := get_tree().current_scene
	var target_pos := fallback_pos
	if root:
		var marker := root.find_child(marker_name, true, false) as Node3D
		if marker:
			target_pos = marker.global_position + Vector3(0, 0.5, 0)
	player.global_position = target_pos
	if "velocity" in player:
		player.velocity = Vector3.ZERO
	_set_status("Teleported to %s (%v)" % [marker_name.replace("Teleport_", ""), target_pos])

# ---------------------------------------------------------------------------
# Arsenal & Tools
# ---------------------------------------------------------------------------

func _on_equip_pickaxe() -> void: _switch_player_tool(0)
func _on_equip_axe() -> void: _switch_player_tool(1)
func _on_equip_spear() -> void: _switch_player_tool(2)
func _on_equip_club() -> void: _switch_player_tool(3)
func _on_equip_torch() -> void: _switch_player_tool(4)

func _switch_player_tool(tool_id: int) -> void:
	var player := GameManager.get_local_player() as Node
	if player and "viewmodel" in player and player.viewmodel:
		player.viewmodel.switch_tool(tool_id)
		var names: Array[String] = ["Pickaxe", "Axe", "Spear", "Club", "Torch"]
		var t_name: String = names[tool_id] if tool_id < names.size() else "Tool"
		_set_status("Equipped: %s" % t_name)

func _on_club_t1() -> void: _set_club_tier(1)
func _on_club_t2() -> void: _set_club_tier(2)
func _on_club_t3() -> void: _set_club_tier(3)
func _on_club_t4() -> void: _set_club_tier(4)

func _set_club_tier(tier: int) -> void:
	ProgressionManager.set_weapon_tier("club", tier)
	var data: Dictionary = ProgressionManager.get_weapon_tier_data("club", tier)
	_set_status("Club set to Tier %d: %s (%d DMG)" % [tier, data.get("name", ""), int(data.get("damage", 32))])

func _on_refill_spears() -> void:
	var player := GameManager.get_local_player() as Node
	if player and "inventory" in player and player.inventory:
		player.inventory.add_item("flint_spear", 10)
	ProgressionManager.deposit_resources({"flint": 10, "wood": 10})
	_set_status("Refilled 10x Flint Spears & Materials")

# ---------------------------------------------------------------------------
# Loot & Resources
# ---------------------------------------------------------------------------

func _on_give_all_resources() -> void:
	var items := {
		"stone": 50, "flint": 50, "wood": 50, "bone": 50,
		"meat": 50, "roast_meat": 25, "hide": 50, "copper": 50,
		"crystal": 25, "glow_charge": 10
	}
	ProgressionManager.deposit_resources(items)
	var player := GameManager.get_local_player() as Node
	if player and "inventory" in player and player.inventory:
		for id in items:
			player.inventory.add_item(id, items[id])
	_set_status("Granted +50 of all resources")

func _on_give_wood() -> void: _give_res("wood", 20)
func _on_give_stone() -> void: _give_res("stone", 20)
func _on_give_flint() -> void: _give_res("flint", 20)
func _on_give_meat() -> void: _give_res("meat", 15)
func _on_give_roast_meat() -> void: _give_res("roast_meat", 10)
func _on_give_bone() -> void: _give_res("bone", 15)
func _on_give_hide() -> void: _give_res("hide", 15)
func _on_give_copper() -> void: _give_res("copper", 15)
func _on_give_crystal() -> void: _give_res("crystal", 10)
func _on_give_glow_charge() -> void: _give_res("glow_charge", 5)

func _give_res(res_id: String, amount: int) -> void:
	ProgressionManager.deposit_resources({res_id: amount})
	var player := GameManager.get_local_player() as Node
	if player and "inventory" in player and player.inventory:
		player.inventory.add_item(res_id, amount)
	_set_status("Granted +%d %s" % [amount, res_id.capitalize()])

func _on_clear_inventory() -> void:
	var player := GameManager.get_local_player() as Node
	if player and "inventory" in player and player.inventory:
		player.inventory.items.clear()
		player.inventory.inventory_updated.emit()
	_set_status("Cleared player inventory")

# ---------------------------------------------------------------------------
# Creature Spawning & Combat Arena
# ---------------------------------------------------------------------------

func _on_spawn_rat_creature() -> void: _spawn_creature("rat")
func _on_spawn_deer() -> void: _spawn_creature("deer")
func _on_spawn_boar() -> void: _spawn_creature("boar")
func _on_spawn_wolf() -> void: _spawn_creature("wolf")
func _on_spawn_bear() -> void: _spawn_creature("bear")

func _on_spawn_wolf_pack() -> void:
	for i in range(5):
		_spawn_creature("wolf", Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)))
	_set_status("Spawned Wolf Pack (x5)")

func _spawn_creature(type: String, extra_offset: Vector3 = Vector3.ZERO) -> void:
	var root := get_tree().current_scene
	if not root:
		return
	var scene_path := "res://scenes/creatures/Creature.tscn"
	var scene := load(scene_path) as PackedScene
	if not scene:
		_set_status("Creature scene not found")
		return
	var def_path := "res://resources/creatures/%s.tres" % type
	var def := load(def_path) as CreatureDefinition
	var creature := scene.instantiate()
	root.add_child(creature)

	var player := GameManager.get_local_player() as Node3D
	var spawn_pos := Vector3(0, 1.0, 0)
	if player:
		var fwd := -player.global_transform.basis.z
		spawn_pos = player.global_position + fwd * 4.0 + Vector3(0, 0.5, 0) + extra_offset
	creature.global_position = spawn_pos
	if def:
		creature.creature_def = def
	_set_status("Spawned %s" % type.capitalize())

func _on_toggle_ai() -> void:
	var creatures := get_tree().get_nodes_in_group("creatures")
	var new_state := false
	for c in creatures:
		var ai := c.find_child("CreatureAI", true, false) as CreatureAI
		if ai:
			new_state = not ai._ai_enabled
			ai.set_ai_enabled(new_state)
	_set_status("Creature AI: %s" % ("ENABLED" if new_state else "DISABLED"))

func _on_clear_creatures() -> void:
	var count := 0
	for node in get_tree().get_nodes_in_group("creatures"):
		node.queue_free()
		count += 1
	_set_status("Cleared %d creatures" % count)

# ---------------------------------------------------------------------------
# Jolt Physics & Demolition
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
	rat.apply_central_impulse(fwd * 6.0 + Vector3.UP * 2.5)
	rat.apply_torque_impulse(Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3)))
	_set_status("Spawned Jolt Physics Rat")

func _on_spawn_rat_swarm() -> void:
	var root := get_tree().current_scene
	if not root:
		return
	var player := GameManager.get_local_player() as Node3D
	var base_pos := player.global_position + Vector3(0, 1.2, 0) if player else Vector3(0, 1.5, 0)
	for i in range(10):
		var rat := RAT_PHYSICS_SCENE.instantiate() as RigidBody3D
		root.add_child(rat)
		var angle := (float(i) / 10.0) * TAU
		var offset := Vector3(cos(angle), 0, sin(angle)) * 0.9
		rat.global_position = base_pos + offset + Vector3(0, randf_range(0.1, 0.5), 0)
		var burst := (offset.normalized() + Vector3.UP * randf_range(1.2, 2.2)) * randf_range(4.0, 7.0)
		rat.apply_central_impulse(burst)
		rat.apply_torque_impulse(Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4)))
	_set_status("Spawned 10 Physics Rats (Jolt Swarm)")

func _on_shockwave_blast() -> void:
	var player := GameManager.get_local_player() as Node3D
	var origin := player.global_position if player else Vector3.ZERO
	var count := 0
	var bodies := get_tree().get_nodes_in_group("physics_props") + get_tree().get_nodes_in_group("physics_rats")
	for node in bodies:
		if node is RigidBody3D:
			var diff := (node as RigidBody3D).global_position - origin
			var dist := diff.length()
			if dist < 24.0:
				var dir := diff.normalized() if dist > 0.05 else Vector3.UP
				dir.y = maxf(dir.y, 0.45)
				var force := (1.0 - dist / 24.0) * 22.0
				(node as RigidBody3D).apply_central_impulse(dir.normalized() * force)
				(node as RigidBody3D).apply_torque_impulse(Vector3(randf_range(-5, 5), randf_range(-5, 5), randf_range(-5, 5)))
				count += 1
	_set_status("Shockwave blast applied to %d physics bodies" % count)

func _on_spawn_barrel() -> void: _spawn_prop("res://assets/models/camp/primitive_barrel.obj", Vector3(0.45, 0.9, 0.45), 16.0)
func _on_spawn_crate() -> void: _spawn_prop("res://assets/models/camp/primitive_crate.obj", Vector3(0.8, 0.8, 0.8), 20.0)
func _on_spawn_stone_wheel() -> void: _spawn_prop("res://assets/models/items/stone_wheel.obj", Vector3(0.35, 0.14, 0.35), 25.0)
func _on_spawn_mammoth_bone() -> void: _spawn_prop("res://assets/models/camp/mammoth_bone.obj", Vector3(0.25, 0.85, 0.25), 12.0)

func _spawn_prop(mesh_path: String, col_size: Vector3, mass: float) -> void:
	var root := get_tree().current_scene
	if not root:
		return
	var mesh := load(mesh_path) as Mesh
	if not mesh:
		return
	var rb := RigidBody3D.new()
	rb.add_to_group("physics_props")
	rb.mass = mass
	rb.collision_layer = 1
	rb.collision_mask = 15

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	rb.add_child(mi)

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = col_size
	cs.shape = box
	rb.add_child(cs)

	root.add_child(rb)

	var player := GameManager.get_local_player() as Node3D
	var spawn_pos := Vector3(0, 1.5, 0)
	var fwd := Vector3.FORWARD
	if player:
		fwd = -player.global_transform.basis.z
		spawn_pos = player.global_position + fwd * 2.2 + Vector3(0, 0.8, 0)

	rb.global_position = spawn_pos
	rb.apply_central_impulse(fwd * 4.0 + Vector3.UP * 2.0)
	_set_status("Spawned physics prop: %s" % mesh_path.get_file().get_basename())

func _on_clear_rats() -> void:
	var count := 0
	for node in get_tree().get_nodes_in_group("physics_rats"):
		node.queue_free()
		count += 1
	_set_status("Cleared %d physics rats" % count)

func _on_clear_props() -> void:
	var count := 0
	for node in get_tree().get_nodes_in_group("physics_props"):
		node.queue_free()
		count += 1
	_set_status("Cleared %d loose physics props" % count)

# ---------------------------------------------------------------------------
# Environment & Time of Day
# ---------------------------------------------------------------------------

func _on_time_dawn() -> void: _apply_time(6.0)
func _on_time_noon() -> void: _apply_time(12.0)
func _on_time_dusk() -> void: _apply_time(18.0)
func _on_time_midnight() -> void: _apply_time(0.0)

func _apply_time(hour: float) -> void:
	_simulated_hour = hour
	var target_map: Node = find_parent("DebugIsland")
	if not target_map:
		var root := get_tree().current_scene
		if root and root.has_method("set_time_of_day"):
			target_map = root
		elif root:
			target_map = root.find_child("DebugIsland", true, false)
			if not target_map and get_parent() and get_parent().has_method("set_time_of_day"):
				target_map = get_parent()
	if target_map and target_map.has_method("set_time_of_day"):
		target_map.set_time_of_day(hour)
	else:
		var root := get_tree().current_scene
		var sun := root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D if root else null
		if sun:
			var angle := ((hour - 6.0) / 24.0) * TAU
			sun.rotation_degrees.x = -rad_to_deg(sin(angle)) * 60.0
			sun.rotation_degrees.y = rad_to_deg(angle)
			sun.light_energy = 1.3 if (hour >= 6.0 and hour <= 18.0) else 0.15
	_set_status("Time set to %02d:00" % int(hour))

# ---------------------------------------------------------------------------
# Game Flow & Dungeon
# ---------------------------------------------------------------------------

func _on_regen_dungeon() -> void:
	var seed_text := _seed_input.text.strip_edges() if _seed_input else ""
	var seed := int(seed_text) if seed_text.is_valid_int() else randi()
	_set_status("Regenerating dungeon (seed=%d)…" % seed)
	GameManager.start_expedition(seed)

func _on_complete_quest() -> void:
	if QuestManager.active_quest:
		QuestManager._progress[QuestManager.active_quest.target_id] = QuestManager.active_quest.required_quantity
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

func _on_return_to_camp() -> void:
	GameManager.enter_camp()

func _on_return_to_menu() -> void:
	GameManager.return_to_main_menu()

func _set_status(msg: String) -> void:
	if _status:
		_status.text = msg
	print("DEBUG: " + msg)
