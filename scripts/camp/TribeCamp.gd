## TribeCamp.gd
## Central hub scene controller.
## Manages station interactions, first-person InteractableComponent bindings,
## physical camp props, and expedition launches.

extends Node3D

# ---------------------------------------------------------------------------
# Node References
# ---------------------------------------------------------------------------
@onready var camp_hud: CampHUD = $CampHUD
@onready var stations_parent: Node3D = $Stations
@onready var props_parent: Node3D = $Props

var _crafting_menu: CraftingMenu = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Auto-accept a default quest if none active
	if not QuestManager.active_quest:
		var default_quest := load("res://resources/quests/kill_boars.tres") as QuestDefinition
		if default_quest:
			QuestManager.accept_quest(default_quest)

	_setup_stations()
	_setup_crafting_menu()
	_spawn_physics_props()
	_ensure_two_sided_materials(self)

# ---------------------------------------------------------------------------
# Station Interactions Setup
# ---------------------------------------------------------------------------
func _setup_stations() -> void:
	if not stations_parent:
		return

	for child in stations_parent.get_children():
		# 1. Proximity triggers via CampStation
		if child is CampStation:
			child.player_entered.connect(func(_p): camp_hud.show_station_prompt(child))
			child.player_exited.connect(func(_p): camp_hud.hide_station_prompt(child))
			child.station_interacted.connect(func(st, pl): _handle_station_interaction(st.station_id, pl))

		# 2. First-Person Raycast target via InteractableComponent
		var ic := child.get_node_or_null("InteractableComponent") as InteractableComponent
		if not ic:
			for sub in child.get_children():
				if sub is InteractableComponent:
					ic = sub
					break
		if ic:
			ic.interacted.connect(func(pl): _handle_station_interaction(ic.interactable_id, pl))

