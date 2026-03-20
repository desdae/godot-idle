extends Control

const GameActions = preload("res://scripts/game_actions.gd")
const GameCommands = preload("res://scripts/game_commands.gd")
const GameData = preload("res://scripts/game_data.gd")
const GameDomain = preload("res://scripts/game_domain.gd")
const GameEconomy = preload("res://scripts/game_economy.gd")
const GameInteractions = preload("res://scripts/game_interactions.gd")
const GamePresentation = preload("res://scripts/game_presentation.gd")
const GameQueries = preload("res://scripts/game_queries.gd")
const GameQueue = preload("res://scripts/game_queue.gd")
const GameRules = preload("res://scripts/game_rules.gd")
const GameRuntime = preload("res://scripts/game_runtime.gd")
const GameState = preload("res://scripts/game_state.gd")
const GameUiBuilder = preload("res://scripts/game_ui_builder.gd")
const GameUiController = preload("res://scripts/game_ui_controller.gd")

var game_title := "Idle Gatherer"
var game_subtitle := "Gather, craft a Stone Axe for Logs, and spend resources on stronger tools, bigger bags, and longer queues."
var exp_growth := 1.25
var level_speed_multiplier := 0.96
var speed_upgrade_multiplier := 0.9
var min_gather_time := 0.35
var base_queue_size := 5
var queue_size_per_upgrade := 3
var bag_capacity_per_upgrade := 4
var layout_stack_breakpoint := 1024.0

var skill_order: Array = []
var skill_definitions := {}
var gatherable_order: Array = []
var gatherables := {}
var item_order: Array = []
var items := {}
var tool_order: Array = []
var tool_definitions := {}
var craftable_order: Array = []
var craftables := {}
var recipe_order: Array = []
var recipes := {}
var upgrade_order: Array = []
var upgrades := {}

var inventory := {}
var tools := {}
var crafted_items := {}
var craftable_upgrade_levels := {}
var stored_fuel_units := {}
var action_queue: Array[Dictionary] = []
var current_action := {}
var current_action_completion_pending := false
var is_queue_paused := false

var skill_states := {}
var upgrade_levels := {}

var resource_cards := {}
var upgrade_cards := {}
var skill_rows := {}

var current_action_label: Label
var queue_summary_label: Label
var queue_time_left_label: Label
var queue_list: ItemList
var clear_queue_button: Button
var pause_queue_button: Button
var skill_context_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var toast_time_left := 0.0
var page_margin: MarginContainer
var root_box: VBoxContainer
var content_grid: GridContainer
var main_tabs: TabContainer
var queue_column: VBoxContainer
var gatherable_skill_tabs: TabContainer
var tool_cards := {}
var craftable_cards := {}
var recipe_cards := {}
var item_labels := {}
var processing_station_cards := {}
var processing_station_expanded := {}


func _ready() -> void:
	if not _load_game_data():
		set_process(false)
		return

	_initialize_state()
	_build_ui()
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()
	_refresh_ui()


func _load_game_data() -> bool:
	var config_data = _load_json_file("res://data/config.json")
	if typeof(config_data) != TYPE_DICTIONARY:
		return false

	var progression: Dictionary = config_data.get("progression", {})
	exp_growth = float(progression.get("exp_growth", exp_growth))
	level_speed_multiplier = float(progression.get("level_speed_multiplier", level_speed_multiplier))
	speed_upgrade_multiplier = float(progression.get("speed_upgrade_multiplier", speed_upgrade_multiplier))
	min_gather_time = float(progression.get("min_gather_time", min_gather_time))
	base_queue_size = int(progression.get("base_queue_size", base_queue_size))
	queue_size_per_upgrade = int(progression.get("queue_size_per_upgrade", queue_size_per_upgrade))
	bag_capacity_per_upgrade = int(progression.get("bag_capacity_per_upgrade", bag_capacity_per_upgrade))

	var ui_data: Dictionary = config_data.get("ui", {})
	game_title = String(ui_data.get("title", game_title))
	game_subtitle = String(ui_data.get("subtitle", game_subtitle))
	layout_stack_breakpoint = float(ui_data.get("layout_stack_breakpoint", layout_stack_breakpoint))

	var skill_data := _load_ordered_data_file("res://data/skills.json")
	if not skill_data.get("ok", false):
		return false
	skill_order = skill_data["order"]
	skill_definitions = skill_data["entries"]

	var gatherable_data := _load_ordered_data_file("res://data/gatherables.json")
	if not gatherable_data.get("ok", false):
		return false
	gatherable_order = gatherable_data["order"]
	gatherables = gatherable_data["entries"]

	var item_data := _load_ordered_data_file("res://data/items.json")
	if not item_data.get("ok", false):
		return false
	item_order = item_data["order"]
	items = item_data["entries"]

	var tool_data := _load_ordered_data_file("res://data/tools.json")
	if not tool_data.get("ok", false):
		return false
	tool_order = tool_data["order"]
	tool_definitions = tool_data["entries"]

	var craftable_data := _load_ordered_data_file("res://data/craftables.json")
	if not craftable_data.get("ok", false):
		return false
	craftable_order = craftable_data["order"]
	craftables = craftable_data["entries"]

	var recipe_data := _load_ordered_data_file("res://data/recipes.json")
	if not recipe_data.get("ok", false):
		return false
	recipe_order = recipe_data["order"]
	recipes = recipe_data["entries"]

	var upgrade_data := _load_ordered_data_file("res://data/upgrades.json")
	if not upgrade_data.get("ok", false):
		return false
	upgrade_order = upgrade_data["order"]
	upgrades = upgrade_data["entries"]

	return true


