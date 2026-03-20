extends RefCounted

const GameData = preload("res://scripts/game_data.gd")


static func get_capacity(resource_id: String, data: Dictionary, upgrade_levels: Dictionary, bag_capacity_per_upgrade: int) -> int:
	if not data["gatherables"].has(resource_id):
		return 999999

	var gatherable: Dictionary = data["gatherables"][resource_id]
	return int(gatherable["base_capacity"]) + int(upgrade_levels["bag_space"]) * bag_capacity_per_upgrade


static func get_queue_capacity(upgrade_levels: Dictionary, base_queue_size: int, queue_size_per_upgrade: int) -> int:
	return base_queue_size + int(upgrade_levels["queue_slots"]) * queue_size_per_upgrade


static func build_cost(raw_cost: Dictionary, inventory_item_order: Array) -> Dictionary:
	var result := {}
	for resource_id in inventory_item_order:
		if not raw_cost.has(resource_id):
			continue

		var amount := int(raw_cost[resource_id])
		if amount > 0:
			result[resource_id] = amount

	return result


static func get_upgrade_cost(upgrade_id: String, upgrade_levels: Dictionary, upgrades: Dictionary, inventory_item_order: Array) -> Dictionary:
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

	return build_cost(raw_cost, inventory_item_order)


static func get_craftable_upgrade_cost(craftable_id: String, from_level: int, data: Dictionary, inventory_item_order: Array) -> Dictionary:
	var multiplier := pow(GameData.get_craftable_upgrade_cost_multiplier(craftable_id, data), from_level)
	var base_cost := GameData.get_craftable_craft_cost(craftable_id, data)
	var scaled_cost := {}
	for resource_id in base_cost.keys():
		scaled_cost[resource_id] = int(ceil(float(base_cost[resource_id]) * multiplier))

	return build_cost(scaled_cost, inventory_item_order)


static func get_craftable_speed_multiplier(craftable_id: String, upgrade_level: int, data: Dictionary) -> float:
	return pow(GameData.get_craftable_station_speed_multiplier(craftable_id, data), upgrade_level)


static func spend_resources(inventory: Dictionary, cost: Dictionary) -> void:
	for resource_id in cost.keys():
		inventory[resource_id] -= int(cost[resource_id])
