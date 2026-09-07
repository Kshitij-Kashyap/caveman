extends Node

func _ready() -> void:
	print("==================================================")
	print("--- BEGIN VISUAL FOUNDATION & CAMP VERIFICATION ---")
	print("==================================================")

	# 1. Test CharacterCustomizationData
	print("[1/9] Testing CharacterCustomizationData...")
	var data := CharacterCustomizationData.get_default()
	assert(data != null, "Default data should not be null")
	data.skin_color = Color(0.9, 0.2, 0.1, 1.0)
	var save_res := data.save_to_file("user://test_customization.json")
	assert(save_res == OK, "Saving customization should succeed")
	var loaded := CharacterCustomizationData.load_or_create("user://test_customization.json")
	assert(loaded.skin_color.is_equal_approx(data.skin_color), "Loaded skin color should match saved")
	print("  -> CharacterCustomizationData passed.")

	# 2. Test CavemanModel
	print("[2/9] Testing CavemanModel...")
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
	print("[3/9] Testing CharacterPreview with sunny 3D camp scene...")
	var preview_scene := load("res://scenes/character/CharacterPreview.tscn") as PackedScene
	assert(preview_scene != null, "CharacterPreview scene should load")
	var preview := preview_scene.instantiate() as CharacterPreview
	add_child(preview)
	preview.update_customization(data)
	assert(preview.find_child("PalmTree1", true, false) != null, "PalmTree1 must exist in preview")
	assert(preview.find_child("Campfire", true, false) != null, "Campfire must exist in preview")
	print("  -> CharacterPreview passed.")

	# 4. Test Player & Ragdoll
	print("[4/9] Testing Player & CharacterRagdoll...")
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
	print("[5/9] Testing MainMenu scene...")
	var menu_scene := load("res://scenes/main_menu/MainMenu.tscn") as PackedScene
	assert(menu_scene != null, "MainMenu scene should load")
	var menu := menu_scene.instantiate()
	add_child(menu)
	print("  -> MainMenu scene passed.")

	# 6. Test HUD scene
	print("[6/9] Testing HUD scene...")
	var hud_scene := load("res://scenes/ui/HUD.tscn") as PackedScene
	assert(hud_scene != null, "HUD scene should load")
	var hud := hud_scene.instantiate()
	add_child(hud)
	print("  -> HUD scene passed.")

	# 7. Test TribeCamp scene & All 7 Stations + Great Bonfire
	print("[7/9] Testing TribeCamp scene & Stations...")
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

	assert(camp.get_node_or_null("CampHUD") != null, "CampHUD must exist")
	assert(camp.get_node_or_null("PerimeterScenery") != null, "PerimeterScenery must exist")
	print("  -> TribeCamp scene & Stations passed.")

	# 8. Test Physics Props & OBJ Models
	print("[8/9] Testing Camp Low-Poly Models & Physics Props...")
	var props_node := camp.get_node_or_null("Props")
	assert(props_node != null, "Props container must exist")
	var prop_count := props_node.get_child_count()
	assert(prop_count > 0, "Props container must contain spawned physics props")
	for child in props_node.get_children():
		assert(child is RigidBody3D, "Prop child must be RigidBody3D")
		var rb := child as RigidBody3D
		assert(rb.find_child("*MeshInstance3D*", true, false) != null, "Prop must have a MeshInstance3D")
	print("  -> Camp Physics Props passed (spawned: %d props)." % prop_count)

	# 9. Test First-Person Controls, Viewmodel & Reticle
	print("[9/9] Testing First-Person Controls, Viewmodel & Reticle...")
	assert(player.head_pitch_pivot != null, "HeadPitchPivot must exist")
	assert(player.camera != null, "Camera3D must exist")
	assert(player.camera.current, "Camera3D must be current for local player")
	assert(player.interact_ray != null, "InteractRaycast must exist")
	assert(player.interact_ray.collide_with_areas, "InteractRaycast must collide with areas")
	assert(player.viewmodel != null, "FirstPersonViewmodel must exist")
	assert(player.crosshair != null, "Crosshair must exist")

	var vm := player.viewmodel
	assert(vm.arm_mesh != null and vm.arm_mesh.mesh != null, "Viewmodel arm mesh must be loaded")
	assert(vm.pickaxe_mesh != null and vm.pickaxe_mesh.mesh != null, "Viewmodel pickaxe mesh must be loaded")

	vm.apply_customization(data)
	assert(vm.mat_skin.albedo_color.is_equal_approx(data.skin_color), "Viewmodel arm skin color must match customization")

	vm.add_sway(Vector2(15.0, -10.0))
	assert(vm._sway_offset.length_squared() > 0.0, "Mouse motion must produce weapon sway")

	var swing_received := [false]
	vm.swing_started.connect(func(): swing_received[0] = true)
	var swung := vm.try_swing()
	assert(swung, "try_swing must return true")
	assert(swing_received[0], "swing_started signal must emit")

	var ch := player.crosshair
	ch.show_prompt("E", "Examine Great Bonfire", "interact")
	assert(ch.prompt_pill.visible, "Crosshair prompt pill must be visible")
	ch.trigger_hit_marker()
	ch.hide_prompt()
	assert(not ch.prompt_pill.visible, "Crosshair prompt pill must hide")

	var mouse_event := InputEventMouseMotion.new()
	mouse_event.relative = Vector2(40.0, -25.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	player._unhandled_input(mouse_event)
	assert(player.rotation.y != 0.0, "Mouse motion must rotate player body yaw")
	assert(player._camera_pitch != 0.0, "Mouse motion must tilt head pitch")

	# Test ragdoll camera switch and first-person restoral
	player.enable_ragdoll(Vector3(0, 4, -4))
	assert(player.is_ragdoll, "Player must enter ragdoll")
	assert(player.camera.position != Vector3.ZERO, "Camera must push back for third-person tumble")
	assert(not player.viewmodel.visible, "Viewmodel must hide in ragdoll")
	assert(not player.crosshair.visible, "Crosshair must hide in ragdoll")

	player.disable_ragdoll()
	assert(not player.is_ragdoll, "Player must recover from ragdoll")
	assert(player.camera.position == Vector3.ZERO, "Camera must restore to first-person eye position")
	assert(player.viewmodel.visible, "Viewmodel must restore in first-person")
	assert(player.crosshair.visible, "Crosshair must restore in first-person")
	print("  -> First-Person Controls, Viewmodel & Reticle passed.")

	print("==================================================")
	print("--- ALL 9 VERIFICATION TESTS PASSED! ---")
	print("==================================================")
	get_tree().quit(0)