func _load_json_file(path: String):
	if not FileAccess.file_exists(path):
		push_error("Missing data file: %s" % path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open data file: %s" % path)
		return null

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_error("Could not parse JSON data file: %s" % path)
		return null

	return json.data


func _load_ordered_data_file(path: String) -> Dictionary:
	var raw_data = _load_json_file(path)
	if typeof(raw_data) != TYPE_ARRAY:
		push_error("Expected an array in data file: %s" % path)
		return {"ok": false}

	var order: Array = []
	var entries := {}

	for item in raw_data:
		if typeof(item) != TYPE_DICTIONARY:
			push_error("Expected object entries in data file: %s" % path)
			return {"ok": false}

		var entry: Dictionary = item.duplicate(true)
		var item_id := String(entry.get("id", ""))
		if item_id == "":
			push_error("Missing id in data file: %s" % path)
			return {"ok": false}

		entry.erase("id")
		order.append(item_id)
		entries[item_id] = entry

	return {
		"ok": true,
		"order": order,
		"entries": entries,
	}


func _initialize_state() -> void:
	inventory.clear()
	for resource_id in gatherable_order:
		inventory[resource_id] = 0
	for item_id in item_order:
		inventory[item_id] = 0

	tools.clear()
	for tool_id in tool_order:
		tools[tool_id] = {
			"durability": 0,
		}

	crafted_items.clear()
	for craftable_id in craftable_order:
		crafted_items[craftable_id] = 0

	craftable_upgrade_levels.clear()
	for craftable_id in craftable_order:
		craftable_upgrade_levels[craftable_id] = 0

	stored_fuel_units.clear()
	for craftable_id in craftable_order:
		stored_fuel_units[craftable_id] = 0

	skill_states.clear()
	for skill_id in skill_order:
		skill_states[skill_id] = {
			"level": 1,
			"exp": 0,
			"exp_to_next": 10,
		}

	upgrade_levels.clear()
	for upgrade_id in upgrade_order:
		upgrade_levels[upgrade_id] = 0
	action_queue.clear()
	current_action.clear()
	current_action_completion_pending = false
	is_queue_paused = false


func _build_data_context() -> Dictionary:
	return {
		"skill_order": skill_order,
		"skill_definitions": skill_definitions,
		"gatherable_order": gatherable_order,
		"gatherables": gatherables,
		"item_order": item_order,
		"items": items,
		"tool_order": tool_order,
		"tool_definitions": tool_definitions,
		"craftable_order": craftable_order,
		"craftables": craftables,
		"recipe_order": recipe_order,
		"recipes": recipes,
	}


func _build_rules_context() -> Dictionary:
	var data_context := _build_data_context()
	data_context.merge({
		"exp_growth": exp_growth,
		"level_speed_multiplier": level_speed_multiplier,
		"speed_upgrade_multiplier": speed_upgrade_multiplier,
		"min_gather_time": min_gather_time,
		"bag_capacity_per_upgrade": bag_capacity_per_upgrade,
		"upgrade_levels": upgrade_levels,
		"inventory_item_order": GameData.get_inventory_item_order(data_context),
	}, true)
	return data_context


func _build_ui_controller_context() -> Dictionary:
	return {
		"data": _build_data_context(),
		"rules": _build_rules_context(),
		"simulation_state": _create_simulation_state(),
		"skill_order": skill_order,
		"gatherable_order": gatherable_order,
		"tool_order": tool_order,
		"craftable_order": craftable_order,
		"recipe_order": recipe_order,
		"upgrade_order": upgrade_order,
		"upgrades": upgrades,
		"inventory": inventory,
		"tools": tools,
		"crafted_items": crafted_items,
		"craftable_upgrade_levels": craftable_upgrade_levels,
		"stored_fuel_units": stored_fuel_units,
		"action_queue": action_queue,
		"current_action": current_action,
		"is_queue_paused": is_queue_paused,
		"skill_states": skill_states,
		"upgrade_levels": upgrade_levels,
		"bag_capacity_per_upgrade": bag_capacity_per_upgrade,
		"base_queue_size": base_queue_size,
		"queue_size_per_upgrade": queue_size_per_upgrade,
		"speed_upgrade_multiplier": speed_upgrade_multiplier,
		"resource_cards": resource_cards,
		"upgrade_cards": upgrade_cards,
		"skill_rows": skill_rows,
		"current_action_label": current_action_label,
		"queue_summary_label": queue_summary_label,
		"queue_time_left_label": queue_time_left_label,
		"queue_list": queue_list,
		"clear_queue_button": clear_queue_button,
		"pause_queue_button": pause_queue_button,
		"skill_context_label": skill_context_label,
		"main_tabs": main_tabs,
		"gatherable_skill_tabs": gatherable_skill_tabs,
		"tool_cards": tool_cards,
		"craftable_cards": craftable_cards,
		"recipe_cards": recipe_cards,
		"item_labels": item_labels,
		"processing_station_cards": processing_station_cards,
		"processing_station_expanded": processing_station_expanded,
	}


func _process(delta: float) -> void:
	if toast_panel != null and toast_panel.visible:
		toast_time_left = maxf(0.0, toast_time_left - delta)
		if toast_time_left <= 0.0:
			toast_panel.visible = false

	if current_action_completion_pending:
		current_action_completion_pending = false
		_complete_current_action()

	if not is_queue_paused and current_action.is_empty():
		_start_next_action()

	if not is_queue_paused and not current_action.is_empty():
		var duration := maxf(0.001, float(current_action["duration"]))
		var elapsed := minf(float(current_action["elapsed"]) + delta, duration)
		current_action["elapsed"] = elapsed
		if elapsed >= duration:
			current_action_completion_pending = true

	var ui_context := _build_ui_controller_context()
	GameUiController.refresh_runtime_status(ui_context)
	GameUiController.refresh_queue_button_hover_previews(ui_context)


func _build_ui() -> void:
	var page_scroll := ScrollContainer.new()
	page_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(page_scroll)

	page_margin = MarginContainer.new()
	page_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_margin.add_theme_constant_override("margin_left", 16)
	page_margin.add_theme_constant_override("margin_top", 16)
	page_margin.add_theme_constant_override("margin_right", 16)
	page_margin.add_theme_constant_override("margin_bottom", 16)
	page_scroll.add_child(page_margin)

	root_box = VBoxContainer.new()
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_theme_constant_override("separation", 10)
	page_margin.add_child(root_box)

	var title := Label.new()
	title.text = game_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	root_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = game_subtitle
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 14)
	root_box.add_child(subtitle)

	_build_skill_panel(root_box)
	_build_content(root_box)
	_build_toast()


