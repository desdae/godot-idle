extends RefCounted


static func build_toast_layer(root: Control) -> Dictionary:
	var toast_anchor := CenterContainer.new()
	toast_anchor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast_anchor.offset_top = -84
	toast_anchor.offset_bottom = -20
	toast_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_anchor)

	var toast_panel := PanelContainer.new()
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

	var toast_label := Label.new()
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_margin.add_child(toast_label)

	return {
		"toast_panel": toast_panel,
		"toast_label": toast_label,
	}


static func build_skill_panel(parent: VBoxContainer, skill_entries: Array) -> Dictionary:
	var skill_panel := PanelContainer.new()
	skill_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(skill_panel)

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

	var skill_rows := {}
	for entry in skill_entries:
		var skill_id := String(entry["id"])
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
		skill_label.text = String(entry["name"])
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

	var skill_context_label := Label.new()
	skill_context_label.add_theme_font_size_override("font_size", 13)
	skill_box.add_child(skill_context_label)

	return {
		"skill_rows": skill_rows,
		"skill_context_label": skill_context_label,
	}


static func build_gatherables_panel(
	parent: Container,
	skill_groups: Array,
	queue_pickable_handler: Callable,
	gatherable_tab_changed_handler: Callable
) -> Dictionary:
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

	var gatherable_skill_tabs := TabContainer.new()
	gatherable_skill_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gatherable_skill_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not gatherable_tab_changed_handler.is_null():
		gatherable_skill_tabs.tab_changed.connect(gatherable_tab_changed_handler)
	gatherables_root.add_child(gatherable_skill_tabs)

	var resource_cards := {}
	for skill_group in skill_groups:
		var gatherables_scroll := ScrollContainer.new()
		gatherables_scroll.name = String(skill_group["id"])
		gatherables_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gatherables_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		gatherable_skill_tabs.add_child(gatherables_scroll)
		gatherable_skill_tabs.set_tab_title(gatherable_skill_tabs.get_tab_count() - 1, String(skill_group["name"]))

		var gatherables_box := VBoxContainer.new()
		gatherables_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gatherables_box.add_theme_constant_override("separation", 6)
		gatherables_scroll.add_child(gatherables_box)

		for resource_entry in skill_group["resources"]:
			var resource_id := String(resource_entry["id"])
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
			name_label.text = String(resource_entry["name"])
			name_label.custom_minimum_size = Vector2(100, 0)
			name_label.add_theme_font_size_override("font_size", 15)
			top_row.add_child(name_label)

			var stats_label := Label.new()
			stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top_row.add_child(stats_label)

			var queue_button := Button.new()
			queue_button.custom_minimum_size = Vector2(122, 0)
			queue_button.pressed.connect(queue_pickable_handler.bind(resource_id))
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

	return {
		"gatherable_skill_tabs": gatherable_skill_tabs,
		"resource_cards": resource_cards,
	}


static func build_queue_panel(
	parent: VBoxContainer,
	clear_queue_handler: Callable,
	pause_queue_handler: Callable
) -> Dictionary:
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

	var current_action_label := Label.new()
	current_action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	queue_box.add_child(current_action_label)

	var queue_summary_label := Label.new()
	queue_box.add_child(queue_summary_label)

	var queue_time_left_label := Label.new()
	queue_box.add_child(queue_time_left_label)

	var queue_list := ItemList.new()
	queue_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	queue_list.custom_minimum_size = Vector2(0, 140)
	queue_box.add_child(queue_list)

	var clear_queue_button := Button.new()
	clear_queue_button.text = "Clear queued actions"
	clear_queue_button.pressed.connect(clear_queue_handler)
	queue_box.add_child(clear_queue_button)

	var pause_queue_button := Button.new()
	pause_queue_button.text = "Pause queue"
	pause_queue_button.pressed.connect(pause_queue_handler)
	queue_box.add_child(pause_queue_button)

	return {
		"current_action_label": current_action_label,
		"queue_summary_label": queue_summary_label,
		"queue_time_left_label": queue_time_left_label,
		"queue_list": queue_list,
		"clear_queue_button": clear_queue_button,
		"pause_queue_button": pause_queue_button,
	}


static func build_tools_panel(
	parent: VBoxContainer,
	tool_entries: Array,
	craft_tool_handler: Callable,
	meta_clicked_handler: Callable
) -> Dictionary:
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

	var tool_cards := {}
	for entry in tool_entries:
		var tool_id := String(entry["id"])
		var tool_row := VBoxContainer.new()
		tool_row.add_theme_constant_override("separation", 2)
		tools_box.add_child(tool_row)

		var name_label := Label.new()
		name_label.text = String(entry["name"])
		name_label.add_theme_font_size_override("font_size", 15)
		tool_row.add_child(name_label)

		var status_label := Label.new()
		status_label.add_theme_font_size_override("font_size", 14)
		tool_row.add_child(status_label)

		var detail_label := _create_resource_navigation_rich_label(13, meta_clicked_handler)
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tool_row.add_child(detail_label)

		var button := Button.new()
		button.pressed.connect(craft_tool_handler.bind(tool_id))
		tool_row.add_child(button)

		tool_cards[tool_id] = {
			"status_label": status_label,
			"detail_label": detail_label,
			"button": button,
		}

	return tool_cards


