class_name SceneInteractable
extends Control

## 所有 2D 场景交互物的父类。NPC、调查物、传送门等具体类型继承本类。
## 场景内没有可操控角色，玩家通过鼠标悬停与点击与这些对象互动。

signal activated(interactable: SceneInteractable)
signal hover_changed(interactable: SceneInteractable, hovered: bool)

const DEFAULT_NAME := "可互动对象"
const DEFAULT_PROMPT := "互动"

@export var interaction_id: StringName = &""
@export var display_name: String = DEFAULT_NAME
@export var interaction_prompt: String = DEFAULT_PROMPT
@export var enabled: bool = true

## 使用锚点定位，窗口尺寸变化时对象会保持在画面中的相对位置。
## 取值为 0~1 的归一化坐标。
@export var anchor_position: Vector2 = Vector2(0.5, 0.5)
## 可点击区域的尺寸；视觉元素可以小于或大于该区域。
@export var hit_size: Vector2 = Vector2(150.0, 210.0)
@export var show_name_label: bool = true
@export var name_label_offset: Vector2 = Vector2(0.0, 6.0)

var _scene: Node = null
var _visual_root: Control
var _hover_frame: Panel
var _name_label: Label
var _hovered := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_to_group(&"scene_interactable")
	_apply_layout()
	_configure_interactable()
	if interaction_id == &"":
		interaction_id = StringName(name.to_snake_case())
	_build_visual_root()
	_build_visual()
	_build_overlay()
	_refresh_name_label()
	_register_with_scene()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_on_resized)


func _exit_tree() -> void:
	if _scene != null and is_instance_valid(_scene):
		if _scene.has_method("unregister_interactable"):
			_scene.unregister_interactable(self)


func _gui_input(event: InputEvent) -> void:
	if not can_interact():
		return
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		accept_event()
		activate()


func can_interact(_context: Variant = null) -> bool:
	return enabled and visible and is_inside_tree()


func activate() -> void:
	if not can_interact():
		return
	interact(_scene)
	activated.emit(self)


func get_interaction_prompt() -> String:
	return interaction_prompt


func set_interaction_enabled(value: bool) -> void:
	enabled = value
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
	)
	modulate = Color.WHITE if value else Color(0.62, 0.66, 0.7, 0.82)
	if not value:
		_set_hovered(false)


func get_scene() -> Node:
	return _scene


## 具体互动物覆写本方法实现行为。scene_ref 为当前 RPGScene。
func interact(_scene_ref: Node) -> void:
	pass


## 对话选项会先交给发起互动的对象处理；返回 false 时由场景层继续派发。
func handle_dialogue_action(
	_action_id: StringName,
	_payload: Variant
) -> bool:
	return false


func _configure_interactable() -> void:
	pass


## 子类向 _visual_root 添加 2D 视觉节点，父类负责点击、高亮和名称。
func _build_visual() -> void:
	pass


func get_accent_color() -> Color:
	return Color(0.35, 0.78, 0.92)


func get_visual_root() -> Control:
	return _visual_root


## 创建圆角面板的通用辅助方法，供 NPC、传送门、调查物复用。
func make_rounded_panel(
	rect: Rect2,
	color: Color,
	corner_radius: int,
	border_color: Color = Color(0.0, 0.0, 0.0, 0.0),
	border_width: int = 0
) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(corner_radius)
	if border_width > 0:
		style.border_color = border_color
		style.set_border_width_all(border_width)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func make_glow_texture(
	color: Color,
	texture_size: Vector2i = Vector2i(128, 128)
) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(color.r, color.g, color.b, 1.0),
		Color(color.r, color.g, color.b, 0.45),
		Color(color.r, color.g, color.b, 0.0),
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.38, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = texture_size.x
	texture.height = texture_size.y
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


## 生成圆形多边形的点集，供 Polygon2D 使用。
func make_circle_polygon(
	center: Vector2,
	radius: float,
	segments: int = 36
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(segments, 3)):
		var angle := TAU * float(index) / float(maxi(segments, 3))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## 生成椭圆多边形的点集，供 Polygon2D 使用。
func make_ellipse_polygon(
	center: Vector2,
	radius: Vector2,
	segments: int = 36
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(maxi(segments, 3)):
		var angle := TAU * float(index) / float(maxi(segments, 3))
		points.append(center + Vector2(
			cos(angle) * radius.x,
			sin(angle) * radius.y
		))
	return points


func make_polygon2d(
	node_name: String,
	points: PackedVector2Array,
	color: Color
) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.polygon = points
	polygon.color = color
	polygon.antialiased = true
	return polygon


func _apply_layout() -> void:
	anchor_left = anchor_position.x
	anchor_right = anchor_position.x
	anchor_top = anchor_position.y
	anchor_bottom = anchor_position.y
	offset_left = -hit_size.x * 0.5
	offset_right = hit_size.x * 0.5
	offset_top = -hit_size.y * 0.5
	offset_bottom = hit_size.y * 0.5


func _build_visual_root() -> void:
	_visual_root = Control.new()
	_visual_root.name = "VisualRoot"
	_visual_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_visual_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_visual_root)


## 悬停高亮与名称标签在子类视觉之后创建，确保始终显示在最上层。
func _build_overlay() -> void:
	_hover_frame = Panel.new()
	_hover_frame.name = "HoverFrame"
	_hover_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hover_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_frame.z_index = 20
	var accent := get_accent_color()
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(accent.r, accent.g, accent.b, 0.07)
	frame_style.border_color = Color(accent.r, accent.g, accent.b, 0.9)
	frame_style.set_border_width_all(2)
	frame_style.set_corner_radius_all(12)
	_hover_frame.add_theme_stylebox_override("panel", frame_style)
	_hover_frame.visible = false
	_visual_root.add_child(_hover_frame)

	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.z_index = 21
	_name_label.anchor_left = 0.5
	_name_label.anchor_right = 0.5
	_name_label.anchor_top = 1.0
	_name_label.anchor_bottom = 1.0
	_name_label.offset_left = -130.0 + name_label_offset.x
	_name_label.offset_right = 130.0 + name_label_offset.x
	_name_label.offset_top = name_label_offset.y
	_name_label.offset_bottom = name_label_offset.y + 30.0
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_font_size_override("font_size", 15)
	_name_label.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0))
	_name_label.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.9)
	)
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 2)
	_visual_root.add_child(_name_label)


func _refresh_name_label() -> void:
	if _name_label == null:
		return
	_name_label.text = display_name
	_name_label.visible = show_name_label and not display_name.is_empty()


func _register_with_scene() -> void:
	var current := get_parent()
	while current != null:
		if current.has_method("register_interactable"):
			_scene = current
			current.register_interactable(self)
			return
		current = current.get_parent()


func _on_mouse_entered() -> void:
	_set_hovered(can_interact())


func _on_mouse_exited() -> void:
	_set_hovered(false)


func _on_resized() -> void:
	if _visual_root != null:
		_visual_root.pivot_offset = size * 0.5


func _set_hovered(value: bool) -> void:
	var next_value := value and can_interact()
	if _hovered == next_value:
		return
	_hovered = next_value
	if _hover_frame != null:
		_hover_frame.visible = _hovered
	if _visual_root != null:
		_visual_root.pivot_offset = size * 0.5
		_visual_root.scale = Vector2.ONE * (1.045 if _hovered else 1.0)
	hover_changed.emit(self, _hovered)
	if _scene != null and _scene.has_method("_on_interactable_hovered"):
		_scene._on_interactable_hovered(self, _hovered)
