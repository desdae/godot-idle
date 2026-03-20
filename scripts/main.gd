extends Control

const GameRules = preload("res://scripts/game_rules.gd")

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


func _build_rules_context() -> Dictionary:
	return {
		"exp_growth": exp_growth,
		"level_speed_multiplier": level_speed_multiplier,
		"speed_upgrade_multiplier": speed_upgrade_multiplier,
		"min_gather_time": min_gather_time,
		"bag_capacity_per_upgrade": bag_capacity_per_upgrade,
		"upgrade_levels": upgrade_levels,
		"inventory_item_order": _get_inventory_item_order(),
		"skill_definitions": skill_definitions,
		"gatherables": gatherables,
		"items": items,
		"tool_definitions": tool_definitions,
		"craftables": craftables,
		"recipes": recipes,
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

	_refresh_runtime_status()
	_refresh_queue_button_hover_previews()


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
	var toast_anchor := CenterContainer.new()
	toast_anchor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast_anchor.offset_top = -84
	toast_anchor.offset_bottom = -20
	toast_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_anchor)

	toast_panel = PanelContainer.new()
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.custom_minimum_size = Vector2(320, 0)
	toast_anchor.add_child(toast_panel)

	var toast_margin := MarginContainer.new()
	toast_margin.add_theme_constant_override("margin_left", 12)
	toast_margin.add_theme_constant_override("margin_top", 8)
	toast_margin.add_theme_constant_override("margin_right", 12)
	toast_margin.add_theme_constant_override("margin_bottom", 8)
	toast_panel.add_child(toast_margin)

	toast_label = Label.new()
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_margin.add_child(toast_label)


func _build_skill_panel(root: VBoxContainer) -> void:
	var skill_panel := PanelContainer.new()
	skill_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(skill_panel)

	var skill_margin := MarginContainer.new()
	skill_margin.add_theme_constant_override("margin_left", 10)
	skill_margin.add_theme_constant_override("margin_top", 8)
	skill_margin.add_theme_constant_override("margin_right", 10)
	skill_margin.add_theme_constant_override("margin_bottom", 8)
	skill_panel.add_child(skill_margin)

	var skill_box := VBoxContainer.new()
	skill_box.add_theme_constant_override("separation", 4)
	skill_margin.add_child(skill_box)

	var skill_scroll := ScrollContainer.new()
	skill_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	skill_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skill_scroll.custom_minimum_size = Vector2(0, 58)
	skill_box.add_child(skill_scroll)

	var skill_strip := HBoxContainer.new()
	skill_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_strip.add_theme_constant_override("separation", 8)
	skill_scroll.add_child(skill_strip)

	for skill_id in skill_order:
		var card_panel := PanelContainer.new()
		card_panel.custom_minimum_size = Vector2(170, 0)
		skill_strip.add_child(card_panel)

		var card_margin := MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 8)
		card_margin.add_theme_constant_override("margin_top", 6)
		card_margin.add_theme_constant_override("margin_right", 8)
		card_margin.add_theme_constant_override("margin_bottom", 6)
		card_panel.add_child(card_margin)

		var card_box := VBoxContainer.new()
		card_box.add_theme_constant_override("separation", 3)
		card_margin.add_child(card_box)

		var skill_label := Label.new()
		skill_label.add_theme_font_size_override("font_size", 16)
		card_box.add_child(skill_label)

		var exp_label := Label.new()
		exp_label.add_theme_font_size_override("font_size", 12)
		card_box.add_child(exp_label)

		var exp_bar := ProgressBar.new()
		exp_bar.min_value = 0
		exp_bar.max_value = 100
		exp_bar.show_percentage = false
		exp_bar.custom_minimum_size = Vector2(0, 6)
		card_box.add_child(exp_bar)

		skill_rows[skill_id] = {
			"panel": card_panel,
			"skill_label": skill_label,
			"exp_label": exp_label,
			"exp_bar": exp_bar,
		}

	skill_context_label = Label.new()
	skill_context_label.add_theme_font_size_override("font_size", 13)
	skill_box.add_child(skill_context_label)


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
	var gatherables_panel := PanelContainer.new()
	gatherables_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gatherables_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(gatherables_panel)

	var gatherables_margin := MarginContainer.new()
	gatherables_margin.add_theme_constant_override("margin_left", 10)
	gatherables_margin.add_theme_constant_override("margin_top", 10)
	gatherables_margin.add_theme_constant_override("margin_right", 10)
	gatherables_margin.add_theme_constant_override("margin_bottom", 10)
	gatherables_panel.add_child(gatherables_margin)

	var gatherables_root := VBoxContainer.new()
	gatherables_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gatherables_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gatherables_root.add_theme_constant_override("separation", 8)
	gatherables_margin.add_child(gatherables_root)

	gatherable_skill_tabs = TabContainer.new()
	gatherable_skill_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gatherable_skill_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gatherable_skill_tabs.tab_changed.connect(_on_gatherable_skill_tab_changed)
	gatherables_root.add_child(gatherable_skill_tabs)

	for skill_id in _get_gatherable_skill_ids():
		var gatherables_scroll := ScrollContainer.new()
		gatherables_scroll.name = skill_id
		gatherables_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gatherables_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		gatherable_skill_tabs.add_child(gatherables_scroll)
		gatherable_skill_tabs.set_tab_title(gatherable_skill_tabs.get_tab_count() - 1, _get_skill_name(skill_id))

		var gatherables_box := VBoxContainer.new()
		gatherables_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gatherables_box.add_theme_constant_override("separation", 6)
		gatherables_scroll.add_child(gatherables_box)

		for resource_id in gatherable_order:
			if _get_resource_skill_id(resource_id) != skill_id:
				continue

			var row_panel := PanelContainer.new()
			row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_panel.custom_minimum_size = Vector2(0, 46)
			gatherables_box.add_child(row_panel)

			var row_margin := MarginContainer.new()
			row_margin.add_theme_constant_override("margin_left", 8)
			row_margin.add_theme_constant_override("margin_top", 6)
			row_margin.add_theme_constant_override("margin_right", 8)
			row_margin.add_theme_constant_override("margin_bottom", 6)
			row_panel.add_child(row_margin)

			var row_box := VBoxContainer.new()
			row_box.add_theme_constant_override("separation", 4)
			row_margin.add_child(row_box)

			var top_row := HBoxContainer.new()
			top_row.add_theme_constant_override("separation", 8)
			row_box.add_child(top_row)

			var name_label := Label.new()
			name_label.text = _get_resource_name(resource_id)
			name_label.custom_minimum_size = Vector2(100, 0)
			name_label.add_theme_font_size_override("font_size", 15)
			top_row.add_child(name_label)

			var stats_label := Label.new()
			stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top_row.add_child(stats_label)

			var queue_button := Button.new()
			queue_button.custom_minimum_size = Vector2(122, 0)
			queue_button.pressed.connect(_queue_pickable.bind(resource_id))
			top_row.add_child(queue_button)

			var bottom_row := HBoxContainer.new()
			bottom_row.add_theme_constant_override("separation", 8)
			row_box.add_child(bottom_row)

			var gather_bar := ProgressBar.new()
			gather_bar.min_value = 0
			gather_bar.max_value = 100
			gather_bar.show_percentage = false
			gather_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gather_bar.custom_minimum_size = Vector2(0, 8)
			bottom_row.add_child(gather_bar)

			resource_cards[resource_id] = {
				"stats_label": stats_label,
				"gather_bar": gather_bar,
				"queue_button": queue_button,
			}


func _build_queue_panel(parent: VBoxContainer) -> void:
	var queue_panel := PanelContainer.new()
	queue_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(queue_panel)

	var queue_margin := MarginContainer.new()
	queue_margin.add_theme_constant_override("margin_left", 10)
	queue_margin.add_theme_constant_override("margin_top", 8)
	queue_margin.add_theme_constant_override("margin_right", 10)
	queue_margin.add_theme_constant_override("margin_bottom", 8)
	queue_panel.add_child(queue_margin)

	var queue_box := VBoxContainer.new()
	queue_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_box.add_theme_constant_override("separation", 6)
	queue_margin.add_child(queue_box)

	var queue_title := Label.new()
	queue_title.text = "Action Queue"
	queue_title.add_theme_font_size_override("font_size", 18)
	queue_box.add_child(queue_title)

	current_action_label = Label.new()
	current_action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	queue_box.add_child(current_action_label)

	queue_summary_label = Label.new()
	queue_box.add_child(queue_summary_label)

	queue_time_left_label = Label.new()
	queue_box.add_child(queue_time_left_label)

	queue_list = ItemList.new()
	queue_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_list.custom_minimum_size = Vector2(0, 140)
	queue_box.add_child(queue_list)

	clear_queue_button = Button.new()
	clear_queue_button.text = "Clear queued actions"
	clear_queue_button.pressed.connect(_clear_queue)
	queue_box.add_child(clear_queue_button)

	pause_queue_button = Button.new()
	pause_queue_button.text = "Pause queue"
	pause_queue_button.pressed.connect(_toggle_queue_pause)
	queue_box.add_child(pause_queue_button)