static func build_craftables_panel(
	parent: VBoxContainer,
	craftable_entries: Array,
	craft_item_handler: Callable,
	meta_clicked_handler: Callable
) -> Dictionary:
	if craftable_entries.is_empty():
		return {}

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

	var craftable_cards := {}
	for entry in craftable_entries:
		var craftable_id := String(entry["id"])
		var craftable_row := VBoxContainer.new()
		craftable_row.add_theme_constant_override("separation", 2)
		craftables_box.add_child(craftable_row)

		var name_label := Label.new()
		name_label.text = String(entry["name"])
		name_label.add_theme_font_size_override("font_size", 15)
		craftable_row.add_child(name_label)

		var status_label := Label.new()
		status_label.add_theme_font_size_override("font_size", 14)
		craftable_row.add_child(status_label)

		var detail_label := _create_resource_navigation_rich_label(13, meta_clicked_handler)
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		craftable_row.add_child(detail_label)

		var button := Button.new()
		button.pressed.connect(craft_item_handler.bind(craftable_id))
		craftable_row.add_child(button)

		craftable_cards[craftable_id] = {
			"status_label": status_label,
			"detail_label": detail_label,
			"button": button,
		}

	return craftable_cards


static func build_processing_panel(
	parent: VBoxContainer,
	summary_item_ids: Array,
	station_entries: Array,
	queue_recipe_handler: Callable,
	queue_station_fuel_handler: Callable,
	toggle_station_handler: Callable,
	meta_clicked_handler: Callable
) -> Dictionary:
	if station_entries.is_empty():
		return {}

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

	var item_labels := {}
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
			item_labels[String(item_id)] = item_label

	var processing_station_cards := {}
	var processing_station_expanded := {}
	var recipe_cards := {}
	for station_entry in station_entries:
		var craftable_id := String(station_entry["id"])
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
		station_title.text = String(station_entry["name"])
		station_title.add_theme_font_size_override("font_size", 16)
		station_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		station_header.add_child(station_title)

		var toggle_button := Button.new()
		toggle_button.custom_minimum_size = Vector2(90, 0)
		toggle_button.pressed.connect(toggle_station_handler.bind(craftable_id))
		station_header.add_child(toggle_button)

		var station_status := Label.new()
		station_box.add_child(station_status)

		var fuel_buttons := {}
		var fuel_state_label: Label = null
		var burnable_items: Array = station_entry["burnable_items"]
		if not burnable_items.is_empty():
			var fuel_buttons_row := HBoxContainer.new()
			fuel_buttons_row.add_theme_constant_override("separation", 6)
			station_box.add_child(fuel_buttons_row)

			var burn_label := Label.new()
			burn_label.text = "Burn"
			fuel_buttons_row.add_child(burn_label)

			fuel_state_label = Label.new()
			fuel_state_label.visible = false
			fuel_buttons_row.add_child(fuel_state_label)

			for burnable_item in burnable_items:
				var fuel_item_id := String(burnable_item["id"])
				var fuel_button := Button.new()
				fuel_button.text = String(burnable_item["name"])
				fuel_button.custom_minimum_size = Vector2(72, 0)
				fuel_button.pressed.connect(queue_station_fuel_handler.bind(craftable_id, fuel_item_id))
				fuel_buttons_row.add_child(fuel_button)
				fuel_buttons[fuel_item_id] = fuel_button

		var recipes_box := VBoxContainer.new()
		recipes_box.add_theme_constant_override("separation", 4)
		station_box.add_child(recipes_box)

		for recipe_entry in station_entry["recipes"]:
			var recipe_id := String(recipe_entry["id"])
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
			name_label.text = String(recipe_entry["name"])
			name_label.custom_minimum_size = Vector2(150, 0)
			name_label.add_theme_font_size_override("font_size", 15)
			row_box.add_child(name_label)

			var stats_label := _create_resource_navigation_rich_label(13, meta_clicked_handler)
			stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stats_label.fit_content = false
			stats_label.bbcode_enabled = true
			row_box.add_child(stats_label)

			var button := Button.new()
			button.custom_minimum_size = Vector2(122, 0)
			button.pressed.connect(queue_recipe_handler.bind(recipe_id))
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

	return {
		"item_labels": item_labels,
		"recipe_cards": recipe_cards,
		"processing_station_cards": processing_station_cards,
		"processing_station_expanded": processing_station_expanded,
	}


static func build_upgrades_panel(
	parent: VBoxContainer,
	upgrade_entries: Array,
	buy_upgrade_handler: Callable,
	meta_clicked_handler: Callable
) -> Dictionary:
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

	var upgrade_cards := {}
	for entry in upgrade_entries:
		var upgrade_id := String(entry["id"])
		var row_box := HBoxContainer.new()
		row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_box.add_theme_constant_override("separation", 10)
		upgrades_box.add_child(row_box)

		var info_box := VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.add_theme_constant_override("separation", 2)
		row_box.add_child(info_box)

		var name_label := Label.new()
		name_label.text = String(entry["name"])
		name_label.add_theme_font_size_override("font_size", 15)
		info_box.add_child(name_label)

		var level_label := Label.new()
		level_label.add_theme_font_size_override("font_size", 13)
		info_box.add_child(level_label)

		var detail_label := Label.new()
		detail_label.add_theme_font_size_override("font_size", 13)
		info_box.add_child(detail_label)

		var cost_label := _create_resource_navigation_rich_label(13, meta_clicked_handler)
		info_box.add_child(cost_label)

		var button := Button.new()
		button.custom_minimum_size = Vector2(118, 0)
		button.text = String(entry["button_text"])
		button.pressed.connect(buy_upgrade_handler.bind(upgrade_id))
		row_box.add_child(button)

		upgrade_cards[upgrade_id] = {
			"level_label": level_label,
			"detail_label": detail_label,
			"cost_label": cost_label,
			"button": button,
		}

	return upgrade_cards


static func _create_resource_navigation_rich_label(font_size: int, meta_clicked_handler: Callable) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.context_menu_enabled = false
	label.shortcut_keys_enabled = false
	label.selection_enabled = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", font_size)
	if not meta_clicked_handler.is_null():
		label.meta_clicked.connect(meta_clicked_handler)
	return label
