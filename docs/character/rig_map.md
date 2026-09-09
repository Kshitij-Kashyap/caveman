# Base Caveman — Rig Map

Canonical bones (spec section 10) → runtime Mixamo bones in
`assets/models/character/rafael/rigged_character.glb` (52 bones).
Mapping lives in `CavemanRig.MIXAMO_MAP`; ragdoll bodies in `RAGDOLL_MAP`.

| Canonical      | Mixamo bone            | Ragdoll body |
|----------------|------------------------|--------------|
| Root           | mixamorig_Hips         | —            |
| Pelvis         | mixamorig_Hips         | Pelvis       |
| Spine          | mixamorig_Spine        | Chest        |
| Chest          | mixamorig_Spine1       | Chest        |
| Neck           | mixamorig_Neck         | Head         |
| Head           | mixamorig_Head         | Head         |
| LeftShoulder   | mixamorig_LeftShoulder | ArmL         |
| LeftUpperArm   | mixamorig_LeftArm      | ArmL         |
| LeftLowerArm   | mixamorig_LeftForeArm  | ArmL         |
| LeftHand       | mixamorig_LeftHand     | ArmL         |
| RightShoulder  | mixamorig_RightShoulder| ArmR         |
| RightUpperArm  | mixamorig_RightArm     | ArmR         |
| RightLowerArm  | mixamorig_RightForeArm | ArmR         |
| RightHand      | mixamorig_RightHand    | ArmR         |
| LeftUpperLeg   | mixamorig_LeftUpLeg    | LegL         |
| LeftLowerLeg   | mixamorig_LeftLeg      | LegL         |
| LeftFoot       | mixamorig_LeftFoot     | LegL         |
| RightUpperLeg  | mixamorig_RightUpLeg   | LegR         |
| RightLowerLeg  | mixamorig_RightLeg     | LegR         |
| RightFoot      | mixamorig_RightFoot    | LegR         |

One skeleton serves animation + ragdoll (spec section 11): the same
`Skeleton3D` drives the `AnimationPlayer`/`AnimationTree` states and the
`CharacterRagdoll` proxy bodies copy its bones. Never build a second,
incompatible ragdoll skeleton.

Resolve at runtime with `CavemanRig.canonical_bone_index(skeleton, "Head")`.
