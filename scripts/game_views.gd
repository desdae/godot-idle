extends RefCounted

const GameActions = preload("res://scripts/game_actions.gd")
const GameData = preload("res://scripts/game_data.gd")
const GameEconomy = preload("res://scripts/game_economy.gd")
const GamePresentation = preload("res://scripts/game_presentation.gd")


static func get_resource_card_view(
	resource_id: String,
	data: Dictionary,
	upgrade_levels: Dictionary,
	bag_capacity_per_upgrade: int,
	inventory: Dictionary,
	skill_states: Dictionary,
	current_action: Dictionary,
	block_reason: String,
	gather_duration: float,
	queue_tooltip: String
) -> Dictionary:
	var unlock_level := GameData.get_unlock_level(resource_id, data)
	var current_capacity := GameEconomy.get_capacity(resource_id, data, upgrade_levels, bag_capacity_per_upgrade)
	var output_item_id := GameData.get_gather_output_item_id(resource_id, data)
	var inventory_count := int(inventory.get(output_item_id, 0))
	var xp := GameData.get_resource_xp(resource_id, data)
	var is_current_action := _is_current_action(current_action, "gather", resource_id)
	var display_duration := maxf(0.001, float(current_action["duration"])) if is_current_action else gather_duration
	var stats_text := "Lv %d | %.2fs | %d XP | %d/%d" % [
		unlock_level,
		display_duration,
		xp,
		inventory_count,
		current_capacity,
	]
	if not _is_resource_unlocked(resource_id, data, skill_states):
		return {
			"stats_text": stats_text,
			"button_text": "Locked",
			"button_disabled": true,
			"button_tooltip": "",
		}

	if block_reason != "" and not is_current_action:
		var button_text := "Blocked"
		if block_reason.begins_with("Need "):
			button_text = block_reason
		elif block_reason == "Full at end of queue":
			button_text = "Full"
		elif block_reason == "Queue full":
			button_text = "Queue Full"

		return {
			"stats_text": stats_text,
			"button_text": button_text,
			"button_disabled": true,
			"button_tooltip": "",
		}

	return {
		"stats_text": stats_text,
		"button_text": "Queue +1" if is_current_action else "Queue",
		"button_disabled": false,
		"button_tooltip": queue_tooltip,
	}


static func get_station_status_view(
	craftable_id: String,
	data: Dictionary,
	crafted_items: Dictionary,
	craftable_upgrade_levels: Dictionary,
	stored_fuel_units: Dictionary,
	is_expanded: bool
) -> Dictionary:
	var built_count := int(crafted_items.get(craftable_id, 0))
	var station_level := _get_processing_station_level(craftable_id, crafted_items, craftable_upgrade_levels)
	var fuel_capacity := GameData.get_station_fuel_capacity(craftable_id, data)
	var fuel_stored := int(stored_fuel_units.get(craftable_id, 0))
	var speed_multiplier := GameEconomy.get_craftable_speed_multiplier(craftable_id, int(craftable_upgrade_levels.get(craftable_id, 0)), data)

	var status_text := "Build %s to unlock its recipes." % GameData.get_craftable_name(craftable_id, data)
	if built_count > 0:
		if fuel_capacity > 0:
			status_text = "Lv %d | Fuel %d/%d | %.0f%% faster station crafting" % [
				station_level,
				fuel_stored,
				fuel_capacity,
				(1.0 - speed_multiplier) * 100.0,
			]
		else:
			status_text = "Lv %d | %.0f%% faster station crafting" % [
				station_level,
				(1.0 - speed_multiplier) * 100.0,
			]

	return {
		"toggle_text": "Collapse" if is_expanded else "Expand",
		"recipes_visible": is_expanded,
		"status_text": status_text,
		"show_fuel_summary": built_count > 0,
	}


static func get_fuel_button_view(
	fuel_item_id: String,
	data: Dictionary,
	current_action: Dictionary,
	craftable_id: String,
	fuel_block_reason: String,
	queue_tooltip: String
) -> Dictionary:
	var is_refueling_now := (
		not current_action.is_empty()
		and GameActions.get_action_type(current_action) == "refuel_station"
		and GameActions.get_action_station_id(current_action) == craftable_id
		and GameActions.get_action_fuel_item_id(current_action) == fuel_item_id
	)
	var button_text := GameData.get_resource_name(fuel_item_id, data)
	if is_refueling_now:
		button_text = "Loading..."
	elif fuel_block_reason == "Fuel full":
		button_text = "Fuel Full"
	elif fuel_block_reason == "No fuel space":
		button_text = "No Space"
	elif fuel_block_reason == "Queue full":
		button_text = "Queue Full"
	elif fuel_block_reason.begins_with("Need "):
		button_text = fuel_block_reason
	elif fuel_block_reason != "":
		button_text = "Blocked"

	var button_disabled := is_refueling_now or fuel_block_reason != ""
	return {
		"button_text": button_text,
		"button_disabled": button_disabled,
		"button_tooltip": queue_tooltip if not button_disabled else "",
		"is_full": fuel_block_reason == "Fuel full",
	}


