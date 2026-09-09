## CavemanRig.gd
## Canonical humanoid rig definition for the Cave Raiders base caveman.
## Maps the spec bone names (Root/Pelvis/Spine/...) to the runtime Mixamo
## skeleton inside rigged_character.glb, documents world scale, polygon
## budget and ragdoll body mapping. No gameplay logic here — pure data.
##
## Spec rig:
##   Root -> Pelvis -> Spine -> Chest -> Neck -> Head
##   Chest -> Shoulder.L/R -> UpperArm -> LowerArm -> Hand
##   Root -> UpperLeg.L/R -> LowerLeg -> Foot

class_name CavemanRig
extends Node3D

# ---------------------------------------------------------------------------
# World scale (meters, Godot units). LOCKED — doors/caves/props use this.
# ---------------------------------------------------------------------------
const CHARACTER_HEIGHT: float = 1.80
const EYE_HEIGHT: float = 1.65
const SHOULDER_WIDTH: float = 0.62
const HAND_SIZE: Vector3 = Vector3(0.20, 0.22, 0.10)
const FOOT_SIZE: Vector3 = Vector3(0.20, 0.12, 0.34)
const HEAD_RADIUS: float = 0.26

# ---------------------------------------------------------------------------
# Polygon budget (approximate triangles, entire character incl. face/hair)
# ---------------------------------------------------------------------------
const TRIANGLE_BUDGET: int = 4500
const TRIANGLE_BUDGET_MIN: int = 2500
const TRIANGLE_BUDGET_MAX: int = 6000

# ---------------------------------------------------------------------------
# Canonical bone order (spec section 10)
# ---------------------------------------------------------------------------
const CANONICAL_BONES: Array[String] = [
	"Root",
	"Pelvis",
	"Spine",
	"Chest",
	"Neck",
	"Head",
	"LeftShoulder",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightShoulder",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
]

# Mixamo (rafael rigged_character.glb, 52 bones) -> canonical mapping.
# Missing shoulders map to the upper-arm chain start; this keeps ONE
# skeleton for animation + ragdoll (spec section 11).
const MIXAMO_MAP: Dictionary = {
	"Root": "mixamorig_Hips",
	"Pelvis": "mixamorig_Hips",
	"Spine": "mixamorig_Spine",
	"Chest": "mixamorig_Spine1",
	"Neck": "mixamorig_Neck",
	"Head": "mixamorig_Head",
	"LeftShoulder": "mixamorig_LeftShoulder",
	"LeftUpperArm": "mixamorig_LeftArm",
	"LeftLowerArm": "mixamorig_LeftForeArm",
	"LeftHand": "mixamorig_LeftHand",
	"RightShoulder": "mixamorig_RightShoulder",
	"RightUpperArm": "mixamorig_RightArm",
	"RightLowerArm": "mixamorig_RightForeArm",
	"RightHand": "mixamorig_RightHand",
	"LeftUpperLeg": "mixamorig_LeftUpLeg",
	"LeftLowerLeg": "mixamorig_LeftLeg",
	"LeftFoot": "mixamorig_LeftFoot",
	"RightUpperLeg": "mixamorig_RightUpLeg",
	"RightLowerLeg": "mixamorig_RightLeg",
	"RightFoot": "mixamorig_RightFoot",
}

# Canonical bone -> CharacterRagdoll proxy body node name.
const RAGDOLL_MAP: Dictionary = {
	"Pelvis": "Pelvis",
	"Spine": "Chest",
	"Chest": "Chest",
	"Neck": "Head",
	"Head": "Head",
	"LeftUpperArm": "ArmL",
	"LeftLowerArm": "ArmL",
	"LeftHand": "ArmL",
	"RightUpperArm": "ArmR",
	"RightLowerArm": "ArmR",
	"RightHand": "ArmR",
	"LeftUpperLeg": "LegL",
	"LeftLowerLeg": "LegL",
	"LeftFoot": "LegL",
	"RightUpperLeg": "LegR",
	"RightLowerLeg": "LegR",
	"RightFoot": "LegR",
}

# Animation states every caveman must expose (spec section 13).
const ANIMATION_STATES: Array[String] = [
	"idle",
	"walk",
	"run",
	"jump",
	"fall",
	"land",
	"attack",
	"spear_throw",
	"ragdoll_down",
	"ragdoll_recover",
]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
static func mixamo_bone(canonical: String) -> String:
	return str(MIXAMO_MAP.get(canonical, ""))

static func ragdoll_body(canonical: String) -> String:
	return str(RAGDOLL_MAP.get(canonical, ""))

## Resolve a canonical bone index on a runtime Skeleton3D. Returns -1 if absent.
static func canonical_bone_index(skel: Skeleton3D, canonical: String) -> int:
	if skel == null:
		return -1
	var mixamo := mixamo_bone(canonical)
	if mixamo.is_empty():
		return -1
	return skel.find_bone(mixamo)
