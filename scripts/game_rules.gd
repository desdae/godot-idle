extends RefCounted


static func get_action_duration_for_state(action: Dictionary, state: Dictionary, rules: Dictionary) -> float:
	var action_type := _get_action_type(action)
	var action_id := _get_action_id(action)
	match action_type:
		"gather":
			var skill_id := _get_resource_skill_id(action_id, rules)
			return get_gather_action_duration_for_state(
				action_id,
				int(state["skills"][skill_id]["level"]),
				int(rules["upgrade_levels"]["tooling"]),
				rules
			)
		"craft_tool":
			return _get_tool_craft_time(action_id, rules)
		"craft_item":
			return _get_craftable_craft_time(action_id, rules)
		"upgrade_craftable":
			return _get_craftable_craft_time(action_id, rules)
		"process_recipe":
			return get_recipe_craft_time_for_state(action_id, state, rules)
		"refuel_station":
			return 0.35
		_:
			return 0.0


static func get_gather_action_duration_for_state(resource_id: String, level_value: int, tooling_level: int, rules: Dictionary) -> float:
	var gatherable: Dictionary = rules["gatherables"][resource_id]
	var level_multiplier := get_skill_level_speed_multiplier(level_value, rules)
	var upgrade_multiplier := pow(float(rules["speed_upgrade_multiplier"]), tooling_level)
	var duration := float(gatherable["base_time"]) * level_multiplier * upgrade_multiplier
	return maxf(float(rules["min_gather_time"]), duration)


static func get_recipe_craft_time_for_state(recipe_id: String, state: Dictionary, rules: Dictionary) -> float:
	var recipe: Dictionary = rules["recipes"][recipe_id]
	var station_id := _get_recipe_station_id(recipe_id, rules)
	var skill_id := _get_recipe_skill_id(recipe_id, rules)
	var skill_state: Dictionary = {"level": 1}
	if state["skills"].has(skill_id):
		skill_state = state["skills"][skill_id]

	var skill_level := int(skill_state.get("level", 1))
	var upgrade_level := int(state["craftable_upgrade_levels"].get(station_id, 0))
	var base_duration := float(recipe.get("craft_time", 0.0))
	if bool(recipe.get("use_source_fuel_value", false)):
		base_duration *= float(get_recipe_source_fuel_units(recipe_id, rules))

	var duration := (
		base_duration
		* get_skill_level_speed_multiplier(skill_level, rules)
		* pow(_get_craftable_station_speed_multiplier(station_id, rules), upgrade_level)
	)
	return maxf(float(rules["min_gather_time"]), duration)


static func simulate_exp_gain(level_value: int, exp_value: int, exp_to_next_value: int, amount: int, exp_growth: float) -> Dictionary:
	var next_level := level_value
	var next_exp := exp_value + amount
	var next_exp_to_next := exp_to_next_value

	while next_exp >= next_exp_to_next:
		next_exp -= next_exp_to_next
		next_level += 1
		next_exp_to_next = maxi(int(ceil(float(next_exp_to_next) * exp_growth)), next_exp_to_next + 1)

	return {
		"level": next_level,
		"exp": next_exp,
		"exp_to_next": next_exp_to_next,
	}


static func get_item_fuel_units(item_id: String, rules: Dictionary) -> int:
	if not rules["items"].has(item_id):
		return 0

	var item: Dictionary = rules["items"][item_id]
	return int(item.get("fuel_units", 0))


static func get_skill_level_speed_multiplier(level_value: int, rules: Dictionary) -> float:
	return pow(float(rules["level_speed_multiplier"]), maxi(level_value - 1, 0))


static func is_resource_unlocked_in_state(resource_id: String, state: Dictionary, rules: Dictionary) -> bool:
	var skill_id := _get_resource_skill_id(resource_id, rules)
	var skill_state: Dictionary = {"level": 1}
	if state["skills"].has(skill_id):
		skill_state = state["skills"][skill_id]

	return int(skill_state.get("level", 1)) >= _get_unlock_level(resource_id, rules)


static func get_resource_unlock_requirement_text(resource_id: String, rules: Dictionary) -> String:
	return "%s unlocks at %s Lv %d." % [
		_get_resource_name(_get_gather_output_item_id(resource_id, rules), rules),
		_get_skill_name(_get_resource_skill_id(resource_id, rules), rules),
		_get_unlock_level(resource_id, rules),
	]


