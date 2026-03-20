extends RefCounted

const GameData = preload("res://scripts/game_data.gd")
const GameDomain = preload("res://scripts/game_domain.gd")
const GameEconomy = preload("res://scripts/game_economy.gd")
const GamePresentation = preload("res://scripts/game_presentation.gd")
const GameQueries = preload("res://scripts/game_queries.gd")
const GameState = preload("res://scripts/game_state.gd")
const GameUiRefresh = preload("res://scripts/game_ui_refresh.gd")
const GameViews = preload("res://scripts/game_views.gd")


static func refresh_ui(game: Dictionary) -> void:
	refresh_skill_section(game)
	GameUiRefresh.refresh_queue_list(game["queue_list"], game["current_action"], game["action_queue"], game["data"])
	GameUiRefresh.refresh_queue_controls(
		game["clear_queue_button"],
		game["pause_queue_button"],
		bool(game["is_queue_paused"]),
		game["current_action"],
		game["action_queue"]
	)
	_refresh_tool_panel(game)
	_refresh_craftable_panel(game)
	_refresh_processing_panel(game)
	_refresh_item_summary(game)
	_refresh_resource_cards(game)
	_refresh_upgrade_cards(game)
	refresh_runtime_status(game)


static func refresh_skill_section(game: Dictionary) -> void:
	var active_skill_id := get_active_skill_id(game)
	var data: Dictionary = game["data"]
	var skill_states: Dictionary = game["skill_states"]
	var skill_rows: Dictionary = game["skill_rows"]

	for skill_id in game["skill_order"]:
		var view := GameViews.get_skill_row_view(skill_id, data, skill_states, active_skill_id)
		GameUiRefresh.apply_skill_row(skill_rows[skill_id], view)

	var skill_context_label: Label = game["skill_context_label"]
	if skill_context_label != null:
		skill_context_label.text = GameViews.get_skill_context_text(active_skill_id, data, skill_states)


static func refresh_runtime_status(game: Dictionary) -> void:
	var current_action: Dictionary = game["current_action"]
	var action_queue: Array = game["action_queue"]
	var simulation_state: Dictionary = game["simulation_state"]
	var rules_context: Dictionary = game["rules"]
	var queue_capacity := _get_queue_capacity(game)
	var estimated_time_left := GameQueries.estimate_queue_time_left(
		current_action,
		action_queue,
		simulation_state,
		GameState.get_current_action_time_left(current_action),
		rules_context
	)
	var view := GameViews.get_runtime_status_view(
		current_action,
		bool(game["is_queue_paused"]),
		action_queue.size(),
		queue_capacity,
		estimated_time_left,
		game["data"]
	)
	GameUiRefresh.apply_runtime_status(
		game["current_action_label"],
		game["queue_summary_label"],
		game["queue_time_left_label"],
		view
	)
	_update_gather_bars(game)


static func refresh_queue_button_hover_previews(game: Dictionary) -> void:
	var is_ctrl_pressed := Input.is_key_pressed(KEY_CTRL)
	var is_shift_pressed := Input.is_key_pressed(KEY_SHIFT)
	var free_queue_slots := GameQueries.get_free_queue_slots(game["action_queue"].size(), _get_queue_capacity(game))
	var current_action: Dictionary = game["current_action"]
	var queue_tooltip := GamePresentation.get_queue_button_tooltip()

	for resource_id in game["gatherable_order"]:
		var card: Dictionary = game["resource_cards"][resource_id]
		var queue_button: Button = card["queue_button"]
		if queue_button.disabled:
			continue

		var is_current_action := GameState.is_current_action(current_action, "gather", resource_id)
		var base_text := "Queue +1" if is_current_action else "Queue"
		queue_button.tooltip_text = queue_tooltip
		queue_button.text = GameViews.get_hover_queue_button_text(
			base_text,
			queue_button.is_hovered(),
			is_ctrl_pressed,
			is_shift_pressed,
			free_queue_slots
		)

	for recipe_id in game["recipe_order"]:
		if not game["recipe_cards"].has(recipe_id):
			continue

		var recipe_card: Dictionary = game["recipe_cards"][recipe_id]
		var recipe_button: Button = recipe_card["button"]
		if recipe_button.disabled:
			continue

		var is_current_recipe := GameState.is_current_action(current_action, "process_recipe", recipe_id)
		var recipe_base_text := "Queue +1" if is_current_recipe else "Queue"
		recipe_button.text = GameViews.get_hover_queue_button_text(
			recipe_base_text,
			recipe_button.is_hovered(),
			is_ctrl_pressed,
			is_shift_pressed,
			free_queue_slots
		)

	for craftable_id in game["processing_station_cards"].keys():
		var station_card: Dictionary = game["processing_station_cards"][craftable_id]
		var fuel_buttons: Dictionary = station_card["fuel_buttons"]
		for fuel_item_id in fuel_buttons.keys():
			var fuel_button: Button = fuel_buttons[fuel_item_id]
			if fuel_button.disabled:
				continue

			var fuel_base_text := GameData.get_resource_name(fuel_item_id, game["data"])
			fuel_button.text = GameViews.get_hover_queue_button_text(
				fuel_base_text,
				fuel_button.is_hovered(),
				is_ctrl_pressed,
				is_shift_pressed,
				free_queue_slots,
				true
			)


