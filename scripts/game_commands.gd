extends RefCounted

const GameActions = preload("res://scripts/game_actions.gd")
const GameDomain = preload("res://scripts/game_domain.gd")
const GameQueries = preload("res://scripts/game_queries.gd")
const GameQueue = preload("res://scripts/game_queue.gd")
const GameState = preload("res://scripts/game_state.gd")


static func try_queue_pickable(
	resource_id: String,
	requested_amount: int,
	action_queue: Array,
	current_action: Dictionary,
	skill_states: Dictionary,
	upgrade_levels: Dictionary,
	base_queue_size: int,
	queue_size_per_upgrade: int,
	initial_state: Dictionary,
	data: Dictionary,
	rules: Dictionary
) -> bool:
	var queue_capacity := GameDomain.get_queue_capacity(upgrade_levels, base_queue_size, queue_size_per_upgrade)
	var block_reason := GameQueries.get_gather_queue_block_reason(
		resource_id,
		action_queue,
		queue_capacity,
		current_action,
		initial_state,
		rules
	)
	if not GameQueries.can_queue_pickable(resource_id, skill_states, data, block_reason):
		return false

	return GameQueue.queue_action_count(
		action_queue,
		GameActions.make_gather_action(resource_id),
		requested_amount,
		queue_capacity,
		GameActions.copy_action(current_action),
		initial_state,
		rules
	)


static func try_queue_tool(
	tool_id: String,
	action_queue: Array,
	current_action: Dictionary,
	upgrade_levels: Dictionary,
	base_queue_size: int,
	queue_size_per_upgrade: int,
	initial_state: Dictionary,
	rules: Dictionary
) -> bool:
	var queue_capacity := GameDomain.get_queue_capacity(upgrade_levels, base_queue_size, queue_size_per_upgrade)
	var block_reason := GameQueries.get_tool_queue_block_reason(
		tool_id,
		action_queue,
		queue_capacity,
		current_action,
		initial_state,
		rules
	)
	if not GameQueries.can_queue_from_block_reason(block_reason):
		return false

	action_queue.append(GameActions.make_craft_tool_action(tool_id))
	return true


static func try_queue_craftable(
	craftable_id: String,
	action_queue: Array,
	current_action: Dictionary,
	crafted_items: Dictionary,
	upgrade_levels: Dictionary,
	base_queue_size: int,
	queue_size_per_upgrade: int,
	initial_state: Dictionary,
	rules: Dictionary
) -> bool:
	if GameState.get_crafted_item_count(crafted_items, craftable_id) > 0:
		return try_queue_craftable_upgrade(
			craftable_id,
			action_queue,
			current_action,
			upgrade_levels,
			base_queue_size,
			queue_size_per_upgrade,
			initial_state,
			rules
		)

	var queue_capacity := GameDomain.get_queue_capacity(upgrade_levels, base_queue_size, queue_size_per_upgrade)
	var block_reason := GameQueries.get_craftable_queue_block_reason(
		craftable_id,
		action_queue,
		queue_capacity,
		current_action,
		initial_state,
		rules
	)
	if not GameQueries.can_queue_from_block_reason(block_reason):
		return false

	action_queue.append(GameActions.make_craft_item_action(craftable_id))
	return true


static func try_queue_craftable_upgrade(
	craftable_id: String,
	action_queue: Array,
	current_action: Dictionary,
	upgrade_levels: Dictionary,
	base_queue_size: int,
	queue_size_per_upgrade: int,
	initial_state: Dictionary,
	rules: Dictionary
) -> bool:
	var queue_capacity := GameDomain.get_queue_capacity(upgrade_levels, base_queue_size, queue_size_per_upgrade)
	var block_reason := GameQueries.get_craftable_upgrade_queue_block_reason(
		craftable_id,
		action_queue,
		queue_capacity,
		current_action,
		initial_state,
		rules
	)
	if not GameQueries.can_queue_from_block_reason(block_reason):
		return false

	action_queue.append(GameActions.make_upgrade_craftable_action(craftable_id))
	return true


static func try_queue_recipe(
	recipe_id: String,
	requested_amount: int,
	action_queue: Array,
	current_action: Dictionary,
	upgrade_levels: Dictionary,
	base_queue_size: int,
	queue_size_per_upgrade: int,
	initial_state: Dictionary,
	rules: Dictionary
) -> bool:
	var queue_capacity := GameDomain.get_queue_capacity(upgrade_levels, base_queue_size, queue_size_per_upgrade)
	var block_reason := GameQueries.get_recipe_queue_block_reason(
		recipe_id,
		action_queue,
		queue_capacity,
		current_action,
		initial_state,
		rules
	)
	if not GameQueries.can_queue_from_block_reason(block_reason):
		return false

	return GameQueue.queue_action_count(
		action_queue,
		GameActions.make_process_recipe_action(recipe_id),
		requested_amount,
		queue_capacity,
		GameActions.copy_action(current_action),
		initial_state,
		rules
	)


static func try_queue_station_fuel(
	craftable_id: String,
	item_id: String,
	requested_amount: int,
	action_queue: Array,
	current_action: Dictionary,
	upgrade_levels: Dictionary,
	base_queue_size: int,
	queue_size_per_upgrade: int,
	initial_state: Dictionary,
	rules: Dictionary
) -> bool:
	var queue_capacity := GameDomain.get_queue_capacity(upgrade_levels, base_queue_size, queue_size_per_upgrade)
	var block_reason := GameQueries.get_station_fuel_queue_block_reason(
		craftable_id,
		item_id,
		action_queue,
		queue_capacity,
		current_action,
		initial_state,
		rules
	)
	if not GameQueries.can_queue_from_block_reason(block_reason):
		return false

	return GameQueue.queue_action_count(
		action_queue,
		GameActions.make_refuel_station_action(craftable_id, item_id),
		requested_amount,
		queue_capacity,
		GameActions.copy_action(current_action),
		initial_state,
		rules
	)


static func buy_upgrade(upgrade_id: String, inventory: Dictionary, upgrade_levels: Dictionary, upgrades: Dictionary, data: Dictionary) -> bool:
	var cost := GameDomain.get_upgrade_cost(upgrade_id, upgrade_levels, upgrades, data)
	if not GameDomain.can_afford(cost, inventory):
		return false

	GameDomain.spend_resources(inventory, cost)
	upgrade_levels[upgrade_id] += 1
	return true


static func toggle_processing_station(processing_station_expanded: Dictionary, craftable_id: String) -> void:
	processing_station_expanded[craftable_id] = not bool(processing_station_expanded.get(craftable_id, true))


static func clear_queue(action_queue: Array) -> void:
	action_queue.clear()


static func toggle_queue_pause(is_queue_paused: bool) -> bool:
	return not is_queue_paused


static func queue_action(action_queue: Array, action: Dictionary) -> bool:
	action_queue.append(action.duplicate(true))
	return true