static func get_tool_card_view(
	tool_id: String,
	data: Dictionary,
	tools: Dictionary,
	inventory: Dictionary,
	current_action: Dictionary,
	current_action_time_left: float,
	is_crafting_queued: bool,
	block_reason: String
) -> Dictionary:
	var durability := int(tools[tool_id]["durability"])
	var max_durability := GameData.get_tool_max_durability(tool_id, data)
	var tool_name := GameData.get_tool_name(tool_id, data)
	var is_crafting_now := _is_current_action(current_action, "craft_tool", tool_id)
	var status_text := "%s: Not crafted" % tool_name
	if is_crafting_now:
		status_text = "%s: Crafting (%s left)" % [
			tool_name,
			GamePresentation.format_seconds(current_action_time_left),
		]
	elif durability > 0:
		status_text = "%s: %d / %d durability" % [tool_name, durability, max_durability]

	var detail_text := GamePresentation.format_recipe_detail_rich_text(
		GameData.get_tool_craft_time(tool_id, data),
		GameData.get_tool_craft_xp(tool_id, data),
		GameData.get_tool_craft_cost(tool_id, data),
		GameData.get_tool_use_text(tool_id, data),
		data,
		inventory
	)
	var button_text := "Queue %s" % tool_name
	if is_crafting_now:
		button_text = "Crafting..."
	elif is_crafting_queued:
		button_text = "Queued"
	elif durability >= max_durability:
		button_text = "%s Ready" % tool_name

	return {
		"status_text": status_text,
		"detail_text": detail_text,
		"button_text": button_text,
		"button_disabled": is_crafting_now or is_crafting_queued or block_reason != "",
	}


static func get_craftable_card_view(
	craftable_id: String,
	data: Dictionary,
	inventory: Dictionary,
	crafted_items: Dictionary,
	craftable_upgrade_levels: Dictionary,
	current_action: Dictionary,
	current_action_time_left: float,
	block_reason: String,
	upgrade_block_reason: String
) -> Dictionary:
	var owned_count := int(crafted_items.get(craftable_id, 0))
	var station_level := _get_processing_station_level(craftable_id, crafted_items, craftable_upgrade_levels)
	var craftable_name := GameData.get_craftable_name(craftable_id, data)
	var is_crafting_now := _is_current_action(current_action, "craft_item", craftable_id)
	var is_upgrading_now := _is_current_action(current_action, "upgrade_craftable", craftable_id)
	var can_upgrade := owned_count > 0
	var status_text := "%s: Not built" % craftable_name
	if is_crafting_now:
		status_text = "%s: Building (%s left)" % [
			craftable_name,
			GamePresentation.format_seconds(current_action_time_left),
		]
	elif is_upgrading_now:
		status_text = "%s: Upgrading to Lv %d (%s left)" % [
			craftable_name,
			station_level + 1,
			GamePresentation.format_seconds(current_action_time_left),
		]
	elif owned_count > 0:
		status_text = "%s: Built | Station Lv %d | %.0f%% faster" % [
			craftable_name,
			station_level,
			(1.0 - GameEconomy.get_craftable_speed_multiplier(craftable_id, int(craftable_upgrade_levels.get(craftable_id, 0)), data)) * 100.0,
		]

	var detail_text := ""
	if owned_count > 0:
		detail_text = GamePresentation.format_recipe_detail_rich_text(
			GameData.get_craftable_craft_time(craftable_id, data),
			GameData.get_craftable_craft_xp(craftable_id, data),
			GameEconomy.get_craftable_upgrade_cost(craftable_id, int(craftable_upgrade_levels.get(craftable_id, 0)), data, GameData.get_inventory_item_order(data)),
			"Next upgrade: 15%% faster station recipes. %s" % GameData.get_craftable_use_text(craftable_id, data),
			data,
			inventory
		)
	else:
		detail_text = GamePresentation.format_recipe_detail_rich_text(
			GameData.get_craftable_craft_time(craftable_id, data),
			GameData.get_craftable_craft_xp(craftable_id, data),
			GameData.get_craftable_craft_cost(craftable_id, data),
			GameData.get_craftable_use_text(craftable_id, data),
			data,
			inventory
		)

	var button_text := "Build %s" % craftable_name
	if is_crafting_now:
		button_text = "Building..."
	elif is_upgrading_now:
		button_text = "Upgrading..."
	elif can_upgrade:
		button_text = "Upgrade %s" % craftable_name

	return {
		"status_text": status_text,
		"detail_text": detail_text,
		"button_text": button_text,
		"button_disabled": is_crafting_now or is_upgrading_now or (upgrade_block_reason != "" if can_upgrade else block_reason != ""),
	}


