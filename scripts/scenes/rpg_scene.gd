class_name RPGScene
extends BaseGameScene

## 固定视角 2D RPG 场景父类。
##
## 场景是固定视角的 2D 背景画面：玩家不能移动或转动视角，只能通过鼠标
## 点击画面中的 NPC、调查物或传送门进行互动。具体地图继承本类，覆写
## _configure_scene()、_draw_scene_background() 与 _build_concrete_scene()。
##
## 与玩法无关的公共流程（场景切换、出生点、提示信息）由 BaseGameScene 提供。

signal interactable_registered(interactable: SceneInteractable)
signal interactable_unregistered(interactable: SceneInteractable)
signal dialogue_action_requested(
	scene: RPGScene,
	source: SceneInteractable,
	action_id: StringName,
	payload: Variant
)

const DialoguePanelScript := preload("res://scripts/ui/dialogue_panel.gd")

@export_group("背景")
@export var background_enabled: bool = true
@export var background_texture: Texture2D
@export var background_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var background_top_color: Color = Color(0.07, 0.10, 0.14)
@export var background_bottom_color: Color = Color(0.02, 0.03, 0.05)

var interactables: Array[SceneInteractable] = []
var spawn_points: Dictionary = {}
var dialogue_panel: DialoguePanel = null
var active_interactable: SceneInteractable = null

var _background_cache: GradientTexture2D = null
var _hovered_interactable: SceneInteractable = null
var _hud_root: Control = null
var _title_label: Label = null
var _prompt_label: Label = null
var _prompt_panel: PanelContainer = null


# ---------------------------------------------------------------------------
# 子类钩子
# ---------------------------------------------------------------------------


## 声明场景 ID、显示名、背景氛围与出生点。子类覆写并调用父类注册 API。
func _configure_scene() -> void:
	super()


## 用相对坐标绘制 2D 背景装饰，位于背景贴图之上、互动物之下。
func _draw_scene_background() -> void:
	pass


## 布置本场景的贴图、模型与互动物。默认不放置任何内容。
func _build_concrete_scene() -> void:
	pass


# ---------------------------------------------------------------------------
# 绘制
# ---------------------------------------------------------------------------


func _draw() -> void:
	if background_enabled:
		_draw_background()
	_draw_scene_background()


func _draw_background() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if background_texture != null:
		draw_texture_rect(background_texture, rect, false, background_modulate)
		return
	draw_texture_rect(_get_background_texture(), rect, false, background_modulate)


func _get_background_texture() -> GradientTexture2D:
	if _background_cache == null:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([
			background_top_color,
			background_bottom_color,
		])
		gradient.offsets = PackedFloat32Array([0.0, 1.0])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 64
		texture.height = 256
		texture.fill_from = Vector2(0.0, 0.0)
		texture.fill_to = Vector2(0.0, 1.0)
		_background_cache = texture
	return _background_cache


## 刷新程序化背景；更改背景颜色后调用即可。
func refresh_background() -> void:
	_background_cache = null
	queue_redraw()


func _on_scene_resized() -> void:
	super()
	queue_redraw()


# 相对坐标绘制辅助：所有输入使用 0~1 的归一化坐标。


func draw_relative_rect(rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(rect.position * size, rect.size * size), color, true)


func draw_relative_line(
	from: Vector2,
	to: Vector2,
	color: Color,
	width: float = 2.0
) -> void:
	draw_line(from * size, to * size, color, width, true)


func draw_relative_circle(
	center: Vector2,
	radius: float,
	color: Color,
	segments: int = 48
) -> void:
	draw_colored_polygon(
		make_relative_ellipse(center, Vector2(radius, radius), segments),
		color
	)


func draw_relative_ellipse(
	center: Vector2,
	radius: Vector2,
	color: Color,
	segments: int = 48
) -> void:
	draw_colored_polygon(
		make_relative_ellipse(center, radius, segments),
		color
	)


func make_relative_ellipse(
	center: Vector2,
	radius: Vector2,
	segments: int = 48
) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(center * size + Vector2(
			cos(angle) * radius.x * size.x,
			sin(angle) * radius.y * size.y
		))
	return points


func draw_relative_polygon(points: PackedVector2Array, color: Color) -> void:
	var scaled := PackedVector2Array()
	for point in points:
		scaled.append(point * size)
	if scaled.size() >= 3:
		draw_colored_polygon(scaled, color)


# ---------------------------------------------------------------------------
# 场景内容构建 API
# ---------------------------------------------------------------------------


## 放置一张按相对矩形铺开的 2D 贴图（壁画、告示、场景背景层等）。
func add_scene_texture(
	node_name: String,
	texture: Texture2D,
	relative_rect: Rect2,
	modulate_color: Color = Color(1.0, 1.0, 1.0, 1.0)
) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = texture
	rect.modulate = modulate_color
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_relative_rect(rect, relative_rect)
	add_child(rect)
	return rect


## 放置任意 2D 建模节点（Polygon2D、Sprite2D、Node2D 组合等）。
## 节点原点会被放到相对锚点上。
func place_scene_node(
	node_name: String,
	node: Node,
	anchor_position: Vector2,
	local_offset: Vector2 = Vector2.ZERO
) -> Node:
	var anchor := Control.new()
	anchor.name = "%sAnchor" % node_name
	anchor.anchor_left = anchor_position.x
	anchor.anchor_right = anchor_position.x
	anchor.anchor_top = anchor_position.y
	anchor.anchor_bottom = anchor_position.y
	anchor.offset_left = local_offset.x
	anchor.offset_right = local_offset.x
	anchor.offset_top = local_offset.y
	anchor.offset_bottom = local_offset.y
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(node)
	add_child(anchor)
	return node