func _build_toast() -> void:
	var refs := GameUiBuilder.build_toast_layer(self)
	toast_panel = refs["toast_panel"]
	toast_label = refs["toast_label"]


func _build_skill_panel(root: VBoxContainer) -> void:
	var skill_entries := []
	for skill_id in skill_order:
		skill_entries.append({
			"id": skill_id,
			"name": _get_skill_name(skill_id),
		})

	var refs := GameUiBuilder.build_skill_panel(root, skill_entries)
	skill_rows = refs["skill_rows"]
	skill_context_label = refs["skill_context_label"]


func _build_content(root: VBoxContainer) -> void:
	content_grid = GridContainer.new()
	content_grid.columns = 2
	content_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_grid.add_theme_constant_override("h_separation", 12)
	content_grid.add_theme_constant_override("v_separation", 12)
	root.add_child(content_grid)

	main_tabs = TabContainer.new()
	main_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_tabs.tab_changed.connect(_on_main_tab_changed)
	content_grid.add_child(main_tabs)

	var gatherables_tab := VBoxContainer.new()
	gatherables_tab.name = "Gatherables"
	gatherables_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gatherables_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_tabs.add_child(gatherables_tab)
	_build_gatherables_panel(gatherables_tab)

	var tools_tab_scroll := ScrollContainer.new()
	tools_tab_scroll.name = "Tools"
	tools_tab_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_tab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools_tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_tabs.add_child(tools_tab_scroll)

	var tools_tab := VBoxContainer.new()
	tools_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_tab.add_theme_constant_override("separation", 10)
	tools_tab_scroll.add_child(tools_tab)
	_build_tools_panel(tools_tab)

	var buildables_tab_scroll := ScrollContainer.new()
	buildables_tab_scroll.name = "Buildables"
	buildables_tab_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buildables_tab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buildables_tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_tabs.add_child(buildables_tab_scroll)

	var buildables_tab := VBoxContainer.new()
	buildables_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buildables_tab.add_theme_constant_override("separation", 10)
	buildables_tab_scroll.add_child(buildables_tab)
	_build_craftables_panel(buildables_tab)

	var processing_tab_scroll := ScrollContainer.new()
	processing_tab_scroll.name = "Processing"
	processing_tab_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	processing_tab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	processing_tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_tabs.add_child(processing_tab_scroll)

	var processing_tab := VBoxContainer.new()
	processing_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	processing_tab.add_theme_constant_override("separation", 10)
	processing_tab_scroll.add_child(processing_tab)
	_build_processing_panel(processing_tab)

	var upgrades_tab_scroll := ScrollContainer.new()
	upgrades_tab_scroll.name = "Upgrades"
	upgrades_tab_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrades_tab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	upgrades_tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_tabs.add_child(upgrades_tab_scroll)

	var upgrades_tab := VBoxContainer.new()
	upgrades_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrades_tab.add_theme_constant_override("separation", 10)
	upgrades_tab_scroll.add_child(upgrades_tab)
	_build_upgrades_panel(upgrades_tab)

	queue_column = VBoxContainer.new()
	queue_column.custom_minimum_size = Vector2(340, 0)
	queue_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_grid.add_child(queue_column)
	_build_queue_panel(queue_column)


