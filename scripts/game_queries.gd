extends RefCounted

const GameActions = preload("res://scripts/game_actions.gd")
const GameQueue = preload("res://scripts/game_queue.gd")
const GameRules = preload("res://scripts/game_rules.gd")
const GameState = preload("res://scripts/game_state.gd")


static func can_queue_pickable(resource_id: String, skill_states: Dictionary, data: Dictionary, block_reason: String) -> bool:
	if not GameState.is_resource_unlocked(resource_id, skill_states, data):
		return false

	return block_reason == ""


static func can_queue_from_block_reason(block_reason: String) -> bool:
	return block_reason == ""


static func get_queue_block_reason_for_action(
	action_queue: Array,
	queue_capacity: int,
	action: Dictionary,
	current_action: Dictionary,
	simulation_state: Dictionary,
	rules_context: Dictionary
) -> String:
	return GameQueue.get_queue_block_reason_for_action(
		action_queue,
		queue_capacity,
		action,
		GameActions.copy_action(current_action),
		simulation_state,
		rules_context
	)


static func get_gather_queue_block_reason(
	resource_id: String,
	action_queue: Array,
	queue_capacity: int,
	current_action: Dictionary,
	simulation_state: Dictionary,
	rules_context: Dictionary
) -> String:
	return get_queue_block_reason_for_action(
		action_queue,
		queue_capacity,
		GameActions.make_gather_action(resource_id),
		current_action,
		simulation_state,
		rules_context
	)


static func get_tool_queue_block_reason(
	tool_id: String,
	action_queue: Array,
	queue_capacity: int,
	current_action: Dictionary,
	simulation_state: Dictionary,
	rules_context: Dictionary
) -> String:
	return get_queue_block_reason_for_action(
		action_queue,
		queue_capacity,
		GameActions.make_craft_tool_action(tool_id),
		current_action,
		simulation_state,
		rules_context
	)


static func get_craftable_queue_block_reason(
	craftable_id: String,
	action_queue: Array,
	queue_capacity: int,
	current_action: Dictionary,
	simulation_state: Dictionary,
	rules_context: Dictionary
) -> String:
	return get_queue_block_reason_for_action(
		action_queue,
		queue_capacity,
		GameActions.make_craft_item_action(craftable_id),
		current_action,
		simulation_state,
		rules_context
	)


static func get_craftable_upgrade_queue_block_reason(
	craftable_id: String,
	action_queue: Array,
	queue_capacity: int,
	current_action: Dictionary,
	simulation_state: Dictionary,
	rules_context: Dictionary
) -> String:
	return get_queue_block_reason_for_action(
		action_queue,
		queue_capacity,
		GameActions.make_upgrade_craftable_action(craftable_id),
		current_action,
		simulation_state,
		rules_context
	)


static func get_recipe_queue_block_reason(
	recipe_id: String,
	action_queue: Array,
	queue_capacity: int,
	current_action: Dictionary,
	simulation_state: Dictionary,
	rules_context: Dictionary
) -> String:
	return get_queue_block_reason_for_action(
		action_queue,
		queue_capacity,
		GameActions.make_process_recipe_action(recipe_id),
		current_action,
		simulation_state,
		rules_context
	)


static func get_station_fuel_queue_block_reason(
	craftable_id: String,
	item_id: String,
	action_queue: Array,
	queue_capacity: int,
	current_action: Dictionary,
	simulation_state: Dictionary,
	rules_context: Dictionary
) -> String:
	return get_queue_block_reason_for_action(
		action_queue,
		queue_capacity,
		GameActions.make_refuel_station_action(craftable_id, item_id),
		current_action,
		simulation_state,
		rules_context
	)


static func get_free_queue_slots(action_queue_size: int, queue_capacity: int) -> int:
	return GameQueue.get_free_queue_slots(action_queue_size, queue_capacity)


static func get_action_duration(action: Dictionary, simulation_state: Dictionary, rules_context: Dictionary) -> float:
	return GameRules.get_action_duration_for_state(action, simulation_state, rules_context)


static func get_gather_action_duration(resource_id: String, simulation_state: Dictionary, rules_context: Dictionary) -> float:
	return get_action_duration(GameActions.make_gather_action(resource_id), simulation_state, rules_context)


static func get_gather_action_duration_for_state(resource_id: String, level_value: int, tooling_level: int, rules_context: Dictionary) -> float:
	return GameRules.get_gather_action_duration_for_state(resource_id, level_value, tooling_level, rules_context)


static func get_recipe_craft_time_for_state(recipe_id: String, state: Dictionary, rules_context: Dictionary) -> float:
	return GameRules.get_recipe_craft_time_for_state(recipe_id, state, rules_context)


static func estimate_queue_time_left(
	current_action: Dictionary,
	action_queue: Array,
	simulation_state: Dictionary,
	current_action_time_left: float,
	rules_context: Dictionary
) -> float:
	return GameQueue.estimate_queue_time_left(
		GameActions.copy_action(current_action),
		action_queue,
		simulation_state,
		current_action_time_left,
		rules_context
	)


static func build_pipeline_end_state(
	current_action: Dictionary,
	action_queue: Array,
	simulation_state: Dictionary,
	rules_context: Dictionary
) -> Dictionary:
	return GameRules.build_pipeline_end_state(
		simulation_state,
		GameActions.copy_action(current_action),
		action_queue,
		rules_context
	)