func _build_tools_panel(parent: VBoxContainer) -> void:
	var tools_panel := PanelContainer.new()
	tools_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(tools_panel)

	var tools_margin := MarginContainer.new()
	tools_margin.add_theme_constant_override("margin_left", 10)
	tools_margin.add_theme_constant_override("margin_top", 8)
	tools_margin.add_theme_constant_override("margin_right", 10)
	tools_margin.add_theme_constant_override("margin_bottom", 8)
	tools_panel.add_child(tools_margin)

	var tools_box := VBoxContainer.new()
	tools_box.add_theme_constant_override("separation", 4)
	tools_margin.add_child(tools_box)

	var tools_title := Label.new()
	tools_title.text = "Tools"
	tools_title.add_theme_font_size_override("font_size", 18)
	tools_box.add_child(tools_title)

	for tool_id in tool_order:
		var tool_row := VBoxContainer.new()
		tool_row.add_theme_constant_override("separation", 2)
		tools_box.add_child(tool_row)

		var name_label := Label.new()
		name_label.text = _get_tool_name(tool_id)
		name_label.add_theme_font_size_override("font_size", 15)
		tool_row.add_child(name_label)

		var status_label := Label.new()
		status_label.add_theme_font_size_override("font_size", 14)
		tool_row.add_child(status_label)

		var detail_label := _create_resource_navigation_rich_label(13)
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tool_row.add_child(detail_label)

		var button := Button.new()
		button.pressed.connect(_craft_tool.bind(tool_id))
		tool_row.add_child(button)

		tool_cards[tool_id] = {
			"status_label": status_label,
			"detail_label": detail_label,
			"button": button,
		}


func _build_craftables_panel(parent: VBoxContainer) -> void:
	if craftable_order.is_empty():
		return

	var craftables_panel := PanelContainer.new()
	craftables_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(craftables_panel)

	var craftables_margin := MarginContainer.new()
	craftables_margin.add_theme_constant_override("margin_left", 10)
	craftables_margin.add_theme_constant_override("margin_top", 8)
	craftables_margin.add_theme_constant_override("margin_right", 10)
	craftables_margin.add_theme_constant_override("margin_bottom", 8)
	craftables_panel.add_child(craftables_margin)

	var craftables_box := VBoxContainer.new()
	craftables_box.add_theme_constant_override("separation", 4)
	craftables_margin.add_child(craftables_box)

	var craftables_title := Label.new()
	craftables_title.text = "Buildables"
	craftables_title.add_theme_font_size_override("font_size", 18)
	craftables_box.add_child(craftables_title)

	for craftable_id in craftable_order:
		var craftable_row := VBoxContainer.new()
		craftable_row.add_theme_constant_override("separation", 2)
		craftables_box.add_child(craftable_row)

		var name_label := Label.new()
		name_label.text = _get_craftable_name(craftable_id)
		name_label.add_theme_font_size_override("font_size", 15)
		craftable_row.add_child(name_label)

		var status_label := Label.new()
		status_label.add_theme_font_size_override("font_size", 14)
		craftable_row.add_child(status_label)

		var detail_label := _create_resource_navigation_rich_label(13)
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		craftable_row.add_child(detail_label)

		var button := Button.new()
		button.pressed.connect(_craft_item.bind(craftable_id))
		craftable_row.add_child(button)

		craftable_cards[craftable_id] = {
			"status_label": status_label,
			"detail_label": detail_label,
			"button": button,
		}


func _build_processing_panel(parent: VBoxContainer) -> void:
	if recipe_order.is_empty():
		return

	var processing_panel := PanelContainer.new()
	processing_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(processing_panel)

	var processing_margin := MarginContainer.new()
	processing_margin.add_theme_constant_override("margin_left", 10)
	processing_margin.add_theme_constant_override("margin_top", 8)
	processing_margin.add_theme_constant_override("margin_right", 10)
	processing_margin.add_theme_constant_override("margin_bottom", 8)
	processing_panel.add_child(processing_margin)

	var processing_box := VBoxContainer.new()
	processing_box.add_theme_constant_override("separation", 6)
	processing_margin.add_child(processing_box)

	var processing_title := Label.new()
	processing_title.text = "Stations"
	processing_title.add_theme_font_size_override("font_size", 18)
	processing_box.add_child(processing_title)

	var summary_item_ids := _get_processing_summary_item_ids()
	if not summary_item_ids.is_empty():
		var items_panel := VBoxContainer.new()
		items_panel.add_theme_constant_override("separation", 3)
		processing_box.add_child(items_panel)

		var items_title := Label.new()
		items_title.text = "Items"
		items_title.add_theme_font_size_override("font_size", 15)
		items_panel.add_child(items_title)

		for item_id in summary_item_ids:
			var item_label := Label.new()
			items_panel.add_child(item_label)
			item_labels[item_id] = item_label

	var recipes_by_station := {}
	for recipe_id in recipe_order:
		var station_id := _get_recipe_station_id(recipe_id)
		if not recipes_by_station.has(station_id):
			recipes_by_station[station_id] = []
		recipes_by_station[station_id].append(recipe_id)

	for craftable_id in craftable_order:
		if not recipes_by_station.has(craftable_id):
			continue

		processing_station_expanded[craftable_id] = true

		var station_panel := PanelContainer.new()
		station_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		processing_box.add_child(station_panel)

		var station_margin := MarginContainer.new()
		station_margin.add_theme_constant_override("margin_left", 8)
		station_margin.add_theme_constant_override("margin_top", 8)
		station_margin.add_theme_constant_override("margin_right", 8)
		station_margin.add_theme_constant_override("margin_bottom", 8)
		station_panel.add_child(station_margin)

		var station_box := VBoxContainer.new()
		station_box.add_theme_constant_override("separation", 5)
		station_margin.add_child(station_box)

		var station_header := HBoxContainer.new()
		station_header.add_theme_constant_override("separation", 8)
		station_box.add_child(station_header)

		var station_title := Label.new()
		station_title.text = _get_craftable_name(craftable_id)
		station_title.add_theme_font_size_override("font_size", 16)
		station_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		station_header.add_child(station_title)

		var toggle_button := Button.new()
		toggle_button.custom_minimum_size = Vector2(90, 0)
		toggle_button.pressed.connect(_toggle_processing_station.bind(craftable_id))
		station_header.add_child(toggle_button)

		var station_status := Label.new()
		station_box.add_child(station_status)

		var fuel_buttons := {}
		var fuel_state_label: Label = null
		if _get_station_fuel_capacity(craftable_id) > 0:
			var fuel_buttons_row := HBoxContainer.new()
			fuel_buttons_row.add_theme_constant_override("separation", 6)
			station_box.add_child(fuel_buttons_row)

			var burn_label := Label.new()
			burn_label.text = "Burn"
			fuel_buttons_row.add_child(burn_label)

			fuel_state_label = Label.new()
			fuel_state_label.visible = false
			fuel_buttons_row.add_child(fuel_state_label)

			for fuel_item_id in _get_burnable_item_ids():
				var fuel_button := Button.new()
				fuel_button.custom_minimum_size = Vector2(72, 0)
				fuel_button.pressed.connect(_queue_station_fuel.bind(craftable_id, fuel_item_id))
				fuel_buttons_row.add_child(fuel_button)
				fuel_buttons[fuel_item_id] = fuel_button

		var recipes_box := VBoxContainer.new()
		recipes_box.add_theme_constant_override("separation", 4)
		station_box.add_child(recipes_box)

		for recipe_id in recipes_by_station[craftable_id]:
			var row_panel := PanelContainer.new()
			row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_panel.custom_minimum_size = Vector2(0, 44)
			recipes_box.add_child(row_panel)

			var row_margin := MarginContainer.new()
			row_margin.add_theme_constant_override("margin_left", 8)
			row_margin.add_theme_constant_override("margin_top", 6)
			row_margin.add_theme_constant_override("margin_right", 8)
			row_margin.add_theme_constant_override("margin_bottom", 6)
			row_panel.add_child(row_margin)

			var row_box := HBoxContainer.new()
			row_box.add_theme_constant_override("separation", 8)
			row_margin.add_child(row_box)

			var name_label := Label.new()
			name_label.text = _get_recipe_name(recipe_id)
			name_label.custom_minimum_size = Vector2(150, 0)
			name_label.add_theme_font_size_override("font_size", 15)
			row_box.add_child(name_label)

			var stats_label := _create_resource_navigation_rich_label(13)
			stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stats_label.fit_content = false
			stats_label.bbcode_enabled = true
			row_box.add_child(stats_label)

			var button := Button.new()
			button.custom_minimum_size = Vector2(122, 0)
			button.pressed.connect(_queue_recipe.bind(recipe_id))
			row_box.add_child(button)

			recipe_cards[recipe_id] = {
				"stats_label": stats_label,
				"button": button,
			}

		processing_station_cards[craftable_id] = {
			"status_label": station_status,
			"toggle_button": toggle_button,
			"fuel_buttons": fuel_buttons,
			"fuel_state_label": fuel_state_label,
			"recipes_box": recipes_box,
		}


