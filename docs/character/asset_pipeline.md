# Cave Raiders Character — Asset Pipeline

## Procedural stylized model → Godot (current default)

`CavemanModel` now defaults to the modular procedural mesh. It is the
canonical character language: elongated limbs, a large faceted head, giant
readable eyes, primitive clothing blocks, and a deliberately awkward stance.
`EvolutionStageDefinition` changes only visual presentation (Stage 1–5), while
`CharacterCustomizationData` keeps skin, hair, clothing, and accent colors
across every stage. `CharacterVisualController` is the bridge for a future
PlayerData owner; it never owns stats or inventory.

## External model → Godot (legacy compatibility path)

1. Model + rig + skin + draft animations are authored externally and
   exported as `assets/models/character/rafael/rigged_character.glb`
   (Y-up, meters, ~1.85 m tall, vertex COLOR used for body-part masks).
2. `tools/download_character.py` fetches the source asset; do not commit
   large sources, only the exported `.glb` (+ `.import`).
3. Godot imports the GLB untouched: Skeleton3D (52 Mixamo bones),
   mesh (single `Cube` surface), no embedded animations required —
   `CavemanModel._setup_character_animations()` + `_setup_extended_animations()`
   generate the placeholder set procedurally (`idle walk run jump fall
   land attack spear_throw ragdoll_down ragdoll_recover`).
4. `shaders/character_rigged.gdshader` recolors body parts from the vertex
   COLOR mask via `skin/clothing/pants/boots_color` uniforms, fed by
   `CavemanModel.apply_customization(CharacterCustomizationData)`.
5. Scale/orientation fix lives in one place:
   `CavemanModel._build_rigged_character()` (scale 0.185 → 1.85 m,
   rotated 180° to face -Z). If the source export changes, fix it there.

## Procedural fallback path (no external asset needed)

`tools/generate_lowpoly_caveman.py` → `caveman.obj` + `part_*.obj` +
`caveman.mtl` (material slots `mat_skin/hair/clothing/accent/eyes_*`). It is
the default. Set `CavemanModel.use_rigged_character = true` only for the
legacy imported rig. Pivots
(head/arms/legs) are baked as local origins so idle-bob/walk code and
the ragdoll proxy keep working.

## Reusable scene

`scenes/character/Caveman.tscn` (script `Caveman.gd`) is the canonical
asset: `CharacterVisual` + `FirstPersonVisual` (arms + `HeldItemSocket`)
+ `AnimationTree` (built at runtime by `CavemanAnimator` from the
AnimationPlayer) + `RagdollComponent`. Gameplay `CharacterBody3D`
(`Player.tscn`) stays separate and references this visual.

## Validation (must stay green)

- `scenes/character/tests/CharacterShowcase.tscn`
- `scenes/character/tests/CharacterCustomizationTest.tscn`
- `scenes/character/tests/FirstPersonTest.tscn`
- `scenes/character/tests/RagdollTest.tscn`
- `scenes/character/tests/AnimationTest.tscn`
- Headless regression: `scenes/test_runner.tscn`
