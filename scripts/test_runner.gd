extends Node

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

	# 2. Test CavemanModel
	print("[2/10] Testing CavemanModel...")
	var model_scene := load("res://scenes/character/CavemanModel.tscn") as PackedScene
	assert(model_scene != null, "CavemanModel scene should load")
	var model := model_scene.instantiate() as CavemanModel
	add_child(model)
	model.apply_customization(data)
	assert(model.torso != null, "Torso should be generated")
	assert(model.head != null, "Head should be generated")
	assert(model.mat_skin.albedo_color.is_equal_approx(data.skin_color), "Skin material color should match")
	var obj_mesh := load("res://assets/models/character/caveman.obj") as Mesh
	assert(obj_mesh != null, "caveman.obj should load as Mesh")
	print("  -> CavemanModel passed.")

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

	assert(camp.get_node_or_null("PerimeterScenery/StoneWheelMonument1") != null, "StoneWheelMonument1 must exist")
	assert(camp.get_node_or_null("PerimeterScenery/StoneWheelMonument2") != null, "StoneWheelMonument2 must exist")
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

	# 10. Test Arsenal Weapon Switching (Pickaxe, Spear, Club, Torch)
	print("[10/10] Testing Prehistoric Weapon Switching & Stats...")
	# Initial tool is Pickaxe
	assert(vm.current_tool == FirstPersonViewmodel.ToolType.PICKAXE, "Initial tool must be PICKAXE")
	assert(vm.pickaxe_mesh.visible, "Pickaxe mesh must be visible")
	assert(not vm.spear_mesh.visible, "Spear mesh must be hidden initially")

	# Switch to Spear
	vm.switch_tool(FirstPersonViewmodel.ToolType.SPEAR, true)
	assert(vm.current_tool == FirstPersonViewmodel.ToolType.SPEAR, "Current tool must be SPEAR")
	assert(vm.spear_mesh.visible, "Spear mesh must be visible")
	assert(not vm.pickaxe_mesh.visible, "Pickaxe mesh must be hidden when Spear is active")
	assert(vm.reach >= 3.5, "Spear reach must be at least 3.5m")
	assert(vm.get_current_tool_name() == "Flint Spear", "Tool name must be Flint Spear")

	# Switch to Club
	vm.switch_tool(FirstPersonViewmodel.ToolType.CLUB, true)
	assert(vm.current_tool == FirstPersonViewmodel.ToolType.CLUB, "Current tool must be CLUB")
	assert(vm.club_mesh.visible, "Club mesh must be visible")
	assert(vm.melee_damage >= 30.0, "Club damage must be at least 30")

	# Switch to Torch
	vm.switch_tool(FirstPersonViewmodel.ToolType.TORCH, true)
	assert(vm.current_tool == FirstPersonViewmodel.ToolType.TORCH, "Current tool must be TORCH")
	assert(vm.torch_mesh.visible, "Torch mesh must be visible")
	assert(vm.torch_light.visible, "Torch light must be visible when Torch is active")

	# Cycle back to Pickaxe
	vm.switch_tool(FirstPersonViewmodel.ToolType.PICKAXE, true)
	assert(vm.current_tool == FirstPersonViewmodel.ToolType.PICKAXE, "Current tool must restore to PICKAXE")
	assert(not vm.torch_light.visible, "Torch light must turn off when switching away")
	print("  -> Prehistoric Weapon Switching & Stats passed.")

	print("==================================================")
	print("--- ALL 10 VERIFICATION TESTS PASSED! ---")
	print("==================================================")
	get_tree().quit(0)
