extends RefCounted

const GameRules = preload("res://scripts/game_rules.gd")


static func get_free_queue_slots(queue_size: int, queue_capacity: int) -> int:
	return maxi(0, queue_capacity - queue_size)


static func get_queue_block_reason_for_action(
	action_queue: Array,
	queue_capacity: int,
	action: Dictionary,
	current_action: Dictionary,
	initial_state: Dictionary,
	rules: Dictionary
) -> String:
	if action_queue.size() >= queue_capacity:
		return "Queue full"

	var pipeline_state := GameRules.build_pipeline_end_state(initial_state, current_action, action_queue, rules)
	return GameRules.get_action_block_reason_in_state(action, pipeline_state, rules)


static func queue_action_count(
	action_queue: Array,
	action: Dictionary,
	amount: int,
	queue_capacity: int,
	current_action: Dictionary,
	initial_state: Dictionary,
	rules: Dictionary
) -> bool:
	if amount <= 0:
		return false

	var queue_count := mini(amount, get_free_queue_slots(action_queue.size(), queue_capacity))
	if queue_count <= 0:
		return false

	var pipeline_state := GameRules.build_pipeline_end_state(initial_state, current_action, action_queue, rules)
	var queued_any := false

	for _index in range(queue_count):
		var simulation_result := GameRules.simulate_action_in_state(pipeline_state, action, rules)
		if not simulation_result["ran"]:
			break

		action_queue.append(action.duplicate(true))
		queued_any = true

	return queued_any


static func estimate_queue_time_left(
	current_action: Dictionary,
	action_queue: Array,
	initial_state: Dictionary,
	current_action_time_left: float,
	rules: Dictionary
) -> float:
	var total_time := 0.0
	var state := initial_state.duplicate(true)

	if not current_action.is_empty():
		total_time += current_action_time_left
		GameRules.apply_action_completion_to_state(state, current_action, rules)

	for queued_action in action_queue:
		var result := GameRules.simulate_action_in_state(state, queued_action, rules)
		if result["ran"]:
			total_time += result["duration"]

	return total_time
