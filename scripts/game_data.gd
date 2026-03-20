extends RefCounted


static func get_resource_xp(resource_id: String, data: Dictionary) -> int:
	if not data["gatherables"].has(resource_id):
		return 0

	var gatherable: Dictionary = data["gatherables"][resource_id]
	return int(gatherable["xp"])


static func get_unlock_level(resource_id: String, data: Dictionary) -> int:
	var gatherable: Dictionary = data["gatherables"][resource_id]
	return int(gatherable["unlock_level"])


static func get_resource_name(resource_id: String, data: Dictionary) -> String:
	if data["items"].has(resource_id):
		var item: Dictionary = data["items"][resource_id]
		return String(item["name"])

	var gatherable: Dictionary = data["gatherables"][resource_id]
	return String(gatherable["name"])


static func get_item_description(item_id: String, data: Dictionary) -> String:
	if not data["items"].has(item_id):
		return ""

	var item: Dictionary = data["items"][item_id]
	return String(item.get("description", ""))


static func get_item_fuel_units(item_id: String, data: Dictionary) -> int:
	if not data["items"].has(item_id):
		return 0

	var item: Dictionary = data["items"][item_id]
	return int(item.get("fuel_units", 0))


static func get_item_category(item_id: String, data: Dictionary) -> String:
	if not data["items"].has(item_id):
		return "materials"

	var item: Dictionary = data["items"][item_id]
	return String(item.get("category", "materials"))


static func get_item_gather_source(item_id: String, data: Dictionary) -> String:
	if not data["items"].has(item_id):
		return ""

	var item: Dictionary = data["items"][item_id]
	return String(item.get("gather_source", ""))


static func get_resource_skill_id(resource_id: String, data: Dictionary) -> String:
	if not data["gatherables"].has(resource_id):
		return "crafting"

	var gatherable: Dictionary = data["gatherables"][resource_id]
	return String(gatherable.get("skill", "gathering"))


static func get_gather_output_item_id(resource_id: String, data: Dictionary) -> String:
	if not data["gatherables"].has(resource_id):
		return resource_id

	var gatherable: Dictionary = data["gatherables"][resource_id]
	return String(gatherable.get("output_item", resource_id))


static func get_inventory_item_order(data: Dictionary) -> Array:
	var inventory_item_order: Array = []
	for item_id in data["item_order"]:
		if not inventory_item_order.has(item_id):
			inventory_item_order.append(item_id)

	return inventory_item_order


static func get_inventory_group_ids(data: Dictionary) -> Array:
	return ["resources", "materials", "food"]


static func get_inventory_group_name(group_id: String) -> String:
	match group_id:
		"resources":
			return "Resources"
		"materials":
			return "Materials"
		"food":
			return "Food"
		_:
			return "Items"


static func get_inventory_group_item_ids(group_id: String, data: Dictionary) -> Array:
	var item_ids: Array = []
	for item_id in data["item_order"]:
		if get_item_category(item_id, data) != group_id:
			continue

		item_ids.append(item_id)

	return item_ids


static func get_processing_summary_item_ids(data: Dictionary) -> Array:
	var summary_item_ids: Array = []
	for item_id in data["item_order"]:
		if data["gatherables"].has(item_id):
			continue

		summary_item_ids.append(item_id)

	return summary_item_ids


static func get_burnable_item_ids(data: Dictionary) -> Array:
	var burnable_item_ids: Array = []
	for item_id in data["item_order"]:
		if get_item_fuel_units(item_id, data) <= 0:
			continue

		burnable_item_ids.append(item_id)

	return burnable_item_ids


static func get_required_tool_id(resource_id: String, data: Dictionary) -> String:
	var gatherable: Dictionary = data["gatherables"][resource_id]
	if not gatherable.has("required_tool"):
		return ""

	return String(gatherable["required_tool"])


static func get_tool_durability_cost(resource_id: String, data: Dictionary) -> int:
	var gatherable: Dictionary = data["gatherables"][resource_id]
	if not gatherable.has("tool_durability_cost"):
		return 0

	return int(gatherable["tool_durability_cost"])


static func skill_has_gatherables(skill_id: String, data: Dictionary) -> bool:
	for resource_id in data["gatherable_order"]:
		if get_resource_skill_id(resource_id, data) == skill_id:
			return true

	return false


static func get_gatherable_skill_ids(data: Dictionary) -> Array:
	var ids: Array = []
	for skill_id in data["skill_order"]:
		var skill: Dictionary = data["skill_definitions"][skill_id]
		if bool(skill.get("gatherable_tab", false)) and skill_has_gatherables(skill_id, data):
			ids.append(skill_id)

	return ids


