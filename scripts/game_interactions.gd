extends RefCounted

const GameActions = preload("res://scripts/game_actions.gd")
const GameData = preload("res://scripts/game_data.gd")
const GamePresentation = preload("res://scripts/game_presentation.gd")
const GameRules = preload("res://scripts/game_rules.gd")


static func parse_resource_meta(meta: Variant) -> Dictionary:
	var meta_text := String(meta)
	if not meta_text.begins_with("resource:"):
		return {}

	var meta_parts := meta_text.split(":")
	if meta_parts.size() < 2:
		return {}

	var required_amount := 0
	if meta_parts.size() >= 3:
		required_amount = int(meta_parts[2])

	return {
		"resource_id": String(meta_parts[1]),
		"required_amount": required_amount,
	}


static func get_focus_target_for_resource(resource_id: String, data: Dictionary) -> Dictionary:
	var gather_resource_id := get_gather_resource_for_item(resource_id, data)
	if gather_resource_id == "":
		return {}

	return {
		"main_tab_title": "Gatherables",
		"gather_skill_id": GameData.get_resource_skill_id(gather_resource_id, data),
	}


static func build_linked_resource_queue_plan(
	item_id: String,
	required_amount: int,
	pipeline_state: Dictionary,
	free_queue_slots: int,
	data: Dictionary,
	rules_context: Dictionary
) -> Dictionary:
	var gather_resource_id := get_gather_resource_for_item(item_id, data)
	if gather_resource_id == "":
		return {
			"toast_message": "Can't auto-queue %s from a cost link." % GameData.get_resource_name(item_id, data),
		}

	var projected_amount := int(pipeline_state["inventory"].get(item_id, 0))
	var missing_amount := required_amount - projected_amount
	if missing_amount <= 0:
		return {
			"queue_amount": 0,
		}

	var gather_action := GameActions.make_gather_action(gather_resource_id)
	var block_reason := GameRules.get_action_block_reason_in_state(gather_action, pipeline_state, rules_context)
	if block_reason != "":
		return {
			"toast_message": GamePresentation.get_auto_queue_requirement_message(
				gather_resource_id,
				block_reason,
				data,
				GameRules.get_resource_unlock_requirement_text(gather_resource_id, rules_context)
			),
		}

	if free_queue_slots <= 0:
		return {
			"toast_message": "Queue is full.",
		}

	return {
		"action": gather_action,
		"queue_amount": missing_amount,
	}


static func get_gather_resource_for_item(item_id: String, data: Dictionary) -> String:
	if data["gatherables"].has(item_id):
		return item_id

	for resource_id in data["gatherable_order"]:
		if GameData.get_gather_output_item_id(resource_id, data) == item_id:
			return resource_id

	return ""