static func get_requested_queue_amount(
	is_ctrl_pressed: bool,
	is_shift_pressed: bool,
	action_queue_size: int,
	queue_capacity: int
) -> int:
	if is_ctrl_pressed:
		return GameQueries.get_free_queue_slots(action_queue_size, queue_capacity)
	if is_shift_pressed:
		return 5

	return 1


static func get_active_skill_id(game: Dictionary) -> String:
	var main_tabs: TabContainer = game["main_tabs"]
	if main_tabs == null or main_tabs.get_tab_count() == 0:
		return ""

	var active_tab_title := main_tabs.get_tab_title(main_tabs.current_tab)
	var active_gather_skill_id := ""
	var gatherable_skill_tabs: TabContainer = game["gatherable_skill_tabs"]
	if gatherable_skill_tabs != null and gatherable_skill_tabs.get_tab_count() > 0:
		active_gather_skill_id = String(gatherable_skill_tabs.get_child(gatherable_skill_tabs.current_tab).name)

	return GameViews.get_active_skill_id(active_tab_title, active_gather_skill_id)


static func _refresh_resource_cards(game: Dictionary) -> void:
	var data: Dictionary = game["data"]
	var rules_context: Dictionary = game["rules"]
	var simulation_state: Dictionary = game["simulation_state"]
	var queue_capacity := _get_queue_capacity(game)
	var queue_tooltip := GamePresentation.get_queue_button_tooltip()

	for resource_id in game["gatherable_order"]:
		var view := GameViews.get_resource_card_view(
			resource_id,
			data,
			game["upgrade_levels"],
			int(game["bag_capacity_per_upgrade"]),
			game["inventory"],
			game["skill_states"],
			game["current_action"],
			GameQueries.get_gather_queue_block_reason(
				resource_id,
				game["action_queue"],
				queue_capacity,
				game["current_action"],
				simulation_state,
				rules_context
			),
			GameQueries.get_gather_action_duration(resource_id, simulation_state, rules_context),
			queue_tooltip
		)
		GameUiRefresh.apply_resource_card(game["resource_cards"][resource_id], view)


static func _refresh_tool_panel(game: Dictionary) -> void:
	var data: Dictionary = game["data"]
	var rules_context: Dictionary = game["rules"]
	var simulation_state: Dictionary = game["simulation_state"]
	var queue_capacity := _get_queue_capacity(game)
	var current_action: Dictionary = game["current_action"]
	var current_action_time_left := GameState.get_current_action_time_left(current_action)

	for tool_id in game["tool_order"]:
		var view := GameViews.get_tool_card_view(
			tool_id,
			data,
			game["tools"],
			game["inventory"],
			current_action,
			current_action_time_left,
			GameState.has_queued_action(game["action_queue"], "craft_tool", tool_id),
			GameQueries.get_tool_queue_block_reason(
				tool_id,
				game["action_queue"],
				queue_capacity,
				current_action,
				simulation_state,
				rules_context
			)
		)
		GameUiRefresh.apply_tool_card(game["tool_cards"][tool_id], view)


static func _refresh_craftable_panel(game: Dictionary) -> void:
	var data: Dictionary = game["data"]
	var rules_context: Dictionary = game["rules"]
	var simulation_state: Dictionary = game["simulation_state"]
	var queue_capacity := _get_queue_capacity(game)
	var current_action: Dictionary = game["current_action"]
	var current_action_time_left := GameState.get_current_action_time_left(current_action)

	for craftable_id in game["craftable_order"]:
		var view := GameViews.get_craftable_card_view(
			craftable_id,
			data,
			game["inventory"],
			game["crafted_items"],
			game["craftable_upgrade_levels"],
			current_action,
			current_action_time_left,
			GameQueries.get_craftable_queue_block_reason(
				craftable_id,
				game["action_queue"],
				queue_capacity,
				current_action,
				simulation_state,
				rules_context
			),
			GameQueries.get_craftable_upgrade_queue_block_reason(
				craftable_id,
				game["action_queue"],
				queue_capacity,
				current_action,
				simulation_state,
				rules_context
			)
		)
		GameUiRefresh.apply_craftable_card(game["craftable_cards"][craftable_id], view)