func _build_upgrades_panel(parent: VBoxContainer) -> void:
	var upgrades_panel := PanelContainer.new()
	upgrades_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(upgrades_panel)

	var upgrades_margin := MarginContainer.new()
	upgrades_margin.add_theme_constant_override("margin_left", 10)
	upgrades_margin.add_theme_constant_override("margin_top", 8)
	upgrades_margin.add_theme_constant_override("margin_right", 10)
	upgrades_margin.add_theme_constant_override("margin_bottom", 8)
	upgrades_panel.add_child(upgrades_margin)

	var upgrades_box := VBoxContainer.new()
	upgrades_box.add_theme_constant_override("separation", 6)
	upgrades_margin.add_child(upgrades_box)

	var upgrades_title := Label.new()
	upgrades_title.text = "Upgrades"
	upgrades_title.add_theme_font_size_override("font_size", 18)
	upgrades_box.add_child(upgrades_title)

	for upgrade_id in upgrade_order:
		var row_box := HBoxContainer.new()
		row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_box.add_theme_constant_override("separation", 10)
		upgrades_box.add_child(row_box)

		var info_box := VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.add_theme_constant_override("separation", 2)
		row_box.add_child(info_box)

		var name_label := Label.new()
		name_label.text = upgrades[upgrade_id]["name"]
		name_label.add_theme_font_size_override("font_size", 15)
		info_box.add_child(name_label)

		var level_label := Label.new()
		level_label.add_theme_font_size_override("font_size", 13)
		info_box.add_child(level_label)

		var detail_label := Label.new()
		detail_label.add_theme_font_size_override("font_size", 13)
		info_box.add_child(detail_label)

		var cost_label := _create_resource_navigation_rich_label(13)
		info_box.add_child(cost_label)

		var button := Button.new()
		button.custom_minimum_size = Vector2(118, 0)
		button.text = upgrades[upgrade_id]["button_text"]
		button.pressed.connect(_buy_upgrade.bind(upgrade_id))
		row_box.add_child(button)

		upgrade_cards[upgrade_id] = {
			"level_label": level_label,
			"detail_label": detail_label,
			"cost_label": cost_label,
			"button": button,
		}


func _queue_pickable(resource_id: String) -> void:
	if not _can_queue_pickable(resource_id):
		return

	_queue_action_count(_make_gather_action(resource_id), _get_requested_queue_amount())


func _craft_tool(tool_id: String) -> void:
	if not _can_queue_tool_action(tool_id):
		return

	_queue_action(_make_craft_tool_action(tool_id))


func _craft_item(craftable_id: String) -> void:
	if _get_crafted_item_count(craftable_id) > 0:
		_upgrade_craftable(craftable_id)
		return

	if not _can_queue_craftable_action(craftable_id):
		return

	_queue_action(_make_craft_item_action(craftable_id))


func _upgrade_craftable(craftable_id: String) -> void:
	if not _can_queue_craftable_upgrade_action(craftable_id):
		return

	_queue_action(_make_upgrade_craftable_action(craftable_id))


func _queue_recipe(recipe_id: String) -> void:
	if not _can_queue_recipe_action(recipe_id):
		return

	_queue_action_count(_make_process_recipe_action(recipe_id), _get_requested_queue_amount())


func _queue_station_fuel(craftable_id: String, item_id: String) -> void:
	if not _can_queue_station_fuel_action(craftable_id, item_id):
		return

	_queue_action_count(_make_refuel_station_action(craftable_id, item_id), _get_requested_queue_amount())


func _toggle_processing_station(craftable_id: String) -> void:
	processing_station_expanded[craftable_id] = not bool(processing_station_expanded.get(craftable_id, true))
	_refresh_recipe_panel()


func _queue_action(action: Dictionary) -> void:
	action_queue.append(action.duplicate(true))
	_refresh_ui()

	if current_action.is_empty():
		_start_next_action()


func _queue_action_count(action: Dictionary, amount: int) -> void:
	if amount <= 0:
		return

	var queue_count := mini(amount, _get_free_queue_slots())
	if queue_count <= 0:
		return

	var pipeline_state := _build_pipeline_end_state()
	var queued_any := false

	for _index in range(queue_count):
		var simulation_result := _simulate_action_in_state(pipeline_state, action)
		if not simulation_result["ran"]:
			break

		action_queue.append(action.duplicate(true))
		queued_any = true

	if not queued_any:
		return

	_refresh_ui()

	if current_action.is_empty():
		_start_next_action()


func _buy_upgrade(upgrade_id: String) -> void:
	var cost := _get_upgrade_cost(upgrade_id)
	if not _can_afford(cost):
		return

	_spend_resources(cost)
	upgrade_levels[upgrade_id] += 1
	_refresh_ui()


func _clear_queue() -> void:
	action_queue.clear()
	_refresh_ui()


func _toggle_queue_pause() -> void:
	is_queue_paused = not is_queue_paused
	_refresh_ui()


func _start_next_action() -> void:
	current_action_completion_pending = false
	while not action_queue.is_empty():
		var next_action: Dictionary = action_queue.pop_front()
		var live_state := _create_simulation_state()
		if _get_action_block_reason_in_state(next_action, live_state) != "":
			continue

		_apply_action_start_to_state(live_state, next_action)
		inventory = live_state["inventory"]
		tools = live_state["tools"]
		crafted_items = live_state["crafted_items"]
		craftable_upgrade_levels = live_state["craftable_upgrade_levels"]
		stored_fuel_units = live_state["stored_fuel_units"]
		current_action = {
			"type": _get_action_type(next_action),
			"id": _get_action_id(next_action),
			"station_id": String(next_action.get("station_id", "")),
			"fuel_item_id": String(next_action.get("fuel_item_id", "")),
			"elapsed": 0.0,
			"duration": _get_action_duration(next_action),
		}
		_refresh_ui()
		return

	current_action.clear()
	_refresh_ui()


func _complete_current_action() -> void:
	if current_action.is_empty():
		return

	current_action_completion_pending = false
	var action := _action_from_current_action()
	match _get_action_type(action):
		"gather":
			var resource_id := _get_action_id(action)
			var output_item_id := _get_gather_output_item_id(resource_id)
			if inventory[output_item_id] < _get_capacity(resource_id):
				inventory[output_item_id] += 1
				_gain_skill_exp(_get_resource_skill_id(resource_id), _get_resource_xp(resource_id))
		"craft_tool":
			var tool_id := _get_action_id(action)
			tools[tool_id]["durability"] = _get_tool_max_durability(tool_id)
			_gain_skill_exp("crafting", _get_tool_craft_xp(tool_id))
		"craft_item":
			var craftable_id := _get_action_id(action)
			crafted_items[craftable_id] += 1
			_gain_skill_exp("crafting", _get_craftable_craft_xp(craftable_id))
		"upgrade_craftable":
			var upgrade_craftable_id := _get_action_id(action)
			craftable_upgrade_levels[upgrade_craftable_id] += 1
			_gain_skill_exp("crafting", _get_craftable_craft_xp(upgrade_craftable_id))
		"process_recipe":
			var recipe_id := _get_action_id(action)
			var recipe_outputs := _get_recipe_outputs(recipe_id)
			for output_id in recipe_outputs.keys():
				inventory[output_id] += int(recipe_outputs[output_id])
			_gain_skill_exp(_get_recipe_skill_id(recipe_id), _get_recipe_craft_xp(recipe_id))

	current_action.clear()
	_refresh_ui()
	_start_next_action()


func _gain_skill_exp(skill_id: String, amount: int) -> void:
	var current_state: Dictionary = skill_states[skill_id]
	var result := _simulate_exp_gain(
		int(current_state["level"]),
		int(current_state["exp"]),
		int(current_state["exp_to_next"]),
		amount
	)
	skill_states[skill_id] = result


func _refresh_ui() -> void:
	for skill_id in skill_order:
		_refresh_skill_row(skill_id)
	_refresh_skill_context_label()

	queue_list.clear()
	if not current_action.is_empty():
		queue_list.add_item("Now: %s" % _get_action_queue_label(current_action))

	for index in range(action_queue.size()):
		var queued_action: Dictionary = action_queue[index]
		queue_list.add_item("%d. %s" % [index + 1, _get_action_queue_label(queued_action)])

	clear_queue_button.disabled = action_queue.is_empty()
	pause_queue_button.text = "Resume queue" if is_queue_paused else "Pause queue"
	pause_queue_button.disabled = current_action.is_empty() and action_queue.is_empty()
	_refresh_tool_panel()
	_refresh_craftable_panel()
	_refresh_recipe_panel()
	_refresh_item_summary()

	for resource_id in gatherable_order:
		_refresh_resource_card(resource_id)

	for upgrade_id in upgrade_order:
		_refresh_upgrade_card(upgrade_id)

	_refresh_runtime_status()


func _refresh_resource_card(resource_id: String) -> void:
	var card: Dictionary = resource_cards[resource_id]
	var stats_label: Label = card["stats_label"]
	var queue_button: Button = card["queue_button"]

	var unlock_level := _get_unlock_level(resource_id)
	var current_capacity := _get_capacity(resource_id)
	var output_item_id := _get_gather_output_item_id(resource_id)
	var is_current_action := _is_current_gather_action(resource_id)
	var block_reason := _get_gather_queue_block_reason(resource_id)
	var display_duration := _get_gather_action_duration(resource_id)

	if not _is_resource_unlocked(resource_id):
		stats_label.text = "Lv %d | %.2fs | %d XP | %d/%d" % [
			unlock_level,
			display_duration,
			_get_resource_xp(resource_id),
			int(inventory.get(output_item_id, 0)),
			current_capacity,
		]
		queue_button.disabled = true
		queue_button.text = "Locked"
		queue_button.tooltip_text = ""
		return

	if is_current_action:
		display_duration = maxf(0.001, float(current_action["duration"]))

	if block_reason != "" and not is_current_action:
		queue_button.disabled = true
		queue_button.tooltip_text = ""
		if block_reason.begins_with("Need "):
			queue_button.text = block_reason
		elif block_reason == "Full at end of queue":
			queue_button.text = "Full"
		elif block_reason == "Queue full":
			queue_button.text = "Queue Full"
		else:
			queue_button.text = "Blocked"
	else:
		queue_button.disabled = false
		queue_button.text = "Queue +1" if is_current_action else "Queue"
		queue_button.tooltip_text = _get_queue_button_tooltip()

	stats_label.text = "Lv %d | %.2fs | %d XP | %d/%d" % [
		unlock_level,
		display_duration,
		_get_resource_xp(resource_id),
		int(inventory.get(output_item_id, 0)),
		current_capacity,
	]


