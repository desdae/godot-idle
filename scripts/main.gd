extends Control

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

var gatherable_order: Array = []
var gatherables := {}
var tool_order: Array = []
var tool_definitions := {}
var upgrade_order: Array = []
var upgrades := {}

var inventory := {}
var tools := {}
var action_queue: Array[Dictionary] = []
var current_action := {}
var current_action_completion_pending := false

var gathering_level := 1
var gathering_exp := 0
var gathering_exp_to_next := 10
var crafting_level := 1
var crafting_exp := 0
var crafting_exp_to_next := 10
var upgrade_levels := {}

var resource_cards := {}
var upgrade_cards := {}

var gathering_skill_label: Label
var gathering_exp_label: Label
var gathering_exp_bar: ProgressBar
var crafting_skill_label: Label
var crafting_exp_label: Label
var crafting_exp_bar: ProgressBar
var next_unlock_label: Label
var current_action_label: Label
var queue_summary_label: Label
var queue_time_left_label: Label
var queue_list: ItemList
var clear_queue_button: Button
var page_margin: MarginContainer
var root_box: VBoxContainer
var content_grid: GridContainer
var sidebar_scroll: ScrollContainer
var tool_cards := {}


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

	var gatherable_data := _load_ordered_data_file("res://data/gatherables.json")
	if not gatherable_data.get("ok", false):
		return false
	gatherable_order = gatherable_data["order"]
	gatherables = gatherable_data["entries"]

	var tool_data := _load_ordered_data_file("res://data/tools.json")
	if not tool_data.get("ok", false):
		return false
	tool_order = tool_data["order"]
	tool_definitions = tool_data["entries"]

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

	tools.clear()
	for tool_id in tool_order:
		tools[tool_id] = {
			"durability": 0,
		}

	upgrade_levels.clear()
	for upgrade_id in upgrade_order:
		upgrade_levels[upgrade_id] = 0
	action_queue.clear()
	current_action.clear()
	current_action_completion_pending = false
	gathering_level = 1
	gathering_exp = 0
	gathering_exp_to_next = 10
	crafting_level = 1
	crafting_exp = 0
	crafting_exp_to_next = 10


func _process(delta: float) -> void:
	if current_action_completion_pending:
		current_action_completion_pending = false
		_complete_current_action()

	if current_action.is_empty():
		_start_next_action()

	if not current_action.is_empty():
		var duration := maxf(0.001, float(current_action["duration"]))
		var elapsed := minf(float(current_action["elapsed"]) + delta, duration)
		current_action["elapsed"] = elapsed
		if elapsed >= duration:
			current_action_completion_pending = true

	_refresh_runtime_status()


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

	var gather_row := HBoxContainer.new()
	gather_row.add_theme_constant_override("separation", 12)
	skill_box.add_child(gather_row)

	gathering_skill_label = Label.new()
	gathering_skill_label.add_theme_font_size_override("font_size", 18)
	gather_row.add_child(gathering_skill_label)

	gathering_exp_label = Label.new()
	gathering_exp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gather_row.add_child(gathering_exp_label)

	next_unlock_label = Label.new()
	next_unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	next_unlock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gather_row.add_child(next_unlock_label)

	gathering_exp_bar = ProgressBar.new()
	gathering_exp_bar.min_value = 0
	gathering_exp_bar.max_value = 100
	gathering_exp_bar.show_percentage = false
	gathering_exp_bar.custom_minimum_size = Vector2(0, 12)
	skill_box.add_child(gathering_exp_bar)

	var crafting_row := HBoxContainer.new()
	crafting_row.add_theme_constant_override("separation", 12)
	skill_box.add_child(crafting_row)

	crafting_skill_label = Label.new()
	crafting_skill_label.add_theme_font_size_override("font_size", 16)
	crafting_row.add_child(crafting_skill_label)

	crafting_exp_label = Label.new()
	crafting_exp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crafting_row.add_child(crafting_exp_label)

	crafting_exp_bar = ProgressBar.new()
	crafting_exp_bar.min_value = 0
	crafting_exp_bar.max_value = 100
	crafting_exp_bar.show_percentage = false
	crafting_exp_bar.custom_minimum_size = Vector2(0, 10)
	skill_box.add_child(crafting_exp_bar)


