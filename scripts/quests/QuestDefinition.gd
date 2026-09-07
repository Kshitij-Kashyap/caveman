## QuestDefinition.gd
## Data resource defining a single quest available in Cave Raiders.
## Create instances as .tres files in res://resources/quests/

class_name QuestDefinition
extends Resource

enum QuestType {
	COLLECT,   ## Collect N of a specific item
	KILL,      ## Kill N of a specific creature type
	HUNT,      ## Hunt creature and return with trophy
	FIND,      ## Reach a specific location or NPC
	RETRIEVE,  ## Retrieve a specific item and bring it back
	SURVIVE,   ## Survive in the dungeon for a duration
	ESCORT,    ## Escort an NPC to the extraction zone
	BOSS,      ## Defeat a boss creature
	EXTRACT,   ## Successfully extract from the dungeon
}

@export var quest_id: String = ""
@export var quest_name: String = ""
@export_multiline var description: String = ""
@export var quest_type: QuestType = QuestType.COLLECT

## The creature name or item_id that is the target of this quest
@export var target_id: String = ""

## How many of the target are required to complete the quest
@export var required_quantity: int = 1

## Resources rewarded on completion: { item_id: quantity }
@export var reward_resources: Dictionary = {}

## Bonus currency ("bones") rewarded on completion
@export var reward_currency: int = 50

## Which biome this quest requires — "any" means no restriction
@export var required_biome: String = "any"

## Player level range that may receive this quest
@export var min_level: int = 1
@export var max_level: int = 999