static func _refresh_processing_panel(game: Dictionary) -> void:
	var data: Dictionary = game["data"]
	var rules_context: Dictionary = game["rules"]
	var simulation_state: Dictionary = game["simulation_state"]
	var queue_capacity := _get_queue_capacity(game)
	var queue_tooltip := GamePresentation.get_queue_button_tooltip()
	var processing_station_cards: Dictionary = game["processing_station_cards"]

	for craftable_id in game["craftable_order"]:
		if not processing_station_cards.has(craftable_id):
			continue

		var station_card: Dictionary = processing_station_cards[craftable_id]
		var fuel_buttons: Dictionary = station_card["fuel_buttons"]
		var is_expanded := bool(game["processing_station_expanded"].get(craftable_id, true))
		var station_view := GameViews.get_station_status_view(
			craftable_id,
			data,
			game["crafted_items"],
			game["craftable_upgrade_levels"],
			game["stored_fuel_units"],
			is_expanded
		)

		var all_fuel_buttons_full := fuel_buttons.size() > 0 and bool(station_view["show_fuel_summary"])
		var fuel_views := {}
		for fuel_item_id in fuel_buttons.keys():
			var fuel_block_reason := GameQueries.get_station_fuel_queue_block_reason(
				craftable_id,
				fuel_item_id,
				game["action_queue"],
				queue_capacity,
				game["current_action"],
				simulation_state,
				rules_context
			)
			fuel_views[fuel_item_id] = GameViews.get_fuel_button_view(
				fuel_item_id,
				data,
				game["current_action"],
				craftable_id,
				fuel_block_reason,
				queue_tooltip
			)
			all_fuel_buttons_full = all_fuel_buttons_full and bool(fuel_views[fuel_item_id]["is_full"])

		GameUiRefresh.apply_station_card(station_card, station_view, fuel_views, all_fuel_buttons_full)

	for recipe_id in game["recipe_order"]:
		_refresh_recipe_card(game, recipe_id)


static func _refresh_item_summary(game: Dictionary) -> void:
	for item_id in GameData.get_processing_summary_item_ids(game["data"]):
		if not game["item_labels"].has(item_id):
			continue

		GameUiRefresh.apply_item_summary(
			game["item_labels"][item_id],
			"%s: %d" % [GameData.get_resource_name(item_id, game["data"]), int(game["inventory"].get(item_id, 0))],
			GameData.get_item_description(item_id, game["data"])
		)


static func _refresh_recipe_card(game: Dictionary, recipe_id: String) -> void:
	var card: Dictionary = game["recipe_cards"].get(recipe_id, {})
	if card.is_empty():
		return

	var current_action: Dictionary = game["current_action"]
	var is_processing_now := GameState.is_current_action(current_action, "process_recipe", recipe_id)
	var simulation_state: Dictionary = game["simulation_state"]
	var rules_context: Dictionary = game["rules"]
	var display_duration := maxf(0.001, float(current_action["duration"])) if is_processing_now else GameDomain.get_recipe_craft_time(
		recipe_id,
		simulation_state,
		rules_context
	)
	var view := GameViews.get_recipe_card_view(
		recipe_id,
		game["data"],
		game["inventory"],
		game["crafted_items"],
		current_action,
		GameState.get_current_action_time_left(current_action),
		GameQueries.get_recipe_queue_block_reason(
			recipe_id,
			game["action_queue"],
			_get_queue_capacity(game),
			current_action,
			simulation_state,
			rules_context
		),
		display_duration,
		GameDomain.get_recipe_craft_cost(recipe_id, game["data"]),
		GameDomain.get_recipe_outputs(recipe_id, rules_context),
		GamePresentation.get_queue_button_tooltip()
	)
	GameUiRefresh.apply_recipe_card(card, view)


static func _refresh_upgrade_cards(game: Dictionary) -> void:
	for upgrade_id in game["upgrade_order"]:
		var next_cost := GameDomain.get_upgrade_cost(upgrade_id, game["upgrade_levels"], game["upgrades"], game["data"])
		var view := GameViews.get_upgrade_card_view(
			upgrade_id,
			game["data"],
			game["inventory"],
			game["upgrade_levels"],
			next_cost,
			GamePresentation.get_upgrade_detail(
				upgrade_id,
				game["upgrade_levels"],
				int(game["bag_capacity_per_upgrade"]),
				float(game["speed_upgrade_multiplier"]),
				int(game["queue_size_per_upgrade"]),
				int(game["base_queue_size"])
			),
			GameDomain.can_afford(next_cost, game["inventory"])
		)
		GameUiRefresh.apply_upgrade_card(game["upgrade_cards"][upgrade_id], view)


static func _update_gather_bars(game: Dictionary) -> void:
	for resource_id in game["gatherable_order"]:
		var card: Dictionary = game["resource_cards"][resource_id]
		var bar: ProgressBar = card["gather_bar"]
		bar.value = GameViews.get_gather_progress_value(resource_id, game["current_action"])


static func _get_queue_capacity(game: Dictionary) -> int:
	return GameEconomy.get_queue_capacity(
		game["upgrade_levels"],
		int(game["base_queue_size"]),
		int(game["queue_size_per_upgrade"])
	)
