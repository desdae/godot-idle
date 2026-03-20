extends RefCounted

static func refresh_queue_list(queue_list: ItemList, queue_entry_views: Array, selected_queue_index: int) -> int:
	queue_list.clear()
	for entry_view in queue_entry_views:
		var item_index := queue_list.item_count
		queue_list.add_item(String(entry_view["text"]))
		queue_list.set_item_tooltip(item_index, String(entry_view.get("tooltip", "")))
		queue_list.set_item_custom_fg_color(item_index, entry_view.get("color", Color(0.85, 0.85, 0.85, 1.0)))

	if queue_entry_views.is_empty():
		return -1

	var next_selected_index := selected_queue_index
	if next_selected_index >= queue_entry_views.size():
		next_selected_index = queue_entry_views.size() - 1
	if next_selected_index >= 0:
		queue_list.select(next_selected_index)

	return next_selected_index


static func refresh_queue_controls(
	clear_queue_button: Button,
	pause_queue_button: Button,
	remove_queue_button: Button,
	move_up_queue_button: Button,
	move_down_queue_button: Button,
	is_queue_paused: bool,
	current_action: Dictionary,
	action_queue: Array,
	selected_queue_index: int
) -> void:
	clear_queue_button.disabled = action_queue.is_empty()
	pause_queue_button.text = "Resume queue" if is_queue_paused else "Pause queue"
	pause_queue_button.disabled = current_action.is_empty() and action_queue.is_empty()
	remove_queue_button.disabled = selected_queue_index < 0 or selected_queue_index >= action_queue.size()
	move_up_queue_button.disabled = selected_queue_index <= 0 or selected_queue_index >= action_queue.size()
	move_down_queue_button.disabled = selected_queue_index < 0 or selected_queue_index >= action_queue.size() - 1


static func apply_resource_card(card: Dictionary, view: Dictionary) -> void:
	var stats_label: Label = card["stats_label"]
	var queue_button: Button = card["queue_button"]
	stats_label.text = view["stats_text"]
	queue_button.text = view["button_text"]
	queue_button.disabled = view["button_disabled"]
	queue_button.tooltip_text = view["button_tooltip"]


static func apply_station_card(station_card: Dictionary, station_view: Dictionary, fuel_views: Dictionary, show_fuel_full_label: bool) -> void:
	var station_status: Label = station_card["status_label"]
	var toggle_button: Button = station_card["toggle_button"]
	var fuel_buttons: Dictionary = station_card["fuel_buttons"]
	var fuel_state_label: Label = station_card["fuel_state_label"]
	var recipes_box: VBoxContainer = station_card["recipes_box"]

	toggle_button.text = station_view["toggle_text"]
	recipes_box.visible = station_view["recipes_visible"]
	station_status.text = station_view["status_text"]

	for fuel_item_id in fuel_buttons.keys():
		var fuel_button: Button = fuel_buttons[fuel_item_id]
		var fuel_view: Dictionary = fuel_views[fuel_item_id]
		fuel_button.text = fuel_view["button_text"]
		fuel_button.disabled = fuel_view["button_disabled"]
		fuel_button.tooltip_text = fuel_view["button_tooltip"]
		fuel_button.visible = not show_fuel_full_label

	if fuel_state_label != null:
		fuel_state_label.visible = show_fuel_full_label
		if show_fuel_full_label:
			fuel_state_label.text = "Fuel Full"


static func apply_item_summary(item_label: Label, text: String, tooltip: String) -> void:
	item_label.text = text
	item_label.tooltip_text = tooltip


static func apply_tool_card(card: Dictionary, view: Dictionary) -> void:
	var status_label: Label = card["status_label"]
	var detail_label: RichTextLabel = card["detail_label"]
	var button: Button = card["button"]
	status_label.text = view["status_text"]
	detail_label.text = view["detail_text"]
	button.text = view["button_text"]
	button.disabled = view["button_disabled"]
	button.tooltip_text = view["button_tooltip"]
	button.set_meta("base_text", view["button_text"])


static func apply_craftable_card(card: Dictionary, view: Dictionary) -> void:
	var status_label: Label = card["status_label"]
	var detail_label: RichTextLabel = card["detail_label"]
	var button: Button = card["button"]
	status_label.text = view["status_text"]
	detail_label.text = view["detail_text"]
	button.text = view["button_text"]
	button.disabled = view["button_disabled"]
	button.tooltip_text = view["button_tooltip"]
	button.set_meta("base_text", view["button_text"])


static func apply_recipe_card(card: Dictionary, view: Dictionary) -> void:
	var stats_label: RichTextLabel = card["stats_label"]
	var button: Button = card["button"]
	stats_label.text = view["summary_text"]
	button.text = view["button_text"]
	button.disabled = view["button_disabled"]
	button.tooltip_text = view["button_tooltip"]


static func apply_upgrade_card(card: Dictionary, view: Dictionary) -> void:
	var level_label: Label = card["level_label"]
	var detail_label: Label = card["detail_label"]
	var cost_label: RichTextLabel = card["cost_label"]
	var button: Button = card["button"]
	level_label.text = view["level_text"]
	detail_label.text = view["detail_text"]
	cost_label.text = view["cost_text"]
	button.disabled = view["button_disabled"]


static func apply_runtime_status(
	current_action_label: Label,
	queue_summary_label: Label,
	queue_time_left_label: Label,
	view: Dictionary
) -> void:
	current_action_label.text = view["current_action_text"]
	queue_summary_label.text = view["queue_summary_text"]
	queue_time_left_label.text = view["queue_time_left_text"]


static func apply_skill_row(row: Dictionary, view: Dictionary) -> void:
	var panel: PanelContainer = row["panel"]
	var skill_label: Label = row["skill_label"]
	var exp_label: Label = row["exp_label"]
	var exp_bar: ProgressBar = row["exp_bar"]
	skill_label.text = view["skill_label_text"]
	exp_label.text = view["exp_label_text"]
	exp_bar.value = view["exp_progress"]
	panel.add_theme_stylebox_override("panel", view["panel_style"])
	skill_label.add_theme_color_override("font_color", view["skill_label_color"])
	exp_label.add_theme_color_override("font_color", view["exp_label_color"])