func _build_gatherables_panel(parent: Container) -> void:
	var skill_groups := []
	for skill_id in _get_gatherable_skill_ids():
		var resources := []
		for resource_id in gatherable_order:
			if _get_resource_skill_id(resource_id) != skill_id:
				continue
			resources.append({
				"id": resource_id,
				"name": _get_resource_name(resource_id),
			})

		skill_groups.append({
			"id": skill_id,
			"name": _get_skill_name(skill_id),
			"resources": resources,
		})

	var refs := GameUiBuilder.build_gatherables_panel(
		parent,
		skill_groups,
		Callable(self, "_queue_pickable"),
		Callable(self, "_on_gatherable_skill_tab_changed")
	)
	gatherable_skill_tabs = refs["gatherable_skill_tabs"]
	resource_cards = refs["resource_cards"]


func _build_queue_panel(parent: VBoxContainer) -> void:
	var refs := GameUiBuilder.build_queue_panel(
		parent,
		Callable(self, "_clear_queue"),
		Callable(self, "_toggle_queue_pause")
	)
	current_action_label = refs["current_action_label"]
	queue_summary_label = refs["queue_summary_label"]
	queue_time_left_label = refs["queue_time_left_label"]
	queue_list = refs["queue_list"]
	clear_queue_button = refs["clear_queue_button"]
	pause_queue_button = refs["pause_queue_button"]


func _build_tools_panel(parent: VBoxContainer) -> void:
	var tool_entries := []
	for tool_id in tool_order:
		tool_entries.append({
			"id": tool_id,
			"name": _get_tool_name(tool_id),
		})

	tool_cards = GameUiBuilder.build_tools_panel(
		parent,
		tool_entries,
		Callable(self, "_craft_tool"),
		Callable(self, "_on_cost_meta_clicked")
	)


func _build_craftables_panel(parent: VBoxContainer) -> void:
	var craftable_entries := []
	for craftable_id in craftable_order:
		craftable_entries.append({
			"id": craftable_id,
			"name": _get_craftable_name(craftable_id),
		})

	craftable_cards = GameUiBuilder.build_craftables_panel(
		parent,
		craftable_entries,
		Callable(self, "_craft_item"),
		Callable(self, "_on_cost_meta_clicked")
	)


func _build_processing_panel(parent: VBoxContainer) -> void:
	var summary_item_ids := _get_processing_summary_item_ids()

	var recipes_by_station := {}
	for recipe_id in recipe_order:
		var station_id := _get_recipe_station_id(recipe_id)
		if not recipes_by_station.has(station_id):
			recipes_by_station[station_id] = []
		recipes_by_station[station_id].append(recipe_id)

	var station_entries := []
	for craftable_id in craftable_order:
		if not recipes_by_station.has(craftable_id):
			continue

		var burnable_items := []
		if _get_station_fuel_capacity(craftable_id) > 0:
			for fuel_item_id in _get_burnable_item_ids():
				burnable_items.append({
					"id": fuel_item_id,
					"name": _get_resource_name(fuel_item_id),
				})

		var recipe_entries := []
		for recipe_id in recipes_by_station[craftable_id]:
			recipe_entries.append({
				"id": recipe_id,
				"name": _get_recipe_name(recipe_id),
			})

		station_entries.append({
			"id": craftable_id,
			"name": _get_craftable_name(craftable_id),
			"burnable_items": burnable_items,
			"recipes": recipe_entries,
		})

	var refs := GameUiBuilder.build_processing_panel(
		parent,
		summary_item_ids,
		station_entries,
		Callable(self, "_queue_recipe"),
		Callable(self, "_queue_station_fuel"),
		Callable(self, "_toggle_processing_station"),
		Callable(self, "_on_cost_meta_clicked")
	)
	if refs.is_empty():
		return

	item_labels = refs["item_labels"]
	recipe_cards = refs["recipe_cards"]
	processing_station_cards = refs["processing_station_cards"]
	processing_station_expanded = refs["processing_station_expanded"]