static func get_recipe_outputs(recipe_id: String, rules: Dictionary) -> Dictionary:
	var recipe: Dictionary = rules["recipes"][recipe_id]
	var outputs := Dictionary(recipe.get("outputs", {})).duplicate(true)
	if not bool(recipe.get("use_source_fuel_value", false)):
		return outputs

	var multiplier := get_recipe_source_fuel_units(recipe_id, rules)
	if multiplier <= 1:
		return outputs

	var scaled_outputs := {}
	for item_id in outputs.keys():
		scaled_outputs[item_id] = int(outputs[item_id]) * multiplier

	return scaled_outputs


static func get_recipe_source_fuel_units(recipe_id: String, rules: Dictionary) -> int:
	var recipe_cost := _get_recipe_craft_cost(recipe_id, rules)
	if recipe_cost.size() != 1:
		return 1

	for item_id in recipe_cost.keys():
		return maxi(1, get_item_fuel_units(String(item_id), rules))

	return 1


static func build_pipeline_end_state(initial_state: Dictionary, current_action: Dictionary, action_queue: Array, rules: Dictionary) -> Dictionary:
	var state := initial_state.duplicate(true)

	if not current_action.is_empty():
		apply_action_completion_to_state(state, current_action, rules)

	for queued_action in action_queue:
		simulate_action_in_state(state, queued_action, rules)

	return state


static func simulate_action_in_state(state: Dictionary, action: Dictionary, rules: Dictionary) -> Dictionary:
	if get_action_block_reason_in_state(action, state, rules) != "":
		return {
			"ran": false,
			"duration": 0.0,
		}

	var duration := get_action_duration_for_state(action, state, rules)
	apply_action_start_to_state(state, action, rules)
	apply_action_completion_to_state(state, action, rules)
	return {
		"ran": true,
		"duration": duration,
	}


static func get_action_block_reason_in_state(action: Dictionary, state: Dictionary, rules: Dictionary) -> String:
	var action_type := _get_action_type(action)
	var action_id := _get_action_id(action)
	match action_type:
		"gather":
			if not is_resource_unlocked_in_state(action_id, state, rules):
				return get_resource_unlock_requirement_text(action_id, rules)

			var output_item_id := _get_gather_output_item_id(action_id, rules)
			if int(state["inventory"].get(output_item_id, 0)) >= _get_capacity(action_id, rules):
				return "Full at end of queue"

			var required_tool_id := _get_required_tool_id(action_id, rules)
			if required_tool_id != "":
				var available_durability := int(state["tools"][required_tool_id]["durability"])
				if available_durability < _get_tool_durability_cost(action_id, rules):
					return "Need %s" % _get_tool_name(required_tool_id, rules)

			return ""
		"craft_tool":
			if int(state["tools"][action_id]["durability"]) >= _get_tool_max_durability(action_id, rules):
				return "%s ready" % _get_tool_name(action_id, rules)
			if not can_afford_inventory(state["inventory"], _get_tool_craft_cost(action_id, rules)):
				return "Need %s" % _format_cost(_get_tool_craft_cost(action_id, rules), rules)
			return ""
		"craft_item":
			if int(state["crafted_items"][action_id]) >= _get_craftable_max_count(action_id, rules):
				return "%s built" % _get_craftable_name(action_id, rules)
			if not can_afford_inventory(state["inventory"], _get_craftable_craft_cost(action_id, rules)):
				return "Need %s" % _format_cost(_get_craftable_craft_cost(action_id, rules), rules)
			return ""
		"upgrade_craftable":
			if int(state["crafted_items"][action_id]) <= 0:
				return "Build %s first" % _get_craftable_name(action_id, rules)
			if not can_afford_inventory(state["inventory"], _get_craftable_upgrade_cost(action_id, int(state["craftable_upgrade_levels"][action_id]), rules)):
				return "Need %s" % _format_cost(_get_craftable_upgrade_cost(action_id, int(state["craftable_upgrade_levels"][action_id]), rules), rules)
			return ""
		"process_recipe":
			var station_id := _get_recipe_station_id(action_id, rules)
			if int(state["crafted_items"].get(station_id, 0)) <= 0:
				return "Need %s" % _get_craftable_name(station_id, rules)
			if not can_afford_inventory(state["inventory"], _get_recipe_craft_cost(action_id, rules)):
				return "Need %s" % _format_cost(_get_recipe_craft_cost(action_id, rules), rules)
			if int(state["stored_fuel_units"].get(station_id, 0)) < _get_recipe_fuel_cost_units(action_id, rules):
				return "Need fuel"
			return ""
		"refuel_station":
			var refuel_station_id := _get_action_station_id(action)
			var fuel_item_id := _get_action_fuel_item_id(action)
			if int(state["crafted_items"].get(refuel_station_id, 0)) <= 0:
				return "Need %s" % _get_craftable_name(refuel_station_id, rules)
			if get_item_fuel_units(fuel_item_id, rules) <= 0:
				return "Invalid fuel"
			if int(state["inventory"].get(fuel_item_id, 0)) <= 0:
				return "Need %s" % _get_resource_name(fuel_item_id, rules)
			if int(state["stored_fuel_units"].get(refuel_station_id, 0)) >= _get_station_fuel_capacity(refuel_station_id, rules):
				return "Fuel full"
			if int(state["stored_fuel_units"].get(refuel_station_id, 0)) + get_item_fuel_units(fuel_item_id, rules) > _get_station_fuel_capacity(refuel_station_id, rules):
				return "No fuel space"
			return ""
		_:
			return "Unknown action"


