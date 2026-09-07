## ItemDefinition.gd
## Data resource defining a single item type in Cave Raiders.
## Create instances as .tres files in res://resources/items/

class_name ItemDefinition
extends Resource

enum ItemType {
	RESOURCE,    ## Raw materials (stone, meat, hide)
	WEAPON,      ## Combat equipment
	TOOL,        ## Mining tools
	CONSUMABLE,  ## One-use items
	TROPHY,      ## Creature trophies (tusks, claws, horns)
	FOSSIL,      ## Rare collectibles
	CURRENCY,    ## Tradeable currency items
}

@export var item_id: String = ""
@export var item_name: String = ""
@export var item_type: ItemType = ItemType.RESOURCE
@export_multiline var description: String = ""
@export var max_stack: int = 20
@export var weight: float = 1.0
@export var sell_value: int = 1
@export var icon: Texture2D = null