func _build_upgrades_panel(parent: VBoxContainer) -> void:
	var upgrade_entries := []
	for upgrade_id in upgrade_order:
		upgrade_entries.append({
			"id": upgrade_id,
			"name": upgrades[upgrade_id]["name"],
			"button_text": upgrades[upgrade_id]["button_text"],
		})

	upgrade_cards = GameUiBuilder.build_upgrades_panel(
		parent,
		upgrade_entries,
		Callable(self, "_buy_upgrade"),
		Callable(self, "_on_cost_meta_clicked")
	)


func _queue_pickable(resource_id: String) -> void:
	if not GameCommands.try_queue_pickable(
		resource_id,
		_get_requested_queue_amount(),
		action_queue,
		current_action,
		skill_states,
		upgrade_levels,
		base_queue_size,
		queue_size_per_upgrade,
		_create_simulation_state(),
		_build_data_context(),
		_build_rules_context()
	):
		return

	_refresh_ui()
	if current_action.is_empty():
		_start_next_action()


func _craft_tool(tool_id: String) -> void:
	if not GameCommands.try_queue_tool(
		tool_id,
		action_queue,
		current_action,
		upgrade_levels,
		base_queue_size,
		queue_size_per_upgrade,
		_create_simulation_state(),
		_build_rules_context()
	):
		return

	_refresh_ui()
	if current_action.is_empty():
		_start_next_action()


func _craft_item(craftable_id: String) -> void:
	if not GameCommands.try_queue_craftable(
		craftable_id,
		action_queue,
		current_action,
		crafted_items,
		upgrade_levels,
		base_queue_size,
		queue_size_per_upgrade,
		_create_simulation_state(),
		_build_rules_context()
	):
		return

	_refresh_ui()
	if current_action.is_empty():
		_start_next_action()


func _queue_recipe(recipe_id: String) -> void:
	if not GameCommands.try_queue_recipe(
		recipe_id,
		_get_requested_queue_amount(),
		action_queue,
		current_action,
		upgrade_levels,
		base_queue_size,
		queue_size_per_upgrade,
		_create_simulation_state(),
		_build_rules_context()
	):
		return

	_refresh_ui()
	if current_action.is_empty():
		_start_next_action()


func _queue_station_fuel(craftable_id: String, item_id: String) -> void:
	if not GameCommands.try_queue_station_fuel(
		craftable_id,
		item_id,
		_get_requested_queue_amount(),
		action_queue,
		current_action,
		upgrade_levels,
		base_queue_size,
		queue_size_per_upgrade,
		_create_simulation_state(),
		_build_rules_context()
	):
		return

	_refresh_ui()
	if current_action.is_empty():
		_start_next_action()


func _toggle_processing_station(craftable_id: String) -> void:
	GameCommands.toggle_processing_station(processing_station_expanded, craftable_id)
	_refresh_ui()


func _queue_action_count(action: Dictionary, amount: int) -> void:
	var queued_any := GameQueue.queue_action_count(
		action_queue,
		action,
		amount,
		GameDomain.get_queue_capacity(upgrade_levels, base_queue_size, queue_size_per_upgrade),
		_action_from_current_action(),
		_create_simulation_state(),
		_build_rules_context()
	)
	if not queued_any:
		return

	_refresh_ui()

	if current_action.is_empty():
		_start_next_action()


func _buy_upgrade(upgrade_id: String) -> void:
	if not GameCommands.buy_upgrade(upgrade_id, inventory, upgrade_levels, upgrades, _build_data_context()):
		return
	_refresh_ui()


func _clear_queue() -> void:
	GameCommands.clear_queue(action_queue)
	_refresh_ui()


func _toggle_queue_pause() -> void:
	is_queue_paused = GameCommands.toggle_queue_pause(is_queue_paused)
	_refresh_ui()


