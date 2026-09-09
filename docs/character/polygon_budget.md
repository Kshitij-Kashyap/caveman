# Base Caveman — Triangle Budget

Locked constants live in `scripts/character/CavemanRig.gd`
(`TRIANGLE_BUDGET = 4500`, min 2500 / max 6000).

## Why ~4500 triangles

- 4 players visible + multiple creatures + active ragdolls + a crowded
  camp + procedural cave props must hold 120 FPS on modest hardware
  (see project performance panel: 1.2 ms physics, 412 draw calls budget).
- One character at ~4500 tris = ~18k tris for a full co-op party, a
  fraction of a single cave room mesh. Ragdoll bodies are 7 primitives
  (boxes/capsules/sphere) — physics cost dominates, not render cost.
- The fallback procedural caveman (`tools/generate_lowpoly_caveman.py`,
  `part_*.obj` + `caveman.obj`) lands at roughly 2–3k triangles; the
  Rafael rigged GLB (`assets/models/character/rafael/rigged_character.glb`,
  vertex-colored, 52 bones) is denser but still inside the 6k ceiling.

## Rule

Do NOT chase a minimum triangle count at the expense of deformation.
Shoulders, elbows, wrists, hips, knees, neck and jaw keep enough edge
loops to bend cleanly. If a nicer silhouette needs +500 tris, take it —
stay under 6000 and note the reason here.