static func apply_action_start_to_state(state: Dictionary, action: Dictionary, rules: Dictionary) -> void:
	var action_type := _get_action_type(action)
	var action_id := _get_action_id(action)
	match action_type:
		"gather":
			var required_tool_id := _get_required_tool_id(action_id, rules)
			if required_tool_id != "":
				state["tools"][required_tool_id]["durability"] = maxi(
					0,
					int(state["tools"][required_tool_id]["durability"]) - _get_tool_durability_cost(action_id, rules)
				)
		"craft_tool":
			var craft_cost := _get_tool_craft_cost(action_id, rules)
			for resource_id in craft_cost.keys():
				state["inventory"][resource_id] -= int(craft_cost[resource_id])
		"craft_item":
			var item_craft_cost := _get_craftable_craft_cost(action_id, rules)
			for resource_id in item_craft_cost.keys():
				state["inventory"][resource_id] -= int(item_craft_cost[resource_id])
		"upgrade_craftable":
			var upgrade_cost := _get_craftable_upgrade_cost(action_id, int(state["craftable_upgrade_levels"][action_id]), rules)
			for resource_id in upgrade_cost.keys():
				state["inventory"][resource_id] -= int(upgrade_cost[resource_id])
		"process_recipe":
			var recipe_cost := _get_recipe_craft_cost(action_id, rules)
			for resource_id in recipe_cost.keys():
				state["inventory"][resource_id] -= int(recipe_cost[resource_id])

			var station_id := _get_recipe_station_id(action_id, rules)
			state["stored_fuel_units"][station_id] = maxi(
				0,
				int(state["stored_fuel_units"].get(station_id, 0)) - _get_recipe_fuel_cost_units(action_id, rules)
			)
		"refuel_station":
			var refuel_station_id := _get_action_station_id(action)
			var fuel_item_id := _get_action_fuel_item_id(action)
			state["inventory"][fuel_item_id] -= 1
			state["stored_fuel_units"][refuel_station_id] = int(state["stored_fuel_units"].get(refuel_station_id, 0)) + get_item_fuel_units(fuel_item_id, rules)


static func apply_action_completion_to_state(state: Dictionary, action: Dictionary, rules: Dictionary) -> void:
	var action_type := _get_action_type(action)
	var action_id := _get_action_id(action)
	match action_type:
		"gather":
			var output_item_id := _get_gather_output_item_id(action_id, rules)
			if int(state["inventory"].get(output_item_id, 0)) < _get_capacity(action_id, rules):
				state["inventory"][output_item_id] += 1
				var gather_skill_id := _get_resource_skill_id(action_id, rules)
				var gather_skill_state: Dictionary = state["skills"][gather_skill_id]
				state["skills"][gather_skill_id] = simulate_exp_gain(
					int(gather_skill_state["level"]),
					int(gather_skill_state["exp"]),
					int(gather_skill_state["exp_to_next"]),
					_get_resource_xp(action_id, rules),
					float(rules["exp_growth"])
				)
		"craft_tool":
			var crafting_skill_state: Dictionary = state["skills"]["crafting"]
			state["tools"][action_id]["durability"] = _get_tool_max_durability(action_id, rules)
			state["skills"]["crafting"] = simulate_exp_gain(
				int(crafting_skill_state["level"]),
				int(crafting_skill_state["exp"]),
				int(crafting_skill_state["exp_to_next"]),
				_get_tool_craft_xp(action_id, rules),
				float(rules["exp_growth"])
			)
		"craft_item":
			var item_crafting_skill_state: Dictionary = state["skills"]["crafting"]
			state["crafted_items"][action_id] += 1
			state["skills"]["crafting"] = simulate_exp_gain(
				int(item_crafting_skill_state["level"]),
				int(item_crafting_skill_state["exp"]),
				int(item_crafting_skill_state["exp_to_next"]),
				_get_craftable_craft_xp(action_id, rules),
				float(rules["exp_growth"])
			)
		"upgrade_craftable":
			var upgrade_skill_state: Dictionary = state["skills"]["crafting"]
			state["craftable_upgrade_levels"][action_id] += 1
			state["skills"]["crafting"] = simulate_exp_gain(
				int(upgrade_skill_state["level"]),
				int(upgrade_skill_state["exp"]),
				int(upgrade_skill_state["exp_to_next"]),
				_get_craftable_craft_xp(action_id, rules),
				float(rules["exp_growth"])
			)
		"process_recipe":
			var recipe_skill_id := _get_recipe_skill_id(action_id, rules)
			var recipe_skill_state: Dictionary = state["skills"][recipe_skill_id]
			var recipe_outputs := get_recipe_outputs(action_id, rules)
			for output_id in recipe_outputs.keys():
				state["inventory"][output_id] += int(recipe_outputs[output_id])
			state["skills"][recipe_skill_id] = simulate_exp_gain(
				int(recipe_skill_state["level"]),
				int(recipe_skill_state["exp"]),
				int(recipe_skill_state["exp_to_next"]),
				_get_recipe_craft_xp(action_id, rules),
				float(rules["exp_growth"])
			)