func _start_next_action() -> void:
	current_action_completion_pending = false
	var runtime_result := GameRuntime.start_next_action(
		action_queue,
		_create_simulation_state(),
		_build_rules_context()
	)
	action_queue = runtime_result["queue"]
	if bool(runtime_result["started"]):
		_apply_live_state(runtime_result["state"])
		current_action = runtime_result["current_action"]
		_refresh_ui()
		return

	current_action.clear()
	_refresh_ui()


func _complete_current_action() -> void:
	if current_action.is_empty():
		return

	current_action_completion_pending = false
	_apply_live_state(
		GameRuntime.complete_current_action(
			_action_from_current_action(),
			_create_simulation_state(),
			_build_rules_context()
		)
	)
	current_action.clear()
	_refresh_ui()
	_start_next_action()


func _apply_live_state(state: Dictionary) -> void:
	inventory = state["inventory"]
	tools = state["tools"]
	crafted_items = state["crafted_items"]
	craftable_upgrade_levels = state["craftable_upgrade_levels"]
	stored_fuel_units = state["stored_fuel_units"]
	skill_states = state["skills"]


func _refresh_ui() -> void:
	GameUiController.refresh_ui(_build_ui_controller_context())


func _get_requested_queue_amount() -> int:
	return GameUiController.get_requested_queue_amount(
		Input.is_key_pressed(KEY_CTRL),
		Input.is_key_pressed(KEY_SHIFT),
		action_queue.size(),
		GameEconomy.get_queue_capacity(upgrade_levels, base_queue_size, queue_size_per_upgrade)
	)


func _on_main_tab_changed(_tab: int) -> void:
	GameUiController.refresh_skill_section(_build_ui_controller_context())


func _on_gatherable_skill_tab_changed(_tab: int) -> void:
	GameUiController.refresh_skill_section(_build_ui_controller_context())


func _get_capacity(resource_id: String) -> int:
	return GameEconomy.get_capacity(resource_id, _build_data_context(), upgrade_levels, bag_capacity_per_upgrade)


func _get_resource_xp(resource_id: String) -> int:
	return GameData.get_resource_xp(resource_id, _build_data_context())


func _get_unlock_level(resource_id: String) -> int:
	return GameData.get_unlock_level(resource_id, _build_data_context())


func _get_resource_name(resource_id: String) -> String:
	return GameData.get_resource_name(resource_id, _build_data_context())


func _get_item_description(item_id: String) -> String:
	return GameData.get_item_description(item_id, _build_data_context())


func _get_item_fuel_units(item_id: String) -> int:
	return GameData.get_item_fuel_units(item_id, _build_data_context())


func _get_resource_skill_id(resource_id: String) -> String:
	return GameData.get_resource_skill_id(resource_id, _build_data_context())


func _get_gather_output_item_id(resource_id: String) -> String:
	return GameData.get_gather_output_item_id(resource_id, _build_data_context())


func _get_inventory_item_order() -> Array:
	return GameData.get_inventory_item_order(_build_data_context())


func _get_processing_summary_item_ids() -> Array:
	return GameData.get_processing_summary_item_ids(_build_data_context())


func _get_burnable_item_ids() -> Array:
	return GameData.get_burnable_item_ids(_build_data_context())


func _get_required_tool_id(resource_id: String) -> String:
	return GameData.get_required_tool_id(resource_id, _build_data_context())


func _get_tool_durability_cost(resource_id: String) -> int:
	return GameData.get_tool_durability_cost(resource_id, _build_data_context())


func _get_skill_name(skill_id: String) -> String:
	return GameData.get_skill_name(skill_id, _build_data_context())


func _get_skill_level_speed_multiplier(level_value: int) -> float:
	return GameRules.get_skill_level_speed_multiplier(level_value, _build_rules_context())


func _is_resource_unlocked_in_state(resource_id: String, state: Dictionary) -> bool:
	return GameRules.is_resource_unlocked_in_state(resource_id, state, _build_rules_context())


func _skill_has_gatherables(skill_id: String) -> bool:
	return GameData.skill_has_gatherables(skill_id, _build_data_context())


func _get_gatherable_skill_ids() -> Array:
	return GameData.get_gatherable_skill_ids(_build_data_context())


func _get_tool_name(tool_id: String) -> String:
	return GameData.get_tool_name(tool_id, _build_data_context())


func _get_tool_max_durability(tool_id: String) -> int:
	return GameData.get_tool_max_durability(tool_id, _build_data_context())


func _get_tool_craft_cost(tool_id: String) -> Dictionary:
	return GameData.get_tool_craft_cost(tool_id, _build_data_context())


func _get_tool_craft_time(tool_id: String) -> float:
	return GameData.get_tool_craft_time(tool_id, _build_data_context())


func _get_tool_craft_xp(tool_id: String) -> int:
	return GameData.get_tool_craft_xp(tool_id, _build_data_context())