func _refresh_tool_panel() -> void:
	for tool_id in tool_order:
		_refresh_tool_card(tool_id)


func _refresh_craftable_panel() -> void:
	for craftable_id in craftable_order:
		_refresh_craftable_card(craftable_id)


func _refresh_recipe_panel() -> void:
	for craftable_id in craftable_order:
		if not processing_station_cards.has(craftable_id):
			continue

		var station_card: Dictionary = processing_station_cards[craftable_id]
		var station_status: Label = station_card["status_label"]
		var toggle_button: Button = station_card["toggle_button"]
		var fuel_buttons: Dictionary = station_card["fuel_buttons"]
		var fuel_state_label: Label = station_card["fuel_state_label"]
		var recipes_box: VBoxContainer = station_card["recipes_box"]
		var built_count := _get_crafted_item_count(craftable_id)
		var station_level := _get_processing_station_level(craftable_id)
		var is_expanded := bool(processing_station_expanded.get(craftable_id, true))
		var fuel_capacity := _get_station_fuel_capacity(craftable_id)
		var fuel_stored := _get_station_stored_fuel_units(craftable_id)

		toggle_button.text = "Collapse" if is_expanded else "Expand"
		recipes_box.visible = is_expanded
		if built_count <= 0:
			station_status.text = "Build %s to unlock its recipes." % _get_craftable_name(craftable_id)
		else:
			if fuel_capacity > 0:
				station_status.text = "Lv %d | Fuel %d/%d | %.0f%% faster station crafting" % [
					station_level,
					fuel_stored,
					fuel_capacity,
					(1.0 - _get_craftable_speed_multiplier(craftable_id)) * 100.0,
				]
			else:
				station_status.text = "Lv %d | %.0f%% faster station crafting" % [
					station_level,
					(1.0 - _get_craftable_speed_multiplier(craftable_id)) * 100.0,
				]

		var all_fuel_buttons_full := fuel_buttons.size() > 0
		for fuel_item_id in fuel_buttons.keys():
			var fuel_button: Button = fuel_buttons[fuel_item_id]
			var is_refueling_now: bool = (
				not current_action.is_empty()
				and _get_action_type(current_action) == "refuel_station"
				and _get_action_station_id(current_action) == craftable_id
				and _get_action_fuel_item_id(current_action) == fuel_item_id
			)
			var fuel_block_reason := _get_station_fuel_queue_block_reason(craftable_id, fuel_item_id)
			var base_text := _get_resource_name(fuel_item_id)
			all_fuel_buttons_full = all_fuel_buttons_full and fuel_block_reason == "Fuel full"

			if is_refueling_now:
				fuel_button.text = "Loading..."
			elif fuel_block_reason == "Fuel full":
				fuel_button.text = "Fuel Full"
			elif fuel_block_reason == "No fuel space":
				fuel_button.text = "No Space"
			elif fuel_block_reason == "Queue full":
				fuel_button.text = "Queue Full"
			elif fuel_block_reason.begins_with("Need "):
				fuel_button.text = fuel_block_reason
			elif fuel_block_reason != "":
				fuel_button.text = "Blocked"
			else:
				fuel_button.text = base_text

			fuel_button.disabled = is_refueling_now or fuel_block_reason != ""
			fuel_button.tooltip_text = _get_queue_button_tooltip() if not fuel_button.disabled else ""

		if fuel_state_label != null:
			var show_fuel_full_label := built_count > 0 and all_fuel_buttons_full
			fuel_state_label.visible = show_fuel_full_label
			if show_fuel_full_label:
				fuel_state_label.text = "Fuel Full"
			for fuel_item_id in fuel_buttons.keys():
				var fuel_button: Button = fuel_buttons[fuel_item_id]
				fuel_button.visible = not show_fuel_full_label

	for recipe_id in recipe_order:
		_refresh_recipe_card(recipe_id)


func _refresh_item_summary() -> void:
	for item_id in _get_processing_summary_item_ids():
		if not item_labels.has(item_id):
			continue

		var item_label: Label = item_labels[item_id]
		item_label.text = "%s: %d" % [_get_resource_name(item_id), int(inventory.get(item_id, 0))]
		item_label.tooltip_text = _get_item_description(item_id)


func _refresh_tool_card(tool_id: String) -> void:
	var card: Dictionary = tool_cards[tool_id]
	var status_label: Label = card["status_label"]
	var detail_label: RichTextLabel = card["detail_label"]
	var button: Button = card["button"]
	var durability := _get_tool_durability(tool_id)
	var max_durability := _get_tool_max_durability(tool_id)
	var is_crafting_now := not current_action.is_empty() and _get_action_type(current_action) == "craft_tool" and _get_action_id(current_action) == tool_id
	var is_crafting_queued := _has_queued_action("craft_tool", tool_id)
	var block_reason := _get_tool_queue_block_reason(tool_id)

	if is_crafting_now:
		status_label.text = "%s: Crafting (%s left)" % [
			_get_tool_name(tool_id),
			_format_seconds(_get_current_action_time_left()),
		]
	elif durability > 0:
		status_label.text = "%s: %d / %d durability" % [
			_get_tool_name(tool_id),
			durability,
			max_durability,
		]
	else:
		status_label.text = "%s: Not crafted" % _get_tool_name(tool_id)

	detail_label.text = _format_recipe_detail_rich_text(
		_get_tool_craft_time(tool_id),
		_get_tool_craft_xp(tool_id),
		_get_tool_craft_cost(tool_id),
		_get_tool_use_text(tool_id)
	)

	if is_crafting_now:
		button.text = "Crafting..."
	elif is_crafting_queued:
		button.text = "Queued"
	elif durability >= max_durability:
		button.text = "%s Ready" % _get_tool_name(tool_id)
	else:
		button.text = "Queue %s" % _get_tool_name(tool_id)

	button.disabled = is_crafting_now or is_crafting_queued or block_reason != ""


func _refresh_craftable_card(craftable_id: String) -> void:
	var card: Dictionary = craftable_cards[craftable_id]
	var status_label: Label = card["status_label"]
	var detail_label: RichTextLabel = card["detail_label"]
	var button: Button = card["button"]
	var owned_count := _get_crafted_item_count(craftable_id)
	var station_level := _get_processing_station_level(craftable_id)
	var is_crafting_now := not current_action.is_empty() and _get_action_type(current_action) == "craft_item" and _get_action_id(current_action) == craftable_id
	var is_upgrading_now := not current_action.is_empty() and _get_action_type(current_action) == "upgrade_craftable" and _get_action_id(current_action) == craftable_id
	var block_reason := _get_craftable_queue_block_reason(craftable_id)
	var upgrade_block_reason := _get_craftable_upgrade_queue_block_reason(craftable_id)
	var can_upgrade := owned_count > 0

	if is_crafting_now:
		status_label.text = "%s: Building (%s left)" % [
			_get_craftable_name(craftable_id),
			_format_seconds(_get_current_action_time_left()),
		]
	elif is_upgrading_now:
		status_label.text = "%s: Upgrading to Lv %d (%s left)" % [
			_get_craftable_name(craftable_id),
			station_level + 1,
			_format_seconds(_get_current_action_time_left()),
		]
	else:
		if owned_count > 0:
			status_label.text = "%s: Built | Station Lv %d | %.0f%% faster" % [
				_get_craftable_name(craftable_id),
				station_level,
				(1.0 - _get_craftable_speed_multiplier(craftable_id)) * 100.0,
			]
		else:
			status_label.text = "%s: Not built" % _get_craftable_name(craftable_id)

	if owned_count > 0:
		detail_label.text = _format_recipe_detail_rich_text(
			_get_craftable_craft_time(craftable_id),
			_get_craftable_craft_xp(craftable_id),
			_get_craftable_upgrade_cost(craftable_id),
			"Next upgrade: 15%% faster station recipes. %s" % _get_craftable_use_text(craftable_id)
		)
	else:
		detail_label.text = _format_recipe_detail_rich_text(
			_get_craftable_craft_time(craftable_id),
			_get_craftable_craft_xp(craftable_id),
			_get_craftable_craft_cost(craftable_id),
			_get_craftable_use_text(craftable_id)
		)

	if is_crafting_now:
		button.text = "Building..."
	elif is_upgrading_now:
		button.text = "Upgrading..."
	elif can_upgrade:
		button.text = "Upgrade %s" % _get_craftable_name(craftable_id)
	else:
		button.text = "Build %s" % _get_craftable_name(craftable_id)

	button.disabled = is_crafting_now or is_upgrading_now or (upgrade_block_reason != "" if can_upgrade else block_reason != "")