static func can_afford_inventory(stock: Dictionary, cost: Dictionary) -> bool:
	for resource_id in cost.keys():
		if int(stock.get(resource_id, 0)) < int(cost[resource_id]):
			return false

	return true


static func _get_action_type(action: Dictionary) -> String:
	return String(action.get("type", ""))


static func _get_action_id(action: Dictionary) -> String:
	return String(action.get("id", ""))


static func _get_action_station_id(action: Dictionary) -> String:
	return String(action.get("station_id", _get_action_id(action)))


static func _get_action_fuel_item_id(action: Dictionary) -> String:
	return String(action.get("fuel_item_id", ""))


static func _get_resource_skill_id(resource_id: String, rules: Dictionary) -> String:
	if not rules["gatherables"].has(resource_id):
		return "crafting"

	var gatherable: Dictionary = rules["gatherables"][resource_id]
	return String(gatherable.get("skill", "gathering"))


static func _get_gather_output_item_id(resource_id: String, rules: Dictionary) -> String:
	if not rules["gatherables"].has(resource_id):
		return resource_id

	var gatherable: Dictionary = rules["gatherables"][resource_id]
	return String(gatherable.get("output_item", resource_id))


static func _get_capacity(resource_id: String, rules: Dictionary) -> int:
	if not rules["gatherables"].has(resource_id):
		return 999999

	var gatherable: Dictionary = rules["gatherables"][resource_id]
	return int(gatherable["base_capacity"]) + int(rules["upgrade_levels"]["bag_space"]) * int(rules["bag_capacity_per_upgrade"])


static func _get_resource_xp(resource_id: String, rules: Dictionary) -> int:
	if not rules["gatherables"].has(resource_id):
		return 0

	var gatherable: Dictionary = rules["gatherables"][resource_id]
	return int(gatherable["xp"])


static func _get_unlock_level(resource_id: String, rules: Dictionary) -> int:
	var gatherable: Dictionary = rules["gatherables"][resource_id]
	return int(gatherable["unlock_level"])


static func _get_resource_name(resource_id: String, rules: Dictionary) -> String:
	if rules["items"].has(resource_id):
		var item: Dictionary = rules["items"][resource_id]
		return String(item["name"])

	var gatherable: Dictionary = rules["gatherables"][resource_id]
	return String(gatherable["name"])


static func _get_skill_name(skill_id: String, rules: Dictionary) -> String:
	var skill: Dictionary = rules["skill_definitions"][skill_id]
	return String(skill["name"])


static func _get_required_tool_id(resource_id: String, rules: Dictionary) -> String:
	var gatherable: Dictionary = rules["gatherables"][resource_id]
	if not gatherable.has("required_tool"):
		return ""

	return String(gatherable["required_tool"])


static func _get_tool_durability_cost(resource_id: String, rules: Dictionary) -> int:
	var gatherable: Dictionary = rules["gatherables"][resource_id]
	if not gatherable.has("tool_durability_cost"):
		return 0

	return int(gatherable["tool_durability_cost"])


static func _get_tool_name(tool_id: String, rules: Dictionary) -> String:
	var tool: Dictionary = rules["tool_definitions"][tool_id]
	return String(tool["name"])


