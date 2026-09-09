extends Node

const ChoppableTree = preload("res://scripts/items/ChoppableTree.gd")
const ThrownSpear = preload("res://scripts/items/ThrownSpear.gd")
const BasecampTerrain = preload("res://scripts/camp/BasecampTerrain.gd")
const SpearTarget = preload("res://scripts/camp/SpearTarget.gd")

func _ready() -> void:

	print("==================================================")
	print("--- BEGIN VISUAL FOUNDATION & WEAPON ARSENAL VERIFICATION ---")
	print("==================================================")

	# 1. Test CharacterCustomizationData
	print("[1/10] Testing CharacterCustomizationData...")
	var data := CharacterCustomizationData.get_default()
	assert(data != null, "Default data should not be null")
	data.skin_color = Color(0.9, 0.2, 0.1, 1.0)
	var save_res := data.save_to_file("user://test_customization.json")
	assert(save_res == OK, "Saving customization should succeed")
	var loaded := CharacterCustomizationData.load_or_create("user://test_customization.json")
	assert(loaded.skin_color.is_equal_approx(data.skin_color), "Loaded skin color should match saved")
	print("  -> CharacterCustomizationData passed.")

	# 2. Test CavemanModel (canonical modular Cave Raiders character)
	print("[2/10] Testing CavemanModel (canonical modular character)...")
	var model_scene := load("res://scenes/character/CavemanModel.tscn") as PackedScene
	assert(model_scene != null, "CavemanModel scene should load")
	var model := model_scene.instantiate() as CavemanModel
	add_child(model)
	model.apply_customization(data)
	assert(model.torso != null, "Torso should be generated")
	assert(model.head != null, "Head should be generated")
	assert(model.mat_skin.albedo_color.is_equal_approx(data.skin_color), "Skin material color should match")
	assert(not model.use_rigged_character, "The stylized modular character should be the default")
	assert(model.stage_visuals != null, "Stage visual container must exist")
	model.set_evolution_stage(5)
	assert(model.stage_visuals.get_child_count() >= 4, "Stage 5 must add readable refined silhouette pieces")
	model.set_expression("angry")
	assert(model.head_pivot.get_node_or_null("ExpressionBrows") != null, "Expressions must be driven by simple face geometry")
	var obj_mesh := load("res://assets/models/character/caveman.obj") as Mesh
	assert(obj_mesh != null, "caveman.obj should load as Mesh")
	print("  -> CavemanModel (canonical modular character) passed.")

	# 3. Test CharacterPreview with sunny 3D camp scene
	print("[3/10] Testing CharacterPreview with sunny 3D camp scene...")
	var preview_scene := load("res://scenes/character/CharacterPreview.tscn") as PackedScene
	assert(preview_scene != null, "CharacterPreview scene should load")
	var preview := preview_scene.instantiate() as CharacterPreview
	add_child(preview)
	preview.update_customization(data)
	assert(preview.find_child("PalmTree1", true, false) != null, "PalmTree1 must exist in preview")
	assert(preview.find_child("Campfire", true, false) != null, "Campfire must exist in preview")
	print("  -> CharacterPreview passed.")

	# 4. Test Player & Ragdoll
	print("[4/10] Testing Player & CharacterRagdoll...")
	var player_scene := load("res://scenes/player/Player.tscn") as PackedScene
	assert(player_scene != null, "Player scene should load")
	var player := player_scene.instantiate() as Player
	add_child(player)
	assert(player.caveman_model != null, "Player should have CavemanModel")
	assert(player.ragdoll != null, "Player should have CharacterRagdoll")
	player.enable_ragdoll(Vector3(0, 5, 0), Vector3(0, 10, 0))
	assert(player.is_ragdoll == true, "Player should be ragdolling")
	player.disable_ragdoll()
	assert(player.is_ragdoll == false, "Player should have recovered from ragdoll")
	print("  -> Player & CharacterRagdoll passed.")

	# 5. Test MainMenu scene
	print("[5/10] Testing MainMenu scene...")
	var menu_scene := load("res://scenes/main_menu/MainMenu.tscn") as PackedScene
	assert(menu_scene != null, "MainMenu scene should load")
	var menu := menu_scene.instantiate()
	add_child(menu)
	print("  -> MainMenu scene passed.")

	# 6. Test HUD scene & Stone Ring Currency
	print("[6/10] Testing HUD scene & Stone Ring Currency...")
	var hud_scene := load("res://scenes/ui/HUD.tscn") as PackedScene
	assert(hud_scene != null, "HUD scene should load")
	var hud := hud_scene.instantiate()
	add_child(hud)
	var hud_currency: Label = hud.get_node_or_null("TopRight/VBox/CurrencyLabel")
	assert(hud_currency != null, "HUD CurrencyLabel must exist")
	assert("STONE RINGS" in hud_currency.text, "HUD currency must display STONE RINGS")
	print("  -> HUD scene passed.")

	# 7. Test TribeCamp scene & Stone Wheel Monuments
	print("[7/10] Testing TribeCamp scene & Stone Wheel Monuments...")
	var camp_scene := load("res://scenes/camp/TribeCamp.tscn") as PackedScene
	assert(camp_scene != null, "TribeCamp scene should load")
	var camp := camp_scene.instantiate()
	add_child(camp)

	var station_names := [
		"Stations/ExpeditionGate",
		"Stations/QuestBoard",
		"Stations/CraftingFire",
		"Stations/StorageChest",
		"Stations/UpgradeStation",
		"Stations/CharacterStation",
		"Stations/NPCArea",
		"Stations/CampCenter"
	]
	for s_name in station_names:
		var st_node := camp.get_node_or_null(s_name)
		assert(st_node != null, "Station %s must exist in TribeCamp" % s_name)
		var ic := st_node.get_node_or_null("InteractableComponent") as InteractableComponent
		assert(ic != null, "Station %s must have an InteractableComponent" % s_name)

	assert(camp.find_child("StoneWheelMonument1", true, false) != null, "StoneWheelMonument1 must exist")
	var camp_currency: Label = camp.get_node_or_null("CampHUD/TopRight/VBox/CurrencyLabel")
	assert(camp_currency != null, "CampHUD CurrencyLabel must exist")
	assert("STONE RINGS" in camp_currency.text, "Camp currency must display STONE RINGS")
	print("  -> TribeCamp scene & Stone Wheel Monuments passed.")

	# 8. Test Physics Props & Rollable Stone Wheels
	print("[8/10] Testing Camp Low-Poly Models & Physics Props...")
	var props_node := camp.get_node_or_null("Props")
	assert(props_node != null, "Props container must exist")
	var prop_count := props_node.get_child_count()
	assert(prop_count > 0, "Props container must contain spawned physics props")
	assert(props_node.find_child("*Wheel*", true, false) != null, "Rollable stone wheel physics prop must exist")
	print("  -> Camp Physics Props passed (spawned: %d props including stone wheels)." % prop_count)

	# 9. Test First-Person Controls & Viewmodel
	print("[9/10] Testing First-Person Controls & Viewmodel...")
	assert(player.head_pitch_pivot != null, "HeadPitchPivot must exist")
	assert(player.camera != null, "Camera3D must exist")
	assert(player.camera.current, "Camera3D must be current for local player")
	assert(player.interact_ray != null, "InteractRaycast must exist")
	assert(player.viewmodel != null, "FirstPersonViewmodel must exist")
	assert(player.crosshair != null, "Crosshair must exist")

	var vm := player.viewmodel
	assert(vm.arm_mesh != null and vm.arm_mesh.mesh != null, "Viewmodel arm mesh must be loaded")
	assert(vm.pickaxe_mesh != null and vm.pickaxe_mesh.mesh != null, "Pickaxe mesh must be loaded")
	assert(vm.axe_mesh != null and vm.axe_mesh.mesh != null, "Stone Axe mesh must be loaded")
	assert(vm.spear_mesh != null and vm.spear_mesh.mesh != null, "Spear mesh must be loaded")
	assert(vm.club_mesh != null and vm.club_mesh.mesh != null, "Club mesh must be loaded")
	assert(vm.torch_mesh != null and vm.torch_mesh.mesh != null, "Torch mesh must be loaded")
	assert(vm.torch_light != null, "Torch OmniLight3D must exist")

	vm.apply_customization(data)
	assert(vm.mat_skin.albedo_color.is_equal_approx(data.skin_color), "Viewmodel arm skin color must match customization")

	vm.add_sway(Vector2(15.0, -10.0))
	assert(vm._sway_offset.length_squared() > 0.0, "Mouse motion must produce weapon sway")

	var swing_received := [false]
	vm.swing_started.connect(func(): swing_received[0] = true)
	var swung := vm.try_swing()
	assert(swung, "try_swing must return true")
	assert(swing_received[0], "swing_started signal must emit")

	# Test ragdoll camera switch and first-person restoral
	player.enable_ragdoll(Vector3(0, 4, -4))
	assert(player.is_ragdoll, "Player must enter ragdoll")
	assert(not player.viewmodel.visible, "Viewmodel must hide in ragdoll")
	player.disable_ragdoll()
	assert(not player.is_ragdoll, "Player must recover from ragdoll")
	assert(player.viewmodel.visible, "Viewmodel must restore in first-person")
	print("  -> First-Person Controls & Viewmodel passed.")

	# 10. Test Arsenal Weapon Switching (Pickaxe, Axe, Spear, Club, Torch)
	print("[10/12] Testing Prehistoric 5-Tool Arsenal Switching & Stats...")
	# Initial tool is Pickaxe (0)
	assert(vm.current_tool == FirstPersonViewmodel.ToolType.PICKAXE, "Initial tool must be PICKAXE")
	assert(vm.pickaxe_mesh.visible, "Pickaxe mesh must be visible")
	assert(not vm.axe_mesh.visible, "Axe mesh must be hidden initially")
	assert(not vm.spear_mesh.visible, "Spear mesh must be hidden initially")

	# Switch to Stone Axe (1)
	vm.switch_tool(FirstPersonViewmodel.ToolType.AXE, true)
	assert(vm.current_tool == FirstPersonViewmodel.ToolType.AXE, "Current tool must be AXE")
	assert(vm.axe_mesh.visible, "Axe mesh must be visible")
	assert(not vm.pickaxe_mesh.visible, "Pickaxe mesh must be hidden when Axe is active")
	assert(vm.melee_damage >= 20.0, "Stone axe damage must be at least 20")
	assert(vm.get_current_tool_name() == "Stone Axe", "Tool name must be Stone Axe")

	# Switch to Spear (2)
	vm.switch_tool(FirstPersonViewmodel.ToolType.SPEAR, true)
	assert(vm.current_tool == FirstPersonViewmodel.ToolType.SPEAR, "Current tool must be SPEAR")
	assert(vm.spear_mesh.visible, "Spear mesh must be visible")
	assert(not vm.axe_mesh.visible, "Axe mesh must be hidden when Spear is active")
	assert(vm.reach >= 3.5, "Spear reach must be at least 3.5m")
	assert(vm.get_current_tool_name() == "Flint Spear", "Tool name must be Flint Spear")

	# Switch to Club (3)
	vm.switch_tool(FirstPersonViewmodel.ToolType.CLUB, true)
	assert(vm.current_tool == FirstPersonViewmodel.ToolType.CLUB, "Current tool must be CLUB")
	assert(vm.club_mesh.visible, "Club mesh must be visible")
	assert(vm.melee_damage >= 30.0, "Club damage must be at least 30")

	# Switch to Torch (4)
	vm.switch_tool(FirstPersonViewmodel.ToolType.TORCH, true)
	assert(vm.current_tool == FirstPersonViewmodel.ToolType.TORCH, "Current tool must be TORCH")
	assert(vm.torch_mesh.visible, "Torch mesh must be visible")
	assert(vm.torch_light.visible, "Torch light must be visible when Torch is active")
	assert(vm.torch_light.light_energy > 0.0, "Torch light energy must be positive")

	# Cycle back to Pickaxe
	vm.switch_tool(FirstPersonViewmodel.ToolType.PICKAXE, true)
	assert(vm.current_tool == FirstPersonViewmodel.ToolType.PICKAXE, "Current tool must restore to PICKAXE")
	assert(not vm.torch_light.visible, "Torch light must turn off when switching away")

	# Test HUD Quickslot Dock
	assert(hud._tool_slot_panels.size() == 5, "HUD must have 5 quickslot panels")
	hud._on_active_tool_changed(1, "Stone Axe")
	assert(hud._active_tool_index == 1, "HUD active tool index must update to 1 for Stone Axe")
	print("  -> Prehistoric 5-Tool Arsenal Switching & HUD Dock passed.")

	# 11. Test Woodchopping Mechanic & ChoppableTree
	print("[11/12] Testing Woodchopping Mechanic & ChoppableTree...")
	var tree_scene := load("res://scenes/items/ChoppableTree.tscn") as PackedScene
	assert(tree_scene != null, "ChoppableTree scene must load")
	var tree := tree_scene.instantiate() as ChoppableTree
	add_child(tree)
	assert(tree.current_health == 5, "Tree initial health should be 5")

	# Chop with generic tool (1 damage)
	tree.on_hit(1.0, false)
	assert(tree.current_health == 4, "Generic hit should reduce tree health by 1")

	# Chop with Stone Axe (2.5x multiplier -> 3 damage)
	tree.on_hit(1.0, true)
	assert(tree.current_health == 1, "Axe hit should deal bonus chopping damage")

	# Final chop to fell tree
	var felled := [false]
	tree.tree_chopped.connect(func(): felled[0] = true)
	tree.on_hit(1.0, true)
	assert(tree.is_chopped, "Tree should be flagged as chopped")
	assert(felled[0], "tree_chopped signal must emit")

	# Test Torch Ignition on a fresh tree
	var burn_tree := tree_scene.instantiate() as ChoppableTree
	add_child(burn_tree)
	var ignited := [false]
	burn_tree.tree_ignited.connect(func(): ignited[0] = true)
	burn_tree.on_torch_hit()
	assert(burn_tree.is_burning, "Tree should be burning when hit with torch")
	assert(ignited[0], "tree_ignited signal must emit")
	var fire_light: OmniLight3D = burn_tree.get_node_or_null("FireLight")
	assert(fire_light != null and fire_light.visible, "Tree fire light must be visible when burning")
	print("  -> Woodchopping Mechanic & ChoppableTree passed.")

	# 12. Test Wood Resource & Loot Collection
	print("[12/12] Testing Wood Resource & Inventory Collection...")
	var wood_res := load("res://resources/items/wood.tres") as ItemDefinition
	assert(wood_res != null, "wood.tres must load")
	assert(wood_res.item_id == "wood", "wood.tres item_id must be 'wood'")
	assert(wood_res.item_type == ItemDefinition.ItemType.RESOURCE, "wood item_type must be RESOURCE")

	var axe_res := load("res://resources/items/axe.tres") as ItemDefinition
	assert(axe_res != null, "axe.tres must load")
	assert(axe_res.item_id == "stone_axe", "axe.tres item_id must be 'stone_axe'")

	var pickaxe_res := load("res://resources/items/pickaxe.tres") as ItemDefinition
	assert(pickaxe_res != null, "pickaxe.tres must load")
	assert(pickaxe_res.item_id == "stone_pickaxe", "pickaxe.tres item_id must be 'stone_pickaxe'")

	# Test player collecting wood into inventory
	var inv: InventoryComponent = player.inventory
	assert(inv != null, "Player must have InventoryComponent")
	var add_ok := inv.add_item("wood", 4)
	assert(add_ok, "Player inventory should successfully collect wood")
	assert(inv.has_item("wood", 4), "Inventory must contain 4 wood")
	print("  -> Wood Resource & Inventory Collection passed.")

	# 13. Test Animated Campfire (Poly by Google)
	print("[13/15] Testing Animated Campfire (Poly by Google)...")
	var campfire_scene := load("res://scenes/camp/Campfire.tscn") as PackedScene
	assert(campfire_scene != null, "Campfire scene must load")
	var campfire := campfire_scene.instantiate() as Campfire
	add_child(campfire)
	assert(campfire.stones_mesh != null and campfire.stones_mesh.mesh != null, "Campfire must have separate Stones mesh")
	assert(campfire.wood_logs_mesh != null and campfire.wood_logs_mesh.mesh != null, "Campfire must have separate WoodLogs mesh")
	assert(campfire.flames_node != null, "Campfire must have separate Flames node")
	assert(campfire.flame_mesh != null and campfire.flame_mesh.mesh != null, "Campfire flame mesh must be loaded")
	assert(campfire.fire_light != null, "Campfire must have FireLight OmniLight3D")
	assert(campfire.smoke != null, "Campfire must have Smoke particles")
	assert(campfire.has_smoke(), "Campfire smoke must be emitting when lit")
	assert(campfire.is_flame_animated(), "Campfire flame must report as animated")

	# Test toggling stones and wood logs separately
	campfire.set_show_stones(false)
	assert(not campfire.stones_mesh.visible, "Stones should hide when show_stones is false")
	campfire.set_show_stones(true)
	assert(campfire.stones_mesh.visible, "Stones should be visible when show_stones is true")

	campfire.set_show_wood_logs(false)
	assert(not campfire.wood_logs_mesh.visible, "Wood logs should hide when show_wood_logs is false")
	campfire.set_show_wood_logs(true)
	assert(campfire.wood_logs_mesh.visible, "Wood logs should be visible when show_wood_logs is true")

	# Test shader on flame mesh
	var flame_mat := campfire.flame_mesh.get_surface_override_material(0)
	assert(flame_mat is ShaderMaterial, "Campfire flame must use ShaderMaterial for animated vertex flicker")

	# Test dynamic flame breathing scale over time
	campfire._process(0.15)
	var s1 := campfire.flames_node.scale
	campfire._process(0.25)
	var s2 := campfire.flames_node.scale
	assert(s1 != s2, "Campfire flame scale must animate dynamically across frames")

	# Test extinguish and reignite
	campfire.set_lit(false)
	assert(not campfire.flames_node.visible, "Flames should hide when extinguished")
	assert(not campfire.smoke.emitting, "Smoke should stop emitting when extinguished")
	campfire.set_lit(true)
	assert(campfire.flames_node.visible, "Flames should show when reignited")
	assert(campfire.smoke.emitting, "Smoke should resume emitting when reignited")
	print("  -> Animated Campfire with Separated Wood/Flame & Smoke passed.")


	# 14. Test Wood Log Model & Loot Integration (Quaternius)
	print("[14/15] Testing Wood Log Model & Loot Integration (Quaternius)...")
	var log_prop_scene := load("res://scenes/items/WoodLogProp.tscn") as PackedScene
	assert(log_prop_scene != null, "WoodLogProp scene must load")
	var log_prop := log_prop_scene.instantiate()
	add_child(log_prop)
	var log_mesh_inst: MeshInstance3D = log_prop.find_child("MeshInstance3D", true, false)
	assert(log_mesh_inst != null and log_mesh_inst.mesh != null, "WoodLogProp must have Quaternius mesh")
	assert(log_prop.find_child("CollisionShape3D", true, false) != null, "WoodLogProp must have CollisionShape3D")

	# Verify LootItem displays Quaternius wood log when item_id == 'wood'
	var loot_scene := load("res://scenes/items/LootItem.tscn") as PackedScene
	assert(loot_scene != null, "LootItem scene must load")
	var loot := loot_scene.instantiate() as LootItem
	add_child(loot)
	loot.setup("wood", 3)
	var loot_mesh: MeshInstance3D = loot.find_child("MeshInstance3D", true, false)
	assert(loot_mesh != null and loot_mesh.mesh != null, "LootItem must have mesh instance")
	assert(loot_mesh.mesh.resource_path.ends_with("wood_log.obj") or loot_mesh.mesh.get_name() == "wood_log", "LootItem wood must use Quaternius wood log mesh")
	print("  -> Wood Log Model & Loot Integration passed.")

	# 15. Test Poly Tree & Choppable Poly Tree (Poly by Google)
	print("[15/15] Testing Poly Tree & Choppable Poly Tree (Poly by Google)...")
	var polytree_scene := load("res://scenes/nature/PolyTree.tscn") as PackedScene
	assert(polytree_scene != null, "PolyTree scene must load")
	var polytree := polytree_scene.instantiate()
	add_child(polytree)
	var p_mesh: MeshInstance3D = polytree.find_child("MeshInstance3D", true, false)
	assert(p_mesh != null and p_mesh.mesh != null, "PolyTree must have Google Poly tree mesh")

	var choppable_poly_scene := load("res://scenes/items/ChoppablePolyTree.tscn") as PackedScene
	assert(choppable_poly_scene != null, "ChoppablePolyTree scene must load")
	var choppable_poly := choppable_poly_scene.instantiate() as ChoppableTree
	add_child(choppable_poly)
	assert(choppable_poly.current_health == 5, "ChoppablePolyTree initial health should be 5")
	choppable_poly.on_hit(1.0, true)
	assert(choppable_poly.current_health < 5, "ChoppablePolyTree should take axe chopping damage")
	print("  -> Poly Tree & Choppable Poly Tree passed.")

	# 16. Test Jolt Physics Engine & Rat Physics Prop (Quaternius)
	print("[16/16] Testing Jolt Physics Engine & Rat Physics Prop (Quaternius)...")
	var engine_setting: String = ProjectSettings.get_setting("physics/3d/physics_engine", "")
	assert(engine_setting == "Jolt Physics", "Project must use Jolt Physics as 3D physics engine (current: %s)" % engine_setting)

	# Rat Physics Prop
	var rat_scene := load("res://scenes/creatures/RatPhysicsProp.tscn") as PackedScene
	assert(rat_scene != null, "RatPhysicsProp scene must load")
	var rat := rat_scene.instantiate() as RigidBody3D
	assert(rat != null, "RatPhysicsProp must inherit RigidBody3D for Jolt Physics simulation")
	add_child(rat)
	assert(rat.mass > 0.5, "Rat mass should be configured for physical realism")
	assert(rat.physics_material_override != null, "Rat must have PhysicsMaterial override for bounce/friction")
	assert(rat.is_in_group("physics_rats"), "Rat must belong to 'physics_rats' group")
	assert(rat.find_child("CollisionShape3D", true, false) != null, "Rat must have CollisionShape3D")
	var rat_model: Node = rat.find_child("RatModel", true, false)
	assert(rat_model != null, "Rat must have RatModel node containing Quaternius GLB")
	assert(rat.has_method("apply_explosion_impulse"), "Rat must implement apply_explosion_impulse for shockwave blasts")

	# Rat Creature Definition
	var rat_def := load("res://resources/creatures/rat.tres") as CreatureDefinition
	assert(rat_def != null, "rat.tres must load as CreatureDefinition")
	assert(rat_def.creature_name == "Rat", "rat.tres creature_name must be 'Rat'")
	assert(rat_def.display_name == "Cave Rat", "rat.tres display_name must be 'Cave Rat'")
	assert(rat_def.loot_entries.size() > 0, "Rat must have loot entries")

	# Debug Menu Rat Controls
	var debug_scene := load("res://scenes/ui/DebugMenu.tscn") as PackedScene
	assert(debug_scene != null, "DebugMenu scene must load")
	var debug_inst := debug_scene.instantiate()
	add_child(debug_inst)
	assert(debug_inst.find_child("SpawnPhysicsRatBtn", true, false) != null, "DebugMenu must have SpawnPhysicsRatBtn")
	assert(debug_inst.find_child("SpawnSwarmBtn", true, false) != null, "DebugMenu must have SpawnSwarmBtn")
	assert(debug_inst.find_child("ShockwaveBtn", true, false) != null, "DebugMenu must have ShockwaveBtn")
	assert(debug_inst.find_child("SpawnRatCreatureBtn", true, false) != null, "DebugMenu must have SpawnRatCreatureBtn")
	assert(debug_inst.find_child("ClearRatsBtn", true, false) != null, "DebugMenu must have ClearRatsBtn")
	print("  -> Jolt Physics Engine, Rat Prop, Creature Def & Debug Controls passed.")

	# 17. Test Spear Throwing & Ballistic Projectile System
	print("[17/18] Testing Spear Throwing & Ballistic Projectile System...")
	assert(InputMap.has_action("aim"), "InputMap must define 'aim' action (RMB)")

	# ThrownSpear projectile
	var thrown_scene := load("res://scenes/items/ThrownSpear.tscn") as PackedScene
	assert(thrown_scene != null, "ThrownSpear scene must load")
	var spear := thrown_scene.instantiate() as ThrownSpear
	assert(spear != null, "ThrownSpear must inherit RigidBody3D for Jolt ballistic simulation")
	add_child(spear)
	assert(spear.continuous_cd, "ThrownSpear must use continuous collision detection (CCD)")
	assert(spear.mass >= 1.0, "ThrownSpear mass should be realistic")
	assert(spear.find_child("SpearMesh", true, false) != null, "ThrownSpear must contain 3D SpearMesh")
	assert(spear.find_child("CollisionShape3D", true, false) != null, "ThrownSpear must have CollisionShape3D")
	assert(spear.interactable_comp != null, "ThrownSpear must have InteractableComponent for retrieval")

	# Launch test
	spear.launch(Vector3(0, 1.5, 0), Vector3.FORWARD, 28.0)
	assert(spear.linear_velocity.length() > 20.0, "Spear launch must impart ballistic velocity")

	# Stick & Retrieval test
	spear._stick_to_target(null, Vector3(0, 1.0, -10), Vector3.FORWARD)
	assert(spear.is_embedded, "Spear must report is_embedded = true after hitting surface")
	assert(spear.freeze, "Spear must freeze physics body when embedded")
	assert(spear.can_be_retrieved, "Embedded spear must be retrievable")
	spear.retrieve(player)
	assert(player.inventory.has_item("flint_spear", 1), "Player inventory must receive retrieved flint_spear")

	# Viewmodel Aim & Throw State Machine
	vm.switch_tool(FirstPersonViewmodel.ToolType.SPEAR, true)
	var aim_ok := vm.start_spear_aim()
	assert(aim_ok, "start_spear_aim() must succeed when SPEAR is active")
	assert(vm.is_aiming_spear, "vm.is_aiming_spear must be true")
	vm.cancel_spear_aim()
	assert(not vm.is_aiming_spear, "cancel_spear_aim() must reset is_aiming_spear")
	vm.start_spear_aim()
	var throw_launched := [false]
	var throw_ok := vm.throw_spear(func(): throw_launched[0] = true)
	assert(throw_ok, "throw_spear() must execute from aim stance")

	# Modular model retains a stable gameplay-facing action API even though its
	# presentation animation is procedural until the authored lanky rig arrives.
	model.play_action("spear_throw")
	print("  -> Spear Throwing & Ballistic Projectile System passed.")

	# 18. Test Uneven Basecamp Terrain & Spear Target Testing Ground
	print("[18/18] Testing Uneven Basecamp Terrain & Testing Ground Targets...")
	var terrain := BasecampTerrain.new()
	add_child(terrain)
	assert(terrain is StaticBody3D, "BasecampTerrain must inherit StaticBody3D")
	var t_mesh_inst: MeshInstance3D = terrain.find_child("MeshInstance3D", true, false)
	assert(t_mesh_inst != null and t_mesh_inst.mesh != null, "BasecampTerrain must generate procedural ArrayMesh")
	var t_mesh: ArrayMesh = t_mesh_inst.mesh as ArrayMesh
	assert(t_mesh.get_surface_count() > 0, "BasecampTerrain mesh must have surfaces")
	var t_col: CollisionShape3D = terrain.find_child("CollisionShape3D", true, false)
	assert(t_col != null and t_col.shape != null, "BasecampTerrain must generate Jolt collision shape")

	# SpearTarget
	var target_scene := load("res://scenes/camp/SpearTarget.tscn") as PackedScene
	assert(target_scene != null, "SpearTarget scene must load")
	var target := target_scene.instantiate() as SpearTarget
	add_child(target)
	assert(target.is_in_group("targets"), "SpearTarget must belong to 'targets' group")
	var score_bullseye := target.on_spear_hit(target.global_position + Vector3(0, 1.4, 0))
	assert(score_bullseye == 100, "Center hit on SpearTarget must score 100 bullseye (got: %d)" % score_bullseye)
	var score_outer := target.on_spear_hit(target.global_position + Vector3(0.45, 1.4, 0))
	assert(score_outer == 25, "Outer hit on SpearTarget must score 25 (got: %d)" % score_outer)

	# TribeCamp TestingGround integration
	assert(camp.find_child("TestingGround", true, false) != null, "TribeCamp must contain TestingGround node")
	assert(camp.find_child("SpearTarget1", true, false) != null, "TribeCamp must have SpearTarget1")
	assert(camp.find_child("SpearTarget2", true, false) != null, "TribeCamp must have SpearTarget2")
	var camp_ground := camp.get_node_or_null("Ground")
	assert(camp_ground != null and camp_ground.get_script() == BasecampTerrain, "TribeCamp Ground must use BasecampTerrain script")
	print("  -> Uneven Basecamp Terrain & Testing Ground Targets passed.")

	# 19. Test Modular Weapon Visual & Stat Upgrades (Club Tiers 1-4)
	print("[19/19] Testing Modular Weapon Visual & Stat Upgrades (Club T1-T4)...")
	var vm_upgrade := FirstPersonViewmodel.new()
	add_child(vm_upgrade)
	vm_upgrade.set_tool(FirstPersonViewmodel.ToolType.CLUB)
	assert(vm_upgrade.club_mesh != null, "Viewmodel must have ClubMesh")
	assert(vm_upgrade.club_t2_mesh != null and vm_upgrade.club_t2_mesh.mesh != null, "Club must have Tier 2 attachment mesh")
	assert(vm_upgrade.club_t3_mesh != null and vm_upgrade.club_t3_mesh.mesh != null, "Club must have Tier 3 attachment mesh")
	assert(vm_upgrade.club_t4_mesh != null and vm_upgrade.club_t4_mesh.mesh != null, "Club must have Tier 4 attachment mesh")

	# Test Tier 1 (Crude)
	ProgressionManager.set_weapon_tier("club", 1)
	vm_upgrade.apply_weapon_tier("club", 1)
	assert(not vm_upgrade.club_t2_mesh.visible, "T1 club should not show T2 spikes")
	assert(not vm_upgrade.club_t3_mesh.visible, "T1 club should not show T3 obsidian")
	assert(not vm_upgrade.club_t4_mesh.visible, "T1 club should not show T4 totem")
	assert(is_equal_approx(vm_upgrade.melee_damage, 32.0), "T1 club damage should be 32.0 (got: %f)" % vm_upgrade.melee_damage)

	# Test Tier 2 (Bone Spikes)
	ProgressionManager.set_weapon_tier("club", 2)
	vm_upgrade.apply_weapon_tier("club", 2)
	assert(vm_upgrade.club_t2_mesh.visible, "T2 club must show bone spikes")
	assert(not vm_upgrade.club_t3_mesh.visible, "T2 club should not show T3 obsidian")
	assert(is_equal_approx(vm_upgrade.melee_damage, 48.0), "T2 club damage should be 48.0 (got: %f)" % vm_upgrade.melee_damage)

	# Test Tier 3 (Obsidian Cleaver)
	ProgressionManager.set_weapon_tier("club", 3)
	vm_upgrade.apply_weapon_tier("club", 3)
	assert(not vm_upgrade.club_t2_mesh.visible, "T3 club should hide T2 spikes")
	assert(vm_upgrade.club_t3_mesh.visible, "T3 club must show obsidian blades")
	assert(is_equal_approx(vm_upgrade.melee_damage, 65.0), "T3 club damage should be 65.0 (got: %f)" % vm_upgrade.melee_damage)

	# Test Tier 4 (Chieftain Totem)
	ProgressionManager.set_weapon_tier("club", 4)
	vm_upgrade.apply_weapon_tier("club", 4)
	assert(not vm_upgrade.club_t3_mesh.visible, "T4 club should hide T3 obsidian")
	assert(vm_upgrade.club_t4_mesh.visible, "T4 club must show volcanic totem attachments")
	assert(is_equal_approx(vm_upgrade.melee_damage, 85.0), "T4 club damage should be 85.0 (got: %f)" % vm_upgrade.melee_damage)

	# Test Target Damage Popup with upgraded club
	target.on_hit(vm_upgrade.melee_damage)
	var found_popup := false
	for child in target.get_children():
		if child is Label3D and "85 DMG" in child.text:
			found_popup = true
			break
	assert(found_popup, "SpearTarget must spawn 3D damage popup showing 85 DMG on T4 hit")

	# Reset weapon tier
	ProgressionManager.set_weapon_tier("club", 1)
	print("  -> Modular Weapon Visual & Stat Upgrades (Club T1-T4) passed.")

	# 20. Test Solid TribeCamp Ground Physics & Void Fall Prevention
	print("[20/20] Testing Solid TribeCamp Ground Physics & Void Fall Prevention...")
	var camp_test_scene := load("res://scenes/camp/TribeCamp.tscn") as PackedScene
	assert(camp_test_scene != null, "TribeCamp scene must load")
	var sim_camp := camp_test_scene.instantiate() as Node3D
	add_child(sim_camp)

	# Simulate 30 physics frames for gravity and collision resolution
	for f in range(30):
		await get_tree().physics_frame

	# Check that player and all props are firmly grounded and none fell into the void
	var void_falls := 0
	var grounded_props := 0
	for node in sim_camp.find_children("*", "RigidBody3D", true, false):
		var y_pos: float = (node as Node3D).global_position.y
		if y_pos < -2.0:
			void_falls += 1
		else:
			grounded_props += 1

	for node in sim_camp.find_children("*", "CharacterBody3D", true, false):
		var y_pos: float = (node as Node3D).global_position.y
		if y_pos < -2.0:
			void_falls += 1
		else:
			grounded_props += 1

	assert(void_falls == 0, "No physics bodies should fall through ground into void (got: %d fell)" % void_falls)
	assert(grounded_props > 0, "Rigid bodies and player must be resting on ground (found: %d)" % grounded_props)
	sim_camp.queue_free()
	print("  -> Solid TribeCamp Ground Physics passed (%d bodies firmly grounded, 0 void falls)." % grounded_props)

	# 21. Test InventoryMenu (Tab grid, Use consumable, Drop loot)
	print("[21/23] Testing InventoryMenu (grid, eat, drop)...")
	var inv_menu := player.get_node_or_null("FirstPersonHUD/InventoryMenu")
	assert(inv_menu != null, "Player must code-instance InventoryMenu for local authority")
	inv_menu.open_menu()
	assert(inv_menu.is_open(), "InventoryMenu must open")
	assert(inv_menu.get_item_count() == player.inventory.get_all_items().size(), "Grid rows must match carried item types")
	var had_wood: int = player.inventory.get_quantity("wood")
	assert(had_wood > 0, "Test player should carry wood by now")
	player.inventory.add_item("roast_meat", 1)
	await get_tree().process_frame
	assert(inv_menu.get_item_count() == player.inventory.get_all_items().size(), "Grid must refresh on pickup")
	# Eat roast meat: wound then heal.
	player.current_health = 50.0
	inv_menu._select("roast_meat")
	assert(inv_menu.use_selected(), "use_selected must eat roast meat")
	assert(player.inventory.get_quantity("roast_meat") == 0, "Eaten meat must leave the pack")
	assert(player.current_health > 50.0, "Eating roast meat must heal")
	# Drop one wood: spawns a LootItem ahead and removes it from the pack.
	inv_menu._select("wood")
	var loot_before := get_tree().current_scene.find_children("LootItem*", "", true, false).size()
	assert(inv_menu.drop_selected(), "drop_selected must toss a LootItem")
	assert(player.inventory.get_quantity("wood") == had_wood - 1, "Dropped wood must leave the pack")
	await get_tree().process_frame
	var loot_after := get_tree().current_scene.find_children("LootItem*", "", true, false).size()
	assert(loot_after == loot_before + 1, "Drop must spawn exactly one LootItem")
	inv_menu.toggle()
	assert(not inv_menu.is_open(), "Tab toggle must close the menu")
	print("  -> InventoryMenu passed.")

	# 22. Test CraftingMenu (stockpile recipes, grant, failure path)
	print("[22/23] Testing CraftingMenu (recipes, stockpile, glow charge)...")
	var craft_scene := load("res://scenes/ui/CraftingMenu.tscn") as PackedScene
	assert(craft_scene != null, "CraftingMenu scene must load")
	var craft_menu := craft_scene.instantiate()
	add_child(craft_menu)
	assert(craft_menu.get_recipe_count() == 3, "Must load 3 camp recipes")
	var saved_stock: Dictionary = ProgressionManager.stored_resources.duplicate()
	ProgressionManager.stored_resources = {"meat": 2, "wood": 3, "flint": 1, "crystal": 1}
	craft_menu.open_for(player)
	assert(craft_menu.is_open(), "CraftingMenu must open for the player")
	var meat_had: int = player.inventory.get_quantity("roast_meat")
	assert(craft_menu.craft_by_id("roast_meat"), "Roast meat craft must succeed when stocked")
	assert(player.inventory.get_quantity("roast_meat") == meat_had + 1, "Crafted meat must reach the pack")
	assert(int(ProgressionManager.stored_resources.get("meat", 0)) == 1, "Craft must consume stockpile meat")
	# Glow charge refills a spent rock.
	player.glow_system.current_rocks = 2
	assert(craft_menu.craft_by_id("glow_charge"), "Glow charge must succeed when stocked")
	assert(player.glow_system.current_rocks == 3, "Glow charge must restore one rock")
	player.glow_system.current_rocks = GlowRockSystem.MAX_ROCKS
	assert(not craft_menu.can_craft("glow_charge"), "Glow charge must refuse when rocks are full")
	# Failure path: empty stockpile crafts nothing.
	ProgressionManager.stored_resources = {}
	assert(not craft_menu.craft_by_id("flint_spear"), "Craft must fail without materials")
	craft_menu.close_menu()
	assert(not craft_menu.is_open(), "CraftingMenu must close")
	ProgressionManager.stored_resources = saved_stock
	craft_menu.queue_free()
	print("  -> CraftingMenu passed.")

	# 23. Test MapMenu (regions, dungeon schematic, player marker)
	print("[23/23] Testing MapMenu (regions + cave chart)...")
	var map_menu := player.get_node_or_null("FirstPersonHUD/MapMenu")
	assert(map_menu != null, "Player must code-instance MapMenu for local authority")
	map_menu.open_menu()
	assert(map_menu.is_open(), "MapMenu must open")
	assert(map_menu.get_region_count() == 4, "Must list 4 tribe regions")
	assert(map_menu.get_unlocked_count() >= 1, "At least shallow_caves must be unlocked")
	assert("shallow_caves" in ProgressionManager.unlocked_regions, "shallow_caves must stay unlocked")
	var chart := DungeonData.new()
	var room_a := DungeonData.RoomData.new()
	room_a.id = 0
	room_a.type = DungeonData.RoomType.ENTRANCE
	room_a.world_position = Vector3.ZERO
	room_a.size = Vector2(12, 12)
	var room_b := DungeonData.RoomData.new()
	room_b.id = 1
	room_b.type = DungeonData.RoomType.EXTRACTION
	room_b.world_position = Vector3(16, 0, 0)
	room_b.size = Vector2(12, 12)
	chart.add_room(room_a)
	chart.add_room(room_b)
	var corr := DungeonData.CorridorData.new()
	corr.from_room_id = 0
	corr.to_room_id = 1
	corr.start_pos = Vector3.ZERO
	corr.end_pos = Vector3(16, 0, 0)
	chart.add_corridor(corr)
	chart.extraction_point = Vector3(16, 0, 0)
	map_menu.set_test_data(chart)
	var marker: Vector2 = map_menu.get_player_marker()
	var expected := Vector2(player.global_position.x, player.global_position.z)
	assert(marker.is_equal_approx(expected), "Player marker must track the local player")
	map_menu.toggle()
	assert(not map_menu.is_open(), "M toggle must close the map")
	print("  -> MapMenu passed.")
	print("==================================================")
	get_tree().quit(0)