static func get_skill_name(skill_id: String, data: Dictionary) -> String:
	var skill: Dictionary = data["skill_definitions"][skill_id]
	return String(skill["name"])


static func get_tool_name(tool_id: String, data: Dictionary) -> String:
	var tool: Dictionary = data["tool_definitions"][tool_id]
	return String(tool["name"])


static func get_tool_max_durability(tool_id: String, data: Dictionary) -> int:
	var tool: Dictionary = data["tool_definitions"][tool_id]
	return int(tool["max_durability"])


static func get_tool_craft_cost(tool_id: String, data: Dictionary) -> Dictionary:
	var tool: Dictionary = data["tool_definitions"][tool_id]
	return Dictionary(tool["craft_cost"]).duplicate(true)


static func get_tool_craft_time(tool_id: String, data: Dictionary) -> float:
	var tool: Dictionary = data["tool_definitions"][tool_id]
	return float(tool["craft_time"])


static func get_tool_craft_xp(tool_id: String, data: Dictionary) -> int:
	var tool: Dictionary = data["tool_definitions"][tool_id]
	return int(tool["craft_xp"])


static func get_tool_use_text(tool_id: String, data: Dictionary) -> String:
	var tool: Dictionary = data["tool_definitions"][tool_id]
	return String(tool.get("use_text", ""))


static func get_craftable_name(craftable_id: String, data: Dictionary) -> String:
	var craftable: Dictionary = data["craftables"][craftable_id]
	return String(craftable["name"])


static func get_craftable_craft_cost(craftable_id: String, data: Dictionary) -> Dictionary:
	var craftable: Dictionary = data["craftables"][craftable_id]
	return Dictionary(craftable["craft_cost"]).duplicate(true)


static func get_craftable_craft_time(craftable_id: String, data: Dictionary) -> float:
	var craftable: Dictionary = data["craftables"][craftable_id]
	return float(craftable["craft_time"])


static func get_craftable_craft_xp(craftable_id: String, data: Dictionary) -> int:
	var craftable: Dictionary = data["craftables"][craftable_id]
	return int(craftable["craft_xp"])


static func get_craftable_use_text(craftable_id: String, data: Dictionary) -> String:
	var craftable: Dictionary = data["craftables"][craftable_id]
	return String(craftable.get("use_text", ""))


static func get_craftable_max_count(craftable_id: String, data: Dictionary) -> int:
	var craftable: Dictionary = data["craftables"][craftable_id]
	return int(craftable.get("max_count", 999999))


static func get_craftable_upgrade_cost_multiplier(craftable_id: String, data: Dictionary) -> float:
	var craftable: Dictionary = data["craftables"][craftable_id]
	return float(craftable.get("upgrade_cost_multiplier", 1.3))


static func get_craftable_station_speed_multiplier(craftable_id: String, data: Dictionary) -> float:
	var craftable: Dictionary = data["craftables"][craftable_id]
	return float(craftable.get("station_speed_multiplier", 0.85))


static func get_station_fuel_capacity(craftable_id: String, data: Dictionary) -> int:
	var craftable: Dictionary = data["craftables"][craftable_id]
	return int(craftable.get("fuel_capacity", 0))


static func get_recipe_name(recipe_id: String, data: Dictionary) -> String:
	var recipe: Dictionary = data["recipes"][recipe_id]
	return String(recipe["name"])


static func get_recipe_station_id(recipe_id: String, data: Dictionary) -> String:
	var recipe: Dictionary = data["recipes"][recipe_id]
	return String(recipe.get("station", ""))


static func get_recipe_craft_cost(recipe_id: String, data: Dictionary) -> Dictionary:
	var recipe: Dictionary = data["recipes"][recipe_id]
	return Dictionary(recipe.get("craft_cost", {})).duplicate(true)


static func get_recipe_craft_xp(recipe_id: String, data: Dictionary) -> int:
	var recipe: Dictionary = data["recipes"][recipe_id]
	return int(recipe.get("craft_xp", 0))


static func get_recipe_skill_id(recipe_id: String, data: Dictionary) -> String:
	var recipe: Dictionary = data["recipes"][recipe_id]
	return String(recipe.get("skill", "crafting"))


static func get_recipe_fuel_cost_units(recipe_id: String, data: Dictionary) -> int:
	var recipe: Dictionary = data["recipes"][recipe_id]
	return int(recipe.get("fuel_cost_units", 0))