func _refresh_recipe_card(recipe_id: String) -> void:
	var card: Dictionary = recipe_cards.get(recipe_id, {})
	if card.is_empty():
		return

	var stats_label: RichTextLabel = card["stats_label"]
	var button: Button = card["button"]
	var station_id := _get_recipe_station_id(recipe_id)
	var station_ready := _get_crafted_item_count(station_id) > 0
	var is_processing_now := not current_action.is_empty() and _get_action_type(current_action) == "process_recipe" and _get_action_id(current_action) == recipe_id
	var block_reason := _get_recipe_queue_block_reason(recipe_id)
	var display_duration := _get_recipe_craft_time(recipe_id)

	if is_processing_now:
		display_duration = maxf(0.001, float(current_action["duration"]))

	var summary_text := ""
	if not station_ready:
		summary_text = ""
	else:
		summary_text = "%.2fs | +%d XP | Cost: %s | Output: %s" % [
			display_duration,
			_get_recipe_craft_xp(recipe_id),
			_format_cost_markup(_get_recipe_craft_cost(recipe_id)),
			_format_cost(_get_recipe_outputs(recipe_id)),
		]
		var fuel_cost_units := _get_recipe_fuel_cost_units(recipe_id)
		if fuel_cost_units > 0:
			summary_text += " | Fuel: %d" % fuel_cost_units
		if is_processing_now:
			summary_text += " | %s left" % _format_seconds(_get_current_action_time_left())

	stats_label.text = summary_text

	if block_reason != "" and not is_processing_now:
		button.text = block_reason if block_reason.length() <= 18 else "Blocked"
	else:
		button.text = "Queue +1" if is_processing_now else "Queue"

	button.disabled = (block_reason != "" and not is_processing_now)
	if not button.disabled:
		button.tooltip_text = _get_queue_button_tooltip()
	else:
		button.tooltip_text = ""


func _refresh_upgrade_card(upgrade_id: String) -> void:
	var card: Dictionary = upgrade_cards[upgrade_id]
	var level_label: Label = card["level_label"]
	var detail_label: Label = card["detail_label"]
	var cost_label: RichTextLabel = card["cost_label"]
	var button: Button = card["button"]
	var current_level := int(upgrade_levels[upgrade_id])
	var next_cost := _get_upgrade_cost(upgrade_id)

	level_label.text = "Lv %d" % current_level
	detail_label.text = _get_upgrade_detail(upgrade_id)
	cost_label.text = _format_cost_rich_text(next_cost)
	button.disabled = not _can_afford(next_cost)


func _can_queue_pickable(resource_id: String) -> bool:
	if not _is_resource_unlocked(resource_id):
		return false

	return _get_gather_queue_block_reason(resource_id) == ""


func _can_queue_tool_action(tool_id: String) -> bool:
	return _get_tool_queue_block_reason(tool_id) == ""


func _can_queue_craftable_action(craftable_id: String) -> bool:
	return _get_craftable_queue_block_reason(craftable_id) == ""


func _can_queue_craftable_upgrade_action(craftable_id: String) -> bool:
	return _get_craftable_upgrade_queue_block_reason(craftable_id) == ""


func _can_queue_recipe_action(recipe_id: String) -> bool:
	return _get_recipe_queue_block_reason(recipe_id) == ""


func _can_queue_station_fuel_action(craftable_id: String, item_id: String) -> bool:
	return _get_station_fuel_queue_block_reason(craftable_id, item_id) == ""


func _get_gather_queue_block_reason(resource_id: String) -> String:
	if action_queue.size() >= _get_queue_capacity():
		return "Queue full"

	var pipeline_state := _build_pipeline_end_state()
	return _get_action_block_reason_in_state(_make_gather_action(resource_id), pipeline_state)


func _get_tool_queue_block_reason(tool_id: String) -> String:
	if action_queue.size() >= _get_queue_capacity():
		return "Queue full"

	var pipeline_state := _build_pipeline_end_state()
	return _get_action_block_reason_in_state(_make_craft_tool_action(tool_id), pipeline_state)


func _get_craftable_queue_block_reason(craftable_id: String) -> String:
	if action_queue.size() >= _get_queue_capacity():
		return "Queue full"

	var pipeline_state := _build_pipeline_end_state()
	return _get_action_block_reason_in_state(_make_craft_item_action(craftable_id), pipeline_state)


func _get_craftable_upgrade_queue_block_reason(craftable_id: String) -> String:
	if action_queue.size() >= _get_queue_capacity():
		return "Queue full"

	var pipeline_state := _build_pipeline_end_state()
	return _get_action_block_reason_in_state(_make_upgrade_craftable_action(craftable_id), pipeline_state)


func _get_recipe_queue_block_reason(recipe_id: String) -> String:
	if action_queue.size() >= _get_queue_capacity():
		return "Queue full"

	var pipeline_state := _build_pipeline_end_state()
	return _get_action_block_reason_in_state(_make_process_recipe_action(recipe_id), pipeline_state)


func _get_station_fuel_queue_block_reason(craftable_id: String, item_id: String) -> String:
	if action_queue.size() >= _get_queue_capacity():
		return "Queue full"

	var pipeline_state := _build_pipeline_end_state()
	return _get_action_block_reason_in_state(_make_refuel_station_action(craftable_id, item_id), pipeline_state)


func _refresh_runtime_status() -> void:
	var active_count := 0
	if not current_action.is_empty():
		active_count = 1

	if current_action.is_empty():
		current_action_label.text = "Current action: Paused" if is_queue_paused else "Current action: Idle"
	else:
		var duration := maxf(0.001, float(current_action["duration"]))
		var elapsed := minf(float(current_action["elapsed"]), duration)
		var percent := int(round((elapsed / duration) * 100.0))
		var time_left := maxf(0.0, duration - elapsed)
		var action_prefix := "Current action"
		if is_queue_paused:
			action_prefix = "Current action (Paused)"
		current_action_label.text = "%s: %s (%d%%, %s left)" % [
			action_prefix,
			_get_action_progress_label(current_action),
			clampi(percent, 0, 100),
			_format_seconds(time_left),
		]

	var queue_state_text := "Paused" if is_queue_paused else "Running"
	queue_summary_label.text = "Pipeline: %s | %d active, %d queued / %d queued slots" % [
		queue_state_text,
		active_count,
		action_queue.size(),
		_get_queue_capacity(),
	]
	queue_time_left_label.text = "Total time left: %s" % _format_seconds(_estimate_queue_time_left())
	_update_gather_bars()


func _refresh_queue_button_hover_previews() -> void:
	for resource_id in gatherable_order:
		var card: Dictionary = resource_cards[resource_id]
		var queue_button: Button = card["queue_button"]
		if queue_button.disabled:
			continue

		var is_current_action := _is_current_gather_action(resource_id)
		var base_text := "Queue +1" if is_current_action else "Queue"
		queue_button.tooltip_text = _get_queue_button_tooltip()

		if not queue_button.is_hovered():
			queue_button.text = base_text
			continue

		if Input.is_key_pressed(KEY_CTRL):
			queue_button.text = "Queue +%d" % _get_free_queue_slots()
		elif Input.is_key_pressed(KEY_SHIFT):
			queue_button.text = "Queue +5"
		else:
			queue_button.text = base_text

	for recipe_id in recipe_order:
		if not recipe_cards.has(recipe_id):
			continue

		var recipe_card: Dictionary = recipe_cards[recipe_id]
		var recipe_button: Button = recipe_card["button"]
		if recipe_button.disabled:
			continue

		var is_current_recipe: bool = (
			not current_action.is_empty()
			and _get_action_type(current_action) == "process_recipe"
			and _get_action_id(current_action) == recipe_id
		)
		var recipe_base_text := "Queue +1" if is_current_recipe else "Queue"
		if not recipe_button.is_hovered():
			recipe_button.text = recipe_base_text
			continue

		if Input.is_key_pressed(KEY_CTRL):
			recipe_button.text = "Queue +%d" % _get_free_queue_slots()
		elif Input.is_key_pressed(KEY_SHIFT):
			recipe_button.text = "Queue +5"
		else:
			recipe_button.text = recipe_base_text

	for craftable_id in processing_station_cards.keys():
		var station_card: Dictionary = processing_station_cards[craftable_id]
		var fuel_buttons: Dictionary = station_card["fuel_buttons"]
		for fuel_item_id in fuel_buttons.keys():
			var fuel_button: Button = fuel_buttons[fuel_item_id]
			if fuel_button.disabled:
				continue

			var fuel_base_text := _get_resource_name(fuel_item_id)
			if not fuel_button.is_hovered():
				fuel_button.text = fuel_base_text
				continue

			if Input.is_key_pressed(KEY_CTRL):
				fuel_button.text = "+%d" % _get_free_queue_slots()
			elif Input.is_key_pressed(KEY_SHIFT):
				fuel_button.text = "+5"
			else:
				fuel_button.text = fuel_base_text


func _get_queue_button_tooltip() -> String:
	return "Click: queue 1\nShift: queue 5\nCtrl: queue max"


func _get_requested_queue_amount() -> int:
	if Input.is_key_pressed(KEY_CTRL):
		return _get_free_queue_slots()
	if Input.is_key_pressed(KEY_SHIFT):
		return 5

	return 1


func _get_free_queue_slots() -> int:
	return maxi(0, _get_queue_capacity() - action_queue.size())