func _build_content(root: VBoxContainer) -> void:
	content_grid = GridContainer.new()
	content_grid.columns = 2
	content_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_grid.add_theme_constant_override("h_separation", 12)
	content_grid.add_theme_constant_override("v_separation", 12)
	root.add_child(content_grid)

	_build_gatherables_panel(content_grid)

	sidebar_scroll = ScrollContainer.new()
	sidebar_scroll.custom_minimum_size = Vector2(320, 0)
	sidebar_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_grid.add_child(sidebar_scroll)

	var sidebar := VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 10)
	sidebar_scroll.add_child(sidebar)

	_build_queue_panel(sidebar)
	_build_tools_panel(sidebar)
	_build_upgrades_panel(sidebar)


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

	var gatherables_title := Label.new()
	gatherables_title.text = "Gatherables"
	gatherables_title.add_theme_font_size_override("font_size", 18)
	gatherables_root.add_child(gatherables_title)

	var gatherables_scroll := ScrollContainer.new()
	gatherables_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gatherables_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gatherables_root.add_child(gatherables_scroll)

	var gatherables_box := VBoxContainer.new()
	gatherables_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gatherables_box.add_theme_constant_override("separation", 6)
	gatherables_scroll.add_child(gatherables_box)

	for resource_id in gatherable_order:
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
		name_label.custom_minimum_size = Vector2(80, 0)
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
	queue_list.custom_minimum_size = Vector2(0, 84)
	queue_box.add_child(queue_list)

	clear_queue_button = Button.new()
	clear_queue_button.text = "Clear queued actions"
	clear_queue_button.pressed.connect(_clear_queue)
	queue_box.add_child(clear_queue_button)


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

		var detail_label := Label.new()
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_label.add_theme_font_size_override("font_size", 13)
		tool_row.add_child(detail_label)

		var button := Button.new()
		button.pressed.connect(_craft_tool.bind(tool_id))
		tool_row.add_child(button)

		tool_cards[tool_id] = {
			"status_label": status_label,
			"detail_label": detail_label,
			"button": button,
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

		var cost_label := Label.new()
		cost_label.add_theme_font_size_override("font_size", 13)
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

	_queue_action(_make_gather_action(resource_id))


func _craft_tool(tool_id: String) -> void:
	if not _can_queue_tool_action(tool_id):
		return

	_queue_action(_make_craft_tool_action(tool_id))


func _queue_action(action: Dictionary) -> void:
	action_queue.append(action.duplicate(true))
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
		current_action = {
			"type": _get_action_type(next_action),
			"id": _get_action_id(next_action),
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
			if inventory[resource_id] < _get_capacity(resource_id):
				inventory[resource_id] += 1
				_gain_gathering_exp(_get_resource_xp(resource_id))
		"craft_tool":
			var tool_id := _get_action_id(action)
			tools[tool_id]["durability"] = _get_tool_max_durability(tool_id)
			_gain_crafting_exp(_get_tool_craft_xp(tool_id))

	current_action.clear()
	_refresh_ui()
	_start_next_action()


func _gain_gathering_exp(amount: int) -> void:
	var result := _simulate_exp_gain(gathering_level, gathering_exp, gathering_exp_to_next, amount)
	gathering_level = result["level"]
	gathering_exp = result["exp"]
	gathering_exp_to_next = result["exp_to_next"]


func _gain_crafting_exp(amount: int) -> void:
	var result := _simulate_exp_gain(crafting_level, crafting_exp, crafting_exp_to_next, amount)
	crafting_level = result["level"]
	crafting_exp = result["exp"]
	crafting_exp_to_next = result["exp_to_next"]


func _refresh_ui() -> void:
	gathering_skill_label.text = "Gathering Lv %d" % gathering_level
	gathering_exp_label.text = "%d / %d EXP" % [gathering_exp, gathering_exp_to_next]
	gathering_exp_bar.value = float(gathering_exp) / float(gathering_exp_to_next) * 100.0
	crafting_skill_label.text = "Crafting Lv %d" % crafting_level
	crafting_exp_label.text = "%d / %d EXP" % [crafting_exp, crafting_exp_to_next]
	crafting_exp_bar.value = float(crafting_exp) / float(crafting_exp_to_next) * 100.0
	next_unlock_label.text = _get_next_unlock_text()

	queue_list.clear()
	if not current_action.is_empty():
		queue_list.add_item("Now: %s" % _get_action_queue_label(current_action))

	for index in range(action_queue.size()):
		var queued_action: Dictionary = action_queue[index]
		queue_list.add_item("%d. %s" % [index + 1, _get_action_queue_label(queued_action)])

	clear_queue_button.disabled = action_queue.is_empty()
	_refresh_tool_panel()

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
	var is_current_action := _is_current_gather_action(resource_id)
	var block_reason := _get_gather_queue_block_reason(resource_id)
	var status_text := "Ready"
	var display_duration := _get_gather_action_duration(resource_id)

	if not _is_resource_unlocked(resource_id):
		status_text = "Unlock Lv %d" % unlock_level
		stats_label.text = "Lv %d | %.2fs | %d XP | %d/%d | %s" % [
			unlock_level,
			display_duration,
			_get_resource_xp(resource_id),
			inventory[resource_id],
			current_capacity,
			status_text,
		]
		queue_button.disabled = true
		queue_button.text = "Locked"
		return

	if is_current_action:
		display_duration = maxf(0.001, float(current_action["duration"]))
		status_text = "Gathering %s" % _format_seconds(_get_current_action_time_left())
	else:
		status_text = "Ready"

	if block_reason != "" and not is_current_action:
		status_text = block_reason
		queue_button.disabled = true
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

	stats_label.text = "Lv %d | %.2fs | %d XP | %d/%d | %s" % [
		unlock_level,
		display_duration,
		_get_resource_xp(resource_id),
		inventory[resource_id],
		current_capacity,
		status_text,
	]


func _refresh_tool_panel() -> void:
	for tool_id in tool_order:
		_refresh_tool_card(tool_id)


func _refresh_tool_card(tool_id: String) -> void:
	var card: Dictionary = tool_cards[tool_id]
	var status_label: Label = card["status_label"]
	var detail_label: Label = card["detail_label"]
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

	detail_label.text = "%.1fs craft | +%d XP | Cost: %s" % [
		_get_tool_craft_time(tool_id),
		_get_tool_craft_xp(tool_id),
		_format_cost(_get_tool_craft_cost(tool_id)),
	]

	if is_crafting_now:
		button.text = "Crafting..."
	elif is_crafting_queued:
		button.text = "Queued"
	elif durability >= max_durability:
		button.text = "%s Ready" % _get_tool_name(tool_id)
	else:
		button.text = "Queue %s" % _get_tool_name(tool_id)

	button.disabled = is_crafting_now or is_crafting_queued or block_reason != ""


func _refresh_upgrade_card(upgrade_id: String) -> void:
	var card: Dictionary = upgrade_cards[upgrade_id]
	var level_label: Label = card["level_label"]
	var detail_label: Label = card["detail_label"]
	var cost_label: Label = card["cost_label"]
	var button: Button = card["button"]
	var current_level := int(upgrade_levels[upgrade_id])
	var next_cost := _get_upgrade_cost(upgrade_id)

	level_label.text = "Lv %d" % current_level
	detail_label.text = _get_upgrade_detail(upgrade_id)
	cost_label.text = "Cost: %s" % _format_cost(next_cost)
	button.disabled = not _can_afford(next_cost)


func _can_queue_pickable(resource_id: String) -> bool:
	if not _is_resource_unlocked(resource_id):
		return false

	return _get_gather_queue_block_reason(resource_id) == ""


func _can_queue_tool_action(tool_id: String) -> bool:
	return _get_tool_queue_block_reason(tool_id) == ""


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


func _refresh_runtime_status() -> void:
	var active_count := 0
	if not current_action.is_empty():
		active_count = 1

	if current_action.is_empty():
		current_action_label.text = "Current action: Idle"
	else:
		var duration := maxf(0.001, float(current_action["duration"]))
		var elapsed := minf(float(current_action["elapsed"]), duration)
		var percent := int(round((elapsed / duration) * 100.0))
		var time_left := maxf(0.0, duration - elapsed)
		current_action_label.text = "Current action: %s (%d%%, %s left)" % [
			_get_action_progress_label(current_action),
			clampi(percent, 0, 100),
			_format_seconds(time_left),
		]

	queue_summary_label.text = "Pipeline: %d active, %d queued / %d queued slots" % [
		active_count,
		action_queue.size(),
		_get_queue_capacity(),
	]
	queue_time_left_label.text = "Total time left: %s" % _format_seconds(_estimate_queue_time_left())
	_update_gather_bars()


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
	var action_type := _get_action_type(action)
	var action_id := _get_action_id(action)
	match action_type:
		"gather":
			return _get_gather_action_duration_for_state(action_id, int(state["gathering_level"]), int(upgrade_levels["tooling"]))
		"craft_tool":
			return _get_tool_craft_time(action_id)
		_:
			return 0.0


func _get_gather_action_duration_for_state(resource_id: String, level_value: int, tooling_level: int) -> float:
	var gatherable: Dictionary = gatherables[resource_id]
	var level_multiplier := pow(level_speed_multiplier, maxi(level_value - 1, 0))
	var upgrade_multiplier := pow(speed_upgrade_multiplier, tooling_level)
	var duration := float(gatherable["base_time"]) * level_multiplier * upgrade_multiplier
	return maxf(min_gather_time, duration)


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


func _get_next_unlock_text() -> String:
	for resource_id in gatherable_order:
		var unlock_level := _get_unlock_level(resource_id)
		if gathering_level < unlock_level:
			return "Next unlock: %s at Gathering Level %d" % [_get_resource_name(resource_id), unlock_level]

	return "All gatherables unlocked. Keep upgrading your setup."


func _get_capacity(resource_id: String) -> int:
	var gatherable: Dictionary = gatherables[resource_id]
	return int(gatherable["base_capacity"]) + int(upgrade_levels["bag_space"]) * bag_capacity_per_upgrade


func _get_queue_capacity() -> int:
	return base_queue_size + int(upgrade_levels["queue_slots"]) * queue_size_per_upgrade


func _get_resource_xp(resource_id: String) -> int:
	var gatherable: Dictionary = gatherables[resource_id]
	return int(gatherable["xp"])


func _get_unlock_level(resource_id: String) -> int:
	var gatherable: Dictionary = gatherables[resource_id]
	return int(gatherable["unlock_level"])


func _get_resource_name(resource_id: String) -> String:
	var gatherable: Dictionary = gatherables[resource_id]
	return String(gatherable["name"])


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
	return gathering_level >= _get_unlock_level(resource_id)


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


func _build_pipeline_end_state() -> Dictionary:
	var state := _create_simulation_state()

	if not current_action.is_empty():
		_apply_action_completion_to_state(state, _action_from_current_action())

	for queued_action in action_queue:
		_simulate_action_in_state(state, queued_action)

	return state


func _create_simulation_state() -> Dictionary:
	return {
		"inventory": inventory.duplicate(true),
		"tools": tools.duplicate(true),
		"gathering_level": gathering_level,
		"gathering_exp": gathering_exp,
		"gathering_exp_to_next": gathering_exp_to_next,
		"crafting_level": crafting_level,
		"crafting_exp": crafting_exp,
		"crafting_exp_to_next": crafting_exp_to_next,
	}


func _simulate_action_in_state(state: Dictionary, action: Dictionary) -> Dictionary:
	if _get_action_block_reason_in_state(action, state) != "":
		return {
			"ran": false,
			"duration": 0.0,
		}

	var duration := _get_action_duration_for_state(action, state)
	_apply_action_start_to_state(state, action)
	_apply_action_completion_to_state(state, action)
	return {
		"ran": true,
		"duration": duration,
	}


func _get_action_block_reason_in_state(action: Dictionary, state: Dictionary) -> String:
	var action_type := _get_action_type(action)
	var action_id := _get_action_id(action)
	match action_type:
		"gather":
			if int(state["inventory"][action_id]) >= _get_capacity(action_id):
				return "Full at end of queue"

			var required_tool_id := _get_required_tool_id(action_id)
			if required_tool_id != "":
				var available_durability := int(state["tools"][required_tool_id]["durability"])
				if available_durability < _get_tool_durability_cost(action_id):
					return "Need %s" % _get_tool_name(required_tool_id)

			return ""
		"craft_tool":
			if int(state["tools"][action_id]["durability"]) >= _get_tool_max_durability(action_id):
				return "%s ready" % _get_tool_name(action_id)
			if not _can_afford_inventory(state["inventory"], _get_tool_craft_cost(action_id)):
				return "Need %s" % _format_cost(_get_tool_craft_cost(action_id))
			return ""
		_:
			return "Unknown action"


func _apply_action_start_to_state(state: Dictionary, action: Dictionary) -> void:
	var action_type := _get_action_type(action)
	var action_id := _get_action_id(action)
	match action_type:
		"gather":
			var required_tool_id := _get_required_tool_id(action_id)
			if required_tool_id != "":
				state["tools"][required_tool_id]["durability"] = maxi(
					0,
					int(state["tools"][required_tool_id]["durability"]) - _get_tool_durability_cost(action_id)
				)
		"craft_tool":
			var craft_cost := _get_tool_craft_cost(action_id)
			for resource_id in craft_cost.keys():
				state["inventory"][resource_id] -= int(craft_cost[resource_id])


func _apply_action_completion_to_state(state: Dictionary, action: Dictionary) -> void:
	var action_type := _get_action_type(action)
	var action_id := _get_action_id(action)
	match action_type:
		"gather":
			if int(state["inventory"][action_id]) < _get_capacity(action_id):
				state["inventory"][action_id] += 1
				var gather_result := _simulate_exp_gain(
					int(state["gathering_level"]),
					int(state["gathering_exp"]),
					int(state["gathering_exp_to_next"]),
					_get_resource_xp(action_id)
				)
				state["gathering_level"] = gather_result["level"]
				state["gathering_exp"] = gather_result["exp"]
				state["gathering_exp_to_next"] = gather_result["exp_to_next"]
		"craft_tool":
			state["tools"][action_id]["durability"] = _get_tool_max_durability(action_id)
			var craft_result := _simulate_exp_gain(
				int(state["crafting_level"]),
				int(state["crafting_exp"]),
				int(state["crafting_exp_to_next"]),
				_get_tool_craft_xp(action_id)
			)
			state["crafting_level"] = craft_result["level"]
			state["crafting_exp"] = craft_result["exp"]
			state["crafting_exp_to_next"] = craft_result["exp_to_next"]


func _get_action_queue_label(action: Dictionary) -> String:
	match _get_action_type(action):
		"gather":
			return _get_resource_name(_get_action_id(action))
		"craft_tool":
			return "Craft %s" % _get_tool_name(_get_action_id(action))
		_:
			return "Unknown"


func _get_action_progress_label(action: Dictionary) -> String:
	match _get_action_type(action):
		"gather":
			return "Gathering %s" % _get_resource_name(_get_action_id(action))
		"craft_tool":
			return "Crafting %s" % _get_tool_name(_get_action_id(action))
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


func _action_from_current_action() -> Dictionary:
	if current_action.is_empty():
		return {}

	return {
		"type": _get_action_type(current_action),
		"id": _get_action_id(current_action),
	}


func _get_action_type(action: Dictionary) -> String:
	return String(action.get("type", ""))


func _get_action_id(action: Dictionary) -> String:
	return String(action.get("id", ""))


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
	for resource_id in gatherable_order:
		if not raw_cost.has(resource_id):
			continue

		var amount := int(raw_cost[resource_id])
		if amount > 0:
			result[resource_id] = amount

	return result


func _can_afford(cost: Dictionary) -> bool:
	return _can_afford_inventory(inventory, cost)


func _can_afford_inventory(stock: Dictionary, cost: Dictionary) -> bool:
	for resource_id in cost.keys():
		if int(stock.get(resource_id, 0)) < int(cost[resource_id]):
			return false

	return true


func _spend_resources(cost: Dictionary) -> void:
	for resource_id in cost.keys():
		inventory[resource_id] -= int(cost[resource_id])


func _format_cost(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in gatherable_order:
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
	if page_margin == null or content_grid == null or sidebar_scroll == null:
		return

	page_margin.custom_minimum_size = Vector2(maxf(0.0, size.x), 0.0)

	var is_stacked := size.x < layout_stack_breakpoint
	content_grid.columns = 1 if is_stacked else 2

	if is_stacked:
		sidebar_scroll.custom_minimum_size = Vector2(0, 0)
		sidebar_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	else:
		sidebar_scroll.custom_minimum_size = Vector2(340, 0)
		sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