func _handle_station_interaction(station_id: String, player: Player) -> void:
	AudioManager.play_sfx(AudioManager.SFX.UI_CLICK)

	match station_id:
		"expedition_gate":
			camp_hud.show_modal(
				"EXPEDITION GATE",
				"Descend into the dark underground caves?\nHunt prehistoric beasts, mine valuable glowing minerals, and extract alive with the tribe's loot!",
				"START EXPEDITION",
				_start_expedition
			)
		"quest_board":
			var q_text := "No quest currently selected."
			if QuestManager.active_quest:
				q_text = "Active Quest:\n%s\n\nGoal: Eliminate %d beasts.\nReward: %d Stone Rings." % [
					QuestManager.active_quest.quest_name,
					QuestManager.active_quest.required_quantity,
					QuestManager.active_quest.reward_currency
				]
			camp_hud.show_modal(
				"TRIBE QUEST BOARD",
				q_text,
				"ACCEPT BOAR HUNT",
				func():
					var default_quest := load("res://resources/quests/kill_boars.tres") as QuestDefinition
					if default_quest:
						QuestManager.accept_quest(default_quest)
			)
		"crafting_fire":
			if _crafting_menu:
				_crafting_menu.open_for(player)
			else:
				camp_hud.show_modal(
					"CRAFTING FIRE",
					"The campfire crackles with bright orange embers.\nRoast raw beast meats to heal wounds, and craft sturdy stone tools and spears."
				)
		"storage_chest":
			var stock_text := "Tribe Stockpile:\n"
			if ProgressionManager.stored_resources.is_empty():
				stock_text += "No resources stored yet. Mine deposits during cave expeditions!"
			else:
				for k in ProgressionManager.stored_resources:
					stock_text += "• %s: %d\n" % [k.capitalize(), ProgressionManager.stored_resources[k]]
			camp_hud.show_modal("TRIBE STORAGE", stock_text)
		"upgrade_station":
			var cur_tier: int = ProgressionManager.get_weapon_tier("club")
			var cur_data: Dictionary = ProgressionManager.get_weapon_tier_data("club", cur_tier)
			var next_data: Dictionary = ProgressionManager.get_next_weapon_tier_data("club")

			var title := "TRIBE WEAPON UPGRADES"
			var body := "ACTIVE WEAPON: %s (Tier %d)\n" % [cur_data.get("name", "Stone Club"), cur_tier]
			body += "• Striking Damage: %d DMG\n" % int(cur_data.get("damage", 32.0))
			body += "• Physical Knockback: %.1fx\n" % cur_data.get("impulse", 1.0)
			body += "• Visuals: %s\n\n" % cur_data.get("desc", "")

			if not next_data.is_empty():
				body += "NEXT UPGRADE: Tier %d — %s\n" % [cur_tier + 1, next_data.get("name", "")]
				body += "• New Damage: %d DMG (+%d)\n" % [
					int(next_data.get("damage", 0)),
					int(next_data.get("damage", 0) - cur_data.get("damage", 0))
				]
				body += "• New Details: %s\n\n" % next_data.get("desc", "")
				body += "Required Cost: %d Stone Rings" % next_data.get("cost_rings", 0)
				var cost_res: Dictionary = next_data.get("cost_res", {})
				for r in cost_res:
					body += " | %d %s" % [cost_res[r], r.capitalize()]

				var can_afford := ProgressionManager.can_upgrade_weapon("club")
				var action_txt := "UPGRADE WEAPON" if can_afford else "NEED MORE RESOURCES"
				camp_hud.show_modal(
					title,
					body,
					action_txt,
					func():
						if ProgressionManager.can_upgrade_weapon("club"):
							ProgressionManager.upgrade_weapon("club")
							AudioManager.play_sfx(AudioManager.SFX.PICKAXE_HIT_ORE)
				)
			else:
				body += "★ MAXIMUM TIER REACHED ★\nYour tribal war club has attained supreme chieftain strength!"
				camp_hud.show_modal(title, body)
		"character_station":
			camp_hud.show_modal(
				"WAR PAINT TOTEM",
				"Tribal elder marks your warrior's skin with ochre clay and mammoth ash.\nAppearance saved to tribe records."
			)
		"elder_npc":
			camp_hud.show_modal(
				"TRIBE ELDER OOG",
				"\"Greetings, hunter! Take your spear and pickaxe deep into the caves. Watch your stamina, look out for beast packs, and bring back carved stone rings to honor the tribe!\"",
				"\"HONOR THE TRIBE\""
			)
		"camp_center", "camp_bonfire":
			camp_hud.show_modal(
				"GREAT BONFIRE",
				"The blazing heart of the tribe. Flames rise high into the clear blue sky, warming all warriors preparing for the raid."
			)

func _setup_crafting_menu() -> void:
	var scene := load("res://scenes/ui/CraftingMenu.tscn") as PackedScene
	if scene:
		_crafting_menu = scene.instantiate() as CraftingMenu
		add_child(_crafting_menu)

func _start_expedition() -> void:
	if not NetworkManager.is_connected_to_session():
		NetworkManager.host_game()
	if DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameManager.start_expedition()

