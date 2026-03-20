extends RefCounted

const GameActions = preload("res://scripts/game_actions.gd")


static func refresh_queue_list(queue_list: ItemList, current_action: Dictionary, action_queue: Array, data: Dictionary) -> void:
	queue_list.clear()
	if not current_action.is_empty():
		queue_list.add_item("Now: %s" % GameActions.get_action_queue_label(current_action, data))

	for index in range(action_queue.size()):
		var queued_action: Dictionary = action_queue[index]
		queue_list.add_item("%d. %s" % [index + 1, GameActions.get_action_queue_label(queued_action, data)])


static func refresh_queue_controls(
	clear_queue_button: Button,
	pause_queue_button: Button,
	is_queue_paused: bool,
	current_action: Dictionary,
	action_queue: Array
) -> void:
	clear_queue_button.disabled = action_queue.is_empty()
	pause_queue_button.text = "Resume queue" if is_queue_paused else "Pause queue"
	pause_queue_button.disabled = current_action.is_empty() and action_queue.is_empty()


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


static func apply_craftable_card(card: Dictionary, view: Dictionary) -> void:
	var status_label: Label = card["status_label"]
	var detail_label: RichTextLabel = card["detail_label"]
	var button: Button = card["button"]
	status_label.text = view["status_text"]
	detail_label.text = view["detail_text"]
	button.text = view["button_text"]
	button.disabled = view["button_disabled"]


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