static func _get_tool_max_durability(tool_id: String, rules: Dictionary) -> int:
	var tool: Dictionary = rules["tool_definitions"][tool_id]
	return int(tool["max_durability"])


static func _get_tool_craft_cost(tool_id: String, rules: Dictionary) -> Dictionary:
	var tool: Dictionary = rules["tool_definitions"][tool_id]
	return Dictionary(tool["craft_cost"]).duplicate(true)


static func _get_tool_craft_time(tool_id: String, rules: Dictionary) -> float:
	var tool: Dictionary = rules["tool_definitions"][tool_id]
	return float(tool["craft_time"])


static func _get_tool_craft_xp(tool_id: String, rules: Dictionary) -> int:
	var tool: Dictionary = rules["tool_definitions"][tool_id]
	return int(tool["craft_xp"])


static func _get_craftable_name(craftable_id: String, rules: Dictionary) -> String:
	var craftable: Dictionary = rules["craftables"][craftable_id]
	return String(craftable["name"])


static func _get_craftable_craft_cost(craftable_id: String, rules: Dictionary) -> Dictionary:
	var craftable: Dictionary = rules["craftables"][craftable_id]
	return Dictionary(craftable["craft_cost"]).duplicate(true)


static func _get_craftable_craft_time(craftable_id: String, rules: Dictionary) -> float:
	var craftable: Dictionary = rules["craftables"][craftable_id]
	return float(craftable["craft_time"])


static func _get_craftable_craft_xp(craftable_id: String, rules: Dictionary) -> int:
	var craftable: Dictionary = rules["craftables"][craftable_id]
	return int(craftable["craft_xp"])


static func _get_craftable_max_count(craftable_id: String, rules: Dictionary) -> int:
	var craftable: Dictionary = rules["craftables"][craftable_id]
	return int(craftable.get("max_count", 999999))


static func _get_craftable_upgrade_cost(craftable_id: String, from_level: int, rules: Dictionary) -> Dictionary:
	var multiplier := pow(_get_craftable_upgrade_cost_multiplier(craftable_id, rules), from_level)
	var base_cost := _get_craftable_craft_cost(craftable_id, rules)
	var scaled_cost := {}
	for resource_id in base_cost.keys():
		scaled_cost[resource_id] = int(ceil(float(base_cost[resource_id]) * multiplier))

	return scaled_cost


static func _get_craftable_upgrade_cost_multiplier(craftable_id: String, rules: Dictionary) -> float:
	var craftable: Dictionary = rules["craftables"][craftable_id]
	return float(craftable.get("upgrade_cost_multiplier", 1.3))


static func _get_craftable_station_speed_multiplier(craftable_id: String, rules: Dictionary) -> float:
	var craftable: Dictionary = rules["craftables"][craftable_id]
	return float(craftable.get("station_speed_multiplier", 0.85))


static func _get_station_fuel_capacity(craftable_id: String, rules: Dictionary) -> int:
	var craftable: Dictionary = rules["craftables"][craftable_id]
	return int(craftable.get("fuel_capacity", 0))


static func _get_recipe_station_id(recipe_id: String, rules: Dictionary) -> String:
	var recipe: Dictionary = rules["recipes"][recipe_id]
	return String(recipe.get("station", ""))


static func _get_recipe_craft_cost(recipe_id: String, rules: Dictionary) -> Dictionary:
	var recipe: Dictionary = rules["recipes"][recipe_id]
	return Dictionary(recipe.get("craft_cost", {})).duplicate(true)


static func _get_recipe_craft_xp(recipe_id: String, rules: Dictionary) -> int:
	var recipe: Dictionary = rules["recipes"][recipe_id]
	return int(recipe.get("craft_xp", 0))


static func _get_recipe_skill_id(recipe_id: String, rules: Dictionary) -> String:
	var recipe: Dictionary = rules["recipes"][recipe_id]
	return String(recipe.get("skill", "crafting"))


static func _get_recipe_fuel_cost_units(recipe_id: String, rules: Dictionary) -> int:
	var recipe: Dictionary = rules["recipes"][recipe_id]
	return int(recipe.get("fuel_cost_units", 0))


static func _format_cost(cost: Dictionary, rules: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in rules["inventory_item_order"]:
		if not cost.has(resource_id):
			continue

		parts.append("%d %s" % [int(cost[resource_id]), _get_resource_name(String(resource_id), rules)])

	if parts.is_empty():
		return "Free"

	return ", ".join(parts)