func _update_gather_bars() -> void:
	for resource_id in gatherable_order:
		var card: Dictionary = resource_cards[resource_id]
		var bar: ProgressBar = card["gather_bar"]
		if _is_current_gather_action(resource_id):
			var duration := maxf(0.001, float(current_action["duration"]))
			bar.value = clampf((float(current_action["elapsed"]) / duration) * 100.0, 0.0, 100.0)
		else:
			bar.value = 0.0


func _get_gather_action_duration(resource_id: String) -> float:
	return _get_action_duration(_make_gather_action(resource_id))


func _get_action_duration(action: Dictionary) -> float:
	return _get_action_duration_for_state(action, _create_simulation_state())


func _get_action_duration_for_state(action: Dictionary, state: Dictionary) -> float:
	return GameRules.get_action_duration_for_state(action, state, _build_rules_context())


func _get_gather_action_duration_for_state(resource_id: String, level_value: int, tooling_level: int) -> float:
	return GameRules.get_gather_action_duration_for_state(resource_id, level_value, tooling_level, _build_rules_context())


func _get_recipe_craft_time_for_state(recipe_id: String, state: Dictionary) -> float:
	return GameRules.get_recipe_craft_time_for_state(recipe_id, state, _build_rules_context())


func _estimate_queue_time_left() -> float:
	var total_time := 0.0
	var state := _create_simulation_state()

	if not current_action.is_empty():
		total_time += _get_current_action_time_left()
		_apply_action_completion_to_state(state, _action_from_current_action())

	for queued_action in action_queue:
		var result := _simulate_action_in_state(state, queued_action)
		if result["ran"]:
			total_time += result["duration"]

	return total_time


func _simulate_exp_gain(level_value: int, exp_value: int, exp_to_next_value: int, amount: int) -> Dictionary:
	return GameRules.simulate_exp_gain(level_value, exp_value, exp_to_next_value, amount, exp_growth)


func _refresh_skill_row(skill_id: String) -> void:
	var row: Dictionary = skill_rows[skill_id]
	var skill_level := _get_skill_level(skill_id)
	var skill_exp := _get_skill_exp(skill_id)
	var skill_exp_to_next := _get_skill_exp_to_next(skill_id)
	var panel: PanelContainer = row["panel"]
	var skill_label: Label = row["skill_label"]
	var exp_label: Label = row["exp_label"]
	var exp_bar: ProgressBar = row["exp_bar"]
	var is_active := skill_id == _get_active_skill_id()

	skill_label.text = "%s Lv %d" % [_get_skill_name(skill_id), skill_level]
	exp_label.text = "%d / %d" % [skill_exp, skill_exp_to_next]
	exp_bar.value = float(skill_exp) / float(skill_exp_to_next) * 100.0
	panel.add_theme_stylebox_override("panel", _make_skill_card_style(is_active))
	skill_label.add_theme_color_override("font_color", Color(1, 1, 1, 1) if is_active else Color(0.82, 0.82, 0.82, 1))
	exp_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1) if is_active else Color(0.65, 0.65, 0.65, 1))


func _refresh_skill_context_label() -> void:
	if skill_context_label == null:
		return

	skill_context_label.text = _get_skill_context_text()


func _get_skill_context_text() -> String:
	var active_skill_id := _get_active_skill_id()
	if active_skill_id == "":
		return "Upgrades improve gathering speed, bag size, and queue size across skills."

	if active_skill_id == "crafting":
		return "Crafting levels up by making tools and buildables."
	if active_skill_id == "cooking":
		return "Cooking levels up by processing meals like Cook Rabbit."

	return "%s: %s" % [_get_skill_name(active_skill_id), _get_next_unlock_text_for_skill(active_skill_id)]


func _get_active_skill_id() -> String:
	if main_tabs == null or main_tabs.get_tab_count() == 0:
		return ""

	var active_tab_title := main_tabs.get_tab_title(main_tabs.current_tab)
	if active_tab_title == "Tools" or active_tab_title == "Buildables":
		return "crafting"
	if active_tab_title != "Gatherables":
		return ""
	if gatherable_skill_tabs == null or gatherable_skill_tabs.get_tab_count() == 0:
		return ""

	return String(gatherable_skill_tabs.get_child(gatherable_skill_tabs.current_tab).name)


func _make_skill_card_style(is_active: bool) -> StyleBoxFlat:
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


func _on_main_tab_changed(_tab: int) -> void:
	_refresh_skill_context_label()
	for skill_id in skill_order:
		_refresh_skill_row(skill_id)


func _on_gatherable_skill_tab_changed(_tab: int) -> void:
	_refresh_skill_context_label()
	for skill_id in skill_order:
		_refresh_skill_row(skill_id)


func _get_next_unlock_text_for_skill(skill_id: String) -> String:
	for resource_id in gatherable_order:
		if _get_resource_skill_id(resource_id) != skill_id:
			continue

		var unlock_level := _get_unlock_level(resource_id)
		if _get_skill_level(skill_id) < unlock_level:
			return "Next: %s Lv %d" % [_get_resource_name(resource_id), unlock_level]

	return "All unlocked"


func _get_capacity(resource_id: String) -> int:
	if not gatherables.has(resource_id):
		return 999999

	var gatherable: Dictionary = gatherables[resource_id]
	return int(gatherable["base_capacity"]) + int(upgrade_levels["bag_space"]) * bag_capacity_per_upgrade


func _get_queue_capacity() -> int:
	return base_queue_size + int(upgrade_levels["queue_slots"]) * queue_size_per_upgrade


func _get_resource_xp(resource_id: String) -> int:
	if not gatherables.has(resource_id):
		return 0

	var gatherable: Dictionary = gatherables[resource_id]
	return int(gatherable["xp"])


func _get_unlock_level(resource_id: String) -> int:
	var gatherable: Dictionary = gatherables[resource_id]
	return int(gatherable["unlock_level"])


func _get_resource_name(resource_id: String) -> String:
	if items.has(resource_id):
		var item: Dictionary = items[resource_id]
		return String(item["name"])

	var gatherable: Dictionary = gatherables[resource_id]
	return String(gatherable["name"])


func _get_item_description(item_id: String) -> String:
	if not items.has(item_id):
		return ""

	var item: Dictionary = items[item_id]
	return String(item.get("description", ""))


func _get_item_fuel_units(item_id: String) -> int:
	return GameRules.get_item_fuel_units(item_id, _build_rules_context())


func _get_resource_skill_id(resource_id: String) -> String:
	if not gatherables.has(resource_id):
		return "crafting"

	var gatherable: Dictionary = gatherables[resource_id]
	return String(gatherable.get("skill", "gathering"))


func _get_gather_output_item_id(resource_id: String) -> String:
	if not gatherables.has(resource_id):
		return resource_id

	var gatherable: Dictionary = gatherables[resource_id]
	return String(gatherable.get("output_item", resource_id))


func _get_inventory_item_order() -> Array:
	var inventory_item_order: Array = []
	for item_id in item_order:
		if not inventory_item_order.has(item_id):
			inventory_item_order.append(item_id)
	for resource_id in gatherable_order:
		if not inventory_item_order.has(resource_id):
			inventory_item_order.append(resource_id)

	return inventory_item_order


func _get_processing_summary_item_ids() -> Array:
	var summary_item_ids: Array = []
	for item_id in item_order:
		if gatherables.has(item_id):
			continue
		summary_item_ids.append(item_id)

	return summary_item_ids


func _get_burnable_item_ids() -> Array:
	var burnable_item_ids: Array = []
	for item_id in item_order:
		if _get_item_fuel_units(item_id) <= 0:
			continue
		burnable_item_ids.append(item_id)

	return burnable_item_ids


func _get_required_tool_id(resource_id: String) -> String:
	var gatherable: Dictionary = gatherables[resource_id]
	if not gatherable.has("required_tool"):
		return ""

	return String(gatherable["required_tool"])


func _get_tool_durability_cost(resource_id: String) -> int:
	var gatherable: Dictionary = gatherables[resource_id]
	if not gatherable.has("tool_durability_cost"):
		return 0

	return int(gatherable["tool_durability_cost"])


func _resource_requires_tool(resource_id: String) -> bool:
	return _get_required_tool_id(resource_id) != ""


func _is_resource_unlocked(resource_id: String) -> bool:
	return _get_skill_level(_get_resource_skill_id(resource_id)) >= _get_unlock_level(resource_id)


func _get_skill_name(skill_id: String) -> String:
	var skill: Dictionary = skill_definitions[skill_id]
	return String(skill["name"])


func _get_skill_level(skill_id: String) -> int:
	return int(skill_states[skill_id]["level"])


func _get_skill_exp(skill_id: String) -> int:
	return int(skill_states[skill_id]["exp"])


func _get_skill_exp_to_next(skill_id: String) -> int:
	return int(skill_states[skill_id]["exp_to_next"])


func _get_skill_level_speed_multiplier(level_value: int) -> float:
	return GameRules.get_skill_level_speed_multiplier(level_value, _build_rules_context())


func _is_resource_unlocked_in_state(resource_id: String, state: Dictionary) -> bool:
	return GameRules.is_resource_unlocked_in_state(resource_id, state, _build_rules_context())


func _get_resource_unlock_requirement_text(resource_id: String) -> String:
	return GameRules.get_resource_unlock_requirement_text(resource_id, _build_rules_context())


func _skill_has_gatherables(skill_id: String) -> bool:
	for resource_id in gatherable_order:
		if _get_resource_skill_id(resource_id) == skill_id:
			return true

	return false


