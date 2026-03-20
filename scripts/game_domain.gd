extends RefCounted

const GameActions = preload("res://scripts/game_actions.gd")
const GameData = preload("res://scripts/game_data.gd")
const GameEconomy = preload("res://scripts/game_economy.gd")
const GameQueries = preload("res://scripts/game_queries.gd")
const GameRules = preload("res://scripts/game_rules.gd")
const GameState = preload("res://scripts/game_state.gd")


static func get_queue_capacity(upgrade_levels: Dictionary, base_queue_size: int, queue_size_per_upgrade: int) -> int:
	return GameEconomy.get_queue_capacity(upgrade_levels, base_queue_size, queue_size_per_upgrade)


static func resource_requires_tool(resource_id: String, data: Dictionary) -> bool:
	return GameData.get_required_tool_id(resource_id, data) != ""


static func get_craftable_upgrade_cost(
	craftable_id: String,
	craftable_upgrade_levels: Dictionary,
	data: Dictionary,
	from_level: int = -1
) -> Dictionary:
	var effective_level := from_level
	if effective_level < 0:
		effective_level = GameState.get_craftable_upgrade_level(craftable_upgrade_levels, craftable_id)

	return GameEconomy.get_craftable_upgrade_cost(
		craftable_id,
		effective_level,
		data,
		GameData.get_inventory_item_order(data)
	)


static func get_craftable_speed_multiplier(craftable_id: String, craftable_upgrade_levels: Dictionary, data: Dictionary) -> float:
	return GameEconomy.get_craftable_speed_multiplier(
		craftable_id,
		GameState.get_craftable_upgrade_level(craftable_upgrade_levels, craftable_id),
		data
	)


static func get_recipe_craft_cost(recipe_id: String, data: Dictionary) -> Dictionary:
	return GameEconomy.build_cost(
		GameData.get_recipe_craft_cost(recipe_id, data),
		GameData.get_inventory_item_order(data)
	)


static func get_recipe_outputs(recipe_id: String, rules_context: Dictionary) -> Dictionary:
	return GameEconomy.build_cost(
		GameRules.get_recipe_outputs(recipe_id, rules_context),
		rules_context["inventory_item_order"]
	)


static func get_recipe_craft_time(recipe_id: String, simulation_state: Dictionary, rules_context: Dictionary) -> float:
	return GameQueries.get_action_duration(
		GameActions.make_process_recipe_action(recipe_id),
		simulation_state,
		rules_context
	)


static func get_upgrade_cost(upgrade_id: String, upgrade_levels: Dictionary, upgrades: Dictionary, data: Dictionary) -> Dictionary:
	return GameEconomy.get_upgrade_cost(
		upgrade_id,
		upgrade_levels,
		upgrades,
		GameData.get_inventory_item_order(data)
	)


static func can_afford(cost: Dictionary, inventory: Dictionary) -> bool:
	return GameRules.can_afford_inventory(inventory, cost)


static func spend_resources(inventory: Dictionary, cost: Dictionary) -> void:
	GameEconomy.spend_resources(inventory, cost)