static func get_recipe_card_view(
	recipe_id: String,
	data: Dictionary,
	inventory: Dictionary,
	crafted_items: Dictionary,
	current_action: Dictionary,
	current_action_time_left: float,
	block_reason: String,
	display_duration: float,
	recipe_cost: Dictionary,
	recipe_outputs: Dictionary,
	queue_tooltip: String
) -> Dictionary:
	var station_id := GameData.get_recipe_station_id(recipe_id, data)
	var station_ready := int(crafted_items.get(station_id, 0)) > 0
	var is_processing_now := _is_current_action(current_action, "process_recipe", recipe_id)
	var summary_text := ""
	if station_ready:
		summary_text = "%.2fs | +%d XP | Cost: %s | Output: %s" % [
			display_duration,
			GameData.get_recipe_craft_xp(recipe_id, data),
			GamePresentation.format_cost_markup(recipe_cost, data, inventory),
			GamePresentation.format_cost(recipe_outputs, data),
		]
		var fuel_cost_units := GameData.get_recipe_fuel_cost_units(recipe_id, data)
		if fuel_cost_units > 0:
			summary_text += " | Fuel: %d" % fuel_cost_units
		if is_processing_now:
			summary_text += " | %s left" % GamePresentation.format_seconds(current_action_time_left)

	var button_text := "Queue +1" if is_processing_now else "Queue"
	if block_reason != "" and not is_processing_now:
		button_text = block_reason if block_reason.length() <= 18 else "Blocked"

	var button_disabled := block_reason != "" and not is_processing_now
	return {
		"summary_text": summary_text,
		"button_text": button_text,
		"button_disabled": button_disabled,
		"button_tooltip": queue_tooltip if not button_disabled else "",
	}


static func get_upgrade_card_view(
	upgrade_id: String,
	data: Dictionary,
	inventory: Dictionary,
	upgrade_levels: Dictionary,
	next_cost: Dictionary,
	detail_text: String,
	can_afford: bool
) -> Dictionary:
	return {
		"level_text": "Lv %d" % int(upgrade_levels[upgrade_id]),
		"detail_text": detail_text,
		"cost_text": GamePresentation.format_cost_rich_text(next_cost, data, inventory),
		"button_disabled": not can_afford,
	}


static func get_runtime_status_view(
	current_action: Dictionary,
	is_queue_paused: bool,
	action_queue_size: int,
	queue_capacity: int,
	estimated_time_left: float,
	data: Dictionary
) -> Dictionary:
	var active_count := 0
	if not current_action.is_empty():
		active_count = 1

	var current_action_text := "Current action: Paused" if is_queue_paused else "Current action: Idle"
	if not current_action.is_empty():
		var duration := maxf(0.001, float(current_action["duration"]))
		var elapsed := minf(float(current_action["elapsed"]), duration)
		var percent := int(round((elapsed / duration) * 100.0))
		var time_left := maxf(0.0, duration - elapsed)
		var action_prefix := "Current action"
		if is_queue_paused:
			action_prefix = "Current action (Paused)"
		current_action_text = "%s: %s (%d%%, %s left)" % [
			action_prefix,
			GameActions.get_action_progress_label(current_action, data),
			clampi(percent, 0, 100),
			GamePresentation.format_seconds(time_left),
		]

	var queue_state_text := "Paused" if is_queue_paused else "Running"
	return {
		"current_action_text": current_action_text,
		"queue_summary_text": "Pipeline: %s | %d active, %d queued / %d queued slots" % [
			queue_state_text,
			active_count,
			action_queue_size,
			queue_capacity,
		],
		"queue_time_left_text": "Total time left: %s" % GamePresentation.format_seconds(estimated_time_left),
	}


