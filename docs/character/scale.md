# Base Caveman — World Scale (LOCKED)

Do NOT change these without updating doors, caves, props, creatures,
camp stations, procedural rooms and weapons. Constants are duplicated in
`scripts/character/CavemanRig.gd` — that file is authoritative.

| Measure              | Value                        |
|----------------------|------------------------------|
| Character height     | 1.80 m (feet → crown)        |
| Eye / camera height  | 1.65 m (`FirstPersonCamera.eye_height`) |
| Collision capsule    | r=0.40, h=1.80 (`Player.tscn`) |
| Shoulder width       | ~0.62 m                      |
| Hand size            | 0.20 × 0.22 × 0.10 m         |
| Foot size            | 0.20 × 0.12 × 0.34 m         |
| Head radius          | ~0.26 m (oversized, goofy)   |

Derived rules of thumb: doors ≥ 1.1 m wide × 2.2 m tall, cave tunnels ≥
2.5 m diameter, camp station interaction range ≤ 3.2 m (matches
`InteractRaycast`), spear reach 3.6 m, melee reach ~2.0–2.4 m.