func _get_gatherable_skill_ids() -> Array:
	var ids: Array = []
	for skill_id in skill_order:
		var skill: Dictionary = skill_definitions[skill_id]
		if bool(skill.get("gatherable_tab", false)) and _skill_has_gatherables(skill_id):
			ids.append(skill_id)

	return ids


func _get_tool_name(tool_id: String) -> String:
	var tool: Dictionary = tool_definitions[tool_id]
	return String(tool["name"])


func _get_tool_max_durability(tool_id: String) -> int:
	var tool: Dictionary = tool_definitions[tool_id]
	return int(tool["max_durability"])


func _get_tool_craft_cost(tool_id: String) -> Dictionary:
	var tool: Dictionary = tool_definitions[tool_id]
	return Dictionary(tool["craft_cost"])


func _get_tool_craft_time(tool_id: String) -> float:
	var tool: Dictionary = tool_definitions[tool_id]
	return float(tool["craft_time"])


func _get_tool_craft_xp(tool_id: String) -> int:
	var tool: Dictionary = tool_definitions[tool_id]
	return int(tool["craft_xp"])


func _get_tool_durability(tool_id: String) -> int:
	return int(tools[tool_id]["durability"])


func _get_tool_use_text(tool_id: String) -> String:
	var tool: Dictionary = tool_definitions[tool_id]
	return String(tool.get("use_text", ""))


func _get_craftable_name(craftable_id: String) -> String:
	var craftable: Dictionary = craftables[craftable_id]
	return String(craftable["name"])


func _get_craftable_craft_cost(craftable_id: String) -> Dictionary:
	var craftable: Dictionary = craftables[craftable_id]
	return Dictionary(craftable["craft_cost"])


func _get_craftable_craft_time(craftable_id: String) -> float:
	var craftable: Dictionary = craftables[craftable_id]
	return float(craftable["craft_time"])


func _get_craftable_craft_xp(craftable_id: String) -> int:
	var craftable: Dictionary = craftables[craftable_id]
	return int(craftable["craft_xp"])


func _get_craftable_use_text(craftable_id: String) -> String:
	var craftable: Dictionary = craftables[craftable_id]
	return String(craftable.get("use_text", ""))


func _get_crafted_item_count(craftable_id: String) -> int:
	return int(crafted_items[craftable_id])


func _get_craftable_max_count(craftable_id: String) -> int:
	var craftable: Dictionary = craftables[craftable_id]
	return int(craftable.get("max_count", 999999))


func _get_craftable_upgrade_level(craftable_id: String) -> int:
	return int(craftable_upgrade_levels.get(craftable_id, 0))


func _get_processing_station_level(craftable_id: String) -> int:
	if _get_crafted_item_count(craftable_id) <= 0:
		return 0

	return _get_craftable_upgrade_level(craftable_id) + 1


func _get_craftable_upgrade_cost(craftable_id: String, from_level: int = -1) -> Dictionary:
	var effective_level := from_level
	if effective_level < 0:
		effective_level = _get_craftable_upgrade_level(craftable_id)

	var multiplier := pow(_get_craftable_upgrade_cost_multiplier(craftable_id), effective_level)
	var base_cost := _get_craftable_craft_cost(craftable_id)
	var scaled_cost := {}
	for resource_id in base_cost.keys():
		scaled_cost[resource_id] = int(ceil(float(base_cost[resource_id]) * multiplier))

	return _build_cost(scaled_cost)


func _get_craftable_upgrade_cost_multiplier(craftable_id: String) -> float:
	var craftable: Dictionary = craftables[craftable_id]
	return float(craftable.get("upgrade_cost_multiplier", 1.3))


func _get_craftable_station_speed_multiplier(craftable_id: String) -> float:
	var craftable: Dictionary = craftables[craftable_id]
	return float(craftable.get("station_speed_multiplier", 0.85))


func _get_station_fuel_capacity(craftable_id: String) -> int:
	var craftable: Dictionary = craftables[craftable_id]
	return int(craftable.get("fuel_capacity", 0))


func _get_station_stored_fuel_units(craftable_id: String) -> int:
	return int(stored_fuel_units.get(craftable_id, 0))


func _get_craftable_speed_multiplier(craftable_id: String) -> float:
	return pow(_get_craftable_station_speed_multiplier(craftable_id), _get_craftable_upgrade_level(craftable_id))


func _get_recipe_name(recipe_id: String) -> String:
	var recipe: Dictionary = recipes[recipe_id]
	return String(recipe["name"])


func _get_recipe_station_id(recipe_id: String) -> String:
	var recipe: Dictionary = recipes[recipe_id]
	return String(recipe.get("station", ""))


func _get_recipe_craft_cost(recipe_id: String) -> Dictionary:
	var recipe: Dictionary = recipes[recipe_id]
	return _build_cost(Dictionary(recipe.get("craft_cost", {})))


func _get_recipe_outputs(recipe_id: String) -> Dictionary:
	return _build_cost(GameRules.get_recipe_outputs(recipe_id, _build_rules_context()))


func _get_recipe_craft_time(recipe_id: String) -> float:
	return _get_action_duration(_make_process_recipe_action(recipe_id))


func _get_recipe_craft_xp(recipe_id: String) -> int:
	var recipe: Dictionary = recipes[recipe_id]
	return int(recipe.get("craft_xp", 0))


func _get_recipe_skill_id(recipe_id: String) -> String:
	var recipe: Dictionary = recipes[recipe_id]
	return String(recipe.get("skill", "crafting"))


func _get_recipe_fuel_cost_units(recipe_id: String) -> int:
	var recipe: Dictionary = recipes[recipe_id]
	return int(recipe.get("fuel_cost_units", 0))


func _get_recipe_source_fuel_units(recipe_id: String) -> int:
	return GameRules.get_recipe_source_fuel_units(recipe_id, _build_rules_context())


func _build_pipeline_end_state() -> Dictionary:
	return GameRules.build_pipeline_end_state(
		_create_simulation_state(),
		_action_from_current_action(),
		action_queue,
		_build_rules_context()
	)


func _create_simulation_state() -> Dictionary:
	return {
		"inventory": inventory.duplicate(true),
		"tools": tools.duplicate(true),
		"crafted_items": crafted_items.duplicate(true),
		"craftable_upgrade_levels": craftable_upgrade_levels.duplicate(true),
		"stored_fuel_units": stored_fuel_units.duplicate(true),
		"skills": skill_states.duplicate(true),
	}


func _simulate_action_in_state(state: Dictionary, action: Dictionary) -> Dictionary:
	return GameRules.simulate_action_in_state(state, action, _build_rules_context())


func _get_action_block_reason_in_state(action: Dictionary, state: Dictionary) -> String:
	return GameRules.get_action_block_reason_in_state(action, state, _build_rules_context())


func _apply_action_start_to_state(state: Dictionary, action: Dictionary) -> void:
	GameRules.apply_action_start_to_state(state, action, _build_rules_context())


func _apply_action_completion_to_state(state: Dictionary, action: Dictionary) -> void:
	GameRules.apply_action_completion_to_state(state, action, _build_rules_context())


func _get_action_queue_label(action: Dictionary) -> String:
	match _get_action_type(action):
		"gather":
			return _get_resource_name(_get_action_id(action))
		"craft_tool":
			return "Craft %s" % _get_tool_name(_get_action_id(action))
		"craft_item":
			return "Build %s" % _get_craftable_name(_get_action_id(action))
		"upgrade_craftable":
			return "Upgrade %s" % _get_craftable_name(_get_action_id(action))
		"process_recipe":
			return "%s: %s" % [_get_craftable_name(_get_recipe_station_id(_get_action_id(action))), _get_recipe_name(_get_action_id(action))]
		"refuel_station":
			return "Burn %s in %s" % [_get_resource_name(_get_action_fuel_item_id(action)), _get_craftable_name(_get_action_station_id(action))]
		_:
			return "Unknown"


func _get_action_progress_label(action: Dictionary) -> String:
	match _get_action_type(action):
		"gather":
			return "Gathering %s" % _get_resource_name(_get_action_id(action))
		"craft_tool":
			return "Crafting %s" % _get_tool_name(_get_action_id(action))
		"craft_item":
			return "Building %s" % _get_craftable_name(_get_action_id(action))
		"upgrade_craftable":
			return "Upgrading %s" % _get_craftable_name(_get_action_id(action))
		"process_recipe":
			return "Processing %s" % _get_recipe_name(_get_action_id(action))
		"refuel_station":
			return "Loading %s" % _get_resource_name(_get_action_fuel_item_id(action))
		_:
			return "Working"


func _make_gather_action(resource_id: String) -> Dictionary:
	return {
		"type": "gather",
		"id": resource_id,
	}


func _make_craft_tool_action(tool_id: String) -> Dictionary:
	return {
		"type": "craft_tool",
		"id": tool_id,
	}


func _make_craft_item_action(craftable_id: String) -> Dictionary:
	return {
		"type": "craft_item",
		"id": craftable_id,
	}


func _make_upgrade_craftable_action(craftable_id: String) -> Dictionary:
	return {
		"type": "upgrade_craftable",
		"id": craftable_id,
	}


func _make_process_recipe_action(recipe_id: String) -> Dictionary:
	return {
		"type": "process_recipe",
		"id": recipe_id,
	}


func _make_refuel_station_action(craftable_id: String, item_id: String) -> Dictionary:
	return {
		"type": "refuel_station",
		"id": craftable_id,
		"station_id": craftable_id,
		"fuel_item_id": item_id,
	}


