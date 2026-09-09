# Cave Raiders Character Direction

The player is a strange, charismatic, low-poly, slightly lanky caveman—not a
realistic human and not a rounded toy character. The silhouette is the asset:
large head, elongated face, long thin limbs, oversized hands and feet, narrow
torso, angular planes, and a stance that is amusing before any animation runs.

## Non-negotiable visual rules

- Keep the low-poly faceting visible; use flat/lightly stylized shading and no
  detailed skin textures.
- Use one skin, hair, clothing, and accent material. Customization colors are
  persistent across all evolution stages.
- Put expression in big eyes, brows, simple mouth shapes, posture, and motion.
  Do not add realistic facial topology or surface detail.
- Build clothing from clear primitive-shaped silhouettes. Avoid visual noise
  such as dense straps, pouches, and buckles.
- Stage 1 through Stage 5 is refinement of the same odd person. No stage may
  introduce realistic anatomy or realistic first-person hands.

## Runtime ownership

`Player` owns gameplay state and selected `evolution_stage`.
`CharacterCustomizationData` owns the four persistent colors.
`CharacterVisualController` applies those values to `CavemanModel`.
The visual model owns meshes, expression primitives, stage accessories, and
presentation animation only.

## Acceptance pass

Check the existing showcase, expression, animation, ragdoll, first-person, and
customization test scenes after any model change. A model passes only if it is
recognizable without textures or color and becomes funnier—not less readable—
when ragdolled.