static func get_hover_queue_button_text(
	base_text: String,
	is_hovered: bool,
	is_ctrl_pressed: bool,
	is_shift_pressed: bool,
	free_queue_slots: int,
	compact: bool = false
) -> String:
	if not is_hovered:
		return base_text

	if is_ctrl_pressed:
		return "+%d" % free_queue_slots if compact else "Queue +%d" % free_queue_slots
	if is_shift_pressed:
		return "+5" if compact else "Queue +5"

	return base_text


static func get_gather_progress_value(resource_id: String, current_action: Dictionary) -> float:
	if not _is_current_action(current_action, "gather", resource_id):
		return 0.0

	var duration := maxf(0.001, float(current_action["duration"]))
	return clampf((float(current_action["elapsed"]) / duration) * 100.0, 0.0, 100.0)


static func get_active_skill_id(active_tab_title: String, active_gather_skill_id: String) -> String:
	if active_tab_title == "Tools" or active_tab_title == "Buildables":
		return "crafting"
	if active_tab_title == "Processing":
		return "cooking"
	if active_tab_title != "Gatherables":
		return ""

	return active_gather_skill_id


static func get_skill_context_text(active_skill_id: String, data: Dictionary, skill_states: Dictionary) -> String:
	if active_skill_id == "":
		return "Upgrades improve gathering speed, bag size, and queue size across skills."

	if active_skill_id == "crafting":
		return "Crafting levels up by making tools and buildables."
	if active_skill_id == "cooking":
		return "Cooking levels up by processing meals like Cook Rabbit."

	return "%s: %s" % [
		GameData.get_skill_name(active_skill_id, data),
		_get_next_unlock_text_for_skill(active_skill_id, data, skill_states),
	]


static func get_skill_row_view(skill_id: String, data: Dictionary, skill_states: Dictionary, active_skill_id: String) -> Dictionary:
	var skill_level := int(skill_states[skill_id]["level"])
	var skill_exp := int(skill_states[skill_id]["exp"])
	var skill_exp_to_next := int(skill_states[skill_id]["exp_to_next"])
	var is_active := skill_id == active_skill_id
	var exp_progress := 0.0
	if skill_exp_to_next > 0:
		exp_progress = float(skill_exp) / float(skill_exp_to_next) * 100.0

	return {
		"skill_label_text": "%s Lv %d" % [GameData.get_skill_name(skill_id, data), skill_level],
		"exp_label_text": "%d / %d" % [skill_exp, skill_exp_to_next],
		"exp_progress": exp_progress,
		"panel_style": _make_skill_card_style(is_active),
		"skill_label_color": Color(1, 1, 1, 1) if is_active else Color(0.82, 0.82, 0.82, 1),
		"exp_label_color": Color(0.9, 0.9, 0.9, 1) if is_active else Color(0.65, 0.65, 0.65, 1),
	}


static func _is_current_action(current_action: Dictionary, action_type: String, action_id: String) -> bool:
	return not current_action.is_empty() and GameActions.get_action_type(current_action) == action_type and GameActions.get_action_id(current_action) == action_id


static func _is_resource_unlocked(resource_id: String, data: Dictionary, skill_states: Dictionary) -> bool:
	var skill_id := GameData.get_resource_skill_id(resource_id, data)
	return int(skill_states[skill_id]["level"]) >= GameData.get_unlock_level(resource_id, data)


static func _get_processing_station_level(craftable_id: String, crafted_items: Dictionary, craftable_upgrade_levels: Dictionary) -> int:
	if int(crafted_items.get(craftable_id, 0)) <= 0:
		return 0

	return int(craftable_upgrade_levels.get(craftable_id, 0)) + 1


static func _get_next_unlock_text_for_skill(skill_id: String, data: Dictionary, skill_states: Dictionary) -> String:
	var skill_level := int(skill_states[skill_id]["level"])
	for resource_id in data["gatherable_order"]:
		if GameData.get_resource_skill_id(resource_id, data) != skill_id:
			continue

		var unlock_level := GameData.get_unlock_level(resource_id, data)
		if skill_level < unlock_level:
			return "Next: %s Lv %d" % [GameData.get_resource_name(resource_id, data), unlock_level]

	return "All unlocked"


static func _make_skill_card_style(is_active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.21, 0.21, 0.21, 1) if is_active else Color(0.16, 0.16, 0.16, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.75, 0.75, 0.75, 0.95) if is_active else Color(0.24, 0.24, 0.24, 1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style