# ---------------------------------------------------------------------------
# Low-Poly Physics Props Spawning
# ---------------------------------------------------------------------------
func _spawn_physics_props() -> void:
	if not props_parent:
		return

	var barrel_mesh := load("res://assets/models/camp/primitive_barrel.obj") as Mesh
	var crate_mesh := load("res://assets/models/camp/primitive_crate.obj") as Mesh
	var bone_mesh := load("res://assets/models/camp/mammoth_bone.obj") as Mesh
	var boulder_mesh := load("res://assets/models/camp/boulder.obj") as Mesh
	var wheel_mesh := load("res://assets/models/items/stone_wheel.obj") as Mesh

	var prop_configs: Array[Dictionary] = [
		# Barrels
		{ "type": "barrel", "pos": Vector3(-4.5, 0.6, 3.2), "size": Vector3(0.45, 0.9, 0.45), "mesh": barrel_mesh },
		{ "type": "barrel", "pos": Vector3(-5.2, 0.6, 2.7), "size": Vector3(0.45, 0.9, 0.45), "mesh": barrel_mesh },
		{ "type": "barrel", "pos": Vector3(4.8, 0.6, 4.0), "size": Vector3(0.45, 0.9, 0.45), "mesh": barrel_mesh },
		# Crates
		{ "type": "crate",  "pos": Vector3(5.5, 0.5, 2.5), "size": Vector3(0.8, 0.8, 0.8), "mesh": crate_mesh },
		{ "type": "crate",  "pos": Vector3(5.8, 1.3, 2.5), "size": Vector3(0.7, 0.7, 0.7), "mesh": crate_mesh },
		{ "type": "crate",  "pos": Vector3(-6.0, 0.5, -2.0), "size": Vector3(0.8, 0.8, 0.8), "mesh": crate_mesh },
		# Oversized Mammoth Bones
		{ "type": "bone",   "pos": Vector3(2.0, 0.4, 5.5), "size": Vector3(0.25, 0.85, 0.25), "mesh": bone_mesh },
		{ "type": "bone",   "pos": Vector3(2.6, 0.4, 5.2), "size": Vector3(0.22, 0.75, 0.22), "mesh": bone_mesh },
		{ "type": "bone",   "pos": Vector3(-2.2, 0.4, 5.4), "size": Vector3(0.25, 0.9, 0.25), "mesh": bone_mesh },
		# Pushable Boulders
		{ "type": "rock",   "pos": Vector3(-3.5, 0.4, -4.5), "size": Vector3(0.7, 0.6, 0.7), "mesh": boulder_mesh },
		{ "type": "rock",   "pos": Vector3(4.2, 0.4, -3.8), "size": Vector3(0.8, 0.7, 0.8), "mesh": boulder_mesh },
		{ "type": "rock",   "pos": Vector3(0.0, 0.4, -6.5), "size": Vector3(0.9, 0.8, 0.9), "mesh": boulder_mesh },
		# Rollable Stone Wheel Currency Props
		{ "type": "wheel",  "pos": Vector3(-2.8, 0.45, 1.8), "size": Vector3(0.35, 0.14, 0.35), "mesh": wheel_mesh },
		{ "type": "wheel",  "pos": Vector3(3.2, 0.45, 2.2),  "size": Vector3(0.35, 0.14, 0.35), "mesh": wheel_mesh },
	]

	for cfg in prop_configs:
		var rb := RigidBody3D.new()
		rb.name = "Prop_%s" % cfg["type"].capitalize()
		rb.position = cfg["pos"]
		rb.mass = 14.0
		rb.collision_layer = 1 # World
		rb.collision_mask = 3  # World + Player

		var col := CollisionShape3D.new()
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = cfg["mesh"]

		match cfg["type"]:
			"barrel":
				var cyl_shape := CylinderShape3D.new()
				cyl_shape.radius = cfg["size"].x
				cyl_shape.height = cfg["size"].y
				col.shape = cyl_shape
			"crate":
				var box_shape := BoxShape3D.new()
				box_shape.size = cfg["size"]
				col.shape = box_shape
			"bone":
				var cap_shape := CapsuleShape3D.new()
				cap_shape.radius = cfg["size"].x
				cap_shape.height = cfg["size"].y
				col.shape = cap_shape
			"rock":
				var sph_shape := SphereShape3D.new()
				sph_shape.radius = cfg["size"].x * 0.5
				col.shape = sph_shape
			"wheel":
				var cyl_shape := CylinderShape3D.new()
				cyl_shape.radius = cfg["size"].x
				cyl_shape.height = cfg["size"].y
				col.shape = cyl_shape

		rb.add_child(col)
		rb.add_child(mesh_inst)
		props_parent.add_child(rb)

func _ensure_two_sided_materials(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			if mat is StandardMaterial3D:
				var dup: StandardMaterial3D = mat.duplicate()
				dup.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.set_surface_override_material(s, dup)
			elif mat == null:
				var fallback := StandardMaterial3D.new()
				fallback.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.set_surface_override_material(s, fallback)