func _get_tool_use_text(tool_id: String) -> String:
	return GameData.get_tool_use_text(tool_id, _build_data_context())


func _get_craftable_name(craftable_id: String) -> String:
	return GameData.get_craftable_name(craftable_id, _build_data_context())


func _get_craftable_craft_cost(craftable_id: String) -> Dictionary:
	return GameData.get_craftable_craft_cost(craftable_id, _build_data_context())


func _get_craftable_craft_time(craftable_id: String) -> float:
	return GameData.get_craftable_craft_time(craftable_id, _build_data_context())


func _get_craftable_craft_xp(craftable_id: String) -> int:
	return GameData.get_craftable_craft_xp(craftable_id, _build_data_context())


func _get_craftable_use_text(craftable_id: String) -> String:
	return GameData.get_craftable_use_text(craftable_id, _build_data_context())


func _get_craftable_max_count(craftable_id: String) -> int:
	return GameData.get_craftable_max_count(craftable_id, _build_data_context())


func _get_craftable_upgrade_cost_multiplier(craftable_id: String) -> float:
	return GameData.get_craftable_upgrade_cost_multiplier(craftable_id, _build_data_context())


func _get_craftable_station_speed_multiplier(craftable_id: String) -> float:
	return GameData.get_craftable_station_speed_multiplier(craftable_id, _build_data_context())


func _get_station_fuel_capacity(craftable_id: String) -> int:
	return GameData.get_station_fuel_capacity(craftable_id, _build_data_context())


func _get_recipe_name(recipe_id: String) -> String:
	return GameData.get_recipe_name(recipe_id, _build_data_context())


func _get_recipe_station_id(recipe_id: String) -> String:
	return GameData.get_recipe_station_id(recipe_id, _build_data_context())


func _get_recipe_craft_xp(recipe_id: String) -> int:
	return GameData.get_recipe_craft_xp(recipe_id, _build_data_context())


func _get_recipe_skill_id(recipe_id: String) -> String:
	return GameData.get_recipe_skill_id(recipe_id, _build_data_context())


func _get_recipe_fuel_cost_units(recipe_id: String) -> int:
	return GameData.get_recipe_fuel_cost_units(recipe_id, _build_data_context())


func _get_recipe_source_fuel_units(recipe_id: String) -> int:
	return GameRules.get_recipe_source_fuel_units(recipe_id, _build_rules_context())


func _build_pipeline_end_state() -> Dictionary:
	return GameQueries.build_pipeline_end_state(
		current_action,
		action_queue,
		_create_simulation_state(),
		_build_rules_context()
	)


func _create_simulation_state() -> Dictionary:
	return GameState.build_simulation_state(
		inventory,
		tools,
		crafted_items,
		craftable_upgrade_levels,
		stored_fuel_units,
		skill_states
	)


func _simulate_action_in_state(state: Dictionary, action: Dictionary) -> Dictionary:
	return GameRules.simulate_action_in_state(state, action, _build_rules_context())


func _get_action_block_reason_in_state(action: Dictionary, state: Dictionary) -> String:
	return GameRules.get_action_block_reason_in_state(action, state, _build_rules_context())


func _apply_action_start_to_state(state: Dictionary, action: Dictionary) -> void:
	GameRules.apply_action_start_to_state(state, action, _build_rules_context())


func _apply_action_completion_to_state(state: Dictionary, action: Dictionary) -> void:
	GameRules.apply_action_completion_to_state(state, action, _build_rules_context())


func _get_action_queue_label(action: Dictionary) -> String:
	return GameActions.get_action_queue_label(action, _build_data_context())


func _get_action_progress_label(action: Dictionary) -> String:
	return GameActions.get_action_progress_label(action, _build_data_context())


func _make_gather_action(resource_id: String) -> Dictionary:
	return GameActions.make_gather_action(resource_id)


func _make_craft_tool_action(tool_id: String) -> Dictionary:
	return GameActions.make_craft_tool_action(tool_id)


func _make_craft_item_action(craftable_id: String) -> Dictionary:
	return GameActions.make_craft_item_action(craftable_id)


func _make_upgrade_craftable_action(craftable_id: String) -> Dictionary:
	return GameActions.make_upgrade_craftable_action(craftable_id)


func _make_process_recipe_action(recipe_id: String) -> Dictionary:
	return GameActions.make_process_recipe_action(recipe_id)


func _make_refuel_station_action(craftable_id: String, item_id: String) -> Dictionary:
	return GameActions.make_refuel_station_action(craftable_id, item_id)


func _action_from_current_action() -> Dictionary:
	return GameActions.copy_action(current_action)


func _get_action_type(action: Dictionary) -> String:
	return GameActions.get_action_type(action)


