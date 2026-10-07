class_name BattleRadialMenu
extends Control

## 圆盘式行动菜单。只负责显示条目并回传稳定 ID，不读取任何职业技能数据。

signal entry_selected(entry_id: StringName)
signal back_requested

const MENU_SIZE := Vector2(288.0, 288.0)
const CENTER := MENU_SIZE * 0.5
const DISC_RADIUS := 114.0
const BUTTON_RADIUS := 92.0
const BUTTON_SIZE := Vector2(96.0, 42.0)

const DISC_COLOR := Color(0.025, 0.045, 0.07, 0.9)
const RING_COLOR := Color(0.25, 0.65, 0.85, 0.68)
const INNER_RING_COLOR := Color(0.62, 0.78, 0.9, 0.42)
const TEXT_COLOR := Color(0.9, 0.95, 0.98)
const MUTED_TEXT_COLOR := Color(0.55, 0.61, 0.68)

var _back_button: Button
var _entry_buttons: Array[Button] = []


func _ready() -> void:
	custom_minimum_size = MENU_SIZE
	size = MENU_SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_center_controls()
	queue_redraw()


func configure(
	entries: Array[Dictionary],
	allow_back: bool
) -> void:
	_clear_entry_buttons()
	_back_button.visible = allow_back
	_layout_entries(entries)
	queue_redraw()


func set_position_clamped(desired_position: Vector2, viewport_size: Vector2) -> void:
	var margin := 12.0
	var safe_width := maxf(viewport_size.x - size.x - margin, margin)
	var safe_height := maxf(viewport_size.y - size.y - margin, margin)
	position = Vector2(
		clampf(desired_position.x, margin, safe_width),
		clampf(desired_position.y, margin, safe_height)
	)


func _draw() -> void:
	draw_circle(CENTER, DISC_RADIUS, DISC_COLOR)
	draw_arc(CENTER, DISC_RADIUS, 0.0, TAU, 80, RING_COLOR, 2.2, true)
	draw_arc(CENTER, 62.0, 0.0, TAU, 64, INNER_RING_COLOR, 1.2, true)

	for index in range(16):
		var angle := TAU * float(index) / 16.0
		var inner := CENTER + Vector2.from_angle(angle) * 108.0
		var outer := CENTER + Vector2.from_angle(angle) * DISC_RADIUS
		draw_line(inner, outer, RING_COLOR * Color(1.0, 1.0, 1.0, 0.55), 1.0, true)


func _build_center_controls() -> void:
	_back_button = Button.new()
	_back_button.name = "BackButton"
	_back_button.text = "返回"
	_back_button.position = CENTER - Vector2(39.0, 39.0)
	_back_button.size = Vector2(78.0, 78.0)
	_back_button.focus_mode = Control.FOCUS_NONE
	_back_button.add_theme_font_size_override("font_size", 16)
	_back_button.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.14, 0.2, 0.96)))
	_back_button.add_theme_stylebox_override("hover", _button_style(Color(0.12, 0.24, 0.33, 0.98)))
	_back_button.add_theme_stylebox_override("pressed", _button_style(Color(0.2, 0.42, 0.55, 1.0)))
	_back_button.add_theme_color_override("font_color", TEXT_COLOR)
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	_back_button.visible = false
	add_child(_back_button)


func _layout_entries(entries: Array[Dictionary]) -> void:
	var count := entries.size()
	if count == 0:
		return

	var start_angle := -PI * 0.5
	if count % 2 == 0:
		start_angle -= PI / float(count)

	for index in range(count):
		var angle := start_angle + TAU * float(index) / float(count)
		var center_position := CENTER + Vector2.from_angle(angle) * BUTTON_RADIUS
		var button := _create_entry_button(entries[index])
		button.position = center_position - BUTTON_SIZE * 0.5
		add_child(button)
		_entry_buttons.append(button)


func _create_entry_button(entry: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.text = str(entry.get("text", ""))
	button.disabled = not bool(entry.get("available", true))
	button.tooltip_text = str(entry.get("tooltip", ""))
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.055, 0.09, 0.13, 0.97)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.1, 0.22, 0.3, 0.98)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.18, 0.4, 0.52, 1.0)))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.055, 0.065, 0.08, 0.88)))
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", MUTED_TEXT_COLOR)

	var detail := str(entry.get("detail", ""))
	if not detail.is_empty():
		button.text += "\n" + detail
		button.add_theme_font_size_override("font_size", 12)

	var entry_id: StringName = entry.get("id", &"")
	button.pressed.connect(func() -> void: entry_selected.emit(entry_id))
	return button


func _clear_entry_buttons() -> void:
	for button in _entry_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_entry_buttons.clear()


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.38, 0.7, 0.86, 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style