func _action_from_current_action() -> Dictionary:
	if current_action.is_empty():
		return {}

	return {
		"type": _get_action_type(current_action),
		"id": _get_action_id(current_action),
		"station_id": _get_action_station_id(current_action),
		"fuel_item_id": _get_action_fuel_item_id(current_action),
	}


func _get_action_type(action: Dictionary) -> String:
	return String(action.get("type", ""))


func _get_action_id(action: Dictionary) -> String:
	return String(action.get("id", ""))


func _get_action_station_id(action: Dictionary) -> String:
	return String(action.get("station_id", _get_action_id(action)))


func _get_action_fuel_item_id(action: Dictionary) -> String:
	return String(action.get("fuel_item_id", ""))


func _is_current_gather_action(resource_id: String) -> bool:
	return not current_action.is_empty() and _get_action_type(current_action) == "gather" and _get_action_id(current_action) == resource_id


func _has_queued_action(action_type: String, action_id: String) -> bool:
	for queued_action in action_queue:
		if _get_action_type(queued_action) == action_type and _get_action_id(queued_action) == action_id:
			return true

	return false


func _get_upgrade_detail(upgrade_id: String) -> String:
	match upgrade_id:
		"bag_space":
			var current_bonus := int(upgrade_levels[upgrade_id]) * bag_capacity_per_upgrade
			var next_bonus := (int(upgrade_levels[upgrade_id]) + 1) * bag_capacity_per_upgrade
			return "Bag bonus +%d -> +%d" % [
				current_bonus,
				next_bonus,
			]
		"tooling":
			var current_multiplier := pow(speed_upgrade_multiplier, int(upgrade_levels[upgrade_id]))
			var next_multiplier := pow(speed_upgrade_multiplier, int(upgrade_levels[upgrade_id]) + 1)
			var current_reduction := int(round((1.0 - current_multiplier) * 100.0))
			var next_reduction := int(round((1.0 - next_multiplier) * 100.0))
			return "Gather speed +%d%% -> +%d%%" % [
				current_reduction,
				next_reduction,
			]
		"queue_slots":
			var current_capacity := _get_queue_capacity()
			var next_capacity := current_capacity + queue_size_per_upgrade
			return "Queue slots %d -> %d" % [
				current_capacity,
				next_capacity,
			]
		_:
			return ""


func _get_upgrade_cost(upgrade_id: String) -> Dictionary:
	var next_level := int(upgrade_levels[upgrade_id]) + 1
	var upgrade_data: Dictionary = upgrades.get(upgrade_id, {})
	var cost_curve: Dictionary = upgrade_data.get("cost_curve", {})
	var raw_cost := {}

	for resource_id in cost_curve.keys():
		var resource_curve: Dictionary = cost_curve[resource_id]
		var start_level := int(resource_curve.get("start_level", 1))
		if next_level < start_level:
			continue

		var base_cost := int(resource_curve.get("base", 0))
		var step_cost := int(resource_curve.get("step", 0))
		var amount := base_cost + (next_level - start_level) * step_cost
		if amount > 0:
			raw_cost[resource_id] = amount

	return _build_cost(raw_cost)


func _build_cost(raw_cost: Dictionary) -> Dictionary:
	var result := {}
	for resource_id in _get_inventory_item_order():
		if not raw_cost.has(resource_id):
			continue

		var amount := int(raw_cost[resource_id])
		if amount > 0:
			result[resource_id] = amount

	return result


func _can_afford(cost: Dictionary) -> bool:
	return _can_afford_inventory(inventory, cost)


func _can_afford_inventory(stock: Dictionary, cost: Dictionary) -> bool:
	return GameRules.can_afford_inventory(stock, cost)


func _spend_resources(cost: Dictionary) -> void:
	for resource_id in cost.keys():
		inventory[resource_id] -= int(cost[resource_id])


func _on_cost_meta_clicked(meta: Variant) -> void:
	var meta_text := String(meta)
	if not meta_text.begins_with("resource:"):
		return

	var meta_parts := meta_text.split(":")
	if meta_parts.size() < 2:
		return

	var resource_id := String(meta_parts[1])
	var required_amount := 0
	if meta_parts.size() >= 3:
		required_amount = int(meta_parts[2])

	if Input.is_key_pressed(KEY_CTRL):
		_queue_linked_resource_shortfall(resource_id, required_amount)
		return

	_focus_resource_gather_tab(resource_id)


func _focus_resource_gather_tab(resource_id: String) -> void:
	var gather_resource_id := _get_gather_resource_for_item(resource_id)
	if gather_resource_id == "":
		return

	if main_tabs != null:
		for index in range(main_tabs.get_tab_count()):
			if main_tabs.get_tab_title(index) == "Gatherables":
				main_tabs.current_tab = index
				break

	if gatherable_skill_tabs != null:
		var skill_id := _get_resource_skill_id(gather_resource_id)
		for index in range(gatherable_skill_tabs.get_tab_count()):
			if String(gatherable_skill_tabs.get_child(index).name) == skill_id:
				gatherable_skill_tabs.current_tab = index
				break

	_refresh_skill_context_label()
	for skill_id in skill_order:
		_refresh_skill_row(skill_id)


func _queue_linked_resource_shortfall(item_id: String, required_amount: int) -> void:
	var gather_resource_id := _get_gather_resource_for_item(item_id)
	if gather_resource_id == "":
		_show_toast("Can't auto-queue %s from a cost link." % _get_resource_name(item_id))
		return

	var pipeline_state := _build_pipeline_end_state()
	var projected_amount := int(pipeline_state["inventory"].get(item_id, 0))
	var missing_amount := required_amount - projected_amount
	if missing_amount <= 0:
		return

	var gather_action := _make_gather_action(gather_resource_id)
	var block_reason := _get_action_block_reason_in_state(gather_action, pipeline_state)
	if block_reason != "":
		_show_toast(_get_auto_queue_requirement_message(gather_resource_id, block_reason))
		return

	if _get_free_queue_slots() <= 0:
		_show_toast("Queue is full.")
		return

	_queue_action_count(gather_action, missing_amount)


func _get_gather_resource_for_item(item_id: String) -> String:
	if gatherables.has(item_id):
		return item_id

	for resource_id in gatherable_order:
		if _get_gather_output_item_id(resource_id) == item_id:
			return resource_id

	return ""


func _get_auto_queue_requirement_message(resource_id: String, block_reason: String) -> String:
	var item_name := _get_resource_name(_get_gather_output_item_id(resource_id))
	if block_reason == "Queue full":
		return "Queue is full."
	if block_reason == "Full at end of queue":
		return "%s storage will be full at the end of the queue." % item_name
	if block_reason == _get_resource_unlock_requirement_text(resource_id):
		return block_reason
	if block_reason.begins_with("Need "):
		return "%s requires %s." % [item_name, block_reason.trim_prefix("Need ")]

	return "Can't auto-queue %s: %s" % [item_name, block_reason]


func _show_toast(message: String, duration: float = 2.6) -> void:
	if toast_panel == null or toast_label == null:
		return

	toast_label.text = message
	toast_time_left = maxf(0.8, duration)
	toast_panel.visible = true


func _create_resource_navigation_rich_label(font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.context_menu_enabled = false
	label.shortcut_keys_enabled = false
	label.selection_enabled = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.meta_clicked.connect(_on_cost_meta_clicked)
	return label


func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in _get_inventory_item_order():
		if not cost.has(resource_id):
			continue

		parts.append("%d %s" % [int(cost[resource_id]), _get_resource_name(resource_id)])

	if parts.is_empty():
		return "Free"

	var result := ""
	for index in range(parts.size()):
		if index > 0:
			result += ", "
		result += parts[index]

	return result


func _format_recipe_detail_rich_text(duration: float, xp: int, cost: Dictionary, use_text: String) -> String:
	var detail := "%.1fs craft | +%d XP | Cost: %s" % [
		duration,
		xp,
		_format_cost_markup(cost),
	]
	if use_text != "":
		detail += " | %s" % use_text

	return detail


func _format_cost_rich_text(cost: Dictionary) -> String:
	if cost.is_empty():
		return "Cost: Free"

	return "Cost: %s" % _format_cost_markup(cost)


func _format_cost_markup(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in _get_inventory_item_order():
		if not cost.has(resource_id):
			continue

		var amount := int(cost[resource_id])
		var part := _format_resource_cost_part(resource_id, amount)

		parts.append(part)

	if parts.is_empty():
		return "Free"

	return ", ".join(parts)


func _format_resource_cost_part(resource_id: String, amount: int) -> String:
	var part := "%d %s" % [amount, _get_resource_name(resource_id)]
	if int(inventory.get(resource_id, 0)) < amount:
		part = "[url=resource:%s:%d][color=#ff7070]%s[/color][/url]" % [resource_id, amount, part]

	return part


func _format_seconds(seconds: float) -> String:
	var total_seconds := maxf(0.0, seconds)
	var minutes := int(total_seconds / 60.0)
	var remainder := total_seconds - float(minutes * 60)

	if minutes > 0:
		return "%dm %.1fs" % [minutes, remainder]

	return "%.1fs" % total_seconds


func _get_current_action_time_left() -> float:
	if current_action.is_empty():
		return 0.0

	return maxf(0.0, float(current_action["duration"]) - float(current_action["elapsed"]))


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
