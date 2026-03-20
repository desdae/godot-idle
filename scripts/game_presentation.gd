extends RefCounted

const GameData = preload("res://scripts/game_data.gd")


static func get_queue_button_tooltip() -> String:
	return "Click: queue 1\nShift: queue 5\nCtrl: queue max"


static func get_upgrade_detail(
	upgrade_id: String,
	upgrade_levels: Dictionary,
	bag_capacity_per_upgrade: int,
	speed_upgrade_multiplier: float,
	queue_size_per_upgrade: int,
	base_queue_size: int
) -> String:
	match upgrade_id:
		"bag_space":
			var current_bonus := int(upgrade_levels[upgrade_id]) * bag_capacity_per_upgrade
			var next_bonus := (int(upgrade_levels[upgrade_id]) + 1) * bag_capacity_per_upgrade
			return "Bag bonus +%d -> +%d" % [current_bonus, next_bonus]
		"tooling":
			var current_multiplier := pow(speed_upgrade_multiplier, int(upgrade_levels[upgrade_id]))
			var next_multiplier := pow(speed_upgrade_multiplier, int(upgrade_levels[upgrade_id]) + 1)
			var current_reduction := int(round((1.0 - current_multiplier) * 100.0))
			var next_reduction := int(round((1.0 - next_multiplier) * 100.0))
			return "Gather speed +%d%% -> +%d%%" % [current_reduction, next_reduction]
		"queue_slots":
			var current_capacity := base_queue_size + int(upgrade_levels[upgrade_id]) * queue_size_per_upgrade
			var next_capacity := current_capacity + queue_size_per_upgrade
			return "Queue slots %d -> %d" % [current_capacity, next_capacity]
		_:
			return ""


static func get_auto_queue_requirement_message(
	resource_id: String,
	block_reason: String,
	data: Dictionary,
	unlock_requirement_text: String
) -> String:
	var item_name := GameData.get_resource_name(GameData.get_gather_output_item_id(resource_id, data), data)
	if block_reason == "Queue full":
		return "Queue is full."
	if block_reason == "Full at end of queue":
		return "%s storage will be full at the end of the queue." % item_name
	if block_reason == unlock_requirement_text:
		return block_reason
	if block_reason.begins_with("Need "):
		return "%s requires %s." % [item_name, block_reason.trim_prefix("Need ")]

	return "Can't auto-queue %s: %s" % [item_name, block_reason]


static func format_cost(cost: Dictionary, data: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in GameData.get_inventory_item_order(data):
		if not cost.has(resource_id):
			continue

		parts.append("%d %s" % [int(cost[resource_id]), GameData.get_resource_name(resource_id, data)])

	if parts.is_empty():
		return "Free"

	return ", ".join(parts)


static func format_recipe_detail_rich_text(duration: float, xp: int, cost: Dictionary, use_text: String, data: Dictionary, inventory: Dictionary) -> String:
	var detail := "%.1fs craft | +%d XP | Cost: %s" % [
		duration,
		xp,
		format_cost_markup(cost, data, inventory),
	]
	if use_text != "":
		detail += " | %s" % use_text

	return detail


static func format_cost_rich_text(cost: Dictionary, data: Dictionary, inventory: Dictionary) -> String:
	if cost.is_empty():
		return "Cost: Free"

	return "Cost: %s" % format_cost_markup(cost, data, inventory)


static func format_cost_markup(cost: Dictionary, data: Dictionary, inventory: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in GameData.get_inventory_item_order(data):
		if not cost.has(resource_id):
			continue

		var amount := int(cost[resource_id])
		parts.append(format_resource_cost_part(resource_id, amount, data, inventory))

	if parts.is_empty():
		return "Free"

	return ", ".join(parts)


static func format_resource_cost_part(resource_id: String, amount: int, data: Dictionary, inventory: Dictionary) -> String:
	var part := "%d %s" % [amount, GameData.get_resource_name(resource_id, data)]
	if int(inventory.get(resource_id, 0)) < amount:
		part = "[url=resource:%s:%d][color=#ff7070]%s[/color][/url]" % [resource_id, amount, part]

	return part


static func format_seconds(seconds: float) -> String:
	var total_seconds := maxf(0.0, seconds)
	var minutes := int(total_seconds / 60.0)
	var remainder := total_seconds - float(minutes * 60)

	if minutes > 0:
		return "%dm %.1fs" % [minutes, remainder]

	return "%.1fs" % total_seconds
