class_name DialogueData
extends RefCounted

## 通用对话数据。场景只关心节点和选项，不绑定具体 NPC 或剧情。

var speaker_name: String = ""
var start_node: StringName = &"start"
var nodes: Dictionary = {}


func _init(p_speaker_name: String = "") -> void:
	speaker_name = p_speaker_name


func add_line(
	node_id: StringName,
	text: String,
	next_node: StringName = &"",
	speaker: String = ""
) -> DialogueData:
	var resolved_speaker := speaker if not speaker.is_empty() else speaker_name
	nodes[node_id] = {
		"speaker": resolved_speaker,
		"text": text,
		"next": next_node,
		"choices": [],
	}
	return self


func add_choice_node(
	node_id: StringName,
	text: String,
	choices: Array,
	speaker: String = ""
) -> DialogueData:
	var resolved_speaker := speaker if not speaker.is_empty() else speaker_name
	nodes[node_id] = {
		"speaker": resolved_speaker,
		"text": text,
		"next": &"",
		"choices": choices,
	}
	return self


func get_node_data(node_id: StringName) -> Dictionary:
	var value: Variant = nodes.get(node_id, {})
	return value if value is Dictionary else {}


func is_empty() -> bool:
	return nodes.is_empty()


static func choice(
	text: String,
	next_node: StringName = &"",
	action_id: StringName = &"",
	payload: Variant = null
) -> Dictionary:
	return {
		"text": text,
		"next": next_node,
		"action_id": action_id,
		"payload": payload,
	}


static func single(speaker: String, text: String) -> DialogueData:
	return DialogueData.new(speaker).add_line(&"start", text)
