extends RefCounted

const GameActions = preload("res://scripts/game_actions.gd")
const GameData = preload("res://scripts/game_data.gd")


static func build_simulation_state(
	inventory: Dictionary,
	tools: Dictionary,
	crafted_items: Dictionary,
	craftable_upgrade_levels: Dictionary,
	stored_fuel_units: Dictionary,
	skill_states: Dictionary
) -> Dictionary:
	return {
		"inventory": inventory.duplicate(true),
		"tools": tools.duplicate(true),
		"crafted_items": crafted_items.duplicate(true),
		"craftable_upgrade_levels": craftable_upgrade_levels.duplicate(true),
		"stored_fuel_units": stored_fuel_units.duplicate(true),
		"skills": skill_states.duplicate(true),
	}


static func get_skill_level(skill_states: Dictionary, skill_id: String) -> int:
	return int(skill_states[skill_id]["level"])


static func get_tool_durability(tools: Dictionary, tool_id: String) -> int:
	return int(tools[tool_id]["durability"])


static func get_crafted_item_count(crafted_items: Dictionary, craftable_id: String) -> int:
	return int(crafted_items[craftable_id])


static func get_craftable_upgrade_level(craftable_upgrade_levels: Dictionary, craftable_id: String) -> int:
	return int(craftable_upgrade_levels.get(craftable_id, 0))


static func get_processing_station_level(
	crafted_items: Dictionary,
	craftable_upgrade_levels: Dictionary,
	craftable_id: String
) -> int:
	if get_crafted_item_count(crafted_items, craftable_id) <= 0:
		return 0

	return get_craftable_upgrade_level(craftable_upgrade_levels, craftable_id) + 1


static func get_station_stored_fuel_units(stored_fuel_units: Dictionary, craftable_id: String) -> int:
	return int(stored_fuel_units.get(craftable_id, 0))


static func is_resource_unlocked(resource_id: String, skill_states: Dictionary, data: Dictionary) -> bool:
	var skill_id := GameData.get_resource_skill_id(resource_id, data)
	return get_skill_level(skill_states, skill_id) >= GameData.get_unlock_level(resource_id, data)


static func is_current_action(current_action: Dictionary, action_type: String, action_id: String) -> bool:
	return (
		not current_action.is_empty()
		and GameActions.get_action_type(current_action) == action_type
		and GameActions.get_action_id(current_action) == action_id
	)


static func has_queued_action(action_queue: Array, action_type: String, action_id: String) -> bool:
	for queued_action in action_queue:
		if GameActions.get_action_type(queued_action) == action_type and GameActions.get_action_id(queued_action) == action_id:
			return true

	return false


static func get_current_action_time_left(current_action: Dictionary) -> float:
	if current_action.is_empty():
		return 0.0

	return maxf(0.0, float(current_action["duration"]) - float(current_action["elapsed"]))
