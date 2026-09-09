## CraftingRecipe.gd
## Data resource defining one Crafting Fire recipe.
## Materials come from the camp stockpile (ProgressionManager.stored_resources).
## Results go to the crafting player's expedition inventory — except recipes
## with a non-empty `special` id, which trigger a bespoke effect instead
## (e.g. "glow_charge" refills one GlowRockSystem rock).

class_name CraftingRecipe
extends Resource

@export var recipe_id: String = ""
@export var result_name: String = ""
@export var result_item_id: String = ""
@export var result_qty: int = 1
@export_multiline var description: String = ""
## item_id -> quantity required from the stockpile.
@export var cost: Dictionary = {}
## Non-empty for non-item results handled in code (see CraftingMenu).
@export var special: String = ""