func _get_action_id(action: Dictionary) -> String:
	return GameActions.get_action_id(action)


func _get_action_station_id(action: Dictionary) -> String:
	return GameActions.get_action_station_id(action)


func _get_action_fuel_item_id(action: Dictionary) -> String:
	return GameActions.get_action_fuel_item_id(action)


func _get_upgrade_detail(upgrade_id: String) -> String:
	return GamePresentation.get_upgrade_detail(
		upgrade_id,
		upgrade_levels,
		bag_capacity_per_upgrade,
		speed_upgrade_multiplier,
		queue_size_per_upgrade,
		base_queue_size
	)


func _on_cost_meta_clicked(meta: Variant) -> void:
	var parsed_meta := GameInteractions.parse_resource_meta(meta)
	if parsed_meta.is_empty():
		return

	var resource_id := String(parsed_meta["resource_id"])
	var required_amount := int(parsed_meta["required_amount"])

	if Input.is_key_pressed(KEY_CTRL):
		_queue_linked_resource_shortfall(resource_id, required_amount)
		return

	_focus_resource_gather_tab(resource_id)


func _focus_resource_gather_tab(resource_id: String) -> void:
	var focus_target := GameInteractions.get_focus_target_for_resource(resource_id, _build_data_context())
	if focus_target.is_empty():
		return

	if main_tabs != null:
		for index in range(main_tabs.get_tab_count()):
			if main_tabs.get_tab_title(index) == String(focus_target["main_tab_title"]):
				main_tabs.current_tab = index
				break

	if gatherable_skill_tabs != null:
		var skill_id := String(focus_target["gather_skill_id"])
		for index in range(gatherable_skill_tabs.get_tab_count()):
			if String(gatherable_skill_tabs.get_child(index).name) == skill_id:
				gatherable_skill_tabs.current_tab = index
				break

	GameUiController.refresh_skill_section(_build_ui_controller_context())


func _queue_linked_resource_shortfall(item_id: String, required_amount: int) -> void:
	var plan := GameInteractions.build_linked_resource_queue_plan(
		item_id,
		required_amount,
		_build_pipeline_end_state(),
		GameQueries.get_free_queue_slots(
			action_queue.size(),
			GameEconomy.get_queue_capacity(upgrade_levels, base_queue_size, queue_size_per_upgrade)
		),
		_build_data_context(),
		_build_rules_context()
	)
	if plan.has("toast_message"):
		_show_toast(String(plan["toast_message"]))
		return

	var queue_amount := int(plan.get("queue_amount", 0))
	if queue_amount <= 0:
		return

	_queue_action_count(plan["action"], queue_amount)


func _show_toast(message: String, duration: float = 2.6) -> void:
	if toast_panel == null or toast_label == null:
		return

	toast_label.text = message
	toast_time_left = maxf(0.8, duration)
	toast_panel.visible = true


func _format_cost(cost: Dictionary) -> String:
	return GamePresentation.format_cost(cost, _build_data_context())


func _format_recipe_detail_rich_text(duration: float, xp: int, cost: Dictionary, use_text: String) -> String:
	return GamePresentation.format_recipe_detail_rich_text(duration, xp, cost, use_text, _build_data_context(), inventory)


func _format_cost_rich_text(cost: Dictionary) -> String:
	return GamePresentation.format_cost_rich_text(cost, _build_data_context(), inventory)


func _format_cost_markup(cost: Dictionary) -> String:
	return GamePresentation.format_cost_markup(cost, _build_data_context(), inventory)


func _format_resource_cost_part(resource_id: String, amount: int) -> String:
	return GamePresentation.format_resource_cost_part(resource_id, amount, _build_data_context(), inventory)


func _format_seconds(seconds: float) -> String:
	return GamePresentation.format_seconds(seconds)


func _update_responsive_layout() -> void:
	if page_margin == null or main_tabs == null or content_grid == null or queue_column == null:
		return

	page_margin.custom_minimum_size = Vector2(maxf(0.0, size.x), 0.0)
	var is_stacked := size.x < layout_stack_breakpoint
	content_grid.columns = 1 if is_stacked else 2

	if is_stacked:
		main_tabs.custom_minimum_size = Vector2(0, 0)
		queue_column.custom_minimum_size = Vector2(0, 0)
		queue_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	else:
		var available_width := maxf(0.0, size.x - 44.0)
		var queue_width := maxf(320.0, floor(available_width * 0.4))
		var tabs_width := maxf(0.0, available_width - queue_width)
		main_tabs.custom_minimum_size = Vector2(tabs_width, 0)
		queue_column.custom_minimum_size = Vector2(queue_width, 0)
		queue_column.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if is_stacked:
		queue_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		queue_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
