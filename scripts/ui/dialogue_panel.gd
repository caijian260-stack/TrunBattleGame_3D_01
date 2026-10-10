class_name DialoguePanel
extends CanvasLayer

## 通用对话 UI：只读取 DialogueData 并回传选项动作，不判断具体 NPC 或剧情。

signal choice_activated(action_id: StringName, payload: Variant)
signal dialogue_finished

var current_data: DialogueData = null
var current_node_id: StringName = &""

var _speaker_label: Label
var _text_label: Label
var _choice_container: VBoxContainer
var _continue_button: Button


func _ready() -> void:
	layer = 30
	_build_ui()
	visible = false


func open_dialogue(data: DialogueData, start_node: StringName = &"") -> bool:
	if data == null or data.is_empty():
		return false
	current_data = data
	var resolved_start := start_node
	if resolved_start == &"":
		resolved_start = data.start_node
	visible = true
	_show_node(resolved_start)
	return true


func close_dialogue() -> void:
	if not visible and current_data == null:
		return
	visible = false
	current_data = null
	current_node_id = &""
	dialogue_finished.emit()


func select_choice(choice_index: int) -> void:
	_on_choice_pressed(choice_index)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		close_dialogue()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var root := Control.new()
	root.name = "DialogueRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var shade := ColorRect.new()
	shade.name = "DialogueShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.16)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -610.0
	panel.offset_top = -300.0
	panel.offset_right = 610.0
	panel.offset_bottom = -28.0
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color(0.34, 0.72, 0.86))
	)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var top_line := ColorRect.new()
	top_line.custom_minimum_size = Vector2(0.0, 3.0)
	top_line.color = Color(0.45, 0.9, 1.0, 0.88)
	content.add_child(top_line)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 21)
	_speaker_label.add_theme_color_override("font_color", Color(0.62, 0.92, 1.0))
	content.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text_label.add_theme_font_size_override("font_size", 18)
	_text_label.add_theme_color_override("font_color", Color(0.92, 0.96, 0.98))
	content.add_child(_text_label)

	_choice_container = VBoxContainer.new()
	_choice_container.name = "DialogueChoices"
	_choice_container.add_theme_constant_override("separation", 7)
	content.add_child(_choice_container)

	_continue_button = Button.new()
	_continue_button.name = "ContinueButton"
	_continue_button.text = "继续"
	_continue_button.custom_minimum_size = Vector2(0.0, 40.0)
	_continue_button.pressed.connect(_on_continue_pressed)
	_style_button(_continue_button, Color(0.2, 0.58, 0.76))
	content.add_child(_continue_button)


func _show_node(node_id: StringName) -> void:
	if current_data == null:
		close_dialogue()
		return
	var node_data := current_data.get_node_data(node_id)
	if node_data.is_empty():
		close_dialogue()
		return

	current_node_id = node_id
	_speaker_label.text = str(node_data.get("speaker", current_data.speaker_name))
	_text_label.text = str(node_data.get("text", ""))
	_clear_choices()

	var choices: Array = node_data.get("choices", [])
	if choices.is_empty():
		var next_node: StringName = node_data.get("next", &"")
		_continue_button.text = "结束" if next_node == &"" else "继续"
		_continue_button.visible = true
		_continue_button.grab_focus()
		return

	_continue_button.visible = false
	for index in range(choices.size()):
		var choice_data: Variant = choices[index]
		if not choice_data is Dictionary:
			continue
		var choice: Dictionary = choice_data
		var button := Button.new()
		button.text = "%d. %s" % [index + 1, str(choice.get("text", "继续"))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0.0, 39.0)
		button.set_meta("choice_index", index)
		button.pressed.connect(_on_choice_pressed.bind(index))
		_style_button(button, Color(0.28, 0.52, 0.64))
		_choice_container.add_child(button)

	var first_button := _choice_container.get_child(0)
	if first_button is Button:
		first_button.grab_focus()


func _on_continue_pressed() -> void:
	if current_data == null:
		close_dialogue()
		return
	var node_data := current_data.get_node_data(current_node_id)
	var next_node: StringName = node_data.get("next", &"")
	if next_node == &"":
		close_dialogue()
		return
	_show_node(next_node)


func _on_choice_pressed(choice_index: int) -> void:
	if current_data == null:
		return
	var node_data := current_data.get_node_data(current_node_id)
	var choices: Array = node_data.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return
	var choice_data: Variant = choices[choice_index]
	if not choice_data is Dictionary:
		return
	var choice: Dictionary = choice_data

	var action_id: StringName = choice.get("action_id", &"")
	var payload: Variant = choice.get("payload", null)
	var next_node: StringName = choice.get("next", &"")
	if action_id != &"":
		choice_activated.emit(action_id, payload)

	if current_data == null:
		return
	if next_node != &"":
		_show_node(next_node)
	else:
		close_dialogue()


func _clear_choices() -> void:
	for child in _choice_container.get_children():
		_choice_container.remove_child(child)
		child.queue_free()


func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.032, 0.052, 0.96)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.84)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 10
	return style


func _style_button(button: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.58)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.62)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = accent.darkened(0.36)
	hover.border_color = accent.lightened(0.18)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = accent.darkened(0.2)
	pressed.border_color = Color.WHITE

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color(0.92, 0.97, 1.0))
