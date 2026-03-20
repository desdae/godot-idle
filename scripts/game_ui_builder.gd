extends RefCounted


static func _apply_fancy_button(button: Button, variant: String = "gold", compact: bool = false) -> void:
	button.add_theme_stylebox_override("normal", _make_button_style(variant, "normal"))
	button.add_theme_stylebox_override("hover", _make_button_style(variant, "hover"))
	button.add_theme_stylebox_override("pressed", _make_button_style(variant, "pressed"))
	button.add_theme_stylebox_override("disabled", _make_button_style(variant, "disabled"))
	button.add_theme_stylebox_override("focus", _make_button_style(variant, "hover"))
	button.add_theme_color_override("font_color", _get_button_font_color(variant, false))
	button.add_theme_color_override("font_hover_color", _get_button_font_color(variant, false))
	button.add_theme_color_override("font_pressed_color", _get_button_font_color(variant, true))
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5, 0.9))
	button.add_theme_font_size_override("font_size", 12 if compact else 13)
	button.add_theme_constant_override("h_separation", 4)
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.08))
	button.custom_minimum_size = Vector2(button.custom_minimum_size.x, 32 if compact else 36)


static func _make_button_style(variant: String, state: String) -> StyleBoxFlat:
	var palette := _get_button_palette(variant, state)
	var style := StyleBoxFlat.new()
	style.bg_color = palette["fill"]
	style.border_color = palette["border"]
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 3 if state == "pressed" else 2
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_color = palette["shadow"]
	style.shadow_size = 5 if state != "pressed" else 2
	style.shadow_offset = Vector2(0, 2 if state != "pressed" else 1)
	style.expand_margin_left = 2
	style.expand_margin_top = 1
	style.expand_margin_right = 2
	style.expand_margin_bottom = 3
	style.content_margin_left = 14
	style.content_margin_top = 8
	style.content_margin_right = 14
	style.content_margin_bottom = 8
	style.set("skew", Vector2(0.06, 0.0))
	return style


static func _get_button_palette(variant: String, state: String) -> Dictionary:
	var palettes := {
		"gold": {
			"normal": {"fill": Color("e0aa1a"), "border": Color("ffd861"), "shadow": Color(0.35, 0.18, 0.02, 0.45)},
			"hover": {"fill": Color("f7c92a"), "border": Color("fff0a0"), "shadow": Color(0.48, 0.24, 0.04, 0.55)},
			"pressed": {"fill": Color("c68810"), "border": Color("ffcf59"), "shadow": Color(0.24, 0.12, 0.02, 0.35)},
			"disabled": {"fill": Color("6d5c2e"), "border": Color("99844a"), "shadow": Color(0, 0, 0, 0.18)},
		},
		"silver": {
			"normal": {"fill": Color("b5c1cd"), "border": Color("eef6ff"), "shadow": Color(0.08, 0.11, 0.16, 0.4)},
			"hover": {"fill": Color("cdd8e2"), "border": Color("ffffff"), "shadow": Color(0.1, 0.14, 0.2, 0.5)},
			"pressed": {"fill": Color("96a3af"), "border": Color("dbe4ee"), "shadow": Color(0.06, 0.08, 0.12, 0.28)},
			"disabled": {"fill": Color("59616a"), "border": Color("7a848e"), "shadow": Color(0, 0, 0, 0.18)},
		},
		"amber": {
			"normal": {"fill": Color("b86a17"), "border": Color("f0b35a"), "shadow": Color(0.26, 0.09, 0.01, 0.45)},
			"hover": {"fill": Color("cf7c1b"), "border": Color("ffd18f"), "shadow": Color(0.32, 0.12, 0.02, 0.52)},
			"pressed": {"fill": Color("99530f"), "border": Color("e4a64f"), "shadow": Color(0.19, 0.07, 0.01, 0.32)},
			"disabled": {"fill": Color("5f4122"), "border": Color("82603c"), "shadow": Color(0, 0, 0, 0.18)},
		},
	}
	var variant_palettes: Dictionary = palettes.get(variant, palettes["gold"])
	return variant_palettes.get(state, variant_palettes["normal"])


static func _get_button_font_color(variant: String, pressed: bool) -> Color:
	match variant:
		"silver":
			return Color("263140") if not pressed else Color("1a2230")
		_:
			return Color("fff9dc") if not pressed else Color("fff1bf")


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


