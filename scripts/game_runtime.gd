extends RefCounted

const GameActions = preload("res://scripts/game_actions.gd")
const GameRules = preload("res://scripts/game_rules.gd")


static func start_next_action(action_queue: Array, initial_state: Dictionary, rules: Dictionary) -> Dictionary:
	var remaining_queue: Array = action_queue.duplicate(true)
	if remaining_queue.is_empty():
		return {
			"started": false,
			"queue": remaining_queue,
			"state": initial_state.duplicate(true),
			"current_action": {},
		}

	var next_action: Dictionary = remaining_queue[0]
	var live_state := initial_state.duplicate(true)
	if GameRules.get_action_block_reason_in_state(next_action, live_state, rules) != "":
		return {
			"started": false,
			"queue": remaining_queue,
			"state": initial_state.duplicate(true),
			"current_action": {},
		}

	remaining_queue.pop_front()
	var duration := GameRules.get_action_duration_for_state(next_action, live_state, rules)
	GameRules.apply_action_start_to_state(live_state, next_action, rules)
	return {
		"started": true,
		"queue": remaining_queue,
		"state": live_state,
		"current_action": build_current_action(next_action, duration),
	}


static func complete_current_action(current_action: Dictionary, live_state: Dictionary, rules: Dictionary) -> Dictionary:
	var next_state := live_state.duplicate(true)
	GameRules.apply_action_completion_to_state(next_state, current_action, rules)
	return next_state


static func build_current_action(action: Dictionary, duration: float) -> Dictionary:
	var current_action := GameActions.copy_action(action)
	current_action["elapsed"] = 0.0
	current_action["duration"] = duration
	return current_action