## 放置一个按相对矩形定位的 Control 节点。
func place_scene_control(
	control: Control,
	relative_rect: Rect2
) -> Control:
	_apply_relative_rect(control, relative_rect)
	add_child(control)
	return control


func _apply_relative_rect(control: Control, relative_rect: Rect2) -> void:
	control.anchor_left = relative_rect.position.x
	control.anchor_top = relative_rect.position.y
	control.anchor_right = relative_rect.position.x + relative_rect.size.x
	control.anchor_bottom = relative_rect.position.y + relative_rect.size.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


# ---------------------------------------------------------------------------
# 互动物注册
# ---------------------------------------------------------------------------


func register_interactable(interactable: SceneInteractable) -> void:
	if interactable == null or interactables.has(interactable):
		return
	interactables.append(interactable)
	interactable_registered.emit(interactable)


func unregister_interactable(interactable: SceneInteractable) -> void:
	var index := interactables.find(interactable)
	if index < 0:
		return
	interactables.remove_at(index)
	if _hovered_interactable == interactable:
		_hovered_interactable = null
	interactable_unregistered.emit(interactable)


func get_interactable(interaction_id: StringName) -> SceneInteractable:
	for interactable in interactables:
		if interactable != null and interactable.interaction_id == interaction_id:
			return interactable
	return null


func _on_interactable_hovered(
	interactable: SceneInteractable,
	hovered: bool
) -> void:
	if hovered:
		_hovered_interactable = interactable
	elif _hovered_interactable == interactable:
		_hovered_interactable = null
	_refresh_prompt()


func _refresh_prompt() -> void:
	if _prompt_panel == null or _prompt_label == null:
		return
	if _hovered_interactable == null:
		_prompt_panel.visible = false
		return
	var prompt := _hovered_interactable.get_interaction_prompt()
	_prompt_label.text = "点击%s  %s" % [
		_hovered_interactable.display_name,
		prompt,
	]
	_prompt_panel.visible = true


# ---------------------------------------------------------------------------
# 出生点
# ---------------------------------------------------------------------------


func register_spawn_point(
	spawn_id: StringName,
	position: Vector2,
	yaw_degrees: float = 0.0
) -> void:
	spawn_points[spawn_id] = {
		"position": position,
		"yaw": yaw_degrees,
	}


func get_spawn_position(spawn_id: StringName) -> Vector2:
	var entry: Variant = spawn_points.get(spawn_id, null)
	if entry is Dictionary:
		return entry.get("position", Vector2.ZERO)
	return Vector2.ZERO


# ---------------------------------------------------------------------------
# 对话
# ---------------------------------------------------------------------------


func _setup_dialogue() -> void:
	dialogue_panel = DialoguePanelScript.new()
	dialogue_panel.name = "DialoguePanel"
	add_child(dialogue_panel)
	dialogue_panel.choice_activated.connect(_on_dialogue_choice_activated)
	dialogue_panel.dialogue_finished.connect(_on_dialogue_finished)


func open_dialogue(data: DialogueData, source: SceneInteractable = null) -> bool:
	if dialogue_panel == null:
		return false
	var opened := dialogue_panel.open_dialogue(data)
	active_interactable = source if opened else null
	return opened


func close_dialogue() -> void:
	if dialogue_panel != null:
		dialogue_panel.close_dialogue()


func _on_dialogue_choice_activated(
	action_id: StringName,
	payload: Variant
) -> void:
	var source := active_interactable
	if source != null and is_instance_valid(source):
		if source.handle_dialogue_action(action_id, payload):
			return
	dialogue_action_requested.emit(self, source, action_id, payload)


func _on_dialogue_finished() -> void:
	active_interactable = null


# ---------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------


func _build_scene_ui() -> void:
	super()
	_hud_root = Control.new()
	_hud_root.name = "SceneHUD"
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud_root)

	_title_label = Label.new()
	_title_label.name = "SceneTitle"
	_title_label.text = scene_display_name
	_title_label.anchor_left = 0.0
	_title_label.anchor_top = 0.0
	_title_label.offset_left = 30.0
	_title_label.offset_top = 22.0
	_title_label.offset_right = 430.0
	_title_label.offset_bottom = 62.0
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override(
		"font_color",
		Color(0.92, 0.97, 1.0)
	)
	_title_label.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.85)
	)
	_title_label.add_theme_constant_override("shadow_offset_x", 1)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_hud_root.add_child(_title_label)

	_prompt_panel = PanelContainer.new()
	_prompt_panel.name = "InteractionPrompt"
	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_right = 0.5
	_prompt_panel.anchor_top = 1.0
	_prompt_panel.anchor_bottom = 1.0
	_prompt_panel.offset_left = -240.0
	_prompt_panel.offset_right = 240.0
	_prompt_panel.offset_top = -96.0
	_prompt_panel.offset_bottom = -44.0
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var prompt_style := StyleBoxFlat.new()
	prompt_style.bg_color = Color(0.02, 0.04, 0.06, 0.82)
	prompt_style.border_color = Color(0.45, 0.82, 0.95, 0.72)
	prompt_style.set_border_width_all(1)
	prompt_style.set_corner_radius_all(8)
	_prompt_panel.add_theme_stylebox_override("panel", prompt_style)
	_prompt_panel.visible = false
	_hud_root.add_child(_prompt_panel)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label.add_theme_font_size_override("font_size", 17)
	_prompt_label.add_theme_color_override(
		"font_color",
		Color(0.88, 0.96, 1.0)
	)
	_prompt_panel.add_child(_prompt_label)

	_setup_dialogue()