static func build_inventory_panel(parent: VBoxContainer, inventory_groups: Array) -> Dictionary:
	if inventory_groups.is_empty():
		return {"item_labels": {}}

	var inventory_panel := PanelContainer.new()
	inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(inventory_panel)

	var inventory_margin := MarginContainer.new()
	inventory_margin.add_theme_constant_override("margin_left", 10)
	inventory_margin.add_theme_constant_override("margin_top", 8)
	inventory_margin.add_theme_constant_override("margin_right", 10)
	inventory_margin.add_theme_constant_override("margin_bottom", 8)
	inventory_panel.add_child(inventory_margin)

	var inventory_box := VBoxContainer.new()
	inventory_box.add_theme_constant_override("separation", 6)
	inventory_margin.add_child(inventory_box)

	var inventory_title := Label.new()
	inventory_title.text = "Inventory"
	inventory_title.add_theme_font_size_override("font_size", 18)
	inventory_box.add_child(inventory_title)

	var groups_row := HBoxContainer.new()
	groups_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	groups_row.add_theme_constant_override("separation", 10)
	inventory_box.add_child(groups_row)

	var item_labels := {}
	for group in inventory_groups:
		var group_panel := PanelContainer.new()
		group_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		groups_row.add_child(group_panel)

		var group_margin := MarginContainer.new()
		group_margin.add_theme_constant_override("margin_left", 8)
		group_margin.add_theme_constant_override("margin_top", 6)
		group_margin.add_theme_constant_override("margin_right", 8)
		group_margin.add_theme_constant_override("margin_bottom", 6)
		group_panel.add_child(group_margin)

		var group_box := VBoxContainer.new()
		group_box.add_theme_constant_override("separation", 4)
		group_margin.add_child(group_box)

		var group_label := Label.new()
		group_label.text = String(group["name"])
		group_label.add_theme_font_size_override("font_size", 15)
		group_box.add_child(group_label)

		for item_entry in group["items"]:
			var item_label := Label.new()
			item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			group_box.add_child(item_label)
			item_labels[String(item_entry["id"])] = item_label

	return {
		"item_labels": item_labels,
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
			_apply_fancy_button(queue_button, "gold")
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
	pause_queue_handler: Callable,
	remove_queue_handler: Callable,
	move_queue_up_handler: Callable,
	move_queue_down_handler: Callable,
	queue_item_selected_handler: Callable
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
	queue_list.select_mode = ItemList.SELECT_SINGLE
	if not queue_item_selected_handler.is_null():
		queue_list.item_selected.connect(queue_item_selected_handler)
	queue_box.add_child(queue_list)

	var queue_action_row := HBoxContainer.new()
	queue_action_row.add_theme_constant_override("separation", 6)
	queue_box.add_child(queue_action_row)

	var remove_queue_button := Button.new()
	remove_queue_button.text = "Remove selected"
	remove_queue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_fancy_button(remove_queue_button, "silver", true)
	remove_queue_button.pressed.connect(remove_queue_handler)
	queue_action_row.add_child(remove_queue_button)

	var move_up_queue_button := Button.new()
	move_up_queue_button.text = "Move up"
	move_up_queue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_fancy_button(move_up_queue_button, "silver", true)
	move_up_queue_button.pressed.connect(move_queue_up_handler)
	queue_action_row.add_child(move_up_queue_button)

	var move_down_queue_button := Button.new()
	move_down_queue_button.text = "Move down"
	move_down_queue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_fancy_button(move_down_queue_button, "silver", true)
	move_down_queue_button.pressed.connect(move_queue_down_handler)
	queue_action_row.add_child(move_down_queue_button)

	var clear_queue_button := Button.new()
	clear_queue_button.text = "Clear queued actions"
	_apply_fancy_button(clear_queue_button, "amber")
	clear_queue_button.pressed.connect(clear_queue_handler)
	queue_box.add_child(clear_queue_button)

	var pause_queue_button := Button.new()
	pause_queue_button.text = "Pause queue"
	_apply_fancy_button(pause_queue_button, "silver")
	pause_queue_button.pressed.connect(pause_queue_handler)
	queue_box.add_child(pause_queue_button)

	return {
		"current_action_label": current_action_label,
		"queue_summary_label": queue_summary_label,
		"queue_time_left_label": queue_time_left_label,
		"queue_list": queue_list,
		"remove_queue_button": remove_queue_button,
		"move_up_queue_button": move_up_queue_button,
		"move_down_queue_button": move_down_queue_button,
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
		_apply_fancy_button(button, "gold")
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
		_apply_fancy_button(button, "gold")
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
		_apply_fancy_button(toggle_button, "silver", true)
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
				_apply_fancy_button(fuel_button, "amber", true)
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
			_apply_fancy_button(button, "gold")
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
		_apply_fancy_button(button, "gold")
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
