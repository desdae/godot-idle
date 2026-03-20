extends RefCounted

const GameData = preload("res://scripts/game_data.gd")


static func make_gather_action(resource_id: String) -> Dictionary:
	return {
		"type": "gather",
		"id": resource_id,
	}


static func make_craft_tool_action(tool_id: String) -> Dictionary:
	return {
		"type": "craft_tool",
		"id": tool_id,
	}


static func make_craft_item_action(craftable_id: String) -> Dictionary:
	return {
		"type": "craft_item",
		"id": craftable_id,
	}


static func make_upgrade_craftable_action(craftable_id: String) -> Dictionary:
	return {
		"type": "upgrade_craftable",
		"id": craftable_id,
	}


static func make_process_recipe_action(recipe_id: String) -> Dictionary:
	return {
		"type": "process_recipe",
		"id": recipe_id,
	}


static func make_refuel_station_action(craftable_id: String, item_id: String) -> Dictionary:
	return {
		"type": "refuel_station",
		"id": craftable_id,
		"station_id": craftable_id,
		"fuel_item_id": item_id,
	}


static func copy_action(action: Dictionary) -> Dictionary:
	if action.is_empty():
		return {}

	return {
		"type": get_action_type(action),
		"id": get_action_id(action),
		"station_id": get_action_station_id(action),
		"fuel_item_id": get_action_fuel_item_id(action),
	}


static func get_action_type(action: Dictionary) -> String:
	return String(action.get("type", ""))


static func get_action_id(action: Dictionary) -> String:
	return String(action.get("id", ""))


static func get_action_station_id(action: Dictionary) -> String:
	return String(action.get("station_id", get_action_id(action)))


static func get_action_fuel_item_id(action: Dictionary) -> String:
	return String(action.get("fuel_item_id", ""))


static func get_action_queue_label(action: Dictionary, data: Dictionary) -> String:
	match get_action_type(action):
		"gather":
			return GameData.get_resource_name(get_action_id(action), data)
		"craft_tool":
			return "Craft %s" % GameData.get_tool_name(get_action_id(action), data)
		"craft_item":
			return "Build %s" % GameData.get_craftable_name(get_action_id(action), data)
		"upgrade_craftable":
			return "Upgrade %s" % GameData.get_craftable_name(get_action_id(action), data)
		"process_recipe":
			return "%s: %s" % [
				GameData.get_craftable_name(GameData.get_recipe_station_id(get_action_id(action), data), data),
				GameData.get_recipe_name(get_action_id(action), data),
			]
		"refuel_station":
			return "Burn %s in %s" % [
				GameData.get_resource_name(get_action_fuel_item_id(action), data),
				GameData.get_craftable_name(get_action_station_id(action), data),
			]
		_:
			return "Unknown"


static func get_action_progress_label(action: Dictionary, data: Dictionary) -> String:
	match get_action_type(action):
		"gather":
			return "Gathering %s" % GameData.get_resource_name(get_action_id(action), data)
		"craft_tool":
			return "Crafting %s" % GameData.get_tool_name(get_action_id(action), data)
		"craft_item":
			return "Building %s" % GameData.get_craftable_name(get_action_id(action), data)
		"upgrade_craftable":
			return "Upgrading %s" % GameData.get_craftable_name(get_action_id(action), data)
		"process_recipe":
			return "Processing %s" % GameData.get_recipe_name(get_action_id(action), data)
		"refuel_station":
			return "Loading %s" % GameData.get_resource_name(get_action_fuel_item_id(action), data)
		_:
			return "Working"
